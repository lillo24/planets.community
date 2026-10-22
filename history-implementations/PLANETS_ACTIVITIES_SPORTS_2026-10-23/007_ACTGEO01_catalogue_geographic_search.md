# ACTGEO01 — canonical geographic search for external Activities

Read [001_context.md](001_context.md). Hard dependencies: 002 and 005. **006/009 live-source success is not required.** Build/test with synthetic licensed local sources, then continue 008.

## Outcome and implementation boundary

The backend can search the same public external catalogue by radius or viewport, with kind/category/discipline/query/date predicates applied before pagination. Sports places and events/courses with valid published geometry become map candidates. Items lacking geometry remain valid list records. Reuse the current MAP04 search and precision architecture rather than adding provider searches or a separate geocoder.

Inspect the current `search_public_geography_v1`, MAP04 migration/tests/runbook, native public-geometry projection, 002/005 public eligibility and catalogue filters. The current native `GeoKind` has one-time, recurring and resource variants; current RPC inputs/outputs are strict. Choose an additive version or compatible extension; do not surprise old mobile parsers with unrecognized kinds or change the native default All result set.

## Required contract

1. Give imported items an explicit namespaced identity/kind and their existing catalogue UUID. Preserve event/course/place subtype and source-backed public precision. Never route an imported UUID to `/proposals`, `/tavoli` or `/resources`.
2. Geography must come from validated published external source geometry. Store/index it canonically using existing PostgreSQL/PostGIS conventions. Keep coordinate order, finite/range checks, precision and provenance aligned across validators, persistence and readers. Do not infer a map pin from a city string, source label, linked venue without geometry or private native meeting address.
3. Preserve every licensed-public gate on list/detail/**map**: source enabled/rights, publishable state, per-record freshness/expiry, kind-specific currentness and cancellation. Map querying is not an alternate route around source disable or expired record restrictions. Recheck current gates on each page even when the cursor has an older reference time.
4. Radius and viewport use current bounds/complexity conventions, validated finite input, a reference time and deterministic keyset pagination. Bind cursors to the full filter tuple, area/mode, source versions and ordering; reject invalid/expired/tampered cursors explicitly.
5. Support category, kind, discipline, literal query and applicable date scope over the **full eligible catalogue**, not a downloaded first page. Reuse one canonical predicate/helper where appropriate so list/map are consistent. Place eligibility must not require an upcoming date.
6. For a radius, use canonical geodesic metres; for bounds, an index-backed intersection on public geometry. Reuse existing scope limits rather than raising them incidentally. Test non-antimeridian limits and invalid/reversed/broad bounds according to current MAP04 policy.
7. Define metadata for map completeness carefully: pagination means returned/clustered pins are loaded results, not all city facilities. If a list reports that some matching items have no map location, compute it from a consistent eligible scope or use nonnumeric copy; never subtract a loaded pin count from a guessed total.
8. Distance is from the explicitly selected search reference to the published point, not GPS or a guaranteed entrance. Show a numeric venue distance only for adequate source precision; locality points must not be advertised as exact venue proximity. No automatic nearest ranking across coarse native locality markers.
9. Support controlled integration with the shared map family/route. The new Activities scope represents external catalogue items. Native Tavoli retain their own existing list/map entry and filter/count contracts; do not secretly include native records in external query results. Existing native/global maps preserve baseline behavior unless a new explicit external kind/scope is requested.
10. Expose only sanitized card/marker fields needed to navigate/render. Source config/run diagnostics/raw payloads/contacts/service keys remain private. No imported images or untrusted remote icon URLs.

## Storage and performance

Use additive migrations and real indexes appropriate for spatial predicates plus enabled/publishable/freshness selection. Inspect plans on a reproducible moderate synthetic catalogue; avoid N+1 per-item RPCs or performing whole-table great-circle math in Flutter. A targeted measured query plan is enough; do not create a speculative distributed search engine or enormous benchmark.

Maintain old native search signatures, privilege restrictions and approximate/exact policies, plus old external event-client compatibility. Regenerate types and document the new map/list query tuple and error states. Do not activate provider flags, raise map credits, grant public source-table reads or modify native location visibility.

## Acceptance tests and evidence

- Disposable local migration replay, SQL/RLS checks and anonymous HTTP reads for events/courses/places across two sources; deny raw/private access and public writes.
- Include rows inside/on/outside radius and viewport, identical coordinates, public venue and locality precision, no geometry, cancelled/expired/unpublished rows and a disabled source. Verify no native protected coordinate leakage.
- Paginate beyond one page with kind/category/discipline/query/date combinations; assert no duplicates/missing eligible rows, cursor invalidation after source change and no source reappearance after disable.
- Compare complete list/map matching scopes: mapped records are exactly the geometry-bearing subset of the corresponding external list, subject to the same filters/currentness. Verify an undated place remains discoverable and a course without a calculable session follows 002's policy.
- Old native map tests/contracts remain green. Explain/index checks show bounded query behavior on synthetic data. Run changed-area validation and required CI.

Update geography/catalogue runbooks, ownership maps and queue progress; merge and proceed to 008. A source-access blocker is not a blocker to this backend contract.
