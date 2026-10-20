# PLANETS MAP-COST01 — Shared Trento basemap and budget-safe zoom

Prepared: 20 October 2026.
Repository inspected: `lillo24/planets.community`, `main` at `32f37791b11f759adfe4b61c2cdd1b600fdf84f2`.
Predecessor: `PLANETS_MAP-LIVE02_live_map_search_acceptance_2026-10-20.md` in this directory.

## Objective and product decision

The founder expects most initial users to browse Trento. Make that common journey cheap, and keep Map search useful when the provider allowance is exhausted. Reuse real generic basemap imagery across users instead of repeatedly buying the same tiles. When someone zooms toward Povo without remaining credits, enlarge geographically correct cached lower-detail imagery rather than fetching new higher-detail tiles or removing the entire basemap.

This is an intentional new fallback behavior, not the current implementation. It is allowed to look less detailed; it must not fabricate streets, geographical coverage, event precision or successful fresh searches.

Implement after MAP-LIVE02's code/contract changes are merged. Use then-current main, including later UI changes. If only external live-access evidence is missing, independent local cost work may proceed against the stable contract, but label integrated live acceptance pending. Stop dependent work for an unresolved authorization or API-contract defect.

Read root/nested `AGENTS.md`, `docs/development/codex-tooling.md` and relevant map runbooks. Use one isolated branch/worktree and a focused PR for this plan. Follow scoped checks, automatic merge when safe, and cleanup. Do not push implementation directly to main.

## External context and authority

All product requirements are included here; no Google Doc or private uploaded material is required. Provider documentation must be accessible to verify the proposed generic-tile storage rights. Live QA requires the existing staging setup and an ordinary owner-controlled login; signed distribution additionally requires trusted signing inputs. Discover existing tools/configuration rather than assuming they are present or missing.

Computer/browser control, owned Android emulator testing and screenshots are encouraged. Phone inspections must address `48091FDAS0041A` explicitly; no phone clear/uninstall/install or account changes without separate approval. Never extract credentials or sessions. A missing required external resource stops that live/activation step, not unrelated offline implementation.

The request authorizes designing and implementing cheaper generic-basemap reuse. It does not authorize a paid plan, increased provider ceiling, production deployment, Play publication, weakened authentication, unrestricted downloads or broader personal-data retention. Hosted migration/function/configuration changes require separately available owner authorization; otherwise deliver the exact tested activation/rollback steps and mark live rollout pending. Do not spend the real daily allowance to simulate exhaustion.

## What already exists

At the inspected baseline:

- `public_point_map.dart` requests XYZ tiles at native zoom levels 7–18. Changing native zoom changes the requested tile identity; there is no implemented persistent low-detail Trento fallback.
- `shared_basemap_tiles.dart` provides client coalescing and bounded reuse: 64 public tiles / 4 MiB, no disk cache, and configurable compressed-byte retention of 0–60 seconds. Active decoded public pixels have their own documented lifecycle; the short TTL is not a claim that every visible image disappears after 60 seconds.
- `map_discovery_screen.dart` disposes the basemap provider after a tile error. It preserves public results but does not deliberately overzoom retained parent tiles on exhaustion.
- MAP05's server cache is shared for generic tile bytes, whereas city-search selections are actor-bound. The original SQL permits at most 3,600 seconds of tile retention. The preceding live check on 20 October observed a 60-second configured TTL; reverify before activation.
- In `reserve_map_provider_v1`, valid ready cache hits are served before an upstream credit reservation. They already need no new Geoapify credit, including when the daily credit budget has been consumed. Authentication, feature/master gates, rate limits and other prerequisites still apply. Preserve this; do not incorrectly claim the existing ledger charges every hit.
- One upstream standard tile reserves one quarter-credit unit. Editor/city searches and static previews share the same account ceiling. The previously observed global ceiling was 8,000 units, or 2,000 credits, not a new quota to raise.

Read the effective functions after all migrations, not just `20261009083736_map05_interactive_discovery_provider.sql`.

### Likely areas to inspect

