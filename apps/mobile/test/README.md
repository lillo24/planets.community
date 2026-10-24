# Mobile tests

Feature and application widget tests exercise the app with deterministic gateways
from `support/`; `core/` covers shared presentation and utilities.

`flutter_test_config.dart` defaults widget tests to the platform reduced-motion setting.
Functional route/interaction tests can then use `pumpAndSettle` without waiting
for the continuously animated PLANETS branding. This changes only the test
platform, not application behavior. Pure unit suites keep their normal binding
and HTTP environment.

`core/widgets/planets_hero_test.dart` explicitly enables motion and uses bounded
fake-time pumps to verify the website's circular orbit periods, directions,
starting angles and logo float, together with pause/resume and rebuild behavior.
Animation-specific tests must opt in this way rather than wait for an endless
animation to settle. `app/foundation_screen_test.dart` checks card readability
and interaction across theme, narrow-screen and large-text configurations;
`app/startup/` covers Welcome, logout, Auth and external routing.

`support/android_text_font.dart` loads Roboto from the pinned Flutter SDK's
`bin/cache/artifacts/material_fonts/roboto-regular.ttf` using `FLUTTER_ROOT`, which
`flutter test` supplies. Whole-profile narrow/keyboard layout tests use Android
text metrics instead of Ahem's synthetic toolbar widths. Missing SDK font setup
fails explicitly. These remain widget checks, separate from native screenshots.
