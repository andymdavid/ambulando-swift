import SwiftUI
import AmbulandoCore

/// UX lab (Mac): a channel as a list of its conversations, newest activity first (direction A of the channel list
/// review, after the live app's Threads view). Each row: an unread dot, the title, the opening brief when it says more
/// than the title, who has taken part and the newest reply (or which agent is working), then the time and reply count.
/// A conversation opens in place of the list; "New thread" opens the composer. Deliberately not chat: no composer
/// under the list and no message bubbles.
struct ChannelConversationList: View {
    @Environment(AppModel.self) private var model
    let target: ChatTarget
    let workspace: WorkspaceRecord
    let conversations: [ChannelConversation]
    let people: PeopleDirectory
    let threadTitles: [String: String]
    let loaded: Bool
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable { case all = "All", unread = "Unread", mine = "Mine" }

    private var me: String? { model.identity.npub }

    private var shown: [ChannelConversation] {
        switch filter {
        case .all: conversations
        case .unread: conversations.filter(\.unread)
        case .mine: conversations.filter { c in me.map { c.participants.contains($0) || c.root.senderNpub == $0 } ?? false }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header.chatColumn()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { conversation in
                        ConversationRow(conversation: conversation, workspace: workspace, people: people,
                                        title: Self.title(conversation, threadTitles: threadTitles), me: me)
                    }
                    if loaded && shown.isEmpty { empty }
                }
                .padding(.bottom, Amb.Space.l)
                .chatColumn()
            }
        }
    }

    private var header: some View {
        HStack(spacing: Amb.Space.s) {
            HStack(spacing: 2) {
                ForEach(Filter.allCases, id: \.self) { option in
                    Button(option.rawValue) { filter = option }
                        .buttonStyle(.plain)
                        .font(.amb(.footnote).weight(.medium))
                        .foregroundStyle(filter == option ? Amb.foreground : Amb.mutedForeground)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(filter == option ? Amb.selectedFill : .clear, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
                        .accessibilityAddTraits(filter == option ? .isSelected : [])
                        .accessibilityIdentifier("channel.filter.\(option.rawValue.lowercased())")
                }
            }
            Spacer(minLength: 0)
            Button { model.composingThread = true } label: { Label("New thread", systemImage: "square.and.pencil") }
                .buttonStyle(.ambPrimary)
                .accessibilityIdentifier("channel.newThread")
        }
        .padding(.horizontal, 12).padding(.top, Amb.Space.m).padding(.bottom, Amb.Space.s)
    }

    private var empty: some View {
        Text(filter == .all ? "No conversations yet. Start one with New thread." : filter == .unread ? "You're all caught up." : "No conversations you've taken part in.")
            .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    /// Tower's title, else the first line of the opening message.
    static func title(_ c: ChannelConversation, threadTitles: [String: String]) -> String {
        if let thread = c.root.threadId, let title = threadTitles[thread], !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return ThreadTitleText.clean(MentionCodec.plain(title))
        }
        let text = ThreadTitleText.clean(MentionCodec.plain(c.root.body))
        return text.isEmpty ? "Conversation" : text
    }
}

private struct ConversationRow: View {
    @Environment(AppModel.self) private var model
    let conversation: ChannelConversation
    let workspace: WorkspaceRecord
    let people: PeopleDirectory
    let title: String
    let me: String?

