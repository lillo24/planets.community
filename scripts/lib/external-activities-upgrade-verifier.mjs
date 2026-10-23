import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { normalizeActivity } from "./external-activities/records.mjs";

// Called only by the disposable-stack HTTP verifier, after its target guards.
// All predecessor restoration, DDL and synthetic writes roll back together.
export async function verifyExternalCatalogueUpgrade(sql) {
  const legacy = readFileSync(
    new URL(
      "../../supabase/migrations/20261022084023_external_activity_catalogue.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const migration = readFileSync(
    new URL(
      "../../supabase/migrations/20261022231354_external_activity_catalogue_kinds.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const validatorStart = legacy.indexOf(
    "create function private.validate_external_activity(",
  );
  const validatorEnd = legacy.indexOf(
    "create function public.begin_external_activity_import(",
    validatorStart,
  );
  const readsStart = legacy.indexOf(
    "create function public.list_external_activities(",
  );
  const readsEnd = legacy.indexOf(
    "revoke all on function private.activity_public_https_url",
    readsStart,
  );
  assert.ok(
    validatorStart >= 0 &&
      validatorEnd > validatorStart &&
      readsStart >= 0 &&
      readsEnd > readsStart,
  );
  const rollback = new Error(
    "Successful upgrade proof: rollback synthetic fixture and DDL",
  );
  const sourceId = "synthetic-actcat02-upgrade";
  const origin = "https://upgrade.example.org";
  const record = {
    upstream_id: "legacy",
    title: "Synthetic legacy event",
    description: "Synthetic predecessor text",
    canonical_url: origin + "/legacy",
    category: "sports",
    source_categories: [],
    status: "scheduled",
    publishable: true,
    occurrences: [
      {
        kind: "timed",
        start: new Date(Date.now() + 86400000).toISOString(),
        timezone: "Europe/Rome",
      },
    ],
  };
  try {
    await sql.begin(async (tx) => {
      const [configured] =
        await tx`select count(*)::int as count from private.external_activity_sources where enabled`;
      assert.equal(
        configured.count,
        0,
        "Upgrade verification must precede any enabled source.",
      );
      await tx.unsafe(`drop function public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb),
        public.get_external_activity_v2(uuid),
        private.external_catalogue_rows(timestamptz,timestamptz,text,text,date,date),
        private.external_catalogue_payload(private.external_activities,private.external_activity_sources,timestamptz),
        private.external_catalogue_timing(jsonb,timestamptz,date,date),private.external_course_current(jsonb,timestamptz),
        private.validate_external_event_v1(jsonb,text)`);
      await tx.unsafe(
        legacy
          .slice(validatorStart, validatorEnd)
          .replace("create function", "create or replace function"),
      );
      await tx.unsafe(
        legacy
          .slice(readsStart, readsEnd)
          .replaceAll("create function", "create or replace function"),
      );
      const [before] =
        await tx`select 'private.validate_external_activity(jsonb,text)'::regprocedure::oid as oid`;
      await tx`insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
        values(${sourceId},'Synthetic upgrade fixture',${origin},true,true,'Synthetic attribution',${origin + "/license"})`;
      async function publish(records) {
        const [lease] =
          await tx`select public.begin_external_activity_import(${sourceId}) as run`;
        await tx`select public.finish_external_activity_import(${lease.run.run_id}::uuid,'success',${tx.json(records)}::jsonb,${records.length})`;
      }
      // Populate and warm the installed function plans before applying ACTCAT02.
      await publish([record]);
      const [oldPage] =
        await tx`select public.list_external_activities() as page`;
      const oldId = oldPage.page.items[0].id;
      await tx.unsafe(migration);
      const [after] =
        await tx`select 'private.validate_external_activity(jsonb,text)'::regprocedure::oid as oid`;
      assert.equal(
        after.oid,
        before.oid,
        "Already prepared imports keep the installed validator identity.",
      );
      const place = normalizeActivity(
        {
          ...record,
          upstream_id: "place",
          kind: "place",
          description: null,
          occurrences: [],
        },
        origin,
      );
      await publish([place]);
      const [pages] =
        await tx`select public.list_external_activities() as old_page,public.list_external_activities_v2() as new_page`;
      assert.deepEqual(
        pages.old_page.items.map((item) => item.id),
        [oldId],
      );
      assert.equal(pages.old_page.items[0].description, record.description);
      assert.deepEqual(
        pages.new_page.items.map((item) => item.kind),
        ["event", "place"],
      );
      const [identity] =
        await tx`select activity_id::text as id,revision from private.external_activities where source_id=${sourceId} and upstream_id='legacy'`;
      assert.equal(identity.id, oldId);
      assert.equal(Number(identity.revision), 1);
      throw rollback;
    });
  } catch (error) {
    if (error !== rollback) throw error;
  }
  console.log(
    "External catalogue populated upgrade: legacy ID/prose/revision and validator OID preserved; warmed imports accept V2 places. All fixture DDL/data rolled back.",
  );
}
