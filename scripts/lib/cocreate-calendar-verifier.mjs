import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { signInLocalOtpUser } from "./local-authenticated-user.mjs";

// Called by the existing community/meeting HTTP verifier, so CAL01 receives
// the same scoped Database CI gate without a second hosted-runner job.
export async function verifyCocreateCalendar({ sql, status }) {
  const mailpit = new URL(process.env.MAILPIT_URL ?? "http://127.0.0.1:54324");
  assert.ok(
    mailpit.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(mailpit.hostname) &&
      !mailpit.username &&
      !mailpit.password &&
      !mailpit.search &&
      !mailpit.hash &&
      mailpit.pathname === "/",
    "Calendar verification requires its owned loopback Mailpit URL",
  );
  const run = randomUUID().slice(0, 8);
  let checks = 0;
  const equal = (a, b, label) => {
    assert.deepEqual(a, b, label);
    checks++;
  };
  const actor = (p) => ({ p_expected_profile_id: p.id });
  const command = (p) => ({ ...actor(p), p_command_id: randomUUID() });
  async function rpc(p, name, args) {
    const result = await p.client.rpc(name, args);
    equal(
      result.error?.code ?? null,
      null,
      `${name}: ${result.error?.message ?? "success"}`,
    );
    return result.data;
  }
  async function denied(p, name, args, code = "42501") {
    const result = await p.client.rpc(name, args);
    equal(result.error?.code, code, `${name} must deny`);
  }
  async function person(label) {
    const p = await signInLocalOtpUser({
      ...status,
      mailpitUrl: mailpit.toString().replace(/\/$/, ""),
      email: `calendar-${run}-${label}@planets.invalid`,
      verifierName: "calendar",
    });
    await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Synthetic calendar ${label}`})`;
    await rpc(p, "accept_policy_bundle", {
      p_expected_account_id: p.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    return p;
  }
  const [settings] = await sql`select enabled from private.cocreate_settings`;
  try {
    await sql`update private.cocreate_settings set enabled=true`;
    const people = [];
    for (const name of ["creator", "member", "racer-a", "racer-b", "outsider"])
      people.push(await person(name));
    const [a, b, c, d, outside] = people;
    const proposal = await rpc(a, "propose_cocreate_community", {
      ...command(a),
      p_category_id: "videogames",
      p_name: `Synthetic calendar ${run}`,
      p_locality: "Synthetic calendar locality",
    });
    for (const p of [b, c])
      await rpc(p, "mutate_cocreate_community_interest", {
        ...command(p),
        p_proposal_id: proposal.proposal_id,
        p_operation: "interest",
      });
    const { hub_id: hub } = await rpc(a, "get_cocreate_community_proposal", {
      p_proposal_id: proposal.proposal_id,
    });
    const admissions = new Map();
    for (const p of [a, b, c, d])
      admissions.set(
        p.id,
        await rpc(p, "mutate_cocreate_hub", {
          ...command(p),
          p_hub_id: hub,
          p_operation: "join",
        }),
      );
    const start = new Date(),
      end = new Date(start.getTime() + 31 * 86400000);
    const instant = new Date(start.getTime() + 2 * 86400000).toISOString();
    const meeting = await rpc(a, "schedule_cocreate_meeting", {
      ...command(a),
      p_hub_id: hub,
      p_starts_at: instant,
      p_capacity: 2,
    });
    const args = (p, extra = {}) => {
      const m = admissions.get(p.id) ?? admissions.get(a.id);
      return {
        ...actor(p),
        p_hub_id: hub,
        p_general_room_id: m.room_id,
        p_episode_id: m.episode_id,
        p_window_start: start.toISOString(),
        p_window_end: end.toISOString(),
        p_limit: 1,
        ...extra,
      };
    };
    const read = (p, extra) =>
      rpc(p, "get_cocreate_calendar_v1", args(p, extra));
    let page = await read(b);
    equal(page.meetings.length, 1, "one authorized dated meeting");
    equal(
      page.meetings[0].can_join,
      true,
      "General viewer can open canonical Join",
    );
    equal(
      page.meetings[0].episode_id,
      null,
      "calendar read never joins numbered chat",
    );
    await denied(outside, "get_cocreate_calendar_v1", args(outside));
    await denied(
      b,
      "get_cocreate_calendar_v1",
      args(b, { p_expected_profile_id: a.id }),
    );
    const [{ acks: before }] =
      await sql`select jsonb_agg(jsonb_build_array(id,read_sequence) order by id) acks from private.cocreate_room_episodes where actor_id=${b.id}::uuid`;
    await read(b);
    const [{ acks: after }] =
      await sql`select jsonb_agg(jsonb_build_array(id,read_sequence) order by id) acks from private.cocreate_room_episodes where actor_id=${b.id}::uuid`;
    equal(after, before, "HTTP calendar never acknowledges a transcript");
    const joinArgs = (p) => ({
      ...command(p),
      p_hub_id: hub,
      p_room_id: meeting.room_id,
      p_recruitment_id: meeting.recruitment_id,
    });
    const racing = [joinArgs(c), joinArgs(d)];
    const outcomes = await Promise.all(
      [c, d].map((p, i) =>
        p.client.rpc("join_cocreate_recruitment", racing[i]),
      ),
    );
    equal(
      outcomes.filter((x) => x.error == null).length,
      1,
      "one winner for final meeting place",
    );
    equal(
      outcomes.find((x) => x.error)?.error.code,
      "PT409",
      "last-seat loser receives conflict",
    );
    const winIndex = outcomes.findIndex((x) => !x.error),
      winner = [c, d][winIndex];
    const winning = outcomes[winIndex].data;
    equal(
      await rpc(winner, "join_cocreate_recruitment", racing[winIndex]),
      winning,
      "exact join retry recovers one receipt",
    );
    page = await read(b);
    equal(page.meetings[0].occupied, 2, "full meeting occupancy");
    equal(page.meetings[0].can_join, false, "full disables new admission");
    equal(
      (await read(winner)).meetings[0].attending,
      true,
      "full still exposes own attendance",
    );
    equal(
      (
        await sql`select count(*)::int n from private.cocreate_room_episodes where room_id=${meeting.room_id}::uuid and actor_id=${winner.id}::uuid and ended_at is null`
      )[0].n,
      1,
      "no duplicate chat membership",
    );
    await rpc(winner, "mutate_cocreate_meeting", {
      ...command(winner),
      p_hub_id: hub,
      p_room_id: meeting.room_id,
      p_episode_id: winning.episode_id,
      p_meeting_id: meeting.meeting_id,
      p_operation: "decline",
    });
    equal(
      (await read(b)).meetings[0].can_join,
      true,
      "decline reopens canonical place",
    );
    equal(
      (await read(winner)).meetings[0].can_confirm,
      true,
      "decline preserves chat membership",
    );
    await sql`update private.cocreate_recruitments set created_at=clock_timestamp()-interval '8 days',expires_at=clock_timestamp()-interval '1 second' where id=${meeting.recruitment_id}::uuid`;
    equal(
      (await read(b)).meetings[0].can_join,
      false,
      "expired recruitment is distinct from available seats",
    );
    equal(
      (await read(winner)).meetings[0].can_confirm,
      true,
      "future meeting RSVP survives recruitment expiry",
    );
    await rpc(a, "mutate_cocreate_meeting", {
      ...command(a),
      p_hub_id: hub,
      p_room_id: meeting.room_id,
      p_episode_id: meeting.episode_id,
      p_meeting_id: meeting.meeting_id,
      p_operation: "repost",
    });
    page = await read(b);
    equal(page.meetings.length, 1, "repost is one canonical calendar event");
    assert.notEqual(page.meetings[0].recruitment_id, meeting.recruitment_id);
    checks++;
    equal(
      page.meetings[0].can_join,
      true,
      "current eligible repost is selected",
    );
    await rpc(b, "schedule_cocreate_meeting", {
      ...command(b),
      p_hub_id: hub,
      p_starts_at: instant,
      p_capacity: 7,
    });
    const first = await read(b);
    assert.ok(first.next_cursor);
    checks++;
    const second = await read(b, { p_cursor: first.next_cursor });
    equal(second.next_cursor, null, "bounded pagination completes");
    assert.notEqual(
      second.meetings[0].meeting_id,
      first.meetings[0].meeting_id,
    );
    checks++;
    await denied(
      c,
      "get_cocreate_calendar_v1",
      args(c, { p_cursor: first.next_cursor }),
      "22023",
    );
    await denied(
      b,
      "get_cocreate_calendar_v1",
      args(b, { p_cursor: "tampered" }),
      "22023",
    );
    // A second real hub cannot be substituted into an admitted General scope.
    await denied(
      b,
      "get_cocreate_calendar_v1",
      args(b, { p_hub_id: randomUUID() }),
    );
    await rpc(b, "block_user", {
      p_expected_blocker_profile_id: b.id,
      p_blocked_profile_id: a.id,
    });
    equal(
      (await read(b, { p_limit: 25 })).meetings.length,
      1,
      "blocked manager's meeting omitted without count leak",
    );
    await rpc(b, "unblock_user", {
      p_expected_blocker_profile_id: b.id,
      p_blocked_profile_id: a.id,
    });
    await sql`update private.cocreate_rooms set suppressed=true where id=${meeting.room_id}::uuid`;
    equal(
      (await read(b, { p_limit: 25 })).meetings.length,
      1,
      "suppressed meeting is omitted",
    );
    await sql`update private.cocreate_rooms set suppressed=false where id=${meeting.room_id}::uuid`;
    const oldEpisode = admissions.get(b.id);
    await rpc(b, "mutate_cocreate_hub", {
      ...command(b),
      p_hub_id: hub,
      p_episode_id: oldEpisode.episode_id,
      p_operation: "leave",
    });
    page = await read(b, { p_limit: 25 });
    equal(
      page.meetings.every((m) => !m.can_join && !m.can_confirm && !m.attending),
      true,
      "former history grants no fresh attendance",
    );
    await sql`update private.cocreate_settings set enabled=false`;
    await denied(b, "get_cocreate_calendar_v1", args(b));
    console.log(
      `COCREATE CAL01 real Auth verification passed (${checks} assertions).`,
    );
    return checks;
  } finally {
    await sql`update private.cocreate_settings set enabled=${settings.enabled}`;
  }
}
