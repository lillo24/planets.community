import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
const { sql, status } = openCocreateLocalBackend(),
  run = randomUUID().slice(0, 8),
  hub = randomUUID(),
  topic = randomUUID();
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
  const email = "cocreate-number-" + run + "-" + name + "@planets.invalid";
  const user = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email,
    verifierName: "cocreate-numbered",
  });
  await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,${"Synthetic numbered " + name})`;
  await rpc(user, "accept_policy_bundle", {
    p_expected_account_id: user.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return { ...user, email };
}
const joinHub = (user) =>
  rpc(user, "mutate_cocreate_hub", {
    ...actor(user),
    p_hub_id: hub,
    p_command_id: randomUUID(),
    p_operation: "join",
  });
const groupArgs = (user, operation, extra = {}) => ({
  ...actor(user),
  p_command_id: randomUUID(),
  p_hub_id: hub,
  p_operation: operation,
  ...extra,
});
const group = (user, operation, extra = {}) =>
  rpc(
    user,
    "mutate_cocreate_numbered_group",
    groupArgs(user, operation, extra),
  );
const page = (user, ep) =>
  rpc(user, "get_cocreate_room_page", {
    ...actor(user),
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
  });
const send = (user, ep, body) =>
  rpc(user, "send_cocreate_room_message", {
    ...actor(user),
    p_command_id: randomUUID(),
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
    p_body: body,
  });
const summary = (user, room) =>
  rpc(user, "get_cocreate_numbered_group", { p_room_id: room });
const context = (user, ep) =>
  rpc(user, "get_cocreate_numbered_context", {
    ...actor(user),
    p_hub_id: hub,
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
  });
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts with gate OFF",
  );
  await sql`insert into private.cocreate_topics(id,label,active) values(${topic}::uuid,'Synthetic numbered concurrency',true)`;
  await sql`insert into private.cocreate_hubs(id,topic_id,locality,active) values(${hub}::uuid,${topic}::uuid,${"Synthetic concurrency " + run},true)`;
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("a"),
    b = await person("b"),
    c = await person("c"),
    staff = await person("staff");
  await denied(a, "mutate_cocreate_numbered_group", groupArgs(a, "create"));
  const hubA = await joinHub(a),
    hubB = await joinHub(b),
    hubC = await joinHub(c);
  const creation = groupArgs(a, "create", { p_capacity: 2 });
  const created = await Promise.all([
    rpc(a, "mutate_cocreate_numbered_group", creation),
    group(a, "create", { p_capacity: 2 }),
  ]);
  equal(
    created.map((x) => x.number).sort((x, y) => x - y),
    [1, 2],
    "Concurrent creation gets distinct stable per-hub numbers",
  );
  const first = created[0],
    second = created[1];
  equal(
    await rpc(a, "mutate_cocreate_numbered_group", creation),
    first,
    "Uncertain create retry reuses exact room/number/episode",
  );
  await denied(
    a,
    "mutate_cocreate_numbered_group",
    { ...creation, p_capacity: 3 },
    "22023",
  );
  equal(
    (await summary(a, first.room_id)).occupied,
    1,
    "Creator occupies one seat",
  );
  const earlier = await send(a, first, "Synthetic earlier numbered history");
  await denied(b, "get_cocreate_room_page", {
    ...actor(b),
    p_room_id: first.room_id,
    p_episode_id: first.episode_id,
  });
  const joins = [
    groupArgs(b, "join", { p_room_id: first.room_id }),
    groupArgs(c, "join", { p_room_id: first.room_id }),
  ];
  const race = await Promise.all([
    b.client.rpc("mutate_cocreate_numbered_group", joins[0]),
    c.client.rpc("mutate_cocreate_numbered_group", joins[1]),
  ]);
  equal(
    race.map((r) => r.error?.code ?? null).sort(),
    [null, "PT409"].sort(),
    "Exactly one real Auth participant wins the last seat",
  );
  const index = race.findIndex((r) => !r.error),
    winner = index === 0 ? b : c,
    loser = index === 0 ? c : b,
    win = race[index].data;
  equal(
    (await summary(a, first.room_id)).occupied,
    2,
    "Capacity race never overfills",
  );
  equal(
    (await summary(a, first.room_id)).available,
    false,
    "Full remains a live non-actionable summary",
  );
  equal(
    await rpc(winner, "mutate_cocreate_numbered_group", joins[index]),
    win,
    "Winner's exact join retry consumes no second seat",
  );
  equal(
    (await group(winner, "join", { p_room_id: first.room_id })).episode_id,
    win.episode_id,
    "Fresh duplicate join reuses current episode",
  );
  const loserSecond = await group(loser, "join", { p_room_id: second.room_id });
  await denied(loser, "get_cocreate_room_page", {
    ...actor(loser),
    p_room_id: first.room_id,
    p_episode_id: win.episode_id,
  });
  equal(
    (await page(winner, win)).messages.some(
      (m) => m.message_id === earlier.message_id,
    ),
    true,
    "Admitted small group exposes its earlier history",
  );
  await send(a, first, "Synthetic incoming numbered message");
  const feed = await page(winner, win);
  equal(
    (
      await rpc(
        winner,
        "get_own_message_unread_summary_with_cocreate",
        actor(winner),
      )
    ).groups,
    1,
    "One unread numbered room counts once, not as its General alias",
  );
  const ownA = await page(a, first);
  await denied(a, "acknowledge_cocreate_room", {
    ...actor(a),
    p_room_id: second.room_id,
    p_episode_id: second.episode_id,
    p_read_token: ownA.read_token,
  });
  await rpc(winner, "acknowledge_cocreate_room", {
    ...actor(winner),
    p_room_id: win.room_id,
    p_episode_id: win.episode_id,
    p_read_token: feed.read_token,
  });
  equal(
    (
      await rpc(
        winner,
        "get_own_message_unread_summary_with_cocreate",
        actor(winner),
      )
    ).groups,
    0,
    "Correct rendered episode clears only its frontier",
  );
  const third = await group(a, "create", { p_capacity: 3 });
  await group(winner, "join", { p_room_id: third.room_id });
  const thirdContext = await context(a, third);
  const resize = groupArgs(a, "capacity", {
    p_room_id: third.room_id,
    p_episode_id: third.episode_id,
    p_capacity: 2,
    p_expected_version: thirdContext.version,
  });
  const joinThird = groupArgs(loser, "join", { p_room_id: third.room_id });
  const resized = await Promise.all([
    a.client.rpc("mutate_cocreate_numbered_group", resize),
    loser.client.rpc("mutate_cocreate_numbered_group", joinThird),
  ]);
  equal(
    resized.map((r) => r.error?.code ?? null).sort(),
    [null, "PT409"].sort(),
    "Resize/last-seat join serializes; one loses explicitly",
  );
  const bounded = await summary(a, third.room_id);
  equal(
    bounded.occupied <= bounded.capacity,
    true,
    "Resize race preserves occupancy bound",
  );
  await denied(
    loser,
    "mutate_cocreate_numbered_group",
    groupArgs(loser, "capacity", {
      p_room_id: second.room_id,
      p_episode_id: loserSecond.episode_id,
      p_capacity: 3,
      p_expected_version: 2,
    }),
  );
  let source = await context(a, first);
  await group(a, "remove", {
    p_room_id: first.room_id,
    p_episode_id: first.episode_id,
    p_target_profile_id: winner.id,
    p_expected_version: source.version,
  });
  await denied(
    winner,
    "mutate_cocreate_numbered_group",
    groupArgs(winner, "join", { p_room_id: first.room_id }),
  );
  await send(a, first, "Synthetic after removal");
  equal(
    (await page(winner, win)).messages.length,
    2,
    "Removed episode never reads later content",
  );
  const report = await rpc(winner, "submit_cocreate_room_report", {
    p_expected_reporter_profile_id: winner.id,
    p_client_submission_id: randomUUID(),
    p_target_id: earlier.message_id,
    p_category: "other",
    p_explanation: "Synthetic scoped numbered report",
  });
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff.id}::uuid,'moderator')`;
  const evidence = await rpc(staff, "get_moderation_case_cocreate_room", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report[0].case_id,
  });
  equal(
    evidence.evidence.message_id,
    earlier.message_id,
    "Staff get exact scoped numbered evidence",
  );
  await denied(staff, "get_cocreate_room_page", {
    ...actor(staff),
    p_room_id: first.room_id,
    p_episode_id: first.episode_id,
  });
  let mod = await rpc(staff, "moderate_cocreate_numbered_group", {
    p_expected_staff_profile_id: staff.id,
    p_command_id: randomUUID(),
    p_case_id: report[0].case_id,
    p_expected_version: evidence.room_version,
    p_operation: "suppress",
  });
  await denied(winner, "get_cocreate_room_page", {
    ...actor(winner),
    p_room_id: win.room_id,
    p_episode_id: win.episode_id,
  });
  equal(
    (await summary(a, second.room_id)).room_id,
    second.room_id,
    "Scoped suppression leaves another numbered room available",
  );
  await rpc(staff, "moderate_cocreate_numbered_group", {
    p_expected_staff_profile_id: staff.id,
    p_command_id: randomUUID(),
    p_case_id: report[0].case_id,
    p_expected_version: mod.version,
    p_operation: "restore",
  });
  source = await context(a, first);
  await group(a, "restore_member", {
    p_room_id: first.room_id,
    p_episode_id: first.episode_id,
    p_target_profile_id: winner.id,
    p_expected_version: source.version,
  });
  const win2 = await group(winner, "join", { p_room_id: first.room_id });
  equal(
    win2.episode_id === win.episode_id,
    false,
    "Authorized removal reversal still requires a new episode",
  );
  await rpc(winner, "mutate_cocreate_numbered_group", joins[index]);
  equal(
    (
      await rpc(winner, "get_own_cocreate_numbered_membership", {
        ...actor(winner),
        p_room_id: first.room_id,
      })
    ).episode_id,
    win2.episode_id,
    "Old join receipt never replaces the new admission",
  );
  await denied(winner, "acknowledge_cocreate_room", {
    ...actor(winner),
    p_room_id: win2.room_id,
    p_episode_id: win2.episode_id,
    p_read_token: feed.read_token,
  });
  const managed = await group(winner, "create");
  await group(loser, "join", { p_room_id: managed.room_id });
  const winnerHub = winner.id === b.id ? hubB : hubC;
  await rpc(winner, "mutate_cocreate_hub", {
    ...actor(winner),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "leave",
    p_episode_id: winnerHub.episode_id,
  });
  equal(
    (await summary(a, first.room_id)).available,
    true,
    "Hub exit reopens ordinary child seat",
  );
  equal(
    await summary(a, managed.room_id),
    null,
    "Hub exit archives the creator orphan, without transfer",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id where e.actor_id=${winner.id}::uuid and e.ended_at is null and r.hub_id=${hub}::uuid`
    )[0].n,
    0,
    "Hub leave has no partial child memberships",
  );
  await sql`update auth.users set deleted_at=clock_timestamp() where id=${loser.id}::uuid`;
  equal(
    (await summary(a, second.room_id)).occupied,
    1,
    "Permanent erasure vacates its reserved seat",
  );
  await denied(loser, "get_cocreate_room_page", {
    ...actor(loser),
    p_room_id: loserSecond.room_id,
    p_episode_id: loserSecond.episode_id,
  });
  equal(
    (await sql`select email from auth.users where id=${a.id}::uuid`)[0].email,
    a.email,
    "Erasure target is exact synthetic fixture",
  );
  let retained = false;
  try {
    await sql`delete from public.profiles where id=${a.id}::uuid and exists(select 1 from auth.users where id=${a.id}::uuid and email=${a.email})`;
  } catch (error) {
    if (error.code !== "23503") throw error;
    retained = true;
  }
  equal(
    retained,
    true,
    "Native moderation retention FK remains enforced, never bypassed",
  );
  await sql`update auth.users set deleted_at=clock_timestamp() where id=${a.id}::uuid and email=${a.email}`;
  equal(
    await summary(winner, first.room_id),
    null,
    "Erased manager archives remaining groups atomically",
  );
  equal(
    await summary(winner, second.room_id),
    null,
    "Erased manager archives every orphaned room",
  );
  equal(
    (await page(winner, win2)).closed,
    true,
    "Healthy former participant retains only its frozen history",
  );
  const physical = await person("physical");
  await joinHub(physical);
  const physicalRoom = await group(physical, "create");
  equal(
    (await sql`select email from auth.users where id=${physical.id}::uuid`)[0]
      .email,
    physical.email,
    "Physical deletion is limited to an unreported dedicated synthetic fixture",
  );
  await sql`delete from public.profiles where id=${physical.id}::uuid and exists(select 1 from auth.users where id=${physical.id}::uuid and email=${physical.email})`;
  await sql`delete from auth.users where id=${physical.id}::uuid and email=${physical.email}`;
  equal(
    await summary(winner, physicalRoom.room_id),
    null,
    "Physical erasure archives the orphan without deleting retained room records",
  );
  await joinHub(staff);
  const safe = await group(staff, "create");
  await sql`delete from private.policy_acceptances where account_id=${staff.id}::uuid`;
  await sql`update private.cocreate_settings set enabled=false`;
  equal(
    (await rpc(staff, "list_own_cocreate_numbered_exits", actor(staff))).length,
    1,
    "Minimal own exits remain available without current policy/gate",
  );
  await group(staff, "leave", {
    p_room_id: safe.room_id,
    p_episode_id: safe.episode_id,
  });
  console.log(
    "Co-creation numbered-group verification passed: " +
      checks +
      " assertions; activation OFF.",
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
