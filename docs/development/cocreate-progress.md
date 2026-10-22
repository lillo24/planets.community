# COCREATE-RUNALL progress

Authority: [RUNALL pack](../../history-implementations/PLANETS_COCREATE_RUNALL_autonomous_implementation.md).
Base: `675bc592` (latest origin/main fetched 2026-10-21).
Integration branch: `codex/cocreate-runall`. Managed worktree:
`C:/Users/utente/.codex/worktrees/cocreate-runall/planets.community`.
One cumulative draft PR; automatic merge prohibited. No hosted migration,
deployment, store upload or external delivery authorized/performed.

## Stage ledger

| Stage | State    | Dependency      | Evidence / next action                                                                                                                                               |
| ----- | -------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A00   | verified | base            | Implemented and inspected. 287 affected tests pass, eight rendered combinations pass, Flutter analysis and all-file formatting pass. Android debug APK build passed. |
| A01   | verified | A00             | Experimental contract, strict typed identities and default-OFF private server gate added. Fresh replay, negative authorization and genuine OTP/concurrency qualification passed.                      |
| B01   | verified | A01             | Posts, consent/contact backend and negative/concurrency qualification.                                                                                               |
| B02   | verified | B01             | Live mobile Posts/Requests/accepted-contact Messages.                                                                                                                |
| C01   | verified | A01             | Independent hub membership and General backend.                                                                                                                      |
| C02   | verified | C01             | Live communities and General UI.                                                                                                                                     |
| C03   | verified | C01             | Atomic numbered groups, history, hub-exit cascade.                                                                                                                   |
| C04   | verified | C02/C03         | Live numbered groups and versioned Messages integration; local UI/DB/build checks passed.                                                                                |
| D01   | pending  | C03/C04         | Canonical capacity-aware recruitment.                                                                                                                                |
| D02   | pending  | B/C             | Explicit source links and native Project drafts.                                                                                                                     |
| D03   | pending  | B/C             | Ordinary deterministic filters. Provider part conditional on merged ACTAPI01.                                                                                        |
| Q00   | pending  | eligible stages | Full synthetic programme journey, fresh/upgrade DB and regression qualification.                                                                                     |

## Isolation and evidence

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

## Resumable checkpoint

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
