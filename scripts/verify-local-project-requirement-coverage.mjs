import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
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

const sql = postgres(databaseUrl, { max: 8 });
const requiredSkillId = "d0000000-0000-4000-8001-000000000001";
const usefulSkillId = "d0000000-0000-4000-8003-000000000002";

try {
  await verifyLiveProjectRequirementCoverage();
} finally {
  await sql.end();
}

async function verifyLiveProjectRequirementCoverage() {
  const [creator, participantA, participantB, participantC, unrelated] =
    await Promise.all([
      signIn("requirement-coverage-creator@planets.invalid"),
      signIn("requirement-coverage-a@planets.invalid"),
      signIn("requirement-coverage-b@planets.invalid"),
      signIn("requirement-coverage-c@planets.invalid"),
      signIn("requirement-coverage-unrelated@planets.invalid"),
    ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Requirement Coverage Creator"),
    ensureCompleteProfile(participantA, "Requirement Coverage A"),
    ensureCompleteProfile(participantB, "Requirement Coverage B"),
    ensureCompleteProfile(participantC, "Requirement Coverage C"),
    ensureCompleteProfile(unrelated, "Requirement Coverage Unrelated"),
  ]);
  await Promise.all(
    [creator, participantA, participantB, participantC, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  await verifyPrimaryFlows(
    creator,
    participantA,
    participantB,
    participantC,
    unrelated,
  );
  await verifyClaimRace(creator, participantA, participantB);
  await verifyClaimVersusCommitmentCas(creator, participantA);
  await verifyLastSourceRemovalRace(creator, participantA, participantB);
  await verifyManualClearVersusClaim(creator, participantA);
  await verifyRequirementRemovalRaces(creator, participantA);

  console.log(
    "Confirmed real-OTP Proposal/Tavolo live requirement coverage, acceptance mapping, independent manual sources, claim-created commitments, authorized reads, membership and requirement cleanup, rejoin isolation, identifier-only transitions, and Project-lock concurrency.",
  );
}

async function verifyPrimaryFlows(
  creator,
  participantA,
  participantB,
  participantC,
  unrelated,
) {
  const proposalId = await createProposal(
    creator,
    "Coverage primary integration",
  );
  const neededResourceId = await createNeed(
    creator,
    proposalId,
    "Coverage primary needed resource",
  );
  const extraResourceId = await createNeed(
    creator,
    proposalId,
    "Coverage primary extra resource",
  );
  const alreadyFoundResourceId = await createNeed(
    creator,
    proposalId,
    "Coverage primary external resource",
  );
  const claimResourceId = await createNeed(
    creator,
    proposalId,
    "Coverage primary claim resource",
  );
  await publishProposal(creator, proposalId);

  const requestA = await requestToJoin(participantA, proposalId, {
    skillIds: [requiredSkillId, usefulSkillId],
    resourceNeedIds: [
      neededResourceId,
      extraResourceId,
      alreadyFoundResourceId,
    ],
  });
  const membershipA = await acceptRequest(creator, requestA, {
    neededSkillIds: [requiredSkillId],
    extraSkillIds: [usefulSkillId],
    neededResourceNeedIds: [neededResourceId],
    alreadyFoundResourceNeedIds: [alreadyFoundResourceId],
    extraResourceNeedIds: [extraResourceId],
  });

  const [acceptanceState] = await sql`
    select
      (select count(*)::integer
       from public.project_membership_skill_commitments
       where membership_id = ${membershipA}::uuid) as skill_commitments,
      (select count(*)::integer
       from public.project_membership_resource_commitments
       where membership_id = ${membershipA}::uuid) as resource_commitments,
      (select count(*)::integer
       from public.project_membership_skill_coverages
       where membership_id = ${membershipA}::uuid) as skill_coverages,
      (select count(*)::integer
       from public.project_membership_resource_coverages
       where membership_id = ${membershipA}::uuid) as resource_coverages,
      (select count(*)::integer
       from public.project_manual_resource_coverages
       where resource_need_id = ${alreadyFoundResourceId}::uuid
         and originating_request_id = ${requestA}::uuid) as manual_coverages
  `;
  if (
    acceptanceState.skill_commitments !== 2 ||
    acceptanceState.resource_commitments !== 2 ||
    acceptanceState.skill_coverages !== 1 ||
    acceptanceState.resource_coverages !== 1 ||
    acceptanceState.manual_coverages !== 1
  ) {
    throw new Error("Acceptance triage produced unexpected coverage state.");
  }

  const requestB = await requestToJoin(participantB, proposalId, {
    skillIds: [requiredSkillId],
    resourceNeedIds: [neededResourceId],
  });
  const membershipB = await acceptRequest(creator, requestB, {
    neededSkillIds: [requiredSkillId],
    neededResourceNeedIds: [neededResourceId],
  });
  await assertCoverageSourceCount(proposalId, "skill", requiredSkillId, 2);
  await assertCoverageSourceCount(proposalId, "resource", neededResourceId, 2);

  const requestC = await requestToJoin(participantC, proposalId);
  const membershipC = await acceptRequest(creator, requestC);

  await assertCoverageRead(creator, proposalId, {
    requirementId: neededResourceId,
    isCovered: true,
    viewerIsCovering: false,
    isManuallyCovered: false,
  });
  await assertCoverageRead(participantA, proposalId, {
    requirementId: neededResourceId,
    isCovered: true,
    viewerIsCovering: true,
    isManuallyCovered: false,
  });
  await assertRpcCode(
    unrelated.client.rpc("list_project_live_requirement_coverage", {
      p_expected_profile_id: unrelated.id,
      p_project_id: proposalId,
    }),
    "42501",
    "deny an unrelated coverage read",
  );

  await claimRequirement(
    participantA,
    proposalId,
    "skill",
    usefulSkillId,
    membershipA,
  );
  const claimEventCountBefore = await countCommitmentEvents(membershipA);
  await claimRequirement(
    participantA,
    proposalId,
    "resource",
    claimResourceId,
    membershipA,
  );
  if (
    (await countCommitmentEvents(membershipA)) !==
    claimEventCountBefore + 1
  ) {
    throw new Error(
      "A claim-created commitment emitted an unexpected event count.",
    );
  }
  await assertRpcCode(
    participantB.client.rpc("claim_project_requirement", {
      p_expected_participant_profile_id: participantB.id,
      p_project_id: proposalId,
      p_requirement_kind: "resource",
      p_requirement_id: claimResourceId,
    }),
    "PT409",
    "reject a claim after another source covers the requirement",
  );

  await setManualCoverage(
    creator,
    proposalId,
    "resource",
    neededResourceId,
    true,
  );
  await replaceCommitments(participantA, membershipA, {
    expectedSkillIds: [requiredSkillId, usefulSkillId],
    expectedResourceNeedIds: [
      neededResourceId,
      extraResourceId,
      claimResourceId,
    ],
    skillIds: [],
    resourceNeedIds: [extraResourceId, claimResourceId],
  });
  await replaceCommitments(participantB, membershipB, {
    expectedSkillIds: [requiredSkillId],
    expectedResourceNeedIds: [neededResourceId],
    skillIds: [],
    resourceNeedIds: [],
  });
  await assertCoverageSourceCount(proposalId, "resource", neededResourceId, 1);
  const neededAgainBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    neededResourceId,
  );
  await setManualCoverage(
    creator,
    proposalId,
    "resource",
    neededResourceId,
    false,
  );
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      neededResourceId,
    )) !==
    neededAgainBefore + 1
  ) {
    throw new Error(
      "Clearing the final manual source did not emit one transition.",
    );
  }

  await claimRequirement(
    participantC,
    proposalId,
    "resource",
    extraResourceId,
    membershipC,
  );
  await transitionMembership(
    participantC,
    "leave_project",
    "p_expected_participant_profile_id",
    membershipC,
  );
  await assertCoverageSourceCount(proposalId, "resource", extraResourceId, 0);
  const [endedHistory] = await sql`
    select
      count(*)::integer as commitment_count,
      (select count(*)::integer
       from public.project_membership_resource_coverages
       where membership_id = ${membershipC}::uuid) as coverage_count
    from public.project_membership_resource_commitments
    where membership_id = ${membershipC}::uuid
  `;
  if (
    endedHistory.commitment_count !== 1 ||
    endedHistory.coverage_count !== 0
  ) {
    throw new Error("Membership end did not retain commitment-only history.");
  }
  await assertRpcCode(
    participantC.client.rpc("list_project_live_requirement_coverage", {
      p_expected_profile_id: participantC.id,
      p_project_id: proposalId,
    }),
    "42501",
    "deny a former participant coverage read",
  );

  const rejoinRequest = await requestToJoin(participantC, proposalId);
  const rejoinMembership = await acceptRequest(creator, rejoinRequest);
  if (rejoinMembership === membershipC) {
    throw new Error("Rejoin reused an ended membership episode.");
  }

  const removalResourceId = await createNeed(
    creator,
    proposalId,
    "Coverage creator removal resource",
  );
  await claimRequirement(
    participantB,
    proposalId,
    "resource",
    removalResourceId,
    membershipB,
  );
  await transitionMembership(
    creator,
    "remove_project_member",
    "p_expected_creator_profile_id",
    membershipB,
  );
  await assertCoverageSourceCount(proposalId, "resource", removalResourceId, 0);
  const [removedHistory] = await sql`
    select
      (select count(*)::integer
       from public.project_membership_resource_commitments
       where membership_id = ${membershipB}::uuid
         and resource_need_id = ${removalResourceId}::uuid) as commitment_count,
      (select count(*)::integer
       from public.project_membership_resource_coverages
       where membership_id = ${membershipB}::uuid) as coverage_count
  `;
  if (
    removedHistory.commitment_count !== 1 ||
    removedHistory.coverage_count !== 0
  ) {
    throw new Error("Creator removal did not retain commitment-only history.");
  }

  await claimRequirement(
    participantC,
    proposalId,
    "resource",
    extraResourceId,
    rejoinMembership,
  );
  await claimRequirement(
    participantC,
    proposalId,
    "skill",
    requiredSkillId,
    rejoinMembership,
  );
  const neededAgainSkillBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    requiredSkillId,
  );
  await updateProposalSkills(creator, proposalId, [usefulSkillId], ["useful"]);
  await updateProposalSkills(
    creator,
    proposalId,
    [requiredSkillId, usefulSkillId],
    ["required", "useful"],
  );
  await assertCoverageSourceCount(proposalId, "skill", requiredSkillId, 0);
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      requiredSkillId,
    )) !== neededAgainSkillBefore
  ) {
    throw new Error(
      "Proposal skill removal emitted a false needed-again event.",
    );
  }

  const neededAgainCloseBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    extraResourceId,
  );
  await closeNeed(creator, extraResourceId);
  await assertCoverageSourceCount(proposalId, "resource", extraResourceId, 0);
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      extraResourceId,
    )) !== neededAgainCloseBefore
  ) {
    throw new Error("Resource closure emitted a false needed-again event.");
  }

  await verifyTavoloFlow(creator, participantC);
  await assertIdentifierOnlyCoverageEvents(proposalId);
}

