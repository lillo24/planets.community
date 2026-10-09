# MAP05 interactive public discovery

MAP05 adds one shared Flutter map route, `/discover/map/:origin`, reached through
List/Map controls on Progetti, Tavoli and Scambio/Dona. MAP04's public
`search_public_geography_v1` remains the only source of results and geometry.
MAP01 item editing, MAP03 private previews and existing List RPCs retain their
contracts. No provider, hosting, key, billing or policy publication is activated.

## User behavior and ownership

MAP-UX01 uses the same full-width equal-half List/Map selector in every feed
and on Map, with selected semantics and keyboard access. The selected half does
not navigate. The inactive List half pops the preserved route or falls back to
the appropriate origin root for a directly opened map.

Entry inherits Projects' keyword/locality/ANY skills, Tavoli's applied locality,
and Resources' keyword/locality/Dona-or-Scambia selection. Each filter still
applies only to its original family when the map selects All. Map family choices
never write List state. Return to List to edit those filters. Pushing Map retains
the existing List route, scroll and controls; detail pushes use the existing
`/proposals/:id`, `/tavoli/:id` and `/resources/:id` routes. Create and contextual
My Drafts remain accessible from Map.

The initial Trento reference (46.0748, 11.1217, 5 km) is explicitly a search area,
never GPS. Radius choices are 1/3/5/10/20/50/100 km. Moving/zooming changes only
the camera. Search this area deliberately switches to bounds; ordered bounds
must satisfy MAP04's four-degree spans and a conservative client 49,000 km²
rectangle test below the canonical 50,000 km² limit. Invalid or antimeridian
viewports request zooming in. Back to radius and Use map center are explicit.
The latter is a user-chosen reference, not a verified geocoder result.

The independent place field debounces 350 ms, requires explicit suggestion
selection, supports IT/EN, and never writes an item, draft, template or account.
Preferences (family, radius, reference and camera) are RAM-only per origin;
List/Map and detail navigation restore them. Account/readiness changes clear
them, including Alice → Bob → Alice. Public rows live only in MAP04's active
route controller. Route/background changes clear rows, cancel pending selection
generations and dispose tile providers. Resume searches afresh. HTTP already
sent may finish; discarded responses cannot repopulate the screen.

Clustering sorts/deduplicates loaded public identities into a 64px Mercator grid
at integer zoom 7–18, O(N log N). The first stable keyset identity anchors each
cell; appending pages does not move it through averaging. Identical locality
points always offer a loaded-entry chooser. Counts describe loaded results,
never the total or unloaded candidates. Pages are 20 with explicit Load more.
Failed additional pages retain confirmed rows and retry the same cursor;
expired cursors require Refresh. Changed filters/areas clear old pins. Empty,
offline, malformed, too-broad and expired states have separate copy.

Project/Tavolo pins use public locality reference points and approximate copy,
even at high zoom. Resource pins can use their existing public address/venue
policy and distinguish Dona from Scambia. The card uses only MAP04's sanitized
kind/title/cover/public label/date/mode. No private exact geometry, organizer
contact, membership, venue-distance guarantee, hidden image or private URL is
used. Manual-only records stay in List and have no invented map point.

## Renderer and disabled behavior

Pinned `flutter_map` 8.3.2 and Apache-2.0 `latlong2` 0.9.1 fit the resolved SDK constraints.
The renderer is pure Flutter; its BSD-3-Clause license and bundled third-party
notices remain available through Flutter's license registry. Its installed
custom TileProvider API was reviewed. It has no Google SDK or platform map key.

Both Flutter compile-time flags `LOCATION_MAP_CENTERS_ENABLED` and
`LOCATION_MAP_TILES_ENABLED` default false. The disabled gateway initializes no
provider transport and makes zero paid-service requests. Public MAP04 results,
filters, radius, camera, clustering, cards and List remain available on a plainly
labelled no-basemap canvas. There are no fake streets, OSM public-tile or
Nominatim fallbacks, GPS prompts, offline map downloads or background scans.

The custom TileProvider accepts only application gateway bytes. TileLayer has
256px tiles, zoom 7–18, no rotation, zero pan/keep buffers, 350ms debounced tile
updates and no automatic retries. The app queue is bounded at 64 with six
concurrent loads and at most 64 owned image keys. Decoded tiles are RAM-only
while rendering and are evicted on route/background/account disposal; nothing
is written to disk. Tile failure visibly removes the basemap while keeping public
results. Geoapify and OSM copyright links remain in a fixed SafeArea footer and
in the cluster chooser, with link semantics and wrapping touch targets.

## Separate authenticated provider API

