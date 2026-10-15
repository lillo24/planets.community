import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import { createRequire } from "node:module";
import { arch } from "node:os";
import { dirname, join } from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// This intentionally resets ONLY the selected disposable loopback stack. Never
// run concurrently with native/Auth verifiers using the same project and ports.
const root = process.cwd();
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "Member upgrade requires an explicitly disposable local stack.",
);
const status = readLocalSupabaseStatus(root);
for (const endpoint of [status.apiUrl, status.databaseUrl])
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    "Member upgrade requires loopback endpoints.",
  );
const files = (await readdir("supabase/migrations"))
  .filter((name) => name.endsWith(".sql"))
  .sort();
const first = files.findIndex((name) =>
  name.endsWith("_member_contact_domain.sql"),
);
assert.ok(first > 0, "Member contact migration boundary missing.");
function command(executable, args) {
  const cli = executable === "supabase";
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
  if (result.status !== 0 || result.error)
    throw new Error(
      `Member upgrade ${cli ? `${args[0]} ${args[1]}` : "fixture"} failed (${result.status ?? result.error?.code}). ${(result.stderr || result.stdout || "").slice(-800).replace(/postgresql:\/\/[^@\s]+@/g, "postgresql://[redacted]@")}`,
    );
}
command("supabase", [
  "db",
  "reset",
  "--local",
  "--version",
  files[first - 1].split("_")[0],
  "--yes",
]);
command(process.execPath, ["scripts/seed-local-demo-world.mjs"]);
command(process.execPath, ["scripts/verify-local-group-contact.mjs"]);
command(process.execPath, ["scripts/verify-local-group-coordination.mjs"]);
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
    "private.group_contact_requests",
    "private.group_contact_messages",
    "private.group_coordination_proposals",
    "private.moderation_reports",
  ])
    assert.ok(
      before.get(required)?.count > 0,
      `Populated member upgrade requires ${required}.`,
    );
  const [{ oid }] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid oid`;
  const [projector] =
    await sql`select 'public.process_notification_outbox_batch(integer)'::regprocedure::oid oid`;
  command("supabase", ["migration", "up", "--db-url", status.databaseUrl]);
  command("supabase", ["migration", "up", "--db-url", status.databaseUrl]);
  for (const table of tables)
    assert.deepEqual(
      await snapshot(table),
      before.get(table.name),
      `Member upgrade preserved ${table.name}.`,
    );
  const [after] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid oid`;
  assert.equal(
    after.oid,
    oid,
    "Canonical warmed Block function retains identity.",
  );
  const [projectorAfter] =
    await sql`select 'public.process_notification_outbox_batch(integer)'::regprocedure::oid oid`;
  assert.equal(
    projectorAfter.oid,
    projector.oid,
    "Canonical warmed notification worker retains identity.",
  );
  const [counts] =
    await sql`select (select count(*) from private.member_contact_pairs)::int pairs,(select count(*) from private.member_contact_requests)::int requests,(select count(*) from private.member_contact_episodes)::int episodes`;
  assert.deepEqual(
    counts,
    { pairs: 0, requests: 0, episodes: 0 },
    "Upgrade invents no personal relationships or consent.",
  );
  await sql`notify pgrst,'reload schema'`;
  console.log(
    `Member populated predecessor upgrade: ${tables.length} existing table/column/row snapshots preserved; repeated application harmless. C-specific fixtures are required separately if C is incorporated.`,
  );
} finally {
  await sql.end();
}
