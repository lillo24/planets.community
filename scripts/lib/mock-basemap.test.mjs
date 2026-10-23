import assert from "node:assert/strict";
import test from "node:test";
import { createMockBasemapHandler } from "../../supabase/functions/mock-basemap/handler.mjs";
import {
  createRuntime,
  NORMAL_ORIGIN,
  MOCK_ORIGIN,
} from "../../supabase/functions/mock-basemap/runtime.mjs";
import { mapTileFixture } from "./map-provider-fixture.mjs";

const identity = { actor_scope: "a".repeat(64), client_scope: "b".repeat(64) };
const tile = {
  operation: "basemap_tile_v2",
  z: 14,
  x: 8698,
  y: 5824,
  style: "osm-carto",
  version: 1,
  cache_only: false,
};
const payload = {
  status: "ok",
  cached: true,
  source: {
    z: 12,
    x: 2174,
    y: 1456,
    style: "osm-carto",
    version: 1,
    dimension: 256,
    density: 1,
  },
  acquired_at: "2026-10-23T00:00:00Z",
  expires_at: "2026-10-30T00:00:00Z",
  server_time: "2026-10-23T00:00:00Z",
  budget_exhausted: false,
  retry_after_seconds: 0,
  image_base64: Buffer.from(mapTileFixture()).toString("base64"),
};
const request = (
  body = tile,
  headers = {},
  url = NORMAL_ORIGIN + "/functions/v1/mock-basemap",
) =>
  new Request(url, {
    method: "POST",
    headers: { authorization: "Bearer e30.e30.sig", ...headers },
    body: JSON.stringify(body),
  });
