# PLANETS — MAPMOCK01: Real public map background in Mock Mode

**Codex implementation plan** · Prepared 23 October 2026 · Repo: `lillo24/planets.community` · inspected `main` at `d735bb88decbc845ee27d1f5812941a233b61b3f`. Refresh latest main and open PRs before acting.

## Goal

Closed-testing **Mock Mode must display real geographical map tiles** behind fictional Groups, Projects, Ideas, Tavoli and Scambio/Dona pins. A tester—even one entering Mock Mode as a normal signed-out guest—chooses a fictional account and sees the real street basemap when opening Map discovery, zooming or panning. Mock data and real data must never mix.

Only **public, licensable cartographic pixels** may be shared. All user/content/search/pin/venue/membership/chat data stays exclusively in the active mock project. No new Mock ribbons, separate map screen or user toggle. No extra API key, paid provider/account or independent uncontrolled budget.

## Verified starting point

- Normal backend: `planets-staging` / `cllpvruvrrvxczjitlqd`, with `map-provider` Edge Function v5, authenticated `tile` and `basemap_tile_v2`, cache and global Geoapify usage ledger; `location_provider_config` and seven-day fixed Trento baseline enabled when inspected. No genuine hosted Android basemap paint has been verified. The Trento baseline was enabled but not populated.
- Mock backend: `planets-mock` / `pnolarmzxmmjtguligfc`. Its only deployed Edge Function was `mock-personas`; there is **no mock map-provider**. It has real fictional Auth sessions, RPC, Storage, map markers and RLS, but no Geoapify secret or independent tile budget.
- The Flutter map gateway (`apps/mobile/lib/features/geographic_discovery/data/map_provider_gateway.dart`) calls `map-provider` through the **active realm's** `supabaseClientProvider`; Mock Mode therefore calls an absent endpoint. The budget path additionally uses `data/budget_basemap_gateway.dart`, `application/budget_basemap_tiles.dart`, `presentation/budget_tile_provider.dart` and `presentation/map_discovery_screen.dart`.
- `features/mock_mode/presentation/mock_realm_host.dart` and `core/backend/realm_transport.dart` separate backend clients, source origins, private caches and sessions. Preserve this default. A mock session is **not** a normal-staging session.
- `supabase/functions/map-provider/handler.mjs` verifies normal Auth user identity and `expected_profile_id`, while the normal `reserve_map_provider_v1` SQL checks existence of `public.profiles`. You cannot pass a fictional UUID as a normal actor or mint an extra normal user merely to satisfy it.
- Merged PR #290 now supports a Closed testing Mock build with the map flags compiled and verified, separate from production; keep that release behavior. The build fix alone does **not** supply imagery to the mock backend.

Inspect exact current source, deployed functions, effective SQL, and repository `AGENTS.md`, `docs/development/codex-tooling.md`, `implementation_plan_sections_suggestions.md`, `docs/development/mock-environment.md`, `docs/development/mock-mobile-sessions.md`, `docs/development/map05-interactive-discovery.md` and `docs/development/map-cost01-trento-baseline.md`. The repo is the implementation source of truth.

## Required architecture — public tile bytes only, one shared budget

**Preferred:** keep normal staging as the sole trusted tile-acquisition/cache/quota authority; add the smallest safe **public-basemap-only** mock access route (for example a dedicated narrow server proxy or Edge endpoint that validates actual mock Auth/capability before forwarding a fixed-style tile request). Choose after inspecting the existing broker and database permissions; do not create a second app-wide client or duplicate a map renderer.

The contract must accept **only** the minimum needed for fixed `osm-carto` XYZ 256px public imagery and approved v2 source/expiry/cache-only metadata. Never accept or return an item ID, human actor asserted by the caller, user profile, arbitrary provider URL, real proposal/location record, private precise location, search-query bag or arbitrary tile style. Preserve georeference identity and source ancestor/crop semantics, current attribution, server TTL, zoom bounds, source byte limits, no redirects, transport timeouts and cancellation.