async function verifyTavoloFlow(creator, participant) {
  const tavoloId = await createTavolo(creator);
  const firstNeedId = await createNeed(
    creator,
    tavoloId,
    "Coverage Tavolo accepted resource",
  );
  const claimNeedId = await createNeed(
    creator,
    tavoloId,
    "Coverage Tavolo claim resource",
  );
  await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
  const requestId = await requestToJoin(participant, tavoloId, {
    resourceNeedIds: [firstNeedId],
  });
  const membershipId = await acceptRequest(creator, requestId, {
    neededResourceNeedIds: [firstNeedId],
  });
  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  await claimRequirement(
    participant,
    tavoloId,
    "resource",
    claimNeedId,
    membershipId,
  );
  await assertRpcCode(
    participant.client.rpc("claim_project_requirement", {
      p_expected_participant_profile_id: participant.id,
      p_project_id: tavoloId,
      p_requirement_kind: "skill",
      p_requirement_id: requiredSkillId,
    }),
    "22023",
    "reject a Tavolo skill claim",
  );
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  await assertRpcCode(
    participant.client.rpc("list_project_live_requirement_coverage", {
      p_expected_profile_id: participant.id,
      p_project_id: tavoloId,
    }),
    "55000",
    "deny live coverage after Tavolo end",
  );
}

