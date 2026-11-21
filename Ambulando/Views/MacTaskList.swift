import AmbulandoCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
/// UX lab (Mac): Tasks as a table, laid out after gr8r-studio's task list (Phase 5.4, round 6). A toolbar (search, sort,
/// group), a row of column labels, then groups: a group row (fold chevron, mark, name, count, +) over its tasks, one
/// per line with Status, Assignee, Size, Channel and Updated in columns and ••• on hover. Hairlines between rows. A tick
/// box before each task (and Select all in the labels row) selects it; a bar at the bottom then changes the selected
/// tasks' status, assignee or size, or archives them. The tick box column indents titles under the group's name.
struct MacTaskList: View {
    @Environment(AppModel.self) private var model
    let workspace: WorkspaceRecord
    let snapshot: TasksSnapshot
    let search: String
    let sort: MacTaskSort
    let grouping: MacTaskGrouping
    let me: String?
    let setState: (TaskRow, TaskState) -> Void
    /// New task, with the status of the group it was started from.
    let newTask: (TaskState?) -> Void
    @Binding var sortBinding: MacTaskSort
    /// Rows ticked for a bulk change (shared with the board's selection).
    @Binding var selected: Set<String>
    let canChange: (TaskRow) -> Bool
    /// Archive asks first (the board's confirmation).
    let archiveSelected: () -> Void
    @AppStorage("tasks.list.collapsed.v1") private var collapsedList = ""
    /// Your own order of tasks (Sort: Manual), per workspace, on this device: Tower keeps no task order.
    @AppStorage("tasks.list.order.v1") private var orderJSON = "{}"
    /// Where a dragged task would land: before or after a task, or at the top of a group.
    @State private var dropMark: DropMark?

    struct DropMark: Equatable { let id: String; let after: Bool }

    /// Inside a channel every task is in it: the column would repeat the place.
    private var showsChannel: Bool { model.context.channelId == nil }

