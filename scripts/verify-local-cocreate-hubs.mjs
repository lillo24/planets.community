import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import {
  seedCocreateLocalCatalogue,
  cocreateLocalHubs,
} from "./lib/cocreate-local-fixtures.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
const { sql, status } = openCocreateLocalBackend();
const run = randomUUID().slice(0, 8),
  hub = cocreateLocalHubs[0][0];
let checks = 0;
function equal(actual, expected, label) {
  assert.deepEqual(actual, expected, label);
  checks++;
}
const actor = (person) => ({ p_expected_profile_id: person.id });
async function person(name) {
  const user = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: "cocreate-hub-" + run + "-" + name + "@planets.invalid",
    verifierName: "cocreate-hubs",
  });
  await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,${"Synthetic hub " + name})`;
  await rpc(user, "accept_policy_bundle", {
    p_expected_account_id: user.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return user;
}
async function rpc(user, name, args) {
  const result = await user.client.rpc(name, args);
  equal(result.error?.code ?? null, null, name + " succeeds");
  return result.data;
}
async function denied(user, name, args, code = "42501") {
  const result = await user.client.rpc(name, args);
  equal(result.error?.code, code, name + " rejects");
}
const join = (user, key = randomUUID()) =>
  rpc(user, "mutate_cocreate_hub", {
    ...actor(user),
    p_command_id: key,
    p_hub_id: hub,
    p_operation: "join",
  });
const page = (user, ep) =>
  rpc(user, "get_cocreate_room_page", {
    ...actor(user),
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
  });
const send = (user, ep, body, key = randomUUID()) =>
  rpc(user, "send_cocreate_room_message", {
    ...actor(user),
    p_command_id: key,
    p_room_id: ep.room_id,
    p_episode_id: ep.episode_id,
    p_body: body,
  });
const leave = (user, ep, key = randomUUID()) =>
  rpc(user, "mutate_cocreate_hub", {
    ...actor(user),
    p_command_id: key,
    p_hub_id: hub,
    p_operation: "leave",
    p_episode_id: ep.episode_id,
  });
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts with activation OFF",
  );
  await seedCocreateLocalCatalogue(sql);
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("a"),
    b = await person("b"),
    outsider = await person("outsider"),
    staff = await person("staff");
  const catalogue = await rpc(a, "list_cocreate_hubs", {
    p_locality: "Trento",
  });
  equal(catalogue.length, 3, "Three distinct synthetic local hubs");
  equal(
    Object.keys(catalogue[0]).sort(),
    ["hub_id", "topic_id", "topic_label", "locality", "created_at"].sort(),
    "Public catalogue exact allow-list",
  );
  const key = randomUUID(),
    joined = await Promise.all([join(a, key), join(a, key)]),
    epA = joined[0];
  equal(joined[0], joined[1], "Concurrent admission retry returns one episode");
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes where room_id=${epA.room_id}::uuid and actor_id=${a.id}::uuid and ended_at is null`
    )[0].n,
    1,
    "One current admission",
  );
  await denied(outsider, "get_cocreate_room_page", {
    ...actor(outsider),
    p_room_id: epA.room_id,
    p_episode_id: epA.episode_id,
  });
  await denied(outsider, "list_cocreate_room_people", {
    ...actor(outsider),
    p_room_id: epA.room_id,
    p_episode_id: epA.episode_id,
  });
  const first = await send(a, epA, "Synthetic earlier history");
  const epB = await join(b);
  equal(
    (await page(b, epB)).messages.some(
      (m) => m.message_id === first.message_id,
    ),
    true,
    "Explicit admission grants earlier history",
  );
  equal(
    (await rpc(b, "list_own_cocreate_rooms", actor(b)))[0].unread_count,
    0,
    "No fabricated prejoin unread",
  );
  const sendKey = randomUUID(),
    sent = await Promise.all([
      send(a, epA, "Synthetic concurrent exact send", sendKey),
      send(a, epA, "Synthetic concurrent exact send", sendKey),
    ]);
  equal(sent[0], sent[1], "Concurrent send retry creates one message");
  await denied(
    a,
    "send_cocreate_room_message",
    {
      ...actor(a),
      p_command_id: sendKey,
      p_room_id: epA.room_id,
      p_episode_id: epA.episode_id,
      p_body: "Changed intent",
    },
    "22023",
  );
  let feed = await page(b, epB);
  equal(
    (await rpc(b, "get_own_message_unread_summary_with_cocreate", actor(b)))
      .groups,
    1,
    "Complete Groups unread counts room once",
  );
  await denied(a, "acknowledge_cocreate_room", {
    ...actor(a),
    p_room_id: epA.room_id,
    p_episode_id: epA.episode_id,
    p_read_token: feed.read_token,
  });
  await rpc(b, "acknowledge_cocreate_room", {
    ...actor(b),
    p_room_id: epB.room_id,
    p_episode_id: epB.episode_id,
    p_read_token: feed.read_token,
  });
  equal(
    (await rpc(b, "get_own_message_unread_summary_with_cocreate", actor(b)))
      .groups,
    0,
    "Rendered frontier clears canonical unread",
  );
  await rpc(b, "mutate_cocreate_hub", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "mute",
    p_episode_id: epB.episode_id,
    p_muted: true,
  });
  equal(
    (
      await rpc(b, "get_own_cocreate_hub_membership", {
        ...actor(b),
        p_hub_id: hub,
      })
    ).muted,
    true,
    "Canonical mute persists",
  );
  const leaveKey = randomUUID();
  await Promise.all([
    send(a, epA, "Synthetic send competing with exit"),
    leave(b, epB, leaveKey),
  ]);
  const frozen = await page(b, epB),
    frozenIds = frozen.messages.map((m) => m.message_id);
  await send(a, epA, "Synthetic later content denied to former episode");
  equal(
    (await page(b, epB)).messages.map((m) => m.message_id),
    frozenIds,
    "Committed exit freezes exact sequence history",
  );
  await denied(b, "send_cocreate_room_message", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_room_id: epB.room_id,
    p_episode_id: epB.episode_id,
    p_body: "Former cannot send",
  });
  const epB2 = await join(b);
  equal(
    epB2.episode_id === epB.episode_id,
    false,
    "Rejoin creates a new episode",
  );
  await leave(b, epB, leaveKey);
  equal(
    (
      await rpc(b, "get_own_cocreate_hub_membership", {
        ...actor(b),
        p_hub_id: hub,
      })
    ).episode_id,
    epB2.episode_id,
    "An old leave receipt cannot close the new episode",
  );
  await denied(b, "acknowledge_cocreate_room", {
    ...actor(b),
    p_room_id: epB2.room_id,
    p_episode_id: epB2.episode_id,
    p_read_token: feed.read_token,
  });
  equal(
    (await rpc(b, "list_own_cocreate_rooms", actor(b))).length,
    1,
    "Rejoin has one Messages row, no old-episode duplicate",
  );
  const reportArgs = {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_target_id: first.message_id,
    p_category: "other",
    p_explanation: "Synthetic exact room evidence",
  };
  const report = await rpc(b, "submit_cocreate_room_report", reportArgs);
  equal(
    await rpc(b, "submit_cocreate_room_report", reportArgs),
    report,
    "Exact report retry is global and immutable",
  );
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff.id}::uuid,'moderator')`;
  const scoped = await rpc(staff, "get_moderation_case_cocreate_room", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report[0].case_id,
  });
  equal(
    scoped.evidence.body,
    "Synthetic earlier history",
    "Staff receive exact reported evidence",
  );
  await denied(staff, "get_cocreate_room_page", {
    ...actor(staff),
    p_room_id: epA.room_id,
    p_episode_id: epA.episode_id,
  });
  const moderate = (operation, version) =>
    rpc(staff, "moderate_cocreate_hub", {
      p_expected_staff_profile_id: staff.id,
      p_command_id: randomUUID(),
      p_case_id: report[0].case_id,
      p_expected_version: version,
      p_operation: operation,
    });
  let mod = await moderate("remove_sender", scoped.hub_version);
  await denied(a, "mutate_cocreate_hub", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "join",
  });
  mod = await moderate("allow_sender", mod.version);
  const epA2 = await join(a);
  equal(
    (await join(a, key)).episode_id,
    epA.episode_id,
    "Old join receipt stays an acknowledgement, not a fresh grant",
  );
  equal(
    (
      await rpc(a, "get_own_cocreate_hub_membership", {
        ...actor(a),
        p_hub_id: hub,
      })
    ).episode_id,
    epA2.episode_id,
    "Current membership is unchanged by an old admission receipt",
  );
  mod = await moderate("suppress", mod.version);
  await denied(b, "get_cocreate_room_page", {
    ...actor(b),
    p_room_id: epB.room_id,
    p_episode_id: epB2.episode_id,
  });
  await denied(b, "acknowledge_cocreate_room", {
    ...actor(b),
    p_room_id: epB.room_id,
    p_episode_id: epB.episode_id,
    p_read_token: frozen.read_token,
  });
  await moderate("restore", mod.version);
  await sql`update auth.users set banned_until=clock_timestamp()+interval '1 hour' where id=${a.id}::uuid`;
  await denied(a, "get_cocreate_room_page", {
    ...actor(a),
    p_room_id: epA2.room_id,
    p_episode_id: epA2.episode_id,
  });
  await sql`update auth.users set banned_until=null where id=${a.id}::uuid`;
  await rpc(b, "block_user", {
    p_expected_blocker_profile_id: b.id,
    p_blocked_profile_id: a.id,
  });
  equal(
    (await page(b, epB2)).messages.length > 0,
    true,
    "Shared-room blocking follows existing rule, without a new membership grant",
  );
  const erased = await join(outsider);
  // Match 145_contact_erased_subject_reports: exact synthetic identity only,
  // remove its profile before Auth's RESTRICT FK. This is not a production
  // account-erasure implementation or a changed retention policy.
  const erasureEmail = "cocreate-hub-" + run + "-outsider@planets.invalid";
  equal(
    (await sql`select email from auth.users where id=${outsider.id}::uuid`)[0]
      .email,
    erasureEmail,
    "Erasure target is this verifier's exact synthetic fixture",
  );
  await sql`delete from public.profiles where id=${outsider.id}::uuid and exists(
    select 1 from auth.users where id=${outsider.id}::uuid and email=${erasureEmail})`;
  await sql`delete from auth.users where id=${outsider.id}::uuid and email=${erasureEmail}`;
  await denied(outsider, "get_cocreate_room_page", {
    ...actor(outsider),
    p_room_id: erased.room_id,
    p_episode_id: erased.episode_id,
  });
  await sql`update private.cocreate_settings set enabled=false`;
  const exits = await rpc(b, "list_own_cocreate_hub_exits", actor(b));
  equal(
    Object.keys(exits[0]).sort(),
    ["hub_id", "episode_id", "joined_at"].sort(),
    "Disabled own-exit projection contains no source/body/roster",
  );
  await leave(b, epB2);
  console.log(
    "Co-creation hub/General verification passed: " +
      checks +
      " assertions; activation OFF.",
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
