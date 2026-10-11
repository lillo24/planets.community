# CHECK01: private planning and Project Organization

Draft implementation for founder review. Do not merge or roll out until the
privacy/confirmation contract and compact mobile presentation are approved.
This change does not authorize staging migration, deployment or distribution.
Started from `59a05510f152737ca7e99a98175706079889595c`, then integrated current
main `c6a204efc27851eaa1f6b7b2f47eb3e7c73d702e` (including POLICY01B and the
LOCATION02 editor fix) before final validation.

## Ownership and contract

One-time Projects only. Organization is separate from Needs, claims, contribution
credit, Workspace and chat messages. No new notification or provider call.
`idea | defined` remains orthogonal to publication/cancellation. Individual
confirmation is not promotion; Ideas never become time-derived Completed.

`private.project_organization` stores a bounded proposed decision object and a
project-wide revision. Canonical `public.proposals` logistics and
`public.projects.registration_capacity` hold only official values. Private
tasks/receipts/capabilities have RLS enabled and no client/service-role grants.
No planner table is in the exposed Data API.

- `get_project_organization_v1(expected_profile_id, project_id) -> jsonb` returns
  a current-identity/current-group snapshot, including proposal/official values,
  permissions, readiness and ordered tasks.
- `mutate_project_organization_v1(expected_profile_id, project_id,
expected_revision, request_id, command) -> jsonb` returns authoritative readback.
  Commands: `save_decision`, `confirm_decision`, `add_task`, `edit_task`,
  `remove_task`, `set_task_done`, `move_task`. Decision kinds: `location`,
  `schedule`, `capacity`. See the migration and REST verifier for exact payloads.
- Both recheck account identity and current Workspace-equivalent entitlement.
  Creator access works before chat activation. Decision writes additionally
  require Creator/current Co-creator structural authority, complete profile and
  a current photo. Co-organizers and accepted participants may add/check tasks.
- Locks are concrete Proposal -> shared Project -> Organization. Global CAS
  intentionally conflicts even on independent edits. Actor/request-bound retry
  receipts recover an identical current revision without another event. Changed
  retry input fails `22023`; stale/superseded revision fails `PT409`. Revocation
  is checked before receipt recovery. Reload after a lost response; do not invent
  success or resend with a newly rebased revision.

Location proposals contain only bounded text and optional country/locality/region/
label strings. No coordinates, provider receipts or exact venue fields. Ambiguous
text-only suggestions can be saved but not confirmed. Structured city confirmation
uses the existing manual-city representation, with no invented geometry/pin.
Changed city invalidates old precise selection through LOCATION02's canonical
revision triggers. Exact directions/visibility are separate protected content.

Schedule proposals use finite ordered timestamps and an IANA zone, including
multi-day intervals. Confirmation requires a future start. An elapsed official
start remains public but the decision says Update date and promotion rejects it.
Capacity proposals require integer 1..100,000 plus organizer-counting Boolean.
Only confirmation invokes existing occupancy/admission serialization and floors;
private proposals never impose or relax admission limits.

Confirmation consumes the proposal and writes official values atomically; an
alternative remains private until reconfirmed. One identifier-only audit/outbox
event is emitted. Save/task operations emit no chat/notification event.

Tasks: 120 total, 160 trimmed characters, stable UUIDs, immutable project/parent/
author, root plus one child level. Parent completion is derived from children.
Adding a child reopens a completed leaf under the same lock. Current members can
toggle any leaf and edit/remove their own tasks; removing a root containing another
author's child is denied. Creator/Co-creator can edit/reorder/remove all. No
reparenting, assignment, deadline or new task lifecycle. End/cancellation freezes
mutations. Archive reads remain **current-group-only**, not former-chat-history
access; the mutable planner is not a historical message log.

## Compatibility investigation and rollout gate

The previous IDEA01 implementation put tentative fields in public canonical
columns. This is a deliberate contract change, not a visual hide:

| Existing path                                                        | CHECK01 boundary                                                                                                                                                                                   |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `publish_proposal_idea`                                              | Publication trigger captures entered draft logistics/capacity privately, clears public logistics and finite cap; precise content stays protected.                                                  |
| `update_own_proposal` overloads / `private.replace_proposal_content` | Published-Idea table triggers reject changed canonical logistics/capacity, including old clients, with `PT409`; ordinary unchanged-field content edits remain valid.                               |
| structural capacity helper / join and invitation admissions          | Confirmation alone obtains a private transaction capability and uses the existing helper/locks/floor. A client-set GUC cannot bypass it.                                                           |
| location mutations/receipts                                          | Canonical Idea city/broad-field changes without confirmation fail atomically; exact fields retain independent authorization/revisions. Defined/draft controlled location editor remains unchanged. |
| v2 public/list/own/requested/delegated reads                         | Read official canonical fields only; no private planner join. Public web/share/invite readers reuse this projection.                                                                               |
| strict v1, Map/SIM01, templates                                      | v1 still excludes Ideas; all Ideas remain excluded from Map/SIM01. First-publication private template identity/text baseline is retained; reusable completion still requires Defined.              |
| promotion                                                            | Existing official requirements and atomic transition, preserving ID/chat/members/invitations/template identity; proposals cannot satisfy requirements.                                             |

