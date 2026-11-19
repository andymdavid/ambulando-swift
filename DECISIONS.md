# UX Lab decisions

Why the lab looks the way it does. One entry per decision: what, why, status. Detail of each change is in
`LAB-CHANGELOG.md`; the original review is https://claude.ai/artifact/S4HCkDSDtn2gJtky9eWTNH.
Goal: Linear-level polish for the Mac app without changing what the product does.

## Working rules

- **Fork, not a branch on upstream.** `andymdavid/ambulando-swift`; upstream is fetch-only. Experiments stay
  separate; anything offered back goes on a clean `upstream/<topic>` branch cut from `main`.
- **Theme first, add don't rewrite, small commits.** Upstream moves daily; shared theme files and new files merge
  easily, edits to big view files don't.
- **Test app for all UX work.** Sample data, own bundle ID, no keychain; the real app is never touched.

## Build

- **Xcode 27 fix** (`d9d9745`). Swift 6.4 rejects one provider hand-off in `ComposerUploads`; one-line
  `nonisolated(unsafe)`. No behaviour change. *Candidate to offer upstream.*

## Colour

- **Neutral greys, one accent.** Blue-tinted greys and six competing accents read as busy. Accent (violet
  `#6E56CF` / `#7C6AE6`) is for interaction, selection, mentions and unread only.
- **Headings are ink, not accent.** The old deep purple did three jobs (ink, action, identity), so it never read as
  a colour.
- **No colour-coding by record type.** Inbox reused status colours (task = warning amber, doc = success green). Type
  is shown by icon; colour is kept for meaning (status, urgency).
- **One unread signal.** Accent dot everywhere (was orange in some places, purple in others). Orange = urgent only.
- **Neutral title bar.** It was tinted with the workspace colour; the only coloured chrome. Workspace colour may
  return as a small mark later.
- **Dark mode = Linear's dark theme.** Tried Ari and Halaska values first; Linear's read best. Chrome darkest,
  content a step lighter. Light theme unchanged from the first pass.
- **Hover is a translucent overlay** (black 4% / white 5%), as in Linear. A solid grey read too dark and stacked
  unevenly.

## Type

- **Geist + Geist Mono, bundled.** One sans with weight for emphasis; mono only for technical strings (IDs, keys,
  code). Replaces SF + serif titles + scattered mono. OFL licence; no project-file edits.
- **Mac type scale 11/12/13/14/16/18/22/28.** Measured: most Mac labels were 10–11pt (small, not large). Now closer
  to Linear. Text Size menu still works. iPhone/iPad keep Dynamic Type.
- **Tabular figures everywhere.** Times and counts line up.
- **Four text levels** (content / supporting / metadata / hints). Two levels made everything that wasn't primary
  look equally dim.

## Interaction and controls

- **Hover on rows, tabs and icon buttons; row actions (•••) appear on hover** (Mac only). Mac had no hover at all.
- **Four buttons: primary (filled violet), secondary, ghost, icon.** Replaced system bordered buttons, tinted chips
  and four kinds of add button. Filled violet chosen over Halaska-style inverted buttons to keep the brand visible.
- **Tooltips for unexplained terms and icon-only buttons only**; never on buttons with a text label. Helpful
  without being noisy.
- **Spacing scale 4/8/12/16/24/32.** Used as screens are reworked, not converted all at once.

## Copy

- **Remove developer language** (FIPS, NIP-98, "authority-barrier", "cursor reset", "fdCalloutWidget"). Say what
  the person sees and can do.
- **Keep and own "Tower".** It's the product's name for the server and we'll explain it, so it stays wherever it
  means the server. Removed only sentences about Tower's internal checks (developer language).
- **"App" instead of napplet / WApp.**
- **"Your identity" instead of Nostr key / npub**; keys shown only as details.
- **Agent activation consent text left as is.** It's a security disclosure (what is signed, for which host); reword
  only with Pete.
- **Deck greeting by time of day** ("Good evening, Maya"), as in the reference app, instead of "Welcome …, where
  will we focus today?".
- **Rock / Pebble / Sand: open.** Gives the app character but may read as jargon next to a plain priority.
  Leaning: keep the words, make them self-explanatory. Tooltips added ("big rocks first": rock = most important,
  pebble = after the rocks, sand = small tasks); size glyph and order to follow. Wording to confirm with Pete.
- **Kept for now: Autopilot, scopes, Deck/Canvas/Toolbox.** These are product vocabulary;
  they belong to the "who is this for / domains" conversation, not a polish pass.

## Deferred

- **Sidebar rebuild (Phase 4).** Scope and channel rows differ in height, type, radius and hover/selection width.
  Fix with one row component rather than patches.
- **Flatten the Deck (Phase 5).** Four stacked layers (page, section panel, row card, tiles). Two is enough.
- **Product direction.** Agents-first onboarding and scopes as business domains (Finance, Sales, Clients…). A
  conversation with Pete, not a lab change.
