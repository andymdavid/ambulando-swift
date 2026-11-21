import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac, Phase 5.2): the Chat tab at Home or a scope lists every conversation in the place, newest activity
/// first: the channel's own conversation list, spanning its channels, each row saying where it lives (# channel, or the
/// DM's person, agent or Note to self). Replaces the plain channel directory, which repeated the sidebar. Filters are
/// about state (All, Unread, Mine), not type: the sidebar and place header already separate Solo, scopes and people.
/// A conversation opens in place of the list, as in a channel; New thread asks which channel.
struct MacPlaceConversations: View {
    @Environment(AppModel.self) private var model
    let workspace: WorkspaceRecord
    let store: LocalStore
    @State private var snapshot = LiveQuery<PlaceConversationsSnapshot>(initial: PlaceConversationsSnapshot())
    @State private var filter: ChannelConversationList.Filter = .all

    /// Conversations read per channel; the merged list keeps the newest.
    private static let perChannel = 40
    private static let shown = 200

    private var me: String? { model.identity.npub }

    /// The place's channels: one scope's, or every channel at Home.
    private var channels: [ChannelRecord] {
        let nav = model.navigation.value
        let scopeId = model.context.scopeId
        return nav.groups.filter { scopeId == nil || $0.id == scopeId }.flatMap(\.channels)
    }

    private var conversations: [ChannelConversation] {
        let all = snapshot.value.conversations
        switch filter {
        case .all: return all
        case .unread: return all.filter(\.unread)
        case .mine: return all.filter { c in me.map { c.participants.contains($0) || c.root.senderNpub == $0 } ?? false }
        }
    }

    var body: some View {
        let nav = model.navigation.value
        let ids = Set(channels.map { $0.id.lowercased() })
        VStack(spacing: 0) {
            header.chatColumn()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversations) { conversation in
                        let channel = nav.channel(conversation.root.channelId)
                        ConversationRow(conversation: conversation, workspace: workspace, people: snapshot.value.people,
                                        title: ChannelConversationList.title(conversation, threadTitles: snapshot.value.threadTitles), me: me,
                                        place: channel.map { ConversationPlace.of($0, nav: nav, viewer: model.connection?.signerNpub) })
                    }
                    if snapshot.loaded && conversations.isEmpty { empty }
                }
                .padding(.bottom, Amb.Space.l)
                .chatColumn()
            }
        }
        .background(Amb.background)
        // A conversation opened here replaces the list until you go back, as in a channel.
        .overlay {
            if let focus = model.focusedThread, InlineThreadHosts.shared.hosts(focus, mode: model.mode),
               let channel = focus.channelId?.lowercased(), ids.contains(channel) {
                ThreadFocusPanel(focus: focus, expanded: .constant(false), modal: false, inline: true)
                    .id(focus.id)
                    .environment(\.openURL, OpenURLAction { model.browser.handleLink($0) })
            }
        }
        .onAppear { for id in ids { InlineThreadHosts.shared.add(id) } }
        .onDisappear {
            for id in ids { InlineThreadHosts.shared.remove(id) }
            if let channel = model.focusedThread?.channelId?.lowercased(), ids.contains(channel) { model.focusedThread = nil }
        }
        .onChange(of: model.mode) { _, mode in
            if mode != .chat, let channel = model.focusedThread?.channelId?.lowercased(), ids.contains(channel) { model.focusedThread = nil }
        }
        .task(id: channels.map(\.id)) { start() }
        .onChange(of: nav.groups.isEmpty, initial: true) { _, empty in if !empty { model.markCachedListShown() } }
        .accessibilityIdentifier("chat.place.conversations")
    }

    private var header: some View {
        HStack(spacing: Amb.Space.s) {
            HStack(spacing: 2) {
                ForEach(ChannelConversationList.Filter.allCases, id: \.self) { option in
                    Button(option.rawValue) { filter = option }
                        .buttonStyle(.plain)
                        .font(.amb(.footnote).weight(.medium))
                        .foregroundStyle(filter == option ? Amb.foreground : Amb.mutedForeground)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(filter == option ? Amb.selectedFill : .clear, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
                        .accessibilityAddTraits(filter == option ? .isSelected : [])
                        .accessibilityIdentifier("place.filter.\(option.rawValue.lowercased())")
                }
            }
            Spacer(minLength: 0)
            Button { model.composingThread = true } label: { Label("New thread", systemImage: "square.and.pencil") }
                .buttonStyle(.ambPrimary)
                .accessibilityIdentifier("place.newThread")
        }
        .padding(.horizontal, 12).frame(minHeight: Amb.ListLayout.toolbarHeight)   // centred, as every list's toolbar
    }

    @ViewBuilder private var empty: some View {
        let text = channels.isEmpty ? "No channels here."
            : filter == .all ? "No conversations yet. Start one with New thread."
            : filter == .unread ? "You're all caught up." : "No conversations you've taken part in."
        Text(text).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func start() {
        let w = workspace.id, store = store, connection = model.connection?.id ?? "", ids = channels.map(\.id)
        let perChannel = Self.perChannel, shown = Self.shown
        snapshot.start(store: store, matches: { key in
            ((key.workspaceId == w || key.workspaceId == nil) && [.messages, .threads, .channels, .members, .agents, .viewStates].contains(key.table))
                || key.table == .profiles
        }) {
            var all: [ChannelConversation] = [], titles: [String: String] = [:]
            for id in ids {
                all += try await store.reader.channelConversations(workspaceId: w, channelId: id, limit: perChannel)
                titles.merge(try await store.reader.threadTitles(workspaceId: w, channelId: id)) { a, _ in a }
            }
            all.sort { $0.lastActivityAt > $1.lastActivityAt }
            let people = try await store.reader.people(connectionId: connection, workspaceId: w)
            return PlaceConversationsSnapshot(conversations: Array(all.prefix(shown)), people: people, threadTitles: titles)
        }
    }
}

struct PlaceConversationsSnapshot: Sendable, Equatable {
    var conversations: [ChannelConversation] = []
    var people = PeopleDirectory()
    var threadTitles: [String: String] = [:]
}
#endif
