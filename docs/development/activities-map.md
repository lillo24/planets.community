# External Activities map

ACTMAP01 is an explicit external catalogue scope at `/activities/map`. Native
Projects/Tavoli/Resources retain their existing map family, strict GeoKind parser,
default All scope and authorization. The Activities experiment route guard also
covers map deep links. No bottom tab or native join/create flow is added.

## One query, two rendered views

`externalActivitiesControllerProvider` owns category/kind/discipline/query/date
and the optional shared `GeoArea`. The map controller listens to that authority
and owns only its result/cursor lifecycle with `mappedOnly=true`. There is no
second editable filter store. Pending search is flushed deliberately before
opening Map. Edit filters in List returns to the same retained route. A real
filter/area change resets List paging/scroll; detail-back without changes retains
the offset. Camera and selected canonical identity stay in RAM for the current
account/realm/experiment, with no disk location/search history.

The initial view is Trento, not GPS or a permanent query restriction. An unscoped
query still covers all eligible source locations. Dragging/zooming moves only the
camera. Search this area explicitly submits validated bounds; Use displayed
centre explicitly selects a radius reference. Radius and bounds use the shared
MAP04 caps and canonical [V3 contract](activities-sources.md#actgeo01-canonical-external-geography).
Clear area also works in List. No geocoder, location permission or upstream import
is triggered by these actions. Refresh reads the backend only.

## Shared public renderer and privacy

The existing `PublicPointMap` is a native adapter over `PublicMapCanvas`; both
scopes share the camera, stable 64-pixel grid clustering and loaded-entry chooser.
No copy of the large native map screen or second tile/cache implementation exists.
The canvas stays mounted while its modest controls/selected card scroll, as in
the native map. External markers use event/course/place icons and a locality
outline, not color alone. Cluster counts are loaded results, including distinct
equipment at one coordinate, never people/parks/all matches. Load more is explicit.

External namespaced UUIDs open `/activities/external/<UUID>` only. A selected card
labels source precision and shows a numeric reference distance only when V3
supplies a permitted venue distance. No private/native address or client-derived
great-circle calculation is involved. Unlocated results remain usable in the
unscoped List; the map uses nonnumeric completeness copy. Source disable/expiry
on a fresh read removes pins; unavailable detail has no stale action fallback.

`GatewayTileProvider`, `SharedBasemapTiles` and `BudgetTileProvider` retain their
existing enabled/auth/realm/lifecycle/cache/budget policies. With provider flags
OFF the map renders the existing honest no-basemap canvas and performs **zero
tile, center-search or center-resolution gateway attempts**. No direct provider,
OSM/Nominatim URL or key is introduced. Provider attribution appears only when
the external canvas displays provider basemap content. Dataset attribution stays
with source cards/details. No flag, budget or source was activated.

Account, mode and foreground changes fence pending results, chooser callbacks
and rendered tile scopes. Map builds/drags/markers/clusters/cards introduce no
ACTMET01 event; existing deliberate List-card and official-link copy/share
definitions remain. Messages and native participation remain independent.

## Qualification

```text
flutter analyze --no-pub lib/features/external_activities lib/features/geographic_discovery lib/app/router/app_router.dart test/features/external_activities
flutter test --no-pub --concurrency=2 test/features/external_activities test/features/activity_interest
flutter test --no-pub test/features/geographic_discovery test/app/router/navigation_shell_test.dart test/features/settings
flutter test --no-pub test/features/external_activities/external_map_test.dart --dart-define=UI_POLISH_CAPTURE_DIR=<absolute-local-directory>
```

Actual List Sports/Places + query/discipline → cluster → external detail → Back →
List, retained camera/filters, explicit area search, arbitrary valid radius,
source disable, mode OFF, background/account stale response, mixed event/course/
place/locality and paginated partial-health journeys pass. The native map/cache,
router and Settings suites pass in the scoped regression run. All difficult
empty/error/partial/stale/no-basemap states are rendered in EN/IT, both themes,
320/360dp and 2x text; no physical phone/iOS claim.

Selected inspected captures (synthetic public fixtures, no enabled live source):
[map](evidence/activities-sports/external-map-en-light-360-2x.png),
[loaded-entry chooser](evidence/activities-sports/external-cluster-it-dark-320-2x.png),
[error](evidence/activities-sports/external-map-error-it-dark-320-2x.png),
[partial source health](evidence/activities-sports/external-map-partial-en-light-360-2x.png).
Real municipal source ingestion/rendering evidence is recorded separately in the
[source contract](activities-sources.md#sportdata01-official-trento-public-sports-equipment).
