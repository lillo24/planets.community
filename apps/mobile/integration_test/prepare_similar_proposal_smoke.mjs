// Narrow disposable SIM02 fixture. All people/content are synthetic.
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
    throw new Error("SIM02 smoke requires disposable loopback services.");
  }
}
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(user, name, params) {
  const { data, error } = await user.client.rpc(name, params);
  if (error) throw new Error(`SIM02 fixture ${name} failed (${error.code}).`);
  return data;
}
try {
  const people = [];
  for (const role of ["editor", "creator"]) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `sim02-smoke-${role}@planets.invalid`,
      verifierName: `SIM02 synthetic ${role}`,
    });
    await sql`insert into public.profiles(id) values(${user.id}::uuid) on conflict(id) do nothing`;
    await rpc(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `SIM02 synthetic ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "private",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    people.push(user);
  }
  const [actor, creator] = people;
  // Deliberately no editor photo: matching is permitted before join readiness.
  await ensureLocalProfilePhoto(creator);
  const [{ id: skillId }] =
    await sql`select id from public.skills where slug='mural-painting'`;
  const candidateId = await rpc(creator, "create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "SIM02 synthetic repair laboratory",
    p_summary: "Repair synthetic objects together",
    p_description: "SIM02 disposable public description",
    p_starts_at: "2098-01-01T10:00:00Z",
    p_ends_at: "2098-01-01T12:00:00Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Synthetic public laboratory",
    p_exact_meeting_text: "Synthetic private meeting text",
    p_exact_location_visibility: "participants",
    p_skill_ids: [skillId],
    p_skill_importances: ["useful"],
    p_registration_capacity: 1,
    p_count_organizers_toward_capacity: false,
  });
  await rpc(creator, "publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: candidateId,
  });
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: apiUrl,
      SUPABASE_PUBLISHABLE_KEY: publishableKey,
      SIM02_ACTOR_ID: actor.id,
      SIM02_ACCESS_TOKEN: await actor.client.accessToken(),
      SIM02_CREATOR_ID: creator.id,
      SIM02_CREATOR_TOKEN: await creator.client.accessToken(),
      SIM02_CANDIDATE_ID: candidateId,
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared one synthetic upcoming Project and two verified local people; temporary defines written.",
  );
} finally {
  await sql.end();
}
