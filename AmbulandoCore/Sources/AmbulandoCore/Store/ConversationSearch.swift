import Foundation

/// UX lab: searching a conversation list (the Mac Chat tab, a channel). Matches every stored message's text in the
/// given channels through the full-text index, so older conversations than the list holds can be found too.
extension StoreReader {
    /// Messages in these channels whose text matches, newest first; this device's records only, never the network.
    public func conversationMatches(workspaceId: String, channelIds: [String], text: String, limit: Int = 200) throws -> [MessageRecord] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, !channelIds.isEmpty else { return [] }
        let channels = channelIds.map { _ in "?" }.joined(separator: ", ")
        let match: String, values: [SQLValue]
        if hasFTS, let query = SearchIndex.ftsQuery(trimmed) {
            match = "id IN (SELECT record_id FROM search_index WHERE search_index MATCH ? AND workspace_id = ? AND kind = 'message')"
            values = [.text(query), .text(workspaceId)]
        } else {
            match = "body LIKE ?"
            values = [.text("%" + trimmed.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "_", with: "") + "%")]
        }
        let s = try db.prepare("""
        SELECT \(Self.messageColumns) FROM messages
        WHERE workspace_id = ? AND deleted = 0 AND channel_id IN (\(channels)) AND \(match)
        ORDER BY created_at DESC, id DESC LIMIT ?
        """)
        try s.bind([.text(workspaceId)] + channelIds.map { .text($0) } + values + [.int(Int64(limit))])
        var out: [MessageRecord] = []
        while try s.step() { out.append(Self.message(s, workspaceId: workspaceId)) }
        return out
    }
}
