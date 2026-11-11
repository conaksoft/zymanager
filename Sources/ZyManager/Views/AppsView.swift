import AppKit
import SwiftUI

/// Apps not opened for this long are flagged as uninstall candidates.
private let unusedDays = 90

enum AppSort: String, CaseIterable, Identifiable {
    case size
    case name
    case lastUsed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: L("Boyut", "Size")
        case .name: L("Ad", "Name")
        case .lastUsed: L("Son kullanım", "Last used")
        }
    }
}

/// "1 item" / "3 items" in English; Turkish doesn't change the noun.
private func count(_ n: Int, _ tr: String, _ one: String, _ many: String) -> String {
    L("\(n) \(tr)", "\(n) \(n == 1 ? one : many)")
}

struct AppsView: View {
    @Environment(AppState.self) private var state
    @State private var query = ""
    @State private var sort: AppSort = .size
    @State private var onlyUnused = false
    @State private var selectedID: String?
    /// Leftover ids ticked in the detail pane; reset to "all" whenever the selected app changes.
    @State private var chosen: Set<String> = []
    @State private var request: UninstallRequest?

    /// What the confirmation sheet shows; built at the moment "Kaldır…" is pressed.
    struct UninstallRequest: Identifiable {
        let app: InstalledApp
        let leftovers: [AppLeftover]
        var id: String { app.id }
    }

    private var selectedApp: InstalledApp? { state.apps.apps.first { $0.id == selectedID } }

