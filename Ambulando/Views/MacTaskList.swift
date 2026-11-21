import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac): Tasks as a table, laid out after gr8r-studio's task list (Phase 5.4, round 6). A toolbar (search, sort,
/// group), a row of column labels, then groups: a group row (fold chevron, mark, name, count, +) over its tasks, one
/// per line with Status, Assignee, Size, Channel and Updated in columns and ••• on hover. Hairlines between rows.
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
    @AppStorage("tasks.list.collapsed.v1") private var collapsedList = ""

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
                        if !collapsed.contains(key(group)) {
                            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                                taskRow(row).contentListRow(first: index == 0)
                            }
                        }
                    }
                    if groups.isEmpty, !search.isEmpty {
                        Text("No tasks match “\(search)”.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(.bottom, Amb.Space.xl)
            }
        }
    }

    // MARK: Columns

    private var columnLabels: some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            sortLabel("Task", .title).frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: Amb.ListLayout.statusColumn, alignment: .leading)
            Text("Assignee").frame(width: Amb.ListLayout.personColumn, alignment: .leading)
            sortLabel("Size", .size).frame(width: Amb.ListLayout.sizeColumn, alignment: .leading)
            if showsChannel { Text("Channel").frame(width: Amb.ListLayout.placeColumn, alignment: .leading) }
            HStack(spacing: 0) { Spacer(minLength: 0); sortLabel("Updated", .updated) }.frame(width: Amb.ListLayout.timeColumn)
            Color.clear.frame(width: Amb.ListLayout.actionColumn, height: 1)
        }
        .font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.mutedForeground)
        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
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
        .padding(.leading, Amb.ListLayout.leading - 6).padding(.trailing, Amb.ListLayout.trailing)
        .padding(.top, Amb.ListLayout.sectionTop).padding(.bottom, Amb.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Amb.border).frame(height: 1)
                .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
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
        case .manual: return rows
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
        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .contextMenu {
            if row.taskState != .inProgress { Button("Start") { setState(row, .inProgress) } }
            if row.taskState != .done { Button("Mark done") { setState(row, .done) } }
        }
    }

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
