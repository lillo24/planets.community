# D contact lane: parallel revision handoff

Package: `PARALLEL-CD-2026-10-15-v1`. Owner: D00. C owns Group General/Ideas,
room invitations, folders, links and conversion. This file supersedes the old
requirement for an external integration coordinator; it does not approve the
old D privacy model.

## Source and current status

- Cumulative source: [D #254](https://github.com/lillo24/planets.community/pull/254),
  `codex/d-integration`; preserves all D00–D03 ancestry.
- Reconciled commit: `28885237c9b7d7bf11a4815f069469e905a3eac4`.
- Included main: `6b5f419e8a62763d7dc70952bb135d4b6f8fcf09`.
- Peer inspected: [C #257](https://github.com/lillo24/planets.community/pull/257),
  `e8c5c8c7317cf0df22b9a534200586637e7b18f2`; unmerged, not imported.
- Main merge had no textual conflicts. Startup signed-out handling, compact card
  skills, event schedules, request UI and STAGING01 evidence were retained.
- Historical D validation qualifies `db17cd2`, not this revised source. The
  previous incomplete Android journey is still a failure to qualify, not a pass.

## Decision ledger

The active package and user instruction of 15 October 2026 authorize implementation,
parallel coordination and scoped source merge. No approval comments/reviews were
present in #244, #247, #249, #253 or #254 when inspected. Current main's product
decisions do not settle personal or representative chat lifetime. The following
specific questions were sent to the founder; no answer is inferred from silence.

| Topic | Classification / actual reference | Review candidate and dependent scope |
| --- | --- | --- |
| Representation | User decision: package `00_START_HERE_D00`, requested behavior | Current Creator, Co-creator, Co-organizer; real human attribution; ordinary members cannot represent or publish through D |
| Personal contact | User decision: same section and D-M00 fixed flow | Current canonical Group People; selected origin Group; named recipient explicitly accepts; no Project prerequisite or manager oversight |
| Group People | Existing implemented contract: GRP03A/GRP03B | Accepted membership and management are independent relationships; pending applicants/outsiders have no People/contact grant |
| Pending D audience | Unresolved D-R00 question | All eligible target managers triage versus a named recipient; controls request note projections, acceptance, blocking and disclosure |
| Accepted D audience | Unresolved D-R00 question | Submitter plus first acceptor versus explicit shared management audience; controls every chat projection and grant |
| Role loss / Leave / regrant | Unresolved D-R00 question | Existing candidate denies former content permanently; alternative retains pre-exit history read-only; replacement never silently inherits identity/history |
| Multi-group disclosure/history | Unresolved D-R00 question | Existing staged named/versioned all-party consent; fresh room and authored summary; no copied bilateral/C history |
| Member lifetime/history | Unresolved D-M00 question | Candidate stops sends/notices when either origin relationship ends and retains pre-end history read-only; alternative continues independently consented personal chat |
| Member identity/re-entry | Review candidate, included in the question | Stable pair plus selected origin Group, separate explicit consent episodes; reverse requests deduplicate; rejoin alone does not restore sending |
| Bounds | Reversible implementation choices, not founder policy | Existing documented finite operational limits remain synthetic values pending verification; no permanent ban/retention decision inferred |
| Individual-to-Group | Deferred by active package | No arbitrary individual-to-Group request endpoint |
| Distribution/erasure | Outside source authorization | No hosted migration, real-user contact, deployment or new legal retention rule |

All runtime depending on unresolved rows stays on this draft branch. A client
flag cannot make it mergeable. C does not wait for these decisions. Any separately
merged subset must state its exclusions and prove it has no dependent endpoint.

## Stage map

| Stage | Owner and work | Gate |
| --- | --- | --- |
| D-R00 | This ledger, current-main reconciliation, delta and peer seams | Record actual answers per row before dependent source merge |
| D-R01 | Existing `group_contact` backend/mobile; preserve receipts and safety | Reconcile candidate or approved audience/history; complete real native path |
| D-M00 | Member actor/state/history contract | Founder lifetime/history answer; isolated synthetic model may proceed |
| D-M01 | Separate canonical member authorization, request/episode/message owner | Real Auth, races, reporting, block, erasure, paging, upgrade and type evidence |
| D-M02 | Canonical People context and compact actions, private chat UI | Deliberate request/accept; actual EN/IT narrow/large-text and Android journey |
| D-R02 | Existing `group_coordination` extension | Exact audience/history answer and complete three-Group native path |
| D-R03 | Messages, notices, unread, routing, moderation and current-main seams | Preserve every installed kind and legacy parser; integrate C only after merge |
| D-R04 | Final affected suites, current mergeability, source merge and cleanup | Actual approved policy and final-source evidence, not historical green CI |

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
  `20261015095248` add three forward files. Their clean/populated replay,
  real-Auth verification, pgTAP, generated types and final CI remain pending.
  [Contact activity notices](contact-activity-notices.md) documents the bounded
  worker, additive readers and mute/message separation.

All privacy questions in the decision ledger remain open. User instruction to
continue execution does not select one of those consequential policy alternatives.
No dependent runtime has merged to main or been applied to a hosted environment.
No hosted operation has been performed.
