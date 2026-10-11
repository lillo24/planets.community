import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Destructive only to an explicitly selected, disposable, loopback QA stack.
assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Disposable QA consent required",
);
const config = await readFile("supabase/config.toml", "utf8");
assert.ok(
  !config.includes('project_id = "planets-community"'),
  "Do not reset the retained default stack",
);
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
assert.ok(
  ["127.0.0.1", "localhost", "[::1]"].includes(new URL(databaseUrl).hostname),
);
function cli(args, expectSuccess = true) {
  const result = spawnSync("supabase", args, {
    cwd: process.cwd(),
    encoding: "utf8",
    shell: process.platform === "win32",
    timeout: 240000,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (expectSuccess)
    assert.equal(
      result.status,
      0,
      `CHECK01 ${args[0]} ${args[1]} failed (${result.error?.code ?? result.status})`,
    );
  return result;
}
let db;
try {
  cli(["db", "reset", "--local", "--version", "20261011082932"]);
  db = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const owner = randomUUID(),
    member = randomUUID();
  let project;
  await db.begin(async (sql) => {
    await sql`insert into auth.users(id,email) values(${owner},'check01-upgrade-owner@planets.invalid'),(${member},'check01-upgrade-member@planets.invalid')`;
    await sql`insert into public.profiles(id,display_name) values(${owner},'Synthetic upgrade owner'),(${member},'Synthetic upgrade member')`;
    for (const id of [owner, member])
      await sql`insert into public.profile_photos(profile_id,object_path,audience) values(${id},${id + "/" + randomUUID() + ".webp"},'interactions')`;
    await sql`set local role authenticated`;
    await sql`select set_config('request.jwt.claim.sub',${owner},true)`;
    [project] =
      await sql`select public.create_proposal_draft(${owner}::uuid,'CHECK01 legacy Idea','Synthetic legacy logistics and occupancy','Synthetic description',now()+interval '3 days',now()+interval '5 days','Europe/Rome','IT','Trento',null,'Trento',null,'participants',array[]::uuid[],array[]::text[],2,false) id`;
    await sql`select public.publish_proposal_idea(${owner}::uuid,${project.id}::uuid)`;
    await sql`select set_config('request.jwt.claim.sub',${member},true)`;
    const [request] =
      await sql`select public.request_to_join_project(${member}::uuid,${project.id}::uuid,null) id`;
    await sql`select set_config('request.jwt.claim.sub',${owner},true)`;
    await sql`select public.accept_project_join_request(${owner}::uuid,${request.id}::uuid)`;
  });
  const snapshot = async () =>
    (
      await db`select jsonb_build_object('proposal',to_jsonb(p),'project',to_jsonb(j),'meeting',(select to_jsonb(m) from public.proposal_meeting_details m where m.proposal_id=p.id),'memberships',(select jsonb_agg(to_jsonb(m) order by m.id) from public.project_memberships m where m.project_id=p.id)) state from public.proposals p join public.projects j on j.id=p.id where p.id=${project.id}`
    )[0].state;
  const before = await snapshot();
  assert.equal(before.proposal.definition_phase, "idea");
  assert.equal(before.project.registration_capacity, 2);
  assert.ok(before.memberships.length > 0);
  const blocked = cli(["migration", "up", "--local"], false);
  assert.notEqual(blocked.status, 0, "Legacy rollout must stop");
  assert.match(blocked.stdout + blocked.stderr, /CHECK01 rollout blocked/);
  assert.deepEqual(
    await snapshot(),
    before,
    "Failed migration must preserve legacy logistics/capacity/membership",
  );
  assert.equal(
    (
      await db`select to_regclass('private.project_organization') is null absent`
    )[0].absent,
    true,
  );
  console.log(
    "CHECK01 upgrade: populated legacy Idea blocked; canonical logistics, finite capacity and membership unchanged; no partial planner schema.",
  );
} finally {
  if (db) await db.end();
  cli(["db", "reset", "--local"]);
}
console.log(
  "CHECK01 upgrade: clean forward replay restored on the disposable stack.",
);
