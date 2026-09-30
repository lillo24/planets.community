import { createClient } from "@supabase/supabase-js";
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

const sql = postgres(databaseUrl, { max: 6 });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false },
});
const staleSkillId = "d0000000-0000-4000-8001-000000000001";
const currentSkillId = "d0000000-0000-4000-8003-000000000002";

try {
  await verifyActualContributions();
} finally {
  await sql.end();
}

async function verifyActualContributions() {
  const [
    creator,
    participant,
    earlyParticipant,
    leaveRace,
    removeRace,
    unrelated,
  ] = await Promise.all([
    signInWithLocalOtp("actual-contribution-creator@planets.invalid"),
    signInWithLocalOtp("actual-contribution-participant@planets.invalid"),
    signInWithLocalOtp("actual-contribution-early@planets.invalid"),
    signInWithLocalOtp("actual-contribution-leave-race@planets.invalid"),
    signInWithLocalOtp("actual-contribution-remove-race@planets.invalid"),
    signInWithLocalOtp("actual-contribution-unrelated@planets.invalid"),
  ]);
  const creatorSecondSession = await signInWithLocalOtp(
    "actual-contribution-creator@planets.invalid",
  );

  await Promise.all([
    ensureCompleteProfile(creator, "Actual Contribution Creator"),
    ensureCompleteProfile(participant, "Actual Contribution Participant"),
    ensureCompleteProfile(earlyParticipant, "Actual Contribution Early"),
    ensureCompleteProfile(leaveRace, "Actual Contribution Leave Race"),
    ensureCompleteProfile(removeRace, "Actual Contribution Remove Race"),
    ensureCompleteProfile(unrelated, "Actual Contribution Unrelated"),
  ]);
  await Promise.all(
    [
      creator,
      participant,
      earlyParticipant,
      leaveRace,
      removeRace,
      unrelated,
    ].map((user) => ensureLocalProfilePhoto(user)),
  );

  const fixture = await createEndedFixture(
    creator,
    participant,
    earlyParticipant,
    leaveRace,
    removeRace,
  );
  await verifyAutomaticAndCorrectedTruth(
    creator,
    creatorSecondSession,
    participant,
    earlyParticipant,
    unrelated,
    fixture,
  );
  await verifyPostEndLifecycleSerialization(
    creator,
    leaveRace,
    removeRace,
    fixture,
  );
  await verifyTavoloRejection(creator, participant);
  await verifyAnonymousBoundary(fixture.activeMembershipId);

  console.log(
    "Confirmed real-OTP one-time actual attribution: mixed acceptance/later commitments, membership-at-end baseline, coverage independence, sparse creator corrections, closed same-Project additions, effort isolation, participant visibility, creator CAS conflicts across sessions, post-end leave/removal lock serialization, ended-before-end manual credit, Tavolo rejection, identifier-only events, and no public table/RPC leakage.",
  );
}

