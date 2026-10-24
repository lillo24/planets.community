import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { cp, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { openA1World } from "./owned-world.mjs";

const { directory, sql } = await openA1World(process.argv[2]);
const root = process.cwd();
const filename = (await readdir("supabase/migrations")).find((n) =>
  n.endsWith("_a1_unified_private_conversations.sql"),
);
assert.ok(filename);
const source = await readFile(path.join("supabase/migrations", filename));
const names = [
  ...source
    .toString()
    .matchAll(/create function (public|private)\.([a-z0-9_]+)\(/g),
].map((m) => m[2]);
try {
  const predecessor = await readFile(
    "supabase/migrations/20261022090000_cocreate_hubs_general.sql",
    "utf8",
  );
  let originalHook = predecessor.match(
    /create or replace function private\.cocreate_access_change_signal\(\)[\s\S]*?\$\$;/,
  )?.[0];
  assert.ok(originalHook, "Exact predecessor metadata hook required.");
  // The numbered-groups predecessor extends this body through pg_get_functiondef.
  // Retain that effective erasure behavior too, not just its earlier declaration.
  const numbered = await readFile(
    "supabase/migrations/20261022110000_cocreate_numbered_groups.sql",
    "utf8",
  );
  assert.ok(
    numbered.includes(
      "if new.deleted_at is not null and old.deleted_at is null then perform private.cocreate_end_erased_memberships(new.id);end if;",
    ),
  );
  originalHook = originalHook.replace(
    "begin\n",
    "begin\n if tg_table_name='users' then\n  if new.deleted_at is not null and old.deleted_at is null then perform private.cocreate_end_erased_memberships(new.id);end if;\n end if;\n",
  );
  await sql.unsafe(originalHook);
  const history =
    await sql`select version from supabase_migrations.schema_migrations order by version`;
  assert.ok(
    history.every((m) => m.version <= filename.slice(0, 14)),
    "Unexpected later history in this owned rehearsal.",
  );
  // Rehearsal-only rewind of this unshared disposable stack, as with the repo's
  // other populated-upgrade gates. Never used by a shared/hosted writer.
  await sql`delete from supabase_migrations.schema_migrations where version=${filename.slice(0, 14)}`;
  // This disposable development stack may already contain A1 iteration. Remove
  // only objects declared by THIS migration; retain every original source row.
  const functions =
    await sql`select p.oid,p.oid::regprocedure::text signature from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where (n.nspname='private' and p.proname like 'a1_%')
      or (n.nspname='public' and p.proname=any(${names}))`;
  const triggers =
    await sql`select t.tgname,t.tgrelid::regclass::text relation from pg_trigger t where t.tgfoid=any(${functions.map((f) => f.oid)})`;
  for (const t of triggers)
    await sql.unsafe(`drop trigger ${t.tgname} on ${t.relation}`);
  for (const f of functions) await sql.unsafe(`drop function ${f.signature}`);
  for (const table of ["a1_read_snapshots", "a1_send_receipts"])
    await sql.unsafe(`drop table if exists private.${table}`);
  const indexes =
    await sql`select c.oid::regclass::text name from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where c.relkind='i' and n.nspname='private' and c.relname like 'a1_%'`;
  for (const i of indexes) await sql.unsafe(`drop index ${i.name}`);
  const before = await inventory();
  const functionsBefore =
    await sql`select p.oid::text id,p.oid::regprocedure::text signature,pg_get_functiondef(p.oid) definition,
    p.proacl::text acl,p.proconfig::text configuration from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in('public','private') order by p.oid`;
  assert.ok(
    before.reduce((sum, t) => sum + t.rows, 0) > 20,
    "Populate genuine Auth/source/Storage fixtures before rehearsal.",
  );
  await cp(
    path.join(root, "supabase/migrations", filename),
    path.join(directory, "supabase/migrations", filename),
  );
  const environment = {
    ...process.env,
    ...JSON.parse(
      await readFile(path.join(directory, "private-environment.json"), "utf8"),
    ),
  };
  function migrate() {
    const result = spawnSync(
      process.execPath,
      [
        path.join(root, "node_modules/supabase/dist/supabase.js"),
        "migration",
        "up",
        "--local",
        "--workdir",
        directory,
      ],
      {
        env: environment,
        encoding: "utf8",
        timeout: 180000,
        maxBuffer: 8 * 1024 * 1024,
      },
    );
    assert.equal(
      result.status,
      0,
      `A1 owned CLI forward replay failed: ${result.stderr}`,
    );
    return result.stdout;
  }
  migrate();
  const [installed] =
    await sql`select to_regprocedure('public.get_own_private_pair_page_v1(uuid,uuid,integer,timestamptz,text,uuid)') is not null api,
    to_regclass('private.a1_read_snapshots') is not null receipts`;
  assert.equal(installed.api, true);
  assert.equal(installed.receipts, true);
  const after = await inventory();
  for (const original of before)
    assert.deepEqual(
      after.find((t) => t.name === original.name),
      original,
      `Original columns/rows changed: ${original.name}`,
    );
  for (const original of functionsBefore) {
    const [current] =
      await sql`select p.oid::text id,p.oid::regprocedure::text signature,pg_get_functiondef(p.oid) definition,
      p.proacl::text acl,p.proconfig::text configuration from pg_proc p where p.oid=${original.id}::oid`;
    if (original.signature === "private.cocreate_access_change_signal()") {
      const expected = original.definition.replace(
        "\n else\n",
        "\n else\n  perform private.a1_emit_identity_hint(new.id);\n",
      );
      assert.notEqual(expected, original.definition);
      assert.deepEqual(
        current,
        { ...original, definition: expected },
        "Only the exact private metadata hint call may extend the existing hook.",
      );
    } else
      assert.deepEqual(
        current,
        original,
        `Original installed function changed: ${original.signature}`,
      );
  }
  migrate();
  const applied =
    await sql`select version from supabase_migrations.schema_migrations where version=${filename.slice(0, 14)}`;
  assert.equal(applied.length, 1);
  const proof = {
    migration: filename,
    sha256: createHash("sha256").update(source).digest("hex"),
    original_tables: before.length,
    original_rows: before.reduce((s, t) => s + t.rows, 0),
    original_functions: functionsBefore.length,
    original_columns_and_values_preserved: true,
    installed_oids_acl_preserved: true,
    original_domain_reader_writer_bodies_preserved: true,
    exact_private_metadata_hook_extension: true,
    actual_cli_forward_apply: true,
    actual_cli_noop_retry: true,
    source_message_storage_unchanged: true,
    hosted_operations: false,
  };
  await writeFile(
    path.join(directory, "upgrade-proof.json"),
    JSON.stringify(proof, null, 2) + "\n",
  );
  console.log(JSON.stringify(proof));
} finally {
  await sql.end({ timeout: 5 });
}

async function inventory() {
  const tables =
    await sql`select format('%I.%I',n.nspname,c.relname) name,c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in('public','private','auth','storage') and c.relkind='r' order by 1`;
  const result = [];
  for (const t of tables) {
    const columns =
      await sql`select attname,atttypid::text type,attnotnull,attgenerated,attidentity,attcollation::text collation
      from pg_attribute where attrelid=${t.oid} and attnum>0 and not attisdropped order by attnum`;
    const [row] = await sql.unsafe(
      `select count(*)::int rows,md5(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),'')) digest from ${t.name} t`,
    );
    result.push({ name: t.name, columns, ...row });
  }
  return result;
}
