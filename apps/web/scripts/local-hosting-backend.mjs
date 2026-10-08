import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";

function scope(target) {
  assert.ok(
    ["webhost01", "modint01"].includes(target),
    "Unknown local QA scope.",
  );
  return target === "modint01"
    ? {
        project: "planets-community-modint01-qa",
        api: "54611",
        db: "54612",
        mailpit: "54614",
      }
    : {
        project: "planets-community-webhost01-qa",
        api: "54361",
        db: "54362",
        mailpit: "54364",
      };
}

export function assertHostingBackend(config, status, target = "webhost01") {
  const selected = scope(target);
  assert.match(
    config,
    new RegExp(`^project_id = "${selected.project}"$`, "m"),
    "Do not use the shared local project.",
  );
  assert.equal(
    status.apiUrl,
    `http://127.0.0.1:${selected.api}`,
    "Wrong disposable API.",
  );
  assert.ok(status.databaseUrl, "Missing local database URL.");
  const database = new URL(status.databaseUrl);
  assert.equal(database.hostname, "127.0.0.1", "Database must be loopback.");
  assert.equal(database.port, selected.db, "Wrong disposable database port.");
}

export async function readHostingBackend(target = "webhost01") {
  const selected = scope(target);
  const config = await readFile("supabase/config.toml", "utf8");
  // Check the project before invoking its CLI, then bind the reported endpoints.
  assert.match(
    config,
    new RegExp(`^project_id = "${selected.project}"$`, "m"),
    "Do not use the shared local project.",
  );
  const status = readLocalSupabaseStatus(process.cwd());
  assertHostingBackend(config, status, target);
  return {
    ...status,
    mailpitUrl: `http://127.0.0.1:${selected.mailpit}`,
    emailPrefix: target,
  };
}
