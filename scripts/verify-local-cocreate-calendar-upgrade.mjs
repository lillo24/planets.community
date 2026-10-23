import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";

// Rollback-only rehearsal from the immutable CAL01-installed main predecessor.
// Warm its exact readers, then apply the actual forward correction source.
assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit disposable CAL01 rehearsal opt-in required.",
);
const { sql } = openCocreateLocalBackend();
const migration = readFileSync(
  "supabase/migrations/20261023155513_cocreate_calendar_corrections.sql",
  "utf8",
);
const predecessor = "fef1c343501a43712f997aca269a09ca6f245b75";
const installedCalendar = execFileSync(
  "git",
  [
    "show",
    `${predecessor}:supabase/migrations/20261023113719_cocreate_community_calendar_v1.sql`,
  ],
  { encoding: "utf8" },
);
const calendarBody = installedCalendar
  .slice(
    installedCalendar.indexOf(
      "create function public.get_cocreate_calendar_v1(",
    ),
    installedCalendar.indexOf(
      "\nrevoke all on function public.get_cocreate_calendar_v1",
    ),
  )
  .replace("create function public.", "create or replace function public.");
const rollback = new Error("CAL01 successful qualification rollback");
let evidence;
try {
  await sql.begin("isolation level repeatable read", async (tx) => {
    await tx.unsafe(
      "drop function if exists public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid); drop function if exists private.cocreate_can_join_recruitment(uuid,uuid)",
    );
    await tx.unsafe(calendarBody);
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
    await tx`select public.schedule_cocreate_meeting(${actor}::uuid,${randomUUID()}::uuid,${hub}::uuid,clock_timestamp()+interval '3 days',7)`;
    async function readers() {
      const [r] = await tx`select
        public.get_cocreate_current_meeting(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) current,
        public.get_own_cocreate_recruitment(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) legacy,
        public.get_own_cocreate_recruitment_v2(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) dated,
        public.get_cocreate_recruitment_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${meeting.recruitment_id}::uuid) exact,
        public.get_cocreate_room_page_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed2,
        public.get_cocreate_room_page_v3(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed3,
        public.get_cocreate_calendar_v1(${actor}::uuid,${hub}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,
          date_trunc('day',statement_timestamp()),date_trunc('day',statement_timestamp())+interval '31 days',1) calendar`;
      assert.equal(Object.keys(r.legacy).length, 9);
      assert.equal(Object.keys(r.dated).length, 11);
      return r;
    }
    const warmed = await readers();
    assert.ok(
      warmed.calendar.next_cursor,
      "warm a real installed chronological cursor",
    );
    async function continuation() {
      const [r] =
        await tx`select public.get_cocreate_calendar_v1(${actor}::uuid,${hub}::uuid,
        ${member.room_id}::uuid,${member.episode_id}::uuid,date_trunc('day',statement_timestamp()),
        date_trunc('day',statement_timestamp())+interval '31 days',1,${warmed.calendar.next_cursor}) page`;
      return r.page;
    }
    const warmedContinuation = await continuation();
    async function functions() {
      return tx`select oid::text,proacl,pg_get_functiondef(oid) source,pg_get_function_result(oid) result
        from pg_proc where pronamespace='public'::regnamespace
        and proname not in('get_cocreate_calendar_v1','get_cocreate_recruitment_review_v1') order by oid`;
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
    const [calendarContract] =
      await tx`select oid::text,proacl,provolatile,prosecdef,proconfig,
      pg_get_function_identity_arguments(oid) signature,pg_get_function_arguments(oid) defaults,
      pg_get_function_result(oid) result from pg_proc
      where oid='public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text)'::regprocedure`;
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
      await continuation(),
      warmedContinuation,
      "installed signed cursor remains usable after replacement",
    );
    assert.deepEqual(
      await tables(),
      beforeTables,
      "all populated canonical rows unchanged",
    );
    const [afterCalendar] =
      await tx`select oid::text,proacl,provolatile,prosecdef,proconfig,
      pg_get_function_identity_arguments(oid) signature,pg_get_function_arguments(oid) defaults,
      pg_get_function_result(oid) result from pg_proc where oid=${calendarContract.oid}::oid`;
    assert.deepEqual(
      afterCalendar,
      calendarContract,
      "calendar OID, ACL, stability, definer, path, signature/defaults and result preserved",
    );
    await tx.unsafe(
      migration.replace(/create function /g, "create or replace function "),
    );
    assert.deepEqual(
      await readers(),
      warmed,
      "repeat forward body installation preserves all warmed contracts",
    );
    assert.deepEqual(
      await tables(),
      beforeTables,
      "repeat installation preserves all populated rows",
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
      installed_predecessor: predecessor,
      calendar_contract_preserved: true,
      installed_cursor_preserved: true,
      populated_tables_preserved: beforeTables.length,
      installed_functions_preserved: beforeFunctions.length,
      warmed_readers_preserved: 7,
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
  `CAL01-FIX01 populated upgrade preserved ${evidence.populated_tables_preserved} tables / ${evidence.installed_functions_preserved} installed functions / seven warmed readers including CAL01; chronological query ${evidence.execution_ms}ms over 3,000 historical fixtures. All changes rolled back.`,
);
