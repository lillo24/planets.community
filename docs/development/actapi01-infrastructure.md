# ACTAPI01 source-independent infrastructure

The founder authorized continuing infrastructure while separately obtaining
municipal clarification. This change implements a canonical catalogue, bounded
import framework and Flutter public reader. **The municipal connector is absent,
no municipal data has been imported, and the complete official-API MVP is still
blocked.** The [source checkpoint](actapi01-source-checkpoint.md) retains the
actual 2026-10-21 API observations and missing reuse permission.

## Ownership and publication gates

`supabase/migrations/20261022084023_external_activity_catalogue.sql` adds only
`private.external_activity_sources`, `external_activity_runs`,
`external_activities` and `external_activity_occurrences`. These have no native
Project/Profile/participation foreign keys. All four have RLS and no raw
table privileges for `anon`, `authenticated` or `service_role`.

No source is seeded. Only a database owner can configure a source, confirm
rights, set attribution/licence and enable it. Enabling without all those fields
fails. One source may be enabled in this MVP. A service credential cannot change
these controls and can write only through the bounded import RPCs. Public list
and exact-detail RPCs always require a currently enabled, rights-confirmed source
and a publishable record. A device preference is never authorization.

The source row's `official_origin` constrains every canonical event page to that
HTTPS origin. Source-specific mapping must additionally exclude any records
whose rights or publication state conflict with the eventual approved contract.
Do not infer event-text rights from a photo licence or organizer name.

A future database-owner setup can create a disabled row with the verified
official origin, leaving both gates off until the evidence and connector exist:

```sql
insert into private.external_activity_sources
  (source_id, display_name, official_origin, enabled, rights_confirmed)
values
  ('agenda-trento', 'Agenda Trento', 'https://eventi.comune.trento.it', false, false);
```

Populate `attribution` and `license_url` from the approved statement before an
explicit owner decision to set `rights_confirmed=true, enabled=true`. Do not use
a placeholder licence. The importer cannot perform this setup or approve rights.

## Canonical record and time contract

The unique identity is `(source_id, upstream_id)`; the internal UUID survives
repeat imports and content changes. Records contain a title, plain-text
description, official page, `sports`/`culture`/`other` category, original category
strings, optional structured discipline slug, organizer display name, cost,
audience, city, venue and public address. Optional absent fields remain null.
Blank optional source text normalizes to null; required title/description stay
nonempty. Structured contacts, HTML markup, images, attachments and arbitrary extra keys
are rejected. No availability, free admission or native membership is inferred.

Every occurrence explicitly carries `kind`, `start`, nullable `end` and an IANA
`timezone`. `timed` values require ISO timestamps with explicit offsets; original
offset strings are retained. `date` and `all_day` values remain `YYYY-MM-DD`.
Their canonical end is **exclusive**; a missing date end means one calendar day
for internal overlap only. It does not invent an appointment time. A future
connector must translate upstream all-day conventions only after verifying them.
Multiple sessions remain separate; empty schedules stay unknown and do not enter
upcoming discovery. Recurrence is never inferred from text.

Publication state is `scheduled`, `cancelled` or `unpublished`. Cancellation
removes ordinary discovery but remains explicit on a still-eligible exact
detail. Unpublication denies both. Ordinary discovery requires an unexpired
occurrence overlapping a rolling 90×24-hour window. Ordering uses the actual
next unexpired occurrence start, then internal UUID. Date keys use their named
zone for overlap; Flutter displays dates without a midnight clock.

## Import protocol and bounds

`scripts/lib/external-activities/` separates transport, canonical validation and
collection/persistence. This is one connector boundary, not an aggregation
framework. `officialActivityConnector('agenda-trento')` currently throws
`source_rights_checkpoint_blocked` before provider IO or database writes.
Synthetic connectors exist only inside tests and the disposable verifier.

`begin_external_activity_import(source_id)` is service-only and obtains a
source-scoped ten-minute lease. `finish_external_activity_import` validates the
entire batch before atomically updating records, replacing changed occurrence
sets and recording success. Finish is fenced by the current unexpired lease;
obsolete completions fail. Source locks have a five-second wait limit. No
checkpoint or valid catalogue writes occur on incomplete/failed runs.

Content hashes are canonical JSON change detectors, not signatures. Unchanged
records retain content revisions and upstream-modified values while updating
their observation time. Observation is conservatively the run start. Missing
records are neither deleted nor refreshed; absence is not cancellation.

