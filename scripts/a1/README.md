# A1 owned qualification tools

This folder owns the disposable backend and native evidence for
[A1](../../docs/development/private-pair-conversations.md). It is separate from
the audit runner's backend, emulator, artifacts and UIAUDIT02 worktree.

- `local-world.mjs` creates one new OS-temp `planets-a1-*` project from the exact
  predecessor migrations, with independent private signing/API keys and ports
  61320–61329. It refuses occupied ports. Windows uses only the already-running
  `planets-cocreate-qa-root` connection and matching named pipe; Linux accepts the
  local Docker socket. It never changes a global connection or resets an existing
  project. `A1_WORLD_POINTER` optionally records only the created directory path.
- `owned-world.mjs` checks the temp-path/project/loopback-port identity and shares
  safe RPC failures. It never prints credentials or message bodies.
- `verify-local.mjs` applies the A1 SQL to that owned predecessor, or iterates only
  its new functions. `--test` runs a specified transaction-local pgTAP file. This
  iteration mode is not a substitute for canonical forward/fresh replay.
- `prepare-world.mjs` uses real OTP, profile/policy/photo APIs and canonical source
  actions to establish Alice/Marco, reversed requests, Resource coordination,
  member contact and two accepted posts with opposite authors. The second author
  avoids bypassing the real per-actor interest cooldown. It enables the experiment
  only in this owned local world. Partial failure is explicit; use a fresh world
  rather than claiming a completed fixture.
- `verify-upgrade.mjs` rewinds only this migration's unshared local iteration,
  retains every original source record, compares all old rows/columns and installed
  domain bodies/OIDs/ACLs and the exact one-call extension of the existing private
  metadata hook, runs the actual CLI forward migration, then its no-op
  retry. Its metadata-only proof contains counts/hashes, never original values.
  Its removal of A1's disposable history entry is rehearsal-only and must never be
  used against shared/staging/production history.
- `verify-http.mjs` uses genuine OTP sessions and current RPCs, including a real
  observed selected-Resource lock wait and concurrent canonical closure. It
  preserves original message IDs and restores the local experiment OFF in `finally`.
  It intentionally changes the owned fixture's block/request/agreement state, so
  native visual journeys run first on a fresh fixture.
- `check-local.mjs` runs the repository's pinned CLI test/lint/advisors/type commands
  against the owned project. `reset` is an explicitly disposable fresh replay;
  preserve the populated proof first. Generated types retain the normal repository
  nullability postprocessor. Run pgTAP on fresh seeded state, without populated
  A1 public posts or other verifier leftovers.
- `run-native-ci.sh` owns the opt-in Linux hosted-runner journey and cleanup.
  The installed SDK's Pixel 4 base profile uses explicit 1280x2856 pixels at
  480dpi (426.7x952 logical pixels), plus a 320dp/2x variant. This is a reported
  display equivalent, not a claim that the emulator is Pixel 9 Pro hardware.
  `integration_test/a1_private_pairs_test.dart` exercises real OTP in both APKs;
  `capture-server.mjs` owns synchronous loopback checkpoints, original Android
  compositor bytes and real system-setting changes. The SDK's native screenshot
  callbacks run after test completion, so the app uses a bounded 61325 handshake;
  no PNG bytes are retained in Flutter's test-response heap.
  `test_driver/a1_screenshots.dart` retains only safe completion metadata.
  `diagnostics.mjs` exports only a bounded scrubbed failure tail. The workflow
  retains no raw logs, defines, signing material or APKs.
- `report.mjs` validates the seven original captures and writes the phone-sized
  before/after PDF plus source/migration/capture hashes and HTTP/upgrade proof.
- `stop-world.mjs` stops only the exact guarded disposable project.

All commands require `PLANETS_DISPOSABLE_QA=1`. On this Windows workspace also set
process-only `CONTAINER_CONNECTION=planets-cocreate-qa-root` and
`DOCKER_HOST=npipe:////./pipe/podman-planets-cocreate-qa`. Locked dependencies must
already be installed. The normal engine, peer projects and shared Mock are untouched.

```text
node scripts/a1/local-world.mjs
node scripts/a1/verify-local.mjs <owned-temp> --apply
node scripts/a1/prepare-world.mjs <owned-temp>
node scripts/a1/verify-upgrade.mjs <owned-temp>
node scripts/a1/verify-http.mjs <owned-temp>
node scripts/a1/check-local.mjs <owned-temp> reset
node scripts/a1/check-local.mjs <owned-temp> test
node scripts/a1/check-local.mjs <owned-temp> lint
node scripts/a1/check-local.mjs <owned-temp> advisors
node scripts/a1/check-local.mjs <owned-temp> types
```

Keep `private-*` files, defines, Auth mail, CLI logs and APKs outside Git/artifact
exports. Stop only this project's CLI with its exact `--workdir <owned-temp>` and
private environment when finished. Do not stop the shared Podman machine.
