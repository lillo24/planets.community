import assert from "node:assert/strict";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import {
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
  for (const type of ["account_suspension"]) {
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
      "project_chat",
      "resource_chat",
    ]) {
      for (const consequenceFirst of [true, false]) {
        await verifyRace(type, operation, consequenceFirst);
      }
    }
  }
  await verifyReciprocalAdminRace(false);
  await verifyReciprocalAdminRace(true);
  console.log(
    "Suspension concurrency passed: 24 lock-observed winner-order races covering every acceptance role/overload, requests, both durable chat send domains and reciprocal admins; final persisted states asserted.",
  );
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyReciprocalAdminRace(reverse) {
  const fixture = await createConsequenceFixture(sql);
  await sql`update private.moderation_staff_roles set staff_role='admin' where profile_id=${fixture.moderator}::uuid`;
  const cases = {};
  for (const profileId of [fixture.admin, fixture.moderator]) {
    const [row] =
      await sql`insert into private.moderation_cases(state,subject_profile_id,target_kind,target_profile_id)
      values('under_review',${profileId}::uuid,'profile',${profileId}::uuid) returning id`;
    cases[profileId] = row.id;
  }
  const winner = reverse ? fixture.moderator : fixture.admin;
  const loser = reverse ? fixture.admin : fixture.moderator;
  let signalFirst;
  let releaseFirst;
  const acquired = new Promise((resolve) => {
    signalFirst = resolve;
  });
  const release = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const first = asConsequenceActor(sql, winner, async (tx) => {
    await tx`select public.apply_account_suspension(${winner}::uuid,${cases[loser]}::uuid,'Synthetic reason','Synthetic note')`;
    signalFirst();
    await release;
  });
  await Promise.race([
    acquired,
    first.then(() => {
      throw new Error("Reciprocal admin winner did not acquire its barrier.");
    }),
  ]);
  let secondPid;
  const second = asConsequenceActor(sql, loser, async (tx) => {
    [{ pid: secondPid }] = await tx`select pg_backend_pid() as pid`;
    await tx`select public.apply_account_suspension(${loser}::uuid,${cases[winner]}::uuid,'Synthetic reason','Synthetic note')`;
  }).then(
    () => ({ code: undefined }),
    (error) => ({ code: error.code }),
  );
  try {
    const deadline = Date.now() + 10000;
    let waiting = false;
    while (Date.now() < deadline) {
      if (secondPid) {
        const [state] =
          await sql`select wait_event_type from pg_stat_activity where pid=${secondPid}`;
        if (state?.wait_event_type === "Lock") {
          waiting = true;
          break;
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    assert.ok(
      waiting,
      "Reciprocal admin must wait on the sorted shared profile barrier",
    );
  } finally {
    releaseFirst();
  }
  await first;
  assert.equal(
    (await second).code,
    "PT403",
    "Suspended admin cannot finish the reciprocal application",
  );
  const episodes =
    await sql`select affected_profile_id from private.moderation_consequences
    where affected_profile_id in (${winner}::uuid,${loser}::uuid) and consequence_type='account_suspension' and revoked_at is null`;
  assert.deepEqual(
    episodes.map((episode) => episode.affected_profile_id),
    [loser],
    "Exactly the first admin action persists",
  );
}

async function verifyRace(type, operation, consequenceFirst) {
  const fixture = await createConsequenceFixture(sql);
  const resource = operation.startsWith("resource");
  const accept = operation.endsWith("accept");
  const chat = operation.endsWith("_chat");
  let requestId;
  if (accept || chat) requestId = await request(fixture, resource);
  if (chat) {
    await asConsequenceActor(sql, fixture.owner, (tx) =>
      interaction(
        tx,
        fixture,
        resource ? "resource_accept" : "creator_accept",
        requestId,
      ),
    );
    const [row] = resource
      ? await sql`select id from public.resource_request_chats where request_id=${requestId}::uuid`
      : await sql`select id from public.project_group_chats where project_id=${fixture.projectId}::uuid`;
    assert.ok(row, "Winning relationship owns a durable chat");
    fixture.chatId = row.id;
  }
  let signalFirst;
  let releaseFirst;
  const acquired = new Promise((resolve) => {
    signalFirst = resolve;
  });
  const release = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const firstActor = consequenceFirst
    ? fixture.admin
    : actor(fixture, operation);
  const secondActor = consequenceFirst
    ? actor(fixture, operation)
    : fixture.admin;
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
      if (!accept && !chat) requestId = resultId;
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
      "PT403",
      `${type}/${operation}: consequence-first denial`,
    );
  else
    assert.equal(
      result.code,
      undefined,
      `${type}/${operation}: interaction-first consequence succeeds`,
    );
  if (chat) {
    const [count] = resource
      ? await sql`select count(*)::int as value from public.resource_request_chat_messages where chat_id=${fixture.chatId}::uuid`
      : await sql`select count(*)::int as value from public.project_chat_messages where chat_id=${fixture.chatId}::uuid`;
    assert.equal(
      count.value,
      consequenceFirst ? 0 : 1,
      "Messages committed before suspension remain; suspension-first sends cannot cross",
    );
    const [state] = resource
      ? await sql`select status from public.resource_listing_requests where id=${requestId}::uuid`
      : await sql`select status from public.project_join_requests where id=${requestId}::uuid`;
    assert.equal(
      state.status,
      "accepted",
      "Suspension never deletes the accepted relationship",
    );
  } else if (consequenceFirst && !accept) {
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
        ? type === "account_suspension"
          ? "withdrawn"
          : "pending"
        : accept
          ? "accepted"
          : type === "account_suspension"
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
  if (operation === "project_chat") {
    rows =
      await transaction`select message_id as id from public.send_project_chat_message(${fixture.requester}::uuid,${fixture.chatId}::uuid,'Synthetic race Project message')`;
    return rows[0].id;
  }
  if (operation === "resource_chat") {
    rows =
      await transaction`select message_id as id from public.send_resource_request_chat_message(${fixture.requester}::uuid,${fixture.chatId}::uuid,'Synthetic race Resource message')`;
    return rows[0].id;
  }
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

function applyConsequence(tx, fixture) {
  return tx`select public.apply_account_suspension(${fixture.admin}::uuid,${fixture.cases.profile}::uuid,
    'Synthetic race reason','Synthetic private note') as id`;
}
