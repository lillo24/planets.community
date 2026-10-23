import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { setTimeout as pause } from "node:timers/promises";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// One continuous journey with real local OTP identities. No service-role client
// performs a product action; SQL only owns synthetic setup and account controls.
const { sql, status } = openCocreateLocalBackend();
const run = randomUUID().slice(0, 8),
  topic = randomUUID(),
  hub = randomUUID(),
  otherHub = randomUUID();
let checks = 0,
  channel,
  subscriber;
const equal = (actual, expected, label) => {
  assert.deepEqual(actual, expected, label);
  checks++;
};
const actor = (u) => ({ p_expected_profile_id: u.id });
async function rpc(u, name, args) {
  const r = await u.client.rpc(name, args);
  equal(
    r.error?.code ?? null,
    null,
    `${name}: ${r.error?.message ?? "succeeds"}`,
  );
  return r.data;
}
async function denied(u, name, args, code = "42501") {
  const r = await u.client.rpc(name, args);
  equal(r.error?.code, code, `${name} denies`);
}
async function person(name) {
  const email = `cocreate-programme-${run}-${name}@planets.invalid`;
  const u = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email,
    verifierName: "cocreate-programme",
  });
  await sql`insert into public.profiles(id,display_name) values(${u.id}::uuid,${"Synthetic programme " + name})`;
  await rpc(u, "accept_policy_bundle", {
    p_expected_account_id: u.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return { ...u, email };
}
const joinHub = (u, id = hub) =>
  rpc(u, "mutate_cocreate_hub", {
    ...actor(u),
    p_command_id: randomUUID(),
    p_hub_id: id,
    p_operation: "join",
  });
const groupArgs = (u, op, extra = {}) => ({
  ...actor(u),
  p_command_id: randomUUID(),
  p_hub_id: hub,
  p_operation: op,
  ...extra,
});
const group = (u, op, extra = {}) =>
  rpc(u, "mutate_cocreate_numbered_group", groupArgs(u, op, extra));
const scope = (u, ep) => ({
  ...actor(u),
  p_room_id: ep.room_id,
  p_episode_id: ep.episode_id,
});
const page = (u, ep) => rpc(u, "get_cocreate_room_page_v2", scope(u, ep));
const send = (u, ep, body) =>
  rpc(u, "send_cocreate_room_message", {
    ...scope(u, ep),
    p_command_id: randomUUID(),
    p_body: body,
  });
const summary = (u) =>
  rpc(u, "get_own_message_unread_summary_with_cocreate", actor(u));
const context = (u, ep) =>
  rpc(u, "get_cocreate_numbered_context", { ...scope(u, ep), p_hub_id: hub });
const ack = (u, ep, feed) =>
  rpc(u, "acknowledge_cocreate_room", {
    ...scope(u, ep),
    p_read_token: feed.read_token,
  });
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts OFF",
  );
  await sql`insert into private.cocreate_topics(id,label,active) values(${topic}::uuid,${"Synthetic integrated " + run},true)`;
  for (const id of [hub, otherHub])
    await sql`insert into private.cocreate_hubs(id,topic_id,locality,active) values(${id}::uuid,${topic}::uuid,${"Synthetic journey " + id},true)`;
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("author"),
    b = await person("requester"),
    c = await person("race-c"),
    d = await person("race-d"),
    staff = await person("staff");
  const post = await rpc(a, "mutate_cocreate_post", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_operation: "create",
    p_content: {
      title: "Synthetic integrated journey",
      body: "Public invitation only",
      locality: "Trento",
      topic_id: topic,
    },
  });
  await rpc(a, "mutate_cocreate_post", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: post.post_id,
    p_expected_version: post.version,
    p_operation: "publish",
  });
  const interest = await rpc(b, "mutate_cocreate_interest", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_post_id: post.post_id,
    p_operation: "request",
    p_note: "Private synthetic interest",
  });
  const accepted = await rpc(a, "mutate_cocreate_interest", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: post.post_id,
    p_operation: "accept",
    p_interest_id: interest.interest_id,
  });
  const contact = { ...actor(b), p_contact_id: accepted.contact_id };
  await rpc(a, "mutate_cocreate_contact", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_contact_id: accepted.contact_id,
    p_operation: "send",
    p_body: "Private synthetic contact",
  });
  equal((await summary(b)).private, 1, "Accepted contact contributes once");
  await denied(c, "get_cocreate_contact_page", {
    ...actor(c),
    p_contact_id: accepted.contact_id,
  });
  const hubA = await joinHub(a),
    hubB = await joinHub(b);
  const small = await group(a, "create", { p_capacity: 3 });
  const earlier = await send(a, small, "Earlier numbered history");
  await rpc(a, "mutate_cocreate_post_group", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: post.post_id,
    p_expected_version: 2,
    p_operation: "link",
    p_hub_id: hub,
    p_room_id: small.room_id,
    p_episode_id: small.episode_id,
  });
  equal(
    (await rpc(b, "get_cocreate_contact_group", contact)).link.group.room_id,
    small.room_id,
    "Accepted source points at canonical group",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes where actor_id=${b.id}::uuid and room_id=${small.room_id}::uuid`
    )[0].n,
    0,
    "Source review never enrolls",
  );
  const joinIntent = groupArgs(b, "join", { p_room_id: small.room_id });
  const member = await rpc(b, "mutate_cocreate_numbered_group", joinIntent);
  equal(
    (await page(b, member)).messages.some(
      (m) => m.message_id === earlier.message_id,
    ),
    true,
    "Explicit admission grants disclosed earlier history",
  );
  equal(
    (await summary(b)).groups,
    0,
    "Earlier history is not fabricated unread",
  );
  await send(a, hubA, "Incoming General human");
  await send(a, small, "Incoming child human");
  const card = await rpc(a, "mutate_cocreate_recruitment", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_room_id: small.room_id,
    p_episode_id: small.episode_id,
    p_operation: "post",
  });
  equal(
    (await summary(b)).groups,
    2,
    "General and child each count once; structured card adds no human unread",
  );
  await rpc(b, "list_cocreate_room_people", scope(b, member));
  const generalFeed = await page(b, hubB),
    childFeed = await page(b, member);
  equal((await summary(b)).groups, 2, "Preview/People do not ACK");
  await ack(b, hubB, generalFeed);
  equal(
    (await summary(b)).groups,
    1,
    "Rendered General frontier clears only General",
  );
  await group(b, "mute", {
    p_room_id: small.room_id,
    p_episode_id: member.episode_id,
    p_muted: true,
  });
  equal((await summary(b)).groups, 1, "Mute is not ACK");
  await ack(b, member, childFeed);
  const contactFeed = await rpc(b, "get_cocreate_contact_page", contact);
  await rpc(b, "acknowledge_cocreate_contact", {
    ...contact,
    p_read_token: contactFeed.read_token,
  });
  equal(
    (await summary(b)).private,
    0,
    "Only explicit contact frontier clears private unread",
  );
  await joinHub(c);
  await joinHub(d);
  const race = await Promise.all(
    [c, d].map((u) =>
      u.client.rpc("join_cocreate_recruitment", {
        ...actor(u),
        p_command_id: randomUUID(),
        p_hub_id: hub,
        p_room_id: small.room_id,
        p_recruitment_id: card.recruitment_id,
      }),
    ),
  );
  equal(race.filter((r) => r.error === null).length, 1, "One last-seat winner");
  equal(
    race.filter((r) => r.error?.code === "PT409").length,
    1,
    "One explicit full loser",
  );
  equal(
    (await rpc(a, "get_cocreate_numbered_group", { p_room_id: small.room_id }))
      .occupied,
    3,
    "Creator counts; capacity never exceeded",
  );
  await send(a, small, "Full groups remain live");
  await group(b, "leave", {
    p_room_id: small.room_id,
    p_episode_id: member.episode_id,
  });
  const frozen = await page(b, member);
  const later = await send(a, small, "Later private numbered secret");
  equal(
    (await page(b, member)).messages.map((m) => m.message_id),
    frozen.messages.map((m) => m.message_id),
    "Leave freezes sequence",
  );
  let member2 = await group(b, "join", { p_room_id: small.room_id });
  equal(
    member2.episode_id === member.episode_id,
    false,
    "Rejoin has new episode",
  );
  await denied(b, "acknowledge_cocreate_room", {
    ...scope(b, member2),
    p_read_token: frozen.read_token,
  });
  equal(
    (await page(b, member2)).messages.some(
      (m) => m.message_id === later.message_id,
    ),
    true,
    "Fresh admission grants new disclosed history",
  );
  let managed = await context(a, small);
  await group(a, "remove", {
    p_room_id: small.room_id,
    p_episode_id: small.episode_id,
    p_target_profile_id: b.id,
    p_expected_version: managed.version,
  });
  await denied(
    b,
    "mutate_cocreate_numbered_group",
    groupArgs(b, "join", { p_room_id: small.room_id }),
  );
  equal(
    await rpc(b, "mutate_cocreate_numbered_group", joinIntent),
    member,
    "Old receipt is identifier acknowledgement only",
  );
  equal(
    (
      await rpc(b, "get_own_cocreate_numbered_membership", {
        ...actor(b),
        p_room_id: small.room_id,
      })
    ).active,
    false,
    "Retry grants no current access",
  );
  managed = await context(a, small);
  await group(a, "restore_member", {
    p_room_id: small.room_id,
    p_episode_id: small.episode_id,
    p_target_profile_id: b.id,
    p_expected_version: managed.version,
  });
  equal(
    (
      await rpc(b, "get_own_cocreate_numbered_membership", {
        ...actor(b),
        p_room_id: small.room_id,
      })
    ).active,
    false,
    "Reversal does not enroll",
  );
  member2 = await group(b, "join", { p_room_id: small.room_id });
  equal(
    (await rpc(b, "list_own_cocreate_rooms_v2", actor(b))).filter(
      (r) => r.room_id === small.room_id,
    ).length,
    1,
    "Messages shows latest episode once",
  );
  const report = await rpc(b, "submit_cocreate_room_report", {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_target_id: earlier.message_id,
    p_category: "other",
    p_explanation: "Synthetic exact integrated evidence",
  });
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff.id}::uuid,'moderator')`;
  const evidence = await rpc(staff, "get_moderation_case_cocreate_room", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report[0].case_id,
  });
  equal(
    evidence.evidence.message_id,
    earlier.message_id,
    "Staff receive exact reported evidence",
  );
  await denied(staff, "get_cocreate_room_page_v2", scope(staff, small));
  const moderation = {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report[0].case_id,
  };
  const suppressed = await rpc(staff, "moderate_cocreate_numbered_group", {
    ...moderation,
    p_command_id: randomUUID(),
    p_expected_version: evidence.room_version,
    p_operation: "suppress",
  });
  await denied(b, "get_cocreate_room_page_v2", scope(b, member2));
  await rpc(staff, "moderate_cocreate_numbered_group", {
    ...moderation,
    p_command_id: randomUUID(),
    p_expected_version: suppressed.version,
    p_operation: "restore",
  });
  const otherGeneral = await joinHub(b, otherHub);
  await rpc(b, "block_user", {
    p_expected_blocker_profile_id: b.id,
    p_blocked_profile_id: a.id,
  });
  await denied(b, "get_cocreate_contact_page", contact);
  equal(
    (await page(b, member2)).messages.length > 0,
    true,
    "Blocking denies direct contact while preserving canonical shared-room policy",
  );
  await rpc(b, "unblock_user", {
    p_expected_blocker_profile_id: b.id,
    p_blocked_profile_id: a.id,
  });
  const other = await group(b, "create", { p_hub_id: otherHub });
  const signals = [];
  const socketStates = [];
  subscriber = b;
  await b.client.realtime.setAuth();
  channel = b.client
    .channel(`cocreate:profile:${b.id}`, { config: { private: true } })
    .on("broadcast", { event: "cocreate.changed" }, (event) =>
      signals.push(event.payload),
    );
  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("Owned realtime subscription timed out")),
      15000,
    );
    channel.subscribe((state) => {
      socketStates.push(state);
      if (state === "SUBSCRIBED") {
        clearTimeout(timer);
        resolve();
      } else if (["CHANNEL_ERROR", "TIMED_OUT"].includes(state)) {
        clearTimeout(timer);
        reject(new Error(`Owned realtime ${state}`));
      }
    });
  });
  // The pinned local Realtime server can acknowledge a channel while its idle
  // tenant broadcast handler is reconnecting. Warm only transport with actor-ID
  // hints, then require the delivery UUID queued by the one genuine product write.
  // No authorization, message receipt or unread assertion uses these probes.
  for (let i = 0; i < 50 && signals.length === 0; i++) {
    await sql`select private.cocreate_signal(${b.id}::uuid)`;
    await pause(100);
  }
  equal(signals.length > 0, true, "Owned broadcast transport becomes ready");
  signals.length = 0;
  const beforeHints =
    await sql`select payload->>'id' id from realtime.messages where topic=${"cocreate:profile:" + b.id}`;
  await send(a, small, "Retained socket current member signal");
  // realtime.send owns a PL/pgSQL subtransaction, so its xmin need not equal
  // the immutable human message's xmin. This unique actor is exclusively owned
  // by this serial fixture: only the one awaited product write occurs between
  // the delivery-ID snapshots. Transport probes have all committed beforehand.
  const queued =
    await sql`select payload from realtime.messages where topic=${"cocreate:profile:" + b.id}
    and event='cocreate.changed' and not((payload->>'id')=any(${beforeHints.map((r) => r.id)}::text[]))`;
  equal(
    queued.length,
    1,
    "Product message queues exactly one current-recipient hint",
  );
  const productHint = queued[0].payload.id;
  equal(
    typeof productHint,
    "string",
    "Pinned transport attaches its delivery UUID",
  );
  for (let i = 0; i < 50 && !signals.some((s) => s.id === productHint); i++)
    await pause(100);
  equal(
    signals.some((s) => s.id === productHint),
    true,
    "Genuine current-member socket receives invalidation",
  );
  for (const signal of signals) {
    equal(signal.profile_id, b.id, "Signal recipient bound");
    equal(
      Object.keys(signal)
        .filter((k) => k !== "id")
        .sort(),
      ["profile_id"],
      "Signal carries no body, room, roster or count",
    );
  }
  // Close this independent contact before testing absence of future hub hints.
  await rpc(b, "mutate_cocreate_contact", {
    ...contact,
    p_command_id: randomUUID(),
    p_operation: "close",
  });
  await rpc(b, "mutate_cocreate_hub", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "leave",
    p_episode_id: hubB.episode_id,
  });
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id where e.actor_id=${b.id}::uuid and r.hub_id=${hub}::uuid and e.ended_at is null`
    )[0].n,
    0,
    "Atomic hub exit ends every child",
  );
  equal(
    (
      await rpc(b, "get_own_cocreate_numbered_membership", {
        ...actor(b),
        p_room_id: other.room_id,
      })
    ).active,
    true,
    "Other hub untouched",
  );
  await pause(1500);
  signals.length = 0;
  const frozenExit = await page(b, member2);
  const resized = await context(a, small);
  await group(a, "capacity", {
    p_room_id: small.room_id,
    p_episode_id: small.episode_id,
    p_expected_version: resized.version,
    p_capacity: 4,
  });
  await send(a, small, "Retained socket must not see later body or hint");
  await send(a, hubA, "Later General must not hint departed actor");
  await pause(1500);
  equal(signals.length, 0, "Retained socket gets no departed-room activity");
  equal(
    socketStates.every((state) => state === "SUBSCRIBED"),
    true,
    "Negative activity assertion used the same continuously subscribed socket",
  );
  const beforeAlive =
    await sql`select payload->>'id' id from realtime.messages where topic=${"cocreate:profile:" + b.id}`;
  await sql`select private.cocreate_signal(${b.id}::uuid)`;
  const aliveHints =
    await sql`select payload->>'id' id from realtime.messages where topic=${"cocreate:profile:" + b.id}
    and not((payload->>'id')=any(${beforeAlive.map((r) => r.id)}::text[]))`;
  equal(aliveHints.length, 1, "Actor-only liveness probe has one delivery ID");
  const aliveId = aliveHints[0].id;
  for (let i = 0; i < 50 && !signals.some((s) => s.id === aliveId); i++)
    await pause(100);
  equal(
    signals.some((s) => s.id === aliveId),
    true,
    "Retained actor socket remains live for its independent contexts",
  );
  equal(
    (await page(b, member2)).messages.map((m) => m.message_id),
    frozenExit.messages.map((m) => m.message_id),
    "Retained HTTP episode remains frozen",
  );
  await denied(b, "list_cocreate_room_people", scope(b, member2));
  await b.client.removeChannel(channel);
  channel = null;
  const draftIntent = {
    ...scope(a, small),
    p_hub_id: hub,
    p_command_id: randomUUID(),
  };
  const draft = await rpc(a, "create_cocreate_project_draft", draftIntent);
  equal(
    (
      await sql`select title,summary,description,locality from public.proposals where id=${draft.proposal_id}::uuid`
    )[0],
    { title: null, summary: null, description: null, locality: null },
    "Native personal draft copies no private content",
  );
  await sql`update auth.users set banned_until=clock_timestamp()+interval '1 hour' where id=${a.id}::uuid and email=${a.email}`;
  await denied(a, "get_cocreate_room_page_v2", scope(a, small));
  await sql`update auth.users set banned_until=null where id=${a.id}::uuid and email=${a.email}`;
  equal(
    (await rpc(a, "get_cocreate_numbered_group", { p_room_id: small.room_id }))
      .occupied,
    2,
    "Temporary suspension preserves seats",
  );
  await rpc(a, "mutate_cocreate_hub", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "leave",
    p_episode_id: hubA.episode_id,
  });
  equal(
    await rpc(a, "create_cocreate_project_draft", draftIntent),
    draft,
    "Departed creator recovers existing personal draft only",
  );
  equal(
    await rpc(c, "get_cocreate_numbered_group", { p_room_id: small.room_id }),
    null,
    "Creator hub departure archives orphan",
  );
  const erased = await person("erasure");
  await joinHub(erased);
  const erasedRoom = await group(erased, "create");
  await sql`delete from public.profiles where id=${erased.id}::uuid and exists(select 1 from auth.users where id=${erased.id}::uuid and email=${erased.email})`;
  await sql`delete from auth.users where id=${erased.id}::uuid and email=${erased.email}`;
  equal(
    await rpc(c, "get_cocreate_numbered_group", {
      p_room_id: erasedRoom.room_id,
    }),
    null,
    "Exact unreported synthetic erasure archives orphan",
  );
  await denied(erased, "get_cocreate_room_page_v2", scope(erased, erasedRoom));
  await sql`update private.cocreate_settings set enabled=false`;
  await denied(b, "get_cocreate_room_page_v2", scope(b, other));
  equal(
    (
      await rpc(a, "get_own_proposal", {
        p_expected_creator_profile_id: a.id,
        p_proposal_id: draft.proposal_id,
      })
    )[0].proposal_id,
    draft.proposal_id,
    "Native Project ownership independent of experiment OFF",
  );
  await sql`delete from private.policy_acceptances where account_id=${b.id}::uuid`;
  const exits = await rpc(b, "list_own_cocreate_hub_exits", actor(b));
  equal(
    exits.some((e) => e.hub_id === otherHub),
    true,
    "Minimal own exit survives policy/gate OFF",
  );
  await rpc(b, "mutate_cocreate_hub", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: otherHub,
    p_operation: "leave",
    p_episode_id: otherGeneral.episode_id,
  });
  console.log(
    `Co-creation integrated programme passed: ${checks} assertions; real local OTP/socket; activation OFF.`,
  );
} finally {
  if (channel) await subscriber.client.removeChannel(channel);
  if (subscriber) subscriber.client.realtime.disconnect();
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
