import test from "node:test";
import assert from "node:assert/strict";
import { createHandler, BrokerFailure } from "./handler.mjs";
const client = "10000000-0000-4000-8000-000000000001";
const persona = {
  key: "giulia",
  user_id: "20000000-0000-4000-8000-000000000001",
  email: "giulia@personas.planets.invalid",
  name: "Giulia",
  scenario: "Fictional organizer",
};
const request = "30000000-0000-4000-8000-000000000001";
const session = "40000000-0000-4000-8000-000000000001";
function setup(overrides = {}) {
  const calls = [];
  const handler = createHandler({
    enabled: true,
    mockOrigin: "https://pnolarmzxmmjtguligfc.supabase.co",
    rpc: async (name, args) => {
      calls.push({ name, args });
      return name.endsWith("catalog")
        ? { client_id: client, personas: [persona] }
        : name.endsWith("claim")
          ? { state: "new", user_id: persona.user_id, email: persona.email }
          : name.endsWith("client")
            ? client
            : null;
    },
    issue: async () => ({
      user_id: persona.user_id,
      session_id: session,
      access_token: "synthetic-access",
      refresh_token: "synthetic-refresh",
    }),
    seal: async () => "encrypted",
    open: async () => ({ recovered: true }),
    revoke: async () => calls.push({ name: "revoke" }),
    ...overrides,
  });
  const send = (body, capability = "a".repeat(64), authorization = null) =>
    handler(
      new Request("https://broker.invalid", {
        method: "POST",
        headers: {
          ...(capability ? { "x-mock-client": capability } : {}),
          ...(authorization ? { authorization } : {}),
        },
        body: JSON.stringify(body),
      }),
    );
  return { calls, send };
}
test("public bootstrap works without normal identity; disabled and bearer-only clients fail closed", async () => {
  const s = setup();
  const response = await s.send({ action: "bootstrap" }, null);
  assert.equal(response.status, 200);
  const value = await response.json();
  assert.equal(value.client_id, client);
  assert.match(value.capability, /^[a-f0-9]{64}$/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  const missing = setup();
  assert.equal((await missing.send({ action: "catalog" }, null)).status, 401);
  assert.equal(
    (
      await missing.send(
        { action: "catalog" },
        null,
        "Bearer normal-or-persona-token",
      )
    ).status,
    401,
  );
  assert.equal(missing.calls.length, 0);
  const disabled = setup({ enabled: false });
  assert.equal(
    (await disabled.send({ action: "bootstrap" }, null)).status,
    503,
  );
  assert.equal(disabled.calls.length, 0);
});
test("unknown client capability never reaches session issuance", async () => {
  let issued = false;
  const s = setup({
    rpc: async () => {
      throw new BrokerFailure("denied", 403);
    },
    issue: async () => {
      issued = true;
    },
  });
  assert.equal(
    (
      await s.send({
        action: "issue",
        persona_key: "giulia",
        request_id: request,
      })
    ).status,
    403,
  );
  assert.equal(issued, false);
});
test("catalog authorization, no-store, arbitrary personas and destinations", async () => {
  const s = setup();
  const response = await s.send({ action: "catalog" });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.deepEqual((await response.json()).personas, [persona]);
  for (const body of [
    { action: "issue", persona_key: "staff", request_id: request },
    {
      action: "issue",
      persona_key: "giulia",
      request_id: request,
      email: persona.email,
    },
    {
      action: "issue",
      persona_key: "giulia",
      request_id: request,
      url: "https://evil.invalid",
    },
    { action: "issue", persona_key: "x".repeat(2000), request_id: request },
  ])
    assert.ok((await s.send(body)).status >= 400);
});
test("delivery commits exact client/persona/request before exposing session", async () => {
  const s = setup();
  const response = await s.send({
    action: "issue",
    persona_key: "giulia",
    request_id: request,
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).user_id, persona.user_id);
  assert.deepEqual(
    s.calls.map((x) => x.name),
    ["mock_control_catalog", "mock_control_claim", "mock_control_finish"],
  );
  assert.equal(typeof s.calls.at(-1).args.p_capability, "string");
  assert.equal(s.calls.at(-1).args.p_session, session);
});
test("shutdown during issuance retires only the candidate and redacts errors", async () => {
  const calls = [];
  const s = setup({
    rpc: async (name) => {
      calls.push(name);
      if (name.endsWith("catalog"))
        return { client_id: client, personas: [persona] };
      if (name.endsWith("claim"))
        return { state: "new", user_id: persona.user_id, email: persona.email };
      if (name.endsWith("finish")) throw new Error("secret admin key");
    },
    revoke: async (id, user) => calls.push([id, user]),
  });
  const response = await s.send({
    action: "issue",
    persona_key: "giulia",
    request_id: request,
  });
  assert.equal(response.status, 503);
  assert.equal((await response.text()).includes("secret"), false);
  assert.deepEqual(calls.at(-2), [session, persona.user_id]);
  assert.equal(calls.at(-1), "mock_control_retire");
});
test("recovery preserves operation, pending does not reissue", async () => {
  for (const state of ["replay", "pending", "expired"]) {
    let issued = false;
    const s = setup({
      rpc: async (name) =>
        name.endsWith("catalog")
          ? { client_id: client, personas: [persona] }
          : { state, delivery: "encrypted" },
      issue: async () => {
        issued = true;
      },
    });
    const response = await s.send({
      action: "issue",
      persona_key: "giulia",
      request_id: request,
    });
    assert.equal(response.status, state === "replay" ? 200 : 409);
    assert.equal(issued, false);
  }
});