function fixture(options = {}) {
  const calls = [];
  const handler = createMockBasemapHandler({
    enabled: true,
    key: "fixture-provider-key",
    authenticate: async () => {
      calls.push("auth");
      return identity;
    },
    rpc: async (name, args) => {
      calls.push([name, args]);
      return payload;
    },
    fetcher: async () => {
      calls.push("provider");
      return new Response(mapTileFixture(), {
        headers: { "content-type": "image/png" },
      });
    },
    ...options,
  });
  return { handler, calls };
}
test("mock route shares v2 source/expiry, derives scopes and never accepts or returns an actor", async () => {
  const h = fixture();
  const result = await h.handler(request());
  assert.deepEqual(await result.json(), payload);
  assert.equal(result.headers.get("access-control-allow-origin"), null);
  assert.equal(result.headers.get("cache-control"), "no-store");
  assert.deepEqual(h.calls, [
    "auth",
    [
      "reserve_mock_basemap_tile_v1",
      {
        p_actor_scope: identity.actor_scope,
        p_client_scope: identity.client_scope,
        p_z: tile.z,
        p_x: tile.x,
        p_y: tile.y,
        p_cache_only: false,
      },
    ],
  ]);
});
for (const change of [
  { expected_profile_id: "a" },
  { actor: "a" },
  { client: "b" },
  { item_id: "private" },
  { url: "https://example.invalid" },
  { query: "private" },
  { style: "other" },
  { version: 2 },
  { z: 6 },
  { z: 19 },
  { x: -1 },
  { y: 2 ** 14 },
  { x: 1.5 },
  { cache_only: "true" },
  { operation: "search" },
  { latitude: 46 },
  { cache_only: undefined },
]) {
  test(`mock rejects untrusted schema ${JSON.stringify(change)} before authentication or IO`, async () => {
    const h = fixture();
    assert.equal(
      (await h.handler(request({ ...tile, ...change }))).status,
      400,
    );
    assert.deepEqual(h.calls, []);
  });
}
test("web origins, query bags, wrong methods and malformed bodies cannot reach credentials", async () => {
  const h = fixture();
  for (const r of [
    request(tile, { origin: "https://other.invalid" }),
    request(tile, {}, NORMAL_ORIGIN + "/functions/v1/mock-basemap?url=other"),
    new Request(NORMAL_ORIGIN, { method: "GET" }),
    new Request(NORMAL_ORIGIN, { method: "POST", body: "bad" }),
    request({ ...tile, padding: "a".repeat(2000) }),
  ]) {
    assert.equal((await h.handler(r)).status, 400);
  }
  assert.deepEqual(h.calls, []);
});
for (const auth of [null, {}, { ...identity, actor_scope: "guessed" }]) {
  test("missing or invalid verified scopes cannot access cache or reserve", async () => {
    const h = fixture({ authenticate: async () => auth });
    assert.equal((await h.handler(request())).status, 401);
    assert.deepEqual(h.calls, []);
  });
}
test("cache-only can never fetch even with an invalid cold reservation", async () => {
  const h = fixture({
    rpc: async () => ({ status: "ok", cached: false, token: "fixture" }),
  });
  assert.equal(
    (await (await h.handler(request({ ...tile, cache_only: true }))).json())
      .status,
    "unavailable",
  );
  assert.deepEqual(h.calls, ["auth"]);
});
test("cold reserve precedes provider and finish; revalidation fences revoked responses", async () => {
  for (const revoke of [false, true]) {
    let auth = 0;
    const calls = [];
    const h = fixture({
      authenticate: async () => (++auth === 1 || !revoke ? identity : null),
      rpc: async (name, args) => {
        calls.push([name, args]);
        return name.startsWith("reserve")
          ? { status: "ok", cached: false, token: "fixture" }
          : payload;
      },
    });
    const result = await (await h.handler(request())).json();
    assert.equal(result.status, revoke ? "unauthorized" : "ok");
    assert.equal(auth, 2);
    assert.equal(calls[0][0], "reserve_mock_basemap_tile_v1");
    assert.equal(calls[1][0], "finish_mock_basemap_tile_v1");
    assert.equal(
      calls[1][1].p_image_base64,
      revoke ? null : payload.image_base64,
    );
    assert.equal(h.calls.filter((v) => v === "provider").length, 1);
    assert.equal(JSON.stringify(result).includes("fixture"), false);
  }
});
for (const status of [
  "disabled",
  "unconfigured",
  "rate_limited",
  "budget_exhausted",
  "pending",
  "cache_miss",
  "unavailable",
]) {
  test(`mock ${status} returns explicit failure with no provider IO or private data`, async () => {
    const h = fixture({
      rpc: async () => ({ status, retry_after_seconds: 60, private: "secret" }),
    });
    assert.deepEqual(await (await h.handler(request())).json(), {
      status,
      retry_after_seconds: 60,
    });
    assert.deepEqual(h.calls, ["auth"]);
  });
}
test("fixed mock Auth and RPC trust anchors, no bearer forwarding to normal RPC", async () => {
  const calls = [];
  const token = "Bearer e30.e30.signature";
  const service = "synthetic-service";
  const runtime = createRuntime({
    enabled: true,
    normalOrigin: NORMAL_ORIGIN,
    service,
    mockPublicKey: "sb_publishable_" + "x".repeat(24),
    key: "provider",
    fetcher: async (url, init) => {
      calls.push([url, init]);
      assert.equal(init.redirect, "error");
      assert.ok(init.signal);
      return Response.json(
        url.endsWith("/user")
          ? { id: "verified" }
          : url.endsWith("mock_basemap_identity_v1")
            ? identity
            : payload,
      );
    },
  });
  assert.equal(
    (await runtime(request(tile, { authorization: token }))).status,
    200,
  );
  assert.deepEqual(
    calls.map((c) => c[0]),
    [
      MOCK_ORIGIN + "/auth/v1/user",
      MOCK_ORIGIN + "/rest/v1/rpc/mock_basemap_identity_v1",
      NORMAL_ORIGIN + "/rest/v1/rpc/reserve_mock_basemap_tile_v1",
    ],
  );
  assert.equal(calls[0][1].headers.Authorization, token);
  assert.equal(calls[1][1].headers.Authorization, token);
  assert.equal(calls[2][1].headers.Authorization, "Bearer " + service);
  assert.equal(calls[2][1].body.includes(token), false);
});
test("unconfigured target, normal/forged/revoked mock Auth denials never reach the ledger", async () => {
  for (const failureAt of [0, 1]) {
    let calls = 0;
    const runtime = createRuntime({
      enabled: true,
      normalOrigin: NORMAL_ORIGIN,
      service: "fixture",
      mockPublicKey: "sb_publishable_" + "x".repeat(24),
      key: "provider",
      fetcher: async () =>
        ++calls > failureAt
          ? new Response(null, { status: 401 })
          : Response.json({ id: "verified" }),
    });
    assert.equal((await runtime(request())).status, 401);
    assert.equal(calls, failureAt + 1);
  }
  const h = fixture({ enabled: false });
  assert.equal((await (await h.handler(request())).json()).status, "disabled");
  assert.deepEqual(h.calls, []);
});
