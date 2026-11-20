import AmbulandoCore
import PhotosUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A sent message with its reactions, attachments and the actions Tower allows: react (anyone who can write here),
/// edit and delete (the author; edits are signed kind 33358 revisions). Unsent edits and deletes show on the message
/// until Tower accepts them.
struct MessageCell: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && lhs.people == rhs.people && lhs.workspace == rhs.workspace && lhs.extras == rhs.extras
            && lhs.effectiveThreadId == rhs.effectiveThreadId && lhs.route == rhs.route && lhs.replyCount == rhs.replyCount && lhs.lastReplyAt == rhs.lastReplyAt && lhs.threadTitle == rhs.threadTitle && lhs.continued == rhs.continued && lhs.collapsible == rhs.collapsible
    }

    @Environment(AppModel.self) private var model
    let message: MessageRecord
    let people: PeopleDirectory
    let workspace: WorkspaceRecord
    let extras: MessageExtras
    var effectiveThreadId: String? = nil
    private var inherited: Bool { effectiveThreadId.map { message.isInherited(in: $0) } ?? false }
    var route: ChatRoute? = nil
    var replyCount = 0
    var lastReplyAt: String? = nil
    /// Tower's thread title, shown above the root when it says something the root's first words do not.
    var threadTitle: String? = nil
    /// UX lab: continues the previous message's block (no avatar or name line). Thread replies only.
    var continued = false
    /// UX lab: collapse long bodies (channel conversation list).
    var collapsible = false
    @Environment(\.editChatMessage) private var editChatMessage
    @Environment(\.chatThreadLayout) private var threadLayout
    @State private var confirmDelete = false
    @State private var gettingItDone = false
    @State private var autopilot: URL?
    @Environment(\.openURL) private var openURL

    /// UX lab: this conversation is the one open in the Mac thread panel (shown selected in the channel).
    private var isOpenInPanel: Bool {
        #if os(macOS)
        guard route != nil, let open = model.focusedThread?.threadId, let thread = message.threadId else { return false }
        return open.lowercased() == thread.lowercased()
        #else
        false
        #endif
    }

    private var writes: [WriteItem] { extras.writes[message.id] ?? [] }
    private var distinctTitle: String? {
        guard let threadTitle else { return nil }
        let title = MentionCodec.plain(threadTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = MentionCodec.plain(message.body).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.hasPrefix(title.trimmingCharacters(in: CharacterSet(charactersIn: ".…"))) else { return nil }
        return title
    }
    private var pendingEdit: WriteItem? { writes.last { $0.kind == .messageEdit } }
    private var pendingDelete: WriteItem? { writes.last { $0.kind == .messageDelete } }
    private var mine: Bool { message.senderNpub != nil && message.senderNpub == model.identity.npub }

    var body: some View {
        Group {
            // UX lab: in a thread on the Mac, your own messages sit on the right.
            if ChatLayout.mac && threadLayout && mine && !inherited { ownCell } else { flatCell }
        }
        .contextMenu { actions }
        .sheet(isPresented: $gettingItDone) { GetItDoneSheet(message: message, workspace: workspace) }
        .confirmationDialog("Delete this message for everyone?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.submit(WriteIntent(kind: .messageDelete, targetId: message.id, payload: ["row_version": message.rowVersion]), in: workspace)
            }
        }
    }

    /// UX lab (Mac): your own message in a thread, mirrored to the right; the hover toolbar moves to the left.
    private var ownCell: some View {
        let showsReactions = model.identity.npub != nil && !message.deleted && !inherited && !reactions.isEmpty
        return VStack(alignment: .trailing, spacing: 0) {
            OwnMessageRow(message: message, people: people, bodyOverride: pendingEdit?.isPending == true ? pendingEdit?.string("body") : nil,
                          workspace: workspace, continued: continued,
                          reactions: showsReactions ? AnyView(ReactionBar(reactions: reactions, me: model.identity.npub, quickActions: false) { toggle($0) }) : nil,
                          controls: AnyView(messageControls))
                .opacity(pendingDelete?.isPending == true ? 0.45 : 1)
            ForEach(writes.filter { [.messageEdit, .messageDelete].contains($0.kind) }) { item in
                WriteStatusLine(item: item, label: item.kind == .messageEdit ? "Edit" : "Delete").padding(.horizontal, 56).padding(.bottom, 6)
            }
        }
        .ambHoverTracking()   // the message block draws its own highlight, sized to the message
    }

    private var flatCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            if inherited {
                Text("Inherited context · read only").font(.amb(.caption2)).foregroundStyle(Amb.mutedForeground)
                    .padding(.leading, 60).padding(.top, 6)
            }
            Group {
                if let route {
                    ThreadRouteLink(route: route) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let title = distinctTitle {
                                // UX lab: the conversation's title is its heading (was a small caption with an icon).
                                Text(title)
                                    .font(.amb(.headline)).foregroundStyle(Amb.foreground).lineLimit(2)
                                    .padding(.leading, 56).padding(.trailing, 16).padding(.top, 10)
                            }
                            row
                            if replyCount > 0 {
                                // UX lab: a quiet footer (was a rule plus the count in the accent colour).
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right").foregroundStyle(Amb.mutedForeground)
                                    Text("\(replyCount) \(replyCount == 1 ? "reply" : "replies")").fontWeight(.medium).foregroundStyle(Amb.primary)
                                    if let lastReplyAt { Text("Last reply \(ChatTime.label(lastReplyAt))").foregroundStyle(Amb.mutedForeground) }
                                }
                                .font(.amb(.caption))
                                .padding(.leading, 56).padding(.trailing, 16).padding(.bottom, 8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(replyCount > 0 ? "Opens the thread" : "")
                    .accessibilityIdentifier("thread.\(replyCount)")
                } else {
                    row
                }
            }
            .overlay(alignment: .topTrailing) { messageControls }
            if model.identity.npub != nil && !message.deleted && !inherited {
                #if os(macOS)
                // UX lab: reaction pills only when someone has reacted; quick reactions live in the hover toolbar.
                if !reactions.isEmpty {
                    ReactionBar(reactions: reactions, me: model.identity.npub, quickActions: false) { toggle($0) }
                        .padding(.leading, 56).padding(.trailing, 16).padding(.top, 2).padding(.bottom, 8)   // UX lab: right under the text
                }
                #else
                ReactionBar(reactions: reactions, me: model.identity.npub) { toggle($0) }
                    .padding(.leading, 60).padding(.trailing, 16)
                #endif
            }
            ForEach(writes.filter { [.messageEdit, .messageDelete].contains($0.kind) }) { item in
                WriteStatusLine(item: item, label: item.kind == .messageEdit ? "Edit" : "Delete").padding(.leading, 60).padding(.trailing, 16).padding(.bottom, 6)
            }
        }
        .background(isOpenInPanel ? Amb.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
        .ambHoverRow(radius: Amb.radiusPanel)
    }

    /// The message's actions, shared by the visible ⋮ menu and the long-press / right-click menu.
    @ViewBuilder private var actions: some View {
        if !inherited { Menu {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Button { toggle(emoji.rawValue) } label: { Label(emoji.name, systemImage: emoji.symbol) }
                    .accessibilityIdentifier("react.\(emoji.rawValue)")
            }
        } label: { Label("React", systemImage: "face.smiling") }
            .accessibilityIdentifier("message.react") }
        if !message.deleted {
            Button { gettingItDone = true } label: { Label("Get it done", systemImage: "checkmark.circle") }
                .accessibilityIdentifier("message.getitdone")
        }
        if message.threadId != nil && !message.deleted {
            Button { model.branch(from: message, in: workspace, recipient: agentSender, effectiveThreadId: effectiveThreadId) } label: { Label("Branch from here", systemImage: "arrow.triangle.branch") }
                .accessibilityIdentifier("message.branch")
        }
        Button { Pasteboard.copy(MentionCodec.plain(message.body)) } label: { Label("Copy message", systemImage: "doc.on.doc") }
            .accessibilityIdentifier("message.copy")
        if AutopilotSessionLink.sessionId(in: message.raw) != nil {
            Button { Task { await openAutopilot() } } label: { Label("Autopilot Link", systemImage: "arrow.up.forward.app") }
                .accessibilityIdentifier("message.autopilot")
        }
        Button { Pasteboard.copy(Self.reference(for: message)) } label: { Label("FD Ref", systemImage: "link") }
            .accessibilityIdentifier("message.ref")
        if mine && !message.deleted && !inherited {
            Button {
                editChatMessage?(message, pendingEdit?.string("body") ?? message.body)
            } label: { Label("Edit", systemImage: "pencil") }.accessibilityIdentifier("message.edit")
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete message", systemImage: "trash") }.accessibilityIdentifier("message.delete")
        }
    }

    /// The sender when it is a workspace agent: a branch keeps talking to it, as the web does.
    private var agentSender: String? {
        guard let npub = message.senderNpub, people.isAgent(npub) else { return nil }
        return npub
    }

    private func openAutopilot() async {
        guard let url = await model.autopilotURL(for: message, in: workspace) else {
            model.notice = "This workspace has no Autopilot address to open this session."
            return
        }
        openURL(url)
    }

    /// Flight Deck reference to this message, as the web's "FD Ref" copies it.
    static func reference(for message: MessageRecord) -> String {
        "@[Chat message](mention:chat:\(message.channelId)#\(message.id))"
    }

    /// What is true of this stored message: it came from Tower, unless a change to it is still waiting or was refused.
    private var sync: MessageSyncState {
        let changes = writes.filter { [.messageEdit, .messageDelete].contains($0.kind) }
        if changes.contains(where: { !$0.isPending }) { return .failed }
        if changes.contains(where: \.isPending) { return .pending }
        return .synced
    }

    private var messageControls: some View {
        HStack(spacing: 4) {
            // UX lab: the dot only shows when something needs attention (waiting or refused); it stays in the
            // accessibility tree either way.
            SyncDot(state: sync).opacity(sync == .synced ? 0 : 1)
            #if os(macOS)
            // UX lab: quick reactions and the menu appear together in a small toolbar while the message is hovered.
            HStack(spacing: 2) {
                if model.identity.npub != nil && !message.deleted && !inherited {
                    ReactionBar(reactions: [], me: model.identity.npub, compact: true) { toggle($0) }.fixedSize()
                }
                NativeMessageActions(items: nativeActions).frame(width: 26, height: 26)
                    .accessibilityLabel("Message actions")
                    .accessibilityIdentifier("message.actions")
            }
            .padding(2)
            .background(Amb.raised, in: RoundedRectangle(cornerRadius: Amb.radiusControl + 2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl + 2, style: .continuous).stroke(Amb.borderStrong, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
            .fixedSize()
            .offset(y: -10)   // floats over the message's top edge instead of covering its text
            .ambRevealOnHover()
            #else
            Menu { actions } label: {
                Image(systemName: "ellipsis").font(.amb(.footnote).weight(.bold)).foregroundStyle(Amb.mutedForeground)
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Message actions")
            .accessibilityIdentifier("message.actions")
            #endif
        }
        .padding(.top, 6).padding(.trailing, 10)
    }

    #if os(macOS)
    private var nativeActions: [NativeMessageAction] {
        var items = inherited ? [] : [NativeMessageAction("React", "face.smiling", children: ReactionEmoji.allCases.map { emoji in
            NativeMessageAction(emoji.name, emoji.symbol) { toggle(emoji.rawValue) }
        })]
        if !message.deleted {
            items.append(NativeMessageAction("Get it done", "checkmark.circle") { gettingItDone = true })
        }
        if message.threadId != nil && !message.deleted {
            items.append(NativeMessageAction("Branch from here", "arrow.triangle.branch") {
                model.branch(from: message, in: workspace, recipient: agentSender, effectiveThreadId: effectiveThreadId)
            })
        }
        items.append(NativeMessageAction("Copy message", "doc.on.doc") { Pasteboard.copy(MentionCodec.plain(message.body)) })
        if AutopilotSessionLink.sessionId(in: message.raw) != nil {
            items.append(NativeMessageAction("Autopilot Link", "arrow.up.forward.app") { Task { await openAutopilot() } })
        }
        items.append(NativeMessageAction("FD Ref", "link") { Pasteboard.copy(Self.reference(for: message)) })
        if mine && !message.deleted && !inherited {
            items.append(NativeMessageAction("Edit", "pencil") { editChatMessage?(message, pendingEdit?.string("body") ?? message.body) })
            items.append(NativeMessageAction("Delete message", "trash") { confirmDelete = true })
        }
        return items
    }
    #endif

    private var row: some View {
        MessageRow(message: message, people: people, bodyOverride: pendingEdit?.isPending == true ? pendingEdit?.string("body") : nil, workspace: workspace, continued: continued, collapsible: collapsible)
            .opacity(pendingDelete?.isPending == true ? 0.45 : 1)
    }

    /// Stored reactions plus unsent ones (and minus unsent removals).
    private var reactions: [ReactionRecord] {
        var list = extras.reactions[message.id] ?? []
        for item in writes where item.isPending {
            if item.kind == .reactionAdd, let emoji = item.string("emoji") {
                list.append(ReactionRecord(workspaceId: workspace.id, id: "pending-\(item.id)", targetType: "message", targetId: message.id, emoji: emoji,
                                           reactorNpub: model.identity.npub, updatedAt: item.createdAt))
            }
            if item.kind == .reactionRemove, let id = item.string("reaction_id") { list.removeAll { $0.id == id } }
        }
        return list
    }

    private func toggle(_ emoji: String) {
        guard !inherited else { return }
        if let existing = reactions.first(where: { $0.emoji == emoji && $0.reactorNpub == model.identity.npub }) {
            if existing.id.hasPrefix("pending-") {
                Task { try? await model.store?.writer.discardWrite(id: String(existing.id.dropFirst("pending-".count))) }
            } else {
                model.submit(WriteIntent(kind: .reactionRemove, targetId: message.id, payload: ["reaction_id": existing.id]), in: workspace)
            }
        } else {
            model.submit(WriteIntent(kind: .reactionAdd, targetId: message.id, payload: ["target_type": "message", "emoji": emoji]), in: workspace)
        }
    }
}

/// The web's reaction bar (sol `.reaction-bar`), always under a message: one bordered pill per reaction with its symbol and
/// count (yours on the muted fill), a quiet grey thumbs-up that reacts in one tap, and a + that opens the emoji picker.
/// Tapping a pill, the thumbs-up or a picker emoji adds your reaction, or removes it when you already made it.
/// Packs pills into bounded rows, including at accessibility text sizes.
private struct ReactionFlowLayout: Layout {
    let spacing: CGFloat

    private func arrangement(width: CGFloat, subviews: Subviews) -> (CGSize, [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, used: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            used = max(used, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        // UX lab: report the width the items use (was the full proposed width), so a short bar sizes to its content.
        return (CGSize(width: min(width, used), height: y + rowHeight), points)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 320, subviews: subviews).0
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let points = arrangement(width: bounds.width, subviews: subviews).1
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + points[index].x, y: bounds.minY + points[index].y), anchor: .topLeading, proposal: .unspecified)
        }
    }
}

