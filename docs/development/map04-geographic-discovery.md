# MAP04 geographic discovery

The shared Flutter List/Map view is now implemented in MAP05. It consumes this
unchanged public-only contract and supplies deliberate queries/pages, clustering
and independent disabled provider adapters. See [MAP05](map05-interactive-discovery.md).

MAP04 adds a public, read-only PostGIS API and an unused-by-existing-screens
typed Flutter feature. MAP01/02 edit/search and MAP03 preview/launch behavior
remain separate. No provider request, live-key activation, GPS permission,
hosted migration, production/demo reset or map UI is introduced.

## Exact RPC contract

search_public_geography_v1(p_query jsonb, p_limit integer default 20,
p_cursor jsonb default null) returns jsonb.

EXECUTE is granted only to anon/authenticated, with PUBLIC/service_role revoked.
It is SECURITY DEFINER with empty search_path and schema-qualified dependencies.
The internal geo_public_candidates_v1(jsonb,timestamptz,text,uuid) helper has no
client EXECUTE. No raw table/column grants, RLS policies or existing list/detail
signatures change. Existing authenticated owner column reads remain RLS-bound;
membership is not an owner grant. The public RPC does not branch on identity.

p_query is an object <=8192 bytes; unknown keys are rejected (including SRID,
coordinates/options for other modes, expected actors or provider credentials).

| Input                                              | Contract                                                                                                                                      |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| mode                                               | radius or bounds, required                                                                                                                    |
| latitude, longitude, radius_m                      | Radius only; finite numeric -90..90, -180..180, 1..100000 meters                                                                              |
| south, west, north, east                           | Bounds only; ordered south<north, west<east; latitude -85..85, longitude -180..180; each span <=4 degrees; geodesic envelope area <=50000 km² |
| kinds                                              | Optional nonempty set of one_time, recurring, resource; default all; max3 entries, deduplicated/sorted                                        |
| proposal_keyword, proposal_locality                | Optional, affect Proposals only                                                                                                               |
| proposal_skill_ids                                 | Optional <=20 UUID strings; deduplicated/sorted; ANY matching Proposal skill; does not filter Tavoli/Resources                                |
| tavolo_locality                                    | Optional, affects Tavoli only; canonical next occurrence is derived at the reference time                                                     |
| resource_keyword, resource_locality, resource_mode | Optional, affect Resources only; mode donate or exchange                                                                                      |
| reference_time                                     | Optional first-page ISO timestamp; server default statement time; finite, <=1 minute future and <=15 minutes old                              |

Keyword/locality/mode text is <=120 characters, without control characters,
trimmed and case-normalized. Empty text is no filter. Proposal keyword searches
title/summary/description; Resource keyword searches title/description, using
literal substring matching, not SQL patterns. Unknown but well-formed skill
UUIDs simply match no Proposal. Family-specific field names deliberately make
unsupported cross-family filtering explicit. Radius and bounds keys are
mutually exclusive. Bounds crossing the antimeridian, polar boxes, zero spans
and oversized/global viewports are rejected; radius uses geography worldwide.

p_limit is 1..50. Validation errors return SQLSTATE 22023. More than 2000 cheap
spatial/filter candidates returns 54000, requiring a narrower area/filters;
nothing is silently truncated to suggest complete results.

## Output and pagination

Top-level keys: query_key, reference_time, items, has_more, next_cursor,
attribution. No total/global count or distance is returned.

Each item has exactly: kind, item_id, latitude, longitude, precision,
is_approximate, match_precision, title, cover_object_path,
public_location_label, starts_at, ends_at, event_timezone, derived_status,
listing_mode. Dates/status are Proposal-derived; Tavolo dates/zone use the
existing next_recurring_activity_occurrence helper and status is null.
Resource dates/zone/status are null; listing_mode is donate/exchange and null
for other kinds. Covers use existing canonical object paths. No per-marker
detail/protected/batch RPC is required to render these minimal cards.

precision is locality/address/amenity. Projects/Tavoli are always locality;
their flags are is_approximate=true and match_precision=locality_reference.
Resource locality has the same approximation; public address/amenity uses
is_approximate=false and match_precision=public_point.

attribution contains fixed linked geoapify_url=https://www.geoapify.com/ and
openstreetmap_url=https://www.openstreetmap.org/copyright. MAP05 must use
readable linked MAP03 credits alongside derived location labels and imagery;
the projection contains no raw provenance/receipts/upstream objects.

Ordering is ascending (kind,item_id), a unique mixed-family keyset, independent
of geometry, meeting data, mutable occurrence dates or exact distances.
query_key is SHA256 of normalized filters/area plus canonical UTC reference
time. next_cursor contains exactly query_key, reference_time, kind, item_id,
and exists only when has_more=true. Fetch the next page with the same query
and returned cursor; omit reference_time to inherit the cursor's time, or
supply that same instant. Page size can change. Cursor keys are public query
bookmarks, not signed authorization tokens. Forging a seek cannot widen
public permissions.

Changed area/filters must discard all prior cursors/results. Expired snapshots
must restart. First publication after reference_time is excluded. Proposal
status and Tavolo next occurrence stay frozen across pages; current publication,
public geometry/provenance, and the current Proposal 24-hour discovery cutoff
are rechecked on every statement. This is not a durable MVCC snapshot: live
edits/clears/removals can remove rows, or move older IDs into/out of an area;
refresh to observe the new complete set. Unchanged tied records paginate without
omission/duplication. There is no offset, nearest-order promise or server cache.

