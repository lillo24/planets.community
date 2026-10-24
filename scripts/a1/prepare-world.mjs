import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { access, writeFile } from "node:fs/promises";
import path from "node:path";
import { signInLocalOtpUser } from "../lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "../lib/local-profile-photo.mjs";
import { openA1World, rpc } from "./owned-world.mjs";

const { directory, status, sql } = await openA1World(process.argv[2]);
const output = path.join(directory, "private-world.json");
await assert.rejects(
  access(output),
  "Use one fresh owned A1 world; do not replay fixture creation.",
);
const run = randomUUID().slice(0, 8);
const people = {};
try {
  for (const [key, name] of [
    ["alice", "Alice"],
    ["marco", "Marco"],
    ["outsider", "Fictional observer"],
  ]) {
    const email = `a1-${run}-${key}@planets.invalid`;
    const user = await signInLocalOtpUser({
      ...status,
      mailpitUrl: "http://127.0.0.1:61324",
      email,
      verifierName: "A1",
    });
    const inserted = await user.client.from("profiles").insert({ id: user.id });
    assert.equal(inserted.error, null);
    await rpc(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: name,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "private",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    await rpc(user, "accept_policy_bundle", {
      p_expected_account_id: user.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    await ensureLocalProfilePhoto(user);
    people[key] = { ...user, email };
  }
  const { alice, marco } = people,
    project = randomUUID(),
    reverse = randomUUID(),
    listing = randomUUID(),
    group = randomUUID();
  await sql`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
    values(${project},${alice.id},'published','Il giardino del quartiere',now()+interval '1 day',now()+interval '2 days',now()),
      (${reverse},${marco.id},'published','Una serata di giochi',now()+interval '2 days',now()+interval '3 days',now())`;
  await sql`insert into public.resource_listings(id,owner_profile_id,listing_mode,lifecycle_state,title,description,country_code,locality,public_location_label,published_at)
    values(${listing},${alice.id},'donate','published','Attrezzi per il giardino','Materiale immaginario per la verifica locale.','IT','Trento','Trento',now())`;
  await sql`insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
    values(${group},'Il nostro quartiere','Gruppo immaginario per la verifica locale.','informal',false,'published',${alice.id})`;
  await sql`insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)values(${group},${alice.id},${alice.id})`;
  await sql`insert into private.group_memberships(group_id,profile_id,admitted_by)values(${group},${marco.id},${alice.id})`;
  await sql`update private.cocreate_settings set enabled=true`;
  const first = await rpc(marco, "request_to_join_project", {
    p_expected_requester_profile_id: marco.id,
    p_project_id: project,
    p_request_message: "Vorrei aiutare con il giardino.",
  });
  const second = await rpc(alice, "request_to_join_project", {
    p_expected_requester_profile_id: alice.id,
    p_project_id: reverse,
    p_request_message: "Porto volentieri un gioco.",
  });
  const resourceRequest = await rpc(marco, "request_resource_listing", {
    p_expected_requester_profile_id: marco.id,
    p_listing_id: listing,
    p_message: "Vorrei usare gli attrezzi per il giardino.",
  });
  await rpc(alice, "accept_resource_listing_request", {
    p_expected_owner_profile_id: alice.id,
    p_request_id: resourceRequest,
  });
  const memberRequest = await rpc(marco, "submit_member_contact_request", {
    p_expected_profile_id: marco.id,
    p_action_id: randomUUID(),
    p_group_id: group,
    p_recipient_profile_id: alice.id,
    p_note: "Ci organizziamo insieme?",
  });
  const member = await rpc(alice, "accept_member_contact_request", {
    p_expected_profile_id: alice.id,
    p_action_id: randomUUID(),
    p_request_id: memberRequest.request_id,
  });
  const contacts = [];
  for (const [title, author, requester] of [
    ["Passeggiata e disegno", alice, marco],
    ["Giochi da tavolo nel quartiere", marco, alice],
  ]) {
    const draft = await rpc(author, "mutate_cocreate_post", {
      p_expected_profile_id: author.id,
      p_command_id: randomUUID(),
      p_operation: "create",
      p_content: {
        title,
        body: "Un incontro immaginario per conoscerci e fare qualcosa insieme.",
        locality: "Trento",
      },
    });
    await rpc(author, "mutate_cocreate_post", {
      p_expected_profile_id: author.id,
      p_command_id: randomUUID(),
      p_operation: "publish",
      p_post_id: draft.post_id,
      p_expected_version: draft.version,
    });
    const interest = await rpc(requester, "mutate_cocreate_interest", {
      p_expected_profile_id: requester.id,
      p_command_id: randomUUID(),
      p_post_id: draft.post_id,
      p_operation: "request",
      p_note: "Mi piacerebbe partecipare.",
    });
    const contact = await rpc(author, "mutate_cocreate_interest", {
      p_expected_profile_id: author.id,
      p_command_id: randomUUID(),
      p_post_id: draft.post_id,
      p_operation: "accept",
      p_interest_id: interest.interest_id,
    });
    contacts.push(contact.contact_id);
  }
  const resource = (
    await rpc(alice, "get_own_resource_request_chat", {
      p_expected_profile_id: alice.id,
      p_chat_id: (
        await sql`select id from public.resource_request_chats where request_id=${resourceRequest}`
      )[0].id,
    })
  )[0];
  const pair = (
    await rpc(alice, "get_own_participation_conversation", {
      p_expected_profile_id: alice.id,
      p_request_id: first,
    })
  )[0];
  await rpc(marco, "send_participation_conversation_message", {
    p_expected_profile_id: marco.id,
    p_chat_id: pair.chat_id,
    p_body: "Ciao Alice! Sabato posso aiutare in giardino.",
  });
  await rpc(marco, "send_resource_request_chat_message", {
    p_expected_profile_id: marco.id,
    p_chat_id: resource.chat_id,
    p_body: "Ho preparato gli attrezzi per sabato.",
  });
  await rpc(marco, "mutate_cocreate_contact", {
    p_expected_profile_id: marco.id,
    p_command_id: randomUUID(),
    p_contact_id: contacts[0],
    p_operation: "send",
    p_body: "Per la passeggiata possiamo scegliere insieme il percorso.",
  });
  await rpc(marco, "send_member_contact_message", {
    p_expected_profile_id: marco.id,
    p_action_id: randomUUID(),
    p_chat_id: member.chat_id,
    p_episode_id: member.episode_id,
    p_body: "Avviso anche le persone del nostro gruppo.",
  });
  await rpc(marco, "mutate_cocreate_contact", {
    p_expected_profile_id: marco.id,
    p_command_id: randomUUID(),
    p_contact_id: contacts[1],
    p_operation: "send",
    p_body: "Porterò anche un gioco da tavolo.",
  });
  const safePeople = Object.fromEntries(
    Object.entries(people).map(([key, p]) => [
      key,
      { id: p.id, email: p.email },
    ]),
  );
  const world = {
    people: safePeople,
    project,
    reverse,
    first,
    second,
    resourceChat: resource.chat_id,
    resourceRequest,
    agreement: resource.agreement_id,
    member,
    contacts,
    group,
  };
  await writeFile(output, JSON.stringify(world));
  await writeFile(
    path.join(directory, "private-defines.json"),
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: status.apiUrl,
      SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
      ENABLE_DEMO_TOOLS: "false",
      A1_ALICE_EMAIL: alice.email,
      A1_MARCO_EMAIL: marco.email,
      A1_ALICE_ID: alice.id,
      A1_MARCO_ID: marco.id,
      A1_RESOURCE_CHAT: resource.chat_id,
      A1_REQUEST: first,
    }),
  );
  console.log(
    "A1 fictional world ready: two people, reversed Project requests, Resource, member contact, two accepted People posts, five original human messages.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
