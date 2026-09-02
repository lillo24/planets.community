import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const outputPath = fileURLToPath(
  new URL("../apps/mobile/config/local.json", import.meta.url),
);

const host = readHostArgument(process.argv.slice(2));
const result = spawnSync("supabase", ["status", "--output", "json"], {
  cwd: repositoryRoot,
  encoding: "utf8",
  shell: process.platform === "win32",
});

if (result.error) {
  throw new Error(
    `Failed to start the project-scoped Supabase CLI: ${result.error.message}`,
  );
}

if (result.status !== 0) {
  throw new Error(
    "Could not read local Supabase status. Start Docker and run `npm run db:start`, then try again.",
  );
}

let status;
try {
  status = JSON.parse(result.stdout);
} catch {
  throw new Error("Supabase status did not return valid JSON.");
}

if (status === null || Array.isArray(status) || typeof status !== "object") {
  throw new Error("Supabase status returned an unexpected JSON structure.");
}

const apiUrl = readStatusValue(status, ["API_URL", "api_url", "apiUrl"]);
const publishableKey = readStatusValue(status, [
  "PUBLISHABLE_KEY",
  "publishable_key",
  "publishableKey",
  "ANON_KEY",
  "anon_key",
  "anonKey",
]);

if (!apiUrl || !publishableKey) {
  throw new Error(
    "Supabase status is missing its API URL or local publishable/anon key. Update the project-scoped CLI if the status format has changed.",
  );
}

let configuredUrl;
try {
  configuredUrl = new URL(apiUrl);
} catch {
  throw new Error("Supabase status returned an invalid API URL.");
}

if (host) {
  configuredUrl.hostname = host;
}

const config = {
  APP_ENV: "local",
  SUPABASE_URL: configuredUrl.toString().replace(/\/$/, ""),
  SUPABASE_PUBLISHABLE_KEY: publishableKey,
  SENTRY_DSN: "",
};

writeFileSync(outputPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
process.stdout.write(
  `Wrote apps/mobile/config/local.json for ${configuredUrl.host}.\n`,
);

function readStatusValue(statusObject, candidateKeys) {
  for (const key of candidateKeys) {
    const value = statusObject[key];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  return null;
}

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
