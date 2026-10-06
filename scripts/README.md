# Repository scripts

`prepare-local-modint01-qa.ps1` is the guarded resumption utility for draft PR
#154. It accepts the exact retained canonical `config.toml` backup, requires the
existing MODINT01 branch, and refuses unrelated config changes. `Prepare`
recreates only that project's fixed local ports; it never starts/resets services.
`Restore` refuses a running MODINT01 stack and copies the original bytes back,
checking their hash. Both support `-WhatIf`. Keep backup/startup logs outside Git;
CLI status/start output can contain local credentials. See the MODINT01 review
packet for the owned backend, AVD and exact remaining QA commands.

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
- `verify-local-message-unread.mjs` owns MSG02 authenticated count/read,
  delayed-commit, private invalidation and activity/push separation proofs.
  Its `--upgrade` mode resets only an explicitly disposable local stack to
  populated MSG01, then verifies atomic cutover and retained historical rows.
- `classify-validation-paths.mjs` selects affected hosted validation areas.
- `lib/` owns shared local-session/status/photo helpers, deterministic demo
  validation and classifier logic with focused tests.

SIM01's RPC/input/response/error/ranking and SIM02 caller contract is in
[similar-active-proposals.md](../docs/development/similar-active-proposals.md).
No submitted query history or matching worker is created.

- `reset-local-demo-world.mjs` validates project-scoped loopback targets before an explicitly destructive disposable database reset.
- `verify-local-workshop-demo.mjs` is the bounded mutating TW05 stability/interruption/transition check, after domain tests and before generated-type drift in Database validation. It never resets; `verify-local-demo-world.mjs` is its separate non-repairing reader. [Reproduction and PI05 composition](../docs/development/workshop-demo-validation.md).
- `verify-local-demo-stack.mjs` composes PI05 and TW05 phases under one mutation lock/session pool, retaining both interruption proofs. The standalone runners export their existing phases for this owner.
- `verify-local-global-notifications.mjs` exercises the unrestricted canonical worker after delegated blocking/domain rejection producers, without demo row locks or fabricated receipts.
- `verify-local-stack-upgrades.mjs` owns two sequential disposable predecessor stacks and interleaved migration replay. `verify-local-stack-upgrade-state.mjs` hashes every original column/row, checks explicit new-column projections, then separately proves combined seed convergence. The [integration record](../docs/development/template-stack-integration.md) records immutable inputs, port ownership and cleanup.
