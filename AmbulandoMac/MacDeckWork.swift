import AmbulandoCore
import SwiftUI

/// UX lab (round 8, 8.2b): the Mac Deck as the place's work. The greeting on its own line (with how many things need you
/// here), one row of drawers (Agents, Apps, Canvases, Pinned here), then Needs you, In progress and Just finished as
/// three equal columns, five items each: the Activity page's sections for this place. The Inbox feed, which repeated the
/// tabs, is gone from the Mac Deck. iPhone and iPad keep their Deck cards.
struct MacDeckWork: View {
    @Environment(AppModel.self) private var model
    let workspace: WorkspaceRecord
    let store: LocalStore

    @State private var launchers = LiveQuery<MacDeckLaunchers>(initial: MacDeckLaunchers())
    @State private var canvases = LiveQuery<[CanvasRecord]>(initial: [])
    @State private var activity = LiveQuery<MacActivitySnapshot>(initial: MacActivitySnapshot())
    @State private var expanded: String?
    @State private var detail: NotificationItem?

    /// Each column shows this many items; the rest are on the Activity page.
    static let perColumn = 6

    private var origin: String? { model.connection.flatMap { try? TowerOrigin($0.origin).description } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: AgentLiveness.refreshInterval)) { _ in
            let items = placeItems()
            let needs = items.filter { $0.section == .needs }.count
            GeometryReader { geometry in
                let wide = geometry.size.width >= 760
                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        greeting(needs: needs)
                        drawers(columns: wide ? 4 : 2)
                        // The columns run to the foot of the window, so a quiet place still reads as three lanes.
                        columns(items, wide: wide, minHeight: wide ? max(geometry.size.height - 330, 260) : 0)
                    }
                    .frame(maxWidth: 1080, alignment: .leading)
                    .padding(.horizontal, 40).padding(.top, 32).padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Amb.background)
        .task(id: workspace.id) { start() }
        .sheet(item: $detail) { NotificationDetailView(item: $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck.desktop")
    }

    // MARK: Greeting

    private func greeting(needs: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DeckGreeting.line(name: launchers.value.name))
                    .font(.amb(.title2).weight(.bold)).foregroundStyle(Amb.foreground)
                Text([Date().formatted(.dateTime.weekday(.wide).day().month(.wide)),
                      needs == 0 ? "Nothing needs you here" : "\(needs) \(needs == 1 ? "thing needs" : "things need") you here"]
                    .joined(separator: " · "))
                    .font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("deck.welcome")
            Spacer(minLength: 8)
            Button { model.composingThread = true } label: { Label("New thread", systemImage: "square.and.pencil") }
                .buttonStyle(.ambSecondary)
                .accessibilityLabel("New thread")
                .accessibilityIdentifier("deck.inbox.new")
        }
    }

    // MARK: Drawers

    private func drawers(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: columns), alignment: .leading, spacing: 18) {
            drawer("Agents", kind: "agents", noun: "agents", items: agentItems, empty: "No personal agents yet.")
            drawer("Apps", kind: "apps", noun: "apps", items: appItems, empty: nil) {
                Button { model.show(.toolbox) } label: { MacLauncherAddPill(title: "Manage apps") }
                    .buttonStyle(.plain).accessibilityIdentifier("deck.apps.manage")
            }
            drawer("Canvases", kind: "canvases", noun: "canvases", items: canvasItems, empty: "No canvases yet.") {
                NewCanvasButton(workspace: workspace)
            }
            drawer(model.context.isHome ? "Pinned" : "Pinned here", kind: "pins", noun: "pins", items: pinItems,
                   empty: model.context.isHome ? "Nothing pinned yet." : "Nothing pinned here.")
        }
    }

    private func drawer<Footer: View>(_ title: String, kind: String, noun: String, items: [MacLauncherItem], empty: String?,
                                      @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.amb(.caption).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
            if !items.isEmpty {
                MacLauncherStack(kind: kind, noun: noun, items: items, workspace: workspace, expanded: $expanded, footer: footer)
            } else if kind == "apps" {
                Button { model.show(.toolbox) } label: { MacLauncherAddPill(title: "Choose apps") }
                    .buttonStyle(.plain).accessibilityIdentifier("deck.apps.choose")
            } else if let empty {
                Text(empty).font(.amb(.footnote)).foregroundStyle(Amb.faint)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 12)
                    .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel).stroke(Amb.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck.drawer.\(kind)")
    }

    private var agentItems: [MacLauncherItem] {
        let people = launchers.value.people
        return launchers.value.agents.map { agent in
            MacLauncherItem(id: agent.npub, title: people.name(agent.npub), subtitle: agentLine(agent.npub, url: agent.safeURL),
                            url: agent.safeURL, logo: .person(people.person(agent.npub)), identifier: "deck.agent.\(agent.npub)")
        }
    }

    /// "Working" when the agent has a live turn in this place, else where it opens.
    private func agentLine(_ npub: String, url: URL?) -> String {
        let now = ServerClock.shared.now(origin: origin)
        let channels = placeChannels
        if activity.value.activities.contains(where: { $0.agentNpub == npub && (channels == nil || channels!.contains($0.channelId))
            && AgentLiveness.phase($0, now: now).isLive }) { return "Working" }
        return url == nil ? "Can't open right now" : "Open in Autopilot"
    }

    private var appItems: [MacLauncherItem] {
        launchers.value.apps.compactMap { app -> MacLauncherItem? in
            guard let url = app.safeLaunchURL else { return nil }
            return MacLauncherItem(id: app.id, title: app.title, subtitle: app.description ?? "App", url: url,
                                   logo: .app(app.logoCandidates, initials: PersonInitials.of(app.title)), identifier: "deck.app.\(app.title)")
        } + launchers.value.napplets.map { n in
            MacLauncherItem(id: "napplet:" + n.key, title: n.title, subtitle: "Workspace app", url: nil,
                            logo: .app([], initials: PersonInitials.of(n.title)), identifier: "deck.napplet.\(n.key)", nappletKey: n.key)
        }
    }

    private var canvasItems: [MacLauncherItem] {
        let w = workspace.id
        return canvases.value.map { canvas in
            MacLauncherItem(id: canvas.id, title: canvas.title, subtitle: canvas.updatedAt.isEmpty ? "Canvas" : "Updated " + ChatTime.label(canvas.updatedAt),
                            url: nil, logo: .symbol("rectangle.3.group"), identifier: "canvas.\(canvas.title)") { [model] in
                model.canvasWindowRequest = CanvasWindowRoute(workspaceId: w, canvasId: canvas.id)
            }
        }
    }

    /// Your pins in this place (all of them at Home), in your order.
    private var pinItems: [MacLauncherItem] {
        let pins = model.pins.value
        let context = model.context
        return pins.items.filter { item in
            guard pins.isPinned(item.pin.resourceType, item.pin.resourceId) else { return false }
            if let channel = context.channelId { return (item.channelId ?? item.pin.channelId) == channel || (item.pin.resourceType == .channel && item.pin.resourceId == channel) }
            if let scope = context.scopeId { return (item.scopeId ?? item.pin.scopeId) == scope }
            return true
        }.map { item in
            let (kind, symbol): (String, String) = switch item.pin.resourceType {
            case .thread: ("Conversation", "bubble.left")
            case .task: ("Task", "checklist")
            case .document: ("Document", "doc.text")
            case .channel: ("Channel", "number")
            }
            return MacLauncherItem(id: item.id, title: item.title ?? "Not available", subtitle: kind, url: nil, logo: .symbol(symbol),
                                   identifier: "deck.pinned.\(item.title ?? item.pin.resourceId)") { [model] in
                switch item.pin.resourceType {
                case .channel: model.openInChat(channelId: item.pin.resourceId)
                case .thread: model.openRecord(kind: "thread", id: item.pin.resourceId)
                case .task: model.openRecord(kind: "task", id: item.pin.resourceId)
                case .document: model.openRecord(kind: "doc", id: item.pin.resourceId)
                }
            }
        }
    }

    // MARK: Work columns

    /// The channels of the place (nil at Home: everything).
    private var placeChannels: Set<String>? {
        model.context.isHome ? nil : Set(model.navigation.value.channels(in: model.context).map(\.id))
    }

    private func placeItems() -> [MacActivityItem] {
        let all = activity.value.items(now: ServerClock.shared.now(origin: origin), seen: nil, team: true)
        guard let channels = placeChannels else { return all }
        return all.filter { $0.channelId.map(channels.contains) ?? false }
    }

    @ViewBuilder private func columns(_ items: [MacActivityItem], wide: Bool, minHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            if wide {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(MacActivityItem.Section.allCases.enumerated()), id: \.element) { index, section in
                        if index > 0 { Rectangle().fill(Amb.border).frame(width: 1).frame(minHeight: minHeight) }
                        column(section, items.filter { $0.section == section }, minHeight: minHeight)
                            .padding(.leading, index == 0 ? 0 : 20).padding(.trailing, index == 2 ? 0 : 20)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(MacActivityItem.Section.allCases) { section in column(section, items.filter { $0.section == section }, minHeight: 0) }
                }
            }
            Button { model.show(.activity) } label: {
                Text("All activity →").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
            }
            .buttonStyle(.plain).ambHover()
            .accessibilityIdentifier("deck.activity")
        }
    }

    private func column(_ section: MacActivityItem.Section, _ rows: [MacActivityItem], minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(.amb(.subheadline).weight(.semibold))
                    .foregroundStyle(section == .needs && !rows.isEmpty ? Amb.brandOrange : Amb.foreground)
                Text("\(rows.count)").font(.amb(.footnote)).foregroundStyle(Amb.faint)
            }
            .padding(.bottom, 10)
            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: section.emptySymbol).font(.amb(.title3)).foregroundStyle(Amb.faint)
                    Text(section.deckEmpty).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 36)
            } else {
                Rectangle().fill(Amb.border).frame(height: 1)
                ForEach(rows.prefix(Self.perColumn)) { row($0) }
                if rows.count > Self.perColumn {
                    Button { model.show(.activity) } label: {
                        Text("\(rows.count - Self.perColumn) more").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    }
                    .buttonStyle(.plain).padding(.top, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck.column.\(section.rawValue)")
    }

    /// Up to three lines: the title; what's happening (an agent's latest line, who has the task, the notice); state and time.
    private func row(_ item: MacActivityItem) -> some View {
        Button { if let note = model.openActivityItem(item) { detail = note } } label: {
            HStack(alignment: .top, spacing: 10) {
                mark(item.mark).frame(width: 20).padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.amb(.subheadline).weight(.medium)).foregroundStyle(Amb.foreground).lineLimit(2)
                    if !item.detail.isEmpty {
                        Text(item.detail).font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground).lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text(item.tag.label).foregroundStyle(item.tag.tinted ? item.tag.color : Amb.mutedForeground)
                        Text("·").foregroundStyle(Amb.faint)
                        Text(ChatTime.label(item.iso)).foregroundStyle(Amb.mutedForeground)
                    }
                    .font(.amb(.caption)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(AmbTableRule())
        .accessibilityIdentifier("deck.work.row")
    }

    @ViewBuilder private func mark(_ mark: MacActivityItem.Mark) -> some View {
        switch mark {
        case .person(let npub):
            PersonAvatar(person: activity.value.people.person(npub), size: 20, agent: activity.value.people.isAgent(npub))
        case .task(let state):
            TaskStatusRing(state: state)
        case .symbol(let name):
            Image(systemName: name).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
        }
    }

    // MARK: Loading

    private func start() {
        let w = workspace.id, store = store, connection = model.connection?.id ?? "", me = model.connection?.signerNpub
        let connectionId = model.connection?.id
        launchers.start(store: store, matches: { $0.table == .appState || ($0.workspaceId == w && [.toolbox, .members, .agents].contains($0.table)) || $0.table == .profiles }) {
            async let apps = store.reader.personalWapps(connectionId: connection, workspaceId: w)
            async let members = store.reader.members(workspaceId: w)
            let saved = try await store.reader.state(WorkspaceSync.personalAgentsKey(connection, w))
            let agents = saved.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode([PersonalAgentLauncher].self, from: $0) } ?? []
            let people = try await store.reader.people(workspaceId: w)
            return MacDeckLaunchers(name: try await members.first { $0.npub == me }?.label, apps: try await apps,
                                    napplets: try await store.reader.installedNapplets(connectionId: connection, workspaceId: w), agents: agents, people: people)
        }
        canvases.start(store: store, matches: { $0.workspaceId == w && $0.table == .canvases }) { try await store.reader.canvases(workspaceId: w) }
        activity.start(store: store, matches: {
            ($0.workspaceId == w && [.agents, .notifications, .tasks, .threads, .channels, .members].contains($0.table)) || $0.table == .profiles
        }) {
            try await MacActivitySnapshot.load(store: store, workspaceId: w, connectionId: connectionId)
        }
        model.openToolbox(workspace)
        model.openCanvases(workspace)
        model.openNotifications()
        if let sync = model.sync, let connection = model.connection { Task { await sync.refreshPersonalAgentLaunchers(connection, workspace) } }
        Task {
            let channels = (try? await store.reader.channels(workspaceId: w))?.map(\.id) ?? []
            model.openAgents(workspace, channelIds: channels)
        }
    }
}

extension MacActivityItem.Section {
    /// The Deck's empty column: a mark and one line that says what would appear there.
    var emptySymbol: String {
        switch self {
        case .needs: "checkmark.circle"
        case .progress: "circle.dashed"
        case .finished: "flag"
        }
    }
    var deckEmpty: String {
        switch self {
        case .needs: "Nothing needs you here."
        case .progress: "Nothing is in progress here.\nAgents at work and tasks underway appear here."
        case .finished: "Nothing finished here in the last two weeks."
        }
    }
}
