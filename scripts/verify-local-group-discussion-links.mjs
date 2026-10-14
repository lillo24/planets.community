import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Fictional real Auth sessions only. No reset or hosted mutation.
const status = readLocalSupabaseStatus(process.cwd()),
  mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [status.apiUrl, status.databaseUrl, mailpitUrl])
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
    "C03 requires loopback endpoints.",
  );
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} }),
  run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
const expected = (p) => ({ p_expected_profile_id: p.id });
const command = (p, room, admission) => ({
  ...expected(p),
  p_room_id: room,
  p_expected_admission_id: admission,
  p_client_request_id: randomUUID(),
});
async function rpc(p, name, args) {
  const r = await p.client.rpc(name, args);
  equal(r.error?.code ?? null, null, `${name} succeeds`);
  return r.data;
}
async function denied(p, name, args, code = "42501") {
  const r = await p.client.rpc(name, args);
  equal(r.error?.code, code, `${name} denies unavailable scope`);
}
async function user(label) {
  const p = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `c03-${run}-${label}@planets.invalid`,
    verifierName: "group discussion links",
  });
  await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Fictional C03 ${label}`})`;
  return p;
}
const list = (p, room, admission = null, extra = {}) =>
  rpc(p, "list_group_discussion_links", {
    ...expected(p),
    p_room_id: room,
    p_expected_admission_id: admission,
    ...extra,
  });
const exact = (p, room, admission, link) =>
  rpc(p, "get_group_discussion_link", {
    ...expected(p),
    p_room_id: room,
    p_expected_admission_id: admission,
    p_link_id: link,
  });
const add = (p, room, admission, name, url) =>
  rpc(p, "add_group_discussion_link", {
    ...command(p, room, admission),
    p_name: name,
    p_url: url,
  });
