# TUT07 guided navigation and captions

Captured 2026-10-15 from this PR's source based on `87f3983`, Flutter 3.47.2 debug.

The tutorial now demonstrates real discovery controls with a decorative 220ms
press cue and a 300ms directional slide/fade. The destination replaces the outgoing
widget at the midpoint, so only one live preview subscribes at a time. Progress
and caption switch with that destination. Previous and the return from detail
reverse direction. Create/Drafts and Messages focus changes preserve scrim alpha.

The Projects list holds meaningful content still for one second, then eases out
toward the chosen card before revealing its spotlight. Choice follows visible,
filtered Requested-first order: third with a usable cover, otherwise the first
other covered card, otherwise third/first. At most two cover checks have a 600ms
download/decode deadline each. Selection is frozen for the run; there is no extra
page fetch. The caption uses a translucent gradient/panel and opaque theme text.

## Reproduce native sampling

The isolated `PLANETS_TUT07_QA` emulator uses API 36 Google APIs x86_64, serial
`emulator-5592`, 640×1440 at 320dpi (320×720 logical pixels), normal text scale,
English, light/dark themes.
Fixtures provide three public Projects and bundled cover bytes to the actual
router/widgets. No hosted backend, account or production data is involved.

From `apps/mobile`, with that task-owned emulator running:

```powershell
flutter build apk --debug --no-pub --target-platform=android-x64 --target=integration_test/tutorial_guided_transitions_test.dart
$env:ANDROID_SERIAL = 'emulator-5592'
$env:TUT07_EVIDENCE_DIR = '<absolute-output-directory>'
flutter drive --no-enable-impeller --no-dds --no-pub --keep-app-running --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --driver=test_driver/tutorial_guided_transitions.dart --target=integration_test/tutorial_guided_transitions_test.dart -d emulator-5592
```

The driver rejects any other serial. It pulls native PNGs and writes `frames.json`
with observed time, page opacity, scrim alpha, hole count and list offset. The
integration target also writes incremental `tut07-frames.json` in the app cache
for diagnostics if a capture fails before the driver callback.

The capture target uses animation `timeDilation=8` to sample short transitions
despite native screenshot readback latency, and `100` only during image acquisition
to keep the sampled ticker frame almost stationary. Timers retain wall-clock behavior;
observed timestamps are sampling records, not production latency measurements.
Widget tests verify production duration, dwell and intermediate incoming/outgoing
frames with the normal animation clock. Capture uses the test-only Skia runtime
flag after this software emulator's default Impeller/GLES screenshot readback
aborted in `blit_pass_gles.cc`; the application renderer configuration is unchanged.

## Reviewed native frames

The final native run passed and recorded 46 frames. These contact sheets resize
the original 640×1440 PNGs to 320×720 and add frame/measurement labels; their
contents are otherwise unchanged:

- Light: [press, travel, hold and browse scroll](light-sequence-1.png),
  [detail, return, captions and same-page movement](light-sequence-2.png).
- Dark: [press, travel, hold and browse scroll](dark-sequence-1.png),
  [detail, return, captions and same-page movement](dark-sequence-2.png).
- [Original frame measurements](frames.json).

Inspection found the selected cover/title above Create, no spotlight during
browse movement, stable settled focus and readable light/dark captions. Every
sampled same-page frame retains scrim alpha 0.62. Long Create copy remains in its
bounded scroll pane with navigation visible. Readback can miss a short subphase:
the dark series includes incoming Home/list and card/detail frames; widget tests
assert both halves at the production animation clock. The task emulator was
stopped after capture.

## Automated coverage and limits

The focused startup tests cover cover-aware selection, failed/late covers,
Requested filters, empty/small feeds, frozen detail identity, single live surface,
manual pacing, rapid taps, reverse travel, page/focus opacity, reduced motion,
Skip/Back/pause/resize/account replacement/disposal, keyboard focus barriers,
IT/EN, light/dark, 320dp, 2× text, landscape, semantics and caption scrolling.
Existing tests retain public/private gateway barriers, replay and completion
behavior. `interactive-2` is unchanged.

Final local validation passed all 62 focused tutorial tests, including the wide
cover decode regression, keyboard traversal, account replacement and disposal.
The local `npm run check:mobile` completed localization, formatting and analysis,
then was stopped after an existing location-editor test failed at
`location_editor_session_test.dart:116` (`suggestions.single` after a one-second
wall-clock receipt deadline). Its isolated file rerun also failed that case
(14 passed, one failed). That unrelated test and its implementation are unchanged;
the PR's Mobile CI check records the complete-suite result separately.

Native captures use synthetic public fixtures and cannot establish live-backend,
physical-device, iOS, TalkBack or production frame-performance outcomes. Those
checks were not run. There are no backend/schema, credentials, release, Play,
signing or deployment changes. The implementation plan requires explicit direction
before merging this PR.
