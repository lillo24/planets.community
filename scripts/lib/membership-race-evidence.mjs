const UUID = /^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/iu;
const CONSTRAINT = "project_memberships_end_state_valid";

export function readMembershipRaceIterations(args) {
  if (args.length === 0) return 1;
  if (
    args.length === 1 &&
    /^--race-iterations=(?:[1-9]|1\d|20)$/u.test(args[0])
  ) {
    return Number(args[0].split("=")[1]);
  }
  throw new Error(
    "Use no arguments or --race-iterations=1..20 (fresh fixtures, no retries).",
  );
}

export function assertMembershipRaceTargets({
  apiUrl,
  databaseUrl,
  mailpitUrl,
}) {
  for (const [name, value, protocols] of [
    ["API", apiUrl, ["http:", "https:"]],
    ["database", databaseUrl, ["postgres:", "postgresql:"]],
    ["Mailpit", mailpitUrl, ["http:", "https:"]],
  ]) {
    let url;
    try {
      url = new URL(value);
    } catch {
      throw new Error(
        `The membership verifier requires a valid local ${name} URL.`,
      );
    }
    if (
      !protocols.includes(url.protocol) ||
      !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)
    ) {
      throw new Error(
        `The membership verifier refuses a non-loopback ${name} target.`,
      );
    }
  }
}

// The caller starts exactly one losing HTTP operation on a fresh fixture and
// supplies the actual winner PID. Do not match RPC names in pg_stat_activity:
// wide PostgREST statements can exceed track_activity_query_size (default 1 KB).
// A pending promise or a lock held by another backend is not evidence.
export async function observeMembershipRaceLock({
  tracked,
  winnerPid,
  readWaiters,
  action,
  timeoutMs = 10_000,
  now = () => performance.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
}) {
  const deadline = now() + timeoutMs;
  while (now() < deadline) {
    if (tracked.settled) {
      throw new Error(
        `The ${action} operation settled before its blocking lock was observed.`,
      );
    }
    const rows = await readWaiters();
    const waiters = rows.filter(
      (row) =>
        row.pid !== winnerPid &&
        row.wait_event_type === "Lock" &&
        row.blocking_pids.includes(winnerPid),
    );
    if (waiters.length > 1) {
      throw new Error(
        `The ${action} lock observation has multiple waiters behind winner PID ${winnerPid}.`,
      );
    }
    const [waiter] = waiters;
    if (waiter && !tracked.settled) {
      return {
        winner_pid: winnerPid,
        waiter_pid: waiter.pid,
        wait_event: waiter.wait_event,
      };
    }
    await sleep(20);
  }
  throw new Error(
    `Timed out observing the ${action} database lock behind winner PID ${winnerPid}.`,
  );
}

// Parse only this eight-column membership tuple. Never print raw PostgREST
// messages/details: unrelated payloads, SQL, tokens and credentials stay out.
export function membershipConstraintEvidence(error) {
  const evidence = {
    sqlstate: /^[\dA-Z]{5}$/u.test(error?.code ?? "") ? error.code : "unknown",
    constraint:
      error?.constraint === CONSTRAINT ||
      error?.message?.includes(`"${CONSTRAINT}"`)
        ? CONSTRAINT
        : "unavailable",
    failed_row: null,
    failed_clauses: null,
  };
  const details = error?.details ?? error?.detail;
  if (evidence.constraint !== CONSTRAINT || typeof details !== "string")
    return evidence;
  const match = /^Failing row contains \(([^\n]+)\)\.$/u.exec(details);
  if (!match) return evidence;
  const fields = match[1].split(", ");
  if (
    fields.length !== 8 ||
    !fields.slice(0, 4).every((field) => UUID.test(field))
  )
    return evidence;
  const [
    id,
    project_id,
    participant_profile_id,
    originating_request_id,
    joined_at,
    left,
    removed,
    actor,
  ] = fields;
  const joined = timestampMicros(joined_at);
  const leftTime = left === "null" ? null : timestampMicros(left);
  const removedTime = removed === "null" ? null : timestampMicros(removed);
  if (
    joined === undefined ||
    leftTime === undefined ||
    removedTime === undefined ||
    (actor !== "null" && !UUID.test(actor))
  )
    return evidence;
  evidence.failed_row = {
    id,
    project_id,
    participant_profile_id,
    originating_request_id,
    joined_at,
    left_at: left === "null" ? null : left,
    removed_at: removed === "null" ? null : removed,
    removed_by_profile_id: actor === "null" ? null : actor,
  };
  evidence.failed_clauses = [];
  if (leftTime !== null && removedTime !== null)
    evidence.failed_clauses.push("exclusive_end_state");
  if (leftTime !== null && leftTime < joined)
    evidence.failed_clauses.push("left_at_at_or_after_joined_at");
  if (removedTime !== null && removedTime < joined)
    evidence.failed_clauses.push("removed_at_at_or_after_joined_at");
  if ((removedTime === null) !== (actor === "null"))
    evidence.failed_clauses.push("removal_actor_pair");
  return evidence;
}

function timestampMicros(value) {
  const match =
    /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})(?:\.(\d{1,6}))?([+-]\d{2}(?::\d{2})?)$/u.exec(
      value,
    );
  if (!match) return undefined;
  const zone = match[4].length === 3 ? `${match[4]}:00` : match[4];
  const millis = Date.parse(`${match[1]}T${match[2]}${zone}`);
  if (!Number.isFinite(millis)) return undefined;
  return BigInt(millis) * 1000n + BigInt((match[3] ?? "").padEnd(6, "0"));
}