    var body: some View {
        VStack(spacing: 0) {
            columnLabels
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !snapshot.creating.isEmpty { creatingGroup }
                    ForEach(groups) { group in
                        groupRow(group)
                            .overlay(alignment: .bottom) { if dropMark == DropMark(id: "group:" + group.id, after: true) { dropLine } }
                            .onDrop(of: [.plainText], delegate: TaskRowDrop(height: 44, mark: { after in
                                dropMark = after == nil ? nil : DropMark(id: "group:" + group.id, after: true)
                            }, perform: { text, _ in move(text, before: group.rows.first, after: false, into: group) }))
                        if !collapsed.contains(key(group)) {
                            ForEach(group.rows) { row in
                                taskRow(row)
                                    .modifier(TaskTableRule(selected: selected.contains(row.id)))
                                    .overlay(alignment: dropMark?.after == true ? .bottom : .top) { if dropMark?.id == row.id { dropLine } }
                                    .onDrop(of: [.plainText], delegate: TaskRowDrop(height: Amb.ListLayout.rowHeight, mark: { after in
                                        dropMark = after.map { DropMark(id: row.id, after: $0) }
                                    }, perform: { text, after in move(text, before: row, after: after, into: group) }))
                            }
                        }
                    }
                    if groups.isEmpty, !search.isEmpty {
                        Text("No tasks match “\(search)”.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(.bottom, selected.isEmpty ? Amb.Space.xl : 88)
            }
        }
        .overlay(alignment: .bottom) {
            if !selected.isEmpty {
                bulkBar.padding(.bottom, Amb.Space.l).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: selected.isEmpty)
    }

    /// Before a title: the tick box under the group's chevron, then room up to the group's name.
    private static let gutter: CGFloat = Amb.ListLayout.dragMargin
    /// Past the group's name, so a task reads as inside its group (gr8r-studio).
    private static let titleIndent: CGFloat = 48

    // MARK: Columns

    /// Every task shown (search applied, folded groups included).
    private var visibleRows: [TaskRow] { groups.flatMap(\.rows) }

    private var columnLabels: some View {
        let rows = visibleRows.filter(canChange)
        let ticked = rows.filter { selected.contains($0.id) }.count
        return HStack(spacing: Amb.ListLayout.rowGap) {
            HStack(spacing: 0) {
                TaskCheckbox(state: ticked == 0 ? .off : ticked == rows.count ? .on : .mixed, label: "Select all tasks") {
                    if ticked == rows.count { selected.subtract(rows.map(\.id)) } else { selected.formUnion(rows.map(\.id)) }
                }
                .disabled(rows.isEmpty)
                .accessibilityIdentifier("tasks.selectAll")
                Color.clear.frame(width: Self.titleIndent, height: 1)
                sortLabel("Task", .title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: Amb.ListLayout.statusColumn, alignment: .leading)
            Text("Assignee").frame(width: Amb.ListLayout.personColumn, alignment: .leading)
            sortLabel("Size", .size).frame(width: Amb.ListLayout.sizeColumn, alignment: .leading)
            if showsChannel { Text("Channel").frame(width: Amb.ListLayout.placeColumn, alignment: .leading) }
            HStack(spacing: 0) { Spacer(minLength: 0); sortLabel("Updated", .updated) }.frame(width: Amb.ListLayout.timeColumn)
            Color.clear.frame(width: Amb.ListLayout.actionColumn, height: 1)
        }
        .font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.mutedForeground)
        .padding(.leading, Self.gutter).padding(.trailing, Amb.ListLayout.trailing)
        .frame(height: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 1) }
    }

    /// A column label that sorts by it (again to return to the default order).
    private func sortLabel(_ title: String, _ value: MacTaskSort) -> some View {
        Button { sortBinding = sort == value ? .manual : value } label: {
            HStack(spacing: 3) {
                Text(title)
                if sort == value { Image(systemName: value == .title ? "arrow.up" : "arrow.down").font(.amb(.caption2)) }
            }
            .foregroundStyle(sort == value ? Amb.foreground : Amb.mutedForeground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ambTooltip("Sort by \(title.lowercased())")
        .accessibilityIdentifier("tasks.sort.\(value.rawValue)")
    }

    // MARK: Groups

    private func groupRow(_ group: MacTaskGroup) -> some View {
        let closed = collapsed.contains(key(group))
        return HStack(spacing: Amb.Space.s) {
            Button { toggle(group) } label: {
                Image(systemName: closed ? "chevron.right" : "chevron.down").font(.amb(.caption).weight(.semibold))
                    .foregroundStyle(Amb.mutedForeground).frame(width: 16, height: 16).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(closed ? "Show" : "Hide") \(group.title)")
            .accessibilityIdentifier("tasks.group.toggle.\(group.id)")
            group.mark
            Text(group.title).font(.amb(.subheadline).weight(.semibold)).foregroundStyle(Amb.foreground)
            Text("\(group.rows.count)").font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
            Button { newTask(group.state) } label: {
                Image(systemName: "plus").font(.amb(.caption).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain).ambHover()
            .ambTooltip(group.state.map { "New task in \($0.label)" } ?? "New task")
            .accessibilityIdentifier("tasks.group.new.\(group.id)")
            Spacer(minLength: 0)
        }
        .padding(.leading, Self.gutter).padding(.trailing, Amb.ListLayout.trailing)
        .padding(.top, Amb.ListLayout.sectionTop).padding(.bottom, Amb.Space.s)
        .overlay(alignment: .bottom) {
            // Rules run edge to edge, so hover and selected fills sit flush between them (gr8r-studio).
            Rectangle().fill(Amb.border).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private var creatingGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContentListSectionLabel(title: "Creating", count: snapshot.creating.count)
            ForEach(Array(snapshot.creating.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: Amb.ListLayout.rowGap) {
                    Text(item.string("title") ?? "Task").font(.amb(.body)).lineLimit(1)
                    Spacer(minLength: 0)
                    WriteStatusLine(item: item, label: "New task")
                }
                .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
                .frame(minHeight: Amb.ListLayout.rowHeight)
                .contentListRow(first: index == 0)
            }
        }
    }

    private var groups: [MacTaskGroup] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let rows = q.isEmpty ? snapshot.rows : snapshot.rows.filter { $0.title.lowercased().contains(q) }
        let made: [MacTaskGroup]
        switch grouping {
        case .status:
            let byState = Dictionary(grouping: rows) { $0.taskState ?? .new }
            let order: [TaskState] = [.backlog] + TaskState.board
            made = order.compactMap { state in
                guard let rows = byState[state], !rows.isEmpty else { return nil }
                return MacTaskGroup(id: state.rawValue, title: state.label, rows: rows, state: state, mark: AnyView(TaskStatusRing(state: state)))
            }
        case .size:
            let order = ["rock", "pebble", "sand"]
            let bySize = Dictionary(grouping: rows) { order.contains($0.priority) ? $0.priority : "other" }
            made = (order + ["other"]).compactMap { size in
                guard let rows = bySize[size], !rows.isEmpty else { return nil }
                return MacTaskGroup(id: size, title: TaskPriority(rawValue: size)?.label ?? "Other", rows: rows,
                                    mark: AnyView(TaskSizeDot(priority: size)))
            }
        case .assignee:
            let byPerson = Dictionary(grouping: rows) { $0.assignee ?? "" }
            let people = byPerson.keys.filter { !$0.isEmpty }.sorted { name($0) < name($1) }
            made = (people + [""]).compactMap { npub in
                guard let rows = byPerson[npub], !rows.isEmpty else { return nil }
                guard !npub.isEmpty else {
                    return MacTaskGroup(id: "unassigned", title: "Unassigned", rows: rows,
                                        mark: AnyView(Circle().strokeBorder(Amb.faint, style: StrokeStyle(lineWidth: 1, dash: [2, 2])).frame(width: 16, height: 16)))
                }
                return MacTaskGroup(id: npub, title: name(npub), rows: rows, mark: AnyView(avatar(npub)))
            }
        case .channel:
            let byChannel = Dictionary(grouping: rows) { $0.task.channelId }
            let ids = byChannel.keys.sorted { (snapshot.choice.channelName($0) ?? "") < (snapshot.choice.channelName($1) ?? "") }
            made = ids.map { id in
                MacTaskGroup(id: id, title: snapshot.choice.channelName(id) ?? "Channel", rows: byChannel[id] ?? [],
                             mark: AnyView(Text("#").font(.amb(.subheadline)).foregroundStyle(Amb.faint)))
            }
        }
        return made.map { group in var g = group; g.rows = sorted(g.rows); return g }
    }

    private func sorted(_ rows: [TaskRow]) -> [TaskRow] {
        switch sort {
        case .manual:
            // Your saved order; tasks you haven't placed yet stay above, in Tower's order (newest change first).
            let saved = manualOrder
            let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
            return rows.enumerated().sorted { a, b in
                switch (rank[a.element.id], rank[b.element.id]) {
                case let (x?, y?): return x < y
                case (nil, _?): return true
                case (_?, nil): return false
                default: return a.offset < b.offset
                }
            }.map(\.element)
        case .title: return rows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .updated: return rows.sorted { $0.task.updatedAt > $1.task.updatedAt }
        case .size:
            func rank(_ p: String) -> Int { ["rock": 0, "urgent": 0, "high": 0, "pebble": 1, "normal": 1, "sand": 2, "low": 2][p] ?? 3 }
            return rows.enumerated().sorted { (rank($0.element.priority), $0.offset) < (rank($1.element.priority), $1.offset) }.map(\.element)
        }
    }

    private var collapsed: Set<String> { Set(collapsedList.split(separator: ",").map(String.init)) }
    private func key(_ group: MacTaskGroup) -> String { "\(grouping.rawValue):\(group.id)" }
    private func toggle(_ group: MacTaskGroup) {
        var set = collapsed
        if set.contains(key(group)) { set.remove(key(group)) } else { set.insert(key(group)) }
        collapsedList = set.sorted().joined(separator: ",")
    }

    // MARK: Rows

    private func taskRow(_ row: TaskRow) -> some View {
        let ticked = selected.contains(row.id)
        return HStack(spacing: 0) {
            dragHandle(row).frame(width: Self.gutter)
            TaskCheckbox(state: ticked ? .on : .off, label: "Select \(row.title)") {
                if ticked { selected.remove(row.id) } else { selected.insert(row.id) }
            }
            .disabled(!canChange(row))
            .accessibilityIdentifier("task.select.\(row.title)")
            Color.clear.frame(width: Self.titleIndent, height: 1)
            rowContent(row)
        }
        .padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .contextMenu {
            if row.taskState != .inProgress { Button("Start") { setState(row, .inProgress) } }
            if row.taskState != .done { Button("Mark done") { setState(row, .done) } }
        }
    }

    private func rowContent(_ row: TaskRow) -> some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            WorkRecordLink(route: WorkRoute.task(workspaceId: workspace.id, taskId: row.id)) {
                HStack(spacing: Amb.ListLayout.rowGap) {
                    title(row).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        TaskStatusRing(state: row.taskState ?? .new)
                        Text(row.taskState?.label ?? row.state.capitalized).lineLimit(1)
                    }
                    .frame(width: Amb.ListLayout.statusColumn, alignment: .leading)
                    assignee(row).frame(width: Amb.ListLayout.personColumn, alignment: .leading)
                    TaskSizeLabel(priority: row.priority).frame(width: Amb.ListLayout.sizeColumn, alignment: .leading)
                    if showsChannel {
                        Text(snapshot.choice.channelName(row.task.channelId).map { "#\($0)" } ?? "")
                            .lineLimit(1).frame(width: Amb.ListLayout.placeColumn, alignment: .leading)
                    }
                    HStack(spacing: 0) { Spacer(minLength: 0); MessageTimeText(iso: row.task.updatedAt) }.frame(width: Amb.ListLayout.timeColumn)
                }
                .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
            }
            .accessibilityIdentifier("task.\(row.title)")
            NativeMessageActions(items: actions(row), identifier: "task.actions.\(row.title)", label: "Task actions", help: "More actions")
                .frame(width: Amb.ListLayout.actionColumn, height: 24)
                .ambRevealOnHover()
        }
    }

    // MARK: Moving tasks

    /// Six dots in the margin, shown on hover: drag a task to reorder it, or into another group to change that value.
    @ViewBuilder private func dragHandle(_ row: TaskRow) -> some View {
        if sort == .manual && canChange(row) {
            TaskGrip()
                .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                .draggable(TaskBoardDrag(signer: model.identity.npub ?? "", connection: model.connection?.id ?? "", workspace: workspace.id,
                                         app: workspace.appNpub, task: row.id).text) {
                    Text(row.title).font(.amb(.body)).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Amb.raised, in: RoundedRectangle(cornerRadius: Amb.radiusControl))
                }
                .ambRevealOnHover()
                .ambTooltip("Drag to move")
                .accessibilityLabel("Move \(row.title)")
        } else {
            Color.clear
        }
    }

