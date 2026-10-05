// Disposable synthetic loopback fixture, not the TW05 demo world.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "../../../scripts/lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";

const root = process.cwd();
const output = resolve(process.argv[2] ?? "");
if (
  !process.argv[2] ||
  output.toLowerCase().startsWith(resolve(root).toLowerCase())
) {
  throw new Error(
    "Provide an OS-temporary defines-file path outside the repository.",
  );
}
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  if (
    !url ||
    !["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname)
  ) {
    throw new Error(
      "Workshop smoke fixtures require disposable loopback services.",
    );
  }
}
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error)
    throw new Error(`Workshop fixture ${name} failed (${error.code}).`);
  return data;
}
try {
  const actor = await signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email: "tw04-smoke-creator@planets.invalid",
    verifierName: "TW04 synthetic Creator",
  });
  const staff = await signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email: "tw04-smoke-reviewer@planets.invalid",
    verifierName: "TW04 synthetic reviewer",
  });
  for (const user of [actor, staff]) {
    await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,'TW04 synthetic person') on conflict(id) do update set display_name=excluded.display_name`;
  }
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at)
    values(${staff.id}::uuid,'moderator',true,null) on conflict(profile_id) do update set is_active=true,deactivated_at=null`;
  await ensureLocalProfilePhoto(actor);
  const [{ id: skillId }] =
    await sql`select id from public.skills where slug='mural-painting'`;
  const sourceId = await rpc(actor.client, "create_proposal_draft", {
    p_expected_creator_profile_id: actor.id,
    p_title: "TW04 synthetic completed garden",
    p_summary: "Synthetic reusable garden idea",
    p_description:
      "Synthetic open resource preview and private draft smoke fixture.",
    p_starts_at: new Date(Date.now() + 172800000).toISOString(),
    p_ends_at: new Date(Date.now() + 180000125).toISOString(),
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Synthetic locality",
    p_administrative_area: null,
    p_public_location_label: "Synthetic public place",
    p_exact_meeting_text: "Synthetic local meeting text",
    p_exact_location_visibility: "participants",
    p_skill_ids: [skillId],
    p_skill_importances: ["useful"],
    p_registration_capacity: 8,
    p_count_organizers_toward_capacity: false,
  });
  for (let i = 0; i < 51; i++)
    await rpc(actor.client, "create_project_resource_need", {
      p_expected_creator_profile_id: actor.id,
      p_project_id: sourceId,
      p_title: `Synthetic need ${i}`,
      p_details: `Synthetic reusable description ${i}`,
    });
  await rpc(actor.client, "publish_proposal", {
    p_expected_creator_profile_id: actor.id,
    p_proposal_id: sourceId,
  });
  // Trusted adjustment only on this synthetic disposable local source. Domain
  // clients never backdate events or bypass the post-start structural lock.
  await sql`update public.proposals set starts_at='2020-01-01T00:00:00Z',ends_at='2020-01-01T02:00:00.125Z' where id=${sourceId}::uuid`;
  const [{ id: templateId }] =
    await sql`select id from private.proposal_templates where source_proposal_id=${sourceId}::uuid`;
  // These token-bound test clients were created by the repository's verified
  // local OTP helper. Never print tokens or store them under the checkout.
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: apiUrl,
      SUPABASE_PUBLISHABLE_KEY: publishableKey,
      TW04_ACTOR_ID: actor.id,
      TW04_ACCESS_TOKEN: await actor.client.accessToken(),
      TW04_STAFF_ID: staff.id,
      TW04_STAFF_TOKEN: await staff.client.accessToken(),
      TW04_TEMPLATE_ID: templateId,
      TW04_SOURCE_ID: sourceId,
      TW04_REMOVAL_REQUEST: randomUUID(),
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared one synthetic Completed template with 51 open needs; temporary local session defines written.",
  );
} finally {
  await sql.end();
}
