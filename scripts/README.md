# Repository scripts

- `run-contact-native-ci.sh` owns the explicitly opted-in ephemeral Linux Android
  runtime for both D/M review journeys, with serial builds and complete drivers.
  It refuses developer/self-hosted runtimes. `collect-contact-native-evidence.mjs`
  exports only fictional PNGs, compact results, source hashes and scrubbed failure
  diagnostics; session defines, instrumented APKs and raw logs stay private.
  See [workflow triggers and cost](../.github/workflows/README.md).

- `verify-local-member-contact.mjs` owns real local OTP/PostgREST checks for
  personal consent, retained history, legacy readers and observed context-loss races.
- `verify-local-member-contact-upgrade.mjs` resets an explicitly disposable local
  predecessor, hashes existing records and verifies additive/repeated upgrades.
  Both are in `check:db`; see the [provisional contract](../docs/development/member-contact-backend-review.md)
  for isolation and the unresolved policy gate. No hosted or peer-stack use.

- `verify-local-group-contact.mjs` owns D01 real Auth/PostgREST checks for
  private requests, explicit conversation admission, receipts, v5/v6 compatibility,
  unread, targeted reporting and observed send/revoke races.
  It genuinely reports both a disclosed pending request and a received message,
  checks exact target/context storage and rejects outsider/self request reports;
  the mixed C/D/M upgrade gate requires both populated families.
- `verify-local-group-contact-upgrade.mjs` resets only an explicitly disposable
  loopback stack to the pre-D boundary, populates current-main demo/group history,
  hashes every existing table/column/row and verifies additive/repeated upgrades.
  Set `PLANETS_DISPOSABLE_QA=1` outside CI; `MAILPIT_URL` follows the selected
  local stack. Both commands use the checkout's pinned CLI and fail on unavailable
  runtime state. See the provisional D contract and execution evidence.
- `lib/verify-basemap-budget.mjs` extends the existing disposable local location
  verifier with genuine Auth/service REST, a bounded Trento cost comparison,
  cache-only/ceiling/ancestor checks and aggregate request counters. Its provider
  is synthetic; it never consumes Geoapify credits or creates hosted users.

- `verify-local-group-ideas.mjs` checks the revised General/Idea roles, full
  history, exact exit cutoffs and independent participation/oversight rights.
  `verify-local-group-ideas-upgrade.mjs` separately resets an explicitly disposable
  loopback stack to the complete old C predecessor and proves populated row and
  admission preservation across repeated forward application.
- `verify-local-group-discussion-links.mjs` checks General and Idea workspaces,
  versioned mutations, full current collections and canonical Project-only folders.
  `verify-local-group-discussion-conversion.mjs` checks reviewed publication,
  frozen source history and deliberate Project admission. These verifiers run in
  the existing Database job; the upgrade runs before its final fresh reset.

- `verify-local-group-discussions.mjs` owns C01 real OTP consent, episode/history
  denial, command receipts, canonical unread/read snapshots, exact staff evidence
  and observed Group-lock races. `--upgrade` requires CI or
  `PLANETS_DISPOSABLE_QA=1`, resets the selected loopback stack to C01's predecessor,
  populates existing demo/Group/moderation histories and compares every old column
  and row after additive and repeated migration application.

- `verify-local-group-membership.mjs` owns GRP03A genuine Auth/PostgREST
  relationship, role, block, retry and observed multi-connection lock races.
  `--upgrade` resets an explicitly disposable loopback stack, populates GRP01,
  Project delegates/invitations/memberships/chats and policy history, then checks
  every existing table/column/row after both migration applications.

- `verify-local-persistent-groups.mjs` owns GRP01 OTP, duplicate-command/report
  concurrency, directory privacy/keysets, suppression and orphan tests. `--upgrade`
  resets an explicitly disposable loopback stack to the predecessor and verifies
  every existing column/row after additive migration application.
  `fixtures/grp01-query-plan.sql` supplies rollback-only representative EXPLAINs.

