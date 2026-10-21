import { ReleaseError } from "./errors.mjs";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, unlinkSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import postgres from "postgres";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";
import { readMigrations, migrationDiff, STAGING_REF } from "./migrations.mjs";
import { historyQuery, summarizeHistory } from "./backend.mjs";

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
const policy = JSON.parse(readFileSync("scripts/release/policy.json", "utf8"));
mkdirSync("build/release01", { recursive: true });
if (policy.bootstrap_complete) {
  console.log(
    "Bootstrap is reconciled; complete Validation owns routine migration upgrade checks.",
  );
  process.exit(0);
}
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
    "docs/development/evidence/release01/migration-manifest.json",
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
  restore();
  command(cli, ["migration", "up", "--local", "--include-all"]);
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
  command("npm", ["run", "db:types:check"]);
  const evidence = {
    source_sha: process.env.GITHUB_SHA,
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
