# Geographic discovery (MAP04)

This feature owns the typed public map-search contract, without a map UI.

- domain/geographic_discovery.dart: radius/bounds, family-scoped filters, strict public marker/page/cursor parsing and sanitized failure kinds.
- data/geographic_discovery_gateway.dart: one bounded search_public_geography_v1 RPC, eight-second transport deadline and explicit input/complexity/transport/schema failures.
- application/geographic_discovery_controller.dart: Riverpod route/session ownership, active-context gating, generation invalidation and serialized keyset pages.

MAP05 should create one provider family key per navigation/search session, call
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
from these markers. No map widget/GPS/provider lookup is registered here.
The database remains authoritative for the exact viewport-area limit and
15-minute cursor expiration. See the MAP04 runbook.
