import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac): Docs as a table, the same as Tasks (Phase 5.5): search, sort and group in the toolbar; a labels row;
/// optional group rows (by channel or by when it changed); one-line documents with a tick box, title (and any unsaved
/// edits), Channel, Updated and •••. Ticked documents can be archived together. Tower's summary is the start of the body
/// (Markdown, tables), so it isn't shown. Documents have no status or shared order, so there is no drag; Export,
/// Versioning and Move need the open document and stay on its screen.
struct MacDocList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.pushRoute) private var pushRoute
    let workspace: WorkspaceRecord
    let snapshot: DocsSnapshot
    let search: String
    let sort: MacDocSort
    let grouping: MacDocGrouping
    @Binding var sortBinding: MacDocSort
    @Binding var selected: Set<String>
    /// Archive asks first.
    let archive: ([DocRecord]) -> Void
    @AppStorage("docs.list.collapsed.v1") private var collapsedList = ""

    private var showsChannel: Bool { model.context.channelId == nil }
    private var canChange: Bool { model.isUnlocked }
    /// Titles sit past a group's name; with no groups, just clear of the tick box.
    private var titleIndent: CGFloat { grouping == .none ? Amb.Space.l : AmbTable.titleIndent }

    /// The table's width, measured: Channel then Updated give way so the title keeps its room in a narrow window.
    @State private var width: CGFloat = 0
    private enum Column: Hashable { case channel, updated }
    private var columns: Set<Column> {
        var all: [(Column, CGFloat)] = []
        if showsChannel { all.append((.channel, Amb.ListLayout.placeColumn)) }
        all.append((.updated, Amb.ListLayout.timeColumn))
        return AmbTable.fitting(all, dropOrder: [.channel, .updated], width: width, titleIndent: titleIndent)
    }

    var body: some View {
        VStack(spacing: 0) {
            columnLabels
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.creating) { item in
                        HStack(spacing: Amb.ListLayout.rowGap) {
                            Text(item.string("title") ?? "Document").font(.amb(.body)).lineLimit(1)
                            Spacer(minLength: 0)
                            WriteStatusLine(item: item, label: "New document")
                        }
                        .padding(.leading, AmbTable.gutter).padding(.trailing, Amb.ListLayout.trailing)
                        .frame(minHeight: Amb.ListLayout.rowHeight)
                        .modifier(AmbTableRule())
                    }
                    ForEach(groups) { group in
                        if grouping != .none {
                            AmbTableGroupRow(id: group.id, title: group.title, count: group.docs.count, closed: collapsed.contains(key(group)),
                                             toggle: { toggle(group) }) { group.mark }
                        }
                        if grouping == .none || !collapsed.contains(key(group)) {
                            ForEach(group.docs) { doc in
                                docRow(doc).modifier(AmbTableRule(selected: selected.contains(doc.id)))
                            }
                        }
                    }
                    if groups.isEmpty, !search.isEmpty {
                        Text("No documents match “\(search)”.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(.bottom, selected.isEmpty ? Amb.Space.xl : 88)
            }
        }
        .overlay(alignment: .bottom) {
            if !selected.isEmpty {
                AmbBulkBar(count: selected.count, identifier: "docs.bulk", clear: { selected.removeAll() }) {
                    Button { archive(snapshot.docs.filter { selected.contains($0.id) }) } label: { Label("Archive", systemImage: "archivebox").fixedSize() }
                        .buttonStyle(.ambGhost).accessibilityIdentifier("docs.bulk.archive")
                }
                .padding(.bottom, Amb.Space.l).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: selected.isEmpty)
        .onKeyPress(.escape) { selected.removeAll(); return .handled }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .clipped()
    }

    // MARK: Columns

    private var columnLabels: some View {
        let docs = groups.flatMap(\.docs)
        let ticked = docs.filter { selected.contains($0.id) }.count
        return HStack(spacing: Amb.ListLayout.rowGap) {
            HStack(spacing: 0) {
                AmbTableCheckbox(state: ticked == 0 ? .off : ticked == docs.count ? .on : .mixed, label: "Select all documents") {
                    if ticked == docs.count { selected.subtract(docs.map(\.id)) } else { selected.formUnion(docs.map(\.id)) }
                }
                .disabled(docs.isEmpty || !canChange)
                .accessibilityIdentifier("docs.selectAll")
                Color.clear.frame(width: titleIndent, height: 1)
                sortLabel("Title", .title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if columns.contains(.channel) { Text("Channel").frame(width: Amb.ListLayout.placeColumn, alignment: .leading) }
            if columns.contains(.updated) {
                HStack(spacing: 0) { Spacer(minLength: 0); sortLabel("Updated", .updated) }.frame(width: Amb.ListLayout.timeColumn)
            }
            Color.clear.frame(width: Amb.ListLayout.actionColumn, height: 1)
        }
        .font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.mutedForeground)
        .padding(.leading, AmbTable.gutter).padding(.trailing, Amb.ListLayout.trailing)
        .frame(height: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 1) }
    }

    private func sortLabel(_ title: String, _ value: MacDocSort) -> some View {
        Button { sortBinding = value } label: {
            HStack(spacing: 3) {
                Text(title)
                if sort == value { Image(systemName: value == .title ? "arrow.up" : "arrow.down").font(.amb(.caption2)) }
            }
            .foregroundStyle(sort == value ? Amb.foreground : Amb.mutedForeground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ambTooltip("Sort by \(title.lowercased())")
        .accessibilityIdentifier("docs.sort.\(value.rawValue)")
    }

    // MARK: Groups

    private var groups: [MacDocGroup] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let docs = (q.isEmpty ? snapshot.docs : snapshot.docs.filter { $0.title.lowercased().contains(q) })
            .sorted(by: ordered)
        guard !docs.isEmpty else { return [] }
        switch grouping {
        case .none:
            return [MacDocGroup(id: "all", title: "All", docs: docs, mark: AnyView(EmptyView()))]
        case .channel:
            let byChannel = Dictionary(grouping: docs, by: \.channelId)
            return byChannel.keys.sorted { (snapshot.choice.channelName($0) ?? "") < (snapshot.choice.channelName($1) ?? "") }.map { id in
                MacDocGroup(id: id, title: snapshot.choice.channelName(id) ?? "Channel", docs: byChannel[id] ?? [],
                            mark: AnyView(Text("#").font(.amb(.subheadline)).foregroundStyle(Amb.faint)))
            }
        case .updated:
            let calendar = Calendar.current, now = Date()
            func bucket(_ doc: DocRecord) -> Int {
                guard let date = ChatTime.date(doc.updatedAt) else { return 2 }
                if calendar.isDateInToday(date) { return 0 }
                return now.timeIntervalSince(date) < 7 * 86_400 ? 1 : 2
            }
            let byBucket = Dictionary(grouping: docs, by: bucket)
            return [(0, "Today"), (1, "This week"), (2, "Earlier")].compactMap { index, title in
                guard let docs = byBucket[index], !docs.isEmpty else { return nil }
                return MacDocGroup(id: "\(index)", title: title, docs: docs,
                                   mark: AnyView(Image(systemName: "clock").font(.amb(.caption)).foregroundStyle(Amb.faint)))
            }
        }
    }

    private func ordered(_ a: DocRecord, _ b: DocRecord) -> Bool {
        switch sort {
        case .updated: a.updatedAt > b.updatedAt
        case .title: a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    private var collapsed: Set<String> { Set(collapsedList.split(separator: ",").map(String.init)) }
    private func key(_ group: MacDocGroup) -> String { "\(grouping.rawValue):\(group.id)" }
    private func toggle(_ group: MacDocGroup) {
        var set = collapsed
        if set.contains(key(group)) { set.remove(key(group)) } else { set.insert(key(group)) }
        collapsedList = set.sorted().joined(separator: ",")
    }

    // MARK: Rows

    private func docRow(_ doc: DocRecord) -> some View {
        let ticked = selected.contains(doc.id)
        return HStack(spacing: 0) {
            Color.clear.frame(width: AmbTable.gutter, height: 1)
            AmbTableCheckbox(state: ticked ? .on : .off, label: "Select \(doc.title)") {
                if ticked { selected.remove(doc.id) } else { selected.insert(doc.id) }
            }
            .disabled(!canChange)
            .accessibilityIdentifier("doc.select.\(doc.title)")
            Color.clear.frame(width: titleIndent, height: 1)
            HStack(spacing: Amb.ListLayout.rowGap) {
                WorkRecordLink(route: WorkRoute.doc(workspaceId: workspace.id, docId: doc.id)) {
                    HStack(spacing: Amb.ListLayout.rowGap) {
                        title(doc).frame(maxWidth: .infinity, alignment: .leading)
                        if columns.contains(.channel) {
                            Text(snapshot.choice.channelName(doc.channelId).map { "#\($0)" } ?? "")
                                .lineLimit(1).frame(width: Amb.ListLayout.placeColumn, alignment: .leading)
                        }
                        if columns.contains(.updated) {
                            HStack(spacing: 0) { Spacer(minLength: 0); MessageTimeText(iso: doc.updatedAt) }.frame(width: Amb.ListLayout.timeColumn)
                        }
                    }
                    .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                }
                .accessibilityIdentifier("doc.\(doc.title)")
                NativeMessageActions(items: actions(doc), identifier: "doc.actions.\(doc.title)", label: "Document actions", help: "More actions")
                    .frame(width: Amb.ListLayout.actionColumn, height: 24)
                    .ambRevealOnHover()
            }
        }
        .padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .contextMenu { AmbTableMenuItems(items: actions(doc)) }
    }

    private func title(_ doc: DocRecord) -> some View {
        HStack(spacing: Amb.Space.s) {
            Image(systemName: "doc.text").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).accessibilityHidden(true)
            Text(doc.title).font(.amb(.body)).foregroundStyle(Amb.foreground).lineLimit(1)
            if snapshot.drafts.contains(doc.id) {
                Text("Unsaved edits").font(.amb(.caption).weight(.medium)).foregroundStyle(Amb.warning)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Amb.warningBackground, in: Capsule())
                    .fixedSize()
            }
        }
    }

    /// One document's ••• and right-click menu: what can be done without opening it.
    private func actions(_ doc: DocRecord) -> [NativeMessageAction] {
        var items = [
            NativeMessageAction("Open", "arrow.up.right.square") { pushRoute(WorkRoute.doc(workspaceId: workspace.id, docId: doc.id)) },
            NativeMessageAction("Copy reference", "link") { Pasteboard.copy(DocumentActionText.reference(title: doc.title, docId: doc.id)) },
            model.pinAction(.document, doc.id, in: workspace),
        ]
        guard canChange else { return items }
        items += [
            NativeMessageAction(selected.contains(doc.id) ? "Deselect" : "Select", "checkmark.square") {
                if selected.contains(doc.id) { selected.remove(doc.id) } else { selected.insert(doc.id) }
            },
            NativeMessageAction("Archive…", "archivebox") { archive([doc]) },
        ]
        return items
    }
}

struct MacDocGroup: Identifiable {
    let id: String
    let title: String
    let docs: [DocRecord]
    let mark: AnyView
}

enum MacDocSort: String, CaseIterable {
    case updated, title
    var label: String { self == .updated ? "Updated" : "Title" }
}

enum MacDocGrouping: String, CaseIterable {
    case none, channel, updated
    var label: String {
        switch self {
        case .none: "None"
        case .channel: "Channel"
        case .updated: "Updated"
        }
    }
}

/// The Docs toolbar: search, sort and group, as Tasks'.
struct MacDocListControls: View {
    @Binding var search: String
    @Binding var sort: MacDocSort
    @Binding var grouping: MacDocGrouping

    var body: some View {
        // In a narrow window the search field shrinks and Sort and Group become icons.
        controls(search: 240, compact: false)
    }

    private func controls(search width: CGFloat, compact: Bool) -> some View {
        HStack(spacing: Amb.Space.m) {
            AmbTableSearchField(prompt: "Search docs", text: $search, identifier: "docs.search", width: width)
            AmbTableToolbarMenu(symbol: "arrow.up.arrow.down", title: "Sort", values: MacDocSort.allCases, label: \.label,
                                selection: $sort, identifier: "docs.sort", compact: compact)
            AmbTableToolbarMenu(symbol: "rectangle.grid.1x2", title: "Group", values: MacDocGrouping.allCases, label: \.label,
                                selection: $grouping, identifier: "docs.group", compact: compact)
        }
    }
}
#endif
