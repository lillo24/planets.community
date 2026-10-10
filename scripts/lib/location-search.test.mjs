import test from "node:test";
import assert from "node:assert/strict";
import {
  autocomplete,
  boundedJson,
  LocationFailure,
  normalizeQuery,
  normalizeResults,
} from "../../supabase/functions/location-search/provider.mjs";
import { createHandler } from "../../supabase/functions/location-search/handler.mjs";

const row = (changes = {}) => ({
  country_code: "it",
  city: "Synthetic locality",
  state: "Synthetic region",
  formatted: "Synthetic street 42, Synthetic locality",
  result_type: "building",
  lat: 45,
  lon: 12,
  rank: { confidence: 0.9 },
  datasource: { sourcename: "openstreetmap", raw: { secret: "discard" } },
  ...changes,
});
const actor = "00000000-0000-4000-8000-000000000001";
const item = "00000000-0000-4000-8000-000000000002";
const session = "00000000-0000-4000-8000-000000000003";
const receipt = "00000000-0000-4000-8000-000000000004";
const input = (changes = {}) => ({
  operation: "search",
  expected_profile_id: actor,
  item_kind: "one_time",
  item_id: item,
  revision: 0,
  slot: "area",
  session_token: session,
  query: "Trento",
  language: "it",
  ...changes,
});
const request = (body) =>
  new Request("https://local.test/location-search", {
    method: "POST",
    headers: { Authorization: "Bearer synthetic-not-upstream" },
    body: JSON.stringify(body),
  });
const fails = (status) => (error) =>
  error instanceof LocationFailure && error.status === status;

test("Trento suggestions retain province and region without choosing a match", () => {
  const results = normalizeResults(
    {
      results: [
        row({
          city: "Trento",
          county: "Provincia autonoma di Trento",
          state: "Trentino-Alto Adige",
          result_type: "city",
        }),
        row({
          city: "Trento",
          county: "Provincia di Rovigo",
          state: "Veneto",
          result_type: "city",
        }),
      ],
    },
    "it",
  );
  assert.equal(results.length, 2);
  assert.equal(
    results[0].label,
    "Trento, Provincia autonoma di Trento, Trentino-Alto Adige, Italia",
  );
  assert.equal(results[1].label, "Trento, Provincia di Rovigo, Veneto, Italia");
});

test("mixed place slot is restricted to one-time Projects and preserves metering", async () => {
  for (const kind of ["one_time", "recurring", "resource"]) {
    const calls = [];
    const handler = createHandler({
      enabled: true,
      key: "synthetic-key",
      authenticate: async () => actor,
      rpc: async (name, args) => {
        calls.push([name, args]);
        return { status: "disabled" };
      },
      fetcher: async () => {
        throw new Error("Disabled meter must not call provider");
      },
    });
    const result = await (
      await handler(request(input({ item_kind: kind, slot: "place" })))
    ).json();
    assert.equal(
      result.status,
      kind === "one_time" ? "disabled" : "invalid_request",
    );
    assert.equal(calls.length, kind === "one_time" ? 1 : 0);
    if (kind === "one_time") assert.equal(calls[0][1].p_slot, "place");
  }
});

test("normalization bounds, NFC, controls and input encoding", () => {
  assert.equal(normalizeQuery("  Povo,   Trento  "), "Povo, Trento");
  for (const value of [null, "a", "a".repeat(161), "abc\nxyz", "a\u0000b"])
    assert.throws(() => normalizeQuery(value), fails("invalid_request"));
});

test("one endpoint: Italy restriction, Trento ranking bias, IT/EN and no caller metadata", async () => {
  for (const language of ["it", "en"]) {
    const places = await autocomplete({
      enabled: true,
      key: "synthetic-secret",
      query: "Piazza & Duomo",
      language,
      fetcher: async (url, options) => {
        assert.equal(
          url.origin + url.pathname,
          "https://api.geoapify.com/v1/geocode/autocomplete",
        );
        assert.equal(url.searchParams.get("filter"), "countrycode:it");
        assert.equal(url.searchParams.get("bias"), "proximity:11.1217,46.0748");
        assert.equal(url.searchParams.get("limit"), "5");
        assert.equal(url.searchParams.get("text"), "Piazza & Duomo");
        assert.equal(url.searchParams.get("lang"), language);
        assert.deepEqual([...url.searchParams.keys()].sort(), [
          "apiKey",
          "bias",
          "filter",
          "format",
          "lang",
          "limit",
          "text",
        ]);
        assert.equal(options.headers, undefined);
        assert.equal(options.redirect, "error");
        return Response.json({ results: [row()] });
      },
    });
    assert.equal(places[0].latitude, 45);
    assert.equal(places[0].longitude, 12);
    assert.equal(places[0].confidence, 0.9);
    assert.equal(places[0].source, "openstreetmap");
    assert.ok(!JSON.stringify(places).includes("synthetic-secret"));
    assert.ok(!JSON.stringify(places).includes("discard"));
  }
});

