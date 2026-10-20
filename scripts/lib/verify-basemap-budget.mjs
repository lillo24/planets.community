import { createHash } from "node:crypto";
import { createMapProviderHandler } from "../../supabase/functions/map-provider/handler.mjs";
import { mapTileFixture } from "./map-provider-fixture.mjs";

// Called only by the existing disposable-loopback real-Auth location verifier.
export async function verifyBasemapBudget({
  db,
  owner,
  peer,
  server,
  rpc,
  denied,
  check,
}) {
  const original = (
    await db`select * from private.location_provider_config where singleton`
  )[0];
  const baseline = (
    await db`select * from private.map_baseline_config where singleton`
  )[0];
  const priorTiles = await db`select * from private.map_baseline_tiles`;
  const priorUsage = await db`select * from private.location_provider_usage`;
  const ids = [];
  for (let x = 2173; x <= 2175; x++)
    for (let y = 1454; y <= 1457; y++) ids.push({ z: 12, x, y });
  const exact = { z: 18, x: 2001, y: 2001 };
  const exactKey = createHash("sha256")
    .update(`tile:v1:osm-carto:${exact.z}:${exact.x}:${exact.y}`)
    .digest("hex");
  const raceKeys = Array.from({ length: 12 }, (_, i) =>
    createHash("sha256")
      .update(`tile:v1:osm-carto:18:${2100 + i}:2100`)
      .digest("hex"),
  );
  const priorExact =
    await db`select * from private.map_provider_cache where cache_key=${exactKey}`;
  const regularKeys = ids.map((id) =>
    createHash("sha256")
      .update(`tile:v1:osm-carto:${id.z}:${id.x}:${id.y}`)
      .digest("hex"),
  );
  const priorRegular =
    await db`select * from private.map_provider_cache where cache_key=any(${regularKeys})`;
  const units = async () =>
    Number(
      (
        await db`select coalesce(sum(used),0) as n from private.location_provider_usage where scope='units:global'`
      )[0].n,
    );
  const clearRates = () =>
    db`delete from private.location_provider_usage where scope like 'requests:%'`;
  let upstream = 0,
    authCalls = 0,
    rpcCalls = 0,
    edgeCalls = 0;
  const tokens = [
    await owner.client.accessToken(),
    await peer.client.accessToken(),
  ];
  const handler = createMapProviderHandler({
    tilesEnabled: true,
    key: "synthetic-MAP-COST01-key",
    authenticate: async (header) => {
      authCalls++;
      if (!header?.startsWith("Bearer ")) return null;
      const { data, error } = await server.auth.getUser(header.slice(7));
      return error ? null : data.user.id;
    },
    rpc: (name, args) => {
      rpcCalls++;
      return rpc(server, name, args);
    },
    fetcher: async () => {
      upstream++;
      return new Response(mapTileFixture(), {
        headers: { "content-type": "image/png" },
      });
    },
  });
  const send = async (coords, index = 0, cacheOnly = false) => {
    edgeCalls++;
    const result = await handler(
      new Request("https://fixture.invalid/map-provider", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${tokens[index]}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          operation: "basemap_tile_v2",
          expected_profile_id: index ? peer.id : owner.id,
          ...coords,
          style: "osm-carto",
          version: 1,
          cache_only: cacheOnly,
        }),
      }),
    );
    return result.json();
  };
  try {
    for (const client of [owner.client, peer.client]) {
      await denied(
        client,
        "reserve_basemap_tile_v2",
        {
          p_actor: owner.id,
          p_z: 12,
          p_x: 2174,
          p_y: 1456,
          p_cache_only: true,
        },
        "42501",
      );
      await denied(
        client,
        "finish_basemap_tile_v2",
        { p_z: 12, p_x: 2174, p_y: 1456, p_token: owner.id },
        "42501",
      );
      for (const table of ["map_baseline_config", "map_baseline_tiles"]) {
        const { error } = await client
          .schema("private")
          .from(table)
          .select("*");
        check(Boolean(error), `MAP-COST no direct ${table}`);
      }
    }
    await db`delete from private.map_baseline_tiles`;
    await db`delete from private.map_provider_cache where cache_key=${exactKey}`;
    await db`delete from private.location_provider_usage`;
    await db`update private.location_provider_config set enabled=true,tiles_enabled=true,cache_license_approved=true,tile_cache_seconds=60,daily_units_limit=8000,actor_daily_units=8000,actor_minute_requests=120,global_minute_requests=600,failure_streak=0,blocked_until=null where singleton`;
    await db`update private.map_baseline_config set enabled=true,license_approved=true,retention_seconds=604800 where singleton`;
    // Measured v1 control with the identical identities/users. Expiring each
    // previous batch models sessions spaced beyond its original 60-second TTL.
    for (let session = 0; session < 100; session++) {
      await clearRates();
      await db`update private.map_provider_cache set expires_at=statement_timestamp()-interval '1 second' where cache_key=any(${regularKeys})`;
      const responses = await Promise.all(
        ids.map((id) => {
          edgeCalls++;
          return handler(
            new Request("https://fixture.invalid/map-provider", {
              method: "POST",
              headers: {
                Authorization: `Bearer ${tokens[session % 2]}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                operation: "tile",
                expected_profile_id: session % 2 ? peer.id : owner.id,
                ...id,
                style: "osm-carto",
                version: 1,
              }),
            }),
          );
        }),
      );
      check(
        responses.every(
          (r) => r.headers.get("content-type") === "application/octet-stream",
        ),
        "MAP-COST original-policy control returns bounded binary tiles",
      );
      await Promise.all(responses.map((r) => r.arrayBuffer()));
    }
    const control = {
      upstream,
      units: await units(),
      edgeRequests: edgeCalls,
      authRequests: authCalls,
      serviceRPCs: rpcCalls,
    };
    check(
      control.upstream === 1200 && control.units === 1200,
      "MAP-COST measured original 100-session policy has 1200 misses / 300 credits",
    );
    await db`delete from private.map_provider_cache where cache_key=any(${regularKeys})`;
    await db`delete from private.location_provider_usage`;
    upstream = 0;
    authCalls = 0;
    rpcCalls = 0;
    edgeCalls = 0;
    const cold = await Promise.all(ids.map((id) => send(id)));
    check(
      cold.every((r) => r.status === "ok" && r.source.z === 12),
      "MAP-COST finite 12-tile foreground fill",
    );
    check(
      upstream === 12 && (await units()) === 12,
      "MAP-COST measured cold fill is 12 misses / 12 units / 3 credits",
    );
    const expiry =
      await db`select x,y,expires_at from private.map_baseline_tiles order by x,y`;
    // Explicit synthetic aging, beyond the previous 60-second policy. Each
    // simulated session gets a new request-rate minute; credit counters stay.
    await db`update private.map_baseline_tiles set acquired_at=acquired_at-interval '2 minutes',expires_at=expires_at-interval '2 minutes'`;
    const aged =
      await db`select x,y,expires_at from private.map_baseline_tiles order by x,y`;
    const before = {
      upstream,
      units: await units(),
      edgeCalls,
      authCalls,
      rpcCalls,
    };
    for (let session = 0; session < 100; session++) {
      await clearRates();
      const results = await Promise.all(ids.map((id) => send(id, session % 2)));
      check(
        results.every((r) => r.status === "ok" && r.cached),
        "MAP-COST aged shared baseline session",
      );
    }
    const after = {
      upstream,
      units: await units(),
      edgeCalls,
      authCalls,
      rpcCalls,
    };
    check(
      after.upstream === before.upstream && after.units === before.units,
      "MAP-COST 100 aged sessions add zero provider IO / units",
    );
    check(
      after.edgeCalls - before.edgeCalls === 1200 &&
        after.rpcCalls - before.rpcCalls === 1200,
      "MAP-COST backend traffic is counted separately from credits",
    );
    const retained = (
      await db`select count(*)::int as tiles,sum(octet_length(image))::int as bytes from private.map_baseline_tiles`
    )[0];
    const unchanged =
      await db`select x,y,expires_at from private.map_baseline_tiles order by x,y`;
    check(
      JSON.stringify(aged) === JSON.stringify(unchanged) &&
        expiry.length === 12,
      "MAP-COST reads preserve aged acquisition/expiry identity",
    );
    await clearRates();
    await send(exact);
    const beforeRace = await units();
    await db`update private.location_provider_config set daily_units_limit=${beforeRace + 1} where singleton`;
    const race = await Promise.all(
      Array.from({ length: 12 }, (_, i) =>
        rpc(server, "reserve_basemap_tile_v2", {
          p_actor: owner.id,
          p_z: 18,
          p_x: 2100 + i,
          p_y: 2100,
          p_cache_only: false,
        }),
      ),
    );
    check(
      race.filter((r) => r.status === "ok").length === 1 &&
        race.filter((r) => r.status === "budget_exhausted").length === 11,
      "MAP-COST simultaneous final quarter-unit has one winner",
    );
    check(
      (await units()) === beforeRace + 1,
      "MAP-COST concurrent misses cannot exceed atomic ceiling",
    );
    const cap = await units();
    await db`update private.location_provider_config set daily_units_limit=${cap} where singleton`;
    const beforeCap = { upstream, units: await units() };
    check(
      (await send(exact)).source.z === 18,
      "MAP-COST cached exact tile still wins at global ceiling",
    );
    const povo = { z: 14, x: 8698, y: 5824 };
    const fallback = await send(povo);
    check(
      fallback.status === "ok" &&
        fallback.source.z === 12 &&
        fallback.source.x === 2174 &&
        fallback.budget_exhausted,
      "MAP-COST zero-credit Povo returns true covering baseline",
    );
    check(
      fallback.retry_after_seconds > 0 && fallback.retry_after_seconds <= 86400,
      "MAP-COST server UTC reset contract",
    );
    const fresh = await send(povo, 1, true);
    check(
      fresh.status === "ok" && fresh.cached && fresh.source.z === 12,
      "MAP-COST first-time actor reads stored baseline cache-only",
    );
    check(
      (await send({ z: 14, x: 1000, y: 1000 }, 1, true)).status ===
        "cache_miss",
      "MAP-COST missing geography remains missing",
    );
    check(
      beforeCap.upstream === upstream && beforeCap.units === (await units()),
      "MAP-COST fallback/cache-only produces zero upstream IO or reserved units",
    );
    await db`update private.location_provider_config set daily_units_limit=8000,actor_daily_units=1 where singleton`;
    check(
      (await send(povo)).budget_exhausted === true,
      "MAP-COST actor exhaustion uses same fallback without raising ceiling",
    );
    await db`update private.map_baseline_tiles set expires_at=statement_timestamp()-interval '1 second' where x=2174 and y=1456`;
    check(
      (await send(povo, 1, true)).status === "cache_miss",
      "MAP-COST expired base is not refetched cache-only",
    );
    await db`update private.location_provider_config set enabled=false where singleton`;
    check(
      (await send(ids[0], 1, true)).status === "disabled",
      "MAP-COST master kills cached base",
    );
    console.log(
      `MAP-COST01 synthetic workload: ${JSON.stringify({ control, cold: { uniqueMisses: 12, reservedUnits: 12, credits: 3 }, sessions: 100, repeat: { upstream: after.upstream - before.upstream, units: after.units - before.units, edgeRequests: after.edgeCalls - before.edgeCalls, authRequests: after.authCalls - before.authCalls, serviceRPCs: after.rpcCalls - before.rpcCalls }, retained })}`,
    );
  } finally {
    await db`delete from private.map_provider_cache where cache_key=any(${regularKeys})`;
    if (priorRegular.length)
      await db`insert into private.map_provider_cache ${db(priorRegular)}`;
    await db`delete from private.map_provider_cache where cache_key=any(${raceKeys})`;
    await db`delete from private.map_baseline_tiles`;
    if (priorTiles.length)
      await db`insert into private.map_baseline_tiles ${db(priorTiles)}`;
    await db`delete from private.map_provider_cache where cache_key=${exactKey}`;
    if (priorExact.length)
      await db`insert into private.map_provider_cache ${db(priorExact)}`;
    await db`delete from private.location_provider_usage`;
    if (priorUsage.length)
      await db`insert into private.location_provider_usage ${db(priorUsage)}`;
    await db`update private.map_baseline_config c set enabled=s.enabled,license_approved=s.license_approved,retention_seconds=s.retention_seconds,revision=s.revision from jsonb_populate_record(null::private.map_baseline_config,${db.json(baseline)}::jsonb) s where c.singleton`;
    await db`update private.location_provider_config c set enabled=s.enabled,daily_units_limit=s.daily_units_limit,actor_daily_units=s.actor_daily_units,actor_minute_requests=s.actor_minute_requests,global_minute_requests=s.global_minute_requests,center_enabled=s.center_enabled,tiles_enabled=s.tiles_enabled,cache_license_approved=s.cache_license_approved,tile_cache_seconds=s.tile_cache_seconds,failure_streak=s.failure_streak,blocked_until=s.blocked_until from jsonb_populate_record(null::private.location_provider_config,${db.json(original)}::jsonb) s where c.singleton`;
  }
}