A mock bearer can be validated only against the fixed **mock Auth issuer** (or a narrowly scoped, server-verifiable capability), not normal Auth. Keep the ordinary normal `map-provider` JWT and RLS boundaries unchanged. No normal account sign-in is required for the tester. Avoid a general CORS/origin-fence exception for normal product traffic. If a separately deployed Edge Function uses `verify_jwt=false` for cross-issuer authentication, authenticate *inside that one handler on every call* before privileged use; do not relax other Edge functions.

Mock Mode is public to all test-app users, not a tester whitelist. Assume the tile endpoint and any public client capability are discoverable by outsiders. Protect the shared provider from abuse: strict fixed request schema, genuine mock-session validation, request/minute and byte/zoom bounds, per-client/actor and **separate mock aggregate subcaps inside** the existing normal/global ceiling, concurrency/duplicate-IO controls, and kill switch. Do not create a general public Geoapify proxy.

### Unified cost and cache

- Normal + Mock tile demand must consume the **same atomic shared global ledger**, not independent budgets that sum past the provider allowance. Previous cap: 8,000 quarter-credit units (= 2,000 credits)/day; re-read current live values. Do not increase it or create a second paid account/API key.
- Add conservative configurable mock-specific subcaps and rates **within** the existing account/day budget, leaving meaningful allowance for ordinary users. Keep existing master/license switches, circuit breaker, transaction lock order, reservation/finish idempotency, actor-level normal quotas, fixed Trento baseline, shared tile-cache lookup and no double-charging under concurrent cold requests.
- Normal SQL reserves with a verified profile actor. A fictitious normal profile is not an acceptable workaround. If necessary, implement a dedicated narrowly granted **server-side mock tile reservation** using the existing global ledger and separate bounded mock identity scope. A new migration must be additive; preserve installed RPC contracts.
- On a cold authenticated Mock map foreground visit, only necessary bounded tiles can be fetched after a successful reservation. Don't schedule map crawls or background fills. Use existing 60-second client cache and seven-day *public Trento* baseline eligibility. Correctly show cache-only/reduced-detail or unavailable when quota, provider or validation fails. Do not evade budget through unlimited retries, public OSM tiles or other providers.
- No cached public tile response may contain private overlays, per-user metadata or exact meeting coordinates. Don't place mock/normal private histories or bearer tokens into a common cache.

If a genuinely unified ledger cannot be implemented safely within current backend constraints, **stop and report the security/cost obstacle**, rather than silently duplicating spending or weakening authorization.

## Flutter behavior and mode isolation

Use a **map-specific public image gateway** selected by `activeMockRealmProvider` (or the equivalent current realm owner); leave every mock domain gateway using `planets-mock`. The sole cross-realm exception is bounded cartographic imagery. Do not point the mock product `supabaseClientProvider` to staging, forward mock bearer tokens to normal product RPCs, or move public/mock pins into the same read model.

Normal mode retains existing authenticated tile and center-search paths, protected detail reads and normal profiles. Mock Mode uses the separate public tile route for map backgrounds; all mock pin/search/labels/photos/permissions come from mock backend. Keep List/Map switch, zoom, cluster count, radius/viewport, creator flows and attribution. Mock map center-autocomplete may remain unavailable if its cross-realm privacy/budget model is not separately reviewed; don't show a broken active-looking field. This task is about **background imagery**.

On mode/persona/account switch, sign-out, route leave, background, auth denial, kill switch or loss of entitlement, cancel/fence outstanding image traffic, stop refresh, evict route-owned decoded images, clear protected data and reject late callbacks even for A→B→A. Public bytes can reuse backend cache; app-side account-specific caches must not leak.

Production/web and ordinary builds remain Mock-disabled. Closed testing `closed-test-mock` must preserve both `ENABLE_CLOSED_TEST_MOCK=true` and the existing `LOCATION_MAP_TILES_ENABLED`, center/detail, 60-second cache and budget-fallback defines. Don't enable old `ENABLE_DEMO_TOOLS`.

