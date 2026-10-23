# COCREATE-RUNALL progress

Current task: [DEPLOY01 integration and review](cocreate-deploy01.md), on the
existing isolated `codex/cocreate-fill01` branch and draft PR #297. The user has
authorized one cumulative main-targeted review of RUNALL, VIS01 and COMM01/FILL01.
Main `667bf57b` is reconciled; refreshed qualification is in progress. Exact-head
owner SQL review and green required CI remain prerequisites to merge. DEPLOY02
is deferred until the reviewed integration merges; no hosted operation is authorized
by DEPLOY01. [COMM01/FILL01](cocreate-fill01.md) records historical qualification.
The RUNALL ledger below records its original scope.

Authority: [RUNALL pack](../../history-implementations/PLANETS_COCREATE_RUNALL_autonomous_implementation.md).
Pre-programme base: `675bc592`. Latest integrated main: `217ce73e`
(fetched 2026-10-22; final docs-only reconciliation `a2da724a`).
Integration branch: `codex/cocreate-runall`. Managed worktree:
`C:/Users/utente/.codex/worktrees/cocreate-runall/planets.community`.
One cumulative draft PR; automatic merge prohibited. No hosted migration,
deployment, store upload or external delivery authorized/performed.

## Stage ledger

| Stage | State    | Dependency      | Evidence / next action                                                                                                                                                           |
| ----- | -------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A00   | verified | base            | Implemented and inspected. 287 affected tests pass, eight rendered combinations pass, Flutter analysis and all-file formatting pass. Android debug APK build passed.             |
| A01   | verified | A00             | Experimental contract, strict typed identities and default-OFF private server gate added. Fresh replay, negative authorization and genuine OTP/concurrency qualification passed. |
| B01   | verified | A01             | Posts, consent/contact backend and negative/concurrency qualification.                                                                                                           |
| B02   | verified | B01             | Live mobile Posts/Requests/accepted-contact Messages.                                                                                                                            |
| C01   | verified | A01             | Independent hub membership and General backend.                                                                                                                                  |
| C02   | verified | C01             | Live communities and General UI.                                                                                                                                                 |
| C03   | verified | C01             | Atomic numbered groups, history, hub-exit cascade.                                                                                                                               |
| C04   | verified | C02/C03         | Live numbered groups and versioned Messages integration; local UI/DB/build checks passed.                                                                                        |
| D01   | verified | C03/C04         | Structured General cards, canonical capacity-aware admission; fresh DB/Auth/UI/build qualification passed.                                                                       |
| D02   | verified | B/C             | Explicit source links and ordinary native personal drafts; local DB/Auth/UI/native regression/build qualified.                                                                   |
| D03   | verified | B/C             | Actual ACTAPI01 reviewed handoff and deterministic filters; fresh DB/Auth/UI/build qualified.                                                                                    |
| Q00   | partial  | eligible stages | Eligible implementation/local qualification complete in dc188691; exact owner migration review blocks final GitHub jobs.                                                         |

