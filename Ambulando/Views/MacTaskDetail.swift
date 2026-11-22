import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac, round 6.2 A): the task screen reads top to bottom, as Linear and gr8r-studio: title, description,
/// subtasks, then the conversation, with the task's properties in a rail at full width (a grid under the title in a
/// narrow window). Title and description are edited in place (the Edit sheet's write); properties are menus with the
/// same writes and version checks as before; comments run oldest first after the task's creation, composer last.
/// Nothing here is new to Tower: it rearranges what the task screen already did.
struct MacTaskDetail: View {
    @Environment(AppModel.self) private var model
    let taskId: String
    let workspace: WorkspaceRecord
    let store: LocalStore
    @State private var snapshot = LiveQuery<TaskDetailSnapshot>(initial: TaskDetailSnapshot())
    @State private var titleDraft = ""
    @State private var editingDescription = false
    @State private var descriptionDraft = ""
    @State private var comment = ""
    @State private var archiving = false
    @FocusState private var titleFocused: Bool

    /// Under this width the rail folds into a grid under the title.
    private static let railWidth: CGFloat = 900

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= Self.railWidth
            VStack(spacing: 0) {
                crumbs
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        main(wide: wide)
                            .padding(.horizontal, 32).padding(.vertical, 20)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if wide, let row = snapshot.value.row {
                        Rectangle().fill(Amb.border).frame(width: 0.5)
                        ScrollView { rail(row).padding(20) }.frame(width: 280)
                    }
                }
            }
        }
        .background(Amb.background)
        .fixtureLabel()
        .navigationTitle(snapshot.value.row?.title ?? "Task")
        .confirmationDialog("Archive this task?", isPresented: $archiving) {
            Button("Archive", role: .destructive) { submit(.taskState, ["state": TaskState.archive.rawValue]) }
        }
        .task { start() }
        .onAppear { model.openTask(taskId, in: workspace); model.markViewed(.task, taskId, in: workspace) }
        .onChange(of: snapshot.value.row?.title) { _, title in if !titleFocused { titleDraft = title ?? "" } }
        .onChange(of: titleFocused) { _, focused in if !focused { saveTitle() } }
    }

    // MARK: Header

    private var crumbs: some View {
        let channel = snapshot.value.row.flatMap { snapshot.value.choice.channelName($0.task.channelId) }
        return MacRecordCrumbs(place: channel.map { "#\($0)" }, detail: parentTitle.map { "Parent: \($0)" },
                               escape: !(editingDescription || titleFocused)) {
            if let row = snapshot.value.row, canChange {
                NativeMessageActions(items: actions(row), identifier: "task.actions", label: "Task actions", help: "More actions")
                    .frame(width: 28, height: 24)
            }
        }
    }

    @State private var parentTitle: String?

    @ViewBuilder private func main(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let row = snapshot.value.row {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Task title", text: $titleDraft, axis: .vertical)
                        .textFieldStyle(.plain).font(Amb.editorial).foregroundStyle(Amb.foreground)
                        .focused($titleFocused).disabled(!canChange)
                        .onSubmit { titleFocused = false }
                        .onExitCommand { titleDraft = row.title; titleFocused = false }
                        .accessibilityIdentifier("task.title")
                    ForEach(row.pending) { WriteStatusLine(item: $0, label: label(for: $0)) }
                }
                if !wide { grid(row) }
                description(row)
                MacTaskSubtasks(taskId: taskId, workspace: workspace, store: store, canAdd: canChange) { parentTitle = $0 }
                activity(row)
            } else if snapshot.loaded {
                SyncNote(text: model.isUnlocked ? "Loading task…" : "This task is not saved on this \(Device.name) yet. Unlock to load it.")
            }
            if let error = model.syncError(forKey: WorkspaceSync.taskKey(workspace.id, taskId)) { SyncNote(text: error, tone: .warning) }
        }
    }

    // MARK: Description

    @ViewBuilder private func description(_ row: TaskRow) -> some View {
        if editingDescription {
            VStack(alignment: .trailing, spacing: 8) {
                ContentTextEntry(text: $descriptionDraft, placeholder: "Add a description…", workspace: workspace,
                                 field: "task-description-\(row.task.id)", macEditorHeight: 140)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(Amb.borderStrong))
                    .accessibilityIdentifier("edittask.description")
                HStack(spacing: 8) {
                    Button("Cancel") { editingDescription = false }.buttonStyle(.ambGhost)
                        .keyboardShortcut(.escape, modifiers: [])
                    Button("Save") { saveDescription(row) }.buttonStyle(.ambPrimary)
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityIdentifier("edittask.save")
                }
            }
        } else {
            Group {
                if let text = row.task.description, !text.isEmpty {
                    MessageBody(text: text, workspace: workspace)
                } else {
                    Text(canChange ? "Add a description…" : "No description.").font(.amb(.body)).foregroundStyle(Amb.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canChange else { return }
                descriptionDraft = row.task.description ?? ""
                editingDescription = true
            }
            .ambTooltip(canChange ? "Click to edit" : "")
            .accessibilityIdentifier("task.description")
        }
    }

    // MARK: Properties

    private func rail(_ row: TaskRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Properties").font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
            ForEach(properties(row), id: \.0) { name, value in
                HStack(alignment: .center, spacing: 10) {
                    Text(name).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).frame(width: 82, alignment: .leading)
                    value
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func grid(_ row: TaskRow) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(Array(properties(row).prefix(4).enumerated()), id: \.offset) { _, property in
                GridRow {
                    Text(property.0).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    property.1
                }
            }
        }
    }

    /// Status, Size and Assignee are menus (when you may change the task); the rest are shown.
    private func properties(_ row: TaskRow) -> [(String, AnyView)] {
        let names = snapshot.value.names, me = model.identity.npub
        let state = TaskState(rawValue: row.state) ?? .new
        var out: [(String, AnyView)] = [
            ("Status", AnyView(PropertyMenu(enabled: canChange, identifier: "task.state") {
                ForEach(TaskState.board + [.backlog], id: \.self) { value in
                    Button(value.label) { if row.state != value.rawValue { submit(.taskState, ["state": value.rawValue]) } }
                }
            } label: {
                HStack(spacing: 6) { TaskStatusRing(state: state); Text(state.label) }
            })),
            ("Size", AnyView(PropertyMenu(enabled: canChange, identifier: "task.priority") {
                ForEach(TaskPriority.editable, id: \.self) { size in Button(size.label) { patch(row, ["priority": size.rawValue]) } }
            } label: {
                Text(TaskPriority(rawValue: row.priority)?.label ?? row.priority)
            }.ambTooltip(TaskPriority.sizesHelp))),
            ("Assignee", AnyView(PropertyMenu(enabled: canChange, identifier: "task.assignee") {
                Button("Unassigned") { assign(row, nil) }
                Divider()
                ForEach(snapshot.value.members) { member in Button(member.label) { assign(row, member.npub) } }
            } label: {
                if let npub = row.assignee {
                    HStack(spacing: 6) {
                        PersonAvatar(person: snapshot.value.people.person(npub), size: 18)
                        Text(displayName(npub, names, me: me))
                    }
                } else {
                    Text("Unassigned").foregroundStyle(Amb.mutedForeground)
                }
            })),
        ]
        if let channel = snapshot.value.choice.channelName(row.task.channelId) {
            out.append(("Channel", AnyView(Text("#\(channel)").font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground))))
        }
        if let creator = row.task.createdByNpub {
            out.append(("Created by", AnyView(HStack(spacing: 6) {
                PersonAvatar(person: snapshot.value.people.person(creator), size: 18)
                Text(displayName(creator, names, me: me))
            }.font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground))))
        }
        out.append(("Created", AnyView(Text(ChatTime.label(row.task.createdAt)).font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground))))
        out.append(("Updated", AnyView(Text(ChatTime.label(row.task.updatedAt)).font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground))))
        return out
    }

    // MARK: Activity

    private func activity(_ row: TaskRow) -> some View {
        let count = snapshot.value.comments.count + snapshot.value.pendingComments.count
        return VStack(alignment: .leading, spacing: 14) {
            Rectangle().fill(Amb.border).frame(height: 0.5)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Activity").font(.amb(.headline)).foregroundStyle(Amb.itemHeading)
                Text(count == 1 ? "1 comment" : "\(count) comments").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            }
            if let creator = row.task.createdByNpub {
                HStack(spacing: 8) {
                    PersonAvatar(person: snapshot.value.people.person(creator), size: 18)
                    Text("\(displayName(creator, snapshot.value.names, me: model.identity.npub)) created the task · \(ChatTime.label(row.task.createdAt))")
                        .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                }
            }
            ForEach(snapshot.value.comments.sorted { $0.createdAt < $1.createdAt }) { c in
                CommentRow(comment: c, people: snapshot.value.people, workspace: workspace)
            }
            ForEach(snapshot.value.pendingComments) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.string("body") ?? "").font(.amb(.body)).foregroundStyle(Amb.secondaryForeground)
                    WriteStatusLine(item: item, label: "Comment")
                }
                .accessibilityIdentifier("comment.pending")
            }
            commentComposer
        }
    }

    private var commentComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ContentTextEntry(text: $comment, placeholder: "Leave a comment…", workspace: workspace, field: "task-comment-\(taskId)", actorMentions: true)
                .lineLimit(1...6)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous).stroke(Amb.border))
                .accessibilityIdentifier("comment.field")
            Button { sendComment() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)) }
                .buttonStyle(.plain).foregroundStyle(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Amb.faint : Amb.primary)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .ambTooltip("Send (⌘↵)")
                .accessibilityLabel("Send comment").accessibilityIdentifier("comment.send")
        }
    }

    // MARK: Writes

    private var canChange: Bool { snapshot.value.row != nil }

    private func actions(_ row: TaskRow) -> [NativeMessageAction] {
        func mark(_ current: Bool) -> String { current ? "checkmark" : "" }
        return [
            NativeMessageAction("Status", "circle.dashed", children: TaskState.board.map { state in
                NativeMessageAction(state.label, mark(row.state == state.rawValue)) { if row.state != state.rawValue { submit(.taskState, ["state": state.rawValue]) } }
            }),
            NativeMessageAction("Assignee", "person", children:
                [NativeMessageAction("Unassigned", mark(row.assignee == nil)) { assign(row, nil) }]
                + snapshot.value.members.map { member in
                    NativeMessageAction(member.label, mark(row.assignee == member.npub)) { assign(row, member.npub) }
                }),
            NativeMessageAction("Size", "smallcircle.filled.circle", children: TaskPriority.editable.map { size in
                NativeMessageAction(size.label, mark(row.priority == size.rawValue)) { patch(row, ["priority": size.rawValue]) }
            }),
            NativeMessageAction("Archive…", "archivebox") { archiving = true },
        ]
    }

    private func saveTitle() {
        guard let row = snapshot.value.row else { return }
        let t = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { titleDraft = row.title; return }
        if t != row.task.title { patch(row, ["title": t]) }
    }

    private func saveDescription(_ row: TaskRow) {
        if descriptionDraft != (row.task.description ?? "") { patch(row, ["description": descriptionDraft]) }
        editingDescription = false
    }

    private func sendComment() {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if model.submit(WriteIntent(kind: .taskComment, targetId: taskId, payload: ["body": text, "mentions": CommentMentions.actors(in: text).map(\.requestObject)]), in: workspace) { comment = "" }
    }

    private func label(for item: WriteItem) -> String {
        switch item.kind {
        case .taskState: "State change"
        case .taskPatch: "Edit"
        case .taskAssign: "Assignment"
        default: "Change"
        }
    }

    private func submit(_ kind: WriteKind, _ payload: [String: any Sendable]) {
        model.submit(WriteIntent(kind: kind, targetId: taskId, payload: payload), in: workspace)
    }

    /// Edits record the version and values they were made on, so a concurrent change is detected, not overwritten.
    private func patch(_ row: TaskRow, _ fields: [String: String]) {
        submit(.taskPatch, ["base_row_version": row.task.rowVersion,
                            "base": ["title": row.task.title, "description": row.task.description ?? "", "priority": row.task.priority],
                            "patch": fields])
    }

    private func assign(_ row: TaskRow, _ npub: String?) {
        submit(.taskAssign, ["assigned_to_npub": npub ?? "", "base_row_version": row.task.rowVersion, "base_assigned_to_npub": row.task.assignedToNpub ?? ""])
    }

    private func start() {
        let w = workspace.id, id = taskId, store = store, connection = model.connection?.id ?? ""
        snapshot.start(store: store, matches: { ($0.workspaceId == w && [.tasks, .comments, .writes, .members, .agents, .channels].contains($0.table)) || $0.table == .profiles }) {
            async let task = store.reader.task(workspaceId: w, id: id)
            async let comments = store.reader.comments(workspaceId: w, parent: .task, parentId: id)
            async let writes = store.reader.writes(connectionId: connection, workspaceId: w, targetId: id)
            async let people = store.reader.people(connectionId: connection, workspaceId: w)
            async let members = store.reader.directoryMembers(workspaceId: w)
            async let choice = scopeChoice(store, w)
            let pending = try await writes
            let directory = try await members
            return TaskDetailSnapshot(row: try await task.map { TaskRow(task: $0, writes: pending.filter { $0.kind != .taskComment }) },
                                      comments: try await comments, pendingComments: pending.filter { $0.kind == .taskComment }, people: try await people,
                                      members: directory, names: Dictionary(directory.map { ($0.npub, $0.label) }, uniquingKeysWith: { a, _ in a }),
                                      choice: try await choice)
        }
    }
}

