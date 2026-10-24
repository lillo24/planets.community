# PLANETS — DISCOVERYMAP01: compact Projects + Community Places map/list

**Prepared:** 24 October 2026 (Europe/Rome).  
**Status:** Ready for implementation.  
**Repository:** `lillo24/planets.community`.  
**Current main inspected:** `d1e4581b0a816ba182f3d7b3240f72419f001be5`.  
**Required predecessor:** PLACE01 PR #325 / merge `43dcf11a64c375dc9c21c2196770fbd12059c2db`.  
**Coordination:** the five-phase Community→Project consolidation roadmap was added by PR #326 and is product context for this handoff.

## Assignment

Implement the founder’s original map idea on the merged PLACE01 foundation:

- the native **Projects / Find activities** browse surface gets a compact rectangular map near the top, with the ordinary Project results continuing underneath;
- that map shows both existing native Project markers and explicitly discoverable PLANETS **Community Places**;
- tapping a venue such as a football field can open a discovery-safe Place detail showing the PLANETS Communities/numbered groups that explicitly publish it and their upcoming discoverable sessions, including real availability;
- online/locationless Communities such as Valorant remain fully discoverable in Find People and never receive a fake marker;
- preserve the existing expanded Project map route as the larger-map/deep-link view.

Here, **activity** means the existing native collaborative **Project** domain. Do **not** make the imported external Activities/Sports catalogue the primary surface for this change. PR #326 explicitly establishes that the new Find People “Find activities / Projects” path reuses native Projects. The external catalogue and its `/activities` map remain separate and unchanged except for shared renderer regressions.

This is one visual discovery surface over two canonical domains. Do not merge Project IDs, Place IDs, Community hub IDs, numbered-group IDs or meeting IDs.

Start from latest `main`, inspect current `AGENTS.md`, native Project browse/map, PLACE01, geographic discovery, and any already-merged CP01/CP02 work before editing. The SHA above records the reviewed baseline; do not reset newer work to it.

## 1. Coordination with CP01–CP05

PR #326 scopes:

- CP01 — Community-first Find People navigation/naming;
- CP02 — “Find activities / Projects” reuses native Project discovery/creation;
- CP03 — share published Projects into Community General;
- CP04 — retire duplicate People-seeking posts from primary UX;
- CP05 — cross-persona integration/review.

DISCOVERYMAP01 does **not** replace those phases.

If CP01/CP02 are already implemented on latest main, integrate with their settled labels/routes. If not:

- implement the compact map on the existing native Project browse route (`/proposals`) and expanded Project map route;
- do not modify Home/Find People navigation merely to pre-implement CP01/CP02;
- CP02 can later point “Find activities” at this enhanced native Project surface.

Avoid parallel edits to CP01/CP02 navigation files when a smaller surface-local change is sufficient.

## 2. Current foundations to preserve

### Native Projects and map

Current main already has:

- native Project browse at `/proposals` with keyword, locality, skills and definition-phase filters;
- normal Project detail/create/join behavior;
- `MapDiscoveryOrigin.projects`;
- expanded map route `/discover/map/projects`;
- `search_public_geography_v1` with public Project geometry, radius/bounds, paging and current public visibility;
- shared Project/Tavolo/Resource map renderer, clustering, explicit **Search this area**, camera/reference state and List/Map session state.

Do not replace native Project discovery with a second backend or editor.

### PLACE01

Current main already has:

- stable PLANETS Place UUIDs;
- exact normalized-snapshot deduplication excluding `verified_at`;
- optional numbered-group usual Places;
- immutable meeting-specific Places committed atomically with scheduling;
- discovery publication default OFF independently for usual and meeting associations;
- exact addresses restricted to authorized group members;
- `list_discoverable_cocreate_places_v1`, authenticated and bounded;
- hub-authorized Place detail and Calendar/recruitment/attendance integration.

PLACE01 intentionally deferred the map.

Its v1 discovery reader has **no radius/bounds input**. Do not page global results and filter them in Dart to simulate map search.

### Shared map/provider

Reuse the current:

- `PublicMapCanvas` / `PublicPointMap`;
- stable public coordinate clustering;
- `MapDiscoverySessions` / Project camera preferences;
- basemap gateway, byte cache, budget accounting and truthful no-basemap fallback;
- center/reference behavior;
- attribution rules;
- lifecycle/account response fencing.

