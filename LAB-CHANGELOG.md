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