test("broad labels cannot contain provider exact formatted text; amenity supported without Places directory", () => {
  const places = normalizeResults(
    {
      results: [row({ result_type: "city" }), row({ result_type: "amenity" })],
    },
    "en",
  );
  assert.equal(places[0].kind, "locality");
  assert.ok(!places[0].label.includes("street"));
  assert.equal(places[1].kind, "amenity");
  assert.ok(places[1].attribution.includes("OpenStreetMap"));
  assert.equal(normalizeResults({ results: [row(), row()] }, "it").length, 1);
  assert.deepEqual(normalizeResults({ results: [] }, "it"), []);
});

test("country, precision, components, source and confidence fail truthfully", () => {
  for (const [changes, status] of [
    [{ country_code: "fr" }, "invalid_country"],
    [{ country_code: undefined }, "invalid_country"],
    [{ city: undefined }, "malformed_response"],
    [{ formatted: "<script>" }, "malformed_response"],
    [{ lat: "45" }, "malformed_response"],
    [{ lon: 181 }, "malformed_response"],
    [{ rank: { confidence: 2 } }, "malformed_response"],
    [{ result_type: "unknown" }, "unsupported_place"],
    [{ datasource: { sourcename: "unreviewed-source" } }, "unsupported_source"],
  ])
    assert.throws(
      () => normalizeResults({ results: [row(changes)] }, "it"),
      fails(status),
    );
  assert.throws(
    () => normalizeResults({ results: Array(6).fill(row()) }, "it"),
    fails("malformed_response"),
  );
});

test("disabled/missing credentials and invalid language make zero upstream calls", async () => {
  const fetcher = () => {
    assert.fail("upstream called");
  };
  await assert.rejects(
    autocomplete({ enabled: false, key: "secret", fetcher }),
    fails("disabled"),
  );
  await assert.rejects(
    autocomplete({ enabled: true, key: "", fetcher }),
    fails("unconfigured"),
  );
  await assert.rejects(
    autocomplete({ enabled: true, key: "secret", language: "de", fetcher }),
    fails("invalid_request"),
  );
});

test("HTTP errors, malformed JSON and network failure never expose provider bodies/URLs", async () => {
  for (const [code, status] of [
    [401, "invalid_credentials"],
    [403, "invalid_credentials"],
    [429, "provider_quota"],
    [500, "provider_http"],
  ]) {
    await assert.rejects(
      autocomplete({
        enabled: true,
        key: "secret",
        language: "it",
        query: "Trento",
        fetcher: async () =>
          new Response("private upstream body", { status: code }),
      }),
      fails(status),
    );
  }
  await assert.rejects(
    autocomplete({
      enabled: true,
      key: "secret",
      language: "it",
      query: "Trento",
      fetcher: async () => {
        throw new Error("private URL and key");
      },
    }),
    fails("offline"),
  );
  await assert.rejects(
    boundedJson(new Response("x".repeat(65537)), 65536),
    fails("malformed_response"),
  );
  await assert.rejects(
    boundedJson(new Response("{broken"), 65536),
    fails("malformed_response"),
  );
});

test("disabled/unconfigured endpoint and anonymous traffic cannot reach auth, meter or provider", async () => {
  const forbidden = () => assert.fail("unexpected dependency call");
  for (const [config, status] of [
    [{}, "disabled"],
    [{ enabled: true }, "unconfigured"],
  ]) {
    const handler = createHandler({
      ...config,
      authenticate: forbidden,
      rpc: forbidden,
      fetcher: forbidden,
    });
    assert.equal(
      (await (await handler(request(input()))).json()).status,
      status,
    );
  }
  const handler = createHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => null,
    rpc: forbidden,
    fetcher: forbidden,
  });
  assert.equal((await handler(request(input()))).status, 401);
});

