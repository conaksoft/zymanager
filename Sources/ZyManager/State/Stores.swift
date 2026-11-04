import AppKit
import Foundation
import Observation

/// Outcome of a cleanup or uninstall, shown in the result banner. Failures stay on screen until dismissed.
struct ResultMessage: Equatable {
    var text: String
    var isError = false
}

@MainActor @Observable
final class CacheStore {
    struct Entry: Identifiable {
        let item: CacheItem
        var urls: [URL] = []
        var size: Int64 = 0
        var id: String { item.id }
    }

    private(set) var entries: [Entry] = []
    var selection: Set<String> = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var hasScanned = false
    var lastMessage: ResultMessage?

    /// Anything under 1 MB is an empty folder, not worth a row.
    var found: [Entry] { entries.filter { $0.size >= 1_000_000 } }
    var totalSize: Int64 { found.reduce(0) { $0 + $1.size } }
    var safeSize: Int64 { found.filter { $0.item.safety == .safe }.reduce(0) { $0 + $1.size } }
    var selectedEntries: [Entry] { found.filter { selection.contains($0.id) } }
    var selectedSize: Int64 { selectedEntries.reduce(0) { $0 + $1.size } }

    func entries(in ecosystem: Ecosystem) -> [Entry] {
        found.filter { $0.item.ecosystem == ecosystem }.sorted { $0.size > $1.size }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        let items = CacheCatalog.items
        let results = await withTaskGroup(of: Entry.self) { group in
            for item in items {
                group.addTask {
                    let urls = item.locate()
                    return Entry(item: item, urls: urls, size: urls.reduce(0) { $0 + DiskUsage.allocatedSize(of: $1) })
                }
            }
            var out: [Entry] = []
            for await entry in group { out.append(entry) }
            return out
        }
        let order = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        entries = results.sorted { order[$0.id, default: 0] < order[$1.id, default: 0] }
        selection = selection.intersection(found.map(\.id))
        hasScanned = true
        isScanning = false
    }

    func selectAllSafe() {
        selection = Set(found.filter { $0.item.safety == .safe }.map(\.id))
    }

    func cleanSelected(toTrash: Bool) async {
        let targets = selectedEntries
        guard !targets.isEmpty else { return }
        isCleaning = true
        let failures = await Task.detached {
            targets.flatMap { Cleaner.clean($0.item, urls: $0.urls, toTrash: toTrash) }
        }.value
        let total = targets.reduce(0) { $0 + $1.size }
        lastMessage = failures.isEmpty
            ? ResultMessage(text: L("\(total.fileSizeText) temizlendi", "\(total.fileSizeText) cleaned")
                + (toTrash ? L(" (Çöp Kutusu'na taşındı).", " (moved to the Trash).") : "."))
            : ResultMessage(text: L("Bazı öğeler temizlenemedi:", "Some items couldn't be cleaned:") + "\n"
                + failures.joined(separator: "\n"), isError: true)
        selection.removeAll()
        isCleaning = false
        await scan()
    }
}

@MainActor @Observable
final class ProjectStore {
    private static let rootsKey = "projectRoots"

    var roots: [URL] {
        didSet { UserDefaults.standard.set(roots.map(\.path), forKey: Self.rootsKey) }
    }
    private(set) var artifacts: [ProjectArtifact] = []
    var selection: Set<String> = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var hasScanned = false
    var lastMessage: ResultMessage?

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.rootsKey) {
            roots = saved.map { URL(fileURLWithPath: $0) }
        } else {
            roots = ["Desktop", "Documents", "Developer", "Projects", "Code"]
                .map { URL.home.appendingPathComponent($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    var totalSize: Int64 { artifacts.reduce(0) { $0 + $1.size } }
    var selectedArtifacts: [ProjectArtifact] { artifacts.filter { selection.contains($0.id) } }
    var selectedSize: Int64 { selectedArtifacts.reduce(0) { $0 + $1.size } }

    func staleSize(olderThan days: Int) -> Int64 {
        stale(olderThan: days).reduce(0) { $0 + $1.size }
    }

    func stale(olderThan days: Int) -> [ProjectArtifact] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return artifacts.filter { ($0.lastActivity ?? .distantPast) < cutoff && $0.kind.safety == .safe }
    }

    func selectStale(olderThan days: Int) {
        selection = Set(stale(olderThan: days).map(\.id))
    }

    func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Ekle"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !roots.contains(url) { roots.append(url) }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        let roots = roots
        let found = await Task.detached { ProjectScanner.scan(roots: roots) }.value
        artifacts = await withTaskGroup(of: ProjectArtifact.self) { group in
            for artifact in found {
                group.addTask {
                    var a = artifact
                    a.size = DiskUsage.allocatedSize(of: a.url)
                    return a
                }
            }
            var out: [ProjectArtifact] = []
            for await a in group { out.append(a) }
            return out.sorted { $0.size > $1.size }
        }
        selection = selection.intersection(artifacts.map(\.id))
        hasScanned = true
        isScanning = false
    }

    func cleanSelected(toTrash: Bool) async {
        let targets = selectedArtifacts
        guard !targets.isEmpty else { return }
        isCleaning = true
        let failures = await Task.detached { Cleaner.remove(targets.map(\.url), toTrash: toTrash) }.value
        let total = targets.reduce(0) { $0 + $1.size }
        lastMessage = failures.isEmpty
            ? ResultMessage(text: L("\(targets.count) klasör, \(total.fileSizeText) temizlendi.",
                                    "\(targets.count) folders, \(total.fileSizeText) cleaned."))
            : ResultMessage(text: L("Bazı klasörler silinemedi:", "Some folders couldn't be deleted:") + "\n"
                + failures.joined(separator: "\n"), isError: true)
        let removed = Set(targets.map(\.id))
        artifacts.removeAll { removed.contains($0.id) && FileManager.default.fileExists(atPath: $0.url.path) == false }
        selection.removeAll()
        isCleaning = false
    }
}

