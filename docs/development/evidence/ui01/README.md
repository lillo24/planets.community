# UI01 rendered evidence (2026-10-12)

72 PNGs are actual Flutter widget-test engine renders with the SDK Roboto and Material fonts, the app theme and synthetic repository gateways. No provider requests, hosted database operations or physical devices were used.

- 16 Manage Project frames: EN/IT, light/dark, 1x/2x text, empty/populated workspace.
- 24 Manage organizers frames: the same matrix, plus scrolled invitation frames.
- 32 Proposal editor frames: create/published edit, EN/IT, light/dark, 1x/2x, at the Time & Place and location/directions sections.

Captures are 320 x 800 logical pixels. Editor assertions also cover 800px width. At large text sizes the menu omits redundant chevrons to give translated labels space; all rows remain tappable with their leading icons. Scroll tests exercise controls below the viewport. The optional directions hint replaces the long floating input label; its separate optional heading and privacy text remain visible.

Reproduce from `apps/mobile`:

```powershell
flutter test --no-pub --dart-define=ORG_UX01_CAPTURE_DIR=../../docs/development/evidence/ui01 test/features/project_delegates/presentation/project_organization_layout_test.dart --name '(manage|team) (en|it)'
flutter test --no-pub --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/ui01 test/features/proposals/presentation/proposal_editor_test.dart --plain-name 'UI01 Time & Place'
```

Location tests separately verify empty/manual/provider/unknown canonical text, selection clearing and restoration, foreground and identity invalidation, existing manual fallback saves and protected directions. Unknown legacy or older-server provenance keeps credits; UI01 does not classify old data or deploy the previously merged provenance migration.

Visual review covers all frames. Physical Android/iOS, TalkBack/VoiceOver, live authenticated provider flows and real clipboard handoff remain unrun.
