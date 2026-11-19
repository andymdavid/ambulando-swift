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
