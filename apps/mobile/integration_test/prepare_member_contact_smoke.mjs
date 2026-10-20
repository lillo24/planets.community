// Genuine synthetic OTP identities on an explicitly disposable loopback stack.
// Run from the repository root. Secrets go only to an OS-temporary defines file.
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";
import { tmpdir } from "node:os";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";

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
    throw new Error("Member contact fixtures require loopback services.");
  }
}
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function rpc(person, name, params) {
  const result = await person.client.rpc(name, params);
  if (result.error) {
    throw new Error(`Member fixture ${name} failed (${result.error.code}).`);
  }
  return result.data;
}
const people = {};
try {
  const run = randomUUID().slice(0, 8);
  for (const [key, name] of [
    ["owner", "Fictional Group Owner"],
    ["alice", "Fictional Alice"],
    ["bob", "Fictional Bob"],
  ]) {
    const person = await signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: `m-contact-ui-${run}-${key}@planets.invalid`,
      verifierName: "Member contact UI",
    });
    people[key] = person;
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${name})`;
    await rpc(person, "accept_policy_bundle", {
      p_expected_account_id: person.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
  }
  const defines = {
    APP_ENV: "local",
    ENABLE_DEMO_TOOLS: false,
    SUPABASE_URL: status.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
  };
  for (const [key, person] of Object.entries(people)) {
    defines[`M_${key.toUpperCase()}_ID`] = person.id;
    defines[`M_${key.toUpperCase()}_TOKEN`] = await person.client.accessToken();
  }
  // Ordinary participants have no delegated authority and no profile photos.
  // Separate origins exercise each terminal policy without changing cooldowns.
  for (const [key, name] of [
    ["CLOSE", "Fictional M Garden"],
    ["LEAVE", "Fictional M Tool Library"],
    ["CONTEXT", "Fictional M Laboratorio del quartiere"],
  ]) {
    const group = await rpc(people.owner, "create_group_draft", {
      p_expected_profile_id: people.owner.id,
      p_client_request_id: randomUUID(),
      p_content: {
        name: `${name} ${run}`,
        description:
          "Synthetic neighbours sharing a local Group for consent verification.",
        group_kind: "informal",
        locality: "Trento",
        volunteering_focus: true,
      },
    });
    await rpc(people.owner, "set_group_publication_state", {
      p_expected_profile_id: people.owner.id,
      p_group_id: group,
      p_client_request_id: randomUUID(),
      p_expected_version: 1,
      p_publication_state: "published",
    });
    defines[`M_${key}_GROUP`] = group;
    defines[`M_${key}_GROUP_NAME`] = `${name} ${run}`;
    for (const person of [people.alice, people.bob]) {
      const [invitation] = await rpc(
        people.owner,
        "create_group_participant_invitation",
        {
          p_expected_profile_id: people.owner.id,
          p_group_id: group,
          p_client_request_id: randomUUID(),
        },
      );
      await rpc(person, "accept_group_participant_invitation", {
        p_expected_profile_id: person.id,
        p_token: invitation.invite_token,
        p_client_request_id: randomUUID(),
      });
    }
  }
  const idea = await rpc(people.owner, "create_group_discussion_v2", {
    p_expected_profile_id: people.owner.id,
    p_client_request_id: randomUUID(),
    p_group_id: defines.M_CLOSE_GROUP,
    p_title: `Synthetic shared Idea ${run}`,
    p_purpose: "Plan a fictional neighbourhood garden together.",
    p_visibility: "group",
  });
  await rpc(people.alice, "join_group_discussion", {
    p_expected_profile_id: people.alice.id,
    p_client_request_id: randomUUID(),
    p_room_id: idea.room_id,
  });
  defines.M_INVITE_IDEA = idea.room_id;
  await writeFile(output, `${JSON.stringify(defines, null, 2)}\n`, {
    mode: 0o600,
    flag: "wx",
  });
  console.log(
    "Prepared three synthetic members, three origins and one independently joined C Idea; private defines written to OS temporary storage.",
  );
} finally {
  await sql.end();
  for (const person of Object.values(people)) {
    await person.client.removeAllChannels();
  }
}
