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

## SPORTDATA01: official Trento public sports equipment

Source `trento-open-sports-facilities`, parser `trento-free-facilities-csv-v1`,
display name Comune di Trento. The [official dataset metadata](https://www.comune.trento.it/Amministrazione/Documenti-e-dati/Dataset/Impianti-sportivi-ad-accesso-libero)
explicitly licenses this dataset under CC BY 4.0 and describes equipment in
municipal green areas, daily updates, Trento coverage. Resource:
`https://www.comune.trento.it/customexport/dataset-csv_resource-46671`.
Attribution: Comune di Trento — Impianti sportivi ad accesso libero — CC BY 4.0;
[licence](https://creativecommons.org/licenses/by/4.0/). Both transport and public
page origin are exactly `https://www.comune.trento.it`; transport is confined to
`/customexport/`, the connector requests only that one explicit CSV resource.
No image or linked-page rights are inferred.

`Item` is the published stable upstream identifier, never row order/title/URL.
Each equipment entry remains separate even at a shared park or point. The CSV
parser handles BOM, UTF-8/Unicode, quoted commas/multiline values/doubled quotes
and normalized headers; missing/duplicate/unexpected columns, duplicate IDs,
truncation and nonempty invalid coordinates fail the complete snapshot. An empty
export is a structural anomaly, not a replacement empty catalogue. New equipment
types retain source text under honest `other-sports`; known types map to controlled
disciplines. All records are sports **places**, with no fake appointment,
organizer, price, capacity, booking or verified opening status.

Only the single CSV `Link` anchor's safe municipal `/Vivere-il-Comune/Luoghi/`
HTTPS href is extracted and entity-decoded; no HTML page is fetched/executed.
Boundary attribute whitespace is trimmed (the observed export has one trailing
space at Item 57); internal whitespace, unapproved destinations, duplicate anchors,
event handlers and malformed attributes fail. A genuinely empty link uses the
metadata dataset page with typed `link_scope=dataset`. Source entrance wording
is access context in detail, not a verified postal address. The optional Notes
field may stay null without fabricated description.

Published `Coordinate GPS` is interpreted as **latitude, longitude** and recorded
as source venue geometry with dataset provenance. A broad 45.8–46.3 / 10.9–11.4
sanity box catches swaps/outliers, not an asserted municipal boundary. Empty
geometry remains valid in List; nonempty malformed geometry fails loudly. No
geocoding, GPS permission or native/private location is consulted.

Actual 2026-10-23 qualification: **116 equipment records, 60 named places, 10 source
types, 37 dataset-level fallback links, zero missing geometry, zero nonempty
notes**. This is an observation, not a permanent count invariant. Decoded UTF-8
SHA-256 `f7a2820e56ce27a12156a64c7223604734997c1e2b27db8bb224af34e86a7e4b`,
27,085 bytes. The real connector fetched one actual export per qualification run;
all 116 records passed the existing canonical transaction and complete anonymous
four-page traversal. Repeating that **same fetched snapshot** changed zero
records and preserved UUIDs/revisions. The disposable source/data were removed.
No hosted source is configured or scheduled.

Opt-in real-source local qualification (fresh non-default disposable stack):

```text
PLANETS_DISPOSABLE_QA=1 npm run activities:trento:verify:local -- --evidence <new-local-json-path>
flutter test test/features/external_activities/external_activities_test.dart --plain-name SPORTDATA01 --dart-define=ACTIVITIES_MUNICIPAL_EVIDENCE=<absolute-json-path> --dart-define=UI_POLISH_CAPTURE_DIR=<absolute-captures-directory>
```

This live-source command is intentionally outside ordinary CI. CI uses bounded
synthetic parser/HTTP fixtures. The opt-in render reads actual sanitized anonymous
DTOs; it does not add product fixtures or provider calls to Flutter. Inspected
[English list](evidence/activities-sports/municipal-places-en-light-360-2x.png) and
[Italian detail](evidence/activities-sports/municipal-place-it-dark-320-2x.png)
captures use 2x text; both themes/languages passed. No physical device is claimed.

## ACTGEO01 canonical external geography

V3 `list_external_activities_v3` adds an explicit `p_area` and `p_map_only`; V1/V2
signatures and native `search_public_geography_v1` remain unchanged. It reuses
`external_catalogue_rows` for all source/rights/publication/cancellation/freshness,
course and date predicates. Category/kind/query/discipline/date/area filter the
complete eligible catalogue before keyset paging. Map is the geometry-bearing
subset of that query, with `external_activity:<canonical UUID>` identity. No
native proposal/resource UUID or protected coordinate enters this scope.

The generated private `published_point` follows canonical content updates and
has geography and geometry-expression GiST indexes. Radius uses PostGIS geodesic
metres; bounds use inclusive index-backed point boxes. Shared MAP04 limits are
unchanged: radius 1–100,000m; ordered non-antimeridian bounds within ±85° latitude,
≤4° spans and ≤50,000km²; 2,000 complete matching spatial candidates. Overly broad
queries fail with `54000`, never truncate silently. Unscoped List retains records
without geometry. Geographic filtering cannot infer whether an unlocated item
lies in an area. No guessed map completeness count is exposed.

V3 cursors bind full filters/area/map-only scope, every eligible source/version,
canonical order and a 15-minute reference. A private database-local 32-byte key
HMAC-signs each cursor, including the keyset position; arbitrary edits/expired
references/source changes fail explicitly. Key table and signer have RLS/denied
raw execution for anon/authenticated/service roles. An owner key rotation safely
invalidates cursors; no client credential or externally configured secret is
required. Older V2 cursor semantics stay compatible.

Distance is rounded geodesic metres from an **explicit selected radius reference**
to a source **venue** point. Locality precision yields null distance, never exact
venue proximity. No GPS, entrance guarantee or nearest ranking is inferred.
Clients use the shared `GeoArea` validation and the strict namespace/distance
parser. Account changes fence pending list/detail results; inactive/mode-OFF
reads remain denied. V3 requires this migration before a live client upgrade;
no backend flag or hosted deployment was enabled here.

Tests include real service/anonymous list/map equality, both sources and all three
kinds, identical points, radius/box boundaries, missing/locality geometry,
cancelled/expired/unpublished records, HMAC tampering/expiry, disabled-source
continuations and unchanged native map contracts. A 2,406-row local synthetic
catalogue selected both GiST indexes (observed 6.236ms radius / 0.093ms bounds,
not permanent timing assertions) and enforced the full-scope cap. No N+1 detail
reads or provider search is involved.

## SPORTAPI02: bounded Open Data Hub checkpoint

**Assessment complete; `odh-trento-sports` connector blocked, not implemented.**
Initial verification ran 2026-10-23 **11:13:47–11:22:01 UTC** (8m14s, within the
20-minute bound), zero unavailable-endpoint retries, no other provider candidates.
[Content API reference](https://docs.opendatahub.com/use-data/content-api/reference/),
[filters](https://docs.opendatahub.com/use-data/content-api/filtering-and-sorting/),
[record licensing](https://docs.opendatahub.com/licensing/) and actual Swagger V1
JSON were inspected. No historical endpoint or title-keyword sports inference was
used. Source-local outcomes and saved-response hashes are in the
[checkpoint manifest](evidence/activities-sports/odh-source-checkpoint.json).

Observed scope is **46.0748,11.1217 / 10,000 metres**, not broadened to Bolzano:

- Baseline ODHActivityPoi reports 353 rows; the first three are STA transport stops
  with empty sports tags. They are not sports offerings.
- Current `/v1/Tag` place-type metadata returns 201 tags. A query using nine
  observed active facility IDs (fitness, football, indoor/outdoor pool, tennis,
  climbing hall/garden) returns **0 local rows**. A separately labelled **global
  control** using four of those same IDs returns **105**, proving the tag filter
  is accepted; that is not local publication evidence.
- A non-STA diagnostic reports 334 rows; sampled SIAT cycling/MTB route records
  have `License=Closed` and `ClosedData=true`. Their record-level evidence must
  override any broad statement that the API exposes only open records. Routes
  are also outside this queue's place/course/event model. They are excluded.
- Explicit open non-STA filtering returns **12 rows in one complete page**:
  two wine-related records and ten charging points. Source categories identify
  gastronomy/mobility, not sports; some are inactive/unpublished. No eligible
  local sport record was verified.
- Trento Event reports one historical 2021 outing. The actual active/published
  window **2026-10-23 through 2027-01-21** returns **0**. No current course was
  identified. Active alone is not evidence of a current session.

Field selection can return literal dotted keys; source `_Meta.LastUpdate` is
not availability confirmation. A future adapter still needs a useful permitted
local subset, current publication/schedule/type checks, record-level CC0/CC BY
policy and verified public-link origins. Closed/proprietary/unknown licences,
transport/retail/route-only material and media/contacts cannot be silently imported.
There is no always-empty adapter or working second-source claim. The resolver's
explicit `source_coverage_checkpoint_blocked` fails before provider/DB IO; the
separately implemented municipal source and synthetic multi-source qualification
remain useful. Reassessment is separate future work; 010/011 continue now.
