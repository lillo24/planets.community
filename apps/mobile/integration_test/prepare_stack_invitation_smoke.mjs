// Opt-in references only; the native test performs its own real OTP/profile flow.
import { readFile, writeFile } from "node:fs/promises";
import { resolve, relative, isAbsolute } from "node:path";
import postgres from "postgres";
import {
  assertSafeLocalDemoTarget,
  DEMO_PERSONAS,
  DEMO_SCENARIOS,
} from "../../../scripts/lib/demo-world.mjs";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";

const root = process.cwd(),
  output = resolve(process.argv[2] ?? "");
const rel = relative(root, output);
if (!process.argv[2] || (!rel.startsWith("..") && !isAbsolute(rel)))
  throw new Error("Use an OS-temporary defines path outside the repository.");
const config = await readFile("supabase/config.toml", "utf8");
if (!config.includes('project_id = "planets-community-tw-stack01"'))
  throw new Error("Use only the owned TW-STACK01 disposable rehearsal.");
const status = readLocalSupabaseStatus(root);
const mailpitUrl = "http://127.0.0.1:54924";
assertSafeLocalDemoTarget({ ...status, mailpitUrl, environment: "local" });
const fixture = JSON.parse(await readFile(".env.pi05-browser.json", "utf8"));
if (fixture.apiUrl !== status.apiUrl)
  throw new Error("Browser invitation fixture belongs to another backend.");
const journal = JSON.parse(
  await readFile(".env.demo-participant-links.json", "utf8"),
);
if (journal.apiUrl !== status.apiUrl)
  throw new Error("Demo journal belongs to another backend.");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
try {
  const existing =
    await sql`select id from auth.users where email='tw-stack01-native@planets.invalid'`;
  if (existing.length)
    throw new Error(
      "Native OTP/profile journey needs a fresh owned rehearsal account; explicitly reset this disposable stack before repeating.",
    );
  const [source] =
    await sql`select p.id,p.creator_profile_id from public.proposals p join auth.users u on u.id=p.creator_profile_id where p.title=${DEMO_SCENARIOS.proposals.participantFull.title} and u.email=${DEMO_PERSONAS.alice.email}`;
  if (!source) throw new Error("Full invitation fixture missing.");
  const full = Object.values(journal.generations).find(
    (g) => g.projectId === source.id,
  );
  if (!full)
    throw new Error("Full generation absent from private local journal.");
  await writeFile(
    output,
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: status.apiUrl,
      SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
      STACK_PROPOSAL_TOKEN: fixture.links.proposal.token,
      STACK_TAVOLO_TOKEN: fixture.links.tavolo.token,
      STACK_FULL_TOKEN: full.token,
      STACK_OWNER_ID: source.creator_profile_id,
      STACK_MAILPIT_URL: mailpitUrl,
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared private local references; OTP and basic profile will be exercised in the native UI.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
