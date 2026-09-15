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
  await acceptRequest(creator, acceptedRequestId);
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
    "Confirmed real-OTP Proposal and Tavolo contribution selections, private requester/creator reads, lifecycle-retained history, identifier-only events, and Project/need/skill lock serialization.",
  );
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
    blockedRequest = requester.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: requester.id,
      p_project_id: closeFirstProposal,
      p_request_message: null,
      p_skill_ids: [requiredSkillId],
      p_resource_need_ids: [closeFirstNeed],
    });
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
    blockedClose = creator.client.rpc("close_project_resource_need", {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: requestFirstNeed,
    });
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
    blockedRequest = requester.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: requester.id,
      p_project_id: updateFirstProposal,
      p_request_message: null,
      p_skill_ids: [requiredSkillId],
      p_resource_need_ids: [],
    });
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

async function acceptRequest(creator, requestId) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept a contribution-aware join request",
      error ?? {},
    );
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
