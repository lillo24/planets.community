# Dedicated mock environment

This package owns explicitly invoked mock-only operations. It never imports the
local demo seeder and never removes its loopback guard.

- `target.mjs` owns the exact project allowlist and canonical migration digest.
- `operator.mjs` owns dry-run inventory, setup, enrollment and offboarding.
- `world.mjs` owns non-destructive ordinary-persona fixture operations.
- `verify.mjs` reads canonical fixtures without repairing them.
- `target.test.mjs` exercises target-confusion and credential rejection.

The operator configuration is an ignored JSON file outside source control. See
`docs/development/mock-environment.md`. Secrets are environment variables, never
command arguments or report output. There is no hosted reset command.