`supabase/functions/map-provider` owns POST search/resolve/tile with strict
operation-specific JSON keys, maximum 2 KiB body, and no URL query bag.
Every enabled request requires `expected_profile_id` equal to the actor verified
by Supabase Auth `/auth/v1/user`. Guests have no paid lookup or imagery, even
when flags are on. Forwarded IP, client installation IDs and asserted IDs have
no authority. Public geographic discovery itself remains anonymous-capable.

- Search: `{operation:"search",expected_profile_id,query,language}`. NFC 2–160,
  IT/EN, fixed Italy-only Geoapify autocomplete, Trento ranking bias and five
  suggestions. Only MAP01's pure upstream sanitizer is shared; no editor API,
  revision/slot/session/receipt or listing mutation is reused.
- Resolve: `{operation:"resolve",expected_profile_id,suggestion_id}`. Server-issued
  actor-bound UUID, valid for five minutes. Suggestions contain only id, label
  and expiry; explicit resolve returns label/latitude/longitude/country_code.
- Tile: `{operation:"tile",expected_profile_id,z,x,y,style:"osm-carto",version:1}`.
  Integer XYZ in the zoom's range. Fixed HTTPS Geoapify
  `/v1/tile/osm-carto/{z}/{x}/{y}.png`, 256×256 PNG, 256 KiB, fixed Accept header,
  no redirects, no arbitrary URL/style/query, bounded streaming and 3.5s deadline.

The Edge entrypoint uses server-only `GEOAPIFY_MAPS_KEY`, `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`. Auth/REST transports have two-second deadlines;
Flutter has an eight-second operation deadline. Binary uses
`application/octet-stream` to avoid functions_client UTF-8 decoding. Responses
are no-store. App metrics contain fixed status only; no requests, queries,
coordinates, labels, provider IDs, errors, JWTs or API keys are logged. Review
ingress/provider logging and privacy separately before activation.

## Shared account ceiling and migration

Additive migration `20261009083736_map05_interactive_discovery_provider.sql`
creates private config, usage and transient cache tables with RLS and no raw
anon/authenticated/service grants. Three narrow public RPCs are executable only
by service_role: reserve_map_provider_v1, finish_map_provider_v1 and
resolve_map_center_v1. They have hardened empty search paths. The internal ledger
function is not service-callable. Existing MAP01/MAP03 reserve signatures,
permissions and stricter legacy quotas remain; their effective definitions gain
the shared gate. Applied migrations are untouched. Generated Web types include
the service RPC signatures without granting clients execution.

One integer unit is 0.25 credit: tile 1 unit, editor autocomplete 4, map center
4, static preview 16. All four consumers lock search-config then provider-config
in the same order and reserve atomically before upstream IO. Current UTC-day
legacy reservations import ×4 on upgrade; no refunds after failures/timeouts.
UTC-day global and actor totals cannot exceed configured limits. All PLANETS
Geoapify traffic must use these gateways; out-of-band consumers on the same
provider account would invalidate this ceiling and must be excluded or included
through a separately approved integration. Provider soft quotas are insufficient.

`private.location_provider_config` defaults:

| Field                          | Default / bound | Purpose                                                     |
| ------------------------------ | --------------- | ----------------------------------------------------------- |
| enabled                        | false           | Remote master kill for all four consumers, including caches |
| daily_units_limit              | 0 / 0–8000      | Owner account ceiling; zero is unconfigured                 |
| actor_daily_units              | 320 / 1–8000    | Per actor/day, default 80 credits                           |
| actor_minute_requests          | 120 / 1–120     | All consumers and cache/resolve hits                        |
| global_minute_requests         | 600 / 1–600     | Account request abuse control                               |
| center_enabled / tiles_enabled | false           | Independent new consumer gates                              |
| cache_license_approved         | false           | Owner approval prerequisite for new caches                  |
| tile_cache_seconds             | 0 / 0–3600      | Must be positive for live tiles                             |
| failure_streak / blocked_until | 0 / null        | Five map failures open one-minute circuit                   |

The new master is an additional activation prerequisite for existing editor and
static adapters too. Their prior environment/SQL/license gates remain required.
Missing configuration fails closed. Request limits run on cache hits; only
cache misses reserve upstream units. Anonymous existing static usage shares a
bounded anonymous source bucket; new tile/center calls always require a user.

Center caches are actor-local five-minute sanitized selections, without raw
search text or provider IDs (query keys are SHA256 digests including actor and
language). Tiles are public shared fixed-style cache entries with owner-approved
TTL. Pending entries deduplicate for at most 30 seconds; failed entries for 15.
Expired entries are unusable immediately and physically pruned on the next map
reservation. Usage older than the current UTC day is pruned on the next meter
request. **TTL is validity, not a promised wall-clock deletion job**: a quiet
database can retain expired records until pruning. Before live use, the owner
must approve this retention or schedule bounded SQL cleanup in its chosen
runtime. No managed-only scheduler or production provisioning is introduced.

