# Dedicated mock environment

`world.mjs` now registers two separate five-person login catalogs: Activities
(Giulia, Marco, Sara, Dario, Elena) and Find people (Luca, Maya, Nora, Teo, Iris).
The mock-only registry's dataset field is presentation metadata, never authority.
`people-world.mjs` creates the requested categorized interests, three-account
activation, explicit General/group admission, timed 4/7 and full meeting cards,
persistent chat messages and pending proposals through the canonical RPCs.
`verify.mjs` checks those exact fixtures without repairing tester edits.
Settings presentation selection filters Home Help's offered login profiles;
Mock remains an independent realm. This task does not apply hosted changes.

This package owns explicitly invoked mock-only operations. It never imports the
local demo seeder and never removes its loopback guard.

- `target.mjs` owns the exact project allowlist and canonical migration digest.
- `operator.mjs` owns dry-run inventory, setup, maintenance and mock-only shutdown.
  Temporary CLI access initializes four actual session-pooler connections with
  `SET SESSION ROLE postgres`; a lost connection fails closed for that operation.
- `hosted-setup.mjs` runs the same seed/verifier on an explicitly selected owned CI
  host, using a short-lived platform CLI login for the disabled mock target only.
  Its private `verifyOnly` boolean skips control/seed mutations after a schema-only
  upgrade. Auth sessions remain real; failures export bounded codes/status only.
- `world.mjs` owns non-destructive ordinary-persona fixture operations.
- `public-geography.mjs` adds once-receipted fictional public references under
  the verified mock marker; it preserves existing points and edited localities.
- `basemap-fixture.mjs` replaces only provider PNGs for real two-realm Auth/SQL
  qualification; `verify-basemap.mjs` proves shared cache, subcaps, global races,
  revocation and kills without hosted/provider access.
- `verify.mjs` reads canonical fixtures without repairing them.
- `target.test.mjs` exercises target-confusion and credential rejection.
- `qualify-local.mjs` owns two new disposable stacks, unique signing/API keys,
  canonical fixture replay, standard Auth sessions, isolation and client retirement.
  It first runs the real notification worker concurrency/rollback regression on
  its owned loopback realm, so a queue failure stops before an expensive native build.
- `native-bridge.mjs` is restricted to GitHub-hosted Linux. It forwards the
  release fixture's loopback traffic to those real stacks and the reviewed broker,
  captures bounded synthetic PNGs, and verifies the canonical cross-person write.
- `scan-native-apk.py` scans every private APK entry for privileged credentials
  and embedded session JWTs, exporting counts and an APK hash only.
- `collect-native.mjs` exports allowlisted evidence and source provenance. Private
  defines, signing inputs, raw runtime logs and APKs never become artifacts.
  A failed synthetic native test includes at most four redacted assertion summaries
  with its current operation; release-mode Flutter omits those details by default.
  Qualification checks the current persona manifest; native metadata separately
  records the five activity-persona journeys exercised by the device fixture.

The operator configuration is an ignored JSON file outside source control. See
`docs/development/mock-environment.md`. Secrets are environment variables, never
command arguments or report output. There is no hosted reset command.
