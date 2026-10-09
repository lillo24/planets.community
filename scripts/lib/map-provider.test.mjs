import assert from "node:assert/strict";
import test from "node:test";
import { createMapProviderHandler } from "../../supabase/functions/map-provider/handler.mjs";
import {
  fetchTile,
  validateTile,
  validateTilePng,
} from "../../supabase/functions/map-provider/provider.mjs";
import { mapCenterFixture, mapTileFixture } from "./map-provider-fixture.mjs";

const actor = "a9610000-0000-4000-8000-000000000001";
const other = "a9610000-0000-4000-8000-000000000002";
const tile = {
  operation: "tile",
  expected_profile_id: actor,
  z: 12,
  x: 2174,
  y: 1456,
  style: "osm-carto",
  version: 1,
};
const search = {
  operation: "search",
  expected_profile_id: actor,
  query: "Bolzano",
  language: "it",
};
const request = (body, extra = {}) =>
  new Request("https://fixture.invalid/map-provider", {
    method: "POST",
    body: JSON.stringify(body),
    headers: {
      Authorization: "Bearer synthetic-private-jwt",
      "Content-Type": "application/json",
      ...extra,
    },
  });
function harness(overrides = {}) {
  const calls = [],
    metrics = [];
  const handler = createMapProviderHandler({
    tilesEnabled: true,
    centersEnabled: true,
    key: "synthetic-server-key",
    authenticate: async (value) => {
      calls.push(["auth", value]);
      return actor;
    },
    rpc: async (name, args) => {
      calls.push([name, args]);
      return name === "reserve_map_provider_v1"
        ? { status: "ok", token: other, cached: false }
        : name === "resolve_map_center_v1"
          ? {
              status: "ok",
              center: {
                label: "Synthetic",
                latitude: 46,
                longitude: 11,
                country_code: "it",
              },
            }
          : {
              status: "ok",
              suggestions: [
                {
                  id: other,
                  label: "Synthetic",
                  expires_at: "2026-10-09T20:00:00Z",
                },
              ],
            };
    },
    fetcher: async (url, options) => {
      calls.push(["upstream", url, options]);
      return url.pathname.includes("/tile/")
        ? new Response(mapTileFixture(), {
            headers: { "Content-Type": "image/png" },
          })
        : Response.json(mapCenterFixture);
    },
    metric: (status) => metrics.push(status),
    ...overrides,
  });
  return { handler, calls, metrics };
}

