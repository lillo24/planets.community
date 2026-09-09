import { spawnSync } from "node:child_process";

export function readLocalSupabaseStatus(repositoryRoot) {
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

  return parseLocalSupabaseStatus(result.stdout);
}

export function parseLocalSupabaseStatus(output) {
  let status;
  try {
    status = JSON.parse(output);
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
  const serviceRoleKey = readStatusValue(status, [
    "SERVICE_ROLE_KEY",
    "service_role_key",
    "serviceRoleKey",
  ]);
  const databaseUrl = readStatusValue(status, [
    "DB_URL",
    "db_url",
    "databaseUrl",
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

  if (
    configuredUrl.protocol !== "http:" &&
    configuredUrl.protocol !== "https:"
  ) {
    throw new Error("Supabase status API URL must use HTTP or HTTPS.");
  }

  return Object.freeze({
    apiUrl: configuredUrl.toString().replace(/\/$/, ""),
    publishableKey,
    ...(serviceRoleKey ? { serviceRoleKey } : {}),
    ...(databaseUrl ? { databaseUrl } : {}),
  });
}

export function replaceUrlHost(apiUrl, host) {
  const configuredUrl = new URL(apiUrl);
  configuredUrl.hostname = host;
  return configuredUrl.toString().replace(/\/$/, "");
}

function readStatusValue(status, candidateKeys) {
  for (const key of candidateKeys) {
    const value = status[key];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  return null;
}
