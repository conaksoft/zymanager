import SwiftUI

struct ProjectsView: View {
    @Environment(AppState.self) private var state
    @State private var confirming = false
    @AppStorage("projectStaleDays") private var staleDays = 30
    @State private var sortOrder = [KeyPathComparator(\ProjectArtifact.size, order: .reverse)]
    @State private var query = ""

    private var visible: [ProjectArtifact] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return state.projects.artifacts }
        return state.projects.artifacts.filter {
            $0.projectName.localizedCaseInsensitiveContains(q) || $0.url.tildePath.localizedCaseInsensitiveContains(q)
                || $0.kind.rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        @Bindable var projects = state.projects
        let staleCutoff = Date().addingTimeInterval(-Double(staleDays) * 86_400)
        let maxSize = Double(projects.artifacts.map(\.size).max() ?? 1)
        let rows = visible

        VStack(spacing: 0) {
            header
            Divider()
            Table(rows.sorted(using: sortOrder), selection: $projects.selection, sortOrder: $sortOrder) {
                TableColumn("Proje", value: \.projectName) { a in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill").foregroundStyle(a.kind.tint).font(.callout)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.projectName).fontWeight(.medium)
                            Text(a.projectURL.tildePath).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .width(min: 140)
                TableColumn("Klasör", value: \.kind.rawValue) { a in
                    HStack(spacing: 5) {
                        Chip(text: a.kind.rawValue, tint: a.kind.tint, symbol: a.kind.symbol)
                        if a.kind.safety == .caution { SafetyBadge(safety: .caution) }
                    }
                }
                .width(min: 135, ideal: 150)
                TableColumn("Son değişiklik", value: \.activitySortKey) { a in
                    let stale = (a.lastActivity ?? .distantPast) < staleCutoff
                    HStack(spacing: 4) {
                        if stale { Image(systemName: "clock").font(.caption2) }
                        Text(a.lastActivity?.relativeText ?? "bilinmiyor").lineLimit(1)
                    }
                    .foregroundStyle(stale ? Brand.amberInk : .secondary)
                    .font(stale ? .body.weight(.medium) : .body)
                }
                .width(min: 90, ideal: 105)
                TableColumn("Geri getirme", value: \.kind.restoreHint) { a in
                    Text(a.kind.restoreHint).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .help(a.kind.restoreHint)
                }
                .width(min: 85, ideal: 105)
                TableColumn("Boyut", value: \.size) { a in
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(a.size.fileSizeText).font(.body.weight(.semibold).monospacedDigit()).lineLimit(1)
                        UsageBar(segments: [.init(value: Double(a.size), color: a.kind.tint)], total: maxSize, height: 3)
                            .frame(width: 50)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 72, ideal: 80)
            }
            .contextMenu(forSelectionType: String.self) { ids in
                Button("Finder'da göster") {
                    revealInFinder(projects.artifacts.filter { ids.contains($0.id) }.map(\.url))
                }
            }
            .overlay {
                if projects.isScanning && !projects.hasScanned {
                    ScanningPlaceholder(text: "Projeler taranıyor…", symbol: "folder")
                        .background(.background)
                } else if projects.hasScanned && projects.artifacts.isEmpty {
                    ContentUnavailableView("Bağımlılık klasörü bulunamadı", systemImage: "folder",
                                           description: Text("Taranan klasörlerde node_modules, .dart_tool, Pods gibi yeniden üretilebilir klasör yok."))
                } else if projects.hasScanned && rows.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }

            ActionBar {
                Picker("", selection: $staleDays) {
                    Text("7 gün").tag(7)
                    Text("30 gün").tag(30)
                    Text("90 gün").tag(90)
                }
                .labelsHidden()
                .fixedSize()
                Button {
                    projects.selectStale(olderThan: staleDays)
                } label: {
                    Label("Eskileri seç (\(projects.staleSize(olderThan: staleDays).fileSizeText))", systemImage: "clock")
                }
                .help("\(staleDays) gündür dokunulmamış projelerin güvenli klasörlerini seçer")
            } trailing: {
                if projects.isCleaning { ProgressView().controlSize(.small) }
                if projects.selection.isEmpty {
                    Text("Seçim yok").foregroundStyle(.tertiary)
                } else {
                    Text("\(projects.selection.count) klasör · ").foregroundStyle(.secondary)
                    + Text(projects.selectedSize.fileSizeText).fontWeight(.semibold).foregroundStyle(.primary)
                }
                Button {
                    confirming = true
                } label: {
                    Label("Temizle…", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .disabled(projects.selection.isEmpty || projects.isCleaning)
            }
        }
        .navigationTitle("Projeler")
        .searchable(text: $query, placement: .toolbar, prompt: "Proje veya klasör ara")
        .navigationSubtitle(projects.hasScanned ? "\(projects.artifacts.count) klasör · \(projects.totalSize.fileSizeText)" : "taranıyor…")
        .toolbar {
            Button {
                Task { await projects.scan() }
            } label: {
                if projects.isScanning { ProgressView().controlSize(.small) } else { Label("Yeniden tara", systemImage: "arrow.clockwise") }
            }
            .disabled(projects.isScanning)
            .help("Yeniden tara")
        }
        .sheet(isPresented: $confirming) {
            CleanupConfirmation(lines: projects.selectedArtifacts.map {
                .init(id: $0.id, title: "\($0.projectName) · \($0.kind.rawValue)", subtitle: $0.url.tildePath,
                      size: $0.size, safety: $0.kind.safety)
            }) { toTrash in
                Task { await projects.cleanSelected(toTrash: toTrash); state.refreshVolume() }
            }
        }
        .resultBanner($projects.lastMessage)
    }

    /// Scanned roots as removable chips, plus a quick summary of what was found.
    private var header: some View {
        @Bindable var projects = state.projects
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape").foregroundStyle(.secondary)
                Text("Taranan klasörler").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(projects.roots, id: \.self) { root in
                            HStack(spacing: 5) {
                                Text(root.tildePath).font(.callout)
                                Button { projects.roots.removeAll { $0 == root } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.borderless)
                                .help("Taramadan çıkar")
                            }
                            .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                    }
                }
                Button { projects.addRoot() } label: { Label("Klasör ekle", systemImage: "plus") }
            }
            if projects.hasScanned, !projects.artifacts.isEmpty {
                HStack(spacing: 16) {
                    summary("folder.fill", "\(projects.artifacts.count) klasör", Brand.cyan)
                    summary("internaldrive.fill", "\(projects.totalSize.fileSizeText) toplam", Brand.cyan)
                    summary("clock", "\(projects.staleSize(olderThan: staleDays).fileSizeText) · \(staleDays)+ gündür dokunulmamış", Brand.amberInk)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func summary(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(tint).font(.caption)
            Text(text).font(.caption.weight(.medium).monospacedDigit())
        }
        .fixedSize()
    }
}

extension ProjectArtifact {
    var activitySortKey: Date { lastActivity ?? .distantPast }
}
