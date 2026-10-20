# D contact lane: parallel revision handoff

Package: `PARALLEL-CD-2026-10-15-v1`. Owner: D00. C owns Group General/Ideas,
room invitations, folders, links and conversion. This file supersedes the old
requirement for an external integration coordinator; it does not approve the
old D privacy model.

## Source and current status

- Cumulative source: [D #254](https://github.com/lillo24/planets.community/pull/254),
  `codex/d-integration`; preserves all D00–D03 ancestry.
- Published D predecessor: `9ea6ca3f`; post-ACTSPLIT01 qualification and the
  remaining native follow-up are recorded below.
- Main integration target: `89292af4b084dc2bbd9748797227531b13abe8cc`, the actual
  C merge. Combined qualification is in progress as recorded below. Its preceding
  `9fc89268` map-plan documents do not authorize executing those plans here.
- Peer inspected: [C #257](https://github.com/lillo24/planets.community/pull/257),
  `99407174f6d183716e32464963aa40121a0431d3`; merged by `89292af4` on 20 October.
- Main reconciliation preserves startup signed-out handling, compact card skills,
  event schedules, request UI, STAGING01 evidence and UIPOLISH02. Localization
  conflicts retain both contact copy and the actual skill/Workshop changes.
  MAPUI03 and MAPFIX03 are included; shared discovery screens retain both main's
  independent city attribution and D's explicit contact/Project-join entries.
  UIPOLISH03 is also included; both localization sets and native guides survive,
  and the Project detail retains D's contact entry beside the current sections.
  ACTSPLIT01 is included as a device-local, default-off discovery experiment;
  canonical Group/contact routes and permissions remain independent of examples.
- Historical D validation qualifies `db17cd2`, not this revised source. Current
  results below distinguish full CI, focused checks and actual native journeys.

## Decision ledger

The active package and user instruction of 15 October 2026 authorize implementation,
parallel coordination and scoped source merge. On 19 October 2026 the founder
explicitly wrote in this task: "I approve policies 1 and 2 for group-representative
communication." This approves the pending/accepted audience, representative
history/regrant and named/versioned fresh coordination choices below. The same
message explicitly withholds policy 3 pending clarification, asks for authorized
Android testing (or a safe manual procedure if automation remains unavailable),
and authorizes cumulative merge after the remaining policy and validation gates.
Hosted database and Play Store deployment are explicitly excluded. The reference
is the human message in this task; no transcript URL is invented.

| Topic                          | Classification / actual reference                              | Review candidate and dependent scope                                                                                                                            |
| ------------------------------ | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Representation                 | User decision: package `00_START_HERE_D00`, requested behavior | Current Creator, Co-creator, Co-organizer; real human attribution; ordinary members cannot represent or publish through D                                       |
| Personal contact               | User decision: same section and D-M00 fixed flow               | Current canonical Group People; selected origin Group; named recipient explicitly accepts; no Project prerequisite or manager oversight                         |
| Group People                   | Existing implemented contract: GRP03A/GRP03B                   | Accepted membership and management are independent relationships; pending applicants/outsiders have no People/contact grant                                     |
| Pending D audience             | Approved: human policy 1, 19 October 2026                      | All eligible target managers triage the pending request; only the disclosed pending audience receives its note                                                  |
| Accepted D audience            | Approved: human policy 1, 19 October 2026                      | Submitter plus first accepting human; other managers do not inherit chat admission/history                                                                      |
| Role loss / Leave / regrant    | Approved: human policy 2, 19 October 2026                      | Role loss/own Leave denies former content; regrant/replacement inherits none; Close preserves read-only history for still-valid admissions                      |
| Multi-group disclosure/history | Approved: human policy 2, 19 October 2026                      | Staged named/versioned all-party consent; fresh room and authored summary; no copied bilateral/C history                                                        |
| Member lifetime/history        | Unresolved D-M00 question                                      | Candidate stops sends/notices after loss of either person's last origin relationship and retains pre-end history; alternatives remove history access or defer M |
| Member identity/re-entry       | Review candidate, included in the question                     | Stable pair plus selected origin Group, separate explicit consent episodes; reverse requests deduplicate; rejoin alone does not restore sending                 |
| Bounds                         | Reversible implementation choices, not founder policy          | Existing documented finite operational limits remain synthetic values pending verification; no permanent ban/retention decision inferred                        |
| Individual-to-Group            | Deferred by active package                                     | No arbitrary individual-to-Group request endpoint                                                                                                               |
| Distribution/erasure           | Outside source authorization                                   | No hosted migration, real-user contact, deployment or new legal retention rule                                                                                  |

All runtime depending on unresolved rows stays on this draft branch. A client
flag cannot make it mergeable. C does not wait for these decisions. Any separately
merged subset must state its exclusions and prove it has no dependent endpoint.

Policy 3 covers only a named private request from one current Group person to
another through that Group's authorized People list. Canonical eligibility is
current membership **or** current management authority; losing one relationship
does not end an episode while the other remains. Both must qualify at request and
acceptance. There is no public people directory, profile-based arbitrary contact,
manager oversight or free-form messaging before acceptance. Existing Project/
Resource conversations and C rooms are separate scopes.

The unresolved candidate ends sending/notices when either person loses their last
qualifying origin relationship, or explicitly closes/leaves. Both retain only
their authorized episode history, including incoming messages within that boundary
that were not yet read. Rejoin requires fresh request/acceptance. A temporary Block
stops sending/notices but does not itself terminate a live episode; unblock can
restore sending only if that episode and both origin relationships still qualify.
This differs from representative access because the latter is tied to a specific
authority grant. The difference is a product choice, not a technical requirement,
and policies 1/2 do not approve member history retention.

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
Six forward files add member domain/safety (`20261015095004` and
`20261015095042`), contact activity/preferences (`20261015095248`) and canonical
notification-worker preservation (`20261015110945`), followed by canonical Block
lock-order correction (`20261015114510`) and erased-subject report provenance
(`20261019073011`). There are sixteen D/M migrations and 112 repository migrations
at this checkpoint. All sixteen applied on the owned local stack, including a
complete clean replay of the 112-file repository history.
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

At inspected C `7183efe0`, the implemented unread reader is
`get_own_message_unread_summary_with_discussions(uuid)`, based on the legacy
summary; the `_with_discussions_v2` name in C's handoff is not yet implemented.
The later integrator must inspect the final C source, compose its room unread
with D v3 totals without duplicate Project-folder counts, and preserve C's
`acknowledge_group_discussion_read_v2(uuid,uuid,text)` snapshot ACK alongside D's
UUID-boundary ACK. C's canonical People invitation is
`invite_group_discussion_member(uuid,uuid,uuid,uuid)`, with an Idea picker filtered
by its actual `can_invite` capability. These are read-only integration notes, not
an import or qualification of unmerged C.

Read-only preflight against C's unchanged seven-file migration tree found no
direct collision with D's erased-subject constraint/staff-reader correction.
The sorted combined tree would contain 119 migrations. This is not combined
qualification: after C lands, replay all files and both populated lane orders,
including mixed C/D/M report evidence, exact target/key-reuse isolation, live C
versus erased D/M and official-template labels, and warmed staff-reader
OID/ACL/result contracts. Preserve full SQL test filenames where numeric prefixes
overlap; separate standalone upgrade checks do not prove the mixed corpus.

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

## Final qualification checkpoint (supersedes earlier progress)

- Published `73c90a30` passed every job in full classified
  [Validation run 564](https://github.com/lillo24/planets.community/actions/runs/38732122661).
  Database completed clean replay of all 111 migrations, lint/security advisors,
  146 SQL files / 5,350 assertions, all Auth verifiers and generated-type checks.
  Populated upgrades preserved 121 existing table snapshots for main-to-D,
  130 for D02-to-coordination and 133 for the member predecessor upgrade;
  repeat application was harmless. C remains absent from this qualification.
  Mobile passed formatting, analysis and 3,494 tests (two existing skips).
  Web passed 98 tooling tests and 395 application tests (two existing skips),
  lint, typecheck, build and invitation checks. Site passed 41 client and 19
  waitlist tests, lint, typecheck, build and deployment dry-run.
- The implementation fix is forward migration `20261015110945`, preserving the
  canonical public worker's original OID and composing the contact-page budget
  inside its existing resolver/locking loop. The six legacy structure assertions
  that failed run 560 were retained and now pass in run 564.
  Unexpected peer changes fail an explicit migration guard before replacement.
  The populated member upgrade verifier also checks worker identity preservation.
- That correction applied successfully on the owned database; affected SQL files
  019, 029, 054, 089, 140 and 143 passed all 208 assertions before the further
  Block-order regression was added.
- Additional review found the member wrapper prelocked a partial Group set before
  legacy Project/Resource closure. Forward `20261015114510` instead adds member
  origins at the predecessor's single complete legacy/coordination Group union,
  then delegates before member-pair cleanup. Guards and postconditions preserve
  both function OIDs/ACLs and reject unexpected source changes. Ten added SQL
  assertions and a real-Auth regression independently observe Block waiting on a
  Project row while affected Groups remain lockable with `NOWAIT`. Actual apply,
  70 member SQL assertions and 125 genuine member Auth checks passed locally;
  run 564 independently passed the same regression. Contact and coordination
  verifiers passed 62 and 218 genuine Auth checks respectively in that CI run.
- At `73c90a30`, all fifteen then-existing D/M files were installed locally. Its earlier
  109-file clean replay plus incremental forward applies is distinguished from
  CI's subsequent complete 111-file clean replay. The interrupted local populated
  upgrade attempt is not a pass; completed CI upgrades supply preservation proof.
- Later Mobile corrections at `e6a51725` fix bounded lazy-page reveal, exclude
  text-field inner scrolling, require real keyboard insets, and suppress the
  generic ineligibility note while member delivery is unresolved. The latter's
  lost-response/access-refresh/recovery regression passed all 11 screen widgets
  and focused analysis. Main was then reconciled at `1b59a82b`. These changes
  still require final-source native and CI qualification.
- The acceptance audit added explicit member request-lifecycle/account-erasure
  checks and mixed Requests v4/Chats v7 pagination. Dedicated SQL 144 passed 97
  assertions across old/current readers, tied domain IDs and more than one page
  per kind. Expanded genuine member Auth reached post-erasure reporting, then
  failed the inherited template-provenance CHECK. Forward `20261019073011` now
  composes the effective constraint with a five-contact-kind exception and fixes
  canonical staff labels without changing reader identities/grants. The subsequent
  19 October qualification below includes actual application and completed reruns.
- The 15 October rebuilt native attempts reached genuine keyboard input, request
  recovery, explicit acceptance and first human messages, then failed actual chat
  keyboard overflows (D 9.3 px; M 153 px). Both remain failed journeys. Reproducing
  EN/IT widgets now pass with bounded composers; M also bounds context/status.
  D's further denial/offline keyboard cases reproduced 245/365 px overflows and
  now pass while proving immediate content removal and exact known reporting
  without a content reread/ACK. Final D screen suite: 17 passed; M: 13 passed.
- All 22 contact-flow FilledButtons now use the existing 12 px rectangle radius,
  preserving multiline-label contrast without changing global theme or copy.
  The 32 scoped screen tests and analysis passed; before/after production submit
  and accept renders cover EN/IT at 320dp/2x. Final emulator frames remain needed.
- Final source review found forbidden older-page reads retained already loaded
  private body/composer/ACK state when no access hint arrived. `164d41c2` clears
  that state in both D/M screens and invalidates the pending read revision;
  transient failures retain the same cursor and draft for retry. Successful older
  pages preserve the exact incoming report ID actually loaded, including when the
  newest page contained only the actor's messages. Four regressions failed on
  the old source and passed after correction; both full changed screen suites
  passed all 34 tests and focused analysis was clean. No backend contract changed.
- Fresh 19 October localization generation and serial debug APK builds passed on
  native `0e874157`, whose tracked Mobile source matches parent `164d41c2` exactly
  (D 175.4 seconds; M 116.1 seconds). Distinct ignored APK copies retain the exact
  targets/fixtures; these are build results, not completed native journeys.
- Actual 19 October attempts remain failed. The first D run stopped before any
  contact submission when Android System UI's ANR overlay blocked the required
  real keyboard inset. The unchanged retry passed that assertion and representative
  request/recovery/triage/acceptance/chat, then found a 57px overflow in the
  coordination Group picker at inner 208×566.7 / 320dp / 2x text. M produced 20
  English/Italian Flutter captures plus a verified full-device Gboard capture,
  then failed canonical unread-zero after revealing the message body short of
  the card's timestamp/Report end. Effective API/token contracts and database
  snapshots agree; the production ACK guard correctly requires the settled
  newest viewport. The picker layout and explicit harness user-scroll traversal
  have separate regressions; no assertion is removed or weakened.
  Sanitized failures are retained at
  `C:/Users/utente/.planets/qa/d-contact-2026-10-19-native-0e874157`
  in distinct `failed-d-system-ui`, `failed-d-picker` and `failed-m-unread` folders.
- `e5ecab6b` replaces the picker's fixed header/collapsed result area/footer with
  one bounded ListView. Four real-font regressions reproduced the exact native
  English 57px overflow plus Italian/keyboard failures before the correction;
  all four pass afterward, alongside six existing coordination screen tests.
  EN/IT rendered selection/confirmation frames and focused analysis passed.
  `1dded63d` adds actual member-history scroll gestures and explicit actor/token/
  route/lifecycle/ticker/settled-end checks before the unchanged backend unread
  assertion. Thirteen focused tests, including body-visible-without-ACK then
  exact-boundary ACK after scrolling, and focused analysis passed. Both corrected
  APKs subsequently built successfully on native `42b685be`, with tracked Mobile
  identical to parent `1dded63d` (D 190.6 seconds; M 114.7 seconds), using fresh
  fixtures. Localization generation passed; complete real-backend reruns remain
  required.
- The subsequent `42b685be` native attempts remain failed, with distinct evidence
  at `C:/Users/utente/.planets/qa/d-contact-2026-10-19-native-42b685be`.
  D passed actual keyboard input, request recovery, acceptance, chat, the corrected
  picker, declined coordination, audience change and consent reset, then failed
  when an awaited readiness pump disposed the lazy Recover row before its tap.
  Canonical state was active/version 4 with the three exact named seats confirmed.
  Its archive contains 14 Flutter captures and the sanitized failed log. M passed
  actual keyboard input, EN/IT consent/chat, mute, Private and the unchanged backend
  unread-zero assertion after real history gestures, then applied Block and failed
  to reveal the center of the long read-only notice. Its archive contains 26 PNGs
  and the sanitized failed log, including a full-device Gboard capture. Neither
  attempt produced a RenderFlex overflow. D's device captures were taken after
  keyboard dismissal; its positive keyboard-inset assertion is distinguished from
  keyboard pixels in the M device capture.
- `962f0cc1` keeps final D action readiness and its real tap in the same frame,
  re-finding lazy children after each earlier reveal/wait. Both EN/IT regressions
  reproduced the exact zero-widget failure with the old extra pump and pass with
  the correction; all eight changed/existing coordination tests and focused
  analysis pass. Native checks additionally require one final confirmation and
  one explicit recovery of that same action UUID with the canonical replayed
  active receipt and exact fresh chat ID. Production behavior is unchanged.
- `abbc370f` reveals already-built member content through its actual nearest
  scrollable and centers an oversized notice, preserving the bounded lazy-row
  search for absent targets. EN/IT real-screen regressions reproduce the clipped
  leading alignment at 320dp/2x, then traverse overlapping notice portions to
  expose all text without moving older chat history or acknowledging its fresh
  pending boundary. Both notice tests, the frontier regression and twelve unread
  tests pass (15 total), with focused analysis/formatting clean. Production code
  and the actual user-gesture frontier helper are unchanged.
- Both fresh APKs rebuilt successfully at native `1bcf6087`, whose tracked Mobile
  source is identical to cumulative `abbc370f`: D 157.6 seconds and M 115.5
  seconds, with localization generation passing. The exact targets use separate
  private, fresh fixtures and saved APKs; these builds do not by themselves
  qualify either complete native journey.
- The next native launch at `1bcf6087` was blocked before execution by automatic
  approval review. D's seven owned containers had started and Auth returned HTTP
  200, but the explicit hidden `PLANETS_D_QA` / 5580 launch returned only
  `rejected: blocked by policy`, with no specific rationale. The command already
  used verified absolute SDK/AVD targets, fixed port, two cores and 1536 MiB.
  No emulator or native test started, and no alternate launch route was attempted.
  This is an environment/policy blocker, not a native pass or a new runtime
  failure. The source and both built APKs remain available for the required
  complete journeys once that boundary is resolved. Full source CI proceeds
  independently; its current-head results belong to the cumulative PR checks.
  Sanitized preflight/localization/build logs and an explicit NOT RUN/BLOCKED
  manifest are retained at
  `C:/Users/utente/.planets/qa/d-contact-2026-10-19-blocked-1bcf6087`, without
  private defines or APKs. The unconsumed fixtures were not refreshed.
- Web's five-kind erased-subject parser correction passed 31 focused tests,
  typecheck, ESLint and formatting. Independent read-only review found no
  actionable security/upgrade defect in the narrow database correction. Its
  populated upgrade verifier now checks staff reader OIDs, ACLs and return shapes;
  actual populated execution passed below; final-source CI remains pending.
- On 19 October, local native-worktree `9ac2c2bb` (source-equivalent to parent
  `b5351a6f`) passed forward application, the populated member upgrade with all
  133 existing table/column/row snapshots and warmed reader/worker identities,
  grants and return shapes preserved, and a complete clean replay of all 112
  migrations plus seed. SQL 074/075/081/112/128/145 passed 241 assertions after
  replay. Standard database lint, security advisors and generated-type drift
  checks passed. The expanded genuine member Auth verifier passed all 248 checks,
  including observed lock waits, terminal/cooldown/rate boundaries, scoped
  synthetic erasure, old-token denial and exact post-erasure reporting.
  SQL 145's initial varchar/text pgTAP overload error was corrected explicitly;
  earlier global-count failures against retained native fixtures were rerun on
  the required clean database, without weakening their assertions. Sanitized
  logs and the source manifest are retained outside the checkout at
  `C:/Users/utente/.planets/qa/d-contact-2026-10-19-backend-9ac2c2bb`.
- D uses only project `planets-community-d-qa`, explicit engine `planets-d-qa`,
  ports 55320–55329, inspector 8183 and AVD 5580. Under the latest explicit
  [19 October native-slot handoff](https://github.com/lillo24/planets.community/pull/257#issuecomment-6264362161),
  D's seven reverified containers and AVD 5580 are stopped with volumes preserved,
  empty listeners/devices, and no SDK/build process. C owns the next native slot;
  D's last attempted launch was denied as described above. Corrected APKs and
  complete native journeys still require qualification after that policy boundary
  is resolved and a new explicit resource handoff is agreed.
  Old exposed synthetic identities were retired and their old tokens verified
  denied. Private defines and instrumented APKs remain outside Git/logs. Failed
  native evidence is retained separately at
  `C:/Users/utente/.planets/qa/d-contact-2026-10-15-final-a62ef3bc-1252`.

Native completion, passing current-head source CI and all unresolved decision rows
remain gates. The cumulative PR's current-head checks and qualification comments
record final CI results without a results-only source push.
No policy answer is inferred from the instruction to continue.

## 19 October ACTSPLIT01 main reconciliation

Main `32f37791` was merged at `c56629b0`. Only the two appended ARB sections
conflicted. All keys and values from both D and main were compared after the
resolution and preserved exactly, including 29 new keys per language. Router,
Proposal and Tavoli changes merged without conflicts. The local preference
refreshes the existing router and gates only `/activities` routes; it does not
grant contact authority, replace native domain records or submit an action.

Before this reconciliation, published `defa69fe` passed every job in
[Validation 572](https://github.com/lillo24/planets.community/actions/runs/39233252766):
112 migrations, 148 SQL files / 5,508 assertions, populated preservation of
121/130/133 table snapshots, and genuine contact 62 / coordination 218 / member
248 Auth checks. Mobile passed 3,582 tests with two existing skips, formatting
and analysis; Web passed 98 tooling and 398 application tests with two existing
skips, and Site passed 41 client / 19 waitlist tests, with all standard checks.
The first Database attempt applied all migrations then failed because runner
port 54324 was already in use; only that failed job was retried, without changing
source or assertions. These results qualify `defa69fe`, not the changed Mobile
source after ACTSPLIT01.

Database, scripts, Web, Site, dependency manifests and validation configuration
are unchanged from that green source. The real `PlanetsApp`/router regression in
`navigation_shell_test.dart` selects a represented Group through the actual UI,
enters a title/note, and changes the preference OFF/ON/OFF. It proves the same
router, route, compose State/controllers, source and input survive, with no
submission/recovery and an empty attempt registry. Unknown RPCs fail explicitly,
including those caught by a screen boundary; native Group parent reads use exact
test envelopes rather than a competing route/controller.

The regression passed separately, then one combined run of app/bootstrap,
settings, activities, geographic discovery, D/coordination/member and Messages
passed all 609 tests. Localization generation, formatting and full Flutter
analysis passed (no issues). Agent `1f699b42` and cumulative `5404efc8` have
identical tracked Mobile source. Sanitized focused/analyzer logs and a source
manifest are retained at
`C:/Users/utente/.planets/qa/d-contact-2026-10-19-actsplit-5404efc8`.
The SDK slot was explicitly returned to C after all test/analyzer processes exited;
no D build, backend or emulator was started during this integration window.

Post-integration source CI is required and recorded on the cumulative PR.
Corrected-source native completion and the remaining member lifetime/history
decision remain gates; representative policies 1 and 2 were subsequently approved
as recorded above. Earlier APK builds
precede ACTSPLIT01 and their fixtures have expired, so future native QA requires
fresh fixtures and current-source builds after launch review and resource handoff.
C is still unmerged and unimported.

## 20 October policy clarification and Android follow-up

The decision ledger now records the human's actual policies 1/2 approval and
conditional cumulative merge authorization. Member policy 3 remains a named,
accepted Group People conversation with an unresolved history/lifetime choice;
it is not an unrestricted direct-message feature. The
[manual Android procedure](contact-android-manual-qa.md) uses the normal app and
fresh local OTP sign-in, explicitly separates manual observations from deterministic
driver/canonical evidence, and excludes hosted database and Play Store actions.

Read-only investigation of the earlier launch established a tool `CreateProcess`
rejection before PowerShell, with only `blocked by policy` and no narrower reason.
It did not establish an Android/AVD startup failure. The human now authorizes the
test; the same D-only launch must be reviewed after the full C resource handoff.
No executor, permission setting or peer device is substituted to bypass review.

The EN/IT member read-only notice now requires fresh consent conditionally for an
ended conversation; temporary Block does not falsely imply termination. New
production-screen regressions traverse temporary read-only, restored and ended
projections, retain authorized history and perform no domain mutation. The complete
member module passed 26 tests in the explicitly lent SDK-only window. The first
longer wording exceeded the existing Italian notice-scroll test's bounded search;
shorter copy passed the unchanged overlap/full-content/history/ACK assertions.
Localization generation, changed-test formatting and focused full-member analysis
(no issues, 44.3 seconds) also passed. The SDK was explicitly returned to C after
all owned analysis/test processes exited. No D backend,
fixture, emulator or APK build was started during this SDK-only window.

Current-head CI outcomes belong to the cumulative PR checks/comments. Historical
Validation 574 passed all jobs on `eed96e5d` (including 3,611 Mobile tests with two
existing skips), and does not qualify the later notice wording. Final native
qualification and the remaining policy 3 answer still gate cumulative merge.

## 20 October executed native attempts and focused repairs

The same reviewed D-only emulator launch executed successfully under the human's
authorization, without changing an executor or permission setting. Both `f355736a`
APKs built against seven verified D services and 112 migrations. The first D
attempt encountered a System UI ANR before submission; zero requests/receipts
were verified before reusing that fixture. A process-local 2 GiB/two-core launch
with a visually verified healthy launcher then passed nine D checkpoints,
including the real IME, committed-request recovery, acceptance and chat. It failed
at the first coordination Decline action while the canonical read still allowed
declining. Neither attempt is a completed native pass.

M passed every app assertion and teardown, saving 40 fresh PNGs, but its host
driver then exhausted heap while serializing the response and exited 1. This is
also not a complete native pass. Sanitized attempts are kept separately at
`C:/Users/utente/.planets/qa/d-contact-2026-10-20-native-f355736a`.

The focused repairs preserve authorization and the deliberate final lost-reply
assertions:

- Both host drivers retain the SDK's screenshot validation and PNG callback, then
  write bounded screenshot metadata rather than serializing a second copy of
  image bytes. Eight pure tests cover malformed data, early failure, preservation
  and a large byte list that must never be read or copied.
- The D journey explicitly settles ordinary known coordination receipts. An
  access refresh can keep an acknowledged claim frozen until the existing Recover
  action reconciles it. Real-screen EN/IT tests prove that recovery exposes
  Decline without repeating the claim; the final deliberate uncertain confirmation
  still requires its original UUID and one explicit recovery.
- Narrow EN/IT confirmation buttons use the existing compact Accept caption while
  preserving the full consent body and callback. Real glyph-bound tests at 320 dp
  and 2x text prove the caption fits. The Italian optional-note label is shorter.

All 80 scoped contact/coordination/member/driver tests passed together. Full Flutter
analysis passed with no issues in 75.6 seconds; localization generation, changed
Dart/document formatting and diff checks passed. Fresh fixtures, APKs and complete
driver exit-zero reruns remain required for these repairs. Historical Validation
575 passed every job on `f355736a`; final-head CI is recorded on the PR, without a
results-only source push.

The D AVD and seven label/workdir-verified containers were stopped after those
attempts, with volumes preserved and zero owned processes/listeners/devices. C
subsequently completed its native qualification and explicitly returned the full
SDK/runtime slot to D; its own machine is stopped. No global engine, WSL or device
configuration was changed. C now has eight forward migrations; 120 combined
migrations is only an integration preflight count, not evidence of qualification.
If C merges first, actual sorted clean replay, both populated lane orders, shared
API reconciliation and regenerated combined types remain required.

## Actual C merge integration in progress

C merged at `89292af4` after its complete Validation 577 passed. D now reconciles
that actual source. Both Group entry widgets, locale key/value sets, Messages
folders/cards, notification owners and exact moderation evidence loaders are
preserved. The additive combined unread reader and shared C signal/ACK ownership
are documented in [combined qualification](contact-discussion-integration.md).
The immutable source review found no concrete early report-constraint abort;
no already-merged C migration is rewritten on speculation.

The first 17 combined unread/ACK tests and full Flutter analysis passed (no issues,
76.2 seconds); 98 tooling tests and formatting of 859 Dart files passed. The
broader local Mobile run failed to start reliably when Windows exhausted process
memory; it is not a passing full test run or a demonstrated product test failure.
The owned D containers and machine are stopped, with volumes preserved. Another
PLANETS Android task is active outside the C/D resource agreement; its processes,
AVD and backend are untouched. A request to the human to authorize a serialized
resource handoff remains pending; no message to that task is inferred as allowed.

`verify-local-contact-discussion-upgrades.mjs` adds exact C-first and D-first
populated histories, mixed reports and unread/auth parity. Both histories,
full affected suites, fresh native builds/
drivers and final published-head CI remain pending. The
preceding standalone Validation 578 passed all jobs on `9ea6ca3f`; it does not
qualify this combined source. Policy 3 remains unresolved.

The database-only D follow-up actually applied all 121 combined migrations,
passed the nine new pgTAP API/security assertions, and regenerated the combined
types. All 371 public function names from D and all 368 from C remain present
among 432 combined RPC names. This incremental D-first application is not the
two populated histories or sorted clean replay. Only D's database was started;
it and the machine are stopped again, other services/AVD untouched.

The now-required C People action is implemented over a target-bound metadata
selector and the existing invitation command. C's source review identified four
concrete recovery/cache/context races; guards and regressions were added. The
cross-route notification fix now passes all ten new widget/domain regressions,
including connected/disconnected invalidation and deferred context changes.
The actual selector SQL suite passes 28 assertions, including pre-limit
authorization, manager independence, cursor bounds, exact metadata, pending
invitations, admission, Block/Unblock, membership loss, deleted profiles and
combined unread without an implicit ACK. The initial fixture attempted to delete
a profile referenced by retained Block audit; it now uses a separate unblocked
synthetic target and leaves the production foreign key unchanged. Together with
the nine API probes, 37 new pgTAP assertions passed. Broader analysis, full suites
and native completion remain separate gates. The member native fixture/journey now
also creates, explicitly joins and invites through a real C Idea, checking that
the pending invitation creates no personal request or room admission.

The opt-in Android workflow uses an ephemeral standard Linux runner with local
Supabase and synthetic accounts to avoid contention with unrelated Windows work.
Both fresh APKs build before booting its owned emulator, both complete drivers
must exit zero, and only fictional PNGs/compact metadata/scrubbed diagnostics are
retained. This workflow is prepared, not yet executed or qualified. Its label is
explicitly reapplied for each reviewed source head; ordinary pushes add no native
run. No hosted database or store action is included.

After the selector fixes, full Flutter analysis passed with no issues (5.8
seconds). Its initial analysis findings were confined to the new integration:
explicit mounted guards, braces and one redundant null assertion were corrected.
The ten selector tests passed before those lint-only/control-flow guard edits;
the complete published-head Mobile job remains required.

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
