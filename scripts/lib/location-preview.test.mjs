import test from "node:test";
import assert from "node:assert/strict";
import {
  renderStatic,
  validatePng,
  MAX_BYTES,
  RESERVED_CREDITS,
} from "../../supabase/functions/location-preview/provider.mjs";
import { createPreviewHandler } from "../../supabase/functions/location-preview/handler.mjs";

const png = Uint8Array.from(
  Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAgAAAAEACAYAAADFkM5nAAAEQUlEQVR4nO3WMQ0AIADAMPz7I0ECLsAFHOvRf+fG2vMAAC3jdwAA8J4BAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABB0AdTsa1lG1P77AAAAAElFTkSuQmCC",
    "base64",
  ),
);
const item = "00000000-0000-4000-8000-000000000001";
const actor = "00000000-0000-4000-8000-000000000002";
const imageKey = "a".repeat(64);
const projection = (changes = {}) => ({
  item_kind: "one_time",
  item_id: item,
  revision: 1,
  image_key: imageKey,
  scope: "area",
  audience: "public",
  place: {
    kind: "locality",
    label: "Synthetic area",
    latitude: 45,
    longitude: 12,
  },
  ...changes,
});
const body = (changes = {}) => ({
  item_kind: "one_time",
  item_id: item,
  view: "card",
  revision: 1,
  image_key: imageKey,
  ...changes,
});
const request = (b) =>
  new Request("https://local.invalid/location-preview", {
    method: "POST",
    headers: { Authorization: "Bearer synthetic" },
    body: JSON.stringify(b),
  });
const imageResponse = () =>
  new Response(png, { headers: { "Content-Type": "image/png" } });
const fail = (status) => (e) => e.status === status;

