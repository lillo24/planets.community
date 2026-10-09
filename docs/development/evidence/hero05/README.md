# HERO05 Welcome and Home comparison

Base: TUT04 merged at `a30e3eae434398e52465de21205ea101e60ba293`.
Flutter 3.47.2 / Dart 3.13.2; Android API 35, task-owned Pixel 6 emulator.
The native harness uses real application/router/widgets with deterministic fake
gateways, English, normal motion, and a completed tutorial preference. It makes
no hosted database calls. Debug captures establish appearance, not performance.

The same harness captures Welcome and Home at 360×740 and 412×915, light/dark,
before and after. Selected pairs are retained here:

| Surface | Before | After |
| --- | --- | --- |
| Welcome, 360 light | [before](hero05-before-360-light-welcome.png) | [after](hero05-after-360-light-welcome.png) |
| Home, 360 light | [before](hero05-before-360-light-home.png) | [after](hero05-after-360-light-home.png) |
| Welcome, 412 dark | [before](hero05-before-412-dark-welcome.png) | [after](hero05-after-412-dark-welcome.png) |
| Home, 412 dark | [before](hero05-before-412-dark-home.png) | [after](hero05-after-412-dark-home.png) |

Recorded widget geometry with the same English locale, normal text and chrome
(logical pixels; Home clearance conservatively includes the far planet's full
9.2px halo even when its current angle is elsewhere):

| Measurement | Before | After |
| --- | --- | --- |
| Welcome center / available SafeArea height, both portraits | .270 | .400 |
| Explore / Login height, both portraits | 48 / 48 | 60 / 60 |
| Home orbit center Y, 360×740 | 194.8 | 194.8 |
| Home orbit center Y, 412×915 | 230.8 | 230.8 |
| Home halo-to-first-card clearance, both portraits | 0.8 | 24.8 |

Lower star visibility was limited by occlusion and entrance-coordinate wrapping:
Home sampled its full painter, including opaque cards. It now samples only the
backdrop above the first card, with seeded irregular lower weighting. Welcome
settles onto the weighted coordinates rather than wrapping the lower concentration
back toward the top. Counts remain proportional and capped at 100, coordinates
cached and deterministic. Tests require at least two stars in Home's new visible
halo-to-card zone and over 65% in a representative backdrop's lower half.
Farewell retains its original uniform map, geometry and continuous travel.

The 24-case layout matrix covers both languages at 360×740, 412×915, 320×640,
740×360 and 1×/1.5×/2× text. Additional checks exercise keyboard-reduced space,
real Login, Projects/Scambio actions and Help, full halo bounds, reduced motion,
continuous orbital periods and lifecycle pauses. Compact/scaled screens reclaim
the extra Home reservation; Welcome adapts below the nominal 40% target when the
actions consume its canvas.

Reproduce native captures (the `HERO05_BEFORE` define labels a build of the base;
it does not switch production code):

```powershell
flutter drive -d <owned-emulator> --driver=test_driver/tutorial_screenshots.dart --target=integration_test/hero_layout_smoke_test.dart
```

Host PNGs are written under `apps/mobile/build/tutorial-screenshots`. The full
mobile gate passed 1,918 tests with two existing skips. After the final Home
padding adjustment, 124 focused hero/startup/tutorial/Help tests and targeted
analysis passed. Integration sources are formatted and compiled by the Android
build. No physical Android, iOS or assistive-technology QA is claimed.