Migration `20261011100002_project_organization_private_planning.sql` **stops with
55000 before schema changes** if any legacy Idea contains canonical schedule,
city/broad-location data or finite capacity (including cancelled Ideas).
It does not infer publication consent, reclassify tentative content or remove a
capacity relied on by members. The upgrade verifier populates a legacy Idea with
finite capacity and accepted membership, attempts the real migration, compares
unchanged records and proves no partial planner schema before clean replay.

Read-only staging aggregate on 2026-10-11 found 3 Projects and 0 Ideas; this is
point-in-time evidence, **not rollout permission**. Repeat the audit immediately
before a separately authorized rollout. If nonempty, founder choices include
explicit per-Project confirmation of known-public values, or a reviewed private
proposal conversion with admission-safe capacity handling. Neither is automated
here. Do not erase a finite cap or silently label old tentative values official.

Apply the reviewed migration before compatible clients. Old strict readers remain
strict; old writes crossing the new boundary fail safely. No published-Idea
canonical clearing/reset RPC is added. Correct official values through a replacement
proposal and confirmation. Draft/Defined/Tavolo/Scambio behavior is unchanged.

## Mobile and visual review

Chat tools: Needs -> Organization -> Workspace. One-time management also links
the sheet before chat exists. Published-Idea content editing links the same planner
instead of exposing legacy logistics controls; protected arrival directions remain
editable separately. Precise provider receipt selection remains in the normal
draft/Defined location editor; Organization makes no paid lookup and offers only
manual city confirmation. Closing the planner from the editor exits the old form
to avoid resaving its obsolete canonical snapshot.

Three compact action/status rows, no value subtitle/second heading. Missing uses
neutral question/chevron; Proposed is explicit and never checked. Only official
current values are checked. Expanded pending replacements retain the currently
public value for comparison. Large text uses short visible labels with full
screen-reader action/status labels. Read-only expansion replaces the action text
with its saved value in the original row, not a second value heading. Unsaved editor changes disable confirmation
of the previous persisted proposal. Saving has no publication effect; the separate
one-sentence confirmation dialog explains public officialization.

Private state is memory-only, identity/profile bound, cleared on failures, account
change, background/inactive and close. Foreground polling every 20 seconds plus
resume/manual reload is an authoritative role/readback, not another Realtime
domain. A detected chat entitlement loss clears it immediately; every mutation
reauthorizes. No claim of instantaneous cross-device revocation while offline.

The pure task-owned fixture/previews use fictional data and no backend identity.
Review PNGs in `apps/mobile/test/features/project_organization/goldens/` cover
missing/proposed/confirmed, expanded replacement, nested tasks, EN/IT, 320dp,
1x/2x and light/dark. They are rendered Flutter widget evidence, **not native
emulator screenshots or physical-phone/TalkBack qualification**. Roboto and
MaterialIcons load from the installed Flutter SDK; pixel baselines are Windows-only
to avoid pretending cross-platform font rasterizers are identical. Layout and
interaction assertions still run on every platform. `proposed-it-1.0-false.png`
and `proposed-it-expanded.png` show the same fixture before/after row expansion.
Native fixture/physical-device review remains unrun. No protected live data
appears in images.

## Reproduction

Use a new disposable checkout/stack, not a retained demo. Local execution uses
uncommitted project `planets-check01-qa`, API 59521 / DB 59522 / Mailpit 59524.
Set `PLANETS_DISPOSABLE_QA=1`, `MAILPIT_URL=http://127.0.0.1:59524`, and ensure
the pinned Supabase binary is on PATH. Restore ordinary config before commit.
On this Windows host, the Web build needed `NODE_USE_SYSTEM_CA=1` and
`NEXT_TURBOPACK_EXPERIMENTAL_USE_SYSTEM_TLS_CERTS=1` to fetch Google Fonts through
the system trust store. These are process-local validation settings, not a
repository configuration change or disabled TLS verification.

- `npm run project:organization:upgrade:verify:local` resets only an explicitly
  disposable non-default loopback stack to the populated predecessor, proves the
  rollout refusal, then restores full forward replay.
- `npm run check:db` includes transactional `129_project_organization.test.sql`
  and real OTP/JWT Organization checks composed by `proposal:verify:local`.
- `npm run check:mobile`, `npm run check:web`, `npm run check:site`.
- `flutter test test/features/project_organization/project_organization_test.dart
--update-goldens` (from mobile) deliberately regenerates review images.
- `flutter run -d chrome --target=test_support/check01_previews.dart` runs the
  standalone data-free debug fixture, never the product backend or a live session.

See the draft PR for exact final-head pass/fail/unrun evidence. No hosted database
write, retained-demo reset, provider activation, distribution or merge is included.