Do not create a second renderer, cache, Geoapify client, city-search implementation, GPS prompt or provider accounting path.

## 3. Primary UX: compact map above Projects

Change the native Project browse screen from:

- List/Map control;
- filters;
- Project cards;

to a cleaner integrated layout:

1. existing top-level browse switcher, if present under the current mode;
2. **compact full-width map rectangle**;
3. concise layer/area controls and selected-item context;
4. existing Project search/filter UI;
5. existing Project result list and pagination.

The ordinary Project list remains the authoritative full browse surface. Do not hide locationless Projects merely because they cannot be mapped.

The compact map is a geographic discovery aid over the current Project filters plus Community Places; it does not silently turn the entire Project list into “only records in the current map viewport.”

### Size and scrolling

On a typical 360–430dp phone, target roughly **200–240dp** of map height after responsive review, instead of the current 340dp full-map emphasis. Use existing layout tokens/constraints; do not hardcode a size that breaks 320dp or 2× text.

The page remains one normal vertical scroll. The map stays mounted while the page scrolls. Do not add a nested vertical scroll or draggable sheet.

### Expanded map

Keep `/discover/map/projects` as the expanded map.

Replace the now-redundant prominent Project List/Map segmented control on `/proposals` with a modest **Expand map** action associated with the compact map.

Do not change Tavolo/Resource List/Map controls unless a shared extraction requires a behavior-preserving refactor.

Compact → expanded → Back should preserve useful:

- Project filters;
- camera/reference;
- searched area;
- enabled map layers;
- selected marker where sensible;
- Project list scroll state where current navigation allows.

## 4. Two typed layers

The Project compact/expanded map has two independent layers:

- **Projects** — existing native Project public geographic results;
- **Community Places** — PLACE01 discoverable amenity Places.

For an eligible signed-in Find People user, both are ON by default.

For signed-out users or accounts that cannot use Co-Creation, the Project layer still works according to current native public behavior; Community Places are absent/disabled and no unauthorized co-creation read is issued.

Use a compact layer control that is understandable without relying on color.

### Filter semantics

Do not pretend the two domains share every filter.

Existing Project keyword/locality/skills/definition-phase filters continue to constrain the **Project** map query as they do on the expanded Project map.

The explicit geographic area — radius or searched bounds — is shared by both enabled layers.

Community Places are not silently filtered by Project skills, definition phase or keyword in this slice.

If a later product decision wants Community category/search filtering, keep that for a separate change.

Turning a layer off stops its new reads and removes only its markers/selected section. It never changes server publication state.

## 5. Add an area-aware Community Place discovery reader

Add an additive/versioned reader for discoverable co-creation Places with the same radius/bounds model as MAP04/ACTGEO01.

Do not change `list_discoverable_cocreate_places_v1` signature or shape.

A likely name is `list_discoverable_cocreate_places_v2`, but follow current naming conventions after inspection.

### Input

At minimum:

- expected actor/profile;
- one explicit radius or non-antimeridian bounds area;
- bounded page size;
- deterministic continuation.

Use the existing map safety limits:

- radius 1–100,000m;
- existing latitude limits;
- ordered bounds;
- spans ≤4 degrees;
- geodesic area ≤50,000 km²;
- no arbitrary extra JSON fields.

If a genuinely shared private area normalizer exists on latest main, reuse it. Otherwise add a new private shared helper in the forward migration. Do not make co-creation depend on the domain-specific name `private.external_catalogue_area`.

### Spatial behavior

- Filter with PostGIS **before pagination**.
- Use stored PLACE01 geometry only; no provider/geocoder request.
- Explain the actual query over bounded synthetic data.
- Add a geography/expression GiST index only if the existing PLACE representation needs one for this query.
- Do not fetch global Place pages then filter in Flutter.
- Every page rechecks experiment/account/policy/publication/lifecycle/blocking eligibility.
- Unpublished, address/private, suppressed, archived, cancelled, past or otherwise ineligible associations contribute no row or aggregate.
- Several Communities/groups using the same PLANETS Place UUID still produce one marker.
- Nearby but distinct Place UUIDs remain distinct; never merge by proximity or similar label.

### Result

