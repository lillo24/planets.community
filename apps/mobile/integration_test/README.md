# Local native integration checks

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
role. It is not production history or the deferred TW05 demo world.

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
