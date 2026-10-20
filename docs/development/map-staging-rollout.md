# Staging map rollout — 20 October 2026

**Deployed and enabled; not populated.** The owner explicitly authorized this
map-only staging rollout, including the seven-day public Trento retention policy.
Source was freshly pulled main `93414af566d51c7cf01176c2b7229420e34eed31`
(MAP-LIVE02 #270 and MAP-COST01 #271). The installed app has not changed.

PR #254 merged during execution. The evidence branch was reconciled with main
`db21460bbee3e8238216f1acc0ef094d3ee64ec5`; all five map bundle source files and
the map builder are unchanged. The whole-app warning below reflects that newer
source, rather than assuming the initial migration gap stayed constant.

Target reverified through the management connector: **planets-staging**,
`cllpvruvrrvxczjitlqd`, ACTIVE_HEALTHY, PostgreSQL `17.11.0.003`, EU West 1.
The sanitized [execution evidence](evidence/map-cost01/hosted-rollout.json) records
starting/effective configuration, hashes, grants, counters and remaining gaps.

## Deployed identities and history

- Canonical migration `20261020150706_map_cost01_public_trento_baseline.sql`,
  SHA-256 `549b44da10c304a38884c5aa4686bfc1d07050f631ec04a250b83a3298ef132d`.
  Staging history advanced **96 → 97**. All 96 previous rows retain digest
  `b6e5df757d6b5428f22e37a84d433edf`.
- `map-provider` **v4 → v5**, function ID
  `c5ec25e0-944c-45ee-a874-014e6fb11c10`, ACTIVE, **verify_jwt=true**.
  Deployed bundle SHA-256
  `afbba54efcce958ac5416d5e0eb9a9874827da7a931886d8d3181e917fc8b7b3`.
  All five downloaded source files exactly match the selected commit, including
  `basemap.mjs` and the bundled `location-search/provider.mjs` dependency.
- The separate `location-search` v5 and `location-preview` v4 deployments were
  unchanged. No provider key or other secret was read, replaced or embedded.

CLI 2.118.0-beta.39 still lacked authentication: the scoped `db push --dry-run`
stopped with `AccessTokenRequiredError`. The authenticated migration API provided
the working route. Its single guarded statement checked the entire prior history,
all **595** existing routine definitions/grants, existing configuration and the
canonical file hash before executing the full migration. It recorded the canonical
version/full SQL only after successful execution, with postconditions in the same
atomic statement. Lock/statement timeouts were transaction-local.

The API also generated wrapper `20261020183010`,
`map_cost01_staging_rollout_20261020`. Following the documented
[STAGING01 procedure](staging01-hosted-deployment.md), only that redundant record
was removed after exact MD5/SHA-256 and canonical-entry verification. The wrapper
hashes remain in the evidence. No unexecuted SQL was marked applied, old history
rewritten, shared data reset or unrelated migration deployed. The 595 prior
routines/grants retain digest `c2b4a57330b2710dbab55b12468cf7b1`.

## Effective policy and cost

Enabled at **2026-10-20 18:31:30 UTC**, verified again at 18:35:27 UTC:

| Setting                                        | Effective value                                      |
| ---------------------------------------------- | ---------------------------------------------------- |
| Baseline enabled / license approved            | true / true                                          |
| Baseline retention / revision                  | 604800 seconds / 1                                   |
| Fixed coverage                                 | z12, x2173..2175, y1454..1457                        |
| Storage bounds                                 | 12 tiles, 3 MiB compressed total                     |
| Shared global ceiling                          | 8000 quarter units = 2000 credits/day                |
| Actor ceiling                                  | 8000 quarter units/day, unchanged                    |
| Request limits                                 | actor 30/minute; global 120/minute                   |
| Ordinary tile retention                        | 60 seconds, unchanged                                |
| Master, tiles, centers, ordinary cache license | enabled, unchanged                                   |
| Editor search                                  | enabled; actor 80/day and 10/minute, global 1000/day |
| Baseline population                            | **0 rows / 0 ready tiles / 0 bytes**                 |

The global current-day ledger remained **0 → 0 quarter units**, and no provider
requests were made by this QA. Guest requests stop before reservations. No quota
was increased or lowered, and no real allowance was consumed to test exhaustion.
Population is deliberately left to the next eligible authenticated foreground
visit from a client built with `--budget-basemap`; it must use normal reservations.
An enabled empty cache does not promise fallback imagery before that acquisition.

The owner approved these retention values in this rollout prompt. Rechecked
[Geoapify tile policy](https://www.geoapify.com/map-tiles/) permits caching,
storing and redistributing generated tiles. The
[osm-carto documentation](https://apidocs.geoapify.com/docs/maps/) specifies
0.25 credit per standard tile and Geoapify/OpenStreetMap attribution; the current
client keeps both attributions. [Terms v5, 2 February 2024](https://www.geoapify.com/terms-and-conditions/)
preserve plan-specific usage limits. The account portal reached its sign-in page;
no account-specific contract was accessible and no concrete contrary retention
restriction was found. Published permission plus explicit owner approval supplied
the activation basis. No paid service or production resource was activated.

## Verification and its limits

- **18 live SQL assertions passed**: fixed coverage, bounded base64 payload,
  UTC resets across both DST dates, empty
  ancestor behavior, guest refusal and service-only grants. These checks did not
  insert images, claim reservations or impersonate a user.
- **10 real HTTP checks passed**; see [transport results](evidence/map-cost01/transport-results.json).
  Anonymous public Trento search returned **200 / one item / no next page**.
  Legacy tile/city and valid new v2 requests returned **401 guest_disabled**;
  malformed JWT returned 401. Both service RPCs denied anonymous execution
  (`42501`), the private schema was unavailable (`PGRST106`), and preflight was 204.
  The handler's early gates show tile/center runtime flags and a nonempty map key
  are present; that does **not** validate the key with Geoapify.
- **47 provider tests passed**, rerun against source verified identical to the
  deployed bundle. Their old-client tile/city shapes, budget/failure paths,
  cache-only no-IO and exact ancestor behavior use synthetic providers/auth.
  Accepted source [CI](https://github.com/lillo24/planets.community/actions/runs/39457745643)
  also passed 3,676 Mobile tests (two skipped), 5,894 SQL assertions and 435 genuine
  local Auth/REST/concurrency checks. Exhaustion evidence is local, not hosted.
- Both new private tables have RLS and only owner raw grants; their new public
  RPCs grant EXECUTE only to service_role. Existing map routines/grants, search
  configuration, limits and ordinary TTL match preflight.
- Security advisor comparison adds only the two expected
  [RLS-without-policy INFO findings](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
  for the RPC-only private tables. Existing
  [anon definer](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
  (38), [authenticated definer](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
  (315), and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
  (one) warnings are unchanged; no new warning or exposure was introduced.

ADB listed no connected devices. No ordinary authenticated PLANETS session was
available. Real authenticated tile/city success, cache acquisition/reuse, and
Trento → Povo painted real imagery therefore remain unverified. No stored OTP/JWT
was retrieved or authentication weakened. No new real/cached-real screenshots
were produced; the four earlier Flutter captures remain **synthetic**. No emulator
or release build was necessary for the independent backend work. The phone and
the previously blocked cleanup directory were left alone.

## Final owner build and whole-app compatibility

From `apps/mobile`, with the existing strict ignored staging/signing configuration,
replace `UNUSED_PLAY_VERSION_CODE` with a code verified unused in Play history:

```text
dart run tool/build_map_live_staging.dart appbundle UNUSED_PLAY_VERSION_CODE --budget-basemap
```

For a signed APK use `apk` instead of `appbundle`. The builder supplies all six
required defines: `LOCATION_MAP_TILES_ENABLED=true`,
`LOCATION_MAP_CENTERS_ENABLED=true`, `LOCATION_DETAIL_TILES_ENABLED=true`,
`LOCATION_MAP_CACHE_SECONDS=60`, `LOCATION_EDITOR_SEARCH_ENABLED=true`, and
`LOCATION_BASEMAP_BUDGET_ENABLED=true`. Staging JSON supplies `APP_ENV=staging`
and the verified staging URL/client publishable key. It never contains the
provider or service key. The command builds only; distribution remains owner-owned.

**Whole-app warning:** reconciled main has **122 migrations, staging 97**.
There are now **25 unrelated pending Group/contact migrations**: the original
eight plus 17 from PR #254. Both snapshots are in the execution JSON. Catalog
checks confirm `list_own_scoped_conversation_items_v7` and
`get_own_message_unread_summary_with_contacts_and_discussions`, called by current
main's Messages gateways, are absent, alongside the Group discussion APIs.
Messages/unread and corresponding Group/contact features therefore lack backend
parity in a new whole-app build. This map rollout does not certify a whole-app
release and did not deploy those unrelated features. No installed app change,
signed artifact, Play upload or release is claimed.

## Rollback

No regression requiring rollback was found in the completed checks. If a later
authenticated map check demonstrates one, disable only
`private.map_baseline_config.enabled`; retain the additive migration and existing
limits. A client built without `--budget-basemap` continues using v1. Restart a
client after changing its learned shutdown state. The former v4 bundle was saved
outside Git under `C:/Users/utente/.planets/qa/map-staging-rollout/rollback` for a
targeted redeployment if needed; function versions increment normally. Avoid a
baseline purge unless deliberately reacquiring bytes, and never reset quotas or
unrelated data as rollback.