This folder owns reproducible configuration generation, local authenticated
domain verification and change-scoped validation tooling.

- `verify-local-staging01-upgrade.mjs` owns the one-time STAGING01 exact hosted
  baseline/populated-upgrade rehearsal. It requires a designated non-default
  disposable loopback stack and records only counts/hashes. It has no hosted
  deployment mode. See [the preflight](../docs/development/staging01-recovery-preflight.md).

- `generate-database-types.mjs` writes the canonical public TypeScript schema
  from the checkout's local Supabase stack. Never hand-edit its output.
- `generate-*-local-config.mjs` prepares local client configuration.
- `official-starter-inventory.mjs` emits read-only preflight/catalog-diff SQL
  or verifies the actual anonymous public Workshop RPC. It has no mutation mode.
  `verify-local-official-starter-templates.mjs` is the separate loopback-only
  fixture/concurrency verifier composed by `proposal:verify:local`. See
  [OST01 activation and ownership](../docs/development/official-starter-templates.md).
- `verify-local-*.mjs` exercise each named domain against disposable synthetic
  local data. Root `package.json` maps commands; the
  [database guide](../docs/development/database.md) maps setup and checks.
  Run pgTAP before verifiers populate the stack.
- `verify-local-proposal-skills.mjs` is composed by `proposal:verify:local`.
  It requires an explicitly disposable loopback stack, uses real OTP/JWT calls,
  proves both queued skills/details save orders and skill conflicts with actual
  row locks, and checks queued revocation and unchanged resource privileges.
  See [UI02 contract](../docs/development/ui02-skills-resources.md).
- `verify-local-public-ideas.mjs` exports the IDEA01A OTP/JWT and concurrency
  scenarios, composed by `verify-local-proposals.mjs`. It requires explicitly
  disposable loopback API/database/mailbox targets; it never resets or targets
  hosted data. See the [API/review handoff](../docs/development/idea01a-public-idea-domain.md).
- `verify-local-similar-active-proposals.mjs` owns SIM01 OTP/API, ranking,
  capacity/blocking/media/privacy and read-only assertions. Its rollback-only
  `fixtures/sim01-query-plan.sql` supplies reproducible EXPLAIN work.
- `verify-local-project-organization.mjs` owns CHECK01 OTP/JWT privacy, roles,
  CAS/retry, bounded task and capacity/admission races. It is composed by
  `proposal:verify:local` and requires disposable loopback targets.
- `verify-local-project-organization-upgrade.mjs` rehearses the populated legacy
  Idea rollout refusal and clean replay on an explicitly disposable non-default
  local stack. See the [CHECK01 contract](../docs/development/check01-project-organization.md).
- `verify-local-policy-acceptance.mjs` checks real OTP sessions without profiles,
  concurrent first acceptance, preserved server time, second-session restoration,
  account/version denial and private Data API isolation. It refuses non-loopback
  API/database/mailbox targets. See the [policy contract](../docs/development/policy01b-server-acceptance.md).
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
  local stack to main's `20261007103000` predecessor (including MSG02), populates
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

## C/D populated integration

`verify-local-contact-discussion-upgrades.mjs` owns the exact immutable C→D and
D→C populated upgrade checks, row/function preservation and genuine mixed report/
unread checks. It serially resets only the explicitly disposable selected local
stack. Its temporary migration-set journal and recovery steps are documented in
[combined qualification](../docs/development/contact-discussion-integration.md).


- `lib/profile-avatar-variant-verifier.mjs` extends the existing profile-photo
  viewer gate with real local Auth/Storage checks for IMG01 immutable variants,
  legacy RPC shapes, contextual authorization, Block, removal and byte ceilings.
  It uses the viewer verifier's synthetic actors and restores their original
  photo after its fixture checks. It does not use hosted accounts or service keys.