- `apps/mobile/lib/features/geographic_discovery/application/shared_basemap_tiles.dart`.
- `apps/mobile/lib/features/geographic_discovery/domain/basemap_tile.dart`, `basemap_viewport.dart`, `map_discovery.dart`.
- `apps/mobile/lib/features/geographic_discovery/data/map_provider_gateway.dart`.
- `apps/mobile/lib/features/geographic_discovery/presentation/public_point_map.dart`, `map_discovery_screen.dart`, `read_only_basemap.dart`.
- Existing detail ownership in `apps/mobile/lib/features/locations/` and related tests.
- `supabase/functions/map-provider/`, the effective reservation/cache functions and private configuration.
- `docs/development/map05-interactive-discovery.md`, `map-cache01-shared-tiles.md`, `map-live01-android-activation.md`, and the predecessor's outcome.

Use existing responsibilities; file names above are inspection pointers, not an instruction to rewrite every file.

## Required behavior

### 1. Normal operation: shared reuse first

Keep normal discovery quality when the budget permits. Check eligible cached imagery before upstream IO and retain concurrent-miss coalescing. Panning or refreshing PLANETS activities is not itself a reason to re-geocode a place or re-download unchanged imagery.

Keep the existing known Trento search reference: entering Map need not geocode the word Trento again. This remains a selected/default search area, not GPS or a claim about the viewer's actual position. Radius/bounds database queries remain independent of the provider allowance. Keep deliberate Search this area, filters, public eligibility and cursor behavior.

### 2. A bounded reusable Trento base

Provide a small server-shared coarse tile set for the public Trento area, with enough coverage for the initial camera and a zoom toward Povo. This is a set of georeferenced tiles, not a screenshot of an app page.

Prefer a narrow fixed public baseline over building a general offline map platform. Determine its geographical extent and base zoom from real viewport inspection; zoom 12 or 13 is a candidate, not a required answer. Verify coverage on supported phone dimensions and check readability visually. Do not derive the retained baseline's extent from individual private searches or meeting locations.

The implementation starting policy is a configurable maximum seven-day lifetime for this fixed generic public baseline, with at most 64 tiles and 16 MiB of raw compressed image bytes server-side; choose tighter limits when the measured footprint allows. These are proposed configuration defaults for this new feature, not assertions of existing owner-approved hosted settings. Keep activation explicit. Any required change to existing SQL bounds belongs in a new migration, not edited migration history.

For minimal privacy impact, keep long retention limited to the deterministic public Trento baseline. Do not automatically extend actor-bound autocomplete selections, arbitrary private-detail requests, exact coordinates, overlays or request histories. A small isolated cache/tier or an extension of existing ownership is acceptable; choose after inspecting the effective schema and explain the boundary. Non-baseline requests can retain existing policies.

Populate from bounded foreground demand for the initial Trento view before optional higher-detail work. Protect the small ready baseline from eviction by unrelated high-zoom browsing within its existing lifetime/count/byte limits. Do not add bulk region downloads, all zoom levels, device disk caching, a background crawler, recurring warm-up jobs, a CDN or a paid storage dependency. If a bounded foreground baseline-fill step is needed beyond visible tiles, document the exact finite set and include every miss in the same reservation ledger; never disguise prefetch as a free cache hit.

Do not fetch a new Trento base after the allowance is exhausted. A first-time device can receive the already stored valid server baseline without new Geoapify requests, subject to auth/rate limits and ordinary backend traffic. If that baseline was never acquired, expired, is incomplete or was removed, show an honest partial/no-basemap state with working search/List. No absolute offline-availability guarantee is required.

### 3. Degrade detail, not geographic search

When the account or actor daily provider budget is exhausted:

1. Continue using usable exact-zoom cached tiles.
2. Where they are unavailable, use a valid cached covering ancestor/coarse baseline and enlarge it in the correct geographic position.
3. Where neither exists, display an honest uncovered area or List fallback while keeping available imagery and public results. Do not substitute Trento imagery for another city, silently recenter the user, or erase an entire valid map because one child tile failed.

The actual search area, activity pins, clusters and hit targets must follow the real camera. Scaling the basemap must not shift coordinates, alter search results, or turn approximate Project/Tavolo locality references into precise venue pins. Detailed-looking streets do not improve a record's public location precision.

Use the currently pinned renderer's native overzoom behavior or a small tested ancestor resolver, whichever fits best. Verify versioned APIs in the installed source. A zoom cap alone is insufficient: requesting a missing parent can still spend credits. Enforce cache-only fallback at the server boundary as well as in the client.

