import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

const { sql, status } = openCocreateLocalBackend();
const run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (a, b, message) => {
  assert.deepEqual(a, b, message);
  checks++;
};
const actor = (p) => ({ p_expected_profile_id: p.id });
const command = (p) => ({ ...actor(p), p_command_id: randomUUID() });
async function rpc(p, name, args = {}) {
  const r = await p.client.rpc(name, args);
  equal(r.error?.code ?? null, null, `${name} succeeds`);
  return r.data;
}
async function denied(p, name, args, code = "42501") {
  const r = await p.client.rpc(name, args);
  equal(
    r.error?.code,
    code,
    `${name} denies (${r.error?.message ?? "no error"})`,
  );
}
async function person(key) {
  const p = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: `cocreate-comm-${run}-${key}@planets.invalid`,
    verifierName: "cocreate-community-meetings",
  });
  await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Synthetic community ${key}`})`;
  await rpc(p, "accept_policy_bundle", {
    p_expected_account_id: p.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return p;
}
async function drain() {
  for (let n = 0; n < 100; n++) {
    const [r] =
      await sql`select * from public.process_notification_outbox_batch(100)`;
    if (r.processed_count === 0) return;
  }
  throw Error("Bounded notification drain did not finish.");
}
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Gate starts OFF",
  );
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("a"),
    b = await person("b"),
    c = await person("c"),
    d = await person("d"),
    muted = await person("muted"),
    outside = await person("outside");
  const proposing = {
    ...command(a),
    p_category_id: "videogames",
    p_name: `Synthetic ${run} Valorant`,
    p_locality: "Synthetic Trento",
    p_explanation: "Synthetic shared interest, no private address.",
  };
  const proposals = await Promise.all([
    rpc(a, "propose_cocreate_community", proposing),
    rpc(a, "propose_cocreate_community", proposing),
  ]);
  equal(proposals[0], proposals[1], "Exact concurrent proposal retry");
  const id = proposals[0].proposal_id;
  const duplicate = await rpc(b, "propose_cocreate_community", {
    ...command(b),
    p_category_id: "videogames",
    p_name: `  SYNTHETIC  ${run}  VALORANT `,
    p_locality: "  synthetic  TRENTO ",
    p_explanation: "Different explanation does not duplicate identity.",
  });
  equal(duplicate.proposal_id, id, "Case/space normalized pending duplicate");
  let proposal = await rpc(a, "get_cocreate_community_proposal", {
    p_proposal_id: id,
  });
  equal(
    proposal.interested_count,
    1,
    "Proposer is one unique initial interest",
  );
  const interest = (p, operation = "interest") => ({
    ...command(p),
    p_proposal_id: id,
    p_operation: operation,
  });
  const support = interest(b);
  await rpc(b, "mutate_cocreate_community_interest", support);
  await rpc(b, "mutate_cocreate_community_interest", support);
  proposal = await rpc(a, "get_cocreate_community_proposal", {
    p_proposal_id: id,
  });
  equal(
    proposal.interested_count,
    2,
    "Duplicate supporter does not add a person",
  );
  equal(proposal.state, "pending", "Two is insufficient");
  const last = await Promise.all(
    [c, d].map((p) =>
      p.client.rpc("mutate_cocreate_community_interest", interest(p)),
    ),
  );
  equal(
    last.filter((r) => !r.error).length,
    1,
    "Exactly one last supporter activates; late pending action conflicts",
  );
  equal(
    last.find((r) => r.error)?.error.code,
    "PT409",
    "Late support needs current review",
  );
  proposal = await rpc(a, "get_cocreate_community_proposal", {
    p_proposal_id: id,
  });
  equal(proposal.state, "activated", "Three distinct eligible people activate");
  const hub = proposal.hub_id;
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_rooms where hub_id=${hub}::uuid and kind='general'`
    )[0].n,
    1,
    "Exactly one General",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_rooms where hub_id=${hub}::uuid and kind='numbered'`
    )[0].n,
    0,
    "Activation creates no numbered group",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id where r.hub_id=${hub}::uuid`
    )[0].n,
    0,
    "Support never enrolls anyone",
  );
  const own = await rpc(b, "list_own_cocreate_community_interests", {
    ...actor(b),
  });
  equal(
    own.find((i) => i.proposal.proposal_id === id)?.ready_to_join,
    true,
    "Durable actor-private invitation",
  );
  const activeDuplicate = await rpc(d, "propose_cocreate_community", {
    ...command(d),
    p_category_id: "videogames",
    p_name: proposing.p_name.toUpperCase(),
    p_locality: "SYNTHETIC TRENTO",
  });
  equal(
    activeDuplicate.hub_id,
    hub,
    "Active duplicate routes to canonical hub",
  );
  const otherCity = await rpc(a, "propose_cocreate_community", {
    ...command(a),
    p_category_id: "videogames",
    p_name: proposing.p_name,
    p_locality: "Synthetic Verona",
  });
  equal(otherCity.hub_id, null, "A different city does not share the hub");
  assert.notEqual(otherCity.proposal_id, id);
  checks++;
  const joinHub = (p) =>
    rpc(p, "mutate_cocreate_hub", {
      ...command(p),
      p_hub_id: hub,
      p_operation: "join",
    });
  const ha = await joinHub(a),
    hb = await joinHub(b),
    hc = await joinHub(c),
    hd = await joinHub(d),
    hm = await joinHub(muted);
  await rpc(muted, "mutate_cocreate_hub", {
    ...command(muted),
    p_hub_id: hub,
    p_operation: "mute",
    p_episode_id: hm.episode_id,
    p_muted: true,
  });
  const starts = new Date(Date.now() + 3 * 86400000).toISOString();
  const scheduling = {
    ...command(a),
    p_hub_id: hub,
    p_starts_at: starts,
    p_capacity: 2,
  };
  const scheduled = await Promise.all([
    rpc(a, "schedule_cocreate_meeting", scheduling),
    rpc(a, "schedule_cocreate_meeting", scheduling),
  ]);
  equal(
    scheduled[0],
    scheduled[1],
    "Lost reply/exact schedule retry creates one meeting and group",
  );
  const meeting = scheduled[0];
  await denied(
    a,
    "schedule_cocreate_meeting",
    { ...scheduling, p_capacity: 3 },
    "22023",
  );
  const getCard = (p) =>
    rpc(p, "get_cocreate_recruitment", {
      ...actor(p),
      p_general_room_id: ha.room_id,
      p_episode_id:
        p === a
          ? ha.episode_id
          : p === b
            ? hb.episode_id
            : p === c
              ? hc.episode_id
              : hd.episode_id,
      p_recruitment_id: meeting.recruitment_id,
    });
  let card = await getCard(b);
  equal(card.occupied, 1, "Creator counts toward meeting occupancy");
  equal(card.capacity, 2, "Meeting capacity independent of persistent chat");
  equal(
    new Date(card.starts_at).toISOString(),
    starts,
    "Meeting card carries the exact instant",
  );
  await drain();
  const notices = await rpc(b, "list_own_notifications_with_cocreate", {
    ...actor(b),
  });
  const notice = notices.find(
    (n) => n.cocreate_recruitment_id === meeting.recruitment_id,
  );
  assert.ok(notice);
  checks++;
  equal(
    new Date(notice.cocreate_starts_at).toISOString(),
    starts,
    "Notification already includes meeting time",
  );
  equal(notice.cocreate_capacity, 2, "Notification shows meeting capacity");
  equal(
    (await rpc(a, "list_own_notifications_with_cocreate", actor(a))).filter(
      (n) => n.cocreate_recruitment_id === meeting.recruitment_id,
    ).length,
    0,
    "No author self-notification",
  );
  equal(
    (
      await rpc(muted, "list_own_notifications_with_cocreate", actor(muted))
    ).filter((n) => n.cocreate_recruitment_id === meeting.recruitment_id)
      .length,
    0,
    "Muted General receives no filling notification",
  );
  const joining = (p) => ({
    ...command(p),
    p_hub_id: hub,
    p_room_id: meeting.room_id,
    p_recruitment_id: meeting.recruitment_id,
  });
  await denied(outside, "join_cocreate_recruitment", joining(outside));
  const races = await Promise.all(
    [b, c].map((p) => p.client.rpc("join_cocreate_recruitment", joining(p))),
  );
  equal(
    races.filter((r) => !r.error).length,
    1,
    "One final meeting seat wins atomically",
  );
  equal(
    races.find((r) => r.error)?.error.code,
    "PT409",
    "The losing meeting join is full",
  );
  const winner = races[0].error ? c : b,
    loser = winner === b ? c : b,
    admitted = races.find((r) => !r.error).data;
  card = await getCard(d);
  equal(card.occupied, 2, "No meeting overfill");
  equal(card.state, "full", "Full card truthful");
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes where room_id=${meeting.room_id}::uuid and ended_at is null`
    )[0].n,
    2,
    "Winning join also enters persistent chat only once",
  );
  await rpc(winner, "mutate_cocreate_meeting", {
    ...command(winner),
    p_hub_id: hub,
    p_room_id: meeting.room_id,
    p_episode_id: admitted.episode_id,
    p_meeting_id: meeting.meeting_id,
    p_operation: "decline",
  });
  card = await getCard(d);
  equal(card.occupied, 1, "Declining frees one place");
  equal(
    (
      await rpc(winner, "get_own_cocreate_numbered_membership", {
        ...actor(winner),
        p_room_id: meeting.room_id,
      })
    ).active,
    true,
    "Declining retains chat membership",
  );
  const loserJoined = await rpc(
    loser,
    "join_cocreate_recruitment",
    joining(loser),
  );
  await rpc(a, "mutate_cocreate_meeting", {
    ...command(a),
    p_hub_id: hub,
    p_room_id: meeting.room_id,
    p_episode_id: meeting.episode_id,
    p_meeting_id: meeting.meeting_id,
    p_operation: "cancel",
  });
  equal(
    (await getCard(d)).state,
    "retracted",
    "Cancellation makes the old card non-actionable",
  );
  equal(
    (
      await rpc(winner, "get_own_cocreate_numbered_membership", {
        ...actor(winner),
        p_room_id: meeting.room_id,
      })
    ).active,
    true,
    "Cancellation keeps the same chat",
  );
  // Advance only this synthetic card's anti-spam timestamp; no real room touched.
  await sql`update private.cocreate_recruitments set created_at=created_at-interval '2 hours' where room_id=${meeting.room_id}::uuid`;
  const next = await rpc(a, "schedule_cocreate_meeting", {
    ...command(a),
    p_hub_id: hub,
    p_room_id: meeting.room_id,
    p_episode_id: meeting.episode_id,
    p_starts_at: new Date(Date.now() + 5 * 86400000).toISOString(),
    p_capacity: 3,
  });
  equal(
    next.room_id,
    meeting.room_id,
    "Next meeting reuses the persistent chat",
  );
  const current = await rpc(winner, "get_cocreate_current_meeting", {
    ...actor(winner),
    p_room_id: next.room_id,
    p_episode_id: admitted.episode_id,
  });
  equal(
    current.occupied,
    1,
    "A new meeting starts with explicit creator attendance only",
  );
  equal(current.attending, false, "Old chat membership is not an RSVP");
  const confirming = {
    ...command(winner),
    p_hub_id: hub,
    p_room_id: next.room_id,
    p_episode_id: admitted.episode_id,
    p_meeting_id: next.meeting_id,
    p_operation: "attend",
  };
  const confirmed = await rpc(winner, "mutate_cocreate_meeting", confirming);
  equal(
    await rpc(winner, "mutate_cocreate_meeting", confirming),
    confirmed,
    "Current member RSVP has an exact receipt",
  );
  equal(
    (
      await rpc(winner, "get_cocreate_current_meeting", {
        ...actor(winner),
        p_room_id: next.room_id,
        p_episode_id: admitted.episode_id,
      })
    ).occupied,
    2,
    "Persistent chat member confirms this occurrence explicitly",
  );
  await drain();
  await rpc(d, "mutate_cocreate_hub", {
    ...command(d),
    p_hub_id: hub,
    p_operation: "leave",
    p_episode_id: hd.episode_id,
  });
  equal(
    (await rpc(d, "list_own_notifications_with_cocreate", actor(d))).filter(
      (n) => n.cocreate_recruitment_id === next.recruitment_id,
    ).length,
    0,
    "Exit revokes retained filling notifications",
  );
  await denied(loser, "get_cocreate_current_meeting", {
    ...actor(loser),
    p_room_id: next.room_id,
    p_episode_id: admitted.episode_id,
  });
  await sql`update private.cocreate_settings set enabled=false`;
  await denied(a, "list_cocreate_categories", {});
  await denied(a, "schedule_cocreate_meeting", {
    ...command(a),
    p_hub_id: hub,
    p_starts_at: starts,
    p_capacity: 5,
  });
  await rpc(loser, "mutate_cocreate_meeting", {
    ...command(loser),
    p_hub_id: hub,
    p_room_id: meeting.room_id,
    p_episode_id: loserJoined.episode_id,
    p_meeting_id: next.meeting_id,
    p_operation: "decline",
  });
  console.log(
    `COCREATE COMM01/FILL01 real Auth verification passed (${checks} assertions).`,
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
