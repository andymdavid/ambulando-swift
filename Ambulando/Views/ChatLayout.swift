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

    /// The centred reading column for a channel or thread (and its composer). Mac only. In the quick-view modal the
    /// column is narrower with wider margins, so a thread there doesn't run edge to edge.
    func chatColumn() -> some View { modifier(ChatColumn()) }
}

private struct ChatColumnModalKey: EnvironmentKey { static let defaultValue = false }
private struct ThreadInPanelKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// The chat is shown in the quick-view modal.
    var chatInModal: Bool {
        get { self[ChatColumnModalKey.self] }
        set { self[ChatColumnModalKey.self] = newValue }
    }
    /// The thread is shown in the Mac thread panel (inline or quick-view), over a shell that already shows the
    /// sample-data banner.
    var threadInPanel: Bool {
        get { self[ThreadInPanelKey.self] }
        set { self[ThreadInPanelKey.self] = newValue }
    }
}

private struct ChatColumn: ViewModifier {
    @Environment(\.chatInModal) private var modal
    func body(content: Content) -> some View {
        #if os(macOS)
        let margin = modal ? 48 : Amb.Space.xl
        let width = (modal ? 720 : Amb.chatColumnWidth) * TextScale.shared.factor
        content
            .padding(.horizontal, margin)
            .frame(maxWidth: width + 2 * margin)
            .frame(maxWidth: .infinity)
        #else
        content
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
    /// The hover toolbar, pinned to the message block's top-left corner.
    var controls: AnyView?

    /// Padding around the message block, so its highlight hugs the message. The sides get more than the top and bottom,
    /// which already carry the text's line spacing; this reads as even.
    static let insetH: CGFloat = 16
    static let insetV: CGFloat = 12

    var body: some View {
        let display = MessageDisplayCache.shared.display(message)
        let sender = people.person(message.senderNpub, senderLabel: message.senderLabel)
        let interactive = !display.attachments.isEmpty || (bodyOverride == nil && (display.blocks.map(RichBlocksInfo.hasControls) ?? false))
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 96)
            // The hover toolbar hangs just outside the message's left edge, so it never covers the name or time.
            Color.clear.frame(width: 4, height: 1)
                .overlay(alignment: .topTrailing) { controls }
            HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 9 * ChatTypography.scale) {
                if !continued {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MessageTimeText(iso: message.createdAt, thread: true)
                        Text(sender.name).font(.amb(.subheadline).weight(.semibold)).foregroundStyle(Amb.foreground).lineLimit(1)
                            .accessibilityIdentifier("message.author")
                    }
                }
                // Reactions sit right under the text, 6pt below it (Buzz), aligned with its first character.
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
                    if let reactions { reactions }
                }
                .environment(\.chatTextFits, true)
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
            .messageHighlight(continued: continued)
        }
        // The space between senders sits outside the highlight.
        .padding(.top, continued ? 0 : ChatLayout.senderGap - Self.insetV)
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

/// A message's time in its byline. UX lab: relative while it's recent ("now", "12m ago", "3h ago"); older messages
/// show the clock time in a thread (a day label sits above them) or the day elsewhere ("Yesterday", "Tue", "17 Nov").
/// The exact date and time is in the tooltip. Today's labels refresh every minute.
struct MessageTimeText: View {
    let iso: String
    /// In a thread, a day label sits above each day's messages.
    var thread = false

