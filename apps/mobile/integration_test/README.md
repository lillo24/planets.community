# Real own-history Android smoke

## MODINT01 integrated-head replay

The existing normal-main OTP and request harnesses also accept the explicit
`--modint01` preparer switch. It selects only `planets-community-modint01-qa`,
API 54611 and Mailpit 54614; it is not permission to use an arbitrary backend.
Both emit `MODINT01_SMOKE=true` to ignored `config/local.json`, with public
configuration/synthetic identifiers only. The normal app still obtains real OTP
sessions through its UI. Sign-out uses current Settings/Profile controls, not
the demo-only Home button. Both harnesses scroll to the actual lower sign-out
action in lazy Settings on the small phone; no direct session mutation replaces
that UI action. Both helpers settle route/IME animation before real OTP taps.
After a Profile or Settings exit, main reopens Welcome. Account switching uses
its normal Log in button (or public Messages' contextual login after exploring); those
signed-out screens need not redirect automatically to Auth.
Main removed the Home Auth card: native ready-Home captures assert the actual
hero plus canonical ready identity/no command failure, not obsolete status text.
Incomplete-profile completion uses the normal Messages setup action.
`native_ui_settle.dart` settles finite entrance/route motion when the actual
Home/Welcome orbit is visible, without disabling its intentional repeating
animation. Other screens retain a strict animation-idle wait; canonical async
readiness/result assertions and their 30-second deadlines remain unchanged.
The helper's widget regressions keep real orbit motion and reject stuck loaders.
The OTP language helper changes away and back when a retained device preference
already equals the requested language: a selected radio does not emit a save or
pop. It still uses the real Settings controls and unchanged save deadlines.
The OTP smoke additionally covers navigation choices,
photo-free participant admission, nullable request origin, chat continuity under
content hiding, all private notice types and suspension during ordinary access.
The continuation additionally prepares a real pending request/personal pair and
verifies delegate denial without a fabricated conversation. The normal app sends
a pair message and independently reads its canonical feed, uses a seeded public
template for a photo-free private copy, then denies those pair/template/draft
shortcuts during suspension. Broader Workshop/pair coverage remains in main's
domain and widget suites; no production identity gateway is replaced here.
Synthetic EN/IT screenshots use the existing explicit driver output directories.

The integrated replay uses the task-owned `PLANETS_MODINT01_API35` small-phone
AVD (official Google APIs x86_64 API 35, revision 9/extension 13), 720×1280 at
320 dpi, 1536 MB RAM and owned port 5560. The installed API 37.1 image enforces
a 4 GB minimum despite smaller `-memory` values. No user AVD or SDK/tool version
is changed. Compile before execution and use `--use-application-binary` to avoid
overlapping a build with the device smoke. A command-local
`GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx1g` caps that build daemon's heap without
editing repository/global Gradle configuration; restore any prior value after
the build. Pause only the owned backend with backups retained if compilation
needs its memory; resume it before execution. A resource or compile failure
remains a failure, not a passed smoke.
After any run that committed admission, prepare fresh actors/Projects and rebuild
the matching compile-time fixture config; do not erase membership history or
reuse an already-joined Project as proof of fresh admission.

Run each preparer immediately before its matching driver after the Database gate:

```powershell
$env:MAILPIT_URL = 'http://127.0.0.1:54614'
npm exec -- node apps/mobile/integration_test/prepare_authqa_fixtures.mjs --modint01
# then otp_home_test.dart with test_driver/otp_home_driver.dart
npm exec -- node apps/mobile/integration_test/prepare_request_restriction_fixtures.mjs --modint01
# then request_restriction_test.dart with test_driver/request_restriction_driver.dart
```

The participant bearer token stays only in ignored local configuration; screenshots
must never show it. Prior AUTHQA01/09C2B2 results remain historical, not evidence for
this combined source. Restore generated configuration and stop only owned services.

This folder owns the task-local 09C2B1 real-backend UI smoke, not host widget
tests, production startup, or a replacement for the Database verifiers.

- `prepare_local_fixtures.mjs` reuses repository OTP/consequence fixtures, creates
  seven fresh synthetic accounts and a canonical under-review case, and generates
  ignored `config/local.json` with public configuration and synthetic identifiers.
  It refuses any project other than `planets-community-09c2b1-qa` and any non-loopback
  host backend/mailbox. It exports no service-role key, database URL or staff token.
- `own_history_test.dart` uses real OTP sessions on the emulator for staff and
  ordinary accounts. It loads the normal app/router/Auth/gateway, applies and
  revokes a notice, refreshes, tests Settings/Back, switches accounts, and verifies
  history denial → existing suspension screen → Check status again → removed
  suspension history. Reasons are synthetic plain text. Monitoring is disabled.
- `../test_driver/own_history_driver.dart` is the SDK integration driver. No
  Driver extension, staff controls or fixture API is added to `lib/main.dart`.
- `isolated_pkce_storage.dart` provides the resolved SDK's required PKCE verifier
  storage for directly constructed real-OTP clients. App and staff have separate
  memory-only stores, cleared at teardown; production PKCE/Auth is unchanged.

Use a disposable task-owned Supabase project, not the shared local stack or any
remote environment. Configure project `planets-community-09c2b1-qa` on API 54501,
DB 54502, shadow 54500, Studio 54503, Mailpit 54504, analytics 54507, pooler 54509,
and inspector 8093; retain the original config for exact restoration. Start it
from this checkout and retain its normal backup when stopping. The preparer reads
project-scoped status, so repository `node_modules/.bin` must be on PATH (or invoke
it through `npm exec`). Do not commit generated config or tokens.

From the repository root, after the backend is started and the Android emulator
is available:

```powershell
$env:MAILPIT_URL = 'http://127.0.0.1:54504'
npm exec -- node apps/mobile/integration_test/prepare_local_fixtures.mjs
cd apps/mobile
flutter drive --driver=test_driver/own_history_driver.dart --target=integration_test/own_history_test.dart -d emulator-5554 --dart-define-from-file=config/local.json
```

The generated Android URLs use `10.0.2.2`, the emulator's host loopback bridge.
Physical-device routing is deliberately not guessed. `flutter test` only runs
the existing `test/` host suite; this device smoke is an explicit local command,
not a hosted-CI claim. Formatting these entrypoints explicitly uses
`dart format --output=none --set-exit-if-changed integration_test test_driver`.
See the review report for actual run status, limits and cleanup evidence.

## AUTHQA01 normal-main OTP smoke

`prepare_authqa_fixtures.mjs` is a separate narrow preparer, refusing any project
other than `planets-community-authqa01-qa`. Use fresh API/DB/shadow/Studio/Mailpit/
analytics/pooler ports 54511/54512/54510/54513/54514/54517/54519 and inspector 8103.
Back up the exact config before changing it; do not reset or stop another stack.
It creates synthetic complete accounts and reserves a never-created new-account
email. `otp_home_test.dart` calls normal `lib/main.dart` with no app gateway or
provider overrides and signs in ONLY through real email/code UI. It checks
canonical anchors, Home EN/IT, new-profile save, preserved destination, Settings,
focused own-history isolation and suspension. The separate synthetic staff client
only arranges/revokes local notices. No staff helper is added to production.

```powershell
$env:MAILPIT_URL = 'http://127.0.0.1:54514'
npm exec -- node apps/mobile/integration_test/prepare_authqa_fixtures.mjs
$env:AUTHQA_SCREENSHOT_DIR = 'C:/absolute/task-owned/evidence'
cd apps/mobile
flutter drive --driver=test_driver/otp_home_driver.dart --target=integration_test/otp_home_test.dart -d emulator-5554 --dart-define-from-file=config/local.json
```

`otp_home_driver.dart` saves only named synthetic Home screenshots to the required
explicit evidence directory. The smoke restores the prior language preference,
signs out and revokes its own temporary consequences even on failure. Use a fresh
preparation for a new-account run; do not claim an already-completed account tests
initial onboarding. This is an explicit device check, not a hosted-CI assertion.

## 09C2B2 normal request-form smoke

`prepare_request_restriction_fixtures.mjs` refuses any project other than
`planets-community-09c2b2-qa`, API 54521 and Mailpit 54524 on loopback. Configure
DB/shadow/Studio/analytics/pooler 54522/54520/54523/54527/54529 and inspector 8113,
backing up exact configuration first. It creates fresh synthetic OTP accounts,
canonical profile photos and a consequence fixture, exporting only public
configuration and synthetic identifiers to ignored `config/local.json`.

`request_restriction_test.dart` calls normal main and real OTP UI without app
overrides. It exercises unrestricted requests, staff restriction, independent own
status, notices/Back with Project and modal Resource drafts, removal/explicit
retry with withdrawn episodes retained, blocking/coexistence, unrelated account
isolation and both forms' suspension routing. Staff and the inbound-blocking owner
authenticate with separate PKCE stores. Before launching each Resource form,
the harness explicitly refreshes the existing canonical requester-history cache
to reconcile external fixture actions; no production polling or test hook is added.
The driver requires an explicit screenshot directory and saves only four named
synthetic EN/IT request-form screenshots. No production test hook is introduced.

```powershell
$env:MAILPIT_URL = 'http://127.0.0.1:54524'
npm exec -- node apps/mobile/integration_test/prepare_request_restriction_fixtures.mjs
$env:REQUEST_SCREENSHOT_DIR = 'C:/absolute/task-owned/evidence'
cd apps/mobile
flutter drive --driver=test_driver/request_restriction_driver.dart --target=integration_test/request_restriction_test.dart -d emulator-5556 --dart-define-from-file=config/local.json
```

Run after the clean Database gate, using the task emulator's `10.0.2.2` bridge.
The smoke revokes its consequences, signs out and restores the prior language in
teardown. Stop only this owned backend with backup retained, then restore the
original config. Actual evidence and limits are in the 09C2B2 review report.

## Workshop local native integration checks

`template_workshop_smoke_test.dart` runs actual mobile navigation/screens and
canonical RPCs against an explicitly local backend with verified synthetic OTP
identities. It preserves a sparse prior form, browses a Completed template,
inspects 51 resource descriptions, self-reports through the shared form, drops
one accepted RPC response, recovers the same draft, edits/saves after audited
template removal and reopens both independent editors. It injects only the
verified starting identity and synthetic response loss; profile readiness,
templates, report, copy, owner reads and departure writes use the real backend.
This is opt-in native smoke, separate from ordinary `flutter test`/scoped CI.

`prepare_workshop_smoke.mjs` owns one synthetic fixture and two `.invalid`
accounts on an isolated disposable loopback stack. It uses existing local OTP
and photo helpers, canonical creation/publication/resource RPCs, and trusted
local-only SQL to backdate that source and give the synthetic reviewer its
role. It is not production history. TW05 now supplies a separate repeatable demo
world and combined inventory journey below.

Run from the repository root, with Docker, Node dependencies and an Android
emulator available. First assign a unique local Supabase `project_id` and free
ports in this checkout only, preserving original config bytes outside Git.
Start/reset that isolated stack; do not reset another checkout or shared DB.
Use its Mailpit URL and add `node_modules/.bin` to PATH so the fixture helper
can read project-scoped CLI status. Then:

```text
node apps/mobile/integration_test/prepare_workshop_smoke.mjs <OS-temp>/tw04-defines.json
adb -s <emulator> reverse tcp:<local-api-port> tcp:<local-api-port>
cd apps/mobile
flutter test integration_test/template_workshop_smoke_test.dart -d <emulator> --dart-define-from-file=<OS-temp>/tw04-defines.json
```

The temporary defines file contains local synthetic access tokens. Keep it
outside the repository, never print/upload it and delete it afterward. The
test refuses nonlocal backend URLs. Recreate the fixture/defines before a new
run: the successful journey removes that one template. Verify formatting with
`dart format --output=none --set-exit-if-changed integration_test` and fixture
syntax with `node --check apps/mobile/integration_test/prepare_workshop_smoke.mjs`.

On a shared emulator, temporarily give the Android build a distinct QA
`applicationId` (this run used the `.tw04qa` suffix), restore exact Gradle bytes
afterward, and remove only that QA package/reverse rule. Stop the unique local
stack **before** restoring its original Supabase configuration.

Native smoke exercises real navigation and saves. Physical iOS swipe/interactive
Back behavior, platform accessibility and release/signing remain separate QA;
widget tests and an Android emulator do not establish those results.

## Automatic suggestions (SIM02)

`similar_proposal_smoke_test.dart` reuses the native wait helpers and real
app/router/screens with a separate narrow fixture. It checks automatic title-only
matching without a photo, dismissing without creating a draft, one guarded save
before ordinary detail and destination feedback, Back to the same draft with
the first bound ID as exclusion, the normal photo gate, a candidate becoming
Full/cancelled after lookup, and exact creation recovery after a committed RPC's
response is deliberately dropped. Home/Browse switching verifies paused hidden
matching and one current-query refresh on return. It records only exclusion and
creation-request IDs in test memory;
queries/tokens are never logged. All actual matching/persistence/detail RPCs are
real. Identity injection represents the verified local OTP session.

Start/reset a unique disposable stack as above; then, from repository root:

```text
node --check apps/mobile/integration_test/prepare_similar_proposal_smoke.mjs
node apps/mobile/integration_test/prepare_similar_proposal_smoke.mjs <OS-temp>/sim02-defines.json
adb -s <emulator> reverse tcp:<local-api-port> tcp:<local-api-port>
cd apps/mobile
flutter test integration_test/similar_proposal_smoke_test.dart -d <emulator> --dart-define-from-file=<OS-temp>/sim02-defines.json
```

The fixture owns two `.invalid` people and one upcoming synthetic Project. The
editor is ready without a photo; only the candidate Creator gets a synthetic
photo. Use a fresh reset of this task's isolated stack before repeating the
journey, because the test changes/cancels Projects and creates private drafts.
Never reset another checkout or shared backend. Preserve original config/Gradle
bytes outside Git, use a distinct `.sim02qa` Android application ID on a shared
emulator, and restore after verification. Delete temporary token defines and
token-bearing native build caches, uninstall only that QA package/remove only
its reverse rule, then stop the isolated stack before restoring config.

Use `flutter clean` in `apps/mobile` to remove compiled build/Dart artifacts.
Gradle can retain encoded Dart defines in this checkout's
`android/.gradle/<gradle-version>/executionHistory/executionHistory.bin`; remove
that specific cache file as well. This run used Gradle 9.3.1 and verified that
remaining project caches/daemon logs contained no SIM02 credential markers.
Preserve other projects' caches and shared Gradle processes.

Manual founder QA: try IT/EN with keyboard open, title-only versus selected tags,
empty/error/Retry, Full/unknown preview, dismiss/reopen across save/Back, invalid
raw geography, failed save and explicit discard, partial image save, rapid taps
and competing Back/tab actions. Repeat on supported physical Android/iOS with
large text and accessibility; inspect modal focus and interactive swipe return.

## Cumulative Workshop demo (TW05)

`prepare_workshop_demo_smoke.mjs` authenticates the already-seeded demo world;
it verifies rather than repairs it. `workshop_demo_smoke_test.dart` uses that
inventory for a combined real-app journey: preserve the original form, browse
the core catalog, self-report, recover one committed copy whose response was
dropped, dismiss suggestions without saving, handle one failed save, retry into
ordinary Full detail, return to the same draft, then remove the dedicated
transition template and recover its accepted independent copy again.

Reset only the selected disposable stack, seed/verify the world, and prepare
temporary defines outside Git:

```text
npm run demo:reset:local
node apps/mobile/integration_test/prepare_workshop_demo_smoke.mjs <OS-temp>/tw05-defines.json
adb -s <emulator> reverse tcp:<local-api-port> tcp:<local-api-port>
cd apps/mobile
flutter test integration_test/workshop_demo_smoke_test.dart -d <emulator> --dart-define-from-file=<OS-temp>/tw05-defines.json
```

The test uses English and 1.3 text scaling. Optional
`--dart-define=TW05_CAPTURE_SCREENSHOTS=true` captures the real Workshop in
English/Italian into the QA application's temporary directory. Use the same
distinct QA package, credential/cache cleanup and stack isolation described
above. The journey deliberately removes the additional transition template;
the eight core entries remain intact, and baseline verification must report
that drift until an explicit reset. Run the separate TW04 and SIM02 journeys
on fresh fixtures for their complementary paging/photo/creation-recovery cases.
See [the cumulative evidence and inventory](../../../docs/development/workshop-demo-validation.md).

## Integrated native invitation continuation (TW-STACK01)

`prepare_stack_invitation_smoke.mjs` reads the already-seeded world and the
PI05 browser rehearsal's private journal. It refuses every project except
`planets-community-tw-stack01` and writes references only to an OS-temporary
file. A fresh `tw-stack01-native@planets.invalid` identity is required; preparation
does not create it. `stack_invitation_smoke_test.dart` uses normal Supabase/Auth
initialization, real OTP and profile screens, duplicate platform messages during
both forms, photo-free Proposal/Tavolo admission and chat, Full/block denial,
dirty native departure, one explicit pre-commit save failure/Keep editing/retry,
invalid-host safe navigation and return to the same private draft. It reads
private state through canonical gateways; raw table access remains denied.
Platform message injection tests the app receiver, not OS HTTPS association.

With the owned stack on API 54921/Mailpit 54924 and the existing PI05 browser
fixture prepared, run from repository root:

```text
node apps/mobile/integration_test/prepare_stack_invitation_smoke.mjs <OS-temp>/stack-invitation-defines.json
adb -s <emulator> reverse tcp:54921 tcp:54921
adb -s <emulator> reverse tcp:54924 tcp:54924
cd apps/mobile
flutter test integration_test/stack_invitation_smoke_test.dart -d <emulator> --dart-define-from-file=<OS-temp>/stack-invitation-defines.json
```

The test consumes OTP only in memory from its fixed synthetic loopback mailbox.
It deliberately signs out any previous QA session before starting. Repeat only
after an explicit reset/reseed of this owned disposable stack and fresh browser
journal/preparation, because it completes the identity, admits two members and
creates a draft. Use the distinct QA package and exact configuration/build/cache
cleanup above. The [integration record](../../../docs/development/template-stack-integration.md)
and final draft PR own results and outstanding physical-device/founder gates.
