import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Fictional genuine Auth identities, selected loopback stack only. No reset.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
  );
}
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
const expected = (person) => ({ p_expected_profile_id: person.id });
const key = () => ({ p_client_request_id: randomUUID() });
async function rpc(person, name, parameters = {}) {
  const result = await person.client.rpc(name, parameters);
  assert.equal(
    result.error?.code ?? null,
    null,
    `${name}: ${result.error?.code ?? "success"}`,
  );
  return result.data;
}
async function denied(person, name, parameters, code = "42501") {
  const result = await person.client.rpc(name, parameters);
  equal(result.error?.code, code, `${name} denial`);
}
async function waitForLock(blocker, functionName) {
  for (let i = 0; i < 200; i++) {
    const rows = await sql`select pid from pg_stat_activity
      where wait_event_type='Lock' and query like ${`%${functionName}%`}
        and pg_blocking_pids(pid) @> array[${blocker}::integer]`;
    if (rows.length === 1) {
      checks++;
      return rows[0].pid;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.fail(
    `Expected ${functionName} to wait on the independently held row.`,
  );
}

async function publishAheadOfQueuedSend(publisher, sender, project, room) {
  const held = await sql.reserve();
  let publication, sending;
  try {
    await held`begin`;
    const [{ pid }] = await held`select pg_backend_pid() pid`;
    // The fixture holds only the terminal room lock and requests no other lock.
    // The genuine publisher must first own Project/Group, then wait here.
    await held`select id from private.group_discussions where id=${room}::uuid for update`;
    publication = rpc(publisher, "publish_proposal_idea", {
      p_expected_creator_profile_id: publisher.id,
      p_proposal_id: project,
    });
    const publisherPid = await waitForLock(pid, "publish_proposal_idea");
    sending = denied(
      sender,
      "send_group_discussion_message",
      {
        ...expected(sender),
        ...key(),
        p_room_id: room,
        p_body: "Queued during publication; must not commit after the marker.",
      },
      "55000",
    );
    await waitForLock(publisherPid, "send_group_discussion_message");
    await held`commit`;
    await Promise.all([publication, sending]);
  } finally {
    await held`rollback`;
    await Promise.allSettled([publication, sending].filter(Boolean));
    held.release();
  }
}
async function person(label) {
  const identity = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `cr05-${run}-${label}@planets.invalid`,
    verifierName: "discussion-conversion",
  });
  await sql`insert into public.profiles(id,display_name) values(${identity.id}::uuid,${`Fictional ${label}`})`;
  await sql`insert into public.profile_photos(profile_id,object_path,audience) values(${identity.id}::uuid,${`${identity.id}/${randomUUID()}.webp`},'interactions')`;
  return identity;
}
async function delegate(owner, target, group, role) {
  const [invite] = await rpc(owner, "create_group_authority_invitation", {
    ...expected(owner),
    ...key(),
    p_group_id: group,
    p_role: role,
  });
  await rpc(target, "accept_group_authority_invitation", {
    ...expected(target),
    ...key(),
    p_token: invite.invite_token,
  });
}
async function joinGroup(owner, target, group) {
  const [invite] = await rpc(owner, "create_group_participant_invitation", {
    ...expected(owner),
    ...key(),
    p_group_id: group,
  });
  return (
    await rpc(target, "accept_group_participant_invitation", {
      ...expected(target),
      ...key(),
      p_token: invite.invite_token,
    })
  )[0];
}
async function conversion(person, room) {
  return rpc(person, "get_group_discussion_conversion", {
    ...expected(person),
    p_room_id: room,
  });
}
async function request(person, room) {
  const params = {
    ...expected(person),
    ...key(),
    p_room_id: room,
    p_title: "Fictional community garden",
    p_summary: "People plan a fictional garden together.",
    p_expected_version: null,
  };
  const result = await rpc(
    person,
    "request_group_discussion_publication",
    params,
  );
  equal(
    await rpc(person, "request_group_discussion_publication", params),
    result,
    "Lost proposal reply is idempotent",
  );
  return result;
}
async function counts(project) {
  const [value] = await sql`select
    (select count(*)::int from public.project_memberships where project_id=${project}::uuid) memberships,
    (select count(*)::int from public.project_chat_messages m join public.project_group_chats c on c.id=m.chat_id where c.project_id=${project}::uuid) messages`;
  return value;
}
try {
  const carlo = await person("Carlo"),
    alice = await person("Alice"),
    bea = await person("Bea"),
    diana = await person("Diana"),
    second = await person("SecondPublisher"),
    planner = await person("Planner"),
    departed = await person("DepartedPlanner");
  const group = await rpc(carlo, "create_group_draft", {
    ...expected(carlo),
    ...key(),
    p_content: {
      name: `Fictional conversion ${run}`,
      description: "Fictional local people planning together.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(carlo, "set_group_publication_state", {
    ...expected(carlo),
    ...key(),
    p_group_id: group,
    p_expected_version: 1,
    p_publication_state: "published",
  });
  await joinGroup(carlo, alice, group);
  await delegate(carlo, bea, group, "co_organizer");
  await delegate(carlo, second, group, "co_creator");
  const settings = await rpc(carlo, "get_group_discussion_settings", {
    ...expected(carlo),
    p_group_id: group,
  });
  await rpc(carlo, "set_group_discussion_settings", {
    ...expected(carlo),
    ...key(),
    p_group_id: group,
    p_expected_version: settings.version,
    p_creation_policy: "members",
  });
  const created = await rpc(alice, "create_group_discussion_v2", {
    ...expected(alice),
    ...key(),
    p_group_id: group,
    p_title: "Fictional planning",
    p_purpose: "Discuss the garden",
    p_visibility: "group",
  });
  const room = created.room_id;
  const departedMembership = await joinGroup(carlo, departed, group);
  await joinGroup(carlo, planner, group);
  for (const target of [planner, departed])
    await rpc(target, "join_group_discussion", {
      ...expected(target),
      ...key(),
      p_room_id: room,
    });
  const sourceAccess = await rpc(alice, "get_group_discussion_v2", {
    ...expected(alice),
    p_room_id: room,
  });
  const sourceLink = await rpc(alice, "add_group_discussion_link_v2", {
    ...expected(alice),
    ...key(),
    p_room_id: room,
    p_expected_admission_id: sourceAccess.access_id,
    p_name: "Selected planning document",
    p_url: "https://example.invalid/selected-planning",
  });
  await rpc(departed, "leave_group", {
    ...expected(departed),
    ...key(),
    p_membership_id: departedMembership.relationship_id,
  });
  await rpc(carlo, "get_group_discussion_v2", {
    ...expected(carlo),
    p_room_id: room,
  });
  await rpc(bea, "get_group_discussion_v2", {
    ...expected(bea),
    p_room_id: room,
  });
  await rpc(second, "get_group_discussion_v2", {
    ...expected(second),
    p_room_id: room,
  });
  await rpc(alice, "send_group_discussion_message", {
    ...expected(alice),
    ...key(),
    p_room_id: room,
    p_body: "Fictional private planning message.",
  });
  for (let n = 0; n < 31; n++)
    await rpc(alice, "send_group_discussion_message", {
      ...expected(alice),
      ...key(),
      p_room_id: room,
      p_body: `Fictional planning page ${n}.`,
    });
  let proposal = await request(alice, room);
  equal(
    (await conversion(alice, room)).can_publish,
    false,
    "Ordinary creator can propose but cannot publish",
  );
  await denied(alice, "create_group_discussion_project_draft", {
    ...expected(alice),
    ...key(),
    p_room_id: room,
    p_expected_version: proposal.version,
  });
  await denied(bea, "create_group_discussion_project_draft", {
    ...expected(bea),
    ...key(),
    p_room_id: room,
    p_expected_version: proposal.version,
  });
  proposal = await rpc(bea, "review_group_discussion_publication", {
    ...expected(bea),
    ...key(),
    p_room_id: room,
    p_expected_version: proposal.version,
    p_endorse: true,
  });
  const draftArgs = {
    ...expected(carlo),
    ...key(),
    p_room_id: room,
    p_expected_version: proposal.version,
  };
  const otherDraftArgs = {
    ...expected(second),
    ...key(),
    p_room_id: room,
    p_expected_version: proposal.version,
  };
  const attempts = await Promise.all([
    carlo.client.rpc("create_group_discussion_project_draft", draftArgs),
    second.client.rpc("create_group_discussion_project_draft", otherDraftArgs),
  ]);
  equal(
    attempts.filter((a) => !a.error).length,
    1,
    "Two publishers create exactly one bound draft",
  );
  equal(
    attempts.filter((a) => a.error?.code === "PT409").length,
    1,
    "Losing publisher receives canonical conflict",
  );
  const publisher = attempts[0].error ? second : carlo;
  const project = attempts.find((a) => !a.error).data;
  equal(
    await rpc(
      publisher,
      "create_group_discussion_project_draft",
      attempts[0].error ? otherDraftArgs : draftArgs,
    ),
    project,
    "Lost draft reply recovers the same author's draft",
  );
  const own = await conversion(publisher, room);
  equal(own.project_id, project, "Actual publisher can recover its draft");
  equal(
    (await conversion(bea, room)).project_id,
    null,
    "Reviewer cannot discover actual author's private draft ID",
  );
  const [anchor] =
    await sql`select creator_profile_id,attributed_group_id from public.projects where id=${project}::uuid`;
  equal(
    anchor,
    { creator_profile_id: publisher.id, attributed_group_id: group },
    "Actual publisher remains real Project author",
  );
  equal(
    await counts(project),
    { memberships: 0, messages: 0 },
    "Pending draft creates no memberships or copied messages",
  );
  await rpc(alice, "send_group_discussion_message", {
    ...expected(alice),
    ...key(),
    p_room_id: room,
    p_body: "Still active while the private draft is pending.",
  });
  const [before] =
    await sql`select last_sequence,frozen_at from private.group_discussions where id=${room}::uuid`;
  equal(before.frozen_at, null, "Draft does not freeze source");
  // Supply the remaining sparse-draft fields that the real editor collects.
  await sql`update public.proposals set description='Fictional full publication description.',country_code='IT',locality='Trento' where id=${project}::uuid`;
  const binding = await rpc(publisher, "get_own_project_group", {
    ...expected(publisher),
    p_project_id: project,
  });
  await rpc(publisher, "set_project_group", {
    ...expected(publisher),
    ...key(),
    p_project_id: project,
    p_expected_version: binding.version,
    p_group_id: null,
  });
  await denied(
    publisher,
    "publish_proposal_idea",
    { p_expected_creator_profile_id: publisher.id, p_proposal_id: project },
    "PT409",
  );
  equal(
    (await conversion(publisher, room)).state,
    "draft",
    "Legacy personal publish cannot bypass conversion binding",
  );
  const cleared = await rpc(publisher, "get_own_project_group", {
    ...expected(publisher),
    p_project_id: project,
  });
  await rpc(publisher, "set_project_group", {
    ...expected(publisher),
    ...key(),
    p_project_id: project,
    p_expected_version: cleared.version,
    p_group_id: group,
  });
  // Archive is checked by the transactional trigger, even via the old API.
  await sql`update private.group_discussions set archived=true where id=${room}::uuid`;
  await denied(
    publisher,
    "publish_proposal_idea",
    { p_expected_creator_profile_id: publisher.id, p_proposal_id: project },
    "PT409",
  );
  await sql`update private.group_discussions set archived=false where id=${room}::uuid`;
  await publishAheadOfQueuedSend(publisher, alice, project, room);
  await rpc(publisher, "publish_proposal_idea", {
    p_expected_creator_profile_id: publisher.id,
    p_proposal_id: project,
  });
  const published = await conversion(alice, room);
  equal(
    published.state,
    "published",
    "Successful legacy publisher commits conversion",
  );
  equal(
    Number(published.frozen_sequence),
    Number(before.last_sequence) + 1,
    "Conversion marker commits after last planning message",
  );
  equal(
    published.project_chat_id,
    null,
    "Nonparticipating planner sees no Project chat preview",
  );
  equal(
    await counts(project),
    { memberships: 0, messages: 0 },
    "Successful conversion copies no messages and enrolls nobody",
  );
  await denied(
    alice,
    "send_group_discussion_message",
    {
      ...expected(alice),
      ...key(),
      p_room_id: room,
      p_body: "Must fail after freeze.",
    },
    "55000",
  );
  const invites = await rpc(
    alice,
    "list_my_discussion_project_invitations",
    expected(alice),
  );
  equal(
    invites.length,
    1,
    "Active original planner receives one durable invitation",
  );
  equal(
    Object.keys(invites[0]).sort(),
    ["created_at", "invitation_id", "project_id", "status", "summary", "title"],
    "Invitation exposes only public Project metadata",
  );
  const secondSource = await rpc(alice, "create_group_discussion_v2", {
    ...expected(alice),
    ...key(),
    p_group_id: group,
    p_title: "Fictional second planning source",
    p_purpose: "Separate public invitation pagination fixture.",
    p_visibility: "group",
  });
  let secondProposal = await request(alice, secondSource.room_id);
  secondProposal = await rpc(publisher, "review_group_discussion_publication", {
    ...expected(publisher),
    ...key(),
    p_room_id: secondSource.room_id,
    p_expected_version: secondProposal.version,
    p_endorse: true,
  });
  const secondProject = await rpc(
    publisher,
    "create_group_discussion_project_draft",
    {
      ...expected(publisher),
      ...key(),
      p_room_id: secondSource.room_id,
      p_expected_version: secondProposal.version,
    },
  );
  await sql`update public.proposals set description='Fictional second publication description.',country_code='IT',locality='Trento' where id=${secondProject}::uuid`;
  await rpc(publisher, "publish_proposal_idea", {
    p_expected_creator_profile_id: publisher.id,
    p_proposal_id: secondProject,
  });
  const firstInvitePage = await rpc(
    alice,
    "list_my_discussion_project_invitations",
    { ...expected(alice), p_limit: 1 },
  );
  const secondInvitePage = await rpc(
    alice,
    "list_my_discussion_project_invitations",
    {
      ...expected(alice),
      p_limit: 1,
      p_before_created_at: firstInvitePage[0].created_at,
      p_before_id: firstInvitePage[0].invitation_id,
    },
  );
  equal(
    secondInvitePage.length,
    1,
    "Durable Project invitations have a second bounded page",
  );
  equal(
    new Set([...firstInvitePage, ...secondInvitePage].map((i) => i.project_id))
      .size,
    2,
    "Invitation keyset pages are disjoint",
  );
  const secondInvite = [...firstInvitePage, ...secondInvitePage].find(
    (i) => i.project_id === secondProject,
  );
  await rpc(alice, "respond_discussion_project_invitation", {
    ...expected(alice),
    p_invitation_id: secondInvite.invitation_id,
    p_response: "declined",
  });
  equal(
    await rpc(bea, "list_my_discussion_project_invitations", expected(bea)),
    [],
    "Oversight-only manager is not an original planner",
  );
  equal(
    await rpc(diana, "get_project_discussion_origin", {
      ...expected(diana),
      p_project_id: project,
    }),
    null,
    "Public newcomer receives no private source route",
  );
  await denied(diana, "get_group_discussion_conversion", {
    ...expected(diana),
    p_room_id: room,
  });
  await rpc(alice, "respond_discussion_project_invitation", {
    ...expected(alice),
    p_invitation_id: invites[0].invitation_id,
    p_response: "opened",
  });
  equal(
    await counts(project),
    { memberships: 0, messages: 0 },
    "Opening invitation performs zero automatic admissions",
  );
  await rpc(alice, "respond_discussion_project_invitation", {
    ...expected(alice),
    p_invitation_id: invites[0].invitation_id,
    p_response: "declined",
  });
  await rpc(alice, "respond_discussion_project_invitation", {
    ...expected(alice),
    p_invitation_id: invites[0].invitation_id,
    p_response: "declined",
  });
  equal(
    await counts(project),
    { memberships: 0, messages: 0 },
    "Decline and retry preserve zero memberships",
  );
  equal(
    (await conversion(alice, room)).project_id,
    project,
    "Decline preserves entitled read-only source history",
  );
  equal(
    await rpc(alice, "list_my_discussion_project_invitations", expected(alice)),
    [],
    "Declined invitation is not reissued by publication retry",
  );
  const [invitationCount] =
    await sql`select count(*)::int n from private.group_discussion_project_invitations where room_id=${room}::uuid`;
  equal(
    invitationCount.n,
    1,
    "Durable source audience is deduplicated across publication retries",
  );
  equal(
    await rpc(
      departed,
      "list_my_discussion_project_invitations",
      expected(departed),
    ),
    [],
    "A planner who left before publication is outside the original active audience",
  );
  const plannerInvites = await rpc(
    planner,
    "list_my_discussion_project_invitations",
    expected(planner),
  );
  equal(
    plannerInvites.length,
    1,
    "Another explicit planner independently retrieves its invitation",
  );
  await rpc(planner, "respond_discussion_project_invitation", {
    ...expected(planner),
    p_invitation_id: plannerInvites[0].invitation_id,
    p_response: "opened",
  });
  equal(
    await counts(project),
    { memberships: 0, messages: 0 },
    "Every opened invitation still requires canonical Join",
  );
  for (const target of [planner, diana]) {
    const joinRequest = await rpc(target, "request_to_join_project", {
      p_expected_requester_profile_id: target.id,
      p_project_id: project,
      p_request_message: "Fictional deliberate participation.",
    });
    await rpc(publisher, "accept_project_join_request", {
      p_expected_creator_profile_id: publisher.id,
      p_request_id: joinRequest,
    });
  }
  equal(
    (await counts(project)).memberships,
    2,
    "Only the two deliberate canonical requests create membership",
  );
  const [chat] = await rpc(planner, "get_own_project_group_chat", {
    ...expected(planner),
    p_project_id: project,
  });
  for (let n = 0; n < 3; n++)
    await rpc(planner, "send_project_chat_message", {
      ...expected(planner),
      p_chat_id: chat.chat_id,
      p_body: `Public Project planning ${n}.`,
    });
  equal(
    (
      await rpc(planner, "get_project_discussion_origin", {
        ...expected(planner),
        p_project_id: project,
      })
    ).room_id,
    room,
    "Explicit planner who joins can open its independently protected source",
  );
  equal(
    await rpc(diana, "get_project_discussion_origin", {
      ...expected(diana),
      p_project_id: project,
    }),
    null,
    "Public Project membership never grants a private origin",
  );
  await denied(diana, "get_group_discussion_message_page_v2", {
    ...expected(diana),
    p_room_id: room,
  });
  const planningPage = await rpc(
    planner,
    "get_group_discussion_message_page_v2",
    { ...expected(planner), p_room_id: room, p_limit: 2 },
  );
  const olderPlanning = await rpc(
    planner,
    "get_group_discussion_message_page_v2",
    {
      ...expected(planner),
      p_room_id: room,
      p_limit: 2,
      p_before_sequence: planningPage.items.at(-1).sequence,
    },
  );
  equal(
    olderPlanning.items.length,
    2,
    "Protected frozen planning supports another page",
  );
  equal(
    olderPlanning.items.some((m) =>
      planningPage.items.some((p) => p.message_id === m.message_id),
    ),
    false,
    "Source history pages are disjoint",
  );
  const publicPage = await rpc(diana, "list_own_project_chat_messages", {
    ...expected(diana),
    p_chat_id: chat.chat_id,
    p_limit: 2,
  });
  const olderPublic = await rpc(diana, "list_own_project_chat_messages", {
    ...expected(diana),
    p_chat_id: chat.chat_id,
    p_limit: 2,
    p_before_created_at: publicPage.at(-1).created_at,
    p_before_message_id: publicPage.at(-1).message_id,
  });
  equal(
    olderPublic.length,
    1,
    "Public Project history has an independent second page",
  );
  equal(
    [...publicPage, ...olderPublic].some((m) =>
      m.body?.includes("Fictional private planning"),
    ),
    false,
    "Private planning is never copied into the public Project history",
  );
  const publisherAccess = await rpc(publisher, "get_group_discussion_v2", {
    ...expected(publisher),
    p_room_id: room,
  });
  const shareArgs = {
    ...expected(publisher),
    ...key(),
    p_room_id: room,
    p_project_id: project,
    p_expected_access_id: publisherAccess.access_id,
    p_link_id: sourceLink.object_id,
    p_expected_version: sourceLink.version,
  };
  const shared = await rpc(
    publisher,
    "share_discussion_link_to_project",
    shareArgs,
  );
  equal(
    await rpc(publisher, "share_discussion_link_to_project", shareArgs),
    shared,
    "Selected-link sharing recovers one canonical Project Add",
  );
  await denied(diana, "share_discussion_link_to_project", {
    ...shareArgs,
    ...expected(diana),
    ...key(),
  });
  console.log(
    `Discussion conversion Auth verifier passed: ${checks} assertions.`,
  );
} finally {
  await sql.end();
}
