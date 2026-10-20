import assert from "node:assert/strict";
import test from "node:test";
import { createMapProviderHandler } from "../../supabase/functions/map-provider/handler.mjs";
import { mapTileFixture } from "./map-provider-fixture.mjs";

const actor = "a9610000-0000-4000-8000-000000000001";
const tile = {
  operation: "basemap_tile_v2",
  expected_profile_id: actor,
  z: 14,
  x: 8698,
  y: 5824,
  style: "osm-carto",
  version: 1,
  cache_only: false,
};
const request = (body) =>
  new Request("https://fixture.invalid/map-provider", {
    method: "POST",
    headers: { Authorization: "Bearer synthetic" },
    body: JSON.stringify(body),
  });
const payload = (z = 12, x = 2174, y = 1456) => ({
  status: "ok",
  cached: true,
  source: {
    z,
    x,
    y,
    style: "osm-carto",
    version: 1,
    dimension: 256,
    density: 1,
  },
  acquired_at: "2026-10-20T00:00:00Z",
  expires_at: "2026-10-27T00:00:00Z",
  server_time: "2026-10-20T00:00:00Z",
  budget_exhausted: true,
  retry_after_seconds: 3600,
  image_base64: Buffer.from(mapTileFixture()).toString("base64"),
});
function fixture(claim, overrides = {}) {
  const calls = [];
  const handler = createMapProviderHandler({
    tilesEnabled: true,
    centersEnabled: true,
    key: "synthetic",
    authenticate: async () => actor,
    rpc: async (name, args) => {
      calls.push([name, args]);
      return name === "reserve_basemap_tile_v2"
        ? claim
        : { ...payload(tile.z, tile.x, tile.y), cached: false };
    },
    fetcher: async () => {
      calls.push(["upstream"]);
      return new Response(mapTileFixture(), {
        headers: { "content-type": "image/png" },
      });
    },
    ...overrides,
  });
  return { handler, calls };
}
test("v2 preserves ancestor identity, original expiry and reset, without upstream IO", async () => {
  const h = fixture(payload());
  const response = await h.handler(request({ ...tile, cache_only: true }));
  assert.deepEqual(await response.json(), payload());
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0][1].p_cache_only, true);
});
for (const status of [
  "budget_exhausted",
  "disabled",
  "unconfigured",
  "guest_disabled",
  "unauthorized",
  "rate_limited",
  "pending",
  "cache_miss",
  "unavailable",
]) {
  test(`v2 ${status} makes zero upstream calls and is not disguised as imagery`, async () => {
    const h = fixture({ status, retry_after_seconds: 60 });
    const result = await (await h.handler(request(tile))).json();
    assert.equal(result.status, status);
    assert.equal(h.calls.length, 1);
  });
}
test("cache-only refuses even a defective upstream reservation response", async () => {
  const h = fixture({ status: "ok", cached: false, token: actor });
  assert.equal(
    (await (await h.handler(request({ ...tile, cache_only: true }))).json())
      .status,
    "unavailable",
  );
  assert.equal(h.calls.length, 1);
});
test("cold v2 tile reserves then fetches then finishes, with no legacy contract mutation", async () => {
  const h = fixture({ status: "ok", cached: false, token: actor });
  const r = await (await h.handler(request(tile))).json();
  assert.equal(r.status, "ok");
  assert.equal(r.source.z, 14);
  assert.deepEqual(
    h.calls.map((c) => c[0]),
    ["reserve_basemap_tile_v2", "upstream", "finish_basemap_tile_v2"],
  );
});
test("kill at v2 finish never returns fetched bytes", async () => {
  const h = fixture(null, {
    rpc: async (name) =>
      name === "reserve_basemap_tile_v2"
        ? { status: "ok", cached: false, token: actor }
        : { status: "disabled" },
  });
  assert.deepEqual(await (await h.handler(request(tile))).json(), {
    status: "disabled",
  });
});
test("corrupt cached PNG is an explicit failure", async () => {
  const h = fixture({ ...payload(), image_base64: "aW52YWxpZA==" });
  assert.equal(
    (await (await h.handler(request(tile))).json()).status,
    "invalid_image",
  );
  assert.equal(h.calls.length, 1);
});
test("v2 rejects caller cache promotion, URLs, and missing cache-only mode before auth", async () => {
  let io = 0;
  const h = fixture(payload(), {
    authenticate: async () => {
      io++;
      return actor;
    },
  });
  for (const change of [
    { cache_only: undefined },
    { cache_only: "true" },
    { public: true },
    { url: "https://example.invalid" },
  ]) {
    assert.equal(
      (await h.handler(request({ ...tile, ...change }))).status,
      400,
    );
  }
  assert.equal(io, 0);
  assert.equal(h.calls.length, 0);
});
test("v2 guest and expected-actor checks guard cache-only reuse", async () => {
  for (const identity of [null, "a9610000-0000-4000-8000-000000000002"]) {
    const h = fixture(payload(), { authenticate: async () => identity });
    assert.equal(
      (await h.handler(request({ ...tile, cache_only: true }))).status,
      identity ? 403 : 401,
    );
    assert.equal(h.calls.length, 0);
  }
});