@MainActor @Observable
final class MemoryMonitor {
    private(set) var snapshot = MemorySnapshot()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task {
            snapshot = await Task.detached(priority: .utility) { MemorySampler.sample() }.value
        }
    }

    /// Asks a GUI app to quit normally, so it can save its state.
    func quit(_ app: AppMemory) {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL?.path == app.bundlePath || app.pids.contains($0.processIdentifier)
        }
        running.forEach { $0.terminate() }
    }

    func canQuit(_ app: AppMemory) -> Bool {
        guard let bundle = app.bundlePath, !bundle.hasPrefix("/System") else { return false }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.path == bundle && $0.activationPolicy == .regular }
    }
}

@MainActor @Observable
final class AppsStore {
    private(set) var apps: [InstalledApp] = []
    private(set) var leftovers: [String: [AppLeftover]] = [:]
    private(set) var loadingLeftovers: Set<String> = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var uninstallingID: String?
    var lastMessage: ResultMessage?

    var totalSize: Int64 { apps.reduce(0) { $0 + $1.size } }

    /// Apps Spotlight last saw opened more than `days` ago — the usual uninstall candidates.
    /// Apps with no usable date are left out rather than guessed at; running apps are in use by definition.
    func unused(olderThan days: Int) -> [InstalledApp] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return apps.filter { app in
            guard let used = app.knownLastUsed, used < cutoff else { return false }
            return !isRunning(app)
        }
    }

    func unusedSize(olderThan days: Int) -> Int64 {
        unused(olderThan: days).reduce(0) { $0 + $1.size }
    }

    func leftoverSize(of app: InstalledApp) -> Int64 {
        leftovers[app.id]?.reduce(0) { $0 + $1.size } ?? 0
    }

    func isRunning(_ app: InstalledApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.standardizedFileURL == app.url.standardizedFileURL }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        let found = await Task.detached { AppInventory.installedApps() }.value
        apps = await withTaskGroup(of: InstalledApp.self) { group in
            for app in found {
                group.addTask {
                    var a = app
                    a.size = DiskUsage.allocatedSize(of: a.url)
                    return a
                }
            }
            var out: [InstalledApp] = []
            for await a in group { out.append(a) }
            return out.sorted { $0.size > $1.size }
        }
        leftovers = leftovers.filter { key, _ in apps.contains { $0.id == key } }
        hasScanned = true
        isScanning = false
    }

    /// Looks up the app's leftover files once; call again with `force` after something changed.
    func loadLeftovers(for app: InstalledApp, force: Bool = false) async {
        guard force || leftovers[app.id] == nil, !loadingLeftovers.contains(app.id) else { return }
        loadingLeftovers.insert(app.id)
        leftovers[app.id] = await Task.detached { AppInventory.leftovers(for: app) }.value
        loadingLeftovers.remove(app.id)
    }

    func uninstall(_ app: InstalledApp, leftovers chosen: [AppLeftover], toTrash: Bool) async {
        uninstallingID = app.id
        defer { uninstallingID = nil }

        guard await AppInventory.quitIfRunning(app) else {
            lastMessage = ResultMessage(text: L("\(app.name) kapanmadı. Uygulamayı kaydedip kapatın, sonra tekrar deneyin.",
                                                "\(app.name) didn't quit. Save your work and quit it, then try again."),
                                        isError: true)
            return
        }
        let failures = await AppInventory.uninstall(app, leftovers: chosen, toTrash: toTrash)
        let total = app.size + chosen.reduce(0) { $0 + $1.size }
        if failures.isEmpty {
            lastMessage = ResultMessage(text: L("\(app.name) kaldırıldı (\(total.fileSizeText)). Uygulama Çöp Kutusu'nda; ",
                                                "\(app.name) was uninstalled (\(total.fileSizeText)). The app is in the Trash; ")
                + (toTrash || chosen.isEmpty
                    ? L("alan, Çöp Kutusu boşaltılınca açılır.", "the space is freed when you empty the Trash.")
                    : L("kalıntı dosyalar silindi.", "its leftover files were deleted.")))
        } else {
            lastMessage = ResultMessage(text: L("Kaldırma tamamlanamadı:", "Uninstall didn't finish:") + "\n"
                + failures.joined(separator: "\n"), isError: true)
        }
        if !FileManager.default.fileExists(atPath: app.url.path) {
            apps.removeAll { $0.id == app.id }
            leftovers[app.id] = nil
        }
    }
}

extension InstalledApp {
    /// Spotlight sometimes reports the Unix epoch for apps it never saw opened; treat that as unknown.
    var knownLastUsed: Date? {
        guard let lastUsed, lastUsed.timeIntervalSince1970 > 978_307_200 else { return nil } // 2001-01-01
        return lastUsed
    }
}

@MainActor @Observable
final class AppState {
    let caches = CacheStore()
    let projects = ProjectStore()
    let apps = AppsStore()
    let memory = MemoryMonitor()
    private(set) var volume = DiskUsage.rootVolume()

    func refreshVolume() { volume = DiskUsage.rootVolume() }

    func scanAll() async {
        async let c: Void = caches.scan()
        async let p: Void = projects.scan()
        async let a: Void = apps.scan()
        _ = await (c, p, a)
        refreshVolume()
    }
}
