# C-R07 Android evidence

Passed: all 41 native checkpoints and the complete driver exited 0 (2m23s app test). Driver window: 2026-10-20 13:48:11.9933665–13:50:59.5086266 UTC. Debug APK SHA-256: `367251cae0e766fb32aacbcd6ef1c4c8786ded3f760d0fe567c4feaef2cfe0cb` (build 248.6 s).

Runtime source: `56e657ed6694fdff3e10bb8cf4a063a3781f05c2`, including product
consent correction `2ee7a995340e932bb6322c08b5699e7e6aca062e`, the bounded Project layout repair and main
`32f37791b11f759adfe4b61c2cdd1b600fdf84f2`. Subsequent qualification commits add tests, verifier assertions, documentation and these evidence files only; runtime Mobile sources and migrations remain identical. D was unmerged and was
not imported or simulated.

The 41 originals are real Android screenshots from one completed run of
`group_discussion_smoke_test.dart` and `discussion_conversion_journey.dart`.
The historical `c02-` filename prefix belongs to the reused screenshot driver;
these are revised-C R07 frames, not copied C02/C04 evidence.
The inherited `empty-frontier-en` checkpoint now explicitly requires visible
pre-admission messages; its old filename is not an empty-history claim.
`manifest.json`
records every original's dimensions and SHA-256. All modification times were
checked against this run's start before copying; a mixed set from partial runs
cannot satisfy that check. All seven contact sheets and critical full-size consent, former-history, audience, large-text and Project-origin frames were inspected. Content clipped by a bounded viewport remains scrollable; widget regressions separately exercise full warning, tools and composer reachability. The owned AVD and all eight C backend services were stopped afterward; ADB and the C runtime inventory were empty.

## Environment and reproduction

Flutter 3.47.2 / Dart 3.13.2; Android API 36 Google APIs x86_64 on emulator
37.2.12, 2 cores / 2048 MiB, owned AVD `PLANETS_C_QA` on `emulator-5582`. The actual display is
960×1920 at density 480 (320×640dp); the harness exercises EN/IT, text scale 1.0
and 1.8, light and dark. The Vulkan-disabled emulator launch is recorded as an
environment choice, not a proven explanation for the earlier host crash.

Only C's isolated `planets-c-qa` backend, Podman machine `planets-c-revision`,
explicit connection and loopback ports 60320–60329 were used. The external CLI
workdir contains synchronized source migrations/tests; hashes matched all 104
migrations and 145 SQL test files. It does not use the default shared stack.

From the C checkout, with its task-owned CLI environment, disposable loopback
configuration, `MAILPIT_URL` and `PLANETS_DISPOSABLE_QA=1`:

```text
node apps/mobile/integration_test/prepare_group_discussion_smoke.mjs <private-defines.json>
# From apps/mobile; stop backend/emulator while building on this host:
flutter build apk --debug --target=integration_test/group_discussion_smoke_test.dart --dart-define-from-file=<private-defines.json>
# Restart only the owned backend and emulator, wait for a responsive launcher:
adb -s emulator-5582 reverse tcp:60321 tcp:60321
flutter drive --driver=test_driver/groups_screenshots.dart --target=integration_test/group_discussion_smoke_test.dart --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --device-id=emulator-5582 --no-dds
```

Record the UTC start before the driver, require exit 0, then validate all 41
literal checkpoint names against their fresh output modification times,
960×1920 dimensions and hashes. Inspect every contact sheet and critical full
frames before publishing. Private defines, tokens, raw logs and the APK are not
committed.

## What the journey establishes

- Targeted invitation title/purpose/audience/sender before explicit acceptance,
  no pre-acceptance transcript, full earlier history afterward; committed lost
  send reply recovered with one command/message, stable older-page history and
  exact retained former boundary after a later message.
- Messages/Group entries, Idea and Group named links, automatic General, empty
  and populated Group workspace, per-account dismissible guidance, manager mute,
  all-member creation, ordinary member restricted Idea, disclosed oversight
  without admission, hide/show and large-text dark folders in both languages.
- Propose/review, actual publisher-owned private draft and ordinary publication;
  one planner declines, another opens without enrollment and deliberately sends
  the normal Project Join request. Canonical organizer approval activates chat.
- Public newcomer sees Project chat without a planning origin or even a private
  source-history request; entitled planner opens frozen planning and returns to
  Project chat; author and decliner retain only their independent rights. Selected
  source-link sharing uses the real review/confirmation UI and verifies exactly
  one canonical Project workspace link after confirmed completion. Lost-reply
  and remount recovery are separate automated widget/Auth evidence.

## Setup and limits

The setup script prepares fictional real OTP identities, ready profiles/photos,
canonical Group relationships, a pending Idea invitation and separate conversion
source. The app restores those verified starting identities; this does not test
signup/profile/photo-picker UI. Requests, admission, publication and most actions
use actual UI and canonical RPCs. Organizer approvals and the public newcomer's
Join request use genuine authenticated API clients. No service credential grants
client access. Deliberate transport faults occur after actual server acceptance.

Continuity is the permitted linked read-only planning view plus ordinary Project
chat, with separate history authorization; it is not an interleaved timeline.
Project return frames can show the existing live-update-unavailable warning.
The run does not establish uninterrupted Realtime or the cause of that warning.
External URL launching uses the injected recorder; storing/signposting a link
does not grant Google, WhatsApp or Telegram access, and no real external app
handoff, provider invitation or permission was exercised.

Physical Android, iOS, TalkBack and real FCM/APNs delivery remain unrun. No hosted
migration, deployment or store upload occurred. The qualification report and
PR #257's final checks/merge/closeout identify the final published source and
owned cleanup; historical failed attempts are recorded separately there.
