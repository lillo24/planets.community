import { ReleaseError } from "./errors.mjs";
import {
  readFileSync,
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import postgres from "postgres";
import {
  STAGING_REF,
  migrationDiff,
  verifiedDeploymentSet,
} from "./migrations.mjs";
import {
  historyQuery,
  summarizeHistory,
  verificationQuery,
  assertNativeDeploymentDisabled,
} from "./backend.mjs";
import { inventoryDigest } from "./safety.mjs";
import { githubClient } from "./reviews.mjs";
import { assertStagingRecoveryMode, stagingRecovery } from "./recovery.mjs";
import {
  stagingTlsOptions,
  stagingCaPath,
  migrationStartupOptions,
  migrationStartupProbe,
} from "./transport.mjs";
import {
  authorizeVerifiedPending,
  effectCatalogQuery,
  catalogEffects,
  assertPredecessorCatalog,
} from "./eligibility.mjs";
import { preservationTables, preservationSnapshot } from "./preservation.mjs";
import {
  assertReconciledWriter,
  previousWriterState,
} from "./writer-state.mjs";

export function assertDeployContext(env) {
  if (
    env.GITHUB_ACTIONS !== "true" ||
    env.GITHUB_REPOSITORY !== "lillo24/planets.community" ||
    env.GITHUB_REF !== "refs/heads/main" ||
    !/^[a-f0-9]{40}$/.test(env.GITHUB_SHA ?? "") ||
    env.RELEASE_VALIDATED_SHA !== env.GITHUB_SHA ||
    env.RELEASE_REHEARSED_SHA !== env.GITHUB_SHA ||
    env.STAGING_DEPLOYMENT_OWNER !== "github-actions" ||
    env.STAGING_AUTOMATION_READY !== "true" ||
    !env.GH_TOKEN ||
    !env.SUPABASE_ACCESS_TOKEN ||
    !env.STAGING_CONFIG_JSON
  )
    throw new ReleaseError(
      "Staging writes require exact tested/rehearsed main, protected one-time readiness, credentials and the single GitHub owner",
    );
  assertStagingRecoveryMode(env, STAGING_REF);
}
function currentMain(env) {
  const result = spawnSync("git", ["ls-remote", "origin", "refs/heads/main"], {
    encoding: "utf8",
    timeout: 60000,
  });
  if (result.status !== 0 || result.stdout.split(/\s/)[0] !== env.GITHUB_SHA)
    throw new ReleaseError(
      "Main advanced before staging write; run fresh exact-source validation",
    );
}
export function assertWriterSnapshot(acquired, direct, fresh, observed) {
  if (!acquired)
    throw new ReleaseError("Another staging deployment holds the writer lock");
  if (
    JSON.stringify(direct) !== JSON.stringify(observed) ||
    JSON.stringify(fresh) !== JSON.stringify(observed)
  )
    throw new ReleaseError(
      "Observed staging history changed or direct identity differs",
    );
}
export async function writeStaging({
  root,
  local,
  remote,
  diff,
  policy,
  env,
  api,
  historyApi,
  save,
  urlValidator,
}) {
  // Persist known no-write state before any gate can reject. A proven failure
  // before apply must not become an "unknown partial write" on the next run.
  save?.("deployment", {
    source_sha: env?.GITHUB_SHA ?? null,
    workflow_run_id: env?.GITHUB_RUN_ID ?? null,
    status: "failed-before-write",
    completed: [],
    attempt_started: false,
  });
  if (!diff.pending.length) {
    // Even an all-applied observation must not clear a prior unverified apply.
    // Ordinary local read-only use has no protected workflow history to mutate.
    if (env?.GITHUB_ACTIONS === "true")
      assertReconciledWriter(
        await previousWriterState(historyApi ?? githubClient(env), env),
        diff.predecessor_sha256,
        env,
      );
    if (env?.GITHUB_ACTIONS !== "true") return { remote, diff };
  }
  assertStagingRecoveryMode(env, diff.project_ref);
  if (policy.staging_safety_version !== 2)
    throw new ReleaseError("Missing staging safety policy");
  assertDeployContext(env);
  if (process.platform !== "linux")
    throw new ReleaseError(
      "Hosted apply requires the protected Linux Actions runner",
    );
  currentMain(env);
  let rehearsal;
  try {
    rehearsal = JSON.parse(
      readFileSync("build/release01/rehearsal.json", "utf8"),
    );
  } catch {
    throw new ReleaseError(
      "Download the exact-source populated rehearsal artifact before staging",
    );
  }
  if (rehearsal.workflow_run_id !== env.GITHUB_RUN_ID)
    throw new ReleaseError("Rehearsal belongs to a different workflow run");
  // The whole dependency set is qualified before acquiring a write transaction.
  // Owner comments and the retired bootstrap waiver are never consulted.
  const treeResult = spawnSync("git", ["rev-parse", "HEAD^{tree}"], {
    encoding: "utf8",
  });
  if (treeResult.status !== 0)
    throw new ReleaseError("Cannot verify tested source tree");
  const tree = treeResult.stdout.trim();
  const decisions = authorizeVerifiedPending(
    diff,
    local,
    rehearsal,
    env.GITHUB_SHA,
    tree,
  );
  const pending = verifiedDeploymentSet(diff, policy, decisions);
  const proofApi = historyApi ?? githubClient(env);
  assertReconciledWriter(
    await previousWriterState(proofApi, env),
    diff.predecessor_sha256,
    env,
  );
  const sql = postgres(urlValidator(env.STAGING_DB_URL), {
    ssl: stagingTlsOptions(),
    max: 1,
    onnotice: () => {},
  });
  let temp;
  const progress = {
    source_sha: env.GITHUB_SHA,
    workflow_run_id: env.GITHUB_RUN_ID,
    status: "planned",
    completed: [],
    attempt_started: false,
  };
  try {
    const [lock] = await sql`select pg_try_advisory_lock(72701,1) as acquired`;
    assertWriterSnapshot(lock.acquired, remote, remote, remote);
    const direct = summarizeHistory(await sql.unsafe(historyQuery));
    const fresh = summarizeHistory(await api.query(historyQuery));
    assertWriterSnapshot(lock.acquired, direct, fresh, remote);
    currentMain(env);
    assertNativeDeploymentDisabled(await api.branches());
    assertPredecessorCatalog(
      rehearsal.predecessor_catalog,
      (await sql.unsafe(effectCatalogQuery))[0].catalog,
    );
    if (!pending.length) return { remote, diff }; // backend verification records the observed no-op
    const boundedUrl = new URL(urlValidator(env.STAGING_DB_URL));
    boundedUrl.searchParams.set("options", migrationStartupOptions);
    const probe = spawnSync(
      resolve("node_modules/.bin/supabase"),
      ["db", "query", "--db-url", boundedUrl.toString(), migrationStartupProbe],
      {
        encoding: "utf8",
        timeout: 60000,
        maxBuffer: 65536,
        env: { ...process.env, PGSSLROOTCERT: stagingCaPath },
      },
    );
    if (probe.error || probe.status !== 0)
      throw new ReleaseError(
        "Staging CLI strict TLS/startup bound verification failed before apply; diagnostics withheld",
      );
    const recovery = await stagingRecovery(
      env,
      proofApi,
      inventoryDigest(
        local.filter((m) => !pending.some((p) => p.version === m.version)),
      ),
      diff.project_ref,
    );
    const predecessorChecks = (
      await api.query(verificationQuery(root, policy.budget_basemap))
    )[0];
    if (
      predecessorChecks.unsafe_tables.length ||
      !predecessorChecks.storage_safe ||
      !predecessorChecks.grants_safe
    )
      throw new ReleaseError(
        "Existing staging authorization/Storage drift blocks writes",
      );
    save("safety", {
      source_sha: env.GITHUB_SHA,
      recovery,
      decisions,
      cli_startup_bounds: true,
      predecessor_catalog_verified: true,
    });
    await sql.unsafe("set lock_timeout='5s';set statement_timeout='60s'");
    const initialTables = await preservationTables(sql);
    const initialRows = await preservationSnapshot(sql, initialTables);
    temp = mkdtempSync(join(tmpdir(), "planets-staging-auto01-"));
    mkdirSync(join(temp, "supabase", "migrations"), { recursive: true });
    writeFileSync(
      join(temp, "supabase", "config.toml"),
      'project_id = "planets-release01"\n',
    );
    const applied = new Set(remote.map((m) => m.version));
    let lastArgs;
    for (const planned of pending) {
      const migration = local.find((m) => m.version === planned.version);
      const beforeEffects = (await sql.unsafe(effectCatalogQuery))[0].catalog;
      const currentTables = await preservationTables(sql);
      const beforeRows = await preservationSnapshot(sql, currentTables);
      for (const m of local.filter(
        (m) => applied.has(m.version) || m.version === migration.version,
      ))
        writeFileSync(join(temp, "supabase", "migrations", m.file), m.sql);
      // Each invocation contains exactly one independently qualified pending
      // file. Include-all cannot select another unexecuted historical file.
      const args = [
        "db",
        "push",
        "--db-url",
        boundedUrl.toString(),
        "--workdir",
        temp,
        "--skip-vault",
        "--yes",
        ...(planned.historical ? ["--include-all"] : []),
      ];
      lastArgs = args;
      progress.current_version = migration.version;
      for (const dry of [true, false]) {
        currentMain(env);
        if (!dry) {
          progress.status = "applying";
          progress.attempt_started = true;
          progress.current_version = migration.version;
          save("deployment", progress);
        }
        const result = spawnSync(
          resolve("node_modules/.bin/supabase"),
          [...args, ...(dry ? ["--dry-run"] : [])],
          {
            encoding: "utf8",
            timeout: 600000,
            maxBuffer: 8 * 1024 * 1024,
            // CLI uses the same reviewed CA as the session-lock client.
            env: { ...process.env, PGSSLROOTCERT: stagingCaPath },
          },
        );
        if (result.error || result.status !== 0)
          throw new ReleaseError(
            `Staging ${migration.version} CLI ${dry ? "dry run" : "apply"} failed; output withheld to protect credentials`,
          );
      }
      applied.add(migration.version);
      const actualEffects = catalogEffects(
        beforeEffects,
        (await sql.unsafe(effectCatalogQuery))[0].catalog,
      );
      const expected = rehearsal.migration_safety.find(
        (w) =>
          w.version === migration.version &&
          w.predecessor_inventory_sha256 ===
            decisions.find((d) => d.version === migration.version)
              .predecessor_inventory_sha256,
      );
      if (
        JSON.stringify(actualEffects) !==
          JSON.stringify(expected.catalog_effects) ||
        JSON.stringify(await preservationSnapshot(sql, currentTables)) !==
          JSON.stringify(beforeRows)
      )
        throw new ReleaseError(
          `Migration ${migration.version} changed unverified catalog or existing rows; deployment halted for reconciliation`,
        );
      remote = summarizeHistory(await api.query(historyQuery));
      const observed = migrationDiff(local, remote, STAGING_REF);
      if (
        observed.drift.length ||
        remote.length !== applied.size ||
        remote.some((r) => !applied.has(r.version))
      )
        throw new ReleaseError(
          "Unexpected history after staging apply; stop and reconcile, never repair automatically",
        );
      progress.completed.push(migration.version);
      progress.attempt_started = false;
      progress.status = "verified-prefix";
      save("deployment", progress);
    }
    diff = migrationDiff(local, remote, STAGING_REF);
    if (diff.pending.length || diff.drift.length)
      throw new ReleaseError("Staging has not reached canonical parity");
    // The same bounded CLI invocation must now perform no work. Protect and
    // inspect it like an apply; do not label two metadata reads a no-op retry.
    currentMain(env);
    const noOpCatalog = (await sql.unsafe(effectCatalogQuery))[0].catalog;
    progress.attempt_started = true;
    progress.current_version = "no-op-retry";
    save("deployment", progress);
    const retry = spawnSync(resolve("node_modules/.bin/supabase"), lastArgs, {
      encoding: "utf8",
      timeout: 600000,
      maxBuffer: 8 * 1024 * 1024,
      env: { ...process.env, PGSSLROOTCERT: stagingCaPath },
    });
    if (
      retry.error ||
      retry.status !== 0 ||
      catalogEffects(
        noOpCatalog,
        (await sql.unsafe(effectCatalogQuery))[0].catalog,
      ).length
    )
      throw new ReleaseError(
        "Staging CLI no-op retry failed or changed catalog; reconcile before retry",
      );
    if (
      JSON.stringify(await preservationSnapshot(sql, initialTables)) !==
      JSON.stringify(initialRows)
    )
      throw new ReleaseError(
        "Existing staged rows changed during the deployment; reconcile before retry",
      );
    // Authoritative history and preserved rows prove the CLI retry was a no-op.
    const repeated = summarizeHistory(await sql.unsafe(historyQuery));
    if (JSON.stringify(repeated) !== JSON.stringify(remote))
      throw new ReleaseError("Staging history changed after completion");
    save("deployment", {
      source_sha: env.GITHUB_SHA,
      workflow_run_id: env.GITHUB_RUN_ID,
      status: "verified",
      no_op_retry: true,
      applied: decisions,
      preserved_tables: initialRows,
    });
    return { remote, diff };
  } catch (error) {
    progress.status = progress.attempt_started
      ? "failed-unverified"
      : progress.completed.length
        ? "failed-partial"
        : "failed-before-write";
    save("deployment", progress);
    throw error;
  } finally {
    await sql.end({ timeout: 5 });
    if (temp) rmSync(temp, { recursive: true, force: true });
  }
}
