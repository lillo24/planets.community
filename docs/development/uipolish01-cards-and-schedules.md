# UIPOLISH01 cards and schedules

Project cards and Template Workshop catalog cards use a measured, card-only
`CompactSkillPreview`. It accepts resolved display names, shows at most three in
one row, and reserves a final `...` only for hidden skills. Project cards retain
their required-first stable order; Workshop cards retain catalog order. Skills,
importance and IDs are unchanged. The parent card owns the action, including the
overflow marker. Full skill names remain accessible; details retain importance.
Skill localization belongs to UIPOLISH02.

`EventSchedule` renders canonical public dates in their saved event timezone.
Same-day schedules have one localized date with year and a prominent time range;
multiday schedules have vertical Start/End endpoints. Missing dates stay honestly
undecided, and confirmed Idea dates do not change phase. The shared time helpers
show UTC offsets when a DST transition would make the clock endpoints ambiguous.
Tavolo schedule metadata and every existing occurrence reuse this visual language
without changing recurrence, lifecycle, duration or timezone.

## Reproduction and evidence

The focused widget tests use finite constraints, including Project and Workshop
cards in EN/IT, light/dark, 320/360/412 logical pixels, and 1x/2x text. They check
row geometry, no overflow/first-frame height jump, full semantics, priorities,
card taps, detail completeness, same-day/multiday schedules, year/month crossings,
event-local dates, DST and undecided dates. Existing card assertions changed only
where the requested preview/schedule presentation supersedes them.

Commands from `apps/mobile`:

```text
flutter test test/core/widgets/compact_skill_preview_test.dart test/core/widgets/event_schedule_test.dart test/features/proposals/presentation/uipolish01_cards_test.dart
flutter drive -d emulator-5584 --disable-dds --host-vmservice-port=62023 --driver integration_test/uipolish01_driver.dart --target integration_test/uipolish01_smoke_test.dart --dart-define=UIPOLISH_BEFORE=true
flutter drive -d emulator-5584 --disable-dds --host-vmservice-port=62023 --driver integration_test/uipolish01_driver.dart --target integration_test/uipolish01_smoke_test.dart
```

The before run uses an exported copy of the latest-main implementation base
`6b6f9bc` with the same synthetic capture fixture. The after run uses the
implementation checkout. The task-owned Android API 36 emulator is
`PLANETS_UIPOLISH_QA` / `emulator-5584`; no shared database or installed founder
application is used. Screenshots exercise scrolling and card taps, but do not
claim live backend validation. The driver writes to
`%TEMP%/planets-uipolish-runtime`.

The repository-wide affected check is `npm run check:mobile` from the repository
root. Native captures cover Italian 360px/light/1x and 320px/dark/2x; the broader
locale/theme/width matrix runs in widget tests. Physical Android, iOS and a
release/app-store build are outside this validation. No release or hosted
deployment occurs. The separate Drafts loading failure is unchanged.

Both final native runs passed their two scenarios (plus binding teardown), with
scrolling, card taps and no framework layout exceptions. The initial probe used
placeholder IDs rejected by the parser; the fixture now uses deterministic UUIDs.
A completed assertion run then lost its driver connection on port 5586; replay
on fully booted port 5584 with DDS disabled completed capture collection. These
were fixture/transport issues, not backend validation. The final baseline replay
used `--no-pub --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk`.

The 51 focused preview/schedule/card tests and 41 affected regression tests passed.
Static analysis passed after the final fixture corrections. An existing Tavolo
participation assertion now deliberately scrolls to its target because structured
schedule surfaces take more vertical space; the expected capacity is unchanged.

| Surface       | 360px light 1x before                                                   | After                                                                 | 320px dark 2x before                                                    | After                                                                 |
| ------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Project card  | [Before](evidence/uipolish01/uipolish01-before-360-1x-project-card.png) | [After](evidence/uipolish01/uipolish01-after-360-1x-project-card.png) | [Before](evidence/uipolish01/uipolish01-before-320-2x-project-card.png) | [After](evidence/uipolish01/uipolish01-after-320-2x-project-card.png) |
| Schedule      | [Before](evidence/uipolish01/uipolish01-before-360-1x-schedule.png)     | [After](evidence/uipolish01/uipolish01-after-360-1x-schedule.png)     | [Before](evidence/uipolish01/uipolish01-before-320-2x-schedule.png)     | [After](evidence/uipolish01/uipolish01-after-320-2x-schedule.png)     |
| Template card | [Before](evidence/uipolish01/uipolish01-before-360-1x-template.png)     | [After](evidence/uipolish01/uipolish01-after-360-1x-template.png)     | [Before](evidence/uipolish01/uipolish01-before-320-2x-template.png)     | [After](evidence/uipolish01/uipolish01-after-320-2x-template.png)     |
