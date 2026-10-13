# Registered groups

GRP03C's public Project/Tavolo feed and contextual creation belong to
[`../group_projects/`](../group_projects/README.md). Group participation and
authority remain independent of each associated Project's own access rules.

Personal Auth remains the actor. Group pages and Project chats are distinct.

- `domain/group_models.dart` owns strict public/owner projections, paired immutable
  cursors, exact enums, Unicode scalar bounds and canonical whitespace normalization.
- `data/group_gateway.dart` is the only group backend boundary: named RPCs,
  explicit parameters, strict scalar/row parsing. No direct group-table access.
- `application/group_controllers.dart` owns paging epochs and frozen actor-bound
  commands. Public and owner data are never substituted for each other.
- `presentation/group_directory_screen.dart` owns public filters/retained scroll.
  Deliberate-scroll pagination has an explicit
  Load more/Retry fallback; layout never requests another page.
- `presentation/group_detail_screen.dart` owns public detail, the separate exact-self
  participation feature, and the genuine contextual report route.
- `presentation/group_editor_screen.dart` owns full content editing, separate
  Save/Publish/lifecycle actions, policy action boundaries, and registration with
  the shared departure coordinator. `group_widgets.dart` owns shared presentation.

Routes: public `/groups`, `/groups/:groupId`; completed personal accounts:
`/groups/mine`, `/groups/create`, `/groups/:groupId/edit`,
`/groups/:groupId/report`. Public browse/detail bypass Auth and policy. Report
routes preserve their UUID through email OTP/profile completion and never send
automatically. Auth/setup cancellation returns a public directory/detail.

Management reads bypass policy. Each mutation checks the current account and
policy bundle, including exact retries. Policy review can be pushed while keeping
the editor underneath; no automatic mutation occurs on return. Close, Back and
route changes share Save/Discard/Stay. A failed save blocks departure. Pending
ambiguous commands must be resolved before departure; no saved message is shown
without a receipt and successful current owner reload.

Commands keep one UUID, actor, target, expected version and normalized intent in
editor memory. Recovery precedes exact delivery and reloads the current protected
projection; receipts can be older than the latest group version. Inputs cannot
retarget an unresolved command. PT409 preserves input and requires explicit
reload/reconciliation. No automatic version adoption or overwrite. Closing the
app discards in-memory recovery state; My groups is the authoritative way to find
previously accepted drafts after restart. No durable token/receipt store is added.
Identity/readiness changes dispose private forms and discard late results.

Published saves change the live page immediately. Archive is reversible through
Restore to draft. Staff suppression is independent and cannot be cleared by
managers. This original content feature adds no personal photo requirement, logos,
exact locations, external contacts, verification, group-owned Projects or chat.

Tests are in `test/features/groups/`; real local fixtures and native journey are
in `integration_test/prepare_groups_smoke.mjs` and `groups_smoke_test.dart`.

GRP03B participation/Team/My groups section ownership is mapped in
[`../group_membership/README.md`](../group_membership/README.md). The existing
editor now has an explicit structural mode using managed RPCs for Co-creators;
Restore-to-draft confirms and exits without reading the Creator draft. Creator
draft/edit/recovery interfaces remain unchanged.