    private var dropLine: some View {
        Rectangle().fill(Amb.primary).frame(height: 2)
            .padding(.leading, Self.gutter)
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var manualOrder: [String] {
        let all = (try? JSONSerialization.jsonObject(with: Data(orderJSON.utf8))) as? [String: [String]]
        return all?[workspace.id] ?? []
    }

    /// Drops a task before or after another (or at the top of a group): saves the order on this device and, when the
    /// group differs, changes the task's status, size or assignee to the group's. Tasks can't move between channels here.
    private func move(_ text: String, before target: TaskRow?, after: Bool, into group: MacTaskGroup) {
        dropMark = nil
        guard let id = TaskBoardDrag.taskId(from: text, signer: model.identity.npub ?? "", connection: model.connection?.id ?? "",
                                            workspace: workspace.id, app: workspace.appNpub),
              let row = snapshot.rows.first(where: { $0.id == id }), canChange(row), target?.id != id else { return }
        let from = groups.first { $0.rows.contains { $0.id == id } }
        if from?.id != group.id {
            guard let intent = change(row, to: group) else { return }
            model.submit(intent, in: workspace)
        }
        var order = groups.flatMap(\.rows).map(\.id).filter { $0 != id }
        let anchor = target.flatMap { t in order.firstIndex(of: t.id) }
        let index = anchor.map { after ? $0 + 1 : $0 } ?? (group.rows.first.flatMap { order.firstIndex(of: $0.id) } ?? order.count)
        order.insert(id, at: min(index, order.count))
        var all = ((try? JSONSerialization.jsonObject(with: Data(orderJSON.utf8))) as? [String: [String]]) ?? [:]
        all[workspace.id] = order
        if let data = try? JSONSerialization.data(withJSONObject: all), let json = String(data: data, encoding: .utf8) { orderJSON = json }
    }

    /// The write that puts a task in another group, by the current grouping.
    private func change(_ row: TaskRow, to group: MacTaskGroup) -> WriteIntent? {
        switch grouping {
        case .status:
            guard let state = group.state, row.state != state.rawValue else { return nil }
            return WriteIntent(kind: .taskState, targetId: row.id, payload: ["state": state.rawValue])
        case .size:
            guard TaskPriority(rawValue: group.id) != nil else { return nil }
            return sizeIntent(row, group.id)
        case .assignee:
            return assignIntent(row, group.id == "unassigned" ? nil : group.id)
        case .channel:
            return nil
        }
    }

    private func sizeIntent(_ row: TaskRow, _ size: String) -> WriteIntent? {
        guard row.priority != size else { return nil }
        let payload: [String: any Sendable] = ["base_row_version": row.task.rowVersion,
            "base": ["title": row.task.title, "description": row.task.description ?? "", "priority": row.task.priority],
            "patch": ["priority": size]]
        return WriteIntent(kind: .taskPatch, targetId: row.id, payload: payload)
    }

    private func assignIntent(_ row: TaskRow, _ npub: String?) -> WriteIntent? {
        guard row.assignee != npub else { return nil }
        return WriteIntent(kind: .taskAssign, targetId: row.id, payload: ["assigned_to_npub": npub ?? "", "base_row_version": row.task.rowVersion,
                                                                           "base_assigned_to_npub": row.task.assignedToNpub ?? ""])
    }

    // MARK: Bulk changes

    private var chosen: [TaskRow] { snapshot.rows.filter { selected.contains($0.id) && canChange($0) } }

    private var bulkBar: some View {
        HStack(spacing: 2) {
            Text("\(selected.count) selected").font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.foreground)
                .monospacedDigit().padding(.horizontal, 10)
            barDivider
            barMenu("Status", "circle.dashed", identifier: "tasks.bulk.status") {
                ForEach(TaskState.board, id: \.self) { state in
                    Button(state.label) {
                        bulk { row in row.state == state.rawValue ? nil : WriteIntent(kind: .taskState, targetId: row.id, payload: ["state": state.rawValue]) }
                    }
                }
            }
            barMenu("Assignee", "person", identifier: "tasks.bulk.assignee") {
                Button("Unassigned") { assign(nil) }
                Divider()
                ForEach(snapshot.names.keys.sorted { name($0) < name($1) }, id: \.self) { npub in
                    Button(name(npub)) { assign(npub) }
                }
            }
            barMenu("Size", "smallcircle.filled.circle", identifier: "tasks.bulk.size") {
                ForEach(TaskPriority.editable, id: \.self) { size in
                    Button(size.label) { bulk { row in sizeIntent(row, size.rawValue) } }
                }
            }
            Button(action: archiveSelected) { Label("Archive", systemImage: "archivebox").fixedSize() }
                .buttonStyle(.ambGhost).accessibilityIdentifier("tasks.bulk.archive")
            barDivider
            Button { selected.removeAll() } label: { Image(systemName: "xmark") }
                .buttonStyle(.ambIcon).ambTooltip("Clear selection (Esc)")
                .accessibilityLabel("Clear selection").accessibilityIdentifier("tasks.bulk.clear")
        }
        .font(.amb(.footnote))
        .padding(6)
        .background(Amb.raised, in: RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous).stroke(Amb.borderStrong))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bulk actions")
        .accessibilityIdentifier("tasks.bulk")
    }

    private var barDivider: some View { Rectangle().fill(Amb.border).frame(width: 1, height: 18).padding(.horizontal, 4) }

    private func barMenu<Items: View>(_ title: String, _ symbol: String, identifier: String, @ViewBuilder items: () -> Items) -> some View {
        Menu { items() } label: { Label(title, systemImage: symbol).font(.amb(.footnote).weight(.medium)) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .tint(Amb.secondaryForeground).foregroundStyle(Amb.secondaryForeground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .ambHover()
            .accessibilityIdentifier(identifier)
    }

    /// Sends one write per selected task that needs it, then clears the selection.
    private func bulk(_ make: (TaskRow) -> WriteIntent?) {
        for row in chosen { if let intent = make(row) { model.submit(intent, in: workspace) } }
        selected.removeAll()
    }

    private func assign(_ npub: String?) { bulk { row in assignIntent(row, npub) } }

    private func title(_ row: TaskRow) -> some View {
        HStack(spacing: Amb.Space.s) {
            Text(row.title)
                .font(.amb(.body))
                .foregroundStyle(row.taskState?.isTerminal == true ? Amb.mutedForeground : Amb.foreground)
                .lineLimit(1)
            if let counts = subtasks[row.id] {
                Label("\(counts.done)/\(counts.total)", systemImage: "checklist")
                    .labelStyle(.titleAndIcon).font(.amb(.caption)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
                    .accessibilityLabel("\(counts.done) of \(counts.total) subtasks done")
            }
            if row.pending.contains(where: \.isPending) {
                Image(systemName: "arrow.up.circle").foregroundStyle(Amb.mutedForeground).accessibilityLabel("Change not sent yet")
            }
            if row.pending.contains(where: { !$0.isPending }) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Amb.destructive).accessibilityLabel("Change not saved")
            }
        }
    }

    @ViewBuilder private func assignee(_ row: TaskRow) -> some View {
        if let npub = row.assignee {
            HStack(spacing: 6) { avatar(npub); Text(name(npub)).lineLimit(1) }
        } else {
            Text("Unassigned").foregroundStyle(Amb.faint)
        }
    }

    private func avatar(_ npub: String) -> some View {
        InitialsAvatar(initials: PersonInitials.of(name(npub)), size: 18, agent: snapshot.agents.contains { $0.npub == npub })
    }

    private func name(_ npub: String) -> String { displayName(npub, snapshot.names, me: me) }

    /// Subtasks done and in all, per parent task.
    private var subtasks: [String: (done: Int, total: Int)] {
        var out: [String: (done: Int, total: Int)] = [:]
        for row in snapshot.rows {
            guard let parent = TaskTreeNode(row.task).parentId else { continue }
            let done = row.taskState?.isTerminal == true ? 1 : 0
            out[parent] = ((out[parent]?.done ?? 0) + done, (out[parent]?.total ?? 0) + 1)
        }
        return out
    }

    private func actions(_ row: TaskRow) -> [NativeMessageAction] {
        var items: [NativeMessageAction] = []
        if row.taskState != .inProgress { items.append(NativeMessageAction("Start", "play") { setState(row, .inProgress) }) }
        if row.taskState != .done { items.append(NativeMessageAction("Mark done", "checkmark") { setState(row, .done) }) }
        items.append(NativeMessageAction("Move to", "arrow.right", children: TaskState.board.filter { $0.rawValue != row.state }.map { state in
            NativeMessageAction(state.label, "circle") { setState(row, state) }
        }))
        return items
    }
}

