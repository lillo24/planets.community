# MAPMOCK01 public imagery in Mock Mode

Source implementation begins at main `667bf57b`. Hosted activation is a separate
owner action. No new function, SQL, provider spending or Play upload is deployed
by this implementation task. Fixture Android pixels do not establish a working
hosted Android map.

## Trust and ownership

Mock Mode keeps its existing Supabase client, fictional Auth sessions, domain
RPCs, RLS, Storage and private caches on `pnolarmzxmmjtguligfc`. The only exception
is `data/mock_public_basemap_gateway.dart`: its dedicated HTTP transport POSTs
fixed public-image fields to normal staging's `/functions/v1/mock-basemap`.
It cannot choose a product RPC or provider URL. It uses the current mock bearer,
with no normal user session and no service/provider key in the app. Normal
`RealmTransport` origin restrictions and `map-provider` JWT policy are unchanged.

The separate staging function validates the bearer against fixed mock
`/auth/v1/user` and calls mock `mock_basemap_identity_v1` with that same bearer.
PostgREST verifies mock signature/expiry. The SQL verifier requires `auth.uid()`,
the signed session ID, a live `auth.sessions` row, an issued broker delivery,
an available persona and the enabled, independently confirmed mock environment.
It returns only SHA256 scopes for the persona and broker client. A normal token
with an overlapping UUID cannot satisfy independent mock signing keys. No
normal profile is created or impersonated. Retired/revoked sessions fail even
while an access JWT has time remaining. Cold IO rechecks the proof before finish.

`verify_jwt=false` applies only to `mock-basemap`; cross-issuer verification runs
inside that handler on every call. No CORS wildcard is added. Requests with a
browser Origin, query bag, asserted actor/client, item, arbitrary style/URL,
search text or extra fields are refused before privileged use. Fixed origin
constants intentionally describe this closed-test pair; local qualification
injects a transport mapping them onto two independent disposable stacks. A
future production/self-hosted trust-anchor change requires its own review.

## One budget and one public cache

Migration `20261023054839_mapmock01_shared_public_basemap.sql` adds a private,
RLS-protected `mock_basemap_config` and service-only mock reserve/finish APIs.
The installed normal v2 reservation keeps its signature, OID, ACL and JSON
contract, delegating the same cache/ancestor algorithm to a private shared
implementation. Normal profiles and their existing quotas remain mandatory.
The legacy binary tile/center endpoints keep their contracts.

Both consumers lock **search configuration → provider configuration** before
reading or changing `private.location_provider_usage` or public tile claims.
Mock then locks mock configuration before baseline configuration. A cold mock
miss increments the same `units:global` UTC-day row used by normal tile, center,
editor and static consumers, and simultaneously increments bounded mock actor,
client and aggregate scopes. Shared pending entries deduplicate normal/mock v2
cold races; failed/time-out reservations stay charged. Cache hits are charged
request-rate capacity, never provider units. Finish tokens are single-use and
never returned by the image endpoint. The existing master, licensing gates,
circuit breaker and 30-second pending/15-second failed entries remain in force.

Default mock bounds (all independently configurable downwards):

| Setting                   | Default | Hard bound / additional shared constraint                       |
| ------------------------- | ------: | --------------------------------------------------------------- |
| enabled                   |   false | Separate mock kill switch                                       |
| daily_units_limit         |     800 | ≤2,000 and ≤one quarter of the configured global limit          |
| actor_daily_units         |     120 | 1–320, shared by all clients using that persona                 |
| client_daily_units        |     160 | 1–400, shared across persona changes                            |
| actor_minute_requests     |      24 | 1–30, including cache hits                                      |
| client_minute_requests    |      36 | 1–60, including cache hits                                      |
| aggregate_minute_requests |      60 | ≤120 and ≤half the configured global minute limit               |
| max_concurrent_tiles      |       6 | 1–6 outstanding cold mock acquisitions; cache hits need no slot |

One unit is 0.25 credit. The default mock allowance is at most 200 credits/day
inside the existing account ceiling. A separate private table holds only the
opaque tokens of at most six pending mock acquisitions, with 30-second leases;
completion releases a slot and expired/non-pending tokens are pruned on the
next reservation. A full IO pool returns pending before any credit charge.

