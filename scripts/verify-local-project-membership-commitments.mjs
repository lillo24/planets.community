import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import {
  assertMembershipRaceTargets,
  membershipConstraintEvidence,
  observeMembershipRaceLock,
  readMembershipRaceIterations,
} from "./lib/membership-race-evidence.mjs";

const repositoryRoot = process.cwd();
const raceIterations = readMembershipRaceIterations(process.argv.slice(2));
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing its database URL. Update the project-scoped CLI if the status format has changed.",
  );
}

assertMembershipRaceTargets({ apiUrl, databaseUrl, mailpitUrl });
const sql = postgres(databaseUrl, {
  max: 4,
  connection: { statement_timeout: 15_000 },
});
const requiredSkillId = "d0000000-0000-4000-8001-000000000001";
const usefulSkillId = "d0000000-0000-4000-8003-000000000002";

try {
  await verifyProjectMembershipCommitments();
} finally {
  await sql.end();
}

async function verifyProjectMembershipCommitments() {
  const [creator, participant, unrelated] = await Promise.all([
    signInWithLocalOtp("membership-commitment-creator@planets.invalid"),
    signInWithLocalOtp("membership-commitment-participant@planets.invalid"),
    signInWithLocalOtp("membership-commitment-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Membership Commitment Creator"),
    ensureCompleteProfile(participant, "Membership Commitment Participant"),
    ensureCompleteProfile(unrelated, "Membership Commitment Unrelated"),
  ]);
  await Promise.all(
    [creator, participant, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  await verifyPrimaryFlows(creator, participant, unrelated);
  await verifyOptimisticConcurrency(creator, participant);
  await verifyTavoloFlow(creator, unrelated);
  for (let iteration = 1; iteration <= raceIterations; iteration += 1) {
    await verifyEndStateSerialization(
      creator,
      participant,
      "leave_project",
      iteration,
    );
    await verifyEndStateSerialization(
      creator,
      participant,
      "remove_project_member",
      iteration,
    );
  }
  await verifyResourceClosureSerialization(creator, participant);
  await verifySkillRemovalSerialization(creator, participant);

  console.log(
    "Confirmed real-OTP acceptance seeding, authorized current/ended commitment reads, current addable-option snapshots including paused Tavoli, compare-and-swap full-set replacement and no-ops, participant/creator stale-editor rejection, lifecycle/stale-option rules, identifier-only events without notifications, rejoin isolation, and membership/resource/skill lock serialization.",
  );
}

async function verifyPrimaryFlows(creator, participant, unrelated) {
  const fixture = await createMembershipFixture(
    creator,
    participant,
    "Integration membership commitment primary",
    [requiredSkillId],
    [],
  );
  const secondNeedId = await createNeed(
    creator,
    fixture.proposalId,
    "Primary second open need",
  );

  await assertCommitments(participant, fixture.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
  await assertCommitments(creator, fixture.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
  const eventCountsBeforeOptions = await readAuditOutboxCounts();
  await assertCommitmentOptions(participant, fixture.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["skill", usefulSkillId, "Woodworking"],
    ["resource", secondNeedId, "Primary second open need"],
  ]);
  await assertCommitmentOptions(creator, fixture.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["skill", usefulSkillId, "Woodworking"],
    ["resource", secondNeedId, "Primary second open need"],
  ]);
  await assertRpcCode(
    unrelated.client.rpc("list_own_project_membership_commitments", {
      p_expected_profile_id: unrelated.id,
      p_membership_id: fixture.membershipId,
    }),
    "42501",
    "deny an unrelated membership commitment read",
  );
  await assertRpcCode(
    unrelated.client.rpc("list_own_project_membership_commitment_options", {
      p_expected_profile_id: unrelated.id,
      p_membership_id: fixture.membershipId,
    }),
    "42501",
    "deny an unrelated membership commitment-options read",
  );
  const eventCountsAfterOptions = await readAuditOutboxCounts();
  if (
    JSON.stringify(eventCountsBeforeOptions) !==
    JSON.stringify(eventCountsAfterOptions)
  ) {
    throw new Error("Commitment-options reads created audit or outbox rows.");
  }
  const { error: directReadError } = await participant.client
    .from("project_membership_skill_commitments")
    .select("membership_id");
  if (!directReadError) {
    throw new Error(
      "Direct authenticated commitment-table access did not fail.",
    );
  }

  await assertNoCommitmentEvent(fixture.membershipId);
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [requiredSkillId],
    [],
    [usefulSkillId, requiredSkillId],
    [secondNeedId],
  );
  const beforeNoop = await readCommitmentState(fixture.membershipId);
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
  );
  const afterNoop = await readCommitmentState(fixture.membershipId);
  if (JSON.stringify(beforeNoop) !== JSON.stringify(afterNoop)) {
    throw new Error(
      "An identical desired set rewrote commitment state or events.",
    );
  }

  await closeNeed(creator, secondNeedId);
  await updateProposalSkills(
    creator,
    fixture.proposalId,
    [usefulSkillId],
    ["useful"],
    "Integration membership commitment primary",
  );
  await assertCommitments(participant, fixture.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["skill", usefulSkillId, "Woodworking"],
    ["resource", secondNeedId, "Primary second open need"],
  ]);
  await assertCommitmentOptions(participant, fixture.membershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
  );
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
    [usefulSkillId],
    [],
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_expected_skill_ids: [usefulSkillId],
      p_expected_resource_need_ids: [],
      p_membership_id: fixture.membershipId,
      p_skill_ids: [requiredSkillId, usefulSkillId],
      p_resource_need_ids: [],
    }),
    "22023",
    "reject re-adding a removed Proposal skill",
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_expected_skill_ids: [usefulSkillId],
      p_expected_resource_need_ids: [],
      p_membership_id: fixture.membershipId,
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [secondNeedId],
    }),
    "22023",
    "reject re-adding a closed resource need",
  );

  await replaceCommitments(
    creator,
    fixture.membershipId,
    [usefulSkillId],
    [],
    null,
    null,
  );
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [],
    [],
    [usefulSkillId],
    [],
  );
  await sql`
    update public.proposals
    set
      starts_at = statement_timestamp() - interval '1 hour',
      ends_at = statement_timestamp() + interval '2 hours'
    where id = ${fixture.proposalId}::uuid
  `;
  await assertCommitmentOptions(participant, fixture.membershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [usefulSkillId],
    [],
    [usefulSkillId],
    [],
  );
  await transitionMembership(
    participant,
    "leave_project",
    "p_expected_participant_profile_id",
    fixture.membershipId,
  );
  await assertCommitments(participant, fixture.membershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_expected_skill_ids: [usefulSkillId],
      p_expected_resource_need_ids: [],
      p_membership_id: fixture.membershipId,
      p_skill_ids: [],
      p_resource_need_ids: [],
    }),
    "55000",
    "reject mutation of an ended membership",
  );
  await assertRpcCode(
    participant.client.rpc("list_own_project_membership_commitment_options", {
      p_expected_profile_id: participant.id,
      p_membership_id: fixture.membershipId,
    }),
    "55000",
    "reject options for an ended membership",
  );

  const rejoinRequestId = await requestToJoin(
    participant,
    fixture.proposalId,
    [usefulSkillId],
    [],
  );
  const rejoinMembershipId = await acceptRequest(
    creator,
    rejoinRequestId,
    [usefulSkillId],
    [],
  );
  if (rejoinMembershipId === fixture.membershipId) {
    throw new Error("Rejoining reused an ended membership episode.");
  }
  await assertCommitments(participant, rejoinMembershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);

  await sql`
    update public.proposals
    set
      starts_at = statement_timestamp() - interval '2 hours',
      ends_at = statement_timestamp() - interval '1 hour'
    where id = ${fixture.proposalId}::uuid
  `;
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_expected_skill_ids: [usefulSkillId],
      p_expected_resource_need_ids: [],
      p_membership_id: rejoinMembershipId,
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [],
    }),
    "55000",
    "reject a no-op after the Proposal has ended",
  );
  await assertRpcCode(
    participant.client.rpc("list_own_project_membership_commitment_options", {
      p_expected_profile_id: participant.id,
      p_membership_id: rejoinMembershipId,
    }),
    "55000",
    "reject options after the Proposal has ended",
  );
  await assertCommitments(creator, fixture.membershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);
  await assertIdentifierOnlyEventsWithoutNotifications(fixture.membershipId);
}

