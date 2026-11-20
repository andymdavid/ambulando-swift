import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac): Tasks as one-line rows grouped by status (Phase 5.4). Each group has a quiet label (status ring, name,
/// count); each row has its status ring, the title, then size, channel and assignee in fixed columns so they line up.
/// Rows don't repeat their group's status. Start and Done, which the iPhone list offers by swiping, are in the context
/// menu.
struct MacTaskList: View {
    let workspace: WorkspaceRecord
    let snapshot: TasksSnapshot
    let columns: [(TaskState, [TaskRow])]
    let me: String?
    let setState: (TaskRow, TaskState) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !snapshot.creating.isEmpty {
                    ContentListSectionLabel(title: "Creating", count: snapshot.creating.count)
                    ForEach(Array(snapshot.creating.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: Amb.ListLayout.rowGap) {
                            Text(item.string("title") ?? "Task").font(.amb(.body).weight(.medium)).lineLimit(1)
                            Spacer(minLength: 0)
                            WriteStatusLine(item: item, label: "New task")
                        }
                        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
                        .frame(minHeight: Amb.ListLayout.rowHeight)
                        .contentListRow(first: index == 0)
                    }
                }
                ForEach(columns, id: \.0) { state, rows in
                    if !rows.isEmpty {
                        ContentListSectionLabel(title: state.label, count: rows.count) { TaskStatusRing(state: state) }
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            WorkRecordLink(route: WorkRoute.task(workspaceId: workspace.id, taskId: row.id)) {
                                MacTaskRow(row: row, snapshot: snapshot, me: me)
                            }
                            .contentListRow(first: index == 0)
                            .contextMenu {
                                if row.taskState != .inProgress { Button("Start") { setState(row, .inProgress) } }
                                if row.taskState != .done { Button("Mark done") { setState(row, .done) } }
                            }
                            .accessibilityIdentifier("task.\(row.title)")
                        }
                    }
                }
            }
            .padding(.bottom, Amb.Space.xl)
        }
    }
}

private struct MacTaskRow: View {
    let row: TaskRow
    let snapshot: TasksSnapshot
    let me: String?

    var body: some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            TaskStatusRing(state: row.taskState ?? .new)
            Text(row.title)
                .font(.amb(.body).weight(.medium))
                .foregroundStyle(row.taskState?.isTerminal == true ? Amb.mutedForeground : Amb.foreground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if row.pending.contains(where: \.isPending) {
                Image(systemName: "arrow.up.circle").foregroundStyle(Amb.mutedForeground).accessibilityLabel("Change not sent yet")
            }
            if row.pending.contains(where: { !$0.isPending }) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Amb.destructive).accessibilityLabel("Change not saved")
            }
            TaskSizeLabel(priority: row.priority).frame(width: Amb.ListLayout.sizeColumn, alignment: .leading)
            Text(snapshot.choice.channelName(row.task.channelId).map { "#\($0)" } ?? "")
                .lineLimit(1).frame(width: Amb.ListLayout.placeColumn, alignment: .leading)
            // A fixed slot even when unassigned, so the columns line up down the list.
            Color.clear.frame(width: Amb.ListLayout.personColumn, height: 1).overlay(alignment: .leading) { assignee }
        }
        .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var assignee: some View {
        if let npub = row.assignee {
            let name = displayName(npub, snapshot.names, me: me)
            HStack(spacing: 6) {
                InitialsAvatar(initials: PersonInitials.of(name), size: 18, agent: snapshot.agents.contains { $0.npub == npub })
                Text(name).lineLimit(1)
            }
            .accessibilityLabel("Assigned to \(name)")
        }
    }
}

/// A task's status as a ring in its status colour: open for not started, half for under way, full when finished.
struct TaskStatusRing: View {
    let state: TaskState
    var size: CGFloat = 12

    var body: some View {
        let color = Amb.taskStatus(state.rawValue)
        ZStack {
            Circle().strokeBorder(color, lineWidth: 1.75)
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

/// A task's size as a dot and a word, the dot scaled to the size (Rock, Pebble, Sand). Rock is orange, the urgency
/// colour; the tooltip explains the sizes.
struct TaskSizeLabel: View {
    let priority: String

    var body: some View {
        let value = TaskPriority(rawValue: priority)
        let urgent = value == .rock || value == .urgent || value == .high
        HStack(spacing: 6) {
            Circle().frame(width: dot(value), height: dot(value)).frame(width: 10)
            Text(value?.label ?? priority.capitalized).lineLimit(1)
        }
        .foregroundStyle(urgent ? Amb.brandOrange : Amb.mutedForeground)
        .ambTooltip(value?.help ?? "")
        .accessibilityLabel("Size: \(value?.label ?? priority)")
    }

    private func dot(_ value: TaskPriority?) -> CGFloat {
        switch value {
        case .rock, .urgent, .high: 9
        case .pebble, .normal: 6
        default: 4
        }
    }
}
#endif