    var body: some View {
        if let date = ChatTime.date(iso) {
            Group {
                if Calendar.current.isDateInToday(date) {
                    TimelineView(.everyMinute) { context in label(RelativeTime.label(date, now: context.date, thread: thread)) }
                } else {
                    label(RelativeTime.label(date, now: Date(), thread: thread))
                }
            }
            .ambTooltip(date.formatted(date: .complete, time: .shortened))
        } else {
            label(ChatTime.label(iso))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.amb(.caption)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
    }
}

enum RelativeTime {
    static func label(_ date: Date, now: Date, thread: Bool) -> String {
        let calendar = Calendar.current
        let seconds = now.timeIntervalSince(date)
        if calendar.isDate(date, inSameDayAs: now) && seconds >= -60 {
            if seconds < 60 { return "now" }
            if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
            return "\(Int(seconds / 3600))h ago"
        }
        if thread { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days > 0 && days < 7 { return date.formatted(.dateTime.weekday(.abbreviated)) }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) { return date.formatted(.dateTime.day().month(.abbreviated)) }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

/// The people and agents who have written in a thread, most recent first, for its header.
struct ThreadParticipants: Sendable, Equatable {
    var threadId = ""
    var people: [PersonDisplay] = []
    var agents: Set<String> = []
}

struct ThreadParticipantsKey: PreferenceKey {
    static let defaultValue = ThreadParticipants()
    static func reduce(value: inout ThreadParticipants, nextValue: () -> ThreadParticipants) {
        let next = nextValue()
        if !next.people.isEmpty { value = next }
    }
}

extension ThreadParticipants {
    /// Distinct senders of the thread's messages, most recent first.
    init(threadId: String, messages: [MessageRecord], directory: PeopleDirectory) {
        var seen = Set<String>(), list: [PersonDisplay] = []
        for message in messages.reversed() {
            guard let npub = message.senderNpub, seen.insert(npub).inserted else { continue }
            list.append(directory.person(npub, senderLabel: message.senderLabel))
        }
        self.init(threadId: threadId, people: list, agents: Set(list.map(\.npub).filter(directory.isAgent)))
    }
}

/// Overlapping avatars of a thread's participants (up to three, the most recent on top) and "+N" for the rest.
/// The names are in the tooltip and for VoiceOver.
struct ParticipantFacepile: View {
    let participants: ThreadParticipants
    var size: CGFloat = 22

    var body: some View {
        let shown = Array(participants.people.prefix(3))
        let more = participants.people.count - shown.count
        HStack(spacing: 4) {
            HStack(spacing: -6) {
                ForEach(Array(shown.enumerated().reversed()), id: \.element.npub) { index, person in
                    let agent = participants.agents.contains(person.npub)
                    PersonAvatar(person: person, size: size, agent: agent)
                        .overlay(AvatarShape(agent: agent, size: size).stroke(Amb.background, lineWidth: 2))
                        .zIndex(Double(shown.count - index))
                }
            }
            if more > 0 {
                Text("+\(more)").font(.amb(.caption).weight(.medium)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
            }
        }
        .ambTooltip(participants.people.map(\.name).joined(separator: ", "))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Participants: " + participants.people.map(\.name).joined(separator: ", "))
        .accessibilityIdentifier("thread.participants")
    }
}

extension View {
    /// Tracks hover like `ambHoverRow` (so `ambRevealOnHover` controls show) without painting the row; the view
    /// draws its own highlight.
    func ambHoverTracking() -> some View { modifier(HoverTracking()) }
}

private struct HoverTracking: ViewModifier {
    @State private var hovered = false
    @Environment(\.ambHoverPaused) private var hoverPaused
    func body(content: Content) -> some View {
        content
            .environment(\.ambRowHovered, hovered)
            .environment(\.ambInHoverRow, true)
            .onHover { hovered = $0 && !hoverPaused }
            .onChange(of: hoverPaused) { _, paused in if paused { hovered = false } }
    }
}

extension View {
    /// UX lab: a thread message's block: even insets (more at the sides, which carry no line spacing), tighter for a
    /// continued message in a same-sender run, and a hover highlight that hugs it. Needs `ambHoverTracking()` above.
    func messageHighlight(continued: Bool) -> some View { modifier(MessageHighlight(continued: continued)) }
}

private struct MessageHighlight: ViewModifier {
    let continued: Bool
    @Environment(\.ambRowHovered) private var hovered
    func body(content: Content) -> some View {
        content
            .environment(\.chatTextFits, true)
            .padding(.horizontal, OwnMessageRow.insetH).padding(.vertical, continued ? 4 : OwnMessageRow.insetV)
            .background(hovered ? Amb.hoverFill : .clear, in: RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
    }
}

/// UX lab (Mac): the thread each channel had open in place when you left Chat or switched channel, so coming back
/// reopens it. Closing a thread yourself (back, Esc) forgets it. In memory only (not across launches).
@MainActor
final class InlineThreadMemory {
    static let shared = InlineThreadMemory()
    private var open: [String: ThreadFocus] = [:]
    func remember(_ focus: ThreadFocus?, channel: String) { open[channel.lowercased()] = focus }
    func recall(channel: String) -> ThreadFocus? { open[channel.lowercased()] }
}