    var body: some View {
        Group {
            if let thread = conversation.root.threadId {
                ThreadRouteLink(route: ChatRoute.thread(workspaceId: workspace.id, channelId: conversation.root.channelId, threadId: thread)) {
                    content.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the conversation")
            } else {
                content
            }
        }
        .ambHoverRow(radius: Amb.radiusPanel)
        .overlay(alignment: .top) { Rectangle().fill(Amb.border).frame(height: 1).padding(.leading, 34).padding(.trailing, 12) }
        .accessibilityIdentifier("channel.conversation")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Amb.Space.m) {
            Circle().fill(conversation.unread ? Amb.unread : .clear).frame(width: 7, height: 7).padding(.top, 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.amb(.body).weight(conversation.unread ? .semibold : .medium)).foregroundStyle(Amb.foreground).lineLimit(1)
                if let brief { Text(brief).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).lineLimit(1) }
                meta.padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                MessageTimeText(iso: conversation.lastActivityAt)
                if conversation.replyCount > 0 {
                    Text("\(conversation.replyCount) \(conversation.replyCount == 1 ? "reply" : "replies")")
                        .font(.amb(.caption)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// The opening message's first line, when the title doesn't already say it.
    private var brief: String? {
        let body = MentionCodec.plain(conversation.root.body)
        let first = ThreadTitleText.clean(body)
        let line = first == title ? Self.secondLine(body) : first
        guard let line, !line.isEmpty, line != title else { return nil }
        return line
    }

    private static func secondLine(_ text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return lines.dropFirst().first.map { ConversationPreview.plain(String($0)) }
    }

    @ViewBuilder private var meta: some View {
        HStack(spacing: Amb.Space.s) {
            ParticipantStack(npubs: conversation.participants, people: people)
            TimelineView(.periodic(from: .now, by: 15)) { context in
                if let agent = workingAgent(now: context.date) {
                    WorkingLabel(name: people.person(agent).name)
                } else if let reply = conversation.latestReply {
                    (Text(senderName(reply) + ": ").fontWeight(.medium).foregroundColor(Amb.secondaryForeground)
                     + Text(ConversationPreview.plain(reply.body)).foregroundColor(Amb.mutedForeground))
                        .font(.amb(.footnote)).lineLimit(1)
                } else {
                    // No replies yet: who started it.
                    Text(senderName(conversation.root)).font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.secondaryForeground).lineLimit(1)
                }
            }
        }
    }

    private func senderName(_ message: MessageRecord) -> String {
        if let me, message.senderNpub == me { return "You" }
        return people.person(message.senderNpub, senderLabel: message.senderLabel).name
    }

    /// An agent with a live turn in this conversation (Tower's clock).
    private func workingAgent(now: Date) -> String? {
        let origin = model.connection.flatMap { try? TowerOrigin($0.origin).description }
        let serverNow = ServerClock.shared.now(origin: origin)
        return conversation.activities.first { AgentLiveness.phase($0, now: serverNow).isLive }?.agentNpub
    }

    private var accessibilityText: String {
        var parts = [title]
        if conversation.unread { parts.append("unread") }
        if conversation.replyCount > 0 { parts.append("\(conversation.replyCount) \(conversation.replyCount == 1 ? "reply" : "replies")") }
        if let reply = conversation.latestReply { parts.append("latest from \(senderName(reply))") }
        return parts.joined(separator: ", ")
    }
}

/// Up to three overlapping avatars, the most recent on top; agents are rounded squares.
private struct ParticipantStack: View {
    let npubs: [String]
    let people: PeopleDirectory

    var body: some View {
        let shown = Array(npubs.prefix(3))
        HStack(spacing: -6) {
            ForEach(Array(shown.enumerated().reversed()), id: \.element) { index, npub in
                PersonAvatar(person: people.person(npub), size: 20, agent: people.isAgent(npub))
                    .overlay(AvatarShape(agent: people.isAgent(npub), size: 20).stroke(Amb.background, lineWidth: 2))
                    .zIndex(Double(shown.count - index))
            }
        }
        .accessibilityHidden(true)
    }
}

/// "Lara is working" with three pulsing dots.
private struct WorkingLabel: View {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Text("\(name) is working").font(.amb(.footnote).weight(.medium))
            TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { context in
                let phase = Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().frame(width: 4, height: 4).opacity(reduceMotion || i == phase ? 1 : 0.35)
                    }
                }
            }
        }
        .foregroundStyle(Amb.primary)
    }
}

/// One-line preview text: mentions as names, Markdown marks and link targets removed.
enum ConversationPreview {
    static func plain(_ text: String) -> String {
        var s = MentionCodec.plain(text)
        // [label](target) → label
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]*)\]\([^)]*\)"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        for mark in ["**", "__", "`"] { s = s.replacingOccurrences(of: mark, with: "") }
        let lines = s.split(whereSeparator: \.isNewline).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            while let first = l.first, "#>-*".contains(first) { l.removeFirst() }
            return l.trimmingCharacters(in: .whitespaces)
        }
        return lines.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
