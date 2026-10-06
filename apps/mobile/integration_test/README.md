# Real own-history Android smoke

## MODINT01 integrated-head replay

The existing normal-main OTP and request harnesses also accept the explicit
`--modint01` preparer switch. It selects only `planets-community-modint01-qa`,
API 54611 and Mailpit 54614; it is not permission to use an arbitrary backend.
Both emit `MODINT01_SMOKE=true` to ignored `config/local.json`, with public
configuration/synthetic identifiers only. The normal app still obtains real OTP
sessions through its UI. Sign-out uses current Settings/Profile controls, not
the demo-only Home button. The OTP smoke additionally covers navigation choices,
photo-free participant admission, nullable request origin, chat continuity under
content hiding, all private notice types and suspension during ordinary access.
Synthetic EN/IT screenshots use the existing explicit driver output directories.

The integrated replay uses the task-owned `PLANETS_MODINT01_API35` small-phone
AVD (official Google APIs x86_64 API 35, revision 9/extension 13), 720×1280 at
320 dpi, 1536 MB RAM and owned port 5560. The installed API 37.1 image enforces
a 4 GB minimum despite smaller `-memory` values. No user AVD or SDK/tool version
is changed. Compile before execution and use `--use-application-binary` to avoid
overlapping a build with the device smoke. A command-local
`GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx2g` caps that build daemon's heap without
editing repository/global Gradle configuration; restore any prior value after
the build. A resource or compile failure remains a failure, not a passed smoke.
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
