// Fictional genuine OTP identities. Run only in an explicitly disposable stack.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "../../../scripts/lib/local-profile-photo.mjs";

const output = resolve(process.argv[2] ?? "");
if (
  !process.argv[2] ||
  output.toLowerCase().startsWith(resolve(process.cwd()).toLowerCase()) ||
  process.env.PLANETS_DISPOSABLE_QA !== "1"
)
  throw new Error(
    "Provide an OS-temporary defines path and explicitly disposable stack.",
  );
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl])
  if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname))
    throw new Error("Group Project fixtures require loopback services.");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(person, name, params) {
  const result = await person.client.rpc(name, params);
  if (result.error)
    throw new Error(`Fixture ${name} failed (${result.error.code}).`);
  return result.data;
}
try {
  const run = randomUUID().slice(0, 8),
    people = {};
  for (const name of ["creator", "requester"]) {
    const person = await signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: `grp03c-ui-${run}-${name}@planets.invalid`,
      verifierName: "group Project UI",
    });
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${name}`})`;
    await rpc(person, "accept_policy_bundle", {
      p_expected_account_id: person.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    await ensureLocalProfilePhoto(person);
    people[name] = person;
  }
  const creator = people.creator,
    actor = { p_expected_profile_id: creator.id };
  const group = await rpc(creator, "create_group_draft", {
    ...actor,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "Fictional Neighbourhood Garden",
      description:
        "Fictional neighbours creating and caring for a garden together.",
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
  const values = {
    APP_ENV: "local",
    SUPABASE_URL: status.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
    GRP03C_GROUP: group,
    GRP03C_RUN: run,
  };
  const catalog = await rpc(creator, "list_public_proposal_templates_v2", {
    p_limit: 50,
    p_query: "Repair Café",
  });
  const official = catalog.find((row) => row.is_official);
  if (!official)
    throw new Error("The public official starter fixture is unavailable.");
  values.GRP03C_TEMPLATE = official.template_id;
  for (const [name, person] of Object.entries(people)) {
    values[`GRP03C_${name.toUpperCase()}_ID`] = person.id;
    values[`GRP03C_${name.toUpperCase()}_TOKEN`] =
      await person.client.accessToken();
  }
  await writeFile(output, JSON.stringify(values), { mode: 0o600 });
  console.log(
    "Prepared fictional OTP identities, canonical photos/policy and public group. Private defines written outside checkout.",
  );
} finally {
  await sql.end();
}
