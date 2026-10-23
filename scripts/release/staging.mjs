import { writeStaging } from "./writer.mjs";
import { releaseVariant } from "./config.mjs";
import { ReleaseError, reportFailure } from "./errors.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import postgres from "postgres";
import { stagingTlsOptions } from "./transport.mjs";
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

const sessionQuery = `select current_database() as database_name,
  current_user as database_role, pg_backend_pid() as backend_pid`;

export async function inspectSessionConnection(
  env,
  remote,
  connect = postgres,
) {
  // Successful queries on this connection prove client-to-endpoint TLS with
  // certificate/hostname validation. pg_stat_ssl through a pooler describes the
  // separate pooler-to-Postgres leg, so it cannot prove this client's TLS.
  const sql = connect(assertDatabaseUrl(env.STAGING_DB_URL), {
    ssl: stagingTlsOptions(),
    max: 1,
    connect_timeout: 20,
    onnotice: () => {},
  });
  try {
    const [before] = await sql.unsafe(sessionQuery);
    const direct = summarizeHistory(await sql.unsafe(historyQuery));
    const [after] = await sql.unsafe(sessionQuery);
    if (
      before?.database_name !== "postgres" ||
      before.database_role !== "postgres" ||
      !Number.isSafeInteger(before.backend_pid) ||
      JSON.stringify(before) !== JSON.stringify(after) ||
      JSON.stringify(direct) !== JSON.stringify(remote)
    )
      throw new ReleaseError(
        "Staging session or independent migration history verification failed",
      );
    return {
      client_tls_verified: true,
      session_verified: true,
      history_matches: true,
      port: 5432,
    };
  } finally {
    await sql.end({ timeout: 5 });
  }
}

// Only fixed labels enter public artifacts; native diagnostics can contain URLs.
export function connectionFailure(error) {
  if (error instanceof ReleaseError) return error.message;
  if (["28P01", "28000"].includes(error?.code))
    return "Staging database authentication failed";
  if (
    [
      "CERT_HAS_EXPIRED",
      "UNABLE_TO_VERIFY_LEAF_SIGNATURE",
      "SELF_SIGNED_CERT_IN_CHAIN",
      "DEPTH_ZERO_SELF_SIGNED_CERT",
      "ERR_TLS_CERT_ALTNAME_INVALID",
    ].includes(error?.code)
  )
    return "Staging database TLS certificate validation failed";
  if (
    [
      "ENOTFOUND",
      "ECONNREFUSED",
      "ETIMEDOUT",
      "CONNECT_TIMEOUT",
      "EHOSTUNREACH",
      "ENETUNREACH",
    ].includes(error?.code)
  )
    return "Staging database network connection failed";
  return "Staging database connection failed; native diagnostics withheld";
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
  if (mode === "inspect") {
    try {
      save("connection", {
        source_sha: env.GITHUB_SHA ?? null,
        status: "verified",
        ...(await inspectSessionConnection(env, remote)),
      });
      save("observed-history", {
        project_ref: STAGING_REF,
        source_sha: env.GITHUB_SHA,
        workflow_run_id: env.GITHUB_RUN_ID,
        client_tls_verified: true,
        session_verified: true,
        history_matches: true,
        history: remote,
      });
    } catch (error) {
      const failure = connectionFailure(error);
      save("connection", {
        source_sha: env.GITHUB_SHA ?? null,
        status: "failed",
        failure,
      });
      throw new ReleaseError(failure);
    }
  }
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
