import Foundation

/// The app's two languages. Texts live next to the code that uses them as `L("Türkçe", "English")`,
/// so a screen reads in both languages at once and nothing needs a separate strings file.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follow the Mac's preferred language: Turkish if it's Turkish, English otherwise.
    case auto
    case tr
    case en

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// Shown in the language picker, always in its own language so it can be found from either one.
    var pickerTitle: String {
        switch self {
        case .auto: L("Otomatik (sistem dili)", "Automatic (system language)")
        case .tr: "Türkçe"
        case .en: "English"
        }
    }

    static var saved: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:)) ?? .auto
    }

    /// True when texts should be shown in English. Read on every `L` call; it's a single defaults lookup.
    static var isEnglish: Bool {
        switch saved {
        case .tr: false
        case .en: true
        case .auto: !(Locale.preferredLanguages.first ?? "en").hasPrefix("tr")
        }
    }

    /// Locale for dates and relative times ("2 ay önce" / "2 months ago").
    static var locale: Locale { Locale(identifier: isEnglish ? "en_US" : "tr_TR") }
}

/// Picks the Turkish or English text for the current language.
func L(_ tr: String, _ en: String) -> String {
    AppLanguage.isEnglish ? en : tr
}

/// A text stored in data (catalog items, kinds) that must follow a language change made after it was created.
struct LText: Sendable, Hashable {
    let tr: String
    let en: String

    init(_ tr: String, _ en: String) {
        self.tr = tr
        self.en = en
    }

    var text: String { L(tr, en) }
}
