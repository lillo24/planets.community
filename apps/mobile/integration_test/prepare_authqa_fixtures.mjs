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

// Test-only preparation: publishable key + synthetic email/case identifiers are
// passed to the emulator. No service-role key, staff token or database URL leaves
// this loopback-owned fixture process. The device obtains real OTP sessions.
const root = fileURLToPath(new URL("../../../", import.meta.url));
const configuration = readFileSync(
  new URL("../../../supabase/config.toml", import.meta.url),
  "utf8",
);
if (!/^project_id = "planets-community-authqa01-qa"$/m.test(configuration)) {
  throw new Error(
    "Own-history smoke preparation requires task-owned project planets-community-authqa01-qa, never the shared stack.",
  );
}
const status = readLocalSupabaseStatus(root);
const mailpit = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const value of [status.apiUrl, status.databaseUrl, mailpit]) {
  if (!value || !["127.0.0.1", "localhost"].includes(new URL(value).hostname)) {
    throw new Error(
      "Own-history smoke preparation requires an explicit loopback-only disposable backend and mailbox.",
    );
  }
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
    const email = `authqa01-${role}-${run}@planets.invalid`;
    const user = await signInLocalOtpUser({
      apiUrl: status.apiUrl,
      publishableKey: status.publishableKey,
      mailpitUrl: mailpit,
      email,
      verifierName: "AuthQA01 normal OTP smoke",
    });
    const anchor = await user.client.from("profiles").insert({ id: user.id });
    if (anchor.error)
      throw new Error(
        `Synthetic profile anchor failed (${anchor.error.code}).`,
      );
    const profile = await user.client.rpc("update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `History smoke ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    if (profile.error)
      throw new Error(
        `Synthetic profile setup failed (${profile.error.code}).`,
      );
    actors[role] = user.id;
    emails[role] = email;
  }
  const fixture = await createConsequenceFixture(sql, actors);
  const config = {
    APP_ENV: "local",
    SUPABASE_URL: replaceUrlHost(status.apiUrl, "10.0.2.2"),
    SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
    SENTRY_DSN: "",
    ENABLE_DEMO_TOOLS: "false",
    HISTORY_SMOKE_MAILPIT_URL: replaceUrlHost(mailpit, "10.0.2.2"),
    HISTORY_SMOKE_EMAIL_A: emails.requester,
    HISTORY_SMOKE_EMAIL_B: emails.unrelated,
    AUTHQA_NEW_EMAIL: `authqa01-new-${run}@planets.invalid`,
    HISTORY_SMOKE_STAFF_EMAIL: emails.admin,
    HISTORY_SMOKE_CASE_ID: fixture.cases.profile,
  };
  writeFileSync(
    new URL("../config/local.json", import.meta.url),
    `${JSON.stringify(config, null, 2)}\n`,
    "utf8",
  );
  console.log(
    "Prepared synthetic own-history smoke and ignored config/local.json for the Android emulator. No privileged credentials exported.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
