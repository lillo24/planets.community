import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
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
  name.endsWith("_group_contact_requests.sql"),
);
assert.ok(first > 0, "D01 migration boundary missing.");
function command(executable, args) {
  const cli = executable === "supabase";
  const result = spawnSync(
    cli ? process.execPath : executable,
    cli
      ? [
          fileURLToPath(
            new URL(
              "../node_modules/supabase/dist/supabase.js",
              import.meta.url,
            ),
          ),
          ...args,
        ]
      : args,
    {
      cwd: root,
      encoding: "utf8",
      shell: false,
      maxBuffer: 32 * 1024 * 1024,
    },
  );
  if (result.status !== 0 || result.error) {
    // Arguments may contain a local credential URL; never interpolate them.
    throw new Error(
      `D upgrade ${cli ? `${args[0]} ${args[1]}` : "fixture"} failed (${result.status ?? result.error?.code}). ${(result.stderr || result.stdout || "").slice(-800).replace(/postgresql:\/\/[^@\s]+@/g, "postgresql://[redacted]@")}`,
    );
  }
}
// Explicit verified loopback URL avoids beta.39's Windows/Podman local-reset
// detection failure. This is the same pinned CLI reset/replay, never a hosted DB.
command("supabase", [
  "db",
  "reset",
  "--db-url",
  status.databaseUrl,
  "--version",
  files[first - 1].split("_")[0],
  "--yes",
]);
command(process.execPath, ["scripts/seed-local-demo-world.mjs"]);
command(process.execPath, ["scripts/verify-local-persistent-groups.mjs"]);
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
    "public.projects",
    "public.project_memberships",
    "public.project_chat_messages",
    "private.community_groups",
    "private.moderation_reports",
  ])
    assert.ok(
      before.get(required)?.count > 0,
      `Populated upgrade requires ${required}.`,
    );
  const [{ oid }] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid oid`;
  command("supabase", ["migration", "up", "--db-url", status.databaseUrl]);
  command("supabase", ["migration", "up", "--db-url", status.databaseUrl]);
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
    await sql`select (select count(*) from private.group_contact_requests)::int requests,(select count(*) from private.group_contact_admissions)::int admissions`;
  assert.deepEqual(
    counts,
    { requests: 0, admissions: 0 },
    "Upgrade invents no contact or admission.",
  );
  await sql`notify pgrst,'reload schema'`;
  console.log(
    `D populated current-main upgrade: ${tables.length} existing table/column/row snapshots preserved; repeat application harmless.`,
  );
} finally {
  await sql.end();
}