Return only map-safe Place summaries:

- stable Place UUID;
- public amenity label/locality;
- exact public geometry;
- attribution/source licence required by current policy;
- eligible Community/group count;
- eligible upcoming-session count;
- structural `has_open_session` (or equivalent);
- viewer-specific immediate-action aggregate only if explicitly separated from structural openness.

No roster, manager identity, chat data, hidden totals, private associations or exact address.

## 6. “Open session” and “Can join now” are different

Do not reuse PLACE01’s viewer-specific `available` as the only public discovery message.

Define separate server-derived concepts:

### Open session

An explicitly published upcoming session/recruitment is structurally open:

- publication is on;
- recruitment is live/current;
- meeting is future and not cancelled;
- meeting has capacity;
- persistent numbered group has capacity;
- creator/group/hub lifecycle allows newcomer discovery;
- other non-viewer structural conditions hold.

### Can join now

This current viewer is already authorized to use the immediate direct meeting/group admission path.

A person outside the Community may see **Open session** but must first deliberately join/open the Community. They do not get direct meeting admission.

A current hub member may get the canonical Join/Confirm action when authorized.

Do not label a structurally open meeting “Full” merely because this viewer has reached a personal membership limit or another viewer-specific restriction.

Keep occupancy, persistent chat capacity and attendance conceptually distinct.

## 7. Add a cross-community discovery Place detail

PLACE01’s existing route `/people/hubs/:hub/places/:place` is hub-authorized. Keep it that way.

Add a separate discovery-safe backend reader and mobile route for a Place opened from the Project map. Do **not** choose an arbitrary hub and call the member reader.

A suitable backend contract may be `get/list_discoverable_cocreate_place_detail_v1`.

### Discovery-safe output

For an explicitly discoverable Place, return a bounded, stable list grouped by Community/group containing only:

- public Community hub ID;
- topic/name;
- locality;
- category summary already permitted by the Community directory;
- numbered-group number;
- whether this Place is an explicitly published usual Place for that group;
- explicitly published upcoming meeting if present;
- localizable meeting instant;
- meeting capacity/occupancy if the explicit publication contract allows those counts;
- structural `open_for_recruitment`;
- viewer-specific `can_join` / `can_confirm` separately;
- current viewer `attending` only when authorized.

No roster, manager identity, transcript, membership history, hidden meeting, private address, read token or ACK.

Pagination is bounded and deterministic. Every page rechecks publication/lifecycle access.

### Actions

From discovery Place detail:

- tapping a Community opens its existing Community detail/admission flow;
- a non-hub member never auto-joins the hub/group/meeting;
- an open session may show **Join/Open community first**;
- after deliberate hub admission and a fresh read, eligible meeting admission uses the existing canonical recruitment/attendance flow;
- a viewer already in the hub can use existing meeting review when current authority permits.

This is the requested football-field flow without weakening admission.

## 8. Combined Flutter marker model

Create a small presentation-only combined marker abstraction over:

- existing native Project `GeoItem` markers;
- co-creation Place markers.

Do not add a co-creation kind to the strict installed `GeoKind` parser merely for UI composition, and do not create a cross-domain database union table.

Keep identities distinct, e.g.:

- existing Project geographic identity;
- `cocreate_place:<uuid>`.

Icons and semantics distinguish Project vs Community Place without color alone.

Cluster counts mean **loaded marker entries**, not attendees, groups or server-wide total matches.

If a Project and Community Place share the exact coordinate/grid cell, the cluster chooser lists both typed entries rather than merging them.

Selecting a marker should reveal concise selected context directly below the compact map:

- Project marker → compact Project card/action using existing public Project data;
- Community Place → compact venue card with counts/open-session signal and action to discovery Place detail.

Do not require that the selected Project already be present in the paginated ordinary Project list.

## 9. Ordinary Project list remains complete

The existing Project result list below the compact map keeps its current browse semantics and includes Projects without usable map geometry.

Map area changes affect map queries/layers, not the full ordinary list unless an existing explicit Project locality/filter already does so.

Make the distinction visually clean rather than explanatory:

- compact map = “nearby / this map area” context;
- filters + list = existing Project discovery.

Do not duplicate every map Project into a second full “nearby projects” list.

A selected map Project may have one compact selected card under the map.

