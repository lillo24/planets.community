import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";

assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit owned-local populated upgrade opt-in required.",
);
const { sql } = openCocreateLocalBackend();
const predecessor = "04c63e5fb6ac08fb72a2b395f247be5bcdc3cb3c"; // Current main: CAL01-FIX01 and RADAR01 installed.
const migrationPath =
  "supabase/migrations/20261024072459_cocreate_reusable_places.sql";
const migration = readFileSync(migrationPath, "utf8");
const installed = (path) =>
  execFileSync("git", ["show", `${predecessor}:${path}`], {
    encoding: "utf8",
  }).replaceAll("\r\n", "\n");
const foundation = installed(
  "supabase/migrations/20261008124856_geoapify_shared_location_foundation.sql",
);
const lock = foundation
  .slice(
    foundation.indexOf("create function private.lock_location_item("),
    foundation.indexOf("\nrevoke all on function private.lock_location_item"),
  )
  .replace("create function", "create or replace function");
const location02 = installed(
  "supabase/migrations/20261010131622_proposal_inline_location_privacy.sql",
);
const reserve = location02.slice(
  location02.indexOf(
    "create or replace function public.reserve_location_search_v1(",
  ),
  location02.indexOf("-- One-time directions"),
);
const names = [
  ...migration.matchAll(
    /create (?:or replace )?function (public|private)\.([a-z0-9_]+)\(/g,
  ),
]
  .map((m) => [m[1], m[2]])
  .filter(
    ([, name]) =>
      !["lock_location_item", "reserve_location_search_v1"].includes(name),
  );
const rolledBack = new Error("PLACE01 successful qualification rollback");
let evidence;
try {
  await sql.begin("isolation level repeatable read", async (tx) => {
    // Rollback-only remove precisely PLACE01 additions. Restore the ACTUAL pinned
    // installed scope bodies/constraint, never an invented predecessor reader.
    for (const [schema, name] of names) {
      const functions =
        await tx`select oid::regprocedure::text signature from pg_proc where pronamespace=${schema}::regnamespace and proname=${name}`;
      for (const f of functions)
        await tx.unsafe(`drop function ${f.signature}`);
    }
    await tx.unsafe(
      "drop table private.cocreate_meeting_places,private.cocreate_room_places,private.cocreate_place_receipts,private.cocreate_places",
    );
    await tx`delete from private.location_search_batches where item_kind in ('cocreate_hub','cocreate_room')`;
    await tx.unsafe(
      "alter table private.location_search_batches drop constraint location_search_batches_item_kind_check; alter table private.location_search_batches add constraint location_search_batches_item_kind_check check(item_kind in ('one_time','recurring','resource'))",
    );
    await tx.unsafe(lock);
    await tx.unsafe(reserve);
    await tx`update private.cocreate_settings set enabled=true`;
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    for (const id of ids) {
      await tx`insert into auth.users(id,email) values(${id}::uuid,${`place-upgrade-${id}@planets.invalid`})`;
      await tx`insert into public.profiles(id,display_name) values(${id}::uuid,'Synthetic Place upgrade')`;
      await tx`insert into private.policy_acceptances(account_id,bundle_version) values(${id}::uuid,'POLICY01-2026-10-08-v1')`;
    }
    const [actor, joiner] = ids;
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const [{ p }] =
      await tx`select public.propose_cocreate_community(${actor}::uuid,${randomUUID()}::uuid,'sports',${`Synthetic Place upgrade ${actor}`},'Synthetic upgrade locality') p`;
    for (const id of ids.slice(1)) {
      await tx`select set_config('request.jwt.claim.sub',${id},true)`;
      await tx`select public.mutate_cocreate_community_interest(${id}::uuid,${randomUUID()}::uuid,${p.proposal_id}::uuid,'interest')`;
    }
    const [{ hub }] =
      await tx`select public.get_cocreate_community_proposal(${p.proposal_id}::uuid)->>'hub_id' hub`;
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const [{ member }] =
      await tx`select public.mutate_cocreate_hub(${actor}::uuid,${randomUUID()}::uuid,${hub}::uuid,'join') member`;
    const scheduleCommand = randomUUID(),
      starts = new Date(Date.now() + 2 * 86400000).toISOString();
    const [{ meeting }] =
      await tx`select public.schedule_cocreate_meeting(${actor}::uuid,${scheduleCommand}::uuid,${hub}::uuid,${starts}::timestamptz,7) meeting`;
    await tx`select public.schedule_cocreate_meeting(${actor}::uuid,${randomUUID()}::uuid,${hub}::uuid,clock_timestamp()+interval '3 days',7)`;
    await tx`select set_config('request.jwt.claim.sub',${joiner},true)`;
    await tx`select public.mutate_cocreate_hub(${joiner}::uuid,${randomUUID()}::uuid,${hub}::uuid,'join')`;
    const joinCommand = randomUUID();
    const [{ joined }] =
      await tx`select public.join_cocreate_recruitment(${joiner}::uuid,${joinCommand}::uuid,${hub}::uuid,${meeting.room_id}::uuid,${meeting.recruitment_id}::uuid) joined`;
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const windowStart = new Date().toISOString(),
      windowEnd = new Date(Date.now() + 31 * 86400000).toISOString();
    async function readers() {
      const [r] = await tx`select
    public.get_cocreate_current_meeting(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) current,
    public.get_own_cocreate_recruitment(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) legacy,
    public.get_own_cocreate_recruitment_v2(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) dated,
    public.get_cocreate_recruitment_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${meeting.recruitment_id}::uuid) exact,
    public.get_cocreate_recruitment_review_v1(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${meeting.recruitment_id}::uuid) review,
    public.get_cocreate_room_page_v2(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed2,
    public.get_cocreate_room_page_v3(${actor}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid) feed3,
    public.get_cocreate_calendar_v1(${actor}::uuid,${hub}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${windowStart}::timestamptz,${windowEnd}::timestamptz,1) calendar`;
      assert.equal(Object.keys(r.legacy).length, 9);
      assert.equal(Object.keys(r.dated).length, 11);
      assert.equal(Object.keys(r.review).length, 6);
      assert.equal(Object.keys(r.calendar.meetings[0]).length, 12);
      return r;
    }
    const warmed = await readers();
    assert.ok(warmed.calendar.next_cursor);
    async function continuation() {
      const [r] =
        await tx`select public.get_cocreate_calendar_v1(${actor}::uuid,${hub}::uuid,${member.room_id}::uuid,${member.episode_id}::uuid,${windowStart}::timestamptz,${windowEnd}::timestamptz,1,${warmed.calendar.next_cursor}) page`;
      return r.page;
    }
    const oldContinuation = await continuation();
    const functions =
      await tx`select oid::text,proacl,provolatile,prosecdef,proconfig,pg_get_function_arguments(oid) args,
   pg_get_function_result(oid) result,pg_get_functiondef(oid) source from pg_proc where pronamespace='public'::regnamespace order by oid`;
    async function tables() {
      const result = [];
      const names =
        await tx`select n.nspname schema,c.relname name from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','private') and c.relkind in('r','p') order by n.nspname,c.relname`;
      for (const { schema, name } of names) {
        const [r] =
          await tx`select count(*)::integer rows,md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,'[]')) digest from ${tx(schema + "." + name)} t`;
        result.push({ schema, name, ...r });
      }
      return result;
    }
    const before = await tables();
    await tx.unsafe(migration);
    assert.deepEqual(
      await readers(),
      warmed,
      "all eight installed warm readers retain exact results",
    );
    assert.deepEqual(
      await continuation(),
      oldContinuation,
      "installed signed continuation remains valid",
    );
    const afterFunctions =
      await tx`select oid::text,proacl,provolatile,prosecdef,proconfig,pg_get_function_arguments(oid) args,
   pg_get_function_result(oid) result,pg_get_functiondef(oid) source from pg_proc where oid=any(${functions.map((f) => Number(f.oid))}::oid[]) order by oid`;
    assert.equal(afterFunctions.length, functions.length);
    for (let i = 0; i < functions.length; i++) {
      const old = functions[i],
        current = afterFunctions[i];
      if (old.source.includes("FUNCTION public.reserve_location_search_v1(")) {
        const { source: _old, ...oldContract } = old,
          { source: _new, ...newContract } = current;
        assert.deepEqual(newContract, oldContract);
      } else
        assert.deepEqual(
          current,
          old,
          "old public function OID/ACL/source/signature/result retained",
        );
    }
    const after = await tables();
    assert.deepEqual(
      after.filter((t) =>
        before.some((b) => b.schema === t.schema && b.name === t.name),
      ),
      before,
      "all installed populated table rows/digests retained",
    );
    assert.equal(after.length, before.length + 4);
    const [{ retry }] =
      await tx`select public.schedule_cocreate_meeting(${actor}::uuid,${scheduleCommand}::uuid,${hub}::uuid,${starts}::timestamptz,7) retry`;
    assert.deepEqual(
      retry,
      meeting,
      "installed scheduling exact receipt remains valid",
    );
    await tx`select set_config('request.jwt.claim.sub',${joiner},true)`;
    const [{ retry: joinRetry }] =
      await tx`select public.join_cocreate_recruitment(${joiner}::uuid,${joinCommand}::uuid,${hub}::uuid,${meeting.room_id}::uuid,${meeting.recruitment_id}::uuid) retry`;
    assert.deepEqual(joinRetry, joined, "installed Join receipt remains valid");
    await tx`select set_config('request.jwt.claim.sub',${actor},true)`;
    const [{ current }] =
      await tx`select public.get_cocreate_current_meeting_v2(${actor}::uuid,${meeting.room_id}::uuid,${meeting.episode_id}::uuid) current`;
    assert.deepEqual(
      current,
      { ...warmed.current, place: null },
      "null Place preserves old meeting behavior exactly",
    );
    evidence = {
      plan: "COCREATE-PLACE01",
      predecessor,
      source: migrationPath,
      sha256: createHash("sha256").update(migration).digest("hex"),
      populatedTablesPreserved: before.length,
      installedPublicFunctionsPreserved: functions.length,
      allowedExistingBodyChange:
        "reserve_location_search_v1 (same OID/ACL/signature; co-creation scope only)",
      warmedReaders: 8,
      oldCalendarCursorRetained: true,
      closedRecruitmentFields: [9, 11],
      closedReviewFields: 6,
      oldSchedulingAndJoinReceiptsRetained: true,
      nullPlaceBehaviorPreserved: true,
      otherLocationDomainsUnchanged: true,
      rollbackOnly: true,
    };
    throw rolledBack;
  });
} catch (error) {
  if (error !== rolledBack) throw error;
} finally {
  await sql.end();
}
assert.ok(
  evidence,
  "Populated upgrade did not produce qualification evidence.",
);
mkdirSync("build/place01", { recursive: true });
writeFileSync(
  "build/place01/upgrade.json",
  JSON.stringify(evidence, null, 2) + "\n",
);
console.log(JSON.stringify(evidence));