async function verifyClaimRace(creator, participantA, participantB) {
  const fixture = await createTwoMemberFixture(
    creator,
    participantA,
    participantB,
    "Coverage concurrent claim",
  );
  const requirementId = await createNeed(
    creator,
    fixture.proposalId,
    "Coverage concurrent claim resource",
  );
  const results = await Promise.all([
    participantA.client.rpc("claim_project_requirement", {
      p_expected_participant_profile_id: participantA.id,
      p_project_id: fixture.proposalId,
      p_requirement_kind: "resource",
      p_requirement_id: requirementId,
    }),
    participantB.client.rpc("claim_project_requirement", {
      p_expected_participant_profile_id: participantB.id,
      p_project_id: fixture.proposalId,
      p_requirement_kind: "resource",
      p_requirement_id: requirementId,
    }),
  ]);
  const successCount = results.filter((result) => !result.error).length;
  const conflictCount = results.filter(
    (result) => result.error?.code === "PT409",
  ).length;
  if (successCount !== 1 || conflictCount !== 1) {
    throw new Error(
      "Concurrent claims did not produce one winner and conflict.",
    );
  }
  await assertCoverageSourceCount(
    fixture.proposalId,
    "resource",
    requirementId,
    1,
  );
  if (
    (await countCoverageEvents(
      "project.requirement_covered",
      requirementId,
    )) !== 1
  ) {
    throw new Error("Concurrent claims emitted an unexpected covered count.");
  }
}

