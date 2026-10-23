import { ReleaseError } from "./errors.mjs";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, unlinkSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import postgres from "postgres";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";
import { readMigrations, migrationDiff, STAGING_REF } from "./migrations.mjs";
import { historyQuery, summarizeHistory } from "./backend.mjs";
import {
  catalogQuery,
  assertRoutineCatalog,
  classifyMigration,
  inventoryDigest,
} from "./safety.mjs";
import {
  POLICY_VERSION,
  TRUSTED_PRODUCT_BASE,
  TRUSTED_CALENDAR_BASE,
  effectCatalogQuery,
  catalogEffects,
  migrationCandidate,
  assertBoundedCatalog,
  policyModuleHash,
  UnsafeCatalogError,
  predecessorCatalog,
} from "./eligibility.mjs";
import {
  mockBasemapContract,
  realActorServiceDenials,
  seedStorageWitness,
  mapPolicyNegativeControls,
  writerLockContract,
} from "./contracts.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import {
  migrationStartupOptions,
  migrationStartupProbe,
} from "./transport.mjs";
import { applyParticipationRpcNullability } from "../lib/participation-rpc-nullability.mjs";

// This destructive rehearsal is confined to a fresh, credential-free Actions
// runner. It never accepts a remote connection URL, target flag or project ref.
if (
  process.env.GITHUB_ACTIONS !== "true" ||
  process.env.PLANETS_DISPOSABLE_QA !== "1" ||
  resolve(process.env.GITHUB_WORKSPACE ?? "missing") !== process.cwd() ||
  process.platform !== "linux"
) {
  throw new ReleaseError(
    "RELEASE01 rehearsal requires its isolated disposable Linux Actions workspace",
  );
}
mkdirSync("build/release01", { recursive: true });
const cli = resolve("node_modules/.bin/supabase");
// Direct immutable fixture scripts do not receive npm's implicit executable PATH.
process.env.PATH = `${resolve("node_modules/.bin")}:${process.env.PATH ?? ""}`;
function command(program, args) {
  console.log(
    `Disposable step: ${program} ${args.map((a) => (/^postgres(?:ql)?:\/\//.test(a) ? "[disposable-db]" : a)).join(" ")}`,
  );
  const result = spawnSync(program, args, {
    encoding: "utf8",
    timeout: 900000,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    // Only disposable synthetic services are reachable here. Still redact keys
    // and connection credentials before retaining bounded diagnostic context.
    const diagnostic = `${result.stdout ?? ""}\n${result.stderr ?? ""}`
      .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[jwt]")
      .replace(/sb_(?:secret|publishable)_[A-Za-z0-9_-]+/g, "[key]")
      .replace(/postgres(?:ql)?:\/\/[^\s]+/g, "[database-url]")
      .split("\n")
      .slice(-30)
      .join("\n");
    console.error(diagnostic);
    throw new ReleaseError(
      `Disposable rehearsal ${program} ${args[0]} failed (exit ${result.status ?? "spawn"}; no hosted target used)`,
    );
  }
  return result.stdout;
}
const existing = spawnSync(cli, ["status", "--output", "json"], {
  encoding: "utf8",
});
if (existing.status === 0)
  throw new ReleaseError("Rehearsal refuses to reuse an existing stack");
let baseline = JSON.parse(
  readFileSync(
    "docs/development/evidence/release01/staging-auto01-predecessor.json",
    "utf8",
  ),
);
const local = readMigrations(process.cwd());
const trusted = resolve("build/release01/trusted-product");
mkdirSync(trusted, { recursive: true });
command("git", [
  "archive",
  "--format=tar",
  "--output=build/release01/trusted-product.tar",
  TRUSTED_PRODUCT_BASE,
]);
command("tar", ["-xf", "build/release01/trusted-product.tar", "-C", trusted]);
const trustedCalendar = resolve("build/release01/trusted-calendar");
mkdirSync(trustedCalendar, { recursive: true });
command("git", [
  "archive",
  "--format=tar",
  "--output=build/release01/trusted-calendar.tar",
  TRUSTED_CALENDAR_BASE,
]);
command("tar", [
  "-xf",
  "build/release01/trusted-calendar.tar",
  "-C",
  trustedCalendar,
]);
if (process.env.RELEASE_OBSERVED_HISTORY_FILE) {
  const observed = JSON.parse(
    readFileSync(process.env.RELEASE_OBSERVED_HISTORY_FILE, "utf8"),
  );
  assert.equal(observed.project_ref, STAGING_REF);
  assert.equal(observed.source_sha, process.env.GITHUB_SHA);
  assert.equal(observed.workflow_run_id, process.env.GITHUB_RUN_ID);
  for (const key of [
    "client_tls_verified",
    "session_verified",
    "history_matches",
    "native_deployment_disabled",
  ])
    assert.equal(observed[key], true);
  assert.equal(
    migrationDiff(local, observed.history, STAGING_REF).drift.length,
    0,
  );
  baseline = {
    applied_history: observed.history.map((r) => ({
      version: r.version,
      canonical_sha256: local.find((m) => m.version === r.version).sha256,
    })),
  };
}
for (const previous of baseline.applied_history) {
  assert.equal(
    local.find((m) => m.version === previous.version)?.sha256,
    previous.canonical_sha256,
    "Predecessor source drift",
  );
}
const applied = new Set(baseline.applied_history.map((m) => m.version));
const pending = local.filter((m) => !applied.has(m.version));
const witnesses = [];
const path = (m) => `supabase/migrations/${m.file}`;
const restore = () => {
  for (const m of pending) writeFileSync(path(m), m.sql);
};
let sql;
let started = false;
async function snapshot(tables) {
  const output = [];
  for (const table of tables) {
    const quoted = (value) => '"' + value.replaceAll('"', '""') + '"';
    const projection = table.columns.map(quoted).join(",");
    const name = `${quoted(table.schema)}.${quoted(table.name)}`;
    const [row] = await sql.unsafe(
      `select count(*)::int as count,md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' order by row_to_json(t)::text),'')) as digest from (select ${projection} from ${name}) t`,
    );
    output.push({ table: `${table.schema}.${table.name}`, ...row });
  }
  return output;
}
try {
  for (const m of pending) unlinkSync(path(m));
  started = true;
  command(cli, ["start"]);
  const status = parseLocalSupabaseStatus(
    command(cli, ["status", "--output", "json"]),
  );
  const url = new URL(status.databaseUrl);
  if (!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname))
    throw new ReleaseError("Rehearsal database must be loopback");
  sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
  // Normal staging's already documented non-canonical RLS callback is part of
  // its actual predecessor. Reproduce the immutable pre-change bytes only on
  // this owned loopback stack; never suppress its live catalog fingerprint.
  const hostedRuntime = readFileSync(
    resolve(
      trusted,
      "docs/development/evidence/staging01/hosted-rls-event-trigger.sql",
    ),
    "utf8",
  );
  await sql.unsafe(hostedRuntime);
  const callbackRollback = new Error("rollback-only hosted RLS probe");
  try {
    await sql.begin(async (tx) => {
      await tx.unsafe("create table public.auto03_rls_probe(id uuid)");
      assert.equal(
        (
          await tx`select relrowsecurity from pg_class where oid='public.auto03_rls_probe'::regclass`
        )[0].relrowsecurity,
        true,
        "The actual hosted callback must enable RLS on a new public table",
      );
      throw callbackRollback;
    });
  } catch (error) {
    if (error !== callbackRollback) throw error;
  }
  const predecessor = summarizeHistory(await sql.unsafe(historyQuery));
  assert.deepEqual(
    predecessor.map((r) => r.version),
    baseline.applied_history.map((r) => r.version),
  );
  // Existing fictional OTP/Profile/Proposal producers exercise genuine Auth/RLS
  // and retain populated predecessor rows. No new seed or privileged admission.
  command("node", [
    resolve(trusted, "scripts/verify-local-profile-visibility.mjs"),
  ]);
  command("node", [resolve(trusted, "scripts/verify-local-proposals.mjs")]);
  command("node", [
    resolve(trusted, "scripts/verify-local-project-organization.mjs"),
  ]);
  const verifyStorage = await seedStorageWitness(status, sql);
  const tables =
    await sql`select n.nspname as schema,c.relname as name,array_agg(a.attname order by a.attnum) as columns
    from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
    where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped
    group by n.nspname,c.relname order by n.nspname,c.relname`;
  const before = await snapshot(tables);
  const predecessorCatalogProof = predecessorCatalog(
    (await sql.unsafe(effectCatalogQuery))[0].catalog,
  );
  const boundedLocal = new URL(status.databaseUrl);
  boundedLocal.searchParams.set("sslmode", "disable"); // owned loopback fixture only
  boundedLocal.searchParams.set("options", migrationStartupOptions);
  command(cli, [
    "db",
    "query",
    "--db-url",
    boundedLocal.toString(),
    migrationStartupProbe,
  ]);
  const wrongBounds = new URL(boundedLocal);
  wrongBounds.searchParams.set(
    "options",
    migrationStartupOptions.replace("lock_timeout=5000", "lock_timeout=7000"),
  );
  const rejectedBounds = spawnSync(
    cli,
    ["db", "query", "--db-url", wrongBounds.toString(), migrationStartupProbe],
    {
      encoding: "utf8",
      timeout: 60000,
      maxBuffer: 65536,
    },
  );
  assert.equal(rejectedBounds.error, undefined);
  assert.notEqual(
    rejectedBounds.status,
    0,
    "The real CLI must reject a mismatched startup bound",
  );
  const previousInventory = local.filter((m) => applied.has(m.version));
  for (const migration of pending) {
    const currentTables =
      await sql`select n.nspname as schema,c.relname as name,array_agg(a.attname order by a.attnum) as columns from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped group by n.nspname,c.relname order by n.nspname,c.relname`;
    const original = await snapshot(currentTables);
    const priorCatalog = (await sql.unsafe(catalogQuery))[0].catalog;
    const beforeEffects = (await sql.unsafe(effectCatalogQuery))[0].catalog;
    writeFileSync(path(migration), migration.sql);
    command(cli, [
      "migration",
      "up",
      "--db-url",
      boundedLocal.toString(),
      "--include-all",
    ]);
    assert.deepEqual(
      await snapshot(currentTables),
      original,
      "Per-file predecessor rows/columns changed",
    );
    const witness = {
      version: migration.version,
      sha256: migration.sha256,
      predecessor_inventory_sha256: inventoryDigest(previousInventory),
      preserved_rows: true,
      routine_security_preserved: false,
      catalog_verified: false,
      independent_contracts: false,
      status: "review-required-for-hosted",
    };
    const classification = migrationCandidate(migration);
    const afterEffects = (await sql.unsafe(effectCatalogQuery))[0].catalog;
    witness.candidate = classification.classification;
    witness.reason = classification.reason;
    witness.catalog_effects = catalogEffects(beforeEffects, afterEffects);
    witness.effect_sha256 = sha256(JSON.stringify(witness.catalog_effects));
    try {
      if (classification.classification === "routine-candidate") {
        assertRoutineCatalog(
          priorCatalog,
          (await sql.unsafe(catalogQuery))[0].catalog,
          classification.effects,
        );
        witness.routine_security_preserved = true;
      } else {
        if (
          ![
            "private-additive-candidate",
            "mock-basemap-contract-candidate",
            "established-contract-candidate",
          ].includes(classification.classification)
        )
          throw new ReleaseError(classification.reason);
        assertBoundedCatalog(beforeEffects, afterEffects, classification);
      }
      witness.catalog_verified = true;
      witness.status = "auto-eligible-for-staging";
    } catch (error) {
      if (
        !(error instanceof ReleaseError) ||
        error instanceof UnsafeCatalogError
      )
        throw error;
      witness.reason = error.message;
    }
    witnesses.push(witness);
    previousInventory.push(migration);
  }
  assert.deepEqual(
    await snapshot(tables),
    before,
    "Populated predecessor rows/columns changed",
  );
  const first = summarizeHistory(await sql.unsafe(historyQuery));
  const diff = migrationDiff(local, first, STAGING_REF);
  assert.equal(diff.pending.length, 0);
  assert.deepEqual(diff.drift, []);
  command(cli, [
    "migration",
    "up",
    "--db-url",
    boundedLocal.toString(),
    "--include-all",
  ]);
  assert.deepEqual(
    summarizeHistory(await sql.unsafe(historyQuery)),
    first,
    "No-op retry changed history",
  );
  assert.deepEqual(
    await snapshot(tables),
    before,
    "No-op retry changed predecessor data",
  );
  command("node", [
    resolve(trusted, "scripts/verify-local-resource-listings.mjs"),
  ]);
  // Exercise the positive semantic proof against real pg_catalog even if the
  // candidate PR adds no SQL. The fixture and its column are rolled back.
  const rollback = new Error("rollback-only routine semantic fixture");
  try {
    await sql.begin(async (tx) => {
      await tx.unsafe(
        "create table private.staging_auto01_probe(id uuid); alter table private.staging_auto01_probe enable row level security; revoke all on private.staging_auto01_probe from public,anon,authenticated,service_role;",
      );
      const original = (await tx.unsafe(catalogQuery))[0].catalog;
      const sample =
        "set lock_timeout='5s'; set statement_timeout='60s'; alter table private.staging_auto01_probe add column note text null; reset lock_timeout; reset statement_timeout;";
      await tx.unsafe(sample);
      assertRoutineCatalog(
        original,
        (await tx.unsafe(catalogQuery))[0].catalog,
        classifyMigration(sample).effects,
      );
      // Prove the real catalog query observes consequential changes, not only
      // a hand-written unit-test catalog. All mutations roll back below.
      for (const [change, undo] of [
        [
          "alter table private.staging_auto01_probe disable row level security",
          "alter table private.staging_auto01_probe enable row level security",
        ],
        [
          "grant select on private.staging_auto01_probe to anon",
          "revoke select on private.staging_auto01_probe from anon",
        ],
        [
          "create function private.staging_auto01_probe_fn() returns integer language sql as 'select 1'",
          "drop function private.staging_auto01_probe_fn()",
        ],
        [
          "create index staging_auto01_probe_idx on private.staging_auto01_probe(id)",
          "drop index private.staging_auto01_probe_idx",
        ],
      ]) {
        await tx.unsafe(change);
        const altered = (await tx.unsafe(catalogQuery))[0].catalog;
        assert.throws(
          () =>
            assertRoutineCatalog(
              original,
              altered,
              classifyMigration(sample).effects,
            ),
          ReleaseError,
        );
        await tx.unsafe(undo);
        assertRoutineCatalog(
          original,
          (await tx.unsafe(catalogQuery))[0].catalog,
          classifyMigration(sample).effects,
        );
      }
      throw rollback;
    });
  } catch (error) {
    if (error !== rollback) throw error;
  }
  await verifyStorage();
  // Baseline pgTAP fixtures require an otherwise clean application dataset
  // (fixed Auth emails, singleton searches and template counts). First finish
  // every populated upgrade/Storage proof above. Reset only this owned loopback
  // stack, then prove its entire effective catalog equals the upgraded catalog
  // before running unchanged trusted fixtures. No assertion/test is skipped.
  const upgradedCatalog = (await sql.unsafe(effectCatalogQuery))[0].catalog;
  await sql.end({ timeout: 5 });
  sql = null;
  command(cli, ["db", "reset", "--local", "--yes"]);
  sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
  await sql.unsafe(hostedRuntime);
  assert.deepEqual(
    catalogEffects(
      upgradedCatalog,
      (await sql.unsafe(effectCatalogQuery))[0].catalog,
    ),
    [],
    "Clean security fixture catalog differs from actual populated upgrade",
  );
  command(cli, ["test", "db", resolve(trusted, "supabase/tests")]);
  command(cli, [
    "test",
    "db",
    resolve(trustedCalendar, "supabase/tests/162_cocreate_calendar.test.sql"),
  ]);
  command("node", [
    resolve(
      trustedCalendar,
      "scripts/verify-local-cocreate-calendar-upgrade.mjs",
    ),
  ]);
  command("node", [
    resolve(trustedCalendar, "scripts/verify-local-cocreate-calendar.mjs"),
  ]);
  // Exercise a real wrong-actor body at the same signature/OID. A copied source
  // hash is insufficient if this independent Auth/privacy contract cannot fail.
  const calendarDefinition = (
    await sql`select pg_get_functiondef('public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text)'::regprocedure) definition`
  )[0].definition;
  const wrongActorCalendar = calendarDefinition.replace(
    "private.require_cocreate_actor(p_expected_profile_id)",
    "auth.uid()",
  );
  assert.notEqual(wrongActorCalendar, calendarDefinition);
  try {
    await sql.unsafe(wrongActorCalendar);
    const rejected = spawnSync(
      "node",
      [resolve(trustedCalendar, "scripts/verify-local-cocreate-calendar.mjs")],
      { encoding: "utf8", timeout: 120000, maxBuffer: 1024 * 1024 },
    );
    assert.ok(
      rejected.status !== 0 &&
        /get_cocreate_calendar_v1 must deny/.test(rejected.stderr ?? ""),
      "Calendar wrong-actor mutation must fail the independent genuine Auth contract",
    );
  } finally {
    await sql.unsafe(calendarDefinition);
  }
  const effective = (await sql.unsafe(effectCatalogQuery))[0].catalog;
  const addedFunctions = effective.functions.filter((f) =>
    witnesses.some((w) =>
      w.catalog_effects.some(
        (c) => c.section === "functions" && c.id === f.id && !c.before,
      ),
    ),
  );
  await sql.unsafe("notify pgrst, 'reload schema'");
  await new Promise((resolve) => setTimeout(resolve, 1000));
  const denials = await realActorServiceDenials(status, addedFunctions);
  const mapInstalled = (
    await sql`select to_regclass('private.mock_basemap_config') name`
  )[0].name;
  const proposedMapSql = mapInstalled
    ? null
    : command("git", [
        "show",
        "b20c20758f6addfa1a15b670b6155e09cac614f6:supabase/migrations/20261023054839_mapmock01_shared_public_basemap.sql",
      ]);
  await mapPolicyNegativeControls(status, proposedMapSql);
  await writerLockContract(status.databaseUrl);
  for (const w of witnesses) {
    if (w.candidate === "mock-basemap-contract-candidate")
      await mockBasemapContract(status.databaseUrl);
    w.independent_contracts = true;
    if (w.catalog_verified)
      w.reason =
        "Populated rows, observed catalog, trusted security tests and real actor API denials verified";
  }
  const generated =
    applyParticipationRpcNullability(
      command(cli, [
        "gen",
        "types",
        "typescript",
        "--local",
        "--schema",
        "public",
      ]).trimEnd(),
    ) + "\n";
  assert.equal(
    readFileSync("apps/web/src/types/database.generated.ts", "utf8").replaceAll(
      "\r\n",
      "\n",
    ),
    generated,
    "Generated public API types differ from canonical database",
  );
  const evidence = {
    policy_version: POLICY_VERSION,
    project_ref: STAGING_REF,
    source_sha: process.env.GITHUB_SHA,
    pr_head_sha: process.env.GITHUB_EVENT_PATH
      ? (JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"))
          .pull_request?.head.sha ?? null)
      : null,
    source_tree: command("git", ["rev-parse", "HEAD^{tree}"]).trim(),
    policy_module_sha256: policyModuleHash(),
    trusted_product_base: TRUSTED_PRODUCT_BASE,
    trusted_calendar_base: TRUSTED_CALENDAR_BASE,
    workflow_run_id: process.env.GITHUB_RUN_ID,
    inventory_sha256: inventoryDigest(local),
    predecessor_catalog: predecessorCatalogProof,
    predecessor_catalog_sha256: sha256(JSON.stringify(predecessorCatalogProof)),
    migration_safety: witnesses,
    routine_catalog_probe: true,
    routine_catalog_negative_probes: true,
    predecessor_migrations: predecessor.length,
    applied_migrations: first.length,
    pending: pending.map(({ sql, ...m }) => m),
    preserved_tables: before,
    no_op_retry: true,
    resource_auth_rest: true,
    generated_types: true,
    trusted_security_tests: true,
    trusted_security_fixture_mode:
      "clean-fixtures-with-equivalent-upgraded-catalog",
    real_actor_denials: denials.verified,
    denial_probes: denials,
    storage_objects_preserved: true,
    policy_negative_probes: true,
    single_writer_probe: true,
    cli_startup_bounds: true,
    hosted_runtime_callback: true,
    calendar_security_contracts: true,
  };
  writeFileSync(
    "build/release01/rehearsal.json",
    JSON.stringify(evidence, null, 2),
  );
  writeFileSync(
    "build/release01/staging-eligibility.json",
    JSON.stringify(evidence, null, 2) + "\n",
  );
  console.log(
    `Populated rehearsal passed: ${predecessor.length} → ${first.length}; ${before.length} tables preserved; second invocation no-op; real Resource Auth/REST and generated types passed.`,
  );
} finally {
  restore();
  if (sql) await sql.end({ timeout: 5 });
  if (started) command(cli, ["stop", "--no-backup"]);
}
