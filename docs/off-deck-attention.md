# Off-deck attention

Archived conversations/documents and archived or cancelled tasks do not contribute
unread channel badges or Deck attention. Unknown parent records retain their real
unread state: paging, filtering and an unloaded card are not lifecycle evidence.
Completed tasks keep the existing unread exception.

The shared SQLite read projection checks only stored lifecycle state. It retains
activity and read versions, emits no automatic read receipt and works offline after
reopening the cache. Sidebar observers include parent lifecycle changes on iPhone
and Mac. Restoring an item restores retained unread attention unless explicitly
acknowledged in the meantime.

The iPhone and Mac Settings “Unread and Mentions” section shares the private
`ambulando.attention-types` preference with other clients through WorkspaceSync.
Its cache is scoped to the exact Tower, signed actor, application and workspace.
Missing, malformed or future values show all types; unsupported schemas are not
overwritten. Version 1 toggles preserve unknown object fields and disabled names.

Unread/Mentions notifications, notification badges, sidebar attention and unread
Deck rows use the same projection. Read Deck activity and explicit section
navigation remain available. Filtering never advances a read position or dismisses
a notification. Deck mark-all is now limited to the displayed cards after type,
search and paging filters; notification mark-all sends individual changes for the
displayed rows and their observed versions.

The last confirmed preference persists offline. A pending CAS mutation keeps its
original value, base version and mutation ID across retries and relaunch. Swift
serializes switch edits until confirmation: during an uncertain save all switches
are disabled and Settings offers Retry. Conflicts show the latest server choice
and require an explicit new choice. An authoritative null clears a stale cache.
Private-preference SSE hints, workspace catch-up, foreground/reconnect and Settings
refresh all reuse the keyed sync job; no second polling owner is introduced.

`UnreadAttentionTests` covers hidden-only and mixed channel attention, missing
parents, stale view-state sync, reopen and restoration. `DeckActivityTests` covers
the completed-task exception and context selection. `AttentionTypesTests` covers
all switch combinations, schema preservation, cache isolation, notification and
Deck projections, visible bulk reads, uncertain retry, conflict and server reset. Physical installation and
real-account multi-device verification remain separate from source/build checks.
