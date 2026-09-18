import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

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

const sql = postgres(databaseUrl, { max: 4 });
const requiredSkillId = "d0000000-0000-4000-8001-000000000001";
const usefulSkillId = "d0000000-0000-4000-8003-000000000002";
const unattachedSkillId = "d0000000-0000-4000-8006-000000000001";

try {
  await verifyProjectContributionSelections();
} finally {
  await sql.end();
}

async function verifyProjectContributionSelections() {
  const [creator, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("contribution-selection-creator@planets.invalid"),
    signInWithLocalOtp("contribution-selection-requester@planets.invalid"),
    signInWithLocalOtp("contribution-selection-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Contribution Selection Creator"),
    ensureCompleteProfile(requester, "Contribution Selection Requester"),
    ensureCompleteProfile(unrelated, "Contribution Selection Unrelated"),
  ]);

  const proposalId = await createProposalDraft(
    creator,
    "Integration contribution selection Proposal",
    [requiredSkillId, usefulSkillId],
    ["required", "useful"],
  );
  const firstNeedId = await createNeed(
    creator,
    proposalId,
    "Paint and brushes",
  );
  const secondNeedId = await createNeed(creator, proposalId, "Transport van");
  await publishProposal(creator, proposalId);

  const otherProposalId = await createProposalDraft(
    creator,
    "Integration unrelated-need Proposal",
    [],
    [],
  );
  const otherNeedId = await createNeed(
    creator,
    otherProposalId,
    "Unrelated Project need",
  );
  await publishProposal(creator, otherProposalId);

  await assertRpcCode(
    requester.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: requester.id,
      p_project_id: proposalId,
      p_request_message: null,
      p_skill_ids: [unattachedSkillId],
      p_resource_need_ids: [],
    }),
    "22023",
    "reject an unattached Proposal skill",
  );
  await assertRpcCode(
    requester.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: requester.id,
      p_project_id: proposalId,
      p_request_message: null,
      p_skill_ids: [],
      p_resource_need_ids: [otherNeedId],
    }),
    "22023",
    "reject another Project resource need",
  );

  const withdrawnRequestId = await requestToJoin(
    requester,
    proposalId,
    "Integration request marker that must not reach events",
    [usefulSkillId, requiredSkillId],
    [secondNeedId, firstNeedId],
  );
  await assertSelections(requester, withdrawnRequestId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["skill", usefulSkillId, "Woodworking"],
    ["resource", firstNeedId, "Paint and brushes"],
    ["resource", secondNeedId, "Transport van"],
  ]);
  await assertSelections(creator, withdrawnRequestId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["skill", usefulSkillId, "Woodworking"],
    ["resource", firstNeedId, "Paint and brushes"],
    ["resource", secondNeedId, "Transport van"],
  ]);
  await assertRpcCode(
    unrelated.client.rpc(
      "list_own_project_join_request_contribution_selections",
      {
        p_expected_profile_id: unrelated.id,
        p_request_id: withdrawnRequestId,
      },
    ),
    "42501",
    "deny unrelated selection history",
  );
  await transitionRequest(
    requester,
    "withdraw_project_join_request",
    withdrawnRequestId,
    "p_expected_requester_profile_id",
  );

  const rejectedRequestId = await requestToJoin(
    requester,
    proposalId,
    null,
    [usefulSkillId],
    [secondNeedId],
  );
  await transitionRequest(
    creator,
    "reject_project_join_request",
    rejectedRequestId,
    "p_expected_creator_profile_id",
  );

  const acceptedRequestId = await requestToJoin(
    requester,
    proposalId,
    null,
    [requiredSkillId],
    [firstNeedId],
  );
  await assertRpcCode(
    creator.client.rpc("accept_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: acceptedRequestId,
    }),
    "22023",
    "require triage for a selected-contribution request",
  );
  await acceptRequest(
    creator,
    acceptedRequestId,
    [requiredSkillId],
    [firstNeedId],
  );
  await assertAcceptanceState(acceptedRequestId, {
    decisions: [
      ["skill", requiredSkillId, "needed"],
      ["resource", firstNeedId, "needed"],
    ],
    commitments: [
      ["skill", requiredSkillId],
      ["resource", firstNeedId],
    ],
  });
  await updateNeed(creator, firstNeedId, "Updated paint supplies");
  await closeNeed(creator, firstNeedId);
  await updateProposalSkills(creator, proposalId, [], []);

  await assertSelections(requester, acceptedRequestId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["resource", firstNeedId, "Updated paint supplies"],
  ]);
  await assertHistoricalSelectionCounts([
    withdrawnRequestId,
    rejectedRequestId,
    acceptedRequestId,
  ]);

  const backwardProposalId = await createProposalDraft(
    creator,
    "Integration backward-compatible Proposal",
    [],
    [],
  );
  await publishProposal(creator, backwardProposalId);
  const { data: backwardRequestId, error: backwardError } =
    await unrelated.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: unrelated.id,
      p_project_id: backwardProposalId,
      p_request_message: null,
    });
  if (backwardError || typeof backwardRequestId !== "string") {
    throw safeDatabaseFailure(
      "preserve the existing three-argument request call",
      backwardError ?? {},
    );
  }
  await assertSelections(unrelated, backwardRequestId, []);
  await acceptZeroSelectionRequest(creator, backwardRequestId);

  const tavoloId = await createTavoloDraft(creator);
  const tavoloNeedId = await createNeed(
    creator,
    tavoloId,
    "Community room chairs",
  );
  await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
  await assertRpcCode(
    unrelated.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: unrelated.id,
      p_project_id: tavoloId,
      p_request_message: null,
      p_skill_ids: [requiredSkillId],
      p_resource_need_ids: [],
    }),
    "22023",
    "reject a Tavolo skill selection",
  );
  const tavoloRequestId = await requestToJoin(
    unrelated,
    tavoloId,
    null,
    [],
    [tavoloNeedId],
  );
  await assertSelections(unrelated, tavoloRequestId, [
    ["resource", tavoloNeedId, "Community room chairs"],
  ]);
  await acceptRequest(creator, tavoloRequestId, [], [tavoloNeedId]);

  await verifyMixedAcceptanceAndRejoin(creator, requester);
  await verifyAcceptanceSerialization(creator, unrelated);

  const raceRequestIds = await verifyResourceNeedSerialization(
    creator,
    requester,
  );
  raceRequestIds.push(
    ...(await verifyProposalSkillSerialization(creator, unrelated)),
  );

  await assertIdentifierOnlyEvents([
    withdrawnRequestId,
    rejectedRequestId,
    acceptedRequestId,
    backwardRequestId,
    tavoloRequestId,
    ...raceRequestIds,
  ]);

  console.log(
    "Confirmed real-OTP Proposal and Tavolo contribution selections, exact acceptance triage, decision/commitment separation, rejoin independence, identifier-only events, and Project/need/skill/request lock serialization.",
  );
}

