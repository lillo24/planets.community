import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

const { sql, status } = openCocreateLocalBackend();
const hub = randomUUID(),
  topic = randomUUID(),
  run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (actual, expected, label) => {
  assert.deepEqual(actual, expected, label);
  checks++;
};
const actor = (user) => ({ p_expected_profile_id: user.id });
async function rpc(user, name, args) {
  const r = await user.client.rpc(name, args);
  equal(r.error?.code ?? null, null, name + " succeeds");
  return r.data;
}
async function denied(user, name, args, code = "42501") {
  const r = await user.client.rpc(name, args);
  equal(r.error?.code, code, name + " denies");
}
async function person(name) {
  const user = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: "cocreate-card-" + run + "-" + name + "@planets.invalid",
    verifierName: "cocreate-recruitment",
  });
  await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,${"Synthetic card " + name})`;
  await rpc(user, "accept_policy_bundle", {
    p_expected_account_id: user.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return user;
}
const joinHub = (user) =>
  rpc(user, "mutate_cocreate_hub", {
    ...actor(user),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "join",
  });
const group = (user, operation, extra = {}) =>
  rpc(user, "mutate_cocreate_numbered_group", {
    ...actor(user),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: operation,
    ...extra,
  });
const cardArgs = (user, room, operation, extra = {}) => ({
  ...actor(user),
  p_command_id: randomUUID(),
  p_hub_id: hub,
  p_room_id: room,
  p_operation: operation,
  ...extra,
});
const page = (user, ep, version = "_v2") =>
  rpc(user, "get_cocreate_room_page" + version, {
    ...actor(user),
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
  });
const joinArgs = (user, room, card) => ({
  ...actor(user),
  p_command_id: randomUUID(),
  p_hub_id: hub,
  p_room_id: room,
  p_recruitment_id: card,
});
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts OFF",
  );
  await sql`insert into private.cocreate_topics(id,label,active) values(${topic}::uuid,'Synthetic card concurrency',true)`;
  await sql`insert into private.cocreate_hubs(id,topic_id,locality,active) values(${hub}::uuid,${topic}::uuid,${"Synthetic cards " + run},true)`;
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("a"),
    b = await person("b"),
    c = await person("c"),
    outsider = await person("outsider");
  const ha = await joinHub(a),
    hb = await joinHub(b),
    hc = await joinHub(c);
  const room = await group(a, "create", { p_capacity: 2 });
  const posting = cardArgs(a, room.room_id, "post", {
    p_episode_id: room.episode_id,
  });
  const posted = await Promise.all([
    rpc(a, "mutate_cocreate_recruitment", posting),
    rpc(a, "mutate_cocreate_recruitment", posting),
  ]);
  equal(
    posted[0],
    posted[1],
    "Concurrent exact posting creates one immutable reference",
  );
  const card = posted[0];
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_recruitments where room_id=${room.room_id}::uuid`
    )[0].n,
    1,
    "One active row",
  );
  await denied(
    a,
    "mutate_cocreate_recruitment",
    cardArgs(a, room.room_id, "post", { p_episode_id: room.episode_id }),
    "PT409",
  );
  await denied(
    b,
    "mutate_cocreate_recruitment",
    cardArgs(b, room.room_id, "post", { p_episode_id: hb.episode_id }),
  );
  await denied(outsider, "get_cocreate_room_page_v2", {
    ...actor(outsider),
    p_room_id: ha.room_id,
    p_episode_id: hb.episode_id,
  });
  await denied(outsider, "get_cocreate_recruitment", {
    ...actor(outsider),
    p_general_room_id: ha.room_id,
    p_episode_id: hb.episode_id,
    p_recruitment_id: card.recruitment_id,
  });
  const read = await page(b, hb),
    entry = read.messages[0];
  equal(entry.kind, "recruitment", "Structured kind");
  equal(entry.sender_name, "Synthetic card a", "Admitted author attribution");
  equal(entry.recruitment.available, true, "One available seat");
  const ownRooms = await rpc(b, "list_own_cocreate_rooms_v2", actor(b));
  equal(
    ownRooms.find((r) => r.room_id === hb.room_id).unread_count,
    0,
    "Recruitment is not human unread",
  );
  equal(
    (await page(b, hb, "")).messages,
    [],
    "Legacy room reader does not render card as human text",
  );
  const race = await Promise.all([
    b.client.rpc(
      "join_cocreate_recruitment",
      joinArgs(b, room.room_id, card.recruitment_id),
    ),
    c.client.rpc(
      "join_cocreate_recruitment",
      joinArgs(c, room.room_id, card.recruitment_id),
    ),
  ]);
  equal(
    race.filter((r) => r.error === null).length,
    1,
    "Exactly one last-seat winner",
  );
  equal(
    race.filter((r) => r.error?.code === "PT409").length,
    1,
    "Exactly one full loser",
  );
  const index = race.findIndex((r) => r.error === null),
    winner = [b, c][index],
    loser = [b, c][1 - index],
    joined = race[index].data;
  equal(
    (await page(b, hb)).messages[0].recruitment.state,
    "full",
    "Stale cards resolve full",
  );
  await group(winner, "leave", {
    p_room_id: room.room_id,
    p_episode_id: joined.episode_id,
  });
  equal(
    (await page(b, hb)).messages[0].recruitment.state,
    "open",
    "Leaving reopens without repost",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_messages where room_id=${ha.room_id}::uuid`
    )[0].n,
    1,
    "No automated second card",
  );
  const rejoin = joinArgs(winner, room.room_id, card.recruitment_id);
  const current = await rpc(winner, "join_cocreate_recruitment", rejoin);
  equal(
    await rpc(winner, "join_cocreate_recruitment", rejoin),
    current,
    "Exact admission returns canonical episode",
  );
  await denied(
    winner,
    "join_cocreate_recruitment",
    { ...rejoin, p_recruitment_id: randomUUID() },
    "22023",
  );
  const context = await rpc(a, "get_cocreate_numbered_context", {
    ...actor(a),
    p_hub_id: hub,
    p_room_id: room.room_id,
    p_episode_id: room.episode_id,
  });
  await group(a, "remove", {
    p_room_id: room.room_id,
    p_episode_id: room.episode_id,
    p_target_profile_id: winner.id,
    p_expected_version: context.version,
  });
  await denied(
    winner,
    "join_cocreate_recruitment",
    joinArgs(winner, room.room_id, card.recruitment_id),
  );
  const retract = cardArgs(a, room.room_id, "retract", {
    p_recruitment_id: card.recruitment_id,
  });
  const retracted = await rpc(a, "mutate_cocreate_recruitment", retract);
  equal(
    await rpc(a, "mutate_cocreate_recruitment", retract),
    retracted,
    "Exact retraction retries",
  );
  await denied(
    loser,
    "join_cocreate_recruitment",
    joinArgs(loser, room.room_id, card.recruitment_id),
    "PT409",
  );
  equal(
    (await page(b, hb)).messages[0].recruitment.state,
    "retracted",
    "Retraction keeps immutable card history",
  );
  await denied(
    a,
    "mutate_cocreate_recruitment",
    cardArgs(a, room.room_id, "post", { p_episode_id: room.episode_id }),
    "PT429",
  );
  await sql`update private.cocreate_recruitments set created_at=clock_timestamp()-interval '2 hours' where id=${card.recruitment_id}::uuid`;
  const second = await rpc(
    a,
    "mutate_cocreate_recruitment",
    cardArgs(a, room.room_id, "post", { p_episode_id: room.episode_id }),
  );
  equal(
    second.recruitment_id === card.recruitment_id,
    false,
    "Deliberate new posting gets a new immutable card",
  );
  await sql`update private.cocreate_recruitments set created_at=clock_timestamp()-interval '8 days',expires_at=clock_timestamp()-interval '1 day' where id=${second.recruitment_id}::uuid`;
  await denied(
    loser,
    "join_cocreate_recruitment",
    joinArgs(loser, room.room_id, second.recruitment_id),
    "PT409",
  );
  const evidence = await rpc(b, "submit_cocreate_room_report", {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_target_id: second.message_id,
    p_category: "spam",
    p_explanation: "Synthetic exact structured card report",
  });
  equal(
    (
      await sql`select cocreate_evidence->'recruitment'->>'recruitment_id' id from private.moderation_cases where id=${evidence[0].case_id}::uuid`
    )[0].id,
    second.recruitment_id,
    "Exact report snapshot",
  );
  await sql`update private.cocreate_settings set enabled=false`;
  await rpc(
    a,
    "mutate_cocreate_recruitment",
    cardArgs(a, room.room_id, "retract", {
      p_recruitment_id: second.recruitment_id,
    }),
  );
  await denied(b, "get_cocreate_room_page_v2", {
    ...actor(b),
    p_room_id: hb.room_id,
    p_episode_id: hb.episode_id,
  });
  console.log(
    "Co-creation recruitment verification passed: " +
      checks +
      " assertions; activation OFF.",
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
