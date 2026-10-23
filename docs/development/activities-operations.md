# External Activities refresh operations

ACTOPS01 extends the existing Node importer and disabled daily Actions workflow.
It creates no hosted configuration, queue, dashboard or new provider dependency.
The [source contract](activities-sources.md) owns licences, identities, observation
freshness and public visibility. The [map contract](activities-map.md) owns V3.

## Commands and budgets

`node scripts/operate-external-activities.mjs` accepts exactly one mode: `--dry-run`, `--apply`,
`--inspect` or `--maintain`. Select one to four distinct code-owned IDs with
`--sources id,id` or private `ACTIVITIES_SOURCES`; no default source is selected.
Unknown IDs are rejected. Agenda Trento and ODH return their existing separate
rights/coverage errors before provider traffic. Other selected sources continue.

```text
node scripts/operate-external-activities.mjs --sources trento-open-sports-facilities --dry-run
node scripts/operate-external-activities.mjs --sources trento-open-sports-facilities --inspect --target <target-id>
node scripts/operate-external-activities.mjs --sources trento-open-sports-facilities --apply --target <target-id>
node scripts/operate-external-activities.mjs --sources trento-open-sports-facilities --apply --due-only --target <target-id>
node scripts/operate-external-activities.mjs --sources trento-open-sports-facilities --maintain --target <target-id>
```

Dry-run validates a bounded fresh export without database access or writes.
Every other mode requires server-only `ACTIVITIES_API_URL`,
`ACTIVITIES_SERVICE_ROLE_KEY`, and exact equality between `--target` and
`ACTIVITIES_TARGET`. URLs require HTTPS, except HTTP loopback for local testing;
userinfo/query/fragment are denied. Credentials are environment values, never
CLI arguments, mobile/public variables or log output. The old single-source
`activities:import` interface remains supported.

Sources run sequentially under one seven-minute parent deadline, retaining each
source's five-minute budget, 160-request cap (including retries), 2 MiB response,
16 MiB total, 50 pages, 100 related lookups, 2,000 records, two retries and bounded
redirect/delay policy. At most four sources means at most four such attempt
budgets, all subject to the shorter parent deadline. Interrupt signals propagate
through collection/persistence; a pre-aborted operation cannot claim a lease.
Failure receipt gets a separate ten seconds. A lost success reply whose receipt
cannot be confirmed reports `completion_unconfirmed`, never a fabricated failure.

Default cadence is 24 hours. Optional private `ACTIVITIES_REFRESH_POLICY_JSON`
maps known source IDs to whole-day hours from 24 to 168, e.g.
`{"trento-open-sports-facilities":48}`. It cannot set origins, rights or connectors.
`--due-only` compares database `as_of` with durable `last_success_at`; a failed
attempt does not postpone a due source. Manual apply can force a bounded refresh.
No conditional request is invented: the municipal CSV is fetched afresh; a 304
cannot silently refresh observations. Cadence is independent of seasons,
appointments, stale/expired observation policy and actual venue availability.

Output is bounded source IDs, outcome codes and counts. Overall `success` needs
every source to be validated/refreshed or genuinely not due. Mixed results are
`partial`; all failed/disabled/unconfigured/blocked is `failure`; these return
exit 1. Inspection of an unconfigured source also exits 1. Standalone maintenance
reports its own metadata operation, not a successful refresh. No raw upstream
content, contact, URL, lease token or key appears in operation output. A municipal
new type remains the documented `other-sports` with its source label, and produces
`unknown_source_types` plus a bounded count and nonzero warning outcome. Review
the parser mapping before calling that run qualified. Empty/duplicate-ID/schema/
truncated municipal exports fail; no historical row-count threshold is assumed.
Explicit successful empty traversals remain supported for other capable adapters.
Unexpected record or schedule validation rejections likewise return nonzero
`source_record_drift` with counts, even if the existing transaction saved a valid
subset. When no valid candidates remain and any unexpected validation rejection
occurred, the **shared importer** fails before success for both CLI paths. Apply
stores `incomplete/invalid_payload`, preserves the previous success/observations
and exposes unavailable/partial public health. Unsupported source kinds never
count as accepted. An all-rejected malformed export cannot appear as a healthy
empty refresh.
Routine explicit outside-window or unlicensed-record exclusions retain their
existing rejection policy; no rejected body is logged or used to delete old rows.

## Private inspection and maintenance

`inspect_external_activity_sources(text[])` is service-only. It returns selected
source configured/rights/enabled and lease state, last attempt/success, compact
last-run counts/error, and fresh/stale/expired **observation-age** aggregates with
oldest/newest observation times. These are neither public eligible counts nor
opening/availability assurances. It exposes no record bodies or contact fields.
The private tables retain RLS and denied raw grants, including service role;
the importer cannot configure or approve a source. Anon/authenticated cannot
execute either operator RPC. No public technical dashboard is added.

`maintain_external_activity_imports(text[], integer default 100)` works even for
disabled sources when refresh never succeeds. It locks selected sources in stable
order, before their runs, using `SKIP LOCKED`; active holders are left alone.
Only expired ten-minute leases are cleared; their still-running receipts become
`incomplete/lease_expired`. Late completions remain fenced. It deletes at most
1–100 finished compact receipts older than the existing 30 days, only in selected
sources. It never deletes canonical data, observations or provenance. Begin keeps
its OID/signature/grants, and replaces the old global unbounded prune with this
same source-scoped bound. Run maintenance repeatedly for a backlog. Visibility
expiry continues to hide unobserved rows without destroying them.

