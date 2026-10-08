import assert from "node:assert/strict";
import test from "node:test";

import {
  assertMembershipRaceTargets,
  membershipConstraintEvidence,
  observeMembershipRaceLock,
  readMembershipRaceIterations,
} from "./membership-race-evidence.mjs";

function observer(rows, tracked = { settled: false }) {
  let time = 0;
  return {
    tracked,
    winnerPid: 10,
    action: "removal behind replacement",
    readWaiters: async () => rows,
    timeoutMs: 50,
    now: () => time,
    sleep: async (ms) => {
      time += ms;
    },
  };
}

test("an unsettled promise with no server lock must fail, not pass after a delay", async () => {
  await assert.rejects(
    observeMembershipRaceLock(observer([])),
    /Timed out observing/,
  );
});

test("another backend's lock is not the forced winner order", async () => {
  await assert.rejects(
    observeMembershipRaceLock(
      observer([{ pid: 20, wait_event_type: "Lock", blocking_pids: [11] }]),
    ),
    /Timed out/,
  );
});

test("non-lock waits do not establish transaction serialization", async () => {
  await assert.rejects(
    observeMembershipRaceLock(
      observer([{ pid: 20, wait_event_type: "Client", blocking_pids: [10] }]),
    ),
    /Timed out/,
  );
});

test("records an observed loser blocked by the actual winner", async () => {
  assert.deepEqual(
    await observeMembershipRaceLock(
      observer([
        {
          pid: 20,
          wait_event_type: "Lock",
          wait_event: "transactionid",
          blocking_pids: [10],
        },
      ]),
    ),
    { winner_pid: 10, waiter_pid: 20, wait_event: "transactionid" },
  );
});

test("a settled RPC fails before or during observation", async () => {
  await assert.rejects(
    observeMembershipRaceLock(observer([], { settled: true })),
    /settled before/,
  );
  const options = observer([
    { pid: 20, wait_event_type: "Lock", blocking_pids: [10] },
  ]);
  options.readWaiters = async () => {
    options.tracked.settled = true;
    return [{ pid: 20, wait_event_type: "Lock", blocking_pids: [10] }];
  };
  await assert.rejects(observeMembershipRaceLock(options), /settled before/);
});

test("observer query errors remain failures", async () => {
  const options = observer([]);
  options.readWaiters = async () => {
    throw new Error("observer database failed");
  };
  await assert.rejects(
    observeMembershipRaceLock(options),
    /observer database failed/,
  );
});

test("ambiguous waiters are not silently attributed to the expected RPC", async () => {
  await assert.rejects(
    observeMembershipRaceLock(
      observer([
        { pid: 20, wait_event_type: "Lock", blocking_pids: [10] },
        { pid: 21, wait_event_type: "Lock", blocking_pids: [10] },
      ]),
    ),
    /multiple waiters/,
  );
});

test("campaign limit is explicit and invalid arguments fail", () => {
  assert.equal(readMembershipRaceIterations([]), 1);
  assert.equal(readMembershipRaceIterations(["--race-iterations=20"]), 20);
  for (const args of [
    ["--race-iterations=0"],
    ["--race-iterations=21"],
    ["--race-iterations=1.5"],
    ["--race-iterations=2", "retry"],
  ]) {
    assert.throws(
      () => readMembershipRaceIterations(args),
      /fresh fixtures, no retries/,
    );
  }
});

test("all three targets must be loopback; refusal does not leak credentials", () => {
  const targets = {
    apiUrl: "http://127.0.0.1:54381",
    databaseUrl: "postgresql://postgres:secret@[::1]:54382/postgres",
    mailpitUrl: "http://localhost:54384",
  };
  assertMembershipRaceTargets(targets);
  for (const name of Object.keys(targets)) {
    assert.throws(
      () =>
        assertMembershipRaceTargets({
          ...targets,
          [name]: "https://secret@example.com",
        }),
      (error) =>
        /refuses/.test(error.message) && !error.message.includes("secret"),
    );
  }
  assert.throws(
    () =>
      assertMembershipRaceTargets({
        ...targets,
        databaseUrl: "invalid-secret",
      }),
    /valid local database/,
  );
});

const ids = [1, 2, 3, 4].map(
  (i) => `d0000000-0000-4000-8000-${String(i).padStart(12, "0")}`,
);
const joined = "2026-10-04 20:02:17.124718+00";
function failure({
  left = "null",
  removed = "2026-10-04 20:02:17.124717+00",
  actor = ids[2],
} = {}) {
  return {
    code: "23514",
    message:
      'new row violates check constraint "project_memberships_end_state_valid"',
    details: `Failing row contains (${ids.join(", ")}, ${joined}, ${left}, ${removed}, ${actor}).`,
  };
}

test("constraint diagnostics distinguish microseconds, rather than truncate to milliseconds", () => {
  const evidence = membershipConstraintEvidence(failure());
  assert.deepEqual(evidence.failed_clauses, [
    "removed_at_at_or_after_joined_at",
  ]);
  assert.equal(evidence.failed_row.removed_at, "2026-10-04 20:02:17.124717+00");
  assert.deepEqual(
    membershipConstraintEvidence(failure({ removed: joined })).failed_clauses,
    [],
  );
  const { details, ...sqlError } = failure();
  assert.deepEqual(
    membershipConstraintEvidence({ ...sqlError, detail: details })
      .failed_clauses,
    ["removed_at_at_or_after_joined_at"],
  );
});

test("constraint diagnostics identify exclusive states, leave chronology and actor metadata independently", () => {
  assert.deepEqual(
    membershipConstraintEvidence(
      failure({
        left: "2026-10-04 20:02:17.124716+00",
        removed: joined,
        actor: "null",
      }),
    ).failed_clauses,
    [
      "exclusive_end_state",
      "left_at_at_or_after_joined_at",
      "removal_actor_pair",
    ],
  );
  assert.deepEqual(
    membershipConstraintEvidence(failure({ removed: "null" })).failed_clauses,
    ["removal_actor_pair"],
  );
});

test("missing or unexpected error details never print arbitrary payloads", () => {
  for (const error of [
    { ...failure(), details: "token=secret" },
    { ...failure(), details: failure().details.replace(ids[0], "secret") },
    { ...failure(), details: failure().details.replace(joined, "secret") },
    { code: "secret!", message: "private payload", details: failure().details },
    { ...failure(), details: undefined },
  ]) {
    const evidence = membershipConstraintEvidence(error);
    assert.equal(evidence.failed_row, null);
    assert.equal(evidence.failed_clauses, null);
    assert.ok(!JSON.stringify(evidence).includes("secret"));
    assert.ok(!JSON.stringify(evidence).includes("private payload"));
  }
});