## Tests and acceptance evidence

1. **Authorization and isolation:** genuine independent mock/normal Auth issuers and databases; reject mock JWTs from normal product RPCs, RLS tables, Storage, private map/location readers. Reject normal tokens against the mock-only route where inappropriate, forged/revoked mock sessions, guesses, arbitrary actor/request/URL/style/coordinates, duplicate/replay and unauthorized hosts. Prove no real people, Projects or private locations cross with fake overlapping UUIDs in both realms. Verify no secrets in AAB/logs/HTTP response.
2. **Cost/concurrency:** mock + normal tile request races with one empty cache and one shared ledger; honor caps even during concurrent first fetch and cache hits, preserve failure accounting and no unseen repeated charges. Prove mock subcap and global daily cap both work. Check expired Trento ancestor and budget fallback, real PNG bounds/source validity, provider shutdown and honest error UI.
3. **Native app:** run an EN/IT Android release-configuration integration journey with two local Supabase realms and controlled PNGs: normal guest → Mock Mode → Giulia → Map imagery plus fictional pins → persona change → return to normal. Exercise active route/scroll/image lifecycle, large text and attribution; existing normal map stays functional. Explicitly label locally injected pixels **fixture evidence**, not real hosted-provider success.
4. **Hosted smoke (separate external gate):** if the exact target, credentials, licence/quota and account-owner deployment permission are available, make a deliberately tiny authenticated public-mock tile request against the deployed system and verify a real Geoapify PNG plus an accounted charge **on the existing staging ledger**. Verify independent normal logged-in map tiles too, preferably with Android screenshots. If hosted access is missing, deliver source code/tests and a precise activation/rollback checklist; do not call the live mock map ready.
5. **Release validation:** check the actual compilation markers and map defines inside the signed Closed testing AAB, no flags silently missing and production Mock off; preserve package/signing/target SDK and don't reuse an uploaded version code. No Play upload in this task.
6. Run backend handler/SQL/RLS/migration checks, focused Flutter, combined affected Mobile/Web/Database CI and native smoke. Preserve legacy map endpoints and tests. Update nearest mock/map docs with server trust, one-budget proof, attribution, cache limitations, activation/kill/rollback and test results.

## Delivery and boundaries

One focused implementation PR is appropriate. Work in an isolated worktree from latest `main`, commit/push, check required CI, merge automatically only after the required source, security and native gates pass. Do not deploy a new normal staging migration or function, activate provider spending, upgrade accounts, modify real data, publish Google Play, or alter production without **separate explicit authorization**. Missing external credential/approval should block the affected hosted phase, not justify insecure fallback.

Your final Codex report must state: merged source PR/SHA (or exact blocker), selected narrow architecture and single-ledger proof, mock-vs-real isolation checks, executed tests and screenshots, true hosted/deployed status, real provider charges/limits (if observed), compiled flags, external steps still required. **Do not claim live Android Mock basemap working unless real hosted imagery was actually painted.**

### Reference files

- [Map discovery](https://github.com/lillo24/planets.community/blob/main/apps/mobile/lib/features/geographic_discovery/README.md)
- [Map source and SQL](https://github.com/lillo24/planets.community/blob/main/supabase/functions/map-provider/handler.mjs)
- [Shared Trento tile budget](https://github.com/lillo24/planets.community/blob/main/docs/development/map-cost01-trento-baseline.md)
- [Mock session boundary](https://github.com/lillo24/planets.community/blob/main/docs/development/mock-mobile-sessions.md)
- [Mock setup](https://github.com/lillo24/planets.community/blob/main/docs/development/mock-environment.md)
- [Release variant](https://github.com/lillo24/planets.community/blob/main/scripts/release/config.mjs)
- [Supabase function auth](https://supabase.com/docs/guides/functions/auth)
