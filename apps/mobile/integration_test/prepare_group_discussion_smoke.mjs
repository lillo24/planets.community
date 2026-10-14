// Fictional verified OTP sessions on an explicitly disposable loopback stack.
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
  output.toLowerCase().startsWith(resolve(process.cwd()).toLowerCase())
)
  throw new Error("Supply an OS temporary defines path outside the checkout.");
const status = readLocalSupabaseStatus(process.cwd()),
  mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
if (
  process.env.PLANETS_DISPOSABLE_QA !== "1" ||
  [status.apiUrl, status.databaseUrl, mailpitUrl].some(
    (url) =>
      !url ||
      !["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
  )
)
  throw new Error("C native fixtures require disposable loopback services.");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(person, name, params) {
  const { data, error } = await person.client.rpc(name, params);
  if (error) throw new Error(`C fixture ${name} failed (${error.code}).`);
  return data;
}
const expected = (person) => ({ p_expected_profile_id: person.id });
try {
  const people = {},
    run = randomUUID().slice(0, 8);
  for (const label of ["creator", "member"]) {
    const person = await signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: `c-native-${label}-${run}@planets.invalid`,
      verifierName: "fictional C native person",
    });
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${label}`})`;
    await rpc(person, "accept_policy_bundle", {
      p_expected_account_id: person.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    await ensureLocalProfilePhoto(person);
    people[label] = person;
  }
  const { creator, member } = people;
  const group = await rpc(creator, "create_group_draft", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_content: {
      name: "Trento Green · C native",
      description:
        "Fictional neighbours planning a collaborative park activity.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(creator, "set_group_publication_state", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_group_id: group,
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const [offer] = await rpc(creator, "create_group_participant_invitation", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_group_id: group,
  });
  await rpc(member, "accept_group_participant_invitation", {
    ...expected(member),
    p_client_request_id: randomUUID(),
    p_token: offer.invite_token,
  });
  const room = await rpc(creator, "create_group_discussion", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_group_id: group,
    p_title: "Parco",
  });
  await rpc(creator, "send_group_discussion_message", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_room_id: room.room_id,
    p_body: "Private message before your admission.",
  });
  await rpc(creator, "invite_group_discussion_member", {
    ...expected(creator),
    p_client_request_id: randomUUID(),
    p_room_id: room.room_id,
    p_profile_id: member.id,
  });
  const values = {
    APP_ENV: "local",
    ENABLE_DEMO_TOOLS: false,
    SUPABASE_URL: status.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
    C_GROUP: group,
    C_ROOM: room.room_id,
  };
  for (const [label, person] of Object.entries(people)) {
    values[`C_${label.toUpperCase()}_ID`] = person.id;
    values[`C_${label.toUpperCase()}_TOKEN`] =
      await person.client.accessToken();
  }
  await writeFile(output, JSON.stringify(values), { mode: 0o600 });
  console.log(
    "Prepared C fictional OTP identities, ready profiles, Group membership and a pending room invitation; private defines saved.",
  );
} finally {
  await sql.end();
}
