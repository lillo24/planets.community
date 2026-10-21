import { ReleaseError, reportFailure } from "./errors.mjs";
import {
  mkdirSync,
  readFileSync,
  writeFileSync,
  mkdtempSync,
  cpSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import postgres from "postgres";
import {
  STAGING_REF,
  readMigrations,
  migrationDiff,
  deploymentSet,
  assertBackendReady,
} from "./migrations.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import {
  historyQuery,
  summarizeHistory,
  verificationQuery,
  managementClient,
  verifyFunctions,
  publicSmoke,
} from "./backend.mjs";

export function assertDatabaseUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new ReleaseError("Missing/invalid STAGING_DB_URL");
  }
  const direct =
    url.hostname === `db.${STAGING_REF}.supabase.co` &&
    url.username === "postgres";
  const pooler =
    /^aws-[0-9]+-[a-z0-9-]+\.pooler\.supabase\.com$/.test(url.hostname) &&
    url.username === `postgres.${STAGING_REF}`;
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    (!direct && !pooler) ||
    url.pathname !== "/postgres" ||
    !url.password
  )
    throw new ReleaseError("Database URL is not the verified staging target");
}

export async function stagingRelease(mode, env = process.env) {
  if (!["inspect", "deploy", "verify"].includes(mode))
    throw new ReleaseError("Use staging.mjs inspect|deploy|verify");
  const root = process.cwd();
  const policy = JSON.parse(
    readFileSync("scripts/release/policy.json", "utf8"),
  );
  const api = managementClient(env.SUPABASE_ACCESS_TOKEN);
  const identity = await api.identity();
  if (
    (identity.id ?? identity.ref) !== STAGING_REF ||
    identity.name !== "planets-staging" ||
    identity.status !== "ACTIVE_HEALTHY"
  )
    throw new ReleaseError("Staging identity/health mismatch");
  const local = readMigrations(root);
  let remote = summarizeHistory(await api.query(historyQuery));
  let diff = migrationDiff(local, remote, identity.id ?? identity.ref);
  mkdirSync("build/release01", { recursive: true });
  const save = (file, data) =>
    writeFileSync(
      `build/release01/${file}.json`,
      JSON.stringify(data, null, 2) + "\n",
    );
  save("preflight", {
    source_sha: env.GITHUB_SHA ?? null,
    ...diff,
    approval_digest: sha256(JSON.stringify(diff)),
    history: remote,
  });
  if (mode === "deploy") {
    const pending = deploymentSet(diff, policy, env.BOOTSTRAP_MANIFEST_SHA256);
    if (pending.length) {
      if (process.platform !== "linux")
        throw new ReleaseError(
          "Hosted apply is supported only in the protected Linux Actions runner",
        );
      if (
        env.GITHUB_REF !== "refs/heads/main" ||
        env.RELEASE_VALIDATED_SHA !== env.GITHUB_SHA ||
        env.STAGING_DEPLOYMENT_OWNER !== "github-actions"
      )
        throw new ReleaseError(
          "Deployment requires tested main and confirmed single deployment owner",
        );
      assertDatabaseUrl(env.STAGING_DB_URL);
      const sql = postgres(env.STAGING_DB_URL, {
        ssl: { rejectUnauthorized: true },
        max: 1,
        onnotice: () => {},
      });
      let temp;
      try {
        // Hold a session advisory lock even across CLI transactions. Compare the
        // direct connection's history to the independently identified API target.
        await sql`select pg_advisory_lock(72701, 1)`;
        const direct = summarizeHistory(await sql.unsafe(historyQuery));
        if (JSON.stringify(direct) !== JSON.stringify(remote))
          throw new ReleaseError(
            "Staging history changed or direct identity differs",
          );
        temp = mkdtempSync(join(tmpdir(), "planets-release01-"));
        mkdirSync(join(temp, "supabase"));
        cpSync(
          join(root, "supabase/migrations"),
          join(temp, "supabase/migrations"),
          { recursive: true },
        );
        writeFileSync(
          join(temp, "supabase/config.toml"),
          'project_id = "planets-release01"\n',
        );
        const args = [
          "db",
          "push",
          "--db-url",
          env.STAGING_DB_URL,
          "--workdir",
          temp,
          "--skip-vault",
          "--yes",
        ];
        // Include-all is permitted only for the exact approved bootstrap set.
        if (pending.some((m) => m.historical)) args.push("--include-all");
        for (const dry of [true, false]) {
          const result = spawnSync(
            resolve("node_modules/.bin/supabase"),
            [...args, ...(dry ? ["--dry-run"] : [])],
            { encoding: "utf8", timeout: 600000, maxBuffer: 8 * 1024 * 1024 },
          );
          // CLI errors can contain connection strings: never forward its output.
          if (result.error || result.status !== 0)
            throw new ReleaseError(
              `Staging CLI ${dry ? "dry run" : "apply"} failed; release blocked (output withheld to protect credentials)`,
            );
        }
      } finally {
        await sql.end({ timeout: 5 }); // closes session and releases its lock
        if (temp) rmSync(temp, { recursive: true, force: true });
      }
      remote = summarizeHistory(await api.query(historyQuery));
      diff = migrationDiff(local, remote, STAGING_REF);
    }
  }
  const checks = (
    await api.query(verificationQuery(root, policy.budget_basemap))
  )[0];
  const functions = await api.functions();
  const provider = functions.find(
    (f) =>
      f.slug === "map-provider" &&
      f.status === "ACTIVE" &&
      f.verify_jwt === true,
  );
  checks.map_safe =
    checks.map_safe &&
    Boolean(provider) &&
    verifyFunctions(root, policy, functions);
  save("backend", {
    source_sha: env.GITHUB_SHA ?? null,
    verified_at: new Date().toISOString(),
    ...diff,
    checks,
    history: remote,
    map_provider: provider
      ? { version: provider.version, verify_jwt: true }
      : null,
  });
  console.log(
    `Staging: ${diff.applied} applied, ${diff.pending.length} pending, ${diff.drift.length} drift; evidence in build/release01`,
  );
  if (mode !== "inspect") {
    assertBackendReady(diff, checks);
    save("http-smoke", {
      source_sha: env.GITHUB_SHA,
      checks: await publicSmoke(env.STAGING_CONFIG_JSON),
    });
  }
  return { diff, checks };
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  stagingRelease(process.argv[2]).catch((error) =>
    reportFailure("staging", error),
  );
}
