# STAGING01 evidence

This folder holds sanitized Phase 1 inventory and local-rehearsal evidence for
[the recovery preflight](../../staging01-recovery-preflight.md). It contains no
tester content, OTPs, keys or sessions.

- `remote-migration-fingerprints.json`: 83 hosted versions/names and stored-SQL
  hashes; two complete-file hashes explain different statement packaging.
- `pending-migration-sha256.json`: exact 13 canonical file bytes reviewed.
- `history-comparison.json`: canonical replay versus stored hosted history.
- `remote-routine-fingerprints.json`: inspected hosted routine definition hashes
  and grants, including the extra automatic-RLS helper.
- `hosted-rls-event-trigger.sql`: exact inspected helper, reproduced only in the
  disposable rehearsal; never a hosted deployment script or canonical migration.
- `routine-comparison.json`: baseline routine/hash/grant comparison after
  reproducing the extra hosted helper.
- `upgrade-result.json`: created only after preservation and API assertions pass.
- `hosted-deployment.json`: owner backup waiver, executed file hashes, canonical
  history parity, sanitized hosted API/count/grant checks and remaining native QA.
  See [the deployment record](../../staging01-hosted-deployment.md).

The loopback-only `scripts/verify-local-staging01-upgrade.mjs` produces the
comparison/result files. None of these inventories is a recoverable data backup.
