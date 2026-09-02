import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const outputPath = fileURLToPath(
  new URL("../apps/web/.env.local", import.meta.url),
);
const status = readLocalSupabaseStatus(repositoryRoot);

const values = {
  NEXT_PUBLIC_APP_ENV: "local",
  NEXT_PUBLIC_SUPABASE_URL: status.apiUrl,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
  NEXT_PUBLIC_SENTRY_DSN: "",
};

const contents = Object.entries(values)
  .map(([key, value]) => `${key}=${formatEnvValue(value, key)}`)
  .join("\n");

writeFileSync(outputPath, `${contents}\n`, "utf8");
process.stdout.write(
  `Wrote apps/web/.env.local for ${new URL(status.apiUrl).host}.\n`,
);

function formatEnvValue(value, key) {
  if (value.includes("\r") || value.includes("\n")) {
    throw new Error(`${key} cannot contain a line break.`);
  }
  return value;
}
