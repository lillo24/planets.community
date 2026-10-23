import assert from "node:assert/strict";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { mapTileFixture } from "../lib/map-provider-fixture.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import {
  effectCatalogQuery,
  assertBoundedCatalog,
  catalogEffects,
} from "./eligibility.mjs";

const loopback = (value) =>
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(value).hostname),
    "Security contracts run only against owned disposable loopback services",
  );
const a = "a".repeat(64),
  b = "b".repeat(64);
const tableNames = [
  "location_provider_config",
  "map_baseline_config",
  "mock_basemap_config",
  "location_provider_usage",
  "map_provider_cache",
  "map_baseline_tiles",
  "mock_basemap_claims",
];
export async function seedStorageWitness(status, sql) {
  loopback(status.apiUrl);
  const options = {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  };
  const admin = createClient(status.apiUrl, status.serviceRoleKey, options);
  const id = "ad030000-0000-4000-8000-000000000001";
  const email = "staging-auto03-storage@planets.invalid";
  assert.equal(
    (await admin.auth.admin.createUser({ id, email, email_confirm: true }))
      .error,
    null,
  );
  const link = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  assert.equal(link.error, null);
  const client = createClient(status.apiUrl, status.publishableKey, options);
  assert.equal(
    (
      await client.auth.verifyOtp({
        type: "magiclink",
        token_hash: link.data.properties.hashed_token,
      })
    ).error,
    null,
  );
  await sql`insert into public.profiles(id,display_name) values(${id}::uuid,'AUTO03 synthetic preservation witness')`;
  const object = id + "/ad030000-0000-4000-8000-000000000002.webp";
  const bytes = Buffer.from(
    "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
    "base64",
  );
  assert.equal(
    (
      await client.storage
        .from("profile-photos")
        .upload(object, bytes, { contentType: "image/webp" })
    ).error,
    null,
  );
  assert.equal(
    (
      await client.rpc("set_own_profile_photo", {
        p_expected_profile_id: id,
        p_object_path: object,
        p_audience: "interactions",
      })
    ).error,
    null,
  );
  return async () => {
    const downloaded = await client.storage
      .from("profile-photos")
      .download(object);
    assert.equal(downloaded.error, null);
    assert.equal(
      sha256(Buffer.from(await downloaded.data.arrayBuffer())),
      sha256(bytes),
      "Storage object bytes preserved",
    );
    const own = await client.rpc("get_own_profile_photo", {
      p_expected_profile_id: id,
    });
    assert.equal(own.error, null);
    assert.equal(
      own.data[0].object_path,
      object,
      "Existing owner photo API preserved",
    );
  };
}
export async function mockBasemapContract(databaseUrl) {
  loopback(databaseUrl);
  const sql = postgres(databaseUrl, { max: 12, onnotice: () => {} });
  const saved = new Map();
  try {
    for (const table of tableNames)
      saved.set(
        table,
        (
          await sql.unsafe(
            `select coalesce(jsonb_agg(t),'[]') rows from private.${table} t`,
          )
        )[0].rows,
      );
    assert.equal(
      saved.get("mock_basemap_config")[0].enabled,
      false,
      "Mock defaults off",
    );
    assert.ok(saved.get("mock_basemap_config")[0].daily_units_limit <= 2000);
    const [grants] = await sql`select
      has_function_privilege('authenticated','public.reserve_mock_basemap_tile_v1(text,text,integer,integer,integer,boolean)','execute') bad_reserve,
      has_function_privilege('anon','public.finish_mock_basemap_tile_v1(integer,integer,integer,uuid,text)','execute') bad_finish,
      has_table_privilege('service_role','private.mock_basemap_config','select') bad_config`;
    assert.deepEqual(grants, {
      bad_reserve: false,
      bad_finish: false,
      bad_config: false,
    });
    await sql`update private.location_provider_config set enabled=true,tiles_enabled=true,cache_license_approved=true,tile_cache_seconds=60,daily_units_limit=8000,actor_daily_units=8000,actor_minute_requests=120,global_minute_requests=600,failure_streak=0,blocked_until=null`;
    await sql`update private.map_baseline_config set enabled=true,license_approved=true`;
    await sql`update private.mock_basemap_config set enabled=true,daily_units_limit=800,actor_daily_units=120,client_daily_units=160,max_concurrent_tiles=2`;
    for (const table of tableNames.slice(3))
      await sql.unsafe(`delete from private.${table}`);
    const reserve = (x, scope = a, client = b) =>
      sql`select public.reserve_mock_basemap_tile_v1(${scope},${client},18,${x},4000,false) result`.then(
        (r) => r[0].result,
      );
    await assert.rejects(
      () => reserve(4000, "asserted-actor", b),
      (e) => e.code === "22023",
    );
    const results = await Promise.all(
      Array.from({ length: 12 }, (_, i) => reserve(4000 + i)),
    );
    assert.equal(
      results.filter((r) => r.status === "ok").length,
      2,
      "Only two server IO slots",
    );
    assert.equal(results.filter((r) => r.status === "pending").length, 10);
    const used = async (scope) =>
      (
        await sql`select coalesce(sum(used),0)::integer units from private.location_provider_usage where scope=${scope}`
      )[0].units;
    assert.equal(
      await used("units:global"),
      2,
      "Actual shared ledger charged twice",
    );
    assert.equal(
      await used("units:mock"),
      2,
      "Mock is a subcap of the same units",
    );
    assert.equal(
      await used("units:actor:" + a),
      0,
      "No fictional normal actor",
    );
    const first = results.findIndex((r) => r.token);
    const png = mapTileFixture().toString("base64");
    assert.equal(
      (
        await sql`select public.finish_mock_basemap_tile_v1(18,${4000 + first},4000,${results[first].token}::uuid,${png}) result`
      )[0].result.status,
      "ok",
    );
    assert.equal(
      (await reserve(4000 + first)).cached,
      true,
      "Identical public cache hit",
    );
    assert.equal(
      await used("units:global"),
      2,
      "Cache hit is not acquired twice",
    );
    await sql`update private.mock_basemap_config set max_concurrent_tiles=6,daily_units_limit=2`;
    assert.equal(
      (await reserve(5000)).status,
      "budget_exhausted",
      "Mock subcap enforced",
    );
    await sql`update private.mock_basemap_config set enabled=false`;
    assert.equal(
      (await reserve(4000 + first)).status,
      "disabled",
      "Kill precedes public cache",
    );
    await sql`update private.mock_basemap_config set enabled=true,daily_units_limit=800`;
    await sql`update private.location_provider_config set daily_units_limit=4`;
    await sql`delete from private.location_provider_usage where scope like 'units:%' or scope like 'requests:%'`;
    await sql`insert into private.location_provider_usage values('units:global',date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC',4)`;
    assert.equal(
      (await reserve(6000)).status,
      "budget_exhausted",
      "Global limit remains authoritative",
    );
    assert.equal(await used("units:global"), 4);
    assert.equal(
      (await reserve(4000 + first)).cached,
      true,
      "Cache remains available at cap",
    );
    await sql`update private.location_provider_config set enabled=false`;
    assert.equal(
      (await reserve(4000 + first)).status,
      "disabled",
      "Master gates shared public bytes",
    );
    return true;
  } finally {
    // These tables belong to this explicitly loopback-only disposable stack.
    // Restore state without treating test mutations as migration effects.
    if (saved.size === tableNames.length)
      await sql.begin(async (tx) => {
        for (const table of tableNames) {
          await tx.unsafe(`delete from private.${table}`);
          await tx.unsafe(
            `insert into private.${table} select * from jsonb_populate_recordset(null::private.${table},$1::jsonb)`,
            [tx.json(saved.get(table))],
          );
        }
      });
    await sql.end({ timeout: 5 });
  }
}

