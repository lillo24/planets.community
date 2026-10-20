# MAP-LIVE02 execution evidence

Execution starts at main `89292af4` on 20 October 2026. Live acceptance remains
pending an ordinary owner-controlled staging login. No authenticated provider
response or painted real mobile imagery has yet been established by this run.

## Verified layers

- Read-only management access confirms `planets-staging`,
  `cllpvruvrrvxczjitlqd`, ACTIVE_HEALTHY, Postgres 17.
- `map-provider` v4 and `location-search` v5 are ACTIVE with JWT verification
  enabled. Tile/center/master/license gates are true, ordinary tile TTL is 60
  seconds, and account/actor ceilings remain 8,000 quarter-credit units.
- The current-day global ledger contained zero reserved units before native QA.
- A real **anon REST** call to `search_public_geography_v1` for the repository's
  default Trento reference returns HTTP 200, one item, no additional page.
  Both anon/authenticated roles have EXECUTE on its exact three-argument API.
  A privileged SQL result alone was not used as transport evidence.
- Staging has 96 migrations; this source has 104. Map functions have no later
  replacement in source, but full staging/source parity is **not** claimed.
- The physical phone `48091FDAS0041A` is absent from ADB. No phone package,
  signing, compiled flags or session could be inspected; it was not modified.
- No local staging JSON or upload signing configuration was initially present.
  The ignored staging JSON was reconstructed using the existing project's
  client-safe publishable key. No secret/server key, JWT or provider key was
  copied into a client or report.

## Narrow change

The explicit staging builder now supports
`dart run tool/build_map_live_staging.dart debug-apk` from `apps/mobile`.
It uses the same strict managed-staging validation and five existing opt-in map
defines as the signed path. It needs neither upload signing nor a Play version
code. Signed `apk|appbundle UNUSED_PLAY_VERSION_CODE` behavior remains explicit.

Successful builds write `build/map-live-staging/manifest.json` containing source
commit/dirty status, backend origin, package, mode, target and the map defines.
Keys and other configuration values are excluded. Record artifact SHA-256,
signer and SDK alongside this manifest; it proves build inputs, not rendering.
Failed Flutter builds remove previous success evidence before invoking Flutter.

There is no demonstrated application, SQL or tile-adapter defect to patch yet.
Both `api.geoapify.com` and the documented `maps.geoapify.com` endpoint return
HTTP 401 JSON without a key and no redirect. This unauthenticated probe cannot
establish which endpoint succeeds with the existing account; the fixed adapter,
redirect prohibition and JWT checks are unchanged. Current reference:
[Geoapify Maps](https://apidocs.geoapify.com/docs/maps/).

## Checks and remaining acceptance

Executed: 10 build/preflight tests, 31 provider tests, `flutter analyze` (no
issues), Dart formatting and `git diff --check`. Existing provider tests cover
guest/actor binding, fixed inputs, reservation failures, binary validation,
deadlines and kill during fetch. Hosted CI is recorded by the PR.

The first native build failed before compilation because the template's 8 GiB
Gradle heap exceeded this host's commit limit. The retry uses task-process
`GRADLE_OPTS` to select a 768 MiB heap, 384 MiB metaspace, 128 MiB code cache and
one worker. No repository/global memory configuration is changed.

Task-owned Android target: AVD `PLANETS_MAP_LIVE02_QA`, `emulator-5598`, API 36.
Only this emulator may receive the debug artifact. Normal login must be entered
by the owner, without extracting sessions or OTPs. Do not capture login UI.
Use the journey and bounded quota procedure in the
[implementation plan](../../history-implementations/PLANETS_MAP-LIVE02_live_map_search_acceptance_2026-10-20.md).

Still pending: authenticated tile/city requests, decoded and painted Geoapify
imagery, real navigation/filter/detail and guest/lifecycle screenshots, measured
client/Edge/upstream deltas, physical Android/iOS QA and signed distribution.
No hosted migration/function/configuration change, Play action or quota increase
is authorized or performed by this execution. Full live acceptance must not be
inferred from this source change or the public-search success.

MAP-COST01 may proceed after this PR merges against the stable existing map
contract while external login evidence is missing. Any subsequently demonstrated
authorization/API defect stops dependent activation until resolved.