async function verifyMixedAcceptanceAndRejoin(creator, requester) {
  const proposalId = await createProposalDraft(
    creator,
    "Integration mixed acceptance triage",
    [requiredSkillId, usefulSkillId],
    ["required", "useful"],
  );
  const extraNeedId = await createNeed(creator, proposalId, "Extra supplies");
  const foundNeedId = await createNeed(
    creator,
    proposalId,
    "Already sourced supplies",
  );
  await publishProposal(creator, proposalId);

  const requestId = await requestToJoin(
    requester,
    proposalId,
    "Private acceptance marker",
    [requiredSkillId, usefulSkillId],
    [extraNeedId, foundNeedId],
  );
  const membershipId = await acceptTriagedRequest(creator, requestId, {
    neededSkillIds: [requiredSkillId],
    alreadyFoundSkillIds: [usefulSkillId],
    extraResourceNeedIds: [extraNeedId],
    alreadyFoundResourceNeedIds: [foundNeedId],
  });
  await assertAcceptanceState(requestId, {
    decisions: [
      ["skill", requiredSkillId, "needed"],
      ["skill", usefulSkillId, "already_found"],
      ["resource", extraNeedId, "extra"],
      ["resource", foundNeedId, "already_found"],
    ],
    commitments: [
      ["skill", requiredSkillId],
      ["resource", extraNeedId],
    ],
  });
  await assertAcceptedEventPrivacy(requestId);

  const { error: editError } = await creator.client.rpc(
    "replace_project_membership_commitments",
    {
      p_expected_actor_profile_id: creator.id,
      p_membership_id: membershipId,
      p_expected_skill_ids: [requiredSkillId],
      p_expected_resource_need_ids: [extraNeedId],
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [foundNeedId],
    },
  );
  if (editError) {
    throw safeDatabaseFailure(
      "edit current commitments after triaged acceptance",
      editError,
    );
  }
  await assertDecisionCount(requestId, 4);

  await transitionMembership(
    requester,
    "leave_project",
    membershipId,
    "p_expected_participant_profile_id",
  );
  const rejoinRequestId = await requestToJoin(
    requester,
    proposalId,
    null,
    [usefulSkillId],
    [extraNeedId],
  );
  const rejoinMembershipId = await acceptTriagedRequest(
    creator,
    rejoinRequestId,
    {
      neededSkillIds: [usefulSkillId],
      extraResourceNeedIds: [extraNeedId],
    },
  );
  if (rejoinMembershipId === membershipId) {
    throw new Error("Acceptance triage reused an ended membership episode.");
  }
  await assertAcceptanceState(rejoinRequestId, {
    decisions: [
      ["skill", usefulSkillId, "needed"],
      ["resource", extraNeedId, "extra"],
    ],
    commitments: [
      ["skill", usefulSkillId],
      ["resource", extraNeedId],
    ],
  });
}

