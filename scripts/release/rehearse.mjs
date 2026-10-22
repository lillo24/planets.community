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
import { githubClient, ownerReviewsForPr } from "./reviews.mjs";

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
function command(program, args) {
  const result = spawnSync(program, args, {
    encoding: "utf8",
    timeout: 900000,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0)
    throw new ReleaseError(
      `Disposable rehearsal ${program} step failed (output withheld; no hosted target used)`,
    );
  return result.stdout;
}
const existing = spawnSync(cli, ["status", "--output", "json"], {
  encoding: "utf8",
});
if (existing.status === 0)
  throw new ReleaseError("Rehearsal refuses to reuse an existing stack");
const baseline = JSON.parse(
  readFileSync(
    "docs/development/evidence/release01/staging-auto01-predecessor.json",
    "utf8",
  ),
);
const local = readMigrations(process.cwd());
for (const previous of baseline.applied_history) {
  assert.equal(
    local.find((m) => m.version === previous.version)?.sha256,
    previous.canonical_sha256,
    "Predecessor source drift",
  );
}
const applied = new Set(baseline.applied_history.map((m) => m.version));
const pending = local.filter((m) => !applied.has(m.version));
const event = process.env.GITHUB_EVENT_PATH
  ? JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"))
  : {};
const changed = event.pull_request
  ? new Set(
      command("git", [
        "diff",
        "--no-renames",
        "--name-only",
        event.pull_request.base.sha,
        event.pull_request.head.sha,
        "--",
        "supabase/migrations",
      ])
        .trim()
        .split("\n"),
    )
  : new Set();
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
  const predecessor = summarizeHistory(await sql.unsafe(historyQuery));
  assert.deepEqual(
    predecessor.map((r) => r.version),
    baseline.applied_history.map((r) => r.version),
  );
  // Existing fictional OTP/Profile/Proposal producers exercise genuine Auth/RLS
  // and retain populated predecessor rows. No new seed or privileged admission.
  command("npm", ["run", "profile:verify:local"]);
  command("npm", ["run", "proposal:verify:local"]);
  const tables =
    await sql`select n.nspname as schema,c.relname as name,array_agg(a.attname order by a.attnum) as columns
    from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
    where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped
    group by n.nspname,c.relname order by n.nspname,c.relname`;
  const before = await snapshot(tables);
  const previousInventory = local.filter((m) => applied.has(m.version));
  for (const migration of pending) {
    const currentTables =
      await sql`select n.nspname as schema,c.relname as name,array_agg(a.attname order by a.attnum) as columns from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped group by n.nspname,c.relname order by n.nspname,c.relname`;
    const original = await snapshot(currentTables);
    const priorCatalog = (await sql.unsafe(catalogQuery))[0].catalog;
    writeFileSync(path(migration), migration.sql);
    command(cli, ["migration", "up", "--local", "--include-all"]);
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
    };
    const classification = classifyMigration(migration.sql);
    if (classification.classification === "routine-candidate") {
      try {
        assertRoutineCatalog(
          priorCatalog,
          (await sql.unsafe(catalogQuery))[0].catalog,
          classification.effects,
        );
        witness.routine_security_preserved = true;
      } catch (error) {
        if (!(error instanceof ReleaseError)) throw error;
        if (changed.has(path(migration))) {
          const needed = {
            version: migration.version,
            sha256: migration.sha256,
            predecessor_inventory_sha256: witness.predecessor_inventory_sha256,
          };
          writeFileSync(
            "build/release01/review-required.json",
            JSON.stringify(
              {
                project_ref: STAGING_REF,
                source_sha: event.pull_request.head.sha,
                approvals: [needed],
              },
              null,
              2,
            ),
          );
          const reviews = await ownerReviewsForPr(
            githubClient(process.env),
            event.pull_request,
          );
          if (
            !reviews.some(
              (r) =>
                r.version === needed.version &&
                r.sha256 === needed.sha256 &&
                r.predecessor_inventory_sha256 ===
                  needed.predecessor_inventory_sha256,
            )
          )
            throw new ReleaseError(
              "Catalog semantics require pre-merge owner review: use the sanitized review-required artifact and rerun; SQL grammar alone is insufficient",
            );
        }
      }
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
  command(cli, ["migration", "up", "--local", "--include-all"]);
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
  command("npm", ["run", "resource:listings:verify:local"]);
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
  command("npm", ["run", "db:types:check"]);
  const evidence = {
    source_sha: process.env.GITHUB_SHA,
    workflow_run_id: process.env.GITHUB_RUN_ID,
    inventory_sha256: inventoryDigest(local),
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
  };
  writeFileSync(
    "build/release01/rehearsal.json",
    JSON.stringify(evidence, null, 2),
  );
  console.log(
    `Populated rehearsal passed: ${predecessor.length} → ${first.length}; ${before.length} tables preserved; second invocation no-op; real Resource Auth/REST and generated types passed.`,
  );
} finally {
  restore();
  if (sql) await sql.end({ timeout: 5 });
  if (started) command(cli, ["stop", "--no-backup"]);
}