/// A property's value as a quiet menu (plain text until hovered), or just the value when it can't be changed.
private struct PropertyMenu<Items: View, Label: View>: View {
    let enabled: Bool
    let identifier: String
    @ViewBuilder let items: () -> Items
    @ViewBuilder let label: () -> Label

    var body: some View {
        if enabled {
            Menu { items() } label: {
                label().font(.amb(.footnote)).foregroundStyle(Amb.foreground)
                    .padding(.horizontal, 6).padding(.vertical, 3).contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .ambHover()
            .padding(.leading, -6)
            .accessibilityIdentifier(identifier)
        } else {
            label().font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
        }
    }
}

// MARK: Subtasks

private struct MacSubtaskSnapshot: Sendable, Equatable {
    var children: [TaskRecord] = []
    var parent: TaskRecord?
    var cache: TaskRelationshipCache?
    var choice = ScopeChoice()
    var task: TaskRecord?
    var pending: [WriteItem] = []
    var people = PeopleDirectory()
}

/// The task's subtasks as rows (ring, title, assignee), a done/total count, and Add subtask as the last row. Loads and
/// refreshes as the shared subtasks view does (local relationship cache, refreshed from Tower).
private struct MacTaskSubtasks: View {
    @Environment(AppModel.self) private var model
    @Environment(\.pushRoute) private var pushRoute
    let taskId: String
    let workspace: WorkspaceRecord
    let store: LocalStore
    let canAdd: Bool
    let parent: (String?) -> Void
    @State private var snapshot = LiveQuery<MacSubtaskSnapshot>(initial: MacSubtaskSnapshot())
    @State private var adding = false