async function verifyOptimisticConcurrency(creator, participant) {
  const fixture = await createMembershipFixture(
    creator,
    participant,
    "Integration membership commitment stale editor",
  );
  await Promise.all([
    assertCommitments(participant, fixture.membershipId, []),
    assertCommitments(creator, fixture.membershipId, []),
  ]);
  const countsBefore = await readAuditOutboxCounts();

  await replaceCommitments(
    participant,
    fixture.membershipId,
    [],
    [],
    [requiredSkillId],
    [],
  );
  await assertRpcCode(
    creator.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: creator.id,
      p_expected_skill_ids: [],
      p_expected_resource_need_ids: [],
      p_membership_id: fixture.membershipId,
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [],
    }),
    "PT409",
    "reject a creator replacement based on the participant stale snapshot",
  );

  await Promise.all([
    assertCommitments(participant, fixture.membershipId, [
      ["skill", requiredSkillId, "Mural painting"],
    ]),
    assertCommitments(creator, fixture.membershipId, [
      ["skill", requiredSkillId, "Mural painting"],
    ]),
  ]);
  const countsAfter = await readAuditOutboxCounts();
  if (
    countsAfter.audit_count !== countsBefore.audit_count + 1 ||
    countsAfter.outbox_count !== countsBefore.outbox_count + 1
  ) {
    throw new Error(
      "A stale creator replacement changed commitment event side effects.",
    );
  }
}

