# CAL01-FIX01 correction evidence

Qualified on 23 October 2026 against the CAL01-installed predecessor
`fef1c343501a43712f997aca269a09ca6f245b75`, using the task-owned loopback project
`planets-cal01fix-313`. No shared or hosted database was used.

## Regressions

- **F01:** [refresh regressions](../../../../apps/mobile/test/features/co_creation/co_creation_calendar_refresh_test.dart)
  cover 27 meetings and a later selected day after timer, connected hint and review
  return; fresh occupancy/removal, delayed append coalescing, scope restart, access
  loss, inactive/hidden response fencing and foreground resume. A 127-meeting
  fixture plus three earlier inserts proves the four-page cap and practical
  continuation without losing the old frontier or duplicating rows.
  Socket loss clears protected rows immediately while retaining fresh authorized
  HTTP polling when metadata delivery remains unavailable.
- **F02:** [recruitment review tests](../../../../apps/mobile/test/features/co_creation/co_creation_recruitment_test.dart)
  exercise ineligible direct entry, eligibility loss/recovery and exact frozen
  Join retry after the card fills. The calendar flow independently rechecks
  eligibility after navigation. The [SQL](../../../../supabase/tests/162_cocreate_calendar.test.sql)
  and [real HTTP verifier](../../../../scripts/lib/cocreate-calendar-verifier.mjs)
  distinguish full chat and membership limits from meeting seats, reject forged
  actor/episode scope, preserve historical frontiers, and prove direct command
  denial without reader-created attendance/membership or message ACK.
- **F03:** SQL and real authenticated HTTP cover both block directions, exact
  current episodes, active attendance, decline/retry, current nonattendees,
  temporary creator unavailability, ended episodes, newcomer denial and
  suppression. Reinstalling the predecessor calendar body made five of these
  assertions fail; the corrected source passes them.
- **F04:** The refresh test enables semantics and invokes the date node's actual
  semantic tap action, asserting selected date and changed agenda. EN and IT run
  at 2x text scale and preserve full-date and mixed available/full descriptions.

The initial mobile fixtures also failed against predecessor presentation source
for lost later pages, lifecycle hints, viewer eligibility and missing semantic
tap. Tests awaiting an intentionally delayed response use bounded pumps: the
new serialized controller no longer discards that operation on a timer tick.

## Local qualification

- Clean canonical migration/seed replay: passed.
- Numbered groups, recruitment, meeting and calendar pgTAP: **4 files / 539
  assertions**, including **79** calendar assertions.
- Calendar real OTP/HTTP: **98 assertions**, including the genuine last-seat
  race, receipt retry, blocking/review/decline and separate eligibility checks.
- [Populated forward upgrade](database-qualification.json): **196 tables, 555
  installed public functions and seven warmed readers** preserved. Calendar
  OID, signature/defaults, ACL, stability, definer context and fixed search path
  remain unchanged; its envelope and old signed continuation still work.
  Installed nine-/eleven-field cards remain closed. Repeated body installation
  preserves data/contracts. The actual query uses the chronological index over
  3,000 synthetic historical meetings. All rehearsal changes roll back.
- Database lint/security advisors: no schema errors or issues.
- Public database types regenerated from the replayed source; only the new
  review RPC is added. Web consumer typecheck passed.
- Latest combined-main verification also passed the map/calendar SQL pair
  (**124 assertions**), 98 calendar HTTP assertions and regenerated-type comparison.
  Its [upgrade summary](database-qualification-current-main.json) preserves
  **198 tables / 557 other public functions**, including the independently merged
  map objects, while using the same immutable CAL01 reader predecessor contract.
- Complete Co-Creation and native router suites: **308 tests passed**. Root
  tooling: **343 tests passed**. Affected Dart/Markdown/JavaScript formatting
  and whitespace checks passed. Representative render tests also passed.

The complete mobile/router and tooling checks, analysis and required GitHub
checks are reported with the implementation PR. The repository's independent
hosted eligibility check remains separate from source validation.

## Rendered review

These are fictional contract fixtures rendered by Flutter, not live backend or
device screenshots. Inspected examples:

- [Later-page selected day after refresh](later-day-refreshed.png): the removed
  meeting is absent and Group 27's fresh full state remains on the selected day.
- [Ineligible recruitment review](ineligible-review.png): spare meeting seats
  remain visible, with localized unavailability wording and no ordinary Join.
- [Ordinary available/full calendar](available-and-full.png),
  [attending](attending.png), and [IT dark/2x](calendar-it-dark-2x.png).

Reproduce renders from `apps/mobile`:

```text
flutter test --no-pub --concurrency=2 --dart-define=UI_POLISH_CAPTURE_DIR=../../build/cocreate-cal01-fix01/renders test/features/co_creation/co_creation_calendar_refresh_test.dart test/features/co_creation/co_creation_calendar_flow_test.dart test/features/co_creation/co_creation_recruitment_test.dart
```

Actual TalkBack/VoiceOver and physical Android/iOS QA were not run. No hosted
migration, experiment activation, Mock seed, app installation or store release
is performed by this task. Optional meeting places and map work remain deferred.
