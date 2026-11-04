import Foundation

enum Ecosystem: String, CaseIterable, Identifiable, Sendable {
    case xcode
    case android
    case flutter
    case node
    case python
    case php
    case homebrew
    case apps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcode: "Xcode & iOS"
        case .android: "Android & Gradle"
        case .flutter: "Flutter & Dart"
        case .node: "Node.js / TypeScript"
        case .python: "Python"
        case .php: "PHP"
        case .homebrew: "Homebrew"
        case .apps: L("Editörler & Tarayıcılar", "Editors & Browsers")
        }
    }

    var symbol: String {
        switch self {
        case .xcode: "hammer"
        case .android: "apps.iphone"
        case .flutter: "bird"
        case .node: "curlybraces"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .php: "server.rack"
        case .homebrew: "mug"
        case .apps: "macwindow"
        }
    }
}

enum Safety: Sendable {
    /// Tools regenerate it automatically or on the next build/install.
    case safe
    /// Deleting it loses something you may have to recreate by hand.
    case caution
}

struct CacheItem: Identifiable, Sendable {
    let id: String
    let nameText: LText
    let detailText: LText
    let ecosystem: Ecosystem
    let safety: Safety
    /// Finds the folders this item covers at scan time.
    let locate: @Sendable () -> [URL]
    /// When set, cleanup runs this instead of deleting the folders directly.
    var command: (executable: String, arguments: [String])?

    var name: String { nameText.text }
    var detail: String { detailText.text }

    init(
        _ id: String, _ name: LText, _ ecosystem: Ecosystem, _ safety: Safety = .safe,
        detail: LText, paths: [String] = [],
        locate: (@Sendable () -> [URL])? = nil,
        command: (executable: String, arguments: [String])? = nil
    ) {
        self.id = id
        self.nameText = name
        self.detailText = detail
        self.ecosystem = ecosystem
        self.safety = safety
        self.command = command
        self.locate = locate ?? {
            paths.map { URL.home.appendingPathComponent($0) }.filter(DiskUsage.exists)
        }
    }
}

