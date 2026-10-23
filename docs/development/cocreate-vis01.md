# COCREATE-VIS01: planetary interests introduction

Implemented on `codex/cocreate-vis01`, dependent on the experimental Co-Creation
integration PR [#287](https://github.com/lillo24/planets.community/pull/287).
The inspected/rebased dependency is `15180d53fdd54624f86484b3caf815202ae41d8a`.
This focused PR targets `codex/cocreate-runall`, not `main`, and must remain
unmerged for visual review as required by the VIS01 plan. It does not merge #287.

## Behavior and access

Enable **Settings > Sandbox > Co-Creation Mode**, then open **Trova persone /
Find people** from Home. The first ordinary `/people` entry presents a six-second
native Flutter illustration. Explore and Skip are immediately usable; completion
does not navigate. The browse info action **Replay intro / Rivedi introduzione**
pushes `/people/intro` and returns to the same search, filters and scroll state.

Only automatic presentation writes installation-local boolean
`planets.coCreation.interestsIntroSeen.v1`. It is independent of identity,
backend activation, Activities Split and the startup tutorial's completion/version
key. OFF→ON preserves it. Deep links and query-bearing continuations bypass the
automatic introduction. Existing Messages and exit routes keep their authority.
Storage failures are surfaced after the frame without blocking discovery.

Replay needs no reset. For first-entry QA use a fresh disposable installation or
the injectable preference store in the tests. Clearing app data also resets other
installation preferences, including the startup tutorial. No reset control or
interest collection was added to the product.

Board games (Fuso, Lupus in Fabula), concerts (The Strokes, Måneskin) and video
games (Valorant) are illustrative text. They create no topics, communities,
memberships, requests, notifications, analytics, backend records or partnerships.
The illustration uses the existing PLANETS logo, three brand-colored planets,
faint orbits and deterministic star accents, with no dependency or asset download.

Reduced motion shows the settled composition with no ticks. Background,
covered-route and TickerMode changes pause the finite clock and preserve phase.
One static accessible description replaces the animated label semantics. The body
scrolls at narrow sizes/large text, decorative artwork shrinks, and actions stay
outside the scroll region with at least 48dp touch height.

## Rendered evidence

The Flutter widget harness produced eleven PNGs. Inspected representative frames:

- [Initial, 320×740, English/light](evidence/cocreate-vis01/intro-en-light-initial.png).
- [Labels in flight at 1.8 seconds](evidence/cocreate-vis01/intro-en-light-in-flight.png).
- [Settled at six seconds](evidence/cocreate-vis01/intro-en-light-settled.png).
- [Italian/dark, 320×480, 2× text, scrolled](evidence/cocreate-vis01/intro-it-true-2.0x-static.png).

The eight static captures cover EN/IT × light/dark × 1×/2× text at 320×480.
They are scrolled to the last interest, demonstrating wrapped examples and
accessible actions. The timing captures show the full regular-size composition.
These are rendered widget tests, not physical-phone recordings.

## Validation

Run from `apps/mobile`, using Flutter 3.47.2 / Dart 3.13.2:

| Command                                                                                                                                                                                   | Result                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `flutter pub get`                                                                                                                                                                         | Passed; pinned lockfile unchanged                     |
| `flutter gen-l10n`                                                                                                                                                                        | Passed for both languages                             |
| `dart format --output=none --set-exit-if-changed lib test test_support`                                                                                                                   | Passed, 925 files unchanged                           |
| `flutter analyze --no-pub`                                                                                                                                                                | Passed; no issues on the final implementation         |
| `flutter test --no-pub test/features/co_creation test/features/settings test/app test/core/widgets/planets_hero_test.dart --reporter expanded`                                            | Passed, 406 tests                                     |
| `flutter test --no-pub --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/cocreate-vis01 test/features/co_creation/people_interests_intro_test.dart --reporter expanded` | Passed, 24 tests and eleven captures                  |
| `flutter build apk --debug --no-pub`                                                                                                                                                      | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check`                                                                                                                                                                        | Passed                                                |

Tests exercise initial/staggered/final frames with fake time; immediate Skip and
Explore; completion without navigation; disposal without ticks; background,
TickerMode and popup visibility; reduced motion; localized/scaled semantics and
layout; first/subsequent entry and fresh-container restoration; replay/Back and
live filter retention; OFF mid-view and OFF→ON; protected destinations; stale
preference restore; and synchronous read/asynchronous write failure. The actual
app-router test uses fake gateways with the experiment backend unavailable; it
does not claim a live backend journey.

An earlier regression run found synchronous storage failure attempting a snackbar
during build. Preference loading now starts after the frame, and the new failure
test exercises synchronous rejection. An initial broad capture run also exposed
an unrelated Resource-draft test's real-font/capture layout sensitivity; that test
passes with standard settings. Capture is scoped to VIS01, and the complete
affected 406-test run passes without capture. Existing tests were not changed.

The Android build emits existing native-access and sentry_flutter/share_plus KGP
compatibility warnings; no dependency was upgraded for this presentation task.
Physical Android/iOS QA and an iOS build were not performed on this Windows host.
No deployment, store upload, hosted migration or production activation occurred.
