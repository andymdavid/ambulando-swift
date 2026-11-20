import AmbulandoCore
import SwiftUI

/// UX lab (Phase 4): the sidebar's Solo section, which works like a scope: its rows are your DMs with agents (and Note to
/// self), most recent activity first. Each is a place with all its tabs; its Chat tab lists every conversation with
/// that agent. + starts a new chat with an agent.
struct MacSoloSection: View {
    @Environment(AppModel.self) private var model
    let solo: SoloSnapshot
    let loaded: Bool
    /// No DM with that agent yet: upstream's New message sheet for the DM scope starts one.
    let startDirectMessage: () -> Void
    @State private var menu = NativeMessageActions.Coordinator(items: [])

    var body: some View {
        SidebarSectionHeading(text: "Solo") {
            SidebarRowButton(systemImage: "plus", accessibilityLabel: "New chat with an agent", identifier: "sidebar.solo.new") {
                menu.openAtAnchor()
            }
            .background(NativeMenuAnchor(items: newChatItems, presenter: menu, identifier: "sidebar.solo.new.anchor"))
        }
        if loaded && solo.channels.isEmpty {
            Text("Your private chats with agents appear here.")
                .font(.amb(.footnote)).foregroundStyle(Amb.faint).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Amb.SidebarLayout.inset).padding(.vertical, 4)
        }
        ForEach(channels) { channel in row(channel) }
    }

    /// Solo DMs, most recent conversation first.
    private var channels: [ChannelRecord] {
        let latest = Dictionary(solo.conversations.map { ($0.channel.id, $0.conversation.lastActivityAt) }, uniquingKeysWith: max)
        return solo.channels.sorted { (latest[$0.id] ?? "") > (latest[$1.id] ?? "") }
    }

    private func row(_ channel: ChannelRecord) -> some View {
        let nav = model.navigation.value
        let label = nav.label(channel)
        let agent = SidebarNavigation.participants(channel).first { $0 != viewer }
        let unread = nav.unread.contains(channel.id)
        return TimelineView(.periodic(from: .now, by: 15)) { context in
            let working = isWorking(channel, now: context.date)
            SidebarRow(label: label, selected: model.mode != .toolbox && model.context.channelId == channel.id, unread: unread,
                       accessibilityLabel: label + (working ? ", agent working" : ""), identifier: "sidebar.solo.\(label)",
                       action: { model.choosePlace(WorkContext(scopeId: channel.scopeId, channelId: channel.id)) }) {
                if let agent {
                    PersonAvatar(person: solo.people.person(agent), size: Amb.SidebarLayout.iconSlot, agent: true)
                } else {
                    Image(systemName: "note.text").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
                }
            } status: {
                if working { ProgressView().controlSize(.mini) } else if unread { SidebarUnreadDot() }
            } rowAction: { EmptyView() }
        }
    }

    /// An agent still working in one of this DM's conversations (as the channel list shows it).
    private func isWorking(_ channel: ChannelRecord, now: Date) -> Bool {
        let origin = model.connection.flatMap { try? TowerOrigin($0.origin).description }
        let serverNow = ServerClock.shared.now(origin: origin)
        return solo.conversations.contains { item in
            item.channel.id == channel.id && item.conversation.activities.contains { AgentLiveness.phase($0, now: serverNow).isLive }
        }
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
