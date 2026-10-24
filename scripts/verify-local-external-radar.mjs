import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { assertSafeLocalDemoTarget } from "./lib/demo-world.mjs";
import {
  radarSources,
  radarConnector,
} from "./lib/external-activities/radar-sources.mjs";
import {
  runRadarImport,
  radarImportStore,
} from "./lib/external-activities/radar-importer.mjs";

const ci = process.env.CI === "true";
if (!ci && process.env.PLANETS_DISPOSABLE_QA !== "1")
  throw Error("Explicit disposable local QA required.");
const args = process.argv.slice(2);
if (
  ![0, 3, 5].includes(args.length) ||
  (args.length &&
    (args[0] !== "--live" || args[1] !== "--evidence" || !args[2])) ||
  (args.length === 5 &&
    (args[3] !== "--source" ||
      !radarSources.some((s) => s.sourceId === args[4])))
)
  throw Error(
    "Use no arguments for synthetic HTTP/SQL, or --live --evidence <new private local JSON path> [--source <known source>].",
  );
const live = args.length > 0;
if (live && (ci || process.env.PLANETS_DISPOSABLE_QA !== "1"))
  throw Error("Live publisher checks require explicit owned local QA, not CI.");
const status = readLocalSupabaseStatus(process.cwd());
assertSafeLocalDemoTarget({
  ...status,
  mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
});
// Ephemeral hosted CI owns its default local stack; human QA must use isolation.
if (!ci && new URL(status.apiUrl).port === "54321")
  throw Error("Default stack is not disposable.");
const sql = postgres(status.databaseUrl, { max: 2, onnotice: () => {} });
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const service = createClient(status.apiUrl, status.serviceRoleKey, options),
  guest = createClient(status.apiUrl, status.publishableKey, options);
const store = radarImportStore({
    rpc(name, params) {
      return {
        async abortSignal(signal) {
          const result = await service.rpc(name, params).abortSignal(signal);
          if (result.error)
            console.error(
              JSON.stringify({
                step: name,
                code: result.error.code,
                message: result.error.message,
              }),
            );
          return result;
        },
      };
    },
  }),
  sources = [];
