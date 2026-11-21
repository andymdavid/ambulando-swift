import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac): the toolbar over a list of conversations (the Chat tab, a channel), the same bar as Tasks' and Docs':
/// search, then All / Unread / Mine as a quiet segmented switch, then New thread. Full width; the list below keeps
/// the chat column.
struct ConversationListToolbar<Trailing: View>: View {
    @Binding var search: String
    @Binding var filter: ChannelConversationList.Filter
    /// "place" (the Chat tab) or "channel", for accessibility identifiers.
    let identifier: String
    let newThread: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ListHeaderBar {
            AmbTableSearchField(prompt: "Search chats", text: $search, identifier: "\(identifier).search")
            Picker("Show", selection: $filter) {
                ForEach(ChannelConversationList.Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .tint(Amb.selectedFill)   // as Tasks' list/board switch: quiet, not the accent
            .accessibilityIdentifier("\(identifier).filter")
            Spacer(minLength: 0)
            trailing()
            // The label gives way to its icon in a narrow window, as New task and New document.
            ViewThatFits(in: .horizontal) {
                Button(action: newThread) { Label("New thread", systemImage: "square.and.pencil").fixedSize() }
                    .buttonStyle(.ambPrimary).accessibilityIdentifier("\(identifier).newThread")
                Button(action: newThread) { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.ambPrimary).ambTooltip("New thread").accessibilityLabel("New thread")
                    .accessibilityIdentifier("\(identifier).newThread")
            }
        }
    }
}

#endif

/// What a conversation list's search found in the store: the newest matching message per conversation, and the
/// matching conversations older than the list holds.
struct ConversationSearchResult: Equatable {
    var query = ""
    var matches: [String: MessageRecord] = [:]
    var older: [ChannelConversation] = []
}

enum ConversationSearch {
    /// A conversation's key: its thread, or its one message when it has no thread.
    static func key(_ c: ChannelConversation) -> String { c.root.threadId ?? c.root.id }
    static func key(_ m: MessageRecord) -> String { m.threadId ?? m.id }

    static func active(_ query: String) -> Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    /// Every stored message in these channels, through the full-text index; then the conversations it found that the
    /// list doesn't hold.
    static func run(store: LocalStore, workspaceId: String, channelIds: [String], query: String,
                    loaded: Set<String>) async -> ConversationSearchResult {
        guard active(query) else { return ConversationSearchResult() }
        let found = (try? await store.reader.conversationMatches(workspaceId: workspaceId, channelIds: channelIds, text: query)) ?? []
        var matches: [String: MessageRecord] = [:], channels: [String: Set<String>] = [:]
        for message in found where matches[key(message)] == nil {   // newest first: keep the newest match
            matches[key(message)] = message
            if !loaded.contains(key(message)) { channels[message.channelId, default: []].insert(key(message)) }
        }
        var older: [ChannelConversation] = []
        for (channel, keys) in channels {
            older += (try? await store.reader.channelConversations(workspaceId: workspaceId, channelId: channel, limit: keys.count, only: keys)) ?? []
        }
        return ConversationSearchResult(query: query, matches: matches, older: older)
    }

    /// The list while searching: conversations whose own words (title, people, place) or any stored message match,
    /// with the older ones found, newest activity first.
    static func filter(_ list: [ChannelConversation], query: String, result: ConversationSearchResult,
                       words: (ChannelConversation) -> [String]) -> [ChannelConversation] {
        guard active(query) else { return list }
        let q = query.trimmingCharacters(in: .whitespaces)
        let hit: (ChannelConversation) -> Bool = { c in
            result.matches[key(c)] != nil || words(c).contains { $0.localizedStandardContains(q) }
        }
        var seen = Set<String>()
        return (list.filter(hit) + result.older.filter(hit))
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    /// The message to quote on a row while searching: the newest stored match, else the opening or newest reply when
    /// it holds the words.
    static func matchedMessage(_ c: ChannelConversation, query: String, result: ConversationSearchResult) -> MessageRecord? {
        guard active(query) else { return nil }
        let q = query.trimmingCharacters(in: .whitespaces)
        if let match = result.matches[key(c)] { return match }
        return [c.latestReply, c.root].compactMap { $0 }.first { MentionCodec.plain($0.body).localizedStandardContains(q) }
    }

    /// One line of the message around the first matching word, each word in bold.
    static func snippet(_ body: String, query: String) -> AttributedString {
        let text = ConversationPreview.plain(body)
        let words = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var line = text
        if let first = words.lazy.compactMap({ text.range(of: $0, options: options) }).first {
            let lead = text.distance(from: text.startIndex, to: first.lowerBound)
            if lead > 40 { line = "…" + text[text.index(first.lowerBound, offsetBy: -30)...] }
        }
        var out = AttributedString(line)
        for word in words {
            var from = line.startIndex
            while let range = line.range(of: word, options: options, range: from..<line.endIndex) {
                if let r = Range(range, in: out) {
                    out[r].foregroundColor = Amb.foreground
                    out[r].inlinePresentationIntent = .stronglyEmphasized
                }
                from = range.upperBound
            }
        }
        return out
    }
}
