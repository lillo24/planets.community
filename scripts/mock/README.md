# Dedicated mock environment

This package owns explicitly invoked mock-only operations. It never imports the
local demo seeder and never removes its loopback guard.

- `target.mjs` owns the exact project allowlist and canonical migration digest.
- `operator.mjs` owns dry-run inventory, setup, enrollment and offboarding.
- `world.mjs` owns non-destructive ordinary-persona fixture operations.
- `verify.mjs` reads canonical fixtures without repairing them.
- `target.test.mjs` exercises target-confusion and credential rejection.
- `qualify-local.mjs` owns two new disposable stacks, unique signing/API keys,
  canonical fixture replay, standard Auth sessions, isolation and offboarding.
- `native-bridge.mjs` is restricted to GitHub-hosted Linux. It forwards the
  release fixture's loopback traffic to those real stacks and the reviewed broker,
  captures bounded synthetic PNGs, and verifies the canonical cross-person write.
- `scan-native-apk.py` scans every private APK entry for privileged credentials
  and embedded session JWTs, exporting counts and an APK hash only.
- `collect-native.mjs` exports allowlisted evidence and source provenance. Private
  defines, signing inputs, raw runtime logs and APKs never become artifacts.

The operator configuration is an ignored JSON file outside source control. See
`docs/development/mock-environment.md`. Secrets are environment variables, never
command arguments or report output. There is no hosted reset command.