## Activation checklist (account owner)

1. Review current provider contract, caching/proxy/redistribution rights, OSM
   attribution and privacy disclosures. Approve five-minute actor-local center
   retention, chosen tile TTL, active-renderer RAM retention and expired-row
   pruning/deletion policy. Generic public terms do not establish a specific
   cache entitlement. Record any additional style credits. No terms were accepted
   and no policy page was published in MAP05.
2. Use an owner-controlled account/key whose PLANETS consumers all share this
   ledger. Approve credit/day and actor/minute limits after checking current
   prices/account allowance. Keep ceiling at zero and flags off until approved.
   Do not split traffic among accounts/projects to evade provider billing.
3. Configure the Edge server secrets and independently approved center/tile flags
   in the chosen local/self-hosted runtime. Never place a Geoapify or service key
   in Dart defines, public environment or a tile template. Set database master,
   limits, consumer/cache gates and positive approved tile TTL explicitly.
4. Rehearse actual Auth/JWT checks, network deadlines, private grants, hard-ceiling
   concurrency, cache rates, circuit and kill behavior in an isolated environment.
   Review self-hosted ingress/logging and key restrictions. Guest paid lookup
   stays disabled; enabling it requires a separately reviewed trusted perimeter.
5. Build mobile with only the approved `LOCATION_MAP_*_ENABLED=true` defines.
   Run owner-authorized real Android/iOS tile, quality, latency, attribution,
   screen-reader and keyboard checks. The offline fixture is not live-provider
   or physical-device evidence. Stage a small rollout and inspect fixed-status
   counts and private aggregate units without logging queries/locations.
6. Shutdown: set database enabled=false first (blocks new reservations, cache
   reads and MAP05 finish responses), then disable all provider Edge flags;
   remove/rotate the provider key using account-owner
   tools. Clear approved transient caches when required. Revocation does not
   recall an already delivered public tile or a legacy request already reserved
   before shutdown; clients dispose map tiles on departure.
   Re-enable only after reviewing remaining reservations and the failure cause.

Official references checked 2026-10-09: [renderer](https://pub.dev/packages/flutter_map),
[custom tile providers](https://docs.fleaflet.dev/layers/tile-layer/tile-providers),
[Geoapify fixed raster endpoint](https://apidocs.geoapify.com/docs/maps),
[credits](https://www.geoapify.com/pricing-details/),
[terms](https://www.geoapify.com/terms-and-conditions/),
[OSM copyright](https://www.openstreetmap.org/copyright),
[OSMF raster policy](https://operations.osmfoundation.org/policies/tiles/),
[Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/).
The OSMF public raster policy is not permission to proxy Geoapify tiles; no OSMF
tile endpoint is used. Public Nominatim autocomplete is prohibited by its policy
and is absent. Recheck terms and prices before live enablement.

## Reproduction and evidence

Run `node --test scripts/lib/map-provider.test.mjs`, focused Flutter
`test/features/geographic_discovery` tests, `npm run check:mobile`,
`npm run check:web`, and `npm run check:db` only with an explicitly verified,
disposable loopback stack. The location verifier now retains MAP01–04 probes and
adds real authenticated/anonymous/service REST grants, concurrent final-quarter
reservations, pending dedup, cache expiry, actor selection and mid-fetch kill.
SQL tests are rolled back; no fake flag is deployed.

The Android journey uses real List/Map/detail widgets and offline gateways;
HttpOverrides rejects and counts any attempted network access. Use a new owned
AVD and explicit serial, never phone 48091FDAS0041A, another emulator or the
retained planets-community 54321/54322 stack. From apps/mobile:

```powershell
$env:MAP05_CAPTURE_DIR = '<task-owned capture directory>'
flutter drive --driver=test_driver/map05_driver.dart --target=integration_test/map_discovery_smoke_test.dart -d <owned-emulator-serial>
```

`map05_app_fixture.dart` owns real widget wiring, `map_discovery_fixture.dart`
owns sanitized public DTOs and decodable neutral tiles, integration_test owns
the deliberate journey, and test_driver owns host screenshot export. Native
iOS, real provider imagery, billing, production ingress and physical-device QA
remain external activation work. See the [MAP05 validation record](map05-validation.md)
for measured results and any environment limitations.

## MAP-CACHE01 shared byte ownership

GatewayTileProvider now delegates compressed bytes and request scheduling to the
app-owned shared public basemap store; its decoded image resources remain route
owned and are evicted on disposal. Eligible detail previews use the same tuple/grid
and store, with an independent default-off opt-in. Client retention defaults to
zero and needs a reviewed explicit TTL. See [MAP-CACHE01](map-cache01-shared-tiles.md)
for protected isolation, bounds, cancellation and quantified fake reuse.