async function verifyTavoloFlow(creator, participant) {
  const tavoloId = await createTavoloDraft(creator);
  const firstNeedId = await createNeed(creator, tavoloId, "Tavolo first need");
  const secondNeedId = await createNeed(
    creator,
    tavoloId,
    "Tavolo second need",
  );
  await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
  const requestId = await requestToJoin(
    participant,
    tavoloId,
    [],
    [firstNeedId],
  );
  const membershipId = await acceptRequest(
    creator,
    requestId,
    [],
    [firstNeedId],
  );
  await assertCommitmentOptions(participant, membershipId, [
    ["resource", firstNeedId, "Tavolo first need"],
    ["resource", secondNeedId, "Tavolo second need"],
  ]);
  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  await assertCommitmentOptions(participant, membershipId, [
    ["resource", firstNeedId, "Tavolo first need"],
    ["resource", secondNeedId, "Tavolo second need"],
  ]);
  await replaceCommitments(
    participant,
    membershipId,
    [],
    [firstNeedId],
    [],
    [firstNeedId, secondNeedId],
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_expected_skill_ids: [],
      p_expected_resource_need_ids: [firstNeedId, secondNeedId],
      p_membership_id: membershipId,
      p_skill_ids: [requiredSkillId],
      p_resource_need_ids: [firstNeedId, secondNeedId],
    }),
    "22023",
    "reject a new Tavolo skill commitment",
  );
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  await assertRpcCode(
    participant.client.rpc("list_own_project_membership_commitment_options", {
      p_expected_profile_id: participant.id,
      p_membership_id: membershipId,
    }),
    "55000",
    "reject options after the Tavolo has ended",
  );
}

