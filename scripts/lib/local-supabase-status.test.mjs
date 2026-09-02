import assert from "node:assert/strict";
import test from "node:test";

import {
  parseLocalSupabaseStatus,
  replaceUrlHost,
} from "./local-supabase-status.mjs";

test("parses current Supabase status fields", () => {
  assert.deepEqual(
    parseLocalSupabaseStatus(
      JSON.stringify({
        API_URL: "http://127.0.0.1:54321/",
        PUBLISHABLE_KEY: "publishable-key",
      }),
    ),
    {
      apiUrl: "http://127.0.0.1:54321",
      publishableKey: "publishable-key",
    },
  );
});

test("accepts the legacy local anon-key field", () => {
  assert.equal(
    parseLocalSupabaseStatus(
      JSON.stringify({
        api_url: "http://localhost:54321",
        anon_key: "legacy-anon-key",
      }),
    ).publishableKey,
    "legacy-anon-key",
  );
});

test("fails loudly when the status contract is incomplete", () => {
  assert.throws(
    () => parseLocalSupabaseStatus(JSON.stringify({ API_URL: "http://x" })),
    /missing its API URL or local publishable\/anon key/,
  );
});

test("replaces only the URL host for mobile emulators", () => {
  assert.equal(
    replaceUrlHost("http://127.0.0.1:54321", "10.0.2.2"),
    "http://10.0.2.2:54321",
  );
});
