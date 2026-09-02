import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import {
  readLocalSupabaseStatus,
  replaceUrlHost,
} from "./lib/local-supabase-status.mjs";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const outputPath = fileURLToPath(
  new URL("../apps/mobile/config/local.json", import.meta.url),
);

const host = readHostArgument(process.argv.slice(2));
const status = readLocalSupabaseStatus(repositoryRoot);
const supabaseUrl = host ? replaceUrlHost(status.apiUrl, host) : status.apiUrl;
const configuredUrl = new URL(supabaseUrl);

const config = {
  APP_ENV: "local",
  SUPABASE_URL: supabaseUrl,
  SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
  SENTRY_DSN: "",
};

writeFileSync(outputPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
process.stdout.write(
  `Wrote apps/mobile/config/local.json for ${configuredUrl.host}.\n`,
);

function readHostArgument(argumentsList) {
  if (argumentsList.length === 0) {
    return null;
  }
  if (argumentsList.length !== 2 || argumentsList[0] !== "--host") {
    throw new Error("Usage: npm run mobile:config:local -- [--host 10.0.2.2]");
  }

  const value = argumentsList[1];
  if (!/^[a-zA-Z0-9.-]+$/.test(value)) {
    throw new Error(
      "--host must be a hostname or IPv4 address without a port.",
    );
  }
  return value;
}
