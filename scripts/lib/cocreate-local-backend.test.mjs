import test from "node:test";
import assert from "node:assert/strict";
import { assertCocreateLocalBackend } from "./cocreate-local-backend.mjs";
const local = {
  apiUrl: "http://127.0.0.1:54321",
  databaseUrl: "postgres://postgres:synthetic@127.0.0.1:54322/postgres",
};
test("co-creation LOCAL guard requires explicit engine ownership and loopback on every endpoint", () => {
  assert.throws(() => assertCocreateLocalBackend(local, {}));
  assert.doesNotThrow(() =>
    assertCocreateLocalBackend(local, { PLANETS_DISPOSABLE_QA: "1" }),
  );
  assert.doesNotThrow(() =>
    assertCocreateLocalBackend(local, {
      CONTAINER_CONNECTION: "planets-cocreate-qa-root",
      DOCKER_HOST: "npipe:////./pipe/podman-planets-cocreate-qa",
    }),
  );
  for (const key of ["apiUrl", "databaseUrl"]) {
    assert.throws(() =>
      assertCocreateLocalBackend(
        { ...local, [key]: "https://hosted.invalid" },
        { PLANETS_DISPOSABLE_QA: "1" },
      ),
    );
  }
});
