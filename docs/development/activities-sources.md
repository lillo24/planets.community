# External Activities sources and operations

The canonical catalogue is independent of native Projects/Tavoli and Find people.
ACTSRC02 adds independent sources without enabling any source. Import credentials
can claim/finish existing enabled licensed sources; only a database owner can
configure rights, origins, capabilities or publication. Private source/run tables
remain denied to anon, authenticated and service roles. RLS is retained.

## Source policy

Use a small code-owned connector directory (`connectors.mjs`), not arbitrary URLs
or runtime modules. Each source declares its stable ID, kinds, API HTTPS origins,
path/exact resource, separate public information origins, parser version, rights,
attribution, coverage and freshness. API origins allow at most two; public origins
are the owner-only primary origin plus at most four explicit additions. They are
never feed-controlled destinations. Rights for a dataset do not imply rights for
linked pages/images. Agenda Trento retains its distinct rights-checkpoint block.

Owner configuration template (review for the actual approved source; disabled):

```sql
insert into private.external_activity_sources
 (source_id,display_name,official_origin,public_link_origins,supported_kinds,
  attribution,license_url,rights_confirmed,enabled)
values ('reviewed-source-id','Reviewed official source','https://official.example.org',
 array[]::text[],array['place'],'Reviewed attribution',
 'https://official.example.org/license',false,false);
```

No migration seeds that template. Hosted configuration/imports/schedules require
separate activation authorization. A service key cannot grant itself approval.

## Canonical compatibility and health

Source/upstream ID pairs retain distinct UUIDs, even at the same official page.
No fuzzy merge or absence deletion. Each source has its own ten-minute lease,
atomic complete snapshot and version. Failed/incomplete imports preserve content,
observation times and last success. Disabling a source also denies its in-flight
success; configuration changes increment its version, including OFF→ON cycles.
Readers bind the complete eligible source/version set and filters into the cursor.
Healthy source B never refreshes A's records. All filters/facets run before paging.

V2 adds `partial` health with available healthy results and sanitized configured,
failed and pending counts. All failed, never synchronized, unconfigured and a
successful empty catalogue remain distinct. No raw errors, runs, API URLs, origin
policies or credentials enter the public projection. V1 retains its event-only,
non-null prose shape and existing health vocabulary (`unavailable` for partial),
but now traverses every eligible event source deterministically. Existing RPC
signatures, OIDs and grants are retained. V2 explicitly adds typed `link_scope`:
`item` (compatible default) or `dataset`, which determines truthful action copy.

Events/courses warn after 72 hours and expire after 14 days without observation;
places warn after seven days and expire after 30. Course terms and exceptions,
exclusive date filters, ordering and cursor reference remain in the
[ACTCAT02 contract](actcat02-catalogue-contract.md). Public clients only read the
backend; refreshing a screen never launches a provider import.

## Transport and verification

JSON and the narrow municipal CSV/text path share the existing streamed and
decompressed byte, redirect, origin/path, request, retry and five-minute budgets.
CSV/text requires explicitly accepted non-HTML MIME and UTF-8; invalid encoding,
structural errors, duplicate upstream IDs or incomplete traversal fail a snapshot.
No arbitrary uploaded CSV, archive, HTML scraper or linked-page crawling exists.

Reproducible checks on a fresh task-owned non-default local stack:

```text
node --test scripts/lib/external-activities.test.mjs scripts/lib/external-catalogue.test.mjs scripts/lib/external-multi-source.test.mjs
supabase test db --local supabase/tests/148_external_activities.test.sql supabase/tests/149_external_catalogue_kinds.test.sql supabase/tests/162_external_multi_source.test.sql
PLANETS_DISPOSABLE_QA=1 npm run activities:verify:local
npm run db:types:check
npm run db:lint
npm run db:advisors
```

The guarded HTTP verifier uses real local service/anonymous requests for A/A and
A/B claims, colliding upstream strings, repeats, changed content, obsolete replies,
partial health, paging/facets, denied configuration and mid-run disable. Synthetic
source data is removed in `finally`; no hosted source is used as a test fixture.
