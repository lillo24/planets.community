# PI01 — Sharing and direct participant invitation domain

Implementation base: `92d93ca5a455ab853df8bc34b66fd8d69f4fb341` (merged #124).
This plan owns the backend contract and compatibility adapters. Mobile sharing,
browser onboarding, native associations/routing and broader demo work remain
PI02–PI05. No deployment or shared-database migration is performed here.

## Product boundary

Ordinary public sharing keeps the existing public activity URL and
organizer-approved request flow, including its photo and contribution rules.
The browser's future ordinary-share action leads to opening/downloading PLANETS;
it does not force login or create a browser request.

A special participant link is a separate reusable bearer capability. Its holder
can explicitly join after authentication and the existing non-photo profile
requirements. Forwarding gives the recipient the same admission/photo exception;
it proves no personal acquaintance. Neither preview, signup, installation nor
profile completion joins anyone. It grants participation, never authority.
`/join/project/<token>` is the proposed future route; PI01 installs no route.
Existing `/invite/project/<token>` authority invitations remain separate.

## Manager API

All management RPCs bind `p_expected_profile_id` to the verified account and
require the current Creator, Co-creator or Co-organizer. Ordinary participants
and former managers cannot create, retrieve, revoke, rotate or read history.

| RPC                                           | Arguments after expected account                                                       | Result/behavior                                                                                                                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `create_project_participant_invitation`       | `p_project_id`                                                                         | Get-or-create one current generation. Returns `invitation_id`, `invite_token`, `created_at`. Repeated sharing never rotates. First creation requires current joinability. |
| `get_current_project_participant_invitation`  | `p_project_id`                                                                         | Same secret result, or zero rows when there is no current link. Works during pause/after closure so managers can manage existing links.                                   |
| `regenerate_project_participant_invitation`   | `p_project_id`                                                                         | Atomically revokes the prior generation, deletes its secret and creates/returns a new one. Requires current joinability.                                                  |
| `revoke_project_participant_invitation`       | `p_project_id`, `p_invitation_id`                                                      | Returns the revoked ID. A stale generation fails with `PT409`; it cannot revoke a newer link.                                                                             |
| `list_project_participant_invitation_history` | `p_project_id`, optional `p_limit=20`, `p_before_created_at`, `p_before_invitation_id` | Metadata only: generation/issuer/creation/revocation/revoker/reason. Descending `(created_at,id)` cursor, complete cursor pair, limit 1–50. No tokens/digests.            |

There is no fixed expiry, capacity reservation, per-account redemption limit or
issuer-role-loss rotation. Published Proposals admit before their **current** end;
published Tavoli admit while active. A paused Tavolo's unrevoked link becomes
usable on resume. Current manager/blocking/account rules are rechecked at admission.
Issuer identity is attribution; authorization belongs to the Project. Managers
may explicitly revoke/regenerate after a personnel change.

Generations/digests and one-shot revocation history live in
`private.project_participant_invitations`. Verification uses SHA-256 digests of
256-bit random, 43-character URL-safe tokens. The current raw sharing secret
lives only in `private.project_participant_invitation_secrets`, with no direct
client/service-role grant, and is deleted on rotation/revoke. This private
database storage is intentionally portable and requires no new credential or
external encryption service. Ordinary lists, histories, events and errors never
contain secrets. Creation/current-share responses are intentional manager-only
disclosure; future clients must keep them out of logging/analytics.

## Preview and explicit admission

`get_project_participant_invitation_preview(p_token)` is callable by `anon` and
`authenticated` and returns exactly one row:
`available`, nullable `project_id`, `project_kind`, `project_title`. It exposes
only already-public activity identity/title. Invalid, malformed, revoked,
replaced and non-joinable links all return `false` plus null fields. It grants
no roster/chat/meeting/profile/photo access and performs no writes.

`accept_project_participant_invitation(p_expected_profile_id, p_token,
p_client_action_id)` is the single authenticated admission RPC for future
mobile and browser clients. It returns exactly one row:

| Field               | Meaning                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `project_id`        | The admitted/recovered Project.                                                                |
| `membership_id`     | Original membership episode; null only for the immutable Creator outcome.                      |
| `outcome`           | Original `joined`, `already_joined`, or `creator` outcome.                                     |
| `membership_status` | Current state of that **original episode**: `current`, `left`, `removed`, or null for Creator. |
| `replayed`          | Whether a committed account/action receipt was recovered.                                      |

Fresh admission verifies the complete non-photo profile, current token generation,
canonical joinability, all current-manager blocking barriers, and participant-aware
capacity. The existing shared identity/profile helpers are used; unmerged
moderation consequence/suspension PRs #123/#125 are not assumed implemented.
Future suspension integration must retain these operation/recovery boundaries.
No public skip-photo flag or account-wide exemption exists. Ordinary requests,
publication and other trust-sensitive operations still enforce their photo gates.

The Creator returns `creator` without inventing participant membership. Active
delegates may acquire an independent membership; canonical capacity avoids
counting them twice in either organizer-counting mode. A current participant
returns `already_joined` without a new episode, commitment, join event or slot.
Unavailable links/interaction races return `PT409`; capacity retains its canonical
full message. Stale identity/manager authorization uses `42501`, incomplete
profile uses `55000`, malformed action/cursor input uses `22023`. There is no
success-shaped fallback after failed admission.

## Retry and re-entry protocol for PI02/PI03

Generate a UUID **when the user explicitly presses Join**. Keep that action UUID,
exact token and expected account through double-click suppression, connectivity
loss, ambiguous response and automatic/manual retries of that same action.
Do not automatically submit on route opening, auth restoration or profile return.
After account changes discard pending work; never submit it under another identity.

`private.project_participant_admissions` durably binds account + action UUID to
the exact generation/Project and original outcome/episode. An exact retry recovers
that result even after rotation/revocation/closure or departure. Changing the
token/generation for a used action fails with `PT409`. Recovery never creates
membership, emits events or restores an ended episode. Clients must inspect
`membership_status`: `outcome=joined` with `status=left/removed` describes a past
join, not present membership. They must not show a successful current join for it.

A later deliberate Join uses a **new UUID**, and may create a fresh episode
through the same currently valid link after voluntary leave **or removal**.
Removal is not a permanent Project ban; blocks/current eligibility still apply.
Old episodes retain their terminal fields and chat intervals. Concurrent distinct
UUIDs for one current account produce one `joined` episode and `already_joined`
receipts for the others. Receipts are append-only; there is no lifetime single-use
limit for accounts or links.

The admission action advisory lock precedes the established deterministic
interaction pairs → concrete activity → shared Project → generation/membership/
request lock hierarchy. Manager operations use concrete → shared Project →
generation. No Project-held path acquires interaction pair locks. Revoke/rotation,
ordinary approval, capacity/lifecycle and manager changes serialize at the same
domain rows; manager-set changes across a wait fail for a fresh retry.

## Provenance and existing consumers

Membership has exactly one origin: nullable `originating_request_id` for ordinary
approval, or `originating_participant_invitation_id` for direct admission.
Composite FKs retain Project/account binding. Existing request-origin uniqueness
and one-current-member uniqueness remain. Origins cannot be rewritten.
Existing rows need no backfill or fabricated requests.

A pending request is atomically withdrawn by its requester with
`resolution_reason=direct_participant_invitation` and
`superseded_by_membership_id`. Its message, selections, chat and resolution history
remain; no organizer acceptance/triage is invented. The existing withdrawal
event includes the reason and membership ID, retaining notification/push/Message
projection. `get_project_join_request_resolution_context(expected,id)` returns
the reason and superseding episode to the requester/current managers only;
outsiders receive zero rows.

Null request origins naturally give the existing contribution-seeding/coverage
triggers no offers or acceptance decisions to inherit. Explicit post-admission
commitment coordination remains available. Existing chat activation/entitlement,
People/history, capacity, participation projections, meeting access and statistics
consume the same membership rows. The moderation corroboration cohort now includes
direct members as well as genuine accepted-request members. Flutter's existing
membership models/parser accept null request origins, preserving historical reads.

`db:types` applies a tested, bounded nullability correction because pg-meta cannot
infer nullable `RETURNS TABLE` outputs. It covers changed membership-origin results
and the new admission/preview/resolution/history fields; schema/type drift fails loudly.
The generated file is still produced by the repository command, never hand-edited.

## Verification

`110_participant_invitation_domain.test.sql` verifies access, identity, privacy,
photo exception, supersession/offers, receipts/re-entry, lifecycle and history.
`013_project_participation_structure.test.sql` is updated for the intentional
added schema columns. The runnable synthetic verifier is
`npm run project:participant-invites:verify:local`; it uses separate PostgreSQL
connections and observes lock waits before releasing the winning transaction.
Its fixtures persist until reset; run pgTAP first and verifiers sequentially.
It never prints tokens. Both `check:db` and hosted Database CI include it.

Local validation on 3 October 2026 used a disposable `planets-community-pi01`
Supabase stack with isolated ports; the repository stack configuration is unchanged.

| Command                                            | Result                                                                                                                                           |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `npm run check:db`                                 | Clean migration replay, lint/advisors, 107 pgTAP files / 3,377 assertions, every existing local verifier, and generated-type drift check passed. |
| `npm run project:participant-invites:verify:local` | Final 25 multi-connection scenarios passed, including both ordinary-approval/direct-admission orders for the same applicant.                     |
| `npm run check:mobile`                             | Formatting, static analysis and 1,140 tests passed.                                                                                              |
| `npm run check:web`                                | 28 tooling tests, 142 web tests, lint, typecheck and production build passed.                                                                    |
| `npm run check:site`                               | 34 unit tests, 19 worker tests, lint, typecheck, build and deployment dry-run passed.                                                            |
| `npm run format:check`                             | Repository formatting passed.                                                                                                                    |
| `git diff --check`                                 | No whitespace errors.                                                                                                                            |

The full local database run set `MAILPIT_URL=http://127.0.0.1:58324` for the
isolated stack. Windows host time ran several hundred milliseconds ahead of
Docker/PostgreSQL, causing existing host-timestamped fixtures to violate database
timestamp checks. An untracked, temporary Node preload aligned synthetic fixture
`Date` values with PostgreSQL time for that run. Database constraints, triggers,
assertions and repository scripts were unchanged. The final participant-only
verifier also passed without that preload. Hosted CI runs the standard commands
without either local adjustment; its final-head status and exact Git heads are
recorded in the PR/task completion report.

Production/native/browser-flow proof belongs to later plans and is not claimed here.
