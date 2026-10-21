# Staging and closed-test release tooling

This module owns release orchestration, separate from application/domain rules.
Nothing enables deployment merely by merging these files.

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
- `staging.mjs inspect|deploy|verify` performs identified preflight, approved CLI
  apply and verification. Apply is supported only in the protected Linux runner.
  It never repairs history, includes seeds/roles/Vault secrets or deploys Edge
  Functions. `--include-all` is restricted to an exactly approved bootstrap delta.
- `inventory.mjs REMOTE_STATEMENTS_JSON OUTPUT_JSON` produces an offline review
  manifest from a metadata-only migration export. It never connects to a backend.
- `rehearse.mjs` reconstructs the observed non-contiguous staging predecessor on
  a fresh disposable Actions runner, populates fictional Auth/Profile/Proposal
  records, checks every original column/row digest, applies all candidate files,
  checks no-op retry, real Resource Auth/REST and generated types. It refuses
  local/shared/remote targets. Its result is evidence, never rollout approval.
- `validation.mjs` reuses or dispatches the complete existing `Validation` suite
  on the exact main SHA. All four areas must succeed; skipped checks do not count.
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
  and 64-bit ELF alignment using checksum-pinned bundletool and the installed JDK.
  The original upload certificate is self-signed: its known JDK trust-chain warning
  is accepted only alongside successful signature verification and the pinned
  certificate; unsigned payloads, expiry and disabled algorithms still fail.
  `test_artifact.py` runs through the root Node tooling test gate.
- `play.mjs` owns service-account OAuth and the Publisher edits API. It never
  creates tracks, modifies testers/countries or submits production releases.

Run `npm run test:tooling`. The focused suite is
`node --test scripts/lib/release01.test.mjs`; it uses fictional files/mock HTTP,
never a real Play account. See the [operator runbook](../../docs/development/release01-staging-play.md).