/// A task row's hover and selected fills and the hairline under it, all edge to edge, so the fills sit flush between
/// the rules and a group's last task is closed off too (gr8r-studio).
private struct TaskTableRule: ViewModifier {
    var selected = false
    func body(content: Content) -> some View {
        content
            .background(selected ? Amb.selectedFill : .clear)
            .ambHoverRow(radius: 0)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Amb.border).frame(height: 1).accessibilityHidden(true)
            }
    }
}

/// Six dots: the handle a task row is dragged by.
private struct TaskGrip: View {
    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 2.5) { Circle().frame(width: 2.5, height: 2.5); Circle().frame(width: 2.5, height: 2.5) }
            }
        }
        .foregroundStyle(Amb.faint)
        .accessibilityHidden(true)
    }
}

/// Drop target for a task row: reports whether the drop would land in its top or bottom half, and hands over the
/// dragged text.
private struct TaskRowDrop: DropDelegate {
    let height: CGFloat
    let mark: (Bool?) -> Void
    let perform: (String, Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.plainText]) }
    func dropUpdated(info: DropInfo) -> DropProposal? { mark(info.location.y > height / 2); return DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { mark(nil) }
    func performDrop(info: DropInfo) -> Bool {
        let after = info.location.y > height / 2
        mark(nil)
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        nonisolated(unsafe) let perform = perform
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String else { return }
            DispatchQueue.main.async { perform(text, after) }
        }
        return true
    }
}