    private var visible: [InstalledApp] {
        var list = onlyUnused ? state.apps.unused(olderThan: unusedDays) : state.apps.apps
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(q) || ($0.bundleID?.localizedCaseInsensitiveContains(q) ?? false) }
        }
        switch sort {
        case .size: return list.sorted { $0.size > $1.size }
        case .name: return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastUsed: return list.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
    }

    var body: some View {
        @Bindable var apps = state.apps
        let unused = apps.unused(olderThan: unusedDays)

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                listHeader(unusedCount: unused.count, unusedSize: apps.unusedSize(olderThan: unusedDays))
                Divider()
                Group {
                    if apps.isScanning && !apps.hasScanned {
                        ScanningPlaceholder(text: L("Uygulamalar taranıyor…", "Scanning apps…"), symbol: "square.grid.2x2")
                    } else if apps.hasScanned && apps.apps.isEmpty {
                        ContentUnavailableView(L("Uygulama bulunamadı", "No apps found"), systemImage: "square.grid.2x2",
                                               description: Text(L("/Applications ve ~/Applications içinde üçüncü taraf uygulama yok.",
                                                                   "There are no third-party apps in /Applications or ~/Applications.")))
                    } else if apps.hasScanned && visible.isEmpty {
                        if query.isEmpty {
                            ContentUnavailableView(L("Aday yok", "No candidates"), systemImage: "checkmark.circle",
                                                   description: Text(L("Her uygulama son \(unusedDays) gün içinde açılmış.",
                                                                       "Every app was opened in the last \(unusedDays) days.")))
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    } else {
                        List(selection: $selectedID) {
                            ForEach(visible) { app in
                                AppRow(app: app, isRunning: apps.isRunning(app))
                                    .tag(app.id)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .contextMenu(forSelectionType: String.self) { ids in
                            Button(L("Finder'da göster", "Show in Finder")) { revealInFinder(apps.apps.filter { ids.contains($0.id) }.map(\.url)) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

            Divider()

            Group {
                if let app = selectedApp {
                    AppDetail(app: app, chosen: $chosen) { requestUninstall(app) }
                        .id(app.id)
                } else {
                    ContentUnavailableView {
                        Label(L("Bir uygulama seç", "Select an app"), systemImage: "square.grid.2x2")
                    } description: {
                        Text(L("Boyutunu ve ~/Library'de bıraktığı dosyaları gör; istersen tek adımda kaldır.",
                            "See its size and the files it left in ~/Library, and uninstall it in one step if you want."))
                    }
                }
            }
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L("Uygulamalar", "Apps"))
        .navigationSubtitle(apps.hasScanned ? "\(count(apps.apps.count, "uygulama", "app", "apps")) · \(apps.totalSize.fileSizeText)" : L("taranıyor…", "scanning…"))
        .searchable(text: $query, placement: .toolbar, prompt: L("Uygulama ara", "Search apps"))
        .toolbar {
            Picker(L("Sırala", "Sort"), selection: $sort) {
                ForEach(AppSort.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .help(L("Sıralama", "Sort order"))
            Button {
                Task { await apps.scan() }
            } label: {
                if apps.isScanning { ProgressView().controlSize(.small) } else { Label(L("Yeniden tara", "Rescan"), systemImage: "arrow.clockwise") }
            }
            .disabled(apps.isScanning)
            .help(L("Yeniden tara", "Rescan"))
        }
        .task {
            if !apps.hasScanned { await apps.scan() }
            preselectFromLaunchArgs()
        }
        .onChange(of: apps.hasScanned) { preselectFromLaunchArgs() }
        .task(id: selectedID) {
            guard let app = selectedApp else { return }
            await apps.loadLeftovers(for: app)
            chosen = Set(apps.leftovers[app.id]?.map(\.id) ?? [])
        }
        .sheet(item: $request) { req in
            UninstallConfirmation(app: req.app, leftovers: req.leftovers, isRunning: apps.isRunning(req.app)) { toTrash in
                Task {
                    await apps.uninstall(req.app, leftovers: req.leftovers, toTrash: toTrash)
                    state.refreshVolume()
                }
            }
        }
        .resultBanner($apps.lastMessage)
    }

    private func requestUninstall(_ app: InstalledApp) {
        let leftovers = (state.apps.leftovers[app.id] ?? []).filter { chosen.contains($0.id) }
        request = UninstallRequest(app: app, leftovers: leftovers)
    }

    /// `-initialApp Blender` on the command line opens that app's detail (handy for screenshots).
    private func preselectFromLaunchArgs() {
        guard selectedID == nil, state.apps.hasScanned,
              let name = UserDefaults.standard.string(forKey: "initialApp"),
              let app = state.apps.apps.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { return }
        selectedID = app.id
        // `-previewUninstall YES` only opens the confirmation sheet; nothing happens until "Kaldır" is clicked.
        if UserDefaults.standard.bool(forKey: "previewUninstall") {
            Task {
                await state.apps.loadLeftovers(for: app)
                while state.apps.loadingLeftovers.contains(app.id) { try? await Task.sleep(for: .milliseconds(100)) }
                chosen = Set(state.apps.leftovers[app.id]?.map(\.id) ?? [])
                requestUninstall(app)
            }
        }
    }

    private func listHeader(unusedCount: Int, unusedSize: Int64) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: $onlyUnused) {
                Text(L("Tümü", "All")).tag(false)
                Text(L("\(unusedDays)+ gün", "\(unusedDays)+ days")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(L("Yalnızca \(unusedDays) gündür açılmamış uygulamaları göster", "Show only apps not opened in \(unusedDays) days"))
            Spacer(minLength: 4)
            if state.apps.hasScanned, unusedCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.caption)
                    Text("\(count(unusedCount, "aday", "candidate", "candidates")) · \(unusedSize.fileSizeText)")
                        .font(.caption.weight(.medium).monospacedDigit())
                }
                .foregroundStyle(Brand.amberInk)
                .fixedSize()
                .help(L("\(unusedDays) gündür açılmamış uygulamalar", "Apps not opened in \(unusedDays) days"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.bar)
    }
}

// MARK: - Helpers

extension InstalledApp {
    func isUnused(days: Int = unusedDays) -> Bool {
        guard let used = knownLastUsed else { return false }
        return used < Date().addingTimeInterval(-Double(days) * 86_400)
    }

    /// Spotlight's last-open date is approximate, so the text says so.
    var lastUsedText: String {
        knownLastUsed.map { "≈ \($0.relativeText)" } ?? L("son kullanım bilinmiyor", "last use unknown")
    }
}

/// Finder icons, cached so list scrolling doesn't keep asking the workspace.
enum AppIcons {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for url: URL) -> NSImage {
        if let hit = cache.object(forKey: url.path as NSString) { return hit }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 64, height: 64)
        cache.setObject(image, forKey: url.path as NSString)
        return image
    }
}

private struct AppStoreBadge: View {
    var body: some View {
        Image(systemName: "bag.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Brand.cyan)
            .frame(width: 16, height: 16)
            .background(Brand.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .help(L("App Store'dan yüklendi", "Installed from the App Store"))
    }
}

private struct RunningBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Brand.tealInk).frame(width: 6, height: 6)
            Text(L("Açık", "Running")).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(Brand.tealInk)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Brand.teal.opacity(0.14), in: Capsule())
        .help(L("Uygulama şu anda çalışıyor", "The app is running right now"))
    }
}

// MARK: - List row

private struct AppRow: View {
    let app: InstalledApp
    let isRunning: Bool

    var body: some View {
        let unused = app.isUnused() && !isRunning
        HStack(spacing: 10) {
            Image(nsImage: AppIcons.icon(for: app.url))
                .resizable().interpolation(.high)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name).font(.callout.weight(.medium)).lineLimit(1)
                    if app.isAppStore { AppStoreBadge() }
                    if isRunning { RunningBadge() }
                }
                HStack(spacing: 4) {
                    if let version = app.version {
                        Text(version).lineLimit(1)
                        Text("·")
                    }
                    if unused { Image(systemName: "clock").font(.caption2) }
                    Text(isRunning ? L("şu anda açık", "running now") : app.lastUsedText).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(unused ? Brand.amberInk : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(app.size.fileSizeText)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .fixedSize()
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Detail

private struct AppDetail: View {
    @Environment(AppState.self) private var state
    let app: InstalledApp
    @Binding var chosen: Set<String>
    let onUninstall: () -> Void

    private var leftovers: [AppLeftover] { state.apps.leftovers[app.id] ?? [] }
    private var isLoading: Bool { state.apps.loadingLeftovers.contains(app.id) }
    private var chosenSize: Int64 { leftovers.filter { chosen.contains($0.id) }.reduce(0) { $0 + $1.size } }
    private var isUninstalling: Bool { state.apps.uninstallingID == app.id }

    /// Leftovers grouped by kind, heaviest group first.
    private var groups: [(kind: LeftoverKind, items: [AppLeftover])] {
        Dictionary(grouping: leftovers, by: \.kind)
            .map { (kind: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.items.reduce(0) { $0 + $1.size } > $1.items.reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if app.isUnused() && !state.apps.isRunning(app) { unusedNote }
                    stats
                    leftoverSection
                    Text(L("Son kullanım tarihi Spotlight kayıtlarına dayanır ve yaklaşıktır. Kalıntılar yalnızca ~/Library altında aranır; sistem genelindeki (ör. /Library) dosyalar listelenmez.",
                            "Last-used dates come from Spotlight and are approximate. Leftovers are only searched for in ~/Library; system-wide files (e.g. in /Library) aren't listed."))
                        .font(.caption).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
            }

            ActionBar {
                let allOn = !leftovers.isEmpty && chosen.count == leftovers.count
                Button(allOn ? L("Kalıntı seçimini kaldır", "Deselect leftovers") : L("Tüm kalıntıları seç", "Select all leftovers")) {
                    if allOn { chosen.removeAll() } else { chosen = Set(leftovers.map(\.id)) }
                }
                .disabled(leftovers.isEmpty)
            } trailing: {
                if isUninstalling { ProgressView().controlSize(.small) }
                (Text(L("Toplam ", "Total "))
                    .foregroundStyle(.secondary)
                + Text((app.size + chosenSize).fileSizeText).fontWeight(.semibold).foregroundStyle(.primary)
                + Text(chosen.isEmpty ? "" : " · \(count(chosen.count, "kalıntı", "leftover", "leftovers"))").foregroundStyle(.secondary))
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Button(action: onUninstall) {
                    Label(L("Kaldır…", "Uninstall…"), systemImage: "trash")
                }
                .fixedSize()
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .disabled(isUninstalling || isLoading)
            }
        }
        .overlay {
            if isUninstalling {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text(L("\(app.name) kaldırılıyor…", "Uninstalling \(app.name)…")).font(.callout.weight(.medium))
                    Text(L("Uygulama açıksa önce kapanması bekleniyor.", "If the app is open, waiting for it to quit first.")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.15))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isUninstalling)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: AppIcons.icon(for: app.url))
                .resizable().interpolation(.high)
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(app.name).font(.title2.weight(.bold)).lineLimit(1)
                    if app.isAppStore {
                        Chip(text: "App Store", tint: Brand.cyan, symbol: "bag.fill")
                    }
                    if state.apps.isRunning(app) { RunningBadge() }
                }
                if let version = app.version {
                    Text(L("Sürüm \(version)", "Version \(version)"))
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                // Bundle id and path get their own lines: next to the version the id was cut to "com.go…Chrome".
                ForEach([app.bundleID, app.url.tildePath].compactMap { $0 }, id: \.self) { line in
                    Text(line)
                        .font(.caption.monospaced()).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { revealInFinder([app.url]) } label: {
                Label(L("Finder'da göster", "Show in Finder"), systemImage: "magnifyingglass")
            }
        }
    }

    private var unusedNote: some View {
        Label {
            let when = app.knownLastUsed?.relativeText ?? ""
            Text(L("Spotlight'a göre yaklaşık \(when) açılmış. Kullanmıyorsan kaldırma adayı olabilir; kullanıyorsan bu uyarıyı yok sayabilirsin.",
                   "Spotlight says it was last opened about \(when). If you don't use it, it may be worth uninstalling; if you do, you can ignore this."))
        } icon: {
            Image(systemName: "clock.fill")
        }
        .font(.callout)
        .foregroundStyle(Brand.amberInk)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.amber.opacity(0.25)))
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("shippingbox.fill", L("Uygulama", "App"), app.size.fileSizeText, "\(app.url.deletingLastPathComponent().tildePath)", Brand.violetInk)
            stat("tray.full.fill", L("Kalıntılar", "Leftovers"),
                 isLoading ? "…" : state.apps.leftoverSize(of: app).fileSizeText,
                 isLoading ? L("aranıyor", "searching") : "\(count(leftovers.count, "öğe", "item", "items")) · \(L("\(chosen.count) seçili", "\(chosen.count) selected"))", Brand.cyan)
            stat("sparkles", L("Açılacak alan", "Space to free"), (app.size + chosenSize).fileSizeText,
                 L("uygulama + kalıntılar", "app + leftovers"), Brand.tealInk)
        }
    }

    private func stat(_ symbol: String, _ title: String, _ value: String, _ caption: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                IconTile(symbol: symbol, tint: tint, size: 24)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(value).numeral(22).lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(caption).font(.caption).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    @ViewBuilder
    private var leftoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L("Kalıntı dosyalar", "Leftover files"),
                         subtitle: L("~/Library altında bu uygulamaya ait klasörler. Seçtiklerin uygulamayla birlikte kaldırılır.",
                                     "Folders in ~/Library that belong to this app. The ones you select are removed along with it."))
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L("Kalıntı dosyalar aranıyor…", "Looking for leftover files…")).font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .card()
            } else if leftovers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle").foregroundStyle(Brand.tealInk)
                    Text(L("Kalıntı bulunamadı. Kaldırınca yalnızca uygulama paketi Çöp Kutusu'na gider.",
                            "No leftovers found. Uninstalling moves only the app bundle to the Trash."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                ForEach(groups, id: \.kind) { group in
                    LeftoverGroupCard(kind: group.kind, items: group.items, chosen: $chosen)
                }
            }
        }
    }
}

