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

  await verifyPrimaryFlows(creator, participant, unrelated);
  await verifyTavoloFlow(creator, unrelated);
  await verifyLeaveSerialization(creator, participant);
  await verifyRemovalSerialization(creator, participant);
  await verifyResourceClosureSerialization(creator, participant);
  await verifySkillRemovalSerialization(creator, participant);

  console.log(
    "Confirmed real-OTP acceptance seeding, authorized current/ended commitment reads, full-set replacement and no-ops, lifecycle/stale-option rules, identifier-only events without notifications, rejoin isolation, and membership/resource/skill lock serialization.",
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
  await assertRpcCode(
    unrelated.client.rpc("list_own_project_membership_commitments", {
      p_expected_profile_id: unrelated.id,
      p_membership_id: fixture.membershipId,
    }),
    "42501",
    "deny an unrelated membership commitment read",
  );
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
    [usefulSkillId, requiredSkillId],
    [secondNeedId],
  );
  const beforeNoop = await readCommitmentState(fixture.membershipId);
  await replaceCommitments(
    participant,
    fixture.membershipId,
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
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [requiredSkillId, usefulSkillId],
    [secondNeedId],
  );
  await replaceCommitments(
    participant,
    fixture.membershipId,
    [usefulSkillId],
    [],
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
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
      p_membership_id: fixture.membershipId,
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [secondNeedId],
    }),
    "22023",
    "reject re-adding a closed resource need",
  );

  await replaceCommitments(creator, fixture.membershipId, null, null);
  await replaceCommitments(
    participant,
    fixture.membershipId,
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
  await replaceCommitments(
    participant,
    fixture.membershipId,
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
      p_membership_id: fixture.membershipId,
      p_skill_ids: [],
      p_resource_need_ids: [],
    }),
    "55000",
    "reject mutation of an ended membership",
  );

  const rejoinRequestId = await requestToJoin(
    participant,
    fixture.proposalId,
    [usefulSkillId],
    [],
  );
  const rejoinMembershipId = await acceptRequest(creator, rejoinRequestId);
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
      p_membership_id: rejoinMembershipId,
      p_skill_ids: [usefulSkillId],
      p_resource_need_ids: [],
    }),
    "55000",
    "reject a no-op after the Proposal has ended",
  );
  await assertCommitments(creator, fixture.membershipId, [
    ["skill", usefulSkillId, "Woodworking"],
  ]);
  await assertIdentifierOnlyEventsWithoutNotifications(fixture.membershipId);
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
  const membershipId = await acceptRequest(creator, requestId);
  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  await replaceCommitments(
    participant,
    membershipId,
    [],
    [firstNeedId, secondNeedId],
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_commitments", {
      p_expected_actor_profile_id: participant.id,
      p_membership_id: membershipId,
      p_skill_ids: [requiredSkillId],
      p_resource_need_ids: [firstNeedId, secondNeedId],
    }),
    "22023",
    "reject a new Tavolo skill commitment",
  );
}

async function verifyLeaveSerialization(creator, participant) {
  const leaveFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration leave-first commitment race",
  );
  let blockedReplace;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await transaction`
      select public.leave_project(
        ${participant.id}::uuid,
        ${leaveFirst.membershipId}::uuid
      )
    `;
    blockedReplace = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_membership_id: leaveFirst.membershipId,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedReplace, "replacement behind leave");
  });
  await assertTrackedRpcCode(
    blockedReplace,
    "55000",
    "reject replacement after leave wins",
  );

  const replaceFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration replace-first leave race",
  );
  let blockedLeave;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      replaceFirst.membershipId,
      [requiredSkillId],
      [],
    );
    blockedLeave = track(
      participant.client.rpc("leave_project", {
        p_expected_participant_profile_id: participant.id,
        p_membership_id: replaceFirst.membershipId,
      }),
    );
    await assertBlocked(blockedLeave, "leave behind replacement");
  });
  await assertTrackedRpcValue(
    blockedLeave,
    replaceFirst.membershipId,
    "complete leave after replacement wins",
  );
  await assertCommitments(participant, replaceFirst.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
}

async function verifyRemovalSerialization(creator, participant) {
  const removeFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration remove-first commitment race",
  );
  let blockedReplace;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.remove_project_member(
        ${creator.id}::uuid,
        ${removeFirst.membershipId}::uuid
      )
    `;
    blockedReplace = track(
      participant.client.rpc("replace_project_membership_commitments", {
        p_expected_actor_profile_id: participant.id,
        p_membership_id: removeFirst.membershipId,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedReplace, "replacement behind removal");
  });
  await assertTrackedRpcCode(
    blockedReplace,
    "55000",
    "reject replacement after removal wins",
  );

  const replaceFirst = await createMembershipFixture(
    creator,
    participant,
    "Integration replace-first removal race",
  );
  let blockedRemoval;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await replaceInTransaction(
      transaction,
      participant.id,
      replaceFirst.membershipId,
      [requiredSkillId],
      [],
    );
    blockedRemoval = track(
      creator.client.rpc("remove_project_member", {
        p_expected_creator_profile_id: creator.id,
        p_membership_id: replaceFirst.membershipId,
      }),
    );
    await assertBlocked(blockedRemoval, "removal behind replacement");
  });
  await assertTrackedRpcValue(
    blockedRemoval,
    replaceFirst.membershipId,
    "complete removal after replacement wins",
  );
  await assertCommitments(creator, replaceFirst.membershipId, [
    ["skill", requiredSkillId, "Mural painting"],
  ]);
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
        p_membership_id: closeFirst.membershipId,
        p_skill_ids: [],
        p_resource_need_ids: [closeFirstNeedId],
      }),
    );
    await assertBlocked(blockedReplace, "resource add behind closure");
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
      [replaceFirstNeedId],
    );
    blockedClose = track(
      creator.client.rpc("close_project_resource_need", {
        p_expected_creator_profile_id: creator.id,
        p_resource_need_id: replaceFirstNeedId,
      }),
    );
    await assertBlocked(blockedClose, "resource closure behind add");
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
        p_membership_id: removeFirst.membershipId,
        p_skill_ids: [requiredSkillId],
        p_resource_need_ids: [],
      }),
    );
    await assertBlocked(blockedReplace, "skill add behind requirement removal");
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
    await assertBlocked(blockedUpdate, "requirement removal behind skill add");
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
  const membershipId = await acceptRequest(creator, requestId);
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
  skillIds,
  resourceNeedIds,
) {
  await transaction`
    select public.replace_project_membership_commitments(
      ${actorId}::uuid,
      ${membershipId}::uuid,
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
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: skillIds,
    p_skill_importances: importances,
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

async function acceptRequest(creator, requestId) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("accept a commitment join request", error ?? {});
  }
  return data;
}

async function replaceCommitments(user, membershipId, skillIds, resourceIds) {
  const { data, error } = await user.client.rpc(
    "replace_project_membership_commitments",
    {
      p_expected_actor_profile_id: user.id,
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
        where jsonb_object_length(event.payload) = 5
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
  return tracked;
}

async function assertBlocked(tracked, action) {
  await delay(250);
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
  return new Error(`Failed to ${action} (code ${code}).`);
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
