# 07C4 — Unified Project People and Member Actions

Status: implemented; PR #124 targets `main`, remains draft and must not be merged.
This revised plan records the founder's
2026-10-02 decisions and supersedes the attached draft's immediate-grant,
Chat/Block grouping, and optional-pagination requirements.

## Integration gate

The original implementation started exactly at
`c4c3f1c4e585ca7587f7308865aae35554dd5d2a` on
`codex/07c4-unified-project-people`, stacked on the 05E2 branch.
The founder subsequently authorized integration on 2026-10-02: merge reviewed
#122, reconcile #124 onto the resulting `main`, and keep #124 draft and unmerged.
#122 was merged at `15d875fd77e9d6d6b652778c57540dc4c458207c`.

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
database types, inspect the diff, and retain the draft PR against `main`. Keep external
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
popularity/ranking are still unimplemented. The 05E2/#122 merge gate is satisfied;
later dependent work still requires the 07C4 review/integration gate. No unresolved
product decision blocks this implementation. Hosted Validation results are
reported in the PR/task handoff, distinguishing executed jobs from skipped jobs.
Neither merging #124 nor deployment is authorized by the current integration request.

## 2026-10-02 integration report

- Reviewed #122 head: `c4c3f1c4e585ca7587f7308865aae35554dd5d2a`.
  It contained only the reviewed 05E2 presentation, tests and documentation.
  GitHub reported CLEAN/MERGEABLE; classification and Mobile CI passed, with
  Web/Site/Database correctly path-skipped. #122 was explicitly marked ready and
  merged using a merge commit, preserving the dependency commit in `main`.
- #122 merge/new `main`: `15d875fd77e9d6d6b652778c57540dc4c458207c`.
- Previous #124 head: `2cc5356061fb2c26ea991eba7bdbda6647b5e113`.
- Reconciliation: merge the new `origin/main` into the existing #124 branch.
  There were no conflicts and no source-tree changes: #124 already contained
  the exact reviewed 05E2 commit. No side was chosen wholesale, no migration was
  duplicated, and no history was rewritten. Only this integration record and
  roadmap status required updates.
- PR #124 is retargeted to `main`, remains draft, and is not authorized to merge.
  The final commit ID, hosted Validation run/results and GitHub mergeability are
  recorded in the PR body after publication, avoiding a self-referential commit
  hash in this tracked report.
- Cumulative integration validation passed on the reconciled tree:
  - full `npm run check:db`: clean local reset/replay and deterministic seed,
    schema lint, security advisors, 106 pgTAP files / 3,313 assertions, every
    repository integration verifier and regenerated DB type drift check;
  - capacity, People consent/episode/issuer/step-down races, delegate,
    participation, blocking, notification/push, request-chat and group-chat
    verifiers all passed as part of that complete database chain;
  - `npm run check:mobile`: generated localization, 419 formatted files,
    clean static analysis and 1,139 tests;
  - `npm run check:web`: 24 tooling tests, 142 web tests, lint, typecheck and
    production build. The first concurrent run had a five-second admin-route
    import timeout followed by a mock assertion failure from that late test;
    the unchanged full rerun passed. No test or timeout was weakened;
  - `npm run check:site`: 34 site tests and 19 waitlist tests, lint, typecheck,
    production build and deploy dry run only; no external deployment;
  - English/Italian parity: 1,275 message keys each, all ICU argument sets match,
    including all 32 new 07C4 messages; their template placeholder metadata
    agrees with the translated arguments;
  - repository-wide `npm run format:check`, generated DB type drift and
    `git diff --check` passed.
- Final diff audit against the new `main`: all runtime code, tests, migrations,
  CI and generated types are byte-for-byte unchanged from the previous #124
  head. The public count helper/label, public cards/details and 05E2 regression
  tests match `main` exactly. The notification projector matches `main` except
  for the deliberate role-offer whitelist entry; older resolver behavior remains
  delegated unchanged. Only one new 07C4 migration exists, with no duplicates or
  rewrites of mainline migrations. No product/domain conflict was found.
- #122's clean managed checkout was archived recoverably and its merged local
  and remote branch removed. #124's checkout is retained for review/QA.
- Hosted Validation for the final published head and current GitHub mergeability
  are reported in PR #124's body after the run completes. Physical Android/iOS
  QA and deferred mute/popularity work remain outside this integration.