async function createEndedFixture(
  creator,
  participant,
  earlyParticipant,
  leaveRace,
  removeRace,
) {
  const proposalId = await createProposalDraft(creator);
  await publishProposal(creator, proposalId);
  const baselineNeedId = await createNeed(
    creator,
    proposalId,
    "Actual baseline material",
  );
  const extraNeedId = await createNeed(
    creator,
    proposalId,
    "Actual extra material",
  );
  const laterNeedId = await createNeed(
    creator,
    proposalId,
    "Actual later commitment",
  );
  const offAppNeedId = await createNeed(
    creator,
    proposalId,
    "Actual off-app material",
  );

  const activeRequestId = await requestToJoin(
    participant,
    proposalId,
    [staleSkillId],
    [baselineNeedId, extraNeedId],
  );
  const activeMembershipId = await acceptRequest(
    creator,
    activeRequestId,
    [staleSkillId],
    [],
    [baselineNeedId],
    [extraNeedId],
  );
  await replaceCommitments(
    participant,
    activeMembershipId,
    [staleSkillId],
    [baselineNeedId, extraNeedId],
    [staleSkillId],
    [baselineNeedId, extraNeedId, laterNeedId],
  );
  await claimRequirement(participant, proposalId, "resource", extraNeedId);

  const earlyMembershipId = await createMembership(
    creator,
    earlyParticipant,
    proposalId,
    [staleSkillId],
    [],
  );
  const leaveRaceMembershipId = await createMembership(
    creator,
    leaveRace,
    proposalId,
    [staleSkillId],
    [baselineNeedId],
  );
  const removeRaceMembershipId = await createMembership(
    creator,
    removeRace,
    proposalId,
    [staleSkillId],
    [baselineNeedId],
  );

  await leaveMembership(earlyParticipant, earlyMembershipId);
  await closeNeed(creator, extraNeedId);
  await closeNeed(creator, offAppNeedId);
  await updateProposalSkills(creator, proposalId, [currentSkillId], ["useful"]);

  await sql`
    update public.proposals
    set
      starts_at = statement_timestamp() - interval '2 hours',
      ends_at = statement_timestamp() + interval '750 milliseconds'
    where id = ${proposalId}::uuid
  `;
  await delay(1000);

  return {
    proposalId,
    activeMembershipId,
    earlyMembershipId,
    leaveRaceMembershipId,
    removeRaceMembershipId,
    baselineNeedId,
    extraNeedId,
    laterNeedId,
    offAppNeedId,
  };
}

async function verifyAutomaticAndCorrectedTruth(
  creator,
  creatorSecondSession,
  participant,
  earlyParticipant,
  unrelated,
  fixture,
) {
  const baselineSkills = [staleSkillId];
  const baselineResources = [
    fixture.baselineNeedId,
    fixture.extraNeedId,
    fixture.laterNeedId,
  ];

  await assertActualIds(participant, fixture.activeMembershipId, {
    skills: baselineSkills,
    resources: baselineResources,
    effort: false,
  });
  await assertActualIds(creator, fixture.activeMembershipId, {
    skills: baselineSkills,
    resources: baselineResources,
    effort: false,
  });
  await assertActualIds(earlyParticipant, fixture.earlyMembershipId, {
    skills: [],
    resources: [],
    effort: false,
  });
  await assertRpcCode(
    unrelated.client.rpc("list_project_membership_actual_contributions", {
      p_expected_profile_id: unrelated.id,
      p_membership_id: fixture.activeMembershipId,
    }),
    "42501",
    "deny an unrelated actual-contribution read",
  );
  await assertRpcCode(
    participant.client.rpc(
      "list_project_membership_actual_contribution_options",
      {
        p_expected_creator_profile_id: participant.id,
        p_membership_id: fixture.activeMembershipId,
      },
    ),
    "42501",
    "deny participant access to creator correction options",
  );
  await assertRpcCode(
    participant.client.rpc("replace_project_membership_actual_contributions", {
      p_expected_creator_profile_id: participant.id,
      p_membership_id: fixture.activeMembershipId,
      p_expected_skill_ids: baselineSkills,
      p_expected_resource_need_ids: baselineResources,
      p_expected_substantial_effort: false,
      p_skill_ids: baselineSkills,
      p_resource_need_ids: baselineResources,
      p_substantial_effort: true,
    }),
    "42501",
    "deny participant actual-contribution mutation",
  );

  const options = await readOptions(creator, fixture.activeMembershipId);
  assertSetEqual(
    options
      .filter((row) => row.option_kind === "skill")
      .map((row) => row.option_id),
    [staleSkillId, currentSkillId],
    "actual-contribution skill options",
  );
  assertSetEqual(
    options
      .filter((row) => row.option_kind === "resource")
      .map((row) => row.option_id),
    [
      fixture.baselineNeedId,
      fixture.extraNeedId,
      fixture.laterNeedId,
      fixture.offAppNeedId,
    ],
    "actual-contribution resource options",
  );

  const desiredSkills = [currentSkillId];
  const desiredResources = [
    fixture.extraNeedId,
    fixture.laterNeedId,
    fixture.offAppNeedId,
  ];
  await replaceActual(
    creator,
    fixture.activeMembershipId,
    baselineSkills,
    baselineResources,
    false,
    desiredSkills,
    desiredResources,
    true,
  );
  await assertActualIds(participant, fixture.activeMembershipId, {
    skills: desiredSkills,
    resources: desiredResources,
    effort: true,
  });
  await assertSparseState(fixture.activeMembershipId, {
    skillOverrides: 2,
    resourceOverrides: 2,
    effortMarkers: 1,
  });

  const beforeNoop = await readActualState(fixture.activeMembershipId);
  await replaceActual(
    creator,
    fixture.activeMembershipId,
    desiredSkills,
    desiredResources,
    true,
    desiredSkills,
    desiredResources,
    true,
  );
  const afterNoop = await readActualState(fixture.activeMembershipId);
  if (JSON.stringify(beforeNoop) !== JSON.stringify(afterNoop)) {
    throw new Error(
      "An exact actual-contribution no-op rewrote state or events.",
    );
  }

  await assertRpcCode(
    creatorSecondSession.client.rpc(
      "replace_project_membership_actual_contributions",
      {
        p_expected_creator_profile_id: creatorSecondSession.id,
        p_membership_id: fixture.activeMembershipId,
        p_expected_skill_ids: baselineSkills,
        p_expected_resource_need_ids: baselineResources,
        p_expected_substantial_effort: false,
        p_skill_ids: desiredSkills,
        p_resource_need_ids: desiredResources,
        p_substantial_effort: true,
      },
    ),
    "PT409",
    "reject a stale creator session even when desired equals current truth",
  );
  const afterConflict = await readActualState(fixture.activeMembershipId);
  if (JSON.stringify(afterNoop) !== JSON.stringify(afterConflict)) {
    throw new Error("A stale creator CAS attempt changed canonical state.");
  }

  await replaceActual(
    creator,
    fixture.earlyMembershipId,
    [],
    [],
    false,
    [currentSkillId],
    [fixture.offAppNeedId],
    true,
  );
  await assertActualIds(earlyParticipant, fixture.earlyMembershipId, {
    skills: [currentSkillId],
    resources: [fixture.offAppNeedId],
    effort: true,
  });
  await assertIdentifierOnlyEvents(fixture.activeMembershipId);
  await assertNoCoverageSideEffects(
    fixture.activeMembershipId,
    fixture.offAppNeedId,
  );
}

