import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// C01 fictional Auth fixtures. This verifier never resets a database.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
    "Discussion verification requires loopback endpoints.",
  );
}
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
const expected = (p) => ({ p_expected_profile_id: p.id });
const command = (p, room) => ({
  ...expected(p),
  p_room_id: room,
  p_client_request_id: randomUUID(),
});
async function rpc(p, name, args) {
  const response = await p.client.rpc(name, args);
  equal(response.error?.code ?? null, null, `${name} succeeds`);
  return response.data;
}
async function denied(p, name, args, code = "42501") {
  const response = await p.client.rpc(name, args);
  equal(response.error?.code, code, `${name} denied`);
}
async function user(label) {
  const p = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `c01-${run}-${label}@planets.invalid`,
    verifierName: "group-discussions",
  });
  await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Fictional C01 ${label}`})`;
  return p;
}
async function delegate(creator, person, group, role) {
  const [offer] = await rpc(creator, "create_group_authority_invitation", {
    ...expected(creator),
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_role: role,
  });
  return (
    await rpc(person, "accept_group_authority_invitation", {
      ...expected(person),
      p_client_request_id: randomUUID(),
      p_token: offer.invite_token,
    })
  )[0];
}
async function invite(manager, person, room) {
  return rpc(manager, "invite_group_discussion_member", {
    ...command(manager, room),
    p_profile_id: person.id,
  });
}
async function accept(person, room, invitation) {
  return rpc(person, "respond_group_discussion_invitation", {
    ...command(person, room),
    p_invitation_id: invitation.object_id,
    p_response: "accepted",
  });
}
async function send(person, room, body) {
  return rpc(person, "send_group_discussion_message", {
    ...command(person, room),
    p_body: body,
  });
}
const context = (person, room) =>
  rpc(person, "get_group_discussion", { ...expected(person), p_room_id: room });
const history = (person, room, extra = {}) =>
  rpc(person, "list_group_discussion_messages", {
    ...expected(person),
    p_room_id: room,
    ...extra,
  });
const unread = (person) =>
  rpc(person, "get_group_discussion_unread", expected(person));
