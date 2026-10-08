import { readFileSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import {
  readLocalSupabaseStatus,
  replaceUrlHost,
} from "../../../scripts/lib/local-supabase-status.mjs";
import { createConsequenceFixture } from "../../../scripts/lib/moderation-consequence-fixtures.mjs";
import { ensureLocalProfilePhoto } from "../../../scripts/lib/local-profile-photo.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const toml = readFileSync(
  new URL("../../../supabase/config.toml", import.meta.url),
  "utf8",
);
const modint = process.argv.includes("--modint01");
const project = modint
  ? "planets-community-modint01-qa"
  : "planets-community-09c2b2-qa";
if (!new RegExp(`^project_id = "${project}"$`, "m").test(toml)) {
  throw new Error(
    "Request-explanation smoke requires its owned 09C2B2 project.",
  );
}
const status = readLocalSupabaseStatus(root);
const mailbox = process.env.MAILPIT_URL;
for (const url of [status.apiUrl, status.databaseUrl, mailbox]) {
  if (!url || !["127.0.0.1", "localhost"].includes(new URL(url).hostname)) {
    throw new Error(
      "Request-explanation smoke requires explicit loopback backend/mailbox.",
    );
  }
}
if (
  new URL(status.apiUrl).port !== (modint ? "54611" : "54521") ||
  new URL(mailbox).port !== (modint ? "54614" : "54524")
) {
  throw new Error("Request-explanation smoke requires its owned ports.");
}
const sql = postgres(status.databaseUrl, { max: 2, onnotice: () => {} });
try {
  const run = randomUUID();
  const actors = {};
  const emails = {};
  for (const role of [
    "moderator",
    "admin",
    "owner",
    "cocreator",
    "coorganizer",
    "requester",
    "unrelated",
  ]) {
    const email = `09c2b2-${role}-${run}@planets.invalid`;
    const user = await signInLocalOtpUser({
      apiUrl: status.apiUrl,
      publishableKey: status.publishableKey,
      mailpitUrl: mailbox,
      email,
      verifierName: "09C2B2 synthetic fixture",
    });
    const anchor = await user.client.from("profiles").insert({ id: user.id });
    if (anchor.error)
      throw new Error(`Fixture anchor failed (${anchor.error.code}).`);
    const profile = await user.client.rpc("update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `Synthetic ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    if (profile.error)
      throw new Error(`Fixture profile failed (${profile.error.code}).`);
    await ensureLocalProfilePhoto(user);
    actors[role] = user.id;
    emails[role] = email;
  }
  const fixture = await createConsequenceFixture(sql, actors);
  writeFileSync(
    new URL("../config/local.json", import.meta.url),
    JSON.stringify(
      {
        APP_ENV: "local",
        SUPABASE_URL: replaceUrlHost(status.apiUrl, "10.0.2.2"),
        SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
        SENTRY_DSN: "",
        ENABLE_DEMO_TOOLS: "false",
        MODINT01_SMOKE: String(modint),
        REQUEST_SMOKE_MAILPIT: replaceUrlHost(mailbox, "10.0.2.2"),
        REQUEST_SMOKE_EMAIL: emails.requester,
        REQUEST_SMOKE_UNRELATED_EMAIL: emails.unrelated,
        REQUEST_SMOKE_STAFF_EMAIL: emails.admin,
        REQUEST_SMOKE_OWNER_EMAIL: emails.owner,
        REQUEST_SMOKE_CASE: fixture.cases.profile,
        REQUEST_SMOKE_PROJECT: fixture.projectId,
        REQUEST_SMOKE_LISTING: fixture.listingId,
        REQUEST_SMOKE_OWNER: actors.owner,
      },
      null,
      2,
    ) + "\n",
    "utf8",
  );
  console.log(
    "Prepared fresh synthetic 09C2B2 identities and ignored public configuration. No privileged credentials exported.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
