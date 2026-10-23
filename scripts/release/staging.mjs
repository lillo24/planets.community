import { writeStaging } from "./writer.mjs";
import { releaseVariant } from "./config.mjs";
import { ReleaseError, reportFailure } from "./errors.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import {
  STAGING_REF,
  readMigrations,
  migrationDiff,
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
    !url.password ||
    // Port 6543 is the transaction pooler; it cannot hold our session lock.
    (url.port && url.port !== "5432") ||
    url.hash ||
    [...url.searchParams.keys()].some((key) => key !== "sslmode")
  )
    throw new ReleaseError("Database URL is not the verified staging target");
  url.searchParams.set("sslmode", "verify-full");
  return url.toString();
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
    ({ remote, diff } = await writeStaging({
      root,
      local,
      remote,
      diff,
      policy,
      env,
      api,
      save,
      urlValidator: assertDatabaseUrl,
    }));
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
    verifyFunctions(root, policy, functions, releaseVariant(env));
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
