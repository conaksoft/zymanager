import SwiftUI

struct MemoryView: View {
    @Environment(AppState.self) private var state

    private var s: MemorySnapshot { state.memory.snapshot }
    private var swapHeavy: Bool { s.swapUsed > s.physical / 4 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    pressureCard
                    compositionCard
                    swapCard
                }
                .fixedSize(horizontal: false, vertical: true)

                if let advice {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(symbol: "lightbulb.fill", tint: Brand.amber, size: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Öneri").font(.headline)
                            Text(advice).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Brand.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.amber.opacity(0.25)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                topApps
            }
            .padding(22)
            .animation(.easeOut(duration: 0.4), value: advice)
        }
        .navigationTitle("Bellek")
        .navigationSubtitle("\(s.used.memoryText) / \(s.physical.memoryText) kullanımda")
    }

    // MARK: Cards

    private var pressureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bellek basıncı").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: s.pressure.symbol).foregroundStyle(s.pressure.color)
            }
            HStack(spacing: 14) {
                RingGauge(segments: [
                    .init(value: Double(s.appMemory), color: s.pressure == .normal ? Brand.cyan : s.pressure.color),
                    .init(value: Double(s.wired), color: Brand.violet.opacity(0.9)),
                    .init(value: Double(s.compressed), color: Brand.amber),
                ], total: Double(s.physical), lineWidth: 9) {
                    Text(s.physical > 0 ? Int(Double(s.used) / Double(s.physical) * 100) : 0, format: .percent)
                        .numeral(15)
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.pressure.title).numeral(24).foregroundStyle(s.pressure.color)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text("\(s.used.memoryText) / \(s.physical.memoryText)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(pressureHint).font(.caption).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }

    private var pressureHint: String {
        switch s.pressure {
        case .normal: "Sistem rahat; bellek verimli kullanılıyor."
        case .warning: "Bellek sıkışık; macOS sıkıştırma ve swap'e başvuruyor."
        case .critical: "Bellek kritik; uygulamalar yavaşlayabilir."
        }
    }

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kullanım dağılımı").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(s.used.memoryText).numeral(24)
                .contentTransition(.numericText())
            UsageBar(segments: [
                .init(value: Double(s.appMemory), color: Brand.cyan),
                .init(value: Double(s.wired), color: Brand.violet.opacity(0.9)),
                .init(value: Double(s.compressed), color: Brand.amber),
            ], total: Double(s.physical), height: 10)
            VStack(alignment: .leading, spacing: 4) {
                LegendDot(color: Brand.cyan, label: "Uygulamalar", value: s.appMemory.memoryText)
                LegendDot(color: Brand.violet.opacity(0.9), label: "Sistem (wired)", value: s.wired.memoryText)
                LegendDot(color: Brand.amber, label: "Sıkıştırılmış", value: s.compressed.memoryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }

    private var swapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Swap").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "internaldrive").foregroundStyle(swapHeavy ? Brand.amberInk : .secondary)
            }
            Text(s.swapUsed.memoryText).numeral(24).foregroundStyle(swapHeavy ? Brand.amberInk : .primary)
                .contentTransition(.numericText())
            UsageBar(segments: [.init(value: Double(s.swapUsed), color: swapHeavy ? Brand.amber : Brand.cyan)],
                     total: Double(max(s.swapTotal, s.swapUsed, 1)), height: 10)
            Text(s.swapTotal > 0 ? "\(s.swapTotal.memoryText) ayrılmış" : "Swap kullanılmıyor")
                .font(.caption).foregroundStyle(.secondary)
            Text(swapHeavy ? "Diskte yer kaplıyor ve erişimi yavaşlatıyor." : "Makul düzeyde.")
                .font(.caption).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }

    // MARK: Apps

    private var topApps: some View {
        let apps = Array(s.apps.prefix(15))
        let maxFootprint = Double(apps.first?.footprint ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "En çok bellek kullananlar", subtitle: "Yardımcı işlemler ait oldukları uygulamada toplanır")
            VStack(spacing: 0) {
                ForEach(Array(apps.enumerated()), id: \.element.id) { i, app in
                    AppMemoryRow(app: app, maxFootprint: maxFootprint)
                    if i < apps.count - 1 { Divider().padding(.leading, 44) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// Point at the app whose closing would help most, instead of a fake "free RAM" button.
    private var advice: String? {
        guard s.pressure != .normal || swapHeavy else { return nil }
        let quittable = s.apps.filter { state.memory.canQuit($0) }.prefix(2)
        guard !quittable.isEmpty else { return nil }
        let names = quittable.map { "\($0.name) (\($0.footprint.memoryText))" }.joined(separator: " ve ")
        let gain = quittable.reduce(0) { $0 + $1.footprint }
        let reason = s.pressure == .normal
            ? "Swap'te \(s.swapUsed.memoryText) var; bu hem yavaşlatır hem diskte yer kaplar."
            : "Bellek sıkışık ve swap'e yazılıyor."
        return "\(reason) \(names) kapatılırsa yaklaşık \(gain.memoryText) boşalır."
    }
}

struct AppMemoryRow: View {
    @Environment(AppState.self) private var state
    let app: AppMemory
    let maxFootprint: Double
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let bundle = app.bundlePath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: bundle)).resizable().frame(width: 26, height: 26)
            } else {
                IconTile(symbol: "terminal", tint: .secondary, size: 26)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(app.name).font(.callout.weight(.medium)).lineLimit(1)
                    if app.processCount > 1 {
                        Text("\(app.processCount) işlem").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(app.footprint.memoryText).font(.callout.weight(.semibold).monospacedDigit()).fixedSize()
                }
                UsageBar(segments: [.init(value: Double(app.footprint), color: Brand.cyan)], total: maxFootprint, height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Kapat") { state.memory.quit(app) }
                .controlSize(.small)
                .opacity(state.memory.canQuit(app) && hovering ? 1 : 0)
                .disabled(!state.memory.canQuit(app))
                .frame(width: 56)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(hovering ? 0.05 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
