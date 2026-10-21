import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { createRuntime } from "./runtime.mjs";

test("wrong-project Auth rejection remains an authoritative denial before control RPCs", async () => {
  let calls = 0;
  const handler = createRuntime({
    enabled: true,
    normalOrigin: "https://cllpvruvrrvxczjitlqd.supabase.co",
    mockOrigin: "https://pnolarmzxmmjtguligfc.supabase.co",
    service: "synthetic-server-key",
    normalKey: "sb_publishable_" + "a".repeat(30),
    deliveryKey: randomBytes(32).toString("base64"),
    fetcher: async (url) => {
      calls++;
      assert.equal(new URL(url).host, "cllpvruvrrvxczjitlqd.supabase.co");
      return new Response(JSON.stringify({ code: "bad_jwt" }), { status: 403 });
    },
  });
  const response = await handler(
    new Request("https://broker.invalid", {
      method: "POST",
      headers: { authorization: "Bearer wrong-project-token" },
      body: '{"action":"catalog"}',
    }),
  );
  assert.equal(response.status, 403);
  assert.equal(calls, 1);
  assert.deepEqual(await response.json(), { error: "denied" });
});

test("standard Auth exchange accepts void RPC completion and recovers encrypted delivery", async () => {
  const tester = "10000000-0000-4000-8000-000000000001";
  const user = "20000000-0000-4000-8000-000000000001";
  const request = "30000000-0000-4000-8000-000000000001";
  const session = "40000000-0000-4000-8000-000000000001";
  const persona = {
    key: "giulia",
    user_id: user,
    email: "giulia@personas.planets.invalid",
  };
  const token =
    "synthetic." +
    Buffer.from(JSON.stringify({ session_id: session })).toString("base64url") +
    ".synthetic";
  let encrypted = null;
  let generations = 0;
  const json = (value) =>
    new Response(JSON.stringify(value), {
      headers: { "Content-Type": "application/json" },
    });
  const handler = createRuntime({
    enabled: true,
    normalOrigin: "https://cllpvruvrrvxczjitlqd.supabase.co",
    mockOrigin: "https://pnolarmzxmmjtguligfc.supabase.co",
    service: "synthetic-server-key",
    normalKey: "sb_publishable_" + "a".repeat(30),
    deliveryKey: randomBytes(32).toString("base64"),
    fetcher: async (url, init) => {
      const target = new URL(url);
      if (target.host.startsWith("cllpv")) {
        assert.equal(target.pathname, "/auth/v1/user");
        return json({ id: tester });
      }
      const body = init.body ? JSON.parse(init.body) : null;
      if (target.pathname.endsWith("/mock_control_catalog"))
        return json([persona]);
      if (target.pathname.endsWith("/mock_control_claim"))
        return json(
          encrypted
            ? { state: "replay", delivery: encrypted }
            : { state: "new", user_id: user, email: persona.email },
        );
      if (target.pathname.endsWith("/mock_control_finish")) {
        assert.equal(body.p_session, session);
        encrypted = body.p_delivery;
        return new Response(null, { status: 204 });
      }
      if (target.pathname.endsWith("/admin/users/" + user))
        return json({ id: user, email: persona.email });
      if (target.pathname.endsWith("/admin/generate_link")) {
        generations++;
        assert.deepEqual(body, { type: "magiclink", email: persona.email });
        return json({ id: user, hashed_token: "synthetic-one-time-token" });
      }
      if (target.pathname.endsWith("/verify"))
        return json({
          user: { id: user },
          access_token: token,
          refresh_token: "synthetic-refresh",
        });
      if (target.pathname.endsWith("/user")) return json({ id: user });
      throw new Error("Unexpected server request");
    },
  });
  const send = () =>
    handler(
      new Request("https://broker.invalid", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-normal" },
        body: JSON.stringify({
          action: "issue",
          persona_key: "giulia",
          request_id: request,
        }),
      }),
    );
  const first = await send();
  assert.equal(first.status, 200);
  const delivered = await first.json();
  assert.equal(delivered.user_id, user);
  assert.equal(delivered.request_id, request);
  assert.equal(encrypted.includes("synthetic-refresh"), false);
  const second = await send();
  assert.equal(second.status, 200);
  assert.deepEqual(await second.json(), delivered);
  assert.equal(generations, 1);
});
