import assert from "node:assert/strict";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

// Only the selected disposable local stack. No hosted credentials or service-role writes.
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl) throw new Error("Skills verification requires a local database URL.");
assert.ok(process.env.PLANETS_DISPOSABLE_QA === "1" || process.env.CI === "true", "UI02 requires an explicitly disposable QA stack");
const mailpitUrl = (process.env.MAILPIT_URL ?? "http://127.0.0.1:54324").replace(/\/$/, "");
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname), "UI02 requires loopback API/database/mailbox URLs");
}
const sql = postgres(databaseUrl, { max: 6, onnotice: () => {} });
try {
  const [creator, coCreator, organizer, participant] = await Promise.all(
    ["creator", "cocreator", "organizer", "participant"].map(async (name) => {
      const user = await signInLocalOtpUser({ apiUrl, publishableKey, mailpitUrl,
        email: `ui02-${name}@planets.invalid`, verifierName: "proposal-skills" });
      const { error } = await user.client.from("profiles").insert({ id: user.id });
      if (error && !(error.code === "23505" && `${error.message} ${error.details}`.includes("profiles_pkey"))) {
        throw failure("profile anchor", error);
      }
      await rpc(user, "update_own_profile", {
        p_expected_profile_id: user.id, p_display_name: `UI02 ${name}`, p_bio: null,
        p_skill_ids: [], p_display_name_audience: "public", p_bio_audience: "private", p_skills_audience: "public",
      });
      await ensureLocalProfilePhoto(user);
      return user;
    }),
  );
  const [{ id: skill }] = await sql`select id from public.skills where slug = 'mural-painting'`;
  const content = {
    p_title: "UI02 skills concurrency", p_summary: "Local skills verification",
    p_description: "Original description", p_starts_at: "2098-01-02T10:00:00Z", p_ends_at: "2098-01-02T14:00:00Z",
    p_event_timezone: "Europe/Rome", p_country_code: "IT", p_locality: "Trento", p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo", p_exact_meeting_text: "Protected meeting text", p_exact_location_visibility: "participants",
    p_skill_ids: [skill], p_skill_importances: ["required"], p_registration_capacity: 12, p_count_organizers_toward_capacity: false,
  };
  const project = await rpc(creator, "create_proposal_draft", { p_expected_creator_profile_id: creator.id, ...content });
  await rpc(creator, "publish_proposal", { p_expected_creator_profile_id: creator.id, p_proposal_id: project });
  const grant = async (user, role) => {
    const [invite] = await rpc(creator, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: creator.id, p_project_id: project, p_requested_authority_role: role,
    });
    return rpc(user, "accept_project_delegate_invitation", { p_expected_delegate_profile_id: user.id, p_token: invite.invite_token });
  };
  const delegateId = await grant(coCreator, "co_creator");
  await grant(organizer, "co_organizer");
  const skills = (user, expected, importance) => user.client.rpc("update_proposal_skills", {
    p_expected_structural_profile_id: user.id, p_proposal_id: project, p_expected_skills: { [skill]: expected },
    p_skill_ids: [skill], p_skill_importances: [importance],
  });
  const details = { p_expected_creator_profile_id: creator.id, p_proposal_id: project,
    ...content, p_description: "Concurrent content", p_registration_capacity: 17,
    p_exact_meeting_text: "New private entrance", p_skill_ids: null, p_skill_importances: null };

  // A full form holds the row first. The skill writer must wait and retain ALL other fields.
  await queued(creator, async (tx) => fullUpdate(tx, details), () => skills(coCreator, "required", "useful"));
  const before = await snapshot(project);
  assert.equal(before.proposal.description, "Concurrent content");
  assert.equal(before.project.registration_capacity, 17);
  assert.equal(before.meeting.exact_meeting_text, "New private entrance");
  assert.equal(before.skills[0].importance, "useful");

  // The skill writer holds the row first. An older open details form must preserve those skills.
  await queued(coCreator, async (tx) => {
    await tx`select public.update_proposal_skills(${coCreator.id}::uuid, ${project}::uuid,
      ${JSON.stringify({ [skill]: "useful" })}::jsonb, array[${skill}::uuid], array['required'])`;
  }, () => creator.client.rpc("update_own_proposal", { ...details, p_description: "Second content save" }));
  assert.equal((await snapshot(project)).skills[0].importance, "required");
  assert.equal((await snapshot(project)).proposal.description, "Second content save");

  const unchanged = await snapshot(project);
  // Two overlapping skill writers: one commits, the other detects the stale collection.
  const race = await Promise.all([skills(creator, "required", "useful"), skills(coCreator, "required", "useful")]);
  assert.equal(race.filter((r) => !r.error).length, 1);
  assert.equal(race.find((r) => r.error)?.error.code, "40001");
  const after = await snapshot(project);
  assert.deepEqual(after.proposal, unchanged.proposal);
  assert.deepEqual(after.project, unchanged.project);
  assert.deepEqual(after.meeting, unchanged.meeting);
  const publicRows = await rpc(participant, "get_public_proposal", { p_proposal_id: project });
  assert.equal(publicRows[0].skills[0].importance, "useful");
  const requestId = await rpc(participant, "request_to_join_project", {
    p_expected_requester_profile_id: participant.id, p_project_id: project,
    p_request_message: "UI02 participant gate", p_skill_ids: [], p_resource_need_ids: [],
  });
  await rpc(creator, "accept_project_join_request", { p_expected_creator_profile_id: creator.id, p_request_id: requestId });
  for (const user of [organizer, participant]) await denied(skills(user, "useful", "required"), "42501");
  await denied(coCreator.client.rpc("create_project_resource_need", {
    p_expected_creator_profile_id: coCreator.id, p_project_id: project, p_title: "Not authorized", p_details: null,
  }), "42501");
  await denied(creator.client.rpc("update_proposal_skills", {
    p_expected_structural_profile_id: participant.id, p_proposal_id: project,
    p_expected_skills: { [skill]: "useful" }, p_skill_ids: [], p_skill_importances: [],
  }), "42501");
  const anon = createClient(apiUrl, publishableKey, { auth: { persistSession: false } });
  await denied(anon.rpc("update_proposal_skills", {
    p_expected_structural_profile_id: creator.id, p_proposal_id: project,
    p_expected_skills: { [skill]: "useful" }, p_skill_ids: [], p_skill_importances: [],
  }), "42501");

  // Canonical revocation owns activity then registry locks; a queued save must recheck authority.
  await queued(creator, async (tx) => {
    await tx`select public.revoke_project_delegate(${creator.id}::uuid, ${delegateId}::uuid)`;
  }, () => skills(coCreator, "useful", "required"), "42501");
  assert.equal((await snapshot(project)).skills[0].importance, "useful");
  await sql`update public.proposals set starts_at=now()-interval '1 hour', ends_at=now()+interval '1 hour' where id=${project}::uuid`;
  await denied(skills(creator, "useful", "required"), "55000");
  console.log("Confirmed skill-only writes, both queued form/skill save orders, concurrent skill conflicts, safe public projection, actor/lifecycle gates, resource privilege separation and queued revocation.");
} finally {
  await sql.end();
}