const read = async (name, params = {}) => {
  const { data, error } = await guest.rpc(name, params);
  assert.equal(error, null, `${name}: ${error?.message}`);
  return data;
};
try {
  assert.equal(
    (
      await sql`select count(*)::integer n from private.external_activity_sources`
    )[0].n,
    0,
    "Fresh owned backend required; preserve peer data.",
  );
  if (live) {
    const outcomes = [];
    for (const source of radarSources.filter(
      (s) => args.length < 5 || s.sourceId === args[4],
    )) {
      await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,supported_kinds,radar_collection_enabled,radar_parser_version)
        values(${source.sourceId},${source.displayName},${source.origin},array['event'],true,${source.parserVersion})`;
      sources.push(source.sourceId);
      try {
        const result = await runRadarImport({
          connector: radarConnector(source.sourceId),
          store,
          apply: true,
        });
        const rows =
          await sql`select upstream_id,title,record,reason,evidence,published_at from private.external_radar_candidates where source_id=${source.sourceId} order by upstream_id`;
        outcomes.push({ source: source.sourceId, ...result, candidates: rows });
        assert.equal(result.publishable, 0);
        assert.equal(
          (await read("list_external_activities_v4")).items.length,
          0,
        );
        const before =
          await sql`select upstream_id,revision_digest from private.external_radar_candidates where source_id=${source.sourceId} order by upstream_id`;
        // Replay the same extracted representations without provider refetch.
        // This proves evidence/revision idempotency, not a fresh observation.
        const docs =
          await sql`select representation from private.external_radar_documents where source_id=${source.sourceId}`;
        const replay = await store.beginRadar(
          source.sourceId,
          source.parserVersion,
          AbortSignal.timeout(15000),
        );
        await store.finishRadar(
          replay.run_id,
          { candidates: rows, documents: docs.map((d) => d.representation) },
          AbortSignal.timeout(15000),
        );
        assert.deepEqual(
          await sql`select upstream_id,revision_digest from private.external_radar_candidates where source_id=${source.sourceId} order by upstream_id`,
          before,
        );
      } catch (error) {
        outcomes.push({
          source: source.sourceId,
          state: "failed",
          code: error.code ?? "verification_failed",
          message: error.message,
        });
      }
    }
    await writeFile(
      args[2],
      JSON.stringify(
        {
          evidence: "actual_private_publisher_candidates_publication_held",
          as_of: new Date().toISOString(),
          outcomes,
        },
        null,
        2,
      ),
      { flag: "wx" },
    );
    console.log(
      JSON.stringify({
        mode: "live",
        outcomes: outcomes.map(({ candidates, ...summary }) => summary),
      }),
    );
    if (outcomes.some((o) => o.state === "failed")) process.exitCode = 1;
  } else {
    const origin = "https://radar-fixture.example.org",
      parser = "radar-fixture-v1";
    const future = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const occurrence = {
      kind: "date",
      start: future,
      end: null,
      timezone: "Europe/Rome",
    };
    let records = [
      {
        upstream_id: "one",
        title: "Synthetic workshop",
        canonical_url: origin + "/events/one",
        kind: "event",
        activity_type: "workshops",
        category: "culture",
        description: null,
        source_categories: [],
        discipline: null,
        organizer: null,
        cost: "Synthetic free admission",
        audience: null,
        city: "Trento",
        venue: "Synthetic hall",
        address: null,
        status: "scheduled",
        publishable: true,
        source_modified_at: null,
        geometry: {
          latitude: 46.07,
          longitude: 11.12,
          precision: "venue",
          provenance_url: origin + "/events/one",
        },
        occurrences: [occurrence],
      },
      {
        upstream_id: "two",
        title: "Synthetic music",
        canonical_url: origin + "/events/two",
        kind: "event",
        activity_type: "music",
        category: "culture",
        description: null,
        source_categories: [],
        discipline: null,
        organizer: null,
        cost: null,
        audience: null,
        city: "Trento",
        venue: null,
        address: null,
        status: "scheduled",
        publishable: true,
        source_modified_at: null,
        geometry: null,
        occurrences: [occurrence],
      },
    ];
    const connector = (id) => ({
      sourceId: id,
      parserVersion: parser,
      origin,
      origins: [origin],
      publicLinkOrigins: [origin],
      allowedPaths: ["/robots.txt", "/events/"],
      delayMs: 0,
      async collect({ document }) {
        return {
          complete: true,
          candidates: await document(origin + "/events/data", "json", (rows) =>
            rows.map((record) => ({
              upstream_id: record.upstream_id,
              title: record.title,
              record,
              fields: {
                title: "synthetic $.title",
                occurrences: "synthetic $.occurrences",
              },
              reason: null,
            })),
          ),
        };
      },
    });
    let fail = false;
    const fetchImpl = async (url) =>
      url.endsWith("/robots.txt")
        ? new Response("User-agent: *\nAllow: /", {
            headers: { "content-type": "text/plain" },
          })
        : fail
          ? new Response("failure", { status: 503 })
          : new Response(JSON.stringify(records), {
              headers: { "content-type": "application/json" },
            });
    const importSource = (id, extra = {}) =>
      runRadarImport({
        connector: connector(id),
        store,
        apply: true,
        fetchImpl,
        sleep: async () => {},
        ...extra,
      });
    const register = async (id, enabled = true) => {
      sources.push(id);
      await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,supported_kinds,enabled,rights_confirmed,attribution,license_url,radar_collection_enabled,radar_parser_version,radar_parser_qualified,radar_facts_reuse,radar_policy_url,radar_qualified_parser_version,radar_policy_revision,radar_qualified_policy_revision)
      values(${id},'Synthetic QA publisher',${origin},array['event'],${enabled},${enabled},'Synthetic QA only',${enabled ? origin + "/licence" : null},true,${parser},${enabled},${enabled},${enabled ? origin + "/licence" : null},${enabled ? parser : null},${enabled ? "a".repeat(64) : null},${enabled ? "a".repeat(64) : null})`;
    };
    await register("radar-qa-a");
    const first = await importSource("radar-qa-a");
    assert.equal(first.publishable, 2);
    const identities =
      await sql`select upstream_id,activity_id,revision from private.external_activities order by upstream_id`;
    assert.equal((await importSource("radar-qa-a")).changed, 0);
    assert.deepEqual(
      await sql`select upstream_id,activity_id,revision from private.external_activities order by upstream_id`,
      identities,
    );
    const page = await read("list_external_activities_v4");
    assert.equal(page.items.length, 2);
    assert.deepEqual(page.facets.activity_types, ["music", "workshops"]);
    // Qualification binds both exact parser and actual approved policy revision.
    await sql`update private.external_activity_sources set radar_policy_revision=${"b".repeat(64)} where source_id='radar-qa-a'`;
    assert.equal((await read("list_external_activities_v4")).items.length, 0);
    assert.equal((await importSource("radar-qa-a")).publishable, 0);
    await sql`update private.external_activity_sources set radar_policy_revision=${"a".repeat(64)},radar_parser_version='unqualified-new-parser' where source_id='radar-qa-a'`;
    assert.equal(
      await read("get_external_activity_v2", {
        p_activity_id: identities[0].activity_id,
      }),
      null,
    );
    await sql`update private.external_activity_sources set radar_parser_version=${parser} where source_id='radar-qa-a'`;
    await sql`update private.external_activity_sources set radar_parser_version=null where source_id='radar-qa-a'`;
    assert.equal(
      (await read("list_external_activities_v4")).items.length,
      0,
      "Missing Radar parser cannot fall back to legacy approval",
    );
    await sql`update private.external_activity_sources set radar_parser_version=${parser} where source_id='radar-qa-a'`;
    const selected = await read("list_external_activities_v4", {
      p_activity_type: "workshops",
      p_limit: 1,
    });
    assert.equal(selected.items.length, 1);
    assert.equal(selected.items[0].activity_type, "workshops");
    const map = await read("list_external_activities_v4", {
      p_map_only: true,
      p_activity_type: "workshops",
    });
    assert.deepEqual(
      map.items.map((i) => i.id),
      selected.items.map((i) => i.id),
    );
    assert.equal(
      (
        await read("list_external_activities_v4", {
          p_activity_type: "music",
          p_map_only: true,
        })
      ).items.length,
      0,
    );
    const paged = await read("list_external_activities_v4", { p_limit: 1 });
    assert.ok(paged.next_cursor);
    assert.equal(
      (
        await guest.rpc("list_external_activities_v4", {
          p_limit: 1,
          p_cursor: { ...paged.next_cursor, key: "tampered" },
        })
      ).error?.code,
      "22023",
    );
    assert.equal(
      (
        await guest.rpc("list_external_activities_v4", {
          p_limit: 1,
          p_cursor: paged.next_cursor,
          p_activity_type: "music",
        })
      ).error?.code,
      "22023",
    );
    records = [
      {
        ...records[0],
        title: "Changed synthetic title",
        occurrences: [
          {
            ...occurrence,
            start: new Date(Date.now() + 2 * 86400000)
              .toISOString()
              .slice(0, 10),
          },
        ],
      },
      records[1],
    ];
    assert.equal((await importSource("radar-qa-a")).changed, 1);
    assert.equal(
      (
        await sql`select activity_id from private.external_activities where upstream_id='one'`
      )[0].activity_id,
      identities[0].activity_id,
    );
    const beforeFailure =
      await sql`select activity_id,last_observed_at,content_hash from private.external_activities order by upstream_id`;
    fail = true;
    await assert.rejects(
      importSource("radar-qa-a"),
      (e) => e.code === "upstream_error",
    );
    fail = false;
    assert.deepEqual(
      await sql`select activity_id,last_observed_at,content_hash from private.external_activities order by upstream_id`,
      beforeFailure,
    );
    // Complete absence is neither cancellation nor a new observation.
    const full = records;
    records = [records[0]];
    await importSource("radar-qa-a");
    assert.equal(
      (
        await sql`select count(*)::integer n from private.external_activities`
      )[0].n,
      2,
    );
    records = [records[0]];
    await register("radar-qa-b");
    await importSource("radar-qa-b");
    assert.equal(
      (await read("list_external_activities_v4")).items.length,
      2,
      "Exact duplicate collapsed",
    );
    const alias = (
      await sql`select alias_id,canonical_id from private.external_activity_aliases`
    )[0];
    assert.ok(alias);
    assert.equal(
      (
        await read("get_external_activity_v2", {
          p_activity_id: alias.alias_id,
        })
      ).id,
      alias.canonical_id,
    );
    records = [
      {
        ...records[0],
        occurrences: [
          {
            ...occurrence,
            start: new Date(Date.now() + 3 * 86400000)
              .toISOString()
              .slice(0, 10),
          },
        ],
      },
    ];
    assert.equal(
      (await importSource("radar-qa-b")).publishable,
      0,
      "Conflicting same URL is withheld",
    );
    assert.equal(
      (
        await sql`select count(*)::integer n from private.external_radar_candidates where reason='source_conflict'`
      )[0].n,
      1,
    );
    await sql`update private.external_activity_sources set enabled=false where source_id='radar-qa-a'`;
    assert.equal(
      await read("get_external_activity_v2", {
        p_activity_id: identities[0].activity_id,
      }),
      null,
    );
    await sql`update private.external_activity_sources set rights_confirmed=false,enabled=false where source_id='radar-qa-b'`;
    assert.equal((await read("list_external_activities_v4")).items.length, 0);
    await register("radar-qa-held", false);
    records = full;
    const held = await importSource("radar-qa-held");
    assert.equal(held.state, "collected_held");
    assert.equal(held.publishable, 0);
    assert.equal(
      (
        await sql`select count(*)::integer n from private.external_radar_candidates where source_id='radar-qa-held'`
      )[0].n,
      2,
    );
    const inFlight = await store.beginRadar(
      "radar-qa-held",
      parser,
      AbortSignal.timeout(15000),
    );
    await sql`update private.external_activity_sources set radar_collection_enabled=false where source_id='radar-qa-held'`;
    const receipt = await store.finishRadar(
      inFlight.run_id,
      { candidates: [], documents: [] },
      AbortSignal.timeout(15000),
    );
    assert.equal(receipt.publishable, 0);
    assert.ok(receipt.source_reasons.includes("source_configuration_changed"));
    assert.ok(
      (
        await guest.rpc("inspect_external_radar_candidates", {
          p_source_id: "radar-qa-held",
        })
      ).error,
    );
    assert.ok(
      (
        await guest.rpc("begin_external_radar_collection", {
          p_source_id: "radar-qa-held",
          p_parser_version: parser,
        })
      ).error,
    );
    await register("radar-qa-flight");
    records = [
      {
        ...full[0],
        upstream_id: "flight",
        canonical_url: origin + "/events/flight",
      },
    ];
    await importSource("radar-qa-flight");
    const flightBefore =
      await sql`select activity_id,content_hash,last_observed_at from private.external_activities where source_id='radar-qa-flight'`;
    records = [{ ...records[0], title: "Changed during in-flight withdrawal" }];
    const base = connector("radar-qa-flight");
    const withdrawn = await importSource("radar-qa-flight", {
      connector: {
        ...base,
        async collect(context) {
          const result = await base.collect(context);
          await sql`update private.external_activity_sources set enabled=false,rights_confirmed=false where source_id='radar-qa-flight'`;
          return result;
        },
      },
    });
    assert.equal(withdrawn.publishable, 0);
    assert.equal(withdrawn.state, "collected_held");
    assert.deepEqual(
      await sql`select activity_id,content_hash,last_observed_at from private.external_activities where source_id='radar-qa-flight'`,
      flightBefore,
    );
    assert.equal(
      await read("get_external_activity_v2", {
        p_activity_id: flightBefore[0].activity_id,
      }),
      null,
    );
    const expired = await store.beginRadar(
      "radar-qa-flight",
      parser,
      AbortSignal.timeout(15000),
    );
    await sql`update private.external_activity_sources set lease_expires_at=clock_timestamp()-interval '1 second' where source_id='radar-qa-flight'`;
    const maintenance = await service.rpc("maintain_external_radar_evidence", {
      p_source_id: "radar-qa-flight",
    });
    assert.equal(maintenance.error, null);
    assert.equal(
      (
        await sql`select state from private.external_radar_runs where run_id=${expired.run_id}`
      )[0].state,
      "failure",
    );
    // An explicit owner mapping preserves a known corrected upstream identity.
    await sql`update private.external_activity_sources set enabled=true where source_id='radar-qa-a'`;
    records = [
      {
        ...full[1],
        upstream_id: "corrected-two",
        title: "Corrected synthetic identity",
        canonical_url: origin + "/events/corrected-two",
      },
    ];
    await importSource("radar-qa-a");
    const corrected = (
      await sql`select activity_id,content from private.external_activities where source_id='radar-qa-a' and upstream_id='corrected-two'`
    )[0];
    const oldMusic = identities.find(
      (row) => row.upstream_id === "two",
    ).activity_id;
    await sql`insert into private.external_activity_aliases(alias_id,canonical_id,evidence_url,source_correction) values(${oldMusic},${corrected.activity_id},${corrected.content.canonical_url},true)`;
    assert.equal(
      (await read("get_external_activity_v2", { p_activity_id: oldMusic })).id,
      corrected.activity_id,
    );
    await sql`update private.external_activity_sources set enabled=false where source_id='radar-qa-a'`;
    assert.equal((await read("list_external_activities_v2")).items.length, 0);
    assert.equal((await read("list_external_activities_v3")).items.length, 0);
    console.log(
      JSON.stringify({
        mode: "synthetic_real_local_http_sql",
        checks: [
          "private_collection",
          "qualified_promotion",
          "idempotence",
          "title_time_update",
          "failure_preservation",
          "absence_preservation",
          "type_facets",
          "list_map",
          "signed_cursor",
          "exact_alias",
          "owner_source_correction",
          "parser_policy_revision_binding",
          "conflict_hold",
          "rights_disable",
          "inflight_disable",
          "lease_recovery",
          "anon_denial",
          "legacy_reads",
        ],
        passed: true,
      }),
    );
  }
} finally {
  if (sources.length) {
    await sql`delete from private.external_activity_aliases where alias_id in(select activity_id from private.external_activities where source_id=any(${sources})) or canonical_id in(select activity_id from private.external_activities where source_id=any(${sources}))`;
    await sql`delete from private.external_radar_documents where source_id=any(${sources})`;
    await sql`delete from private.external_radar_candidates where source_id=any(${sources})`;
    await sql`delete from private.external_radar_runs where source_id=any(${sources})`;
    await sql`delete from private.external_activity_runs where source_id=any(${sources})`;
    await sql`delete from private.external_activities where source_id=any(${sources})`;
    await sql`delete from private.external_activity_sources where source_id=any(${sources})`;
  }
  await sql.end();
}