/// A square tick box in the accent when ticked (selection is an interaction: the accent's job).
struct TaskCheckbox: View {
    enum State { case off, on, mixed }
    let state: State
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(state == .off ? Color.clear : Amb.primary)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Amb.borderStrong : .clear, lineWidth: 1.25)
                if state == .on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Amb.primaryForeground) }
                if state == .mixed { Capsule().fill(Amb.primaryForeground).frame(width: 8, height: 2) }
            }
            .frame(width: 16, height: 16)
            .opacity(enabled ? 1 : 0.4)
            .frame(width: 16, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .on ? "Selected" : state == .mixed ? "Some selected" : "Not selected")
    }
}

/// One group in the task table.
struct MacTaskGroup: Identifiable {
    let id: String
    let title: String
    var rows: [TaskRow]
    /// The status a task started from this group gets (status grouping only).
    var state: TaskState? = nil
    let mark: AnyView
}

enum MacTaskSort: String, CaseIterable {
    case manual, size, updated, title
    var label: String {
        switch self {
        case .manual: "Manual"
        case .size: "Size"
        case .updated: "Updated"
        case .title: "Title"
        }
    }
}

enum MacTaskGrouping: String, CaseIterable {
    case status, size, assignee, channel
    var label: String { rawValue.capitalized }
}

