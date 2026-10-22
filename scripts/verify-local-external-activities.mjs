import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { assertSafeLocalDemoTarget } from "./lib/demo-world.mjs";
import {
  activityImportStore,
  runActivityImport,
} from "./lib/external-activities/importer.mjs";
import { ActivityImportError } from "./lib/external-activities/transport.mjs";
import { verifyExternalCatalogueUpgrade } from "./lib/external-activities-upgrade-verifier.mjs";

const ci = process.env.CI === "true";
if (!ci && process.env.PLANETS_DISPOSABLE_QA !== "1") {
  throw new Error(
    "External-activity verification requires PLANETS_DISPOSABLE_QA=1 and a task-owned disposable local stack.",
  );
}
const status = readLocalSupabaseStatus(process.cwd());
assertSafeLocalDemoTarget({
  ...status,
  mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
});
if (!ci && new URL(status.apiUrl).port === "54321") {
  throw new Error(
    "Use a non-default task-owned API port; the retained development stack is not disposable.",
  );
}
const sql = postgres(status.databaseUrl, { max: 3, onnotice: () => {} });
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const service = createClient(status.apiUrl, status.serviceRoleKey, options);
const guest = createClient(status.apiUrl, status.publishableKey, options);
const sourceId = `actapi01-qa-${randomUUID().slice(0, 8)}`;
const origin = "https://calendar.example.org";
const start = new Date(Date.now() + 36 * 3_600_000);
const record = (id) => ({
  upstream_id: id,
  title: `Synthetic activity ${id}`,
  description: "Synthetic QA text only.",
  canonical_url: `${origin}/events/${id}`,
  category: "culture",
  source_categories: ["Synthetic"],
  status: "scheduled",
  publishable: true,
  occurrences: [
    {
      kind: "timed",
      start: start.toISOString(),
      end: new Date(start.getTime() + 3_600_000).toISOString(),
      timezone: "Europe/Rome",
    },
  ],
});
let entries = [{ record: record("a") }, { record: record("b") }];
const connector = {
  sourceId,
  origins: [origin],
  officialOrigin: origin,
  apiPathPrefix: "/api/",
  collect: async () => ({ complete: true, entries }),
};
const store = activityImportStore(service);
let createdSource = false;
async function list(params = {}) {
  const { data, error } = await guest.rpc("list_external_activities", params);
  assert.equal(error, null, "Guest list RPC succeeds.");
  assert.ok(Array.isArray(data.items));
  return data;
}
async function detail(id) {
  const { data, error } = await guest.rpc("get_external_activity", {
    p_activity_id: id,
  });
  assert.equal(error, null, "Guest exact-detail RPC succeeds.");
  return data;
}
try {
  await verifyExternalCatalogueUpgrade(sql);
  assert.equal(
    (await list()).state,
    "unconfigured",
    "No enabled source is seeded or silently taken over.",
  );
  const [nativeBefore] =
    await sql`select count(*)::integer as count from public.projects`;
  await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
    values(${sourceId},'Synthetic local QA calendar',${origin},true,true,'Synthetic fixture attribution','https://calendar.example.org/license')`;
  createdSource = true;
  assert.equal((await list()).state, "never_synchronized");
  for (const name of [
    "begin_external_activity_import",
    "finish_external_activity_import",
  ]) {
    const { error } = await guest.rpc(
      name,
      name.startsWith("begin")
        ? { p_source_id: sourceId }
        : { p_run_id: randomUUID(), p_state: "success" },
    );
    assert.equal(error?.code, "42501", "Guest cannot call service mutations.");
  }
  const direct = await guest
    .schema("private")
    .from("external_activity_runs")
    .select("*");
  assert.ok(
    direct.error,
    "Private diagnostics are unavailable over the public Data API.",
  );
  const claims = await Promise.all([
    service.rpc("begin_external_activity_import", { p_source_id: sourceId }),
    service.rpc("begin_external_activity_import", { p_source_id: sourceId }),
  ]);
  assert.equal(
    claims.filter((r) => !r.error).length,
    1,
    "Two real concurrent claims yield one lease.",
  );
  assert.equal(claims.find((r) => r.error)?.error.code, "55P03");
  await store.finish(
    claims.find((r) => !r.error).data.run_id,
    {
      state: "failure",
      records: [],
      fetched: 0,
      rejected: 0,
      errorCode: "upstream_error",
    },
    AbortSignal.timeout(10_000),
  );

  const first = await runActivityImport({ connector, store, apply: true });
  assert.equal(first.changed, 2);
  const page = await list();
  assert.equal(page.state, "healthy");
  assert.equal(page.items.length, 2);
  const ids = new Map(page.items.map((item) => [item.title, item.id]));
  assert.equal(
    (await runActivityImport({ connector, store, apply: true })).changed,
    0,
  );
  assert.deepEqual(
    (await list()).items.map((item) => item.id).sort(),
    [...ids.values()].sort(),
  );
  const firstPage = await list({ p_limit: 1 });
  const secondPage = await list({
    p_limit: 1,
    p_cursor: firstPage.next_cursor,
  });
  assert.notEqual(firstPage.items[0].id, secondPage.items[0].id);
  assert.equal(secondPage.next_cursor, null);
  assert.equal((await list({ p_query: "activity b" })).items.length, 1);
  entries = [
    {
      record: {
        ...record("a"),
        title: "Changed synthetic activity",
        occurrences: [
          ...record("a").occurrences,
          {
            ...record("a").occurrences[0],
            start: new Date(start.getTime() + 7 * 86400000).toISOString(),
            end: new Date(
              start.getTime() + 7 * 86400000 + 3600000,
            ).toISOString(),
          },
        ],
      },
    },
  ];
  assert.equal(
    (await runActivityImport({ connector, store, apply: true })).changed,
    1,
  );
  const id = ids.get("Synthetic activity a");
  assert.equal((await detail(id)).occurrences.length, 2);
  const [before] =
    await sql`select last_success_at,catalogue_version from private.external_activity_sources where source_id=${sourceId}`;
  const beforeContent =
    await sql`select activity_id,content_hash from private.external_activities where source_id=${sourceId} order by activity_id`;
  await assert.rejects(
    runActivityImport({
      connector: {
        ...connector,
        collect: async () => {
          throw new ActivityImportError("upstream_error");
        },
      },
      store,
      apply: true,
    }),
  );
  const [after] =
    await sql`select last_success_at,catalogue_version from private.external_activity_sources where source_id=${sourceId}`;
  assert.deepEqual(after, before, "Failed run preserves completeness/version.");
  assert.deepEqual(
    await sql`select activity_id,content_hash from private.external_activities where source_id=${sourceId} order by activity_id`,
    beforeContent,
  );
  assert.equal((await list()).state, "unavailable");
  await sql`update private.external_activities set last_observed_at=statement_timestamp()-interval '73 hours' where activity_id=${id}`;
  assert.equal((await detail(id)).stale, true);
  await sql`update private.external_activities set last_observed_at=statement_timestamp()-interval '15 days' where activity_id=${id}`;
  entries = [{ record: record("b") }];
  await runActivityImport({ connector, store, apply: true });
  assert.equal(
    await detail(id),
    null,
    "Fresh source success does not refresh an absent old record.",
  );
  assert.equal((await list()).items.length, 1);
  const old = await store.begin(sourceId, AbortSignal.timeout(10_000));
  await sql`update private.external_activity_sources set lease_expires_at=clock_timestamp()-interval '1 second' where source_id=${sourceId}`;
  const newer = await store.begin(sourceId, AbortSignal.timeout(10_000));
  const obsolete = await service.rpc("finish_external_activity_import", {
    p_run_id: old.run_id,
    p_state: "success",
  });
  assert.equal(
    obsolete.error?.code,
    "40001",
    "A late worker cannot complete after lease takeover.",
  );
  await store.finish(
    newer.run_id,
    { state: "success", records: [], fetched: 0, rejected: 0 },
    AbortSignal.timeout(10_000),
  );
  // V2 uses the same leased import and identities. Unknown values never become
  // fabricated event dates/prose, and V1 cannot receive a new listing kind.
  const place = {
    ...record("place"),
    kind: "place",
    category: "sports",
    discipline: "basketball",
    description: null,
    occurrences: [],
    geometry: {
      latitude: 46.07,
      longitude: 11.12,
      precision: "locality",
      provenance_url: origin + "/dataset",
    },
  };
  const course = {
    ...record("course"),
    kind: "course",
    category: "sports",
    discipline: "yoga",
    description: null,
    occurrences: [],
    schedule: {
      season_start: new Date(Date.now() - 86400000).toISOString().slice(0, 10),
      season_end: new Date(Date.now() + 30 * 86400000)
        .toISOString()
        .slice(0, 10),
      text: "Synthetic schedule to confirm",
    },
  };
  entries = [record("b"), place, course].map((record) => ({ record }));
  assert.equal(
    (await runActivityImport({ connector, store, apply: true })).changed,
    2,
  );
  assert.equal((await list()).items.length, 1, "V1 remains event-only.");
  async function listV2(params = {}) {
    const { data, error } = await guest.rpc(
      "list_external_activities_v2",
      params,
    );
    assert.equal(error, null, "Anonymous V2 HTTP list succeeds.");
    return data;
  }
  const catalogue = await listV2();
  assert.deepEqual(
    catalogue.items.map((item) => item.kind),
    ["event", "course", "place"],
  );
  const placeId = catalogue.items.find((item) => item.kind === "place").id;
  const courseId = catalogue.items.find((item) => item.kind === "course").id;
  assert.equal(catalogue.items[1].next_at, null);
  assert.equal(catalogue.items[2].description, null);
  assert.equal(catalogue.items[2].geometry.precision, "locality");
  assert.equal((await listV2({ p_kind: "place" })).items[0].id, placeId);
  const v2first = await listV2({ p_limit: 1 });
  assert.equal(
    (await listV2({ p_limit: 1, p_cursor: v2first.next_cursor })).items[0].id,
    courseId,
  );
  assert.equal(
    (await runActivityImport({ connector, store, apply: true })).changed,
    0,
  );
  entries = [
    { record: record("b") },
    { record: place },
    { record: { ...course, kind: "place", schedule: null } },
  ];
  assert.equal(
    (await runActivityImport({ connector, store, apply: true })).changed,
    1,
  );
  const changedKind = await guest.rpc("get_external_activity_v2", {
    p_activity_id: courseId,
  });
  assert.equal(changedKind.error, null);
  assert.equal(
    changedKind.data.id,
    courseId,
    "Kind updates preserve the canonical UUID.",
  );
  assert.equal(changedKind.data.kind, "place");
  assert.equal(
    await detail(courseId),
    null,
    "V1 exact detail excludes new kinds.",
  );
  await sql`update private.external_activity_sources set enabled=false where source_id=${sourceId}`;
  assert.equal((await list()).state, "unconfigured");
  assert.equal((await listV2()).state, "unconfigured");
  assert.equal(
    (await guest.rpc("get_external_activity_v2", { p_activity_id: placeId }))
      .data,
    null,
  );
  assert.equal(await detail(ids.get("Synthetic activity b")), null);
  const [nativeAfter] =
    await sql`select count(*)::integer as count from public.projects`;
  assert.deepEqual(nativeAfter, nativeBefore);
  console.log(
    "External activities: synthetic local service/anonymous V1/V2 HTTP pipeline, all three kinds, stable repeat/kind update, paging, private denial, concurrent claims, failed-run preservation, per-record expiry, obsolete completion and source disable passed. No municipal data was fetched or published.",
  );
} finally {
  // Only this run's synthetic source is owned here; never reset a peer stack.
  if (createdSource) {
    await sql`delete from private.external_activities where source_id=${sourceId}`;
    await sql`delete from private.external_activity_runs where source_id=${sourceId}`;
    await sql`delete from private.external_activity_sources where source_id=${sourceId}`;
  }
  await sql.end({ timeout: 5 });
}
