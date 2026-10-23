import assert from "node:assert/strict";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

export function assertCocreateLocalBackend(status, environment = process.env) {
  assert.ok(
    (environment.CONTAINER_CONNECTION === "planets-cocreate-qa-root" &&
      environment.DOCKER_HOST ===
        "npipe:////./pipe/podman-planets-cocreate-qa") ||
      environment.PLANETS_DISPOSABLE_QA === "1",
    "Co-creation requires its owned LOCAL engine or explicit disposable QA opt-in.",
  );
  for (const endpoint of [
    status.apiUrl,
    status.databaseUrl,
    "http://127.0.0.1:54324",
  ]) {
    assert.ok(
      ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
      "Co-creation tooling refuses non-loopback endpoints.",
    );
  }
}
export function openCocreateLocalBackend() {
  const status = readLocalSupabaseStatus(process.cwd());
  assertCocreateLocalBackend(status);
  return {
    status,
    sql: postgres(status.databaseUrl, { max: 8, onnotice: () => {} }),
  };
}
