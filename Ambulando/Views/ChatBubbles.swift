import SwiftUI
import AmbulandoCore

/// UX lab (Mac): channel and thread share a centred reading column with real side margins. Inside a thread, your own
/// messages sit on the right in a soft-accent bubble sized to its text (name and time above, avatar beside its last
/// line); everyone else's stay flat rows, so long agent replies (lists, tables) keep the full width. The channel stays a
/// list of conversations. iPhone and iPad keep the flat rows.
enum ChatBubbles {
    static var enabled: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}

/// UX lab switches for the Test app.
enum UXLabOptions {
    /// Hides the sample-data banner, to judge layouts without it: launch with `-UXHideSampleBanner YES` (or set it
    /// with `defaults write`). Ignored while the app's Mac checks run, which find their window by the banner.
    static let hideSampleBanner = UserDefaults.standard.bool(forKey: "UXHideSampleBanner")
        && !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-AmbulandoMac") }
}

private struct ChatBubbleFitKey: EnvironmentKey { static let defaultValue = false }
private struct ChatThreadLayoutKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Inside a bubble, message text is only as wide as it needs to be (the bubble sets the maximum).
    var chatBubbleFit: Bool {
        get { self[ChatBubbleFitKey.self] }
        set { self[ChatBubbleFitKey.self] = newValue }
    }
    /// Messages inside a thread (chat), as opposed to a channel's list of conversations.
    var chatThreadLayout: Bool {
        get { self[ChatThreadLayoutKey.self] }
        set { self[ChatThreadLayoutKey.self] = newValue }
    }
}

extension View {
    /// Message text fills the readable width, or inside a bubble only as wide as it needs.
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

    /// Tracks hover over a message without painting the row; the bubble darkens instead and the hover toolbar shows.
    func bubbleHoverArea() -> some View { modifier(BubbleHoverArea()) }
}

private struct BubbleHoverArea: ViewModifier {
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .environment(\.ambRowHovered, hovered)
            .environment(\.ambInHoverRow, true)
            .onHover { hovered = $0 }
    }
}

/// One message as a bubble. The caller supplies reactions (drawn inside the bubble), what goes below it (a thread's
/// reply summary) and wraps it in the thread link where there is one.
struct BubbleMessageRow: View {
    let message: MessageRecord
    let people: PeopleDirectory
    var bodyOverride: String?
    var workspace: WorkspaceRecord?
    let mine: Bool
    /// Continues the previous message's run: no name line.
    var continued = false
    /// Last message of a run: carries the avatar.
    var showsAvatar = true
    var title: String?
    var collapsible = false
    var reactions: AnyView?
    var below: AnyView?
    @Environment(\.ambRowHovered) private var hovered

    private static var avatarSide: CGFloat { 32 }

    var body: some View {
        let display = MessageDisplayCache.shared.display(message)
        let sender = people.person(message.senderNpub, senderLabel: message.senderLabel)
        let interactive = !display.attachments.isEmpty || (bodyOverride == nil && (display.blocks.map(RichBlocksInfo.hasControls) ?? false))
        VStack(alignment: mine ? .trailing : .leading, spacing: Amb.Space.xs) {
        HStack(alignment: .bottom, spacing: Amb.Space.s) {
            if mine { Spacer(minLength: 64) } else { avatar(sender) }
            VStack(alignment: mine ? .trailing : .leading, spacing: Amb.Space.xs) {
                if !continued {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(sender.name).font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.secondaryForeground).lineLimit(1)
                            .accessibilityIdentifier("message.author")
                        Text(display.time).font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
                    }
                    .padding(.horizontal, 14)
                }
                bubble(display)
                    .accessibilityElement(children: interactive ? .contain : .combine)
                    .continuedMessageLabel(continued ? "\(sender.name), \(display.time)" : nil)
                    .accessibilityIdentifier("message")
            }
            if mine { avatar(sender) } else { Spacer(minLength: 64) }
        }
        // Below the bubble, not beside the avatar: the avatar stays level with the bubble's last line.
        if let below { below.padding(mine ? .trailing : .leading, Self.avatarSide + Amb.Space.s + 10) }
        }
        .padding(.top, continued ? 2 : Amb.Space.m)
        .padding(.bottom, 2)
    }

    @ViewBuilder private func avatar(_ sender: PersonDisplay) -> some View {
        if showsAvatar {
            PersonAvatar(person: sender, size: Self.avatarSide)
        } else {
            Color.clear.frame(width: Self.avatarSide, height: 1).accessibilityHidden(true)
        }
    }

    private func bubble(_ display: MessageDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title).font(.amb(.headline)).foregroundStyle(Amb.foreground).lineLimit(2)
            }
            CollapsibleMessageBody(enabled: collapsible) {
                if let bodyOverride {
                    if !bodyOverride.isEmpty { MessageBody(text: bodyOverride, muted: true) }
                } else if !message.body.isEmpty {
                    if let blocks = display.blocks { RichBlocksView(blocks: blocks, workspace: workspace) } else { MessageBody(plain: message.body) }
                }
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
            if let reactions { reactions.padding(.top, 2) }
        }
        .environment(\.chatBubbleFit, true)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(mine ? Amb.bubbleMine : Amb.bubble, in: RoundedRectangle(cornerRadius: Amb.radiusBubble, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Amb.radiusBubble, style: .continuous).fill(hovered ? Amb.hoverFill : .clear).allowsHitTesting(false))
    }
}