async function verifyResourceNeedSerialization(creator, requester) {
  const closeFirstProposal = await createProposalDraft(
    creator,
    "Integration close-first contribution race",
    [requiredSkillId],
    ["required"],
  );
  const closeFirstNeed = await createNeed(
    creator,
    closeFirstProposal,
    "Close-first need",
  );
  await publishProposal(creator, closeFirstProposal);

  let blockedRequest;
  let blockedRequestSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.close_project_resource_need(
        ${creator.id}::uuid,
        ${closeFirstNeed}::uuid
      )
    `;
    blockedRequest = Promise.resolve(
      requester.client.rpc("request_to_join_project", {
        p_expected_requester_profile_id: requester.id,
        p_project_id: closeFirstProposal,
        p_request_message: null,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [closeFirstNeed],
      }),
    );
    blockedRequest.then(
      () => {
        blockedRequestSettled = true;
      },
      () => {
        blockedRequestSettled = true;
      },
    );
    await delay(250);
    if (blockedRequestSettled) {
      throw new Error(
        "A contribution request did not wait behind resource-need closure.",
      );
    }
  });
  await assertRpcCode(
    blockedRequest,
    "22023",
    "reject a need selection after closure wins",
  );

  const requestFirstProposal = await createProposalDraft(
    creator,
    "Integration request-first resource race",
    [requiredSkillId],
    ["required"],
  );
  const requestFirstNeed = await createNeed(
    creator,
    requestFirstProposal,
    "Request-first need",
  );
  await publishProposal(creator, requestFirstProposal);

  let requestFirstId;
  let blockedClose;
  let blockedCloseSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    const [requestRow] = await transaction`
      select public.request_to_join_project(
        ${requester.id}::uuid,
        ${requestFirstProposal}::uuid,
        null,
        array[${requiredSkillId}::uuid],
        array[${requestFirstNeed}::uuid]
      ) as request_id
    `;
    requestFirstId = requestRow.request_id;
    blockedClose = Promise.resolve(
      creator.client.rpc("close_project_resource_need", {
        p_expected_creator_profile_id: creator.id,
        p_resource_need_id: requestFirstNeed,
      }),
    );
    blockedClose.then(
      () => {
        blockedCloseSettled = true;
      },
      () => {
        blockedCloseSettled = true;
      },
    );
    await delay(250);
    if (blockedCloseSettled) {
      throw new Error(
        "Resource-need closure did not wait behind contribution selection.",
      );
    }
  });
  const closeResult = await blockedClose;
  if (closeResult.error || closeResult.data !== requestFirstNeed) {
    throw safeDatabaseFailure(
      "complete closure after a request-first resource race",
      closeResult.error ?? {},
    );
  }
  await assertSelections(requester, requestFirstId, [
    ["skill", requiredSkillId, "Mural painting"],
    ["resource", requestFirstNeed, "Request-first need"],
  ]);
  return [requestFirstId];
}

async function verifyProposalSkillSerialization(creator, requester) {
  const updateFirstProposal = await createProposalDraft(
    creator,
    "Integration update-first skill race",
    [requiredSkillId],
    ["required"],
  );
  await publishProposal(creator, updateFirstProposal);

  let blockedRequest;
  let blockedRequestSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await updateProposalSkillsInTransaction(
      transaction,
      creator.id,
      updateFirstProposal,
      "Integration update-first skill race",
      [],
      [],
    );
    blockedRequest = Promise.resolve(
      requester.client.rpc("request_to_join_project", {
        p_expected_requester_profile_id: requester.id,
        p_project_id: updateFirstProposal,
        p_request_message: null,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [],
      }),
    );
    blockedRequest.then(
      () => {
        blockedRequestSettled = true;
      },
      () => {
        blockedRequestSettled = true;
      },
    );
    await delay(250);
    if (blockedRequestSettled) {
      throw new Error(
        "A contribution request did not wait behind Proposal skill replacement.",
      );
    }
  });
  await assertRpcCode(
    blockedRequest,
    "22023",
    "reject a skill selection after requirement removal wins",
  );

  const requestFirstProposal = await createProposalDraft(
    creator,
    "Integration request-first skill race",
    [requiredSkillId],
    ["required"],
  );
  await publishProposal(creator, requestFirstProposal);

  let requestFirstId;
  let blockedUpdate;
  let blockedUpdateSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    const [requestRow] = await transaction`
      select public.request_to_join_project(
        ${requester.id}::uuid,
        ${requestFirstProposal}::uuid,
        null,
        array[${requiredSkillId}::uuid],
        '{}'::uuid[]
      ) as request_id
    `;
    requestFirstId = requestRow.request_id;
    blockedUpdate = updateProposalSkills(
      creator,
      requestFirstProposal,
      [],
      [],
      "Integration request-first skill race",
    );
    blockedUpdate.then(
      () => {
        blockedUpdateSettled = true;
      },
      () => {
        blockedUpdateSettled = true;
      },
    );
    await delay(250);
    if (blockedUpdateSettled) {
      throw new Error(
        "Proposal skill replacement did not wait behind contribution selection.",
      );
    }
  });
  await blockedUpdate;
  await assertSelections(requester, requestFirstId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
  return [requestFirstId];
}

async function verifyAcceptanceSerialization(creator, requester) {
  const closeFirstProposal = await createProposalDraft(
    creator,
    "Integration triage close-first race",
    [],
    [],
  );
  const closeFirstNeed = await createNeed(
    creator,
    closeFirstProposal,
    "Triage close-first need",
  );
  await publishProposal(creator, closeFirstProposal);
  const closeFirstRequest = await requestToJoin(
    requester,
    closeFirstProposal,
    null,
    [],
    [closeFirstNeed],
  );
  let blockedAcceptance;
  let blockedAcceptanceSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.close_project_resource_need(
        ${creator.id}::uuid,
        ${closeFirstNeed}::uuid
      )
    `;
    blockedAcceptance = Promise.resolve(
      creator.client.rpc("accept_project_join_request", {
        p_expected_creator_profile_id: creator.id,
        p_request_id: closeFirstRequest,
        p_needed_skill_ids: [],
        p_already_found_skill_ids: [],
        p_extra_skill_ids: [],
        p_needed_resource_need_ids: [closeFirstNeed],
        p_already_found_resource_need_ids: [],
        p_extra_resource_need_ids: [],
      }),
    );
    blockedAcceptance.then(
      () => {
        blockedAcceptanceSettled = true;
      },
      () => {
        blockedAcceptanceSettled = true;
      },
    );
    await delay(250);
    if (blockedAcceptanceSettled) {
      throw new Error(
        "Needed-resource acceptance did not wait behind closure.",
      );
    }
  });
  await assertRpcCode(
    blockedAcceptance,
    "22023",
    "reject needed-resource triage when closure wins",
  );
  await acceptTriagedRequest(creator, closeFirstRequest, {
    extraResourceNeedIds: [closeFirstNeed],
  });

  const acceptFirstProposal = await createProposalDraft(
    creator,
    "Integration triage accept-first race",
    [],
    [],
  );
  const acceptFirstNeed = await createNeed(
    creator,
    acceptFirstProposal,
    "Triage accept-first need",
  );
  await publishProposal(creator, acceptFirstProposal);
  const acceptFirstRequest = await requestToJoin(
    requester,
    acceptFirstProposal,
    null,
    [],
    [acceptFirstNeed],
  );
  let blockedClose;
  let blockedCloseSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await acceptInTransaction(transaction, creator.id, acceptFirstRequest, {
      neededResourceNeedIds: [acceptFirstNeed],
    });
    blockedClose = Promise.resolve(
      creator.client.rpc("close_project_resource_need", {
        p_expected_creator_profile_id: creator.id,
        p_resource_need_id: acceptFirstNeed,
      }),
    );
    blockedClose.then(
      () => {
        blockedCloseSettled = true;
      },
      () => {
        blockedCloseSettled = true;
      },
    );
    await delay(250);
    if (blockedCloseSettled) {
      throw new Error(
        "Resource closure did not wait behind needed acceptance.",
      );
    }
  });
  const closeResult = await blockedClose;
  if (closeResult.error || closeResult.data !== acceptFirstNeed) {
    throw safeDatabaseFailure(
      "close a need after acceptance wins serialization",
      closeResult.error ?? {},
    );
  }

  const removeFirstProposal = await createProposalDraft(
    creator,
    "Integration triage remove-first skill race",
    [requiredSkillId],
    ["required"],
  );
  await publishProposal(creator, removeFirstProposal);
  const removeFirstRequest = await requestToJoin(
    requester,
    removeFirstProposal,
    null,
    [requiredSkillId],
    [],
  );
  let blockedSkillAcceptance;
  let blockedSkillAcceptanceSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await updateProposalSkillsInTransaction(
      transaction,
      creator.id,
      removeFirstProposal,
      "Integration triage remove-first skill race",
      [],
      [],
    );
    blockedSkillAcceptance = Promise.resolve(
      creator.client.rpc(
        "accept_project_join_request",
        triageArguments(creator.id, removeFirstRequest, {
          neededSkillIds: [requiredSkillId],
        }),
      ),
    );
    blockedSkillAcceptance.then(
      () => {
        blockedSkillAcceptanceSettled = true;
      },
      () => {
        blockedSkillAcceptanceSettled = true;
      },
    );
    await delay(250);
    if (blockedSkillAcceptanceSettled) {
      throw new Error("Needed-skill acceptance did not wait behind removal.");
    }
  });
  await assertRpcCode(
    blockedSkillAcceptance,
    "22023",
    "reject needed-skill triage when removal wins",
  );
  await acceptTriagedRequest(creator, removeFirstRequest, {
    extraSkillIds: [requiredSkillId],
  });

  const skillAcceptFirstProposal = await createProposalDraft(
    creator,
    "Integration triage accept-first skill race",
    [requiredSkillId],
    ["required"],
  );
  await publishProposal(creator, skillAcceptFirstProposal);
  const skillAcceptFirstRequest = await requestToJoin(
    requester,
    skillAcceptFirstProposal,
    null,
    [requiredSkillId],
    [],
  );
  let blockedSkillRemoval;
  let blockedSkillRemovalSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await acceptInTransaction(
      transaction,
      creator.id,
      skillAcceptFirstRequest,
      { neededSkillIds: [requiredSkillId] },
    );
    blockedSkillRemoval = updateProposalSkills(
      creator,
      skillAcceptFirstProposal,
      [],
      [],
      "Integration triage accept-first skill race",
    );
    blockedSkillRemoval.then(
      () => {
        blockedSkillRemovalSettled = true;
      },
      () => {
        blockedSkillRemovalSettled = true;
      },
    );
    await delay(250);
    if (blockedSkillRemovalSettled) {
      throw new Error("Skill removal did not wait behind needed acceptance.");
    }
  });
  await blockedSkillRemoval;

  const withdrawProposal = await createProposalDraft(
    creator,
    "Integration withdraw-first triage race",
    [requiredSkillId],
    ["required"],
  );
  await publishProposal(creator, withdrawProposal);
  const withdrawRequest = await requestToJoin(
    requester,
    withdrawProposal,
    null,
    [requiredSkillId],
    [],
  );
  let blockedWithdrawAcceptance;
  let blockedWithdrawAcceptanceSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    await transaction`
      select public.withdraw_project_join_request(
        ${requester.id}::uuid,
        ${withdrawRequest}::uuid
      )
    `;
    blockedWithdrawAcceptance = Promise.resolve(
      creator.client.rpc(
        "accept_project_join_request",
        triageArguments(creator.id, withdrawRequest, {
          neededSkillIds: [requiredSkillId],
        }),
      ),
    );
    blockedWithdrawAcceptance.then(
      () => {
        blockedWithdrawAcceptanceSettled = true;
      },
      () => {
        blockedWithdrawAcceptanceSettled = true;
      },
    );
    await delay(250);
    if (blockedWithdrawAcceptanceSettled) {
      throw new Error("Acceptance did not wait behind request withdrawal.");
    }
  });
  await assertRpcCode(
    blockedWithdrawAcceptance,
    "55000",
    "reject acceptance when withdrawal wins",
  );
  await assertDecisionCount(withdrawRequest, 0);
}

