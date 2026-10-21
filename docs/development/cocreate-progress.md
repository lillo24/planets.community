# COCREATE-RUNALL progress

Authority: [RUNALL pack](../../history-implementations/PLANETS_COCREATE_RUNALL_autonomous_implementation.md).
Base: `675bc592` (latest origin/main fetched 2026-10-21).
Integration branch: `codex/cocreate-runall`. Managed worktree:
`C:/Users/utente/.codex/worktrees/cocreate-runall/planets.community`.
One cumulative draft PR; automatic merge prohibited. No hosted migration,
deployment, store upload or external delivery authorized/performed.

## Stage ledger

| Stage | State                  | Dependency      | Evidence / next action                                                                                                                                               |
| ----- | ---------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A00   | verified               | base            | Implemented and inspected. 287 affected tests pass, eight rendered combinations pass, Flutter analysis and all-file formatting pass. Android debug APK build passed. |
| A01   | implemented_unverified | A00             | Experimental contract, strict typed identities and default-OFF private server gate added. Local stack startup/DB replay and gate tests pending.                      |
| B01   | implemented_unverified | A01             | Posts, consent/contact backend and negative/concurrency qualification.                                                                                               |
| B02   | partial                | B01             | Live mobile Posts/Requests/accepted-contact Messages.                                                                                                                |
| C01   | pending                | A01             | Independent hub membership and General backend.                                                                                                                      |
| C02   | pending                | C01             | Live communities and General UI.                                                                                                                                     |
| C03   | pending                | C01             | Atomic numbered groups, history, hub-exit cascade.                                                                                                                   |
| C04   | pending                | C02/C03         | Live numbered groups and Messages integration.                                                                                                                       |
| D01   | pending                | C03/C04         | Canonical capacity-aware recruitment.                                                                                                                                |
| D02   | pending                | B/C             | Explicit source links and native Project drafts.                                                                                                                     |
| D03   | pending                | B/C             | Ordinary deterministic filters. Provider part conditional on merged ACTAPI01.                                                                                        |
| Q00   | pending                | eligible stages | Full synthetic programme journey, fresh/upgrade DB and regression qualification.                                                                                     |

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
