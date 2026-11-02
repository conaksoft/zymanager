import Foundation

enum Ecosystem: String, CaseIterable, Identifiable, Sendable {
    case xcode = "Xcode & iOS"
    case android = "Android & Gradle"
    case flutter = "Flutter & Dart"
    case node = "Node.js / TypeScript"
    case python = "Python"
    case php = "PHP"
    case homebrew = "Homebrew"
    case apps = "Editörler & Tarayıcılar"

    var id: String { rawValue }

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
    let name: String
    let detail: String
    let ecosystem: Ecosystem
    let safety: Safety
    /// Finds the folders this item covers at scan time.
    let locate: @Sendable () -> [URL]
    /// When set, cleanup runs this instead of deleting the folders directly.
    var command: (executable: String, arguments: [String])?

    init(
        _ id: String, _ name: String, _ ecosystem: Ecosystem, _ safety: Safety = .safe,
        detail: String, paths: [String] = [],
        locate: (@Sendable () -> [URL])? = nil,
        command: (executable: String, arguments: [String])? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
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
        CacheItem("xcode.derived", "DerivedData", .xcode,
                  detail: "Xcode build çıktıları. Bir sonraki derlemede yeniden oluşur.",
                  paths: ["Library/Developer/Xcode/DerivedData"]),
        CacheItem("xcode.devicesupport", "Cihaz destek dosyaları", .xcode,
                  detail: "Bağladığın iPhone/Watch sürümleri için semboller. Cihaz tekrar bağlanınca iner.",
                  paths: ["Library/Developer/Xcode/iOS DeviceSupport",
                          "Library/Developer/Xcode/watchOS DeviceSupport",
                          "Library/Developer/Xcode/tvOS DeviceSupport"]),
        CacheItem("xcode.simcaches", "Simülatör önbelleği", .xcode,
                  detail: "CoreSimulator dyld ve runtime önbellekleri. Simülatör açılınca yeniden oluşur.",
                  paths: ["Library/Developer/CoreSimulator/Caches"]),
        CacheItem("xcode.unavailablesims", "Kullanılamayan simülatörler", .xcode,
                  detail: "Runtime'ı silinmiş, artık açılamayan simülatör cihazları.",
                  locate: unavailableSimulators,
                  command: ("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])),
        CacheItem("xcode.cache", "Xcode önbelleği", .xcode,
                  detail: "Xcode'un genel önbelleği.",
                  paths: ["Library/Caches/com.apple.dt.Xcode"]),
        CacheItem("xcode.cocoapods", "CocoaPods önbelleği", .xcode,
                  detail: "İndirilmiş pod'lar. `pod install` tekrar indirir.",
                  paths: ["Library/Caches/CocoaPods"]),
        CacheItem("xcode.archives", "Xcode arşivleri", .xcode, .caution,
                  detail: "Yayınladığın sürümlerin arşivleri. Crash loglarını çözmek için dSYM içerir.",
                  paths: ["Library/Developer/Xcode/Archives"]),

        // Android & Gradle
        CacheItem("gradle.caches", "Gradle önbelleği", .android,
                  detail: "İndirilen bağımlılıklar ve build önbelleği. Android Studio kapalıyken temizle.",
                  paths: [".gradle/caches"]),
        CacheItem("gradle.wrapper", "Gradle sürümleri", .android,
                  detail: "Wrapper ile inen Gradle dağıtımları. Projede kullanılan sürüm tekrar iner.",
                  paths: [".gradle/wrapper/dists"]),
        CacheItem("gradle.daemon", "Gradle daemon logları", .android,
                  detail: "Eski daemon log dosyaları.",
                  paths: [".gradle/daemon"]),
        CacheItem("android.cache", "Android önbelleği", .android,
                  detail: "SDK manager önbelleği.",
                  paths: [".android/cache"]),
        CacheItem("android.oldndk", "Eski NDK sürümleri", .android,
                  detail: "En yeni NDK dışındaki sürümler. Eski bir proje bunu isterse tekrar iner.",
                  locate: { olderVersions(in: "Library/Android/sdk/ndk") }),
        CacheItem("android.oldbuildtools", "Eski build-tools sürümleri", .android,
                  detail: "En yeni build-tools dışındaki sürümler.",
                  locate: { olderVersions(in: "Library/Android/sdk/build-tools") }),
        CacheItem("android.avd", "Android emülatörleri", .android, .caution,
                  detail: "Emülatör cihazları ve içlerindeki veriler. Device Manager'dan yeniden oluşturman gerekir.",
                  paths: [".android/avd"]),
        CacheItem("android.systemimages", "Emülatör sistem imajları", .android, .caution,
                  detail: "Emülatörlerin kullandığı Android imajları. Emülatör kullanmıyorsan silinebilir.",
                  paths: ["Library/Android/sdk/system-images"]),

        // Flutter & Dart
        CacheItem("pub.hosted", "Pub paket önbelleği", .flutter,
                  detail: "pub.dev'den inen paketler. `flutter pub get` tekrar indirir.",
                  paths: [".pub-cache/hosted", ".pub-cache/git", ".pub-cache/_temp"]),

        // Node.js
        CacheItem("node.npm", "npm önbelleği", .node,
                  detail: "npm'in indirme önbelleği. `npm install` tekrar indirir.",
                  paths: [".npm/_cacache", ".npm/_npx", ".npm/_logs"]),
        CacheItem("node.yarn", "Yarn önbelleği", .node,
                  detail: "Yarn'ın paket önbelleği.",
                  paths: ["Library/Caches/Yarn", ".yarn/berry/cache"]),
        CacheItem("node.pnpm", "pnpm deposu", .node,
                  detail: "pnpm'in paylaşılan paket deposu.",
                  paths: ["Library/pnpm/store", "Library/Caches/pnpm"]),
        CacheItem("node.bun", "Bun önbelleği", .node,
                  detail: "Bun'ın paket önbelleği.",
                  paths: [".bun/install/cache"]),
        CacheItem("node.browsers", "Puppeteer / Playwright tarayıcıları", .node,
                  detail: "Test için indirilen Chromium sürümleri. Gerektiğinde tekrar iner.",
                  paths: [".cache/puppeteer", "Library/Caches/ms-playwright"]),

        // Python
        CacheItem("python.pip", "pip önbelleği", .python,
                  detail: "pip'in indirme ve wheel önbelleği.",
                  paths: ["Library/Caches/pip", ".cache/pip"]),
        CacheItem("python.uv", "uv önbelleği", .python,
                  detail: "uv'nin paket önbelleği.",
                  paths: [".cache/uv", "Library/Caches/uv"]),
        CacheItem("python.poetry", "Poetry önbelleği", .python,
                  detail: "Poetry'nin paket önbelleği.",
                  paths: ["Library/Caches/pypoetry"]),

        // PHP
        CacheItem("php.composer", "Composer önbelleği", .php,
                  detail: "Composer'ın paket önbelleği. `composer install` tekrar indirir.",
                  paths: ["Library/Caches/composer", ".composer/cache", ".cache/composer"]),

        // Homebrew
        CacheItem("brew.cache", "Homebrew indirmeleri", .homebrew,
                  detail: "Kurulumdan sonra kalan indirme dosyaları.",
                  paths: ["Library/Caches/Homebrew"]),

        // Editors & browsers
        CacheItem("apps.vscode", "VS Code önbelleği", .apps,
                  detail: "VS Code'un önbellek ve log klasörleri. Ayarların ve eklentilerin silinmez.",
                  paths: ["Library/Application Support/Code/Cache",
                          "Library/Application Support/Code/CachedData",
                          "Library/Application Support/Code/CachedExtensionVSIXs",
                          "Library/Application Support/Code/logs"]),
        CacheItem("apps.cursor", "Cursor önbelleği", .apps,
                  detail: "Cursor'ın önbellek ve log klasörleri.",
                  paths: ["Library/Application Support/Cursor/Cache",
                          "Library/Application Support/Cursor/CachedData",
                          "Library/Application Support/Cursor/logs"]),
        CacheItem("apps.chrome", "Chrome önbelleği", .apps,
                  detail: "Chrome'un sayfa önbelleği. Chrome kapalıyken temizle; geçmiş ve şifreler silinmez.",
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