enum CacheCatalog {
    static let items: [CacheItem] = [
        // Xcode & iOS
        CacheItem("xcode.derived", LText("DerivedData", "DerivedData"), .xcode,
                  detail: LText("Xcode build çıktıları. Bir sonraki derlemede yeniden oluşur.",
                                "Xcode build output. Recreated on the next build."),
                  paths: ["Library/Developer/Xcode/DerivedData"]),
        CacheItem("xcode.devicesupport", LText("Cihaz destek dosyaları", "Device support files"), .xcode,
                  detail: LText("Bağladığın iPhone/Watch sürümleri için semboller. Cihaz tekrar bağlanınca iner.",
                                "Symbols for the iPhone/Watch versions you connected. Downloaded again when the device reconnects."),
                  paths: ["Library/Developer/Xcode/iOS DeviceSupport",
                          "Library/Developer/Xcode/watchOS DeviceSupport",
                          "Library/Developer/Xcode/tvOS DeviceSupport"]),
        CacheItem("xcode.simcaches", LText("Simülatör önbelleği", "Simulator cache"), .xcode,
                  detail: LText("CoreSimulator dyld ve runtime önbellekleri. Simülatör açılınca yeniden oluşur.",
                                "CoreSimulator dyld and runtime caches. Recreated when a simulator starts."),
                  paths: ["Library/Developer/CoreSimulator/Caches"]),
        CacheItem("xcode.unavailablesims", LText("Kullanılamayan simülatörler", "Unavailable simulators"), .xcode,
                  detail: LText("Runtime'ı silinmiş, artık açılamayan simülatör cihazları.",
                                "Simulator devices whose runtime was removed and that can no longer start."),
                  locate: { unavailableSimulators() },
                  command: ("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])),
        CacheItem("xcode.cache", LText("Xcode önbelleği", "Xcode cache"), .xcode,
                  detail: LText("Xcode'un genel önbelleği.", "Xcode's general cache."),
                  paths: ["Library/Caches/com.apple.dt.Xcode"]),
        CacheItem("xcode.cocoapods", LText("CocoaPods önbelleği", "CocoaPods cache"), .xcode,
                  detail: LText("İndirilmiş pod'lar. `pod install` tekrar indirir.",
                                "Downloaded pods. `pod install` downloads them again."),
                  paths: ["Library/Caches/CocoaPods"]),
        CacheItem("xcode.archives", LText("Xcode arşivleri", "Xcode archives"), .xcode, .caution,
                  detail: LText("Yayınladığın sürümlerin arşivleri. Crash loglarını çözmek için dSYM içerir.",
                                "Archives of the builds you shipped. They contain the dSYMs needed to symbolicate crash logs."),
                  paths: ["Library/Developer/Xcode/Archives"]),

        // Android & Gradle
        CacheItem("gradle.caches", LText("Gradle önbelleği", "Gradle cache"), .android,
                  detail: LText("İndirilen bağımlılıklar ve build önbelleği. Android Studio kapalıyken temizle.",
                                "Downloaded dependencies and build cache. Clean it while Android Studio is closed."),
                  paths: [".gradle/caches"]),
        CacheItem("gradle.wrapper", LText("Gradle sürümleri", "Gradle distributions"), .android,
                  detail: LText("Wrapper ile inen Gradle dağıtımları. Projede kullanılan sürüm tekrar iner.",
                                "Gradle distributions downloaded by the wrapper. The version a project uses is downloaded again."),
                  paths: [".gradle/wrapper/dists"]),
        CacheItem("gradle.daemon", LText("Gradle daemon logları", "Gradle daemon logs"), .android,
                  detail: LText("Eski daemon log dosyaları.", "Old daemon log files."),
                  paths: [".gradle/daemon"]),
        CacheItem("android.cache", LText("Android önbelleği", "Android cache"), .android,
                  detail: LText("SDK manager önbelleği.", "SDK manager cache."),
                  paths: [".android/cache"]),
        CacheItem("android.oldndk", LText("Eski NDK sürümleri", "Old NDK versions"), .android,
                  detail: LText("En yeni NDK dışındaki sürümler. Eski bir proje bunu isterse tekrar iner.",
                                "Every NDK version except the newest. Downloaded again if an older project needs it."),
                  locate: { olderVersions(in: "Library/Android/sdk/ndk") }),
        CacheItem("android.oldbuildtools", LText("Eski build-tools sürümleri", "Old build-tools versions"), .android,
                  detail: LText("En yeni build-tools dışındaki sürümler.", "Every build-tools version except the newest."),
                  locate: { olderVersions(in: "Library/Android/sdk/build-tools") }),
        CacheItem("android.avd", LText("Android emülatörleri", "Android emulators"), .android, .caution,
                  detail: LText("Emülatör cihazları ve içlerindeki veriler. Device Manager'dan yeniden oluşturman gerekir.",
                                "Emulator devices and the data inside them. You have to recreate them in Device Manager."),
                  paths: [".android/avd"]),
        CacheItem("android.systemimages", LText("Emülatör sistem imajları", "Emulator system images"), .android, .caution,
                  detail: LText("Emülatörlerin kullandığı Android imajları. Emülatör kullanmıyorsan silinebilir.",
                                "Android images used by emulators. Safe to remove if you don't use emulators."),
                  paths: ["Library/Android/sdk/system-images"]),

        // Flutter & Dart
        CacheItem("pub.hosted", LText("Pub paket önbelleği", "Pub package cache"), .flutter,
                  detail: LText("pub.dev'den inen paketler. `flutter pub get` tekrar indirir.",
                                "Packages downloaded from pub.dev. `flutter pub get` downloads them again."),
                  paths: [".pub-cache/hosted", ".pub-cache/git", ".pub-cache/_temp"]),

        // Node.js
        CacheItem("node.npm", LText("npm önbelleği", "npm cache"), .node,
                  detail: LText("npm'in indirme önbelleği. `npm install` tekrar indirir.",
                                "npm's download cache. `npm install` downloads packages again."),
                  paths: [".npm/_cacache", ".npm/_npx", ".npm/_logs"]),
        CacheItem("node.yarn", LText("Yarn önbelleği", "Yarn cache"), .node,
                  detail: LText("Yarn'ın paket önbelleği.", "Yarn's package cache."),
                  paths: ["Library/Caches/Yarn", ".yarn/berry/cache"]),
        CacheItem("node.pnpm", LText("pnpm deposu", "pnpm store"), .node,
                  detail: LText("pnpm'in paylaşılan paket deposu.", "pnpm's shared package store."),
                  paths: ["Library/pnpm/store", "Library/Caches/pnpm"]),
        CacheItem("node.bun", LText("Bun önbelleği", "Bun cache"), .node,
                  detail: LText("Bun'ın paket önbelleği.", "Bun's package cache."),
                  paths: [".bun/install/cache"]),
        CacheItem("node.browsers", LText("Puppeteer / Playwright tarayıcıları", "Puppeteer / Playwright browsers"), .node,
                  detail: LText("Test için indirilen Chromium sürümleri. Gerektiğinde tekrar iner.",
                                "Chromium builds downloaded for testing. Downloaded again when needed."),
                  paths: [".cache/puppeteer", "Library/Caches/ms-playwright"]),

        // Python
        CacheItem("python.pip", LText("pip önbelleği", "pip cache"), .python,
                  detail: LText("pip'in indirme ve wheel önbelleği.", "pip's download and wheel cache."),
                  paths: ["Library/Caches/pip", ".cache/pip"]),
        CacheItem("python.uv", LText("uv önbelleği", "uv cache"), .python,
                  detail: LText("uv'nin paket önbelleği.", "uv's package cache."),
                  paths: [".cache/uv", "Library/Caches/uv"]),
        CacheItem("python.poetry", LText("Poetry önbelleği", "Poetry cache"), .python,
                  detail: LText("Poetry'nin paket önbelleği.", "Poetry's package cache."),
                  paths: ["Library/Caches/pypoetry"]),

        // PHP
        CacheItem("php.composer", LText("Composer önbelleği", "Composer cache"), .php,
                  detail: LText("Composer'ın paket önbelleği. `composer install` tekrar indirir.",
                                "Composer's package cache. `composer install` downloads packages again."),
                  paths: ["Library/Caches/composer", ".composer/cache", ".cache/composer"]),

        // Homebrew
        CacheItem("brew.cache", LText("Homebrew indirmeleri", "Homebrew downloads"), .homebrew,
                  detail: LText("Kurulumdan sonra kalan indirme dosyaları.", "Download files left over after installs."),
                  paths: ["Library/Caches/Homebrew"]),

        // Editors & browsers
        CacheItem("apps.vscode", LText("VS Code önbelleği", "VS Code cache"), .apps,
                  detail: LText("VS Code'un önbellek ve log klasörleri. Ayarların ve eklentilerin silinmez.",
                                "VS Code's cache and log folders. Your settings and extensions are kept."),
                  paths: ["Library/Application Support/Code/Cache",
                          "Library/Application Support/Code/CachedData",
                          "Library/Application Support/Code/CachedExtensionVSIXs",
                          "Library/Application Support/Code/logs"]),
        CacheItem("apps.cursor", LText("Cursor önbelleği", "Cursor cache"), .apps,
                  detail: LText("Cursor'ın önbellek ve log klasörleri.", "Cursor's cache and log folders."),
                  paths: ["Library/Application Support/Cursor/Cache",
                          "Library/Application Support/Cursor/CachedData",
                          "Library/Application Support/Cursor/logs"]),
        CacheItem("apps.chrome", LText("Chrome önbelleği", "Chrome cache"), .apps,
                  detail: LText("Chrome'un sayfa önbelleği. Chrome kapalıyken temizle; geçmiş ve şifreler silinmez.",
                                "Chrome's page cache. Clean it while Chrome is closed; history and passwords are kept."),
                  paths: ["Library/Caches/Google/Chrome"]),
    ]

    /// Every version folder except the newest, compared as version numbers.
    private static func olderVersions(in relativePath: String) -> [URL] {
        let dir = URL.home.appendingPathComponent(relativePath)
        let versions = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedAscending }
        return Array(versions.dropLast())
    }

    private static func unavailableSimulators() -> [URL] {
        let result = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "unavailable", "-j"])
        guard result.status == 0,
              let json = try? JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any],
              let runtimes = json["devices"] as? [String: [[String: Any]]] else { return [] }
        let devicesDir = URL.home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        return runtimes.values.flatMap { $0 }
            .compactMap { $0["udid"] as? String }
            .map { devicesDir.appendingPathComponent($0) }
            .filter(DiskUsage.exists)
    }
}
