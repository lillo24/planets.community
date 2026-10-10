# TUT06 Project collaboration before Scambio

Captured 2026-10-10 from this PR's Flutter source, based on `3645f8d62a2038466f369bc32b73dcda844ab87c`.
IDEA01A #201 and IDEA01B #204 were already merged before this work began.
The tour also tests a published Idea with no dates, timezone or city.

The twelve states are introduction → Home Projects → Project card → detail /
participation → Create → Drafts → fictional Project group chat → Messages
Requests → Messages Private/Groups → Home Scambio-Dona → Scambio listing /
Create / My listings → farewell. `interactive-2` remains unchanged: completed
or dismissed installations are not re-onboarded; Help replay uses the new order.

## Actual Android captures

Task-owned read-only session of `PLANETS_PLAY_ASSETS01`, API 35 Google APIs
x86_64, serial `emulator-5584`, 1080×1920 at 480dpi (360×640 logical pixels),
1.0 text scale, light theme, Flutter 3.47.2 debug. The integration target uses
the actual app/router/widgets with fake gateways and an in-memory startup store.
It requires no database or hosted account. The emulator was closed after capture.

- Fictional mural conversation: [English](tut06-english-projectGroupChatExample.png)
  / [Italian](tut06-italian-projectGroupChatExample.png). All three messages fit
  in the observed normal phone view; expanded text can scroll. The pinned example
  label and bounded conversation viewport have separate intentional spotlights.
- Next, [Messages Requests](tut06-italian-messagesTabs.png) and the
  [Private/Groups selector](tut06-italian-messagesScopes.png).
- Then [Home Scambio entry](tut06-italian-homeResources.png) and
  [Scambio's listing/Create/My listings targets](tut06-italian-resources.png).

These are settled native emulator screenshots. Frame-level widget tests, rather
than these static images, verify the unobscured first look, intermediate page
fade, same-page Messages opacity and interrupted focus movement.

Reproduce from `apps/mobile` on an isolated, task-owned emulator:

```powershell
flutter drive --no-pub -d <owned-emulator-id> --driver=test_driver/tutorial_screenshots.dart --target=integration_test/tutorial_chat_sequence_test.dart --dart-define=TUT06_SCREENSHOTS=true
```

The driver writes all ten EN/IT captures under `build/tutorial-screenshots`.
Six representative originals are included here without image manipulation.

## Validation and boundaries

- `npm run mobile:l10n` and `npm run check:mobile`: formatting, analysis and
  full Flutter suite; 2,146 passed, two existing tests skipped.
- Final focused startup tests: 63 passed, including the exact forward/reverse
  narrative, EN/IT 320dp layouts at 2x text in light/dark, semantics, keyboard
  traversal/Enter, reading scroll, rotation, reduced motion and fade regressions.
- Final native integration: both English and Italian complete journeys passed.
- Tests verify empty Message and Project-chat gateway calls/subscriptions during
  the tour, no sample in ordinary guest/authenticated Messages or real Project
  chat, and disposal after first-run/replay Skip, Back, navigation and account
  replacement. The standalone conversation tests mount without a ProviderScope.

The fictional Giulia/Marco/Sara conversation is local presentation only. It
accepts no Project/chat ID or identity, mounts no live chat/controller, loads no
photos, persists no messages and offers no composer or product action. Its mural
title does not imply membership in the Project/Idea inspected earlier.

Physical Android/iOS, manual TalkBack/voice operation, live-backend membership
and hosting/deployment QA were not run. Widget semantics/keyboard evidence and
fake-gateway emulator evidence do not establish those outcomes. No database,
staging, Play, signing, map-provider or production deployment was changed.
