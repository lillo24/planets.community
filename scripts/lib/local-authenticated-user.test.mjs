import assert from "node:assert/strict";
import test from "node:test";
import { createClient } from "@supabase/supabase-js";

import { createTokenBoundDataClient } from "./local-authenticated-user.mjs";

test("an ordinary sessionless client falls back to the publishable key as Bearer", async () => {
  const requests = [];
  const publishableKey = "sb_publishable_test-key";
  const client = createClient("http://127.0.0.1:54321", publishableKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
    global: {
      fetch: async (input, init) => {
        requests.push({ input, headers: new Headers(init?.headers) });
        return new Response("[]", {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      },
    },
  });

  const { error } = await client.from("profiles").select("id");

  assert.equal(error, null);
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].headers.get("authorization"),
    `Bearer ${publishableKey}`,
  );
});

test("token-bound data clients use the verified session token immediately", async () => {
  const requests = [];
  const client = createTokenBoundDataClient({
    apiUrl: "http://127.0.0.1:54321",
    publishableKey: "sb_publishable_test-key",
    accessToken: "test-header.test-payload.test-signature",
    fetch: async (input, init) => {
      requests.push({ input, headers: new Headers(init?.headers) });
      return new Response("[]", {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });

  const { error } = await client.from("profiles").select("id");

  assert.equal(error, null);
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].headers.get("authorization"),
    "Bearer test-header.test-payload.test-signature",
  );
  assert.equal(requests[0].headers.get("apikey"), "sb_publishable_test-key");
});

test("token-bound data clients reject a missing verified token", () => {
  assert.throws(
    () =>
      createTokenBoundDataClient({
        apiUrl: "http://127.0.0.1:54321",
        publishableKey: "sb_publishable_test-key",
        accessToken: "",
      }),
    /verified local Supabase session access token/u,
  );
});
