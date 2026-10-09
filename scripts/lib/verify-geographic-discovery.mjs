import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";

// Called only from the existing explicitly disposable, loopback location verifier.
export async function verifyGeographicDiscovery({
  db,
  owner,
  peer,
  anonymous,
  rpc,
  denied,
  check,
}) {
  const test = await readFile(
    new URL(
      "../../supabase/tests/123_geographic_discovery.test.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const fixture = test
    .split("-- MAP04 fixture begin")[1]
    .split("-- MAP04 fixture end")[0]
    .replaceAll("a9410000-0000-4000-8000-000000000001", owner.id)
    .replaceAll("a9410000-0000-4000-8000-000000000002", peer.id);
  await db.begin((sql) => sql.unsafe(fixture).simple());
  const query = {
    mode: "radius",
    latitude: 46.07,
    longitude: 11.12,
    radius_m: 5000,
  };
  const search = (client, q = query, cursor = null, limit = 20) =>
    rpc(client, "search_public_geography_v1", {
      p_query: q,
      p_limit: limit,
      p_cursor: cursor,
    });
  const first = await search(anonymous);
  const frozen = { ...query, reference_time: first.reference_time };
  check(
    first.items.length === 7 && !first.has_more && first.next_cursor === null,
    "MAP04 honest bounded public page",
  );
  assert.deepEqual(await search(peer.client, frozen), first);
  check(true, "MAP04 actual authenticated member JWT equals anonymous");
  assert.deepEqual(await search(owner.client, frozen), first);
  check(true, "MAP04 manager gets no extra geographic precision");
  const fields = [
    "kind",
    "item_id",
    "latitude",
    "longitude",
    "precision",
    "is_approximate",
    "match_precision",
    "title",
    "cover_object_path",
    "public_location_label",
    "starts_at",
    "ends_at",
    "event_timezone",
    "derived_status",
    "listing_mode",
  ].sort();
  function inspect(page) {
    check(
      !/PRIVATE|selected_|exact_location|receipt|email|membership|participant|distance|total_count/.test(
        JSON.stringify(page),
      ),
      "MAP04 recursive private payload scan",
    );
    for (const row of page.items) {
      assert.deepEqual(Object.keys(row).sort(), fields);
      check(
        row.kind === "resource" ||
          (row.precision === "locality" &&
            row.is_approximate &&
            row.match_precision === "locality_reference"),
        "MAP04 marker precision allowlist",
      );
      check(
        row.latitude === 46.07 && row.longitude === 11.12,
        "MAP04 canonical public coordinates only",
      );
    }
    check(
      page.attribution.geoapify_url === "https://www.geoapify.com/" &&
        page.attribution.openstreetmap_url ===
          "https://www.openstreetmap.org/copyright",
      "MAP04 retained label credits",
    );
  }
  inspect(first);
  for (const client of [anonymous, peer.client]) {
    const { error, data } = await client
      .from("proposals")
      .select("approximate_location,selected_public_place")
      .eq("id", "a9420000-0000-4000-8000-000000000001");
    check(
      error
        ? ["42501", "PGRST205"].includes(error.code)
        : Array.isArray(data) && data.length === 0,
      "MAP04 existing owner RLS denies unrelated/member raw geometry",
    );
  }
  const all = [];
  let cursor = null,
    pages = 0;
  do {
    const page = await search(anonymous, frozen, cursor, 2);
    all.push(...page.items);
    cursor = page.next_cursor;
    pages++;
    if (!page.has_more) break;
    assert.ok(pages < 10, "MAP04 cursor terminates");
  } while (true);
  assert.deepEqual(all, first.items);
  check(
    pages === 4,
    "MAP04 tied mixed-kind pages have no duplication/omission",
  );
  const c = (await search(anonymous, frozen, null, 2)).next_cursor;
  await denied(
    anonymous,
    "search_public_geography_v1",
    { p_query: { ...frozen, radius_m: 2000 }, p_cursor: c, p_limit: 2 },
    "22023",
  );
  await denied(
    peer.client,
    "search_public_geography_v1",
    {
      p_query: { ...frozen, resource_mode: "exchange" },
      p_cursor: c,
      p_limit: 2,
    },
    "22023",
  );
  const resource = await search(anonymous, {
    ...frozen,
    kinds: ["resource"],
    resource_mode: "exchange",
  });
  check(
    resource.items.length === 1 &&
      resource.items[0].listing_mode === "exchange",
    "MAP04 Resource mode",
  );
  const skill = (
    await db.unsafe(
      "select skill_id from public.proposal_skills where proposal_id='a9420000-0000-4000-8000-000000000001'",
    )
  )[0].skill_id;
  check(
    (
      await search(anonymous, {
        ...frozen,
        kinds: ["one_time"],
        proposal_skill_ids: [skill],
      })
    ).items.length === 1,
    "MAP04 real skill filter",
  );
  check(
    (
      await search(anonymous, {
        ...frozen,
        proposal_keyword: "Garden 1",
        resource_keyword: "Resource 2",
      })
    ).items.length === 3,
    "MAP04 explicit family keyword scope",
  );
  const bbox = {
    mode: "bounds",
    south: 46.07,
    north: 46.08,
    west: 11.12,
    east: 11.13,
    reference_time: first.reference_time,
  };
  assert.deepEqual((await search(anonymous, bbox)).items, first.items);
  check(true, "MAP04 real REST inclusive viewport boundaries");
  const probes = [];
  for (let i = 0; i < 8; i++) {
    probes.push({
      ...frozen,
      latitude: -33.86 + i / 100000,
      longitude: 151.21,
      radius_m: 1,
    });
    probes.push({
      ...frozen,
      latitude: 46.07 + i / 100000,
      longitude: 11.12,
      radius_m: 1,
    });
  }
  const before = [];
  for (const p of probes) before.push((await search(anonymous, p)).items);
  for (const rows of before) {
    const paired = rows.filter((r) =>
      [
        "a9420000-0000-4000-8000-000000000001",
        "a9420000-0000-4000-8000-000000000002",
      ].includes(r.item_id),
    );
    check(
      paired.length === 0 || paired.length === 2,
      "MAP04 repeated tiny probes cannot distinguish different private venues",
    );
  }
  await db.unsafe(
    "update public.project_memberships set removed_at=now(),removed_by_profile_id=$1 where id in ('a9460000-0000-4000-8000-000000000001','a9460000-0000-4000-8000-000000000002')",
    [owner.id],
  );
  await db.unsafe(
    "update public.proposal_meeting_details set exact_location_visibility='public',exact_location=extensions.st_setsrid(extensions.st_makepoint(-30,-20),4326)::extensions.geography where proposal_id='a9420000-0000-4000-8000-000000000001'",
  );
  await db.unsafe(
    "update public.recurring_activity_meeting_details set exact_location_visibility='public',exact_location=extensions.st_setsrid(extensions.st_makepoint(-30,-20),4326)::extensions.geography where recurring_activity_id='a9440000-0000-4000-8000-000000000001'",
  );
  assert.deepEqual(await search(peer.client, frozen), first);
  check(
    true,
    "MAP04 removed member/exact visibility cannot alter public output",
  );
  for (let i = 0; i < probes.length; i++) {
    assert.deepEqual((await search(peer.client, probes[i])).items, before[i]);
    check(
      true,
      "MAP04 tiny probe after revocation identical to anon before revocation",
    );
  }
  check(
    (
      await search(anonymous, {
        mode: "bounds",
        south: -33.87,
        north: -33.85,
        west: 151.2,
        east: 151.22,
      })
    ).items.length === 0,
    "MAP04 shifted negative viewport never matches private exact",
  );
  await db.unsafe(
    "update public.proposals set selected_public_place=null,approximate_location=null where id='a9420000-0000-4000-8000-000000000001'",
  );
  check(
    (await search(anonymous, frozen)).items.length === 6,
    "MAP04 cleared public selection stops matching subsequent REST reads",
  );
  await denied(
    anonymous,
    "search_public_geography_v1",
    { p_query: { ...query, srid: 3857 } },
    "22023",
  );
  await denied(
    anonymous,
    "search_public_geography_v1",
    {
      p_query: { mode: "bounds", south: 46, north: 47, west: 179, east: -179 },
    },
    "22023",
  );
  await denied(
    anonymous,
    "search_public_geography_v1",
    { p_query: query, p_limit: 51 },
    "22023",
  );
  await verifyGeographicPerformance({ db, owner, check });
}

export async function verifyGeographicPerformance({ db, owner, check }) {
  // Synthetic EXPLAIN fixtures are always rolled back; never rewrite product geometry.
  const rollback = new Error("MAP04 performance fixture rollback");
  let evidence;
  try {
    await db.begin(async (sql) => {
      const base = {
        provider: "geoapify",
        kind: "locality",
        result_type: "city",
        label: "MAP04 synthetic density",
        country_code: "IT",
        locality: "Trento",
        source: "openstreetmap",
        attribution: "Powered by Geoapify | © OpenStreetMap contributors",
        source_license: "https://www.openstreetmap.org/copyright",
        verified_at: "2026-10-01T00:00:00Z",
      };
      for (const [table, point, prefix, actor] of [
        ["proposals", "approximate_location", "a9480000", "creator_profile_id"],
        [
          "recurring_activities",
          "approximate_location",
          "a9490000",
          "creator_profile_id",
        ],
        [
          "resource_listings",
          "public_location",
          "a94a0000",
          "owner_profile_id",
        ],
      ]) {
        const extra =
          table === "proposals"
            ? ",summary,starts_at,ends_at,event_timezone"
            : table === "resource_listings"
              ? ",listing_mode"
              : "";
        const extraValues =
          table === "proposals"
            ? ",'Synthetic summary',now()+interval '1 day',now()+interval '2 days','Europe/Rome'"
            : table === "resource_listings"
              ? ",'donate'"
              : "";
        await sql.unsafe(
          `insert into public.${table}(id,${actor},title,description,country_code,locality,public_location_label,lifecycle_state,published_at,selected_public_place,${point}${extra})
          select ('${prefix}-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,$1,'MAP04 density','Synthetic density','IT','Trento','MAP04 synthetic density','published',now()-interval '1 hour',place,private.selected_place_point(place)${extraValues}
          from (select i,$2::jsonb||jsonb_build_object('latitude',36+(i%120)*0.1,'longitude',6+(i/120)*0.1) place from generate_series(1,5000)i)s`,
          [owner.id, base],
        );
        if (table === "recurring_activities")
          await sql.unsafe(
            "insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from) select id,'weekly',1,'12:00',60,'Europe/Rome',current_date from public.recurring_activities where id::text like 'a9490000-%'",
          );
        await sql.unsafe(`analyze public.${table}`);
      }
      evidence = { synthetic_rows_per_family: 5000, queries: [] };
      for (const [table, point] of [
        ["proposals", "approximate_location"],
        ["recurring_activities", "approximate_location"],
        ["resource_listings", "public_location"],
      ]) {
        for (const mode of ["radius", "bounds"]) {
          const spatial =
            mode === "radius"
              ? `extensions.st_dwithin(p.${point},extensions.st_setsrid(extensions.st_makepoint(9,46),4326)::extensions.geography,5000)`
              : `(p.${point}::extensions.geometry) operator(extensions.&&) extensions.st_makeenvelope(8.95,45.95,9.05,46.05,4326)`;
          const [plan] = await sql.unsafe(
            `explain (analyze,buffers,format json) select p.id from public.${table} p where p.lifecycle_state='published' and p.published_at<=now() and p.${point} is not null and p.selected_public_place is not null and private.valid_selected_place(p.selected_public_place) and ${spatial}${table === "proposals" ? " and p.ends_at>now()-interval '24 hours'" : ""} order by p.id limit 2001`,
          );
          const data = plan["QUERY PLAN"];
          check(
            JSON.stringify(data).includes(table + "_map04_" + mode),
            "MAP04 " + table + " " + mode + " uses scoped GiST",
          );
          evidence.queries.push({ table, mode, plan: data });
        }
      }
      const [full] = await sql.unsafe(
        "explain (analyze,buffers,format json) select public.search_public_geography_v1($1::jsonb)",
        [{ mode: "radius", latitude: 46, longitude: 9, radius_m: 5000 }],
      );
      evidence.full_rpc = full["QUERY PLAN"];
      throw rollback;
    });
  } catch (error) {
    if (error !== rollback) throw error;
  }
  if (process.env.MAP04_EXPLAIN_OUTPUT)
    await writeFile(
      process.env.MAP04_EXPLAIN_OUTPUT,
      JSON.stringify(evidence, null, 2) + "\n",
      "utf8",
    );
  console.log(
    "MAP04 EXPLAIN: 15000 rolled-back synthetic rows; all six radius/bounds GiST plans verified.",
  );
}
