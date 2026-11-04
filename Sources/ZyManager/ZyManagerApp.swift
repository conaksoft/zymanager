import SwiftUI

@main
struct ZyManagerApp: App {
    @State private var state = AppState()
    @State private var navigation = Navigation()
    /// Changing the language rebuilds the views (`.id`) so every `L(...)` text is read again.
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.auto.rawValue

    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--clean"), i + 1 < CommandLine.arguments.count {
            exit(CommandLineCleaner.run(id: CommandLine.arguments[i + 1]))
        }
    }

    var body: some Scene {
        Window("ZyManager", id: "main") {
            ContentView()
                .environment(state)
                .environment(navigation)
                .frame(minWidth: 1120, minHeight: 680)
                .environment(\.locale, AppLanguage.locale)
                .id(language)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L("ZyManager Hakkında", "About ZyManager")) { navigation.showAbout = true }
            }
            // ⌘1–⌘5 switch sections, ⌘R rescans the one on screen.
            CommandGroup(after: .sidebar) {
                Divider()
                ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { i, s in
                    Button(s.title) { navigation.section = s }
                        .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                }
                Divider()
                Button(L("Yeniden tara", "Rescan")) { Task { await rescan(navigation.section ?? .overview) } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(state)
                .environment(\.locale, AppLanguage.locale)
                .id(language)
        } label: {
            MenuBarLabel(snapshot: state.memory.snapshot)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private func rescan(_ section: SidebarSection) async {
        switch section {
        case .overview: await state.scanAll()
        case .caches: await state.caches.scan(); state.refreshVolume()
        case .projects: await state.projects.scan()
        case .apps: await state.apps.scan()
        case .memory: state.memory.refresh()
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview = "Genel Bakış"
    case caches = "Önbellekler"
    case projects = "Projeler"
    case apps = "Uygulamalar"
    case memory = "Bellek"

    /// Raw values stay Turkish: they're the saved last section and the `-initialSection` argument.
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: L("Genel Bakış", "Overview")
        case .caches: L("Önbellekler", "Caches")
        case .projects: L("Projeler", "Projects")
        case .apps: L("Uygulamalar", "Apps")
        case .memory: L("Bellek", "Memory")
        }
    }

    var symbol: String {
        switch self {
        case .overview: "internaldrive"
        case .caches: "archivebox"
        case .projects: "folder"
        case .apps: "square.grid.2x2"
        case .memory: "memorychip"
        }
    }
}

/// Which screen is showing. Lives outside the view tree so menu commands can drive it.
@MainActor @Observable
final class Navigation {
    private static let lastSectionKey = "lastSection"

    var section: SidebarSection? {
        didSet { if let section { UserDefaults.standard.set(section.rawValue, forKey: Self.lastSectionKey) } }
    }
    var showAbout = false

    init() {
        // `-initialSection Projeler` on the command line wins; otherwise reopen where the user left off.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-initialSection"), i + 1 < args.count, let s = SidebarSection(rawValue: args[i + 1]) {
            section = s
        } else if let saved = UserDefaults.standard.string(forKey: Self.lastSectionKey), let s = SidebarSection(rawValue: saved) {
            section = s
        } else {
            section = .overview
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var state
    @Environment(Navigation.self) private var navigation
    /// Bumped shortly after launch and after the first scan. Sidebar rows measured before the window
    /// has its final width otherwise keep that tiny layout and show clipped titles (macOS 14 quirk).
    @State private var sidebarGeneration = 0

    var body: some View {
        @Bindable var navigation = navigation

        NavigationSplitView {
            VStack(spacing: 0) {
                List(SidebarSection.allCases, selection: $navigation.section) { s in
                    HStack {
                        Label(s.title, systemImage: s.symbol)
                        Spacer(minLength: 6)
                        if let value = sidebarValue(for: s) {
                            Text(value.text)
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundStyle(value.tint)
                                .fixedSize()
                        }
                    }
                    .tag(s)
                }
                .id(sidebarGeneration)
                sidebarFooter
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 215)
        } detail: {
            switch navigation.section ?? .overview {
            case .overview: OverviewView(section: $navigation.section)
            case .caches: CachesView()
            case .projects: ProjectsView()
            case .apps: AppsView()
            case .memory: MemoryView()
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            sidebarGeneration += 1
        }
        .task {
            if !state.caches.hasScanned { await state.scanAll() }
            sidebarGeneration += 1
        }
        .sheet(isPresented: $navigation.showAbout) { AboutSheet() }
    }

    private var sidebarFooter: some View {
        Button { navigation.showAbout = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption)
                Text("ZyManager · Conaksoft").font(.caption).lineLimit(1)
                Spacer(minLength: 0)
                Text("v\(Bundle.main.shortVersion)").font(.caption2.monospacedDigit()).fixedSize()
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("ZyManager Hakkında", "About ZyManager"))
    }

    /// Small live figure shown next to each sidebar item.
    private func sidebarValue(for s: SidebarSection) -> (text: String, tint: Color)? {
        switch s {
        case .overview:
            return nil
        case .caches:
            guard state.caches.hasScanned, state.caches.safeSize > 0 else { return nil }
            return (state.caches.safeSize.fileSizeText, .secondary)
        case .projects:
            guard state.projects.hasScanned, state.projects.totalSize > 0 else { return nil }
            return (state.projects.totalSize.fileSizeText, .secondary)
        case .apps:
            guard state.apps.hasScanned, !state.apps.apps.isEmpty else { return nil }
            return (state.apps.totalSize.fileSizeText, .secondary)
        case .memory:
            let m = state.memory.snapshot
            if m.pressure != .normal { return (m.pressure.title, m.pressure.color) }
            guard m.swapUsed > 0 else { return nil }
            return (m.swapUsed.memoryText, m.swapUsed > m.physical / 4 ? Brand.amberInk : .secondary)
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "—" }
}

/// Small About sheet: icon, version, company.
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
                .shadow(color: Brand.indigo.opacity(0.3), radius: 12, y: 6)
            VStack(spacing: 4) {
                Text("ZyManager").font(.title2.weight(.bold))
                Text(L("Sürüm", "Version") + " \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(L("Geliştiriciler için depolama ve bellek yöneticisi. Yalnızca yeniden üretilebilir dosyaları gösterir; hiçbir şeyi sormadan silmez.",
                    "Storage and memory manager for developers. It only shows files that can be recreated, and never deletes anything without asking."))
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("© Conaksoft").font(.caption).foregroundStyle(.tertiary)
            Button(L("Tamam", "OK")) { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 340)
    }
}

/// ZyManager > Settings (⌘,): app language.
struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.auto.rawValue

    var body: some View {
        Form {
            Picker(L("Dil", "Language"), selection: $language) {
                ForEach(AppLanguage.allCases) { Text($0.pickerTitle).tag($0.rawValue) }
            }
            .pickerStyle(.radioGroup)
            Text(L("Otomatik, Mac'in dili Türkçeyse Türkçe, değilse İngilizce kullanır.",
                   "Automatic uses Turkish if your Mac's language is Turkish, English otherwise."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 380)
        .id(language)
    }
}