async function verifyClaimVersusCommitmentCas(creator, participant) {
  const fixture = await createMemberFixture(
    creator,
    participant,
    "Coverage claim before stale CAS",
  );
  const requirementId = await createNeed(
    creator,
    fixture.proposalId,
    "Coverage claim before stale CAS resource",
  );
  let blockedReplacement;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await transaction`
      select public.claim_project_requirement(
        ${participant.id}::uuid,
        ${fixture.proposalId}::uuid,
        'resource',
        ${requirementId}::uuid
      )
    `;
    blockedReplacement = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_membership_id: fixture.membershipId,
        p_expected_skill_ids: [],
        p_expected_resource_need_ids: [],
        p_skill_ids: [],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedReplacement, "stale CAS behind claim");
  });
  await assertTrackedRpcCode(
    blockedReplacement,
    "PT409",
    "reject stale commitment replacement after claim",
  );

  const replaceFirst = await createMemberFixture(
    creator,
    participant,
    "Coverage replacement before claim",
  );
  const replaceFirstRequirementId = await createNeed(
    creator,
    replaceFirst.proposalId,
    "Coverage replacement before claim resource",
  );
  let blockedClaim;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      replaceFirst.membershipId,
      [],
      [],
      [],
      [replaceFirstRequirementId],
    );
    blockedClaim = track(
      participant.client.rpc("claim_project_requirement", {
        p_expected_participant_profile_id: participant.id,
        p_project_id: replaceFirst.proposalId,
        p_requirement_kind: "resource",
        p_requirement_id: replaceFirstRequirementId,
      }),
    );
    await assertBlocked(blockedClaim, "claim behind commitment replacement");
  });
  await assertTrackedRpcValue(
    blockedClaim,
    replaceFirst.membershipId,
    "complete claim from latest commitment state",
  );
}

