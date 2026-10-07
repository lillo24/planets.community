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
- `verify-local-message-unread.mjs` owns MSG02 authenticated count/read,
  delayed-commit, private invalidation and activity/push separation proofs.
  Its `--upgrade` mode resets only an explicitly disposable local stack to
  populated MSG01, then verifies atomic cutover and retained historical rows.
  Its first upgraded feed read polls PostgREST's `PGRST202` missing-cache response
  for up to 10 seconds, every 200ms, because CLI completion precedes schema-cache
  readiness. Other errors and all mutations fail immediately without retries.
- `classify-validation-paths.mjs` selects affected hosted validation areas.
- `verify-local-message-list-preview-upgrade.mjs` resets an explicitly disposable
  local stack to main's `20261007090000` predecessor (including MSG02), populates
  canonical pair/legacy/group fixtures, applies
  UI-MSG03 and proves v3 definitions/payloads remain identical across every
  fixture actor and scope while v4 adds only its two preview fields. Run
  `npm exec --call "node scripts/verify-local-message-list-preview-upgrade.mjs"` with
  `PLANETS_DISPOSABLE_QA=1` and the selected stack's `MAILPIT_URL`; it never
  targets a hosted database.
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
