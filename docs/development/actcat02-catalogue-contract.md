# ACTCAT02 catalogue contracts

The external catalogue now represents `event`, `course` and `place` in the
existing private tables and atomic importer. Category remains independently
`sports`, `culture` or `other`; discipline remains a bounded source-mapped slug.
Identity stays `(source_id, upstream_id)` with the same internal UUID through
updates, including a corrected listing kind. No source is seeded or enabled.

## Rollout and released clients

Apply the four additive catalogue-kinds, multi-source, geography and operations
migrations in canonical order for this integration. The current Flutter reader
calls `list_external_activities_v3` and `get_external_activity_v2`; the geographic
migration is required before this client release. The earlier V2 list stays
available for existing clients. Missing RPCs remain
visible read failures; there is no client fallback to examples or provider APIs.
Settings → Sandbox → Activities Split Mode remains off by default.

The original RPC signatures remain available. V1 list/detail return only
events with source descriptions; their occurrence, cancellation, observation,
cursor and health behavior is retained. New records without descriptions are
valid in V2 but deliberately excluded from V1: the released parser requires
non-null prose. Courses and places never reach the released event reader.
No invented description is stored to satisfy that compatibility contract.

## Canonical content

`records.mjs` validates and normalizes existing fields; `catalogue.mjs` owns the
new typed metadata. SQL validates the complete batch before any catalogue write.
Existing records without `kind` mean `event`. New normalized records include:

```json
{
  "kind": "place",
  "description": null,
  "schedule": null,
  "geometry": {
    "latitude": 46.07,
    "longitude": 11.12,
    "precision": "locality",
    "provenance_url": "https://source.example.org/dataset"
  },
  "level": null,
  "access": null,
  "occurrences": []
}
```

This fragment omits the unchanged required identity/title/source/category/status
fields. Plain text and official HTTPS URL validation still apply. Geometry must
be explicitly published by the same official origin, finite, in latitude and
longitude ranges, and labelled `venue` or `locality`. It never comes from native
meeting locations, city-label geocoding or the device. Nullable cost, audience,
level and access text do not imply free access, enrollment or opening hours.
The retained `scheduled` status means a discoverable published record for a
place; it asserts no appointment, opening schedule or access availability.

Places cannot carry occurrences or course schedules. Descriptions are nullable
for every kind. Events retain at most 200 exact disjoint occurrences, explicit
offsets, date-only values, exclusive all-day ends and unknown end times.

## Finite course schedules

The optional `schedule` object is accepted only on courses:

```json
{
  "season_start": "2026-10-01",
  "season_end": "2026-11-30",
  "timezone": "Europe/Rome",
  "text": "Source-supplied schedule text, if any",
  "weekly": { "days": [7], "start_time": "10:00", "end_time": null },
  "exceptions": ["2026-10-25"]
}
```

Season dates are inclusive and at most 366 days apart. Weekly days are unique
ISO weekdays 1–7. A weekly rule requires both season dates and an IANA timezone;
wall clocks use `HH:mm`, with an optional strictly later end on the same day.
Overnight rules and arbitrary RRULEs are unsupported. Exceptions are at most 200
explicit dates inside the term and suppress both derived and explicit lessons.
Text-only schedules and incomplete season metadata remain representable but
cannot derive a lesson.

The server derives only the next relevant lesson within the existing 90-day
horizon, using the source wall clock in its timezone. DST changes do not shift
the lesson's local time. Nonexistent spring clocks are skipped; ambiguous autumn
clocks use PostgreSQL's standard-time interpretation. An unknown end remains
null. V2 returns `next_occurrence` separately so source `occurrences` remain
unchanged and bounded; Flutter performs no competing recurrence calculation.

A course enters active discovery only during its explicitly bounded season.
A current course with no calculable lesson has null `next_at` and
`next_occurrence`, and shows its source schedule or “Schedule to confirm”.
Expired, unknown-season and future-season courses are excluded. An unspecified
season timezone uses UTC only for season eligibility, never for deriving times.
Exact course details apply the same season gate.

## Public reads and filters

V2 list accepts `p_kind`, `p_category`, `p_discipline`, literal `p_query` (at most
120 characters), paired `p_from`/`p_to` dates, `p_limit` (1–30), and an opaque
`p_cursor`. The date window is `[from,to)`, at most 90 days, and matches occurrence
overlap in its explicit timezone. Places and courses without a known relevant
session are outside a date-filtered result; date filtering makes no claim that
an undated place “happens” on that date.