## Activation order — prepared, not executed on hosted systems

Current main includes STAGING-AUTO03 and separately merged #310's exact
**source-only** contract for 005's one-source index retirement; see the
[policy resolution and hosted hold](activities-sports-policy-blocker.md).
The hosted authorizer still refuses that pending migration, and the remaining
catalogue/importer/geography/operations effects need independently installed
hosted contracts. Resolve the whole hosted eligibility chain before rollout.
Owner fingerprint comments are historical technical review, not an override.
This feature PR leaves validator/workflow/dependency policy unchanged; direct
Node commands above require no new npm aliases. The steps below are preparation,
not authorization to apply SQL or activate sources/jobs during RESUME02.

1. Merge reviewed code with protected Validation. Confirm all four forward
   catalogue/source/geography/operations migrations after current main are
   applied through the authorized migration process. Do not use a live client
   requiring V3 against an older backend. A source gate cannot replace schema.
2. Recheck the actual municipal dataset's CC BY 4.0, export shape, public-link
   policy and coverage against [source evidence](activities-sources.md).
   ODH and Agenda remain blocked; do not include them in a production source set.
3. An authorized database owner registers metadata **disabled**. Service keys
   cannot do this. This is the current municipal template, not an executed write:

   ```sql
   insert into private.external_activity_sources
    (source_id,display_name,official_origin,public_link_origins,supported_kinds,
     attribution,license_url,rights_confirmed,enabled)
   values ('trento-open-sports-facilities','Comune di Trento',
    'https://www.comune.trento.it',array[]::text[],array['place'],
    'Comune di Trento — Impianti sportivi ad accesso libero — CC BY 4.0',
    'https://creativecommons.org/licenses/by/4.0/',true,false);
   ```

   If already present, inspect and reconcile explicitly instead of overwriting
   metadata with an unreviewed upsert.

4. Run local dry-run and opt-in disposable real-source acceptance; inspect
   anonymous V3 List/Map, real detail and dataset-link fallback. Confirm exact
   source identity/attribution and stable repeated IDs. Configure server-only
   target credentials through the existing protected environment, without
   printing them. Nothing in this queue configures a hosted target or secret.
5. After separate hosted activation authorization, an owner deliberately sets
   `enabled=true` on that reviewed source. Run the first explicit apply command
   above, inspect the result/receipts, then anonymous V3 List/Map/detail and public
   health. Failure retains only previously valid observations; it does not seed
   examples. Complete traversal, not one page, proves count/completeness.
6. Only after that qualification, optionally set Actions `ACTIVITIES_SOURCES`
   to `trento-open-sports-facilities`, `ACTIVITIES_TARGET` to its explicit target,
   existing `ACTIVITIES_API_URL`/`ACTIVITIES_SERVICE_ROLE_KEY` secrets, optional
   private cadence JSON secret, and `ACTIVITIES_IMPORT_ENABLED=true`. The existing
   daily cron is 04:20 UTC; its main-only owner-repository job runs `--due-only`.
   Manual dispatch defaults to dry-run; apply requires its explicit input. There
   is no PR/fork event or write token permission. Target-wide concurrency does
   not cancel an active job; database per-source leases also fence other cron
   runners. The 10-minute job budget includes setup. These settings remain OFF
   and unmodified by this work. Ordinary self-hosted cron can use the same exact
   due-only command and server environment; no managed scheduler is required.
7. Prepare the client release only after backend compatibility and platform
   qualification. Code merge, local import, hosted publication, scheduling and
   app/store deployment are separate milestones. No release/store/deploy dispatch
   is authorized by this operations stage.

## Disable and recover

An authorized database owner can immediately unpublish just the municipal source:

```sql
update private.external_activity_sources set enabled=false
 where source_id='trento-open-sports-facilities';
```

This denies new reads and in-flight success and fences cursors; other sources
remain independent. Stop future scheduled runs by setting the existing repository
variable `ACTIVITIES_IMPORT_ENABLED=false`. Already running imports are bounded
and cannot publish a disabled source. There is no need to delete data, force
clear a live lease, roll back published migrations or modify basemap budgets.
Use `--inspect`, wait for or maintain an expired lease, repair the connector/data
issue, locally qualify it, and only then deliberately re-enable/retry. Failed or
incomplete traversals never remove disappeared items; source-contract removals
require explicit cancellation/unpublication, otherwise observation expiry applies.

Reproducible offline tooling: `node --test scripts/lib/external-operations.test.mjs`.
SQL: `supabase test db --local supabase/tests/164_external_operations.test.sql`.
Real synthetic HTTP: guarded `npm run activities:verify:local`. The tests exercise
A success/B failure, rights/coverage denial, all disabled/failed, valid empty,
due skips, interrupts/deadline/unknown types, safe logs, wrong targets, no-write
dry-run, private grants, expired/locked leases, retention bounds and unchanged
canonical rows. Provider access stays outside CI.
