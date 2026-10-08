import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Explicitly destructive only inside a designated disposable local QA stack.
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "UI-MSG03 upgrade requires an explicitly disposable local stack.",
);
const status = readLocalSupabaseStatus(process.cwd());
assert.ok(["localhost", "127.0.0.1"].includes(new URL(status.apiUrl).hostname));
// Current main predecessor includes MSG02 and the merged push receipt fix.
cli("supabase", ["db", "reset", "--local", "--version", "20261007103000"]);
cli(process.execPath, ["scripts/verify-local-participation-conversations.mjs"]);
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
try {
  const actors = await sql`select id from public.profiles order by id`;
  const definition =
    await sql`select pg_get_functiondef('public.list_own_scoped_conversation_items_v3(uuid,text,integer,timestamptz,text,uuid)'::regprocedure) as body`;
  const before = await snapshot("v3", actors);
  assert.ok(
    before.some((page) => page.rows.length > 0),
    "Populated legacy/pair/group fixtures required.",
  );
  cli("supabase", ["migration", "up", "--local"]);
  assert.deepEqual(
    await snapshot("v3", actors),
    before,
    "Every v3 field, order and unread remains unchanged.",
  );
  assert.deepEqual(
    await sql`select pg_get_functiondef('public.list_own_scoped_conversation_items_v3(uuid,text,integer,timestamptz,text,uuid)'::regprocedure) as body`,
    definition,
    "Released v3 definition unchanged.",
  );
  const upgraded = await snapshot("v4", actors);
  for (let index = 0; index < before.length; index++) {
    const base = upgraded[index].rows.map(
      ({
        latest_request_activity_status,
        latest_group_system_event_label,
        ...row
      }) => {
        assert.ok(
          latest_request_activity_status === null ||
            ["pending", "accepted", "rejected", "withdrawn"].includes(
              latest_request_activity_status,
            ),
        );
        assert.ok(
          latest_group_system_event_label === null ||
            typeof latest_group_system_event_label === "string",
        );
        return row;
      },
    );
    assert.deepEqual(base, before[index].rows);
  }
  console.log(
    `UI-MSG03 populated upgrade passed: ${actors.length} actors, ${before.length} scope pages; v3 definition/payloads unchanged, v4 additive.`,
  );
} finally {
  await sql.end();
}

async function snapshot(version, actors) {
  const pages = [];
  for (const { id } of actors) {
    for (const scope of ["private", "groups"]) {
      const rows = await sql.begin(async (transaction) => {
        await transaction`select set_config('request.jwt.claim.sub', ${id}, true)`;
        await transaction`set local role authenticated`;
        return (
          await transaction.unsafe(
            `select public.list_own_scoped_conversation_items_${version}($1,$2,50) as rows`,
            [id, scope],
          )
        )[0].rows;
      });
      pages.push({ id, scope, rows });
    }
  }
  return pages;
}

function cli(command, args) {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    shell: process.platform === "win32" && command !== process.execPath,
  });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed`);
}
