import SwiftUI
import AmbulandoCore

/// UX lab (Mac): channel and thread share a centred reading column with real side margins. Messages are flat rows;
/// inside a thread your own messages sit on the right (name, time and avatar mirrored, text still reads left to right)
/// and there is more air between different senders. Bubbles were tried and dropped: long agent replies (lists, tables)
/// don't belong in a bubble. iPhone and iPad keep their layout.
enum ChatLayout {
    static var mac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
    /// Space above a message from a new sender in a thread (same-sender runs sit tight).
    static let senderGap: CGFloat = 14
}

/// UX lab switches for the Test app.
enum UXLabOptions {
    /// Hides the sample-data banner, to judge layouts without it: launch with `-UXHideSampleBanner YES` (or set it
    /// with `defaults write`). Ignored while the app's Mac checks run, which find their window by the banner.
    static let hideSampleBanner = UserDefaults.standard.bool(forKey: "UXHideSampleBanner")
        && !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-AmbulandoMac") }
}

private struct ChatTextFitsKey: EnvironmentKey { static let defaultValue = false }
private struct ChatThreadLayoutKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Message text is only as wide as it needs to be (your own messages, pushed to the right).
    var chatTextFits: Bool {
        get { self[ChatTextFitsKey.self] }
        set { self[ChatTextFitsKey.self] = newValue }
    }
    /// Messages inside a thread (chat), as opposed to a channel's list of conversations.
    var chatThreadLayout: Bool {
        get { self[ChatThreadLayoutKey.self] }
        set { self[ChatThreadLayoutKey.self] = newValue }
    }
}

extension View {
    /// Message text fills the readable width, or only as wide as it needs.
    @ViewBuilder func chatTextWidth(fit: Bool, readable: CGFloat) -> some View {
        if fit { self } else { frame(maxWidth: readable, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading) }
    }

    /// The centred reading column for a channel or thread (and its composer). Mac only.
    @ViewBuilder func chatColumn() -> some View {
        #if os(macOS)
        padding(.horizontal, Amb.Space.xl)
            .frame(maxWidth: Amb.chatColumnWidth * TextScale.shared.factor + 2 * Amb.Space.xl)
            .frame(maxWidth: .infinity)
        #else
        self
        #endif
    }
}

/// Your own message in a thread: the flat row mirrored to the right. The caller supplies reactions and wraps it in
/// the hover row and menus.
struct OwnMessageRow: View {
    let message: MessageRecord
    let people: PeopleDirectory
    var bodyOverride: String?
    var workspace: WorkspaceRecord?
    /// Continues the previous message's run: no name line or avatar.
    var continued = false
    var reactions: AnyView?

    var body: some View {
        let display = MessageDisplayCache.shared.display(message)
        let sender = people.person(message.senderNpub, senderLabel: message.senderLabel)
        let interactive = !display.attachments.isEmpty || (bodyOverride == nil && (display.blocks.map(RichBlocksInfo.hasControls) ?? false))
        HStack(alignment: .top, spacing: 10) {
            Spacer(minLength: 96)
            VStack(alignment: .trailing, spacing: 6 * ChatTypography.scale) {
                if !continued {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        MessageTimeText(iso: message.createdAt, thread: true)
                        Text(sender.name).font(.amb(.subheadline).weight(.semibold)).foregroundStyle(Amb.foreground).lineLimit(1)
                            .accessibilityIdentifier("message.author")
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let bodyOverride {
                        if !bodyOverride.isEmpty { MessageBody(text: bodyOverride, muted: true) }
                    } else if !message.body.isEmpty {
                        if let blocks = display.blocks { RichBlocksView(blocks: blocks, workspace: workspace) } else { MessageBody(plain: message.body) }
                    }
                    if let workspace {
                        ForEach(display.attachments, id: \.storageObjectId) { attachment in
                            if attachment.textAttachment != nil {
                                SentTextAttachmentCard(message: message, attachment: attachment, workspace: workspace)
                            } else {
                                AttachmentView(attachment: attachment, workspace: workspace)
                            }
                        }
                    }
                }
                .environment(\.chatTextFits, true)
                if let reactions { reactions }
            }
            .accessibilityElement(children: interactive ? .contain : .combine)
            .continuedMessageLabel(continued ? "\(sender.name), \(display.time)" : nil)
            .accessibilityIdentifier("message")
            if continued {
                Color.clear.frame(width: 34, height: 1).accessibilityHidden(true)
            } else {
                PersonAvatar(person: sender)
            }
        }
        .padding(.horizontal, 12).padding(.top, continued ? 0 : ChatLayout.senderGap).padding(.bottom, 4)
    }
}

/// UX lab: an avatar's outline. Agents are a rounded square, people a circle, so you can tell them apart at a glance.
struct AvatarShape: Shape {
    let agent: Bool
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        agent ? RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).path(in: rect) : Circle().path(in: rect)
    }
}

/// A message's time in its byline.
struct MessageTimeText: View {
    let iso: String
    /// In a thread, a day label sits above each day's messages.
    var thread = false
    var body: some View {
        Text(ChatTime.label(iso)).font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
    }
}
