# UX Lab change log

Lab-only file (never offered upstream). One entry per commit on UX branches: what changed and why.
Review: https://claude.ai/artifact/S4HCkDSDtn2gJtky9eWTNH

## Phase 1: Foundations (`ux/foundations`)

### 1.1 Palette (`style(theme): neutral palette with a single accent`)
- Neutral greys replace the blue-tinted light and navy dark palettes (Linear/Ari habit: true greys).
- One accent, a brighter purple (#6E56CF light / #7C6AE6 dark), used only for interaction, selection controls,
  focus, mentions and unread. Headings (`itemHeading`) and selected text are ink.
- One unread signal: accent dot (was orange in the sidebar, purple in notifications). Orange kept for urgency.
- Neutral fallback monograms (`monogram`, `monogramForeground`).
- Inbox types are told apart by icon; they no longer reuse info/warning/success colours.
- Task size and property chips on neutral fills.
- Touched: AmbulandoTheme, NativeChatTypography, Sidebar, Deck, Tasks, People avatar, Docs shadow, workspace tint base.

### 1.2 Surfaces and borders (`style(theme): surface layers and softer borders`)
- New surface tokens: `sidebar`, `raised`, `hoverFill`, `borderStrong`; `selectedFill` is its own grey.
- Borders much fainter, so separation comes from shade first.
- Mac sidebar sits on the recessed `sidebar` surface; Home row and workspace switcher lose their outlines.

### 1.2b Dark surfaces match Ari; neutral title bar (`style(theme): Ari dark surfaces and neutral window chrome`)
- Dark values now Ari's: chrome/sidebar #090A0B, page #0C0D0E, panel #121314, raised #17181A, hover #1C1D20,
  selected #222327, lines #222327/#2D2F33. Light lines/selected aligned to Ari too.
- Title bar is neutral window chrome (`Amb.sidebar`) instead of a 12% tint of the workspace colour (upstream
  `WorkspaceHeaderTint`). Workspace colour could return later as a small mark on the workspace avatar (shell phase).
- Mac section tab bar sits on the page surface, so the content column is one surface.

### 1.2c Halaska dark neutrals (`style(theme): Halaska neutral greys for dark mode`)
- Ari's dark scale still read slightly cool and its levels were too close to see selection. Dark mode only now uses
  Halaska UI's pure neutral greys with clearer steps: page #0A0A0A, chrome #111111, panels #171717, muted #202020,
  selected #262626, lines #262626; dark text #F2F2F2 / #8F8F8F / #6E6E6E.
- Light theme and the accent are unchanged from 1.2b.

### 1.2d Dark structure: darkest chrome, lighter content (`style(theme): dark chrome darkest, content a step lighter`)
- Test of a reference the user shared: in dark mode the window chrome (title bar + sidebar) is the darkest surface
  (#080808) and content sits a step lighter (#131313), with cards #1A1A1A, raised #1F1F1F, muted #232323 and
  selected #2A2A2A above it. Reverses 1.2c's order (page darker than sidebar). Light theme and accent unchanged.
- The rounded inset content panel from the reference is shell work (Phase 4).

### 1.2e Dark chrome from Ari, content from Linear (`style(theme): Ari chrome and Linear content in dark mode`)
- Dark mode only, two values: chrome/sidebar #090A0B (Ari), content page #0F1011 (Linear level 1). Cards and fills
  unchanged. Deck layering (page → section panel → row card → tiles) noted; flattening deferred to Phase 5.

### 1.3a Four text levels, preview (`style(theme): four text levels`)
- New `secondaryForeground` between ink and grey. Levels: foreground (content you read), secondaryForeground
  (supporting content), mutedForeground (metadata), faint (hints/empty states).
  Dark #EDEDED / #B8B8B8 / #8A8A8A / #636363; light #1B1C1F / #45474D / #6B6E75 / #9A9CA3.
- Preview promotions only: unselected sidebar channels, Deck inbox subtitles and thread previews, app/agent and
  canvas subtitles, notification bodies → secondary; "Nothing here" → faint. Full pass of ~240 uses comes in 1.3.

### 1.3 Geist, Mac type scale, tabular figures, text levels (`style(type): Geist type system`)
- Bundled Geist (Regular, Italic, Medium, SemiBold, Bold, BoldItalic, ExtraBold) and Geist Mono (Regular–Bold) in
  `Ambulando/Resources/Fonts` with the OFL licence; registered on first use. No project-file or Info.plist edits.
- New `Ambulando/Theme/AmbTypography.swift`: every `Font.amb` style is Geist; `.monospaced` → Geist Mono;
  serif/rounded → Geist (task and document titles leave the serif). Headlines semibold. Tabular figures everywhere.
- Mac scale (pt): caption 11, footnote 12, subheadline/callout 13, body/headline 14, title3 16, title2 18,
  title 22, largeTitle 28. Measured baseline was the system's 10/10/11/13/15/17/22/26, so Mac text is a point or
  two larger; the View › Text Size menu still scales it. iPhone/iPad keep Dynamic Type sizes, in Geist.
- AppKit composer uses Geist via `TextScale.nsFont`. Not yet Geist: iOS composer (UIKit), document body
  (`DocumentTypography`, web editor), ~37 hard-coded `.system(size:)` sites (mostly icons).
- Text levels, full pass: supporting content → secondary (search snippets, comment bodies, excerpts, attachment
  previews, WApp descriptions, suggestion details, agent activity lines, notification detail); empty states → faint.
  Remaining ~215 grey uses reviewed and left as metadata (timestamps, counts, labels, icons, status lines).
- Correction to the review: Mac text was not "large"; it was small (10–11pt for most labels).

### 1.4 Hover (`style(interaction): hover fills and hover-revealed row actions`)
- New `Ambulando/Theme/AmbHover.swift`: `ambHover` (hover fill), `ambHoverRow` (row hover group) and
  `ambRevealOnHover` (Mac-only: shown while the row is hovered; stays accessible and clickable).
- Applied to: Mac section tabs, sidebar Home row, scope headers and channel rows (channel ••• now appears on hover),
  Deck rows (shared `DeckRowStyle`), task cards. Not yet: Docs/Files lists (system List rows), chat messages
  (Phase 3), icon buttons (1.5).
- Known pre-existing failure: `-AmbulandoMacThreadRegression` fails "synced reply must render in actual thread" on
  upstream main + the Xcode 27 fix alone (no lab UX changes), so it's environmental (Xcode/macOS 27), not ours.

### 1.4b Linear dark theme and translucent hover (`style(theme): Linear dark theme and overlay hover`)
- User still disliked the dark colours; dark mode now uses Linear's dark theme values (linear.app `[data-theme=dark]`):
  chrome #08090A, page #0F1011, cards #141516, raised #1C1C1F, muted #191A1B, selected #232326, lines
  #23252A/#34343A, text #F7F8F8 / #D0D6E0 / #8A8F98 / #62666D. Light theme and accent unchanged.
- Hover is now a translucent overlay like Linear's (black 4% light, white 5% dark) instead of a solid grey; the old
  light hover (#F0F0F2, about 6% black) was too dark. New `PlatformColor.overlay(lightBlack:darkWhite:)`.
- Fix (1.4c): with the translucent hover, sidebar channel rows drew two stacked hover layers (row + row group), so the
  inner part looked darker. `ambHover` now steps aside inside an `ambHoverRow`, leaving one fill.

### 1.5 Buttons (`style(controls): four-button system`)
- New `Ambulando/Theme/AmbButtons.swift`: `.ambPrimary` (filled violet), `.ambSecondary` (grey fill, ink label;
  red label for `role: .destructive`), `.ambGhost` (fill on hover), `.ambIcon` (grey glyph → ink on hover, hover fill).
  Mac heights 24/28pt by control size; iPhone/iPad keep 44pt hit areas.
- Swapped all 21 system `.bordered`/`.borderedProminent` buttons in app views (canvas, docs, management, sidebar,
  workspaces) to secondary/primary. Settings buttons (Manage Workspace, Lock now, Remove identity, Refresh Nostr
  profiles) → secondary; "Mark all read" and Tasks "Select" → ghost.
- Mac `iconButton()` (composer photo/file/@ and others) → `.ambIcon`, so icon buttons are grey instead of accent.
- One add button: Tasks, Docs, Files, Deck inbox and Canvas "+" are all `.ambIcon` with a plain plus.
- Deck type filters lose their outlines (fill when on, hover otherwise). Decorative record icons (canvas, doc,
  agent, naplet) grey instead of accent.

### 1.6 Spacing values (`style(theme): spacing scale`)
- `Amb.Space` (2/4/8/12/16/24/32) and `Amb.rowHeight` (32). No visual change; later phases use them as each screen
  is reworked instead of converting all ~245 literal paddings at once (keeps merges with upstream small).

## Phase 2: Copy (`ux/copy`, off `lab` after Phase 1 merged)

### 2.1 Developer language and terminology (`copy: plain language`)
- Removed or rewrote developer text: unsupported-block placeholder, "Saved relationship list.", Toolbox HTTPS and
  "Web content ·" lines, WApps explainer, canvas sharing note, agent launch lines, FIPS notes (Settings, Connect,
  Agents), "Transport: HTTPS + NIP-98" → "Security: Signed requests", delete-workspace and edit-takeover dialogs,
  "Flight Deck" notification source label hidden.
- Terminology: "Tower" kept only for choosing/connecting a server (Settings shows "Server"); napplet/WApp → app;
  Nostr key → identity; "Nostr profiles" → "Public profiles". 32 help/confirmation strings rewritten.
- Deck greeting by time of day (new `DeckGreeting.swift`).
- Updated `SurfacesUITests` for the new Toolbox "Can't open" string.
- Left as is: agent activation consent text (security disclosure), connection/Tower-picking screens, Test-app banner.
- New `DECISIONS.md`: short rationale log for Pete and his agents.

### 2.2 Keep "Tower" (`copy: keep Tower as the product name for the server`)
- User decision: own the term. Restored "Tower" in 17 strings where it names the server (Settings row, diagnostics,
  uploads, unlock, archive/delete/avatar notes, notifications, scope setup, membership). Sentences about Tower's
  internal checks stay removed. Rock/Pebble/Sand logged as an open decision.

### 2.3 Tooltips (`copy: tooltips for task sizes and icon buttons`)
- New `TaskPriorityHelp.swift`: one-line help per task size ("big rocks first"), shown on priority badges, the task
  priority menu and the edit picker.
- Tooltips on icon-only buttons: composer photo/file/mention, Deck inbox new thread and type filters, Tasks/Docs/
  Files add buttons, task list/board toggle. Rule: only unexplained terms and icon-only controls.

### 2.4 Themed tooltips (`style(controls): themed tooltips`)
- New `Ambulando/Theme/AmbTooltip.swift`: `ambTooltip(_:)` draws a themed tooltip on the Mac (raised surface,
  borderStrong hairline, soft shadow, Geist caption, max 280pt, line breaks allowed) in a borderless non-activating
  panel after 0.6s; switches instantly between tooltips; continuous hover so parent redraws don't cancel it. iOS
  falls back to `.help`. Text also set as the accessibility hint.
- All 31 `.help(...)` uses in app views now use `ambTooltip`. Task-size picker tooltip is a three-line list.
- DECISIONS.md: removed "confirm with Pete" phrasing; entries state the decision and rationale only.
- Fix (2.4b): tooltips could appear far from the hovered item (placed at the pointer when shown, and a hover-ended
  event can be missed when a parent row redraws). Now anchored to the item's frame (centred below, above near the
  screen edge), shown only if the pointer is still on the item, and hidden by a 0.1s watch as soon as it leaves.

## Phase 3: Chat (`ux/chat`, off `lab` after Phase 2 merged)

### 3.1 Flat, grouped messages (`style(chat): flat grouped messages with a hover toolbar`)
- `ConversationCard` is a flat row (no card fill or border). Mac message padding 12/8→4 (was 24/14).
- New `ChatGrouping.swift`: posts continuing the same sender within 5 min (no day break, previous without replies)
  drop the avatar and name line; VoiceOver hint keeps sender and time.
- `MessageCell`: whole message is an `ambHoverRow`; Mac hover toolbar (quick 👍, reaction picker, •••) in a raised
  pill floating over the top edge; reactions below only when present (`ReactionBar quickActions: false`), pills
  borderless (muted fill, yours on the soft accent). iOS keeps the existing reaction bar.
- `SyncDot` hidden while synced (kept in the accessibility tree; `ComposerParityUITests` still finds it).
- `ReactionFlowLayout` reports the width it uses, not the proposed width.
- `AmbRevealPolicy`: hover-revealed controls stay visible with VoiceOver, Full Keyboard Access or `-AmbulandoMac*`
  checks (read once at launch). Found via `-AmbulandoMacThreadRegression`; it now fails only at the known
  environmental step.

### 3.1b Conversations, not chat lines (`style(chat): channel as a list of conversations`)
- User feedback: grouping merged separate conversations (each channel post is a thread root, often titled and long).
  Grouping removed from the channel; `ChatGrouping.continuedReplies` now groups same-sender replies inside a thread
  only, and the thread view drops the rule between replies.
- `ConversationCard`: block with 6pt vertical padding and a hairline between conversations (no card).
- Thread title (when Tower's differs from the body) is the block heading (headline, ink), not a caption with icon.
- Reply footer: quiet line (icon, "N replies" in accent, "Last reply …" in metadata grey), no rule above.
- New `CollapsibleMessageBody.swift`: channel bodies over ~5 lines are cut with a fade and "Read more" (the block
  opens the thread). Inline expansion was tried; the block's thread link wins the click on the Mac.
- `ThreadTitleText.clean`: thread header titles derived from a body drop Markdown marks ("## Build checklist" →
  "Build checklist"). Pre-existing bug.
- Known: hover toolbars on channel rows can stay visible behind the thread overlay (hover-ended not delivered);
  to fix with the thread side panel (3.3). Reply participants aren't in the feed data, so the footer has no avatars.

### 3.2 Composer (`style(chat): single-box composer on the Mac`)
- Mac `Composer` layout: one rounded box on `Amb.raised` with a hairline (accent when focused); text on top; photo,
  file and @ tools in a row inside the bottom edge (28pt, regular weight); 28pt send button (accent when sendable).
  iPhone/iPad layout unchanged (keyboard handling). Same component for channel and thread replies.
- Verified with `-AmbulandoMacThreadRegression` (presses `composer.send`; fails only at the known later step).

### 3.3 Thread side panel (`style(chat): threads in a side panel on the Mac`)
- `ThreadFocusPresenter` (Mac): an open thread is a `MacThreadSidePanel` — a trailing safe-area inset (the shell
  keeps its own layout and narrows) with a draggable hairline (340–760pt, stored as `ux.threadPanelWidth`, clamped to
  45% of the window). Full screen overlays the shell. Composing a new thread is still modal. Panel isn't `.isModal`.
- The conversation open in the panel is shown selected in the channel (`MessageCell.isOpenInPanel`).
- Found by `-AmbulandoMacThreadRegression`: wrapping the shell in an HStack clipped the section bar; an unclamped
  fixed-width panel caused an AppKit constraint loop when the window shrank. Both fixed; harness back to the known
  environmental failure.
- Known: the section tab bar clips ("To…") when the panel narrows the window — shell work (Phase 4).

### 3.4 Threads in place of the list (`style(chat): threads open in place in their channel`)
- Replaces 3.3's side panel (user: two chats side by side; panel floated over other sections).
- Mac: `ChannelView` overlays `ThreadFocusPanel(inline: true)` when the focused thread belongs to it (back chevron
  with the channel name, Esc, no full-screen toggle); registers itself in `InlineThreadHosts`. `ThreadFocusPresenter`
  shows the modal only when no channel hosts the thread. Leaving Chat or the channel closes an inline thread.
- Modal header gains "Open in #channel" (choose channel → Chat → refocus, since choosing a channel goes to Deck and
  clears the thread).
- Channel composer placeholder: "Start a thread in #…". Thread replies inset 8pt so hover doesn't touch the edges.
- Removed `MacThreadSidePanel`. Harness back at the known failure; iOS builds.
- Next: optional side-by-side (list + thread) toggle; Solo section with the Phase 4 sidebar.

### 3.5 Chat bubbles in a reading column (`style(chat): bubbles in a centred column on the Mac`)
- User direction (Buzz reference): messages as bubbles, your own on the right, real side margins instead of full width.
- New `ChatBubbles.swift`: `BubbleMessageRow` (name and time above, bubble sized to its text, 32pt avatar level with the
  bubble's last line; reactions inside the bubble; reply summary below), `chatColumn()` (centred, 820pt + 24pt
  margins, follows text size), `chatBubbleFit` environment so `RichBlocksView`/`MessageBody` fit their text in a bubble.
- Theme: `Amb.bubble` (neutral), `Amb.bubbleMine` (soft violet), `radiusBubble` 18, `chatColumnWidth` 820.
- `MessageCell` picks the bubble layout on the Mac (`flatCell` kept for iPhone/iPad); hover darkens the bubble and
  shows the toolbar (on the left for your messages). Thread runs show the avatar on the run's last message
  (`lastInRun`). `OutboxRow` shows your unsent message as your bubble with its delivery state below.
- Channel and thread content and their composers sit in the column; no hairline between channel conversations and no
  divider or card band above the composer on the Mac.
- iPhone/iPad unchanged (all gated on `ChatBubbles.enabled`); iOS builds.
- `-AmbulandoMacThreadRegression`: the channel-opened thread scenario now passes fully (it used to stop at "synced
  reply must render"). The Deck-composed quick-view scenario now fails later, at "native menu must open and perform
  FD Ref" after 12 synced replies. Likely cause, not verified: the harness clicks the first message's menu, which
  taller bubble rows scroll out of view.

### 3.5b Bubbles only for your own thread messages (`style(chat): bubbles only for your own messages in a thread`)
- User feedback: the channel list had become chat, and bubbles round everything (long agent replies, tables) don't
  work. Kept: the centred column and your messages on the right.
- New `chatThreadLayout` environment (set by `ThreadView`): `MessageCell` uses the bubble only for your own messages
  in a thread; everything else is the flat row. `OutboxRow` likewise. Channel conversations are flat blocks with the
  hairline again (`ConversationCard` restored), inside the column.
- `UXLabOptions.hideSampleBanner`: launch the Test app with `-UXHideSampleBanner YES` (or `defaults write`) to hide the
  sample-data banner. Ignored while `-AmbulandoMac*` checks run (they find the window by the banner).

### 3.6 Flat thread messages, yours on the right (`style(chat): flat thread messages, yours on the right, agent avatars`)
- User feedback: bubbles suit Slack-style back-and-forth, not briefs and long agent replies. Bubbles removed.
- `ChatBubbles.swift` → `ChatLayout.swift`. `OwnMessageRow`: in a thread your message is the flat row mirrored to the
  right (time, name, avatar; text still left-aligned, fits its width); hover toolbar on the left. `OutboxRow` matches.
- More air between senders in a thread (`ChatLayout.senderGap` 14pt above a new sender; runs stay tight).
- Agents get rounded-square avatars (`AvatarShape`; `PersonAvatar`/`InitialsAvatar` take `agent:`), in messages and
  the channel list. Bubble tokens removed from the theme; `chatColumnWidth` kept.

### 3.7 Relative times (`style(chat): relative message times`)
- `MessageTimeText` / `RelativeTime`: today "now", "12m ago", "3h ago" (refreshes each minute); older: clock time in a
  thread (day label above), "Yesterday" / weekday / "17 Nov" elsewhere. Exact date and time in the tooltip.
- `-AmbulandoMacThreadRegression` crashed once in five runs with an AppKit "Update Constraints in Window" loop during
  the resize steps; four runs (with and without the time tooltip) ended at the known failure. Cause not found.

### 3.8 Channel as a list of conversations (`style(chat): channel as a list of conversations, newest activity first`)
- Direction A from the channel-list mockups (https://claude.ai/artifact/7NSjSt4mPHP96Y8wEnZ5og), after the live app's
  Threads view (upstream removed it in `7908759`, Mac build 22; Andy's build 19 still has it).
- New Core read `channelConversations` (new file `ChannelConversations.swift`; `channelFeed` untouched): newest
  activity first, reply count, newest reply, up to four participants, unread (thread view state), agent lifecycles.
- New `ChannelConversationList.swift` (Mac): All / Unread / Mine filters; "New thread" opens the existing composer
  (`model.composingThread`); rows show unread dot, title, brief (when it adds to the title), participant avatars,
  newest reply ("You:" for yours, Markdown stripped) or "Rick is working" with pulsing dots, starter name when no
  replies, relative time and reply count. Opens in place as before. No composer under the list.
- iPhone/iPad keep the message feed. Channel refreshes on view-state and agent changes too. iOS builds; regression
  harness at the known failure.
- Not carried over to the list: the per-message actions on a conversation's first message (they're in the thread).

### 3.9 New thread in place; list alignment (`style(chat): new thread opens in place; list titles line up with filters`)
- User: New thread opened a modal rather than a thread screen. `InlineNewThread` replaces the list like an open thread
  (← #channel, "New thread", a hint, the composer; Esc goes back), shows your pending message, then opens the new
  thread in place once Tower creates it (same sent-message watch as the Deck composer). Deck's modal is unchanged.
- Row titles, briefs and hairlines start on the filter labels' line; the unread dot hangs in the margin.

### 3.10 Thread participants; quick-view margins (`style(chat): thread participants in the header; roomier quick-view column`)
- `ParticipantFacepile` on the thread row (inline and quick-view), before the pin: up to three avatars, most recent on
  top, agents as rounded squares, "+N", names in the tooltip. From the thread's stored history (`ThreadParticipants`
  in `ThreadSnapshot`, passed up by preference). Placed on the thread row, not the scope/channel row: they belong to
  the conversation.
- `chatColumn()` is now a modifier: in the quick-view modal (`chatInModal`) the column is 720pt with 48pt margins
  (was the full 820pt + 24pt, which ran nearly edge to edge in a smaller window).
- Harness at the known failure.
- 3.10b (`style(chat): reading column in the New thread modal`): the Deck's New thread modal (`DeckThreadComposer`,
  Mac) uses the same 720pt quick-view column; it ran edge to edge. One call-site line in `DeckViews.swift`.

### 3.11 Channel menu in New thread (`fix(deck): channel menu in the Mac New thread composer`)
- Upstream (Mac build 23, `f4bdd65`) replaced the Mac channel picker with a button that opens an inline `List`; in the
  modal it read as a broken grey box. Mac now has a "Channel  #general ⌄" menu (as in Mac build 19). With no channel
  chosen (Home), plain hover rows keep `deck.compose.option.*` for `MacDeckComposerCheck` (passes). iPhone/iPad
  unchanged.

### 3.12 Own-message spacing (`style(chat): more room around your own messages' name and avatar`)
- Your messages (sent and unsent): 14pt between text and avatar (was 10), 9pt between name line and text (was 6),
  8pt between time and name (was 6). Other people's rows unchanged.
- 3.11b (`fix(deck): Channel menu is the only channel control on the Mac`): the plain rows kept for the check showed
  under the menu as a second picker (user: "why do we have both"). Removed; the hint reads "Choose a channel to start
  your thread." `MacDeckComposerCheck` now picks #general through the real menu (`menuAction`); passes.
- 3.12b (`style(chat): your messages' highlight hugs the message with even padding`): user: bottom padding thinner
  than elsewhere and the hover stretched edge to edge. `OwnMessageRow` draws its own highlight on the message block
  only (10pt inset on all four sides, `ambHoverTracking()` for hover without a row fill); the gap between senders is
  outside it; the hover toolbar hangs just left of the message instead of covering the name and time. Unsent messages
  use the same geometry. Other people's rows unchanged (their highlight still spans the row, 14pt top / 4pt bottom).
- 3.12c (`style(chat): roomier sides on your messages' highlight`): 16pt sides, 12pt top and bottom.

### 3.13 Reactions (`style(chat): compact reactions right under the text, with an add button`)
- After Buzz (`Messages.module.css` `.reactions`): pills 24pt (was 28) with caption counts and tabular figures, 4pt
  apart, 6pt under the text and aligned with it (yours were right-aligned ~40pt below, inflating the hover area), then
  a small add-reaction button (same picker as the toolbar). Mac only; iPhone/iPad keep their bar. Picker content
  shared by both buttons.

### 3.14–3.18 Rough edges before Phase 4
- 3.14 (`style(chat): others' thread messages get the hugging, even-padded highlight`): `threadCell` in
  `MessageCell` (Mac, thread, not yours): `MessageRow(bare:)` inside `messageHighlight(continued:)` (16pt sides, 12pt
  top/bottom, 4pt in a same-sender run; text hugs), sender gap outside; toolbar stays at the row's top right. Yours use
  the same modifier.
- 3.15 (`fix(chat): one sample banner in thread panels; reopen the channel's thread on return`): `threadInPanel`
  environment drops ThreadView's own sample banner inside the Mac thread panel. `InlineThreadMemory` remembers the
  thread each channel had open in place; leaving Chat or switching channel and coming back reopens it; closing it
  yourself (back, Esc) forgets it. In memory only.
- 3.16 (`fix(chat): switching section closes the quick-view and New thread modals`): `ThreadFocusPresenter` watches
  section changes; the quick-view and New thread modals close unless the same change opened the thread (Open in
  #channel).
- Section tab bar clipping: no change needed. The side panel that caused it is gone; at the window's 900pt minimum
  the labelled tabs fit, and `MacSectionBar` falls back to icons only (`ViewThatFits`) before clipping.
- 3.17 (`style(deck): New thread composer lines up with the text above`): Mac composer in `DeckThreadComposer` offset
  by its own 16pt inset.
- 3.18 (`style(chat): channel participants facepile beside New thread`): everyone in the channel's conversations,
  most recent first, agents as rounded squares, names in the tooltip.
- Checks for the batch: thread harness at the known failure; `MacDeckComposerCheck` passes; iOS builds.

## Upstream merge (2026-11-20)
- `main` fast-forwarded to upstream `548b4e8` (Pete: Mac "Refresh data" without discarding current work) and merged
  into `lab` (`bb2e379`). Two neighbouring-line conflicts, both kept: `ThreadFocus.swift` header = facepile, then
  Pete's `MacRefreshDataButton`, then pin and menu; `MacWorkspaceShell.swift` section row = Pete's button with the
  lab's `Amb.background`. Project file identical to upstream.
- Checks: thread harness at the known failure. Pete's new `-AmbulandoMacDataRefreshCheck` fails at "Timed out: same
  open thread receives remote reply", and fails the same way on upstream itself (`main` + the Xcode 27 fix), so it's
  the same environmental synced-reply issue, not the lab.

## Phase 4: Sidebar (`ux/sidebar`, off `lab` after Phase 3 and the upstream merge)

Proposal and agreed decisions: https://claude.ai/artifact/NbziWbiYt1WhQc56PqrXtt. Mac only throughout: the shared
`SidebarContent` stays as it is for the iPhone drawer and iPad.

### 4.1 One sidebar row (`style(sidebar): one row component for the Mac sidebar`)
- `Amb.SidebarLayout` tokens (row 28pt, 8pt gutter and inset, 16pt mark slot, 8pt gap, 24pt indent, 20pt trailing
  slot, 18pt section gap) and `SidebarRow` (new `AmbSidebarRow.swift`), with `SidebarSectionHeading`,
  `SidebarRowButton` and `SidebarUnreadDot`.
- New `MacSidebarContent` (AmbulandoMac) lays out today's content with it; `MacSidebar` uses it. Same content,
  behaviour and accessibility identifiers. Home, Unread & Active, a new "Scopes" heading, scopes, channels and
  Manage scopes are all the same row: same height, radius, type and full-width hover/selection. Indent is inside the
  row; a nested row's mark lines up with its parent's label.
- Scope rows: the chevron sits in the mark slot and folds the channels; the rest of the row opens the scope. Its +
  (New channel) and a channel's ••• (Channel settings) now live in the row's trailing slot and appear on hover,
  replacing the unread dot while hovered. Previously the ••• was a 44pt button outside the row, which made channel
  rows narrower than Home.
- Workspace switcher (shared `WorkspaceFooter`, now internal) is a row on the Mac rather than a filled card.
- `ambHoverRow(fill:)` can track hover without drawing a fill (used by section headings).
- Several enabled workspaces still use the shared stacked navigation; restyle later if needed.
- Checks: thread harness at the known failure (one earlier run hit the known intermittent AppKit crash in the resize
  steps; the rerun passed them). `MacDeckComposerCheck` passes. iOS builds. No iPad check needed (Mac-only views).

### 4.2 Sections (`style(sidebar): no Unread & Active; Manage scopes on the Scopes heading`)
- "Unread & Active" removed from the Mac sidebar: unread channels already show bold with a dot in place.
- "Manage scopes" is the Scopes heading's hover action (slider icon, tooltip, same identifier) instead of a row
  under the last scope. Several workspaces keep the row.

### 4.3 Solo (`feat(sidebar): Solo section for your conversations with agents`)
- New shared `SoloConversations` (which DMs are Solo: you plus only agents, or Note to self; their conversations newest
  activity first) and `SoloDirectory` (the Solo channel ids, and a pending New chat). Mac view `MacSoloSection`.
- Sidebar: a "Solo" section under Home, one row per conversation (title, the agent's rounded-square avatar or a note
  icon, unread dot or a spinner while an agent works), 8 shown then "Show all". Solo DMs no longer repeat under the
  DMs scope. Reads the local store only (background sync already catches up every channel).
- Opening one selects its DM in Chat and opens the thread in place (the 3.4 inline thread). In a Solo DM the header
  reads "Solo · Rick" instead of "← Rick", and Esc doesn't close it: there's no list to go back to.
- + on the Solo heading: a menu of the workspace's agents and Note to self. Opens the New chat composer in your DM
  with them; with no DM yet, upstream's New message sheet for the DM scope.
- New thread composer in a DM: "New chat", "Start a conversation with Rick", and the DM's name without a "#".
- Test app: `-UXSampleDMs YES` adds sample DMs (Rick: four conversations; Note to self; Ana; Bea). Off by default so the
  app's checks keep their layout.
- Not yet: the DM's conversation list still shows if the thread is closed some other way; unread counts on Solo depend
  on view states, which the sample data doesn't set.

### 4.4 Direct messages (`feat(sidebar): Direct messages section for DMs with people`)
- DM scopes no longer appear under Scopes. DMs with people (and group DMs) are a "Direct messages" section at the
  bottom: the person's avatar, unread dot, ••• Channel settings; + on the heading starts one (upstream's New message
  sheet). DMs with only agents stay under Solo.

### 4.5 Section tabs in the content header (`feat(mac): place header with section tabs; sidebar choices keep the tab`)
- New `MacPlaceHeader` replaces the section bar and the context strip ("All scopes | Everything"): sidebar toggle,
  the place's name ("Home Studio", "Ambulando", "Ambulando / # general", "Solo / Rick", "Ana Lima", "Toolbox"),
  refresh, and under it the tabs Deck · Chat · Tasks · Docs · Files (underlined when selected; same `section.*`
  identifiers). No tabs for a direct message (Solo or with people) or for Toolbox.
- Choosing Home, a scope or a channel keeps the current tab (`AppModel.choosePlace`), replacing the web's jump to
  Deck and the lock; from Toolbox it opens Deck. A direct message opens in Chat (`openConversation`).
- Toolbox is a sidebar row under Home, since it ignores the place. `ContextBar` draws nothing on the Mac (iPhone and
  iPad unchanged).

### 4.6 Polish to the mockup (`style(sidebar): heading actions shown, one-letter small avatars, scope chevron after the name`)
- Section heading actions (+, Manage scopes) always shown, quiet, instead of on hover.
- Avatars at sidebar size (≤18pt) show one letter, larger: "R" not "RI" (`InitialsAvatar`, `WorkspaceAvatar`).
- Scope rows: a scope mark in front and the fold chevron right after the name (`SidebarRow` group layout); the rest
  of the row still opens the scope.
- Checks for Phase 4 (run once for the batch): thread harness at the known failure ("synced reply must render in
  actual thread"); `MacDeckComposerCheck` passes; iOS builds. Earlier runs on this branch twice hit the known
  intermittent AppKit crash in the harness's window-resize steps. No iPad check needed: the Mac sidebar, header and
  Solo views are Mac-only; shared edits (`ContextBar`, `WorkspaceFooter`, avatars at ≤18pt) are Mac-gated or affect
  no iPad size in use.
- Differs from upstream (for Pete): a sidebar choice keeps the tab instead of opening Deck (no lock); DM scopes are
  split into Solo (agents only) and Direct messages (people); channels list conversations by newest activity.

### 4.7 Sidebar width (`fix(mac): sidebar opens at 248pt, resizable 200–380 and remembered`)
- The shell's `HSplitView` ignored the sidebar's ideal width and always opened it at its widest (380pt). Now a plain
  row with a stored width (`ux.sidebarWidth`, default 248pt, Ari 232 / Linear ~240) and `MacSidebarResizer`: a
  hairline edge with an 8pt grab area that drags between 200 and 380pt. Membership stays stable while hidden.
- `SidebarRow` group rows: the name takes room before the space after its chevron (no "Operatio…" at 248pt).

### 4.8 Solo as a scope (`feat(sidebar): Solo rows are your agent DMs, places with tabs`)
- Andy's live app treats a DM (e.g. with Lara) as a place with Deck, Chat, Tasks, Docs and Files. Solo now does the
  same: its rows are your DMs with agents and Note to self (most recent activity first; unread dot; spinner while an
  agent works), and choosing one keeps the current tab. Its Chat tab is the list of every chat with that agent.
  Replaces 4.3's one row per conversation and "Show all".
- Direct messages with people also keep the tab instead of opening Chat without tabs; the header reads
  "Solo / Rick" or "Direct messages / Ana Lima", with tabs.
- Thread header back to the standard "← Rick" (the Solo-only header and Esc rule from 4.3 removed: there is a list
  to go back to now). + New chat unchanged.

### 4.9 Chat channel list grouped like the sidebar (`style(chat): channel list as Solo, scopes, Direct messages`)
- The Chat tab at Home or a scope (upstream `ChannelDirectoryView`) listed every DM under one "DMs" scope. On the
  Mac its sections now follow the sidebar: Solo, the scopes, then Direct messages (`directorySections`). iPhone and
  iPad unchanged. The screen's design itself is untouched (still upstream's list).

## Phase 5: Content screens (`ux/content`, off `lab` after Phase 4)

Proposal and mockups: https://claude.ai/artifact/PFA62Dm9pTnTHMNrHH686J. Mac only unless noted.

### 5.0 Start tab for captures (`test(fixture): -UXStartTab opens the sample app on a tab`)
- `-UXStartTab deck|chat|tasks|docs|files` opens the Test app on that tab (sample data only; ignored outside the
  fixture). For screen captures without clicking.

### 5.1 Shared list pieces (`style(theme): content list header, section label and row`)
- `Amb.ListLayout` tokens (20pt leading margin for the unread dot, 16pt trailing, 38pt one-line rows, 10pt column
  gap, 18/6pt section spacing, fixed size/place/person column widths) and new `AmbContentList.swift`:
  `ContentListHeader`, `ContentListSectionLabel` (mark, name, count; space above, never a rule) and
  `.contentListRow(first:)` (hover fill, inset hairline above all but a section's first row). Used by Tasks first.

### 5.4 Tasks list (`style(tasks): one-line task rows grouped by status`)
- Mac list is new `MacTaskList`: groups labelled by a status ring, name and count; rows are one line: status ring,
  title (muted when done), then size, channel and assignee in fixed columns. Rows no longer repeat the status chip.
- Status ring (`TaskStatusRing`): open for not started, half for in progress and review, full for done.
- Size (`TaskSizeLabel`): a dot scaled to the size and the word (Rock, Pebble, Sand), Rock in the urgency orange;
  Phase 2 tooltip kept. Replaces the all-caps pill on the Mac list.
- Start and Mark done in each row's context menu (the iPhone list has them as swipes).
- "New task" is a labelled primary button; the List/Board switch uses the selected grey, not the accent.
- iPhone and iPad unchanged (`listView`); no iPad check needed.

### 5.4b Flatter board (`style(tasks): board columns on the page, cards the only layer`)
- Mac board: open columns lose their grey fill (a collapsed column keeps its strip); cards get a hairline edge;
  column headings use the list's status ring and name instead of a chip; card size shows as `TaskSizeLabel`.
- `-UXStartTab board` opens Tasks as a board in the sample app, for captures.
- iPhone and iPad unchanged; no iPad check needed.

### 5.2 Chat tab at Home or a scope (`feat(chat): the place's conversations, newest activity first`)
- New `MacPlaceConversations` replaces the Mac channel directory (`ChannelDirectoryView`, still used on iPhone and
  iPad): every conversation in the place's channels (a scope's, or all at Home, Solo and DMs included), newest
  activity first, using the channel's `ConversationRow` (now internal). Filters All · Unread · Mine; New thread opens
  the composer with its channel menu. A conversation opens in place of the list (the channels are inline-thread
  hosts while it's shown); leaving Chat closes it.
- Rows say where they live (`ConversationPlace`): "# deploys", or a DM's person or agent (face and name) or Note to
  self. A DM shows its face once: no facepile, and the other person's own messages don't repeat their name.
- Supersedes 4.9's grouped directory on the Mac. Rounds 1–3: https://claude.ai/artifact/PFA62Dm9pTnTHMNrHH686J.
- No iPad check needed (Mac paths only).

### 5.4c Board lanes (`style(tasks): each board status is a lane`)
- Mac board: each column is a lane again, recessed (`Amb.canvas`) with a hairline edge, as gr8r-studio's board (B2 of
  round 3); bordered cards from 5.4b sit on it. No "Add task" at the foot. Columns keep their 280pt width and scroll.

### 5.4d Board moves animate (`style(tasks): cards slide between lanes`)
- Moving a card to another status made it vanish from one lane and reappear in the other. Cards now keep their
  identity across lanes (`matchedGeometryEffect`), and the board springs to the new placement (0.38s), so the card
  slides over and both lanes close and open the gap; the drop highlight fades in and out. Same for bulk moves.
- Not watched in motion here (no mouse in the lab session); needs a hand check.

### 5.4e Task table (`style(tasks): task list as a table, after gr8r-studio`)
- Replaces 5.4's list layout (Andy: gr8r-studio's layout, our look). `MacTaskList` is now a table: toolbar (Search
  tasks, Sort: Manual/Size/Updated/Title, Group: Status/Size/Assignee/Channel; remembered), a row of column labels
  (Task, Size and Updated sort when clicked), group rows (fold chevron, mark, name, count, +; hairline under; folds
  remembered), and one-line tasks with hairlines between: title (subtasks done/total), Status (ring and word),
  Assignee (face and name, or "Unassigned"), Size (dot and word), Channel (hidden inside a channel), Updated, and •••
  on hover (Start, Mark done, Move to).
- A group's + opens New task with that status (`TaskCreateSheet.initialState`; status grouping only).
- New tokens `Amb.ListLayout.statusColumn`, `timeColumn`, `actionColumn`. `-UXStartTab tasks` now opens the list.
- Not taken from gr8r: checkboxes and bulk bar (bulk select stays on the board), "Add task" rows, task keys, due dates
  and labels (Ambulando tasks have none). Mockup rounds 4–5 (Linear-led) were not chosen.
- No iPad check needed: `TaskCreateSheet` gains an optional status that only the Mac list passes.

### 5.4f Select tasks for bulk changes (`feat(tasks): tick boxes and a bulk bar in the task table`)
- Each task row starts with a tick box (accent when ticked; `TaskCheckbox`), under the group row's chevron; the title
  is indented to line up with the group's name, as in gr8r-studio. The labels row has Select all (with a part-ticked
  state). Ticked rows take the selected fill.
- With anything ticked, a bar floats at the bottom: "N selected" · Status · Assignee · Size · Archive · ✕ (or Esc).
  Status, Assignee and Size send the same writes as one task's edits (state, assign with its version check, size as a
  task edit); Archive asks first (the board's confirmation). The selection is the board's, cleared on switching.
- Content-list hover and selection fills stay within the rows' hairlines (`ambHoverRow(inset:)`) instead of running
  to the window edge.
- `-UXSelectTasks 2` ticks the first tasks in the sample app, for captures.
- No iPad check needed: `ambHoverRow`'s new inset defaults to none; the list is Mac only.

### 5.4g Task table rules and indent (`style(tasks): a rule under every task, titles indented inside their group`)
- Every task row has a hairline under it (a group's last task too), and rules start at the tick box's edge, as in
  gr8r-studio; before, the last task had none and rules started a few points right of the boxes.
- Titles (and the Task label) sit 20pt past the group's name, so tasks read as inside their status group.

### 5.4h Drag tasks; full-width hover (`feat(tasks): drag tasks by a handle to reorder or regroup`)
- With Sort: Manual, a six-dot handle appears in the left margin on hover (`TaskGrip`). Drag a task by it: a 2pt
  accent line shows where it lands (above or below a task, or at the top of a group). Dropping it in another group
  changes that value (status, size or assignee, with the same writes as the bulk bar); channels don't change by drag.
- **Order is saved on this device only** (`tasks.list.order.v1`, per workspace): Tower keeps no task order (tasks come
  newest-changed first). Tasks you haven't placed stay above, newest first. *For Pete: a shared manual order needs a
  task position on Tower.*
- Task rows' hover and selected fills run the full width, square, against the rules (as gr8r-studio), replacing the
  inset rounded fill of 5.4f.
- Drag and drop not exercised here (no mouse in the lab session); needs a hand check.

### 5.4i Flush fills, room for the handle (`style(tasks): edge-to-edge rules and a wider drag margin`)
- Task and group rules now run edge to edge, so the full-width hover and selected fills sit flush between them (they
  overhung rules that stopped short of both edges).
- The margin left of the tick boxes is 28pt (`Amb.ListLayout.dragMargin`, was 14), so the six-dot handle has room;
  the labels and group rows move with it.

### 5.4j Full task menu (`feat(tasks): a task's ••• and right-click menus offer everything it can do`)
- Both menus now list the same items: Open; Edit title and description…; Status, Assignee and Size (submenus, the
  current value ticked); Add subtask…; Select/Deselect; Archive…. That is what the task screen offers plus the bulk
  bar's actions, so nothing needs the selection or the task screen. Was: Start, Mark done, Move to.
- Edit and Add subtask open the task screen's own sheets (`TaskEditSheet`, `TaskCreateSheet` with the parent); Archive
  uses the bulk bar's confirmation, which now reads "Archive this task?" for one. Only Open shows for a task that can't
  change (locked, a parent of subtasks, or with a change still sending).
- Menus not opened here (no mouse in the lab session); needs a hand check.

### 5.5a Shared table pieces (`refactor(theme): the task table's pieces become the shared AmbTable`)
- New `AmbTable.swift` (Mac): `AmbTable` (gutter, title indent), `AmbTableRule`, `AmbTableCheckbox`,
  `AmbTableMenuItems`, `AmbTableGroupRow`, `AmbBulkBar` (+ menu and divider), `AmbTableSearchField`,
  `AmbTableToolbarMenu`. Moved out of `MacTaskList` so Docs uses the same table. No visible change.

### 5.5b Docs table (`style(docs): documents as a table, the same as Tasks`)
- New `MacDocList` (Mac) replaces the Docs list: toolbar (Search docs, Sort: Updated/Title, Group: None/Channel/
  Updated as Today, This week, Earlier; remembered) with a labelled New document button; labels row (Title and Updated
  sort); one-line documents with a tick box, icon, title and "Unsaved edits" pill, Channel (hidden inside a channel),
  Updated; full-width hover and rules; ••• and right-click: Open, Copy reference, Select, Archive….
- Ticked documents: bar with Archive (asks first; online and version guarded, as the document screen's archive;
  failures listed). Search moves out of the window's title bar (the `.searchable` field) into the toolbar.
- Tower's summary is the start of the body (Markdown, tables, ticked items), so it isn't shown. No drag (documents have
  no status or shared order). Export, Versioning and Move stay on the document screen, which has the document open.
- iPhone and iPad keep today's list; no iPad check needed.

### Phase 5 checks (Chat tab, Tasks, board, Docs; Deck on hold)
- Thread harness: only the known failure ("synced reply must render in actual thread"). `MacDeckComposerCheck` passes.
  `MacKanbanCheck` (run too, for the board and list changes) passes after one test change: it looked for the size in
  capitals ("ROCK"); cards now say "Rock" with a dot (5.4), so it accepts either (`test(mac)` commit). iOS builds.
- Sub-checks such as `MacDeckComposerCheck` only run with `-AmbulandoMacThreadRegression`; alone they wait silently.
- Rerun before merging into `lab` (after 5.6–5.6c): same results (thread harness at the known failure;
  `MacDeckComposerCheck` and `MacKanbanCheck` pass; iOS builds). Upstream unchanged since 548b4e8.
- Hand checks still wanted (no mouse in the lab session): dragging tasks, the task and document ••• menus, bulk
  actions, archiving documents.
- For Pete (in addition to Phase 4's): the Mac Deck's Inbox is under review (Phase 5 Deck, on hold); task and doc
  lists are tables after gr8r-studio; manual task order is per device.

### 5.6 Toolbar rows centred (`style(theme): list toolbars are one fixed height with centred content`)
- Every list's toolbar row is now 52pt high with its content centred (`Amb.ListLayout.toolbarHeight`): Tasks, Docs
  and Files (`ListHeaderBar`, Mac only) and Chat's filters (`ChannelConversationList`, `MacPlaceConversations`).
  Before, Tasks/Docs/Files had 6pt above and below (cramped against the column labels) and Chat 12pt above, 8pt below.
- No iPad check needed (`ListHeaderBar` keeps its padding on iPhone and iPad).

### 5.6b Chat rows flush (`style(chat): conversation rows hover flush between full-width rules`)
- Conversation rows (a channel's list and the Chat tab at Home or a scope) had a rounded hover wider than their rules,
  which stopped 20pt and 12pt short of the row. Rules now span the row and the hover is square, as in Tasks and Docs;
  text keeps its 20pt inner margin.

### 5.6c Reply count on the meta line (`style(chat): reply count beside who's taken part`)
- "3 replies" moves from under the time to the meta line, after the faces and before the latest reply ("3 replies ·
  Ana: …"), so it reads with who's in the conversation; the right keeps the time only. Accent and medium weight while
  the conversation is unread (Slack's reply line), grey otherwise; nothing without replies.
- The sample data marks no conversation unread, so the accent state is untested on screen. *For Pete: a count of
  unread replies per conversation would allow "2 new".*

### 5.7 Narrow windows (`fix(mac): sidebar gives way so content keeps its minimum` and `style(theme): tables and toolbars fit narrow windows`)
- Shell (fixes 4.7): the content pane has a 580pt minimum and the window a 900pt one, so a sidebar wider than 319pt
  pushed the layout past both window edges (content spilled over the sidebar, the toolbar's right end was cut). The
  sidebar now shows narrower in such a window (never under 200pt); its stored width is kept for wider windows.
- Tables (Tasks, Docs): columns give way as the pane narrows, keeping the title at least 200pt
  (`AmbTable.fitting`). Tasks drops, in order: Status when grouped by status (the group row says it), Updated,
  Channel, Assignee, then Size; otherwise Updated, Channel, Assignee, Status, Size. Docs drops Channel, then Updated.
- Toolbars: the search field shrinks to 100pt, Sort and Group fall back to their icons (full text as tooltip), and
  New task / New document to "+" (`AmbTablePrimaryButton`) when there isn't room.
- Checked at 900pt with sidebars of 248 and 380pt, and at 1440pt (all columns). Checks rerun: thread harness at the
  known failure; `MacDeckComposerCheck` and `MacKanbanCheck` pass; iOS builds. Earlier captures were all at 1440pt,
  which is how this was missed.

## Phase 6: Screens (`ux/screens`, off `lab` after Phase 5)

Proposal and mockups: https://claude.ai/artifact/CMRBzByqnjaX5ACzQLvLW1. Mac only unless noted.

**To do (Andy, 2026-11-21): redesign every modal and settings sheet.** They're still plain system forms. The list:
channel settings and its access pages (Grant/Change access), workspace management (members, groups, scopes, apps,
danger zone), scope setup and move-to-scope, New scope / New DM, agent setup, Settings, unlock, workspace selection
and connect, Upload, the task sheets (Edit, Add subtask), document versions/review/history, rename thread, Get it
done, notification detail, Search (iPhone). The round 6 composer (6.4) and Members popover (6.6) set the style.

### 6.0 Open a record for captures (`test(fixture): -UXOpen opens a task, document, file or composer at launch`)
- `-UXOpen "task:<title>"`, `doc:<title>` or `file:<name>` opens that record once its list loads; `task:new` and `doc:new`
  open New task / New document (`UXLabOpen.swift`, one call in each list). Sample app only. For captures of the
  detail screens without clicking.

### 6.0b Chat lists get the Tasks/Docs toolbar and search (`feat(chat): conversation lists share the table toolbar and search`)
- Asked first, before the round 6 screens. The Chat tab and a channel's conversation list share one toolbar
  (`ConversationListToolbar`): the same full-width bar as Tasks and Docs (`ListHeaderBar`, 16pt gutter), "Search
  chats", All / Unread / Mine as a quiet segmented switch (as Tasks' list/board), then New thread (keeps its pencil;
  icon only when narrow). The list itself keeps the chat column. A channel keeps its facepile by New thread.
- Search filters as you type: the title, the people and the place on each row, plus every stored message in the
  list's channels through the full-text index (`StoreReader.conversationMatches`, new). Conversations older than the
  list holds (40 per channel) are brought in (`channelConversations(…, only:)`, an optional filter). Each match quotes
  the matching message with the words in bold, unless the title already shows them; the reply preview isn't repeated.
  Local only: what this Mac has stored (Tower has no search).
- Lab flags (sample app only): `-UXSearch <text>` fills the search; `-UXOpen channel:<name>` opens a channel.
- Checked at 1440 and 900pt (sidebar 248 and 380), searching on the Chat tab and in #general. Thread regression: only
  the known failure. Mac only; no iPad check (the shared Core query adds an optional parameter, default unchanged).
- For Pete: `channelConversations` gains an optional `only:` set; `conversationMatches` is a new reader query.

### 6.0c The content is a rounded panel (`style(mac): content pane as a rounded panel on the window chrome`)
- Andy, after Ari: the working area should stand out as one panel, with the title bar and sidebar blending into a
  single frame around it. The content pane (place header, tabs, section) is now inset `Amb.contentInset` (8pt) from
  the sidebar and the window's right and bottom edges, rounded `Amb.radiusPanel` (10pt) on all four corners, with a
  hairline border, on the `Amb.sidebar` chrome. The sidebar's hairline edge is gone; the gap is the resize handle.
- `MacWorkspaceShell` only (plus one theme value). The sidebar's fitted width subtracts the two gaps so the content
  keeps its 580pt minimum.
- Checked dark and light, 1440 and 900pt (sidebar 248 and 380): Chat, Tasks list and board, Docs, a document.
  Thread regression: only the known failure. Mac only; no iPad check.
- Shown up by the frame (not changed here): the document screen's toolbar row is a chrome-coloured strip inside the
  panel. It goes with the document screen (round 6, 6.3/6.4).

### 6.0d Workspace at the top of the sidebar, you at the foot (`style(mac): workspace heads the sidebar, you end it`)
- Andy's ask: the workspace switcher moves to the top of the sidebar, the person to the bottom, and the rule above the
  sidebar's foot goes. `WorkspaceFooter(rule: false)` now heads `MacSidebarContent`; new `MacSidebarPerson` ends it: a
  sidebar row with your avatar and name that opens Settings (identifier `settings`, so the harness still finds it).
  The avatar leaves the end of the window toolbar on the Mac (`#if os(iOS)` around it in `WorkspaceShell`).
- Shared files: `WorkspaceFooter` gains `rule` (default true, unchanged elsewhere); the toolbar avatar is unchanged on
  iPhone and iPad. iOS build passes; no iPad check needed. Thread regression: only the known failure.
- Not changed: Home's icon is still the workspace's monogram, now just under the switcher with the same letters.

