import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Never accepts a hosted URL/key. The named engine belongs to this programme.
assert.equal(process.env.CONTAINER_CONNECTION, "planets-cocreate-qa-root");
assert.equal(
  process.env.DOCKER_HOST,
  "npipe:////./pipe/podman-planets-cocreate-qa",
);
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
    "Co-creation verification requires the owned loopback stack.",
  );
}
const sql = postgres(status.databaseUrl, { max: 6, onnotice: () => {} });
let checks = 0;
const equal = (actual, expected, label) => {
  assert.deepEqual(actual, expected, label);
  checks++;
};
const run = randomUUID().slice(0, 8);
async function user(name) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: "cocreate-" + run + "-" + name + "@planets.invalid",
    verifierName: "cocreate-posts",
  });
  await sql`insert into public.profiles(id,display_name)
    values(${person.id}::uuid,${"Fictional co-creation " + name})`;
  await rpc(person, "accept_policy_bundle", {
    p_expected_account_id: person.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return person;
}
async function rpc(person, name, args) {
  const result = await person.client.rpc(name, args);
  equal(result.error?.code ?? null, null, name + " succeeds");
  return result.data;
}
async function denied(person, name, args, code = "42501") {
  const result = await person.client.rpc(name, args);
  equal(result.error?.code, code, name + " rejects");
}
const actor = (person) => ({ p_expected_profile_id: person.id });
async function post(person, title) {
  const args = {
    ...actor(person),
    p_command_id: randomUUID(),
    p_operation: "create",
    p_content: {
      title: "Synthetic " + title + " " + run,
      body: "Fictional test content",
      locality: "Trento",
    },
  };
  const draft = await rpc(person, "mutate_cocreate_post", args);
  equal(
    await rpc(person, "mutate_cocreate_post", args),
    draft,
    "Lost create response recovers exactly",
  );
  await denied(
    person,
    "mutate_cocreate_post",
    { ...args, p_content: { title: "Changed intent" } },
    "22023",
  );
  const published = await rpc(person, "mutate_cocreate_post", {
    ...actor(person),
    p_command_id: randomUUID(),
    p_operation: "publish",
    p_post_id: draft.post_id,
    p_expected_version: draft.version,
  });
  return published;
}
const interestArgs = (person, source) => ({
  ...actor(person),
  p_command_id: randomUUID(),
  p_post_id: source.post_id,
  p_operation: "request",
});
let configured = false;
try {
  const settings =
    await sql`select enabled from private.cocreate_settings where singleton`;
  equal(settings.length, 1, "Canonical configuration exists");
  equal(settings[0].enabled, false, "Owned stack starts disabled");
  await sql`update private.cocreate_settings set enabled=true where singleton`;
  configured = true;
  const a = await user("author"),
    b = await user("requester");
  const outsider = await user("outsider"),
    staff = await user("staff");
  const source = await post(a, "football");
  const request = interestArgs(b, source);
  request.p_note = "Private fictional note";
  const pending = await rpc(b, "mutate_cocreate_interest", request);
  equal(
    await rpc(b, "mutate_cocreate_interest", request),
    pending,
    "Request retry never retransmits",
  );
  equal(
    await rpc(outsider, "list_own_cocreate_interests", {
      ...actor(outsider),
      p_post_id: source.post_id,
    }),
    [],
    "Other authors see no private note",
  );
  const accept = {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: source.post_id,
    p_operation: "accept",
    p_interest_id: pending.interest_id,
  };
  const accepted = await Promise.all([
    rpc(a, "mutate_cocreate_interest", accept),
    rpc(a, "mutate_cocreate_interest", accept),
  ]);
  equal(
    accepted[0],
    accepted[1],
    "Concurrent duplicate acceptance has one result",
  );
  const room = accepted[0].contact_id;
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_contacts where post_id=${source.post_id}::uuid`
    )[0].n,
    1,
    "One post-scoped contact",
  );
  const send = {
    ...actor(a),
    p_command_id: randomUUID(),
    p_contact_id: room,
    p_operation: "send",
    p_body: "Private synthetic message",
  };
  const messages = await Promise.all([
    rpc(a, "mutate_cocreate_contact", send),
    rpc(a, "mutate_cocreate_contact", send),
  ]);
  equal(messages[0], messages[1], "Concurrent send retry writes once");
  await denied(
    a,
    "mutate_cocreate_contact",
    { ...send, p_body: "Changed message" },
    "22023",
  );
  await denied(outsider, "get_cocreate_contact_page", {
    ...actor(outsider),
    p_contact_id: room,
  });
  await denied(staff, "get_cocreate_contact_page", {
    ...actor(staff),
    p_contact_id: room,
  });
  const page = await rpc(b, "get_cocreate_contact_page", {
    ...actor(b),
    p_contact_id: room,
  });
  equal(
    page.messages.length,
    1,
    "Only genuine persisted human message returned",
  );
  equal(page.profile_id, b.id, "Page binds the expected viewer");
  equal(page.contact_id, room, "Page binds the exact contact");
  await rpc(b, "acknowledge_cocreate_contact", {
    ...actor(b),
    p_contact_id: room,
    p_read_token: page.read_token,
  });
  equal(
    (await rpc(b, "list_own_cocreate_contacts", actor(b)))[0].unread_count,
    0,
    "Rendered ACK clears canonical unread",
  );
  await denied(a, "acknowledge_cocreate_contact", {
    ...actor(a),
    p_contact_id: room,
    p_read_token: page.read_token,
  });
  const report = await rpc(b, "submit_cocreate_report", {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_target_kind: "cocreate_contact_message",
    p_target_id: page.messages[0].message_id,
    p_category: "spam",
    p_explanation: "Synthetic test report explanation",
  });
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff.id}::uuid,'moderator')`;
  const evidence = await rpc(staff, "get_moderation_case_cocreate", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report[0].case_id,
  });
  equal(
    evidence.message_id,
    page.messages[0].message_id,
    "Staff get only scoped reported message evidence",
  );
  await denied(staff, "get_cocreate_contact_page", {
    ...actor(staff),
    p_contact_id: room,
  });

  // Distinct accounts race opposite state transitions on the same post/request.
  const racePost = await post(a, "race");
  const raceInterest = await rpc(
    outsider,
    "mutate_cocreate_interest",
    interestArgs(outsider, racePost),
  );
  const race = await Promise.all([
    a.client.rpc("mutate_cocreate_interest", {
      ...actor(a),
      p_command_id: randomUUID(),
      p_post_id: racePost.post_id,
      p_operation: "accept",
      p_interest_id: raceInterest.interest_id,
    }),
    outsider.client.rpc("mutate_cocreate_interest", {
      ...actor(outsider),
      p_command_id: randomUUID(),
      p_post_id: racePost.post_id,
      p_operation: "withdraw",
      p_interest_id: raceInterest.interest_id,
    }),
  ]);
  equal(
    race.filter((r) => r.error === null).length,
    1,
    "Exactly one accept/withdraw wins",
  );
  equal(
    race.find((r) => r.error)?.error.code,
    "PT409",
    "Losing state transition is an explicit conflict",
  );
  const terminal =
    await sql`select state from private.cocreate_interests where id=${raceInterest.interest_id}::uuid`;
  assert.ok(["accepted", "withdrawn"].includes(terminal[0].state));
  checks++;
  const expiryPost = await post(a, "expiry");
  await sql`update private.cocreate_posts set expires_at=clock_timestamp()-interval '1 second' where id=${expiryPost.post_id}::uuid`;
  equal(
    await rpc(b, "get_cocreate_post", { p_post_id: expiryPost.post_id }),
    null,
    "Expired detail is not public",
  );
  await denied(b, "mutate_cocreate_interest", interestArgs(b, expiryPost));
  const publicRows = await rpc(outsider, "list_cocreate_posts", {
    p_search: run,
    p_limit: 50,
  });
  equal(
    publicRows.some((p) => p.post_id === expiryPost.post_id),
    false,
    "Expiry is enforced before pagination",
  );
  for (const row of publicRows) {
    equal(
      Object.keys(row).sort(),
      [
        "post_id",
        "title",
        "body",
        "locality",
        "topic_id",
        "created_at",
        "expires_at",
      ].sort(),
      "Public projection has no private note/contact/identity field",
    );
  }
  const closed = await rpc(a, "mutate_cocreate_post", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_operation: "close",
    p_post_id: source.post_id,
    p_expected_version: source.version,
  });
  equal(closed.state, "closed", "Explicit close ends discovery only");
  equal(
    (
      await rpc(b, "get_cocreate_contact_page", {
        ...actor(b),
        p_contact_id: room,
      })
    ).messages.length,
    1,
    "Accepted history survives post closure",
  );
  await rpc(b, "block_user", {
    p_expected_blocker_profile_id: b.id,
    p_blocked_profile_id: a.id,
  });
  await denied(b, "get_cocreate_contact_page", {
    ...actor(b),
    p_contact_id: room,
  });
  await rpc(b, "submit_cocreate_report", {
    p_expected_reporter_profile_id: b.id,
    p_client_submission_id: randomUUID(),
    p_target_kind: "cocreate_contact_message",
    p_target_id: page.messages[0].message_id,
    p_category: "spam",
    p_explanation: "Synthetic report after blocking",
  });
  await sql`update private.cocreate_settings set enabled=false where singleton`;
  await denied(a, "list_cocreate_posts", {});
  await rpc(b, "mutate_cocreate_contact", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_contact_id: room,
    p_operation: "close",
  });
  console.log(
    "Co-creation post/contact verification passed: " +
      checks +
      " assertions; activation OFF.",
  );
} finally {
  if (configured)
    await sql`update private.cocreate_settings set enabled=false where singleton`;
  await sql.end();
}
