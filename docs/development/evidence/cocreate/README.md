# Co-creation A00/A01 rendered evidence

These are Flutter widget captures with real fonts, not physical-device or live
backend evidence. The source tests cover EN/IT, light/dark, 320dp and 1x/2x.
Home additionally uses a short 320×480 viewport at 2x; it scrolls to each pillar
and verifies the correct route. All shown content is explicitly fictional.

Inspected captures:

- `home-it-light-320-2x.png`: scrollable Home, Co-Creation preceding the saved
  Activities Split choice; all three destinations tested.
- `posts-en-dark-320-2x.png`: labelled Demo discovery with wrapping controls.
- `group-en-dark-320-2x.png`: separate member-chat preview and history disclosure;
  remaining content scrolls below the viewport. No real admission or transcript.

Regenerate from `apps/mobile`:

```text
flutter test --no-pub --concurrency=1 --dart-define=UI_POLISH_CAPTURE_DIR=<absolute-output-directory> test/features/co_creation/co_creation_demo_test.dart
```

No Android/iOS device, installation, screen-reader or founder phone QA is
claimed. See [the progress ledger](../../cocreate-progress.md) for actual stage
status and backend qualification. No production deployment occurred.
