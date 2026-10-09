import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { createMapProviderHandler } from "../../supabase/functions/map-provider/handler.mjs";
import { mapCenterFixture, mapTileFixture } from "./map-provider-fixture.mjs";

// Reached only through the existing explicit disposable/loopback verifier.
export async function verifyMapDiscoveryProvider({
  db,
  owner,
  peer,
  server,
  anonymous,
  rpc,
  denied,
  check,
}) {
  const original = (
    await db`select * from private.location_provider_config where singleton`
  )[0];
  const keys = [];
  const key = () => {
    const value = createHash("sha256")
      .update(`MAP05 REST ${randomUUID()}`)
      .digest("hex");
    keys.push(value);
    return value;
  };
  const reserve = (cacheKey, actor = owner.id, kind = "tile") =>
    rpc(server, "reserve_map_provider_v1", {
      p_actor: actor,
      p_kind: kind,
      p_cache_key: cacheKey,
    });
  const units = async () =>
    Number(
      (
        await db`select coalesce(sum(used),0) as used from private.location_provider_usage where scope='units:global' and bucket=date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC'`
      )[0].used,
    );
  try {
    await db`update private.location_provider_config set enabled=true,daily_units_limit=8000,actor_daily_units=8000,center_enabled=true,tiles_enabled=true,cache_license_approved=true,tile_cache_seconds=600,failure_streak=0,blocked_until=null where singleton`;
    const boundary = [
      [
        "reserve_map_provider_v1",
        { p_actor: owner.id, p_kind: "tile", p_cache_key: key() },
      ],
      ["finish_map_provider_v1", { p_cache_key: key(), p_token: randomUUID() }],
      [
        "resolve_map_center_v1",
        { p_actor: owner.id, p_suggestion: randomUUID() },
      ],
    ];
    for (const client of [anonymous, owner.client, peer.client]) {
      for (const [name, args] of boundary)
        await denied(client, name, args, "42501");
      for (const table of [
        "location_provider_config",
        "location_provider_usage",
        "map_provider_cache",
      ]) {
        const { error } = await client
          .schema("private")
          .from(table)
          .select("*");
        check(Boolean(error), `MAP05 no REST raw ${table}`);
      }
    }
    check(
      (await reserve(key(), null)).status === "guest_disabled",
      "MAP05 server rejects anonymous paid lookup",
    );

    const before = await units();
    await db`update private.location_provider_config set daily_units_limit=${before + 1} where singleton`;
    const race = await Promise.all(
      Array.from({ length: 12 }, () => reserve(key())),
    );
    check(
      race.filter((r) => r.status === "ok").length === 1,
      "MAP05 concurrent last quarter-unit has exactly one winner",
    );
    check(
      race.filter((r) => r.status === "budget_exhausted").length === 11,
      "MAP05 other concurrent requests fail closed",
    );
    check(
      (await units()) === before + 1,
      "MAP05 no fractional ceiling overshoot",
    );
    await db`update private.location_provider_config set daily_units_limit=8000 where singleton`;

    const shared = key();
    const beforeDedupe = await units();
    const duplicates = await Promise.all(
      Array.from({ length: 10 }, () => reserve(shared)),
    );
    check(
      duplicates.filter((r) => r.status === "ok").length === 1 &&
        duplicates.filter((r) => r.status === "pending").length === 9,
      "MAP05 concurrent pending requests deduplicate",
    );
    check(
      (await units()) === beforeDedupe + 1,
      "MAP05 dedup reserves one tile only",
    );
    const claim = duplicates.find((r) => r.status === "ok");
    const finished = await rpc(server, "finish_map_provider_v1", {
      p_cache_key: shared,
      p_token: claim.token,
      p_image_base64: mapTileFixture().toString("base64"),
    });
    check(
      finished.status === "ok",
      "MAP05 real REST service can finish validated PNG",
    );
    const cached = await reserve(shared, peer.id);
    check(
      cached.cached === true &&
        Buffer.from(cached.image_base64.replaceAll(/\s/g, ""), "base64").equals(
          mapTileFixture(),
        ),
      "MAP05 public tile cache reusable across verified actors",
    );
    check(
      (await units()) === beforeDedupe + 1,
      "MAP05 cache hit charges zero upstream units",
    );
    await db`update private.map_provider_cache set expires_at=statement_timestamp()-interval '1 second' where cache_key=${shared}`;
    check(
      (await reserve(shared)).cached === false,
      "MAP05 expired cache cannot masquerade as ready",
    );

    // The local helper supplies a token-bound data client, not an Auth session.
    const accessToken = await owner.client.accessToken();
    assert.ok(accessToken);
    let upstreamCalls = 0;
    let disableOnFetch = false;
    const handler = createMapProviderHandler({
      centersEnabled: true,
      tilesEnabled: true,
      key: "synthetic-MAP05-key",
      authenticate: async (header) => {
        if (!header?.startsWith("Bearer ")) return null;
        const { data, error } = await server.auth.getUser(header.slice(7));
        return error ? null : data.user.id;
      },
      rpc: (name, args) => {
        if (args.p_cache_key) keys.push(args.p_cache_key);
        return rpc(server, name, args);
      },
      fetcher: async (url, options) => {
        upstreamCalls++;
        check(
          !options.headers?.Authorization &&
            url.origin === "https://api.geoapify.com",
          "MAP05 no caller JWT forwarded upstream",
        );
        if (disableOnFetch)
          await db`update private.location_provider_config set enabled=false where singleton`;
        return url.pathname.includes("/tile/")
          ? new Response(mapTileFixture(), {
              headers: { "Content-Type": "image/png" },
            })
          : Response.json(mapCenterFixture);
      },
    });
    const send = (body, authorization = `Bearer ${accessToken}`) =>
      handler(
        new Request("https://fixture.invalid/map-provider", {
          method: "POST",
          headers: {
            Authorization: authorization,
            "Content-Type": "application/json",
            "X-Forwarded-For": "127.0.0.1",
          },
          body: JSON.stringify(body),
        }),
      );
    const search = {
      operation: "search",
      expected_profile_id: owner.id,
      query: "Synthetic REST Bolzano",
      language: "it",
    };
    check(
      (await send(search, "Bearer forged-actor")).status === 401,
      "MAP05 forged JWT does not use paid service",
    );
    check(
      upstreamCalls === 0,
      "MAP05 untrusted source performs no provider fetch",
    );
    check(
      (await send({ ...search, expected_profile_id: peer.id })).status === 403,
      "MAP05 actual JWT cannot assert another actor",
    );
    const result = await (await send(search)).json();
    check(
      result.status === "ok" &&
        result.suggestions.length === 1 &&
        upstreamCalls === 1,
      "MAP05 authenticated handler uses service REST and synthetic center adapter",
    );
    check(
      !/MUST_NOT_SURVIVE|latitude|longitude|provider_id|apiKey|token/.test(
        JSON.stringify(result),
      ),
      "MAP05 suggestions are minimal transient choices",
    );
    check(
      (await (await send(search)).json()).status === "ok" &&
        upstreamCalls === 1,
      "MAP05 repeated center query cache avoids provider IO",
    );
    const suggestion = result.suggestions[0].id;
    const resolved = await (
      await send({
        operation: "resolve",
        expected_profile_id: owner.id,
        suggestion_id: suggestion,
      })
    ).json();
    check(
      resolved.status === "ok" && resolved.center.latitude === 46.4983,
      "MAP05 explicit selected center resolved with real actor",
    );
    check(
      (
        await rpc(server, "resolve_map_center_v1", {
          p_actor: peer.id,
          p_suggestion: suggestion,
        })
      ).status === "expired",
      "MAP05 another actor cannot resolve a choice",
    );
    await db`update private.map_provider_cache set expires_at=statement_timestamp()-interval '1 second' where kind='center' and actor=${owner.id} and cache_key=any(${keys})`;
    check(
      (
        await (
          await send({
            operation: "resolve",
            expected_profile_id: owner.id,
            suggestion_id: suggestion,
          })
        ).json()
      ).status === "expired",
      "MAP05 expired selection is explicit through handler",
    );
    disableOnFetch = true;
    const tileResponse = await send({
      operation: "tile",
      expected_profile_id: owner.id,
      z: 12,
      x: 2174,
      y: 1456,
      style: "osm-carto",
      version: 1,
    });
    check(
      (await tileResponse.json()).status === "disabled",
      "MAP05 shutdown during fetch releases no bytes",
    );
    check(
      (await reserve(shared)).status === "disabled",
      "MAP05 account kill switch blocks existing ready or pending cache",
    );
  } finally {
    await db`delete from private.map_provider_cache where cache_key=any(${keys})`;
    await db`update private.location_provider_config c set enabled=s.enabled,daily_units_limit=s.daily_units_limit,actor_daily_units=s.actor_daily_units,actor_minute_requests=s.actor_minute_requests,global_minute_requests=s.global_minute_requests,center_enabled=s.center_enabled,tiles_enabled=s.tiles_enabled,cache_license_approved=s.cache_license_approved,tile_cache_seconds=s.tile_cache_seconds,failure_streak=s.failure_streak,blocked_until=s.blocked_until from jsonb_populate_record(null::private.location_provider_config,${db.json(original)}::jsonb) s where c.singleton`;
  }
}
