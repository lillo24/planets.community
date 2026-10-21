import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { operator } from "./operator.mjs";
import { PERSONAS, personaSessions, rpc } from "./world.mjs";

// Authentication changes only Auth session state. All product verification below
// is read-only: no seed, repair, invitation acceptance or read acknowledgement.
export async function verify(context) {
  await context.guard();
  const { sql } = context;
  const people = await personaSessions(context);
  let checks = 0;
  const equal = (actual, expected, label) => {
    assert.deepEqual(actual, expected, label);
    checks++;
  };
  const has = (value, label) => {
    assert.ok(value, label);
    checks++;
  };
  try {
    const registry =
      await sql`select persona_key,user_id,email from mock_control.personas order by persona_key`;
    equal(
      registry.map((r) => ({
        key: r.persona_key,
        id: r.user_id,
        email: r.email,
      })),
      PERSONAS.map((p) => ({ key: p.key, id: p.id, email: p.email })).sort(
        (a, b) => a.key.localeCompare(b.key),
      ),
      "Exact persona registry; no staff",
    );
    equal(
      (
        await sql`select count(*)::int n from private.moderation_staff_roles where profile_id=any(${PERSONAS.map((p) => p.id)}::uuid[])`
      )[0].n,
      0,
      "No privileged persona",
    );
    const [fixture] =
      await sql`select receipt from mock_control.fixtures where fixture_key='group:garden'`;
    has(fixture, "Garden fixture receipt exists");
    const garden = fixture.receipt;
    for (const [key, authority, membership] of [
      ["giulia", "creator", "none"],
      ["marco", "co_creator", "none"],
      ["sara", "co_organizer", "current"],
      ["dario", null, "current"],
      ["elena", null, "none"],
    ]) {
      const person = people[key];
      const [role] = await rpc(person, "get_own_group_role", {
        p_expected_profile_id: person.id,
        p_group_id: garden,
      });
      equal(
        role.authority_role,
        authority,
        `${key} authority remains separate`,
      );
      // Creator membership is intentionally independent; current runtime may
      // represent no membership as null. Never create membership to satisfy QA.
      equal(role.membership_status ?? "none", membership, `${key} membership`);
      const { data, error } = await person.client
        .from("profiles")
        .select("id,display_name")
        .eq("id", person.id)
        .single();
      equal(error, null, "Own profile readable with ordinary token");
      has(data?.display_name, "Ready profile");
    }
    const settings = await rpc(people.sara, "get_group_discussion_settings", {
      p_expected_profile_id: people.sara.id,
      p_group_id: garden,
    });
    const general = await rpc(people.sara, "get_group_discussion_v2", {
      p_expected_profile_id: people.sara.id,
      p_room_id: settings.general_room_id,
    });
    equal(general.access, "general", "General uses accepted Group membership");
    const denied = await people.elena.client.rpc("get_group_discussion_v2", {
      p_expected_profile_id: people.elena.id,
      p_room_id: settings.general_room_id,
    });
    equal(denied.error?.code, "42501", "Unjoined persona cannot read General");
    const [project] =
      await sql`select receipt from mock_control.fixtures where fixture_key='proposal:garden'`;
    const publicProjects = await rpc(people.elena, "list_public_proposals", {
      p_limit: 50,
    });
    has(
      publicProjects.some((p) => p.proposal_id === project.receipt),
      "Canonical public discovery contains fixture",
    );
    const [history] =
      await sql`select p.id,private.derive_proposal_status(p.starts_at,p.ends_at,now()) state
      from public.proposals p join mock_control.fixtures f on f.receipt=to_jsonb(p.id::text) where f.fixture_key='proposal:history'`;
    equal(
      history?.state,
      "completed",
      "History is meaningful completed content",
    );
    has(
      (
        await sql`select count(*)::int n from private.proposal_templates where source_proposal_id=${history.id}::uuid`
      )[0].n > 0,
      "Reusable canonical template exists",
    );
    has(
      (
        await sql`select count(*)::int n from public.project_chat_messages where chat_id in(select id from public.project_group_chats where project_id=${project.receipt}::uuid)`
      )[0].n > 0,
      "Persisted human Project message",
    );
    const [photo] = await rpc(people.dario, "get_own_profile_photo", {
      p_expected_profile_id: people.dario.id,
    });
    equal(photo, undefined, "Photo-free invitation scenario preserved");
    for (const person of Object.values(people).filter((p) => p.asset)) {
      const [row] = await rpc(person, "get_own_profile_photo", {
        p_expected_profile_id: person.id,
      });
      has(row?.object_path, "Canonical photo metadata");
      const bytes = await person.client.storage
        .from("profile-photos")
        .download(row.object_path);
      equal(bytes.error, null, "Ordinary owner Storage access");
      has(bytes.data?.size > 0, "Usable image bytes");
    }
    return { checks, personas: PERSONAS.length };
  } finally {
    for (const person of Object.values(people))
      await person.client.auth.signOut({ scope: "local" });
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  let context;
  try {
    context = await operator(process.argv[2]);
    console.log(JSON.stringify(await verify(context)));
  } catch {
    console.error(
      "Mock read-only verification failed; fixture drift is not repaired.",
    );
    process.exitCode = 1;
  } finally {
    await context?.sql.end();
  }
}
