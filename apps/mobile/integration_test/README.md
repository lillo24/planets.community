# Local native integration checks

## Navigation profile probe

`navigation_profile_test.dart` runs guest Welcome/intro/Home, three rounds of
Projects/detail/Back and Scambio returns, Messages Requests/Back and Login.
It uses the real router/widgets with fake gateways and an in-memory startup
store, normal motion and profile-mode frame timings. No hosted credentials,
network/DB reads or retained installation data are used. Run on an owned Android
emulator with the same resolution, density, refresh rate and clean app cache for
each comparison. Do not clear the founder's app or shared emulator.

From `apps/mobile`:

```powershell
flutter drive -d <owned-emulator-id> --profile --no-dds --no-pub --driver=test_driver/navigation_profile.dart --target=integration_test/navigation_profile_test.dart --dart-define=NAVPERF_BEFORE=true
# Repeat on the changed source without NAVPERF_BEFORE to write after.json.
```

The driver requires profile mode and writes `build/navigation-profile/{phase}.json`.
`--no-dds` avoids a device-to-host DDS websocket issue in this Windows setup.
For repeated builds, build an APK with the same target/define and use
`--use-application-binary=<apk>` on drive. Gesture-to-chrome measurements include
test harness scheduling; Back measures the next paint of the persistent bottom
bar, with the actual resulting route recorded/asserted separately. Frame samples
cover the action plus 350ms, using Flutter's `watchPerformance`. A separate idle
timeline enables build/layout profiling; its overhead is excluded from those
journey summaries. Raw synthetic evidence and a dependency-free Node summarizer
are under [NAVPERF01 evidence](../../../docs/development/evidence/navperf01/README.md).
These timings do not prove physical Android/iOS speed or live backend latency.

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


## Interactive tutorial smoke

`flutter test integration_test/tutorial_smoke_test.dart -d <dedicated-emulator>`
exercises the complete production guest tour with fake public gateways and an
in-memory installation store. It needs no backend, credentials or fixture reset;
use a separate task emulator rather than the retained founder demo device/stack.
The widget suite supplies deterministic timer, replay, session and layout checks.
Native iOS gestures/motion require a separate device run and are not inferred from
this Android smoke.

## Home Help smoke

`flutter test integration_test/help_smoke_test.dart -d <dedicated-emulator>`
checks Home Help, the complete replay returning to Help, person-report guidance,
bug review/edit/copy, and an injected mail handoff with backend-free fixtures.
To also exercise the real Android missing-handler path, run on an owned QA device
with no enabled mail app and add `--dart-define=HELP01_NO_MAIL_CLIENT=true`.
That test-only flag selects the real launcher and expects a visible failure while
retaining the draft. Do not disable apps on the founder's retained demo device.
Neither mode sends mail or proves delivery; native composer cancellation with a
configured account and native iOS handoff still need their own device checks.
