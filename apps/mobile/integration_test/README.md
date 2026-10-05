# Real own-history Android smoke

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