Filters apply before pagination. `facets.kinds`, `facets.categories` and
`facets.disciplines` span the complete eligible kind/category/date scope, before
query/discipline narrowing and page size. The `disciplines` alias is retained for
the existing controller. Flutter parses and retains typed facets across pages.

Mixed ordering is explicit: events by next occurrence; courses with a known
next lesson; current courses with unknown sessions by lowercase title; places
by lowercase title. UUID breaks ties in every group. Cursors bind every filter,
enabled-source catalogue versions and a reference valid for 30 minutes. Current
source disable, cancellation and observation expiry apply on every page.
Courses must be current at both the page reference and the current read: a
course entering its season after the reference waits for refresh, while an
expired season is removed immediately.

Per-record warning/expiry defaults are 72 hours/14 days for events and courses,
and 7 days/30 days for places. Source-wide success does not refresh an absent
record. No source-specific override is introduced in this step. Failed imports,
unconfigured sources, never-synchronized sources, stale records and valid empty
results remain distinct. Rights/configuration/leases/raw content stay private;
only the existing service-only import transaction may write canonical records.

## Verification and local reproduction

Use a task-owned disposable workdir with canonical config/migrations/tests/seed,
project ID `planets-actcat02-qa` and non-default API/database ports 62521/62522.
Never reset a retained or peer stack. Set `SUPABASE_WORKDIR` to that workdir,
`PLANETS_DISPOSABLE_QA=1`, and the task engine connection before the commands:

```text
node --test scripts/lib/external-activities.test.mjs scripts/lib/external-catalogue.test.mjs
npm run db:lint
npm run db:advisors
npm run db:test
npm run activities:verify:local
npm run db:types
npm run check:mobile
npm run typecheck --workspace @planets/web
```

The HTTP verifier exercises all kinds, repeat identity, a kind correction, V1
compatibility, V2 pagination and anonymous disable behavior using synthetic
records only. Its `external-activities-upgrade-verifier.mjs` helper restores the
predecessor catalogue functions inside a rolled-back transaction, populates and
warms legacy imports, then applies the exact new migration. It verifies the
installed validator OID and legacy UUID, prose and revision survive, and the
warmed importer accepts V2 places. `149_external_catalogue_kinds.test.sql` adds season, geometry,
facet, overlap, cancellation, DST, observation and privilege checks to the
existing catalogue tests. Generated database types come from the disposable
schema, through the standard repository generator.

On this Windows/WSL Podman host, timer-driven container health probes do not run
automatically. Start/restart can report `HealthCheckTimeoutError` despite live
services. Execute each of the six configured task-container health probes
explicitly (`podman healthcheck run <task-container>`); all must succeed before
SQL/HTTP validation. No `--ignore-health-check` option was used. The task service
uses loopback port 62499, with both `DOCKER_HOST` and `CONTAINER_HOST` set for
this CLI process. These are local verification settings, not product config.
Windows tooling tests also need a real `python.exe` ahead of the Windows Store
alias in the process PATH; the bundled runtime was used without changing tests.

Rendered synthetic evidence covers IT/EN, 320/360 dp, 2× text and light/dark:
[English 320 dark](evidence/actcat02/actcat02-en-320-dark.png) and
[Italian 360 light](evidence/actcat02/actcat02-it-360-light.png), plus the other
six combinations in the same folder. These are rendered widget captures;
physical-phone QA remains deferred. No real source was imported, hosted data
changed, scheduler enabled, analytics activated, or production release made.

The repository migration gate requires an exact owner review for this function
and grant migration. Its approval object is tied to the final PR head, SQL hash
and predecessor inventory; ordinary implementation authorization cannot replace
the required owner-authored GitHub review comment. See the
[queue progress](activities-sports-progress.md) for the merge/resume status.

## RADAR01 compatibility

RADAR01 retains V1/V2/V3 signatures and adds V4 type filtering and nullable
activity_type: music, theatre-cinema, talks, workshops, social, exhibitions,
outings. External families remain distinct from sports disciplines, native topics
and competences. The new client requires the Radar migration before rollout.
Private evidence, source approval, exact aliases and bounded batches are defined
in the [Radar contract](radar01-automatic-activities.md).