/// The list's toolbar, left of the layout switch: search, sort and group (gr8r-studio's).
struct MacTaskListControls: View {
    @Binding var search: String
    @Binding var sort: MacTaskSort
    @Binding var grouping: MacTaskGrouping

    var body: some View {
        HStack(spacing: Amb.Space.m) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Amb.mutedForeground).accessibilityHidden(true)
                TextField("Search tasks", text: $search).textFieldStyle(.plain)
                    .accessibilityIdentifier("tasks.search")
            }
            .font(.amb(.footnote))
            .padding(.horizontal, 10).frame(width: 240, height: 28)
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(Amb.border))
            menu("arrow.up.arrow.down", "Sort", sort.label, identifier: "tasks.sort") {
                ForEach(MacTaskSort.allCases, id: \.self) { value in
                    Button { sort = value } label: { if sort == value { Label(value.label, systemImage: "checkmark") } else { Text(value.label) } }
                }
            }
            menu("rectangle.grid.1x2", "Group", grouping.label, identifier: "tasks.group") {
                ForEach(MacTaskGrouping.allCases, id: \.self) { value in
                    Button { grouping = value } label: { if grouping == value { Label(value.label, systemImage: "checkmark") } else { Text(value.label) } }
                }
            }
        }
    }

    private func menu<Items: View>(_ symbol: String, _ title: String, _ value: String, identifier: String, @ViewBuilder items: () -> Items) -> some View {
        // One label: a borderless Mac menu keeps only its first text, and tints its icon with the accent.
        Menu { items() } label: {
            Label { Text(title + ": " + value) } icon: { Image(systemName: symbol) }
                .font(.amb(.footnote).weight(.medium))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(Amb.secondaryForeground)
        .foregroundStyle(Amb.secondaryForeground)
        .accessibilityIdentifier(identifier)
    }
}

