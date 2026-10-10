# Mobile distribution tooling

This folder owns the closed-test build preflight, separate from runtime config.

- `staging_distribution.dart` rejects local/example backends, non-publishable
  keys, extra config keys and enabled/omitted demo tools without logging values.
- `build_staging_bundle.dart` reads ignored local config, checks for the signing
  file, then invokes the ordinary Flutter release bundle command. Gradle owns
  validation of the signing material.
- `build_map_live_staging.dart apk|appbundle UNUSED_PLAY_VERSION_CODE` applies
  the same strict five-key staging preflight and original signing arrangement,
  then explicitly opts into tiles, centers, detail tiles, 60-second RAM reuse
  and staging editor search. Check current Play history before choosing the code.
  It builds only; it never installs, uploads or publishes. See
  [MAP-LIVE01](../../../docs/development/map-live01-android-activation.md).

From `apps/mobile`, run `dart run tool/build_staging_bundle.dart`. The stricter
managed-project origin/key rules apply only to CT-01 distribution, not local or
self-hosted runtime configuration. See the
[setup and artifact verification runbook](../../../docs/development/play-closed-test.md).
The preflight tests run with the ordinary `flutter test` suite.
