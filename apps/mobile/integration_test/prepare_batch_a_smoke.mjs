import { gzipSync } from "node:zlib";
// Only synthetic OTP identities and an explicitly disposable loopback stack.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "../../../scripts/lib/local-profile-photo.mjs";
const root = process.cwd(),
  output = path.resolve(process.argv[2] ?? "");
if (!process.argv[2] || output.toLowerCase().startsWith(root.toLowerCase()))
  throw new Error("Use a temporary defines path outside Git.");
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL;
if (process.env.PLANETS_DISPOSABLE_QA !== "1")
  throw new Error("Designate disposable QA.");
for (const url of [apiUrl, databaseUrl, mailpitUrl])
  if (!url || !["localhost", "127.0.0.1"].includes(new URL(url).hostname))
    throw new Error("Loopback services required.");
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(user, name, params) {
  const { data, error } = await user.client.rpc(name, params);
  if (error) throw new Error(`${name} failed (${error.code}).`);
  return data;
}
try {
  const defines = {
    APP_ENV: "local",
    SUPABASE_URL: apiUrl,
    SUPABASE_PUBLISHABLE_KEY: publishableKey,
  };
  const actors = {};
  for (const role of ["skip", "create", "protected", "manager", "member"]) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `batch-a-${role}-${randomUUID().slice(0, 8)}@planets.invalid`,
      verifierName: "Batch A native synthetic",
    });
    const complete = ["manager", "member"].includes(role);
    await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,${complete ? `Fictional ${role}` : null})`;
    await rpc(user, "accept_policy_bundle", {
      p_expected_account_id: user.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    if (complete) await ensureLocalProfilePhoto(user);
    defines[`BATCH_${role.toUpperCase()}_ID`] = user.id;
    defines[`BATCH_${role.toUpperCase()}_TOKEN`] =
      await user.client.accessToken();
    actors[role] = user;
  }
  const owner = actors.manager;
  const project = await createPublishedProposal(owner),
    tavolo = await createPublishedTavolo(owner);
  for (const id of [project, tavolo]) {
    const request = await rpc(actors.member, "request_to_join_project", {
      p_expected_requester_profile_id: actors.member.id,
      p_project_id: id,
      p_request_message: "Local synthetic native journey",
    });
    const membership = await rpc(
      owner,
      "accept_project_join_request_as_manager",
      { p_expected_manager_profile_id: owner.id, p_request_id: request },
    );
    defines[
      id === project ? "BATCH_PROJECT_MEMBERSHIP" : "BATCH_TAVOLO_MEMBERSHIP"
    ] = membership;
  }
  const group = await rpc(owner, "create_group_draft", {
    p_expected_profile_id: owner.id,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "Batch A invitation garden",
      description: "Fictional people caring for a local garden together.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(owner, "set_group_publication_state", {
    p_expected_profile_id: owner.id,
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const [invitation] = await rpc(owner, "create_group_participant_invitation", {
    p_expected_profile_id: owner.id,
    p_group_id: group,
    p_client_request_id: randomUUID(),
  });
  Object.assign(defines, {
    BATCH_PROJECT: project,
    BATCH_TAVOLO: tavolo,
    BATCH_GROUP: group,
    BATCH_GROUP_TOKEN: invitation.invite_token,
  });
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: defines.APP_ENV,
      SUPABASE_URL: defines.SUPABASE_URL,
      SUPABASE_PUBLISHABLE_KEY: defines.SUPABASE_PUBLISHABLE_KEY,
      BATCH_FIXTURE: gzipSync(Buffer.from(JSON.stringify(defines))).toString(
        "base64",
      ),
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared five synthetic OTP accounts, policy records, Proposal/Tavolo current member and local group invitation. Private defines saved outside Git.",
  );
} finally {
  await sql.end();
}
async function createPublishedProposal(creator, publish = true) {
  const projectId = await rpc(creator, "create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Shared workspace verifier Project",
    p_summary: "A deterministic Project for workspace access verification.",
    p_description:
      "This Project verifies current manager and participant workspace access.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Provincia autonoma di Trento",
    p_public_location_label: "Trento",
    p_exact_meeting_text: "Workspace verifier meeting point",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (publish) {
    await rpc(creator, "publish_proposal", {
      p_expected_creator_profile_id: creator.id,
      p_proposal_id: projectId,
    });
  }
  return projectId;
}

async function createPublishedTavolo(creator, publish = true) {
  const id = await rpc(creator, "create_recurring_activity_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Workspace Tavolo verifier",
    p_summary: "Synthetic workspace verification",
    p_description: "Local synthetic recurring Project",
    p_topic: "Garden",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Trento",
    p_public_location_label: "Trento",
    p_exact_meeting_text: "Synthetic meeting point",
    p_exact_location_visibility: "participants",
    p_recurrence_type: "weekly",
    p_weekday: 2,
    p_day_of_month: null,
    p_local_start_time: "10:00",
    p_duration_minutes: 60,
    p_event_timezone: "Europe/Rome",
    p_effective_from: "2098-01-01",
    p_people_capacity: 20,
  });
  if (publish)
    await rpc(creator, "publish_recurring_activity", {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: id,
    });
  return id;
}