// Genuine independent Auth sessions exercise the PostgREST permission boundary.
// SQL-role checks alone are not the authority for HTTP denial evidence.
export async function realActorServiceDenials(status, functions) {
  loopback(status.apiUrl);
  const options = {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  };
  const admin = createClient(status.apiUrl, status.serviceRoleKey, options);
  let checks = 0;
  for (let index = 0; index < 2; index++) {
    const email = `staging-auto03-actor-${index}@planets.invalid`;
    const created = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
    });
    assert.equal(created.error, null);
    try {
      const link = await admin.auth.admin.generateLink({
        type: "magiclink",
        email,
      });
      assert.equal(link.error, null);
      const client = createClient(
        status.apiUrl,
        status.publishableKey,
        options,
      );
      const verified = await client.auth.verifyOtp({
        type: "magiclink",
        token_hash: link.data.properties.hashed_token,
      });
      assert.equal(verified.error, null);
      assert.equal(verified.data.user.id, created.data.user.id);
      for (const fn of functions.filter(
        (f) =>
          f.id.startsWith("public.") &&
          f.access.service_role &&
          !f.access.authenticated &&
          !f.access.anon,
      )) {
        // Input names are generated by pg_catalog, not caller-selected.
        const args = Object.fromEntries(
          fn.input_names.map((name) => [name, null]),
        );
        const name = fn.id.slice("public.".length, fn.id.indexOf("("));
        const denied = await client.rpc(name, args);
        assert.equal(
          denied.error?.code,
          "42501",
          `Real actor must not execute service-only ${name}`,
        );
        checks++;
      }
      await client.auth.signOut({ scope: "local" });
    } finally {
      assert.equal(
        (await admin.auth.admin.deleteUser(created.data.user.id)).error,
        null,
      );
    }
  }
  return { verified: true, actors: 2, denials: checks };
}

