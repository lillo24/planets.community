# Staging and closed-test release tooling

This module owns release orchestration, separate from application/domain rules.
Nothing enables deployment merely by merging these files. Main pushes cannot
build or publish an Android artifact; those remain manual routes.

`errors.mjs` exposes only repository-authored failure messages; native/provider
diagnostics stay out of public Actions output.

- `policy.json` pins staging, the observed closed track/code floor/upload
  certificate and approved Edge bundle/source hashes. It records the 26 approved
  bootstrap hashes, fixed boundary, populated rehearsal and explicit backup waiver.
  Live history determines whether bootstrap is complete; no state flag bypasses it.
- `migrations.mjs` inventories canonical files, compares applied history and
  rejects drift or an unexpected backlog. `sql-fingerprint.mjs` compares SQL
  tokens without changing literals or function bodies; original file and remote
  statement SHA-256 values remain separate evidence.
- `backend.mjs` owns bounded metadata reads, required mobile RPC inventory,
  Storage/RLS/grant/map/Edge checks and anonymous legacy/V2/privacy HTTP smoke.
  Only the dedicated isolated-Mock URL validator is excluded from normal-staging
  Edge inventory; ordinary builds reject Mock capability and endpoints.
- `staging.mjs inspect|deploy|verify` performs identified preflight, approved CLI
  apply and verification. Apply is supported only in the protected Linux runner.
  It never repairs history, includes seeds/roles/Vault secrets or deploys Edge
  Functions. `--include-all` is restricted to one exactly approved historical file at a time.
- `safety.mjs` owns the complete conservative SQL grammar, canonical inventory
  digests, catalog/security preservation and whole-set authorization. A nullable
  column is only a candidate until populated/catalog witnesses prove compatibility.
- `reviews.mjs` blocks risky PRs in the existing required classification check,
  scopes its populated rehearsal and verifies owner issue-comment proof against
  exact pre-merge head/file/predecessor bytes again at deploy. It accepts no
  post-merge-created/edited authorization. No credentials or raw comments persist.
- `recovery.mjs` verifies a fresh metadata-only receipt from a source-hash-pinned
  main recovery workflow: encrypted/access-controlled DB **and Storage objects**,
  restored against the exact predecessor. Missing one-time setup blocks writes;
  the old task-specific waiver is not reused. It never downloads a real backup.
- `writer.mjs` checks protected readiness, exact tested/rehearsed/current main,
  the whole mixed set, independent history, advisory lock and recovery before
  per-file CLI dry/apply. It retains only safe evidence and never repairs history.
- `reconciliation.json` leaves the exact original two-file historical catch-up
  disabled, bound to fresh observed history. The third pending ACTAPI file needs
  its own review and receives no chronology bypass.
- `inventory.mjs REMOTE_STATEMENTS_JSON OUTPUT_JSON` produces an offline review
  manifest from a metadata-only migration export. It never connects to a backend.
- `rehearse.mjs` reconstructs the observed non-contiguous staging predecessor on
  a fresh disposable Actions runner, populates fictional Auth/Profile/Proposal
  records, checks every original column/row digest after each file, proves actual catalog
  semantics (including a rollback-only positive fixture), applies candidate files,
  checks no-op retry, real Resource Auth/REST and generated types. It refuses
  local/shared/remote targets. Its result is evidence, never rollout approval.
- `validation.mjs` reuses or dispatches the complete existing `Validation` suite
  on the exact main SHA. All four areas must succeed; skipped checks do not count.
- `config.mjs` validates explicit `staging` (Mock off) and `closed-test-mock`
  (fixed isolated Mock on) variants; production is rejected. Normal backend
  verification continues to use only the original staging configuration.
- `android.mjs build` rechecks hosted readiness, selects a verified fresh
  code, creates temporary signing/config files without overwriting owner inputs,
  calls the existing Dart map builder and verifies/persists the AAB. Its `finally` removes only files it
  created. Runner termination is additionally covered by ephemeral runner teardown.
- `publish.mjs` runs in a separate publication environment after the artifact is
  reviewable. It checks the persisted receipt/hash/source, rechecks hosted readiness
  and submits only that AAB; it needs no signing key. First owner approval occurs
  here, after preparation.
- `artifact.py` inspects package/code/SDK/debug flags, upload signature and every
  signed payload, original certificate, source/backend/map flags, compiled origin
  and the effective compiled Mock marker in every ABI, scans every payload for
  privileged keys/JWTs, and checks 64-bit ELF alignment using checksum-pinned bundletool and the installed JDK.
  The original upload certificate is self-signed: its known JDK trust-chain warning
  is accepted only alongside successful signature verification and the pinned
  certificate; unsigned payloads, expiry and disabled algorithms still fail.
  `test_artifact.py` runs through the root Node tooling test gate.
- `play.mjs` owns service-account OAuth and the Publisher edits API. It never
  creates tracks, modifies testers/countries or submits production releases.

Run `npm run test:tooling`. The focused suite is
`node --test scripts/lib/release01.test.mjs scripts/lib/staging-auto01.test.mjs`; it uses fictional files/mock HTTP,
never a real Play account. See the [operator runbook](../../docs/development/release01-staging-play.md).
