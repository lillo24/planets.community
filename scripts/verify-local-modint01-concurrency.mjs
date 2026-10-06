import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import {
  applyConsequence,
  asConsequenceActor,
  createConsequenceFixture,
} from "./lib/moderation-consequence-fixtures.mjs";

const { apiUrl, databaseUrl } = readLocalSupabaseStatus(process.cwd());
assert.match(apiUrl, /^http:\/\/(127\.0\.0\.1|localhost):/u);
assert.ok(
  databaseUrl,
  "MODINT01 races require the project-scoped local database",
);
const sql = postgres(databaseUrl, {
  max: 6,
  onnotice: () => {},
  connection: { statement_timeout: 15000 },
});
let observed = 0;
try {
  for (const type of [
    "interaction_restriction",
    "content_hide",
    "account_suspension",
  ]) {
    for (const consequenceFirst of [true, false]) {
      const f = await fixture();
      const actor = consequenceFirst ? staff(f, type) : f.requester;
      const result = await firstWins(
        actor,
        (tx) => (consequenceFirst ? apply(tx, f, type) : admit(tx, f)),
        consequenceFirst ? f.requester : staff(f, type),
        (tx) => (consequenceFirst ? admit(tx, f) : apply(tx, f, type)),
      );
      if (consequenceFirst) assert.equal(result.code, denial(type));
      else
        assert.equal(
          result.code,
          undefined,
          "winning admission retains membership when moderation follows",
        );
      const [state] = await sql`select
        (select count(*)::int from public.project_memberships where project_id=${f.projectId} and left_at is null and removed_at is null) as members,
        (select count(*)::int from private.project_participant_admissions where project_id=${f.projectId}) as receipts,
        (select count(*)::int from private.outbox_events where event_type='project.participant_invitation_joined' and payload->>'project_id'=${f.projectId}) as events`;
      assert.deepEqual(
        state,
        consequenceFirst
          ? { members: 0, receipts: 0, events: 0 }
          : { members: 1, receipts: 1, events: 1 },
      );
    }
    const f = await fixture();
    const [{ id: episode }] = await asConsequenceActor(
      sql,
      staff(f, type),
      (tx) => apply(tx, f, type),
    );
    const beforeRevoke = await capture(() =>
      asConsequenceActor(sql, f.requester, (tx) => admit(tx, f)),
    );
    assert.equal(
      beforeRevoke.code,
      denial(type),
      "a still-active consequence denies admission before revoke",
    );
    const admitted = await firstWins(
      staff(f, type),
      (tx) => revoke(tx, f, type, episode),
      f.requester,
      (tx) => admit(tx, f),
      type === "account_suspension",
    );
    if (type === "account_suspension") {
      // Suspension is rejected before entering any admission lock. A concurrent
      // uncommitted revoke must not authorize it; an explicit post-commit retry
      // succeeds on the original action. Do not fabricate a lock wait here.
      assert.equal(admitted.code, "PT403");
      const [retried] = await asConsequenceActor(sql, f.requester, (tx) =>
        admit(tx, f),
      );
      assert.equal(retried.outcome, "joined");
    } else assert.equal(admitted.rows[0].outcome, "joined");
  }
  assert.equal(observed, 8);
  console.log(
    "MODINT01 concurrency passed: 6 lock-observed apply/admission winner orders and 2 lock-observed restriction/hide revoke recoveries; suspension denies during uncommitted revoke and permits explicit post-commit retry; denied transitions create no membership, receipt or joined event.",
  );
} finally {
  await sql.end({ timeout: 5 });
}

async function fixture() {
  const f = await createConsequenceFixture(sql);
  const [link] = await asConsequenceActor(
    sql,
    f.owner,
    (tx) =>
      tx`select * from public.create_project_participant_invitation(${f.owner},${f.projectId})`,
  );
  return { ...f, ...link, action: randomUUID() };
}
function staff(f, type) {
  return type === "account_suspension" ? f.admin : f.moderator;
}
function denial(type) {
  return type === "account_suspension" ? "PT403" : "PT409";
}
function apply(tx, f, type) {
  return type === "account_suspension"
    ? tx`select public.apply_account_suspension(${f.admin},${f.cases.profile},'Synthetic suspension','Synthetic private note') as id`
    : applyConsequence(tx, f, type);
}
function revoke(tx, f, type, id) {
  return type === "account_suspension"
    ? tx`select public.revoke_account_suspension(${f.admin},${id},'Synthetic restored access','Synthetic private note')`
    : tx`select public.revoke_moderation_consequence(${f.moderator},${id},'Synthetic restored access','Synthetic private note')`;
}
function admit(tx, f) {
  return tx`select * from public.accept_project_participant_invitation(${f.requester},${f.invite_token},${f.action})`;
}
async function capture(operation) {
  try {
    return { rows: await operation() };
  } catch (error) {
    if (!["PT409", "PT403"].includes(error.code))
      throw new Error(`MODINT01 race failed (code ${error.code ?? "unknown"})`);
    return { code: error.code };
  }
}
async function firstWins(
  actor,
  firstOperation,
  secondActor,
  secondOperation,
  earlyDenial = false,
) {
  let releaseFirst, signalFirst, firstPid, secondPid;
  const held = new Promise((resolve) => {
    signalFirst = resolve;
  });
  const release = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const first = asConsequenceActor(sql, actor, async (tx) => {
    [{ pid: firstPid }] = await tx`select pg_backend_pid() as pid`;
    await firstOperation(tx);
    signalFirst();
    await release;
  });
  await Promise.race([
    held,
    first.then(() => {
      throw new Error("MODINT01 first operation never acquired its locks");
    }),
  ]);
  // Capture the exact backend waiting for this first transaction, not an
  // unrelated wait from another running verifier or a pending JS promise.
  const second = capture(() =>
    asConsequenceActor(sql, secondActor, async (tx) => {
      [{ pid: secondPid }] = await tx`select pg_backend_pid() as pid`;
      return secondOperation(tx);
    }),
  );
  try {
    if (earlyDenial) {
      assert.equal((await second).code, "PT403");
    } else {
      const deadline = Date.now() + 5000;
      let waiting = false;
      while (Date.now() < deadline) {
        if (secondPid) {
          const [state] = await sql`select wait_event_type='Lock'
            and ${firstPid}::int=any(pg_blocking_pids(pid)) as blocked_by_first
            from pg_stat_activity where pid=${secondPid}`;
          if (state?.blocked_by_first) {
            waiting = true;
            break;
          }
        }
        await new Promise((resolve) => setTimeout(resolve, 20));
      }
      assert.ok(
        waiting && secondPid,
        "MODINT01 second operation must actually wait on the first transaction",
      );
      observed++;
    }
  } finally {
    releaseFirst();
  }
  await first;
  return second;
}
