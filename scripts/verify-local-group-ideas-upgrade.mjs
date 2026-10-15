import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Destructive ONLY for an explicitly disposable, selected loopback stack.
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "Populated old C upgrade requires an explicitly disposable local stack.",
);
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl])
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
  );
function cli(args) {
  const result = spawnSync("supabase", args, {
    cwd: process.cwd(),
    encoding: "utf8",
    shell: process.platform === "win32",
    timeout: 900000,
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(
    result.status,
    0,
    `Old C upgrade CLI ${args[0]} failed: ${result.error?.code ?? result.status}\n${result.stderr}`,
  );
}
const migrations = (await readdir("supabase/migrations"))
  .filter((p) => p.endsWith(".sql"))
  .sort();
const revision = migrations.findIndex((p) =>
  p.endsWith("_group_ideas_general_and_history.sql"),
);
assert.ok(
  revision > 0 &&
    migrations
      .slice(0, revision)
      .some((p) => p.endsWith("_group_discussion_named_links.sql")),
  "The revision must follow the old complete C source",
);
cli([
  "db",
  "reset",
  "--local",
  "--version",
  migrations[revision - 1].split("_")[0],
]);
const sql = postgres(status.databaseUrl, { max: 3, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
const expected = (p) => ({ p_expected_profile_id: p.id });
const command = (p, room) => ({
  ...expected(p),
  p_client_request_id: randomUUID(),
  ...(room ? { p_room_id: room } : {}),
});
async function rpc(p, name, args) {
  const response = await p.client.rpc(name, args);
  assert.equal(
    response.error?.code ?? null,
    null,
    `${name}: ${response.error?.message ?? "ok"}`,
  );
  checks++;
  return response.data;
}
async function user(label) {
  const actor = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `cr-upgrade-${run}-${label}@planets.invalid`,
    verifierName: "group-ideas-upgrade",
  });
  await sql`insert into public.profiles(id,display_name) values(${actor.id}::uuid,${`Fictional upgrade ${label}`})`;
  return actor;
}
try {
  const creator = await user("creator"),
    member = await user("member");
  const group = await rpc(creator, "create_group_draft", {
    ...command(creator),
    p_content: {
      name: `Fictional old C ${run}`,
      description: "Fictional populated predecessor for the C revision.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(creator, "set_group_publication_state", {
    ...command(creator),
    p_group_id: group,
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const [sharing] = await rpc(creator, "create_group_participant_invitation", {
    ...command(creator),
    p_group_id: group,
  });
  await rpc(member, "accept_group_participant_invitation", {
    ...command(member),
    p_token: sharing.invite_token,
  });
  const created = await rpc(creator, "create_group_discussion", {
    ...command(creator),
    p_group_id: group,
    p_title: "Fictional preserved planning",
  });
  const room = created.room_id;
  const context = await rpc(creator, "get_group_discussion", {
    ...expected(creator),
    p_room_id: room,
  });
  const earlier = await rpc(creator, "send_group_discussion_message", {
    ...command(creator, room),
    p_body: "Earlier immutable predecessor message.",
  });
  await rpc(creator, "add_group_discussion_link", {
    ...command(creator, room),
    p_expected_admission_id: context.admission_id,
    p_name: "Fictional original workspace",
    p_url: "https://example.invalid/original-planning",
  });
  async function admit() {
    const invitation = await rpc(creator, "invite_group_discussion_member", {
      ...command(creator, room),
      p_profile_id: member.id,
    });
    return rpc(member, "respond_group_discussion_invitation", {
      ...command(member, room),
      p_invitation_id: invitation.object_id,
      p_response: "accepted",
    });
  }
  const ended = await admit();
  await rpc(creator, "send_group_discussion_message", {
    ...command(creator, room),
    p_body: "Current immutable predecessor message.",
  });
  await rpc(member, "leave_group_discussion", {
    ...command(member, room),
    p_admission_id: ended.object_id,
  });
  const active = await admit();
  const tables = [
    "group_discussions",
    "group_discussion_admissions",
    "group_discussion_invitations",
    "group_discussion_messages",
    "group_discussion_links",
    "group_discussion_receipts",
  ];
  const before = new Map();
  for (const table of tables) {
    const rows = await sql.unsafe(
      `select to_jsonb(t) as row from private.${table} t`,
    );
    assert.ok(rows.length > 0, `Populated old C requires ${table}`);
    before.set(
      table,
      rows.map((row) => row.row),
    );
  }
  cli(["migration", "up", "--local"]);
  // An already-applied repeat must not create General, notices or grants again.
  cli(["migration", "up", "--local"]);
  for (const table of tables) {
    for (const row of before.get(table)) {
      const [preserved] = await sql.unsafe(
        `select count(*)::int as n from private.${table} t where to_jsonb(t) @> $1::jsonb`,
        [JSON.stringify(row)],
      );
      assert.equal(
        preserved.n,
        1,
        `Preserves all original fields and identity in ${table}`,
      );
      checks++;
    }
  }
  const [generals] =
    await sql`select count(*)::int n from private.group_discussions where group_id=${group}::uuid and kind='general'`;
  assert.equal(
    generals.n,
    1,
    "Populated backfill and repeated apply create exactly one General",
  );
  checks++;
  const [oldExit] =
    await sql`select end_sequence from private.group_discussion_admissions where id=${ended.object_id}::uuid`;
  assert.equal(
    Number(oldExit.end_sequence),
    0,
    "Legacy ended admission does not invent a timestamp frontier",
  );
  checks++;
  const after = await rpc(member, "get_group_discussion_v2", {
    ...expected(member),
    p_room_id: room,
  });
  assert.equal(
    after.admission_id,
    active.object_id,
    "Current old C admission keeps its identity",
  );
  checks++;
  const page = await rpc(member, "get_group_discussion_message_page_v2", {
    ...expected(member),
    p_room_id: room,
  });
  assert.ok(
    page.items.some((message) => message.message_id === earlier.object_id),
    "Current old C admission receives approved full history without copying messages",
  );
  checks++;
  const [messageCount] =
    await sql`select count(*)::int n from private.group_discussion_messages where room_id=${room}::uuid`;
  assert.equal(messageCount.n, 2, "Upgrade does not duplicate messages");
  checks++;
  console.log(
    `Populated old C to revised C upgrade passed: ${checks} assertions across ${tables.length} original tables.`,
  );
} finally {
  await sql.end();
}
