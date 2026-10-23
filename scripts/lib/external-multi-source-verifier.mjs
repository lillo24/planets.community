import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

// Called only by the existing explicitly guarded disposable-local verifier.
export async function verifyExternalMultiSource(sql, service, guest) {
  const prefix = `actsrc02-${randomUUID().slice(0, 8)}`;
  const sources = [`${prefix}-a`, `${prefix}-b`];
  const origins = [
    "https://source-a.example.org",
    "https://source-b.example.org",
  ];
  const publicOrigin = "https://municipal.example.org";
  const start = new Date(Date.now() + 86400000).toISOString();
  const records = sources.map((_, i) => ({
    upstream_id: "same-id",
    title: `Synthetic source ${i}`,
    description: "Synthetic only",
    category: "sports",
    discipline: i ? "yoga" : "running",
    source_categories: [],
    canonical_url: (i ? origins[i] : publicOrigin) + "/item",
    status: "scheduled",
    publishable: true,
    occurrences: [{ kind: "timed", start, end: null, timezone: "UTC" }],
  }));
  async function rpc(name, params = {}, client = service) {
    const { data, error } = await client.rpc(name, params);
    assert.equal(error, null, name);
    return data;
  }
  const begin = (i) =>
    rpc("begin_external_activity_import", { p_source_id: sources[i] });
  const finish = (run, record) =>
    rpc("finish_external_activity_import", {
      p_run_id: run.run_id,
      p_state: "success",
      p_records: [record],
      p_fetched: 1,
    });
  const list = (params = {}) =>
    rpc("list_external_activities_v2", params, guest);
  try {
    for (let i = 0; i < sources.length; i++)
      await sql`insert into private.external_activity_sources
        (source_id,display_name,official_origin,public_link_origins,enabled,rights_confirmed,attribution,license_url)
        values(${sources[i]},'Synthetic local source',${origins[i]},${i ? [] : [publicOrigin]},true,true,'Synthetic attribution','https://example.org/license')`;
    const denied = await guest.rpc("begin_external_activity_import", {
      p_source_id: sources[0],
    });
    assert.equal(denied.error?.code, "42501");
    const claims = await Promise.all(
      [0, 0].map((i) =>
        service.rpc("begin_external_activity_import", {
          p_source_id: sources[i],
        }),
      ),
    );
    assert.equal(
      claims.filter((x) => !x.error).length,
      1,
      "Real concurrent A/A claim has one winner",
    );
    assert.equal(claims.find((x) => x.error).error.code, "55P03");
    const aRun = claims.find((x) => !x.error).data;
    const bRun = await begin(1);
    await Promise.all([finish(aRun, records[0]), finish(bRun, records[1])]);
    const first = await list({ p_limit: 1 });
    assert.equal(first.state, "healthy");
    assert.deepEqual([...first.disciplines].sort(), ["running", "yoga"]);
    const second = await list({ p_limit: 1, p_cursor: first.next_cursor });
    assert.notEqual(first.items[0].id, second.items[0].id);
    assert.equal(first.as_of, second.as_of);
    const identities = (await list()).items.map((x) => x.id).sort();
    assert.equal(identities.length, 2);
    const old = await rpc("list_external_activities", {}, guest);
    assert.deepEqual(
      old.items.map((x) => x.id).sort(),
      identities,
      "V1 traverses both event sources",
    );
    assert.ok(old.items.every((x) => !Object.hasOwn(x, "kind")));
    assert.equal((await finish(await begin(0), records[0])).changed, 0);
    const repeat = await service.rpc("finish_external_activity_import", {
      p_run_id: aRun.run_id,
      p_state: "success",
      p_records: [records[0]],
      p_fetched: 1,
    });
    assert.equal(
      repeat.error?.code,
      "40001",
      "Lost response retry cannot duplicate an already finished snapshot",
    );
    const before =
      await sql`select last_observed_at from private.external_activities where source_id=${sources[0]}`;
    assert.equal(
      (
        await finish(await begin(1), {
          ...records[1],
          title: "Synthetic updated source B",
        })
      ).changed,
      1,
    );
    assert.deepEqual(
      await sql`select last_observed_at from private.external_activities where source_id=${sources[0]}`,
      before,
    );
    assert.deepEqual((await list()).items.map((x) => x.id).sort(), identities);
    const failureRun = await begin(0);
    await rpc("finish_external_activity_import", {
      p_run_id: failureRun.run_id,
      p_state: "failure",
      p_error_code: "upstream_error",
    });
    assert.equal((await list()).state, "partial");
    assert.equal((await list()).items.length, 2);
    const [aNext, bNext] = await Promise.all([begin(0), begin(1)]);
    const cursor = (await list({ p_limit: 1 })).next_cursor;
    await sql`update private.external_activity_sources set enabled=false where source_id=${sources[0]}`;
    const obsolete = await service.rpc("finish_external_activity_import", {
      p_run_id: aNext.run_id,
      p_state: "success",
      p_records: [records[0]],
      p_fetched: 1,
    });
    assert.equal(obsolete.error?.code, "55000");
    await finish(bNext, records[1]);
    assert.equal((await list()).items.length, 1);
    const invalidCursor = await guest.rpc("list_external_activities_v2", {
      p_cursor: cursor,
    });
    assert.equal(invalidCursor.error?.code, "22023");
    assert.equal(
      (
        await guest.rpc("get_external_activity_v2", {
          p_activity_id: identities.find(
            (id) => id !== old.items.find((x) => x.source.id === sources[1]).id,
          ),
        })
      ).data,
      null,
    );
    console.log(
      "ACTSRC02: real anonymous/service HTTP, concurrent A/A and A/B, cross-source UUIDs/paging/facets, unchanged/update retry, failed-source preservation, partial health and disable fencing PASS.",
    );
  } finally {
    await sql`delete from private.external_activities where source_id=any(${sources})`;
    await sql`delete from private.external_activity_runs where source_id=any(${sources})`;
    await sql`delete from private.external_activity_sources where source_id=any(${sources})`;
  }
}