Do not return an entire parent image as though it were a full-resolution child with the same identity. Preserve source zoom/XYZ and correct crop/scale or layer placement, style/version/dimensions, expiry, attribution and coverage. Cap the number of ancestor/cache lookups; do not scan every zoom level or request many failed children.

Show one concise localized reduced-detail notice when relevant, such as `Mappa a dettaglio ridotto` / `Reduced-detail map`. Avoid developer errors, billing essays or a large permanent banner. Keep Geoapify/OpenStreetMap and any selected-style credits attached to reused imagery. Preserve the existing clean location-detail copy.

A budget-exhausted state must not cause an endless request/retry loop. Use a bounded session policy and server-derived retry/reset information, or another documented equivalent. Recovery at a genuine daily reset or explicit eligible retry must be possible without assuming the device clock is authoritative. Actor-budget and global-budget exhaustion both need coverage.

Normal-quality loading while credits remain is retained; permanently making all maps blurry or changing protected-detail precision is not part of this request. An operator-configurable lower native-detail ceiling may be added only if it simplifies this same implementation; do not expand scope into another settings screen or complex adaptive quota product.

## Budget, privacy and cache invariants

- Keep one atomic server-enforced ceiling for all existing Geoapify consumers. No out-of-band provider calls, client-only caps, hidden retries or second-account workarounds. Do not raise limits to make a test pass.
- A cache-only request must never reserve upstream credits, schedule a fill or reach Geoapify. It may incur ordinary PLANETS backend requests/bandwidth, which are not zero-cost infrastructure.
- Preserve auth, expected-actor checks, cache-license/feature/master gates, allowlisted transport, request bounds, deadlines, binary validation and rate limits. Cached reuse is not permission to bypass a kill switch or serve imagery to guests.
- Distinguish budget exhaustion from `disabled`, `unconfigured`, `guest_disabled`, authorization denial, `rate_limited`, `pending`, malformed imagery and provider outage. Do not convert every failure into successful cached content. Transient failures may retain otherwise authorized public pixels with explicit degraded status; a genuine authorization/master revocation must preserve existing clearing semantics.
- A circuit breaker, rate limit or pending reservation is not the daily-credit budget. Respect its retry contract; do not bypass it by repeatedly calling a new cache endpoint. No promise of instantaneous remote recall of already delivered public pixels should be introduced.
- Cache only generic base images. Never retain mixed screenshots, activity pins, titles, addresses, user identifiers, raw searches, selected place receipts or protected overlay data in the shared baseline. Do not use a client-supplied `public` label to promote arbitrary private state.
- Keep protected detail buffers/scopes, canonical rereads, fresh Maps-tap authorization and sign-out/background/account-switch revocation unchanged. Any longer-lived public scope must be explicitly separate; no protected bytes may enter it. Retain the existing no-device-disk-cache policy.
- Expiry must not slide forward forever on every read. Preserve the original acquisition/expiry identity through server and client; handing out cached bytes cannot restart a full lifetime. Use explicit expiry checks and bounded physical pruning. Document that lazy pruning is not deletion at an exact wall-clock instant.
- Bound count, compressed bytes, decoded memory and concurrency. Protect the small baseline without allowing unlimited retained frames. Style/version/coverage changes and operator purge must invalidate it predictably.
- Preserve compatibility for existing mobile builds and existing tile/center responses. If new metadata or an operation is needed, version/coordinate the narrow contract; old strict parsers must not break. Keep new behavior opt-in until matching server/client rollout is verified.

## Provider evidence and limits

On 20 October 2026, Geoapify's own map-tiles page explicitly permits caching, storing and redistributing generated tiles and requires attribution. Its map documentation prices a standard tile request at 0.25 credits. These support reusing public basemap tiles; they do not make our storage/egress free or authorize retaining personal data.

Recheck the selected style, actual account terms and relevant documentation before activating longer retention. Preserve existing approval gates and record the specific policy/value selected. Do not interpret an old 60-second safety setting as a permanent technical inability to cache public tiles, and do not silently broaden production licensing approval.

References:

- https://www.geoapify.com/map-tiles/
- https://apidocs.geoapify.com/docs/maps/
- https://www.geoapify.com/pricing/
- https://www.geoapify.com/terms-and-conditions/
- https://pub.dev/packages/flutter_map/changelog
- https://pub.dev/documentation/flutter_map/latest/flutter_map/TileLayer-class.html

