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
import { STAGING_REF, migrationDiff, deploymentSet } from "./migrations.mjs";
import {
  historyQuery,
  summarizeHistory,
  verificationQuery,
} from "./backend.mjs";
import {
  inventoryDigest,
  authorizePending,
  classifyMigration,
  catalogQuery,
  assertRoutineCatalog,
  assertRoutineTargets,
} from "./safety.mjs";
import { githubClient, deploymentReviews } from "./reviews.mjs";
import { assertStagingRecoveryMode, stagingRecovery } from "./recovery.mjs";

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
  save,
  urlValidator,
}) {
  if (!diff.pending.length) return { remote, diff }; // verified backend no-op follows in staging.mjs
  if (policy.staging_safety_version !== 1)
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
  const reconciliation = JSON.parse(
    readFileSync("scripts/release/reconciliation.json", "utf8"),
  );
  const proofApi = githubClient(env);
  const risky = diff.pending
    .map((p) => local.find((m) => m.version === p.version))
    .filter(
      (m) =>
        classifyMigration(m.sql).classification !== "routine-candidate" ||
        rehearsal.migration_safety?.find((w) => w.version === m.version)
          ?.routine_security_preserved !== true,
    );
  const paths = risky.map((m) => ({
    path: `supabase/migrations/${m.file}`,
    migrations: [m],
  }));
  if (reconciliation.enabled)
    paths.push({
      path: "scripts/release/reconciliation.json",
      // The one-time enabling PR can review other observed pending files too;
      // only the exact two-file pair receives historical reconciliation rights.
      migrations: diff.pending
        .map((m) => local.find((l) => l.version === m.version))
        .filter(Boolean),
    });
  const reviews = await deploymentReviews(local, paths, proofApi);
  // Authorize the WHOLE mixed set before any CLI transaction. No safe prefix
  // is intentionally applied while a dependent risky file is still unreviewed.
  const decisions = authorizePending(
    diff,
    local,
    rehearsal,
    env.GITHUB_SHA,
    reviews,
    reconciliation,
  );
  const historical = diff.pending.some((m) => m.historical);
  const pending = deploymentSet(
    diff,
    policy,
    env.BOOTSTRAP_MANIFEST_SHA256,
    historical ? reconciliation : null,
  );
  const sql = postgres(urlValidator(env.STAGING_DB_URL), {
    ssl: { rejectUnauthorized: true },
    max: 1,
    onnotice: () => {},
  });
  let temp;
  try {
    const [lock] = await sql`select pg_try_advisory_lock(72701,1) as acquired`;
    assertWriterSnapshot(lock.acquired, remote, remote, remote);
    const direct = summarizeHistory(await sql.unsafe(historyQuery));
    const fresh = summarizeHistory(await api.query(historyQuery));
    assertWriterSnapshot(lock.acquired, direct, fresh, remote);
    currentMain(env);
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
    save("safety", { source_sha: env.GITHUB_SHA, recovery, decisions });
    const initialCatalog = (await sql.unsafe(catalogQuery))[0].catalog;
    for (const decision of decisions.filter(
      (d) => d.authorization === "routine-verified",
    ))
      assertRoutineTargets(
        initialCatalog,
        classifyMigration(local.find((m) => m.version === decision.version).sql)
          .effects,
      );
    temp = mkdtempSync(join(tmpdir(), "planets-staging-auto01-"));
    mkdirSync(join(temp, "supabase", "migrations"), { recursive: true });
    writeFileSync(
      join(temp, "supabase", "config.toml"),
      'project_id = "planets-release01"\n',
    );
    const applied = new Set(remote.map((m) => m.version));
    for (const planned of pending) {
      const migration = local.find((m) => m.version === planned.version);
      const beforeCatalog = (await sql.unsafe(catalogQuery))[0].catalog;
      const classification = classifyMigration(migration.sql);
      for (const m of local.filter(
        (m) => applied.has(m.version) || m.version === migration.version,
      ))
        writeFileSync(join(temp, "supabase", "migrations", m.file), m.sql);
      // Each invocation contains exactly one pending canonical file. Include-all
      // can only select the historically reviewed avatar from the bounded pair.
      const args = [
        "db",
        "push",
        "--db-url",
        urlValidator(env.STAGING_DB_URL),
        "--workdir",
        temp,
        "--skip-vault",
        "--yes",
        ...(planned.historical ? ["--include-all"] : []),
      ];
      for (const dry of [true, false]) {
        currentMain(env);
        const result = spawnSync(
          resolve("node_modules/.bin/supabase"),
          [...args, ...(dry ? ["--dry-run"] : [])],
          { encoding: "utf8", timeout: 600000, maxBuffer: 8 * 1024 * 1024 },
        );
        if (result.error || result.status !== 0)
          throw new ReleaseError(
            `Staging CLI ${dry ? "dry run" : "apply"} failed; output withheld to protect credentials`,
          );
      }
      applied.add(migration.version);
      if (
        decisions.find((d) => d.version === migration.version).authorization ===
        "routine-verified"
      )
        assertRoutineCatalog(
          beforeCatalog,
          (await sql.unsafe(catalogQuery))[0].catalog,
          classification.effects,
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
    }
    diff = migrationDiff(local, remote, STAGING_REF);
    return { remote, diff };
  } finally {
    await sql.end({ timeout: 5 });
    if (temp) rmSync(temp, { recursive: true, force: true });
  }
}
