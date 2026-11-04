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
                TableColumn(L("Proje", "Project"), value: \.projectName) { a in
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
                TableColumn(L("Klasör", "Folder"), value: \.kind.rawValue) { a in
                    HStack(spacing: 5) {
                        Chip(text: a.kind.rawValue, tint: a.kind.tint, symbol: a.kind.symbol)
                        if a.kind.safety == .caution { SafetyBadge(safety: .caution) }
                    }
                }
                .width(min: 135, ideal: 150)
                TableColumn(L("Son değişiklik", "Last modified"), value: \.activitySortKey) { a in
                    let stale = (a.lastActivity ?? .distantPast) < staleCutoff
                    HStack(spacing: 4) {
                        if stale { Image(systemName: "clock").font(.caption2) }
                        Text(a.lastActivity?.relativeText ?? L("bilinmiyor", "unknown")).lineLimit(1)
                    }
                    .foregroundStyle(stale ? Brand.amberInk : .secondary)
                    .font(stale ? .body.weight(.medium) : .body)
                }
                .width(min: 90, ideal: 105)
                TableColumn(L("Geri getirme", "Restore with"), value: \.kind.restoreHint) { a in
                    Text(a.kind.restoreHint).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .help(a.kind.restoreHint)
                }
                .width(min: 85, ideal: 105)
                TableColumn(L("Boyut", "Size"), value: \.size) { a in
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
                Button(L("Finder'da göster", "Show in Finder")) {
                    revealInFinder(projects.artifacts.filter { ids.contains($0.id) }.map(\.url))
                }
            }
            .overlay {
                if projects.isScanning && !projects.hasScanned {
                    ScanningPlaceholder(text: L("Projeler taranıyor…", "Scanning projects…"), symbol: "folder")
                        .background(.background)
                } else if projects.hasScanned && projects.artifacts.isEmpty {
                    ContentUnavailableView(L("Bağımlılık klasörü bulunamadı", "No dependency folders found"), systemImage: "folder",
                                           description: Text(L("Taranan klasörlerde node_modules, .dart_tool, Pods gibi yeniden üretilebilir klasör yok.",
                                                                "The scanned folders contain no regenerable folders such as node_modules, .dart_tool or Pods.")))
                } else if projects.hasScanned && rows.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }

            ActionBar {
                Picker("", selection: $staleDays) {
                    Text(L("7 gün", "7 days")).tag(7)
                    Text(L("30 gün", "30 days")).tag(30)
                    Text(L("90 gün", "90 days")).tag(90)
                }
                .labelsHidden()
                .fixedSize()
                Button {
                    projects.selectStale(olderThan: staleDays)
                } label: {
                    Label(L("Eskileri seç (\(projects.staleSize(olderThan: staleDays).fileSizeText))", "Select old (\(projects.staleSize(olderThan: staleDays).fileSizeText))"), systemImage: "clock")
                }
                .help(L("\(staleDays) gündür dokunulmamış projelerin güvenli klasörlerini seçer", "Selects the safe folders of projects untouched for \(staleDays) days"))
            } trailing: {
                if projects.isCleaning { ProgressView().controlSize(.small) }
                if projects.selection.isEmpty {
                    Text(L("Seçim yok", "Nothing selected")).foregroundStyle(.tertiary)
                } else {
                    Text(L("\(projects.selection.count) klasör · ", projects.selection.count == 1 ? "1 folder · " : "\(projects.selection.count) folders · ")).foregroundStyle(.secondary)
                    + Text(projects.selectedSize.fileSizeText).fontWeight(.semibold).foregroundStyle(.primary)
                }
                Button {
                    confirming = true
                } label: {
                    Label(L("Temizle…", "Clean…"), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.cyan)
                .disabled(projects.selection.isEmpty || projects.isCleaning)
            }
        }
        .navigationTitle(L("Projeler", "Projects"))
        .searchable(text: $query, placement: .toolbar, prompt: L("Proje veya klasör ara", "Search projects or folders"))
        .navigationSubtitle(projects.hasScanned ? L("\(projects.artifacts.count) klasör · \(projects.totalSize.fileSizeText)",
                                                                  "\(projects.artifacts.count == 1 ? "1 folder" : "\(projects.artifacts.count) folders") · \(projects.totalSize.fileSizeText)")
                                                 : L("taranıyor…", "scanning…"))
        .toolbar {
            Button {
                Task { await projects.scan() }
            } label: {
                if projects.isScanning { ProgressView().controlSize(.small) } else { Label(L("Yeniden tara", "Rescan"), systemImage: "arrow.clockwise") }
            }
            .disabled(projects.isScanning)
            .help(L("Yeniden tara", "Rescan"))
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
                Text(L("Taranan klasörler", "Scanned folders")).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(projects.roots, id: \.self) { root in
                            HStack(spacing: 5) {
                                Text(root.tildePath).font(.callout)
                                Button { projects.roots.removeAll { $0 == root } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.borderless)
                                .help(L("Taramadan çıkar", "Remove from scan"))
                            }
                            .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                    }
                }
                Button { projects.addRoot() } label: { Label(L("Klasör ekle", "Add folder"), systemImage: "plus") }
            }
            if projects.hasScanned, !projects.artifacts.isEmpty {
                HStack(spacing: 16) {
                    summary("folder.fill", L("\(projects.artifacts.count) klasör", projects.artifacts.count == 1 ? "1 folder" : "\(projects.artifacts.count) folders"), Brand.cyan)
                    summary("internaldrive.fill", L("\(projects.totalSize.fileSizeText) toplam", "\(projects.totalSize.fileSizeText) total"), Brand.cyan)
                    summary("clock", L("\(projects.staleSize(olderThan: staleDays).fileSizeText) · \(staleDays)+ gündür dokunulmamış", "\(projects.staleSize(olderThan: staleDays).fileSizeText) · untouched for \(staleDays)+ days"), Brand.amberInk)
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
