import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Local synthetic fixtures only. Like the capacity verifier, reset before rerunning.
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl) throw new Error("Local Supabase database URL is missing.");
const sql = postgres(databaseUrl, { max: 6 });

async function asUser(user, operation) {
  return sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${user}, true)`;
    await tx.unsafe("set local role authenticated");
    return operation(tx);
  });
}
async function attempt(operation) {
  try {
    return { ok: true, value: await operation() };
  } catch (error) {
    if (error?.code !== "PT409") throw error;
    return { ok: false, code: error.code };
  }
}
async function fixture(role = "co_organizer") {
  const owner = randomUUID(),
    target = randomUUID(),
    newcomer = randomUUID();
  const project = randomUUID(),
    requests = [randomUUID(), randomUUID()];
  await sql.begin(async (tx) => {
    for (const [id, name] of [
      [owner, "Owner"],
      [target, "Target"],
      [newcomer, "Newcomer"],
    ]) {
      await tx`insert into auth.users(id,email) values (${id}::uuid, ${`people-${id}@planets.invalid`})`;
      await tx`insert into public.profiles(id,display_name) values (${id}::uuid, ${name})`;
    }
    await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
      values (${project}::uuid,${owner}::uuid,'published','People concurrency fixture',
        now()+interval '1 day',now()+interval '2 days',now())`;
    await tx`update public.projects set registration_capacity=1 where id=${project}::uuid`;
    for (const [id, requester] of [
      [requests[0], target],
      [requests[1], newcomer],
    ]) {
      await tx`insert into public.project_join_requests(id,project_id,requester_profile_id)
        values (${id}::uuid,${project}::uuid,${requester}::uuid)`;
    }
  });
  const [member] = await asUser(
    owner,
    (tx) =>
      tx`select public.accept_project_join_request_as_manager(${owner}::uuid,${requests[0]}::uuid) as id`,
  );
  const [offer] = await asUser(
    owner,
    (tx) =>
      tx`select public.create_project_role_offer(${owner}::uuid,${project}::uuid,${member.id}::uuid,${role}) as id`,
  );
  return {
    owner,
    target,
    newcomer,
    project,
    membership: member.id,
    offer: offer.id,
    request: requests[1],
  };
}
function accept(f) {
  return asUser(
    f.target,
    (tx) =>
      tx`select public.accept_project_role_offer(${f.target}::uuid,${f.offer}::uuid) as id`,
  );
}
function leave(f) {
  return asUser(
    f.target,
    (tx) =>
      tx`select public.leave_project(${f.target}::uuid,${f.membership}::uuid)`,
  );
}
async function assertState(f, organizers) {
  const [state] = await sql`select
    (select count(*)::integer from public.project_delegates where project_id=${f.project}::uuid and revoked_at is null) as authorities,
    (select left_at is null and removed_at is null from public.project_memberships where id=${f.membership}::uuid) as current`;
  assert.equal(state.authorities, organizers);
  return state;
}

try {
  // Force both lock orders; these are overlapping transactions, not sequential mocks.
  const leaveFirst = await fixture();
  let queuedAcceptance;
  await sql.begin(async (tx) => {
    await tx`select id from public.projects where id=${leaveFirst.project}::uuid for update`;
    queuedAcceptance = attempt(() => accept(leaveFirst));
    await tx`select set_config('request.jwt.claim.sub', ${leaveFirst.target}, true)`;
    await tx.unsafe("set local role authenticated");
    await tx`select public.leave_project(${leaveFirst.target}::uuid,${leaveFirst.membership}::uuid)`;
  });
  assert.deepEqual(await queuedAcceptance, { ok: false, code: "PT409" });
  assert.equal((await assertState(leaveFirst, 0)).current, false);

  const acceptFirst = await fixture();
  let queuedLeave;
  await asUser(acceptFirst.target, async (tx) => {
    await tx`select public.accept_project_role_offer(${acceptFirst.target}::uuid,${acceptFirst.offer}::uuid)`;
    queuedLeave = leave(acceptFirst);
  });
  await queuedLeave;
  assert.equal((await assertState(acceptFirst, 1)).current, false);

  const duplicate = await fixture();
  const [first, second] = await Promise.all([
    accept(duplicate),
    accept(duplicate),
  ]);
  assert.equal(first[0].id, second[0].id);
  assert.equal((await assertState(duplicate, 1)).current, true);

  const capacity = await fixture();
  const [authority] = await accept(capacity);
  const [stepDown, fill] = await Promise.all([
    attempt(() =>
      asUser(
        capacity.target,
        (tx) =>
          tx`select public.step_down_project_authority(${capacity.target}::uuid,${authority.id}::uuid)`,
      ),
    ),
    attempt(() =>
      asUser(
        capacity.owner,
        (tx) =>
          tx`select public.accept_project_join_request_as_manager(${capacity.owner}::uuid,${capacity.request}::uuid)`,
      ),
    ),
  ]);
  assert.equal(Number(stepDown.ok) + Number(fill.ok), 1);
  assert.equal((await assertState(capacity, fill.ok ? 1 : 0)).current, true);
  const [counts] = await asUser(
    capacity.owner,
    (tx) =>
      tx`select * from public.get_project_capacity_for_manager(${capacity.owner}::uuid,${capacity.project}::uuid)`,
  );
  assert.equal(counts.capacity_used_count, 1);

  const issuerRace = await fixture("co_creator");
  const [issuerAuthority] = await accept(issuerRace);
  const [newMember] = await asUser(
    issuerRace.owner,
    (tx) =>
      tx`select public.accept_project_join_request_as_manager(${issuerRace.owner}::uuid,${issuerRace.request}::uuid) as id`,
  );
  let queuedDemotion, pendingOffer;
  await sql.begin(async (tx) => {
    // Same concrete -> shared ordering as the domain; no inverted lock harness.
    await tx`select id from public.proposals where id=${issuerRace.project}::uuid for update`;
    await tx`select id from public.projects where id=${issuerRace.project}::uuid for update`;
    queuedDemotion = asUser(
      issuerRace.owner,
      (other) =>
        other`select public.change_project_delegate_role(${issuerRace.owner}::uuid,${issuerAuthority.id}::uuid,'co_organizer')`,
    );
    let waiting = false;
    for (let i = 0; i < 100 && !waiting; i++) {
      const [blocked] =
        await sql`select exists(select 1 from pg_stat_activity where wait_event_type='Lock' and query like '%select public.change_project_delegate_role%') as waiting`;
      waiting = blocked.waiting;
      if (!waiting) await new Promise((resolve) => setTimeout(resolve, 10));
    }
    assert.equal(
      waiting,
      true,
      "Competing demotion must be waiting before the offer is created",
    );
    await tx`select set_config('request.jwt.claim.sub',${issuerRace.target},true)`;
    await tx.unsafe("set local role authenticated");
    const [offer] =
      await tx`select public.create_project_role_offer(${issuerRace.target}::uuid,${issuerRace.project}::uuid,${newMember.id}::uuid,'co_organizer') as id`;
    pendingOffer = offer.id;
  });
  await queuedDemotion;
  const [invalidated] =
    await sql`select status, revoked_at>=created_at as valid_time from public.project_delegate_invitations where id=${pendingOffer}::uuid`;
  assert.equal(invalidated.status, "revoked");
  assert.equal(invalidated.valid_time, true);
  console.log(
    "Project People concurrency passed: both leave/accept lock orders, duplicate acceptance, step-down/final-slot and issuer-demotion races preserve canonical authority, membership and offer invalidation.",
  );
} finally {
  await sql.end();
}
