import AppKit
import SwiftUI

// MARK: - Brand palette

enum Brand {
    static let indigo = Color(red: 0x0E / 255, green: 0x13 / 255, blue: 0x30 / 255)
    static let violet = Color(red: 0x3B / 255, green: 0x2A / 255, blue: 0x8C / 255)
    static let teal = Color(red: 0x2E / 255, green: 0xE6 / 255, blue: 0xC5 / 255)
    static let cyan = Color(red: 0x22 / 255, green: 0xB8 / 255, blue: 0xF0 / 255)
    static let amber = Color(red: 0xFF / 255, green: 0xB5 / 255, blue: 0x47 / 255)
    static let red = Color(red: 0xFF / 255, green: 0x5C / 255, blue: 0x6E / 255)

    /// A readable teal for text on light backgrounds; the raw accent is too bright there.
    static let tealInk = Color(light: Color(red: 0x0E / 255, green: 0x9E / 255, blue: 0x86 / 255), dark: teal)
    static let amberInk = Color(light: Color(red: 0xC4 / 255, green: 0x7A / 255, blue: 0x00 / 255), dark: amber)
    /// Violet that reads on both appearances; used for the app-related accents.
    static let violetInk = Color(light: Color(red: 0x5B / 255, green: 0x48 / 255, blue: 0xC8 / 255),
                                 dark: Color(red: 0xA9 / 255, green: 0x9B / 255, blue: 0xFF / 255))

    static let accent = LinearGradient(colors: [teal, cyan], startPoint: .leading, endPoint: .trailing)
    static let hero = LinearGradient(colors: [indigo, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    /// Resolves differently in light and dark appearance.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
    }
}

extension Ecosystem {
    var tint: Color {
        switch self {
        case .xcode: Brand.cyan
        case .android: Color(red: 0x7B / 255, green: 0xD8 / 255, blue: 0x8F / 255)
        case .flutter: Color(red: 0x6D / 255, green: 0xA8 / 255, blue: 0xFF / 255)
        case .node: Color(light: Color(red: 0x6A / 255, green: 0xA8 / 255, blue: 0x12 / 255),
                          dark: Color(red: 0xA3 / 255, green: 0xE6 / 255, blue: 0x35 / 255))
        case .python: Color(light: Color(red: 0xC9 / 255, green: 0x93 / 255, blue: 0x00 / 255),
                            dark: Color(red: 0xFF / 255, green: 0xD1 / 255, blue: 0x66 / 255))
        case .php: Color(red: 0x9B / 255, green: 0x8C / 255, blue: 0xFF / 255)
        case .homebrew: Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x6B / 255)
        case .apps: Color(red: 0xF0 / 255, green: 0x8B / 255, blue: 0xD6 / 255)
        }
    }
}

extension ProjectArtifact.Kind {
    var tint: Color {
        switch self {
        case .nodeModules, .nextBuild: Ecosystem.node.tint
        case .dartTool, .flutterBuild: Ecosystem.flutter.tint
        case .gradleProject: Ecosystem.android.tint
        case .pods: Ecosystem.xcode.tint
        case .composerVendor: Ecosystem.php.tint
        case .pythonVenv: Ecosystem.python.tint
        }
    }

    var symbol: String {
        switch self {
        case .nodeModules, .nextBuild: "shippingbox"
        case .dartTool, .flutterBuild: "bird"
        case .gradleProject: "apps.iphone"
        case .pods: "hammer"
        case .composerVendor: "server.rack"
        case .pythonVenv: "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension MemoryPressure {
    var color: Color {
        switch self {
        case .normal: Brand.tealInk
        case .warning: Brand.amberInk
        case .critical: Brand.red
        }
    }

    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Surfaces

struct CardBackground: ViewModifier {
    var radius: CGFloat = 14
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
            }
    }
}

extension View {
    func card(radius: CGFloat = 14, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius, padding: padding))
    }

    /// Big, rounded, tabular numerals for headline values.
    func numeral(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// Icon in a tinted rounded square, like System Settings.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Badges

struct SafetyBadge: View {
    let safety: Safety

    var body: some View {
        Label(safety == .safe ? "Yeniden üretilir" : "Dikkat",
              systemImage: safety == .safe ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((safety == .safe ? Brand.teal : Brand.amber).opacity(0.16), in: Capsule())
            .foregroundStyle(safety == .safe ? Brand.tealInk : Brand.amberInk)
            .fixedSize()
    }
}

/// Small coloured chip: dot + text, readable in both appearances.
struct Chip: View {
    let text: String
    let tint: Color
    var symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.semibold)).foregroundStyle(tint)
            } else {
                Circle().fill(tint).frame(width: 6, height: 6)
            }
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

// MARK: - Meters

struct UsageBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    let total: Double
    var height: CGFloat = 10
    var track: Color = Color.primary.opacity(0.08)

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: height >= 8 ? 2 : 0) {
                ForEach(segments.filter { $0.value > 0 }) { s in
                    RoundedRectangle(cornerRadius: height / 2.5, style: .continuous)
                        .fill(s.color)
                        .frame(width: total > 0 ? max(2, geo.size.width * min(s.value / total, 1)) : 0)
                }
                Spacer(minLength: 0)
            }
            .animation(.easeOut(duration: 0.6), value: segments.map(\.value))
        }
        .frame(height: height)
        .background(track, in: RoundedRectangle(cornerRadius: height / 2.5, style: .continuous))
    }
}

struct RingGauge<Center: View>: View {
    struct Segment: Identifiable {
        let id = UUID()
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    let total: Double
    var lineWidth: CGFloat = 14
    var track: Color = Color.primary.opacity(0.08)
    @ViewBuilder var center: () -> Center

