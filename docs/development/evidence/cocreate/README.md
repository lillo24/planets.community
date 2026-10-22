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

B02 adds people-live-detail-en-320-2x.png and people-live-detail-it-320-2x.png.
These render the real mobile detail component with a deterministic gateway
contract fixture, real fonts and 2x text at 320dp. The fixture public text is
synthetic English user content in both locales; labels/consent/actions localize.
The Italian capture was visually inspected: body/consent wrap, Report and the
sign-in continuation remain reachable by scrolling, with no overflow. These are
widget render evidence, not phone screenshots or a claim of a live UI session.
The genuine two-account backend is separately verified through OTP/RPC tests.
