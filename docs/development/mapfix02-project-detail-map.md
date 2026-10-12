# MAPFIX02: Project detail map diagnosis

## Finding, 2026-10-12

The missing map is **not a confirmed renderer defect**. The owner identified the
last release as **0.1.5+9**; its local compiled libraries strongly support disabled
server tile transport. The owner requested the replacement candidate **0.1.6+10**.
An ordinary/map-disabled build reproduces the reported text/Google Maps
presentation. The current renderer decodes and paints synthetic tiles on Android
when both compile-time gates are enabled. The installed binary's gates and an
authenticated live tile/render remain unverified.

Source investigation started from clean, fetched `origin/main`
`012f49564bffa79477d7947e7c58a6fdb415f512`, including UI01/UI02 and GRP03A.
This change adds offline native diagnosis coverage and this report; shipping
application logic, default flags, provider configuration and authorization are
unchanged. The owner-requested version metadata is now `0.1.6+10`.
An old binary does not acquire new Dart defines when GitHub or staging
changes.

| Evidence                                                                                                      | Classification                     | Consequence                                                                              |
| ------------------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------- |
| Ordinary staging builder supplies no map defines; both tile/detail defaults are false                         | Verified source                    | That artifact cannot mount detail tile imagery                                           |
| Explicit `build_map_live_staging.dart` supplies both flags, centers, editor search and 60-second RAM reuse    | Verified source                    | An explicit rebuild can opt in; static maps stay disabled                                |
| Existing code-7 OST01 provenance uses the ordinary builder                                                    | Verified local record              | This candidate has maps off; its distribution/installation is unknown                    |
| Existing MAPFIX01 code-8 AAB uses the explicit builder at `23a58f2`; its current SHA-256 matches its manifest | Verified local artifact/provenance | Map-enabled candidate exists, but does not identify the current Play or installed binary |
| Owner answered `9` to highest/current Play-code query                                                         | Owner-reported                     | Treat 9 as highest; active track, source and defines were not independently established  |
| ADB initial inventory was empty; only the subsequently created task emulator is connected                     | Verified                           | Phone `48091FDAS0041A` package, installer, signer and installed version cannot be read   |
| Existing Play publishing tab was discovered but every attempted binding timed out                             | Tool limitation                    | No independent Console bundle/track/signing inspection                                   |
| Canonical public preview returns Trento locality geometry                                                     | Verified live read                 | Missing provider coordinates/manual-only city is excluded for this Project               |
| Staging switches enabled; map function ACTIVE v4, JWT verification enabled                                    | Verified live metadata             | Necessary configuration exists; authenticated upstream health is not proven              |
| Valid anonymous tile request returns HTTP 401 `guest_disabled`                                                | Verified live response             | Guests cannot use the tile endpoint; a signed-in session is necessary                    |
| Enabled native fixture decodes/paints a 144dp approximate map; disabled fixture shows text action             | Verified synthetic Android         | Current layout/native decoder works with valid bytes; no proof of live provider success  |

**Leading hypothesis:** disabled build gates explain the fallback. The phone's
compiled flags and signed-in session are not established. Network/provider/decode failures
also legitimately fall back; they cannot be ruled out without its authenticated
runtime. No speculative client/server patch or global activation is justified.

## Additional code-9 binary evidence

Additional read-only inspection found the primary checkout's existing
`apps/mobile/build/app/outputs/bundle/release/app-release.aab` was inspected:

- Package `community.planets.app`, version **0.1.5+9**.
- SHA-256 `76592a7bba14408b567b2ffba037bcbcc777cad14d80bee9c5165910b596d696`.
- Upload signer SHA-256
  `F9362ED9F6F7BE7C59A6EACFD8AAE99426AF98935FF1197F65E8207CC0FD22C0`.
- All three AOT ABIs contain the staging backend and `DisabledMapProviderGateway`
  markers; none contains `ServerMapProviderGateway`. The renderer itself remains
  present, demonstrating why renderer presence alone does not establish transport.

**Inference:** this binary lacks the server map gateway selected by the compiled
transport flags. It closely explains the reported fallback despite valid geometry.
The owner answered the artifact-identification question affirmatively and confirmed
0.1.5/code 9 as the last release. This is owner correlation, not independent Play
artifact or installed-phone verification. Its source SHA/exact command and detail
flag remain unverified. Retained Gradle history contains map opt-ins from other
build inputs and cannot be used as this AAB's build manifest.

The Downloads copy of `app-release.aab` is a different 0.1.3+7 artifact. It is not
code 9. The replacement uses the existing explicit builder and the owner-requested
repository version **0.1.6+10**; do not infer release identity from generic filenames.

## Read-only staging checks

Project `ca208af9-bacd-4ae7-a107-dd79b9624a9e` remains **mappa test**, published.
Both an `anon`-role read-only transaction and an anonymous HTTPS RPC returned
`public_detail`, audience `public`, scope `area`, revision 7, place kind
`locality`, locality `Trento`, and non-null public geometry. No exact meeting
point was inspected or exposed. The deployed projection lacks `text_source`;
the client conservatively treats that as unknown and retains credits.

