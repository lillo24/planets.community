import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";

// This owned-loopback rehearsal rolls back ALL fixture/DDL changes. It removes
// only CAL01's two new objects inside the transaction to reconstruct its exact
// main predecessor, warms installed readers, then applies the real source file.
assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit disposable CAL01 rehearsal opt-in required.",
);
const { sql } = openCocreateLocalBackend();
const migration = readFileSync(
  "supabase/migrations/20261023113719_cocreate_community_calendar_v1.sql",
  "utf8",
);
const rollback = new Error("CAL01 successful qualification rollback");
let evidence;
try {
  await sql.begin("isolation level repeatable read", async (tx) => {
    await tx.unsafe(
      "drop function public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text); drop index private.cocreate_meetings_calendar",
    );
    await tx`update private.cocreate_settings set enabled=true`;
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    for (const id of ids) {
      await tx`insert into auth.users(id,email) values(${id}::uuid,${`calendar-upgrade-${id}@planets.invalid`})`;
      await tx`insert into public.profiles(id,display_name) values(${id}::uuid,'Synthetic calendar upgrade')`;
      await tx`insert into private.policy_acceptances(account_id,bundle_version) values(${id}::uuid,'POLICY01-2026-10-08-v1')`;
    }
    const actor = ids[0];
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const [{ p }] =
      await tx`select public.propose_cocreate_community(${actor}::uuid,${randomUUID()}::uuid,'videogames',${`Synthetic calendar upgrade ${actor}`},'Synthetic upgrade locality') p`;
    for (const supporter of ids.slice(1)) {
      await tx`select set_config('request.jwt.claim.sub',${supporter},true)`;
      await tx`select public.mutate_cocreate_community_interest(${supporter}::uuid,${randomUUID()}::uuid,${p.proposal_id}::uuid,'interest')`;
    }
    const [{ hub }] =
      await tx`select public.get_cocreate_community_proposal(${p.proposal_id}::uuid)->>'hub_id' hub`;
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const [{ member }] =
      await tx`select public.mutate_cocreate_hub(${actor}::uuid,${randomUUID()}::uuid,${hub}::uuid,'join') member`;
    const [{ meeting }] =
      await tx`select public.schedule_cocreate_meeting(${actor}::uuid,${randomUUID()}::uuid,${hub}::uuid,clock_timestamp()+interval '2 days',7) meeting`;
    async function readers() {
      const [r] = await tx`select
        public.get_cocreate_current_meeting(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) current,
        public.get_own_cocreate_recruitment(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) legacy,
        public.get_own_cocreate_recruitment_v2(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) dated,
        public.get_cocreate_recruitment_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${meeting.recruitment_id}::uuid) exact,
        public.get_cocreate_room_page_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed2,
        public.get_cocreate_room_page_v3(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed3`;
      assert.equal(Object.keys(r.legacy).length, 9);
      assert.equal(Object.keys(r.dated).length, 11);
      return r;
    }
    const warmed = await readers();
    async function functions() {
      return tx`select oid::text,proacl,pg_get_functiondef(oid) source,pg_get_function_result(oid) result
        from pg_proc where pronamespace='public'::regnamespace
        and proname<>'get_cocreate_calendar_v1' order by oid`;
    }
    async function tables() {
      const result = [];
      const names =
        await tx`select n.nspname schema,c.relname name from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where n.nspname in('public','private') and c.relkind in('r','p') order by n.nspname,c.relname`;
      for (const { schema, name } of names) {
        const [r] =
          await tx`select count(*)::integer rows,md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,'[]')) digest from ${tx(schema + "." + name)} t`;
        result.push({ schema, name, ...r });
      }
      return result;
    }
    const beforeFunctions = await functions(),
      beforeTables = await tables();
    await tx.unsafe(migration);
    assert.deepEqual(
      await functions(),
      beforeFunctions,
      "installed function OIDs, ACLs, source and results unchanged",
    );
    assert.deepEqual(
      await readers(),
      warmed,
      "warmed installed payloads and ACK tokens unchanged",
    );
    assert.deepEqual(
      await tables(),
      beforeTables,
      "all populated canonical rows unchanged",
    );

    // Many plausible historical occurrences make the bounded future-window
    // access path representative. They remain inside this rollback transaction.
    await tx`insert into private.cocreate_meetings(room_id,creator_id,created_at,starts_at,capacity)
      select ${meeting.room_id}::uuid,${actor}::uuid,statement_timestamp()-make_interval(days=>n)-interval '1 hour',
        statement_timestamp()-make_interval(days=>n),7 from generate_series(1,3000)n`;
    await tx.unsafe("analyze private.cocreate_meetings");
    const start = new Date(),
      end = new Date(start.getTime() + 31 * 86400000);
    const quote = (v) => `'${String(v).replaceAll("'", "''")}'`;
    const replacements = {
      "episode.exit_sequence": "null::bigint",
      actor: `${quote(actor)}::uuid`,
      p_hub_id: `${quote(hub)}::uuid`,
      p_general_room_id: `${quote(member.room_id)}::uuid`,
      p_window_start: `${quote(start.toISOString())}::timestamptz`,
      p_window_end: `${quote(end.toISOString())}::timestamptz`,
      p_limit: "25",
      after_id: "null::uuid",
      after_at: "null::timestamptz",
      memberships: "1",
    };
    let query = migration
      .slice(
        migration.indexOf(" with eligible as materialized ("),
        migration.indexOf("\n if jsonb_array_length(rows)"),
      )
      .replace(" into rows from projected", " from projected");
    assert.ok(
      query.startsWith(" with eligible as materialized ("),
      "explain the actual reader query",
    );
    for (const [name, value] of Object.entries(replacements)) {
      query = query.replaceAll(
        new RegExp(
          `(?<![a-zA-Z_0-9])${name.replaceAll(".", "\\.")}(?![a-zA-Z_0-9])`,
          "g",
        ),
        value,
      );
    }
    const [plan] = await tx.unsafe(
      `explain (analyze,buffers,format json) ${query}`,
    );
    const detail = plan["QUERY PLAN"][0],
      indexes = new Set();
    function walk(node) {
      if (node == null || typeof node !== "object") return;
      if (node["Index Name"]) indexes.add(node["Index Name"]);
      for (const value of Object.values(node)) {
        if (Array.isArray(value)) value.forEach(walk);
        else walk(value);
      }
    }
    walk(detail.Plan);
    assert.ok(
      indexes.has("cocreate_meetings_calendar"),
      "actual calendar query uses the chronological window index",
    );
    evidence = {
      migration_sha256: createHash("sha256").update(migration).digest("hex"),
      populated_tables_preserved: beforeTables.length,
      installed_functions_preserved: beforeFunctions.length,
      warmed_readers_preserved: 6,
      legacy_card_fields: 9,
      dated_card_fields: 11,
      historical_fixture_meetings: 3000,
      query_indexes: [...indexes].sort(),
      planning_ms: detail["Planning Time"],
      execution_ms: detail["Execution Time"],
      rollback: true,
      hosted_changes: false,
    };
    throw rollback;
  });
} catch (error) {
  if (error !== rollback) throw error;
} finally {
  await sql.end();
}
assert.ok(evidence, "qualification produced complete evidence");
mkdirSync("build/cocreate-cal01", { recursive: true });
writeFileSync(
  "build/cocreate-cal01/qualification.json",
  JSON.stringify(evidence, null, 2) + "\n",
);
console.log(
  `CAL01 populated upgrade preserved ${evidence.populated_tables_preserved} tables / ${evidence.installed_functions_preserved} functions / six warmed readers; chronological query ${evidence.execution_ms}ms over 3,000 historical fixtures. All changes rolled back.`,
);
