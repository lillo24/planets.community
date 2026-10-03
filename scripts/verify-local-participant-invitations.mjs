import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Synthetic local fixtures only. Reset before re-running. Tokens are never logged.
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl) throw new Error("Local Supabase database URL is missing.");
const sql = postgres(databaseUrl, {
  max: 8,
  connection: {
    application_name: "pi01-concurrency",
    statement_timeout: 15000,
  },
});
let scenarios = 0;
async function asUser(user, operation) {
  return sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${user}, true)`;
    await tx.unsafe("set local role authenticated");
    return operation(tx);
  });
}
async function attempt(operation) {
  try {
    return { ok: true, rows: await operation() };
  } catch (error) {
    if (!["PT409", "42501", "55000"].includes(error.code)) throw error;
    return { ok: false, code: error.code };
  }
}
async function fixture(countOrganizers = false, kind = "one_time") {
  const f = {
    owner: randomUUID(),
    a: randomUUID(),
    b: randomUUID(),
    c: randomUUID(),
    project: randomUUID(),
    request: randomUUID(),
    action: randomUUID(),
  };
  await sql.begin(async (tx) => {
    for (const id of [f.owner, f.a, f.b, f.c]) {
      await tx`insert into auth.users(id,email) values (${id},${`pi01-race-${id}@planets.invalid`})`;
      await tx`insert into public.profiles(id,display_name) values (${id},'Synthetic PI01 person')`;
    }
    await tx`insert into public.profile_photos(profile_id,object_path,audience)
      values (${f.owner},${`${f.owner}/${randomUUID()}.webp`},'interactions')`;
    if (kind === "one_time") {
      await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
        values (${f.project},${f.owner},'published','PI01 concurrency fixture',now()+interval '1 day',now()+interval '2 days',now())`;
    } else {
      await tx`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at)
        values (${f.project},${f.owner},'published','PI01 concurrency Tavolo',now())`;
    }
    await tx`update public.projects set registration_capacity=${countOrganizers ? 2 : 1},
      count_organizers_toward_capacity=${countOrganizers} where id=${f.project}`;
    await tx`insert into public.project_join_requests(id,project_id,requester_profile_id)
      values (${f.request},${f.project},${f.b})`;
  });
  const [link] = await asUser(
    f.owner,
    (tx) =>
      tx`select * from public.create_project_participant_invitation(${f.owner},${f.project})`,
  );
  return { ...f, ...link };
}
const acceptIn = (tx, f, user = f.a, action = f.action) =>
  tx`select * from public.accept_project_participant_invitation(${user},${f.invite_token},${action})`;
const accept = (f, user = f.a, action = f.action) =>
  asUser(user, (tx) => acceptIn(tx, f, user, action));
const rotate = (f) =>
  asUser(
    f.owner,
    (tx) =>
      tx`select * from public.regenerate_project_participant_invitation(${f.owner},${f.project})`,
  );
const revoke = (f) =>
  asUser(
    f.owner,
    (tx) =>
      tx`select public.revoke_project_participant_invitation(${f.owner},${f.project},${f.invitation_id})`,
  );
const ordinary = (f) =>
  asUser(
    f.owner,
    (tx) =>
      tx`select public.accept_project_join_request_as_manager(${f.owner},${f.request})`,
  );
async function currentCount(f) {
  const [row] =
    await sql`select count(*)::integer as n from public.project_memberships
    where project_id=${f.project} and left_at is null and removed_at is null`;
  return row.n;
}
async function waitForLock() {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const [state] = await sql`select exists(select 1 from pg_stat_activity
      where application_name='pi01-concurrency' and wait_event_type='Lock') as waiting`;
    if (state.waiting) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error(
    "Expected the overlapping PI01 transaction to wait for a lock.",
  );
}
// Start the second operation while the first holds its final domain locks.
// Observe a real PostgreSQL lock wait before allowing the first to commit.
async function firstWins(actor, first, second) {
  let queued;
  await asUser(actor, async (tx) => {
    await first(tx);
    queued = attempt(second);
    await waitForLock();
  });
  scenarios += 1;
  return queued;
}