async function verifyLastSourceRemovalRace(
  creator,
  participantA,
  participantB,
) {
  const proposalId = await createProposal(
    creator,
    "Coverage concurrent source removal",
  );
  const requirementId = await createNeed(
    creator,
    proposalId,
    "Coverage concurrent source removal resource",
  );
  await publishProposal(creator, proposalId);
  const requestA = await requestToJoin(participantA, proposalId, {
    resourceNeedIds: [requirementId],
  });
  const membershipA = await acceptRequest(creator, requestA, {
    neededResourceNeedIds: [requirementId],
  });
  const requestB = await requestToJoin(participantB, proposalId, {
    resourceNeedIds: [requirementId],
  });
  const membershipB = await acceptRequest(creator, requestB, {
    neededResourceNeedIds: [requirementId],
  });
  const eventCountBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    requirementId,
  );
  let blockedRemoval;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participantA.id);
    await replaceInTransaction(
      transaction,
      participantA.id,
      membershipA,
      [],
      [requirementId],
      [],
      [],
    );
    blockedRemoval = track(
      participantB.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participantB.id,
        p_membership_id: membershipB,
        p_expected_skill_ids: [],
        p_expected_resource_need_ids: [requirementId],
        p_skill_ids: [],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedRemoval, "last source removal");
  });
  await assertTrackedRpcValue(
    blockedRemoval,
    membershipB,
    "complete the serialized last source removal",
  );
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      requirementId,
    )) !==
    eventCountBefore + 1
  ) {
    throw new Error(
      "Concurrent last-source removals did not emit exactly once.",
    );
  }
}