Default bounds are five minutes per run, 15 seconds per HTTP request, 2 MiB per
decompressed response, 16 MiB total, 50 pages, 100 related-record requests, 160
actual HTTP attempts, 2,000 records, 200 occurrences per record, two retries and
two redirects. Individual normalized batches are also database-bounded to
10 MiB. API origins/path prefixes are connector-owned code. Redirects and
pagination URLs are validated before IO; unsafe schemes, credentials, fragments,
origins and paths fail. Repeated page URLs fail rather than looping.

Retry-After seconds and dates are honored up to 15 seconds. Longer requested
waits fail this run instead of retrying early. Conditional 304 responses are
explicit and valid only after sending a conditional header; a future connector
must prove which validated content they re-observe. They are not empty pages.
Malformed envelopes, failed pages and exhausted budgets cannot become a complete
empty result. A lost completion response reports `completion_unconfirmed`.

Private run rows retain compact counts and allow-listed error codes, never raw
responses or contact-rich diagnostics. Completed rows older than 30 days are
pruned when a new run begins. If scheduling stops, operators must perform
retention maintenance themselves; this is not an independent scheduled eraser.

## Public reads and freshness

`list_external_activities(category, query, discipline, limit, cursor)` exposes
server-side filtering, at most 30 rows (Flutter requests 20), all eligible
discipline options, `as_of`, `next_cursor`, `last_success_at` and `state`.
Query text is literal case-insensitive text, at most 120 characters. Cursors
bind category, query, discipline, source/version and a consistent occurrence
reference valid for 30 minutes. New successful imports invalidate old cursors;
Flutter restarts at the first page with the same filters. Disable and expiry
always use current server state, independently of the cursor reference.

`get_external_activity(uuid)` returns one eligible public projection or null.
Both readers expose sanitized canonical fields, source name/attribution/licence,
revision, last observation and per-record staleness. Private run/configuration
state and importer keys are not public. Generated TypeScript types come from
the local database; no generated output is hand-edited.

Records are stale after 72 hours without re-observation and hidden after 14 days.
Expired dates leave upcoming discovery independently. Source-wide success never
refreshes a missing individual record. Source states are `unconfigured`,
`never_synchronized`, `healthy`, `empty`, `stale` and `unavailable`. Healthy/empty
describe a recent complete source run and current filter, not complete Trento
coverage. A failed read is a separate client error, never a successful empty
calendar. A source failure can retain previously observed public rows with an
explicit unavailable message.

## Flutter and rollback

Activities Split Mode stays off by default. When enabled, `/activities` reads
the canonical external catalogue. All/Culture retain a separate native Tavoli
entry. Search and discipline filters apply only to external events. No reliable
discipline metadata means no discipline selector. Pull-to-refresh rereads
PLANETS; it never initiates ingestion or calls the municipal provider.

The clearly labelled preview action opens `/activities/examples`, retaining the
12 fictional examples, their own filters and existing detail routes. Examples
never mix into real results and are never an empty/error fallback. List filters
and scroll survive detail navigation. Retained inactive, background or disabled
surfaces initiate no new catalogue requests. Baseline tutorial behavior and
native joins, maps, chat and creation remain unchanged.

Real detail includes exact source schedules, attribution and the last PLANETS
observation time explicitly labelled UTC. It has no native join/chat/profile or
availability action. Official/licence links use the shared HTTPS-only external
application boundary; credentials, unsafe schemes, IP/local hosts and ports are
rejected. English/Italian interface copy is separate from untranslated source
content. No external images or maps are fetched.

Turning the preference off restores baseline navigation without changing
catalogue records. Independently, the database owner can set the source's
`enabled=false` to immediately deny new public reads and successful imports.
Do not remove historical migrations or delete native records as rollback.

## Commands and deferred activation

```text
npm run activities:import -- --source agenda-trento --dry-run
npm run activities:import -- --source agenda-trento --apply --target local-qa
```

Both commands currently exit nonzero at the explicit municipal checkpoint.
This is intentional, not a passing dry-run or a successful empty import.
After a permitted connector is implemented, apply also requires all of
`ACTIVITIES_TARGET`, `ACTIVITIES_API_URL` and `ACTIVITIES_SERVICE_ROLE_KEY`;
`--target` must match the configured target. There is no implicit production
destination. Target URLs require HTTPS except explicit loopback HTTP. Keys stay
server-only. Dry-run performs fetch/validation and reports counts without any
catalogue/run mutation. Ordinary cron can invoke the same CLI.

