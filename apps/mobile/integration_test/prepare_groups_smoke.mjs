// Synthetic loopback fixtures only. Run from a confirmed disposable local stack.
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
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl])
  if (
    !url ||
    !["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)
  )
    throw new Error("Groups fixtures require disposable loopback services.");
if (process.env.PLANETS_DISPOSABLE_QA !== "1")
  throw new Error("Designate this local stack disposable first.");
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
try {
  const run = randomUUID().slice(0, 8);
  const people = [];
  for (const role of ["manager", "reporter"]) {
    const person = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `grp02-${role}-${run}@planets.invalid`,
      verifierName: "GRP02 fictional local person",
    });
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${role}`})`;
    await person.client
      .rpc("accept_policy_bundle", {
        p_expected_account_id: person.id,
        p_bundle_version: "POLICY01-2026-10-08-v1",
      })
      .then(({ error }) => {
        if (error) throw new Error("Fixture policy acknowledgement failed.");
      });
    people.push(person);
  }
  const [manager, reporter] = people;
  const { data: id, error } = await manager.client.rpc("create_group_draft", {
    p_expected_profile_id: manager.id,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "GRP02 fictional Riverside collective",
      description:
        "Fictional neighbours caring for a shared garden and exchanging practical skills.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  if (error) throw new Error("Fixture group creation failed.");
  const published = await manager.client.rpc("set_group_publication_state", {
    p_expected_profile_id: manager.id,
    p_group_id: id,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  if (published.error) throw new Error("Fixture publication failed.");
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: apiUrl,
      SUPABASE_PUBLISHABLE_KEY: publishableKey,
      GRP02_MANAGER_ID: manager.id,
      GRP02_MANAGER_TOKEN: await manager.client.accessToken(),
      GRP02_REPORTER_ID: reporter.id,
      GRP02_REPORTER_TOKEN: await reporter.client.accessToken(),
      GRP02_PUBLIC_GROUP_ID: id,
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared two fictional verified OTP identities, completed photo-free profiles, policy records and one public group. Temporary local session defines written.",
  );
} finally {
  await sql.end();
}
