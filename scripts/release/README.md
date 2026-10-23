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
  apply and verification. Inspect checks the actual secret using certificate-
  validated client TLS on port 5432, stable session and independent history.
  It retains sanitized connection results/failures without raw diagnostics.
  Apply is supported only in the protected Linux runner.
  It never repairs history, includes seeds/roles/Vault secrets or deploys Edge
  Functions. `--include-all` is restricted to one exactly approved historical file at a time.
- `transport.mjs` pins the public `supabase-prod-ca-2021.crt` bytes and supplies
  strict client TLS options. The CLI uses that same file via `PGSSLROOTCERT` with
  `sslmode=verify-full`. A certificate rotation requires reviewing/replacing the
  public CA and its hash; no private keys or credentials live in either file.
- `safety.mjs` retains the original nullable-column grammar, inventory digests
  and legacy catalog guards. A parsed candidate still requires actual proof.
- `eligibility.mjs` owns standing policy V2: bounded additive classification,
  policy/SQL PR separation, independent catalog effects and whole-set receipts.
  Unknown privileged bodies remain held until an independent contract is installed.
  The exact ACTSRC02 single-enabled-source index retirement has a source-only
  catalog contract; it cannot authorize hosted application, even with a promoted
  witness. Generic destructive-DDL rejection remains in place.
- `contracts.mjs` exercises real Auth/Storage preservation, service-only denials,
  MAPMOCK ledger/quota/concurrency behavior, unsafe mutation controls and two
  real writer sessions on explicitly disposable loopback services.
  Its rollback-only ACTSRC02 controls exercise the real index definition, retained
  identities/leases and unsafe mutations without changing canonical history.
- `reviews.mjs` enforces source safety without owner fingerprints. Validation
  loads it from the trusted pre-change base. Its old comment readers remain
  available for auditing legacy releases, never for current authorization.
- `recovery.mjs` requires explicit protected `STAGING_RECOVERY_MODE` for only
  normal staging. `development-no-backup` accepts possible development-data loss,
  skips backup access and records an honest `waived` result. SQL review and all
  other guards remain independent. Missing/unknown mode blocks writes. Switch to
  `verified-backup` before staging holds irreplaceable data: it retains the fresh
  metadata-only receipt verifier from a source-hash-pinned main recovery workflow,
  encrypted/access-controlled DB **and Storage objects** restored against the
  exact predecessor. It never downloads a real backup.
- `writer.mjs` checks protected readiness, exact tested/rehearsed/current main,
  the complete qualified set, independent history, advisory lock and recovery.
  Per-file bounded CLI apply must match observed catalog and preserve original
  rows. A second real CLI invocation proves no-op retry.
- `writer-state.mjs` reads prior protected writer receipts and withholds writes
  after interrupted/partial/unverified outcomes until exact reconciliation.
- `preservation.mjs` keeps PostgreSQL row values private, returning original
  column identities, counts and digests for before/after comparison.
- `reconciliation.json` and the original bootstrap allowlist are historical
  audit data. V2 uses the independently qualified entire live dependency chain.
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
`node --test scripts/lib/release01.test.mjs scripts/lib/staging-auto01.test.mjs scripts/lib/staging-auto03.test.mjs scripts/lib/actsrc02-policy.test.mjs`; it uses fictional files/mock HTTP,
never a real Play account. See the [operator runbook](../../docs/development/release01-staging-play.md).
