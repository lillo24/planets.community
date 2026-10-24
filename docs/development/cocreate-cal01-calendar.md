# Community calendar (COCREATE-CAL01)

[PLACE01](cocreate-place01.md) adds authorized venue links through calendar v2,
current-meeting v2 and review v2. The installed v1 contracts and signed cursor
are unchanged. Place is nullable: private/off/address associations require current
numbered membership; card-only venue links require explicit eligible amenity
publication. Occupancy, fresh viewer eligibility, loaded-extent refresh and exact
occurrence review remain the CAL01/FIX01 rules. No map widget is added here.

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
blocking and suppression rules. Archived/suppressed rooms are omitted. A current
numbered member retains the same current-occurrence review as the canonical
meeting panel when either party blocks or the creator is temporarily unavailable,
including after declining attendance. An ended episode or prior RSVP grants no
exception. Card-only viewers still require an available, unblocked creator;
excluded rows contribute neither markers nor continuation.

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
protected rows/cursors and starts at page one, retaining only the requested row
extent and chronological frontier as RAM-only pagination intent. It reads up to
**four 25-row pages (100 rows) per pass**, until that extent/frontier is covered or
the continuation ends. New earlier rows cannot silently displace the old frontier.
If the cap is reached, the partial-date notice and **Load more** continue fresh
coverage; partial days are never declared definitively empty. A stale scoped
cursor triggers at most one fresh pass (at most eight calendar requests across
the two passes); a repeated failure clears rows and offers an explicit retry.
Account/realm replacement and access denial discard the old intent as well.

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

Recruitment review uses `get_cocreate_recruitment_review_v1`, an exact actor/
General-room/episode/card-bound envelope containing the unchanged card plus
fresh server-derived `can_join`. It preserves the installed history frontier and
separately checks current hub membership, creator availability/blocking, room
exclusions, persistent-chat capacity, numbered membership limits and dated
meeting eligibility. Every recruitment entry, including direct links, uses that
read. Spare meeting seats never imply that the viewer can join. No reader writes
membership/attendance or acknowledges messages. Atomic Join remains the final
authority on races; a frozen attempt retains its exact recovery even when fresh
eligibility becomes false. Installed nine-/eleven-field cards remain unchanged.

Successful return, actor-only signals, resume/reconnect and the existing
20-second foreground refresh cadence revalidate canonical state. Account,
gateway/realm, hub, month and policy replacement invalidate in-flight responses.
Background/disconnected/access-loss states discard protected rows immediately.
Timer, metadata and return triggers serialize with one coalesced follow-up.
Initiation and response adoption both require the current foreground route and
resumed lifecycle. Connected hints while inactive/hidden cannot repopulate rows;
foreground resume revalidates. Date semantics expose the same tap action as
pointer input, with full localized date, selection and mixed markers.
Metadata-socket loss clears and fences existing rows but does not disable the
authorized HTTP fallback. Foreground polling or an explicit retry starts a fresh
server-authorized read even while the socket remains disconnected.
Loading, backend failure, unavailable admission and a truly empty day have
different presentations. There is no persistent private cache or mock fallback.

The original migration adds the reader and a chronological meeting index. The
forward `20261023155513_cocreate_calendar_corrections.sql` replaces that reader's
body in place and adds the separate recruitment-review contract/helper. Existing
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
`PLANETS_DISPOSABLE_QA=1`. It reconstructs the CAL01-installed predecessor
`fef1c343501a43712f997aca269a09ca6f245b75` inside a rollback transaction, retaining
the installed calendar function/index. It warms seven readers and a real signed
calendar cursor, applies the actual forward correction source and checks all
other installed public functions' OID/ACL/source/result plus every populated
public/private table. The calendar's OID, signature/defaults, ACL, stability,
definer context, fixed path, envelope/row payload and old cursor are preserved.
Repeated body installation also preserves populated rows and warmed contracts.
It explains the actual calendar query against 3,000 synthetic historical
meetings, checks use of the chronological window index, and rolls everything
back. Its count/hash-only summary is written to
`build/cocreate-cal01/qualification.json`. The existing community HTTP CI command
also invokes this bounded rehearsal; no new CI job or trigger is added.

The standalone calendar HTTP verifier accepts `MAILPIT_URL` for an owned local
stack with a different mailbox port; its default is `http://127.0.0.1:54324`.
It validates an HTTP loopback origin before fixture writes and never accepts a
hosted mailbox. This supports isolated integration projects without borrowing a
peer's backend or changing their ports.

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

Correction regressions and current local qualification are recorded separately
in [CAL01-FIX01 evidence](evidence/cocreate-cal01-fix01/README.md).
