import assert from "node:assert/strict";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import {
  applyConsequence,
  asConsequenceActor,
  createConsequenceFixture,
} from "./lib/moderation-consequence-fixtures.mjs";

const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl)
  throw new Error(
    "Local database URL is required for consequence race verification.",
  );
const sql = postgres(databaseUrl, { max: 6, onnotice: () => {} });
try {
  for (const type of ["interaction_restriction", "content_hide"]) {
    for (const operation of [
      "project_request",
      "creator_accept",
      "creator_triaged_accept",
      "cocreator_accept",
      "cocreator_triaged_accept",
      "coorganizer_accept",
      "coorganizer_triaged_accept",
      "resource_request",
      "resource_accept",
    ]) {
      for (const consequenceFirst of [true, false]) {
        await verifyRace(type, operation, consequenceFirst);
      }
    }
  }
  await verifyFinalSpot();
  console.log(
    "Consequence concurrency passed: 36 winner-order races covering every acceptance overload and final-spot capacity; final database states asserted.",
  );
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyRace(type, operation, consequenceFirst) {
  const fixture = await createConsequenceFixture(sql);
  const resource = operation.startsWith("resource");
  const accept = operation.endsWith("accept");
  let requestId;
  if (accept) requestId = await request(fixture, resource);
  let signalFirst;
  let releaseFirst;
  const acquired = new Promise((resolve) => {
    signalFirst = resolve;
  });
  const release = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const firstActor = consequenceFirst
    ? fixture.moderator
    : actor(fixture, operation);
  const secondActor = consequenceFirst
    ? actor(fixture, operation)
    : fixture.moderator;
  const first = asConsequenceActor(sql, firstActor, async (transaction) => {
    if (consequenceFirst)
      await applyConsequence(transaction, fixture, type, resource);
    else {
      const resultId = await interaction(
        transaction,
        fixture,
        operation,
        requestId,
      );
      // Project acceptance returns a membership ID, not a new request attempt.
      if (!accept) requestId = resultId;
    }
    signalFirst();
    await release;
  });
  // Failure before signalling must not hang the verifier.
  await Promise.race([
    acquired,
    first.then(() => {
      throw new Error("Race first operation never acquired its barrier.");
    }),
  ]);
  let secondPid;
  const second = asConsequenceActor(sql, secondActor, async (transaction) => {
    [{ pid: secondPid }] = await transaction`select pg_backend_pid() as pid`;
    if (consequenceFirst)
      return interaction(transaction, fixture, operation, requestId);
    await applyConsequence(transaction, fixture, type, resource);
    return null;
  }).then(
    (id) => ({ id }),
    (error) => ({ code: error.code }),
  );
  try {
    const deadline = Date.now() + 10000;
    let waiting = false;
    while (Date.now() < deadline) {
      if (secondPid) {
        const [state] =
          await sql`select wait_event_type from pg_stat_activity where pid = ${secondPid}`;
        if (state?.wait_event_type === "Lock") {
          waiting = true;
          break;
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    assert.ok(
      waiting,
      `${type}/${operation}: second operation must actually wait on a database lock`,
    );
  } finally {
    releaseFirst();
  }
  await first;
  const result = await second;
  if (consequenceFirst)
    assert.equal(
      result.code,
      "PT409",
      `${type}/${operation}: consequence-first denial`,
    );
  else
    assert.equal(
      result.code,
      undefined,
      `${type}/${operation}: interaction-first consequence succeeds`,
    );
  if (consequenceFirst && !accept) {
    const [count] = resource
      ? await sql`select count(*)::int as value from public.resource_listing_requests where listing_id = ${fixture.listingId}::uuid`
      : await sql`select count(*)::int as value from public.project_join_requests where project_id = ${fixture.projectId}::uuid`;
    assert.equal(count.value, 0);
  } else {
    const [state] = resource
      ? await sql`select status from public.resource_listing_requests where id = ${requestId}::uuid`
      : await sql`select status from public.project_join_requests where id = ${requestId}::uuid`;
    assert.equal(
      state.status,
      consequenceFirst
        ? type === "interaction_restriction"
          ? "withdrawn"
          : "pending"
        : accept
          ? "accepted"
          : type === "interaction_restriction"
            ? "withdrawn"
            : "pending",
    );
    if (accept && !consequenceFirst) {
      const [count] = resource
        ? await sql`select count(*)::int as value from public.resource_exchange_agreements where request_id = ${requestId}::uuid`
        : await sql`select count(*)::int as value from public.project_memberships where project_id = ${fixture.projectId}::uuid and participant_profile_id = ${fixture.requester}::uuid and left_at is null and removed_at is null`;
      assert.equal(
        count.value,
        1,
        "Winning acceptance preserves its relationship",
      );
    }
  }
}
function actor(fixture, operation) {
  if (operation.startsWith("creator_") || operation === "resource_accept")
    return fixture.owner;
  if (operation.startsWith("cocreator_")) return fixture.cocreator;
  if (operation.startsWith("coorganizer_")) return fixture.coorganizer;
  return fixture.requester;
}
async function request(fixture, resource) {
  return asConsequenceActor(sql, fixture.requester, (transaction) =>
    interaction(
      transaction,
      fixture,
      resource ? "resource_request" : "project_request",
    ),
  );
}
async function interaction(transaction, fixture, operation, requestId) {
  let rows;
  if (operation === "project_request")
    rows =
      await transaction`select public.request_to_join_project(${fixture.requester}::uuid, ${fixture.projectId}::uuid) as id`;
  else if (operation === "resource_request")
    rows =
      await transaction`select public.request_resource_listing(${fixture.requester}::uuid, ${fixture.listingId}::uuid) as id`;
  else if (operation === "creator_accept")
    rows =
      await transaction`select public.accept_project_join_request(${fixture.owner}::uuid, ${requestId}::uuid) as id`;
  else if (operation === "creator_triaged_accept")
    rows =
      await transaction`select public.accept_project_join_request(${fixture.owner}::uuid, ${requestId}::uuid, '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[]) as id`;
  else if (operation === "resource_accept")
    rows =
      await transaction`select public.accept_resource_listing_request(${fixture.owner}::uuid, ${requestId}::uuid) as id`;
  else if (operation.includes("_triaged_"))
    rows =
      await transaction`select public.accept_project_join_request_as_manager(${actor(fixture, operation)}::uuid, ${requestId}::uuid, '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[]) as id`;
  else
    rows =
      await transaction`select public.accept_project_join_request_as_manager(${actor(fixture, operation)}::uuid, ${requestId}::uuid) as id`;
  return rows[0].id;
}
async function verifyFinalSpot() {
  const fixture = await createConsequenceFixture(sql);
  await sql`update public.projects set registration_capacity = 1 where id = ${fixture.projectId}::uuid`;
  const firstId = await request(fixture, false);
  const secondId = await asConsequenceActor(
    sql,
    fixture.unrelated,
    async (transaction) => {
      const [row] =
        await transaction`select public.request_to_join_project(${fixture.unrelated}::uuid, ${fixture.projectId}::uuid) as id`;
      return row.id;
    },
  );
  const results = await Promise.allSettled(
    [firstId, secondId].map((id) =>
      asConsequenceActor(sql, fixture.cocreator, (transaction) =>
        interaction(transaction, fixture, "cocreator_accept", id),
      ),
    ),
  );
  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    1,
  );
  const failure = results.find((result) => result.status === "rejected");
  assert.equal(failure.reason.code, "PT409");
  const [snapshot] =
    await sql`select * from private.project_registration_capacity_snapshot(${fixture.projectId}::uuid)`;
  assert.equal(snapshot.capacity_used_count, 1);
  const [count] =
    await sql`select count(*)::int as value from private.moderation_consequences where case_id in (${fixture.cases.profile}::uuid, ${fixture.cases.project}::uuid)`;
  assert.equal(count.value, 0);
}
