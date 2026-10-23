// Fixture pixels only. Both Auth issuers, session revocation, RPCs, locks, caches
// and ledgers are real disposable Supabase services. No hosted provider calls.
import assert from "node:assert/strict";
import {
  createRuntime,
  MOCK_ORIGIN,
  NORMAL_ORIGIN,
} from "../../supabase/functions/mock-basemap/runtime.mjs";
import { createMapProviderHandler } from "../../supabase/functions/map-provider/handler.mjs";
import { mapTileFixture } from "../lib/map-provider-fixture.mjs";

export function basemapFixture({ normal, mock, afterProvider }) {
  const counts = { provider: 0, mock: 0, normal: 0, auth: 0, rpc: 0 };
  const fetcher = async (url, init) => {
    const value = new URL(url);
    if (value.origin === "https://api.geoapify.com") {
      assert.match(
        value.pathname,
        /^\/v1\/tile\/osm-carto\/\d+\/\d+\/\d+\.png$/,
      );
      assert.equal(init.redirect, "error");
      counts.provider++;
      await afterProvider?.();
      return new Response(mapTileFixture(), {
        headers: { "content-type": "image/png" },
      });
    }
    assert.ok([MOCK_ORIGIN, NORMAL_ORIGIN].includes(value.origin));
    assert.ok(
      value.pathname === "/auth/v1/user" ||
        /^\/rest\/v1\/rpc\/(?:mock_basemap_identity_v1|reserve_mock_basemap_tile_v1|finish_mock_basemap_tile_v1|reserve_basemap_tile_v2|finish_basemap_tile_v2)$/.test(
          value.pathname,
        ),
    );
    if (value.pathname === "/auth/v1/user") counts.auth++;
    else counts.rpc++;
    const replacement =
      value.origin === MOCK_ORIGIN ? mock.apiUrl : normal.apiUrl;
    return fetch(url.toString().replace(value.origin, replacement), init);
  };
  const mockHandler = createRuntime({
    enabled: true,
    normalOrigin: NORMAL_ORIGIN,
    mockPublicKey: mock.publishableKey,
    service: normal.serviceRoleKey,
    key: "fixture-no-provider-credential",
    fetcher,
  });
  const normalHandler = createMapProviderHandler({
    tilesEnabled: true,
    key: "fixture-no-provider-credential",
    authenticate: async (header) => {
      const r = await fetch(normal.apiUrl + "/auth/v1/user", {
        headers: { apikey: normal.publishableKey, Authorization: header },
        redirect: "error",
      });
      return r.ok ? (await r.json()).id : null;
    },
    rpc: async (name, args) => {
      const r = await fetcher(NORMAL_ORIGIN + "/rest/v1/rpc/" + name, {
        method: "POST",
        headers: {
          apikey: normal.serviceRoleKey,
          Authorization: "Bearer " + normal.serviceRoleKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        redirect: "error",
      });
      assert.equal(r.status, 200);
      return r.json();
    },
    fetcher,
  });
  return {
    counts,
    mockHandler: (request) => {
      counts.mock++;
      return mockHandler(request);
    },
    normalHandler: (request) => {
      counts.normal++;
      return normalHandler(request);
    },
  };
}
