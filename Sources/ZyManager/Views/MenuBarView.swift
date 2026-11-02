import SwiftUI

struct MenuBarLabel: View {
    let snapshot: MemorySnapshot

    var body: some View {
        let symbol = switch snapshot.pressure {
        case .normal: "memorychip"
        case .warning: "memorychip.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
        Image(systemName: symbol)
        Text("swap \(snapshot.swapUsed.memoryText)")
    }
}

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    private var s: MemorySnapshot { state.memory.snapshot }
    private var swapHeavy: Bool { s.swapUsed > s.physical / 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pressure header, tinted by state.
            HStack(spacing: 10) {
                Image(systemName: s.pressure.symbol)
                    .font(.title3)
                    .foregroundStyle(s.pressure.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bellek basıncı \(s.pressure.title.lowercased())").font(.headline)
                    Text("\(s.used.memoryText) / \(s.physical.memoryText) kullanımda")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(s.pressure.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            UsageBar(segments: [
                .init(value: Double(s.appMemory), color: Brand.cyan),
                .init(value: Double(s.wired), color: Brand.violet.opacity(0.9)),
                .init(value: Double(s.compressed), color: Brand.amber),
            ], total: Double(s.physical), height: 8)

            VStack(spacing: 6) {
                row("Swap", s.swapUsed.memoryText, tint: swapHeavy ? Brand.amberInk : .primary)
                if let v = state.volume {
                    row("Disk boş", v.available.fileSizeText, tint: .primary)
                }
                if state.caches.hasScanned {
                    row("Kazanılabilir", (state.caches.safeSize + state.projects.staleSize(olderThan: 30)).fileSizeText, tint: Brand.tealInk)
                }
            }

            Divider()

            Text("En çok bellek kullananlar").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            let apps = Array(s.apps.prefix(5))
            let maxFootprint = Double(apps.first?.footprint ?? 1)
            VStack(spacing: 7) {
                ForEach(apps) { app in
                    VStack(spacing: 3) {
                        HStack {
                            Text(app.name).font(.callout).lineLimit(1)
                            Spacer()
                            Text(app.footprint.memoryText).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        UsageBar(segments: [.init(value: Double(app.footprint), color: Brand.cyan.opacity(0.8))],
                                 total: maxFootprint, height: 3)
                    }
                }
            }

            Divider()
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("ZyManager'ı aç", systemImage: "macwindow")
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .controlSize(.small)
                Spacer()
                Button("Çık") { NSApp.terminate(nil) }.controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { state.refreshVolume() }
    }

    private func row(_ title: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(title).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.weight(.medium).monospacedDigit()).foregroundStyle(tint)
        }
    }
}
