import SwiftUI
import AmbulandoCore

/// UX lab: inside a thread, consecutive replies from the same person within five minutes read as one block (no
/// repeated avatar and name), as in Slack and Linear. Never used in a channel: there each post starts its own
/// conversation. A new day, the thread's root, or a gap starts a new block.
enum ChatGrouping {
    static let window: TimeInterval = 5 * 60

    /// Ids of replies that continue the previous reply's block.
    static func continuedReplies(_ messages: [MessageRecord], dayStarts: [String: ChatDay]) -> Set<String> {
        var result = Set<String>()
        for (previous, message) in zip(messages, messages.dropFirst()) {
            guard !previous.isThreadRoot, !message.isThreadRoot, dayStarts[message.id] == nil,
                  !previous.deleted, !message.deleted,
                  let sender = message.senderNpub, sender == previous.senderNpub,
                  let a = ChatTime.date(previous.createdAt), let b = ChatTime.date(message.createdAt),
                  b.timeIntervalSince(a) >= 0, b.timeIntervalSince(a) <= window else { continue }
            result.insert(message.id)
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