Current handoff: [draft PR #287](https://github.com/lillo24/planets.community/pull/287).
All eligible implementation is committed and locally qualified. The final
checkpoint below owns current status; earlier checkpoints are historical.
Next action is the repository owner's exact-content migration review, followed
by the existing CI gate/rehearsal and area jobs. Keep the PR draft/unmerged and
both experiment switches OFF until separately reviewed. No deployment follows
from this handoff.

## Initial isolation and evidence (historical)

- Primary checkout was clean on local main `b313b48f`; fetch updated only
  origin/main. No checkout reset, stash, deletion or other worktree mutation.
- Existing ACTAPI01 (`codex/actapi01-official-activities`), ACTMET01
  (`codex/actmet01-activity-interest`), MYHUB01 and TUT07 worktrees preserved.
- Open PRs inspected. ACTAPI01 #274 is a source-rights checkpoint, not an
  implemented model/routes integration. Its optional D03 handoff is unavailable
  on this base; core discovery remains eligible.
- Pinned `npm ci --ignore-scripts` and `flutter pub get` succeeded; no dependency
  upgrade. Flutter analysis initially found four interpolation lint infos;
  implementation repaired; rerun pending.
- Initial A00 run passed preference, composer account clearing, Home precedence
  and setting failure/retry tests. Eight rendered journey cases failed because
  the test selected multiple Scrollables; fix uses the active ListView only.
  This is not a live backend test.
- Existing three Podman machines are stopped and untouched. Creating an owned
  `planets-cocreate-qa` machine for disposable local testing; never reset an
  existing PLANETS database or use hosted credentials.

## Initial A00 checkpoint (historical; use latest checkpoint below)

Current action: rerun corrected A00 tests; extend actual-router/bootstrap
coverage, inspect EN/IT 320dp 2x captures, run analysis/build and inspect diff.
Then commit A00 and its ledger evidence, push and open cumulative draft PR.
Continue A01 → B01 → B02 → C01 → C02 → C03 → C04 → D01 → D02 → D03 → Q00.
Do not stop at A00. Preserve the explicit experimental defaults in RUNALL;
unimplemented live features must never be reported as verified.

## A00 qualification checkpoint

- Passed: flutter gen-l10n; flutter analyze --no-pub (no issues); dart format --output=none --set-exit-if-changed lib test test_support (838 files unchanged).
- Passed: flutter test --no-pub --concurrency=1 test/features/co_creation test/features/settings test/bootstrap test/app/router test/app/startup test/features/activities_sandbox: **287 tests**. Includes actual router/native routes, startup/tutorial/deep-link/protected-draft regressions and new mode tests.
- Separately passed: eight EN/IT, light/dark, 320dp 1x/2x rendered navigation cases plus composer account invalidation, precedence and save/retry (11 tests). Captures: .local/cocreate-renders/. Italian hub and English dark Posts 2x visually inspected. Native-device review unrun.
- Running: flutter build apk --debug --no-pub. Do not claim build success until completion.
- Tooling limitation: documented Dart/Flutter marketplace add reports an existing marketplace from another source; plugin add says plugin not found. Existing marketplace preserved. Installed Flutter/Dart CLI tests and analysis work.
- Local DB startup: first attempt followed the unrelated default Podman connection despite DOCKER_HOST; inspection failed without mutation. Retried with process-only CONTAINER_CONNECTION=planets-cocreate-qa-root and owned pipe. Images downloading; no existing machine/database reset or global default change.
- Next: commit tested A00, push cumulative draft PR; finish A01 gate replay/tests then continue B01 and independent C01. A00-only stop restriction is superseded.

## A01 / B01 resumable checkpoint

- Cumulative draft PR: https://github.com/lillo24/planets.community/pull/287. A00 commit: 230727e5; pushed. Automatic merge remains prohibited.
- A00 Android debug APK build passed (358 seconds). Artifact: apps/mobile/build/app/outputs/flutter-apk/app-debug.apk; no installation/store action.
- A01: experimental contract and access matrix added; strict canonical PostId/HubId/NumberedGroupId parsing and separate route builders pass **8 tests**; Flutter analysis passes. Private server gate defaults OFF, checks existing policy acceptance and live account restrictions; pgTAP includes direct-call grants, missing config, ban/deletion, wrong identity, incomplete profile and protected own-exit. SQL replay/tests are **not yet run** while local images download.
- Owned local machine is planets-cocreate-qa, root connection planets-cocreate-qa-root, pipe npipe:////./pipe/podman-planets-cocreate-qa. Three pre-existing machines remain stopped and untouched. The CLI startup (exec session 40023) is downloading images; do not launch a second stack.
- B01 source work has begun in 20261021195841_cocreate_posts_contacts.sql (uncommitted/incomplete). It is not qualified or a completed stage. Complete scoped moderation/report evidence and blocking serialization, add negative/idempotency/concurrency tests, replay and generate exact public types before claiming verification. Never activate live UI against incomplete backend paths.
- Current next action: finish A01 DB replay/pgTAP when startup completes; continue B01 and independent C01. B02/C02 need real tested domain contracts. No live two-account journey is claimed.

## B01 source checkpoint (not backend-qualified)

- Added canonical post CRUD/public discovery, author-only management, private interest transitions, accepted bilateral contacts, human messages/read receipts, private grants, canonical blocking composition and exact typed moderation evidence. Source: 20261021195841_cocreate_posts_contacts.sql.
- Added 150_cocreate_posts_contacts.test.sql and genuine-OTP/concurrency verifier scripts/verify-local-cocreate-posts.mjs. Node syntax, scoped Prettier and diff checks pass. **These database/Auth tests have not run yet**; do not activate a live UI or mark B01 verified.
- The local ECR image download was exceptionally slow. Only the identified startup process from this worktree was stopped, then retried with process-only SUPABASE_INTERNAL_IMAGE_REGISTRY=ghcr.io and unchanged pinned image versions. Owned startup now runs in exec session 79200. No pre-existing machine or global Podman setting changed.
- GitHub reports PR #287 CONFLICTING with newer main; Actions is enabled/Validation active, but this conflicting PR has no workflow runs. Next action: fetch and inspect actual newer main, checkpoint this source commit, reconcile only already-merged main, run scope checks and DB qualification, generate exact public types and push the cumulative branch. Do not incorporate another open PR as a shortcut.
- Remaining stages B02/C01/C02/C03/C04/D01/D02/D03/Q00 are still pending, not silently omitted or claimed complete.

## Main integration and CI checkpoint

- Already-merged MYHUB01 main 037eba7f integrated at a489e72f; only conflict was adjacent test imports, both sides retained. No open ACTAPI01/ACTMET01 PR copied or changed.
- After integration, **191 affected mobile tests passed** (co-creation, Settings, bootstrap, actual router, draft hub, owner cover cache). Earlier 287-test startup/tutorial run and debug APK pass remain evidence for the pre-integration source; final CI/build must qualify the integrated head.
- B01 source commit: 2527dc77. Added standard cocreate:posts:verify:local and included it in the existing Database job/full check:db with explicit disposable opt-in. 118 tooling tests, Node syntax, scoped formatting and diff checks pass. The genuine backend/concurrency verifier is still NOT RUN locally.
- Next: push reconciled source, check classified CI, finish local image startup; replay/lint/pgTAP B01 and A01, fix concrete errors, run genuine Auth/concurrency verifier and generate public types with the repository command. CI type-drift check must remain intact; generated types have not yet been refreshed.

## Current resumable checkpoint

- Source commits: A00 230727e5; A01 bed2c75c; B01 2527dc77; merged current main 037eba7f at a489e72f; disposable CI integration d878dc82. PR #287 remains draft and unmerged.
- Integrated Android debug APK build passed again (39.8s). Integrated Flutter analysis and all-file formatting passed (845 files unchanged). Four additional Home EN/IT light/dark 320x480 2x tests pass; captures visually inspected and saved under docs/development/evidence/cocreate/.
- Follow-up source review fixed staff moderation usability: case evidence now includes separate current post version/suppression metadata so scoped CAS actions need no guessed version or room-browse grant. The verifier covers suppression/ACK denial and restoration. This follow-up has Node syntax/format/diff validation; actual SQL qualification remains pending.
- Classified CI run **39668948597** on d878dc82: Web and Site passed; Mobile and Database still running when checkpointed. Database is traversing required populated predecessor upgrades. Do not treat this as final-source CI or a completed B01 verifier. No approval control has been bypassed.
- Local startup session **79200** still pulls pinned official GHCR images. Check only the owned planets-cocreate-qa engine using the two documented process env vars. Existing engines remain untouched. It may apply migrations after downloads; if startup fails, diagnose its exact SQL output and replay only this disposable stack after correction.
- Precise next action: finish current CI/local startup, inspect first database error, repair implementation, run 149/150 pgTAP plus genuine Auth/concurrency verifier, then repository lint/advisors/types and populated actual-base upgrade qualification. Refresh apps/web/src/types/database.generated.ts using the repository generator, never guessed definitions. Commit/push repairs, update PR and ledger, then implement B02 and independent C01, followed by C02/C03/C04/D01/D02/D03/Q00. The programme is **not complete**; no remaining stage is silently considered done.

## Qualification failure, implementation repair and B02 independent foundation

- CI 39668948597 on d878dc82 finished: Mobile/Web/Site **passed**. Database fresh replay, lint, advisors and both new co-creation pgTAP files passed, but the complete suite failed **1 of 6,661 assertions** in 160 files: existing 140_member_contact.test.sql assertion 1 protects the canonical Block delegation/body and lock sequence. No test was edited or weakened.
- Root cause: the B01 wrapper preserved runtime order but hid the direct member-contact delegation from the canonical function. Repair now appends a private co-creation cleanup call to the effective existing body in place, with source-shape checks and explicit OID/ACL preservation. The existing direct predecessor call, complete sorted Group reservation and member loop remain unchanged. This repair still requires replay/regression qualification.
- B02 independent work: strict public post/availability parser and read-only gateway added, with exact keys, typed identities, absolute date validation, cursor order/duplicate checks, exact-ID checks and error propagation. Four gateway tests pass; all 27 co-creation tests passed during development. Flutter analysis passes after two brace-style infos were corrected. Live Posts/composer/Requests/Messages UI is still pending; no mock-to-live substitution or authenticated write is wired.
- Latest committed checkpoint before this repair: 4c5398d6. Next action: commit/push this repair and the tested B02 foundation; rerun CI on the repaired source. Finish owned local startup, run DB security tests + genuine Auth/concurrency verifier + generated types, then complete B02 and C01 independently as allowed. The first failed CI never reached the genuine co-creation verifier/type generation; those remain NOT RUN.

## Resume here — latest execution checkpoint

- All implementation code is pushed through **036baf99** on cumulative draft PR **#287**. Canonical Block repair is **89369949**; B02 strict read foundation is **036baf99**. The worktree remains attached and must be retained for continuation. Only task-owned .local render/download diagnostics are untracked.
- Current qualifying CI run: **39671643976**, https://github.com/lillo24/planets.community/actions/runs/39671643976, on 036baf99. It is running; do not claim the repaired DB gate passed. A superseded same-head run was automatically cancelled. Avoid restarting this run for documentation-only checkpoint updates.
- Current stage states: A00 verified; A01/B01 implemented_unverified overall (their own pgTAP passed in prior CI, but the repaired full gate/types/Auth concurrency remain pending); B02 partial (read parsing/gateway only); C01/C02/C03/C04/D01/D02/D03/Q00 pending. No live mobile author/requester journey is implemented or claimed. No stage is blocked by missing phone/provider review.
- Latest local checks: all 27 co-creation tests passed; the four gateway tests passed again after strict impossible-date/time-zone rejection was added; Flutter analysis is clean. Integrated Android debug APK built successfully. Earlier 191 integration tests and 118 tooling tests passed. Initial full CI Mobile/Web/Site passed; Database failed the one preserved native Block assertion, which now has an implementation repair pending verification.
- Precise next action: inspect CI 39671643976; fix implementation if it reports another concrete error, without weakening 140_member_contact or other tests. Owned local startup remains session 79200; set CONTAINER_CONNECTION=planets-cocreate-qa-root and DOCKER_HOST=npipe:////./pipe/podman-planets-cocreate-qa before any CLI operation. SUPABASE_INTERNAL_IMAGE_REGISTRY=ghcr.io keeps the same pins. Check existing owned containers/startup before starting a duplicate. Once ready, run npm run db:test, db:lint, db:advisors, cocreate:posts:verify:local and db:types; inspect generated-type changes and run affected checks. Add/run a populated upgrade rehearsal from the actual pre-programme base. Keep activation OFF after every verifier.
- Then finish B02 live Posts/author/requester/accepted-contact Messages and its account/retry/access invalidation tests; implement independent C01 and continue C02 -> C03 -> C04 -> D01 -> D02 -> D03 -> Q00. ACTAPI01 remains an optional unavailable handoff, never a global blocker. No production deployment, hosted migration, automatic main merge, external delivery or unrelated cleanup was performed.
- This last documentation-only checkpoint is committed locally while code CI runs, so it does not cancel/repeat the expensive unchanged-source validation. Push it with the next implementation/type/qualification result. The programme remains incomplete and is not merge-ready.

## Resumed qualification and type repair (2026-10-22)

- Resumed the existing integration worktree/branch and draft PR #287. Initial inspection found no tracked edits, one unpushed documentation checkpoint (3aef4776), and only task-owned .local diagnostics. Other agents’ worktrees were preserved.
- CI 39671643976 completed with the repaired native Block regression and 72 genuine co-creation assertions passing; its final failure was the generated public type diff.
- Ran the established npm run db:types against the owned disposable planets-cocreate-qa backend; generated 120 additive lines in apps/web/src/types/database.generated.ts. No hand-edited definitions or CLI upgrades.
- Local checks passed: npm run db:test (160 files / 6,661 assertions), npm run cocreate:posts:verify:local (72 assertions, activation restored OFF), npm run db:lint (no schema errors), npm run db:advisors (no issues). A01 and B01 are now backend-qualified. Final populated actual-base upgrade and integrated programme Q00 remain required.
- B02 implementation continues in uncommitted mobile source: strict own-post/interest/contact parsers, paged gateways, immutable command retry, live Posts/compose/My posts/Requests/contact UI. These new UI changes are not yet qualified; do not claim B02 complete.
- Precise next action: commit the generated type repair, verify generation is clean, then complete and test B02 UI/account/policy/retry/access invalidation and Messages projections; continue C01 through Q00. PR remains draft/unmerged; no hosted operation or deployment.

## B02 implementation and qualification (2026-10-22)

- Added live Posts discovery/detail, curated topic/locality/text filters, bounded paging, private draft create/edit, deliberate publish/renew/close, My posts, Interested consent, withdrawal and author acceptance/decline. Explicit /people/demo remains separate; disabled/error never substitutes fixtures.
- Added closed private parsers, typed rows in existing Messages Private/Requests, complete server unread composition, shared actor-only invalidation, chronological contact paging and rendered-viewport ACK. Commands retain a deeply frozen actor/UUID/intent across ambiguous delivery; other operations cannot repurpose an uncertain command. Input survives auth/policy return without automatic submission and clears on established account change.
- Added exact Auth-only close/withdraw routes plus bounded own-anchor exit readers for gate-OFF/outdated-policy recovery. These expose no transcript, note, roster or source title and cannot grant admission/send. The actual router tests cover incomplete/unaccepted accounts with Sandbox OFF.
- Added B02 migration 20261022080000, versioned private title projections and 151 projection/security tests. Existing B01 readers keep their shape. The two reviewed metadata-only Auth hooks have exact event/column/function assertions; no INSERT/BEFORE hooks or profile creation were allowed. Native Block tests remain unchanged.
- Passed fresh disposable replay and complete pgTAP: 161 files / 6,711 assertions. The final additive identity-only interest-exit reader was then applied from the exact migration source to that owned local revision; all 22 targeted projection/exit assertions passed, including suppressed/gate-OFF withdrawal. Final integrated fresh/actual-base upgrade is still Q00 work.
- Passed again: lint (no schema errors), security advisors (no issues), genuine OTP/concurrency post-contact verifier (72 assertions, activation restored OFF), standard exact type generation. Types-only repair f74f1196 was pushed and db:types:check passed. New B02 public RPC types are generated, never guessed.
- Mobile regression batch: 306 tests passed; one newly edited flow file failed to compile because two fixture routes were placed in the wrong call. Corrected the test wiring, then all 20 focused flow/actual-router/parser/retry/unread tests passed. The earlier compact native Messages failure was fixed by placing the additive section after native rows. Final Flutter analysis passes with no issues.
- EN/IT 320dp 2x component captures saved under docs/development/evidence/cocreate; Italian inspected. They are deterministic contract-fixture renders, not a claimed live-phone session. Android debug build is running; confirm completion before calling B02 fully qualified.
- New main f938e017 contains already-merged profile/mock/release work; PR #287 is CONFLICTING and the f74f1196 push therefore has no new CI. Preserve those changes, checkpoint B02, merge actual origin/main on this same integration branch, resolve only actual conflicts and requalify. Do not deploy release work or merge PR #287.
- Precise next action: finish the debug build and commit tested B02, reconcile main, then implement independent C01 (curated hubs/General episodes, scoped moderation and frozen history) and continue C02 -> C03 -> C04 -> D01 -> D02 -> D03 -> Q00 without routine confirmation. The programme remains incomplete.

## B02 qualified checkpoint / C01 begins

- Android debug APK built successfully (172.2s); no installation, store action or deployment. The final mobile analysis is clean and all 20 focused flow/actual-router/parser/retry/unread tests pass. The 306-test native/regression batch passed all loaded tests; its sole new flow-file compile failure was repaired and that entire file passed in the focused rerun. No native regression test was weakened.
- B02 is implemented and change-scoped verified. Final cumulative CI, integrated main and actual-base upgrade remain programme/Q00 gates, not a claim of merge readiness.
- C01 backend source has started in uncommitted 20261022090000_cocreate_hubs_general.sql: independent curated hub/General tables, explicit admission episodes, sequence-frozen exit, HMAC page ACK and a private atomic child-exit extension point. It is incomplete, NOT applied or qualified. Do not activate its public routes until grants, scoped reports/moderation, invalidation, lists, fixtures and negative/concurrency tests are complete.
- Next: commit B02 separately, reconcile origin/main f938e017 on the existing branch and preserve profile/mock/release changes; then complete and qualify C01 and continue the entire remaining programme. All other worktrees and ACTAPI01/ACTMET01 remain untouched.

## Main reconciliation checkpoint

- B02 committed as b7e3f047. Merging already-merged main f938e017 preserves profile avatars, isolated mock realms, release safeguards and the new notification claim fix. Resolved five actual conflicts (router, bootstrap, Settings and EN/IT). Both Sandbox switches and main’s Mock controls remain; co-creation preference restores in both normal and rebuilt realm roots. No release/hosted command was run.
- Integration inspection found B02 translation names collided with native Project People names. All co-creation references now use coPeople-prefixed keys. A structural check preserved every current-main native translation exactly (2,579 EN / 2,322 IT keys). This repair corrects an implementation mistake; no native product copy is intentionally changed.
- Integrated affected mobile tests: 230 passed across co-creation, Settings, bootstrap, actual router and Mock. The command also named a non-existent test/features/project_people directory and therefore exited nonzero; reran the actual participation Project People files: all 57 tests passed. Analysis had no issues before the final bootstrap/realm preference wiring; final analysis is running.
- C01 migration now has candidate General/membership/history/mute/read/unread, own-exit projection, actor-only invalidation, scoped reported-message evidence and staff lifecycle operations, plus 152 negative/security tests. Fresh replay including actual newer main and C01 has reached restart successfully; full database tests are running. C01 remains uncommitted and unverified until its actual Auth/concurrency verifier, lint/advisors and generated types pass.
- Next: finish main merge commit and push the reconciled cumulative branch (without C01 WIP); complete C01 qualification and continue C02/C03/C04/D01/D02/D03/Q00.

## C01 backend qualification checkpoint

- Implemented independent curated hubs/General, explicit membership episodes, earlier active history, frozen exit snapshots, mute, complete canonical Groups unread, strict HMAC read boundaries, bounded People, actor-only invalidation, exact report evidence and scoped staff lifecycle/removal/reversal. Private child-exit extension is explicit and remains to be completed in C03. No hub curator gets room oversight; no native Group/Project memberships or permissions change.
- Fresh replay including actual newer main passed all 163 pgTAP files / 7,113 assertions. Added two metadata checks afterward; final C01 targeted suite passes 240 assertions. Final genuine OTP/concurrency verifier passes 77 assertions, including duplicate admission/send, send-vs-exit, old receipts, rejoin, staff without membership, suppression, bans, shared blocking and exact synthetic erasure. B01 genuine verifier passes all 72 again with C01 installed. Gate restored OFF.
- Repaired two lint-only source issues (unused People variable and child-extension parameters). Applied exact revised function definitions only to the owned local revision; final db:lint reports no schema errors and security advisors no issues. Public types generated by npm run db:types (113 additive C01 lines). Full integrated/actual-base upgrade remains Q00.
- Qualification harness repairs: synthetic erasure now follows repository test 145 (profile before Auth, exact email guard); repeat verification asserts the known earlier message rather than assuming an empty persistent fixture room; SQL fixture selection uses only its exact IDs; metadata assertion accepts only the pinned transport delivery UUID plus recipient ID, matching existing member-contact tests. No authorization test was loosened to hide a product failure.
- 145 tooling tests pass after adding the bundled Python directory to process PATH; the first run hit the Windows Store python alias (9009). No global Python setting or dependency version changed. Node syntax, scoped Prettier and diff checks pass. New CI verifier retains explicit disposable opt-in and original workflow triggers/required checks.
- Main integration mobile tests passed 230 affected plus 57 native Project People tests; final integrated analysis has no issues. CI 39750325726 on pushed 5d8cf6a9 is running: Web/Site passed, Mobile/Database pending at checkpoint. This is B02/main CI, not a claim that unpushed C01 was qualified by GitHub.
- Precise next action: commit/push C01 and generated types, then implement C02 live Communities/General and Messages Groups UI using the canonical episode identity. Continue C03, C04, D01, D02, D03 and Q00; do not stop after this stage. PR #287 stays draft/unmerged, with no production/hosted/store action.

## C02 qualified checkpoint (continue C03)

- Added live Communities browse/filter/detail, explicit history/audience disclosure and join, canonical membership reread, General, member-only People, mute and warned Auth-only hub leave. Existing Messages Groups has one latest-episode General with topic/locality/unread/frozen history; mode OFF cannot trap members. No new inbox/tab or native audience change.
- Strict gateway/parser binds actor/hub/room/episode, rejects cross-scope receipts, duplicate canonical rooms and malformed cursors. Small shared command interface retains frozen exact attempts. General reuses native lazy history and rendered-viewport visibility/retry logic through an episode-bound ACK adapter. Preview and People never ACK.
- New read-only context migration 20261022100000 applied on the populated C01 owned backend; all 8 context/auth assertions pass, including wrong hub, prejoin, retired frozen history and disabled gate. Lint/advisors clean; 9 generated public type lines use the standard generator. Final fresh and pre-programme upgrade remain Q00.
- Initial broad mobile run passed 392 tests with one native avatar-at-bottom layout failure. Fixed availability mounting; native harness now explicitly models server default-OFF and empty own-exit records (unexpected calls still throw). Repaired focused Messages/co-creation batch: 120 tests passed. Includes 14 new strict/flow/actual-exit cases and same-actor episode invalidation. All 4 report contract tests pass; foreign context is rejected. Final Flutter analysis is clean; Android debug APK built (116.9s). Earlier unaffected tests from the broad run remain evidence, not a claim of an unrun all-green aggregate.
- Captured EN/IT 320dp 2x hub disclosure/auth component views, inspected Italian and saved evidence. These use deterministic contract fixtures; genuine OTP backend tests are separate. No native device/installation/store action.
- GitHub Validation 39752043508 on a441268b completed SUCCESS for classification, Site, Web, Mobile and Database. This qualifies the committed C01/main head, not as-yet-unpushed C02.
- Precise next action: commit/push tested C02 and generated types, then implement C03 stable numbered rooms/capacity/admission with the same hub lock, complete atomic child exits and orphan archival, and test last-seat races, old episodes, removal/rejoin, suppression and erasure compatibility. Continue C04 -> D01 -> D02 -> D03 -> Q00 without routine confirmation. No stage after C02 is silently complete. PR #287 remains draft/unmerged; no production/hosted/deployment action.

## C03 backend qualified / C04 next

- C02 is committed/pushed as 942f1f38. C03 adds stable transactional numbering, default-5 configurable 2–50 capacity including creator, explicit hub-before-group admission, separate episodes/People/chat, creator-only versioned management, removal barriers, frozen exits and scoped staff actions. Full groups remain live. Hub exit now atomically ends children and archives creator orphans; other hubs/native domains remain untouched.
- Permanent Auth erasure converges memberships through the existing exact metadata hooks without new profile creation, privilege changes or native retention edits. Temporary suspension denies access but preserves seats. Experimental server abuse limits: 50 active numbered memberships and 5 creations/rolling day, documented in cocreate-hubs.md.
- Fresh owned disposable replay and complete database suite PASS: 165 files / 7,268 assertions. Targeted numbered tests PASS 74. Genuine OTP/concurrency numbered verifier PASS 101; post/contact 72 and hubs 77 pass again. Last-seat and capacity races, concurrent numbering, stale receipts, frozen/rejoin boundaries, cross-room ACK, scoped reports, hub cascade and soft/physical erasure are covered. Native reported-subject deletion FK remains enforced; a separate unreported fixture qualifies physical deletion.
- Lint/advisors clean; generated public types use npm run db:types. Node syntax/scoped formatting/diff checks and 145 tooling tests pass (bundled Python on process PATH). Activation restored OFF. C03 source is qualified locally; cumulative CI/final actual-base upgrade remain programme gates.
- Precise next action: commit/push C03 with its types/evidence, then implement C04 canonical numbered summaries/create/join/manage/chat and versioned mixed Messages Groups, protected own-leave and account/episode invalidation. Continue D01 -> D02 -> D03 -> Q00. PR #287 remains draft/unmerged; no hosted/production/store operation.

## C04 implementation checkpoint

- C03 committed/pushed as 9ec5f033. C04 now implements numbered aggregate discovery/open-seat filter, explicit create with editable default-5 capacity, separate hub/group consent, canonical membership reread, numbered chat/People/settings, creator CAS capacity/removal/reversal/archive, mute and warned protected own leave. Existing Messages uses one versioned mixed General/numbered projection. No second inbox or client grant.
- Shared uncertain retry repair preserves the UUID of an exact unconfirmed intent after a later access/gate rejection. Eight new strict/recovery/creator/account/narrow EN/IT tests pass; an additional mixed-inbox test is qualifying. Co-creation/native Messages regression run passed all 128 tests before the final additional creator/mixed tests. Exact actual-router numbered leave works with Sandbox OFF and incomplete/unaccepted account.
- Additive creator-only removed-member reader applied on populated C03 backend; targeted security suite passes 78 assertions. Lint clean and exact public types regenerated. C04 analysis/debug build/captures are currently qualifying, not yet claimed complete.
- Fetched actual origin/main 97a215ca safely. It now includes merged ACTAPI01 8d9c3ac0; PR is conflicting again. Do not merge while C04 source is uncommitted. Finish C04 checks, commit, reconcile actual main on the same branch preserving ACTAPI01, regenerate integrated types and rerun affected tests before push. D03 must inspect actual merged model rather than assuming absent. ACTMET01 remains untouched.
- Next: finish C04 qualification/commit and main reconciliation, then D01 structured General recruitment, D02 explicit source links/personal native Project drafts, D03 real filters/conditional official-event handoff, Q00 integrated journey and actual-base upgrade. No production/hosted/auto-merge action.

## C04 qualified checkpoint / D01 begins

- Final additional numbered suite passes all 9 tests, including mixed inbox canonical-room deduplication, exact receipts, lost admission recovery, gate-rejection UUID retention, creator-only CAS management/removal and identity-change text disposal. Broad earlier 128-test co-creation/native Messages run passed. Actual router own numbered exit passes while mode OFF/incomplete/unaccepted. No admission/roster/transcript bypass.
- Flutter analysis is clean after fixing test-only brace infos. Android debug APK built successfully (30.6s), with no install/store action. EN/IT 320dp 2x disclosure/create captures saved; Italian visually inspected, scrollable content wraps without overflow. These are contract fixtures, not native-phone or live two-account UI evidence; genuine backend seat/cascade races remain the 101-assertion C03 verifier.
- C04 removal recovery migration is additive and upgraded the populated local C03 state. Targeted database assertions pass 78; lint clean, standard generated types updated. Final integrated fresh/actual-base qualification remains Q00. Preserve task-owned .local diagnostics.
- Precise next action: commit tested C04, merge only already-merged origin/main 97a215ca into this integration branch, resolve actual workflow/router/translation/type conflicts preserving ACTAPI01, regenerate public types and requalify affected source. Then implement D01 and continue D02/D03/Q00 without stopping for a stage report. C03/C04 PR CI is unavailable while this new main conflict persists. No production activation, hosted migration or automatic merge.

## Merged ACTAPI01 reconciliation

- C04 is 5af809c6. Main 97a215ca adds already-merged ACTAPI01 (8d9c3ac0), not another open agent's WIP. Resolved only three adjacent conflicts (EN/IT/package scripts), preserved every main translation exactly (2,606 EN / 2,349 IT), and retained both external-activity and co-creation CI commands. ACTMET01 untouched. The new staging automation is a plan document only; no staging command executed.
- Applied ACTAPI01's backdated additive migration on the owned local backend with migration up --local --include-all. All 154 targeted external/numbered security assertions pass; integrated public types regenerated with the standard command. The inherited external Auth verifier refused the owned stack because it uses API port 54321; its non-default-port guard was preserved, no CI impersonation/guard bypass attempted. That verifier remains a CI/non-default-port qualification item. External pgTAP and mobile contracts qualify independently.
- Integrated co-creation/external/router tests are running. Next: inspect their result, commit the merge and push once, then D01. The programme is incomplete; retain this worktree and draft PR.

## D01 source and qualification checkpoint

- Main reconciliation 13663ff8 is committed/pushed; all 156 affected co-creation/external/router mobile tests passed. CI 39761916941 has Web/Site/Mobile success and Database running at last inspection. It qualifies through C04, not uncommitted D01.
- D01 candidate source adds immutable structured General cards with private lifecycle, one active per room, exact command/card identity, creator-only posting/retraction, live availability, scoped exact review/report snapshots and a canonical C03 join wrapper with identical lock order. Explicit experimental expiry default is 7 days (1–30); existing per-room cooldown is 3,600 seconds. No mass push, automatic enrollment or automatic repost.
- Room v2 feed adds closed human/card variants and authorized sender names; legacy human-only shape and its newest-human token remain compatible. Human unread excludes cards. General seat/capacity/lifecycle metadata invalidation carries no body or child-chat activity. Mobile review is deliberate and retains exact lost-response retry after the card becomes full.
- Fresh replay succeeded. All preceding 166 database files passed; the new file initially had test-authoring errors (wrong immutable error code, wrong pgTAP assertion name, then a dollar-quote damaged by JavaScript replacement). Those were corrected without weakening the immutable assertion. Final targeted D01 file passes all 43 assertions; no claim yet of an all-green aggregate rerun. Genuine OTP/concurrency recruitment verifier passes 54 assertions, gate restored OFF. All 69 co-creation mobile tests pass. Final analysis, debug build, full regression verifiers/types/captures remain in progress.
- Exact next action: finish D01 analysis/build/lint/advisors/types and scoped render inspection; rerun the relevant previous co-creation verifiers and final fresh database aggregate, inspect source, commit/push D01 with evidence. Continue D02 explicit links/native personal drafts, D03 real ACTAPI01 public-reference handoff, Q00 integrated synthetic programme and actual-base upgrade. Do not restart completed stages or stop at D01.

## D01 qualified / continue D02

- Final fresh replay and complete database suite PASS: 167 files / 7,444 assertions. Final genuine OTP verifiers pass again: posts/contacts 72, hubs 77, numbered 101, recruitment 54. All restore activation OFF. The earlier new-test authoring errors are repaired; this is the final all-green aggregate.
- Lint and security advisors clean; exact public types regenerated through the standard command. All 164 tooling tests pass with process-only bundled Python PATH. All 69 co-creation mobile tests pass, including new strict structured payloads, explicit review/join, lost-full-state retry and expired EN/IT 320dp 2x views. Final Flutter analysis clean; Android debug APK built (25.3s). No phone installation or external action.
- Captures saved under docs/development/evidence/cocreate; Italian expired-card review inspected. It shows no join control and wraps without overflow. Sender attribution now comes from the admitted v2 projection; unavailable profiles have no displayed name. Contacts and legacy human report/page shapes are preserved.
- Exact next action: commit/push D01, then implement D02 reviewed post/group references and ordinary personal native Project drafts using the canonical editor creation contract. Do not copy private content/memberships or change native audiences. Continue D03 using the now-merged ACTAPI01 model, then Q00 integrated programme/actual-base upgrade/full final regression. Current cumulative PR remains draft and must not merge/deploy.

## D02 resumable source checkpoint (not qualified)

- D01 committed/pushed as d5ee7ee5. CI 39764223965 qualifies that head and is running; previous 39761916941 was cancelled by this implementation push after Mobile/Web/Site passed. Avoid documentation-only pushes that repeat the expensive unchanged-source database job.
- Candidate D02 migration 20261022140000 adds private post/group references, creator-only selectable groups, exact author/post CAS commands, accepted-contact consent options, idempotent ordinary personal native Project draft creation and public-native-read-gated published Project references. No private text, roster, capacity or location is copied into the native draft. Source correlation is private/minimal and cascades only with native proposal deletion; it creates no new native deletion restriction.
- Meaningful conservative experimental assumption: linking requires the post author also to be the current numbered-group creator. Clear/link is explicit and never joins anyone. An unavailable/archived source retains a non-actionable marker without current counts. Closed/withdrawn contacts get no continuing join option. Creator departure cannot lose an already-created personal draft receipt, but an old episode cannot create a new draft. Identity-only channel invalidation covers linked-source seats/lifecycle without child-chat messages.
- Candidate mobile source includes author reference management, current managed-group picker, accepted-contact review, deliberate existing group/hub admission even with Sandbox OFF, manager personal draft entry with the existing private editor return marker, and published-native links. Exact pending link/draft attempts remain recoverable when source state changes. These changes are NOT yet verified or committed.
- Current active qualification: session 90036 ran a bounded Dart brace fix (6 fixes in the new gateway only) and is running all co-creation tests; session 71009 resets only planets-cocreate-qa and runs new 156 source-link pgTAP. Inspect their actual outputs. A test-harness f/fixture typo and a test's mistaken private-location table column were corrected before the latest test run; no product security assertion removed. Source getter shapes were revised after the initial populated apply, so the current reset is needed to qualify the exact final candidate migration.
- Exact next action: inspect those two sessions/logs; repair source/test-authoring errors without weakening native behavior; add dedicated D02 strict/mobile lost-link/lost-draft/actor/consent tests and a genuine OTP/concurrency source-link verifier, run lint/advisors/types/build, inspect and commit D02. Then D03 real ACTAPI01 reference handoff/remaining deterministic filters, Q00 one integrated synthetic programme, actual pre-programme Git-base populated upgrade and final complete checks. Programme remains incomplete, draft PR unmerged, activation OFF except owned temporary verifiers.

## D02 qualified checkpoint / continue D03

- Candidate source is now qualified: fresh full database PASS 168 files / 7,573 assertions; final genuine OTP source-link/concurrent-CAS/native-draft verifier PASS 50, activation restored OFF. Lint/advisors clean and 51 public type lines generated with the standard command. Current auth contracts were preserved: an accepted request closes through the contact endpoint, rather than inventing accepted-interest withdrawal to satisfy the verifier.
- All 76 co-creation tests passed after the shared acknowledgement repair. Final dedicated source suite passes 8, adding native editor cancellation/back coverage afterward. All 149 affected native editor/gateway/registered-group/Message tests pass. Final Flutter analysis clean; Android debug APK built (29.1s). Source EN/IT 320dp 2x captures saved and Italian inspected; these are contract fixtures, not a live phone claim.
- Shared retry now distinguishes ambiguous delivery from acknowledged-but-unfinished UI completion. Both freeze the exact attempt; completion Retry uses its identifier-only receipt and performs no second write. Busy completion cannot duplicate navigation, and conditional cleanup cannot clear a different actor/attempt. A dedicated callback-failure test proves one write despite two UI completion attempts. New screens watch both pending states.
- D02 adds the documented conservative post-author/current-group-creator link rule, explicit source review and ordinary personal Project drafts. Source departure preserves already-created native ownership, while old episodes cannot start another draft. Unpublished drafts stay private; native public reads gate every published reference. Native cancellation, publication, blocking and retention rules are reused, never weakened. See cocreate-source-links.md.
- Exact next action: commit D02 after final formatting/tooling checks, keep the same integration branch/draft PR, then implement D03 using actual merged ACTAPI01 model/routes with a reviewed public event reference and explicit ordinary post draft, plus verify all deterministic filters/open-seat ordering. Then Q00 one integrated programme, populated actual Git-base upgrade and final full checks. Do not stop after this stage. No production/hosted/store/automatic merge action.

## D03 current source checkpoint (continue here)

- D02 is committed/pushed as 7eed52d9; draft PR #287 body/title now reflect the cumulative programme through D02 and explicitly pending D03/Q00. Complete GitHub Validation 39764223965 on D01 d5ee7ee5 is SUCCESS, including database generated types. D02's new run is separate; do not claim it passed before checking.
- D03 candidate migration 20261022150000 is applied to the owned local backend. New pgTAP 157 passes all 38 assertions: canonical ACTAPI01 rights/availability, explicit unpublished post draft, exact retry/changed intent, no native/event mutation or enrollment, minimal eight-field public reference, truthful cancellation/unavailable state, literal percent/underscore, filtered paired cursors and numeric open-seat paging before limit. Gate remains OFF outside rolled-back tests.
- Candidate mobile files: data/co_creation_events_gateway.dart, presentation/co_creation_event_screen.dart and co_creation_event_widgets.dart. They reuse the actual external activity domain/URL/schedule primitives, add an optional gated event-detail action, re-fetch before composer entry, prefill only editable title/broad city/generic intent, preserve auth/policy text without auto-submit, and expose a minimal public reference with attribution/license through the existing safe HTTPS launcher. Source save rechecks current availability; publication retains ordinary post rules and references truthfully disclose later cancellation/withdrawal.
- UI code is NOT qualified/committed yet. Analysis session 61866 completed with only 8 new brace-style infos, no compiler errors. Apply bounded brace fixes, add strict/event composer/auth-return/exact-retry/cancelled-source/EN-IT narrow tests, rerun co-creation plus external/native regressions and build, lint/advisors/generate types, then commit D03. Existing people-flow fixtures now explicitly return no event source rather than accidentally calling a real backend.
- The inherited ACTAPI01 genuine verifier requires a non-default task-owned API port; the existing owned engine currently exposes 54321. Preserve that guard. For full D03/Q00 live qualification, use the same owned planets-cocreate-qa engine with an available non-default API port (54821 proposed), journaling/restoring only the task's local config and preserving any existing edits. Keep DB/Mailpit ports compatible with existing local helpers. Do not impersonate CI or weaken the guard. No provider credentials or real source activation is required; canonical licensed synthetic fixtures suffice, clearly labelled.
- Q00 still needs one genuine integrated programme journey, fresh full checks and a populated upgrade from actual Git base 675bc592. Do not approximate that base via current migration --version: newer merged main has backdated avatar/ACTAPI01 migrations. Materialize the actual base's migration/config/seed sources in a task-owned .local directory, replay it only on the identified disposable backend, preserve synthetic native rows/ACLs/OIDs as appropriate, then upgrade current sources with --include-all and verify. Existing upgrade scripts provide guarded/journalled patterns. Keep activation OFF afterward and leave precise checkpoints before limits. No production, hosted migration, merge or deployment authorized.

### D03 latest work and owned QA port transition

- Existing co-creation/external regressions pass all 92 tests on the first D03 candidate. Dedicated new event tests initially passed 7/9; two test-authoring issues were a missing scroll before the auth action and a guessed unavailable label. Corrected scroll/explicit event-specific copy; rerun is session 89644. No authorization assertion weakened. A source-ID change test clears unsent text while the new context is pending. Canonical entity route keys now reset post/hub/group/source state on ID/episode changes.
- Public event references now echo the exact post ID in addition to their minimal eight event fields; the client rejects cross-post replies. This and the final index were edited after the initial local apply, so reapply via final fresh/upgrade replay before claiming the latest SQL qualified. The current 38 pgTAP pass belongs to the preceding source shape. Latest source tests expect the echo.
- QA port transition is starting only in owned engine planets-cocreate-qa-root / its documented pipe. Confirmed 54821 free and root config clean. Original config saved at .local/qa-api-overlay/config.original.toml, SHA256 2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6. Stop uses the normal backup-preserving command, not --no-backup. Then change only [api].port 54321 -> 54821 locally, record modified SHA, restart the same owned project and verify actual status before live tests. DB/Mailpit ports stay 54322/54324. Never stage/commit the temporary config. Restore original bytes only after checking the overlay hash; preserve any later edits. Other engines/worktrees remain untouched.

## D03 qualified / Q00 next — current checkpoint

- Owned stack restarted from its backup on API http://127.0.0.1:54821, DB 54322, Mailpit 54324. Actual status/SQL gate OFF verified. Journal state is active-api-54821; modified config SHA256 8dba1c0771395e4088bc4813d0ad87e720a07a5135870bbf751e94fe20bd5e06. The tracked supabase/config.toml API-only overlay must remain UNCOMMITTED and be restored safely after Q00. Other engines/defaults unchanged.
- Latest exact D03 source including post echo/index passed fresh full database: 169 files / 7,640 assertions. Genuine handoff verifier passes 38; inherited ACTAPI01 service/public verifier now PASSES on the proper non-default owned API, with its guard intact. Synthetic licensed fixtures only; no official feed fetched/configured. Both restore co-creation OFF and clean only their source.
- Final affected mobile/external/actual-router run passes all 178 tests; dedicated event suite 9 passes, including auth-return edit preservation, exact unpublished retry, source-ID pending-state clearing and EN/IT 320dp 2x. Analysis clean and Android debug APK built (48.0s). Narrow Italian context capture inspected. Lint/advisors clean; standard generator adds 14 public function lines. The first two dedicated failures were corrected test scrolling/copy assumptions; a mistakenly multi-path dart fix was corrected to separate bounded invocations.
- Complete GitHub Validation 39768046221 on D02 7eed52d9 is SUCCESS. This is not a CI claim for uncommitted D03. ACTMET01 remains open/unmodified; merged ACTAPI01 is reused, not duplicated.
- Exact next action: inspect/commit tested D03 with types/docs, explicitly excluding temporary supabase/config.toml and .local. Then implement/run Q00 single genuine integrated author/contact/hub/group/recruitment/race/history/removal/exit/report/native-draft journey and the populated actual-base upgrade. Verified actual base is 230727e5 parent = 675bc5929c79332d1f4dcaf3446780c3020ef214. Use immutable Git sources, not current --version cutoff. Existing combined-upgrade script shows pinned CLI discovery and safe redaction; prefer separate owned base source materialization to moving current tracked migrations.
- Finish complete validation (including required native domains, full mobile/web/site/tooling and GitHub final head), inspect native device availability without installing/disrupting personal apps, restore config overlay/gate OFF, finalize the draft PR/handoff. Phone/iOS/provider-owner activation remain explicitly unrun external items, not a global blocker. Continue without routine confirmation; no production/hosted/deployment/automatic merge action.

## Q00 active qualification checkpoint

- D03 is committed/pushed as 15180d53. CI 39777384536 stopped at the newly merged STAGING-AUTO01 owner migration-review control; Database/Mobile/Web/Site were skipped. This is an exact-content owner review requirement, not a test failure. Preserve the gate; prepare its review-required.json handoff without impersonating owner approval. Main advanced to a3ae3bfb and was merged cleanly as 1f98a56b, preserving the release controls and explicit closed-test Mock capability.
- The complete legacy upgrade suite additionally requires a genuinely named disposable project. Original planets-community was stopped WITH backup. Current owned project is planets-cocreate-runall-qa, API 54821 / DB 54322 / Mailpit 54324; healthy containers and SQL activation OFF verified. Exact opt-ins: PLANETS_DISPOSABLE_QA=1 and PLANETS_UPGRADE_QA_PROJECT=planets-cocreate-runall-qa, alongside the existing owned engine/pipe. No CI impersonation. Temporary config SHA256 242091c90891b9f290e02655142f371bebd63af535efc0867bba50e21f60608f is journaled in .local/qa-api-overlay/journal.json. Never commit it; check that hash before restoring saved original bytes.
- Running complete database command: session 91781, .local/q00-full-db.log (serial predecessor resets; do not run another DB mutation until finished). Full mobile session 48420, .local/q00-full-mobile.log. Site session 86892, .local/q00-site.log. Candidate Q00 integrated OTP/retained-socket journey and exact Git-base populated-upgrade scripts are written but NOT yet qualified. The latter materializes immutable base sources under .local, avoiding any working migration-directory moves.
- Precise next action: inspect active check results, repair actual failures, then run the new integrated journey and actual-base upgrade serially on the named disposable backend. Qualify scoped new pgTAP on populated upgrade, run final tooling/web/build evidence, restore gate/config safely, commit Q00 and update draft PR. No new branch, merge, hosted/staging migration, deployment or device installation.

- Qualification update: complete Site and Web commands PASS. Web: 181 tooling tests, 401 app tests with 2 existing skips, lint/typecheck/production build/static-invitation check. Site tests/lint/typecheck/build/deploy dry-run pass; nothing published. Full mobile formatting/l10n/analysis pass; default-concurrency test run completed 4,072 passes / 2 existing skips / 1 existing Resource reconnect timing failure (250 ms sleep). Exact isolated file now passes all 16 tests unchanged. Session 66459 is rerunning the COMPLETE mobile suite with --concurrency=1, then Android debug build; logs .local/q00-mobile-serial.log / q00-android-build.log. Do not claim full mobile aggregate green until this finishes.
- Complete DB session 91781 remains active and has passed populated member-contact, group-contact, coordination, participation-conversation, unread and native persistent-group upgrades; membership upgrade is running. Do not start the Q00 reset/programme concurrently. Owned API remains 54821 and config overlay untouched. `adb devices -l` found no attached device; iOS/device/install QA unrun.
- Q00 source inspection found a narrow D02 signal gap: closed accepted contacts still received linked-source capacity/lifecycle hints. Additive migration 20261022160000 filters those recipients; the genuine retained-socket journey asserts no later capacity/body/activity hint after both closure and hub exit. Its source and the exact-base upgrade script remain unqualified until DB is free. Pinned CLI supports all used workdir/db-url/include-all flags. Exact base contains 123 migrations, verified from Git; do not use a guessed timestamp cutoff.

### Q00 complete replay / live verification checkpoint

- All eleven predecessor upgrade checks now PASS, including exact C-first (135 table snapshots / 4 warmed function identities) and D-first (147 / 5), mixed C/D/M cases, grants, result shapes and repeat application. Temporary migration files restored; manifests Vxie7w and MKyNuM are under the task's OS temp planets-cd-migration-set folders if recovery is ever needed.
- Fresh replay INCLUDING 20261022160000, lint/advisors and complete pgTAP PASS: 169 files / 7,640 assertions. ACTAPI synthetic service/public verifier passes again. Session 91781 then stopped at MAP01's explicit missing MAILPIT_URL setup assertion, before a product action. Preserve the guard. Resumed with MAILPIT_URL=http://127.0.0.1:54324 in session 51263, .local/q00-db-remainder.log, from location:verify:local onward using the registered check:db components. Location/basemap's measured 100-session control and synthetic provider checks, push protocol, Auth/session/policy/profile/photos/cover and public proposal verifiers have now passed. No credential/provider activated or delivery performed.
- Do not claim the single original check:db command exited green: it was resumed at the exact setup boundary. Inspect remainder log for 'Q00 remainder stopped at' and each final component result, since the first PowerShell resume wrapper has a child-scope exit-code limitation. Future wrappers should dot-source the loop or capture the actual failing code outside it. No test/assertion was weakened.
- Serial complete mobile session 66459 is near the end with no failures; debug APK follows automatically only on success. Web/Site remain fully qualified. Current draft PR body now reflects committed D03 and active Q00/owner-review blocker; no Q00 candidate source is claimed committed.
- Next: finish remainder (including new continuous programme), repair precise failures, then run actual-base upgrade script and scoped 149–157 pgTAP plus programme on populated upgrade. Finally restore gate/config with hash check, inspect/commit Q00 source, update final progress/PR and exact owner review artifact. Continue; no branch/main merge, hosted operation or phone install.

- Final mobile aggregate is now PASS: `flutter test --no-pub --concurrency=1` completed 4,073 tests / 2 existing opt-in local-backend smoke skips in 19m54s. The unchanged Resource reconnect test passes in this complete run as well as its isolated 16-test file. `flutter build apk --debug --no-pub` then PASS (115.8s); no install/submission. The initial concurrent aggregate's one timing-sensitive failure remains recorded above. L10n/format/analyze and complete Web/Site results remain qualified. Database remainder 51263 is still active through native participation/People concurrency; no reset until it finishes.

## Q00 final local qualification / owner-review handoff

- Implementation commit: `dc188691` (closed accepted-contact source hints, continuous journey, actual-base upgrade and runbooks). Main through `217ce73e` is integrated on this same branch; its last change is only the separate STAGING-AUTO02 plan document. That plan was not executed. ACTAPI01's merged model is reused; ACTMET01 and other agents' unmerged work remain untouched.
- Every registered `check:db` component completed successfully across the recorded resumed runs. All eleven predecessor upgrade checks passed, then clean replay, lint/advisors and **169 files / 7,640 pgTAP assertions**. The first command stopped only at MAP01's missing explicit mailbox URL; resumed with the real loopback `MAILPIT_URL`. The initial continuous verifier's transport-readiness assertion was diagnosed and repaired before continuing from participation conversations. Final tail session 41070 exited zero, including global notification/demo/native Group checks and `db:types:check`. Logs: q00-full-db.log, q00-db-remainder.log, q00-programme-repair2.log and q00-db-tail.log under `.local`.
- All six genuine co-creation OTP verifiers pass: posts/contacts **72**, hubs **77**, numbered **101**, recruitment **54**, source links **50**, reviewed event handoff **38**. No official feed was fetched. Continuous fresh-schema journey passed **136** assertions; final strengthened journey after actual-base upgrade passed **139**, including real last-seat competition, exact staff evidence, direct Block/shared-room behavior, ACK/mute boundaries, removal/rejoin, atomic hub exit, a continuously subscribed and responsive retained actor socket, frozen HTTP history, native draft ownership and exact unreported synthetic erasure. Both restore activation OFF.
- Actual pre-A00 upgrade: **123 immutable Git migrations**, all existing published bytes checked unchanged (line endings normalized only for comparison); Project/Tavolo/registered Group/Resource drafts created through real authenticated canonical contracts. Upgrade to the complete current inventory preserves **163 original native table/common-column snapshots**, three warmed native function OID/ACL/result contracts and all four owner reads while co-creation OFF: **180 assertions PASS**. Manifest: `.local/cocreate-upgrade-dbef054d-a6f5-4ae7-8409-ef0d8a4ccfa3/manifest.json`, state `native-snapshots-preserved-current-schema`. The working migration directory was never moved by this new verifier. All **9 co-creation pgTAP files / 1,151 assertions** pass on that populated upgrade before the final genuine journey.
- New harness corrections preserved the product/security assertions: the pinned Realtime server's idle broadcast handler can start after SUBSCRIBED. Bounded metadata-only probes establish transport readiness, then the test matches the independent delivery UUID queued by exactly one real product write; probes cannot satisfy it. A first attempted xmin correlation was invalid because realtime.send uses a subtransaction, so serial fixture delivery-ID snapshots now provide the correlation. The baseline Group creator returns a scalar UUID (verified in generated types); its initially guessed object receipt was corrected. No native test, grant, RLS rule or approval control was weakened.
- Final post-upgrade lint/advisors clean; public types regenerated by the established command and drift check passed with no further public type changes. Initial requested type repair remains committed as `f74f1196`; D03's generated additions are in `15180d53`. Final tooling **181 PASS**. Complete mobile **4,073 PASS / 2 existing opt-in smoke skips**, l10n/format/analyze clean, Android debug APK built. The unchanged 250 ms Resource reconnect test failed only in the initial concurrent run, then passed its full isolated file and the complete serial aggregate. Complete Web **401 PASS / 2 existing skips**, lint/typecheck/build/static invitation check; complete Site **41 + 19 PASS**, lint/typecheck/build/deployment dry-run. Scoped formatting/syntax and diff inspection pass.
- Rendered EN/IT narrow/large-text evidence remains under `docs/development/evidence/cocreate`; these are actual component/contract-fixture renders, not live phone screenshots. The real backend/socket journey is separate. No Android device was attached. Five pre-existing PLANETS QA AVDs were inventoried but not booted or modified. Physical-phone/accessibility/founder visual review and iOS build remain unrun; they did not stop eligible implementation. Real provider rights/configuration and production policy/identity decisions remain their separate owner work.
- QA restoration is complete. Verified server activation OFF, stopped named project **with backup**, restored original `supabase/config.toml` bytes only after checking overlay hash `242091c90891b9f290e02655142f371bebd63af535efc0867bba50e21f60608f`. Restored SHA256 is **2e67b7a5cda9ffc671c31b4461c1c8b896cc75c3bf727f6e406ee573eefbd8f6**; Git confirms no config diff. Original and named project backups remain intact/stopped; after confirming zero running owned containers, the task-owned `planets-cocreate-qa` VM was stopped. Other machines/worktrees untouched. `.local/qa-api-overlay/journal.json` records restoration. Local diagnostics/manifests are retained untracked, never staged.
- **Exact remaining blocker/next action:** final GitHub validation is gated by STAGING-AUTO01's repository-owner migration review. CI 39777384536 demonstrated this gate before area jobs; the final pushed head will produce its own `staging-migration-review-<run-id>` artifact containing `review-required.json`. The repository owner must inspect the concrete SQL diff and post `STAGING-AUTO01-REVIEW` followed by that exact JSON object for the final head, then rerun the existing gate. Its source SHA, migration hashes and predecessor digests must match; do not post/forge owner approval from this agent or use another workflow to evade the control. Final PR body supplies the final-run link and exact request. Full GitHub CI is therefore **not claimed passed** for the final head. Keep the cumulative PR draft/unmerged; no production/hosted migration, deployment, store submission, real delivery, destructive unrelated cleanup or automatic main merge occurred.

## COMM01/FILL01 follow-up (2026-10-23, active)

New explicitly requested branch/worktree `codex/cocreate-fill01` builds on RUNALL
`a0e810d0` and, under the user's later instruction to combine related unfinished
work, includes VIS01 `512192ec`. Existing branches/worktrees and primary untracked
work are preserved. Draft [PR #297](https://github.com/lillo24/planets.community/pull/297)
targets RUNALL and remains unmerged.

The user supplied COMM01 in chat and combined it with meeting-time filling,
persistent group chats, separate per-meeting attendance, General notifications,
mutually exclusive Activities/Find people presentations, independent mode-specific
mock accounts/data, and a final button-only Crazy Ideas entry. The detailed
contract, bounds, current evidence and precise next action are in
[cocreate-fill01.md](cocreate-fill01.md). Historical RUNALL evidence below remains
unchanged. This follow-up is not complete or ready for production.

### Follow-up backend qualification checkpoint

- Canonical schema/security stage is committed/pushed as `2225a88f`. Final
  additional race, existing-hub reuse, scoped staff and paged-fanout tests pass:
  **104 real Auth assertions / 299 scoped pgTAP assertions**. Fresh full schema
  replay previously passed **170 files / 8,234 assertions**, before twelve newly
  added assertions. No canonical migration changed after that replay.
- Selected actual RUNALL-base populated upgrade passes **216**, preserving
  **187 table snapshots / six function OID/ACL/result contracts**. Public types
  were generated with the standard command and drift check passes. Existing
  continuous programme passes **139**; lint/advisors clean.
- The backend is stopped with backup, activation OFF. Original config SHA256
  `2e67b7a5cda9ffc671c31b4461c1c8b896cc75c3bf727f6e406ee573eefbd8f6` is restored.
  Owned two-realm mock qualification passes **382** and cleans only its own new
  stacks; zero running containers were confirmed before stopping the owned VM.
- Current source remains uncommitted for mobile/admin/mock stages. Complete Web
  **405 pass / two skips**, lint/typecheck/build/invitation check and tooling
  **181 pass**; 36 mobile flow/render tests pass. Analyzer reported three new
  brace-style infos, repaired; full mobile has not run yet. New retry tests cover
  activation/current-meeting replacement before the final aggregate.
- Latest origin/main advanced to `d735bb88` with merged ACTMET01 and an Activities
  planning queue; RUNALL/VIS01 heads remain unchanged. Next: commit qualified
  follow-up stages, integrate only these merged main commits on this branch,
  then full mobile qualification and combined-path regression, inspect final
  captures/diff, push and refresh PR #297's exact owner-review gate. Preserve all
  other branches/worktrees. No hosted operation, merge or provider activation.

### Follow-up staff review stage verified

- Added the real admin case-only proposal snapshot and suppress/restore/reject
  controls. Current staff is rechecked for each read/write; exact command/CAS
  retries are retained. This grants neither supporter roster nor chat access.
- New staff/parser/component tests pass **4**; complete Web **405 pass / two
  existing skips**, lint/typecheck/build/invitation check pass. Scope and model
  documentation are current. Backend qualification is `2225a88f` + `e6fdf8f5`.
- Next: commit qualified mock/mobile stages, integrate merged latest main, finish
  mobile aggregate and final draft-PR evidence. Keep all PRs unmerged.

### Follow-up mock fixture stage verified

- Dedicated mock operator now seeds all eleven requested named communities in
  seven curated categories, timed **4/7 Valorant**, full Lupus, persistent group
  messages and pending interest scenarios through canonical eligible commands.
  Separate five-person Activities and Find people datasets are broker metadata.
- Target/broker/fixture unit tests pass **14**. Actual two-realm qualification
  passes **382 / ten personas / zero normal-realm calls**, including real Auth,
  notification concurrency, populated mock-control replay and non-destructive
  repeat seed. Source schema digest is recorded in `cocreate-fill01.md`.
- No hosted mock data/control update was performed; its separate owner-approved
  schema/control/seed rollout remains required. Next: commit the mobile picker,
  mutually exclusive presentation selection, hierarchy, meeting UI and notices;
  then reconcile latest merged main and complete the final mobile aggregate.

### Follow-up typed reader/notification stage verified

- Added closed categorized/proposal/own-invitation parsers, bounded typed readers,
  meeting scheduling/attendance receipts and compatible optional scheduled card
  fields. Timed filling notices use the existing sole notification inbox and an
  exact review destination; read never joins a chat. Actor-only signals refresh
  inbox/count without publishing meeting details.
- Strict community/notification tests pass **six**. Final formatter checks **937
  files / zero changes**; Flutter analysis is clean. Latest community/meeting
  retry suite passes **23**, including activated support and an older meeting's
  unconfirmed RSVP after the current occurrence changes.
- Next: commit the tested mobile hierarchy/meeting/settings/picker/Home stage,
  merge only latest committed main, run complete combined mobile qualification,
  then final evidence/PR update. Backend/admin/mock commits remain intact.

### Follow-up mobile flow stage verified locally; final aggregate pending

- Mobile now provides lazy category discovery, duplicate suggestions and safe
  proposal preview, private interests/ready CTA and deliberate existing hub Join.
  General publishes dated requests; Join reserves a meeting place and opens the
  persistent chat. Existing members RSVP/decline separately, and creators
  schedule/refill/cancel. Current time and place count are shown before joining.
- Unconfirmed proposal/schedule/support/RSVP commands retain their original UUID
  and intent across remount, activation and current-meeting replacement. Account
  changes clear private drafts and attempts. All **23** latest community/meeting
  tests pass; previous **36** flow/render tests and the picker **nine** pass.
  Presentation selection **three**, strict parsers **six**, format and analysis
  pass. Full mobile is still pending; earlier test-authoring and missing-store
  fixture failures were repaired without reducing assertions.
- Settings serializes mutually exclusive Activities/Find people choices; Mock
  remains independent. Help offers different login catalogs, without silently
  impersonating another account. Crazy Ideas is only an accessible disabled
  Home button with localized coming-later text and no destination/Project/data.
- VIS01 intro/replay/filter behavior is preserved. EN/IT 320dp light/dark 1x/2x
  captures were rendered/inspected, including large Italian category and meeting
  copy plus the disabled Home button. Next: integrate origin/main `d735bb88`,
  complete combined mobile tests/debug APK and final docs/evidence/PR checks.

### Latest-main integration and visual qualification checkpoint

- `f5a25f25` integrates merged main `d735bb88`, including merged ACTMET01, on this
  same branch. The sole adjacent-import conflict preserves both the D03 people
  handoff and ACTMET01 sharing controls. Their denied analytics gate/Mock
  exclusion remains intact. Other agents' branches/worktrees are untouched.
- New EN/IT active hierarchy → General → separate **2/3** room → deliberate room
  Join/Open journeys pass at 320dp/2x. Their screenshots exposed cramped large
  room-row copy; it now uses full-width lines and right-aligned occupancy. Final
  complete Co-Creation **139 pass**; final formatter/analyzer clean. Twenty-four
  focused captures are selected; extra generated renders are preserved in .local.
- Complete integrated serial mobile run is active, currently past native
  Project tests with no failures and two existing opt-in smoke skips. Its log is
  `.local/qa-api-overlay/mobile-complete-final.log`; debug APK follows only on
  success in session **95840**. After the small visual repair, all affected
  Co-Creation tests were independently rerun and pass. Next: finish this run/APK,
  inspect final diff, commit/push evidence, update draft #297 and record the exact
  final-head owner CI artifact. Do not repeat completed stages or touch hosted
  services/main/other branches. QA config/activation restoration is complete.

### Compatibility correction checkpoint (continue here)

- The complete integrated mobile suite passed **4,179 / two existing opt-in
  smoke skips** in 18m10s, followed by a successful Android debug APK (240.5s).
  All **139** Co-Creation tests independently pass after the large-text repair.
- Final interface inspection found a real gap: scheduled-card fields were added
  through installed D01 readers whose earlier client parsers are closed. New
  additive migration `20261023002240_cocreate_versioned_meeting_readers.sql`
  introduces `get_own_cocreate_recruitment_v2`,
  `get_cocreate_recruitment_v2` and `get_cocreate_room_page_v3`, preserving all
  existing Auth/episode/history/ACK checks. Existing readers retain their OID,
  ACL, exact unscheduled behavior and nine-field nested shape; dated cards appear
  unavailable with no occupancy/admission action, so old clients cannot offer
  Join without meeting time. New readers carry the eleven-field dated card.
- Correction source (scoped checks pass; final replay/upgrade in progress): new migration, mobile
  gateway names and corresponding explicit fixture expectations, old/new reader
  pgTAP and genuine Auth/ACK assertions. No previous migration is rewritten.
  Ordinary reader compatibility is repaired at the backend rather than relaxing
  strict parsers. Report snapshots and current-meeting reads retain exact time.
- Owned QA VM restarted and the stopped owned backup resumed; the new migration
  applied successfully. Root config is TEMPORARILY the owned overlay again:
  project `planets-cocreate-fill01-qa`, API54821/DB54322/mail54324, overlay SHA256
  `42c0e9dda182248d77185be3dc12c70c6473a08b87d6b6a666fb22c9abbe56fc`.
  `.local/qa-api-overlay/journal.json` records it; original bytes/hash remain
  safely saved. NEVER stage this config, use the default project or touch another
  machine/worktree. Earlier restoration evidence above is historical.
- Scoped compatibility qualification passes **314 pgTAP / 113 real Auth**;
  standard generation adds 27 public type lines. All **139** Co-Creation tests
  pass with the new RPC names; existing fixtures changed only their explicit
  method expectations, retaining every assertion. Flutter analysis is clean.
- Active sessions: **52764** runs fresh replay/full pgTAP, lint/advisors, selected
  actual-base populated upgrade, continuous programme, final Auth and generation
  (`compat-clean-reset.log`, `compat-full-tap.log`, `compat-upgrade.log`,
  `compat-programme.log`, `compat-auth-final.log`, `compat-types-final.log`).
  **85221** has reached the updated debug APK (`compat-apk.log`). Inspect actual
  results before claiming final qualification. Source stays isolated on
  `codex/cocreate-fill01`, draft PR #297; config overlay must not be staged.
- Exact next action: finish/repair these tests, fresh replay/full pgTAP plus
  lint/advisors, repeat selected actual-base upgrade/continuous journey and public
  types/drift, qualify Web types, then stop own backend with backup and hash-check
  restore original config. Repeat two-realm mock qualification against the final
  migration digest (the earlier 382 pass used three follow-up migrations). Commit
  correction/evidence, push once final local qualification is complete, refresh
  draft #297 and its exact owner-review CI artifact. No hosted operation,
  deployment, main merge, external delivery or approval bypass.

### Compatibility qualified / final mock replay active

- Correction committed as **`9bfa662e`**. Final clean replay plus complete
  database suite passes **170 files / 8,273 assertions**; scoped compatibility
  **314**, lint/advisors clean. Actual selected-base upgrade passes **216** again,
  preserving **187 native/co table snapshots / six function OID/ACL/result
  contracts**. Manifest: `.local/cocreate-upgrade-b85d132f-3d4d-4942-b0b9-4b13458954d8/manifest.json`.
- Final populated real OTP/socket programme passes **139**, final Auth verifier
  **112** (prior race ordering **113**; one conditional branch adds its rejection
  assertion). New generated types are committed and standard drift check passes.
  Web typecheck passes again. Current mobile: **139** Co-Creation tests, clean
  analysis/947-file formatting and updated debug APK **45.2s** pass. Complete
  preceding native/mobile aggregate **4,179 / two existing skips** remains valid
  for unchanged areas; the versioned-reader change was requalified in full for
  its affected area. No test/assertion was removed or relaxed.
- The owned backend is stopped **with backup**, gate OFF, original config bytes
  restored and hash checked. Journal state is
  `stopped_with_backup_compatibility_qualified`; no config diff remains. The QA
  VM stays running only for two newly owned disposable mock stacks.
- **Active final check:** session **55580**, log
  `.local/qa-api-overlay/compat-mock-realms.log`, repeats genuine two-realm
  notification/fixture/control replay with the final four-migration inventory.
  The old 382-pass digest above is historical until this check completes. Next:
  finish/repair it, confirm its cleanup and zero running owned containers, stop
  the owned VM, record the final digest/results, final docs/diff/commit/push and
  update draft PR #297 with its exact-head owner-review artifact. Main remains
  `d735bb88`, RUNALL `a0e810d0`, VIS01 `512192ec`. Other worktrees remain untouched.

## COMM01/FILL01 final local qualification

- **All eligible requested work is implemented and locally qualified.** This
  branch contains latest RUNALL `a0e810d0`, VIS01 `512192ec` and merged main
  `d735bb88` (including ACTAPI01/ACTMET01). Four additive follow-up migrations
  preserve published history, legacy readers/episode rules, RLS and owner gates.
  Separate reviewable stage commits and the installed-reader fix `9bfa662e`
  remain on `codex/cocreate-fill01`; no other branch/worktree was modified.
- Delivered curated category → community → General/separate numbered rooms;
  normalized three-account proposal activation and private deliberate Join
  invitations; timed General requests, per-meeting places/RSVP and persistent
  chats; bounded typed in-app notifications with time, privacy/mute/preferences;
  scoped proposal moderation; exclusive presentation selection and independent
  five-person mock login catalogs with all eleven requested interests; and only
  a disabled coming-later Crazy Ideas Home button, without Project/data wiring.
- Final clean database **170 files / 8,273 assertions PASS**, scoped new contracts
  **314 PASS**, lint/advisors clean. Final selected RUNALL-base upgrade **216 PASS**,
  **187 table snapshots / six function OID/ACL/result contracts** preserved.
  Final genuine OTP/socket programme **139 PASS**, Auth **112 PASS** (earlier valid
  race order 113), public types generated with the standard command and drift
  check PASS. No parser/security assertion was relaxed for compatibility.
- Complete mobile **4,179 PASS / two existing opt-in smoke skips**; final affected
  Co-Creation **139 PASS** after reader correction, clean analysis and formatting
  **947 / zero changes**, final Android debug APK **PASS (45.2s)**. Twenty-four
  EN/IT 320dp light/dark 1x/2x contract-fixture PNGs were rendered/inspected.
  Complete Web **405 PASS / two existing skips**, lint/typecheck/build/invitation
  check PASS; typecheck repeated after final generation. Tooling **181 PASS**.
  Unchanged Site has historical RUNALL evidence; no new Site run is claimed.
- Final actual two-realm mock test **382 PASS / ten personas / zero normal-realm
  product calls**, real notification rollback/concurrency, populated control
  replay and repeat seed. Final canonical schema digest:
  `45b81eeca3f4e7ca4d09cc8adc33076768df54229dbff045f6087243a1b562aa`.
  Mock target/broker/fixture unit tests **14 PASS**. No hosted mock update occurred.
- Restoration complete: activation OFF, owned backend stopped with backup,
  original config hash **2e67b7a5cda9ffc671c31b4461c1c8b896cc75c3bf727f6e406ee573eefbd8f6**
  restored, both newly created mock stacks cleaned up, zero running owned
  containers verified and `planets-cocreate-qa` VM stopped. Private diagnostics,
  extra renders and recovery manifests remain untracked in `.local` only.
- **Precise remaining gate/next action:** see draft
  [PR #297](https://github.com/lillo24/planets.community/pull/297) for the final
  source SHA, CI run and exact migration-review artifact. CI on `c7febc08`
  ([39879321006](https://github.com/lillo24/planets.community/actions/runs/39879321006))
  explicitly rejects the dependent base: **"Review must belong to a
  same-repository main PR"** (`scripts/release/reviews.mjs:124–128`). Area jobs
  were skipped. An owner comment alone cannot resolve this base condition.
  Keep the required RUNALL base/draft and do not bypass or weaken the policy.
  At a later separately authorized integration checkpoint, finish RUNALL's owner
  review/dependency integration, update this branch and retarget the same PR to
  approved main, generate a fresh exact-head inventory/request, then obtain the
  ordinary owner migration review and rerun the existing gate. Current artifact
  source SHAs cannot approve a later changed head. No approval is posted/forged,
  premature retargeting or alternate workflow used. Final-head GitHub CI is not
  claimed passed; the PR body links its final run without a self-referential
  documentation/SHA loop.
  Keep this dependent PR draft/unmerged; no production/hosted migration,
  deployment, store submission or external push delivery was performed.
- Physical Android/voice/accessibility, founder visual review and iOS remain
  unrun owner qualification; `adb devices -l` found no attached device. These did
  not stop eligible implementation. Production experimental-policy activation,
  hosted mock adoption and provider setup remain separately controlled. Exact
  commands, assumptions, compatibility/access matrix and evidence are in
  [cocreate-fill01.md](cocreate-fill01.md). No further eligible code stage remains.

### DEPLOY01 — authorized cumulative integration, 2026-10-23

- The founder now explicitly selected DEPLOY01, with DEPLOY02 only after the
  reviewed integration merges. [Its execution contract](cocreate-deploy01.md)
  supersedes the dependent-base-only handoff above for this checkpoint. Reuse
  the same isolated branch/worktree and #297; do not duplicate #287/#292 ancestry.
- Safely fetched main `667bf57b`, preserving primary `.vis01/`, all `.local/`
  diagnostics and other agents' worktrees. Clean merge `50e66c37` adds only the
  latest MAPMOCK01 planning document. ACTMET01 code/tests and the release safety,
  owner-review, writer, reconciliation and staging workflow match main exactly.
- Static inventory verifies **126 unchanged main migrations + 15 additive,
  unique owner-review-required migrations = 141**. The owned-local upgrade
  verifier now also accepts that exact main SHA/inventory, retaining all reset
  guards, original/RUNALL bases and preservation assertions.
- Refreshed qualification: Mobile **4,181 PASS / two existing skips**, clean
  analysis, **947 formatted / zero changes**; Android debug APK PASS **131.4s**;
  Web **405 PASS / two existing skips**, lint/typecheck/build/invitation check
  PASS; tooling **181 PASS**; Site **60 PASS** plus lint/typecheck/build/dry run.
  Actual two-realm Mock **382 PASS / ten personas / zero normal calls**, worker
  concurrency/rollback, populated controls/repeat seed; unit **14 PASS**.
- Populated main upgrade **185 PASS / 168 original table snapshots / three
  native function OID/ACL/result contracts**. RUNALL upgrade **216 PASS / 187
  snapshots / six contracts**, including existing General/numbered episodes,
  chat, legacy card and original capacity. Post-upgrade real OTP/socket
  programme **139 PASS**; gates restored OFF. Full `check:db` now running.
  A **new** named disposable
  `planets-cocreate-deploy01-qa` protects old backups, with a hash-journaled
  two-line config overlay. The first actual-main CLI reset failed before
  population; diagnostic retry passed unchanged SQL. The failed log and both
  passing manifests remain retained, and diagnostics now include both redacted
  output channels rather than hiding stdout errors behind stderr progress.
- **Audit finding / eligible follow-up:** a withdrawn proposer can accumulate a
  large supporter roster; reactivation's refresh-signal loop is unbounded.
  Private drafts prepare a 36-account canonical regression and a forward limit
  of 25 optional recipient invalidations plus the actor response. Every durable
  Ready-to-join invitation remains available through the existing 20-second
  foreground refresh/entry; no product enrollment or provider change is needed.
- **Precise next action:** finish frozen full `check:db` first, demonstrate the
  regression and apply/qualify the bounded refresh migration without rewriting
  the original 15. Then restore gate OFF, stop only the new project with backup,
  restore original config bytes. Inspect/commit, retarget the same draft #297 to
  main before final push, obtain a fresh exact-head owner-review artifact and
  wait for actual owner SQL proof/current-head green CI. Do not post owner proof,
  weaken controls, merge duplicate ancestry or begin DEPLOY02. No hosted action.