async function verifyPostEndLifecycleSerialization(
  creator,
  leaveRace,
  removeRace,
  fixture,
) {
  let blockedLeave;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await replaceActualInTransaction(
      transaction,
      creator.id,
      fixture.leaveRaceMembershipId,
      [staleSkillId],
      [fixture.baselineNeedId],
      false,
      [staleSkillId, currentSkillId],
      [fixture.baselineNeedId],
      false,
    );
    blockedLeave = track(
      leaveRace.client.rpc("leave_project", {
        p_expected_participant_profile_id: leaveRace.id,
        p_membership_id: fixture.leaveRaceMembershipId,
      }),
    );
    await assertBlocked(blockedLeave, "post-end leave behind attribution");
  });
  await assertTrackedValue(
    blockedLeave,
    fixture.leaveRaceMembershipId,
    "complete post-end leave after attribution",
  );
  await assertActualIds(creator, fixture.leaveRaceMembershipId, {
    skills: [staleSkillId, currentSkillId],
    resources: [fixture.baselineNeedId],
    effort: false,
  });

  let blockedCorrection;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.remove_project_member(
        ${creator.id}::uuid,
        ${fixture.removeRaceMembershipId}::uuid
      )
    `;
    blockedCorrection = track(
      creator.client.rpc("replace_project_membership_actual_contributions", {
        p_expected_creator_profile_id: creator.id,
        p_membership_id: fixture.removeRaceMembershipId,
        p_expected_skill_ids: [staleSkillId],
        p_expected_resource_need_ids: [fixture.baselineNeedId],
        p_expected_substantial_effort: false,
        p_skill_ids: [staleSkillId, currentSkillId],
        p_resource_need_ids: [fixture.baselineNeedId],
        p_substantial_effort: true,
      }),
    );
    await assertBlocked(
      blockedCorrection,
      "actual attribution behind post-end removal",
    );
  });
  await assertTrackedValue(
    blockedCorrection,
    fixture.removeRaceMembershipId,
    "complete attribution after post-end removal",
  );
  await assertActualIds(creator, fixture.removeRaceMembershipId, {
    skills: [staleSkillId, currentSkillId],
    resources: [fixture.baselineNeedId],
    effort: true,
  });
}

async function verifyTavoloRejection(creator, participant) {
  const { data: tavoloId, error: createError } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Actual contribution Tavolo",
      p_summary: "Tavolo attribution remains intentionally unsupported.",
      p_description:
        "This fixture confirms that recurring participation does not imply final contribution attribution.",
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
  if (createError || typeof tavoloId !== "string") {
    throw safeDatabaseFailure(
      "create an actual-attribution Tavolo",
      createError,
    );
  }
  const { error: publishError } = await creator.client.rpc(
    "publish_recurring_activity",
    {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: tavoloId,
    },
  );
  if (publishError) {
    throw safeDatabaseFailure(
      "publish an actual-attribution Tavolo",
      publishError,
    );
  }
  const requestId = await requestToJoin(participant, tavoloId, [], []);
  const membershipId = await acceptRequest(creator, requestId, [], [], [], []);
  await assertRpcCode(
    participant.client.rpc("list_project_membership_actual_contributions", {
      p_expected_profile_id: participant.id,
      p_membership_id: membershipId,
    }),
    "55000",
    "reject Tavolo actual-contribution finalization",
  );
}

async function verifyAnonymousBoundary(membershipId) {
  const { data: directRows, error: directError } = await anonymous
    .from("project_membership_actual_skill_overrides")
    .select("membership_id");
  if (!directError || directRows !== null) {
    throw new Error(
      "Anonymous direct actual-contribution storage access leaked.",
    );
  }
  await assertRpcCode(
    anonymous.rpc("list_project_membership_actual_contributions", {
      p_expected_profile_id: null,
      p_membership_id: membershipId,
    }),
    "42501",
    "deny anonymous actual-contribution RPC access",
  );
}

async function createProposalDraft(creator) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    ...proposalContent([staleSkillId, currentSkillId], ["required", "useful"]),
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create an actual-contribution Proposal", error);
  }
  return data;
}

function proposalContent(skillIds, importances) {
  return {
    p_title: "Integration actual contribution",
    p_summary: "Deterministic actual-contribution integration coverage.",
    p_description:
      "This Project verifies post-end automatic attribution and sparse creator corrections.",
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
    throw safeDatabaseFailure("publish an actual-contribution Proposal", error);
  }
}

async function updateProposalSkills(
  creator,
  proposalId,
  skillIds,
  importances,
) {
  const { data, error } = await creator.client.rpc("update_own_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
    ...proposalContent(skillIds, importances),
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("remove a pre-start Proposal skill", error);
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
    throw safeDatabaseFailure("create an actual-contribution resource", error);
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
    throw safeDatabaseFailure("close an actual-contribution resource", error);
  }
}

async function requestToJoin(user, projectId, skillIds, resourceNeedIds) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: null,
    p_skill_ids: skillIds,
    p_resource_need_ids: resourceNeedIds,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "create an actual-contribution join request",
      error,
    );
  }
  return data;
}

async function acceptRequest(
  creator,
  requestId,
  neededSkillIds,
  extraSkillIds,
  neededResourceIds,
  extraResourceIds,
) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
      p_needed_skill_ids: neededSkillIds,
      p_already_found_skill_ids: [],
      p_extra_skill_ids: extraSkillIds,
      p_needed_resource_need_ids: neededResourceIds,
      p_already_found_resource_need_ids: [],
      p_extra_resource_need_ids: extraResourceIds,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept an actual-contribution join request",
      error,
    );
  }
  return data;
}

async function createMembership(
  creator,
  participant,
  projectId,
  skillIds,
  resourceIds,
) {
  const requestId = await requestToJoin(
    participant,
    projectId,
    skillIds,
    resourceIds,
  );
  return acceptRequest(creator, requestId, skillIds, [], resourceIds, []);
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
    throw safeDatabaseFailure("add a later membership commitment", error);
  }
}

async function claimRequirement(user, projectId, kind, requirementId) {
  const { error } = await user.client.rpc("claim_project_requirement", {
    p_expected_participant_profile_id: user.id,
    p_project_id: projectId,
    p_requirement_kind: kind,
    p_requirement_id: requirementId,
  });
  if (error) {
    throw safeDatabaseFailure("change live coverage independently", error);
  }
}

async function leaveMembership(user, membershipId) {
  const { data, error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error || data !== membershipId) {
    throw safeDatabaseFailure("leave a Project before its end", error);
  }
}

async function replaceActual(
  creator,
  membershipId,
  expectedSkillIds,
  expectedResourceIds,
  expectedEffort,
  skillIds,
  resourceIds,
  effort,
) {
  const { data, error } = await creator.client.rpc(
    "replace_project_membership_actual_contributions",
    {
      p_expected_creator_profile_id: creator.id,
      p_membership_id: membershipId,
      p_expected_skill_ids: expectedSkillIds,
      p_expected_resource_need_ids: expectedResourceIds,
      p_expected_substantial_effort: expectedEffort,
      p_skill_ids: skillIds,
      p_resource_need_ids: resourceIds,
      p_substantial_effort: effort,
    },
  );
  if (error || data !== membershipId) {
    throw safeDatabaseFailure("replace actual contributions", error);
  }
}

async function readOptions(creator, membershipId) {
  const { data, error } = await creator.client.rpc(
    "list_project_membership_actual_contribution_options",
    {
      p_expected_creator_profile_id: creator.id,
      p_membership_id: membershipId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("read actual-contribution options", error);
  }
  return data;
}

async function assertActualIds(user, membershipId, expected) {
  const { data, error } = await user.client.rpc(
    "list_project_membership_actual_contributions",
    {
      p_expected_profile_id: user.id,
      p_membership_id: membershipId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("read actual contributions", error);
  }
  assertSetEqual(
    data
      .filter((row) => row.contribution_kind === "skill")
      .map((row) => row.contribution_id),
    expected.skills,
    "actual skill IDs",
  );
  assertSetEqual(
    data
      .filter((row) => row.contribution_kind === "resource")
      .map((row) => row.contribution_id),
    expected.resources,
    "actual resource IDs",
  );
  const effortRows = data.filter(
    (row) => row.contribution_kind === "substantial_effort",
  );
  if (
    effortRows.length !== (expected.effort ? 1 : 0) ||
    effortRows.some((row) => row.contribution_id !== null || row.label !== null)
  ) {
    throw new Error("Substantial Effort / Energy had an invalid row shape.");
  }
}

async function assertSparseState(membershipId, expected) {
  const [state] = await sql`
    select
      (select count(*)::integer
       from public.project_membership_actual_skill_overrides
       where membership_id = ${membershipId}::uuid) as skill_overrides,
      (select count(*)::integer
       from public.project_membership_actual_resource_overrides
       where membership_id = ${membershipId}::uuid) as resource_overrides,
      (select count(*)::integer
       from public.project_membership_actual_effort_markers
       where membership_id = ${membershipId}::uuid) as effort_markers
  `;
  if (
    state.skill_overrides !== expected.skillOverrides ||
    state.resource_overrides !== expected.resourceOverrides ||
    state.effort_markers !== expected.effortMarkers
  ) {
    throw new Error("Actual-contribution state was not normalized sparsely.");
  }
}

async function readActualState(membershipId) {
  const [row] = await sql`
    select jsonb_build_object(
      'skill_overrides', coalesce((
        select jsonb_agg(
          jsonb_build_array(skill_id, is_included, updated_at)
          order by skill_id
        )
        from public.project_membership_actual_skill_overrides
        where membership_id = ${membershipId}::uuid
      ), '[]'::jsonb),
      'resource_overrides', coalesce((
        select jsonb_agg(
          jsonb_build_array(resource_need_id, is_included, updated_at)
          order by resource_need_id
        )
        from public.project_membership_actual_resource_overrides
        where membership_id = ${membershipId}::uuid
      ), '[]'::jsonb),
      'effort', coalesce((
        select jsonb_agg(jsonb_build_array(marked_at, marked_by_profile_id))
        from public.project_membership_actual_effort_markers
        where membership_id = ${membershipId}::uuid
      ), '[]'::jsonb),
      'events', (
        select count(*)
        from private.outbox_events
        where event_type = 'project.actual_contributions_updated'
          and payload ->> 'membership_id' = ${membershipId}
      )
    ) as state
  `;
  return row.state;
}

async function assertIdentifierOnlyEvents(membershipId) {
  const [summary] = await sql`
    select
      count(*)::integer as total,
      count(*) filter (
        where jsonb_object_length(payload) = 5
          and payload ?& array[
            'project_id',
            'project_kind',
            'membership_id',
            'participant_profile_id',
            'actor_profile_id'
          ]
      )::integer as identifier_only,
      count(*) filter (
        where payload ?| array[
          'skill_ids',
          'resource_need_ids',
          'label',
          'title',
          'message',
          'effort'
        ]
      )::integer as leaking
    from private.outbox_events
    where event_type = 'project.actual_contributions_updated'
      and payload ->> 'membership_id' = ${membershipId}
  `;
  if (
    summary.total !== 1 ||
    summary.identifier_only !== summary.total ||
    summary.leaking !== 0
  ) {
    throw new Error(
      "Actual-contribution events were not exactly identifier-only.",
    );
  }
}

async function assertNoCoverageSideEffects(membershipId, offAppNeedId) {
  const [summary] = await sql`
    select
      (select count(*)::integer
       from public.project_membership_skill_coverages
       where membership_id = ${membershipId}::uuid
         and skill_id = ${currentSkillId}::uuid) as attributed_skill_coverage,
      (select count(*)::integer
       from public.project_membership_resource_coverages
       where membership_id = ${membershipId}::uuid
         and resource_need_id = ${offAppNeedId}::uuid) as attributed_resource_coverage,
      (select count(*)::integer
       from public.project_membership_actual_effort_markers
       where membership_id = ${membershipId}::uuid) as effort
  `;
  if (summary.effort !== 1) {
    throw new Error("The independent effort marker was not retained.");
  }
  if (
    summary.attributed_skill_coverage !== 0 ||
    summary.attributed_resource_coverage !== 0
  ) {
    throw new Error("Actual attribution created a live-coverage source.");
  }
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function replaceActualInTransaction(
  transaction,
  creatorId,
  membershipId,
  expectedSkillIds,
  expectedResourceIds,
  expectedEffort,
  skillIds,
  resourceIds,
  effort,
) {
  await transaction`
    select public.replace_project_membership_actual_contributions(
      ${creatorId}::uuid,
      ${membershipId}::uuid,
      ${expectedSkillIds}::uuid[],
      ${expectedResourceIds}::uuid[],
      ${expectedEffort}::boolean,
      ${skillIds}::uuid[],
      ${resourceIds}::uuid[],
      ${effort}::boolean
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
      throw safeDatabaseFailure(
        "create an actual-contribution profile",
        anchorError,
      );
    }
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error) {
    throw safeDatabaseFailure("complete an actual-contribution profile", error);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project actual-contribution verifier",
  });
}

function assertSetEqual(actual, expected, description) {
  const normalizedActual = [...actual].sort();
  const normalizedExpected = [...expected].sort();
  if (JSON.stringify(normalizedActual) !== JSON.stringify(normalizedExpected)) {
    throw new Error(`${description} did not match canonical expected IDs.`);
  }
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

async function assertTrackedValue(tracked, expectedValue, action) {
  const result = await tracked.promise;
  if (result.error || result.data !== expectedValue) {
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