function runCommand(executable, args) {
  const result = spawnSync(executable, args, {
    cwd: process.cwd(),
    encoding: "utf8",
    shell: process.platform === "win32" && executable === "supabase",
    timeout: 900000,
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(
    result.status,
    0,
    `Discussion upgrade step failed (${args[0]}): ${result.error?.code ?? result.status}`,
  );
}
async function upgrade() {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade requires an explicitly disposable local stack.",
  );
  const migrations = (await readdir("supabase/migrations"))
    .filter((p) => p.endsWith(".sql"))
    .sort();
  const index = migrations.findIndex((p) =>
    p.endsWith("_group_discussions_domain.sql"),
  );
  assert.ok(index > 0, "C01 must have a predecessor migration");
  runCommand("supabase", [
    "db",
    "reset",
    "--local",
    "--version",
    migrations[index - 1].split("_")[0],
  ]);
  runCommand(process.execPath, [
    fileURLToPath(new URL("./seed-local-demo-world.mjs", import.meta.url)),
  ]);
  runCommand(process.execPath, [
    fileURLToPath(
      new URL("./verify-local-group-projects.mjs", import.meta.url),
    ),
  ]);
  runCommand(process.execPath, [
    fileURLToPath(
      new URL("./verify-local-persistent-groups.mjs", import.meta.url),
    ),
  ]);
  runCommand(process.execPath, [
    fileURLToPath(
      new URL("./verify-local-group-membership.mjs", import.meta.url),
    ),
  ]);
  const tables =
    await sql`select table_schema||'.'||table_name as name,array_agg(column_name order by ordinal_position) as columns
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
  for (const name of [
    "private.community_groups",
    "private.group_memberships",
    "private.group_delegates",
    "private.moderation_cases",
    "public.project_chat_messages",
    "public.project_shared_workspaces",
  ])
    assert.ok(
      before.get(name)?.count > 0,
      `Populated preservation requires ${name}`,
    );
  runCommand("supabase", ["migration", "up", "--local"]);
  runCommand("supabase", ["migration", "up", "--local"]);
  for (const table of tables)
    equal(
      await snapshot(table),
      before.get(table.name),
      `Preserves every predecessor column/row: ${table.name}`,
    );
  console.log(
    `Group discussion populated upgrade passed: ${checks} tables preserved; repeated application harmless.`,
  );
}
async function observedGroupWait(group, operation, change) {
  const held = await sql.reserve();
  let pending;
  try {
    await held`begin`;
    await held`select id from private.community_groups where id=${group}::uuid for update`;
    pending = operation();
    let observed = false;
    for (let i = 0; i < 100; i++) {
      const [row] =
        await sql`select count(*)::int n from pg_stat_activity where wait_event_type='Lock' and query like '%send_group_discussion_message%'`;
      if (row.n > 0) {
        observed = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    equal(observed, true, "HTTP send really waits on the Group lock");
    await change(held);
    await held`commit`;
    await pending;
  } catch (error) {
    await held`rollback`;
    if (pending) await pending.catch(() => {});
    throw error;
  } finally {
    held.release();
  }
}

try {
  if (process.argv.includes("--upgrade")) {
    await upgrade();
    process.exitCode = 0;
  } else {
    const creator = await user("creator"),
      member = await user("member"),
      other = await user("unrelated"),
      organizer = await user("organizer"),
      staff = await user("staff");
    const group = await rpc(creator, "create_group_draft", {
      ...expected(creator),
      p_client_request_id: randomUUID(),
      p_content: {
        name: `Fictional C01 ${run}`,
        description: "Fictional group planning a local garden together.",
        group_kind: "informal",
        locality: "Trento",
        volunteering_focus: true,
      },
    });
    await rpc(creator, "set_group_publication_state", {
      ...expected(creator),
      p_client_request_id: randomUUID(),
      p_group_id: group,
      p_expected_version: 1,
      p_publication_state: "published",
    });
    const [sharing] = await rpc(
      creator,
      "create_group_participant_invitation",
      {
        ...expected(creator),
        p_client_request_id: randomUUID(),
        p_group_id: group,
      },
    );
    const [membership] = await rpc(
      member,
      "accept_group_participant_invitation",
      {
        ...expected(member),
        p_client_request_id: randomUUID(),
        p_token: sharing.invite_token,
      },
    );
    await delegate(creator, organizer, group, "co_organizer");
    const createArgs = {
      ...expected(creator),
      p_group_id: group,
      p_client_request_id: randomUUID(),
      p_title: "Parco",
    };
    const created = await rpc(creator, "create_group_discussion", createArgs),
      room = created.room_id;
    const noOp = await rpc(creator, "update_group_discussion", {
      ...command(creator, room),
      p_expected_version: created.version,
      p_title: "Parco",
      p_archived: false,
    });
    equal(noOp.version, created.version, "No-op management preserves version");
    equal(
      await rpc(creator, "create_group_discussion", createArgs),
      created,
      "Dropped creation reply recovers one room",
    );
    await denied(
      creator,
      "create_group_discussion",
      { ...createArgs, p_title: "Changed" },
      "22023",
    );
    await denied(member, "create_group_discussion", {
      ...createArgs,
      ...expected(member),
      p_client_request_id: randomUUID(),
    });
    await denied(other, "get_group_discussion", {
      ...expected(other),
      p_room_id: room,
    });
    await denied(organizer, "get_group_discussion", {
      ...expected(organizer),
      p_room_id: room,
    });
    equal(
      await rpc(member, "list_group_discussions", {
        ...expected(member),
        p_group_id: group,
      }),
      [],
      "Group membership does not disclose rooms",
    );
    await denied(
      creator,
      "list_group_discussions",
      { ...expected(creator), p_group_id: group, p_limit: 51 },
      "22023",
    );
    await denied(
      creator,
      "list_group_discussions",
      { ...expected(creator), p_group_id: group, p_before_id: room },
      "22023",
    );
    const older = await send(
      creator,
      room,
      "Fictional message before admission.",
    );
    const invitation = await invite(creator, member, room);
    const pending = await rpc(
      member,
      "list_group_discussion_invitations",
      expected(member),
    );
    equal(pending[0].title, "Parco", "Consent projection supplies title");
    equal(
      Object.hasOwn(pending[0], "preview"),
      false,
      "Consent projection contains no message preview",
    );
    await denied(member, "get_group_discussion", {
      ...expected(member),
      p_room_id: room,
    });
    const accepted = await accept(member, room, invitation);
    equal(
      (await history(member, room)).items,
      [],
      "Acceptance starts after committed history",
    );
    const newest = await send(
      creator,
      room,
      "Fictional message after admission.",
    );
    // Equality of timestamps must not bypass the sequence frontier.
    // Trusted, transaction-local fixture setup only: force a timestamp tie across
    // the immutable messages and acceptance, without changing their sequences.
    await sql.begin(async (fixture) => {
      await fixture`set local session_replication_role=replica`;
      await fixture`update private.group_discussion_messages set created_at=(select accepted_at from private.group_discussion_admissions where id=${accepted.object_id}::uuid) where id in (${older.object_id}::uuid,${newest.object_id}::uuid)`;
    });
    let page = await history(member, room);
    equal(
      page.items.map((m) => m.message_id),
      [newest.object_id],
      "Only post-admission message is visible",
    );
    equal(await unread(member), 1, "Complete canonical unread count");
    const groups = await rpc(member, "list_my_discussion_groups", {
      ...expected(member),
      p_limit: 1,
    });
    equal(
      Number(groups[0].unread_count),
      1,
      "Collapsed Group uses complete server unread",
    );
    await denied(
      member,
      "acknowledge_group_discussion_read",
      {
        ...expected(member),
        p_room_id: room,
        p_snapshot_token:
          page.snapshot_token.slice(0, -1) +
          (page.snapshot_token.endsWith("0") ? "1" : "0"),
      },
      "22023",
    );
    await send(creator, room, "Fictional unread after snapshot.");
    await rpc(member, "acknowledge_group_discussion_read", {
      ...expected(member),
      p_room_id: room,
      p_snapshot_token: page.snapshot_token,
    });
    equal(
      await unread(member),
      1,
      "Earlier read snapshot cannot consume a later send",
    );
    const sendArgs = {
      ...command(member, room),
      p_body: "Fictional duplicate-safe response.",
    };
    const sent = await rpc(member, "send_group_discussion_message", sendArgs);
    equal(
      await rpc(member, "send_group_discussion_message", sendArgs),
      sent,
      "Lost send reply repeats one message",
    );
    await denied(
      member,
      "send_group_discussion_message",
      { ...sendArgs, p_body: "Changed intent." },
      "22023",
    );
    equal(await unread(member), 1, "Own send never creates own unread");
    const recent = await history(member, room, { p_limit: 1 });
    equal(recent.items.length, 1, "Server bounds newest history");
    const past = await history(member, room, {
      p_limit: 1,
      p_before_sequence: recent.items[0].sequence,
    });
    equal(past.items.length, 1, "Server keyset reads older history");
    equal(
      past.snapshot_token,
      null,
      "Older page cannot acknowledge newest history",
    );
    await denied(member, "invite_group_discussion_member", {
      ...command(member, room),
      p_profile_id: organizer.id,
    });
    await accept(organizer, room, await invite(creator, organizer, room));
    const organizerRoom = await context(organizer, room);
    equal(organizerRoom.can_manage, true, "Admitted Co-organizer manages room");
    equal(
      organizerRoom.can_publish,
      false,
      "Co-organizer does not gain Project publishing",
    );
    await denied(creator, "invite_group_discussion_member", {
      ...command(creator, room),
      p_profile_id: other.id,
    });
    const reportArgs = {
      p_expected_reporter_profile_id: member.id,
      p_client_submission_id: randomUUID(),
      p_message_id: newest.object_id,
      p_category: "other",
      p_explanation: "Fictional report evidence for a local test.",
    };
    await denied(member, "submit_group_discussion_report", {
      ...reportArgs,
      p_message_id: older.object_id,
    });
    const report = (
      await rpc(member, "submit_group_discussion_report", reportArgs)
    )[0];
    equal(
      (await rpc(member, "submit_group_discussion_report", reportArgs))[0]
        .report_id,
      report.report_id,
      "Report retry resolves original case",
    );
    await denied(
      member,
      "submit_group_discussion_report",
      { ...reportArgs, p_explanation: "Changed fictional explanation." },
      "22023",
    );
    await denied(
      member,
      "submit_moderation_report",
      {
        ...reportArgs,
        p_message_id: undefined,
        p_target_kind: "group",
        p_target_id: group,
      },
      "22023",
    );
    await denied(member, "get_moderation_case_group_discussion", {
      p_expected_staff_profile_id: member.id,
      p_case_id: report.case_id,
    });
    await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active) values(${staff.id}::uuid,'moderator',true)`;
    const evidence = await rpc(staff, "get_moderation_case_group_discussion", {
      p_expected_staff_profile_id: staff.id,
      p_case_id: report.case_id,
    });
    equal(
      evidence.message_id,
      newest.object_id,
      "Staff gets exact reported evidence",
    );
    await denied(staff, "get_group_discussion", {
      ...expected(staff),
      p_room_id: room,
    });
    await observedGroupWait(
      group,
      () =>
        denied(
          member,
          "send_group_discussion_message",
          {
            ...command(member, room),
            p_body: "Fictional queued after archive.",
          },
          "55000",
        ),
      async (held) => {
        await held`update private.group_discussions set archived=true,version=version+1 where id=${room}::uuid`;
      },
    );
    equal(
      (await context(member, room)).archived,
      true,
      "Archived room remains currently readable",
    );
    const archived = await context(creator, room);
    await rpc(creator, "update_group_discussion", {
      ...command(creator, room),
      p_expected_version: archived.version,
      p_title: "Parco",
      p_archived: false,
    });
    await observedGroupWait(
      group,
      () =>
        denied(member, "send_group_discussion_message", {
          ...command(member, room),
          p_body: "Fictional queued after source removal.",
        }),
      async (held) => {
        await held`update private.group_memberships set ended_at=clock_timestamp(),ended_by=${creator.id}::uuid,end_reason='removed' where id=${membership.relationship_id}::uuid`;
      },
    );
    await denied(member, "get_group_discussion", {
      ...expected(member),
      p_room_id: room,
    });
    equal(await unread(member), 0, "Source revocation removes unread");
    equal(
      await rpc(member, "list_my_discussion_groups", expected(member)),
      [],
      "Source revocation removes folder",
    );
    await rpc(member, "accept_group_participant_invitation", {
      ...expected(member),
      p_client_request_id: randomUUID(),
      p_token: sharing.invite_token,
    });
    await denied(member, "get_group_discussion", {
      ...expected(member),
      p_room_id: room,
    });
    await accept(member, room, await invite(creator, member, room));
    equal(
      (await history(member, room)).items,
      [],
      "Fresh admission after rejoin excludes all old messages",
    );
    const restored = await context(member, room);
    await rpc(member, "leave_group_discussion", {
      ...command(member, room),
      p_admission_id: restored.admission_id,
    });
    await denied(member, "get_group_discussion", {
      ...expected(member),
      p_room_id: room,
    });
    equal(
      (
        await rpc(staff, "get_moderation_case_group_discussion", {
          p_expected_staff_profile_id: staff.id,
          p_case_id: report.case_id,
        })
      ).message_id,
      newest.object_id,
      "Report evidence survives reporter room exit",
    );
    equal(
      accepted.room_id,
      room,
      "Explicit admission identifies only its room",
    );
    // New direct invitations obey the pair block; existing shared-room
    // entitlement and another admitted manager's independent invite survive.
    const second = await rpc(organizer, "create_group_discussion", {
      ...expected(organizer),
      p_client_request_id: randomUUID(),
      p_group_id: group,
      p_title: "Fictional second room",
    });
    await accept(
      creator,
      second.room_id,
      await invite(organizer, creator, second.room_id),
    );
    await rpc(member, "block_user", {
      p_expected_blocker_profile_id: member.id,
      p_blocked_profile_id: organizer.id,
    });
    await denied(
      organizer,
      "invite_group_discussion_member",
      {
        ...command(organizer, second.room_id),
        p_profile_id: member.id,
      },
      "PT409",
    ); // The existing canonical block barrier uses opaque PT409.
    await accept(
      member,
      second.room_id,
      await invite(creator, member, second.room_id),
    );
    await send(
      member,
      second.room_id,
      "Fictional shared-room send with a blocked pair.",
    );
    equal(
      (await history(organizer, second.room_id)).items.length,
      1,
      "Blocking preserves shared-room visibility",
    );
    await rpc(member, "unblock_user", {
      p_expected_blocker_profile_id: member.id,
      p_blocked_profile_id: organizer.id,
    });
    const [role] = await rpc(organizer, "get_own_group_role", {
      ...expected(organizer),
      p_group_id: group,
    });
    await rpc(creator, "revoke_group_delegate", {
      ...expected(creator),
      p_client_request_id: randomUUID(),
      p_delegate_id: role.delegate_id,
    });
    await denied(organizer, "get_group_discussion", {
      ...expected(organizer),
      p_room_id: second.room_id,
    });
    await delegate(creator, organizer, group, "co_organizer");
    await denied(organizer, "get_group_discussion", {
      ...expected(organizer),
      p_room_id: second.room_id,
    });
    equal(
      (await context(creator, second.room_id)).can_manage,
      true,
      "Explicitly admitted manager retains independent authority",
    );
    console.log(`Group discussion Auth verifier passed: ${checks} assertions.`);
  }
} finally {
  await sql.end();
}
