import assert from "node:assert/strict";
import postgres from "postgres";
import {
  DEMO_PERSONAS,
  assertSafeLocalDemoTarget,
  exerciseLocalDemoInvitations,
  seedLocalDemoWorld,
  verifyLocalDemoWorld,
} from "./lib/demo-world.mjs";
import { snapshotDemoDomain } from "./lib/demo-participant-invitations.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const status = readLocalSupabaseStatus(repositoryRoot);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
assertSafeLocalDemoTarget({ ...status, mailpitUrl, environment: "local" });
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
const options = { repositoryRoot, status, mailpitUrl, sessionPool: new Map() };

async function snapshot() {
  const people =
    await sql`select id from auth.users where email = any(${Object.values(DEMO_PERSONAS).map((p) => p.email)}::text[])`;
  const ids = people.map((p) => p.id);
  const projects =
    await sql`select id from public.projects where creator_profile_id = any(${ids}::uuid[])`;
  const listings =
    await sql`select id from public.resource_listings where owner_profile_id = any(${ids}::uuid[])`;
  return snapshotDemoDomain(
    sql,
    ids,
    projects.map((p) => p.id),
    listings.map((l) => l.id),
  );
}

try {
  const [existing] = await sql`
    select count(*)::int as count from private.project_participant_admissions admission
    join auth.users identity on identity.id = admission.profile_id where identity.email = any(${Object.values(DEMO_PERSONAS).map((p) => p.email)}::text[])
  `;
  if (existing.count === 0) {
    const injected = new Error(
      "Intentional demo partial-run interruption after canonical admission commit.",
    );
    await assert.rejects(
      seedLocalDemoWorld({
        ...options,
        onInvitationCheckpoint: () => {
          throw injected;
        },
      }),
      (error) => error === injected,
    );
    const before = await snapshot();
    await assert.rejects(
      verifyLocalDemoWorld(options),
      /Invitation demo history is missing or drifted/u,
    );
    assert.deepEqual(
      await snapshot(),
      before,
      "Verification must not repair the interrupted demo.",
    );
    console.log(
      "Confirmed committed partial-run interruption and non-repairing verification.",
    );
  }
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  const first = await snapshot();
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  assert.deepEqual(
    await snapshot(),
    first,
    "Unchanged demo seed duplicated or rewrote canonical history.",
  );
  console.log(
    "Confirmed demo seed → verify → unchanged seed → verify with stable canonical IDs, generations, receipts, episodes, offers, chats, notifications and commitments.",
  );
  const departed = await exerciseLocalDemoInvitations(options);
  const afterDeparture = await snapshot();
  await assert.rejects(
    verifyLocalDemoWorld(options),
    /lacks canonical direct membership provenance/u,
  );
  assert.deepEqual(
    await snapshot(),
    afterDeparture,
    "Verification must not re-admit departed accounts.",
  );
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  for (const ended of departed) {
    const [original] =
      await sql`select left_at, removed_at from public.project_memberships where id = ${ended.membershipId}`;
    const [fresh] =
      await sql`select id from public.project_memberships where project_id = ${ended.projectId} and participant_profile_id = (select id from auth.users where email = ${DEMO_PERSONAS.dario.email}) and left_at is null and removed_at is null`;
    assert.ok(original.left_at || original.removed_at);
    assert.ok(
      fresh && fresh.id !== ended.membershipId,
      "Restoration must create a fresh deliberate episode.",
    );
  }
  const restored = await snapshot();
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  assert.deepEqual(
    await snapshot(),
    restored,
    "Restoration rerun must preserve fresh action/episode identity.",
  );
  console.log(
    "Confirmed full/ended/paused admission failures, same-generation resume, later photo gates, stale receipt non-restoration and fresh explicit seed restoration without duplicate reruns.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
