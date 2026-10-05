# Repository scripts

This folder owns reproducible configuration generation, local authenticated
domain verification and change-scoped validation tooling.

- `generate-database-types.mjs` writes the canonical public TypeScript schema
  from the checkout's local Supabase stack. Never hand-edit its output.
- `generate-*-local-config.mjs` prepares local client configuration.
- `verify-local-*.mjs` exercise each named domain against disposable synthetic
  local data. Root `package.json` maps commands; the
  [database guide](../docs/development/database.md) maps setup and checks.
  Run pgTAP before verifiers populate the stack.
- `verify-local-similar-active-proposals.mjs` owns SIM01 OTP/API, ranking,
  capacity/blocking/media/privacy and read-only assertions. Its rollback-only
  `fixtures/sim01-query-plan.sql` supplies reproducible EXPLAIN work.
- `process-local-*.mjs` exercise local projections/workers.
- `classify-validation-paths.mjs` selects affected hosted validation areas.
- `lib/` owns shared local-session/status/photo helpers, deterministic demo
  validation and classifier logic with focused tests.

SIM01's RPC/input/response/error/ranking and SIM02 caller contract is in
[similar-active-proposals.md](../docs/development/similar-active-proposals.md).
No submitted query history or matching worker is created.

- `reset-local-demo-world.mjs` validates project-scoped loopback targets before an explicitly destructive disposable database reset.
- `verify-local-workshop-demo.mjs` is the bounded mutating TW05 stability/interruption/transition check, after domain tests and before generated-type drift in Database validation. It never resets; `verify-local-demo-world.mjs` is its separate non-repairing reader. [Reproduction and PI05 composition](../docs/development/workshop-demo-validation.md).
