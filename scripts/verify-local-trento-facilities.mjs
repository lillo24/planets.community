import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { writeFile } from "node:fs/promises";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { assertSafeLocalDemoTarget } from "./lib/demo-world.mjs";
import {
  activityImportStore,
  runActivityImport,
} from "./lib/external-activities/importer.mjs";
import {
  trentoFacilitiesConnector,
  trentoFacilitiesSource,
} from "./lib/external-activities/trento-facilities.mjs";

if (process.env.PLANETS_DISPOSABLE_QA !== "1")
  throw Error("Explicit disposable local QA authorization required.");
const args = process.argv.slice(2);
if (args.length !== 2 || args[0] !== "--evidence" || !args[1])
  throw Error("Use --evidence <new local JSON path>.");
const status = readLocalSupabaseStatus(process.cwd());
assertSafeLocalDemoTarget({ ...status, mailpitUrl: process.env.MAILPIT_URL });
if (new URL(status.apiUrl).port === "54321")
  throw Error("Retained default stack is not disposable.");
const sql = postgres(status.databaseUrl, { max: 2, onnotice: () => {} });
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const service = createClient(status.apiUrl, status.serviceRoleKey, options);
const guest = createClient(status.apiUrl, status.publishableKey, options);
const source = trentoFacilitiesSource;
let created = false;
async function read(name, params = {}) {
  const { data, error } = await guest.rpc(name, params);
  assert.equal(error, null, name);
  return data;
}
try {
  const [configuration] =
    await sql`select count(*)::integer as count from private.external_activity_sources`;
  assert.equal(
    configuration.count,
    0,
    "Do not modify a configured or peer backend.",
  );
  const nativeBefore =
    await sql`select count(*)::integer as count from public.projects`;
  await sql`insert into private.external_activity_sources
    (source_id,display_name,official_origin,supported_kinds,enabled,rights_confirmed,attribution,license_url)
    values(${source.sourceId},${source.displayName},${source.origin},array['place'],true,true,
      'Comune di Trento — Impianti sportivi ad accesso libero — CC BY 4.0',${source.licenseUrl})`;
  created = true;
  const connector = trentoFacilitiesConnector();
  let snapshot;
  let digest;
  const first = await runActivityImport({
    connector: {
      ...connector,
      async collect(context) {
        snapshot = await connector.collect({
          ...context,
          transport: {
            ...context.transport,
            async text(...input) {
              const result = await context.transport.text(...input);
              digest = createHash("sha256")
                .update(result.value, "utf8")
                .digest("hex");
              return result;
            },
          },
        });
        return snapshot;
      },
    },
    store: activityImportStore(service),
    apply: true,
  });
  assert.equal(first.rejected, 0);
  assert.equal(first.accepted, snapshot.entries.length);
  assert.ok(first.accepted > 0 && first.accepted <= 2000);
  const before =
    await sql`select upstream_id,activity_id,revision,content_hash from private.external_activities where source_id=${source.sourceId} order by upstream_id`;
  // Repeat the very same fetched official snapshot, without another provider
  // request or asserting that a changing live feed is permanently unchanged.
  const repeat = await runActivityImport({
    connector: { ...connector, collect: async () => snapshot },
    store: activityImportStore(service),
    apply: true,
  });
  assert.equal(repeat.changed, 0);
  assert.deepEqual(
    await sql`select upstream_id,activity_id,revision,content_hash from private.external_activities where source_id=${source.sourceId} order by upstream_id`,
    before,
  );
  const pages = [];
  let cursor;
  do {
    const page = await read("list_external_activities_v2", {
      p_kind: "place",
      p_category: "sports",
      p_limit: 30,
      p_cursor: cursor,
    });
    pages.push(page);
    cursor = page.next_cursor;
    assert.ok(pages.length <= 67, "Bound complete local pagination");
  } while (cursor);
  const items = pages.flatMap((page) => page.items);
  assert.equal(new Set(items.map((item) => item.id)).size, first.accepted);
  assert.ok(
    items.every(
      (item) =>
        item.kind === "place" &&
        item.next_at === null &&
        item.occurrences.length === 0 &&
        item.cost === null,
    ),
  );
  assert.equal(
    items.filter((item) => item.link_scope === "dataset").length,
    first.source_summary.dataset_links,
  );
  assert.equal(
    (await read("list_external_activities_v2", { p_kind: "course" })).items
      .length,
    0,
  );
  assert.equal((await read("list_external_activities")).items.length, 0);
  const detail = await read("get_external_activity_v2", {
    p_activity_id: items[0].id,
  });
  assert.equal(detail.id, items[0].id);
  assert.deepEqual(
    await sql`select count(*)::integer as count from public.projects`,
    nativeBefore,
  );
  const evidence = {
    observed_at: new Date().toISOString(),
    source_id: source.sourceId,
    parser_version: source.parserVersion,
    decoded_utf8_sha256: digest,
    first,
    repeat: { accepted: repeat.accepted, changed: repeat.changed },
    page: pages[0],
    detail,
    pages: pages.length,
    statement:
      "One actual official CSV fetch; complete local canonical import and repeat of that exact fetched snapshot. Fixtures cleaned. No hosted writes.",
  };
  await writeFile(args[1], JSON.stringify(evidence, null, 2) + "\n", {
    flag: "wx",
  });
  console.log(
    JSON.stringify({
      result: "PASS",
      ...first.source_summary,
      accepted: first.accepted,
      repeat_changed: repeat.changed,
      pages: pages.length,
      decoded_utf8_sha256: digest,
    }),
  );
} finally {
  if (created) {
    await sql`delete from private.external_activities where source_id=${source.sourceId}`;
    await sql`delete from private.external_activity_runs where source_id=${source.sourceId}`;
    await sql`delete from private.external_activity_sources where source_id=${source.sourceId}`;
  }
  await sql.end({ timeout: 5 });
}
