import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Synthetic local actors only. Never print sessions, notes, provider payloads or
// keys. The CLI selects this checkout's task-owned disposable config.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    "Contact verification requires loopback endpoints.",
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
const bound = (person, params) => ({
  ...(params.p_expected_reporter_profile_id ||
  params.p_expected_blocker_profile_id ||
  params.p_expected_staff_profile_id
    ? {}
    : actor(person)),
  ...params,
});
async function call(person, name, params = {}) {
  const result = await person.client.rpc(name, bound(person, params));
  equal(
    result.error?.code ?? null,
    null,
    `${name} failed: ${result.error?.code ?? "none"}`,
  );
  return result.data;
}
async function denied(person, name, params, code = "42501") {
  const result = await person.client.rpc(name, bound(person, params));
  equal(result.error?.code, code, `${name} denial`);
}
async function user(label) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `d-coordination-${run}-${label}@planets.invalid`,
    verifierName: "group-coordination",
  });
  await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional D ${label}`})`;
  return person;
}
async function group(person, label) {
  const id = await call(person, "create_group_draft", {
    p_client_request_id: randomUUID(),
    p_content: {
      name: `Fictional D ${run} ${label}`,
      description: "A synthetic local collaboration group for verification.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await call(person, "set_group_publication_state", {
    p_group_id: id,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  return id;
}
async function grant(creator, person, groupId) {
  const [invitation] = await call(
    creator,
    "create_group_authority_invitation",
    {
      p_group_id: groupId,
      p_client_request_id: randomUUID(),
      p_role: "co_organizer",
    },
  );
  const [result] = await call(person, "accept_group_authority_invitation", {
    p_token: invitation.invite_token,
    p_client_request_id: randomUUID(),
  });
  return result.relationship_id;
}
async function asUser(tx, person, query) {
  await tx`select set_config('request.jwt.claim.sub',${person.id},true)`;
  await tx.unsafe("set local role authenticated");
  const result = await query(tx);
  await tx.unsafe("reset role");
  return result;
}
async function afterWait(groupId, rpcName, launch, transition) {
  let signal, release;
  const ready = new Promise((resolve) => {
    signal = resolve;
  });
  const proceed = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    await tx`select id from private.community_groups where id=${groupId}::uuid for update`;
    signal();
    await proceed;
    await transition(tx);
  });
  await ready;
  // PostgREST builders are lazy thenables: assimilate now so the HTTP request
  // actually starts while the independent transaction is holding its row lock.
  const pending = Promise.resolve(launch());
  try {
    let waiting = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      const [state] =
        await sql`select exists(select 1 from pg_stat_activity where pid<>pg_backend_pid() and wait_event_type='Lock' and query ilike ${`%${rpcName}%`}) waiting`;
      if (state.waiting) {
        waiting = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    equal(waiting, true, `observed ${rpcName} lock wait`);
  } finally {
    release();
  }
  await holder;
  return pending;
}

try {
  const alice = await user("alice"),
    bob = await user("bob"),
    carol = await user("carol"),
    dave = await user("dave"),
    erin = await user("erin"),
    outsider = await user("outsider");
  const a = await group(alice, "Garden"),
    b = await group(bob, "Workshop"),
    c = await group(erin, "Library"),
    d = await group(dave, "Orchard"),
    e = await group(erin, "Kitchen");
  const carolGrant = await grant(erin, carol, c);
  await grant(erin, carol, e);
  await sql`insert into private.group_memberships(group_id,profile_id,admitted_by) values(${c}::uuid,${carol.id}::uuid,${erin.id}::uuid),(${c}::uuid,${outsider.id}::uuid,${erin.id}::uuid)`;
  const submitted = await call(alice, "submit_group_contact_request", {
    p_action_id: randomUUID(),
    p_source_group_id: a,
    p_target_group_id: b,
    p_purpose: "collaboration",
    p_title: "Original private room",
    p_note: "Original private invitation",
  });
  const source = await call(bob, "accept_group_contact_request", {
    p_action_id: randomUUID(),
    p_request_id: submitted.request_id,
  });
  await call(bob, "send_group_contact_message", {
    p_action_id: randomUUID(),
    p_chat_id: source.chat_id,
    p_body: "Original protected history",
  });
  const propose = (groups = [c]) =>
    call(alice, "submit_group_coordination_proposal", {
      p_action_id: randomUUID(),
      p_source_chat_id: source.chat_id,
      p_group_ids: groups,
      p_title: "Fresh shared coordination",
      p_note: "Only this new invitation is shared.",
    });
  const exact = (person, id) =>
    call(person, "get_own_group_coordination_proposal", { p_proposal_id: id });
  const operation = (person, name, id, version, extra = {}) =>
    call(person, name, {
      p_action_id: randomUUID(),
      p_proposal_id: id,
      p_expected_version: version,
      ...extra,
    });
  const p = await propose([c, d]);
  const invite = await exact(carol, p.coordination_id);
  equal(invite.source_chat_id, null, "no source link for new invitee");
  equal(
    invite.audience,
    [],
    "original private affiliation withheld before consent",
  );
  equal(invite.chat_id, null, "pending proposal is not a conversation");
  await denied(outsider, "get_own_group_coordination_proposal", {
    p_proposal_id: p.coordination_id,
  });
  await denied(carol, "get_own_group_contact_feed", {
    p_chat_id: source.chat_id,
  });
  await operation(
    carol,
    "claim_group_coordination_seat",
    p.coordination_id,
    1,
    { p_group_id: c },
  );
  await operation(dave, "claim_group_coordination_seat", p.coordination_id, 2, {
    p_group_id: d,
  });
  await denied(
    carol,
    "confirm_group_coordination_audience",
    {
      p_action_id: randomUUID(),
      p_proposal_id: p.coordination_id,
      p_expected_version: 3,
    },
    "PT409",
  );
  await operation(
    alice,
    "confirm_group_coordination_audience",
    p.coordination_id,
    3,
  );
  await operation(
    bob,
    "confirm_group_coordination_audience",
    p.coordination_id,
    3,
  );
  equal(
    (await exact(carol, p.coordination_id)).audience.length,
    4,
    "full named audience only after both originals consent",
  );
  await operation(
    carol,
    "confirm_group_coordination_audience",
    p.coordination_id,
    3,
  );
  const finalIntent = {
    ...actor(dave),
    p_action_id: randomUUID(),
    p_proposal_id: p.coordination_id,
    p_expected_version: 3,
  };
  const activation = await Promise.all([
    Promise.resolve(
      dave.client.rpc("confirm_group_coordination_audience", finalIntent),
    ),
    Promise.resolve(
      dave.client.rpc("confirm_group_coordination_audience", finalIntent),
    ),
  ]);
  activation.forEach((r) =>
    equal(r.error, null, "simultaneous same-intent activation"),
  );
  equal(
    activation[0].data.chat_id,
    activation[1].data.chat_id,
    "one room after concurrent/lost final replies",
  );
  const room = activation[0].data.chat_id;
  equal(
    (await call(carol, "get_own_group_contact_feed", { p_chat_id: room }))
      .items,
    [],
    "fresh empty history",
  );
  equal(
    (
      await call(carol, "get_own_group_coordination_for_conversation", {
        p_chat_id: room,
      })
    ).source_chat_id,
    null,
    "fresh context has no unauthorized inherited source",
  );
  await denied(erin, "get_own_group_contact_conversation", { p_chat_id: room });
  await grant(erin, outsider, c);
  await denied(outsider, "get_own_group_contact_conversation", {
    p_chat_id: room,
  });
  equal(
    (
      await call(outsider, "list_own_scoped_conversation_items_v6", {
        p_scope: "groups",
        p_limit: 10,
      })
    ).some((r) => r.chat_id === room),
    false,
    "new manager inherits no room preview",
  );
  equal(
    (await call(outsider, "get_own_message_unread_summary_v2")).groups,
    0,
    "new manager inherits no unread",
  );
  equal(
    (await exact(erin, p.coordination_id)).request_message,
    null,
    "other current Creator minimal resolved triage",
  );
  equal(
    (await call(carol, "get_own_message_unread_summary_v2")).groups,
    0,
    "fresh summary/consent never fake unread",
  );
  // Equal-time incoming fixtures at the last admission frontier. The canonical
  // feed/report reads below use real independent Auth HTTP clients.
  await sql`insert into private.group_contact_messages(conversation_id,admission_id,sender_profile_id,represented_group_id,group_name_at_send,body,ordinal,created_at)
    select ${room}::uuid,(select id from private.group_contact_admissions where conversation_id=${room}::uuid and profile_id=${alice.id}::uuid),${alice.id}::uuid,${a}::uuid,g.name,'Synthetic equal-time human message '||n,n,
      (select max(admitted_at) from private.group_contact_admissions where conversation_id=${room}::uuid)
    from generate_series(1,30) n cross join private.community_groups g where g.id=${a}::uuid`;
  await sql`update private.group_contact_conversations set last_ordinal=30 where id=${room}::uuid`;
  let older = null,
    seenMessages = new Set(),
    readToken;
  do {
    const feed = await call(carol, "get_own_group_contact_feed", {
      p_chat_id: room,
      p_limit: 10,
      p_before_ordinal: older?.ordinal ?? null,
      p_before_id: older?.id ?? null,
    });
    if (!older) readToken = feed.read_boundary;
    else
      equal(
        feed.read_boundary,
        null,
        "older equal-time pages have no acknowledgement token",
      );
    for (const message of feed.items) {
      equal(
        seenMessages.has(message.id),
        false,
        "equal-time human pages have no duplicates",
      );
      seenMessages.add(message.id);
    }
    older = feed.items.length === 10 ? feed.items.at(-1) : null;
  } while (older);
  equal(
    seenMessages.size,
    30,
    "all equal-time messages recovered across explicit pages",
  );
  await call(carol, "acknowledge_group_contact_read", {
    p_chat_id: room,
    p_boundary: readToken,
  });
  const frontierFeed = await call(dave, "get_own_group_contact_feed", {
    p_chat_id: room,
    p_limit: 50,
  });
  await call(dave, "submit_moderation_report", {
    p_expected_reporter_profile_id: dave.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "Synthetic message at exact admission frontier.",
    p_target_kind: "group_contact_message",
    p_target_id: frontierFeed.items.at(-1).id,
  });
  const second = await propose([c, e]);
  await operation(
    carol,
    "claim_group_coordination_seat",
    second.coordination_id,
    1,
    { p_group_id: c },
  );
  await denied(carol, "claim_group_coordination_seat", {
    p_action_id: randomUUID(),
    p_proposal_id: second.coordination_id,
    p_expected_version: 2,
    p_group_id: e,
  });
  await operation(
    erin,
    "claim_group_coordination_seat",
    second.coordination_id,
    2,
    { p_group_id: e },
  );
  await operation(
    alice,
    "confirm_group_coordination_audience",
    second.coordination_id,
    3,
  );
  await operation(
    alice,
    "replace_group_coordination_targets",
    second.coordination_id,
    3,
    { p_group_ids: [d] },
  );
  equal(
    (await exact(alice, second.coordination_id)).own_confirmed,
    false,
    "changed groups invalidate original consent",
  );
  equal(
    (await exact(carol, second.coordination_id)).request_message,
    null,
    "removed invitee loses note/audience",
  );
  await denied(
    bob,
    "confirm_group_coordination_audience",
    {
      p_action_id: randomUUID(),
      p_proposal_id: second.coordination_id,
      p_expected_version: 3,
    },
    "PT409",
  );
  await call(alice, "cancel_group_coordination_proposal", {
    p_action_id: randomUUID(),
    p_proposal_id: second.coordination_id,
  });
  const third = await propose();
  await operation(
    carol,
    "claim_group_coordination_seat",
    third.coordination_id,
    1,
    { p_group_id: c },
  );
  await operation(
    alice,
    "confirm_group_coordination_audience",
    third.coordination_id,
    2,
  );
  await operation(
    bob,
    "confirm_group_coordination_audience",
    third.coordination_id,
    2,
  );
  const waiting = await afterWait(
    c,
    "confirm_group_coordination_audience",
    () =>
      carol.client.rpc("confirm_group_coordination_audience", {
        ...actor(carol),
        p_action_id: randomUUID(),
        p_proposal_id: third.coordination_id,
        p_expected_version: 2,
      }),
    (tx) =>
      tx`update private.group_delegates set revoked_at=clock_timestamp(),revoked_by=${erin.id}::uuid where id=${carolGrant}::uuid`,
  );
  equal(
    waiting.error?.code,
    "PT409",
    "observed revoke while final confirm waits prevents activation",
  );
  await denied(carol, "get_own_group_contact_feed", { p_chat_id: room });
  await grant(erin, carol, c);
  await denied(carol, "get_own_group_contact_feed", { p_chat_id: room });
  equal(
    (await exact(carol, third.coordination_id)).own_confirmed,
    false,
    "regrant cannot restore old consent",
  );
  equal(
    (await exact(carol, third.coordination_id)).audience,
    [],
    "regrant triage does not recover private named audience",
  );
  await operation(
    carol,
    "claim_group_coordination_seat",
    third.coordination_id,
    2,
    { p_group_id: c },
  );
  equal(
    (await exact(alice, third.coordination_id)).own_confirmed,
    false,
    "explicit replacement invalidates all confirmations",
  );
  const competitors = await Promise.all([
    Promise.resolve(
      carol.client.rpc("confirm_group_coordination_audience", {
        ...actor(carol),
        p_action_id: randomUUID(),
        p_proposal_id: third.coordination_id,
        p_expected_version: 3,
      }),
    ),
    Promise.resolve(
      alice.client.rpc("cancel_group_coordination_proposal", {
        ...actor(alice),
        p_action_id: randomUUID(),
        p_proposal_id: third.coordination_id,
      }),
    ),
  ]);
  equal(
    competitors[1].error,
    null,
    "safe cancel wins or follows a nonactivating confirmation",
  );
  equal(
    (await exact(alice, third.coordination_id)).status,
    "canceled",
    "finite cancellation leaves no staged composer",
  );
  const suspended = await propose([d]);
  await operation(
    dave,
    "claim_group_coordination_seat",
    suspended.coordination_id,
    1,
    { p_group_id: d },
  );
  await operation(
    alice,
    "confirm_group_coordination_audience",
    suspended.coordination_id,
    2,
  );
  await operation(
    bob,
    "confirm_group_coordination_audience",
    suspended.coordination_id,
    2,
  );
  const lifecycleWait = await afterWait(
    d,
    "confirm_group_coordination_audience",
    () =>
      dave.client.rpc("confirm_group_coordination_audience", {
        ...actor(dave),
        p_action_id: randomUUID(),
        p_proposal_id: suspended.coordination_id,
        p_expected_version: 2,
      }),
    (tx) =>
      tx`update private.community_groups set publication_state='archived' where id=${d}::uuid`,
  );
  equal(
    ["42501", "PT409"].includes(lifecycleWait.error?.code),
    true,
    "observed lifecycle loss while activation waits denies the command",
  );
  const [suspendedCount] =
    await sql`select count(*)::int count from private.group_contact_conversations where coordination_proposal_id=${suspended.coordination_id}::uuid`;
  equal(suspendedCount.count, 0, "lifecycle race creates no room");
  await call(alice, "cancel_group_coordination_proposal", {
    p_action_id: randomUUID(),
    p_proposal_id: suspended.coordination_id,
  });
  await sql`update private.community_groups set publication_state='published' where id=${d}::uuid`;
  const blocked = await propose();
  await exact(carol, blocked.coordination_id);
  await call(carol, "block_user", {
    p_expected_blocker_profile_id: carol.id,
    p_blocked_profile_id: alice.id,
  });
  equal(
    (await exact(alice, blocked.coordination_id)).status,
    "declined",
    "Block closes pending invitation without direction leak",
  );
  const report = await call(carol, "submit_moderation_report", {
    p_expected_reporter_profile_id: carol.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "Previously received synthetic invitation report.",
    p_target_kind: "group_coordination_proposal",
    p_target_id: blocked.coordination_id,
  });
  equal(report.length, 1, "known invitation can report after Block");
  // More than one page, identical activity times, including lower-ranked D01
  // rows. Administrative fixture construction only; reads are real Auth HTTP.
  await sql`insert into private.group_coordination_proposals(source_chat_id,initiator_id,title,note,status,ended_at,ended_by,activity_at)
    select ${source.chat_id}::uuid,${alice.id}::uuid,'Synthetic pagination','Synthetic note','canceled',clock_timestamp(),${alice.id}::uuid,'2026-10-14T00:00:00Z'::timestamptz from generate_series(1,55)`;
  let cursor = null,
    ids = new Set(),
    pages = 0;
  do {
    const rows = await call(
      alice,
      "list_own_structured_request_message_items_v3",
      {
        p_limit: 10,
        p_cursor_activity_at: cursor?.activity_at ?? null,
        p_cursor_item_kind: cursor?.item_kind ?? null,
        p_cursor_request_id: cursor?.proposal_id ?? cursor?.request_id ?? null,
      },
    );
    equal(rows.length <= 10, true, "server bounded page");
    for (const r of rows) {
      const key = r.proposal_id ?? r.request_id;
      equal(ids.has(key), false, "equal-time page has no duplicate");
      ids.add(key);
    }
    cursor = rows.length === 10 ? rows.at(-1) : null;
    pages++;
  } while (cursor && pages < 20);
  equal(pages > 5, true, "explicit multiple-page invitation recovery");
  equal(
    ids.has(submitted.request_id),
    true,
    "lower-ranked bilateral request survives union keyset boundaries",
  );
  const [counts] =
    await sql`select (select count(*) from private.group_contact_conversations where coordination_proposal_id=${p.coordination_id}::uuid)::int rooms,
    (select count(*) from private.group_contact_conversations where coordination_proposal_id=${third.coordination_id}::uuid)::int canceled_rooms`;
  equal(
    counts,
    { rooms: 1, canceled_rooms: 0 },
    "one role-bound room, no canceled activation",
  );
  const deniedDirect = await carol.client
    .schema("private")
    .from("group_coordination_seats")
    .select("*");
  equal(
    deniedDirect.error !== null,
    true,
    "private tables never exposed over REST",
  );
  console.log(
    `Group coordination: ${checks} real-Auth/PostgREST disclosure, consent, retry, version, block, pagination and observed-race checks passed.`,
  );
} finally {
  await sql.end();
}