try {
  for (const countOrganizers of [false, true]) {
    const finalPlace = await fixture(countOrganizers);
    const results = await Promise.all([
      attempt(() => accept(finalPlace)),
      attempt(() => accept(finalPlace, finalPlace.b, randomUUID())),
    ]);
    assert.equal(results.filter((r) => r.ok).length, 1);
    assert.equal(results.find((r) => !r.ok).code, "PT409");
    assert.equal(await currentCount(finalPlace), 1);
    const [counts] = await asUser(
      finalPlace.owner,
      (tx) =>
        tx`select * from public.get_project_capacity_for_manager(${finalPlace.owner},${finalPlace.project})`,
    );
    assert.equal(counts.capacity_used_count, countOrganizers ? 2 : 1);
    scenarios += 1;

    const mixed = await fixture(countOrganizers);
    const mixedResults = await Promise.all([
      attempt(() => ordinary(mixed)),
      attempt(() => accept(mixed)),
    ]);
    assert.equal(mixedResults.filter((r) => r.ok).length, 1);
    assert.equal(mixedResults.find((r) => !r.ok).code, "PT409");
    assert.equal(await currentCount(mixed), 1);
    scenarios += 1;
  }
  const samePerson = await fixture();

  for (const first of ["direct", "ordinary"]) {
    const f = await fixture();
    const other = await firstWins(
      first === "direct" ? f.b : f.owner,
      (tx) =>
        first === "direct"
          ? acceptIn(tx, f, f.b)
          : tx`select public.accept_project_join_request_as_manager(${f.owner},${f.request})`,
      () => (first === "direct" ? ordinary(f) : accept(f, f.b)),
    );
    if (first === "direct") assert.equal(other.code, "55000");
    else assert.equal(other.rows[0].outcome, "already_joined");
    assert.equal(await currentCount(f), 1);
    const [request] =
      await sql`select status,resolution_reason from public.project_join_requests where id=${f.request}`;
    assert.equal(request.status, first === "direct" ? "withdrawn" : "accepted");
    assert.equal(
      request.resolution_reason,
      first === "direct" ? "direct_participant_invitation" : null,
    );
  }

  const [a, b] = await Promise.all([
    accept(samePerson),
    accept(samePerson, samePerson.a, randomUUID()),
  ]);
  assert.equal(a[0].membership_id, b[0].membership_id);
  assert.deepEqual([a[0].outcome, b[0].outcome].sort(), [
    "already_joined",
    "joined",
  ]);
  assert.equal(await currentCount(samePerson), 1);
  const [events] =
    await sql`select count(*)::integer as n from private.outbox_events
    where event_type='project.participant_invitation_joined' and payload->>'project_id'=${samePerson.project}`;
  assert.equal(events.n, 1);
  scenarios += 1;

  const sameAction = await fixture();
  const retryResults = await Promise.all([
    accept(sameAction),
    accept(sameAction),
  ]);
  assert.equal(
    retryResults[0][0].membership_id,
    retryResults[1][0].membership_id,
  );
  assert.deepEqual(retryResults.map((r) => r[0].replayed).sort(), [
    false,
    true,
  ]);
  scenarios += 1;

  const initial = await fixture();
  await revoke(initial);
  const created = await Promise.all([
    asUser(
      initial.owner,
      (tx) =>
        tx`select * from public.create_project_participant_invitation(${initial.owner},${initial.project})`,
    ),
    asUser(
      initial.owner,
      (tx) =>
        tx`select * from public.create_project_participant_invitation(${initial.owner},${initial.project})`,
    ),
  ]);
  assert.equal(created[0][0].invitation_id, created[1][0].invitation_id);
  scenarios += 1;

  for (const operation of ["revoke", "rotate"]) {
    const f = await fixture();
    const rejected = await firstWins(
      f.owner,
      (tx) =>
        operation === "revoke"
          ? tx`select public.revoke_project_participant_invitation(${f.owner},${f.project},${f.invitation_id})`
          : tx`select * from public.regenerate_project_participant_invitation(${f.owner},${f.project})`,
      () => accept(f),
    );
    assert.equal(rejected.code, "PT409");
    assert.equal(await currentCount(f), 0);

    const admitted = await fixture();
    const management = await firstWins(
      admitted.a,
      (tx) => acceptIn(tx, admitted),
      () => (operation === "revoke" ? revoke(admitted) : rotate(admitted)),
    );
    assert.equal(management.ok, true);
    assert.equal(await currentCount(admitted), 1);
    assert.equal((await accept(admitted))[0].replayed, true);
  }
  const blocked = await fixture();
  const denied = await firstWins(
    blocked.owner,
    (tx) => tx`select public.block_user(${blocked.owner},${blocked.a})`,
    () => accept(blocked),
  );
  assert.equal(denied.code, "PT409");
  assert.equal(await currentCount(blocked), 0);
  const unblocked = await firstWins(
    blocked.owner,
    (tx) => tx`select public.unblock_user(${blocked.owner},${blocked.a})`,
    () => accept(blocked),
  );
  assert.equal(unblocked.ok, true);

  const admittedBeforeBlock = await fixture();
  const blockResult = await firstWins(
    admittedBeforeBlock.a,
    (tx) => acceptIn(tx, admittedBeforeBlock),
    () =>
      asUser(
        admittedBeforeBlock.owner,
        (tx) =>
          tx`select public.block_user(${admittedBeforeBlock.owner},${admittedBeforeBlock.a})`,
      ),
  );
  assert.equal(blockResult.ok, true);
  assert.equal(await currentCount(admittedBeforeBlock), 1);

  for (const end of ["leave", "remove"]) {
    const f = await fixture();
    const [member] = await accept(f);
    const delayed = await firstWins(
      end === "leave" ? f.a : f.owner,
      async (tx) => {
        await tx`select pg_advisory_xact_lock(hashtextextended(${`participant-admission:${f.a}:${f.action}`},0))`;
        if (end === "leave")
          await tx`select public.leave_project(${f.a},${member.membership_id})`;
        else
          await tx`select public.remove_project_member_as_manager(${f.owner},${member.membership_id})`;
      },
      () => accept(f),
    );
    assert.equal(delayed.ok, true);
    assert.equal(delayed.rows[0].membership_id, member.membership_id);
    assert.equal(
      delayed.rows[0].membership_status,
      end === "leave" ? "left" : "removed",
    );
    assert.equal(await currentCount(f), 0);
    const [fresh] = await accept(f, f.a, randomUUID());
    assert.notEqual(fresh.membership_id, member.membership_id);
    assert.equal(await currentCount(f), 1);
  }

  const closed = await fixture();
  const closeResult = await firstWins(
    closed.owner,
    (tx) =>
      tx`select public.cancel_proposal(${closed.owner},${closed.project})`,
    () => accept(closed),
  );
  assert.equal(closeResult.code, "PT409");
  assert.equal(await currentCount(closed), 0);
  const closeAfter = await fixture();
  const cancelled = await firstWins(
    closeAfter.a,
    (tx) => acceptIn(tx, closeAfter),
    () =>
      asUser(
        closeAfter.owner,
        (tx) =>
          tx`select public.cancel_proposal(${closeAfter.owner},${closeAfter.project})`,
      ),
  );
  assert.equal(cancelled.ok, true);
  assert.equal(await currentCount(closeAfter), 1);

  // A new manager may change the pair-lock set while admission is queued.
  // The canonical helper must fail rather than checking a stale manager set.
  const managers = await fixture();
  const [authorityInvite] = await asUser(
    managers.owner,
    (tx) =>
      tx`select * from public.create_project_delegate_invitation(${managers.owner},${managers.project})`,
  );
  const staleManagers = await firstWins(
    managers.c,
    (tx) =>
      tx`select public.accept_project_delegate_invitation(${managers.c},${authorityInvite.invite_token})`,
    () => accept(managers),
  );
  assert.equal(staleManagers.code, "PT409");
  assert.equal(await currentCount(managers), 0);
  assert.equal((await accept(managers))[0].outcome, "joined");
  assert.equal(
    (
      await asUser(
        managers.c,
        (tx) =>
          tx`select * from public.get_current_project_participant_invitation(${managers.c},${managers.project})`,
      )
    )[0].invitation_id,
    managers.invitation_id,
  );

  // Issuer role loss changes management rights, not Project-level authorization.
  const issued = await fixture();
  const [offered] = await asUser(
    issued.owner,
    (tx) =>
      tx`select * from public.create_project_delegate_invitation(${issued.owner},${issued.project})`,
  );
  const [delegate] = await asUser(
    issued.c,
    (tx) =>
      tx`select public.accept_project_delegate_invitation(${issued.c},${offered.invite_token}) as id`,
  );
  const [issuedLink] = await asUser(
    issued.c,
    (tx) =>
      tx`select * from public.regenerate_project_participant_invitation(${issued.c},${issued.project})`,
  );
  const issuerLoss = await firstWins(
    issued.c,
    (tx) =>
      tx`select public.step_down_project_authority(${issued.c},${delegate.id})`,
    () => accept({ ...issued, ...issuedLink }),
  );
  // The changed manager snapshot can require a retry; neither outcome rotates the token.
  if (!issuerLoss.ok) assert.equal(issuerLoss.code, "PT409");
  const [issuedAcceptance] = await accept({ ...issued, ...issuedLink });
  assert.ok(["joined", "already_joined"].includes(issuedAcceptance.outcome));
  assert.equal(
    (
      await attempt(() =>
        asUser(
          issued.c,
          (tx) =>
            tx`select * from public.get_current_project_participant_invitation(${issued.c},${issued.project})`,
        ),
      )
    ).code,
    "42501",
  );

  // Delegates remain independent of membership and do not consume an extra slot.
  for (const countOrganizers of [false, true]) {
    const f = await fixture(countOrganizers);
    await sql`update public.projects set registration_capacity=3 where id=${f.project}`;
    const [offer] = await asUser(
      f.owner,
      (tx) =>
        tx`select * from public.create_project_delegate_invitation(${f.owner},${f.project})`,
    );
    await asUser(
      f.c,
      (tx) =>
        tx`select public.accept_project_delegate_invitation(${f.c},${offer.invite_token})`,
    );
    const [member] = await accept(f, f.c, randomUUID());
    assert.equal(member.outcome, "joined");
    const [count] = await asUser(
      f.owner,
      (tx) =>
        tx`select * from public.get_project_capacity_for_manager(${f.owner},${f.project})`,
    );
    assert.equal(count.capacity_used_count, countOrganizers ? 2 : 0);
    scenarios += 1;
  }

  const tavolo = await fixture(false, "recurring");
  assert.equal((await accept(tavolo))[0].outcome, "joined");
  scenarios += 1;
  process.stdout.write(
    `Participant invitation integration/concurrency passed (${scenarios} scenarios).\n`,
  );
} catch (error) {
  // Keep action inputs and sharing secrets out of generic failure output.
  throw new Error(
    `PI01 integration failed: ${error.code ?? error.name}: ${error.message}`,
  );
} finally {
  await sql.end();
}