async function verifyManualClearVersusClaim(creator, participant) {
  const fixture = await createMemberFixture(
    creator,
    participant,
    "Coverage manual clear before claim",
  );
  const requirementId = await createNeed(
    creator,
    fixture.proposalId,
    "Coverage manual clear before claim resource",
  );
  await setManualCoverage(
    creator,
    fixture.proposalId,
    "resource",
    requirementId,
    true,
  );
  let blockedClaim;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.set_project_requirement_manual_coverage(
        ${creator.id}::uuid,
        ${fixture.proposalId}::uuid,
        'resource',
        ${requirementId}::uuid,
        false
      )
    `;
    blockedClaim = track(
      participant.client.rpc("claim_project_requirement", {
        p_expected_participant_profile_id: participant.id,
        p_project_id: fixture.proposalId,
        p_requirement_kind: "resource",
        p_requirement_id: requirementId,
      }),
    );
    await assertBlocked(blockedClaim, "claim behind manual clear");
  });
  await assertTrackedRpcValue(
    blockedClaim,
    fixture.membershipId,
    "cover the requirement after serialized manual clear",
  );
  await assertCoverageSourceCount(
    fixture.proposalId,
    "resource",
    requirementId,
    1,
  );
}

async function verifyRequirementRemovalRaces(creator, participant) {
  const closeFirst = await createMemberFixture(
    creator,
    participant,
    "Coverage close before removal",
  );
  const closeFirstNeedId = await createNeed(
    creator,
    closeFirst.proposalId,
    "Coverage close before removal resource",
  );
  await claimRequirement(
    participant,
    closeFirst.proposalId,
    "resource",
    closeFirstNeedId,
    closeFirst.membershipId,
  );
  const eventCountBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    closeFirstNeedId,
  );
  let blockedReplacement;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.close_project_resource_need(
        ${creator.id}::uuid,
        ${closeFirstNeedId}::uuid
      )
    `;
    blockedReplacement = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_membership_id: closeFirst.membershipId,
        p_expected_skill_ids: [],
        p_expected_resource_need_ids: [closeFirstNeedId],
        p_skill_ids: [],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedReplacement, "coverage release behind close");
  });
  await assertTrackedRpcValue(
    blockedReplacement,
    closeFirst.membershipId,
    "remove the stale commitment after close",
  );
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      closeFirstNeedId,
    )) !== eventCountBefore
  ) {
    throw new Error("Requirement-removal-first race emitted needed again.");
  }

  const releaseFirst = await createMemberFixture(
    creator,
    participant,
    "Coverage release before close",
  );
  const releaseFirstNeedId = await createNeed(
    creator,
    releaseFirst.proposalId,
    "Coverage release before close resource",
  );
  await claimRequirement(
    participant,
    releaseFirst.proposalId,
    "resource",
    releaseFirstNeedId,
    releaseFirst.membershipId,
  );
  const releaseEventCountBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    releaseFirstNeedId,
  );
  let blockedClose;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      releaseFirst.membershipId,
      [],
      [releaseFirstNeedId],
      [],
      [],
    );
    blockedClose = track(
      creator.client.rpc("close_project_resource_need", {
        p_expected_creator_profile_id: creator.id,
        p_resource_need_id: releaseFirstNeedId,
      }),
    );
    await assertBlocked(blockedClose, "resource close behind coverage release");
  });
  await assertTrackedRpcValue(
    blockedClose,
    releaseFirstNeedId,
    "close requirement after coverage release",
  );
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      releaseFirstNeedId,
    )) !==
    releaseEventCountBefore + 1
  ) {
    throw new Error("Coverage-release-first race lost its real transition.");
  }

  const skillRemovalFirst = await createMemberFixture(
    creator,
    participant,
    "Coverage skill removal before release",
  );
  await claimRequirement(
    participant,
    skillRemovalFirst.proposalId,
    "skill",
    requiredSkillId,
    skillRemovalFirst.membershipId,
  );
  const skillEventCountBefore = await countCoverageEvents(
    "project.requirement_needed_again",
    requiredSkillId,
  );
  let blockedSkillReplacement;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await updateProposalSkillsInTransaction(
      transaction,
      creator.id,
      skillRemovalFirst.proposalId,
      "Coverage skill removal before release",
      [usefulSkillId],
      ["useful"],
    );
    blockedSkillReplacement = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_membership_id: skillRemovalFirst.membershipId,
        p_expected_skill_ids: [requiredSkillId],
        p_expected_resource_need_ids: [],
        p_skill_ids: [],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(
      blockedSkillReplacement,
      "coverage release behind Proposal skill removal",
    );
  });
  await assertTrackedRpcValue(
    blockedSkillReplacement,
    skillRemovalFirst.membershipId,
    "remove stale commitment after Proposal skill removal",
  );
  if (
    (await countCoverageEvents(
      "project.requirement_needed_again",
      requiredSkillId,
    )) !== skillEventCountBefore
  ) {
    throw new Error("Proposal-skill-removal-first race emitted needed again.");
  }
}

async function createMemberFixture(creator, participant, title) {
  const proposalId = await createProposal(creator, title);
  await publishProposal(creator, proposalId);
  const requestId = await requestToJoin(participant, proposalId);
  const membershipId = await acceptRequest(creator, requestId);
  return { proposalId, membershipId };
}

async function createTwoMemberFixture(
  creator,
  participantA,
  participantB,
  title,
) {
  const proposalId = await createProposal(creator, title);
  await publishProposal(creator, proposalId);
  const [requestA, requestB] = await Promise.all([
    requestToJoin(participantA, proposalId),
    requestToJoin(participantB, proposalId),
  ]);
  const membershipA = await acceptRequest(creator, requestA);
  const membershipB = await acceptRequest(creator, requestB);
  return { proposalId, membershipA, membershipB };
}