async function acceptInTransaction(transaction, creatorId, requestId, triage) {
  const args = normalizedTriage(triage);
  await transaction`
    select public.accept_project_join_request(
      ${creatorId}::uuid,
      ${requestId}::uuid,
      ${args.neededSkillIds}::uuid[],
      ${args.alreadyFoundSkillIds}::uuid[],
      ${args.extraSkillIds}::uuid[],
      ${args.neededResourceNeedIds}::uuid[],
      ${args.alreadyFoundResourceNeedIds}::uuid[],
      ${args.extraResourceNeedIds}::uuid[]
    )
  `;
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function createProposalDraft(creator, title, skillIds, skillImportances) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    ...proposalContent(title, skillIds, skillImportances),
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a contribution Proposal", error ?? {});
  }
  return data;
}

async function updateProposalSkills(
  creator,
  proposalId,
  skillIds,
  skillImportances,
  title = "Integration contribution selection Proposal",
) {
  const { data, error } = await creator.client.rpc("update_own_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
    ...proposalContent(title, skillIds, skillImportances),
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("replace Proposal skills", error ?? {});
  }
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

function proposalContent(title, skillIds, skillImportances) {
  return {
    p_title: title,
    p_summary: "Deterministic contribution-selection integration coverage.",
    p_description:
      "This Project verifies historical join-request contribution selections.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: null,
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
    throw safeDatabaseFailure("publish a contribution Proposal", error ?? {});
  }
}

async function createTavoloDraft(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration contribution selection Tavolo",
      p_summary: "Deterministic Tavolo contribution-selection coverage.",
      p_description:
        "This recurring Project verifies resource-only request selections.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: null,
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
    throw safeDatabaseFailure("create a contribution Tavolo", error ?? {});
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
    throw safeDatabaseFailure("create a selectable resource need", error ?? {});
  }
  return data;
}

