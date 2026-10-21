# ACTSPLIT01 Activities Split Mode

Activate **Settings > Sandbox > Activities Split Mode** (Italian: **Modalità
Progetti / Attività**). This public setting is available signed out and in release
builds. It defaults to off and is saved on this installation, independently of
the account and of the existing Messages/Browse shortcut. Turning it off is the
rollback; it changes no domain records or onboarding status.

With the mode on, Home exposes Projects, Activities and Scambio-Dona. Projects
continues to `/proposals`; Activities opens `/activities` in the existing Browse
branch. The top choice becomes Projects/Activities. Existing Tavoli URLs,
invitations, details, join/auth continuations, management, Groups and drafts
remain native. The real Tavoli list is reached from All/Culture, keeps its own
pagination and errors, and labels its map as Tavoli-only. No map exists for
examples. Native location filters and provider activation are unchanged.

The Trento catalogue contains 12 fictional, bilingual local examples: nine
sports and three cultural activities. Categories are All/Sports/Culture;
disciplines derive from fixtures. Search and disciplines filter examples only.
Events show explicit example dates; courses and recurring sessions show weekly
times or “Schedule to confirm,” never an inferred “today.” Cards and details
label their example origin. Missing covers use text cards rather than fetched
stock imagery. There are no organizers to contact, sign-ups, bookings or fake
successful submissions, and the examples make no coverage/availability claim.

`planets.sandbox.activitiesSplit` stores `on`/`off` through the typed Settings
store/controller. Missing or unknown strings restore off. Bootstrap restores it
before first presentation. A failed read restores off with a Settings recovery
message; failed writes retain the previous choice and offer Retry. Overlapping
writes are rejected. Sign-out does not erase the choice. Experiment-only routes
redirect to normal discovery while off. Preference changes refresh the existing
router rather than replacing it or its retained protected forms. Tutorial replay
uses explicit baseline presentation controls and does not overwrite the mode.

## Validation and evidence

Final local checks (2026-10-19):

- `flutter gen-l10n` and `dart format --output=none --set-exit-if-changed lib test test_support`: passed (718 files, no formatting changes).
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub test/app test/bootstrap test/features/settings test/features/activities_sandbox test/features/geographic_discovery`: **395 passed**. This includes the broader shared-router, default tutorial, replay, map/cache and Settings regressions, not just new widgets.
- `flutter build apk --debug --no-pub --target-platform android-x64 --dart-define-from-file=config/local.json --dart-define=ENABLE_DEMO_TOOLS=false`: passed. The initial multi-architecture Android debug build also passed. Existing Android toolchain/plugin warnings remain unrelated to this UI experiment.
- The implementation PR's required Mobile CI runs the complete mobile suite before merge. No database, ingestion or unrelated web integration suite is needed for these paths.

The initial full local run exposed issues in the new test harness (scrolling to a lazily built target and disposing semantics handles); these were corrected and the final scoped run above is green. Typography matrices use the repository's existing real SDK font setup, rather than placeholder glyph metrics. The full final-head suite is enforced by hosted Mobile CI.

Rendered and visually inspected Flutter captures use real fonts and deterministic gateway fixtures. Both Messages/Browse shortcut choices were exercised. The archived widget frames are 800×600, plus Italian 320dp at 2× text; English and Italian both pass at 320dp/1× and 2×, including semantic selected states. Captures are opt-in using the existing `UI_POLISH_CAPTURE_DIR` Dart define; normal CI writes no images.

| Scene                     | Evidence                                                                                                             |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Sandbox off / on          | [Off](evidence/actsplit01/widget-sandbox-off.png), [On](evidence/actsplit01/widget-sandbox-on.png)                   |
| Home on                   | [Three entries](evidence/actsplit01/widget-home-on.png)                                                              |
| Activities All            | [Native entry and examples](evidence/actsplit01/widget-activities-all.png)                                           |
| Sports search             | [Example-only results](evidence/actsplit01/widget-sports.png)                                                        |
| Example detail            | [Read-only provenance and schedule](evidence/actsplit01/widget-example-detail.png)                                   |
| Native Tavoli destination | [Existing list/actions and scoped map](evidence/actsplit01/widget-native-tavoli.png)                                 |
| Restored off              | [Baseline Home](evidence/actsplit01/widget-restored-off.png)                                                         |
| Italian 320dp / 2×        | [All](evidence/actsplit01/widget-italian-320-2x.png), [Sports](evidence/actsplit01/widget-italian-sports-320-2x.png) |

These are rendered widget-test frames, not evidence of physical-device or live-backend QA. Native testing was attempted on a disposable read-only `PLANETS_API_36` emulator (`emulator-5584`), including a smaller-memory cold-boot retry. Android System UI became unresponsive before usable app navigation: [system dialog evidence](evidence/actsplit01/android-system-ui-anr.png). The test emulator was stopped. Physical Android `48091FDAS0041A` was not connected; iOS QA was not available on this Windows host.

Remaining native smoke on a healthy emulator or that authorized physical device: verify off/on in public Settings, exercise both bottom-right choices, inspect Home/All/Sports/one example detail, return through native Tavoli, restart to confirm the stored choice, and switch off to restore baseline navigation. Native sign-out persistence and live backend join/manage actions were not manually exercised here; controller/router tests cover those boundaries. This is code completion and local Android build validation, not an app-store deployment.

## Boundaries and next work

No migration, backend deployment, ingestion service, production source
integration, real submission workflow, billing change or app-store deployment
was added. The taxonomy is a view-local experiment, not a competence catalog or
production activity schema. Fixtures cannot make native membership/chat writes
and never enter native models, providers or caches. Native backend failure is
not converted into example “results.”

A future ingestion plan needs permitted sources and explicit reuse rights,
freshness/availability semantics and real organizer/submission decisions. No
external account, credential or source is required to evaluate this experiment.

ACTAPI01's [source checkpoint](actapi01-source-checkpoint.md) verified live
official municipal JSON on 2026-10-21 but stopped on unresolved event-text reuse
permission. The real-catalogue pipeline is not implemented; these examples
remain fictional and must not be described as imported results.
