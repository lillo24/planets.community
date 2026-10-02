# 07C4 — Unified Project People and Member Actions

Status: implemented and locally validated; draft stacked PR for founder review.
This revised plan records the founder's
2026-10-02 decisions and supersedes the attached draft's immediate-grant,
Chat/Block grouping, and optional-pagination requirements.

## Integration gate

Start exactly at `c4c3f1c4e585ca7587f7308865aae35554dd5d2a`.
Use branch `codex/07c4-unified-project-people` and a draft stacked PR targeting
`codex/05e2-public-social-proof-threshold`. Merge neither this PR nor #122.

## Canonical boundaries

- One People screen reuses the existing participation route from Group info and
  Project management. Its current roster is the unique union of the immutable
  Creator, active delegates, and current participant memberships.
- Only current participants/managers see that roster. Historical chat entitlement
  alone is insufficient. Managers alone see requests (including resolved requests)
  and independent historical membership episodes.
- Joining deliberately authorizes display-name visibility to other current
  Project people, regardless of public/private name audience. The Creator and
  active delegates are also identified in this current-group context. This does
  not change public-profile, bio, skills, or photo access.
- Requests, current People, and historical memberships have independent bounded
  keyset reads. No hidden unbounded preload or per-row contribution/photo fan-out.
  Mutations reset affected cursors; refresh revalidates access and clears denied
  private state. Role/name ordering is not a cross-request snapshot.

## Targeted role offers, not assignments

- Creator/active Co-creator may offer a current participant Co-organizer or
  Co-creator authority. Offer creation does not activate authority or affect counts.
- Offer identity is fixed to the target profile and current membership episode.
  No bearer token is generated, stored, or returned for targeted offers.
- Reuse the invitation/provenance domain, with an explicit targeted offer mode.
  Recipient alone accepts/declines using expected-identity binding. The accepted
  invitation genuinely records offered-by X and accepted-by Y.
- Match existing invitation expiry (seven days); pending targeted offers may be
  withdrawn by structural actors and are invalidated when their issuer loses
  structural authority. Re-check lifecycle, issuer, membership episode, and absence
  of active authority at creation and acceptance.
- Surface received offers in-app with Accept/Decline and the Co-creator privilege
  warning. Keep the ordinary bearer invitation flow for non-participants.
- Serialize on the canonical Project lock. Leave/removal first means acceptance
  fails; acceptance first means a later leave ends membership only. Leaving and
  rejoining does not revive an offer tied to an earlier episode.
- Preserve existing block semantics: accepted membership/chat remains usable and
  new requests are checked against the updated manager set. Do not introduce a
  new authority-specific block prohibition or an incompatible pair/Project lock order.

## Member actions and self-service departure

- Compact rows expose the same bottom sheet via ellipsis and long press.
- Safety: existing account-wide Block/Unblock, explicitly not mute/message hiding.
- Event: lazily open existing commitments and one-time actual contribution flows;
  managers may remove other participants, structural actors may offer roles or
  change/revoke other delegates. Preserve existing generic self-mutation guards.
- An active Co-organizer/Co-creator has a separate, confirmed Step down action
  affecting their own authority only. Immutable Creator cannot step down.
- Revocation/step-down keeps membership, commitments, and history. Membership
  removal keeps authority. Reuse derived capacity/social counts, never mutable counters.
- Revocation/step-down may fail with PT409 when excluded organizers become ordinary
  participants and capacity would be exceeded. Explain that capacity must increase
  or participation must change; do not silently end membership or promise success.
- Preserve own contribution/history access, including manager+participant overlap.
  Keep Team for bearer invitations and independent authority management.

## Verification and handoff

Cover RPC authorization, identity binding, private-name current-group access,
deduplication, all role/membership combinations, offer expiry/withdrawal/decline,
recipient-only acceptance, stale issuer/episode, truthful audit/outbox provenance,
duplicate acceptance, leave/accept and capacity races, blocked existing members,
capacity-conflicted step-down/revocation, and bounded cursor reads.

Cover Flutter payload/controller/session invalidation and role/action matrices,
both menu triggers, own contribution overlap, and explicit errors. Run repository
database/mobile/web/format checks, relevant concurrency verifiers, regenerate
database types, inspect the diff, and open the draft stacked PR. Keep external
deployment, mute, DM, presence, ranking, templates, new contribution semantics,
Tavolo attendance, ownership transfer, and deletion out of scope.

## Implementation and verification report

The invitation table is extended with target profile, exact membership episode,
decline state, and mutually exclusive bearer/targeted delivery. New migration:
`20261002103310_unified_project_people_role_offers.sql`. No applied migration was
rewritten. Existing accepted-invitation authority provenance and derived capacity
guards remain canonical. The shared notification projector preserves its old
resolver, preferences, chronological batch limit, and idempotency receipts; only
eligible pending offers produce the new Participation alert.

The single legacy `participants` route now presents independently bounded
requests, targeted offers, current People, and historical episodes. Compact
current rows show all applicable role labels without duplicate identities.
Safety and Event menus use the same ellipsis/long-press entry point and clear on
identity change. Historical rows retain lazy contribution and account-wide Block
actions. Group info links all current-entitled users to People and retains own
contribution access for organizer/participant overlap. Structural actors may offer
either role; Co-organizers cannot offer roles. Existing non-self delegate role
changes remain separate. Self-service step-down removes only authority.

Local checks passed:

- complete `check:db` (all integration verifiers and generated types); final
  migration/test refinements additionally replayed, linted, security-advised and
  tested: 106 pgTAP files, 3,313 assertions;
- final consent/leave, duplicate acceptance, final-slot step-down and
  issuer-demotion concurrency verifier, plus existing delegate integration;
- `check:mobile`: localization, formatting, static analysis and 1,139 tests;
- `check:web`: tooling/web tests, lint, typecheck and production build;
- `check:site`: tests, lint, typecheck, production build and deployment dry run;
- repository-wide `format:check`, generated-type drift check and diff checks;
- isolated row preview rendered in-browser and hot-restarted. Physical Android/
  iOS QA remains in the consolidated native UX pass, not claimed here.

Existing demo bearer-invitation and derived-count assumptions are unchanged;
no demo role offers or new seed data are introduced. Per-person mute, DM and
popularity/ranking are still unimplemented. Later work must first satisfy the
05E2/#122 and 07C4 review/integration gates; no unresolved product decision blocks
this implementation. Hosted Validation results are reported in the PR/task
handoff, distinguishing executed jobs from skipped jobs. No merge or deployment
is authorized by this plan.
