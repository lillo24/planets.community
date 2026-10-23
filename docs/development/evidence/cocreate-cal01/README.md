# CAL01 calendar qualification

These PNGs are actual Flutter widget renders with Roboto/Material fonts and
fictional contract fixtures. They are not live backend, emulator or physical
device screenshots. Backend evidence comes from separate genuine OTP/HTTP and
database checks.

The populated month/day agenda, full session and already-attending states were
captured at EN 320dp light and IT 360dp dark, each at 1× and 2× text. Empty day,
backend error and unavailable admission use an EN 320dp viewport. All remain
scrollable. The selected month/day and useful scroll position are tested through
a real delayed refresh after attendance review. Full dates/status words have
accessible semantics; mixed days show separate available/full markers.

Inspected images include:

- `cal01-month-320-en-1x-light.png`: month, selected day and 4/7 versus full cards.
- `cal01-month-360-it-2x-dark.png`: large Italian labels, date/time and offset.
- `cal01-full-320-en-2x.png`: selectable full meeting and wrapping status copy.
- `cal01-attending-it-2x.png`: separate attendance status and full session.
- `cal01-empty-day.png`: a genuinely empty selection and upcoming agenda.
- `cal01-backend-error.png` / `cal01-access-unavailable.png`: explicit failures
  and discarded protected markers/rows, with no empty-success substitution.

Actual local validation:

| Check                                              | Result                                                                           |
| -------------------------------------------------- | -------------------------------------------------------------------------------- |
| Clean canonical migration/seed replay              | Pass                                                                             |
| Complete pgTAP                                     | 172 files / 8,336 assertions pass                                                |
| New calendar pgTAP                                 | 50 assertions pass, included above                                               |
| Genuine calendar OTP/HTTP                          | 65 assertions pass                                                               |
| Existing community/meeting HTTP                    | 113 assertions pass                                                              |
| Populated CAL01 migration rehearsal                | 195 tables, 550 installed functions and six warmed readers preserved             |
| Query-plan fixture                                 | Actual reader query uses chronological date index over 3,000 historical meetings |
| Complete Co-Creation mobile suite                  | 213 tests pass                                                                   |
| Final calendar contract/route/widget checks        | 15 tests pass; includes delayed return/scroll, frozen recovery and realm fencing |
| Existing native router/navigation checks           | 77 tests pass                                                                    |
| Mobile analysis                                    | No issues                                                                        |
| Root tooling tests                                 | 181 pass                                                                         |
| Web consumer typecheck                             | Pass                                                                             |
| Public database type generation after fresh replay | Matches the reviewed generated file                                              |
| Database lint and security advisors                | No schema errors / no issues                                                     |

The [database summary](database-qualification.json) records the exact migration
hash, preserved object counts, warmed nine-/eleven-field contracts, actual index
names and measured plan timing. This is a bounded local diagnostic, not a
production latency guarantee. Its fixture and DDL changes all roll back.

The calendar HTTP fixture proves an actual two-actor last-place race, exact
receipt recovery without duplicate chat membership, decline reopening a place,
expired recruitment versus still-future member confirmation, eligible repost
deduplication, signed complete pagination, blocking/suppression and unchanged
message ACK state. SQL additionally covers frozen General frontiers, actual
cross-hub/foreign-episode rejection, private cardless meetings, category/policy
loss, past/cancelled lifecycle and experiment OFF. Mobile checks use device-local
month/year/leap/DST boundaries and fence month/account/realm replacements.

The existing test fixture gained controllable policy loss and a fresh gateway
on invalidation so those authorization boundaries can be exercised; existing
expectations remain unchanged. Calendar date glyphs stay on one line under broad
font metrics while the agenda retains unrestricted large text. These checks
caught and repaired that layout case before delivery.

Regenerate the PNGs from `apps/mobile`:

```text
flutter test --no-pub --concurrency=1 --reporter expanded --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/cocreate-cal01 test/features/co_creation/co_creation_calendar_test.dart test/features/co_creation/co_creation_calendar_flow_test.dart
```

The [feature runbook](../../cocreate-cal01-calendar.md) gives database/HTTP
reproduction commands and the explicit disposable-rehearsal opt-in. The local
project is `planets-cal01-qa`; private CLI credentials/diagnostics are excluded
from Git. An initial local container/Auth timeout was recovered before successful
OTP qualification. Windows tooling used the bundled Python on process PATH for
the existing release artifact test; no project dependency or global setting
changed.

No physical Android/iOS installation, native screen-reader journey or hosted
Mock-broker journey is claimed. Existing Mock seed/persona data is unchanged.
No hosted migration, experiment activation, hosted seed, production deployment
or app installation is performed by this change. Required GitHub CI and
[independent staging eligibility](../../staging-auto03-verified-policy.md)
remain separate from these local results; owner fingerprint comments are no
longer an authorization path.
