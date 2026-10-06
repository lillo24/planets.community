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
const modint = process.argv.includes("--modint01");
const project = modint
  ? "planets-community-modint01-qa"
  : "planets-community-authqa01-qa";
if (!new RegExp(`^project_id = "${project}"$`, "m").test(configuration)) {
  throw new Error(
    `Own-history smoke preparation requires selected task-owned project ${project}, never the shared stack.`,
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
if (
  new URL(status.apiUrl).port !== (modint ? "54611" : "54511") ||
  new URL(mailpit).port !== (modint ? "54614" : "54514")
) {
  throw new Error(
    "Normal OTP smoke requires the explicitly selected owned ports.",
  );
}
const sql = postgres(status.databaseUrl, { max: 2, onnotice: () => {} });
try {
  const run = randomUUID();
  const actors = {};
  const emails = {};
  const users = {};
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
    users[role] = user;
  }
  const fixture = await createConsequenceFixture(sql, actors);
  let integration = {};
  if (modint) {
    const own = await createConsequenceFixture(sql, {
      ...actors,
      owner: actors.requester,
    });
    // PI direct admission must remain photo-free, unlike request-based gates.
    await sql`delete from public.profile_photos where profile_id=${actors.requester}`;
    const { data, error } = await users.owner.client.rpc(
      "create_project_participant_invitation",
      { p_expected_profile_id: actors.owner, p_project_id: fixture.projectId },
    );
    if (error || data?.length !== 1)
      throw new Error(
        `Synthetic participant link failed (${error?.code ?? "shape"}).`,
      );
    integration = {
      MODINT01_SMOKE: "true",
      MODINT_PARTICIPANT_TOKEN: data[0].invite_token,
      MODINT_PROJECT_ID: fixture.projectId,
      MODINT_PROJECT_CASE: fixture.cases.project,
      MODINT_OWN_CONTENT_CASE: own.cases.project,
    };
  }
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
    ...integration,
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
