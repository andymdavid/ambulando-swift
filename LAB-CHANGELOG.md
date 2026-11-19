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
