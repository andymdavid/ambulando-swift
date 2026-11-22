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
- **Our own tooltip, not the system one.** The macOS tooltip can't be styled and looked cheap; ours uses the theme
  (raised surface, soft border and shadow, Geist) and the same pause.
- **Spacing scale 4/8/12/16/24/32.** Used as screens are reworked, not converted all at once.

## Chat

- **A channel is a list of conversations; a thread is chat.** Each channel post starts a conversation (a thread
  root, often titled, often a long brief). Replies inside a thread read as chat: flat, same-sender runs grouped
  (5 min). (The first block layout of the list is superseded by the conversation list below.)
- **"Read more" opens the conversation** rather than expanding inline: the channel previews, the thread shows it
  all, and the whole block is already the way in.
- **Reactions only when they exist.** The always-on 👍 and + under every message moved into a small hover toolbar
  with the ••• menu. Pills have no outline; yours use the soft accent.
- **Chat sits in a centred column (Mac)** with real side margins, as in Buzz; full-width rows read as a log.
- **No bubbles.** Tried for everything, then for your own messages: they suit quick back-and-forth between people,
  not briefs and long agent replies (lists, tables). Messages are flat rows.
- **In a thread your own messages sit on the right** (flat, mirrored), with more space between senders.
- **A message's hover highlight hugs the message** with even padding (more at the sides, which carry no line
  spacing); the gap between senders sits outside it. A full-row highlight made every message look as wide as the page.
- **A channel reopens the thread you left open there**; closing it yourself forgets it. **Switching section closes
  the quick-view**, which belongs to the screen it was opened from.
- **Agents have rounded-square avatars**, people circles, so the two read apart at a glance.
- **Relative times** ("12m ago") for today; older messages show the clock time under a day label.
- **A channel is a list of conversations, newest activity first** (direction A of the mockups): title, brief, who's
  involved, latest reply or which agent is working, unread. Keeps the live app's Threads-view ordering, which upstream
  dropped; deliberately not chat, so "New thread" is a button, not a composer under the list. It opens in place like
  a thread, not as a modal: a new conversation is a destination, the same as an existing one.
- **Participants sit on the thread's header row** (facepile, Buzz-style); the row above names the place, this one
  the conversation.
- **A thread opens in place of its channel's list** (Mac, Chat section), like opening an email: one composer at a
  time, ← back (or Esc) to the list. The channel's composer starts new threads ("Start a thread in #…"). A side
  panel was tried and dropped: two chats side by side, and it floated over other sections.
- **From anywhere else, a quick-view modal** with Reply, Full screen and "Open in #channel". Threads belong to their
  channel: leaving Chat closes an inline thread instead of carrying it over Tasks or Docs.
- **Structure ahead (Phase 4): Solo, scopes, channels.** A "Solo" space for your private conversations with agents
  (each conversation its own sidebar item, opening full width), then scopes as groups of team channels, then DMs.
  Modelled on Buzz's solo vs team channels; "Solo" because it says single player plainly.
- **One composer box.** Text on top, tools along the bottom edge inside it, send at the bottom right (Mac). The old
  layout had tools outside the box and a tall grey field. iPhone keeps its keyboard-aware layout.
- **No Messages / Threads switch.** Upstream already dropped it; almost every post starts a thread. A light header
  filter (has replies, unread, mine) can come back if the full layout shows a need.