Include a clear path to **Find People / Communities** from Community Place context where useful. The map is not the complete Community directory.

## 10. Shared area/camera state

Use the existing Project `MapDiscoveryPreferences` session as the single map camera/area authority.

- Initial reference remains the current Trento reference; it is not GPS.
- Pan/zoom changes only camera state.
- **Search this area** explicitly applies validated bounds to both enabled layers.
- **Use displayed centre/radius** applies the same radius to both.
- **Clear searched area / back to radius** affects both.
- Area changes reset both layer continuations.
- Project filter changes refresh the Project layer while retaining the shared area.
- Compact ↔ expanded keeps the same camera/reference/area.
- Account/realm/experiment/lifecycle changes fence late responses independently.

No new device location permission.

## 11. Independent failure and honest completeness

The layers fail independently.

- A co-creation read failure must not erase valid Project markers/list.
- A native geographic Project failure must not erase valid Community Place markers.
- Show short layer-specific retry/error state.
- A layer with continuation is only partially loaded; cluster counts remain loaded-only.
- Locationless Projects stay in the ordinary list.
- Locationless Communities stay in Find People.
- Never claim that the map shows every nearby Community or real-world group.
- No success-shaped empty fallback after a failed request.

## 12. Basemap/provider/attribution

No new paid-provider behavior.

- Reuse existing shared basemap gateway/cache/budget.
- Community Place map search makes no new Geoapify geocoding request.
- No provider key in Flutter/public config.
- No public OSM/Nominatim fallback.
- No quota, daily ceiling, TTL or flag increase.
- No automatic provider activation.
- With basemap disabled/failing, canonical markers, area controls, list and Place detail remain functional on the existing truthful no-basemap canvas.
- Use current `LocationAttribution` rules for provider-derived Community Place information and basemap imagery.
- Avoid duplicate credits.

External Activities/Sports source provenance remains unchanged because that catalogue is not being integrated into this map phase.

## 13. Analytics and notifications

Preserve existing analytics behavior.

Do not create analytics events for:

- map builds;
- marker renders;
- pan/zoom;
- area changes;
- cluster opens;
- Community Place browsing.

Do not activate PostHog or another SDK.

Do not add a Community Place notification system in this slice.

## 14. Compatibility and migrations

Use additive forward migrations only.

Preserve:

- `list_discoverable_cocreate_places_v1`;
- all PLACE01 command/reader signatures and strict DTOs;
- CAL01/FIX01 signatures/cursors/receipts;
- `search_public_geography_v1` signature/default native families;
- ordinary Project list/detail/create/join contracts;
- expanded `/discover/map/projects`;
- Tavolo/Resource map behavior;
- external Activities/Sports list/map contracts.

Prefer the new co-creation-specific area reader plus Flutter composition instead of modifying `search_public_geography_v1` to return a foreign Place kind.

The populated upgrade rehearsal starts from current PLACE01-installed main and proves old rows/functions/readers/cursors/receipts remain valid.

## 15. Current release holds

At the inspected main:

- PLACE01 source is merged;
- PLACE01 hosted migration remains `review-required-for-hosted` because a new private-table default/constraint function effect is not independently qualified;
- extended `location-search` Edge source approval remains pending;
- no hosted PLACE01 apply, co-creation/provider activation, Mock seeding or installed-app rollout is established.

These are not source-design blockers for DISCOVERYMAP01.

Do not weaken or bypass those holds.

The map read uses stored canonical Places and must not depend on the PLACE01 editing Edge function being deployed.

Final reporting separates:

- source merge;
- hosted schema eligibility/application;
- Edge source approval/deployment;
- co-creation experiment activation;
- map-provider activation;
- installed app/device QA.

## 16. Validation

Run the smallest complete affected set.

### Database / Auth HTTP

Cover:

- radius/bounds validation parity with MAP04/ACTGEO01;
- spatial filtering before pagination;
- explained/index-backed query on bounded synthetic Places;
- one Place shared by several Communities/groups produces one Place row;
- nearby distinct Place UUID remains separate;
- publication OFF absent;
- exact address absent;
- past/cancelled/retracted/suppressed/archived associations absent;
- structural open-session vs viewer `can_join`;
- outsider receives only explicit discovery-safe summaries;
- forged actor denied;
- deterministic continuation and area change invalidation;
- block/account/policy/experiment changes;
- discovery reads create no membership, attendance or transcript ACK;
- PLACE01 v1 remains unchanged;
- populated upgrade preserves installed rows/readers/cursor/command receipts.

