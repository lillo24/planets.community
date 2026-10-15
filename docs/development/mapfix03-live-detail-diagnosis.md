# MAPFIX03: live Android map acceptance pending

## Outcome, 15 October 2026

MAPUI03 merged as [PR #265](https://github.com/lillo24/planets.community/pull/265),
commit `15a378b8fdc207d521db4503f6570b3dfc72b70f`. This investigation starts from
that main commit. The independent Trento fallback is implemented; **real
authenticated Geoapify rendering is still unverified**.

No shipping-code defect has been established from the available evidence. A
map-disabled installed artifact remains the leading hypothesis, not a confirmed
diagnosis of the phone. No speculative renderer patch or default flag change was
made. This report and synthetic captures preserve the handoff; they do not mark
the live-map acceptance gate complete.

## Evidence and limits

| Check                                                | Observed result                                                                                                                               | What it establishes                                                                                            |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Physical phone `48091FDAS0041A`                      | Absent from ADB; explicitly addressed `get-state` returns device not found                                                                    | Installed package/version, installer, signer, compiled gates and account are unresolved                        |
| Ordinary staging builder                             | No map defines; transport and detail defaults are false                                                                                       | An ordinary build cannot mount detail tiles                                                                    |
| Explicit map-live builder                            | Supplies transport/detail/center flags, 60-second reuse and staging editor search                                                             | The existing opt-in build path is available in source; this does not identify a distributed binary             |
| `mappa test`, `ca208af9-bacd-4ae7-a107-dd79b9624a9e` | Public area/locality, revision 7, `Trento / IT`, selected provider place present, `text_source=geoapify`                                      | The public canonical projection has geometry; no record or provenance rewrite is needed                        |
| Staging migration history                            | 96 deployed versions match all 96 versions at the investigated main commit; no missing/extra versions                                         | No current migration dependency was found; this is a dated check, not a permanent invariant                    |
| Staging provider configuration                       | enabled/tiles/centers/cache licence true; TTL 60; failure streak 0; no block; global/actor limits 8,000 quarter-credit units                  | Necessary server switches exist; actual authenticated provider success remains unknown                         |
| Deployed `map-provider`                              | ACTIVE v4, JWT verification true                                                                                                              | Function exists; this alone does not prove a request reached it                                                |
| Current tile source vs deployed files                | Entry point, map handler and tile provider match after line-ending normalization                                                              | No missing tile-code deployment was found                                                                      |
| Play Console                                         | Connected account opens developer-account signup; account-navigation attempts time out                                                        | Existing app/track, uploaded artifacts and unused version code could not be verified; no account was created   |
| Current local release inputs                         | Primary checkout lacks ignored `config/staging.json` and `android/key.properties`; historical AAB is absent at its recorded build-output path | A fresh signed candidate cannot be prepared from these inputs; signing material must be restored, not replaced |

The bundled shared `location-search/provider.mjs` in map-provider v4 predates the
county-plus-region label normalization. Its difference is confined to
`normalizeResults` administrative text. Tile fetch/validation and the shared
binary/error helpers match. This is not evidence of a missing-map cause and was
not deployed incidentally.

The deployed handler returns `application/octet-stream`; the resolved
`functions_client` **2.7.1** decodes that response as bytes. A suspected PNG MIME
decoding mismatch was excluded by inspecting both implementations. No endpoint,
authorization or response contract was changed.

### Bounded log observation

A read-only aggregate of `edge_logs`, from **14 October 12:11:27 UTC** through
**15 October 12:11:27 UTC**, found:

- `get_location_preview_v1`: 60 HTTP 200 and 7 HTTP 403 responses;
- no observed `map-provider` function path in that stream/window.

Only paths/status counts were retrieved, without identities, tokens, request
bodies or exact locations. These logs support investigating the compiled client
gate/session before changing a renderer. They do not prove that no request ever
occurred, identify the phone's session, or establish upstream health. A successful
canonical preview read is not a rendered-map result.

The older code-9/code-10 artifact evidence remains explicitly historical in
[MAPFIX02](mapfix02-project-detail-map.md). The earlier owner-reported code 9 must
not be treated as today's installed or highest Play version. The old code-10
candidate was not rebuilt, verified or distributed by this investigation.

## Validation actually performed

- [MAPUI03 final CI](https://github.com/lillo24/planets.community/actions/runs/38731235779)
  covers the identical application code now on main: formatting and analysis
  pass, **3,460 mobile tests pass**, two existing optional skips. Web/Site/Database
  correctly skip under the repository's scoped merge policy.
- `node --test scripts/lib/map-provider.test.mjs`: **31/31 pass**, rerun during
  MAPFIX03. This covers binary transport, fixed tile inputs, guest/actor binding,
  budget reservations, kill switch, malformed images and deadlines.
- The local full mobile run found superseded UI expectations, subsequently
  corrected and covered by final green CI, and one unchanged chat debounce timing
  failure under host memory pressure. Its whole file passes **16/16** in isolation;
  the final full CI also passes it. No timer/coverage was weakened.
- The current-source Android debug test APK builds successfully. On task-owned
  API36 AVD `PLANETS_MAPUI03_QA` / `emulator-5596`, the existing synthetic detail
  harness passes with both compiled tile/detail flags true. It checks decoded
  144dp imagery, approximate semantics, budget/manual fallback, EN/IT and 2x text,
  zero static calls and **zero real HTTP attempts**.

Reviewed native captures:
[EN decoded synthetic map](evidence/mapfix03/synthetic-detail-rendered-en.png)
and [IT dark 2x independent fallback](evidence/mapfix03/synthetic-detail-fallback-it-2x.png).
The latter proves the fallback state, not an Italian rendered-map acceptance.
The flat basemap bytes and area symbol are synthetic, not Geoapify map content.
The earlier widget matrix also covers decoded/failure/revocation states at
320dp in EN/IT, light/dark and normal/2x text; see [MAPUI03](mapui03-location-ui.md).

The native command reused the APK built with the two explicit true defines:

```text
flutter build apk --debug --no-pub --target=integration_test/map_detail_smoke_test.dart --dart-define=LOCATION_MAP_TILES_ENABLED=true --dart-define=LOCATION_DETAIL_TILES_ENABLED=true
flutter drive --no-pub --driver=test_driver/map05_driver.dart --target=integration_test/map_detail_smoke_test.dart --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk -d emulator-5596
```

`MAP05_CAPTURE_DIR` was a task-owned temporary evidence directory. Initial AVD
boot stalled under memory pressure; boot/build/test were sequenced and the retry
used the SDK's supported `swiftshader` renderer. No phone was installed, cleared
or uninstalled. The debug fixture is not a signed release candidate and contains
no authenticated staging session.

## Remaining owner context and release steps

1. Connect phone `48091FDAS0041A` with USB debugging authorized and leave PLANETS
   signed in normally. First read `dumpsys package community.planets.app`, installer,
   version/name, signing identity and accessible base-APK hash. Correlate its exact
   compiled gates with the build provenance; do not infer them from source/main.
   Do not clear/uninstall the app or retrieve OTP/JWT from storage or auth tables.
2. Open the existing app in the correct Play Console developer account. Verify
   package `community.planets.app`, active Closed-testing artifact/track, complete
   version history, Play App Signing certificate and upload certificate. Establish
   a positive **unused** version code; none is reserved by this report.
3. Restore the existing ignored staging configuration and original upload-key
   configuration from their trusted owner-controlled copies. Follow the
   [staging build preflight](play-closed-test.md) and
   [explicit map activation path](map-live01-android-activation.md). Do not generate
   replacement signing material or fabricate credentials. Recheck then-current
   main/staging migration parity before preparing the candidate.
4. From then-current main, build the signed APK/AAB with
   `dart run tool/build_map_live_staging.dart apk|appbundle UNUSED_PLAY_VERSION_CODE`.
   Record source commit, exact defines, backend, version, package, SHA-256, signing
   fingerprint and build/inspection logs. Verify transport and detail activation
   in that exact output; source presence or a successful build alone is insufficient.
5. Obtain separate approval before a phone update/install or Play upload/rollout.
   Keep the Play App Signing vs upload-key distinction: an upload-key APK is not
   automatically compatible with a Play-installed package. No release is published
   by merging this report.
6. With the approved current build and normal owner-controlled staging login,
   observe **one bounded** authenticated `mappa test` detail load. Correlate sanitized
   tile request/status, PNG/decode/paint and quota observations. Require actual
   Geoapify pixels, the approximate area symbol, nearby attribution and a full-map
   tap with fresh authorization. Exercise negative/lifecycle/privacy controls
   without relaxing guest policy, quotas, cache boundaries or private visibility.
   If it fails, classify the actual failing stage before preparing a narrow fix.

No migration, Edge Function/configuration deployment, project-record write,
provider quota change, real tile call, phone installation, release upload or Play
publication occurred. No new migration is necessary for MAPUI03. Live MAPFIX03
acceptance remains dependent on the device/account/artifact evidence above.
