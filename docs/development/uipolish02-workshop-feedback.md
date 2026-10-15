# UIPOLISH02 Workshop feedback and controlled skill labels

`core/localization/skill_display.dart` maps the 24 seeded skill slugs and IDs,
plus seven category slugs, to EN/IT resources. The catalog audit found only the
original seed in `20260902192101_basic_profiles_skills_visibility.sql`; no later
catalog mutations were found. Unknown entries keep their canonical label. The
resolver does not match English text or change stored data, IDs, importance,
payloads or backend matching. Generic tag widgets remain unchanged. Profile and
contribution-picker callers explicitly opt into the same display mapping; user
text and resource titles remain canonical. Complete detail names wrap at large
text sizes, while cards reuse UIPOLISH01's single-row preview.

The Workshop now has concise introductory copy, explicit card metadata spacing
and a shared Filters disclosure. Collapsing it preserves query/skills and issues
no request. The existing picker-route-return revalidation is retained, along with
debounce, reset, cursor, paging and account-generation rules.

## Outcome and acknowledgement contract

Frozen application attempts and confirmed destination IDs stay in the existing
app-scoped `TemplateApplications`. `TemplateFeedback` separately holds opaque
request IDs, presentation acknowledgements, opening state and read outcomes in
RAM. It stores no copied content and never mutates or deletes an application.

| Outcome                                  | Presentation / action                                                                        |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| No attempt                               | No notice                                                                                    |
| Applying                                 | Creating feedback; no claim of an existing draft                                             |
| Unknown acknowledgement                  | Unconfirmed outcome and explicit Retry of the frozen request                                 |
| Confirmed creation                       | Brief Draft created, exact Open draft and Dismiss confirmation                               |
| Successful editor read                   | Acknowledge discovery feedback; retain explicit detail Open and separate Start another draft |
| Navigation/transport failure             | Truthful reopening error; retain exact destination                                           |
| Canonical owner read absent or forbidden | Account-scoped unavailable explanation, with explicit retry; no deletion claim               |

The optional `ProposalEditorReadObserver` follows the ordinary editor's existing
load. Only a successful read for its exact actor/destination acknowledges the
handoff. Route push/pop, saving, a receipt or an unrelated owner projection do
not prove that read succeeded. Application epochs reject stale callbacks and
account ABA; signed-out/other-account attempts are not displayed or opened.
Covered routes retain late receipts without taking navigation from the active
screen. A later explicit Open still targets the same destination.
An empty canonical owner result and explicit `42501` are distinguished from
transport/configuration failures. Ordinary editor behavior is unchanged.

Confirmed creation can be dismissed without losing its receipt. Unresolved
creation attempts cannot be dismissed into another creation. Lost or failed
receipt lookup still recovers/replays the same immutable actor, token, options,
group and request ID. Process restart drops RAM context, not the saved backend
draft. Nothing here proves that the independent Drafts list currently loads.
That separate failure remains unchanged and visible.

## Validation and reproduction

Focused checks cover the existing controller/recovery suite, actual editor
handoff/back/re-entry, same-draft reopening, dismissal, busy taps, lost
acknowledgement, failed receipt read and exact replay, navigation failure,
transport failure and recovery, removed/forbidden destinations, wrong returned
destination, sign-out, account switches and stale callbacks. Creation command count
and frozen request tuples are asserted. The locale matrix covers known/unknown
labels, unchanged IDs/importance, Project/Workshop cards, complete details,
recovery notices, filter toggles, reset and keyword debounce with keyboard inset
at 320/360/412px, EN/IT, light/dark and 1x/2x text.

From `apps/mobile`:

```text
flutter test test/core/localization/skill_display_test.dart test/features/template_workshop/application/template_controllers_test.dart test/features/template_workshop/presentation/template_workshop_test.dart test/features/template_workshop/presentation/uipolish02_feedback_test.dart test/features/template_workshop/presentation/uipolish02_layout_test.dart
flutter drive -d emulator-5584 --disable-dds --host-vmservice-port=62023 --driver integration_test/uipolish01_driver.dart --target integration_test/uipolish02_smoke_test.dart --dart-define=UIPOLISH_BEFORE=true
flutter drive -d emulator-5584 --disable-dds --host-vmservice-port=62023 --driver integration_test/uipolish01_driver.dart --target integration_test/uipolish02_smoke_test.dart
```

The before run uses exported main `a53768ae3f2204666c348c28f7b77773533a871b`
with the same synthetic fixture. The after run uses the implementation checkout.
Both exercise the task-owned Android API 36 `PLANETS_UIPOLISH_QA` emulator,
Italian 360px/light/1x and 320px/dark/2x, scrolling, real IME-open app viewports,
catalog/detail and creation/uncertain feedback. The shared screenshot collector
from UIPOLISH01 writes to `%TEMP%/planets-uipolish-runtime`. These are synthetic
UI runs, not live backend or successful Drafts-list validation.

Run `npm run check:mobile` at the repository root for affected formatting,
analysis and the full mobile suite. Initial probes corrected assertions that
assumed a permanently visible filter and that tried tapping the removed Use
button while its frozen retry was busy. Filter disclosure request counts are
checked separately from existing picker-route revalidation. No real user data,
shared database reset, migration, hosted deployment or release is involved.
Physical Android and iOS checks and release/store builds were not run.

The final combined focused command passed all 81 tests. Both final native runs
passed two scenarios plus binding teardown and produced twenty nonempty captures.

Captures are in [`evidence/uipolish02/`](evidence/uipolish02/), with
`before/after`, width, text scale and surface in each filename.

| Surface           | 360px light 1x before                                                | After                                                              | 320px dark 2x before                                                 | After                                                              |
| ----------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Catalog           | [Before](evidence/uipolish02/uipolish02-before-360-1x-catalog.png)   | [After](evidence/uipolish02/uipolish02-after-360-1x-catalog.png)   | [Before](evidence/uipolish02/uipolish02-before-320-2x-catalog.png)   | [After](evidence/uipolish02/uipolish02-after-320-2x-catalog.png)   |
| Detail            | [Before](evidence/uipolish02/uipolish02-before-360-1x-detail.png)    | [After](evidence/uipolish02/uipolish02-after-360-1x-detail.png)    | [Before](evidence/uipolish02/uipolish02-before-320-2x-detail.png)    | [After](evidence/uipolish02/uipolish02-after-320-2x-detail.png)    |
| Keyboard viewport | [Before](evidence/uipolish02/uipolish02-before-360-1x-keyboard.png)  | [After](evidence/uipolish02/uipolish02-after-360-1x-keyboard.png)  | [Before](evidence/uipolish02/uipolish02-before-320-2x-keyboard.png)  | [After](evidence/uipolish02/uipolish02-after-320-2x-keyboard.png)  |
| Created           | [Before](evidence/uipolish02/uipolish02-before-360-1x-created.png)   | [After](evidence/uipolish02/uipolish02-after-360-1x-created.png)   | [Before](evidence/uipolish02/uipolish02-before-320-2x-created.png)   | [After](evidence/uipolish02/uipolish02-after-320-2x-created.png)   |
| Unconfirmed       | [Before](evidence/uipolish02/uipolish02-before-360-1x-uncertain.png) | [After](evidence/uipolish02/uipolish02-after-360-1x-uncertain.png) | [Before](evidence/uipolish02/uipolish02-before-320-2x-uncertain.png) | [After](evidence/uipolish02/uipolish02-after-320-2x-uncertain.png) |
