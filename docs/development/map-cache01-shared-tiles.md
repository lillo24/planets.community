# MAP-CACHE01: shared basemap bytes and detail previews

Discovery's existing `GatewayTileProvider` and the single Project/Tavolo/Resource
`LocationPreviewPanel` now use `sharedBasemapTilesProvider`. The detail panel
composes the same 256px XYZ tiles in `ReadOnlyBasemap`, draws the symbol locally,
and retains the existing label, attribution and freshly reauthorized Maps button.
There is no second SDK, provider URL, client key, migration or paid-provider activation.
Cards and the full-width List/Map selector retain MAP-UX01 behavior.

## Ownership and bounds

- Identity is `(provider, style, version, dimension, density, z, x, y)`.
  The supported live adapter remains Geoapify / osm-carto / v1 / 256 / 1x;
  unsupported rendering variants fail explicitly. No item, account, title,
  overlay, exact coordinate or protected screenshot is a shared cache key/value.
- Public compressed bytes use an LRU with independent **64 tile / 4 MiB** caps.
  PNGs are bounded to 256 KiB each and validated for header, dimensions and end.
  Expiry is checked on access/insertion/inspection and one bounded expiry timer
  releases idle bytes. The default clock uses elapsed time so changing the device
  wall clock cannot extend retention. There is no prefetch or disk storage.
- `LOCATION_MAP_CACHE_SECONDS` defaults to **0** (no retention), accepts 0–60,
  and fails on invalid bounds. A nonzero live value requires owner-reviewed
  retention rights and must not exceed the approved server `tile_cache_seconds`.
  Tests inject 60 seconds; this is fixture configuration, not an approved live TTL.
- The shared scheduler permits six active / 64 queued requests. Concurrent public
  misses coalesce. Cancelling one viewport leaves other subscribers intact;
  cancelling the last aborts transport and removes queued work. Failures are
  evicted. Aborting cannot undo a server reservation already made.
- Each viewport owns decoded pixels. Discovery retains at most 64 image-provider
  identities and evicts them on route disposal. Details decode directly, outside
  Flutter's global ImageCache, and synchronously dispose their images on revoke.
  A detail is 144dp high, up to 768dp wide, with no pan buffer or gesture handler.
  Public reference areas use an open symbol and approximate semantics, not a venue
  dot, municipal boundary or invented distance. Exact public Resources use a pin.
- Public compressed bytes survive route disposal. Auth phase/identity changes
  (including A→B→A), app backgrounding, memory pressure and provider disposal clear
  shared memory and invalidate all pending scopes. No cross-account reuse.
- Observed `disabled`, `unconfigured` or `guest_disabled` shuts the store off and
  clears it for that provider instance. Cached hits check local enable/auth state
  first. The server still gates and meters every real gateway request, including
  Edge cache hits. A client hit does not contact the server: a remote switch cannot
  recall already-presented pixels or become known until a request reports it.
  No new remote cache-authorization API or polling was introduced.

Protected exact selection/bytes belong to a widget/authorization scope, capped at
16 tiles / 4 MiB, and **never populate the public LRU**. Already-public bytes may
be copied into that scope. Revoke zeroes its compressed buffers and destroys its
decoded pixels; late transport buffers are zeroed and late decodes disposed.
The canonical MAP03 read, actor/revision checks, 15-second lease, route visibility,
membership/management/meeting listeners and fresh Maps-tap read remain authoritative.
Lease renewal destroys the transient tiled view before reauthorization; it may
make fresh gateway requests, even when the server can satisfy them from cache.
MAP04 public discovery never receives this exact projection.

## Opt-in and static compatibility

All live flags still default off. `LOCATION_DETAIL_TILES_ENABLED=false` is an
independent detail opt-in; `LOCATION_MAP_TILES_ENABLED=false` still gates tile
transport. A guest cannot use the authenticated paid adapter. With imagery off,
no tile/static request or blank map region is mounted; canonical text and the safe
Maps action remain. A legacy projection without coordinates produces no map.

The static provider remains hardcoded disabled. An explicitly injected/enabled
static provider is used only when detail tiles are **not selected**. Selecting
tiles suppresses static generation even if tiles are disabled, fail, or the viewer
is a guest. There is no silent 4-credit fallback and no simultaneous tile/static
request. Existing static public-area caching and protected-image behavior remain
available for separately selected compatibility use.

## Reproducible fake evidence