async function verifyEndStateSerialization(
  creator,
  participant,
  operation,
  iteration,
) {
  const actor = operation === "leave_project" ? participant : creator;
  for (const order of ["end_first", "replacement_first"]) {
    const fixture = await createMembershipFixture(
      creator,
      participant,
      `Integration ${operation} ${order} race ${iteration}`,
    );
    const evidence = {
      operation,
      order,
      iteration,
      membership_id: fixture.membershipId,
      actor_profile_id: actor.id,
      stage: "before_winner",
      before: await readMembershipRaceState(fixture.membershipId),
    };
    let loser;
    try {
      await sql.begin(async (transaction) => {
        const winner = order === "end_first" ? actor : participant;
        await setAuthenticatedTransaction(transaction, winner.id);
        evidence.stage = "execute_winner";
        if (order === "end_first") {
          const [row] =
            operation === "leave_project"
              ? await transaction`select public.leave_project(${actor.id}::uuid, ${fixture.membershipId}::uuid) as id`
              : await transaction`select public.remove_project_member(${actor.id}::uuid, ${fixture.membershipId}::uuid) as id`;
          if (row.id !== fixture.membershipId)
            throw new Error(
              "The membership end-state winner returned an unexpected ID.",
            );
        } else {
          await replaceInTransaction(
            transaction,
            participant.id,
            fixture.membershipId,
            [],
            [],
            [requiredSkillId],
            [],
          );
        }
        const loserOperation =
          order === "end_first"
            ? "replace_project_membership_commitments"
            : operation;
        const pending =
          order === "end_first"
            ? participant.client.rpc(loserOperation, {
                p_expected_actor_profile_id: participant.id,
                p_expected_skill_ids: [],
                p_expected_resource_need_ids: [],
                p_membership_id: fixture.membershipId,
                p_skill_ids: [requiredSkillId],
                p_resource_need_ids: [],
              })
            : actor.client.rpc(loserOperation, {
                [operation === "leave_project"
                  ? "p_expected_participant_profile_id"
                  : "p_expected_creator_profile_id"]: actor.id,
                p_membership_id: fixture.membershipId,
              });
        loser = track(pending.abortSignal(AbortSignal.timeout(15_000)));
        evidence.stage = "observe_loser_lock";
        evidence.lock = await assertBlocked(
          loser,
          `${loserOperation} behind ${order}`,
          transaction,
          loserOperation,
        );
        evidence.before_winner_commit_committed_row =
          await readMembershipRaceState(fixture.membershipId);
      });
      evidence.stage = "await_loser_result";
      if (order === "end_first") {
        await assertTrackedRpcCode(
          loser,
          "55000",
          "reject replacement after membership end wins",
        );
      } else {
        await assertTrackedRpcValue(
          loser,
          fixture.membershipId,
          `complete ${operation} after replacement wins`,
        );
      }
      evidence.stage = "assert_final_state";
      evidence.after = await readMembershipRaceState(fixture.membershipId);
      const state = evidence.after;
      const isLeave = operation === "leave_project";
      if (
        !state.valid_end_state ||
        state.current_memberships !== 0 ||
        state.live_coverages !== 0 ||
        state.end_audit_events !== 1 ||
        state.end_outbox_events !== 1 ||
        state.commitment_events !== (order === "end_first" ? 0 : 1) ||
        (isLeave
          ? state.left_at === null ||
            state.removed_at !== null ||
            state.removed_by_profile_id !== null
          : state.left_at !== null ||
            state.removed_at === null ||
            state.removed_by_profile_id !== actor.id)
      ) {
        throw new Error(
          "Membership end-state, coverage, capacity occupancy or event postcondition failed.",
        );
      }
      await assertCommitments(
        actor,
        fixture.membershipId,
        order === "end_first"
          ? []
          : [["skill", requiredSkillId, "Mural painting"]],
      );
      console.log(
        `Membership race passed: ${operation}, ${order}, iteration ${iteration}; observed ${evidence.lock.wait_event} behind winner; end-state/history/coverage/occupancy/events preserved.`,
      );
    } catch (error) {
      // sql.begin has committed or rolled back before collecting the final row.
      // A rolled-back row is labelled separately from the failed UPDATE tuple.
      if (loser) await loser.promise.catch(() => {});
      try {
        evidence.after_failure_committed_row = await readMembershipRaceState(
          fixture.membershipId,
        );
      } catch (diagnosticError) {
        evidence.snapshot_error =
          membershipConstraintEvidence(diagnosticError).sqlstate;
      }
      evidence.failure =
        error.membershipEvidence ?? membershipConstraintEvidence(error);
      console.error(
        `Membership race failure evidence: ${JSON.stringify(evidence)}`,
      );
      throw new Error(
        `Membership race failed at ${evidence.stage} (${operation}, ${order}, code ${evidence.failure.sqlstate}); see redacted evidence.`,
      );
    }
  }
}

