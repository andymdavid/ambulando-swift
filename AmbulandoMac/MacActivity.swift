import AmbulandoCore
import SwiftUI

/// UX lab (round 8, 8.1): Activity, the workspace's work in progress on one page. The tabs sort a place's records by kind;
/// this sorts them by where the work stands: what needs you, what's moving, what just finished, whether a person or an
/// agent is doing it. Built only from what the app already stores: agent turns, unread notifications and tasks. Rows
/// open the record in its own place (with its tabs). Mac only; a sidebar row under Home, with no tabs, as Apps.
extension AppMode {
    /// Apps and Activity span the workspace: no place, no tabs, and a place chosen from them opens its Deck.
    var isPlaceless: Bool { self == .toolbox || self == .activity }
}

/// What the page reads, as stored. Sections are worked out at render time, because an agent's turn moves from working to
/// stopped on Tower's clock without any new record.
struct MacActivitySnapshot: Sendable, Equatable {
    var activities: [AgentActivityRecord] = []
    var notifications: [NotificationItem] = []
    var tasks: [TaskRecord] = []
    var people = PeopleDirectory()
    var viewer: String?
    var channelLabels: [String: String] = [:]
    var threadTitles: [String: String] = [:]

    static func load(store: LocalStore, workspaceId w: String, connectionId: String?) async throws -> MacActivitySnapshot {
        let reader = store.reader
        var value = MacActivitySnapshot()
        value.viewer = try await reader.viewerNpub(workspaceId: w)
        value.people = try await reader.people(connectionId: connectionId, workspaceId: w)
        value.activities = try await reader.agentActivities(workspaceId: w, channelIds: nil, limit: 300)
        if let connectionId {
            value.notifications = try await reader.notificationSnapshot(connectionId: connectionId, workspaceId: w, filter: .unread, category: nil).items
        }
        value.tasks = try await reader.tasks(workspaceId: w)
        let names = value.people.names
        value.channelLabels = Dictionary(try await reader.channels(workspaceId: w).map {
            ($0.id, SidebarNavigation.label($0, viewerNpub: value.viewer, names: names))
        }, uniquingKeysWith: { a, _ in a })
        for thread in Set(value.activities.compactMap(\.threadId)) {
            if let title = try await reader.thread(workspaceId: w, id: thread)?.title, !title.isEmpty { value.threadTitles[thread] = title }
        }
        return value
    }
}

/// One row of the page.
struct MacActivityItem: Identifiable {
    enum Section: String, CaseIterable, Identifiable {
        case needs, progress, finished
        var id: String { rawValue }
        var title: String {
            switch self {
            case .needs: "Needs you"
            case .progress: "In progress"
            case .finished: "Just finished"
            }
        }
        var empty: String {
            switch self {
            case .needs: "Nothing needs you right now."
            case .progress: "No agents or tasks of yours are in progress."
            case .finished: "Nothing has finished this week."
            }
        }
    }
    enum Tag {
        case waiting, working, queued, finished, stopped, failed, review, inProgress, notice(String)
        var label: String {
            switch self {
            case .waiting: "Waiting for you"
            case .working: "Working"
            case .queued: "Queued"
            case .finished: "Done"
            case .stopped: "Stopped"
            case .failed: "Failed"
            case .review: "Review"
            case .inProgress: "In progress"
            case .notice(let label): label
            }
        }
        var color: Color {
            switch self {
            case .waiting: Amb.brandOrange
            case .working: Amb.primary
            case .stopped, .failed: Amb.destructive
            case .review: Amb.taskStatus("review")
            case .inProgress: Amb.taskStatus("in_progress")
            case .queued, .finished, .notice: Amb.secondaryForeground
            }
        }
        var tinted: Bool { switch self { case .queued, .finished, .notice: false; default: true } }
    }
    enum Mark { case person(String), task(TaskState), symbol(String) }
    enum Target { case thread(channelId: String, threadId: String), task(String), notification(NotificationItem) }

    let id: String
    let section: Section
    let mark: Mark
    let title: String
    let detail: String
    let tag: Tag
    /// Who the row is about (the agent, or the task's assignee), for the Who filter.
    let who: String?
    let channelId: String?
    let date: Date
    let iso: String
    let target: Target
    var isNew = false
}

extension MacActivitySnapshot {
    /// A finished turn stays in Just finished this long.
    static let finishedWindow: TimeInterval = 7 * 24 * 3600

