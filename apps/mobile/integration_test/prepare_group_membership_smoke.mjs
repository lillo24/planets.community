// Fictional verified OTP sessions only; never run against a shared stack.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";

const output = resolve(process.argv[2] ?? "");
if (
  !process.argv[2] ||
  output.toLowerCase().startsWith(resolve(process.cwd()).toLowerCase())
)
  throw new Error("Provide an OS-temporary defines path outside the checkout.");
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [status.apiUrl, status.databaseUrl, mailpitUrl])
  if (
    !url ||
    !["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)
  )
    throw new Error(
      "Group membership fixtures require disposable loopback services.",
    );
if (process.env.PLANETS_DISPOSABLE_QA !== "1")
  throw new Error("Designate this stack disposable first.");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(person, operation, params) {
  const { data, error } = await person.client.rpc(operation, params);
  if (error) throw new Error(`Fixture ${operation} failed (${error.code}).`);
  return data;
}
try {
  const run = randomUUID().slice(0, 8),
    people = {};
  for (const label of ["creator", "requester", "delegate"]) {
    const person = await signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: `grp03b-${label}-${run}@planets.invalid`,
      verifierName: "fictional group UI person",
    });
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${label}`})`;
    await rpc(person, "accept_policy_bundle", {
      p_expected_account_id: person.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    people[label] = person;
  }
  const creator = people.creator,
    actor = { p_expected_profile_id: creator.id };
  const group = await rpc(creator, "create_group_draft", {
    ...actor,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "GRP03B Riverside neighbours",
      description:
        "Fictional neighbours caring for a garden and sharing practical skills.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(creator, "set_group_publication_state", {
    ...actor,
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const [link] = await rpc(creator, "create_group_participant_invitation", {
    ...actor,
    p_group_id: group,
    p_client_request_id: randomUUID(),
  });
  const [authority] = await rpc(creator, "create_group_authority_invitation", {
    ...actor,
    p_group_id: group,
    p_client_request_id: randomUUID(),
    p_role: "co_creator",
  });
  const [browserAuthority] = await rpc(
    creator,
    "create_group_authority_invitation",
    {
      ...actor,
      p_group_id: group,
      p_client_request_id: randomUUID(),
      p_role: "co_organizer",
    },
  );
  // Requester initially has no photo. A second fictional photo-bearing person
  // is not needed: the integration journey commits a tiny real Storage image.
  const values = {
    APP_ENV: "local",
    ENABLE_DEMO_TOOLS: false,
    SUPABASE_URL: status.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
    GRP03B_GROUP: group,
    GRP03B_LINK: link.invite_token,
    GRP03B_AUTHORITY: authority.invite_token,
    GRP03B_BROWSER_AUTHORITY: browserAuthority.invite_token,
    GRP03B_BROWSER_EMAIL: `grp03b-browser-${run}@planets.invalid`,
    GRP03B_MAILPIT: mailpitUrl,
  };
  for (const [label, person] of Object.entries(people)) {
    values[`GRP03B_${label.toUpperCase()}_ID`] = person.id;
    values[`GRP03B_${label.toUpperCase()}_TOKEN`] =
      await person.client.accessToken();
  }
  await writeFile(output, JSON.stringify(values), { mode: 0o600 });
  console.log(
    "Prepared fictional verified OTP identities, canonical policy records, public group and separate participant/authority capabilities. Private temporary defines written.",
  );
} finally {
  await sql.end();
}
