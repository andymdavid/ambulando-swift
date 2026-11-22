import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac, round 6.4): New task as a compact composer (after gr8r-studio's and Linear's): the place and ✕ on top,
/// the title large, a description, then every other field as a chip that already holds a sensible value. Same fields
/// and the same write as the New task sheet it replaces on the Mac. "Create more" keeps it open with the chips as they
/// were; ⌘↵ creates; Esc cancels and keeps a typed draft until the app quits. The same composer serves Add subtask,
/// with the channel fixed.
struct MacTaskComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let workspace: WorkspaceRecord
    let store: LocalStore
    let choice: ScopeChoice
    let context: WorkContext
    var parentTaskId: String? = nil
    var parentChannelId: String? = nil
    var initialState: TaskState? = nil
    @AppStorage("tasks.composer.lastChannel") private var lastChannel = ""
    @State private var title = ""
    @State private var detail = ""
    @State private var channelId: String?
    @State private var state = TaskState.new
    @State private var priority = TaskPriority.sand
    @State private var assignee: String?
    @State private var members: [MemberRecord] = []
    @State private var more = false
    @State private var parentTitle: String?
    @State private var created = 0
    @FocusState private var titleFocused: Bool

    /// A typed title and description, kept when the composer is cancelled (per parent task, or for a new task).
    @MainActor private static var drafts: [String: (String, String)] = [:]
    private var draftKey: String { parentTaskId ?? "new" }

    private var channels: [ChannelRecord] { choice.channels(in: context).filter { parentChannelId == nil || $0.id == parentChannelId } }
    private var canCreate: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && channelId != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: Amb.Space.s) {
                TextField("Task title", text: $title, axis: .vertical)
                    .textFieldStyle(.plain).font(.amb(.title3).weight(.semibold)).lineLimit(1...3)
                    .focused($titleFocused)
                    .accessibilityIdentifier("newtask.title")
                ContentTextEntry(text: $detail, placeholder: "Add a description…", workspace: workspace, field: "new-task-description",
                                 macEditorHeight: 72)
                    .font(.amb(.body))
            }
            .padding(.horizontal, 20).padding(.top, 14)
            chips.padding(.horizontal, 20).padding(.vertical, 14)
            Rectangle().fill(Amb.border).frame(height: 0.5)
            footer
        }
        .frame(width: 640)
        .background(Amb.raised)
        .onExitCommand { cancel() }
        // The list's channels can arrive after the composer opens (a launch straight into New task).
        .onChange(of: channels.map(\.id)) { _, _ in if channelId == nil { chooseChannel() } }
        .task {
            chooseChannel()
            if let initialState, TaskState.board.contains(initialState) { state = initialState }
            if let draft = Self.drafts[draftKey] { (title, detail) = draft }
            titleFocused = true
            members = (try? await store.reader.directoryMembers(workspaceId: workspace.id)) ?? []
            if let parentTaskId { parentTitle = try? await store.reader.task(workspaceId: workspace.id, id: parentTaskId)?.title }
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 6) {
            if parentTaskId != nil {
                Text("Subtask of").foregroundStyle(Amb.mutedForeground)
                Text(parentTitle ?? "task").foregroundStyle(Amb.foreground).lineLimit(1)
            } else {
                Text(channelId.flatMap { choice.channelName($0) }.map { "#\($0)" } ?? "No channel").foregroundStyle(Amb.mutedForeground)
                Image(systemName: "chevron.right").font(.amb(.caption2)).foregroundStyle(Amb.faint)
                Text("New task").foregroundStyle(Amb.foreground)
            }
            if created > 0 {
                Text("· \(created) created").foregroundStyle(Amb.mutedForeground).accessibilityIdentifier("newtask.created")
            }
            Spacer(minLength: 8)
            Button { cancel() } label: { Image(systemName: "xmark") }
                .buttonStyle(.ambIcon).ambTooltip("Close (Esc)").accessibilityLabel("Close")
        }
        .font(.amb(.footnote).weight(.medium))
        .padding(.horizontal, 20).padding(.top, 14)
    }

    private var chips: some View {
        HStack(spacing: Amb.Space.s) {
            ComposerChip(label: state.label, help: "Status") {
                ForEach(TaskState.board, id: \.self) { value in Button(value.label) { state = value } }
            } icon: {
                Circle().fill(Amb.taskStatus(state.rawValue)).frame(width: 8, height: 8)
            }
            .accessibilityIdentifier("newtask.status")
            ComposerChip(label: priority.label, help: "Size") {
                // What each size means sits in the menu, not in a tooltip (which lingered over the open menu).
                ForEach(TaskPriority.editable, id: \.self) { value in
                    Button { priority = value } label: { Text(value.label); Text(value.meaning) }
                }
            } icon: {
                Image(systemName: "circle.grid.cross").font(.amb(.caption2))
            }
            .accessibilityIdentifier("newtask.size")
            ComposerChip(label: members.first { $0.npub == assignee }?.label ?? "Assignee", help: "Assignee") {
                Button("Unassigned") { assignee = nil }
                Divider()
                ForEach(members) { member in Button(member.label) { assignee = member.npub } }
            } icon: {
                Image(systemName: assignee == nil ? "person.crop.circle.badge.plus" : "person.crop.circle").font(.amb(.caption))
            }
            .accessibilityIdentifier("newtask.assignee")
            ComposerChip(label: channelId.flatMap { choice.channelName($0) } ?? "Channel", help: "Channel") {
                ForEach(channels) { channel in
                    Button("#\(choice.channelName(channel.id) ?? channel.name) · \(choice.scopeName(channel.scopeId) ?? "")") { channelId = channel.id }
                }
            } icon: {
                Image(systemName: "number").font(.amb(.caption2))
            }
            .disabled(parentTaskId != nil)
            .accessibilityIdentifier("newtask.channel")
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: Amb.Space.m) {
            if !model.isUnlocked {
                Text("Saved on this \(Device.name), sent after you unlock.").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            }
            Spacer(minLength: 0)
            Toggle("Create more", isOn: $more).toggleStyle(.switch).controlSize(.mini)
                .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                .accessibilityIdentifier("newtask.more")
            HStack(spacing: 3) { Keycap(text: "⌘"); Keycap(text: "↵") }.accessibilityHidden(true)
            Button("Cancel") { cancel() }.buttonStyle(.ambGhost)
            Button(parentTaskId == nil ? "Create task" : "Create subtask") { create() }
                .buttonStyle(.ambPrimary)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canCreate)
                .accessibilityIdentifier("newtask.add")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    // MARK: Actions

    /// The channel you're in; at Home, the last one you created a task in.
    private func chooseChannel() {
        channelId = parentChannelId ?? channelId ?? context.channelId
            ?? channels.first(where: { $0.id == lastChannel })?.id ?? channels.first?.id
    }

    private func cancel() {
        let typed = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Self.drafts[draftKey] = typed ? (title, detail) : nil
        dismiss()
    }

    private func create() {
        guard let channelId, canCreate else { return }
        var payload: [String: any Sendable] = ["channel_id": channelId, "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                                               "state": state.rawValue, "priority": priority.rawValue]
        let d = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty { payload["description"] = d }
        if let assignee { payload["assigned_to_npub"] = assignee }
        if let parentTaskId { payload["metadata"] = ["parent_task_id": parentTaskId] }
        guard model.submit(WriteIntent(kind: .taskCreate, targetId: nil, payload: payload), in: workspace) else { return }
        Self.drafts[draftKey] = nil
        if parentTaskId == nil { lastChannel = channelId }
        if more {
            title = ""; detail = ""; created += 1
            titleFocused = true
        } else {
            dismiss()
        }
    }
}

/// One field of the composer as a chip: its value, opening a menu of the choices.
private struct ComposerChip<Items: View, Icon: View>: View {
    let label: String
    let help: String
    @ViewBuilder let items: () -> Items
    @ViewBuilder let icon: () -> Icon
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Menu { items() } label: {
            HStack(spacing: 5) {
                icon()
                Text(label).lineLimit(1)
            }
            .font(.amb(.footnote).weight(.medium))
            .foregroundStyle(enabled ? Amb.secondaryForeground : Amb.mutedForeground)
            .padding(.horizontal, 9).frame(height: 26)
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous).stroke(Amb.border))
            .contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        // No tooltip: it stayed up over the chip's open menu. The label says what the chip is.
        .accessibilityLabel("\(help): \(label)")
    }
}
#endif