async function createProposal(creator, title) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    ...proposalContent(
      title,
      [requiredSkillId, usefulSkillId],
      ["required", "useful"],
    ),
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a coverage Proposal", error ?? {});
  }
  return data;
}

function proposalContent(title, skillIds, skillImportances) {
  return {
    p_title: title,
    p_summary: "Deterministic live requirement coverage verification.",
    p_description:
      "This Project verifies current coverage sources and transitions.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Meet at the Trento verifier point.",
    p_exact_location_visibility: "participants",
    p_skill_ids: skillIds,
    p_skill_importances: skillImportances,
  };
}

async function publishProposal(creator, proposalId) {
  const { data, error } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("publish a coverage Proposal", error ?? {});
  }
}

async function updateProposalSkills(
  creator,
  proposalId,
  skillIds,
  skillImportances,
) {
  const { data, error } = await creator.client.rpc("update_own_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
    ...proposalContent(
      "Coverage primary integration",
      skillIds,
      skillImportances,
    ),
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("replace Proposal coverage skills", error ?? {});
  }
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
    throw safeDatabaseFailure("create a coverage resource need", error ?? {});
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
    throw safeDatabaseFailure("close a coverage resource need", error ?? {});
  }
}

async function requestToJoin(
  participant,
  projectId,
  { skillIds = [], resourceNeedIds = [] } = {},
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
    throw safeDatabaseFailure("create a coverage join request", error ?? {});
  }
  return data;
}

async function acceptRequest(
  creator,
  requestId,
  {
    neededSkillIds = [],
    alreadyFoundSkillIds = [],
    extraSkillIds = [],
    neededResourceNeedIds = [],
    alreadyFoundResourceNeedIds = [],
    extraResourceNeedIds = [],
  } = {},
) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
      p_needed_skill_ids: neededSkillIds,
      p_already_found_skill_ids: alreadyFoundSkillIds,
      p_extra_skill_ids: extraSkillIds,
      p_needed_resource_need_ids: neededResourceNeedIds,
      p_already_found_resource_need_ids: alreadyFoundResourceNeedIds,
      p_extra_resource_need_ids: extraResourceNeedIds,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("accept a coverage join request", error ?? {});
  }
  return data;
}

async function claimRequirement(
  participant,
  projectId,
  requirementKind,
  requirementId,
  expectedMembershipId,
) {
  const { data, error } = await participant.client.rpc(
    "claim_project_requirement",
    {
      p_expected_participant_profile_id: participant.id,
      p_project_id: projectId,
      p_requirement_kind: requirementKind,
      p_requirement_id: requirementId,
    },
  );
  if (error || data !== expectedMembershipId) {
    throw safeDatabaseFailure("claim a Project requirement", error ?? {});
  }
}

async function setManualCoverage(
  creator,
  projectId,
  requirementKind,
  requirementId,
  isCovered,
) {
  const { data, error } = await creator.client.rpc(
    "set_project_requirement_manual_coverage",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
      p_requirement_kind: requirementKind,
      p_requirement_id: requirementId,
      p_is_covered: isCovered,
    },
  );
  if (error || data !== requirementId) {
    throw safeDatabaseFailure("set manual Project coverage", error ?? {});
  }
}