test("strict purpose-limited endpoint rejects arbitrary relay controls and actor/scope input", async () => {
  const handler = createHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => actor,
    rpc: () => assert.fail("meter should not run"),
    fetcher: () => assert.fail("provider should not run"),
  });
  for (const change of [
    { url: "https://paid.test" },
    { apiKey: "client-key" },
    { latitude: 45 },
    { expected_profile_id: item },
    { language: "fr" },
    { slot: "public" },
    { revision: -1 },
    { session_token: "opaque" },
    { operation: "places" },
    { query: "a" },
  ]) {
    assert.equal((await handler(request(input(change)))).status, 400);
  }
  assert.equal(
    (
      await handler(
        new Request("https://local.test/location-search?url=bad", {
          method: "POST",
        }),
      )
    ).status,
    400,
  );
});

test("budget exhaustion, rate limit, stale input, pending and unavailable meter fail closed", async () => {
  for (const status of [
    "disabled",
    "budget_exhausted",
    "rate_limited",
    "stale_selection",
    "search_pending",
  ]) {
    const handler = createHandler({
      enabled: true,
      key: "fake",
      authenticate: async () => actor,
      rpc: async () => ({ status }),
      fetcher: () => assert.fail("provider called after denial"),
    });
    assert.equal(
      (await (await handler(request(input()))).json()).status,
      status,
    );
  }
  const handler = createHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => actor,
    rpc: async () => {
      throw new Error("sensitive database error");
    },
    fetcher: () => assert.fail("provider called"),
  });
  const response = await (await handler(request(input()))).json();
  assert.deepEqual(response, { status: "metering_unavailable" });
});

test("cached duplicate search and explicit resolve reuse verified receipts with zero provider calls", async () => {
  const calls = [];
  const handler = createHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => actor,
    fetcher: () => assert.fail("provider called"),
    rpc: async (name, args) => {
      calls.push({ name, args });
      return name.startsWith("reserve")
        ? { status: "ok", cached: true, suggestions: [{ id: receipt }] }
        : { status: "ok", selection: { id: receipt } };
    },
  });
  assert.equal(
    (await (await handler(request(input()))).json()).suggestions[0].id,
    receipt,
  );
  assert.equal(
    (
      await (
        await handler(
          request(
            input({
              operation: "resolve",
              query: undefined,
              language: undefined,
              receipt_id: receipt,
            }),
          ),
        )
      ).json()
    ).selection.id,
    receipt,
  );
  assert.ok(!JSON.stringify(calls).includes("Trento"));
  assert.equal(calls[0].args.p_query_hash.length, 64);
  assert.equal(calls[1].args.p_actor, actor);
});

test("successful bounded provider operation spends exactly one reservation and logs status only", async () => {
  const calls = [];
  const metrics = [];
  let upstream = 0;
  const handler = createHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => actor,
    metric: (status) => metrics.push(status),
    fetcher: async () => {
      upstream++;
      return Response.json({ results: [row()] });
    },
    rpc: async (name, args) => {
      calls.push({ name, args });
      return name.startsWith("reserve")
        ? { status: "ok", cached: false, batch_id: session }
        : { status: "ok", suggestions: [] };
    },
  });
  assert.deepEqual(await (await handler(request(input()))).json(), {
    status: "ok",
    suggestions: [],
  });
  assert.equal(upstream, 1);
  assert.equal(calls.length, 2);
  assert.deepEqual(metrics, ["ok"]);
  assert.ok(!JSON.stringify(calls[1]).includes("raw"));
});

test("upstream deadline applies to fetch and body, without retries", async () => {
  await assert.rejects(
    autocomplete({
      enabled: true,
      key: "fake",
      query: "Trento",
      language: "it",
      fetcher: async (_url, { signal }) =>
        new Promise((_resolve, reject) =>
          signal.addEventListener("abort", () => reject(new Error("abort"))),
        ),
    }),
    fails("timeout"),
  );
});
test("slow JSON bodies have a deadline before metering or forwarding", async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode("{"));
    },
  });
  await assert.rejects(
    boundedJson(new Response(stream), 4096, 10),
    fails("timeout"),
  );
});
