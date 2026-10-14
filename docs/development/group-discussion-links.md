# C03 private room links

Each accepted discussion has a separately owned collection in
`private.group_discussion_links`; Project workspace storage and authorization are
unchanged. The Workspace entry opens the collection explicitly, including its
loading, failed and empty states. Reads return at most 25 items with an immutable
`(created_at, id)` cursor. Only an admitted current Group manager can add, edit or
remove. Archived rooms remain entitled read-only.

The provisional C00 since-admission contract applies to destinations as well as
messages. Creation increments the room's committed ordinal under the same Group
and room locks used by acceptance. A link is visible only when its ordinal exceeds
the current admission frontier. Message sequences may consequently have gaps;
message counts and signed read snapshots still count actual messages. Rejoining
never restores older destinations. A manager admitted later cannot edit an item
outside their own entitled history.

Names reuse WORKSPACE02's trimmed 1–120 character, no-control-character rule.
Destinations reuse its bounded HTTPS validation and local Material icon classifier.
These pure helpers convey no Project access. Provider access is independent; there
are no fetched previews, graphics, OAuth, uploads or provider metadata.

Add, edit and removal share C01's actor/action-key receipt namespace. A lost reply
reuses frozen intent and the same key. Two deliberate identical additions remain
distinct. Versions belong to individual items; conflicts require fresh review and
another deliberate Save. Removal is a tombstone, with no client resurrection or
new retention/erasure policy. Immutable provenance uses raw actor identifiers.

Mobile buffers and unresolved URLs stay in actor-scoped memory, with no preferences
or persistent cache. Account/readiness changes fence responses. Authoritative
denial clears the admission and private rows. Every external Open confirms the
hostname, rereads the exact item under the same actor and admission, and confirms
again if its destination changed. Route cancellation and account/episode changes
cancel the pending launch. Canonical denial or removal cannot open a cached URL.

Link names and URLs are absent from public Group/Project projections, templates,
analytics and notification/outbox payloads. The existing private account hint
contains only its profile identifier. C04 does not automatically transfer links.

Reproduce on a disposable loopback backend with `npm run db:test`,
`npm run group:discussion-links:verify:local`, the existing discussion verifier and
WORKSPACE02 verifier. The new Auth verifier accepts the standard local status and
`MAILPIT_URL` configuration and never resets the selected stack. CI runs it once
in the existing change-scoped database job. Native tests live with the discussion
feature and reuse no public or Project authorization fixture.

Executed desktop checks: clean replay and 5,373 pgTAP assertions in 142 files;
131 genuine link Auth assertions, including same-version races and observed
queued writes after archive/source loss; 121 existing discussion Auth assertions;
repository-scoped SQL lint and security advisors; 267 scoped mobile regressions
including WORKSPACE02, followed by 10 current link tests; current scoped Flutter
analysis and Web typecheck; owned Android build and successful MCP hot reload.
All 98 tooling tests and the original real Auth Project/Tavolo workspace verifier
also passed, including legacy signatures, independent roles and public privacy.
The pure preview is defined, with the C02 SDK previewer registration limitation
still applicable. The native probe now includes the entitled empty collection
and a real subsequently added link; cumulative native execution belongs to the
final integration gate. C00 remains provisional. No hosted or physical-device
operation occurred.
