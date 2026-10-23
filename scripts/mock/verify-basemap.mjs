import assert from "node:assert/strict";
import postgres from "postgres";
import { basemapFixture } from "./basemap-fixture.mjs";

export async function verifyMockBasemap({
  normal,
  mock,
  sql,
  token,
  revokedToken,
  normalSentinel,
  equal,
}) {
  const db = postgres(normal.databaseUrl, { max: 8, onnotice: () => {} });
  const f = basemapFixture({ normal, mock });
  const tile = {
    operation: "basemap_tile_v2",
    z: 12,
    x: 2174,
    y: 1456,
    style: "osm-carto",
    version: 1,
    cache_only: false,
  };
  const send = (bearer = token, change = {}) =>
    f.mockHandler(
      new Request("http://localhost/functions/v1/mock-basemap", {
        method: "POST",
        headers: { Authorization: "Bearer " + bearer },
        body: JSON.stringify({ ...tile, ...change }),
      }),
    );
  const json = async (...args) => (await send(...args)).json();
  const units = async () =>
    (
      await db`select coalesce(sum(used),0)::int as units from private.location_provider_usage where scope='units:global'`
    )[0].units;
  const clear = () =>
    db`delete from private.location_provider_usage where scope like 'requests:%'`;
  const rpc = async (name, args) => {
    const r = await fetch(normal.apiUrl + "/rest/v1/rpc/" + name, {
      method: "POST",
      headers: {
        apikey: normal.serviceRoleKey,
        Authorization: "Bearer " + normal.serviceRoleKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
    });
    assert.equal(r.status, 200);
    return r.json();
  };
  try {
    await db`update private.location_provider_config set enabled=true,tiles_enabled=true,cache_license_approved=true,tile_cache_seconds=60,daily_units_limit=8000,actor_daily_units=8000,actor_minute_requests=120,global_minute_requests=600,failure_streak=0,blocked_until=null`;
    await db`update private.map_baseline_config set enabled=true,license_approved=true`;
    await db`update private.mock_basemap_config set enabled=true`;
    await db`delete from private.location_provider_usage`;
    equal(
      (await send(normalSentinel.session.access_token)).status,
      401,
      "MAPMOCK real normal issuer rejected despite overlapping UUID",
    );
    equal(
      (await send(token.slice(0, -10) + "forgedxxxx")).status,
      401,
      "MAPMOCK forged token rejected",
    );
    equal(
      (await send(revokedToken)).status,
      401,
      "MAPMOCK revoked genuine mock session rejected",
    );
    equal(await units(), 0, "MAPMOCK denied sessions reserve no units");
    const forbidden = await f.normalHandler(
      new Request("http://localhost/functions/v1/map-provider", {
        method: "POST",
        headers: { Authorization: "Bearer " + token },
        body: JSON.stringify({
          ...tile,
          expected_profile_id: normalSentinel.id,
        }),
      }),
    );
    equal(
      forbidden.status,
      401,
      "MAPMOCK genuine mock bearer cannot enter ordinary map-provider",
    );
    for (const path of [
      "/rest/v1/profiles?select=id",
      "/rest/v1/rpc/get_authorized_item_location_v1",
      "/storage/v1/object/authenticated/profile-photos/private.png",
    ]) {
      const r = await fetch(normal.apiUrl + path, {
        method: path.includes("/rpc/") ? "POST" : "GET",
        headers: {
          apikey: normal.publishableKey,
          Authorization: "Bearer " + token,
          "Content-Type": "application/json",
        },
        ...(path.includes("/rpc/") ? { body: "{}" } : {}),
      });
      equal(
        r.ok,
        false,
        "MAPMOCK mock JWT denied normal table/private reader/Storage",
      );
    }
    const identity = await fetch(
      mock.apiUrl + "/rest/v1/rpc/mock_basemap_identity_v1",
      {
        method: "POST",
        headers: {
          apikey: mock.publishableKey,
          Authorization: "Bearer " + token,
          "Content-Type": "application/json",
        },
        body: "{}",
      },
    );
    equal(identity.status, 200, "MAPMOCK live issued mock session proof");
    const scopes = await identity.json();
    equal(
      Object.keys(scopes).sort(),
      ["actor_scope", "client_scope"],
      "MAPMOCK only opaque budget scope crosses issuer boundary",
    );
    const mockArgs = {
      p_actor_scope: scopes.actor_scope,
      p_client_scope: scopes.client_scope,
      p_z: 12,
      p_x: 2174,
      p_y: 1456,
      p_cache_only: false,
    };
    const normalArgs = {
      p_actor: normalSentinel.id,
      p_z: 12,
      p_x: 2174,
      p_y: 1456,
      p_cache_only: false,
    };
    await db`delete from private.map_baseline_tiles`;
    const claims = await Promise.all(
      Array.from({ length: 16 }, (_, i) =>
        i % 2
          ? rpc("reserve_mock_basemap_tile_v1", mockArgs)
          : rpc("reserve_basemap_tile_v2", normalArgs),
      ),
    );
    equal(
      claims.filter((r) => r.status === "ok").length,
      1,
      "MAPMOCK mixed normal/mock cold race has one acquisition",
    );
    equal(
      claims.filter((r) => r.status === "pending").length,
      15,
      "MAPMOCK duplicate IO suppressed across realms",
    );
    equal(await units(), 1, "MAPMOCK mixed race has one shared global unit");
    await rpc("finish_basemap_tile_v2", {
      p_z: 12,
      p_x: 2174,
      p_y: 1456,
      p_token: claims.find((r) => r.token).token,
    });
    equal(await units(), 1, "MAPMOCK failed acquisition remains charged");
    await db`delete from private.map_baseline_tiles`;
    await clear();
    const frame = await json();
    equal(
      frame.status,
      "ok",
      "MAPMOCK real Auth/RPC/cache journey returns decodable fixture PNG",
    );
    equal(frame.source.z, 12, "MAPMOCK keeps source georeference");
    equal(f.counts.provider, 1, "MAPMOCK exactly one fixture upstream call");
    const hit = await json();
    equal(hit.expires_at, frame.expires_at, "MAPMOCK immutable cache expiry");
    equal(f.counts.provider, 1, "MAPMOCK replay/cache hit does no provider IO");
    await db`update private.mock_basemap_config set daily_units_limit=1`;
    const ancestor = await json(token, { z: 14, x: 8698, y: 5824 });
    equal(
      ancestor.source.z,
      12,
      "MAPMOCK mock subcap returns covering baseline",
    );
    equal(
      ancestor.budget_exhausted,
      true,
      "MAPMOCK subcap exposes honest reduced detail",
    );
    equal(
      (await json(token, { z: 14, x: 1000, y: 1000 })).status,
      "budget_exhausted",
      "MAPMOCK cold map outside baseline refuses at subcap",
    );
    await clear();
    await db`update private.mock_basemap_config set daily_units_limit=800`;
    await db`update private.mock_basemap_config set max_concurrent_tiles=2`;
    const beforeSlots = await units();
    const slots = await Promise.all(
      Array.from({ length: 12 }, (_, i) =>
        rpc("reserve_mock_basemap_tile_v1", {
          ...mockArgs,
          p_z: 18,
          p_x: 3300 + i,
          p_y: 3300,
        }),
      ),
    );
    equal(
      slots.filter((r) => r.status === "ok").length,
      2,
      "MAPMOCK server cold IO concurrency cap is atomic",
    );
    equal(
      slots.filter((r) => r.status === "pending").length,
      10,
      "MAPMOCK excess parallel mock IO waits without acquisition",
    );
    equal(
      await units(),
      beforeSlots + 2,
      "MAPMOCK concurrency refusals never spend unseen units",
    );
    await Promise.all(
      slots.map((r, i) =>
        r.token
          ? rpc("finish_mock_basemap_tile_v1", {
              p_z: 18,
              p_x: 3300 + i,
              p_y: 3300,
              p_token: r.token,
            })
          : null,
      ),
    );
    equal(
      (await db`select count(*)::int as n from private.mock_basemap_claims`)[0]
        .n,
      0,
      "MAPMOCK completion releases every acquired IO slot",
    );
    await db`update private.mock_basemap_config set max_concurrent_tiles=6`;
    await clear();
    await db`update private.location_provider_config set daily_units_limit=8`;
    await db`delete from private.location_provider_usage where scope like 'units:%'`;
    // Put both consumers one unit below their own ceilings, then race different
    // uncached XYZs through independent DB connections. The global lock wins.
    await db`insert into private.location_provider_usage values('units:global',date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC',7),('units:mock',date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC',1)`;
    const final = await Promise.all(
      Array.from({ length: 12 }, (_, i) =>
        i % 2
          ? rpc("reserve_mock_basemap_tile_v1", {
              ...mockArgs,
              p_z: 18,
              p_x: 3100 + i,
              p_y: 3100,
            })
          : rpc("reserve_basemap_tile_v2", {
              ...normalArgs,
              p_z: 18,
              p_x: 3100 + i,
              p_y: 3100,
            }),
      ),
    );
    equal(
      final.filter((r) => r.status === "ok").length,
      1,
      "MAPMOCK mock plus normal global final-unit race has one winner",
    );
    equal(
      final.filter((r) => r.status === "budget_exhausted").length,
      11,
      "MAPMOCK every other cold request is capped",
    );
    equal(
      await units(),
      8,
      "MAPMOCK single global daily ceiling never exceeded",
    );
    await clear();
    await db`update private.map_baseline_tiles set expires_at=statement_timestamp()-interval '1 second'`;
    equal(
      (await json(token, { z: 14, x: 8698, y: 5824, cache_only: true })).status,
      "cache_miss",
      "MAPMOCK expired Trento cannot masquerade as fallback",
    );
    // Revoke real mock entitlement while the controlled provider is in flight.
    // The completed public acquisition stays accounted and reusable, but must
    // neither reach the retired persona nor poison the shared failure circuit.
    await db`update private.location_provider_config set daily_units_limit=8000,failure_streak=4,blocked_until=null`;
    await db`delete from private.location_provider_usage`;
    const userResponse = await fetch(mock.apiUrl + "/auth/v1/user", {
      headers: {
        apikey: mock.publishableKey,
        Authorization: "Bearer " + token,
      },
    });
    assert.equal(userResponse.status, 200);
    const user = await userResponse.json();
    const retiring = basemapFixture({
      normal,
      mock,
      afterProvider: () =>
        sql`update mock_control.personas set available=false where user_id=${user.id}::uuid`,
    });
    const retiredTile = { ...tile, z: 18, x: 4000, y: 4000 };
    try {
      const retired = await (
        await retiring.mockHandler(
          new Request("http://localhost/functions/v1/mock-basemap", {
            method: "POST",
            headers: { Authorization: "Bearer " + token },
            body: JSON.stringify(retiredTile),
          }),
        )
      ).json();
      equal(
        retired.status,
        "unauthorized",
        "MAPMOCK retirement withholds late pixels",
      );
      equal(
        retired.image_base64,
        undefined,
        "MAPMOCK revoked response contains no image",
      );
      equal(
        await units(),
        1,
        "MAPMOCK completed retired acquisition remains charged once",
      );
      const [circuit] =
        await db`select failure_streak,blocked_until from private.location_provider_config`;
      equal(
        circuit.failure_streak,
        0,
        "MAPMOCK successful PNG is not an Auth-induced provider failure",
      );
      equal(
        circuit.blocked_until,
        null,
        "MAPMOCK retirement cannot trip the shared provider circuit",
      );
      const reused = await (
        await retiring.normalHandler(
          new Request("http://localhost/functions/v1/map-provider", {
            method: "POST",
            headers: {
              Authorization: "Bearer " + normalSentinel.session.access_token,
            },
            body: JSON.stringify({
              ...retiredTile,
              expected_profile_id: normalSentinel.id,
            }),
          }),
        )
      ).json();
      equal(
        reused.cached,
        true,
        "MAPMOCK completed public pixels remain reusable by normal Auth",
      );
      equal(
        retiring.counts.provider,
        1,
        "MAPMOCK retired acquisition reuse has no duplicate provider IO",
      );
    } finally {
      await sql`update mock_control.personas set available=true where user_id=${user.id}::uuid`;
    }
    await db`update private.mock_basemap_config set enabled=false`;
    equal(
      (await json()).status,
      "disabled",
      "MAPMOCK mock kill switch blocks cached and cold calls",
    );
    await db`update private.mock_basemap_config set enabled=true`;
    await db`update private.location_provider_config set enabled=false`;
    equal(
      (await json()).status,
      "disabled",
      "MAPMOCK shared master kills mock tiles",
    );
    // Leave a clean, explicitly synthetic provider state for native fixtures.
    await db`update private.location_provider_config set enabled=true,daily_units_limit=8000`;
    await db`delete from private.location_provider_usage`;
    await db`delete from private.map_provider_cache where kind='tile'`;
    await db`delete from private.map_baseline_tiles`;
    console.log(
      "MAPMOCK01 two-realm proof: genuine independent Auth, revoked JWT denial, shared cold-cache race, subcap, final global unit, expiry and kills passed; pixels are fixtures.",
    );
  } finally {
    await db.end();
  }
}