    /// `team`: the Deck's view of a place, which also shows everyone's tasks in progress there and tasks done in the
    /// last two weeks, so a quiet place still shows what's moving. Activity (team false) is only what's yours.
    func items(now serverNow: Date, seen: Date?, team: Bool = false) -> [MacActivityItem] {
        let finishedWindow = team ? 14 * 24 * 3600 : Self.finishedWindow
        var out: [MacActivityItem] = []
        let viewer = viewer
        // Tasks first: a task in Review on you replaces its own assignment notification.
        var reviewTasks: Set<String> = []
        for task in tasks {
            guard let state = task.taskState else { continue }
            let mine = task.assignedToNpub == viewer && viewer != nil
            let created = task.createdByNpub == viewer && viewer != nil
            let date = AgentLiveness.serverDate(task.updatedAt) ?? .distantPast
            if state == .review && (mine || created) {
                reviewTasks.insert(task.id)
                out.append(MacActivityItem(id: "task.\(task.id)", section: .needs, mark: .task(state), title: task.title,
                                           detail: mine ? "Assigned to you · in Review" : "You created it · in Review",
                                           tag: .review, who: task.assignedToNpub, channelId: task.channelId, date: date, iso: task.updatedAt,
                                           target: .task(task.id)))
            } else if state == .inProgress && (mine || team) {
                out.append(MacActivityItem(id: "task.\(task.id)", section: .progress, mark: .task(state), title: task.title,
                                           detail: mine ? "Your task" : task.assignedToNpub.map { people.name($0) } ?? "Unassigned",
                                           tag: .inProgress, who: task.assignedToNpub,
                                           channelId: task.channelId, date: date, iso: task.updatedAt, target: .task(task.id)))
            } else if team && state == .done && serverNow.timeIntervalSince(date) <= finishedWindow {
                let by = task.assignedToNpub ?? task.createdByNpub
                out.append(MacActivityItem(id: "task.\(task.id)", section: .finished, mark: .task(state), title: task.title,
                                           detail: by.map { $0 == viewer ? "You" : people.name($0) } ?? "Task done",
                                           tag: .finished, who: by, channelId: task.channelId, date: date, iso: task.updatedAt,
                                           target: .task(task.id)))
            }
        }
        // Unread notifications need you, except conversation updates (the Chat tab's unread already covers those).
        for item in notifications where item.category != "chat_thread" {
            var channel: String?
            switch item.target {
            case .thread(let c, _, _): channel = c
            case .channel(let c): channel = c
            case .task(let id):
                if reviewTasks.contains(id) { continue }
                channel = tasks.first { $0.id == id }?.channelId
            default: break
            }
            out.append(MacActivityItem(id: "note.\(item.id)", section: .needs, mark: .symbol(NotificationCategories.systemImage(item.category)),
                                       title: item.title, detail: item.body, tag: .notice(NotificationCategories.label(item.category)),
                                       who: nil, channelId: channel, date: AgentLiveness.serverDate(item.occurredAt) ?? .distantPast,
                                       iso: item.occurredAt, target: .notification(item)))
        }
        // Agent turns: the newest per agent and conversation, older failures that newer work replaced left out.
        let hidden = AgentLiveness.supersededFailures(activities, now: serverNow)
        var newest: [String: AgentActivityRecord] = [:]
        for a in activities where !hidden.contains(a.id) {
            let key = a.agentNpub + "|" + (a.threadId ?? a.channelId)
            if let kept = newest[key], kept.createdAt >= a.createdAt { continue }
            newest[key] = a
        }
        for a in newest.values {
            let agent = people.name(a.agentNpub)
            let thread = a.threadId.flatMap { threadTitles[$0] } ?? "a conversation"
            let date = AgentLiveness.serverDate(a.updatedAt) ?? .distantPast
            let line = a.latestText.map { MacActivityItem.oneLine($0) } ?? ""
            let section: MacActivityItem.Section, title: String, detail: String, tag: MacActivityItem.Tag
            switch AgentLiveness.phase(a, now: serverNow) {
            case .waiting:
                (section, title, detail, tag) = (.needs, "\(agent) is waiting for you in \(thread)", line, .waiting)
            case .working:
                (section, title, detail, tag) = (.progress, "\(agent) · \(thread)", line.isEmpty ? "Working…" : line, .working)
            case .queued(let position):
                (section, title, detail, tag) = (.progress, "\(agent) · \(thread)", position.map { "Queued · position \($0)" } ?? "Queued", .queued)
            case .stopped:
                (section, title, detail, tag) = (.finished, "\(agent) stopped on \(thread)",
                                                 "Stopped responding · last update \(date.formatted(date: .omitted, time: .shortened))", .stopped)
            case .completed:
                (section, title, detail, tag) = (.finished, "\(agent) finished \(thread)", line, .finished)
            case .failed, .cancelled:
                (section, title, detail, tag) = (.finished, "\(agent) didn't finish \(thread)", line.isEmpty ? a.state.capitalized : line, .failed)
            }
            if section == .finished && serverNow.timeIntervalSince(date) > finishedWindow { continue }
            var item = MacActivityItem(id: "agent.\(a.id)", section: section, mark: .person(a.agentNpub), title: title, detail: detail,
                                       tag: tag, who: a.agentNpub, channelId: a.channelId, date: date, iso: a.updatedAt,
                                       target: a.threadId.map { .thread(channelId: a.channelId, threadId: $0) } ?? .thread(channelId: a.channelId, threadId: ""))
            item.isNew = section == .finished && (seen.map { date > $0 } ?? true)
            out.append(item)
        }
        return out.sorted { $0.date > $1.date }
    }

