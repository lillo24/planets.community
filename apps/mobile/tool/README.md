# Mobile maintenance and distribution tooling

This folder owns closed-test build preflight and offline reference-data updates,
separate from runtime config.

- `staging_distribution.dart` rejects local/example backends, non-publishable
  keys, extra config keys and enabled/omitted demo tools without logging values.
  The optional public `GOOGLE_WEB_CLIENT_ID` is shape-validated; empty/omitted
  keeps Google disabled. See the [Google runbook](../../../docs/development/auth01b-google-android.md).
- `build_staging_bundle.dart` reads ignored local config, checks for the signing
  file, then invokes the ordinary Flutter release bundle command. Gradle owns
  validation of the signing material.
- `build_map_live_staging.dart apk|appbundle UNUSED_PLAY_VERSION_CODE` applies
  the same strict staging preflight and original signing arrangement,
  then explicitly opts into tiles, centers, detail tiles, 60-second RAM reuse
  and staging editor search. Check current Play history before choosing the code.
  It builds only; it never installs, uploads or publishes. See
  [MAP-LIVE01](../../../docs/development/map-live01-android-activation.md).
  `debug-apk` uses the same validated staging configuration and map flags for
  an owned emulator, without upload signing or a Play version code. A successful
  build writes `build/map-live-staging/manifest.json` with source commit/dirty
  status, backend, package, mode and defines, excluding keys. Record the APK
  SHA-256 and signer alongside this manifest before handoff. The builder does
  not establish that a version code is unused or that live rendering passed.
- `generate_italian_municipalities.py` uses Python 3's standard library to check
  the pinned ISTAT workbook SHA-256/schema/count, then extract only official
  municipality name aliases into a const Dart lookup. It invokes the repository's
  Dart formatter. `data/istat-municipalities-2026-02-21.xlsx` is the original
  official workbook, retained for reproducibility, not packaged in the app.
  Source and adaptation are licensed CC BY 4.0; see
  [the source record](../../../docs/development/mapui03-location-ui.md).

Regenerate from `apps/mobile` with Python 3 on PATH:

```text
python tool/generate_italian_municipalities.py tool/data/istat-municipalities-2026-02-21.xlsx
```

A source refresh deliberately fails until the workbook checksum, expected schema/
municipality count, source/retrieval dates and licence notice are reviewed and
updated together. Normal Flutter builds need neither Python nor network access.

From `apps/mobile`, run `dart run tool/build_staging_bundle.dart`. The stricter
managed-project origin/key rules apply only to CT-01 distribution, not local or
self-hosted runtime configuration. See the
[setup and artifact verification runbook](../../../docs/development/play-closed-test.md).
The preflight tests run with the ordinary `flutter test` suite.
