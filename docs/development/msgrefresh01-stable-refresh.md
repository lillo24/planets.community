# Stable protected-list refresh

Messages Private/Groups, Requests and Notifications formerly retained rows while
fetching, then replaced all continuation pages with the newest 20 rows. Reopens,
resume and unread hints could overlap these replacements. Stopping chat signals
also invalidated an unrelated pending list read. Notifications read mutations
invalidated inbox loads, but not older unread-count responses.

## Invariants

- A cold process has no retained private rows. First loading is neutral; no disk
  cache, preferences persistence, new subscription or push service is introduced.
- Same-account refresh uses a separate refreshing phase, retains rows throughout
  fetching, and coalesces simultaneous opens. Pagination and refresh serialize.
  A hint arriving during work queues one debounced revalidation afterward.
- Revalidation starts at the canonical head with fresh keyset cursors and reads
  through the previously loaded oldest key, in 20-row pages. It publishes the
  entire authorized range atomically. This removes revoked/deleted older rows;
  merely appending an old tail to a new head would conceal those removals.
- Inserts may require one additional page. A deleted old boundary is crossed by
  timestamp/kind/UUID ordering; the old cursor need not still exist. A repeated
  or empty advancing page fails explicitly. A later page failure retains the
  confirmed snapshot and existing inline retry presentation.
- DTO value records compare all projected fields. Identical values reuse row
  instances and the list; keyed lazy rendering reuses unchanged widgets and
  restores a surviving visible row's position after inserts/removals. At the
  top, new rows appear normally. Active user scrolling takes precedence.
- Requests and Chats keep their mounted tab state. Private/Groups have separate
  account/scope PageStorage positions. AUTO02 still requires genuine user scroll
  and uses the final canonical row as the continuation cursor.
- Sign-out, A → B → A and loss of readiness invalidate protected snapshots and
  in-flight revisions. Canonical permission-denied list reads clear rows; normal
  network failure retains same-account content. Photo metadata revalidation
  retains existing authorized bytes when the canonical version is unchanged.
- Notification reads invalidate older inbox/count responses. Refresh does not
  race pending read writes or Mark all. A failed individual read restores only
  its own row, preserving other successful reads. Count failures retain the last
  confirmed count with an explicit failed state.

## Bounded audit

| Surface | Disposition | Evidence / limits |
| --- | --- | --- |
| Messages Private/Groups and Requests | Fixed | Controller loaded-window, coalescing and paging tests; existing lifecycle, unread, identity and offline widget tests |
| Notifications | Fixed | Loaded-window controller tests and existing read/Mark all/identity/offline widget tests; no background Realtime added |
| Profile | Already correct for warm rows | `ProfileController.load` retains same-owner data; Profile presentation uses `classifyAsyncDataPresentation`; owner photo load retains bytes |
| Public Projects | Already correct on warm mount | Screen loads only in idle phase; filter/query reset deliberately replaces pages |
| Public Tavoli | Already correct on warm mount | Idle-only initial load; reference-time/filter resets deliberately replace pages |
| Scambio/Dona | Already correct on warm mount | Idle-only initial load; mode/query reset deliberately replaces pages |
| Drafts | Already correct for retained rows | Complete owner collections, no continuation pages; actor-bound adapter retains rows while source loading is shown inline |
| Project chat | Fixed warm mount | Screen now calls existing same-target `refresh`, whose canonical history reconciliation retains older pages; cold refresh delegates to load. Composer text is untouched by refresh; `ConversationHistoryList` retains its center anchor |
| Home | Already correct for this issue | Static navigation cards and separately scoped status summaries; no paginated content reload on mount |

Public discovery's explicit pull/filter resets use variable page sizes and
Tavoli's reference-time snapshot. Changing that reset policy requires a separate
plan; it is not folded into protected-list caching. Chat history reconciliation
and authorization remain owned by each canonical chat controller. Physical
device, real two-account and live network/provider testing are separate evidence.
