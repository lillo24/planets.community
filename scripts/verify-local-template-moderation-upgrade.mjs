import assert from "node:assert/strict";
import { readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (
  !databaseUrl ||
  !["localhost", "127.0.0.1", "[::1]"].includes(new URL(databaseUrl).hostname)
)
  throw new Error("TW02 upgrade rehearsal requires a local database.");
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
const checkpoint = join(
  tmpdir(),
  "planets-tw02-upgrade-" + new URL(databaseUrl).port + ".json",
);
const reporter = "e2200000-0000-4000-8000-000000000001";
const subject = "e2200000-0000-4000-8000-000000000002";
const staff = "e2200000-0000-4000-8000-000000000004";
async function snapshot() {
  const rows =
    await sql`select 'reports' as kind,id,to_jsonb(r) as value from private.moderation_reports r
    union all select 'cases',id,to_jsonb(c)-'target_proposal_template_id'-'template_source_proposal_id'-'template_report_content_version' from private.moderation_cases c
    union all select 'notes',id,to_jsonb(n) from private.moderation_case_notes n
    union all select 'events',id,to_jsonb(e) from private.moderation_case_events e order by kind,id`;
  return Array.from(rows);
}
try {
  const [{ present }] =
    await sql`select to_regclass('private.proposal_template_removal_actions') is not null as present`;
  if (process.argv[2] === "--before") {
    assert.equal(
      present,
      false,
      "before rehearsal must run on exact pre-TW02 schema",
    );
    await sql`insert into auth.users(id,email) values(${reporter}::uuid,'tw02-upgrade-reporter@planets.invalid'),(${subject}::uuid,'tw02-upgrade-subject@planets.invalid'),(${staff}::uuid,'tw02-upgrade-staff@planets.invalid') on conflict(id) do nothing`;
    await sql`insert into public.profiles(id,display_name) values(${reporter}::uuid,'TW02 upgrade reporter'),(${subject}::uuid,'TW02 upgrade subject'),(${staff}::uuid,'TW02 upgrade staff') on conflict(id) do nothing`;
    await sql`update public.profile_field_visibility set audience='public' where profile_id=${subject}::uuid and field_key='display_name'`;
    await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub',${reporter},true)`;
      await tx.unsafe("set local role authenticated");
      await tx`select * from public.submit_moderation_report(${reporter}::uuid,'e2200000-0000-4000-8000-000000000003'::uuid,'other','Legacy immutable upgrade report.','profile',${subject}::uuid)`;
    });
    await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${staff}::uuid,'moderator')`;
    await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub',${staff},true)`;
      await tx.unsafe("set local role authenticated");
      const [legacyCase] =
        await tx`select case_id from public.list_moderation_cases(${staff}::uuid) where target_kind='profile'`;
      await tx`select * from public.add_moderation_case_note(${staff}::uuid,${legacyCase.case_id}::uuid,'Legacy protected staff note.')`;
      await tx`select * from public.transition_moderation_case(${staff}::uuid,${legacyCase.case_id}::uuid,0::bigint,'under_review')`;
    });
    writeFileSync(checkpoint, JSON.stringify(await snapshot()), "utf8");
    console.log(
      "TW02 upgrade: retained legacy report/case/event checkpoint created on predecessor schema.",
    );
  } else if (process.argv[2] === "--after") {
    assert.equal(
      present,
      true,
      "after rehearsal requires applied TW02 migration",
    );
    assert.deepEqual(
      await snapshot(),
      JSON.parse(readFileSync(checkpoint, "utf8")),
      "all legacy report/case/note/event records survive unchanged",
    );
    const [{ count }] =
      await sql`select count(*)::int as count from private.proposal_template_removal_actions`;
    assert.equal(count, 0, "upgrade fabricates no removal actions/reasons");
    unlinkSync(checkpoint);
    console.log(
      "TW02 upgrade: legacy evidence preserved exactly; zero fabricated template actions.",
    );
  } else
    throw new Error(
      "Use --before on TW01 schema, migrate forward, then --after.",
    );
} finally {
  await sql.end({ timeout: 2 });
}