async function queued(actor, hold, request, expectedError = null) {
  const tx = await sql.reserve();
  let pending;
  try {
    await tx`begin`;
    await tx`set local statement_timeout='15s'`;
    const [{ pid }] = await tx`select pg_backend_pid() as pid`;
    await tx`select set_config('request.jwt.claim.sub', ${actor.id}, true)`;
    await tx`set local role authenticated`;
    await hold(tx);
    // Start PostgREST eagerly (builders are lazy thenables).
    pending = Promise.resolve(request());
    const deadline = Date.now() + 10000;
    let blocked = false;
    while (Date.now() < deadline) {
      const [{ waiting }] = await sql`select exists(select 1 from pg_stat_activity where ${pid}::integer = any(pg_blocking_pids(pid))) as waiting`;
      if (waiting) { blocked = true; break; }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    assert.equal(blocked, true, "PostgREST writer did not queue behind the activity lock");
    await tx`commit`;
    const result = await pending;
    assert.equal(result.error?.code ?? null, expectedError);
  } finally {
    await tx`rollback`;
    tx.release();
    if (pending) await pending;
  }
}
async function fullUpdate(tx, params) {
  // Named parameters choose the current capacity overload, preserving its original behavior.
  const types = ["uuid", "uuid", "text", "text", "text", "timestamptz", "timestamptz", "text", "text", "text", "text", "text", "text", "text", "uuid[]", "text[]", "integer", "boolean"];
  const names = ["p_expected_creator_profile_id", "p_proposal_id", ...Object.keys(params).filter((k) => !["p_expected_creator_profile_id", "p_proposal_id"].includes(k))];
  assert.equal(names.length, types.length);
  await tx.unsafe(`select public.update_own_proposal(${names.map((name, i) => `${name} => $${i + 1}::${types[i]}`).join(", ")})`, names.map((name) => params[name]));
}
async function snapshot(id) {
  const [proposal] = await sql`select to_jsonb(p)-'updated_at' as value from public.proposals p where id=${id}::uuid`;
  const [project] = await sql`select to_jsonb(p)-'updated_at' as value from public.projects p where id=${id}::uuid`;
  const [meeting] = await sql`select to_jsonb(p)-'updated_at' as value from public.proposal_meeting_details p where proposal_id=${id}::uuid`;
  const skills = await sql`select skill_id, importance from public.proposal_skills where proposal_id=${id}::uuid order by skill_id`;
  return { proposal: proposal.value, project: project.value, meeting: meeting.value, skills: Array.from(skills) };
}
async function rpc(user, name, params) {
  const { data, error } = await user.client.rpc(name, params);
  if (error) throw failure(name, error);
  return data;
}
async function denied(request, code) {
  const result = await request;
  assert.equal(result.error?.code, code);
  assert.equal(result.data, null);
}
function failure(action, error) {
  return new Error(`Proposal skills verification failed at ${action} (code ${error?.code ?? "unknown"}).`);
}