test("fixed area/exact static options and conservative credit estimate", async () => {
  assert.equal(RESERVED_CREDITS, 4);
  for (const scope of ["area", "exact"]) {
    const p = projection({
      scope,
      place: {
        kind: scope === "area" ? "locality" : "address",
        latitude: 45,
        longitude: 12,
      },
    });
    const bytes = await renderStatic({
      projection: p,
      key: "synthetic-secret",
      enabled: true,
      fetcher: async (url, opts) => {
        assert.equal(
          url.origin + url.pathname,
          "https://maps.geoapify.com/v1/staticmap",
        );
        for (const [k, v] of Object.entries({
          style: "osm-carto",
          width: "512",
          height: "256",
          scaleFactor: "1",
          format: "png",
          pitch: "0",
          bearing: "0",
          attribution: "default",
          center: "lonlat:12,45",
        }))
          assert.equal(url.searchParams.get(k), v);
        assert.equal(
          url.searchParams.get("zoom"),
          scope === "area" ? "10" : "16",
        );
        assert.equal(url.searchParams.has("marker"), scope === "exact");
        assert.equal(opts.redirect, "error");
        assert.ok(opts.signal);
        return imageResponse();
      },
    });
    assert.deepEqual(bytes, png);
  }
});
test("disabled/missing key causes zero calls", async () => {
  let calls = 0;
  const fetcher = () => {
    calls++;
    throw Error("network");
  };
  await assert.rejects(
    renderStatic({ projection: projection(), fetcher }),
    fail("disabled"),
  );
  await assert.rejects(
    renderStatic({ projection: projection(), enabled: true, fetcher }),
    fail("unconfigured"),
  );
  for (const config of [{ enabled: false }, { enabled: true, key: "" }]) {
    const handler = createPreviewHandler({
      ...config,
      read: fetcher,
      rpc: fetcher,
      authenticate: fetcher,
      fetcher,
    });
    const result = await handler(request(body()));
    assert.equal(result.status, 200);
  }
  assert.equal(calls, 0);
});
test("bounds, MIME, status, header, truncated PNG and oversized streaming fail loudly", async () => {
  for (const invalid of [
    new Uint8Array(45),
    png.slice(0, -1),
    new Uint8Array(MAX_BYTES + 1),
  ])
    assert.throws(() => validatePng(invalid), fail("invalid_image"));
  const p = projection();
  for (const response of [
    new Response("html", { headers: { "Content-Type": "text/html" } }),
    new Response(png, {
      headers: {
        "Content-Type": "image/png",
        "Content-Length": String(MAX_BYTES + 1),
      },
    }),
    new Response(new Uint8Array(MAX_BYTES + 1), {
      headers: { "Content-Type": "image/png" },
    }),
    new Response(null, { status: 429 }),
  ])
    await assert.rejects(
      renderStatic({
        projection: p,
        key: "fake",
        enabled: true,
        fetcher: async () => response,
      }),
      (e) => ["invalid_image", "quota"].includes(e.status),
    );
  await assert.rejects(
    renderStatic({
      projection: projection({
        place: { kind: "locality", latitude: 91, longitude: 12 },
      }),
      key: "fake",
      enabled: true,
    }),
    fail("invalid_request"),
  );
  await assert.rejects(
    renderStatic({
      projection: p,
      key: "fake",
      enabled: true,
      fetcher: async () => {
        throw new DOMException("synthetic", "AbortError");
      },
    }),
    fail("timeout"),
  );
});
test("purpose-limited request rejects coordinates, options, arbitrary URLs and stale keys", async () => {
  let reads = 0,
    renders = 0;
  const handler = createPreviewHandler({
    enabled: true,
    key: "fake",
    read: async () => {
      reads++;
      return projection();
    },
    rpc: async () => ({ status: "ok" }),
    fetcher: async () => {
      renders++;
      return imageResponse();
    },
  });
  for (const b of [
    body({ latitude: 45 }),
    body({ url: "https://evil.invalid" }),
    body({ style: "other" }),
    body({ expected_profile_id: actor }),
    body({ revision: -1 }),
    body({ image_key: "bad" }),
  ])
    assert.equal((await handler(request(b))).status, 400);
  assert.equal(reads, 0);
  assert.equal(renders, 0);
  assert.equal((await handler(request(body({ revision: 2 })))).status, 409);
  assert.equal(renders, 0);
});
test("public card never renders Project exact and public reads discard viewer Authorization", async () => {
  let metered = 0;
  const handler = createPreviewHandler({
    enabled: true,
    key: "fake",
    read: async (args, authorization) => {
      assert.equal(authorization, null);
      assert.equal(args.p_expected_profile_id, null);
      return projection({
        scope: "exact",
        place: { kind: "address", latitude: 44, longitude: 10 },
      });
    },
    rpc: async () => {
      metered++;
      return { status: "ok" };
    },
  });
  assert.equal((await handler(request(body()))).status, 403);
  assert.equal(metered, 0);
});
test("protected auth, no cache, reauthorization and no reusable image URLs", async () => {
  for (const allowed of [true, false]) {
    let reads = 0,
      reserves = 0,
      finishes = 0;
    const p = projection({
      audience: "protected",
      scope: "exact",
      place: { kind: "address", latitude: 44, longitude: 10 },
    });
    const handler = createPreviewHandler({
      enabled: true,
      key: "fake",
      authenticate: async () => actor,
      read: async (args, authorization) => {
        assert.equal(args.p_expected_profile_id, actor);
        assert.equal(authorization, "Bearer synthetic");
        return ++reads === 2 && !allowed ? null : p;
      },
      rpc: async (name, args) => {
        if (name === "reserve_location_preview_v1") {
          reserves++;
          assert.equal(args.p_cacheable, false);
          assert.equal(args.p_actor, actor);
          return { status: "ok", cached: false };
        }
        finishes++;
      },
      fetcher: async () => imageResponse(),
    });
    const response = await handler(
      request(body({ view: "protected_detail", expected_profile_id: actor })),
    );
    assert.equal(reserves, 1);
    assert.equal(finishes, 0);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    if (allowed) {
      assert.equal(
        response.headers.get("Content-Type"),
        "application/octet-stream",
      );
      assert.deepEqual(new Uint8Array(await response.arrayBuffer()), png);
    } else assert.equal((await response.json()).status, "stale");
  }
  const denied = createPreviewHandler({
    enabled: true,
    key: "fake",
    authenticate: async () => null,
    read: () => {
      throw Error("must not read");
    },
  });
  assert.equal(
    (
      await denied(
        request(body({ view: "protected_detail", expected_profile_id: actor })),
      )
    ).status,
    403,
  );
});
test("cache hit still rereads canonical entitlement, metering failure never fetches", async () => {
  let renders = 0;
  for (const status of [
    "disabled",
    "unconfigured",
    "budget_exhausted",
    "rate_limited",
  ]) {
    const handler = createPreviewHandler({
      enabled: true,
      key: "fake",
      read: async () => projection(),
      rpc: async () => ({ status }),
      fetcher: async () => {
        renders++;
        return imageResponse();
      },
    });
    assert.equal(
      (await (await handler(request(body()))).json()).status,
      status,
    );
  }
  let reads = 0;
  const handler = createPreviewHandler({
    enabled: true,
    key: "fake",
    read: async () => (++reads === 2 ? null : projection()),
    rpc: async () => ({
      status: "ok",
      cached: true,
      image_base64: Buffer.from(png).toString("base64"),
    }),
    fetcher: async () => {
      renders++;
    },
  });
  assert.equal((await (await handler(request(body()))).json()).status, "stale");
  assert.equal(reads, 2);
  assert.equal(renders, 0);
});
test("public area successful generation completes a bounded claim, failed generation marks failure", async () => {
  for (const valid of [true, false]) {
    const finishes = [];
    const handler = createPreviewHandler({
      enabled: true,
      key: "fake",
      read: async () => projection(),
      rpc: async (name, args) => {
        if (name === "reserve_location_preview_v1") {
          assert.equal(args.p_cacheable, true);
          return { status: "ok", cached: false, token: item };
        }
        finishes.push(args);
      },
      fetcher: async () =>
        valid
          ? imageResponse()
          : new Response("bad", { headers: { "Content-Type": "image/png" } }),
    });
    const response = await handler(request(body()));
    assert.equal(finishes.length, 1);
    assert.equal(finishes[0].p_token, item);
    assert.equal(finishes[0].p_image_base64 != null, valid);
    if (!valid) assert.equal((await response.json()).status, "invalid_image");
  }
});