/// A task's status as a ring in its status colour: open for not started, half for under way, full when finished.
struct TaskStatusRing: View {
    let state: TaskState
    var size: CGFloat = 12

    var body: some View {
        let color = Amb.taskStatus(state.rawValue)
        ZStack {
            if state == .backlog {
                Circle().strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            } else {
                Circle().strokeBorder(color, lineWidth: 1.75)
            }
            switch state {
            case .inProgress, .review:
                HalfDisc().fill(color).padding(3)
            case .done, .archive, .archived:
                Circle().fill(color)
            default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The right half of a circle: a task under way.
private struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The size dot alone: scaled to the size, Rock in the urgency orange.
struct TaskSizeDot: View {
    let priority: String
    var body: some View {
        let value = TaskPriority(rawValue: priority)
        let urgent = value == .rock || value == .urgent || value == .high
        Circle().frame(width: Self.diameter(value), height: Self.diameter(value)).frame(width: 10)
            .foregroundStyle(urgent ? Amb.brandOrange : Amb.mutedForeground)
            .accessibilityHidden(true)
    }

    static func diameter(_ value: TaskPriority?) -> CGFloat {
        switch value {
        case .rock, .urgent, .high: 9
        case .pebble, .normal: 6
        default: 4
        }
    }
}

/// A task's size as a dot and a word (Rock, Pebble, Sand). Rock is orange, the urgency colour; the tooltip explains
/// the sizes.
struct TaskSizeLabel: View {
    let priority: String

    var body: some View {
        let value = TaskPriority(rawValue: priority)
        let urgent = value == .rock || value == .urgent || value == .high
        HStack(spacing: 6) {
            TaskSizeDot(priority: priority)
            Text(value?.label ?? priority.capitalized).lineLimit(1)
        }
        .foregroundStyle(urgent ? Amb.brandOrange : Amb.secondaryForeground)
        .ambTooltip(value?.help ?? "")
        .accessibilityLabel("Size: \(value?.label ?? priority)")
    }
}
#endif