export async function writerLockContract(databaseUrl) {
  loopback(databaseUrl);
  const pool = postgres(databaseUrl, { max: 2, onnotice: () => {} });
  const first = await pool.reserve(),
    second = await pool.reserve();
  try {
    await first`select pg_advisory_lock(72701,1)`;
    assert.equal(
      (await second`select pg_try_advisory_lock(72701,1) acquired`)[0].acquired,
      false,
    );
    await first`select pg_advisory_unlock(72701,1)`;
    assert.equal(
      (await second`select pg_try_advisory_lock(72701,1) acquired`)[0].acquired,
      true,
    );
    await second`select pg_advisory_unlock(72701,1)`;
  } finally {
    first.release();
    second.release();
    await pool.end({ timeout: 5 });
  }
  return true;
}

// During the policy-only PR, the already-proposed #300 SQL is a disposable
// untrusted test input. It is never added to canonical history or authorized by
// this fixture. Independent tests must reject its intentionally unsafe mutants.
export async function mapPolicyNegativeControls(status, fixtureSql) {
  loopback(status.databaseUrl);
  const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
  const before = (await sql.unsafe(effectCatalogQuery))[0].catalog;
  const original = (
    await sql`select pg_get_functiondef('public.reserve_basemap_tile_v2(uuid,integer,integer,integer,boolean)'::regprocedure) definition`
  )[0].definition;
  try {
    if (fixtureSql) await sql.begin((tx) => tx.unsafe(fixtureSql));
    await mockBasemapContract(status.databaseUrl);
    const signature = "private.reserve_mock_map_provider_v1(text,text,boolean)";
    const definition = (
      await sql`select pg_get_functiondef(${signature}::regprocedure) definition`
    )[0].definition;
    try {
      await sql.unsafe(
        definition.replaceAll("'units:global'", "'units:shadow'"),
      );
      await assert.rejects(
        () => mockBasemapContract(status.databaseUrl),
        { name: "AssertionError" },
        "Wrong ledger body with unchanged signature must fail",
      );
    } finally {
      await sql.unsafe(definition);
    }
    const fn =
      "public.reserve_mock_basemap_tile_v1(text,text,integer,integer,integer,boolean)";
    try {
      await sql.unsafe("grant execute on function " + fn + " to authenticated");
      await assert.rejects(
        () => mockBasemapContract(status.databaseUrl),
        { name: "AssertionError" },
        "Caller privilege widening must fail",
      );
    } finally {
      await sql.unsafe(
        "revoke execute on function " + fn + " from authenticated",
      );
    }
    const rollback = new Error("rollback-only policy negatives");
    for (const mutation of [
      "alter table private.mock_basemap_config disable row level security",
      "grant select on private.mock_basemap_config to anon",
      "alter function " + fn + " reset search_path",
      "create function private.auto03_hidden_trigger() returns trigger language plpgsql as $$begin return new;end$$;create trigger auto03_hidden before update on private.mock_basemap_config for each row execute function private.auto03_hidden_trigger()",
    ]) {
      try {
        await sql.begin(async (tx) => {
          const a = (await tx.unsafe(effectCatalogQuery))[0].catalog;
          await tx.unsafe(mutation);
          const b = (await tx.unsafe(effectCatalogQuery))[0].catalog;
          assert.throws(() =>
            assertBoundedCatalog(a, b, {
              classification: "private-additive-candidate",
            }),
          );
          throw rollback;
        });
      } catch (error) {
        if (error !== rollback) throw error;
      }
    }
    await sql.unsafe("notify pgrst, 'reload schema'");
    await new Promise((r) => setTimeout(r, 1000));
    const effective = (await sql.unsafe(effectCatalogQuery))[0].catalog;
    await realActorServiceDenials(
      status,
      effective.functions.filter(
        (f) =>
          f.id.startsWith("public.reserve_mock_basemap") ||
          f.id.startsWith("public.finish_mock_basemap"),
      ),
    );
  } finally {
    if (fixtureSql)
      await sql.begin(async (tx) => {
        await tx.unsafe(original);
        await tx.unsafe(
          "drop function public.reserve_mock_basemap_tile_v1(text,text,integer,integer,integer,boolean),public.finish_mock_basemap_tile_v1(integer,integer,integer,uuid,text);drop function private.reserve_basemap_tile_internal_v3(uuid,text,text,integer,integer,integer,boolean),private.reserve_mock_map_provider_v1(text,text,boolean);drop table private.mock_basemap_claims,private.mock_basemap_config",
        );
      });
    if (fixtureSql)
      assert.deepEqual(
        catalogEffects(
          before,
          (await sql.unsafe(effectCatalogQuery))[0].catalog,
        ),
        [],
        "Disposable untrusted input left no schema/security changes",
      );
    await sql.end({ timeout: 5 });
  }
  return true;
}
