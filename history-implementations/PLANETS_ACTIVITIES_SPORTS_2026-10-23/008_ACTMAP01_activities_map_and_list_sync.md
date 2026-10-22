# ACTMAP01 — connect Activities and Sports to the shared map

Read [001_context.md](001_context.md). Depends on 003/004/007; live connectors are optional for local synthetic validation. This is an actual backend-connected Flutter map, not a static preview or mock map route.

## Outcome and existing foundation

From Activities, particularly Sports/Places, **List / Map** opens a useful map of that exact external-catalogue query, keeps filters/camera/navigation coherent, and opens the same kind-aware details. Reuse the existing geographic discovery renderer, query controls, clustering, lifecycle, public basemap cache/budget gateways and attribution.

Inspect current `geographic_discovery` feature, strict `GeoKind`/query/cursor parsers, `MapDiscoveryOrigin`/family/session routing, `MapViewButton`, Browse switcher and latest map-fix runbooks. Do not fork the 38k map screen wholesale or create a second tile/client cache implementation. A modest extraction of reusable public UI can be justified, preserving native contracts and tests.

## Required integration

- Add an Activities-origin map entry in the enabled experiment and a **working** List/Map selector in the Activities/Sports list. Turning the mode OFF removes/gates external experiment routes and stops new external reads; baseline Projects/Tavoli/Resources maps keep working.
- Carry category, kind, discipline, query, applicable date scope and any explicitly selected geographic reference into the new canonical 007 search. Do not substitute default All, lose Sports/Places on first load, or filter only returned pins in memory.
- Keep the same state authority for filters across List/Map. Either edit relevant filters directly through that shared authority or provide a clear Edit filters in List action that preserves camera/reference. Do not maintain two silently divergent filter stores. Detail-back restores map selection/camera and List-back restores scroll/filters as existing routes permit.
- Retain existing explicit search behavior: moving the camera alone does not import or query providers continuously; **Search this area** submits validated bounds. Radius/reference choices have a truthful label. The initial Trento reference is not GPS, a verified current position or a permanent geographic restriction. No new location permission request.
- Display typed public external markers for event/course/place, visually distinguishable without relying on color alone. Reuse clustering/loaded-entry chooser and explicit Load more. Several equipment entries at one park/coordinate remain individually selectable; cluster counts are loaded **results**, not distinct parks, attendees or all matches.
- Selecting a pin/cluster entry shows concise kind-aware public information and navigates to the actual external detail route using its canonical UUID. Existing native detail destinations remain unchanged. Do not route through native join/chat/creator flows.
- Missing-geometry items stay in List. Present a modest accurate indication when useful; never invent coordinates, claim all results are mapped, or hide the useful List when no pins exist. An empty map, loading, backend failure, stale/partial source health, invalid viewport and expired cursor are different states.
- For source-provided public venue points, make their precision clear without the old redundant diagnostic essays. Locality points remain approximate at high zoom; any displayed distance uses the explicit reference and permitted precision, not claimed GPS/entrance certainty.
- Source disable/expiry/currentness is respected on fresh map reads/detail loads. Cancel/discard late responses on filter/area/account/mode/lifecycle changes. Keep route-owned rendered resources and existing public byte-cache policy scoped as documented.
- Preserve ACTMET01's existing event definition. Do not start analytics from marker builds, map drags, clusters or arbitrary new surfaces; keep production denied. Existing list card and official-link share hooks remain intact.

## Basemap and native-flow constraints

Use current flags/gateways exactly; no direct provider URL/key, public OSM tile or Nominatim fallback, new geocoding quota, billing or automatic map activation. With basemap/center lookup unavailable, canonical map results/controls remain functional on the existing honest no-basemap canvas. Show attribution only as required by actual displayed/provider-derived content under current policy.

Projects/Tavoli remain governed by native public approximate geometry; external public facility coordinates must not relax native protected-location policies. Native Tavoli are reachable via their separate entry and existing map, not silently combined with the external Activities list/counts. Keep current global/native map default scopes stable.

## Acceptance and visual QA

Test list Sports/Places + discipline/query → Map → cluster → selected place detail → Back → List, retaining filter tuple/scroll/camera as designed. Include an event/course, two entries at one coordinate, locality precision, no-geometry records, two paginated sources, source disable, late response, off-mode transition and account/background replacement.

Run widget/controller/router and backend-connected local HTTP journeys. Inspect actual rendered screens for populated/empty/error/no-basemap/stale states, IT/EN, light/dark, 320/360 dp and 2× text where layout is dense. Count actual provider attempts: flags OFF must produce **zero new upstream provider traffic**. Validate relevant native map/cache/Settings/tutorial regressions and build Android when supported.

Update map/catalogue runbooks, feature maps, queue progress and visual evidence; merge and continue 009. Phone/iOS interaction remains unverified unless actually exercised; a screenshot is not native-device QA.