The latest API reference is navigation only; inspect the version actually pinned in the repository before using an API. If required current documentation is inaccessible or contradicts the proposed use, stop live activation and report the conflict; local synthetic tests may continue.

## Tests and visual acceptance

Use existing test owners and disposable local SQL fixtures. Record before/after counters for upstream requests, reserved units, Edge cache hits, client hits, baseline/ancestor reuse, gateway traffic and retained bytes. Keep test metrics local/aggregate; do not add location-tracking analytics.

Required scenarios:

1. **Repeated Trento use:** simulate 100 sessions/users over a period longer than 60 seconds but inside the new baseline lifetime. After the finite cold fill, unchanged baseline tiles cause zero additional upstream misses. Measure backend requests separately. This is a local deterministic workload, not permission to create 100 hosted accounts.
2. **Trento → Povo at zero credits:** load the baseline, then exhaust the local test ledger/inject the server status. Zoom/pan within covered Povo, search the viewport, open a result and return. New provider requests and new reserved units remain zero; fallback pixels and public pins stay aligned. Test loaded client data and a fresh client reading the server cache.
3. **Cached exact tile at the cap:** verify the pre-existing hit-before-charge behavior still works. Include global and actor exhaustion and simultaneous final-quarter-credit misses; the ledger must never exceed its ceiling.
4. **Cold/missing/expired coverage:** no parent, partially loaded base, evicted tile, expired baseline, panning outside Trento and zooming out beyond coverage. No fake geography, unbounded retries or concealed search failure.
5. **Lifecycle/security:** guest, expired auth, account A→B→A, background/memory pressure, protected-detail revoke, master off, rate limit, pending claim, corrupt PNG and provider failure. Do not conflate safety denial with budget degradation.
6. **Geometry/quality:** parent/child boundaries, fractional zoom, small screens and relevant pixel densities; no shifted pins or duplicated/mirrored streets. Verify actual source zoom/cropping and stable attribution in EN/IT, light/dark and large text. Distinguish reduced detail from normal fully detailed rendering.
7. **Recovery/compatibility:** daily reset, eligible explicit retry, configuration rollback, old-client behavior, new-server/new-client deployment ordering, expiry and bounded cleanup. Cache-only never triggers upstream IO, including under concurrent requests.

Run affected Flutter/domain/widget/integration, provider and SQL/REST/grants checks. Add an additive migration only where needed; preserve hardened security-definer/service-only boundaries and private table grants. Recheck current Supabase docs/CLI help before using changing commands. Rehearse migration upgrade and replay on owned disposable data, never a shared database reset.

Use computer control and inspect screenshots of normal Trento, zoomed Povo with reduced detail, and missing coverage. Use real imagery for at least one bounded normal/fallback mobile comparison when authorized access exists. Simulate budget refusal locally; never burn the hosted allowance or disable the shared service for a screenshot. Pair visual evidence with request counters: a screenshot alone cannot prove that zooming made no requests. Clearly label real, cached-real and synthetic evidence, and distinguish emulator from physical-phone/iOS QA.

For any cost example, report measured unique misses and multiply by the verified unit price. A hypothetical 12 unique cold tiles would be 3 credits total, not 3 per user, only while the same retained tiles remain usable; do not present that illustrative count as the measured Trento footprint or provider invoice.

## Deliverables and completion gate

Deliver the narrow code/schema changes, automated regression tests, relevant inspected screenshots and a short reproducible cost comparison. Update the map cache/discovery runbooks with the actual lifetime, baseline extent/zoom, memory/storage bounds, cache-only contract, failure/recovery semantics, licensing evidence, activation and rollback.

Keep the release process explicit: distinguish code merged, local synthetic acceptance, real staging imagery accepted, hosted changes deployed, and signed/Play release status. Provide exact remaining owner steps only for actions not available or not authorized; do not stop at instructions for actions the desktop tools can safely perform.

Open the PR, run required scoped CI and follow the repository's merge/cleanup rules. The completion report must include PR/commit, source/build provenance, changed contracts/migrations, exact tests and results, observed provider-credit deltas versus backend traffic, images reviewed, missing external evidence and consequential warnings. Stop the next rollout for a privacy leak, cap bypass, false-geography fallback or unresolved public-contract decision. Do not claim that the map is deployed merely because this plan or its implementation was merged.
