# Member contact native review harness

This is synthetic review coverage for D-M02. The candidate lifetime policy remains
review-only until the founder decision recorded by the parent implementation is
resolved. Source compilation and intermediate screenshots do not constitute a
completed native run or approval of that policy.

`apps/mobile/integration_test/prepare_member_contact_smoke.mjs` creates three real
local OTP identities: a Group owner and two ordinary participants, Alice and Bob.
They have no photos or delegated authority. All three origins are published
through canonical Group commands, and participant invitations are explicitly
accepted. Only the synthetic profile names use fixture SQL. There are no seeded
member request/message rows, service-role sessions, changed clocks or cooldown
bypasses. Separate origins permit independent Close, Leave and context-loss
checks for the same named pair.

Run fixture preparation from the checkout whose uncommitted Supabase config and
selected container engine identify the **owned disposable stack**. The helper
reads `supabase status` from that working directory; the disposable flag does not
select or isolate a stack. Set its Mailpit URL explicitly. Preparation rejects
non-loopback services and requires a defines file inside OS temporary storage,
outside the checkout. Never print, commit or attach that file: it contains actual
short-lived local Auth JWTs.

The native/database owner alone runs the following commands, substituting the
owned engine, API/Mailpit ports and emulator. For the D review stack, the API and
Mailpit ports are 55321 and 55324. Finish cold database image downloads and checks
before starting the emulator on a memory-constrained host.

```powershell
$env:CONTAINER_CONNECTION='planets-d-qa-root'
$env:DOCKER_HOST='npipe:////./pipe/podman-planets-d-qa'
$env:MAILPIT_URL='http://127.0.0.1:55324'
$env:PLANETS_DISPOSABLE_QA='1'
node apps/mobile/integration_test/prepare_member_contact_smoke.mjs "$env:TEMP/planets-member-native-defines.json"
adb -s emulator-5580 reverse tcp:55321 tcp:55321
adb -s emulator-5580 shell wm size 720x1600
adb -s emulator-5580 shell wm density 360
adb -s emulator-5580 shell settings put secure show_ime_with_hard_keyboard 1
cd apps/mobile
flutter drive -d emulator-5580 --no-dds --no-pub --driver=test_driver/member_contact_screenshots.dart --target=integration_test/member_contact_smoke_test.dart --dart-define-from-file="$env:TEMP/planets-member-native-defines.json"
```

For a memory-limited host, use the process-local Gradle limits and serial
build/device procedure in [the representative harness guide](group-contact-mobile.md).
Build with `--target=integration_test/member_contact_smoke_test.dart` and the
member defines, then preserve the result as `build/native-review/member-contact.apk`.
Drive that exact prebuilt file with `--use-application-binary` and the member
driver/target above. Each build replaces `app-debug.apk`; distinct ignored copies
prevent accidentally driving the other test target. Rebuild after any source or
fixture change. The APK also contains private fixture tokens and must be removed
with the temporary defines after QA.

The test asserts the actual device width is 320dp and injects 2x text scaling
through the test platform dispatcher. Every saved checkpoint asserts that the
rendered route received those dimensions and that no Flutter layout exception
occurred. The production app, router, language preference and localization are
used throughout. English and Italian frames come from the same real screen,
after loaded content has replaced progress indicators. The screenshot driver
writes PNGs under ignored `apps/mobile/build/member-contact-screenshots` and
retains failure response data.

Keyboard frames additionally require a real positive bottom view inset. Enable
the owned emulator's software keyboard as above; no keyboard geometry is faked.
Visibility waits scroll the page rather than a text field's inner viewport, and
save a failure frame if the required action never becomes visible.

A visible message body is not proof that its read frontier was rendered: a tall
incoming card also has a timestamp and Report action below the body. After
revealing the body, `member_contact_read_frontier.dart` drags the actual history
through the card end. It checks the current actor and non-null server boundary,
foreground route, resumed lifecycle, enabled ticker and settled history extent
before the unchanged canonical unread-zero assertion. It never calls ACK or
moves the scroll controller directly. Bounded retries allow lazy dimensions to
settle; a failure logs eligibility/scroll metrics without opaque tokens and saves
a diagnostic frame. The 320dp/2x widget regression confirms that body visibility
alone does not ACK and that scrolling through the end acknowledges the exact
boundary. This simulated regression does not replace the real backend run.

The member chat uses the actual resized SafeArea body constraints: contextual
notices scroll within one quarter of its height, and the anchored composer scrolls
within at most half. This reserves visible history even with the keyboard, long
origin names and 2x text. The production-screen EN/IT widget regression uses
320×711 geometry and a 300dp keyboard inset, sends a three-line draft, then verifies
that frozen-response recovery remains reachable above the keyboard without a
second send. It failed with a 65px overflow before the bounded layout change.
These simulated-inset checks supplement the required real native keyboard frames;
they do not replace them or certify a completed native journey.

The complete journey verifies:

- Group detail → private canonical People → compact named sheet → contextual
  request composer. Opening/editing sends nothing. A single real committed
  submission deliberately loses its transport response; recovery resolves that
  original request without a second submit.
- Recipient Requests inbox → named detail → informed explicit Accept. Opening
  the confirmation still leaves the request pending. No Group authority grants
  the owner access to the pair's request or conversation.
- Accepted human message → Private inbox, distinct from Groups. Settings and
  mute preserve unread; the visible foreground conversation acknowledges its
  bounded message frontier. Both people send through the actual composer.
- Info mute, Block confirmation, retained read-only history and rejected blocked
  sending, followed by explicit unblock. Close and Leave each end their own
  episode while preserving history; ending one origin leaves the other active.
- The actual Group Leave UI removes the last origin relationship, terminates its
  episode and rejects stale sends. A fresh canonical participant invitation is
  accepted for rejoin; People becomes accessible but the old chat stays read-only
  with no composer. Other shared Groups never revive that origin.
- A known incoming historical message remains reportable after context loss.
  The actual moderation form uses the exact message target, and the persisted
  own-report projection is verified through its v4 reader.

Accounts are switched by unmounting the app and disposing the previous provider
scope/client. Initial UI identity is supplied by the shared
`contact_local_identity.dart` adapter, paired with the genuine OTP JWT and real
policy store. Domain gateways call the actual backend. The only injected network
failure occurs after a successful request RPC response. Local fixture identities
do not represent coverage of typing an OTP into the login screen.

Create fresh fixtures and choose an unused temporary filename for each run; the
preparer refuses to overwrite an existing file. Successful evidence requires the entire driver
to exit successfully and visual inspection of its final PNGs, including keyboard,
accept/exit/block dialogs, muted settings and read-only history in both languages.
Record the tested commit and actual result in the final D integration evidence.
Remove the private defines file after QA; restore or dispose only the task-owned
emulator/stack according to the native owner's cleanup procedure. Android review
evidence does not imply iOS, physical-device or production-provider validation.
