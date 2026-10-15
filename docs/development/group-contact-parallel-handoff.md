# D contact lane: parallel revision handoff

Package: `PARALLEL-CD-2026-10-15-v1`. Owner: D00. C owns Group General/Ideas,
room invitations, folders, links and conversion. This file supersedes the old
requirement for an external integration coordinator; it does not approve the
old D privacy model.

## Source and current status

- Cumulative source: [D #254](https://github.com/lillo24/planets.community/pull/254),
  `codex/d-integration`; preserves all D00–D03 ancestry.
- Runtime checkpoint: `bd8e510a2007cd22f09b98494d248d177d1fc801`;
  final qualification and native follow-up are recorded below.
- Included main: `94af1c2eb707446baf7b7e027dff6ea997c9813e`.
- Peer inspected: [C #257](https://github.com/lillo24/planets.community/pull/257),
  `a72e9f867a5e5dda8f6059cbbdf445d494ea8b03`; unmerged, not imported.
- Main reconciliation preserves startup signed-out handling, compact card skills,
  event schedules, request UI, STAGING01 evidence and UIPOLISH02. Localization
  conflicts retain both contact copy and the actual skill/Workshop changes.
- Historical D validation qualifies `db17cd2`, not this revised source. Current
  results below distinguish full CI, focused checks and actual native journeys.

## Decision ledger

The active package and user instruction of 15 October 2026 authorize implementation,
parallel coordination and scoped source merge. No approval comments/reviews were
present in #244, #247, #249, #253 or #254 when inspected. Current main's product
decisions do not settle personal or representative chat lifetime. The following
specific questions were sent to the founder; no answer is inferred from silence.

| Topic                          | Classification / actual reference                              | Review candidate and dependent scope                                                                                                                                  |
| ------------------------------ | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Representation                 | User decision: package `00_START_HERE_D00`, requested behavior | Current Creator, Co-creator, Co-organizer; real human attribution; ordinary members cannot represent or publish through D                                             |
| Personal contact               | User decision: same section and D-M00 fixed flow               | Current canonical Group People; selected origin Group; named recipient explicitly accepts; no Project prerequisite or manager oversight                               |
| Group People                   | Existing implemented contract: GRP03A/GRP03B                   | Accepted membership and management are independent relationships; pending applicants/outsiders have no People/contact grant                                           |
| Pending D audience             | Unresolved D-R00 question                                      | All eligible target managers triage versus a named recipient; controls request note projections, acceptance, blocking and disclosure                                  |
| Accepted D audience            | Unresolved D-R00 question                                      | Submitter plus first acceptor versus explicit shared management audience; controls every chat projection and grant                                                    |
| Role loss / Leave / regrant    | Unresolved D-R00 question                                      | Existing candidate denies former content permanently; alternative retains pre-exit history read-only; replacement never silently inherits identity/history            |
| Multi-group disclosure/history | Unresolved D-R00 question                                      | Existing staged named/versioned all-party consent; fresh room and authored summary; no copied bilateral/C history                                                     |
| Member lifetime/history        | Unresolved D-M00 question                                      | Candidate stops sends/notices when either origin relationship ends and retains pre-end history read-only; alternative continues independently consented personal chat |
| Member identity/re-entry       | Review candidate, included in the question                     | Stable pair plus selected origin Group, separate explicit consent episodes; reverse requests deduplicate; rejoin alone does not restore sending                       |
| Bounds                         | Reversible implementation choices, not founder policy          | Existing documented finite operational limits remain synthetic values pending verification; no permanent ban/retention decision inferred                              |
| Individual-to-Group            | Deferred by active package                                     | No arbitrary individual-to-Group request endpoint                                                                                                                     |
| Distribution/erasure           | Outside source authorization                                   | No hosted migration, real-user contact, deployment or new legal retention rule                                                                                        |

All runtime depending on unresolved rows stays on this draft branch. A client
flag cannot make it mergeable. C does not wait for these decisions. Any separately
merged subset must state its exclusions and prove it has no dependent endpoint.

## Stage map

| Stage | Owner and work                                                         | Gate                                                                           |
| ----- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| D-R00 | This ledger, current-main reconciliation, delta and peer seams         | Record actual answers per row before dependent source merge                    |
| D-R01 | Existing `group_contact` backend/mobile; preserve receipts and safety  | Reconcile candidate or approved audience/history; complete real native path    |
| D-M00 | Member actor/state/history contract                                    | Founder lifetime/history answer; isolated synthetic model may proceed          |
| D-M01 | Separate canonical member authorization, request/episode/message owner | Real Auth, races, reporting, block, erasure, paging, upgrade and type evidence |
| D-M02 | Canonical People context and compact actions, private chat UI          | Deliberate request/accept; actual EN/IT narrow/large-text and Android journey  |
| D-R02 | Existing `group_coordination` extension                                | Exact audience/history answer and complete three-Group native path             |
| D-R03 | Messages, notices, unread, routing, moderation and current-main seams  | Preserve every installed kind and legacy parser; integrate C only after merge  |
| D-R04 | Final affected suites, current mergeability, source merge and cleanup  | Actual approved policy and final-source evidence, not historical green CI      |

## Shared API and migration seams

Current D uses `list_own_structured_request_message_items_v3`,
`get_own_structured_request_message_item_v3`,
`list_own_scoped_conversation_items_v6`, `get_own_message_unread_summary_v2`,
`acknowledge_own_message_read_v2` and own-report v3 in the original D source.
The member review implementation now composes these with Requests v4, Chats v7,
unread/ACK v3 and own-report v4. Verify effective signatures before allocating
another version, especially after C merges. Legacy contracts retain old kinds.
Added member kinds are `member_contact_request`, `member_contact_chat` and the
exact moderation target `member_contact_message`; their canonical authorization
is separate from `group_contact_request`, `group_coordination_proposal` and
`group_contact_chat`.

D migrations span `20261014072939` through `20261014125000` (ten files).
Four forward files add member domain/safety (`20261015095004` and
`20261015095042`), contact activity/preferences (`20261015095248`) and canonical
notification-worker preservation (`20261015110945`). There are fourteen D/M
migrations and 110 repository migrations at this checkpoint.
They are absent from main and remain unshipped review source; no applied main
migration is changed. Later integration must test actual sorted C/D migrations,
including populated predecessor report constraints and Block helper identity.
Regenerate database types from the resulting schema, never choose one side.

Shared owners include Messages request/chat models and gateways, unread/hints,
router, EN/IT localization, moderation evidence/dispatch, generated Web types,
package scripts and validation CI. Union/filter before paging, keep typed IDs,
count each human message once, and ACK only rendered foreground frontiers.
Invite notices are not human messages. Hiding/muting do not acknowledge reads.

Member conversations belong to Private. C manager oversight applies only to
planning rooms. The compact People sheet may invoke C's canonical Invite to Idea
operation after C lands; no duplicate invitation subsystem or unmerged import.
Current D routes are `/groups/:id/contact`,
`/messages/requests/group-contact/:id`, `/messages/chats/group-contact/:id`
and coordination routes documented by the owning feature. Login/setup never
submits or accepts an action. Receipt recovery never restores authorization.

## Worked acceptance examples

1. Alice and Bob are current People of Garden. Alice deliberately requests a
   personal conversation from Garden's People sheet. Bob accepts. Carol, Garden's
   manager, cannot read it. If Alice leaves, apply the recorded member lifetime
   decision consistently to body, preview, unread, notices and stale routes.
2. Alice represents Garden and contacts Workshop. The selected recipient policy
   controls who sees the note; the accepted audience is separately granted.
   Revoking Bob's representative grant applies the recorded D history rule,
   independently of Bob's ordinary Group or Project membership.
3. Alice proposes adding Library. Dana claims the Library seat; the reviewed
   candidate requires exact-version consent from every named human and creates
   a fresh room. Dana cannot read the original bilateral source or a C Idea.

## Validation and resource ownership

Use D-owned `planets-community-d-qa`, 55320–55329 / inspector 8183 and
`PLANETS_D_QA` on emulator 5580 only after checking ownership and current use.
Temporary secrets remain outside Git/logs. Never reset `planets-community`,
restart a shared engine, use C's ports/emulator, or overwrite the physical phone.
Inspect scripts before executing their local resets. Keep account tokens private.

Required evidence: clean replay; populated main→D and D02→coordination upgrades;
real Auth consent/retry/race/revocation/report/block/erasure checks; generated types;
full affected Mobile/Web/Database and CI; completed real-backend Android journeys;
inspected EN/IT narrow/large-text frames. Add populated combined C/D evidence if C
has merged. Physical Android, iOS, screen-reader and real-provider work remain
separate and must not be implied by emulator/widget tests.

Actual commands/results and final source references will be appended as completed.

## 15 October revision progress (not final qualification)

- Cumulative `2a8f13f3` includes main `94af1c2e` (UIPOLISH02 #264), member
  backend `43249d3e`, contact notices/mute `2319dfe4`, Web member moderation
  `c265610f`, revised representative/coordination harness `db536f1c`, and member
  mobile `2a8f13f3`. Main localization conflicts were resolved by retaining both
  skill/Workshop copy and contact copy; router and public discovery merged cleanly.
- Parent focused notification/representative run passed 95 tests. Focused analysis
  of both features and changed tests passed with no issues. This includes legacy
  notification parsers, minimal contact destinations, offline access invalidation,
  delayed mutation rejection, mute recovery without ACK, and narrow EN/IT widgets.
- Member branch focused runs passed 72 contract/consent/Message tests, 29
  auth-return/moderation tests and 95 actual People/Blocking/router/Message flow
  tests. These are separate runs, not a unique-test total. Final reconciled broad
  validation and actual member native qualification remain required.
- Web member moderation passed 78 tests across nine files, `next typegen`/`tsc`,
  and targeted ESLint. Optional introductions remain nullable; message bodies do
  not. Staff sees exact reported evidence with no surrounding conversation grant.
- D stack cold startup succeeded with the ten original D migrations and seed.
  The revised native harness passes analysis and 25 focused contact/coordination
  widget checks. Actual OTP fixture requests returned Auth HTTP 504/10-second
  timeout under shared-host contention; this is not a native journey pass.
- The D-owned emulator was stopped while D/C cold pulls and focused checks competed
  for host memory/CPU. No peer emulator, C container, shared engine or physical
  phone was stopped. C was updated through
  [its coordination thread](https://github.com/lillo24/planets.community/pull/257#issuecomment-6190007066).
- Member migrations `20261015095004`/`20261015095042` and notice migration
  `20261015095248` add three forward files. All three applied successfully on the
  isolated D stack. Focused pgTAP `140_member_contact` and `143_contact_activity_notices`
  passed 96 assertions. Database lint and security advisors passed after initial
  host connection timeouts. Actual schema types were regenerated with the standard
  nullability postprocessing at `1388d77a`; no generated types were hand-edited.
  Clean/populated replay, real-Auth verification and final CI remain pending.
  [Contact activity notices](contact-activity-notices.md) documents the bounded
  worker, additive readers and mute/message separation.

All privacy questions in the decision ledger remain open. User instruction to
continue execution does not select one of those consequential policy alternatives.
No dependent runtime has merged to main or been applied to a hosted environment.

The final member native target is now committed at `08edbe48`. It passed analysis,
fixture Node syntax and debug bundle compilation, with a fresh kernel artifact.
Actual driver execution and visual inspection remain required. It covers the
canonical People entry point, deliberate lost-response request/recovery, named
acceptance, Private/unread, mute, Block/unblock, independent origin episodes,
Close, Leave, last-context loss/rejoin and exact historical-message reporting.
The final notification controller regression run passed 17 tests at `070bdf3a`,
including ordinary message refresh preserving a pending activity read and member
access loss clearing cached notices offline. These are focused results; they are
not a completed full Mobile or native qualification.
No hosted operation has been performed.

## Final qualification checkpoint

- Published `db4035a2` received full classified
  [Validation run 560](https://github.com/lillo24/planets.community/actions/runs/38723943780).
  Site, Web and Mobile passed. Database populated upgrades, clean replay, lint
  and security advisors passed; its full SQL corpus ran 146 files / 5,338 tests
  with six legacy worker-structure failures. Subsequent Auth/type steps were
  skipped, so this is not a passing Database gate.
- The implementation fix is forward migration `20261015110945`, preserving the
  canonical public worker's original OID and composing the contact-page budget
  inside its existing resolver/locking loop. Existing failing tests were retained.
  Unexpected peer changes fail an explicit migration guard before replacement.
  The populated member upgrade verifier also checks worker identity preservation.
- That correction applied successfully on the owned database; affected SQL files
  019, 029, 054, 089, 140 and 143 passed all 208 assertions. The full clean Database
  and remaining CI gates must run on the final follow-up push.
- A local clean replay accepted all 109 migrations before the new correction;
  all fourteen D/M files are now installed after the successful forward apply.
  This incremental result is not described as a clean 110-file replay.
- Genuine member Auth verification passed 119 checks after a scoped restart of
  the verified D Auth container resolved OTP HTTP 504 failures. The earlier
  interrupted local populated-upgrade attempt is not a pass; CI's completed
  populated upgrades are the preservation evidence for `db4035a2`.
- C confirmed its containers and AVD 5582 are stopped while D completes native
  Auth checks. D uses only project `planets-community-d-qa`, explicit engine
  `planets-d-qa`, ports 55320–55329, inspector 8183 and AVD 5580. D will explicitly
  release the slot through the PR discussion after its checks/services finish.

Native completion, final source CI and all unresolved decision rows remain gates.
No policy answer is inferred from the instruction to continue.

## Later final-main review

Inspect the effective schema after all sorted migrations, not a stage's original
function declaration. The principal invariants and evidence owners are:

- Representative authority and history stay separate from ordinary membership:
  contact migrations/tests 134–137 and the genuine group-contact verifier.
- Coordination admits only exact-version named consent into a fresh history:
  coordination migrations/test 138 and the coordination Auth/native journeys.
- Personal requests use canonical origin People, named acceptance and separate
  consent episodes; managers gain no oversight: member migrations/test 140 and
  `verify-local-member-contact.mjs`.
- Invitations/activity never count as human unread, stale access is filtered
  before paging, and mute never acknowledges messages: Messages adapters,
  notification controller tests and SQL 143.
- Staff receives exact reported evidence without surrounding private history:
  versioned own-report/staff projections and Web moderation tests.
- If C lands later, compose its actual APIs, kinds and sorted populated schema
  before limits; preserve all existing Project/Resource/contact histories, then
  regenerate types. No combined C/D validation is claimed while C is unmerged.