New public broker
clients are discoverable and cannot be treated as trusted people; even client
churn cannot bypass persona or aggregate subcaps. No new key/account, crawl,
scheduled fill, provider fallback or public OSM tile endpoint is introduced.

The v2 public cache preserves source XYZ, original acquisition/expiry and
approved Trento ancestor/crop metadata. Only the twelve fixed z12 Trento tiles
can use the seven-day baseline. Ordinary public tiles retain the configured
short server TTL. Private overlays, exact meeting points, bearer tokens, product
histories and persona metadata never enter shared tile entries. Existing lazy
expiry pruning remains validity-based, not a timed-deletion promise.

## Flutter behavior and release evidence

`activeMockRealmProvider` selects the image gateway. All domain data stays on
the active mock client. Mock center lookup is disabled and mounts no active
input. List/Map, filters, camera, zoom, clusters, existing public pin families
(Projects/Tavoli/Resources), detail links and Geoapify/OSM attribution remain.
The mock-only seeder adds once-receipted, deterministic fictional public Trento
references to its canonical fixture records; it reads no protected meeting
geometry. It preserves existing selected points and edited locality fields and
never repairs later tester removals on reseed. These are synthetic fixture
references, not a claim of a live geocoding transaction. Group/Idea screens and
the existing geographic-search kind contract are unchanged.

Mock maps acquire visible tiles only; the optional twelve-tile foreground
baseline warm-up remains restricted to normal mode. The existing queue, six IO
slots, 64 entries/4 MiB compressed bound, at-most-60-second RAM reuse, expiry,
budget/cache-only fallback and route-owned decoded-image eviction are reused.
HTTP is bounded to eight seconds, 400,000 response bytes and no redirects.
Persona/session changes cancel requests and increment an epoch, including
A→B→A. Coordinator fencing disposes the dedicated gateway; route departure,
background, denial and provider kill clear/revoke renderer scopes through the
existing stores. Late callbacks cannot revive images or product results.

Closed testing retains `ENABLE_CLOSED_TEST_MOCK=true`, demos off, and the existing
tile, center, detail, 60-second cache, editor and budget defines. Ordinary and
production builds retain Mock off. The AOT diagnostic
`PLANETS_COMPILED_MAP_V1=111111` proves those six effective map settings in that
order, independently of the input manifest. The signed AAB inspector requires
the correct map marker and Mock marker in every ABI and scans all payloads for
privileged credentials/session JWTs. Native CI verifies the same markers in its
ephemerally signed release APK. That fixture is not an upload-signed Closed
testing AAB and does not allocate or reuse a Play version code.

Release dependency verification is variant-aware: the exact isolated mock-image
gateway adds `mock-basemap` only for `closed-test-mock`. Unknown ordinary Edge
dependencies still fail closed. The current approved deployment policy does
**not** approve this new function. The closed-test hosted release gate stays
blocked until its actual deployed source/bundle and permission review are
recorded separately. Normal staging releases retain their installed dependency
policy. Compilation, deployment, provider paint and publication are distinct.

## Validation and reproduction

`node --test scripts/lib/*.test.mjs` includes strict handler/transport tests and
the existing map/cost contracts. `npm run check:mobile` checks all Flutter source
and tests. The focused gateway test also runs with
`flutter test test/features/geographic_discovery/mock_public_basemap_gateway_test.dart --dart-define=LOCATION_MAP_TILES_ENABLED=true`.
The normal database suite discovers `147_mock_public_basemap.test.sql`.

`PLANETS_DISPOSABLE_QA=1 node scripts/mock/qualify-local.mjs` creates two new
independently keyed local Supabase stacks. It runs MAP05/MAP-COST01/MAPMOCK01 SQL
contracts, real Auth/RPC/RLS/Storage checks, revoked mock-session denial, equal
UUID sentinels, mixed cold-cache races, the final shared global unit, mock
subcaps, TTL/fallback and shutdown. Provider pixels are controlled 256px PNGs.
Windows Podman users must explicitly select their intended connection with
`CONTAINER_CONNECTION`; the qualifier never changes the global connection or
resets existing stacks. Failed CLI output stays in a private task-temp log,
not exported artifacts. Never use a retained/shared stack for destructive tests.

