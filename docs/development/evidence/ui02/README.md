# UI02 rendered evidence

These 48 PNGs come from actual Flutter widgets with the SDK's Roboto and
Material fonts and deterministic fictional test data. They are not design
mockups or physical-device screenshots.

- `needs/`: 32 frames across Creator/Co-creator, EN/IT, light/dark, 1x/2x text;
  captures the skill area and the scrolled materials area at 320 x 800dp.
- `manage/`: 16 hub frames across EN/IT, light/dark, 1x/2x and empty/populated
  workspace states. Tests scroll the whole menu and exercise authorized routes.
- The same needs tests assert 800dp layouts, permission separation, independent
  material failures, canonical importance persistence and unsaved departure.

All five contact sheets were visually inspected. Headings, grouped navigation,
separators, translated actions and selector importance remain readable; large
text scrolls vertically. A selected skill also has its full label beside its
importance selector when the selection chip abbreviates. The materials screen
retains its established history and action styling.

Reproduce from `apps/mobile` (replace the absolute capture path):

```powershell
flutter test --no-pub --dart-define=UI_POLISH_CAPTURE_DIR=C:/path/evidence/needs test/features/proposals/presentation/proposal_needs_screen_test.dart
flutter test --no-pub --dart-define=ORG_UX01_CAPTURE_DIR=C:/path/evidence/manage test/features/project_delegates/presentation/project_organization_layout_test.dart --plain-name 'manage '
```

Results: 42 needs tests and 16 rendered menu tests passed with real fonts.
Normal full mobile validation: 2,652 passed, two existing skips, format/analyzer
clean. Full web validation: 355 Vitest tests passed, two existing skips, 97
Node tests passed, typecheck/lint/Next and invitation builds passed.

A separate task-owned synthetic Chrome harness compiled and was hot reloaded.
No physical phone, manual TalkBack/voice, hosted provider or account session was
used. Local database execution was unavailable due Docker Desktop startup;
PR CI supplies isolated migration/security/concurrency and type-generation proof.
See the [contract and limitations](../../ui02-skills-resources.md).