    private var done: Int { snapshot.value.children.filter { [.done, .archive, .archived].contains(TaskState(rawValue: $0.state)) }.count }
    private var complete: Bool { snapshot.value.cache?.complete == true && snapshot.value.cache?.unavailable == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Subtasks").font(.amb(.headline)).foregroundStyle(Amb.itemHeading)
                if !snapshot.value.children.isEmpty {
                    Text("\(done)/\(snapshot.value.children.count)\(complete ? "" : "+")").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
                }
                Spacer()
            }
            .padding(.bottom, 8)
            if let error = model.syncError(forKey: TaskRelationshipCache.key(workspace.id, taskId)) {
                SyncNote(text: "Subtasks could not refresh. Showing saved tasks. \(error)", tone: .warning).padding(.bottom, 6)
            } else if snapshot.value.cache?.unavailable == true {
                SyncNote(text: "Some subtasks are unavailable or restricted.", tone: .warning).padding(.bottom, 6)
            } else if let cache = snapshot.value.cache, !cache.complete {
                SyncNote(text: "Subtasks partially loaded.", tone: .warning).padding(.bottom, 6)
            }
            ForEach(snapshot.value.children) { child in
                Button { pushRoute(.task(workspaceId: workspace.id, taskId: child.id)) } label: {
                    HStack(spacing: 10) {
                        TaskStatusRing(state: TaskState(rawValue: child.state) ?? .new)
                        Text(child.title).font(.amb(.body)).foregroundStyle(Amb.foreground).lineLimit(1)
                        Spacer(minLength: 8)
                        if let npub = child.assignedToNpub {
                            PersonAvatar(person: snapshot.value.people.person(npub), size: 18)
                        } else {
                            Text("Unassigned").font(.amb(.caption)).foregroundStyle(Amb.faint)
                        }
                    }
                    .padding(.horizontal, 8).frame(height: 34).contentShape(Rectangle())
                }
                .buttonStyle(.plain).ambHover()
                .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 0.5) }
                .accessibilityIdentifier("task.subtask.\(child.id)")
            }
            ForEach(snapshot.value.pending) { item in
                HStack(spacing: 10) {
                    TaskStatusRing(state: .new)
                    Text(item.string("title") ?? "New subtask").font(.amb(.body)).foregroundStyle(Amb.secondaryForeground)
                    Spacer(minLength: 8)
                    WriteStatusLine(item: item, label: "Add subtask")
                }
                .padding(.horizontal, 8).frame(minHeight: 34)
            }
            if canAdd {
                Button { adding = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus").font(.amb(.caption).weight(.semibold)).frame(width: 12)
                        Text("Add subtask").font(.amb(.body))
                        Spacer()
                    }
                    .foregroundStyle(Amb.mutedForeground)
                    .padding(.horizontal, 8).frame(height: 34).contentShape(Rectangle())
                }
                .buttonStyle(.plain).ambHover()
                .disabled(snapshot.value.task == nil)
                .accessibilityIdentifier("task.subtasks.add")
            }
        }
        .sheet(isPresented: $adding) {
            if let task = snapshot.value.task {
                TaskCreateSheet(workspace: workspace, store: store, choice: snapshot.value.choice,
                                context: WorkContext(scopeId: task.scopeId, channelId: task.channelId), parentTaskId: task.id, parentChannelId: task.channelId)
            }
        }
        .onChange(of: snapshot.value.parent?.title) { _, title in parent(title) }
        .task {
            start()
            refresh()
            // Foreground fallback covers relationship events missed while this screen stays open.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                refresh(force: true)
            }
        }
        .onChange(of: model.identity) { _, _ in refresh(force: true) }
    }

    private func refresh(force: Bool = false) {
        model.withWorkspace(workspace) { sync, c in
            await sync.refreshTaskRelationships(c, workspace, taskId: taskId, force: force)
        }
    }

    private func start() {
        let w = workspace.id, id = taskId, store = store, connection = model.connection?.id ?? ""
        snapshot.start(store: store, matches: { ($0.workspaceId == w && [.tasks, .channels, .writes, .members].contains($0.table)) || [.appState, .profiles].contains($0.table) }) {
            let task = try await store.reader.task(workspaceId: w, id: id)
            let parentId = task.map { TaskTreeNode($0).parentId } ?? nil
            let parent: TaskRecord?
            if let parentId { parent = try await store.reader.task(workspaceId: w, id: parentId) } else { parent = nil }
            return MacSubtaskSnapshot(children: try await store.reader.directSubtasks(workspaceId: w, taskId: id),
                                      parent: parent,
                                      cache: try await store.reader.taskRelationshipCache(workspaceId: w, taskId: id),
                                      choice: try await scopeChoice(store, w), task: task,
                                      pending: try await store.reader.writes(connectionId: connection, workspaceId: w).filter {
                                          $0.kind == .taskCreate && ($0.payloadObject["metadata"] as? [String: Any])?["parent_task_id"] as? String == id
                                      },
                                      people: try await store.reader.people(connectionId: connection, workspaceId: w))
        }
    }
}
#endif