async function updateNeed(creator, resourceNeedId, title) {
  const { data, error } = await creator.client.rpc(
    "update_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: resourceNeedId,
      p_title: title,
      p_details: null,
    },
  );
  if (error || data !== resourceNeedId) {
    throw safeDatabaseFailure("update a selected resource need", error ?? {});
  }
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
    throw safeDatabaseFailure("close a selected resource need", error ?? {});
  }
}

async function requestToJoin(
  requester,
  projectId,
  message,
  skillIds,
  resourceNeedIds,
) {
  const { data, error } = await requester.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: requester.id,
      p_project_id: projectId,
      p_request_message: message,
      p_skill_ids: skillIds,
      p_resource_need_ids: resourceNeedIds,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "create a contribution-aware join request",
      error ?? {},
    );
  }
  return data;
}

async function transitionRequest(user, operation, requestId, identityKey) {
  const { data, error } = await user.client.rpc(operation, {
    [identityKey]: user.id,
    p_request_id: requestId,
  });
  if (error || data !== requestId) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error ?? {});
  }
}

async function acceptRequest(
  creator,
  requestId,
  neededSkillIds,
  neededResourceNeedIds,
) {
  return acceptTriagedRequest(creator, requestId, {
    neededSkillIds,
    neededResourceNeedIds,
  });
}

