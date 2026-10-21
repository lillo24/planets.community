# SCHED01 compact calendar and date-only compatibility gate

The independent read-only calendar changes are implemented. Date-first editing
and date-only publication are not implemented by this change; the APPVER01
compatibility prerequisite below must ship first. No migration or hosted
operation is included.
The SCHED01 implementation prompt requires this PR to remain open for review.

## Implemented responsibility

`apps/mobile/lib/core/widgets/event_schedule.dart` owns the public exact-time
calendar used by Project and Tavolo details. Same-day intervals use one localized
date and a clock range. Multi-day intervals put the two date/time endpoints beside
an arrow at ordinary widths, or stack them for narrow/large-text layouts.
Screen-reader semantics retain explicit Start/End labels; visible labels do not
repeat them. Unknown canonical logistics remain unknown.

`core/time/event_time.dart` continues converting canonical instants into the
saved event timezone. Differing endpoint offsets remain explicit (including a
repeated DST hour). A different viewer/device UTC offset gets a readable zone
abbreviation and offset; locale is never used to infer timezone. The raw IANA
line is removed from Tavolo detail. Recurrence and occurrence instants, card
summaries, authoring, membership and server rules retain their existing meaning.

## Resolved admission rule

The founder confirmed on 21 October 2026: a date-only Project stops accepting new
requests at midnight **after its final selected local day**, in its saved event
timezone. That is an admission boundary, not an invented event end time. Future
implementation must keep the public clock explicitly unconfirmed, calculate the
boundary from local calendar dates with timezone/DST rules, and test both sides
of that midnight. It must not claim that an activity Happened or Completed at an
invented hour.

## Compatibility prerequisite and evidence

Existing Defined-Project readers cannot represent a date-only record:

- `features/proposals/data/proposal_gateway.dart` requires non-null `starts_at`,
  `ends_at` and a known derived status for a public Defined Project. Nullable
  schedule fields currently belong to the separate Idea contract.
- `private.assert_defined_proposal_publishable` requires exact ordered instants.
  `private.lock_project_for_participation` and other canonical admission and
  lifecycle consumers use the exact end timestamp.
- CHECK01 schedule proposals/confirmation require finite ordered instants;
  confirmation alone makes logistics official. Private planning must never
  become public simply because a reader accepts date-only fields.
- Strict/legacy public and owner readers, map discovery, status/order filters,
  template completion, invitations, notification timing and web/share readers
  must be audited with a new representation. Supplying placeholder midnight
  instants would silently change these contracts and is prohibited.

The founder rejected hiding Projects from older readers and requested a separate
minimum-supported-version prerequisite (APPVER01). New Android clients should
prefer Google's native Immediate Update flow; iOS should link to its verified
App Store listing. A server-controlled startup policy can block update-capable
clients, but cannot retroactively add that check to already-installed versions.
Play Console Recovery tools can prompt those older Android installations without
new code; that prompt is dismissible and is not a backend compatibility barrier.

Safest order: preserve current exact-time contracts, ship the update-capable
client while minimum floors remain inactive, verify replacement availability on
every supported store/track/region, use authorized recovery prompts for older
Android releases, and only activate minimum floors after the replacement is
reachable. Date-only publication must remain disabled until its separate backend
compatibility/cutover safeguard is reviewed and tested. Native update completion
or a reported app version never substitutes for server authorization. APPVER01
alone is not evidence that all old installations have upgraded.

SCHED01 explicitly permits delivery of the independent calendar with a precise
blocker. Root AGENTS.md assigns consequential public-contract and central-flow
choices to the founder. The compatibility prerequisite is now explicit; this PR
adds no incomplete date-only
mutation, no unpersisted date-first form, and no fabricated UTC values.

## Validation and rendered review

`flutter test test/core/widgets/event_schedule_test.dart
test/features/proposals/domain/proposal_time_test.dart
test/features/proposals/presentation/proposal_flow_test.dart
test/features/proposals/presentation/proposal_idea_test.dart
test/features/recurring_activities/presentation/recurring_activity_flow_test.dart`
validates the changed calendar and its detail consumers. The first attempted
command included a nonexistent `test/core/time` path; the corrected command
passed all 64 tests. Eight further rendered-layout cases cover EN/IT, light/dark,
390dp ordinary text and 320dp at 2x text. DST folds/gaps, cross-midnight/year,
unknown logistics, screen-reader endpoints and foreign zones are included.
The complete Flutter suite passed 3815 tests with 2 skipped. Localization
generation, formatting (826 files unchanged), and static analysis passed.

Optional reproducible PNG capture uses
`--dart-define=SCHEDULE_CAPTURE_DIR=<absolute-output-directory>` and
`--dart-define=SCHEDULE_FONT_DIR=<flutter-sdk>/bin/cache/artifacts/material_fonts`
on `test/core/widgets/event_schedule_test.dart`. The fonts are required only for
readable captures, not ordinary tests. Captures use test fixtures, without live
backend calls or personal data. Native Android/iOS and TalkBack/VoiceOver review
remain unrun; no active debug app was available for hot reload.