## Privacy and canonical eligibility

Only proposals.approximate_location, recurring_activities.approximate_location,
and resource_listings.public_location participate in predicates/results.
Each needs non-null valid MAP01 selected_public_place. Project/Tavolo metadata
constraints limit it to an independent locality. No meeting-details table,
exact point, selected_exact_place, participant/private agreement, receipt,
creator/member/auth data or MAP03 protected read is used for matching/ranking.

Missing selected public provenance, manual/legacy-only geography, or exact-only
Projects/Tavoli have no geographic result. They retain ordinary List discovery.
Clearing or changing the public selection changes subsequent inclusion.
Public exact detail visibility and participation/revocation do not affect geo
results. Location revision is deliberately not returned: an exact-only edit
can increment the shared edit revision without changing public discovery.

Effective list definitions were inspected after all migrations on the disposable
stack. Eligibility matches published Proposals until strictly 24 hours after
end; published Tavoli with a canonical next occurrence at the frozen reference;
published Resources. Draft/cancelled/paused/ended/closed history is excluded,
even where exact-ID detail intentionally retains history.

A locality point is neither a venue nor a municipal boundary. Inclusion is
point-based area-reference matching, not a promise that a hidden meeting lies
inside the radius/viewport. Shared centers remain shared; no jitter, derived
private centroid, reverse geocoding or fabricated municipality polygon exists.

## Spatial work and performance

Six partial GiST indexes cover published, non-null public points with selected
metadata: proposals_map04_radius/bounds, recurring_activities_map04_radius/bounds,
resource_listings_map04_radius/bounds. Radius uses geography ST_DWithin (meters).
Bounds uses the geometry-expression index and inclusive && point bounding boxes;
for a point its bbox is the point itself. No cast defeats the matching index.
PostGIS stays in extensions; longitude is X, latitude is Y, SRID4326.
See [ST_DWithin](https://postgis.net/docs/ST_DWithin.html).

Each family emits at most 2001 cheap candidates. The RPC rejects an aggregate
above 2000 before occurrence/cover enrichment. It then sorts eligible minimal
cards and emits at most limit+1 to derive has_more. There is no global count or
protected per-row RPC. Normal PostgREST role timeouts remain anon 3s/authenticated 8s;
the typed transport also bounds completion to 8s. No anonymous SQL proxy,
background generation or provider-credit reservation is added.

The verifier rolls back 5000 synthetic rows/family (15000 total), analyzes the
three tables, and asserts each representative radius/bounds EXPLAIN uses its
scoped GiST. Captured local PostgreSQL 17.6/PostGIS 3.3 plans are in
[evidence/map04-geography-explain.json](evidence/map04-geography-explain.json).
Single-match plan timings were Proposal radius5.048ms/bounds0.103ms,
Tavolo 0.073ms/0.062ms, Resource 0.071ms/0.070ms. Full mixed RPC 6.399ms.
These are synthetic local samples, not production latency guarantees; first
radius invocation includes cold extension work. Recorded shared reads were0.
New data/density/distributions can change planner choices; retain bounded caps.

## MAP05 handoff and reproduction

apps/mobile/lib/features/geographic_discovery owns GeoQuery, strict GeoItem/
GeoPage/GeoCursor parsing, RpcGeographicDiscoveryGateway and the Riverpod
GeographicDiscoveryController. It checks finite/precision/allowlist/cover/
page/snapshot/order contracts and maps invalidInput, tooBroad, unavailable and
malformed failures. MAP05 now consumes this module from the three List entry
points; its UI and separate provider boundary are documented in
[map05-interactive-discovery.md](map05-interactive-discovery.md).

Use an explicit route/session provider key and active lifecycle signal. Search
starts a new generation; loadMore serializes. Context/identity/readiness/ABA/
disposal changes clear stale results. The README documents refresh/error and
logical cancellation behavior. MAP05 owns map widgets, clustering, marker/card
UX, Search this area, and deliberate new queries. Its independent search-center
gateway uses authenticated-user metering; guest paid lookup stays disabled.
MAP02 authenticated item-bound edit receipts retain their separate purpose.

Task-owned local project planets-map04-qa uses API 55631, database 55632,
Mailpit 55634 and distinct auxiliary ports. Configuration is temporary and must
not be committed. Retained planets-community 54321/54322 and physical phone
48091FDAS0041A are excluded.

Run npm run check:mobile; npm run check:web for generated public types;
npm run check:db only against verified disposable configuration, with
PLANETS_DISPOSABLE_QA=1 and MAILPIT_URL=http://127.0.0.1:55634.
location:verify:local includes MAP01–04 authenticated REST/probes and performance.
Its deterministic SQL fixture is the marked section of
supabase/tests/123_geographic_discovery.test.sql; start from a freshly replayed
disposable database before rerunning (fixtures commit for REST visibility and retire after the verifier).
Set MAP04_EXPLAIN_OUTPUT to an external JSON path to capture plans.
db:types regenerates the public Web RPC signature; db:types:check checks drift.
Final command counts, CI/head and known limitations are recorded in the PR.