The daily 04:20 UTC/dispatch workflow `external-activities.yml` is skipped unless
repository variable `ACTIVITIES_IMPORT_ENABLED` is exactly `true`. It accepts no
PR/fork events, has read-only repository permissions, target-scoped concurrency
and a ten-minute cap. It uses `ACTIVITIES_TARGET` plus server-only secrets
`ACTIVITIES_API_URL` and `ACTIVITIES_SERVICE_ROLE_KEY`. Manual dispatch defaults
to dry-run; scheduled runs request apply. Disabled/skipped and blocked/failed are
distinct from successful imports. One daily Node job replaces no service; normal
validation never calls the provider. Do not enable this workflow yet.

After rights clarification: record the authoritative terms and attribution,
verify the remaining source checkpoint, implement the single municipal parser
with scrubbed fixtures, run the permitted live import/repeat/public-read/render
check on a disposable local stack, and review source configuration before
separate hosted setup. Only then may an owner configure the source, secrets,
target and opt-in variable. Disable scheduling by deleting the variable or
setting it to `false`; disable publication separately in PostgreSQL. This task
does not authorize hosted migrations, imports or schedule activation.

## Reproducible verification

Run `node --test scripts/lib/external-activities.test.mjs` and the feature's
Flutter tests. The complete tooling/mobile checks and required CI remain in
place. The Database job includes pgTAP and
`npm run activities:verify:local`; the full manual `check:db` also includes it.
The HTTP verifier requires `CI=true` or `PLANETS_DISPOSABLE_QA=1`, rejects a local
retained default-port stack, uses synthetic content and removes only its own
source. It verifies real service/anonymous RPCs and concurrent claims without
creating organizer accounts or changing native Projects.

For local isolation, copy canonical Supabase config/migrations/tests/templates
to an ignored task workdir, select a unique `project_id` and unused loopback
ports, and set `SUPABASE_WORKDIR` for repository commands. Never reset another
task's stack. This Windows task used `planets-actapi01-qa`, API/database/mailbox
ports 62321/62322/62324, and a task-owned loopback Podman service. On this WSL
runtime without systemd timers, its configured container health probes were
executed explicitly; health failures were not ignored.

Rendered widget evidence uses synthetic public records and the existing
`UI_POLISH_CAPTURE_DIR` opt-in. It is not native Android/iOS or live municipal
evidence. Phone review remains deferred. No permitted municipal end-to-end test
has passed; zero municipal records have been imported or made visible.

### Recorded execution evidence

Validated on 2026-10-22 against `main` at `f938e017` plus this change:

Before merge, the still-unapplied catalogue migration was restamped after the
latest main migrations and RELEASE01's fixed bootstrap boundary. Its SQL is
unchanged; no shared/applied migration history was rewritten. This avoids
creating an unexpected historical gap in a future staged rollout.

- `npm run test:tooling`: 163 passing tests, including 19 bounded importer tests.
- `flutter test --no-pub test/features/external_activities`: 15 passing tests.
- `npm run check:mobile`: Dart formatting and full analysis passed; 3,973 tests
  passed with two existing skips.
- SQL lint and security advisors: no issues on the freshly replayed schema.
- `npm run db:test`: 160 pgTAP files, 6,489 passing assertions, including 76
  external catalogue assertions.
- `npm run activities:verify:local`: synthetic service/anonymous HTTP pipeline
  passed on the disposable stack; native Project count stayed unchanged.
- `npm run db:types:check`: generated contract matches the local schema.
- `npm run check:web` and `npm run check:site`: passed, including production
  builds and the site's deployment dry-run. No deployment was performed.
- Changed JavaScript/workflow/Markdown formatting and `git diff --check`: passed.
  The full `format:check:web` command still reports six unchanged files from
  `main`: `scripts/verify-local-proposal-skills.mjs`, the `hero05`, `navperf01`
  and `tut04` evidence READMEs, `msgrefresh01-stable-refresh.md` and
  `navigation-headers.md`. Those unrelated files were left untouched.

The final local reset applied every migration and seed, then timed out waiting
for a storage health probe on this timer-less WSL runtime. Explicit configured
probes followed by `npm run db:start` confirmed readiness before the final SQL
and HTTP checks. Required Linux CI independently replays the canonical history.

Inspected widget captures:
[synthetic list](evidence/actapi01/actapi01-synthetic-list.png),
[synthetic detail](evidence/actapi01/actapi01-synthetic-detail.png),
[English 320dp at 2× text](evidence/actapi01/actapi01-en-320-2x.png), and
[Italian 320dp at 2× text](evidence/actapi01/actapi01-it-320-2x.png).
These are synthetic rendered widgets, with no claim of municipal or native
device integration.