async function readMembershipRaceState(membershipId) {
  const [row] = await sql`
    select membership.id, membership.project_id, membership.participant_profile_id,
      membership.originating_request_id, membership.joined_at::text,
      membership.left_at::text, membership.removed_at::text, membership.removed_by_profile_id,
      clock_timestamp()::text as database_clock, statement_timestamp()::text as statement_time,
      transaction_timestamp()::text as transaction_time,
      (not (membership.left_at is not null and membership.removed_at is not null)
       and (membership.left_at is null or membership.left_at >= membership.joined_at)
       and (membership.removed_at is null or membership.removed_at >= membership.joined_at)
       and ((membership.removed_at is null and membership.removed_by_profile_id is null)
         or (membership.removed_at is not null and membership.removed_by_profile_id is not null))) as valid_end_state,
      (select count(*)::int from public.project_memberships m where m.project_id = membership.project_id and m.left_at is null and m.removed_at is null) as current_memberships,
      ((select count(*)::int from public.project_membership_skill_coverages c where c.membership_id = membership.id)
       + (select count(*)::int from public.project_membership_resource_coverages c where c.membership_id = membership.id)) as live_coverages,
      (select count(*)::int from private.audit_events e where e.action in ('project.participant_left', 'project.participant_removed') and e.metadata ->> 'membership_id' = membership.id::text) as end_audit_events,
      (select count(*)::int from private.outbox_events e where e.event_type in ('project.participant_left', 'project.participant_removed') and e.payload ->> 'membership_id' = membership.id::text) as end_outbox_events,
      (select count(*)::int from private.outbox_events e where e.event_type = 'project.membership_commitments_updated' and e.payload ->> 'membership_id' = membership.id::text) as commitment_events
    from public.project_memberships membership where membership.id = ${membershipId}::uuid
  `;
  if (!row)
    throw new Error("The synthetic membership evidence row is missing.");
  return row;
}

