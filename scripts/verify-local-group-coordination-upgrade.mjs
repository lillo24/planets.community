import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import { createRequire } from "node:module";
import { arch } from "node:os";
import { dirname, join } from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const root = process.cwd();
const status = readLocalSupabaseStatus(root);
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "D upgrade requires an explicitly disposable local stack.",
);
for (const endpoint of [status.apiUrl, status.databaseUrl])
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    "D upgrade requires loopback endpoints.",
  );
const files = (await readdir("supabase/migrations"))
  .filter((name) => name.endsWith(".sql"))
  .sort();
const first = files.findIndex((name) =>
  name.endsWith("_group_coordination_proposals.sql"),
);
assert.ok(first > 0, "D03 migration boundary missing.");
function command(executable, args) {
  const cli = executable === "supabase";
  // Use the same installed optional binary package as beta.39's Node wrapper,
  // directly: spawnSync timeout must terminate the actual reset process as well.
  const require = createRequire(import.meta.url);
  const platform = process.platform === "win32" ? "windows" : process.platform;
  const binary = cli
    ? join(
        dirname(
          require.resolve(`@supabase/cli-${platform}-${arch()}/package.json`),
        ),
        "bin",
        `supabase${process.platform === "win32" ? ".exe" : ""}`,
      )
    : executable;
  const result = spawnSync(binary, args, {
    cwd: root,
    encoding: "utf8",
    shell: false,
    maxBuffer: 32 * 1024 * 1024,
    timeout: 300000,
  });
  if (result.status !== 0 || result.error) {
    // Arguments may contain a local credential URL; never interpolate them.
    throw new Error(
      `D upgrade ${cli ? `${args[0]} ${args[1]}` : "fixture"} failed (${result.status ?? result.error?.code}). ${(result.stderr || result.stdout || "").slice(-800).replace(/postgresql:\/\/[^@\s]+@/g, "postgresql://[redacted]@")}`,
    );
  }
}
// Verify loopback status first, then use this checkout's local project selector.
// A stalled process fails within five minutes rather than holding QA forever.
const currentBase = process.argv.includes("--from-current-d02");
if (currentBase) {
  assert.ok(
    process.env.PLANETS_DISPOSABLE_QA === "1" && process.env.CI !== "true",
    "Existing D02 baseline is an explicit local QA mode only.",
  );
  const probe = postgres(status.databaseUrl, { max: 1 });
  const [installed] =
    await probe`select max(version) version from supabase_migrations.schema_migrations`;
  await probe.end();
  assert.equal(
    installed.version,
    files[first - 1].split("_")[0],
    "Existing baseline must be the exact last D02 migration.",
  );
} else
  command("supabase", [
    "db",
    "reset",
    "--local",
    "--version",
    files[first - 1].split("_")[0],
    "--yes",
  ]);
// D01's separate current-main upgrade owns populated legacy Project/Resource
// coverage. This gate specifically preserves already-installed D02 records and
// does not require unrelated media upload/processing to populate those records.
command(process.execPath, ["scripts/verify-local-group-contact.mjs"]);
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
try {
  const tables =
    await sql`select table_schema||'.'||table_name name,array_agg(column_name order by ordinal_position) columns
    from information_schema.columns where table_schema in ('public','private') and table_name in
      (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r')
    group by table_schema,table_name order by 1`;
  async function snapshot(table) {
    const [{ rows }] =
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) rows from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
    return {
      count: rows.length,
      hash: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  }
  const before = new Map();
  for (const table of tables) before.set(table.name, await snapshot(table));
  for (const required of [
    "public.profiles",
    "private.community_groups",
    "private.moderation_reports",
    "private.group_contact_requests",
    "private.group_contact_admissions",
    "private.group_contact_messages",
  ])
    assert.ok(
      before.get(required)?.count > 0,
      `Populated upgrade requires ${required}.`,
    );
  const [{ oid }] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid oid`;
  command("supabase", ["migration", "up", "--local"]);
  command("supabase", ["migration", "up", "--local"]);
  for (const table of tables)
    assert.deepEqual(
      await snapshot(table),
      before.get(table.name),
      `D upgrade preserved ${table.name}.`,
    );
  const [after] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid oid`;
  assert.equal(
    after.oid,
    oid,
    "Canonical warmed blocking function OID retained.",
  );
  const [counts] =
    await sql`select (select count(*) from private.group_coordination_proposals)::int proposals,(select count(*) from private.group_coordination_seats)::int seats`;
  assert.deepEqual(
    counts,
    { proposals: 0, seats: 0 },
    "Upgrade invents no coordination or seats.",
  );
  await sql`notify pgrst,'reload schema'`;
  console.log(
    `D03 populated D02 upgrade: ${tables.length} existing table/column/row snapshots preserved; repeat application harmless.`,
  );
} finally {
  await sql.end();
}
