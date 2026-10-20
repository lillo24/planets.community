# MAP-COST01: public Trento baseline and budget fallback

Implementation starts from `34786524` (MAP-LIVE02, PR #270). The subsequent
authorized [staging rollout](map-staging-rollout.md), from merged main `93414af5`,
applied the canonical migration, deployed map-provider v5 and enabled seven-day
retention. The baseline is **enabled, not populated**. Authenticated real imagery
and native visual acceptance remain pending; see [MAP-LIVE02](map-live02-acceptance.md).

## Ownership and measured extent

The additive migration `20261020150706_map_cost01_public_trento_baseline.sql`
adds two private, RLS-enabled, RPC-only tables. `map_baseline_config` defaults
`enabled=false`, `license_approved=false`, `retention_seconds=604800` (maximum
seven days), `revision=1`. The existing shared quarter-credit ceiling, feature
gates, actor/request limits and ordinary 60-second staging tile policy remain.

`map_baseline_tiles` contains only osm-carto/v1/256px/1x public imagery for:

```text
z = 12; x = 2173..2175; y = 1454..1457 (12 identities)
west 10.986328125; east 11.25
south 45.951149687; north 46.195042109
```

The actual screen owns a 340dp viewport with 16dp horizontal page padding. At
the default Trento camera (46.0748, 11.1217, z12), the fixed set covers 320–768dp
phone widths and the covering ancestors for a zoom toward Povo. The extra north
and south rows give a small fixed public fringe. This extent comes from that
viewport/grid, never an individual search or private meeting. The schema's
coordinate checks and primary key allow at most **12 rows / 3 MiB compressed**
(256 KiB per image), protected from unrelated high-zoom eviction. Actual
Geoapify image footprint/readability still needs staging acceptance.

Only foreground entry at the unchanged default Trento camera primes these exact
12 identities before optional higher-detail demand. Every miss is charged in
the existing ledger. Disposing the view cancels its remaining work. There is no
device disk cache, crawler, recurring warm-up, bulk region download or extra
provider/account. Other cameras use ordinary bounded foreground tile demand.

Legacy ready exact tiles can satisfy these requests at their original short
expiry; they are not silently promoted into longer retention. A subsequent
eligible cold miss can acquire the baseline. Incomplete or expired coverage
remains possible and is displayed honestly.

## Versioned contract and client policy

The authenticated `map-provider` operation `basemap_tile_v2` accepts only the
existing expected actor, fixed style/version, valid XYZ, and an explicit boolean
`cache_only`. It calls the service-only `reserve_basemap_tile_v2` and
`finish_basemap_tile_v2`. Existing `tile` binary and center responses are unchanged;
the regenerated public TypeScript types add only these two service RPCs.

Successful JSON contains `status`, `cached`, `source` (true z/x/y, style, version,
dimension, density), `acquired_at`, `expires_at`, `server_time`,
`budget_exhausted`, `retry_after_seconds`, and bounded `image_base64`. The encoder
omits PostgreSQL's default line folding so the full 256 KiB compressed-byte
bound fits the 350,000-character transport envelope.
`acquired_at` is null for legacy ordinary entries whose original acquisition
timestamp was never stored. Original baseline acquisition and expiry persist on
every hit. Lowering retention can shorten effective expiry; reads never extend
it. Revision changes invalidate the fixed set on the next bounded prune.
Expiry is checked on reads; lazy physical pruning is not exact timed deletion.

The reserve order is: auth/profile and master/feature/license/circuit/rate gates;
eligible ready exact imagery; then, only for an eligible miss, the atomic shared
charge. At daily account **or** actor exhaustion, one covering fixed z12 ancestor
may be read instead. Cache-only checks exact then at most one fixed ancestor,
never reserves upstream units, creates a fill, or contacts Geoapify. This is
ordinary PLANETS backend traffic/bandwidth, not free infrastructure.

`LOCATION_BASEMAP_BUDGET_ENABLED` defaults false. When selected with the existing
tile transport enabled, discovery uses a separate **public-only** metadata cache:
64 source frames / 4 MiB compressed, six active / 64 queued, 64 coverage mappings
and 64 bounded negative entries. A frame lives at most 60 seconds in raw RAM,
shortened by its remaining server lifetime and the entire request round trip.
Elapsed time determines retention/reset eligibility; device wall-clock changes
cannot extend it. Baseline sources get priority over ordinary entries within
these bounds. Repeated child crops share the source buffer.

The renderer retains at most 64 image identities (256px decoded frames, at most
16 MiB pixel data before temporary decode/crop buffers). It crops the correct
subrectangle of the real ancestor, then lets the existing renderer apply the
camera/fractional zoom. Pins, clusters, hit targets and search bounds retain the
real camera; locality references remain approximate. One EN/IT reduced-detail
notice appears when a covering ancestor is used. Missing children retain other
valid imagery/results. Unknown/expired coverage stays blank; List/search work.

Budget refusal switches subsequent requests to cache-only until the server's
UTC reset duration elapses. There is no automatic retry timer or device-clock
reset. After eligibility returns, new demand can request normal detail; existing
Refresh search deliberately renews the renderer. Filter/search changes alone
keep unchanged imagery. Rate/circuit/pending failures retain their own bounded
retry contracts. Disabled/unconfigured/guest/authorization refusal clears the
public store/scopes. Background, memory pressure, account changes and ABA clear
pending generations and raw buffers. A learned master/auth shutdown clears the
view; an operator cannot instantly recall already delivered public pixels.

Active decoded public pixels have the existing view lifecycle, separate from
raw-cache expiry. Old source bytes cannot start a new lifetime on cache reads.
Route disposal evicts its decoded identities. Legacy discovery/details continue
to use CACHE01 when the flag is off. Protected detail scopes, canonical rereads,
fresh Maps-tap authorization, private zeroing and revocation are unchanged and
never use the new public store. Non-baseline v2 and v1 tiles share the existing
server cache; private-detail requests cannot populate the long-lived tier.
The two client stores together have a bounded 8 MiB raw cap; each scheduler has
six active requests, and route departure detaches discovery before detail work.

## Licensing and explicit staging rollout

Rechecked 20 October 2026: [Geoapify's tile policy](https://www.geoapify.com/map-tiles/)
permits storing/reusing generated tiles. [Maps pricing and attribution](https://apidocs.geoapify.com/docs/maps/)
list 0.25 credit per standard tile, Geoapify/OSM attribution for this osm-carto
style, and no additional OpenMapTiles credit for osm-carto.
[Account pricing](https://www.geoapify.com/pricing/) and
[binding terms](https://www.geoapify.com/terms-and-conditions/) retain account
usage limits. The owner explicitly approved seven-day staging retention in the
subsequent rollout prompt. Published tile permissions were rechecked; the account
portal required login and exposed no concrete contrary restriction. Staging's
new license and enable gates are now on. Migration defaults remain off for new
environments. See the [executed evidence](evidence/map-cost01/hosted-rollout.json).

The authorized rollout used the procedure below after reverifying main and
`planets-staging` / `cllpvruvrrvxczjitlqd`. It is retained for reproducibility;
completed backend steps are recorded in the [rollout report](map-staging-rollout.md).
Recheck current history before any future deployment:

1. Compare canonical migration history and effective MAP05 dependencies again.
   Preparation observed 96 staging migrations versus 104 at the predecessor base.
   The scoped rollout advanced staging to 97 of its 105 source migrations.
   Main subsequently advanced to 122; the [rollout report](map-staging-rollout.md)
   records the 25 unrelated pending Group/contact migrations and Messages warning.
   Normalized definitions of the four existing geographic/reservation routines
   match staging and the current local schema. Do not push the whole checkout and incidentally deploy the eight unrelated
   missing migrations. A scoped directory is already prepared locally at
   `C:/Users/utente/.planets/qa/map-cost01/staging-deploy`, containing the 96
   applied canonical files plus this one migration, excluding all eight Group
   changes. Its reviewed inputs/hashes are in the
   [deployment plan](evidence/map-cost01/staging-deployment-plan.json).
   Inspect its config and use the pinned CLI's dry run:

   ```text
   supabase db push --workdir SCOPED_WORKDIR --project-ref cllpvruvrrvxczjitlqd --skip-vault --dry-run
   ```

   The only proposed new version must be `20261020150706`. Stop on any other
   file, history mismatch, missing dependency or request for unknown credentials.
   With the reviewed connection and approval, repeat without `--dry-run`.
   Existing CLI authentication/DB access is an owner prerequisite; never put
   passwords in commands/logs. If using the connected migration API instead,
   use the repository's guarded canonical-history procedure from STAGING01;
   API-generated wrapper timestamps must not replace canonical versions.

2. Deploy only the changed map function from the complete source checkout:

   ```text
   supabase functions deploy map-provider --project-ref cllpvruvrrvxczjitlqd --use-api
   ```

   Preserve `verify_jwt=true`, current key/transport flags and all account/actor
   ceilings. No location-search deployment, static activation or new secret is
   needed. Verify old-client tile/center calls before selecting v2 clients.

3. After reviewing applicable tile permissions and the owner-approved lifetime,
   enable only the new config (example is the proposed maximum policy):

   ```sql
   update private.map_baseline_config
   set enabled=true, license_approved=true, retention_seconds=604800
   where singleton;
   select enabled,license_approved,retention_seconds,revision
   from private.map_baseline_config where singleton;
   ```

   Do not change `location_provider_config` limits or ordinary TTL.

4. Build an explicitly selected candidate from `apps/mobile`, with validated
   ignored staging config and normal owner login:

   ```text
   dart run tool/build_map_live_staging.dart debug-apk --budget-basemap
   ```

   The five existing map flags remain on and the manifest additionally records
   `LOCATION_BASEMAP_BUDGET_ENABLED=true`. Omitting the option preserves v1.
   Signed `apk|appbundle UNUSED_PLAY_VERSION_CODE --budget-basemap` keeps the
   original signing/version preflight; verified unused Play code and original
   signing inputs remain required. This builds, never installs/uploads.

5. Capture real normal Trento, reduced-detail Povo and missing coverage on a
   working owned emulator/device. Measure upstream/ledger deltas versus backend
   traffic. Test exhaustion locally, not by burning the hosted allowance. Stop
   on unexpected failures. Physical phone `48091FDAS0041A` may only be inspected
   read-only without separate installation approval. Keep total bounded live QA
   within the plan's remaining allowance and 100-credit maximum.

The commands/options were rechecked against pinned CLI 2.118.0-beta.39 help.
The scoped hosted dry run again stopped before database access with
`AccessTokenRequiredError`. The authenticated management tools completed the
canonical migration, verified removal of the exact redundant API wrapper,
function deployment and activation. CLI authentication did not block execution.

Rollback: set `private.map_baseline_config.enabled=false`, rebuild without
`--budget-basemap`, and restart the client to clear its learned shutdown state.
Leave the additive schema in place; v1 remains compatible. Purge/reacquire a
baseline only with deliberate operator intent: increment `revision` and delete
the at-most-12 baseline rows. No cache read rewarms it in the background, and a
future foreground refill still needs available credits. To withdraw longer
retention rights, disable first, clear `license_approved`, then purge. Do not
reset shared data, disable the whole map service or raise quotas for rollback.

## Reproducible local evidence

Flutter 3.47.2 / Dart 3.13.2; flutter_map 8.3.2 installed source/API; no new
dependencies. Target is a separate owned disposable project
`planets-map-cost01-qa`, loopback API/DB/mail at 62321/62322/62324, never staging.

- Populated 104→105 upgrade: **135 existing tables / 230 rows** and **694
  existing function definitions/grants** unchanged. Clean replay from zero also
  completed. New schema flags remained disabled until local fixtures selected it.
- `flutter test test/features/geographic_discovery test/features/locations`:
  **387 pass**, including 13 new domain/memory/pixel tests and four screen cases.
  Existing protected-detail lease, denial, zeroing and fresh-tap tests pass.
  The final targeted `budget_basemap_test.dart` run passes **15 tests**, adding
  queue cancellation and baseline protection under high-detail cache churn.
  Repeating the whole scoped suite after those two test-only additions exhausted
  this Windows host's commit/thread allocation; required PR CI reruns the full suite.
- Builder/preflight tests: **11 pass**, including explicit budget selection.
  Flutter analysis and formatting pass.
- Provider Node tests: **47 pass** (31 existing + 16 v2); complete tooling suite
  **114 pass**. Cache-only cannot
  fetch even if given an invalid upstream claim; bad PNG and kill at finish fail.
- Native pgTAP runner: **342 assertions / eight location/map files**, including
  44 new checks, full-byte base64 bounds and UTC reset across both Rome DST boundaries. Do not batch whole
  pgTAP files as one Node SQL statement: statement timestamps differ from the
  repository's normal per-command runner. SQL lint and security advisors pass.
- `node scripts/verify-local-location-foundation.mjs`: **435 genuine local
  Auth/REST/concurrency checks**, including both daily ceilings and simultaneous
  last-unit misses (one winner). Generated types add only two RPC signatures.
  Web type checking passes with normal workspace dependencies; PR CI is authoritative.

Measured fake-provider comparison over 100 logically spaced sessions, two
ordinary local fixture actors, identical 12 identities, and synthetic aging
beyond 60 seconds (no hosted accounts or real provider calls):

| Workload                                       | Upstream requests | Reserved quarter units | Credit equivalent | Edge requests | Auth requests | Service RPCs |
| ---------------------------------------------- | ----------------: | ---------------------: | ----------------: | ------------: | ------------: | -----------: |
| Original 60-second policy, 100 expired batches |             1,200 |                  1,200 |               300 |         1,200 |         1,200 |        2,400 |
| New finite cold fill                           |                12 |                     12 |                 3 |            12 |            12 |           24 |
| New 100 sessions after aging the retained base |                 0 |                      0 |                 0 |         1,200 |         1,200 |        1,200 |

The new fixture retained **12 images / 9,072 compressed bytes**. These are
synthetic PNG measurements, not the size of real Trento imagery or an invoice.
There are 12 distinct identities; the old policy repeatedly reacquires them.
Credit equivalents multiply observed mock misses by the verified 0.25-credit
price. Request-rate minutes are reset only in the disposable fixture to model
separate sessions; credit ceilings remain enforced. The client test also spaces
100 fresh memory sessions by two minutes and observes exactly 12 mock upstream
misses. A repeated loaded Povo child uses RAM with no additional gateway call;
fresh-client ancestor/exact-cache reads at cap add zero units/upstream calls.

Reviewed Flutter-rendered captures, all **synthetic**, not mobile Geoapify proof:
[normal Trento](evidence/map-cost01/synthetic-trento-normal.png),
[Povo reduced](evidence/map-cost01/synthetic-povo-reduced.png),
[uncovered area](evidence/map-cost01/synthetic-missing-coverage.png), and
[Italian dark/2× text](evidence/map-cost01/synthetic-povo-it-dark-2x.png).
They use the existing `RenderedEvidence` harness and real SDK fonts; reproduce:

```text
flutter test --dart-define=UI_POLISH_CAPTURE_DIR=ABSOLUTE_OUTPUT_DIR test/features/geographic_discovery/budget_basemap_widget_test.dart
```

The viewport is georeferenced but fixture pixels contain no streets. Pixel tests
separately verify parent/child subrectangles and decoded quadrant color. They do
not establish real street readability or iOS/physical Android quality.

MAP-LIVE02 produced a v1 map-enabled Android debug APK from `89292af4` with
tooling-only working changes later committed in `ad661f3c`; it contains no
MAP-COST01 implementation. SHA-256:
`546acf9a6c8194c64d87c4ca053d420d7a85ba00a91a60e48886c33280d6f219`.
Package `community.planets.app`, pubspec 0.1.6+10, Android Debug signer SHA-256
`f7879aea256ffdb799ba792cbfdd8135ce7694c4e1f1035e6220fd45922e674a`.
Artifact/manifest are preserved outside Git under the task's local QA directory.

Phone was disconnected; the owned API36 emulator failed before boot due to host
memory/commit allocation. No normal staging login was supplied. Initial local
container/CLI restart interruptions were recovered before the passing checks;
no provider/security default or meaningful test coverage was weakened. A new
MAP-COST01 native APK, real imagery comparison and signed/Play release are
**not** claimed. Hosted deployment/activation is separately verified in the
[rollout report](map-staging-rollout.md). Code merge, local synthetic acceptance,
hosted activation and distribution remain separate states.
