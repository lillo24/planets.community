import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

// Real local OTP + PostgREST and independently observed database lock races.
// Synthetic candidate only: this verifier does not approve the lifetime policy.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    "Member contact verification requires loopback endpoints.",
  );
}
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
function equal(actual, expected, label) {
  assert.deepEqual(actual, expected, label);
  checks++;
}
const actor = (person) => ({ p_expected_profile_id: person.id });
async function call(person, name, params = {}) {
  const result = await person.client.rpc(name, {
    ...(params.p_expected_reporter_profile_id ||
    params.p_expected_staff_profile_id ||
    params.p_expected_blocker_profile_id ||
    params.p_expected_creator_profile_id ||
    params.p_expected_requester_profile_id
      ? {}
      : actor(person)),
    ...params,
  });
  equal(
    result.error?.code ?? null,
    null,
    `${name} failed: ${result.error?.code ?? "none"}`,
  );
  return result.data;
}
async function denied(person, name, params, code = "42501") {
  const result = await person.client.rpc(name, { ...actor(person), ...params });
  equal(result.error?.code, code, `${name} denial`);
}
async function user(label) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `m-contact-${run}-${label}@planets.invalid`,
    verifierName: "member-contact",
  });
  await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional M ${label}`})`;
  return person;
}
async function group(owner, label) {
  const id = await call(owner, "create_group_draft", {
    p_client_request_id: randomUUID(),
    p_content: {
      name: `Fictional M ${run} ${label}`,
      description:
        "A synthetic local Group for private member consent verification.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await call(owner, "set_group_publication_state", {
    p_group_id: id,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  return id;
}
async function join(owner, person, groupId) {
  const [invitation] = await call(
    owner,
    "create_group_participant_invitation",
    { p_group_id: groupId, p_client_request_id: randomUUID() },
  );
  const [receipt] = await call(person, "accept_group_participant_invitation", {
    p_token: invitation.invite_token,
    p_client_request_id: randomUUID(),
  });
  return receipt.relationship_id;
}
async function delegate(owner, person, groupId) {
  const [invitation] = await call(owner, "create_group_authority_invitation", {
    p_group_id: groupId,
    p_client_request_id: randomUUID(),
    p_role: "co_organizer",
  });
  const [receipt] = await call(person, "accept_group_authority_invitation", {
    p_token: invitation.invite_token,
    p_client_request_id: randomUUID(),
  });
  return receipt.relationship_id;
}
async function request(
  sender,
  recipient,
  groupId,
  note = "A fictional personal introduction.",
) {
  return call(sender, "submit_member_contact_request", {
    p_action_id: randomUUID(),
    p_group_id: groupId,
    p_recipient_profile_id: recipient.id,
    p_note: note,
  });
}
async function accept(recipient, receipt, action = randomUUID()) {
  return call(recipient, "accept_member_contact_request", {
    p_action_id: action,
    p_request_id: receipt.request_id,
  });
}
async function send(sender, conversation, body, action = randomUUID()) {
  return call(sender, "send_member_contact_message", {
    p_action_id: action,
    p_chat_id: conversation.chat_id,
    p_episode_id: conversation.episode_id,
    p_body: body,
  });
}
async function afterGroupWait(groupId, rpcName, launch, transition) {
  let readySignal, release;
  const ready = new Promise((resolve) => {
    readySignal = resolve;
  });
  const proceed = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    await tx`select id from private.community_groups where id=${groupId}::uuid for update`;
    readySignal();
    await proceed;
    await transition(tx);
  });
  await ready;
  const pending = Promise.resolve(launch());
  try {
    let observed = false;
    for (let attempt = 0; attempt < 120; attempt++) {
      const [state] =
        await sql`select exists(select 1 from pg_stat_activity where pid<>pg_backend_pid() and wait_event_type='Lock' and query ilike ${`%${rpcName}%`}) waiting`;
      if (state.waiting) {
        observed = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    equal(
      observed,
      true,
      `${rpcName} independently observed waiting for canonical Group lock`,
    );
  } finally {
    release();
    await holder;
  }
  return pending;
}
async function blockAfterLegacyProjectWait(blocker, blocked, groupIds) {
  // These records use ordinary real-Auth commands. Only the held lock and the
  // independent NOWAIT observation use SQL; no synthetic Project state is injected.
  // The legacy Project publish/join gate requires photos; member contact above
  // deliberately runs without them and gains no new photo requirement.
  await ensureLocalProfilePhoto(blocked);
  await ensureLocalProfilePhoto(blocker);
  const projectId = await call(blocked, "create_proposal_draft", {
    p_expected_creator_profile_id: blocked.id,
    p_title: `Fictional M Block order ${run}`,
    p_summary: "Synthetic Project for observed Block lock ordering.",
    p_description:
      "A pending participation request must close before Group locks.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Fictional private meeting location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  await call(blocked, "publish_proposal", {
    p_expected_creator_profile_id: blocked.id,
    p_proposal_id: projectId,
  });
  const requestId = await call(blocker, "request_to_join_project", {
    p_expected_requester_profile_id: blocker.id,
    p_project_id: projectId,
    p_request_message: "A fictional pending request for the Block race.",
    p_skill_ids: [],
    p_resource_need_ids: [],
  });
  let readySignal, release, holderPid;
  const ready = new Promise((resolve) => {
    readySignal = resolve;
  });
  const proceed = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    [{ pid: holderPid }] = await tx`select pg_backend_pid() pid`;
    await tx`select id from public.proposals where id=${projectId}::uuid for update`;
    readySignal();
    await proceed;
  });
  // Surface lock-holder setup failures instead of waiting forever for readiness.
  await Promise.race([ready, holder]);
  const pending = Promise.resolve(
    blocker.client.rpc("block_user", {
      p_expected_blocker_profile_id: blocker.id,
      p_blocked_profile_id: blocked.id,
    }),
  );
  let result;
  try {
    let observed = false;
    for (let attempt = 0; attempt < 120; attempt++) {
      const [state] = await sql`select exists(select 1 from pg_stat_activity a
        where a.wait_event_type='Lock' and a.query ilike '%block_user%'
          and ${holderPid}::integer=any(pg_blocking_pids(a.pid))) waiting`;
      if (state.waiting) {
        observed = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    equal(
      observed,
      true,
      "real Block independently observed waiting on its legacy Project row",
    );
    await sql.begin(async (tx) => {
      const groups = await tx`select id from private.community_groups
        where id=any(${groupIds}::uuid[]) order by id for update nowait`;
      equal(
        groups.length,
        groupIds.length,
        "member origin Groups remain acquirable while Block waits for legacy Project closure",
      );
    });
  } finally {
    release();
    await holder;
    result = await pending;
  }
  equal(
    result.error?.code ?? null,
    null,
    "Block completes after the legacy row is released",
  );
  const [closed] =
    await sql`select status from public.project_join_requests where id=${requestId}::uuid`;
  equal(
    closed.status,
    "withdrawn",
    "Block preserves legacy pending Project convergence",
  );
}
try {
  const owner = await user("owner");
  const a = await user("a");
  const b = await user("b");
  const co = await user("co");
  const outsider = await user("outsider");
  const staff = await user("staff");
  const g1 = await group(owner, "one");
  const g2 = await group(owner, "two");
  const aMembership = await join(owner, a, g1);
  const bMembership = await join(owner, b, g1);
  await join(owner, a, g2);
  await join(owner, b, g2);
  const coGrant = await delegate(owner, co, g1);
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff.id}::uuid,'moderator')`;
  equal(
    (
      await call(a, "get_own_member_contact_context", {
        p_group_id: g1,
        p_recipient_profile_id: b.id,
      })
    ).can_request,
    true,
    "ordinary current people eligible",
  );
  for (const recipient of [a, outsider])
    await denied(a, "submit_member_contact_request", {
      p_action_id: randomUUID(),
      p_group_id: g1,
      p_recipient_profile_id: recipient.id,
    });
  await denied(a, "get_own_member_contact_context", {
    p_expected_profile_id: owner.id,
    p_group_id: g1,
    p_recipient_profile_id: b.id,
  });
  const action = randomUUID();
  const intent = {
    p_action_id: action,
    p_group_id: g1,
    p_recipient_profile_id: b.id,
    p_note: " A frozen fictional note ",
  };
  const initial = await call(a, "submit_member_contact_request", intent);
  const replay = await call(a, "submit_member_contact_request", intent);
  equal(
    replay.request_id,
    initial.request_id,
    "lost response recovers original request",
  );
  equal(replay.replayed, true, "replay marked honestly");
  await denied(
    a,
    "submit_member_contact_request",
    { ...intent, p_note: "A frozen fictional note" },
    "PT409",
  );
  await denied(
    b,
    "submit_member_contact_request",
    { p_action_id: randomUUID(), p_group_id: g1, p_recipient_profile_id: a.id },
    "PT409",
  );
  const [noProject] =
    await sql`select count(*)::int n from public.projects where creator_profile_id in(${a.id}::uuid,${b.id}::uuid)`;
  equal(noProject.n, 0, "personal request does not fabricate a Project");
  equal(
    (
      await call(a, "list_own_scoped_conversation_items_v7", {
        p_scope: "private",
        p_limit: 20,
      })
    ).length,
    0,
    "no free-form conversation before acceptance",
  );
  for (const observer of [owner, co, outsider, staff])
    await denied(observer, "get_own_member_contact_request", {
      p_request_id: initial.request_id,
    });
  const readRequest = await call(b, "get_own_member_contact_request", {
    p_request_id: initial.request_id,
  });
  equal(
    readRequest.request_message,
    "A frozen fictional note",
    "named recipient intentionally opens note",
  );
  const acceptanceAction = randomUUID();
  const accepted = await Promise.all([
    accept(b, initial, acceptanceAction),
    accept(b, initial, acceptanceAction),
  ]);
  equal(
    accepted[0].chat_id,
    accepted[1].chat_id,
    "concurrent exact accept creates one anchor",
  );
  equal(
    accepted[0].episode_id,
    accepted[1].episode_id,
    "concurrent exact accept creates one episode",
  );
  const conversation = accepted[0];
  for (const observer of [owner, co, outsider, staff])
    await denied(observer, "get_own_member_contact_feed", {
      p_chat_id: conversation.chat_id,
    });
  const messageAction = randomUUID();
  const first = await send(
    a,
    conversation,
    "First fictional personal message.",
    messageAction,
  );
  equal(
    (
      await send(
        a,
        conversation,
        "First fictional personal message.",
        messageAction,
      )
    ).message_id,
    first.message_id,
    "send lost response cannot duplicate body",
  );
  const feed = await call(b, "get_own_member_contact_feed", {
    p_chat_id: conversation.chat_id,
  });
  equal(feed.items.length, 1, "one committed human body");
  equal(
    (await call(b, "get_own_message_unread_summary_v3")).private,
    1,
    "incoming personal conversation unread",
  );
  equal(
    (await call(b, "get_own_message_unread_summary_v2")).private,
    0,
    "old unread excludes unsupported member kind",
  );
  equal(
    (
      await call(b, "list_own_structured_request_message_items_v3", {
        p_limit: 20,
      })
    ).length,
    0,
    "old Requests parse remains compatible",
  );
  equal(
    (
      await call(b, "list_own_scoped_conversation_items_v6", {
        p_scope: "private",
        p_limit: 20,
      })
    ).length,
    0,
    "old Chats parse remains compatible",
  );
  await call(b, "set_member_contact_muted", {
    p_action_id: randomUUID(),
    p_chat_id: conversation.chat_id,
    p_muted: true,
  });
  equal(
    (await call(b, "get_own_message_unread_summary_v3")).private,
    1,
    "mute does not acknowledge",
  );
  const [muted] =
    await sql`select private.member_contact_message_notice_allowed(${conversation.chat_id}::uuid,${b.id}::uuid) allowed`;
  equal(muted.allowed, false, "muted human notification suppressed");
  await call(b, "acknowledge_own_message_read_v3", {
    p_kind: "member_contact_chat",
    p_chat_id: conversation.chat_id,
    p_boundary: feed.read_boundary,
  });
  equal(
    (await call(b, "get_own_message_unread_summary_v3")).private,
    0,
    "foreground snapshot ACK durable",
  );

  // Losing membership while a delegate grant survives retains the union grant.
  const bGrant = await delegate(owner, b, g1);
  await call(b, "leave_group", {
    p_membership_id: bMembership,
    p_client_request_id: randomUUID(),
  });
  equal(
    (
      await call(b, "get_own_member_contact_conversation", {
        p_chat_id: conversation.chat_id,
      })
    ).is_read_only,
    false,
    "dual-role person remains eligible after member Leave",
  );
  const freshFeed = await call(b, "get_own_member_contact_feed", {
    p_chat_id: conversation.chat_id,
  });
  const racingSend = await afterGroupWait(
    g1,
    "send_member_contact_message",
    () =>
      a.client.rpc("send_member_contact_message", {
        ...actor(a),
        p_action_id: randomUUID(),
        p_chat_id: conversation.chat_id,
        p_episode_id: conversation.episode_id,
        p_body: "Must not survive context exit.",
      }),
    (tx) =>
      tx`update private.group_delegates set revoked_at=clock_timestamp(),revoked_by=${owner.id}::uuid where id=${bGrant}::uuid`,
  );
  equal(
    racingSend.error?.code,
    "PT409",
    "send rechecks episode after last relationship loss during wait",
  );
  const ended = await call(b, "get_own_member_contact_conversation", {
    p_chat_id: conversation.chat_id,
  });
  equal(
    ended.is_read_only,
    true,
    "former person retains bounded read-only history",
  );
  equal(ended.ended_reason, "context_ended", "context ending persisted");
  await denied(b, "acknowledge_member_contact_read", {
    p_chat_id: conversation.chat_id,
    p_boundary: freshFeed.read_boundary,
  });
  equal(
    (
      await call(b, "get_own_member_contact_feed", {
        p_chat_id: conversation.chat_id,
      })
    ).items.length,
    1,
    "racing forbidden send added no message",
  );
  const [report] = await call(b, "submit_moderation_report", {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_category: "spam",
    p_explanation: "A fictional historical message report.",
    p_target_kind: "member_contact_message",
    p_target_id: first.message_id,
    p_context_kind: "member_contact_chat",
    p_context_id: conversation.chat_id,
  });
  const evidence = await call(staff, "get_moderation_case_group_contact", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report.case_id,
  });
  equal(
    evidence.body,
    "First fictional personal message.",
    "staff exact case evidence survives former membership",
  );
  await denied(staff, "get_own_member_contact_feed", {
    p_chat_id: conversation.chat_id,
  });
  await join(owner, b, g1);
  await denied(
    a,
    "send_member_contact_message",
    {
      p_action_id: randomUUID(),
      p_chat_id: conversation.chat_id,
      p_episode_id: conversation.episode_id,
      p_body: "No silent revival.",
    },
    "PT409",
  );
  const reentry = await accept(b, await request(a, b, g1));
  equal(
    reentry.chat_id,
    conversation.chat_id,
    "explicit reconsent preserves canonical pair+origin anchor",
  );
  assert.notEqual(
    reentry.episode_id,
    conversation.episode_id,
    "explicit reconsent creates another episode",
  );
  checks++;
  await denied(
    a,
    "send_member_contact_message",
    {
      p_action_id: randomUUID(),
      p_chat_id: conversation.chat_id,
      p_episode_id: conversation.episode_id,
      p_body: "Old composer cannot target new episode.",
    },
    "PT409",
  );
  const other = await accept(b, await request(a, b, g2));
  assert.notEqual(
    other.chat_id,
    reentry.chat_id,
    "different origin stays independent",
  );
  checks++;
  equal(
    (await call(b, "get_own_member_contact_feed", { p_chat_id: other.chat_id }))
      .items.length,
    0,
    "other origin inherits no personal history",
  );

  // Simultaneous reversed requests are serialized at the canonical block pair.
  const reversed = await Promise.all([
    owner.client.rpc("submit_member_contact_request", {
      ...actor(owner),
      p_action_id: randomUUID(),
      p_group_id: g1,
      p_recipient_profile_id: co.id,
    }),
    co.client.rpc("submit_member_contact_request", {
      ...actor(co),
      p_action_id: randomUUID(),
      p_group_id: g1,
      p_recipient_profile_id: owner.id,
    }),
  ]);
  equal(
    reversed.filter((r) => !r.error).length,
    1,
    "one reversed request wins",
  );
  equal(
    reversed.find((r) => r.error)?.error.code,
    "PT409",
    "reverse loser is explicit conflict",
  );
  const winnerIndex = reversed.findIndex((r) => !r.error);
  const pending = reversed[winnerIndex].data;
  const pendingRecipient = winnerIndex === 0 ? co : owner;
  const recipientLeft = await afterGroupWait(
    g1,
    "accept_member_contact_request",
    () =>
      pendingRecipient.client.rpc("accept_member_contact_request", {
        ...actor(pendingRecipient),
        p_action_id: randomUUID(),
        p_request_id: pending.request_id,
      }),
    (tx) =>
      tx`update private.group_delegates set revoked_at=clock_timestamp(),revoked_by=${owner.id}::uuid where id=${coGrant}::uuid`,
  );
  equal(
    recipientLeft.error?.code,
    "PT409",
    "accept rechecks last relationship after wait",
  );
  const [notice] =
    await sql`select private.member_contact_notice_allowed(${pending.request_id}::uuid,${pendingRecipient.id}::uuid) allowed`;
  equal(notice.allowed, false, "queued note delivery stops at context loss");

  // Equal-time history fixture is explicitly synthetic; reads/ACK use real Auth.
  const tiedAt = "2026-10-15T00:00:00Z";
  await sql.begin(async (tx) => {
    const [pair] =
      await tx`update private.member_contact_pairs set last_ordinal=last_ordinal+6 where id=${reentry.chat_id}::uuid returning last_ordinal`;
    for (let n = 0; n < 6; n++) {
      const ordinal = Number(pair.last_ordinal) - 5 + n;
      await tx`insert into private.member_contact_messages(pair_id,episode_id,sender_profile_id,sender_display_name,body,ordinal,created_at)
        values(${reentry.chat_id}::uuid,${reentry.episode_id}::uuid,${a.id}::uuid,'Fictional M a',${`Tied synthetic message ${n}`},${ordinal},${tiedAt}::timestamptz)`;
      await tx`insert into private.member_contact_incoming values(${b.id}::uuid,${reentry.chat_id}::uuid,${ordinal})`;
    }
  });
  let page,
    before,
    seen = [];
  do {
    page = await call(b, "get_own_member_contact_feed", {
      p_chat_id: reentry.chat_id,
      p_limit: 2,
      p_before_ordinal: before?.ordinal ?? null,
      p_before_id: before?.id ?? null,
    });
    if (before)
      equal(page.read_boundary, null, "older history has no ACK frontier");
    seen.push(...page.items.map((item) => item.id));
    before = page.items.at(-1);
  } while (page.items.length === 2);
  equal(
    seen.length,
    7,
    "several tied-time pages preserve every authorized message",
  );
  equal(
    new Set(seen).size,
    seen.length,
    "stable ordinal tie breaker prevents duplicate history",
  );
  await blockAfterLegacyProjectWait(b, a, [g1, g2]);
  await denied(a, "send_member_contact_message", {
    p_action_id: randomUUID(),
    p_chat_id: reentry.chat_id,
    p_episode_id: reentry.episode_id,
    p_body: "Blocked send.",
  });
  equal(
    (
      await call(b, "get_own_member_contact_feed", {
        p_chat_id: reentry.chat_id,
      })
    ).items.length,
    7,
    "block preserves already-authorized history",
  );
  await call(a, "close_member_contact_conversation", {
    p_action_id: randomUUID(),
    p_chat_id: reentry.chat_id,
    p_episode_id: reentry.episode_id,
  });
  await call(b, "leave_member_contact_conversation", {
    p_action_id: randomUUID(),
    p_chat_id: other.chat_id,
    p_episode_id: other.episode_id,
  });
  equal(
    (
      await call(b, "get_own_member_contact_conversation", {
        p_chat_id: reentry.chat_id,
      })
    ).ended_reason,
    "closed",
    "Close available during block",
  );
  equal(
    (
      await call(a, "get_own_member_contact_conversation", {
        p_chat_id: other.chat_id,
      })
    ).ended_reason,
    "left",
    "Leave terminates consent without deleting history",
  );
  const [identifiers] =
    await sql`select count(*)::int n from private.outbox_events where event_type='member_contact.request_created' and payload-(array['request_id','recipient_profile_id'])<>'{}'::jsonb`;
  equal(identifiers.n, 0, "member outbox discloses identifiers only");
  const [retained] =
    await sql`select count(*)::int n from private.group_memberships where id=${aMembership}::uuid and ended_at is null`;
  equal(retained.n, 1, "conversation lifecycle never changes Group membership");
  console.log(
    `Member contact real Auth/PostgREST verification: ${checks} checks passed; observed lock waits; synthetic equal-time fixture identified separately.`,
  );
} finally {
  await sql.end();
}