### Flutter production screens

Cover:

1. `/proposals` at 320/360dp: compact map + native Project marker + Community Place marker + ordinary Project list below.
2. A football Place shared by two groups, with one structurally open and one full session.
3. Tap Place marker → selected venue card → cross-community Place detail.
4. Non-hub member sees open session but must open/join Community first.
5. Current hub member can proceed to canonical meeting review.
6. Project + Community Place at the same coordinate/grid cell → typed cluster chooser.
7. Community layer OFF → zero co-creation reads/markers; Project layer/list unaffected.
8. Signed-out Project browsing remains valid; no unauthorized co-creation read.
9. Co-creation layer failure + valid Project layer, and Project-map failure + valid co-creation layer.
10. Search this area / radius / back-to-radius updates both enabled map layers only on explicit action.
11. Locationless Project remains in ordinary list.
12. Locationless Community remains in Find People and gets no marker.
13. Compact → expanded Project map → Back retains useful map/filter/list state.
14. Account/realm/background/experiment transitions fence late co-creation results.
15. EN/IT, light/dark, 2× text, semantic marker/layer/expand actions and small width.

### Provider traffic

With all live map/provider flags OFF:

- zero new upstream provider calls;
- canonical Project/Community Place points still render on the existing no-basemap canvas.

When injected synthetic tiles are enabled, reuse current cache/budget tests; do not create another accounting path.

### Regression

Run affected:

- native Project browse/filter/detail;
- geographic discovery Project map;
- Tavolo/Resource map regression where shared code changes;
- shared basemap/cache;
- PLACE01;
- CAL01/FIX01;
- router/navigation;
- Settings/experiment gating.

Do not run unrelated expensive suites merely because the map is cross-feature.

Build Android when supported. Physical Android/iOS and TalkBack/VoiceOver remain unverified unless actually run.

## 17. Visual acceptance

Capture and inspect actual Flutter renders with synthetic data:

- compact Projects + Community Places map with ordinary Project cards underneath;
- mixed Project/Community markers;
- selected football Place with two groups and open/full sessions;
- no-basemap combined view;
- signed-out Project-only view;
- locationless Project visible below the map;
- IT dark 2× text.

The target feel is the founder reference: **map as a compact useful context rectangle, content below as the main browsing surface**.

Remove/compress visible explanatory or debugging text that exists only to describe implementation internals. Preserve needed accessibility, attribution, filter scope and truthful errors.

## 18. Delivery

Use one isolated implementation branch/PR.

The area-aware co-creation reader, discovery-safe Place detail and combined Project-map presentation belong in one coherent slice because the UI cannot safely implement geographic Community Place discovery without those server contracts.

Follow current `AGENTS.md`, validation workflow and staging policy.

After affected checks and required CI pass:

- refresh from latest main;
- merge automatically if no substantive product/security issue remains;
- clean the task branch/worktree.

Do not perform:

- manual hosted migration application;
- release-policy weakening;
- Edge deployment/source approval;
- provider/budget activation;
- Mock seeding;
- device installation;
- store publication;
- CP01/CP02 navigation work unless it already exists and only requires compatibility adjustment.

Final report must include:

- PR/final head/merge SHA;
- exact compact Project-screen behavior;
- new co-creation geographic/detail contracts;
- Open session vs Can join now semantics;
- Project vs Community Place layer/filter behavior;
- compact/expanded state preservation;
- validation actually run;
- populated upgrade/compatibility evidence;
- provider-attempt evidence;
- separate source/hosted/Edge/activation/device status.

## Expected result

A user browsing native **Projects / Find activities** sees a small useful map at the top and ordinary Project results below.

The map contains normal Project pins plus explicitly discoverable PLANETS Community Place pins.

Tapping a football field shows which PLANETS Communities/groups publish that venue and their upcoming sessions. A session can visibly be open without bypassing deliberate Community admission.

An online/locationless Community remains normal in Find People and simply has no map point. A locationless Project remains in the Project list even though it has no marker.
