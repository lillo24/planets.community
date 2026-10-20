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
async function decide(person, operation, receipt, action = randomUUID()) {
  return call(person, `${operation}_member_contact_request`, {
    p_action_id: action,
    p_request_id: receipt.request_id,
  });
}
async function historicalRequest(sender, recipient, groupId, state, days) {
  // Explicit SQL time fixture: insert historical provenance without rewriting
  // immutable timestamps, disabling triggers, or claiming a client submission.
  await sql`insert into private.member_contact_pairs(group_id,low_profile_id,high_profile_id)
    values(${groupId}::uuid,least(${sender.id}::uuid,${recipient.id}::uuid),greatest(${sender.id}::uuid,${recipient.id}::uuid))
    on conflict(group_id,low_profile_id,high_profile_id) do nothing`;
  const [row] = await sql`insert into private.member_contact_requests(
      pair_id,sender_profile_id,recipient_profile_id,group_name,sender_display_name,recipient_display_name,
      note,status,created_at,activity_at,expires_at,resolved_at,resolved_by)
    select p.id,s.id,r.id,g.name,s.display_name,r.display_name,'Synthetic historical introduction.',${state},
      clock_timestamp()-${days.created}*interval '1 day',clock_timestamp()-${days.created}*interval '1 day',
      clock_timestamp()-${days.expired}*interval '1 day',
      case when ${state}='pending' then null else clock_timestamp()-${days.resolved ?? 0}*interval '1 day' end,
      case when ${state}='pending' then null else r.id end
    from private.member_contact_pairs p join private.community_groups g on g.id=p.group_id
      join public.profiles s on s.id=${sender.id}::uuid join public.profiles r on r.id=${recipient.id}::uuid
    where p.group_id=${groupId}::uuid and p.low_profile_id=least(s.id,r.id) and p.high_profile_id=greatest(s.id,r.id)
    returning id request_id,pair_id`;
  assert.ok(row, "Historical request fixture has its exact synthetic pair");
  return row;
}
async function verifyTerminalAndRateBoundaries(owner, groupId) {
  const sender = await user("bounds-sender");
  const recipient = await user("bounds-recipient");
  await join(owner, sender, groupId);
  await join(owner, recipient, groupId);
  const first = await request(sender, recipient, groupId);
  await denied(recipient, "withdraw_member_contact_request", {
    p_action_id: randomUUID(),
    p_request_id: first.request_id,
  });
  await denied(sender, "decline_member_contact_request", {
    p_action_id: randomUUID(),
    p_request_id: first.request_id,
  });
  const withdrawalAction = randomUUID();
  equal(
    (await decide(sender, "withdraw", first, withdrawalAction)).outcome,
    "withdrawn",
    "sender deliberately withdraws pending consent",
  );
  equal(
    (await decide(sender, "withdraw", first, withdrawalAction)).replayed,
    true,
    "lost Withdraw response replays the same decision",
  );
  const withdrawn = await call(recipient, "get_own_member_contact_request", {
    p_request_id: first.request_id,
  });
  equal(
    withdrawn.status,
    "withdrawn",
    "withdrawn request remains truthful metadata",
  );
  equal(
    withdrawn.request_message,
    null,
    "unseen withdrawn note is not newly disclosed",
  );
  await denied(
    recipient,
    "accept_member_contact_request",
    {
      p_action_id: randomUUID(),
      p_request_id: first.request_id,
    },
    "PT409",
  );
  const next = await request(sender, recipient, groupId);
  await call(recipient, "get_own_member_contact_request", {
    p_request_id: next.request_id,
  });
  const declineAction = randomUUID();
  equal(
    (await decide(recipient, "decline", next, declineAction)).outcome,
    "declined",
    "named recipient deliberately declines pending consent",
  );
  equal(
    (await decide(recipient, "decline", next, declineAction)).replayed,
    true,
    "lost Decline response replays the same decision",
  );
  await denied(
    recipient,
    "accept_member_contact_request",
    {
      p_action_id: randomUUID(),
      p_request_id: next.request_id,
    },
    "PT409",
  );
  for (const [from, to] of [
    [sender, recipient],
    [recipient, sender],
  ]) {
    equal(
      (
        await call(from, "get_own_member_contact_context", {
          p_group_id: groupId,
          p_recipient_profile_id: to.id,
        })
      ).can_request,
      false,
      "recent decline cooldown applies to both directions",
    );
    await denied(
      from,
      "submit_member_contact_request",
      {
        p_action_id: randomUUID(),
        p_group_id: groupId,
        p_recipient_profile_id: to.id,
      },
      "PT409",
    );
  }
  const expired = await historicalRequest(owner, sender, groupId, "pending", {
    created: 9,
    expired: 1,
  });
  const expiredView = await call(sender, "get_own_member_contact_request", {
    p_request_id: expired.request_id,
  });
  equal(
    expiredView.status,
    "expired",
    "deadline is enforced without a cleanup worker",
  );
  equal(expiredView.can_accept, false, "expired consent cannot be accepted");
  equal(
    expiredView.request_message,
    null,
    "unseen expired introduction remains private",
  );
  await denied(
    sender,
    "accept_member_contact_request",
    {
      p_action_id: randomUUID(),
      p_request_id: expired.request_id,
    },
    "PT409",
  );
  const replacement = await request(owner, sender, groupId);
  const [expiredStored] =
    await sql`select status from private.member_contact_requests where id=${expired.request_id}::uuid`;
  equal(
    expiredStored.status,
    "expired",
    "new deliberate request seals old expiry",
  );
  await decide(owner, "withdraw", replacement);
  await historicalRequest(owner, recipient, groupId, "declined", {
    created: 9,
    expired: 2,
    resolved: 8,
  });
  const afterCooldown = await request(owner, recipient, groupId);
  equal(
    afterCooldown.outcome,
    "requested",
    "elapsed decline cooldown permits fresh consent",
  );
  await decide(owner, "withdraw", afterCooldown);

  const [{ limits }] = await sql`select private.member_contact_limits() limits`;
  equal(
    {
      actor_daily: limits.actor_daily,
      messages_per_minute: limits.messages_per_minute,
    },
    { actor_daily: 20, messages_per_minute: 30 },
    "documented candidate operational bounds",
  );
  // SQL quota fixture contains resolved requests only. The last permitted request,
  // overflow, recovery and safe exits below all execute through real Auth.
  const [{ n: priorRequests }] =
    await sql`select count(*)::int n from private.member_contact_requests
    where sender_profile_id=${sender.id}::uuid and created_at>clock_timestamp()-interval '1 day'`;
  const requestPadding = limits.actor_daily - 1 - priorRequests;
  assert.ok(
    requestPadding >= 0,
    "Request fixture remains below the intended boundary",
  );
  await sql`insert into private.member_contact_requests(pair_id,sender_profile_id,recipient_profile_id,
      group_name,sender_display_name,recipient_display_name,status,resolved_at,resolved_by)
    select p.id,s.id,r.id,g.name,s.display_name,r.display_name,'withdrawn',clock_timestamp(),s.id
    from private.member_contact_pairs p join private.community_groups g on g.id=p.group_id
      join public.profiles s on s.id=${sender.id}::uuid join public.profiles r on r.id=${owner.id}::uuid
      cross join generate_series(1,${requestPadding}::integer)
    where p.id=${expired.pair_id}::uuid`;
  const lastRequest = await request(sender, owner, groupId);
  equal(
    lastRequest.outcome,
    "requested",
    "last request inside daily bound succeeds",
  );
  const overflowAction = randomUUID();
  await denied(
    sender,
    "submit_member_contact_request",
    {
      p_action_id: overflowAction,
      p_group_id: groupId,
      p_recipient_profile_id: owner.id,
    },
    "PT429",
  );
  equal(
    await call(sender, "recover_member_contact_action", {
      p_action_id: overflowAction,
    }),
    null,
    "rate rejection creates no success receipt",
  );
  await decide(sender, "withdraw", lastRequest);
  const recovered = await call(sender, "recover_member_contact_action", {
    p_action_id: withdrawalAction,
  });
  equal(
    recovered.request_id,
    first.request_id,
    "daily quota does not block historical recovery",
  );
  equal(
    recovered.current_status,
    "withdrawn",
    "recovery retains the terminal status",
  );
  const incoming = await request(owner, sender, groupId);
  await call(sender, "get_own_member_contact_request", {
    p_request_id: incoming.request_id,
  });
  const [noteReport] = await call(sender, "submit_moderation_report", {
    p_expected_reporter_profile_id: sender.id,
    p_client_submission_id: randomUUID(),
    p_category: "spam",
    p_explanation: "Synthetic report at the request bound.",
    p_target_kind: "member_contact_request",
    p_target_id: incoming.request_id,
  });
  assert.ok(
    noteReport.case_id,
    "Reporting remains available at the daily request bound",
  );
  await decide(sender, "decline", incoming);
  // Use another origin for sending; the preceding decline intentionally prevents
  // reopening the first origin before cooldown. The owner initiates fresh consent.
  const sendGroup = await group(owner, "rate-messages");
  await join(owner, sender, sendGroup);
  await denied(
    sender,
    "submit_member_contact_request",
    {
      p_action_id: randomUUID(),
      p_group_id: sendGroup,
      p_recipient_profile_id: owner.id,
    },
    "PT429",
  );
  const conversation = await accept(
    sender,
    await request(owner, sender, sendGroup),
  );
  const firstSendAction = randomUUID();
  const firstMessage = await send(
    sender,
    conversation,
    "First bounded message.",
    firstSendAction,
  );
  // Explicit SQL message-count fixture; does not claim these 28 historical writes
  // were client sends. Ordinals and genuine incoming edges remain consistent.
  await sql.begin(async (tx) => {
    const padding = limits.messages_per_minute - 2;
    const [{ last_ordinal: end }] = await tx`update private.member_contact_pairs
      set last_ordinal=last_ordinal+${padding} where id=${conversation.chat_id}::uuid returning last_ordinal`;
    await tx`insert into private.member_contact_messages(pair_id,episode_id,sender_profile_id,sender_display_name,body,ordinal)
      select ${conversation.chat_id}::uuid,${conversation.episode_id}::uuid,${sender.id}::uuid,p.display_name,
        'Synthetic rate-bound history.',n from public.profiles p cross join generate_series(${end - padding + 1}::bigint,${end}::bigint) n
      where p.id=${sender.id}::uuid`;
    await tx`insert into private.member_contact_incoming(profile_id,pair_id,ordinal)
      select ${owner.id}::uuid,${conversation.chat_id}::uuid,n from generate_series(${end - padding + 1}::bigint,${end}::bigint) n`;
  });
  equal(
    (await send(sender, conversation, "Last message inside minute bound."))
      .outcome,
    "sent",
    "last message inside minute bound succeeds",
  );
  await denied(
    sender,
    "send_member_contact_message",
    {
      p_action_id: randomUUID(),
      p_chat_id: conversation.chat_id,
      p_episode_id: conversation.episode_id,
      p_body: "Message over the minute bound.",
    },
    "PT429",
  );
  equal(
    (
      await send(
        sender,
        conversation,
        "First bounded message.",
        firstSendAction,
      )
    ).message_id,
    firstMessage.message_id,
    "send replay bypasses rate accounting without another body",
  );
  equal(
    (
      await call(sender, "recover_member_contact_action", {
        p_action_id: firstSendAction,
      })
    ).message_id,
    firstMessage.message_id,
    "receipt recovery remains available at both bounds",
  );
  const inbound = await send(
    owner,
    conversation,
    "Incoming message remains reportable at bounds.",
  );
  const feed = await call(sender, "get_own_member_contact_feed", {
    p_chat_id: conversation.chat_id,
  });
  await call(sender, "acknowledge_member_contact_read", {
    p_chat_id: conversation.chat_id,
    p_boundary: feed.read_boundary,
  });
  const [messageReport] = await call(sender, "submit_moderation_report", {
    p_expected_reporter_profile_id: sender.id,
    p_client_submission_id: randomUUID(),
    p_category: "spam",
    p_explanation: "Synthetic message report at both bounds.",
    p_target_kind: "member_contact_message",
    p_target_id: inbound.message_id,
    p_context_kind: "member_contact_chat",
    p_context_id: conversation.chat_id,
  });
  assert.ok(
    messageReport.case_id,
    "Message report remains available at both bounds",
  );
  await call(sender, "close_member_contact_conversation", {
    p_action_id: randomUUID(),
    p_chat_id: conversation.chat_id,
    p_episode_id: conversation.episode_id,
  });
  const fresh = await accept(sender, await request(owner, sender, sendGroup));
  await denied(
    sender,
    "send_member_contact_message",
    {
      p_action_id: randomUUID(),
      p_chat_id: fresh.chat_id,
      p_episode_id: fresh.episode_id,
      p_body: "New consent cannot reset the actor rate bound.",
    },
    "PT429",
  );
  await call(sender, "leave_member_contact_conversation", {
    p_action_id: randomUUID(),
    p_chat_id: fresh.chat_id,
    p_episode_id: fresh.episode_id,
  });
  const [{ n: sentCount }] =
    await sql`select count(*)::int n from private.member_contact_messages
    where pair_id=${conversation.chat_id}::uuid and sender_profile_id=${sender.id}::uuid`;
  equal(
    sentCount,
    limits.messages_per_minute,
    "quota rejection and replay add no extra human message",
  );
}
async function verifySyntheticAccountErasure(owner, staff, groupIds) {
  const erased = await user("erasure-only");
  for (const groupId of groupIds) await join(owner, erased, groupId);
  const requested = await request(erased, owner, groupIds[0]);
  const conversation = await accept(owner, requested);
  const message = await send(
    erased,
    conversation,
    "Synthetic history before account erasure.",
  );
  const replyAction = randomUUID();
  await send(owner, conversation, "Synthetic survivor reply.", replyAction);
  const before = await call(owner, "get_own_member_contact_feed", {
    p_chat_id: conversation.chat_id,
  });
  const pending = await request(erased, owner, groupIds[1]);
  await call(owner, "get_own_member_contact_request", {
    p_request_id: pending.request_id,
  });
  const provenance = () => sql`select
    (select count(*)::int from private.member_contact_pairs where ${erased.id}::uuid in(low_profile_id,high_profile_id)) pairs,
    (select count(*)::int from private.member_contact_requests where sender_profile_id=${erased.id}::uuid) requests,
    (select count(*)::int from private.member_contact_episodes where pair_id=${conversation.chat_id}::uuid) episodes,
    (select count(*)::int from private.member_contact_messages where pair_id=${conversation.chat_id}::uuid) messages,
    (select count(*)::int from private.member_contact_receipts where profile_id=${erased.id}::uuid) receipts`;
  const [prior] = await provenance();
  // There is no automated Plan 10 deletion RPC. Match the existing GRP erasure
  // verifiers, limited to this freshly created synthetic identity. Do not touch
  // audit/retention records, disable FKs, or claim hosted deletion/anonymization.
  await sql.begin(async (tx) => {
    const [identity] =
      await tx`select email from auth.users where id=${erased.id}::uuid for update`;
    equal(
      identity?.email,
      `m-contact-${run}-erasure-only@planets.invalid`,
      "erase only this run's dedicated synthetic account",
    );
    const profiles =
      await tx`delete from public.profiles where id=${erased.id}::uuid returning id`;
    equal(
      profiles.length,
      1,
      "synthetic profile erasure succeeds without new blockers",
    );
    const accounts =
      await tx`delete from auth.users where id=${erased.id}::uuid returning id`;
    equal(
      accounts.length,
      1,
      "synthetic Auth erasure succeeds without new blockers",
    );
  });
  equal(
    (await provenance())[0],
    prior,
    "account erasure retains member consent/message provenance",
  );
  for (const [name, params] of [
    ["get_own_member_contact_feed", { p_chat_id: conversation.chat_id }],
    ["get_own_member_contact_request", { p_request_id: pending.request_id }],
    ["recover_member_contact_action", { p_action_id: randomUUID() }],
  ])
    await denied(erased, name, params);
  const signal = await erased.client.rpc("can_receive_member_contact_signal", {
    p_topic: `member-contact:profile:${erased.id}`,
  });
  equal(signal.error, null, "old token reaches the canonical signal predicate");
  equal(
    signal.data,
    false,
    "erased account's old token cannot subscribe to member hints",
  );
  const ended = await call(owner, "get_own_member_contact_conversation", {
    p_chat_id: conversation.chat_id,
  });
  equal(
    ended.is_read_only,
    true,
    "surviving peer retains only read-only history",
  );
  equal(
    ended.ended_reason,
    "context_ended",
    "account loss permanently seals the episode",
  );
  await denied(
    owner,
    "send_member_contact_message",
    {
      p_action_id: randomUUID(),
      p_chat_id: conversation.chat_id,
      p_episode_id: conversation.episode_id,
      p_body: "No send after account erasure.",
    },
    "PT409",
  );
  await denied(owner, "submit_member_contact_request", {
    p_action_id: randomUUID(),
    p_group_id: groupIds[0],
    p_recipient_profile_id: erased.id,
  });
  await denied(owner, "acknowledge_member_contact_read", {
    p_chat_id: conversation.chat_id,
    p_boundary: before.read_boundary,
  });
  equal(
    (
      await call(owner, "get_own_member_contact_feed", {
        p_chat_id: conversation.chat_id,
      })
    ).items,
    before.items,
    "erasure does not broaden or remove the survivor's prior authorized history",
  );
  const unavailable = await call(owner, "get_own_member_contact_request", {
    p_request_id: pending.request_id,
  });
  equal(
    unavailable.status,
    "unavailable",
    "pending consent invalidates on account erasure",
  );
  equal(
    unavailable.can_accept,
    false,
    "erased requester cannot obtain later acceptance",
  );
  await denied(
    owner,
    "accept_member_contact_request",
    {
      p_action_id: randomUUID(),
      p_request_id: pending.request_id,
    },
    "PT409",
  );
  const [notices] = await sql`select
    private.member_contact_notice_allowed(${pending.request_id}::uuid,${owner.id}::uuid) request_allowed,
    private.member_contact_message_notice_allowed(${conversation.chat_id}::uuid,${owner.id}::uuid) message_allowed`;
  equal(
    notices,
    { request_allowed: false, message_allowed: false },
    "erasure suppresses request and message notices",
  );
  equal(
    (
      await call(owner, "recover_member_contact_action", {
        p_action_id: replyAction,
      })
    ).current_status,
    "read_only",
    "survivor receipt recovery rechecks current erasure state",
  );
  for (const [kind, id, context] of [
    ["member_contact_request", pending.request_id, {}],
    [
      "member_contact_message",
      message.message_id,
      {
        p_context_kind: "member_contact_chat",
        p_context_id: conversation.chat_id,
      },
    ],
  ]) {
    const [report] = await call(owner, "submit_moderation_report", {
      p_expected_reporter_profile_id: owner.id,
      p_client_submission_id: randomUUID(),
      p_category: "spam",
      p_explanation: "Synthetic known content after account erasure.",
      p_target_kind: kind,
      p_target_id: id,
      ...context,
    });
    assert.ok(
      report.case_id,
      "Previously authorized content remains reportable after erasure",
    );
    const evidence = await call(staff, "get_moderation_case_group_contact", {
      p_expected_staff_profile_id: staff.id,
      p_case_id: report.case_id,
    });
    equal(
      evidence.target_id,
      id,
      "post-erasure report retains its exact known target",
    );
    equal(
      evidence.body,
      kind === "member_contact_request"
        ? "A fictional personal introduction."
        : "Synthetic history before account erasure.",
      "post-erasure case evidence preserves only the reported content",
    );
    const [reportCase] =
      await sql`select subject_profile_id from private.moderation_cases where id=${report.case_id}::uuid`;
    equal(
      reportCase.subject_profile_id,
      null,
      "post-erasure report does not invent a live subject identity",
    );
  }
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
  await verifyTerminalAndRateBoundaries(owner, g1);
  await verifySyntheticAccountErasure(owner, staff, [g1, g2]);
  console.log(
    `Member contact real Auth/PostgREST verification: ${checks} checks passed; observed lock waits; explicit synthetic time/rate fixtures and scoped account erasure.`,
  );
} finally {
  await sql.end();
}