/// One kind of leftover (settings, caches…) with a header checkbox and its rows.
private struct LeftoverGroupCard: View {
    let kind: LeftoverKind
    let items: [AppLeftover]
    @Binding var chosen: Set<String>

    private var total: Int64 { items.reduce(0) { $0 + $1.size } }
    private var allOn: Bool { items.allSatisfy { chosen.contains($0.id) } }
    private var isUserData: Bool { kind.isUserData }

    private var symbol: String {
        switch kind {
        case .appData: "person.text.rectangle"
        case .cache: "archivebox"
        case .preferences: "gearshape"
        case .container, .groupContainer: "shippingbox"
        case .savedState: "macwindow"
        case .logs: "doc.text"
        case .launchAgent: "power"
        case .cookies, .webData, .httpStorage: "network"
        case .scripts: "doc"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { allOn },
                    set: { on in for i in items { if on { chosen.insert(i.id) } else { chosen.remove(i.id) } } }
                ))
                .labelsHidden().toggleStyle(.checkbox)
                IconTile(symbol: symbol, tint: isUserData ? Brand.amberInk : Brand.cyan, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).font(.headline)
                    if isUserData {
                        Text(L("Ayarlar, profiller ve oturumlar burada (ör. Chrome profilleri). Silersen uygulamayı sonra yeniden kurduğunda bunlar geri gelmez.",
                                "Settings, profiles and sessions live here (e.g. Chrome profiles). If you delete them, they won't come back when you reinstall the app later."))
                            .font(.caption).foregroundStyle(Brand.amberInk)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(count(items.count, "öğe", "item", "items")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(total.fileSizeText).numeral(15, weight: .semibold).fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.leading, 14)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    LeftoverRow(item: item, isOn: Binding(
                        get: { chosen.contains(item.id) },
                        set: { on in if on { chosen.insert(item.id) } else { chosen.remove(item.id) } }
                    ))
                    if i < items.count - 1 { Divider().padding(.leading, 40) }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isUserData ? Brand.amber.opacity(0.3) : Color.primary.opacity(0.07)))
        }
    }
}