- **Status dot only when something's wrong** (waiting or refused); "synced" is the normal state.
- **Hover-revealed controls stay visible for VoiceOver and Full Keyboard Access** (and the app's Mac checks).
  Hidden controls would otherwise be unreachable.

## Copy

- **Remove developer language** (FIPS, NIP-98, "authority-barrier", "cursor reset", "fdCalloutWidget"). Say what
  the person sees and can do.
- **Keep and own "Tower".** It's the product's name for the server and we'll explain it, so it stays wherever it
  means the server. Removed only sentences about Tower's internal checks (developer language).
- **"App" instead of napplet / WApp.**
- **"Your identity" instead of Nostr key / npub**; keys shown only as details.
- **Agent activation consent text left as is.** It's a security disclosure (what is signed, for which host), so
  its precision matters more than its tone.
- **Deck greeting by time of day** ("Good evening, Maya"), as in the reference app, instead of "Welcome …, where
  will we focus today?".
- **Keep Rock / Pebble / Sand, explain them.** The words give the app character; a tooltip makes them clear
  ("big rocks first": rock = most important, pebble = after the rocks, sand = small tasks). Size glyph and
  consistent order to follow in the task redesign.
- **Kept for now: Autopilot, scopes, Deck/Canvas/Toolbox.** These are product vocabulary;
  they belong to the "who is this for / domains" conversation, not a polish pass.

## Sidebar (Phase 4, Mac)

- **One row for everything in the sidebar.** Home, scopes, channels, conversations and the workspace switcher share
  height, type, radius and full-width hover/selection; indent and the hover action (•••, +) sit inside the row. The
  four row types before differed in all of these (Buzz and Linear use one).
- **Order: Home, Solo, Scopes, Direct messages.** Your own agent work first, team spaces next, people last.
- **Solo = DMs where everyone else is an agent, plus Note to self.** Works on today's data and upstream's DM flow; no
  server change. Buzz labels a private channel instead; Ambulando's threads already give one conversation per item.
- **Solo works like a scope: one row per agent DM** (and Note to self), each a place with all its tabs, as DMs are in
  the live app. Its Chat tab lists every conversation with that agent, so any number of chats has a home. (First
  built as one row per conversation, opening full width; dropped: no list of all chats, and DMs lost their tabs.)
- **Every DM is a place with tabs**, Solo or with people, like a channel.
- **No separate "your space" zone.** Order (Home, Solo, then Scopes and Direct messages) is enough; a dividing rule
  or panel was mocked and not wanted.
- **Collapsing hides the sidebar, as now.** An icon rail was considered: agents and people read as avatars, but
  scopes have no icon or colour, so they'd be identical marks. Revisit if scopes get one.
- **Sidebar opens at 248pt**, resizable 200–380 and remembered (it opened at its widest).
- **No "Unread & Active" on the Mac.** It repeated channels that already show unread in place and pushed Solo down.
- **Scopes are rows, not headings** (Linear's team rows): the row opens the scope, the chevron folds its channels.
- **The sidebar says where, the tabs say what.** Section tabs move into the content header beside the place's name;
  changing place keeps your tab. Replaces the web's rule that a sidebar choice opens Deck (and the lock to stay),
  which surprised anyone clicking a channel. Toolbox, which ignores the place, becomes a sidebar row.

## Content screens (Phase 5, Mac)

- **Lists share one pattern** (`Amb.ListLayout`, `AmbContentList.swift`): filters left and the main action right; section
  labels separated by space, never a rule; a hairline between rows; unread as a dot in the margin. Round 1 mixed rules
  and boxes per screen.
- **The task list is a table, laid out like gr8r-studio's** in Ambulando's look: search, sort and group in a toolbar;
  labelled columns (Status, Assignee, Size, Channel, Updated); a group row per status with fold and +; hairlines
  between rows; ••• on hover; a tick box per task with a floating bar for bulk status, assignee, size and archive;
  drag by a handle to reorder or move between groups. A task's ••• and right-click menus offer everything you can do to
  it (the task screen's edits plus the bulk bar's actions). Row fills are full width and square, as in gr8r. Moving a task
  into another group changes it on Tower; reordering within a group is a personal arrangement, kept on the device. A Linear-style list (bands, icons before the title, a Display menu) was mocked twice and
  read as less organised; one-line rows without labels (round 1) left a wide window feeling empty. Size is a dot scaled
  to Rock/Pebble/Sand plus the word (Rock orange).
- **Board moves animate:** a card slides to its new lane rather than vanishing and reappearing.
- **Board: each status is a lane** (recessed, hairline edge, as gr8r-studio), with bordered cards and the list's ring
  heading. Open columns on the page were tried first; lanes read better as separate statuses.
- **Docs use the same table as Tasks**: toolbar, labels, optional groups (channel or when changed), tick boxes, a bar
  to archive several, and a ••• menu. Tower's summary is raw body text, so rows show the title only.
- **Narrow windows: columns give way, the title never does.** Lower-priority table columns hide as the pane narrows
  (the task's status first when grouped by it); toolbars shorten to icons; the sidebar narrows before the content
  drops under its minimum.
- **The Chat tab at Home or a scope lists the place's conversations, newest first** (one list across its channels and
  DMs, each row tagged with where it lives), not its channels again. The sidebar already lists channels by type, so
  filters are about state (All, Unread, Mine), not type. A DM shows its face once. A refined channel overview (C1) was
  mocked and not chosen.
- **The Mac content is a rounded panel on the window chrome** (8pt gap, 10pt corners, hairline), so the title bar and
  sidebar read as one frame and the working area stands out, as in Ari. The gap replaces the sidebar's hairline.
- **Mac sidebar: the workspace heads it, you end it** (avatar and name, opens Settings), no rules. Where you are
  reads top-down (workspace, then places); the toolbar keeps only Search, Notifications and Browser.
- **Toolbox is "Apps" on the Mac**: the page lists only apps, and "Toolbox" makes you guess. Mac only for now; the web
  and iOS still say Toolbox, so the products differ until Pete decides whether to follow.
- **Chat lists share the table toolbar and are searchable.** The Chat tab and a channel get Tasks' and Docs' bar
  (search, filters, main action); All / Unread / Mine stay one click (segmented, not a menu). Search reaches every
  stored message, not only the loaded list, and quotes the match so you see why a row is there.
- **"New task" and "New document" are labelled primary buttons**, like "New thread" in a channel. What they open is
  still being designed (a compact composer is proposed).

- **Search is a command menu on the Mac** (⌘K or ⌘F, or the title-bar field), as Ari: one field over the window that
  lists where to go and what to do, then narrows to places and stored tasks, docs, files and messages as you type.
  Faster than a sheet, and one place for jumping as well as finding. iPhone and iPad keep the Search sheet.

- **Files is a table like Tasks and Docs** (Mac): Name, Kind, Size, Channel, Updated; folders open in place; no tick
  boxes, since Tower has no bulk file actions yet.

- **Task screen reads top to bottom** (Mac): title, description, subtasks, activity; properties in a rail (a grid when
  narrow). Title and description edit in place, replacing the Edit sheet. Same writes as before.
- **New task is a compact composer** (Mac): title first, every other field a chip with a sensible default; Create more
  for batches. Same write as the old form.

- **A channel shows who has access** (Mac): the faces by New thread are members, not recent posters, and open a
  Members popover to add, change or remove access. Same Tower calls as channel access settings.

## Deferred

- **Flatten the Deck (Phase 5).** Four stacked layers (page, section panel, row card, tiles). Two is enough.
- **Product direction.** Agents-first onboarding and scopes as business domains (Finance, Sales, Clients…). Out of
  scope for a polish pass.
