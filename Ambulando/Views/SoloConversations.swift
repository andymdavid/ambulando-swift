import AmbulandoCore
import Foundation
import Observation

/// UX lab (Phase 4): "Solo" is your private work with agents: the direct-message channels in which everyone else is an
/// agent, plus Note to self. On the Mac each conversation (thread) in them is its own sidebar item and opens full width.
/// Nothing new on the Tower: these are ordinary DM channels, started with upstream's New message picker.
enum SoloConversations {
    /// A DM you are in where every other participant is an agent (none: Note to self).
    static func isSolo(_ channel: ChannelRecord, viewer: String?, people: PeopleDirectory) -> Bool {
        guard let viewer, SidebarNavigation.isDirectMessageChannel(channel) else { return false }
        let participants = SidebarNavigation.participants(channel)
        guard participants.contains(viewer) else { return false }
        return participants.filter { $0 != viewer }.allSatisfy(people.isAgent)
    }

    /// The Solo conversations among `candidates`, newest activity first.
    static func load(store: LocalStore, connectionId: String, workspaceId: String, candidates: [ChannelRecord],
                     viewer: String?, limit: Int) async throws -> SoloSnapshot {
        let people = try await store.reader.people(connectionId: connectionId, workspaceId: workspaceId)
        let channels = candidates.filter { isSolo($0, viewer: viewer, people: people) }
        var conversations: [SoloConversation] = []
        for channel in channels {
            let titles = try await store.reader.threadTitles(workspaceId: workspaceId, channelId: channel.id)
            let agent = SidebarNavigation.participants(channel).first { $0 != viewer }
            for conversation in try await store.reader.channelConversations(workspaceId: workspaceId, channelId: channel.id, limit: limit) {
                let title = conversation.root.threadId.flatMap { titles[$0] }.flatMap(usable)
                    ?? usable(MentionCodec.plain(conversation.root.body)) ?? "Conversation"
                conversations.append(SoloConversation(channel: channel, conversation: conversation, title: title, agent: agent))
            }
        }
        conversations.sort { ($0.conversation.lastActivityAt, $0.id) > ($1.conversation.lastActivityAt, $1.id) }
        let agents = people.names.keys.filter { people.isAgent($0) && $0 != viewer }
            .sorted { people.name($0).localizedCaseInsensitiveCompare(people.name($1)) == .orderedAscending }
        return SoloSnapshot(conversations: conversations, channelIds: Set(channels.map(\.id)), people: people, agents: agents,
                            channels: channels)
    }

    /// The first line, trimmed; nil when empty.
    private static func usable(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return line.isEmpty ? nil : line
    }
}

/// One Solo conversation in the sidebar.
struct SoloConversation: Sendable, Equatable, Identifiable {
    let channel: ChannelRecord
    let conversation: ChannelConversation
    let title: String
    /// The agent in this DM; nil for Note to self.
    let agent: String?
    var id: String { conversation.id }
}

struct SoloSnapshot: Sendable, Equatable {
    var conversations: [SoloConversation] = []
    var channelIds: Set<String> = []
    var people = PeopleDirectory()
    /// The workspace's agents, by name, for New chat.
    var agents: [String] = []
    var channels: [ChannelRecord] = []
}

/// The channels that are Solo right now (kept by the Mac sidebar), so a thread opened in one shows as a Solo
/// conversation: no "back to the channel", since its channel's list isn't a place of its own.
@MainActor @Observable final class SoloDirectory {
    static let shared = SoloDirectory()
    var channelIds: Set<String> = []
    /// A New chat waiting for its DM's conversation list to open the composer (that channel's id).
    var composeRequest: String?
    func contains(_ channelId: String?) -> Bool { channelId.map { channelIds.contains($0) } ?? false }
}
