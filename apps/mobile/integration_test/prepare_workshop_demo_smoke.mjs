import { writeFile } from "node:fs/promises";
import { resolve, relative, isAbsolute } from "node:path";
import postgres from "postgres";
import {
  DEMO_PERSONAS,
  assertSafeLocalDemoTarget,
  verifyLocalDemoWorld,
} from "../../../scripts/lib/demo-world.mjs";
import { WORKSHOP_SOURCES } from "../../../scripts/lib/demo-workshop.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";

const root = process.cwd(),
  output = resolve(process.argv[2] ?? "");
const rel = relative(root, output);
if (!process.argv[2] || (!rel.startsWith("..") && !isAbsolute(rel)))
  throw new Error("Use an OS-temporary defines path outside the repository.");
const status = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
assertSafeLocalDemoTarget({ ...status, mailpitUrl, environment: "local" });
// Prepare requires the already-created world. No product repair, seed or reset.
await verifyLocalDemoWorld({ repositoryRoot: root, status, mailpitUrl });
const actors = await Promise.all(
  ["alice", "reviewer"].map((key) =>
    signInLocalOtpUser({
      ...status,
      mailpitUrl,
      email: DEMO_PERSONAS[key].email,
      verifierName: `TW05 ${key}`,
    }),
  ),
);
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
try {
  const sources =
    await sql`select p.id,p.title,t.id as template_id from public.proposals p join private.proposal_templates t on t.source_proposal_id=p.id join auth.users u on u.id=p.creator_profile_id where u.email=${DEMO_PERSONAS.alice.email}`;
  const transition = sources.find(
    (s) =>
      s.title === WORKSHOP_SOURCES.find((s) => s.key === "transition").title,
  );
  const full = sources.find(
    (s) =>
      s.title === WORKSHOP_SOURCES.find((s) => s.key === "fullRepair").title,
  );
  if (!transition || !full)
    throw new Error("TW05 native demo fixtures missing.");
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: status.apiUrl,
      SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
      TW05_ACTOR_ID: actors[0].id,
      TW05_ACCESS_TOKEN: await actors[0].client.accessToken(),
      TW05_REVIEWER_ID: actors[1].id,
      TW05_REVIEWER_TOKEN: await actors[1].client.accessToken(),
      TW05_TEMPLATE_ID: transition.template_id,
      TW05_FULL_ID: full.id,
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared TW05 verified demo identities and dedicated native rehearsal references; temporary defines written.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
