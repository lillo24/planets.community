import { writeFileSync } from "node:fs";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../../scripts/lib/local-supabase-status.mjs";

// Opt-in, synthetic fixtures only; run from repository root after a disposable reset.
if (!process.argv.includes("--disposable-local"))
  throw new Error(
    "Pass --disposable-local after selecting a disposable local stack.",
  );
const status = readLocalSupabaseStatus(process.cwd());
if (
  new URL(status.databaseUrl).hostname !== "127.0.0.1" ||
  new URL(status.apiUrl).hostname !== "127.0.0.1"
)
  throw new Error("Fixture requires loopback Supabase.");
const ids = {
  manager: "55000000-0000-4000-8000-000000000001",
  participant: "55000000-0000-4000-8000-000000000002",
  project: "55000000-0000-4000-8000-000000000003",
  request: "55000000-0000-4000-8000-000000000004",
};
async function auth(path, key, body) {
  const response = await fetch(`${status.apiUrl}/auth/v1/${path}`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok)
    throw new Error(
      `Local fixture Auth ${path} failed: HTTP ${response.status}. Reset the disposable stack before repeating.`,
    );
  return response.json();
}
const sessions = {};
for (const role of ["manager", "participant"]) {
  const email = `pi02-${role}@planets.invalid`;
  const password = "synthetic-local-pi02-password";
  const user = await auth("admin/users", status.serviceRoleKey, {
    id: ids[role],
    email,
    password,
    email_confirm: true,
  });
  if (user.id !== ids[role])
    throw new Error("Local fixture identity did not match.");
  const session = await auth(
    "token?grant_type=password",
    status.publishableKey,
    { email, password },
  );
  sessions[`${role}Token`] = session.access_token;
}
const sql = postgres(status.databaseUrl, { max: 1 });
try {
  await sql.begin(async (tx) => {
    for (const role of ["manager", "participant"]) {
      await tx`insert into public.profiles(id,display_name) values (${ids[role]},${`Synthetic PI02 ${role}`})`;
    }
    await tx`insert into public.profile_photos(profile_id,object_path,audience) values (${ids.manager},${`${ids.manager}/55000000-0000-4000-8000-000000000005.webp`},'interactions')`;
    await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at) values (${ids.project},${ids.manager},'published','PI02 local mural',now()+interval '1 day',now()+interval '2 days',now())`;
    await tx`insert into public.project_join_requests(id,project_id,requester_profile_id) values (${ids.request},${ids.project},${ids.participant})`;
  });
  writeFileSync(
    "apps/mobile/config/pi02-smoke.json",
    JSON.stringify({
      ...ids,
      ...sessions,
      apiUrl: status.apiUrl,
      key: status.publishableKey,
    }),
  );
  console.log(
    "Synthetic PI02 fixture ready; tokens saved only in ignored local config.",
  );
} finally {
  await sql.end();
}