async function queuedLink(group, operation, change) {
  const held = await sql.reserve();
  let pending;
  try {
    await held`begin`;
    await held`select id from private.community_groups where id=${group}::uuid for update`;
    pending = operation();
    let observed = false;
    for (let i = 0; i < 100; i++) {
      const [row] =
        await sql`select count(*)::int n from pg_stat_activity where wait_event_type='Lock' and query like '%group_discussion_link%'`;
      if (row.n > 0) {
        observed = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    equal(
      observed,
      true,
      "HTTP link write actually waits for Group authorization lock",
    );
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
  const creator = await user("creator"),
    member = await user("member"),
    manager = await user("coorganizer"),
    other = await user("unrelated");
  const group = await rpc(creator, "create_group_draft", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_content: {
      name: "C03 fictional planning group",
      description:
        "Fictional verified actors testing separately scoped private named links.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(creator, "set_group_publication_state", {
    ...expected(creator),
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const [membership] = await rpc(
    creator,
    "create_group_participant_invitation",
    {
      ...expected(creator),
      p_group_id: group,
      p_client_request_id: randomUUID(),
    },
  );
  await rpc(member, "accept_group_participant_invitation", {
    ...expected(member),
    p_client_request_id: randomUUID(),
    p_token: membership.invite_token,
  });
  const [role] = await rpc(creator, "create_group_authority_invitation", {
    ...expected(creator),
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_role: "co_organizer",
  });
  await rpc(manager, "accept_group_authority_invitation", {
    ...expected(manager),
    p_client_request_id: randomUUID(),
    p_token: role.invite_token,
  });
  const created = await rpc(creator, "create_group_discussion", {
      ...expected(creator),
      p_group_id: group,
      p_client_request_id: randomUUID(),
      p_title: "C03 Parco",
    }),
    room = created.room_id,
    creatorAdmission = created.object_id;
  const old = await add(
    creator,
    room,
    creatorAdmission,
    "Documento precedente",
    "https://example.invalid/older",
  );
  for (const p of [member, manager, other]) {
    await denied(p, "list_group_discussion_links", {
      ...expected(p),
      p_room_id: room,
    });
    await denied(p, "get_group_discussion_link", {
      ...expected(p),
      p_room_id: room,
      p_expected_admission_id: creatorAdmission,
      p_link_id: old.object_id,
    });
  }
  const invitation = await rpc(creator, "invite_group_discussion_member", {
    ...expected(creator),
    p_room_id: room,
    p_profile_id: member.id,
    p_client_request_id: randomUUID(),
  });
  await denied(member, "list_group_discussion_links", {
    ...expected(member),
    p_room_id: room,
  });
  const accepted = await rpc(member, "respond_group_discussion_invitation", {
      ...expected(member),
      p_room_id: room,
      p_client_request_id: randomUUID(),
      p_invitation_id: invitation.object_id,
      p_response: "accepted",
    }),
    admission = accepted.object_id;
  equal(
    (await list(member, room, admission)).items,
    [],
    "Admission does not reveal older destinations",
  );
  await denied(member, "get_group_discussion_link", {
    ...expected(member),
    p_room_id: room,
    p_expected_admission_id: admission,
    p_link_id: old.object_id,
  });
  const intent = {
    ...command(creator, room, creatorAdmission),
    p_name: "Foglio",
    p_url: "https://example.invalid/sheet",
  };
  const added = await rpc(creator, "add_group_discussion_link", intent);
  equal(
    await rpc(creator, "add_group_discussion_link", intent),
    added,
    "Lost Add reply returns one frozen receipt",
  );
  await denied(
    creator,
    "add_group_discussion_link",
    { ...intent, p_url: "https://example.invalid/changed" },
    "22023",
  );
  await denied(
    creator,
    "send_group_discussion_message",
    {
      ...expected(creator),
      p_room_id: room,
      p_client_request_id: intent.p_client_request_id,
      p_body: "Another C action",
    },
    "22023",
  );
  const duplicate = await add(
    creator,
    room,
    creatorAdmission,
    "Foglio",
    "https://example.invalid/sheet",
  );
  equal(
    added.object_id === duplicate.object_id,
    false,
    "Two deliberate identical entries remain distinct",
  );
  const visible = await list(member, room, admission);
  equal(visible.items.length, 2, "Current entitled collection only");
  equal(visible.can_manage, false, "Member is a reader");
  equal(
    (await exact(member, room, admission, added.object_id)).url,
    intent.p_url,
    "Exact authorized destination",
  );
  await denied(member, "add_group_discussion_link", {
    ...command(member, room, admission),
    p_name: "Doc",
    p_url: "https://example.invalid/doc",
  });
  await denied(member, "update_group_discussion_link", {
    ...command(member, room, admission),
    p_link_id: added.object_id,
    p_expected_version: 1,
    p_name: "Doc",
    p_url: "https://example.invalid/doc",
  });
  await denied(member, "remove_group_discussion_link", {
    ...command(member, room, admission),
    p_link_id: added.object_id,
    p_expected_version: 1,
  });
  equal(
    await rpc(member, "get_group_discussion_unread", expected(member)),
    0,
    "Adding links never creates message unread",
  );
  for (const url of [
    "http://example.invalid/a",
    "https://person:secret@example.invalid/a",
    "https://example.invalid/a b",
    "https://example.invalid/" + "x".repeat(2048),
  ])
    await denied(
      creator,
      "add_group_discussion_link",
      {
        ...command(creator, room, creatorAdmission),
        p_name: "Doc",
        p_url: url,
      },
      "22023",
    );
  for (const name of ["", "x".repeat(121), "line\nbreak"])
    await denied(
      creator,
      "add_group_discussion_link",
      {
        ...command(creator, room, creatorAdmission),
        p_name: name,
        p_url: "https://example.invalid/doc",
      },
      "22023",
    );
  const edited = await rpc(creator, "update_group_discussion_link", {
    ...command(creator, room, creatorAdmission),
    p_link_id: added.object_id,
    p_expected_version: 1,
    p_name: "Documento",
    p_url: "https://example.invalid/reviewed",
  });
  equal(edited.version, 2, "Per-item version advances");
  await denied(
    creator,
    "update_group_discussion_link",
    {
      ...command(creator, room, creatorAdmission),
      p_link_id: added.object_id,
      p_expected_version: 1,
      p_name: "Stale",
      p_url: "https://example.invalid/stale",
    },
    "PT409",
  );
  const current = await exact(creator, room, creatorAdmission, added.object_id);
  const noop = await rpc(creator, "update_group_discussion_link", {
    ...command(creator, room, creatorAdmission),
    p_link_id: added.object_id,
    p_expected_version: 2,
    p_name: current.name,
    p_url: current.url,
  });
  equal(noop.version, 2, "No-op preserves version");
  equal(
    (await exact(creator, room, creatorAdmission, added.object_id)).updated_at,
    current.updated_at,
    "No-op preserves update time",
  );
  equal(
    (await exact(creator, room, creatorAdmission, duplicate.object_id)).version,
    1,
    "Sibling was untouched",
  );
  const removal = {
      ...command(creator, room, creatorAdmission),
      p_link_id: added.object_id,
      p_expected_version: 2,
    },
    removed = await rpc(creator, "remove_group_discussion_link", removal);
  equal(
    await rpc(creator, "remove_group_discussion_link", removal),
    removed,
    "Lost Remove reply remains recoverable",
  );
  await denied(member, "get_group_discussion_link", {
    ...expected(member),
    p_room_id: room,
    p_expected_admission_id: admission,
    p_link_id: added.object_id,
  });
  await denied(creator, "update_group_discussion_link", {
    ...command(creator, room, creatorAdmission),
    p_link_id: added.object_id,
    p_expected_version: 3,
    p_name: "Resurrect",
    p_url: "https://example.invalid/revive",
  });
  const second = await rpc(creator, "create_group_discussion", {
    ...expected(creator),
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_title: "Separate room",
  });
  await denied(creator, "get_group_discussion_link", {
    ...expected(creator),
    p_room_id: second.room_id,
    p_expected_admission_id: second.object_id,
    p_link_id: duplicate.object_id,
  });
  await denied(creator, "list_group_discussion_links", {
    ...expected(creator),
    p_room_id: room,
    p_expected_admission_id: second.object_id,
  });
  await denied(creator, "get_own_project_shared_workspace", {
    ...expected(creator),
    p_project_id: room,
  });
  const project = await rpc(creator, "create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "C03 separate fictional Project",
    p_summary: "A separate canonical Project for scope confusion testing.",
    p_description: "Fictional scope isolation fixture.",
    p_starts_at: "2098-01-02T10:00:00Z",
    p_ends_at: "2098-01-02T14:00:00Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Trento",
    p_public_location_label: "Trento",
    p_exact_meeting_text: "Fictional local fixture",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  await denied(creator, "list_group_discussion_links", {
    ...expected(creator),
    p_room_id: project,
  });
  for (let i = 0; i < 27; i++)
    await add(
      creator,
      room,
      creatorAdmission,
      `Link ${i}`,
      `https://example.invalid/${i}`,
    );
  // Trusted local fixture only: same timestamp, distinct immutable ordinals/IDs.
  await sql.begin(async (fixture) => {
    await fixture`set local session_replication_role=replica`;
    await fixture`update private.group_discussion_links set created_at=(select accepted_at from private.group_discussion_admissions where id=${admission}::uuid) where room_id=${room}::uuid and created_sequence>1`;
  });
  const first = await list(member, room, admission),
    last = first.items.at(-1),
    next = await list(member, room, admission, {
      p_before_created_at: last.created_at,
      p_before_id: last.link_id,
    });
  equal(first.items.length, 25, "Server bounded first page");
  equal(next.items.length, 3, "Cursor keeps the tied-time tail");
  equal(
    new Set([...first.items, ...next.items].map((i) => i.link_id)).size,
    28,
    "No gap/duplicate in tied-time pages",
  );
  await denied(
    member,
    "list_group_discussion_links",
    {
      ...expected(member),
      p_room_id: room,
      p_expected_admission_id: admission,
      p_limit: 26,
    },
    "22023",
  );
  await denied(
    member,
    "list_group_discussion_links",
    { ...expected(member), p_room_id: room, p_before_id: randomUUID() },
    "22023",
  );
  const message = await rpc(creator, "send_group_discussion_message", {
    ...expected(creator),
    p_room_id: room,
    p_client_request_id: randomUUID(),
    p_body: "Fictional message after links.",
  });
  assert.ok(message.sequence > 30);
  checks++;
  equal(
    await rpc(member, "get_group_discussion_unread", expected(member)),
    1,
    "Message unread ignores ordinal gaps",
  );
  const context = await rpc(creator, "get_group_discussion", {
    ...expected(creator),
    p_room_id: room,
  });
  await rpc(creator, "update_group_discussion", {
    ...expected(creator),
    p_room_id: room,
    p_client_request_id: randomUUID(),
    p_expected_version: context.version,
    p_title: context.title,
    p_archived: true,
  });
  equal(
    (await list(member, room, admission)).can_manage,
    false,
    "Archive retains entitled read-only links",
  );
  await denied(
    creator,
    "add_group_discussion_link",
    {
      ...command(creator, room, creatorAdmission),
      p_name: "Late",
      p_url: "https://example.invalid/late",
    },
    "55000",
  );
  await rpc(creator, "update_group_discussion", {
    ...expected(creator),
    p_room_id: room,
    p_client_request_id: randomUUID(),
    p_expected_version: context.version + 1,
    p_title: context.title,
    p_archived: false,
  });
  const managerInvite = await rpc(creator, "invite_group_discussion_member", {
    ...expected(creator),
    p_room_id: room,
    p_profile_id: manager.id,
    p_client_request_id: randomUUID(),
  });
  const managerAccepted = await rpc(
    manager,
    "respond_group_discussion_invitation",
    {
      ...expected(manager),
      p_room_id: room,
      p_client_request_id: randomUUID(),
      p_invitation_id: managerInvite.object_id,
      p_response: "accepted",
    },
  );
  const managerLink = await add(
    manager,
    room,
    managerAccepted.object_id,
    "Riunione",
    "https://example.invalid/call",
  );
  const [delegate] =
    await sql`select id from private.group_delegates where group_id=${group}::uuid and profile_id=${manager.id}::uuid and revoked_at is null`;
  await rpc(manager, "step_down_group_authority", {
    ...expected(manager),
    p_delegate_id: delegate.id,
    p_client_request_id: randomUUID(),
  });
  await denied(manager, "get_group_discussion_link", {
    ...expected(manager),
    p_room_id: room,
    p_expected_admission_id: managerAccepted.object_id,
    p_link_id: managerLink.object_id,
  });
  await rpc(member, "leave_group_discussion", {
    ...expected(member),
    p_room_id: room,
    p_admission_id: admission,
    p_client_request_id: randomUUID(),
  });
  await denied(member, "list_group_discussion_links", {
    ...expected(member),
    p_room_id: room,
  });
  const reInvite = await rpc(creator, "invite_group_discussion_member", {
    ...expected(creator),
    p_room_id: room,
    p_profile_id: member.id,
    p_client_request_id: randomUUID(),
  });
  const renewed = await rpc(member, "respond_group_discussion_invitation", {
    ...expected(member),
    p_room_id: room,
    p_client_request_id: randomUUID(),
    p_invitation_id: reInvite.object_id,
    p_response: "accepted",
  });
  equal(
    (await list(member, room, renewed.object_id)).items,
    [],
    "Renewed admission never resurrects old destinations",
  );
  await denied(member, "get_group_discussion_link", {
    ...expected(member),
    p_room_id: room,
    p_expected_admission_id: admission,
    p_link_id: duplicate.object_id,
  });
  const publicGroup = await rpc(other, "get_public_group", {
    p_group_id: group,
  });
  equal(
    JSON.stringify(publicGroup).includes("example.invalid"),
    false,
    "Public Group includes no private destination",
  );
  const racing = await add(
    creator,
    room,
    creatorAdmission,
    "Concurrent item",
    "https://example.invalid/race",
  );
  const races = await Promise.all(
    ["one", "two"].map((name) =>
      creator.client.rpc("update_group_discussion_link", {
        ...command(creator, room, creatorAdmission),
        p_link_id: racing.object_id,
        p_expected_version: 1,
        p_name: name,
        p_url: `https://example.invalid/${name}`,
      }),
    ),
  );
  equal(
    races.filter((r) => !r.error).length,
    1,
    "Exactly one same-version item mutation commits",
  );
  equal(
    races.filter((r) => r.error?.code === "PT409").length,
    1,
    "Other same-version mutation is an explicit conflict",
  );
  await queuedLink(
    group,
    () =>
      denied(
        creator,
        "add_group_discussion_link",
        {
          ...command(creator, room, creatorAdmission),
          p_name: "Queued archive",
          p_url: "https://example.invalid/queued",
        },
        "55000",
      ),
    async (held) => {
      await held`update private.group_discussions set archived=true,version=version+1 where id=${room}::uuid`;
    },
  );
  const [count] =
    await sql`select count(*)::int n from private.group_discussion_links where room_id=${room}::uuid and display_name='Queued archive'`;
  equal(count.n, 0, "Post-wait archive check commits no destination");
  await queuedLink(
    group,
    () =>
      denied(creator, "add_group_discussion_link", {
        ...command(creator, room, creatorAdmission),
        p_name: "Queued source end",
        p_url: "https://example.invalid/ended",
      }),
    async (held) => {
      await held`update private.community_groups set publication_state='archived',version=version+1 where id=${group}::uuid`;
    },
  );
  console.log(
    `Group discussion link Auth verifier passed: ${checks} assertions.`,
  );
} finally {
  await sql.end();
}
