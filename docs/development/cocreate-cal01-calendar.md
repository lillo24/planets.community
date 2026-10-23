# Community calendar (COCREATE-CAL01)

Open **Find people → Communities → a named community → Calendar / Calendario**.
The device's Find People preference and the canonical server experiment gate
remain independent and unchanged. Calendar entry never enrolls a viewer.
Guests use the existing authentication and deliberate community admission flow.

The compact month view has previous/next and Today controls. Selecting a day
shows its chronological agenda. An empty day also shows upcoming meetings in
that month. Meeting cards show group number, device-local date/time with UTC
offset, meeting occupancy and an explicit viewer/availability status. Green
places and red full states include words and day semantics. Mixed days retain
both markers. Already-attending and unavailable recruitment are separate states.
Full meetings remain selectable for review.

## Canonical read and privacy

`get_cocreate_calendar_v1` is an authenticated, actor-bound reader. Its scope is
one hub, one exact admitted General room/episode and a half-open UTC window.
Both instants must be finite, ordered and at most **62 days** apart; page size
is **1–50**, with the mobile client requesting **25**. It returns only scope,
minimal meeting summaries, permitted review identifiers and an opaque
`next_cursor`. It returns no transcript, roster, manager identity, read token,
hidden totals or day counts. It never advances read/unread state.

Each row requires either current numbered membership entitled to the canonical
current-meeting review, or a recruitment card within the General episode's
existing `sequence <= exit_sequence / last_sequence` history frontier. Former
General history can show permitted cards but does not grant attendance or Join.
General membership by itself cannot reveal meetings with no permitted card.
All reads recheck canonical experiment, account, policy, hub/category, room,
blocking and suppression rules. Archived/suppressed rooms and unavailable or
blocked creators are omitted, including their contribution to continuation.

Meetings deduplicate by canonical meeting ID. Within authorized history the
reader prefers a currently eligible card, then the latest card; an older
retracted card cannot hide a newer permitted repost. If a new repost is outside
a former episode's frontier, it cannot replace that episode's old permitted
card. Meeting places, current attendance and server-computed `can_confirm` /
`can_join` remain distinct. Card expiry does not prevent an eligible current
chat member confirming a still-future meeting.

Rows sort by `(starts_at, meeting_id)` ascending. A continuation authenticates
that key with HMAC over actor, hub, General room/episode/history, local-window
UTC instants, page size and the actor's hub membership episodes, using the
private episode secret. It cannot transfer to another actor, realm, episode,
window or page size. Every page rechecks current row authority; this is fresh
keyset pagination, not a frozen availability snapshot. Invalid/stale cursors
fail explicitly and require refresh.

The UI offers explicit Load more. Until continuation ends, it says more dates
remain, shows markers for loaded authorized rows only, and never declares a
partially loaded day definitively empty. There is no total inferred from hidden
rows. New inserts before an existing keyset appear on refresh. Refresh clears
loaded pages and rereads the first page.

## Mobile state and compatibility

Local month boundaries are constructed separately as civil dates before UTC
conversion. No next-day/month boundary adds a fixed 24-hour UTC duration, so
month/year boundaries and daylight-saving offset changes remain correct.
Meeting instants and the existing device-local display policy are unchanged.

Selection and useful scroll position survive detail navigation. Calendar rows
open existing recruitment review or an occurrence-specific attendance review;
the latter uses the existing meeting panel and commands, with an exact meeting
ID guard against substituting a newer occurrence. An older frozen operation
retains its recovery control even if the current meeting changes. The calendar
does not read or subscribe to transcripts and does not add command semantics.

Successful return, actor-only signals, resume/reconnect and the existing
20-second foreground refresh cadence revalidate canonical state. Account,
gateway/realm, hub, month and policy replacement invalidate in-flight responses.
Background/disconnected/access-loss states discard protected rows immediately.
Loading, backend failure, unavailable admission and a truly empty day have
different presentations. There is no persistent private cache or mock fallback.

The migration only adds the reader and a chronological meeting index. Existing
installed reader OIDs, grants and closed nine-/eleven-field DTOs are unchanged.
Generated public TypeScript database types include the new RPC. Apply the
additive migration before distributing this client. API failure never falls
back to a weaker or dateless reader.

Existing COMM01/FILL01 Mock fixtures already supply Valorant 4/7 and full Lupus;
the same reader uses those canonical meetings within the independent Mock
backend. No new production seed or fixture replay is needed for this calendar.
This change does not activate or seed a hosted Mock project.

## Validation and delivery evidence

Use an owned disposable loopback Supabase project. Never reset a hosted/shared
database or a project belonging to another task. The independent HTTP command is
`node scripts/verify-local-cocreate-calendar.mjs`; it is also called by the
existing `npm run cocreate:communities:verify:local` CI gate. Both use the
existing loopback and owned-engine guards. The standalone command requires the
project-scoped Supabase CLI on PATH, as do the other local verifiers.

Relevant commands from the repository root:

```text
npm exec supabase -- test db supabase/tests/162_cocreate_calendar.test.sql --local
node scripts/verify-local-cocreate-calendar.mjs
node scripts/verify-local-cocreate-calendar-upgrade.mjs
npm run cocreate:communities:verify:local
npm run db:test
npm run db:lint
npm run db:advisors
npm run db:types
```

The upgrade command requires an owned loopback project and
`PLANETS_DISPOSABLE_QA=1`. It reconstructs the exact pre-CAL01 schema inside a
rollback transaction by removing only CAL01's new function and index. It warms
six installed readers, applies the actual migration source and checks every
public function's OID/ACL/source/result plus all populated public/private rows.
It explains the actual calendar query against 3,000 synthetic historical
meetings, checks use of the chronological window index, and rolls everything
back. Its count/hash-only summary is written to
`build/cocreate-cal01/qualification.json`. The existing community HTTP CI command
also invokes this bounded rehearsal; no new CI job or trigger is added.

Relevant mobile commands from `apps/mobile`:

```text
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded test/features/co_creation
flutter test --no-pub --concurrency=1 --reporter expanded --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/cocreate-cal01 test/features/co_creation/co_creation_calendar_flow_test.dart
```

Actual results and screenshot qualification are recorded beside
[rendered evidence](evidence/cocreate-cal01/README.md). Screenshots use fictional
contract fixtures and actual Flutter rendering, not live-data proof or physical
device QA. Code merge, hosted migration application, experiment activation,
Mock data and installed-app state are separate delivery claims. None implies
another. Places and map discovery remain the prompt's subsequent scoped work.