`private.location_provider_config`: `enabled`, `tiles_enabled`, `center_enabled`
and `cache_license_approved` true; `tile_cache_seconds=60`;
`daily_units_limit=8000`, `actor_daily_units=8000` quarter-credit units;
`failure_streak=0`, `blocked_until=null`. No quota or switch was changed.

One malformed diagnostic request returned 400; one schema-valid anonymous tile
request returned 401 `guest_disabled`. The current UTC-day `units:global` row was
absent before and after these probes. **Observed reserved-unit delta: 0**.
No authenticated tile request, upstream image, provider dashboard consumption,
real account/session creation or OTP read occurred. Fixture HTTP overrides reject
all network attempts. No approved staging-authenticated session was available.

There are 83 deployed migrations and seven later repository migrations at the
investigated base: location text provenance, profile content-only updates, group
chat covers, Proposal skill management, and the three GRP03A migrations. These
were not deployed. Existing map geometry/preview functionality is deployed;
whole-app release readiness is separate. In particular, current Messages calls
`list_own_scoped_conversation_items_v5`, supplied by the pending cover migration.
Do not distribute a latest-main candidate as a fully rehearsed release until the
pending backend compatibility work has its own authorization and validation.

## Reproduction and validation

Task-owned AVD: `PLANETS_MAPFIX02_API35`, `emulator-5590`, API 35 x86_64,
640x1600 pixels at density 320 (320dp wide). It has no real account/session.
Existing AVDs and the founder's phone were not modified.

From `apps/mobile`, set `MAP05_CAPTURE_DIR` to a task-owned absolute directory,
then run the following command with each define combination below:

```powershell
flutter drive --driver=test_driver/map05_driver.dart --target=integration_test/map_detail_smoke_test.dart -d emulator-5590
```

| Defines appended                                                                                 | Expected result                                                                  |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| None                                                                                             | No map transport/render, canonical text/Maps fallback                            |
| `--dart-define=LOCATION_DETAIL_TILES_ENABLED=true`                                               | Disabled transport still prevents map mounting                                   |
| `--dart-define=LOCATION_MAP_TILES_ENABLED=true`                                                  | Disabled detail gate still prevents map mounting                                 |
| `--dart-define=LOCATION_MAP_TILES_ENABLED=true --dart-define=LOCATION_DETAIL_TILES_ENABLED=true` | Real Proposal detail paints decoded synthetic PNGs in a 144dp approximate canvas |

All four define combinations passed on the owned emulator. Each run also checks
IT/dark/2x text, budget failure with retained attribution,
manual-only city with no invented geometry, zero static calls and zero HTTP
attempts. Screenshots named `map05-synthetic-*` are **synthetic**, not live maps.
The fixture's transport does not authenticate; it cannot establish account/RLS
or Geoapify readiness. Existing location/shared-cache tests own private revocation,
15-second renewal, lifecycle, malformed decode and protected/public boundaries.

Additional commands: `npm run check:mobile`,
`node --test scripts/lib/map-provider.test.mjs`, and the explicit builder's
existing distribution preflight tests. Standard mobile checks passed: formatting,
analysis, 2,654 tests and two existing optional skips. All 31 map-provider tests
passed. The new integration test passed in all four compiled flag combinations.
Exact logs, screenshots and local candidate identity are recorded outside Git
under the task's `mapfix02` release directory.
Initial new-harness failures (import, padded-height measurement and lazy scroll)
were corrected; they were not application defects or passing evidence.

## Artifact and owner handoff

The ignored local configuration was verified as `APP_ENV=staging`,
`ENABLE_DEMO_TOOLS=false`, backend `cllpvruvrrvxczjitlqd`. Existing signing inputs
are available and retained. No key values, JWTs or passwords enter this report.
The initial named release inventory ended at code 8; the additional primary
checkout artifact is code 9, matching the owner's last-release answer.
Code 10 is therefore a candidate based on owner-reported history, requiring
a final Console recheck before upload. It is not independently submission-ready.

Build from then-current main with:

```powershell
dart run tool/build_map_live_staging.dart appbundle 10
```

Store the AAB, source SHA, exact command/defines, SHA-256, package/version,
certificate fingerprint, backend, build log and verification outside Git. The
local `HANDOFF.md`/`build-provenance.json` identify the resulting candidate; source
presence alone is not evidence of flags in an earlier distributed artifact.

**One next owner action:** connect phone `48091FDAS0041A` by USB with ADB debugging
authorized. Its read-only package/installer/signature and runtime checks are the
smallest missing step to identify the actual installed failure before changing
distribution. Leave staging credentials and OTP entry with the owner.

If that confirms a map-disabled/outdated build, after backend compatibility and
version/signing review the owner can select Planets Community in Play Console,
open **Test and release ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Testing ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Closed testing**, select the existing track,
create a release using the exact verified local AAB, review it and roll out to
that track. The tester then updates through Google Play without uninstalling or
clearing data, signs into the staging account, and opens **mappa test ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Proposal
details**. Verify actual map pixels, approximate area, attribution and Maps
activation. If flags are enabled and tiles fail, capture the classified runtime
failure before making a code/provider change. Never use an upload-key APK to
assume compatibility with a Play App Signing-installed package.

No Play upload, publication, phone install/update, staging data edit, migration
deployment, new paid service, signing change or quota increase is part of this
task. Physical-device/live-authenticated provider QA remains pending.
