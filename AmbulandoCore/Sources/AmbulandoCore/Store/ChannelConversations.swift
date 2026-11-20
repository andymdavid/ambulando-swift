import Foundation

/// UX lab: one conversation in a channel's list, as the Mac channel view shows it (newest activity first): its first
/// message, how many replies, the newest reply, who has taken part, whether it has unread activity, and any agent
/// lifecycles in it.
public struct ChannelConversation: Sendable, Equatable, Identifiable {
    public let root: MessageRecord
    public let replyCount: Int
    /// The newest reply, or the first message when there are no replies.
    public let lastActivityAt: String
    public let latestReply: MessageRecord?
    /// Distinct senders, most recent first (at most four).
    public let participants: [String]
    public let unread: Bool
    public let activities: [AgentActivityRecord]
    public var id: String { root.id }
}

extension StoreReader {
    /// The channel's conversations, newest activity first. Uses the same rule as `channelFeed` for which message starts
    /// a conversation (the thread's source message, or its earliest stored message when the source is missing).
    public func channelConversations(workspaceId: String, channelId: String, limit: Int) throws -> [ChannelConversation] {
        let columns = Self.messageColumns.split(separator: ",").map { "m." + $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ", ")
        let s = try db.prepare("""
        SELECT \(columns),
          (SELECT COUNT(*) FROM messages r WHERE r.workspace_id = m.workspace_id AND r.thread_id = m.thread_id AND r.id <> m.id AND r.deleted = 0),
          COALESCE((SELECT MAX(r.created_at) FROM messages r WHERE r.workspace_id = m.workspace_id AND r.thread_id = m.thread_id AND r.id <> m.id AND r.deleted = 0),
                   m.created_at) AS last_activity
        FROM messages m
        WHERE m.workspace_id = ? AND m.channel_id = ? AND m.deleted = 0 AND (
          m.thread_id IS NULL OR m.thread_source_id = m.id
          OR (NOT EXISTS (SELECT 1 FROM messages s WHERE s.workspace_id = m.workspace_id AND s.thread_id = m.thread_id
                          AND s.deleted = 0 AND s.thread_source_id = s.id)
              AND NOT EXISTS (SELECT 1 FROM messages e WHERE e.workspace_id = m.workspace_id AND e.thread_id = m.thread_id AND e.deleted = 0
                              AND (e.created_at < m.created_at OR (e.created_at = m.created_at AND e.id < m.id)))))
        ORDER BY last_activity DESC, m.id DESC LIMIT ?
        """)
        try s.bind([.text(workspaceId), .text(channelId), .int(Int64(limit))])
        var heads: [(MessageRecord, Int, String)] = []
        while try s.step() {
            let root = Self.message(s, workspaceId: workspaceId)
            heads.append((root, Int(s.int(13)), s.text(14) ?? root.createdAt))
        }

        let unread = try unreadThreadIds(workspaceId: workspaceId, channelId: channelId)
        let activities = try channelAgentActivities(workspaceId: workspaceId, channelId: channelId)
        let latest = try db.prepare("""
        SELECT \(Self.messageColumns) FROM messages WHERE workspace_id = ? AND thread_id = ? AND id <> ? AND deleted = 0
        ORDER BY created_at DESC, id DESC LIMIT 1
        """)
        let senders = try db.prepare("""
        SELECT sender_npub, MAX(created_at) AS latest FROM messages
        WHERE workspace_id = ? AND thread_id = ? AND deleted = 0 AND sender_npub IS NOT NULL
        GROUP BY sender_npub ORDER BY latest DESC LIMIT 4
        """)
        return try heads.map { root, count, last in
            guard let thread = root.threadId, count > 0 else {
                return ChannelConversation(root: root, replyCount: 0, lastActivityAt: last, latestReply: nil,
                                           participants: root.senderNpub.map { [$0] } ?? [], unread: root.threadId.map(unread.contains) ?? false,
                                           activities: root.threadId.flatMap { activities[$0] } ?? [])
            }
            try latest.bind([.text(workspaceId), .text(thread), .text(root.id)])
            let reply = try latest.step() ? Self.message(latest, workspaceId: workspaceId) : nil
            try senders.bind([.text(workspaceId), .text(thread)])
            var people: [String] = []
            while try senders.step() { if let npub = senders.text(0) { people.append(npub) } }
            return ChannelConversation(root: root, replyCount: count, lastActivityAt: last, latestReply: reply, participants: people,
                                       unread: unread.contains(thread), activities: activities[thread] ?? [])
        }
    }

    /// Threads in a channel with activity newer than you have seen.
    func unreadThreadIds(workspaceId: String, channelId: String) throws -> Set<String> {
        let s = try db.prepare("""
        SELECT resource_id FROM view_states
        WHERE workspace_id = ? AND channel_id = ? AND resource_type = 'thread'
          AND MAX(activity_version, COALESCE(attention_activity_version, 0)) > viewed_activity_version
        """)
        try s.bind([.text(workspaceId), .text(channelId)])
        var ids = Set<String>()
        while try s.step() { if let id = s.text(0) { ids.insert(id) } }
        return ids
    }

    /// Recent agent lifecycles in a channel, by thread, newest first. Liveness is judged by the caller against Tower's clock.
    func channelAgentActivities(workspaceId: String, channelId: String) throws -> [String: [AgentActivityRecord]] {
        let s = try db.prepare("""
        SELECT raw FROM agent_activities WHERE workspace_id = ? AND channel_id = ? AND thread_id IS NOT NULL
        ORDER BY updated_at DESC LIMIT 100
        """)
        try s.bind([.text(workspaceId), .text(channelId)])
        var out: [String: [AgentActivityRecord]] = [:]
        while try s.step() {
            if let record = try? AgentActivityRecord(raw: s.blob(0)), let thread = record.threadId { out[thread, default: []].append(record) }
        }
        return out
    }
}