async function verifyResourceClosureSerialization(creator, participant) {
  const closeFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration close-first commitment race",
  );
  const closeFirstNeedId = await createNeed(
    creator,
    closeFirst.proposalId,
    "Close-first commitment need",
  );
  let blockedReplace;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.close_project_resource_need(
        ${creator.id}::uuid,
        ${closeFirstNeedId}::uuid
      )
    `;
    blockedReplace = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_expected_skill_ids: [],
        p_expected_resource_need_ids: [],
        p_membership_id: closeFirst.membershipId,
        p_skill_ids: [],
        p_resource_need_ids: [closeFirstNeedId],
      }),
    );
    await assertBlocked(
      blockedReplace,
      "resource add behind closure",
      transaction,
      "replace_project_membership_commitments",
    );
  });
  await assertTrackedRpcCode(
    blockedReplace,
    "22023",
    "reject a resource addition after closure wins",
  );

  const replaceFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration add-first resource race",
  );
  const replaceFirstNeedId = await createNeed(
    creator,
    replaceFirst.proposalId,
    "Add-first commitment need",
  );
  let blockedClose;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      replaceFirst.membershipId,
      [],
      [],
      [],
      [replaceFirstNeedId],
    );
    blockedClose = track(
      creator.client.rpc("close_project_resource_need", {
        p_expected_creator_profile_id: creator.id,
        p_resource_need_id: replaceFirstNeedId,
      }),
    );
    await assertBlocked(
      blockedClose,
      "resource closure behind add",
      transaction,
      "close_project_resource_need",
    );
  });
  await assertTrackedRpcValue(
    blockedClose,
    replaceFirstNeedId,
    "complete resource closure after add wins",
  );
  await assertCommitments(participant, replaceFirst.membershipId, [
    ["resource", replaceFirstNeedId, "Add-first commitment need"],
  ]);
}

async function verifySkillRemovalSerialization(creator, participant) {
  const removeFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration skill-remove-first commitment race",
  );
  let blockedReplace;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await updateProposalSkillsInTransaction(
      transaction,
      creator.id,
      removeFirst.proposalId,
      "Integration skill-remove-first commitment race",
      [],
      [],
    );
    blockedReplace = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_expected_skill_ids: [],
        p_expected_resource_need_ids: [],
        p_membership_id: removeFirst.membershipId,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(
      blockedReplace,
      "skill add behind requirement removal",
      transaction,
      "replace_project_membership_commitments",
    );
  });
  await assertTrackedRpcCode(
    blockedReplace,
    "22023",
    "reject a skill addition after requirement removal wins",
  );

  const replaceFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration skill-add-first commitment race",
  );
  let blockedUpdate;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      replaceFirst.membershipId,
      [],
      [],
      [requiredSkillId],
      [],
    );
    blockedUpdate = track(
      updateProposalSkills(
        creator,
        replaceFirst.proposalId,
        [],
        [],
        "Integration skill-add-first commitment race",
      ),
    );
    await assertBlocked(
      blockedUpdate,
      "requirement removal behind skill add",
      transaction,
      "update_own_proposal",
    );
  });
  await assertTrackedSuccess(
    blockedUpdate,
    "complete requirement removal after skill add wins",
  );
  await assertCommitments(participant, replaceFirst.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
}

async function createMembershipFixture(
  creator,
  participant,
  title,
  selectedSkillIds = [],
  selectedResourceNeedIds = [],
) {
  const proposalId = await createProposalDraft(
    creator,
    title,
    [requiredSkillId, usefulSkillId],
    ["required", "useful"],
  );
  await publishProposal(creator, proposalId);
  const requestId = await requestToJoin(
    participant,
    proposalId,
    selectedSkillIds,
    selectedResourceNeedIds,
  );
  const membershipId = await acceptRequest(
    creator,
    requestId,
    selectedSkillIds,
    selectedResourceNeedIds,
  );
  return { proposalId, requestId, membershipId };
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function replaceInTransaction(
  transaction,
  actorId,
  membershipId,
  expectedSkillIds,
  expectedResourceNeedIds,
  skillIds,
  resourceNeedIds,
) {
  await transaction`
    select public.replace_project_membership_commitments(
      ${actorId}::uuid,
      ${membershipId}::uuid,
      ${expectedSkillIds}::uuid[],
      ${expectedResourceNeedIds}::uuid[],
      ${skillIds}::uuid[],
      ${resourceNeedIds}::uuid[]
    )
  `;
}

async function createProposalDraft(creator, title, skillIds, importances) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    ...proposalContent(title, skillIds, importances),
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a commitment Proposal", error ?? {});
  }
  return data;
}

function proposalContent(title, skillIds, importances) {
  return {
    p_title: title,
    p_summary: "Deterministic membership-commitment integration coverage.",
    p_description:
      "This Project verifies accepted-participant commitment semantics and locking.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private commitment verification location",
    p_exact_location_visibility: "participants",
    p_skill_ids: skillIds,
    p_skill_importances: importances,
    p_people_capacity: 20,
  };
}

async function publishProposal(creator, proposalId) {
  const { data, error } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("publish a commitment Proposal", error ?? {});
  }
}

async function updateProposalSkills(
  creator,
  proposalId,
  skillIds,
  importances,
  title,
) {
  const { data, error } = await creator.client.rpc("update_own_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
    ...proposalContent(title, skillIds, importances),
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("replace Proposal skills", error ?? {});
  }
  return data;
}

async function updateProposalSkillsInTransaction(
  transaction,
  creatorId,
  proposalId,
  title,
  skillIds,
  importances,
) {
  const content = proposalContent(title, skillIds, importances);
  await transaction`
    select public.update_own_proposal(
      ${creatorId}::uuid,
      ${proposalId}::uuid,
      ${content.p_title},
      ${content.p_summary},
      ${content.p_description},
      ${content.p_starts_at}::timestamptz,
      ${content.p_ends_at}::timestamptz,
      ${content.p_event_timezone},
      ${content.p_country_code},
      ${content.p_locality},
      ${content.p_administrative_area},
      ${content.p_public_location_label},
      ${content.p_exact_meeting_text},
      ${content.p_exact_location_visibility},
      ${skillIds}::uuid[],
      ${importances}::text[]
    )
  `;
}

async function createNeed(creator, projectId, title) {
  const { data, error } = await creator.client.rpc(
    "create_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
      p_title: title,
      p_details: null,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a commitment resource need", error ?? {});
  }
  return data;
}

async function closeNeed(creator, resourceNeedId) {
  const { data, error } = await creator.client.rpc(
    "close_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: resourceNeedId,
    },
  );
  if (error || data !== resourceNeedId) {
    throw safeDatabaseFailure("close a commitment resource need", error ?? {});
  }
}

async function requestToJoin(
  participant,
  projectId,
  skillIds,
  resourceNeedIds,
) {
  const { data, error } = await participant.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: participant.id,
      p_project_id: projectId,
      p_request_message: null,
      p_skill_ids: skillIds,
      p_resource_need_ids: resourceNeedIds,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a commitment join request", error ?? {});
  }
  return data;
}

async function acceptRequest(
  creator,
  requestId,
  neededSkillIds,
  neededResourceNeedIds,
) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
      p_needed_skill_ids: neededSkillIds,
      p_already_found_skill_ids: [],
      p_extra_skill_ids: [],
      p_needed_resource_need_ids: neededResourceNeedIds,
      p_already_found_resource_need_ids: [],
      p_extra_resource_need_ids: [],
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("accept a commitment join request", error ?? {});
  }
  return data;
}

async function replaceCommitments(
  user,
  membershipId,
  expectedSkillIds,
  expectedResourceIds,
  skillIds,
  resourceIds,
) {
  const { data, error } = await user.client.rpc(
    "replace_project_membership_commitments",
    {
      p_expected_actor_profile_id: user.id,
      p_expected_skill_ids: expectedSkillIds,
      p_expected_resource_need_ids: expectedResourceIds,
      p_membership_id: membershipId,
      p_skill_ids: skillIds,
      p_resource_need_ids: resourceIds,
    },
  );
  if (error || data !== membershipId) {
    throw safeDatabaseFailure("replace membership commitments", error ?? {});
  }
}

async function transitionMembership(
  user,
  operation,
  identityKey,
  membershipId,
) {
  const { data, error } = await user.client.rpc(operation, {
    [identityKey]: user.id,
    p_membership_id: membershipId,
  });
  if (error || data !== membershipId) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error ?? {});
  }
}

async function assertCommitments(user, membershipId, expectedRows) {
  const { data, error } = await user.client.rpc(
    "list_own_project_membership_commitments",
    {
      p_expected_profile_id: user.id,
      p_membership_id: membershipId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("read membership commitments", error ?? {});
  }
  const actualRows = data.map((row) => [
    row.commitment_kind,
    row.commitment_id,
    row.label,
  ]);
  if (JSON.stringify(actualRows) !== JSON.stringify(expectedRows)) {
    throw new Error(
      "Membership commitments had unexpected IDs, labels, or order.",
    );
  }
}

async function assertCommitmentOptions(user, membershipId, expectedRows) {
  const { data, error } = await user.client.rpc(
    "list_own_project_membership_commitment_options",
    {
      p_expected_profile_id: user.id,
      p_membership_id: membershipId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure(
      "read membership commitment options",
      error ?? {},
    );
  }
  const actualRows = data.map((row) => [
    row.option_kind,
    row.option_id,
    row.label,
  ]);
  if (JSON.stringify(actualRows) !== JSON.stringify(expectedRows)) {
    throw new Error(
      "Membership commitment options had unexpected IDs, labels, or order.",
    );
  }
}

async function readAuditOutboxCounts() {
  const [counts] = await sql`
    select
      (select count(*)::integer from private.audit_events) as audit_count,
      (select count(*)::integer from private.outbox_events) as outbox_count
  `;
  return counts;
}

async function readCommitmentState(membershipId) {
  const [summary] = await sql`
    select jsonb_build_object(
      'skills', coalesce((
        select jsonb_agg(
          jsonb_build_array(commitment.skill_id, commitment.committed_at)
          order by commitment.skill_id
        )
        from public.project_membership_skill_commitments as commitment
        where commitment.membership_id = ${membershipId}::uuid
      ), '[]'::jsonb),
      'resources', coalesce((
        select jsonb_agg(
          jsonb_build_array(
            commitment.resource_need_id,
            commitment.committed_at
          )
          order by commitment.resource_need_id
        )
        from public.project_membership_resource_commitments as commitment
        where commitment.membership_id = ${membershipId}::uuid
      ), '[]'::jsonb),
      'events', (
        select count(*)
        from private.outbox_events as event
        where event.event_type = 'project.membership_commitments_updated'
          and event.payload ->> 'membership_id' = ${membershipId}
      )
    ) as state
  `;
  return summary.state;
}

async function assertNoCommitmentEvent(membershipId) {
  const [summary] = await sql`
    select count(*)::integer as event_count
    from private.outbox_events as event
    where event.event_type = 'project.membership_commitments_updated'
      and event.payload ->> 'membership_id' = ${membershipId}
  `;
  if (summary.event_count !== 0) {
    throw new Error("Acceptance seeding emitted a commitment-updated event.");
  }
}

async function assertIdentifierOnlyEventsWithoutNotifications(membershipId) {
  const [summary] = await sql`
    select
      count(*)::integer as total_events,
      count(*) filter (
        where (
          select count(*)
          from jsonb_object_keys(event.payload)
        ) = 5
          and event.payload ?& array[
            'project_id',
            'project_kind',
            'membership_id',
            'participant_profile_id',
            'actor_profile_id'
          ]
      )::integer as identifier_only_events,
      count(*) filter (
        where event.payload ?| array[
          'skill_ids',
          'resource_need_ids',
          'label',
          'title',
          'message',
          'count'
        ]
      )::integer as leaking_events,
      (
        select count(*)::integer
        from public.notifications as notification
        join private.outbox_events as notification_event
          on notification_event.id = notification.source_outbox_event_id
        where notification_event.event_type =
          'project.membership_commitments_updated'
          and notification_event.payload ->> 'membership_id' = ${membershipId}
      ) as notification_count
    from private.outbox_events as event
    where event.event_type = 'project.membership_commitments_updated'
      and event.payload ->> 'membership_id' = ${membershipId}
  `;
  if (
    summary.total_events === 0 ||
    summary.identifier_only_events !== summary.total_events ||
    summary.leaking_events !== 0 ||
    summary.notification_count !== 0
  ) {
    throw new Error(
      "Membership commitment events were not identifier-only or created notifications.",
    );
  }
}

async function createTavoloDraft(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration membership commitment Tavolo",
      p_summary: "Deterministic Tavolo commitment coverage.",
      p_description:
        "This recurring Project verifies resource-only membership commitments.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private commitment Tavolo location",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 4,
      p_day_of_month: null,
      p_local_start_time: "19:00:00",
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2098-01-01",
      p_people_capacity: 20,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a commitment Tavolo", error ?? {});
  }
  return data;
}

async function transitionTavolo(creator, operation, tavoloId) {
  const { data, error } = await creator.client.rpc(operation, {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: tavoloId,
  });
  if (error || data !== tavoloId) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error ?? {});
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a commitment profile", anchorError);
    }
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (updateError) {
    throw safeDatabaseFailure("complete a commitment profile", updateError);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project membership-commitment verifier",
  });
}

function track(pendingResult) {
  const tracked = { settled: false, promise: undefined };
  tracked.promise = Promise.resolve(pendingResult).then(
    (result) => {
      tracked.settled = true;
      return result;
    },
    (error) => {
      tracked.settled = true;
      throw error;
    },
  );
  // Observe rejection immediately even while the winner still owns the lock.
  // The result assertion still awaits this same rejecting promise and fails.
  void tracked.promise.catch(() => {});
  return tracked;
}

async function assertBlocked(tracked, action, transaction, operation) {
  const [{ pid }] = await transaction`select pg_backend_pid() as pid`;
  const lock = await observeMembershipRaceLock({
    tracked,
    action,
    winnerPid: pid,
    readWaiters: () => sql`
      select activity.pid, activity.wait_event_type, activity.wait_event,
        pg_blocking_pids(activity.pid) as blocking_pids
      from pg_stat_activity activity
      where activity.datname = current_database()
        and activity.usename = 'authenticator'
        and activity.pid <> ${pid}
        and ${pid} = any(pg_blocking_pids(activity.pid))
    `,
  });
  return { operation, ...lock };
}

async function assertTrackedRpcCode(tracked, expectedCode, action) {
  const result = await tracked.promise;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw safeDatabaseFailure(
      `${action} with the expected database error`,
      result.error ?? {},
    );
  }
}

async function assertTrackedRpcValue(tracked, expectedValue, action) {
  const result = await tracked.promise;
  if (result.error || result.data !== expectedValue) {
    throw safeDatabaseFailure(action, result.error ?? {});
  }
}

async function assertTrackedSuccess(tracked, action) {
  const result = await tracked.promise;
  if (result.error) {
    throw safeDatabaseFailure(action, result.error);
  }
}

async function assertRpcCode(pendingResult, expectedCode, action) {
  const result = await pendingResult;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  const failure = new Error(`Failed to ${action} (code ${code}).`);
  failure.membershipEvidence = membershipConstraintEvidence(error);
  return failure;
}