private struct LeftoverRow: View {
    let item: AppLeftover
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(item.url.deletingLastPathComponent().tildePath)
                        .font(.caption.monospaced()).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                    if item.matchedByName {
                        Text(L("ada göre eşleşti", "matched by name"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                            .help(L("Bu klasör paket kimliğiyle değil, uygulamanın adıyla eşleşti; başka bir şeye ait olabilir.",
                                     "This folder matched the app's name, not its bundle ID, so it may belong to something else."))
                            .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { revealInFinder([item.url]) } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(L("Finder'da göster", "Show in Finder"))
            .opacity(hovering ? 1 : 0)
            Text(item.size.fileSizeText).font(.callout.weight(.semibold).monospacedDigit()).fixedSize()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? Brand.cyan.opacity(0.08) : Color.primary.opacity(hovering ? 0.05 : 0))
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onTapGesture { isOn.toggle() }
    }
}

// MARK: - Confirmation

/// Sibling of `CleanupConfirmation` for removing an app: what goes where, and what can't come back.
struct UninstallConfirmation: View {
    let app: InstalledApp
    let leftovers: [AppLeftover]
    let isRunning: Bool
    let onConfirm: (_ toTrash: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var toTrash = true

    private var total: Int64 { app.size + leftovers.reduce(0) { $0 + $1.size } }
    private var hasUserData: Bool { leftovers.contains { $0.kind.isUserData } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: AppIcons.icon(for: app.url))
                    .resizable().interpolation(.high)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("\(app.name) kaldırılacak", "Uninstall \(app.name)")).numeral(22)
                    Text(leftovers.isEmpty
                         ? L("Yalnızca uygulama paketi, \(total.fileSizeText).", "Only the app bundle, \(total.fileSizeText).")
                         : L("Uygulama paketi ve \(leftovers.count) kalıntı öğe, toplam \(total.fileSizeText).",
                             "The app bundle and \(leftovers.count == 1 ? "1 leftover item" : "\(leftovers.count) leftover items"), \(total.fileSizeText) in total."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    line(title: app.name, subtitle: app.url.tildePath, size: app.size, note: L("Çöp Kutusu'na", "to Trash"))
                    ForEach(leftovers) { l in
                        Divider().padding(.leading, 12)
                        line(title: l.url.lastPathComponent, subtitle: "\(l.kind.title) · \(l.url.deletingLastPathComponent().tildePath)",
                             size: l.size, note: toTrash ? L("Çöp Kutusu'na", "to Trash") : L("kalıcı", "permanent"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 260)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))

            VStack(alignment: .leading, spacing: 8) {
                note("trash", L("Uygulama paketi her zaman Çöp Kutusu'na taşınır; geri almak için oradan sürüklemen yeterli. Bazı uygulamalar için macOS yönetici parolası isteyebilir.",
                                 "The app bundle always goes to the Trash; to get it back, just drag it out. For some apps, macOS may ask for an administrator password."))
                if isRunning {
                    note("power", L("\(app.name) şu anda açık. Önce normal yoldan kapanması istenecek; kaydedilmemiş işin varsa şimdi kaydet.",
                                     "\(app.name) is running. It will be asked to quit normally first; if you have unsaved work, save it now."), warning: true)
                }
                if hasUserData {
                    note("exclamationmark.triangle.fill", L("Seçili kalıntılarda uygulama verisi var: ayarlar, profiller ve oturumlar. Uygulamayı sonra yeniden kurarsan bunlar geri gelmez.",
                                                             "The selected leftovers include app data: settings, profiles and sessions. They won't come back if you reinstall the app later."), warning: true)
                }
            }

            if !leftovers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L("Kalıntı dosyaları da Çöp Kutusu'na taşı", "Move leftover files to the Trash too"), isOn: $toTrash)
                        .toggleStyle(.switch).controlSize(.small)
                    Text(toTrash
                         ? L("Alan, Çöp Kutusu boşaltılana kadar geri kazanılmaz.", "The space isn't freed until the Trash is emptied.")
                         : L("Kalıntılar kalıcı olarak silinir; bu geri alınamaz.", "Leftovers are deleted permanently; this can't be undone."))
                        .font(.caption).foregroundStyle(toTrash ? .secondary : Brand.amberInk)
                }
            }

            HStack {
                Spacer()
                Button(L("Vazgeç", "Cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("Kaldır", "Uninstall"), role: .destructive) {
                    onConfirm(toTrash)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(toTrash ? Brand.cyan : .red)
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    private func line(title: String, subtitle: String, size: Int64, note: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(note).font(.caption2).foregroundStyle(.tertiary).fixedSize()
            Text(size.fileSizeText).font(.callout.weight(.semibold).monospacedDigit()).fixedSize()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func note(_ symbol: String, _ text: String, warning: Bool = false) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.callout)
        .foregroundStyle(warning ? Brand.amberInk : .secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warning ? Brand.amber.opacity(0.12) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