    /// How many things need you (the sidebar's count).
    func needsCount(now: Date) -> Int { items(now: now, seen: nil).filter { $0.section == .needs }.count }
}

extension MacActivityItem {
    static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}

// MARK: The page

struct MacActivityView: View {
    @Environment(AppModel.self) private var model
    @Environment(MacUI.self) private var ui
    let workspace: WorkspaceRecord
    let store: LocalStore

    @State private var snapshot = LiveQuery<MacActivitySnapshot>(initial: MacActivitySnapshot())
    @State private var show: Filter = .all
    @State private var who: String? = nil
    @State private var place: String? = nil
    @State private var detail: NotificationItem?
    /// Finished turns after this were not seen yet (remembered on this Mac, per workspace).
    @State private var seen: Date?

    enum Filter: String, CaseIterable, Identifiable {
        case all, needs, progress, finished
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All"
            case .needs: "Needs you"
            case .progress: "In progress"
            case .finished: "Finished"
            }
        }
    }

    private var seenKey: String { "activity.seen.\(workspace.id)" }
    private var origin: String? { model.connection.flatMap { try? TowerOrigin($0.origin).description } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: AgentLiveness.refreshInterval)) { _ in
            let all = snapshot.value.items(now: ServerClock.shared.now(origin: origin), seen: seen)
            VStack(spacing: 0) {
                toolbar(all)
                Rectangle().fill(Amb.border).frame(height: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(sections) { section in
                            sectionView(section, all.filter { $0.section == section && matches($0) })
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(.horizontal, 28).padding(.top, 18).padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Amb.background)
        .task(id: workspace.id) { start() }
        .onAppear { seen = (UserDefaults.standard.object(forKey: seenKey) as? Date) }
        .onDisappear {
            snapshot.pause()
            UserDefaults.standard.set(Date(), forKey: seenKey)
        }
        .sheet(item: $detail) { NotificationDetailView(item: $0) }
        .accessibilityIdentifier("activity.screen")
    }

    private var sections: [MacActivityItem.Section] {
        switch show {
        case .all: MacActivityItem.Section.allCases
        case .needs: [.needs]
        case .progress: [.progress]
        case .finished: [.finished]
        }
    }

    private func matches(_ item: MacActivityItem) -> Bool {
        (who == nil || item.who == who) && (place == nil || item.channelId == place)
    }

    // MARK: Toolbar

    private func toolbar(_ all: [MacActivityItem]) -> some View {
        let people = Array(Set(all.compactMap(\.who))).sorted { name($0) < name($1) }
        let places = Array(Set(all.compactMap(\.channelId))).filter { snapshot.value.channelLabels[$0] != nil }
            .sorted { label($0) < label($1) }
        return ListHeaderBar {
            Picker("Show", selection: $show) {
                ForEach(Filter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .accessibilityIdentifier("activity.filter")
            AmbTableToolbarMenu(symbol: "person", title: "Who", values: [nil] + people.map(Optional.some),
                                label: { $0.map(name) ?? "Anyone" }, selection: $who, identifier: "activity.who")
            AmbTableToolbarMenu(symbol: "number", title: "Where", values: [nil] + places.map(Optional.some),
                                label: { $0.map(label) ?? "Everywhere" }, selection: $place, identifier: "activity.where")
            Spacer(minLength: 0)
            // The bell opens this page; the full list (archive, categories, mark all read) stays one click away.
            Button("All notifications") { ui.showNotifications = true }
                .buttonStyle(.ambGhost).font(.amb(.footnote).weight(.medium))
                .accessibilityIdentifier("activity.notifications")
        }
    }

    // MARK: Sections and rows

    private func sectionView(_ section: MacActivityItem.Section, _ rows: [MacActivityItem]) -> some View {
        let newCount = rows.filter(\.isNew).count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(.amb(.footnote).weight(.semibold))
                    .foregroundStyle(section == .needs && !rows.isEmpty ? Amb.brandOrange : Amb.secondaryForeground)
                Text(section == .finished && newCount > 0 ? "\(newCount) since you last looked" : "\(rows.count)")
                    .font(.amb(.footnote)).foregroundStyle(Amb.faint)
            }
            .padding(.horizontal, 8).padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Amb.border).frame(height: 1)
            if rows.isEmpty {
                Text(section.empty).font(.amb(.footnote)).foregroundStyle(Amb.faint).padding(.horizontal, 8).padding(.vertical, 10)
            } else {
                ForEach(rows) { row($0) }
            }
        }
        .accessibilityIdentifier("activity.section.\(section.rawValue)")
    }

    private func row(_ item: MacActivityItem) -> some View {
        Button { open(item) } label: {
            HStack(spacing: 10) {
                mark(item.mark).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.amb(.subheadline)).foregroundStyle(Amb.foreground).lineLimit(1)
                    if !item.detail.isEmpty {
                        Text(item.detail).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.isNew { Circle().fill(Amb.primary).frame(width: 6, height: 6).accessibilityLabel("New") }
                tag(item.tag)
                Text(item.channelId.map(label) ?? "").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    .lineLimit(1).frame(width: 110, alignment: .leading)
                HStack(spacing: 0) { Spacer(minLength: 0); MessageTimeText(iso: item.iso) }
                    .font(.amb(.footnote)).foregroundStyle(Amb.faint).frame(width: 56)
            }
            .padding(.vertical, 8).padding(.horizontal, 8)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(AmbTableRule())   // hover fill edge to edge, flush between the rules
        .accessibilityIdentifier("activity.row")
    }

    @ViewBuilder private func mark(_ mark: MacActivityItem.Mark) -> some View {
        switch mark {
        case .person(let npub):
            PersonAvatar(person: snapshot.value.people.person(npub), size: 20, agent: snapshot.value.people.isAgent(npub))
        case .task(let state):
            TaskStatusRing(state: state)
        case .symbol(let name):
            Image(systemName: name).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
        }
    }

    private func tag(_ tag: MacActivityItem.Tag) -> some View {
        Text(tag.label).font(.amb(.caption).weight(.medium)).lineLimit(1)
            .foregroundStyle(tag.color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(tag.tinted ? tag.color.opacity(0.14) : Amb.muted, in: Capsule())
            .fixedSize()
    }

    private func name(_ npub: String) -> String {
        npub == snapshot.value.viewer ? "You" : snapshot.value.people.name(npub)
    }

    private func label(_ channel: String) -> String {
        snapshot.value.channelLabels[channel].map { $0.hasPrefix("#") ? $0 : "# " + $0 } ?? ""
    }

    // MARK: Actions

    private func open(_ item: MacActivityItem) {
        if let note = model.openActivityItem(item) { detail = note }
    }

    private func start() {
        let w = workspace.id, store = store, connection = model.connection?.id
        snapshot.start(store: store, matches: {
            ($0.workspaceId == w && [.agents, .notifications, .tasks, .threads, .channels, .members].contains($0.table)) || $0.table == .profiles
        }) {
            try await MacActivitySnapshot.load(store: store, workspaceId: w, connectionId: connection)
        }
        // Fetch every channel's agent turns and the notification inbox (the Deck and Agents fetch only their place's).
        Task {
            let channels = (try? await store.reader.channels(workspaceId: w))?.map(\.id) ?? []
            model.openAgents(workspace, channelIds: channels)
            model.openNotifications()
        }
    }
}

extension AppModel {
    /// Opens an Activity row's record in its own place; returns a notification that has no screen, to show as text.
    func openActivityItem(_ item: MacActivityItem) -> NotificationItem? {
        switch item.target {
        case .thread(let channel, let thread):
            openInChat(channelId: channel, threadId: thread.isEmpty ? nil : thread)
        case .task(let id):
            openRecord(kind: "task", id: id)
        case .notification(let note):
            if case .detail = openNotification(note) {
                if note.isUnread { changeNotification(.markRead, note) }
                return note
            }
        }
        return nil
    }
}

/// The sidebar's count beside Activity: how many things need you.
struct MacActivityCount: View {
    @Environment(AppModel.self) private var model
    @State private var snapshot = LiveQuery<MacActivitySnapshot>(initial: MacActivitySnapshot())

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { _ in
            let origin = model.connection.flatMap { try? TowerOrigin($0.origin).description }
            let count = snapshot.value.needsCount(now: ServerClock.shared.now(origin: origin))
            if count > 0 {
                Text("\(count)").font(.amb(.caption2).weight(.semibold)).foregroundStyle(Amb.primary)
                    .accessibilityLabel("\(count) need you")
            }
        }
        .task(id: model.selectedWorkspace?.id) { start() }
    }

    private func start() {
        guard let w = model.selectedWorkspace?.id, let store = model.store else { return }
        let connection = model.connection?.id
        snapshot.start(store: store, matches: {
            ($0.workspaceId == w && [.agents, .notifications, .tasks, .threads, .channels].contains($0.table)) || $0.table == .profiles
        }) {
            try await MacActivitySnapshot.load(store: store, workspaceId: w, connectionId: connection)
        }
    }
}
