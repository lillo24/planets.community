import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
const { sql, status } = openCocreateLocalBackend(),
  hub = randomUUID(),
  topic = randomUUID(),
  run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
const actor = (u) => ({ p_expected_profile_id: u.id });
async function rpc(u, name, args) {
  const r = await u.client.rpc(name, args);
  equal(r.error?.code ?? null, null, name + " succeeds");
  return r.data;
}
async function denied(u, name, args, code = "42501") {
  const r = await u.client.rpc(name, args);
  equal(r.error?.code, code, name + " denies");
}
async function person(name) {
  const u = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: "cocreate-source-" + run + "-" + name + "@planets.invalid",
    verifierName: "cocreate-links",
  });
  await sql`insert into public.profiles(id,display_name) values(${u.id}::uuid,${"Synthetic source " + name})`;
  await rpc(u, "accept_policy_bundle", {
    p_expected_account_id: u.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  return u;
}
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts OFF",
  );
  await sql`insert into private.cocreate_topics(id,label,active) values(${topic}::uuid,'Synthetic source linkage',true)`;
  await sql`insert into private.cocreate_hubs(id,topic_id,locality,active) values(${hub}::uuid,${topic}::uuid,${"Synthetic sources " + run},true)`;
  await sql`update private.cocreate_settings set enabled=true`;
  const a = await person("a"),
    b = await person("b"),
    outsider = await person("outsider");
  const source = await rpc(a, "mutate_cocreate_post", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_operation: "create",
    p_content: {
      title: "Synthetic public source",
      body: "Reviewed public text only",
      locality: "Synthetic sources",
      topic_id: topic,
    },
  });
  await rpc(a, "mutate_cocreate_post", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: source.post_id,
    p_expected_version: 1,
    p_operation: "publish",
  });
  const interest = await rpc(b, "mutate_cocreate_interest", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_post_id: source.post_id,
    p_operation: "request",
    p_note: "Synthetic private note must never be copied",
  });
  const accepted = await rpc(a, "mutate_cocreate_interest", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: source.post_id,
    p_operation: "accept",
    p_interest_id: interest.interest_id,
  });
  const contactArgs = { ...actor(b), p_contact_id: accepted.contact_id };
  equal(
    (await rpc(b, "get_cocreate_contact_group", contactArgs)).link,
    null,
    "No fabricated reference before linking",
  );
  await rpc(a, "mutate_cocreate_hub", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "join",
  });
  const group = await rpc(a, "mutate_cocreate_numbered_group", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "create",
  });
  const link = {
    ...actor(a),
    p_command_id: randomUUID(),
    p_post_id: source.post_id,
    p_expected_version: 2,
    p_operation: "link",
    p_hub_id: hub,
    p_room_id: group.room_id,
    p_episode_id: group.episode_id,
  };
  const linked = await Promise.all([
    rpc(a, "mutate_cocreate_post_group", link),
    rpc(a, "mutate_cocreate_post_group", link),
  ]);
  equal(
    linked[0],
    linked[1],
    "Lost/concurrent link reply changes one version only",
  );
  const shared = await rpc(b, "get_cocreate_contact_group", contactArgs);
  equal(shared.profile_id, b.id, "Actor-bound source");
  equal(shared.link.group.room_id, group.room_id, "Canonical referenced group");
  equal(
    Object.keys(shared.link).sort(),
    ["group", "locality", "state", "topic_label"],
    "Only source-safe public context",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes where actor_id=${b.id}::uuid`
    )[0].n,
    0,
    "No enrollment from acceptance/link",
  );
  await denied(outsider, "get_cocreate_contact_group", {
    ...actor(outsider),
    p_contact_id: accepted.contact_id,
  });
  await denied(b, "get_own_cocreate_post_link", {
    ...actor(b),
    p_post_id: source.post_id,
  });
  await denied(b, "mutate_cocreate_numbered_group", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_room_id: group.room_id,
    p_operation: "join",
  });
  await rpc(b, "mutate_cocreate_hub", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_operation: "join",
  });
  const member = await rpc(b, "mutate_cocreate_numbered_group", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_room_id: group.room_id,
    p_operation: "join",
  });
  equal(
    (await rpc(b, "list_own_cocreate_manageable_groups", actor(b))).length,
    0,
    "A participant gains no creator management",
  );
  const draftArgs = {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_room_id: group.room_id,
    p_episode_id: group.episode_id,
  };
  await denied(b, "create_cocreate_project_draft", {
    ...draftArgs,
    ...actor(b),
    p_command_id: randomUUID(),
    p_episode_id: member.episode_id,
  });
  const drafts = await Promise.all([
    rpc(a, "create_cocreate_project_draft", draftArgs),
    rpc(a, "create_cocreate_project_draft", draftArgs),
  ]);
  equal(drafts[0], drafts[1], "One native draft for an uncertain command");
  const destination = drafts[0].proposal_id;
  equal(
    (
      await sql`select title,summary,description,locality,public_location_label from public.proposals where id=${destination}::uuid`
    )[0],
    {
      title: null,
      summary: null,
      description: null,
      locality: null,
      public_location_label: null,
    },
    "No source content copied",
  );
  equal(
    (
      await rpc(b, "list_cocreate_group_projects", {
        ...actor(b),
        p_room_id: group.room_id,
        p_episode_id: member.episode_id,
      })
    ).length,
    0,
    "Personal unpublished draft is private",
  );
  equal(
    (
      await rpc(a, "get_own_proposal", {
        p_expected_creator_profile_id: a.id,
        p_proposal_id: destination,
      })
    )[0].proposal_id,
    destination,
    "Ordinary editor destination reads through native contract",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_project_sources where room_id=${group.room_id}::uuid`
    )[0].n,
    1,
    "Minimal source correlation only",
  );
  const version = linked[0].version;
  const choices = await Promise.all([
    a.client.rpc("mutate_cocreate_post_group", {
      ...link,
      p_command_id: randomUUID(),
      p_expected_version: version,
    }),
    a.client.rpc("mutate_cocreate_post_group", {
      ...actor(a),
      p_command_id: randomUUID(),
      p_post_id: source.post_id,
      p_expected_version: version,
      p_operation: "clear",
    }),
  ]);
  equal(
    choices.filter((r) => r.error === null).length,
    1,
    "Exactly one concurrent source CAS wins",
  );
  equal(
    choices.filter((r) => r.error?.code === "PT409").length,
    1,
    "Exactly one stale source CAS loses",
  );
  await rpc(b, "mutate_cocreate_contact", {
    ...actor(b),
    p_command_id: randomUUID(),
    p_contact_id: accepted.contact_id,
    p_operation: "close",
  });
  equal(
    (await rpc(b, "get_cocreate_contact_group", contactArgs)).link,
    null,
    "Closed contact has no continuing join invitation",
  );
  equal(
    (
      await rpc(b, "get_own_cocreate_numbered_membership", {
        ...actor(b),
        p_room_id: group.room_id,
      })
    ).active,
    true,
    "Contact closure does not revoke separate deliberate group membership",
  );
  await rpc(a, "mutate_cocreate_numbered_group", {
    ...actor(a),
    p_command_id: randomUUID(),
    p_hub_id: hub,
    p_room_id: group.room_id,
    p_episode_id: group.episode_id,
    p_operation: "leave",
  });
  equal(
    await rpc(a, "create_cocreate_project_draft", draftArgs),
    drafts[0],
    "Creator departure does not lose an already-created personal draft",
  );
  await denied(a, "create_cocreate_project_draft", {
    ...draftArgs,
    p_command_id: randomUUID(),
  });
  await sql`update private.cocreate_settings set enabled=false`;
  equal(
    (
      await rpc(a, "get_own_proposal", {
        p_expected_creator_profile_id: a.id,
        p_proposal_id: destination,
      })
    )[0].proposal_id,
    destination,
    "Sandbox/backend OFF does not change native Project authority",
  );
  console.log(
    "Co-creation source-link verification passed: " +
      checks +
      " assertions; activation OFF.",
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end();
}
