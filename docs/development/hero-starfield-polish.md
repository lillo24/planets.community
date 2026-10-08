# Starfield and Home hero polish

Implemented from `PLANETS_UI_polish_starfield_and_home_centering.md`, starting
at `5cfcdd14331f003b5cf3b5e92cb1c2bcd62d9878` on `codex/ui-starfield-home`.
Before the PR, this was rebased onto merged CT-01 at
`4421f08c9969fdc3fee85678ddd881b23828034f`.
This change owns only mobile artwork and its Home layout; no backend, demo data,
dependencies or release configuration are changed.

The old 18 modular-sequence dots formed repeated apparent alignments. The shared
starfield now uses seeded continuous 2D sampling with minimum separation, modest
radius/opacity variation and mostly faint stars. Density is one star per 2,400
logical square pixels, bounded to 8–100. Generation has at most 64 candidates per
star and retains four size maps. Seed `0x504c414e` reproduces the same map after
eviction, rebuild or route recreation; orbit ticks do not move stars. Welcome's
existing finite entrance drift is preserved.

Home previously combined a `.62` logo-area Y with a negative 6% parent offset.
The vertically centered, shrink-wrapped scroll viewport also excluded the gap
between the actual body top and the content column. Home now fills that viewport
while keeping the cards in their existing centered positions. Its painter extends
up through the gap; the reservation H is the distance from the body top below
AppBar/SafeArea to the first card, including 24px scroll padding and column
centering space. The full composition centers at `(width / 2, H / 2)`.
The far-ring radius plus a 10px halo allowance fits both half-width and half-H;
the logo leaves 14px on either side of short reservations, including its 6px
upward float. This also holds at 320×480 with 2.5× text and reduced motion.

Welcome retains its original 27% settled center and entrance. Help, tutorial,
navigation, opaque/tappable Home cards, orbit colors and 12/16/18-second periods,
8-second float and lifecycle/route/viewport/reduced-motion pausing are unchanged.

## Validation

Focused tests cover deterministic positions, cache eviction, responsive density,
spread and variation, fixed stars across orbit time/rebuild/route recreation,
actual body-to-card geometry, halo bounds, card navigation, startup and Help.
All 87 focused tests passed on the integrated base. Standard mobile localization
generation and formatting (557 files), explicit capture-harness formatting,
Flutter analysis and diff whitespace checks also passed.
Run from `apps/mobile`:

```powershell
flutter test test/core/widgets/planets_hero_test.dart test/app/foundation_screen_test.dart test/app/startup/interactive_tutorial_test.dart test/app/startup/startup_navigation_test.dart test/features/help/help_flow_test.dart
flutter analyze
dart format --output=none --set-exit-if-changed lib test test_support integration_test/hero_polish_smoke_test.dart
```

The backend-free Android harness uses fake gateways and installation preferences.
It restores its fixture explicitly because this harness bypasses real bootstrap;
it then captures Welcome and Home and asserts no preference writes or exceptions.
Reproduce using the existing screenshot host driver:

```powershell
flutter build apk --debug --no-pub --target=integration_test/hero_polish_smoke_test.dart
flutter drive --no-pub -d <isolated-device> --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --driver=test_driver/tutorial_screenshots.dart --target=integration_test/hero_polish_smoke_test.dart
```

On 2026-10-08, the debug build and native capture journey passed on the separately
created `PLANETS_HERO_QA_API35` Android 15 / API 35 Pixel 6 at 1080×2400,
using Flutter 3.47.2 / Dart 3.13.2. Both final frames were visually inspected:

- [Home](evidence/hero-polish/hero-polish-home.png): the entire composition sits
  between the actual AppBar/body boundary and first card, with halos clear of
  both boundaries and the three AppBar actions intact.
- [Welcome](evidence/hero-polish/hero-polish-welcome.png): richer irregular stars
  behind the existing large hero at its unchanged position.

The initial capture exposed the scroll viewport's excluded centering gap;
the layout and body-boundary regression were corrected before these final
captures. An earlier harness-only failure was fixed by restoring the startup
fixture before Explore. These captures use controlled light-theme fixtures;
light/dark and large-text/reduced-motion layouts are covered by widget tests.
This is emulator visual evidence, not a physical-device motion check.
Captures preceded the CT-01 base integration; the rebase changed no artwork or
Home implementation, and the focused tests and analysis were rerun afterwards.
The task emulator was stopped and deleted after capture; shared devices and
the founder's demo database were untouched.

The existing path classifier selects Mobile; unaffected
Database/Web/Site jobs remain skipped. Final-head Mobile CI is required for merge.
Native iOS, physical-device motion and TalkBack/VoiceOver remain unverified.
