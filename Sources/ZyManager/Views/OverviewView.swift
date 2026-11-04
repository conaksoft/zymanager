import SwiftUI

struct OverviewView: View {
    @Environment(AppState.self) private var state
    @Binding var section: SidebarSection?
    @State private var confirming = false

    private var isScanning: Bool { state.caches.isScanning || state.projects.isScanning || state.apps.isScanning }
    private var staleProjects: Int64 { state.projects.staleSize(olderThan: 30) }
    /// What a single click can get back without losing anything: safe caches plus stale project folders.
    private var reclaimable: Int64 { state.caches.safeSize + staleProjects }

    var body: some View {
        @Bindable var caches = state.caches

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                tiles
                HStack(alignment: .top, spacing: 16) {
                    breakdown
                    biggest
                }
            }
            .padding(22)
        }
        .navigationTitle(L("Genel Bakış", "Overview"))
        .toolbar {
            Button {
                Task { await state.scanAll() }
            } label: {
                if isScanning { ProgressView().controlSize(.small) } else { Label(L("Yeniden tara", "Rescan"), systemImage: "arrow.clockwise") }
            }
            .disabled(isScanning)
            .help(L("Yeniden tara", "Rescan"))
        }
        .sheet(isPresented: $confirming) {
            CleanupConfirmation(lines: caches.selectedEntries.map {
                .init(id: $0.id, title: $0.item.name,
                      subtitle: $0.item.command != nil ? L("Komut: ", "Command: ") + "\($0.item.command!.arguments.joined(separator: " "))"
                                                      : $0.urls.map(\.tildePath).joined(separator: ", "),
                      size: $0.size, safety: $0.item.safety)
            }) { toTrash in
                Task { await caches.cleanSelected(toTrash: toTrash); state.refreshVolume() }
            }
        }
        .resultBanner($caches.lastMessage)
    }

    // MARK: Hero

    private var hero: some View {
        let v = state.volume
        let total = Double(v?.total ?? 1)
        let other = Double(max(0, (v?.used ?? 0) - state.caches.totalSize - state.projects.totalSize))
        let free = Double(v?.available ?? 0)
        let lowDisk = v.map { Double($0.available) / Double($0.total) < 0.1 } ?? false

        return HStack(spacing: 26) {
            RingGauge(segments: [
                .init(value: other, color: .white.opacity(0.22)),
                .init(value: Double(state.caches.totalSize), color: Brand.amber),
                .init(value: Double(state.projects.totalSize), color: Brand.cyan),
                .init(value: free, color: Brand.teal),
            ], total: total, lineWidth: 16, track: .white.opacity(0.08)) {
                VStack(spacing: 2) {
                    Text(v.map { Int((Double($0.available) / Double($0.total)) * 100) } ?? 0, format: .percent.locale(AppLanguage.locale))
                        .numeral(28).foregroundStyle(.white)
                    Text(L("boş", "free")).font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 148, height: 148)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill").font(.caption)
                    Text("Macintosh HD").font(.caption.weight(.semibold))
                    Text("·").font(.caption)
                    Text(L("\(v?.available.fileSizeText ?? "—") boş / \(v?.total.fileSizeText ?? "—")",
                            "\(v?.available.fileSizeText ?? "—") free of \(v?.total.fileSizeText ?? "—")"))
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.white.opacity(0.75))

                if state.caches.hasScanned {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(reclaimable.fileSizeText).numeral(38).foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text(L("kazanılabilir", "can be freed")).font(.title3.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    Text(L("Güvenle temizlenebilir önbellek \(state.caches.safeSize.fileSizeText) · 30+ gündür dokunulmamış proje bağımlılıkları \(staleProjects.fileSizeText)",
                            "Caches safe to clean \(state.caches.safeSize.fileSizeText) · Project dependencies untouched for 30+ days \(staleProjects.fileSizeText)"))
                        .font(.callout).foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text(L("Önbellekler ve projeler taranıyor…", "Scanning caches and projects…")).font(.title3.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(height: 46)
                    Text(L("Diskteki geliştirici önbellekleri ve bağımlılık klasörleri ölçülüyor.", "Measuring developer caches and dependency folders on disk."))
                        .font(.callout).foregroundStyle(.white.opacity(0.6))
                }

                HStack(spacing: 10) {
                    Button {
                        state.caches.selectAllSafe()
                        confirming = true
                    } label: {
                        Label(L("Güvenlileri temizle…", "Clean safe items…"), systemImage: "sparkles")
                    }
                    .buttonStyle(HeroButtonStyle())
                    .disabled(state.caches.safeSize == 0 || state.caches.isCleaning)
                    .opacity(state.caches.safeSize == 0 ? 0.5 : 1)

                    Button(L("Ayrıntılar", "Details")) { section = .caches }
                        .buttonStyle(HeroSecondaryButtonStyle())
                }
                .padding(.top, 2)

                HStack(spacing: 14) {
                    heroLegend(.white.opacity(0.35), L("Diğer", "Other"))
                    heroLegend(Brand.amber, L("Geliştirici önbellekleri", "Developer caches"))
                    heroLegend(Brand.cyan, L("Proje bağımlılıkları", "Project dependencies"))
                    heroLegend(Brand.teal, L("Boş", "Free"))
                }
                .padding(.top, 4)

                if lowDisk {
                    Label(L("Disk %90'dan fazla dolu. macOS'un swap ve güncellemeler için boş alana ihtiyacı var.",
                            "The disk is more than 90% full. macOS needs free space for swap and updates."),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(Brand.amber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            shape.fill(Brand.hero)
                // Soft accent glows in the corners; overlays don't change the card's size.
                .overlay(alignment: .topTrailing) {
                    Circle().fill(Brand.teal.opacity(0.30)).frame(width: 320, height: 320).blur(radius: 80)
                        .offset(x: 110, y: -140)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle().fill(Brand.cyan.opacity(0.22)).frame(width: 260, height: 260).blur(radius: 70)
                        .offset(x: -90, y: 110)
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
        }
        .shadow(color: Brand.indigo.opacity(0.25), radius: 18, y: 8)
        .animation(.easeOut(duration: 0.5), value: state.caches.hasScanned)
    }

    private func heroLegend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.75))
        }
        .fixedSize()
    }

    // MARK: Tiles

    private var tiles: some View {
        let m = state.memory.snapshot
        return HStack(spacing: 12) {
            StatTile(symbol: "archivebox.fill", title: L("Güvenli önbellekler", "Safe caches"),
                     value: state.caches.hasScanned ? state.caches.safeSize.fileSizeText : "…",
                     caption: state.caches.hasScanned ? L("toplam bulunan \(state.caches.totalSize.fileSizeText)", "\(state.caches.totalSize.fileSizeText) found in total") : L("taranıyor", "scanning"),
                     tint: Brand.amber) { section = .caches }
            StatTile(symbol: "folder.fill", title: L("Eski bağımlılıklar", "Old dependencies"),
                     value: state.projects.hasScanned ? staleProjects.fileSizeText : "…",
                     caption: state.projects.hasScanned ? L("30+ gün · toplam \(state.projects.totalSize.fileSizeText)", "30+ days · \(state.projects.totalSize.fileSizeText) total") : L("projeler taranıyor", "scanning projects"),
                     tint: Brand.cyan) { section = .projects }
            StatTile(symbol: "square.grid.2x2.fill", title: L("Atıl uygulamalar", "Unused apps"),
                     value: state.apps.hasScanned ? "\(state.apps.unused(olderThan: 90).count)" : "…",
                     caption: state.apps.hasScanned
                        ? L("90+ gündür açılmamış · \(state.apps.unusedSize(olderThan: 90).fileSizeText)", "Unused 90+ days · \(state.apps.unusedSize(olderThan: 90).fileSizeText)")
                        : L("uygulamalar taranıyor", "scanning apps"),
                     tint: Brand.violetInk) { section = .apps }
            StatTile(symbol: m.pressure.symbol, title: L("Bellek basıncı", "Memory pressure"),
                     value: m.pressure.title,
                     caption: "swap \(m.swapUsed.memoryText) · RAM \(m.used.memoryText)",
                     tint: m.pressure.color) { section = .memory }
        }
    }

    // MARK: Breakdown

    private var breakdown: some View {
        let rows = Ecosystem.allCases
            .map { ($0, state.caches.entries(in: $0).reduce(0) { $0 + $1.size }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let max = Double(rows.first?.1 ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L("Ekosisteme göre", "By ecosystem"), subtitle: L("Önbellekler, araç ailesine göre", "Caches by tool family"))
            if !state.caches.hasScanned {
                ScanningPlaceholder(text: L("Taranıyor…", "Scanning…"), symbol: "archivebox").frame(height: 180)
            } else if rows.isEmpty {
                ContentUnavailableView(L("Önbellek bulunamadı", "No caches found"), systemImage: "checkmark.circle",
                                       description: Text(L("Hiçbir geliştirici önbelleği 1 MB'ı geçmiyor.", "No developer cache is larger than 1 MB.")))
                    .frame(height: 180)
            } else {
                ForEach(rows, id: \.0) { eco, size in
                    MeterRow(symbol: eco.symbol, tint: eco.tint, title: eco.title,
                             value: Double(size), total: max, valueText: size.fileSizeText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Biggest items

    private var biggest: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                SectionTitle(title: L("En çok yer kaplayanlar", "Largest items"), subtitle: L("Tek tek en büyük önbellekler", "The biggest individual caches"))
                Spacer()
                Button(L("Tümü", "All")) { section = .caches }.buttonStyle(.link).font(.callout)
            }
            if !state.caches.hasScanned {
                ScanningPlaceholder(text: L("Taranıyor…", "Scanning…"), symbol: "internaldrive").frame(height: 180)
            } else {
                VStack(spacing: 0) {
                    let top = Array(state.caches.found.sorted { $0.size > $1.size }.prefix(7))
                    ForEach(Array(top.enumerated()), id: \.element.id) { i, entry in
                        HStack(spacing: 10) {
                            IconTile(symbol: entry.item.ecosystem.symbol, tint: entry.item.ecosystem.tint, size: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.item.name).font(.callout.weight(.medium)).lineLimit(1)
                                Text(entry.item.ecosystem.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if entry.item.safety == .caution { SafetyBadge(safety: .caution) }
                            Text(entry.size.fileSizeText).font(.callout.weight(.semibold).monospacedDigit()).fixedSize()
                        }
                        .padding(.vertical, 7)
                        if i < top.count - 1 { Divider() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