The existing `qa-mock-native` workflow builds the real release configuration,
uses two real local realms, and runs EN/IT 320dp/2× text imagery, fictional pins,
pan/zoom, persona change, route eviction, ordinary logged-in imagery, return to
normal and restart. `scripts/mock/basemap-fixture.mjs` injects only upstream PNGs;
Auth, SQL quotas, shared cache and canonical geographic readers remain real.
Screenshots are explicitly **fixture evidence**. Hosted logs/credentials/APKs
are excluded from uploaded artifacts. Final executed results are recorded in
the implementation PR; an unrun gate must not be described as passed.

## Hosted activation and rollback — separate owner gate

Read-only inspection on 23 October 2026 confirmed staging map-provider v5 with
JWT verification on; no mock map function existed. Staging provider master,
tiles, centers and cache license were enabled, daily limit **8,000 units**,
actor limit 8,000, actor minute 30, global minute 120, short cache 60 seconds;
Trento baseline enabled/licensed for 604,800 seconds. No current-day global
usage row was returned. This is an observed configuration snapshot, not a
provider-account invoice or evidence of a hosted tile request. No real provider
charge was incurred or measured by this task.

After explicit owner authorization for the exact projects and bytes:

1. Re-read live quota/license/ledger settings and actual remaining provider
   allowance. Keep the account ceiling unchanged. Review public-image proxy and
   caching rights, attribution and ingress log retention for this route.
2. Complete the existing exact-SQL owner review and populated migration
   rehearsal. Apply the additive canonical migration through the approved
   migration owner, not an ad-hoc SQL dashboard. This task authorizes no hosted
   migration. Keep `private.mock_basemap_config.enabled=false`.
3. On the independently verified **mock** project, review/install the updated
   `supabase/mock/control.sql` identity RPC using the existing guarded operator
   maintenance process and approved canonical schema inventory. Review the
   once-only synthetic geography seed before explicitly running that mock-only
   step. It is separate from normal migrations and never installed on staging.
4. Deploy only `mock-basemap` to **staging**, with its dedicated `verify_jwt=false`
   configuration. Supply the mock publishable key and reuse the existing
   server-only Geoapify key and normal runtime service key. Start with
   `LOCATION_MOCK_BASEMAP_ENABLED=false`; preserve normal function JWT settings.
   Confirm a mock bearer fails on ordinary product RPCs and normal map-provider.
5. Approve conservative mock caps, then explicitly enable the SQL mock switch
   and `LOCATION_MOCK_BASEMAP_ENABLED` with normal master/tile/license gates
   intact. A deliberately tiny genuine mock-session tile request must produce
   a real Geoapify 256px PNG and a matching reservation in the **staging** global
   and mock ledgers. A cache hit must show no new acquisition charge. Verify an
   independent normal logged-in tile too, without recording tokens or pixels
   containing overlays. No aggregate query alone proves Geoapify billing.
6. Record reviewed deployed function metadata/source hashes in the release
   policy, then build and inspect the actual original-key signed Closed testing
   AAB with a freshly verified unused Play version code. Confirm both markers,
   package, signing certificate and target SDK. Paint real imagery in Android
   with fictional pins and retain authorized screenshots. No Play upload is
   included in MAPMOCK01.

Rollback: disable the SQL mock switch first, then the dedicated Edge flag. This
blocks new mock reservations, cache reads and finish responses without touching
normal product data or normal map access. Disable the existing provider master
as well if the whole provider must stop. Preserve charged reservations and
migration history; do not delete ledger rows to simulate refunds. Redeploy/remove
the new route only through the approved owner process. Previously delivered
public bytes cannot be recalled; client RAM/decoded scopes expire or are evicted.
Re-enable only after reviewing the cause and remaining shared allowance.

Authentication design follows Supabase's [session revocation guidance](https://supabase.com/docs/guides/auth/sessions)
and [Edge Function authentication boundary](https://supabase.com/docs/guides/functions/auth).
