import SwiftUI

struct CachesView: View {
    @Environment(AppState.self) private var state
    @State private var confirming = false
    @State private var query = ""

    /// Rows matching the search field; everything when it's empty.
    private func visible(_ eco: Ecosystem) -> [CacheStore.Entry] {
        let entries = state.caches.entries(in: eco)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.item.name.localizedCaseInsensitiveContains(q) || $0.item.detail.localizedCaseInsensitiveContains(q)
                || $0.urls.contains { $0.tildePath.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        @Bindable var caches = state.caches
        let groups = Ecosystem.allCases
            .map { ($0, visible($0)) }
            .filter { !$0.1.isEmpty }
            .sorted { $0.1.reduce(0) { $0 + $1.size } > $1.1.reduce(0) { $0 + $1.size } }

        VStack(spacing: 0) {
            Group {
                if caches.isScanning && !caches.hasScanned {
                    ScanningPlaceholder(text: L("Önbellekler taranıyor…", "Scanning caches…"), symbol: "archivebox")
                } else if caches.hasScanned && caches.found.isEmpty {
                    ContentUnavailableView(L("Önbellek bulunamadı", "No caches found"), systemImage: "checkmark.circle",
                                           description: Text(L("Hiçbir geliştirici önbelleği 1 MB'ı geçmiyor.", "No developer cache is larger than 1 MB.")))
                } else if groups.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            // Heaviest ecosystem first.
                            ForEach(groups, id: \.0) { eco, entries in
                                EcosystemCard(ecosystem: eco, entries: entries, grandTotal: caches.totalSize, selection: $caches.selection)
                            }
                        }
                        .padding(22)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ActionBar {
                Button(L("Güvenlileri seç", "Select safe items")) { caches.selectAllSafe() }
                Button(L("Seçimi kaldır", "Deselect all")) { caches.selection.removeAll() }.disabled(caches.selection.isEmpty)
            } trailing: {
                if caches.isCleaning { ProgressView().controlSize(.small) }
                if caches.selection.isEmpty {
                    Text(L("Seçim yok", "Nothing selected")).foregroundStyle(.tertiary)
                } else {
                    Text(L("\(caches.selection.count) öğe · ", caches.selection.count == 1 ? "1 item · " : "\(caches.selection.count) items · "))
                        .foregroundStyle(.secondary)
                    + Text(caches.selectedSize.fileSizeText).fontWeight(.semibold).foregroundStyle(.primary)
                }
                Button {
                    confirming = true
                } label: {
                    Label(L("Temizle…", "Clean…"), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .disabled(caches.selection.isEmpty || caches.isCleaning)
            }
        }
        .navigationTitle(L("Önbellekler", "Caches"))
        .searchable(text: $query, placement: .toolbar, prompt: L("Önbellek ara", "Search caches"))
        .navigationSubtitle(caches.hasScanned ? L("\(caches.found.count) öğe · \(caches.totalSize.fileSizeText)",
                                                              "\(caches.found.count == 1 ? "1 item" : "\(caches.found.count) items") · \(caches.totalSize.fileSizeText)")
                                               : L("taranıyor…", "scanning…"))
        .toolbar {
            Button {
                Task { await caches.scan(); state.refreshVolume() }
            } label: {
                if caches.isScanning { ProgressView().controlSize(.small) } else { Label(L("Yeniden tara", "Rescan"), systemImage: "arrow.clockwise") }
            }
            .disabled(caches.isScanning)
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
}

/// One ecosystem: header with icon, total and share bar, then its cache rows.
private struct EcosystemCard: View {
    let ecosystem: Ecosystem
    let entries: [CacheStore.Entry]
    let grandTotal: Int64
    @Binding var selection: Set<String>

    private var total: Int64 { entries.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { entries.filter { selection.contains($0.id) }.count }
    private var allSelected: Bool { selectedCount == entries.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { allSelected },
                    set: { on in
                        for e in entries { if on { selection.insert(e.id) } else { selection.remove(e.id) } }
                    }
                ))
                .labelsHidden().toggleStyle(.checkbox)
                .help(allSelected ? L("Bu gruptaki seçimi kaldır", "Deselect this group") : L("Bu gruptakilerin tümünü seç", "Select everything in this group"))

                IconTile(symbol: ecosystem.symbol, tint: ecosystem.tint, size: 30)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ecosystem.title).font(.headline)
                        Text(L("\(entries.count) öğe", entries.count == 1 ? "1 item" : "\(entries.count) items")).font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(total.fileSizeText).numeral(15, weight: .semibold)
                    }
                    UsageBar(segments: [.init(value: Double(total), color: ecosystem.tint)], total: Double(grandTotal), height: 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.leading, 14)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    CacheRow(entry: entry, isOn: Binding(
                        get: { selection.contains(entry.id) },
                        set: { on in if on { selection.insert(entry.id) } else { selection.remove(entry.id) } }
                    ))
                    if i < entries.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
        }
    }
}

private struct CacheRow: View {
    let entry: CacheStore.Entry
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(entry.item.name).font(.callout.weight(.medium))
                    SafetyBadge(safety: entry.item.safety)
                }
                Text(entry.item.detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.item.command != nil
                     ? L("Komut: ", "Command: ") + "\(entry.item.command!.arguments.joined(separator: " "))"
                     : entry.urls.map(\.tildePath).joined(separator: " · "))
                    .font(.caption.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                Text(entry.size.fileSizeText).numeral(15, weight: .semibold).fixedSize()
                Button { revealInFinder(entry.urls) } label: {
                    Label(L("Finder'da göster", "Show in Finder"), systemImage: "magnifyingglass").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(L("Finder'da göster", "Show in Finder"))
                .opacity(hovering ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
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
