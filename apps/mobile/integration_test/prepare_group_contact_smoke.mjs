// Genuine synthetic OTP sessions, confined to an explicitly disposable stack.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";
import { tmpdir } from "node:os";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "../../../scripts/lib/local-profile-photo.mjs";

const output = resolve(process.argv[2] ?? "");
const within = relative(process.cwd(), output);
const temporary = relative(tmpdir(), output);
if (
  !process.argv[2] ||
  (!within.startsWith("..") && !isAbsolute(within)) ||
  temporary.startsWith("..") ||
  isAbsolute(temporary) ||
  temporary === "" ||
  process.env.PLANETS_DISPOSABLE_QA !== "1"
) {
  throw new Error(
    "Provide an OS-temporary defines path and explicitly disposable stack.",
  );
}
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  if (
    !["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname)
  ) {
    throw new Error("D contact fixtures require loopback services.");
  }
}
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(person, name, params) {
  const result = await person.client.rpc(name, params);
  if (result.error)
    throw new Error(`D fixture ${name} failed (${result.error.code}).`);
  return result.data;
}
try {
  const run = randomUUID().slice(0, 8),
    people = {};
  for (const name of ["alice", "bob", "carol", "dave"]) {
    const person = await signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: `d-contact-ui-${run}-${name}@planets.invalid`,
      verifierName: "D contact UI",
    });
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${name}`})`;
    await rpc(person, "accept_policy_bundle", {
      p_expected_account_id: person.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    people[name] = person;
  }
  const groups = {};
  for (const [name, person] of [
    ["garden", people.alice],
    ["workshop", people.bob],
    ["library", people.dave],
  ]) {
    const id = await rpc(person, "create_group_draft", {
      p_expected_profile_id: person.id,
      p_client_request_id: randomUUID(),
      p_content: {
        name:
          name === "garden"
            ? "Fictional Neighbourhood Garden"
            : name === "library"
              ? `Fictional D Library ${run}`
              : "Fictional Laboratorio di collaborazione del quartiere",
        description:
          "Synthetic neighbours planning a local collaboration together.",
        group_kind: "informal",
        locality: "Trento",
        volunteering_focus: true,
      },
    });
    await rpc(person, "set_group_publication_state", {
      p_expected_profile_id: person.id,
      p_group_id: id,
      p_client_request_id: randomUUID(),
      p_expected_version: 1,
      p_publication_state: "published",
    });
    groups[name] = id;
  }
  const [invitation] = await rpc(
    people.bob,
    "create_group_authority_invitation",
    {
      p_expected_profile_id: people.bob.id,
      p_group_id: groups.workshop,
      p_client_request_id: randomUUID(),
      p_role: "co_organizer",
    },
  );
  const [admission] = await rpc(
    people.carol,
    "accept_group_authority_invitation",
    {
      p_expected_profile_id: people.carol.id,
      p_token: invitation.invite_token,
      p_client_request_id: randomUUID(),
    },
  );
  // Carol deliberately has no photo: D admission does not add that prerequisite.
  await ensureLocalProfilePhoto(people.bob);
  await ensureLocalProfilePhoto(people.alice); // Existing Project join still needs its photo gate.
  const project = await rpc(people.bob, "create_group_editor_proposal_draft", {
    p_expected_creator_profile_id: people.bob.id,
    p_group_id: groups.workshop,
    p_client_request_id: randomUUID(),
    p_title: `Fictional independent garden Project ${run}`,
    p_summary:
      "Fictional neighbours plan an independent local Project together.",
    p_description:
      "This synthetic public Project uses its existing participation rules.",
    p_starts_at: new Date(Date.now() + 7 * 86400000).toISOString(),
    p_ends_at: new Date(Date.now() + 7 * 86400000 + 3600000).toISOString(),
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Trento",
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: 10,
    p_count_organizers_toward_capacity: false,
  });
  await rpc(people.bob, "publish_proposal", {
    p_expected_creator_profile_id: people.bob.id,
    p_proposal_id: project,
  });
  const values = {
    APP_ENV: "local",
    ENABLE_DEMO_TOOLS: "false",
    SUPABASE_URL: status.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
    D_GARDEN: groups.garden,
    D_WORKSHOP: groups.workshop,
    D_LIBRARY: groups.library,
    D_LIBRARY_NAME: `Fictional D Library ${run}`,
    D_CAROL_GRANT: admission.relationship_id,
    D_PROJECT: project,
  };
  for (const [name, person] of Object.entries(people)) {
    values[`D_${name.toUpperCase()}_ID`] = person.id;
    values[`D_${name.toUpperCase()}_TOKEN`] = await person.client.accessToken();
  }
  await writeFile(output, JSON.stringify(values), { mode: 0o600 });
  console.log(
    "Prepared four fictional OTP accounts, three public groups and independent Project. Private defines written outside checkout.",
  );
} finally {
  await sql.end();
}
