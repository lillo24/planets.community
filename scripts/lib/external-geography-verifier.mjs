import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

export async function verifyExternalGeography(sql, service, guest) {
  const prefix = `actgeo01-${randomUUID().slice(0, 8)}`;
  const sources = [`${prefix}-a`, `${prefix}-b`];
  const origin = "https://geo.example.org";
  const point = (
    latitude = 46.0748,
    longitude = 11.1217,
    precision = "venue",
  ) => ({ latitude, longitude, precision, provenance_url: origin + "/data" });
  const record = (id, geometry, kind = "place") => ({
    upstream_id: id,
    title: id,
    kind,
    geometry,
    description: "Synthetic public fixture",
    canonical_url: origin + "/item",
    category: "sports",
    source_categories: [],
    discipline: "basketball",
    status: "scheduled",
    publishable: true,
    schedule:
      kind === "course"
        ? {
            season_start: new Date(Date.now() - 86400000)
              .toISOString()
              .slice(0, 10),
            season_end: new Date(Date.now() + 30 * 86400000)
              .toISOString()
              .slice(0, 10),
            timezone: "UTC",
          }
        : null,
    occurrences:
      kind === "event"
        ? [
            {
              kind: "timed",
              start: new Date(Date.now() + 86400000).toISOString(),
              end: null,
              timezone: "UTC",
            },
          ]
        : [],
  });
  async function rpc(name, params = {}, client = guest) {
    const { data, error } = await client.rpc(name, params);
    assert.equal(error, null, name);
    return data;
  }
  const list = (params = {}) => rpc("list_external_activities_v3", params);
  try {
    for (const source of sources)
      await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
        values(${source},'Synthetic geo source',${origin},true,true,'Synthetic only',${origin + "/license"})`;
    const sets = [
      [
        record("needle-one", point()),
        record("unmapped", null),
        record("approximate", point(46.0748, 11.1217, "locality")),
        record("event", point(), "event"),
        record("course", point(), "course"),
      ],
      [record("needle-two", point())],
    ];
    for (let i = 0; i < sources.length; i++) {
      const run = await rpc(
        "begin_external_activity_import",
        { p_source_id: sources[i] },
        service,
      );
      await rpc(
        "finish_external_activity_import",
        {
          p_run_id: run.run_id,
          p_state: "success",
          p_records: sets[i],
          p_fetched: sets[i].length,
        },
        service,
      );
    }
    const all = await list();
    const mapped = await list({ p_map_only: true });
    assert.equal(all.items.length, 6);
    assert.equal(mapped.items.length, 5);
    assert.deepEqual(
      mapped.items.map((x) => x.id).sort(),
      all.items
        .filter((x) => x.geometry)
        .map((x) => x.id)
        .sort(),
    );
    assert.ok(
      mapped.items.every((x) => x.map_identity === `external_activity:${x.id}`),
    );
    const radius = {
      mode: "radius",
      latitude: 46.0748,
      longitude: 11.1217,
      radius_m: 1000,
    };
    const scoped = await list({ p_map_only: true, p_area: radius });
    assert.equal(
      scoped.items.find((x) => x.title === "needle-one").distance_m,
      0,
    );
    assert.equal(
      scoped.items.find((x) => x.title === "approximate").distance_m,
      null,
    );
    assert.equal(
      (await list({ p_map_only: true, p_kind: "course" })).items.length,
      1,
    );
    const first = await list({ p_map_only: true, p_limit: 2 });
    let cursor = first.next_cursor;
    const ids = first.items.map((x) => x.id);
    while (cursor) {
      const next = await list({
        p_map_only: true,
        p_limit: 2,
        p_cursor: cursor,
      });
      assert.equal(next.as_of, first.as_of);
      ids.push(...next.items.map((x) => x.id));
      cursor = next.next_cursor;
      assert.ok(ids.length <= 5);
    }
    assert.equal(new Set(ids).size, 5);
    const tampered = await guest.rpc("list_external_activities_v3", {
      p_map_only: true,
      p_cursor: { ...first.next_cursor, id: randomUUID() },
    });
    assert.equal(tampered.error?.code, "22023");
    await sql`update private.external_activity_sources set enabled=false where source_id=${sources[1]}`;
    assert.equal((await list({ p_map_only: true })).items.length, 4);
    const obsolete = await guest.rpc("list_external_activities_v3", {
      p_map_only: true,
      p_cursor: first.next_cursor,
    });
    assert.equal(obsolete.error?.code, "22023");
    await sql`update private.external_activity_sources set enabled=true where source_id=${sources[1]}`;
    // Moderate canonical public-only catalogue for actual planner/candidate cap.
    // Each source stays below its 2000-record import budget; no native data.
    for (let i = 0; i < sources.length; i++) {
      const rows = Array.from({ length: 1200 }, (_, n) =>
        record(
          `volume-${n}`,
          point(46 + (n % 60) * 0.001, 11 + Math.floor(n / 60) * 0.001),
        ),
      );
      await sql`insert into private.external_activities(source_id,upstream_id,content,content_hash,last_observed_at)
        select ${sources[i]},x->>'upstream_id',x,md5(x::text),clock_timestamp() from jsonb_array_elements(${sql.json(rows)}) x`;
    }
    await sql`analyze private.external_activities`;
    const radiusPlan =
      await sql`explain (analyze,buffers,format json) select activity_id from private.external_activities
      where published_point is not null and extensions.st_dwithin(published_point,extensions.st_setsrid(extensions.st_makepoint(11.01,46.03),4326)::extensions.geography,100)`;
    const boundsPlan =
      await sql`explain (analyze,buffers,format json) select activity_id from private.external_activities
      where published_point is not null and (published_point::extensions.geometry) operator(extensions.&&) extensions.st_makeenvelope(11.009,46.029,11.011,46.031,4326)`;
    assert.ok(
      JSON.stringify(radiusPlan).includes("external_activities_geo_radius"),
      "Actual selective geodesic plan uses GiST",
    );
    assert.ok(
      JSON.stringify(boundsPlan).includes("external_activities_geo_bounds"),
      "Actual bounds plan uses expression GiST",
    );
    const tooBroad = await guest.rpc("list_external_activities_v3", {
      p_map_only: true,
    });
    assert.equal(
      tooBroad.error?.code,
      "54000",
      "Full matching spatial scope is capped before pagination",
    );
    assert.equal(
      (await list({ p_map_only: true, p_query: "needle-one" })).items.length,
      1,
      "Canonical filter narrows the complete catalogue before complexity cap",
    );
    console.log(
      `ACTGEO01: real HTTP list/map subset, mixed kinds, signed paging, precision/distance and disable PASS; 2406-row moderate catalogue uses both GiST indexes (${radiusPlan[0]["QUERY PLAN"][0]["Execution Time"]}ms radius / ${boundsPlan[0]["QUERY PLAN"][0]["Execution Time"]}ms bounds); full-scope complexity cap PASS.`,
    );
  } finally {
    await sql`delete from private.external_activities where source_id=any(${sources})`;
    await sql`delete from private.external_activity_runs where source_id=any(${sources})`;
    await sql`delete from private.external_activity_sources where source_id=any(${sources})`;
  }
}