    private var bounds: [(Segment, Double, Double)] {
        guard total > 0 else { return [] }
        var start = 0.0
        return segments.map { s in
            let end = min(start + s.value / total, 1)
            defer { start = end }
            return (s, start, end)
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            ForEach(bounds, id: \.0.id) { s, from, to in
                Circle()
                    .trim(from: from, to: to)
                    .stroke(s.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            .animation(.easeOut(duration: 0.7), value: segments.map(\.value))
            center()
        }
        .padding(lineWidth / 2)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var value: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let value { Text(value).font(.caption.weight(.semibold).monospacedDigit()) }
        }
        .fixedSize()
    }
}

/// Label, value and a proportional bar — the building block of breakdown lists.
struct MeterRow: View {
    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String?
    let value: Double
    let total: Double
    let valueText: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: tint, size: 26)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.callout.weight(.medium))
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 8)
                    Text(valueText).font(.callout.weight(.semibold).monospacedDigit())
                }
                UsageBar(segments: [.init(value: value, color: tint)], total: total, height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Tiles

struct StatTile: View {
    let symbol: String
    let title: String
    let value: String
    var caption: String?
    var tint: Color = Brand.cyan
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconTile(symbol: symbol, tint: tint, size: 26)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if action != nil {
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            Text(value).numeral(26).foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .card()
    }
}

// MARK: - States

/// Spinner with a gently pulsing symbol, for scan-in-progress areas.
/// The pulse is a symbol effect rather than a `repeatForever` animation started in `onAppear`:
/// that one also captured the view's first layout position and kept sliding the icon diagonally.
struct ScanningPlaceholder: View {
    let text: String
    var symbol: String = "internaldrive"

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Brand.cyan.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: symbol).font(.system(size: 26, weight: .medium)).foregroundStyle(Brand.cyan)
                    .symbolEffect(.pulse, options: .repeating)
            }
            ProgressView().controlSize(.small)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Bottom action bar shared by the list screens.
struct ActionBar<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading()
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Highlights a row while the pointer is over it.
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(hovering ? 0.05 : 0), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    func hoverHighlight(radius: CGFloat = 8) -> some View { modifier(HoverHighlight(radius: radius)) }
}

/// Teal-on-indigo call to action used inside the hero card.
struct HeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(Brand.indigo)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Brand.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .shadow(color: Brand.teal.opacity(0.35), radius: 10, y: 3)
    }
}

/// Translucent white secondary button for the hero card.
struct HeroSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))
    }
}

// MARK: - Confirmation

/// Shown before any deletion: what goes, how much space comes back, and where it goes.
struct CleanupConfirmation: View {
    struct Line: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let size: Int64
        let safety: Safety
    }

    let lines: [Line]
    let onConfirm: (_ toTrash: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var toTrash = false

    private var total: Int64 { lines.reduce(0) { $0 + $1.size } }
    private var hasCaution: Bool { lines.contains { $0.safety == .caution } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(symbol: "sparkles", tint: Brand.cyan, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(total.fileSizeText) temizlenecek").numeral(22)
                    Text("\(lines.count) öğe silinecek. Bunlar yeniden üretilebilir dosyalardır; ilgili araç gerektiğinde tekrar indirir ya da derler.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title).font(.callout.weight(.medium))
                            Text(line.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if line.safety == .caution { SafetyBadge(safety: .caution) }
                        Text(line.size.fileSizeText).font(.callout.weight(.semibold).monospacedDigit()).fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    if i < lines.count - 1 { Divider().padding(.leading, 12) }
                }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 300)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))

            if hasCaution {
                Label("\"Dikkat\" işaretli öğeler kendiliğinden geri gelmez; gerekirse elle yeniden oluşturman gerekir.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Brand.amberInk)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Silmek yerine Çöp Kutusu'na taşı", isOn: $toTrash)
                    .toggleStyle(.switch).controlSize(.small)
                if toTrash {
                    Text("Alan, Çöp Kutusu boşaltılana kadar geri kazanılmaz.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(toTrash ? "Çöp Kutusu'na taşı" : "Sil", role: .destructive) {
                    onConfirm(toTrash)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(toTrash ? Brand.cyan : .red)
            }
        }
        .padding(22)
        .frame(width: 540)
    }
}

func revealInFinder(_ urls: [URL]) {
    NSWorkspace.shared.activateFileViewerSelecting(urls)
}

extension Date {
    var relativeText: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Result banner

/// Non-blocking result toast shown at the bottom of a screen. Successes fade out on their own;
/// failures stay until dismissed so nothing gets missed.
struct ResultBanner: ViewModifier {
    @Binding var message: String?
    @State private var dismissTask: Task<Void, Never>?

    private var isFailure: Bool {
        guard let message else { return false }
        return ["emedi", "amadı", "kapanmadı", "hata"].contains { message.lowercased().contains($0) }
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isFailure ? Brand.amberInk : Brand.tealInk)
                        Text(message)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 440, alignment: .leading)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark").font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Kapat")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder((isFailure ? Brand.amber : Brand.teal).opacity(0.45)))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(.bottom, 62)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear(perform: scheduleDismiss)
                    .onChange(of: message) { scheduleDismiss() }
                }
            }
            .animation(.spring(duration: 0.35), value: message == nil)
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard !isFailure else { return }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { dismiss() }
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}

extension View {
    func resultBanner(_ message: Binding<String?>) -> some View { modifier(ResultBanner(message: message)) }
}