for (const options of [
  { tilesEnabled: false, centersEnabled: false },
  { key: "" },
]) {
  test(`disabled or missing configuration does zero auth, database and provider IO: ${JSON.stringify(options)}`, async () => {
    const h = harness(options);
    const response = await h.handler(request(tile));
    assert.ok(
      ["disabled", "unconfigured"].includes((await response.json()).status),
    );
    assert.deepEqual(h.calls, []);
  });
}
for (const change of [
  { url: "https://evil.invalid" },
  { latitude: 46 },
  { z: 6 },
  { z: 19 },
  { x: -1 },
  { y: 4096 },
  { x: 1.5 },
  { style: "satellite" },
  { version: 2 },
  { operation: "proxy" },
  { expected_profile_id: "installation-123" },
]) {
  test(`reject tile request before IO: ${JSON.stringify(change)}`, async () => {
    const h = harness();
    const response = await h.handler(request({ ...tile, ...change }));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).status, "invalid_request");
    assert.deepEqual(h.calls, []);
  });
}
test("reject query bags, oversized and malformed body", async () => {
  const h = harness();
  for (const req of [
    new Request("https://fixture.invalid/map-provider?apiKey=bad", {
      method: "POST",
    }),
    new Request("https://fixture.invalid/map-provider", {
      method: "POST",
      body: "{",
    }),
    request({ ...search, query: "a".repeat(2100) }),
  ]) {
    assert.equal((await h.handler(req)).status, 400);
  }
  assert.deepEqual(h.calls, []);
});
test("guests cannot spoof an actor through headers, IP or request body", async () => {
  const h = harness({ authenticate: async () => null });
  const response = await h.handler(
    request(search, { "X-Forwarded-For": "127.0.0.1", "X-User-Id": actor }),
  );
  assert.equal(response.status, 401);
  assert.equal((await response.json()).status, "guest_disabled");
  assert.deepEqual(h.calls, []);
});
test("verified JWT actor must equal expected actor", async () => {
  const h = harness({ authenticate: async () => other });
  assert.equal((await h.handler(request(search))).status, 403);
  assert.deepEqual(h.calls, []);
});
test("independent flags prevent their disabled operation before auth", async () => {
  const h = harness({ centersEnabled: false });
  assert.equal(
    (await (await h.handler(request(search))).json()).status,
    "disabled",
  );
  assert.deepEqual(h.calls, []);
});
test("center search reserves first, fixes Italy and bias, strips opaque data and caller credentials", async () => {
  const h = harness();
  const result = await (await h.handler(request(search))).json();
  assert.equal(result.status, "ok");
  assert.deepEqual(
    h.calls.map((c) => c[0]),
    ["auth", "reserve_map_provider_v1", "upstream", "finish_map_provider_v1"],
  );
  const [, url, options] = h.calls[2];
  assert.equal(
    url.origin + url.pathname,
    "https://api.geoapify.com/v1/geocode/autocomplete",
  );
  assert.equal(url.searchParams.get("filter"), "countrycode:it");
  assert.equal(url.searchParams.get("bias"), "proximity:11.1217,46.0748");
  assert.equal(url.searchParams.get("limit"), "5");
  assert.equal(options.redirect, "error");
  assert.equal(options.headers, undefined);
  const center = h.calls[3][1].p_centers[0];
  assert.deepEqual(Object.keys(center).sort(), [
    "country_code",
    "label",
    "latitude",
    "longitude",
  ]);
  assert.equal(center.country_code, "it");
  assert.doesNotMatch(
    JSON.stringify([result, center, h.metrics]),
    /MUST_NOT_SURVIVE|synthetic-server-key|private-jwt/,
  );
  assert.deepEqual(h.metrics, ["ok"]);
});
test("resolve uses separate actor-bound selection RPC with no upstream call", async () => {
  const h = harness();
  const result = await (
    await h.handler(
      request({
        operation: "resolve",
        expected_profile_id: actor,
        suggestion_id: other,
      }),
    )
  ).json();
  assert.equal(result.center.latitude, 46);
  assert.deepEqual(
    h.calls.map((c) => c[0]),
    ["auth", "resolve_map_center_v1"],
  );
});
for (const status of [
  "pending",
  "quota_exceeded",
  "rate_limited",
  "disabled",
  "unavailable",
]) {
  test(`reservation ${status} never calls provider`, async () => {
    const h = harness({ rpc: async () => ({ status }) });
    assert.equal(
      (await (await h.handler(request(tile))).json()).status,
      status,
    );
    assert.equal(
      h.calls.some((c) => c[0] === "upstream"),
      false,
    );
  });
}
test("tile transport is valid bounded binary with fixed endpoint and no browser/provider URL", async () => {
  const h = harness();
  const response = await h.handler(request(tile));
  assert.equal(
    response.headers.get("Content-Type"),
    "application/octet-stream",
  );
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), mapTileFixture());
  assert.deepEqual(
    h.calls.map((c) => c[0]),
    ["auth", "reserve_map_provider_v1", "upstream", "finish_map_provider_v1"],
  );
  const [, url, options] = h.calls[2];
  assert.equal(
    url.origin + url.pathname,
    "https://api.geoapify.com/v1/tile/osm-carto/12/2174/1456.png",
  );
  assert.equal(options.redirect, "error");
  assert.deepEqual(options.headers, { Accept: "image/png" });
});
test("cache hit returns bytes without upstream or finish", async () => {
  const h = harness({
    rpc: async () => ({
      status: "ok",
      cached: true,
      image_base64: mapTileFixture().toString("base64"),
    }),
  });
  assert.deepEqual(
    Buffer.from(await (await h.handler(request(tile))).arrayBuffer()),
    mapTileFixture(),
  );
  assert.deepEqual(
    h.calls.map((c) => c[0]),
    ["auth"],
  );
});
test("kill switch at finish prevents fetched bytes from escaping", async () => {
  const h = harness({
    rpc: async (name) =>
      name.startsWith("reserve")
        ? { status: "ok", token: other }
        : { status: "disabled" },
  });
  assert.equal(
    (await (await h.handler(request(tile))).json()).status,
    "disabled",
  );
});
test("provider failure closes reservation with no success-shaped bytes or sensitive metrics", async () => {
  const h = harness({
    fetcher: async () => {
      throw new Error("secret-address private-jwt server-key");
    },
  });
  const response = await h.handler(request(tile));
  assert.deepEqual(await response.json(), { status: "unavailable" });
  assert.deepEqual(h.calls.at(-1), [
    "finish_map_provider_v1",
    { p_cache_key: h.calls[1][1].p_cache_key, p_token: other },
  ]);
  assert.deepEqual(h.metrics, ["unavailable"]);
});
test("PNG rejects dimensions, missing IEND, wrong types and excess bytes", () => {
  const good = mapTileFixture();
  assert.equal(validateTilePng(good), good);
  const dimension = Buffer.from(good);
  dimension.writeUInt32BE(512, 16);
  for (const bad of [
    dimension,
    good.subarray(0, -12),
    new Uint8Array(262145),
    "PNG",
  ])
    assert.throws(() => validateTilePng(bad));
  assert.deepEqual(validateTile(tile), { z: 12, x: 2174, y: 1456 });
});
test("tile deadline bounds both fetch and an incomplete response stream", async () => {
  for (const fetcher of [
    () => new Promise(() => {}),
    async () =>
      new Response(new ReadableStream({ start() {} }), {
        headers: { "Content-Type": "image/png" },
      }),
  ]) {
    await assert.rejects(
      fetchTile({
        tile,
        key: "synthetic",
        enabled: true,
        fetcher,
        timeoutMs: 15,
      }),
      (e) => e.status === "timeout",
    );
  }
});
test("tile content-type, length, status and malformed data fail explicitly", async () => {
  for (const response of [
    new Response("not a PNG", { headers: { "Content-Type": "image/png" } }),
    new Response(mapTileFixture(), {
      headers: { "Content-Type": "image/jpeg" },
    }),
    new Response(mapTileFixture(), {
      headers: { "Content-Type": "image/png", "Content-Length": "262145" },
    }),
    new Response("redirect", {
      status: 302,
      headers: { Location: "https://evil.invalid" },
    }),
  ]) {
    await assert.rejects(
      fetchTile({
        tile,
        key: "synthetic",
        enabled: true,
        fetcher: async () => response,
      }),
    );
  }
});