async function acceptTriagedRequest(creator, requestId, triage) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    triageArguments(creator.id, requestId, triage),
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept a contribution-aware join request",
      error ?? {},
    );
  }
  return data;
}

async function acceptZeroSelectionRequest(creator, requestId) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept a zero-selection join request",
      error ?? {},
    );
  }
  return data;
}

function triageArguments(creatorId, requestId, triage) {
  const args = normalizedTriage(triage);
  return {
    p_expected_creator_profile_id: creatorId,
    p_request_id: requestId,
    p_needed_skill_ids: args.neededSkillIds,
    p_already_found_skill_ids: args.alreadyFoundSkillIds,
    p_extra_skill_ids: args.extraSkillIds,
    p_needed_resource_need_ids: args.neededResourceNeedIds,
    p_already_found_resource_need_ids: args.alreadyFoundResourceNeedIds,
    p_extra_resource_need_ids: args.extraResourceNeedIds,
  };
}

function normalizedTriage(triage = {}) {
  return {
    neededSkillIds: triage.neededSkillIds ?? [],
    alreadyFoundSkillIds: triage.alreadyFoundSkillIds ?? [],
    extraSkillIds: triage.extraSkillIds ?? [],
    neededResourceNeedIds: triage.neededResourceNeedIds ?? [],
    alreadyFoundResourceNeedIds: triage.alreadyFoundResourceNeedIds ?? [],
    extraResourceNeedIds: triage.extraResourceNeedIds ?? [],
  };
}