`shared_basemap_tiles_test.dart` compares zero-retention and 60-second retention
with the same demand-only viewport grid, Trento reference 46.0748 / 11.1217,
zoom 12, detail 320×144, map 320×400. A neutral synthetic PNG is 762 bytes;
these are fixtures, not street-map compression or device-memory benchmarks.
Detail zoom intentionally matches discovery's initial zoom 12.

| Scenario | Loaded tiles | Distinct IDs | Gateway without / with client retention | Edge hits without / with | Upstream misses / reserved units | Hypothetical credits | Shared bytes with retention |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Five same-area details | 30 | 6 | 30 / 6 | 24 / 0 | 6 | 1.5 | 4,572 |
| Map → five details → Map | 42 | 6 | 42 / 6 | 36 / 0 | 6 | 1.5 | 4,572 |
| Map zoom 12 → detail zoom 13 | 10 | 10 | 10 / 10 | 0 / 0 | 10 | 2.5 | 7,620 |
| Protected detail → revoke | 6 | 6 | 6 | 0 | 6 | 1.5 | 0 |

The fake Edge cache stays warm, so client retention saves gateway requests, **not
additional paid credits** in these sequences. If every baseline request were a
real upstream miss, the first two baselines would instead reserve 30/42 units
(7.5/10.5 credits). The canonical ledger charges one quarter-credit unit per real
tile miss, versus 16 units / 4 credits per static render and four units / one credit
per center/editor request. Five distinct cold static renders would reserve
80 units / 20 credits; no static renders occur in the tiled fixture.
Changing zoom saves **zero** tiles in this example. Different XYZ/style/version/
dimension/density identities cannot alias; the current live adapter intentionally
supports only its existing fixed style/version/dimensions.

The protected fixture holds 4,572 private compressed bytes before revoke and zero
after, with zero shared entries throughout. Six decoded 256×256 RGBA images
represent about 1.5 MiB of pixel data, excluding engine/codec overhead. The active
public detail has the same decoded estimate; shared bytes are separately bounded.
The widget integration uses the real discovery TileLayer and real shared Project,
Tavolo and Resource detail location widgets: Map → A → B → Tavolo → Resource → A
→ Map makes **six gateway calls for six unique IDs**, 4,572 shared bytes, zero
static renders. Same-grid public overlay changes/rebuilds add zero gateway calls.

Focused tests cover TTL, LRU/count/byte limits, six/64 backpressure, cancellation,
coalescing, malformed/failing data, public borrowing/private erasure, memory
pressure, shutdown, guests, lease/late completion, account ABA, route/background,
leaving/removal/demotion/meeting revoke, synchronous native pixel disposal,
EN/IT 320px 2×, parent scrolling, keyboard, semantics, credits and one Maps action.
All imagery is injected; tests have no Geoapify API transport/key. The unchanged
map/static Edge adapter suites exercise injected fetchers and reservation failures.

Reproduce from the repository root with `npm run check:mobile` and
`node --test scripts/lib/map-provider.test.mjs scripts/lib/location-preview.test.mjs`.
For the 28 focused cache/widget cases, from `apps/mobile` run
`flutter test test/features/geographic_discovery/shared_basemap_tiles_test.dart test/features/locations/location_tiles_widget_test.dart --reporter expanded`.
The expanded output contains the quantitative rows above. No SQL/service source
changed, so no retained/local/hosted database reset is part of this validation.

## Activation follow-up

No staging settings, secrets, account budgets, Edge deployments, DB master/license
gates, policies or Play artifacts were inspected or changed. Their hosted state
was not reverified. Retained demo services and the physical phone were untouched.
No live Geoapify **API** calls, physical Android/iOS tests or emulator rehearsal
were performed; automated widgets are not device or hosted-provider evidence.

Owner review must still select applicable Free/paid terms, backend proxying and
retention rights, approved client/server TTL, budget and attribution/disclosures,
then separately authorize provider activation and native Android/iOS/live testing.
Geoapify's [tiles page](https://www.geoapify.com/map-tiles/) discusses caching and
0.25 credits per tile; its [static page](https://www.geoapify.com/static-maps-api/)
discusses reuse with attribution. [Terms](https://www.geoapify.com/terms-and-conditions/)
require OSM attribution and Geoapify attribution on Free, with production Free
usage limitations requiring review. These pages were read on 2026-10-09; reading
them does not approve PLANETS' license or enable its traffic. No additional cache
implementation follow-up is required for this bounded plan; live activation
and device verification remain separate work.