async function replaceCommitments(
  user,
  membershipId,
  { expectedSkillIds, expectedResourceNeedIds, skillIds, resourceNeedIds },
) {
  const { data, error } = await user.client.rpc(
    "replace_project_membership_commitments",
    {
      p_expected_actor_profile_id: user.id,
      p_membership_id: membershipId,
      p_expected_skill_ids: expectedSkillIds,
      p_expected_resource_need_ids: expectedResourceNeedIds,
      p_skill_ids: skillIds,
      p_resource_need_ids: resourceNeedIds,
    },
  );
  if (error || data !== membershipId) {
    throw safeDatabaseFailure("replace coverage commitments", error ?? {});
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

async function assertCoverageRead(user, projectId, expectation) {
  const { data, error } = await user.client.rpc(
    "list_project_live_requirement_coverage",
    {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("read live Project coverage", error ?? {});
  }
  const row = data.find(
    (candidate) => candidate.requirement_id === expectation.requirementId,
  );
  if (
    !row ||
    row.is_covered !== expectation.isCovered ||
    row.viewer_is_covering !== expectation.viewerIsCovering ||
    row.is_manually_covered !== expectation.isManuallyCovered
  ) {
    throw new Error("The authorized coverage read returned unexpected state.");
  }
}

async function assertCoverageSourceCount(
  projectId,
  requirementKind,
  requirementId,
  expectedCount,
) {
  const [result] = await sql`
    select private.project_requirement_live_source_count(
      ${projectId}::uuid,
      ${requirementKind},
      ${requirementId}::uuid
    )::integer as source_count
  `;
  if (result.source_count !== expectedCount) {
    throw new Error("The live coverage source count was unexpected.");
  }
}

async function countCoverageEvents(eventType, requirementId) {
  const [result] = await sql`
    select count(*)::integer as event_count
    from private.outbox_events
    where event_type = ${eventType}
      and payload ->> 'requirement_id' = ${requirementId}
  `;
  return result.event_count;
}

async function countCommitmentEvents(membershipId) {
  const [result] = await sql`
    select count(*)::integer as event_count
    from private.outbox_events
    where event_type = 'project.membership_commitments_updated'
      and payload ->> 'membership_id' = ${membershipId}
  `;
  return result.event_count;
}

async function assertIdentifierOnlyCoverageEvents(projectId) {
  const [result] = await sql`
    select
      count(*)::integer as total_count,
      count(*) filter (
        where payload ?& array[
          'project_id',
          'project_kind',
          'requirement_kind',
          'requirement_id',
          'actor_profile_id'
        ]
      )::integer as identifier_count,
      count(*) filter (
        where payload ?| array[
          'label',
          'title',
          'request_message',
          'display_name',
          'email'
        ]
      )::integer as leaking_count
    from private.outbox_events
    where event_type in (
      'project.requirement_covered',
      'project.requirement_needed_again'
    )
      and payload ->> 'project_id' = ${projectId}
  `;
  if (
    result.total_count === 0 ||
    result.identifier_count !== result.total_count ||
    result.leaking_count !== 0
  ) {
    throw new Error("Coverage transition events were not identifier-only.");
  }
}

async function createTavolo(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Coverage Tavolo integration",
      p_summary: "Deterministic recurring coverage verification.",
      p_description: "This Tavolo verifies resource-only live coverage.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Meet at the Tavolo verifier point.",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 4,
      p_day_of_month: null,
      p_local_start_time: "19:00:00",
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2098-01-01",
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a coverage Tavolo", error ?? {});
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

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function updateProposalSkillsInTransaction(
  transaction,
  creatorId,
  proposalId,
  title,
  skillIds,
  skillImportances,
) {
  const content = proposalContent(title, skillIds, skillImportances);
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
      ${skillImportances}::text[]
    )
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

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a coverage profile", anchorError);
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
    throw safeDatabaseFailure("complete a coverage profile", updateError);
  }
}

function signIn(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project requirement-coverage verifier",
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
  return tracked;
}

async function assertBlocked(tracked, action) {
  await new Promise((resolve) => setTimeout(resolve, 250));
  if (tracked.settled) {
    throw new Error(`The ${action} operation did not wait for its lock.`);
  }
}

async function assertTrackedRpcCode(tracked, expectedCode, action) {
  const result = await tracked.promise;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
}

async function assertTrackedRpcValue(tracked, expectedValue, action) {
  const result = await tracked.promise;
  if (result.error || result.data !== expectedValue) {
    throw safeDatabaseFailure(action, result.error ?? {});
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
  return new Error(`Failed to ${action} (code ${code}).`);
}