async function transitionMembership(
  user,
  operation,
  membershipId,
  identityKey,
) {
  const { data, error } = await user.client.rpc(operation, {
    [identityKey]: user.id,
    p_membership_id: membershipId,
  });
  if (error || data !== membershipId) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error ?? {});
  }
}

async function assertAcceptanceState(requestId, expected) {
  const decisions = await sql`
    select kind, item_id, disposition
    from (
      select
        'skill'::text as kind,
        decision.skill_id::text as item_id,
        decision.disposition
      from public.project_join_request_skill_acceptance_decisions as decision
      where decision.request_id = ${requestId}::uuid
      union all
      select
        'resource'::text,
        decision.resource_need_id::text,
        decision.disposition
      from public.project_join_request_resource_acceptance_decisions as decision
      where decision.request_id = ${requestId}::uuid
    ) as accepted
    order by kind, item_id
  `;
  const commitments = await sql`
    select kind, item_id
    from (
      select
        'skill'::text as kind,
        commitment.skill_id::text as item_id
      from public.project_membership_skill_commitments as commitment
      join public.project_memberships as membership
        on membership.id = commitment.membership_id
      where membership.originating_request_id = ${requestId}::uuid
      union all
      select
        'resource'::text,
        commitment.resource_need_id::text
      from public.project_membership_resource_commitments as commitment
      join public.project_memberships as membership
        on membership.id = commitment.membership_id
      where membership.originating_request_id = ${requestId}::uuid
    ) as current_commitment
    order by kind, item_id
  `;
  const actualDecisions = decisions.map((row) => [
    row.kind,
    row.item_id,
    row.disposition,
  ]);
  const actualCommitments = commitments.map((row) => [row.kind, row.item_id]);
  const normalize = (rows) =>
    [...rows].sort((left, right) =>
      JSON.stringify(left).localeCompare(JSON.stringify(right)),
    );
  if (
    JSON.stringify(normalize(actualDecisions)) !==
      JSON.stringify(normalize(expected.decisions)) ||
    JSON.stringify(normalize(actualCommitments)) !==
      JSON.stringify(normalize(expected.commitments))
  ) {
    throw new Error(
      "Acceptance decisions or seeded commitments did not match exact triage.",
    );
  }

  const [integrity] = await sql`
    select
      (
        select count(*)::integer
        from public.project_join_request_skill_selections
        where request_id = ${requestId}::uuid
      ) + (
        select count(*)::integer
        from public.project_join_request_resource_selections
        where request_id = ${requestId}::uuid
      ) as selection_count,
      (
        select count(*)::integer
        from public.project_group_chats as chat
        join public.project_memberships as membership
          on membership.project_id = chat.project_id
        where membership.originating_request_id = ${requestId}::uuid
      ) as chat_count
  `;
  if (
    integrity.selection_count !== expected.decisions.length ||
    integrity.chat_count !== 1
  ) {
    throw new Error(
      "Triaged acceptance changed request selections or missed chat activation.",
    );
  }
}

