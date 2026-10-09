# Geographic discovery (MAP04/MAP05)

This feature owns the typed public map-search contract and reusable List/Map UI.

- domain/geographic_discovery.dart: radius/bounds, family-scoped filters, strict public marker/page/cursor parsing and sanitized failure kinds.
- data/geographic_discovery_gateway.dart: one bounded search_public_geography_v1 RPC, eight-second transport deadline and explicit input/complexity/transport/schema failures.
- application/geographic_discovery_controller.dart: Riverpod route/session ownership, active-context gating, generation invalidation and serialized keyset pages.
- domain/map_discovery.dart: RAM-only reference/camera preferences, bounded viewport checks, public grid clustering and existing detail destinations.
- application/map_discovery_sessions.dart: per-origin preferences that survive navigation and clear on account/readiness changes.
- data/map_provider_gateway.dart: independent actor-bound search-center/selection and fixed XYZ tile transport; both disabled by default.
- presentation/map_view_button.dart: shared full-width, equal-half List/Map selector on feeds and Map; only the inactive half navigates, preserving the originating route and applied filters. Return pops when possible, otherwise goes to the origin's List root.
- presentation/map_discovery_screen.dart: shared controls, explicit queries/pages, loaded-only chooser/card, lifecycle and attribution.
- presentation/public_point_map.dart: Flutter renderer and bounded custom tile queue; no provider URL/key in client code.

MAP05 creates one provider family key per navigation/search session, calls
setActive(true) only while foreground/current, search(query) after selecting an
area, loadMore() while ready, and setActive(false) on route/lifecycle departure.
Any auth phase/identity change clears results and query; the new context must
explicitly search again. Inactivity retains only the query for a fresh read on
resume; no result cache survives. Provider rebuild resets all ownership.
Generation cancellation discards late callbacks; it does not promise HTTP/SQL
transport abortion. A failed extra page keeps confirmed public rows with a
failure state; refresh with search(query), never present failure as empty success.

Use the marker precision flags and linked MAP03 attribution for every retained
derived label. Locality points are reference matches, not municipal extents or
venue distances. Do not derive nearest-first ranking, private URLs or directions
from these markers. The default map is a truthful no-basemap canvas; GPS and
anonymous paid-provider lookup are absent.
The database remains authoritative for the exact viewport-area limit and
15-minute cursor expiration. See the MAP04 runbook and
[MAP05 behavior/configuration/activation](../../../../../docs/development/map05-interactive-discovery.md).

MAP-CACHE01 adds domain/basemap_tile.dart (byte-affecting identity),
domain/basemap_viewport.dart (demand-only XYZ composition),
application/shared_basemap_tiles.dart (app-owned public LRU, bounded scheduler,
revocable protected scopes and lifecycle/auth invalidation), and
presentation/read_only_basemap.dart (uncached native detail pixels/local overlays).
The discovery GatewayTileProvider now shares compressed bytes while retaining
route-owned ImageProvider resources. See [cache ownership and opt-in](../../../../../docs/development/map-cache01-shared-tiles.md).
