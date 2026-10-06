import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";

export function assertHostingBackend(config, status) {
  assert.match(
    config,
    /^project_id = "planets-community-webhost01-qa"$/m,
    "Do not use the shared local project.",
  );
  assert.equal(
    status.apiUrl,
    "http://127.0.0.1:54361",
    "Wrong disposable API.",
  );
  assert.ok(status.databaseUrl, "Missing local database URL.");
  const database = new URL(status.databaseUrl);
  assert.equal(database.hostname, "127.0.0.1", "Database must be loopback.");
  assert.equal(database.port, "54362", "Wrong disposable database port.");
}

export async function readHostingBackend() {
  const config = await readFile("supabase/config.toml", "utf8");
  // Check the project before invoking its CLI, then bind the reported endpoints.
  assert.match(
    config,
    /^project_id = "planets-community-webhost01-qa"$/m,
    "Do not use the shared local project.",
  );
  const status = readLocalSupabaseStatus(process.cwd());
  assertHostingBackend(config, status);
  return status;
}
