import SwiftUI
import AmbulandoCore

/// UX lab: consecutive messages from the same person within five minutes read as one block (no repeated avatar and
/// name), as in Slack and Linear. A new day, a thread with replies, or a gap starts a new block.
enum ChatGrouping {
    static let window: TimeInterval = 5 * 60

    /// Ids of posts that continue the previous post's block.
    static func continued(_ posts: [FeedPost], dayStarts: [String: ChatDay]) -> Set<String> {
        var result = Set<String>()
        for (previous, post) in zip(posts, posts.dropFirst()) {
            guard dayStarts[post.id] == nil, previous.replyCount == 0, !previous.message.deleted, !post.message.deleted,
                  let sender = post.message.senderNpub, sender == previous.message.senderNpub,
                  let a = ChatTime.date(previous.message.createdAt), let b = ChatTime.date(post.message.createdAt),
                  b.timeIntervalSince(a) >= 0, b.timeIntervalSince(a) <= window else { continue }
            result.insert(post.id)
        }
        return result
    }
}

extension View {
    /// A continued message has no visible name line, so VoiceOver still hears who sent it and when.
    @ViewBuilder func continuedMessageLabel(_ label: String?) -> some View {
        if let label { accessibilityHint(label) } else { self }
    }
}