async function assertDecisionCount(requestId, expectedCount) {
  const [row] = await sql`
    select (
      select count(*)::integer
      from public.project_join_request_skill_acceptance_decisions
      where request_id = ${requestId}::uuid
    ) + (
      select count(*)::integer
      from public.project_join_request_resource_acceptance_decisions
      where request_id = ${requestId}::uuid
    ) as decision_count
  `;
  if (row.decision_count !== expectedCount) {
    throw new Error("Acceptance decision history changed unexpectedly.");
  }
}

async function assertAcceptedEventPrivacy(requestId) {
  const [summary] = await sql`
    select
      count(*)::integer as total_events,
      count(*) filter (
        where jsonb_object_length(event.payload) = 7
          and event.payload ?& array[
            'project_kind',
            'request_id',
            'requester_profile_id',
            'membership_id',
            'status',
            'project_id',
            'actor_profile_id'
          ]
      )::integer as identifier_only_events,
      count(*) filter (
        where event.payload ?| array[
          'needed_skill_ids',
          'already_found_skill_ids',
          'extra_skill_ids',
          'needed_resource_need_ids',
          'already_found_resource_need_ids',
          'extra_resource_need_ids',
          'request_message',
          'label',
          'title'
        ]
          or event.payload::text ilike '%private acceptance marker%'
      )::integer as private_leaks
    from private.outbox_events as event
    where event.event_type = 'project.join_request_accepted'
      and event.payload ->> 'request_id' = ${requestId}
  `;
  if (
    summary.total_events !== 1 ||
    summary.identifier_only_events !== 1 ||
    summary.private_leaks !== 0
  ) {
    throw new Error("Acceptance event changed its identifier-only contract.");
  }
}

async function assertSelections(user, requestId, expectedRows) {
  const { data, error } = await user.client.rpc(
    "list_own_project_join_request_contribution_selections",
    {
      p_expected_profile_id: user.id,
      p_request_id: requestId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("read contribution selections", error ?? {});
  }
  const actualRows = data.map((row) => [
    row.selection_kind,
    row.selection_id,
    row.label,
  ]);
  if (JSON.stringify(actualRows) !== JSON.stringify(expectedRows)) {
    throw new Error(
      "Contribution selections had unexpected identity, labels, or order.",
    );
  }
}

async function assertHistoricalSelectionCounts(requestIds) {
  const [summary] = await sql`
    select
      count(*) filter (
        where selected.request_id = any(${requestIds}::uuid[])
      )::integer as skill_count,
      (
        select count(*)::integer
        from public.project_join_request_resource_selections as resource
        where resource.request_id = any(${requestIds}::uuid[])
      ) as resource_count
    from public.project_join_request_skill_selections as selected
  `;
  if (summary.skill_count !== 4 || summary.resource_count !== 4) {
    throw new Error(
      "Request resolution did not retain historical contribution selections.",
    );
  }
}

async function assertIdentifierOnlyEvents(requestIds) {
  const [summary] = await sql`
    select
      count(*)::integer as total_events,
      count(*) filter (
        where jsonb_object_length(event.payload) = 6
          and event.payload ?& array[
            'project_kind',
            'request_id',
            'requester_profile_id',
            'status',
            'project_id',
            'actor_profile_id'
          ]
      )::integer as identifier_only_events,
      count(*) filter (
        where event.payload ?| array[
          'skill_ids',
          'resource_need_ids',
          'request_message',
          'label',
          'title'
        ]
          or event.payload::text ilike '%integration request marker%'
          or event.payload::text ilike '%paint and brushes%'
      )::integer as text_leaks
    from private.outbox_events as event
    where event.event_type = 'project.join_requested'
      and event.payload ->> 'request_id' = any(${requestIds}::text[])
  `;
  if (
    summary.total_events !== requestIds.length ||
    summary.identifier_only_events !== summary.total_events ||
    summary.text_leaks !== 0
  ) {
    throw new Error(
      "Contribution-aware join-request events changed their identifier-only contract.",
    );
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a contribution-selection profile",
        anchorError,
      );
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
    throw safeDatabaseFailure(
      "complete a contribution-selection profile",
      updateError,
    );
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project contribution-selection verifier",
  });
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

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
