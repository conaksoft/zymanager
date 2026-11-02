import AppKit
import CoreServices
import Foundation

struct InstalledApp: Identifiable, Sendable {
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let isAppStore: Bool
    let lastUsed: Date?
    /// Other names the app may use for its folders: bundle name and executable (VS Code is "Code").
    var aliases: [String] = []
    var size: Int64 = 0

    var id: String { url.path }
}

/// A file or folder an app left in ~/Library (settings, caches, containers, saved state…).
struct AppLeftover: Identifiable, Sendable {
    let url: URL
    let kind: String
    /// Matched only by app name, not bundle id — worth a second look before deleting.
    let matchedByName: Bool
    var size: Int64 = 0

    var id: String { url.path }
}

enum AppInventory {
    static let searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL.home.appendingPathComponent("Applications"),
    ]

    /// Third-party apps in /Applications and ~/Applications (one folder level deep, e.g. /Applications/Utilities).
    /// Apple's own apps and ZyManager itself are left out.
    static func installedApps() -> [InstalledApp] {
        let fm = FileManager.default
        var bundles: [URL] = []
        for root in searchRoots {
            let items = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for item in items {
                if item.pathExtension == "app" {
                    bundles.append(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    let inner = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
                    bundles += inner.filter { $0.pathExtension == "app" }
                }
            }
        }

        let ownID = Bundle.main.bundleIdentifier
        return bundles.compactMap { url in
            let bundle = Bundle(url: url)
            let id = bundle?.bundleIdentifier
            if let id, id.hasPrefix("com.apple.") || id == ownID { return nil }
            let info = bundle?.infoDictionary ?? [:]
            return InstalledApp(
                url: url,
                // The bundle's file name is what people see in Finder and Launchpad.
                name: url.deletingPathExtension().lastPathComponent,
                bundleID: id,
                version: info["CFBundleShortVersionString"] as? String,
                isAppStore: fm.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt").path),
                lastUsed: lastUsedDate(of: url),
                aliases: [info["CFBundleName"], info["CFBundleExecutable"]].compactMap { $0 as? String }
            )
        }
    }

    /// Spotlight's record of when the app was last opened.
    private static func lastUsedDate(of url: URL) -> Date? {
        guard let item = MDItemCreate(nil, url.path as CFString),
              let date = MDItemCopyAttribute(item, kMDItemLastUsedDate) else { return nil }
        return date as? Date
    }

    // MARK: Leftovers

    private static let byBundleID: [(folder: String, kind: String)] = [
        ("Application Support", "Uygulama verisi"),
        ("Caches", "Önbellek"),
        ("Containers", "Sandbox kapsayıcısı"),
        ("Group Containers", "Paylaşılan kapsayıcı"),
        ("Preferences", "Ayarlar"),
        ("Saved Application State", "Pencere durumu"),
        ("HTTPStorages", "Ağ verisi"),
        ("WebKit", "Web verisi"),
        ("Cookies", "Çerezler"),
        ("Logs", "Loglar"),
        ("LaunchAgents", "Başlangıç öğesi"),
        ("Application Scripts", "Betikler"),
    ]

    /// Folders where an app's own name is a common folder name too (e.g. ~/Library/Application Support/Slack).
    private static let byName: [(folder: String, kind: String)] = [
        ("Application Support", "Uygulama verisi"),
        ("Caches", "Önbellek"),
        ("Logs", "Loglar"),
    ]

    static func leftovers(for app: InstalledApp) -> [AppLeftover] {
        let fm = FileManager.default
        let library = URL.home.appendingPathComponent("Library")
        var found: [String: AppLeftover] = [:]

        if let id = app.bundleID?.lowercased(), !id.isEmpty {
            for (folder, kind) in byBundleID {
                let dir = library.appendingPathComponent(folder)
                for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                    if matches(item.lastPathComponent.lowercased(), bundleID: id) {
                        found[item.path] = AppLeftover(url: item, kind: kind, matchedByName: false)
                    }
                }
            }
        }

        // Name matches: "Blender", "Code" (VS Code), and vendor folders such as "Google/Chrome" for com.google.Chrome.
        var names = Set(([app.url.deletingPathExtension().lastPathComponent] + app.aliases)
            .map { $0.lowercased() }
            .filter { $0.count >= 3 })
        if let parts = app.bundleID?.lowercased().split(separator: "."), parts.count >= 3 {
            names.insert("\(parts[1])/\(parts[2])")
        }
        for (folder, kind) in byName {
            let dir = library.appendingPathComponent(folder)
            for name in names {
                guard let candidate = existingPath(dir, name.split(separator: "/").map(String.init)),
                      found[candidate.path] == nil else { continue }
                found[candidate.path] = AppLeftover(url: candidate, kind: kind, matchedByName: true)
            }
        }

        return found.values.map { leftover in
            var l = leftover
            l.size = DiskUsage.allocatedSize(of: l.url)
            return l
        }
        .sorted { $0.size > $1.size }
    }

    /// Walks `components` under `dir` ignoring case, since folder names like "Google" vs "google" vary.
    private static func existingPath(_ dir: URL, _ components: [String]) -> URL? {
        var current = dir
        for component in components {
            let children = (try? FileManager.default.contentsOfDirectory(atPath: current.path)) ?? []
            guard let match = children.first(where: { $0.lowercased() == component }) else { return nil }
            current = current.appendingPathComponent(match)
        }
        return current
    }

    /// `com.foo.bar`, `com.foo.bar.plist`, `com.foo.bar.savedState`, `com.foo.bar.helper`,
    /// and group containers such as `ABCDE12345.com.foo.bar` or `group.com.foo.bar`.
    private static func matches(_ name: String, bundleID id: String) -> Bool {
        if name == id || name.hasPrefix(id + ".") { return true }
        guard let dot = name.firstIndex(of: ".") else { return false }
        let rest = name[name.index(after: dot)...]
        return rest == id || rest.hasPrefix(id + ".")
    }

    // MARK: Uninstall

    /// Quits the app if it's running, so its files can be removed. Returns false if it is still running.
    @MainActor
    static func quitIfRunning(_ app: InstalledApp) async -> Bool {
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL == app.url.standardizedFileURL }
        guard !running.isEmpty else { return true }
        running.forEach { $0.terminate() }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(250))
            if running.allSatisfy(\.isTerminated) { return true }
        }
        return false
    }

    /// Moves the app bundle to the Trash the way Finder does (asks for an admin password when the app
    /// belongs to root), and removes or trashes the chosen leftovers.
    @MainActor
    static func uninstall(_ app: InstalledApp, leftovers: [AppLeftover], toTrash: Bool) async -> [String] {
        var failures: [String] = []
        let error: Error? = await withCheckedContinuation { done in
            NSWorkspace.shared.recycle([app.url]) { _, error in done.resume(returning: error) }
        }
        if let error {
            failures.append("\(app.name): \(error.localizedDescription)")
            return failures
        }
        let urls = leftovers.map(\.url)
        failures += await Task.detached { Cleaner.remove(urls, toTrash: toTrash) }.value
        return failures
    }
}