struct ReactionBar: View {
    let reactions: [ReactionRecord]
    let me: String?
    /// UX lab: false draws only the reaction pills (the quick 👍 and + live in the Mac hover toolbar).
    var quickActions = true
    /// UX lab: borderless 26pt quick buttons for the Mac hover toolbar.
    var compact = false
    let toggle: (String) -> Void
    @State private var picking = false

    @ScaledMetric(relativeTo: .footnote) private var scaledSide: CGFloat = 32
    private var side: CGFloat {
        #if os(macOS)
        // UX lab: pills under a message are small capsules (Buzz: ~24px), the toolbar's buttons 26.
        (compact ? 26 : quickActions ? 28 : 24) * TextScale.shared.factor
        #else
        scaledSide
        #endif
    }

    /// UX lab (Mac): pills under a message use a caption-size count and leave room for an add button after them.
    private var pillsOnly: Bool {
        #if os(macOS)
        !quickActions && !compact
        #else
        false
        #endif
    }

    var body: some View {
        let counts = Dictionary(grouping: reactions, by: \.emoji)
        let ordered = ReactionEmoji.allCases.filter { counts[$0.rawValue] != nil }
        ReactionFlowLayout(spacing: 4) {
            ForEach(ordered, id: \.self) { emoji in
                let list = counts[emoji.rawValue] ?? []
                let mine = list.contains { $0.reactorNpub == me }
                Button { toggle(emoji.rawValue) } label: {
                    HStack(spacing: 4) { Image(systemName: emoji.symbol).foregroundStyle(emoji == .heart ? Amb.destructive : (mine ? Amb.primary : Amb.foreground)); Text("\(list.count)") }
                        .font(pillsOnly ? .amb(.caption).weight(.medium) : .amb(.footnote).weight(.semibold)).monospacedDigit()
                        .foregroundStyle(mine ? Amb.primary : Amb.foreground)
                        .padding(.horizontal, 8).frame(minWidth: side, minHeight: side)
                        .background(mine ? Amb.accent : Amb.muted, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(emoji.name), \(list.count)\(mine ? ", including you" : "")")
                .accessibilityAddTraits(mine ? .isSelected : [])
                .accessibilityIdentifier("reaction.\(emoji.rawValue)")
            }
            if quickActions {
            Button { toggle(ReactionEmoji.thumbsUp.rawValue) } label: {
                if compact {
                    Image(systemName: "hand.thumbsup").frame(width: side, height: side)
                } else {
                    Image(systemName: ReactionEmoji.thumbsUp.symbol).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).opacity(0.8)
                        .frame(width: side, height: side).background(Amb.card, in: RoundedRectangle(cornerRadius: Amb.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(Amb.border, lineWidth: 1)).contentShape(Rectangle())
                }
            }
            .ambIconStyle(compact)
            .ambTooltip(compact ? "React with thumbs up" : "")
            .accessibilityLabel("React with thumbs up")
            .accessibilityIdentifier("reaction.quick")
            Button { picking = true } label: {
                if compact {
                    Image(systemName: "face.smiling").frame(width: side, height: side)
                } else {
                    Image(systemName: "plus").font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
                        .frame(width: side, height: side).background(Amb.card, in: RoundedRectangle(cornerRadius: Amb.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(Amb.border, lineWidth: 1)).contentShape(Rectangle())
                }
            }
            .ambIconStyle(compact)
            .ambTooltip(compact ? "Add reaction" : "")
            .accessibilityLabel("Add reaction")
            .accessibilityIdentifier("reaction.add")
            .popover(isPresented: $picking, arrowEdge: .bottom) { picker }
            } else if pillsOnly {
                // UX lab (Buzz): a small add-reaction button after the pills.
                Button { picking = true } label: {
                    Image(systemName: "face.smiling").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
                        .frame(width: side, height: side).background(Amb.muted, in: Capsule()).contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .ambTooltip("Add reaction")
                .accessibilityLabel("Add reaction")
                .accessibilityIdentifier("reaction.add")
                .popover(isPresented: $picking, arrowEdge: .bottom) { picker }
            }
        }
        .padding(.top, compact || pillsOnly ? 0 : quickActions ? 6 : 2).padding(.bottom, compact || pillsOnly ? 0 : quickActions ? 8 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reaction.bar")
    }

    private var picker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 4) {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Button { picking = false; toggle(emoji.rawValue) } label: {
                    Image(systemName: emoji.symbol).font(.system(size: 20)).foregroundStyle(emoji == .heart ? Amb.destructive : Amb.primary).frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emoji.name)
                .accessibilityIdentifier("react.\(emoji.rawValue)")
            }
        }
        .padding(8)
        .frame(width: 220)
        .presentationCompactAdaptation(.popover)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reaction.picker")
    }
}

/// An image or file attached to a message. Bytes come through the signed storage route on the pinned origin and are
/// cached; nothing is fetched while locked.
struct AttachmentView: View {
    @Environment(AppModel.self) private var model
    let attachment: MessageAttachment
    let workspace: WorkspaceRecord
    @State private var url: URL?
    @State private var preview: URL?

    var body: some View {
        if attachment.kind == "image" {
            // Inline, downsampled and cached like images in Markdown and documents.
            StorageImageView(objectId: attachment.storageObjectId, alt: attachment.filename, workspace: workspace, maxHeight: 260, maxWidth: 280)
        } else {
            Button {
                if let url { preview = url } else { model.downloadAttachment(attachment.storageObjectId, in: workspace) }
            } label: {
                Label(attachment.filename, systemImage: "paperclip").font(.amb(.footnote))
                    .padding(8).background(Amb.muted, in: RoundedRectangle(cornerRadius: Amb.radiusControl))
            }
            .buttonStyle(.plain)
            .quickLookPreview($preview)
            .accessibilityIdentifier("attachment")
            .task(id: attachment.storageObjectId) { load() }
            .onChange(of: model.syncStatus) { _, _ in if url == nil { load() } }
        }
    }

    private func load() {
        url = model.fileCache?.attachment(workspaceId: workspace.id, objectId: attachment.storageObjectId)
    }
}

/// Selected photos for the composer, privacy-stripped and staged before they join the outbox: one 72pt tile each in
/// the composer's strip (tap opens the photo, the corner control removes it).
struct ComposerAttachments: View {
    @Environment(\.imageLightbox) private var lightbox
    @Environment(\.displayScale) private var displayScale
    @State private var lightboxImage: LightboxImage?
    @Binding var attachments: [PendingAttachment]
    let staging: URL?
    @State private var thumbnails: [String: PlatformImage] = [:]

    var body: some View {
        ForEach(attachments.filter { $0.text == nil }) { a in
            Group {
                if let image = thumbnails[a.id] { Image(platformImage: image).resizable().scaledToFill() } else { Color(Amb.muted) }
            }
            .frame(width: ComposerTile.side, height: ComposerTile.side).clipShape(RoundedRectangle(cornerRadius: Amb.radiusPanel))
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel).stroke(Amb.border.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { open(a) }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Photo")
            .accessibilityHint("Opens the image")
            .accessibilityIdentifier("composer.attachment.image")
            .composerTile(remove: ComposerTileRemove(label: "Remove photo", identifier: "composer.attachment.remove") { remove(a) })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("composer.attachments")
            .imageLightboxCover(Binding(get: { lightboxImage?.objectId == a.id ? lightboxImage : nil }, set: { lightboxImage = $0 }))
            .task(id: a.id) { await thumbnail(a) }
        }
    }

    private func thumbnail(_ a: PendingAttachment) async {
        guard let staging else { return }
        let url = staging.appendingPathComponent(a.staged)
        let tile = ComposerTile.side * displayScale, scale = displayScale
        thumbnails[a.id] = await Task.detached { StorageImageCache.downsampleFilling(url, tile: tile, scale: scale) }.value
    }

    private func open(_ attachment: PendingAttachment) {
        guard let staging else { return }
        let shown = LightboxImage(objectId: attachment.id, file: staging.appendingPathComponent(attachment.staged), alt: attachment.filename)
        if let lightbox { lightbox.show(shown) } else { lightboxImage = shown }
    }

    private func remove(_ a: PendingAttachment) {
        attachments.removeAll { $0.id == a.id }
        if let staging { try? FileManager.default.removeItem(at: staging.appendingPathComponent(a.staged)) }
    }
}

/// Images and files already uploaded for this draft (their storage Markdown sits after the typed text), in the
/// composer's strip: a 72pt tile for each image that opens full size, a named chip for each file, each removable.
struct ComposerUploadedThumbnails: View {
    let text: String
    let workspace: WorkspaceRecord
    let remove: (String) -> Void

    var body: some View {
        ForEach(StorageMarkdown.rawReferences(in: text).map(\.attachment), id: \.storageObjectId) { item in
            let removal = ComposerTileRemove(label: "Remove \(item.filename)", identifier: "composer.uploaded.remove") { remove(item.storageObjectId) }
            Group {
                if item.kind == "image" {
                    StorageImageView(objectId: item.storageObjectId, alt: item.filename, workspace: workspace, fill: ComposerTile.side)
                        .composerTile(remove: removal)
                } else {
                    HStack(spacing: 0) {
                        Label(item.filename, systemImage: "paperclip").font(.amb(.footnote)).lineLimit(1).truncationMode(.middle)
                            .padding(.leading, 10)
                        removal
                    }
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(Amb.muted, in: RoundedRectangle(cornerRadius: Amb.radiusControl))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("composer.uploaded")
        }
    }
}

/// Images and files pasted into this composer while they upload: what is happening, and Retry / Remove. Only uploads
/// whose placeholder is still in the text are shown.
struct ComposerPastedUploads: View {
    let uploads: ComposerUploads
    let target: ChatTarget
    let text: String

    var body: some View {
        let shown = uploads.uploads(for: target).filter { UploadToken.contains(token: $0.token, in: text) }
        let notice = uploads.notice(for: target)
        if !shown.isEmpty || notice != nil {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(shown) { row($0) }
                if let notice {
                    Text(notice).font(.amb(.caption)).foregroundStyle(Amb.mutedForeground).accessibilityIdentifier("composer.upload.notice")
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
            .accessibilityIdentifier("composer.uploads")
        }
    }

    private func row(_ upload: ComposerUpload) -> some View {
        HStack(spacing: 8) {
            Image(systemName: upload.kind == .image ? "photo" : "doc").foregroundStyle(Amb.mutedForeground)
            VStack(alignment: .leading, spacing: 1) {
                Text(upload.filename).font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.foreground).lineLimit(1).truncationMode(.middle)
                Text(status(upload)).font(.amb(.caption)).foregroundStyle(isFailed(upload) ? Amb.destructive : Amb.mutedForeground).lineLimit(2)
                    .accessibilityIdentifier("composer.upload.status")
            }
            Spacer(minLength: 4)
            if upload.isActive { ProgressView().controlSize(.small) }
            if isFailed(upload), upload.retryable {
                Button("Retry") { uploads.retry(upload.id) }
                    .font(.amb(.footnote).weight(.semibold))
                    .accessibilityIdentifier("composer.upload.retry")
            }
            Button { uploads.remove(upload.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Amb.mutedForeground) }
                .accessibilityLabel("Remove \(upload.filename)")
                .accessibilityIdentifier("composer.upload.remove")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Amb.muted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composer.upload")
    }

    private func isFailed(_ upload: ComposerUpload) -> Bool { if case .failed = upload.phase { true } else { false } }

    private func status(_ upload: ComposerUpload) -> String {
        switch upload.phase {
        case .preparing: "Preparing…"
        case .waiting: "Waiting to upload…"
        case .uploading: "Uploading…"
        case .failed(let message): message
        case .done: "Uploaded"
        }
    }
}

extension PendingAttachment {
    /// Strips and stages one picked photo (off the main actor).
    /// A picked photo as a pasteboard-style item for the upload pipeline. Its bytes load only when the upload reads them.
    static func provider(_ item: PhotosPickerItem) -> NSItemProvider {
        let provider = NSItemProvider()
        let type = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .image
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            Task { @MainActor in
                do {
                    let data = try await item.loadTransferable(type: Data.self)
                    completion(data, nil)
                } catch { completion(nil, error) }
            }
            return nil
        }
        return provider
    }

    static func fromPicker(_ item: PhotosPickerItem, staging: URL) async -> PendingAttachment? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return await Task.detached {
            guard let png = try? ImagePrivacy.strippedPNG(data) else { return nil }
            return try? ImagePrivacy.stage(png, in: staging, filename: "photo.png")
        }.value
    }
}

enum MessageSyncState { case synced, pending, failed }

/// The small dot beside a message: green when Tower holds it (as the web shows), amber while a change waits to send, red
/// when Tower refused it.
struct SyncDot: View {
    let state: MessageSyncState

    private var details: (Color, String) {
        switch state {
        case .synced: (Amb.success, "Synced to Tower")
        case .pending: (Amb.warning, "Waiting to sync to Tower")
        case .failed: (Amb.destructive, "Not synced: Tower did not accept the change")
        }
    }

    var body: some View {
        Circle().fill(details.0).frame(width: 8, height: 8)
            .ambTooltip(details.1)
            .accessibilityLabel(details.1)
            .accessibilityIdentifier("message.sync.\(state)")
    }
}

#if os(macOS)
/// An ordinary stable AppKit button. SwiftUI's popup adaptor eagerly updates menu/accessibility content during
/// layout transactions; incoming replies must not rebuild that native menu graph on every unchanged message.
/// Keep the button identity and current actions, and construct the menu only on explicit user interaction.
struct NativeMessageAction {
    let title: String
    let symbol: String
    var children: [Self] = []
    var perform: (() -> Void)?

    init(_ title: String, _ symbol: String, children: [Self] = [], perform: (() -> Void)? = nil) {
        self.title = title; self.symbol = symbol; self.children = children; self.perform = perform
    }
}

struct NativeMessageActions: NSViewRepresentable {
    let items: [NativeMessageAction]
    /// The message menu by default; the focused thread header reuses this button for the thread menu.
    var identifier = "message.actions"
    var label = "Message actions"
    var help = "Opens the message action menu"

    func makeCoordinator() -> Coordinator { Coordinator(items: items) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .bold))
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.image?.isTemplate = true
        button.setAccessibilityLabel(label)
        button.setAccessibilityHelp(help)
        button.setAccessibilityIdentifier(identifier)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        MacHangDiagnostics.shared.mark("nativeMenu.update")
        context.coordinator.items = items
        // Avoid AX notifications for unchanged metadata while layout is already resolving AX.
        // Action closures still refresh on every update; the menu is built from the current items on open.
        if button.isEnabled != !items.isEmpty { button.isEnabled = !items.isEmpty }
        if button.accessibilityIdentifier() != identifier { MacHangDiagnostics.shared.mark("nativeMenu.metadataWrite"); button.setAccessibilityIdentifier(identifier) }
        if button.accessibilityLabel() != label { MacHangDiagnostics.shared.mark("nativeMenu.metadataWrite"); button.setAccessibilityLabel(label) }
        if button.accessibilityHelp() != help { MacHangDiagnostics.shared.mark("nativeMenu.metadataWrite"); button.setAccessibilityHelp(help) }
        if button.identifier?.rawValue != identifier { button.identifier = NSUserInterfaceItemIdentifier(identifier) }
    }

    final class Coordinator: NSObject {
        var items: [NativeMessageAction]
        weak var anchor: NSView?
        init(items: [NativeMessageAction]) { self.items = items }

        func openAtAnchor() {
            guard let anchor else { return }
            open(in: anchor)
        }
        @objc func open(_ button: NSButton) { open(in: button) }
        private func open(in view: NSView) {
            MacHangDiagnostics.shared.mark("nativeMenu.open")
            let menu = makeMenu(items)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.maxY), in: view)
        }
        private func makeMenu(_ actions: [NativeMessageAction]) -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for action in actions {
                let item = NSMenuItem(title: action.title, action: #selector(invoke(_:)), keyEquivalent: "")
                item.target = self
                item.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil)
                item.representedObject = Action(perform: action.perform)
                if !action.children.isEmpty { item.submenu = makeMenu(action.children) }
                menu.addItem(item)
            }
            return menu
        }
        @objc private func invoke(_ item: NSMenuItem) { (item.representedObject as? Action)?.perform?() }
    }
    private final class Action {
        let perform: (() -> Void)?
        init(perform: (() -> Void)?) { self.perform = perform }
    }
}

/// A noninteractive positioning anchor for a labelled SwiftUI Button. The button owns its ordinary
/// accessibility and hit region; no empty transparent NSButton or SwiftUI popup adaptor is needed.
struct NativeMenuAnchor: NSViewRepresentable {
    let items: [NativeMessageAction]
    let presenter: NativeMessageActions.Coordinator
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        let view = AnchorView()
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        view.setAccessibilityElement(false)
        presenter.anchor = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        presenter.items = items
        presenter.anchor = view
    }
    private final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

#endif
