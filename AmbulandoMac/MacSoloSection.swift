import AmbulandoCore
import SwiftUI

/// UX lab (Phase 4): the sidebar's Solo section. One row per conversation with your agents (and Note to self), newest
/// activity first; choosing one opens it full width in Chat. + starts a new chat with an agent.
struct MacSoloSection: View {
    @Environment(AppModel.self) private var model
    let solo: SoloSnapshot
    let loaded: Bool
    /// No DM with that agent yet: upstream's New message sheet for the DM scope starts one.
    let startDirectMessage: () -> Void
    @State private var showsAll = false
    @State private var menu = NativeMessageActions.Coordinator(items: [])

    private static let shownByDefault = 8

    var body: some View {
        SidebarSectionHeading(text: "Solo") {
            SidebarRowButton(systemImage: "plus", accessibilityLabel: "New chat with an agent", identifier: "sidebar.solo.new") {
                menu.openAtAnchor()
            }
            .background(NativeMenuAnchor(items: newChatItems, presenter: menu, identifier: "sidebar.solo.new.anchor"))
        }
        let all = solo.conversations
        if loaded && all.isEmpty {
            Text("Private conversations with your agents appear here.")
                .font(.amb(.footnote)).foregroundStyle(Amb.faint).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Amb.SidebarLayout.inset).padding(.vertical, 4)
        }
        ForEach(showsAll ? all : Array(all.prefix(Self.shownByDefault))) { item in
            row(item)
        }
        if all.count > Self.shownByDefault {
            SidebarRow(label: showsAll ? "Show fewer" : "Show all (\(all.count))", identifier: "sidebar.solo.showAll",
                       action: { showsAll.toggle() }) {
                Image(systemName: showsAll ? "chevron.up" : "ellipsis").font(.amb(.caption)).foregroundStyle(Amb.faint)
            }
        }
    }

    private func row(_ item: SoloConversation) -> some View {
        let selected = model.mode == .chat && model.focusedThread?.threadId == item.conversation.root.threadId
        let unread = item.conversation.unread
        return TimelineView(.periodic(from: .now, by: 15)) { context in
            let working = workingAgent(item, now: context.date) != nil
            SidebarRow(label: item.title, selected: selected, unread: unread, hasRowAction: false,
                       accessibilityLabel: item.title + (working ? ", agent working" : ""),
                       identifier: "sidebar.solo.\(item.title)", action: { open(item) }) {
                if let agent = item.agent {
                    PersonAvatar(person: solo.people.person(agent), size: Amb.SidebarLayout.iconSlot, agent: true)
                } else {
                    Image(systemName: "note.text").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
                }
            } status: {
                if working { ProgressView().controlSize(.mini) } else if unread { SidebarUnreadDot() }
            } rowAction: { EmptyView() }
            .ambTooltip(item.agent.map { "With \(solo.people.name($0))" } ?? "Note to self")
        }
    }

    /// An agent still working in this conversation (as the channel list shows it).
    private func workingAgent(_ item: SoloConversation, now: Date) -> String? {
        let origin = model.connection.flatMap { try? TowerOrigin($0.origin).description }
        let serverNow = ServerClock.shared.now(origin: origin)
        return item.conversation.activities.first { AgentLiveness.phase($0, now: serverNow).isLive }?.agentNpub
    }

    /// Opens the conversation in place in its DM (Chat), which shows it full width as a Solo conversation.
    private func open(_ item: SoloConversation) {
        guard let thread = item.conversation.root.threadId else { return }
        let focus = ThreadFocus(workspaceId: item.channel.workspaceId, channelId: item.channel.id, threadId: thread)
        if model.mode == .chat && model.context.channelId == item.channel.id {
            model.focusThread(focus)
            return
        }
        // The DM's channel view reopens this thread as it appears (`restoreInlineThread`).
        InlineThreadMemory.shared.remember(focus, channel: item.channel.id)
        model.selectContext(WorkContext(scopeId: item.channel.scopeId, channelId: item.channel.id))
        model.show(.chat)
    }

    private var viewer: String? { model.connection?.signerNpub ?? model.identity.npub }

    private var newChatItems: [NativeMessageAction] {
        var items = solo.agents.map { agent in
            NativeMessageAction(solo.people.name(agent), "sparkles") { newChat(with: agent) }
        }
        items.append(NativeMessageAction("Note to self", "note.text") { newChat(with: nil) })
        return items
    }

    /// A new conversation in your DM with `agent` (nil: Note to self), or upstream's New message sheet when there isn't one.
    private func newChat(with agent: String?) {
        let wanted = agent.map { [$0] } ?? []
        guard let channel = solo.channels.first(where: { SidebarNavigation.participants($0).filter { $0 != viewer } == wanted }) else {
            startDirectMessage()
            return
        }
        InlineThreadMemory.shared.remember(nil, channel: channel.id)
        if model.focusedThread?.channelId == channel.id { model.focusedThread = nil }
        SoloDirectory.shared.composeRequest = channel.id
        model.selectContext(WorkContext(scopeId: channel.scopeId, channelId: channel.id))
        model.show(.chat)
    }
}
