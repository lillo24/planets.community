# TUT05 native transition and finale evidence

Captured 2026-10-09 on the task-owned Android API 35 Google APIs x86_64 emulator
`PLANETS_NAVUI01_TUT05_QA_API35`, serial `emulator-5586`, 720×1600 at 280dpi,
Flutter 3.47.2 debug. Actual app widgets/router run with deterministic fake public
gateways and an in-memory startup store; no hosted records or real messages.

Before: finished NAVUI code `ea8862746bd933c0d03c98dde568816b942bac0c`.
After: `867f011d92ad50c70cd87bcc1d55da39b46a4e70`, based on merged NAVUI01
`e6f4fcba597316a660db2ca2e8228430a9da84ad`, also retaining the independent MAP01
shared-tile update. No map/cover/theme implementation was changed by TUT05.

## Confirmed flicker cause

On the same Projects or Messages surface, `_move` reset `_reveal.value` to zero
and cleared targets even though its keyed page stayed mounted. Both light and
dark baseline probes show alpha **0.62 → 0 → 0.62** on Next, Previous and rapid
Previous/Next. The after probe holds **0.62 throughout**, with one moving hole.
Explanation reflow also resized the preview and cleared its mask; a frame-level
regression caught this secondary focus discontinuity. The visible hole now stays
until its new real anchor is measured. Page opacity and focus geometry use
independent clocks; 16ms widget samples verify actual intermediate rectangles,
interruption, lifecycle pause/resume and an unfinished fade remaining monotonic.

- Same-page Create→Drafts and Requests→selector, [before light](before-light.jpg)
  / [after light](after-light.jpg), [before dark](before-dark.jpg)
  / [after dark](after-dark.jpg).
- Actual Home→Projects, Detail→Browse, Home→Scambio and Scambio→Messages,
  [light](page-transitions-light.jpg) / [dark](page-transitions-dark.jpg): new
  content first, then measured holes and intermediate fade frames. The approved
  600ms content hold and 380ms fade remain; Scambio retains three disjoint holes.
- [80 before samples](before-frames.json) and [103 after samples](after-frames.json)
  include rapid Previous/Next frames. After samples record observed elapsed time.

These are sampled native composites, not a frame-time benchmark. Numeric suffixes
identify requested pump increments; screenshot acquisition adds wall time and
can lag a committed Flutter frame. Intermediate page fades are sampled adaptively
after content/anchor readiness. Deterministic widget tests supply exact first-frame
and timing assertions; native images show no full-page colour inversion in the
observed transitions. The host's debug pointer markers are test instrumentation.

## Examples and farewell

The actual tour shows a labelled fictional [Private row](light-example-private.png)
then a [Groups row](light-example-groups.png), with corresponding
[dark Private](dark-example-private.png) / [dark Groups](dark-example-groups.png)
captures. Placeholder avatars, invented copy and fixed relative timestamps are
pure presentation. Samples are inert, have no unread counts, expose their Example
label to semantics, and never mount private list/inbox/photo readers. Both guest
and ready tutorial identities are covered by provider-isolation widget tests.
Ordinary signed-out Chats adds the example beside honest sign-in guidance; ready
inboxes keep their actual loading/empty/error/content states without samples.

Farewell uses **21–36 integer crossings per 144-second phase**, or **4.00–6.86s
per radius-padded traversal**, replacing 2–4 crossings / 36–72s. Six native samples
with one-second pumps ([light](farewell-light.jpg) / [dark](farewell-dark.jpg))
show clear movement, compared with the [before light](farewell-before-light.jpg)
/ [before dark](farewell-before-dark.jpg) samples; total wall time includes capture overhead. Larger stars are
gently faster. Seed, positions, count, size, orbit/logo/entrance timing and ordinary
Home/Welcome motion stay unchanged. Tests cover the 144s seam, offscreen bounds,
4–7s speeds over long runs, static reduced motion and lifecycle pause.

## Validation and reproduction

- `npm run check:mobile`: localization, format, analysis, **1,992 tests passed**,
  two existing skips, after integrating main/NAVUI01. Final native-capture-only
  adjustments passed another analysis and debug build; final interpolation
  assertions passed their focused widget tests.
- Final native `tutorial_visual_probe_test.dart` and host driver exited **0**
  (one full light/dark journey plus teardown). Earlier screenshot-payload and
  driver-connection failures were recovered and are not counted as passing runs.
- EN/IT 320dp/200%, reduced motion, offline/empty feeds, real first Project,
  participation scrolling, Previous/Next/Back, replay/account changes and no
  private preview reads are automated widget coverage. Native capture is EN,
  ordinary text, guest; ready/IT/accessibility cases are not native-device proof.
- Native iOS, physical Android, TalkBack/VoiceOver and release performance remain
  **unverified**. No deployment or database validation was needed for this scope.

From `apps/mobile`, with a verified task-owned emulator:

```powershell
$env:ANDROID_SERIAL = 'emulator-5586'
$env:TUT05_EVIDENCE_PHASE = 'after'
$env:PATH = "$env:LOCALAPPDATA/Android/Sdk/platform-tools;$env:PATH"
flutter build apk --debug --no-pub --target-platform=android-x64 --target=integration_test/tutorial_visual_probe_test.dart
flutter drive --no-dds --no-pub --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --driver=test_driver/tutorial_visual_probe.dart --target=integration_test/tutorial_visual_probe_test.dart -d $env:ANDROID_SERIAL
```

The probe writes PNGs to its own Android app cache, clears screenshot byte arrays
from the VM response, and returns small metadata. The driver pulls those files
with `adb exec-out run-as` before teardown into `build/tut05-after`. This avoids
returning dozens of PNG arrays in one VM-service response. For a baseline, copy
only the probe/driver onto an isolated predecessor checkout, build with
`--dart-define=TUT05_BEFORE=true`, and set the phase to `before`. Do not run this
harness on a retained founder/shared device. Full raw local captures are generated;
this folder retains reviewed contact sheets, original example PNGs and metadata.
