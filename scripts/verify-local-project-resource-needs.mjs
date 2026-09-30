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

const sql = postgres(databaseUrl, { max: 4 });

try {
  await verifyProjectResourceNeeds();
} finally {
  await sql.end();
}

async function verifyProjectResourceNeeds() {
  const [creator, unrelated] = await Promise.all([
    signInWithLocalOtp("project-needs-creator@planets.invalid"),
    signInWithLocalOtp("project-needs-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Project Needs Creator"),
    ensureCompleteProfile(unrelated, "Project Needs Unrelated"),
  ]);
  await Promise.all(
    [creator, unrelated].map((user) => ensureLocalProfilePhoto(user)),
  );

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });

  const proposalId = await createProposalDraft(
    creator,
    "Integration Project resource needs",
  );
  const proposalNeedOne = await createNeed(
    creator,
    proposalId,
    "  Paint  ",
    "  Private integration marker alpha  ",
  );
  const proposalNeedTwo = await createNeed(
    creator,
    proposalId,
    "Wooden boards",
    null,
  );

  await assertRpcCode(
    unrelated.client.rpc("create_project_resource_need", {
      p_expected_creator_profile_id: unrelated.id,
      p_project_id: proposalId,
      p_title: "Unauthorized need",
      p_details: null,
    }),
    "42501",
    "reject unrelated Project-need creation",
  );
  await assertRpcCode(
    unrelated.client.rpc("list_own_project_resource_needs", {
      p_expected_creator_profile_id: unrelated.id,
      p_project_id: proposalId,
    }),
    "42501",
    "reject unrelated Project-need history access",
  );
  await assertRpcCode(
    creator.client.rpc("update_project_resource_need", {
      p_expected_creator_profile_id: unrelated.id,
      p_resource_need_id: proposalNeedOne,
      p_title: "Stale identity update",
      p_details: null,
    }),
    "42501",
    "reject a stale creator identity",
  );
  await assertPublicNeeds(anonymous, proposalId, []);

  await publishProposal(creator, proposalId);
  await assertPublicNeeds(anonymous, proposalId, [
    proposalNeedOne,
    proposalNeedTwo,
  ]);

  await updateNeed(
    creator,
    proposalNeedOne,
    "Paint and brushes",
    "Private integration marker beta",
  );
  const updatedPublicNeeds = await listPublicNeeds(anonymous, proposalId);
  const updatedNeed = updatedPublicNeeds.find(
    (need) => need.resource_need_id === proposalNeedOne,
  );
  if (
    updatedNeed?.title !== "Paint and brushes" ||
    updatedNeed.details !== "Private integration marker beta"
  ) {
    throw new Error(
      "A public Project need did not reflect its canonical update.",
    );
  }

  await closeNeed(creator, proposalNeedTwo);
  await assertPublicNeeds(anonymous, proposalId, [proposalNeedOne]);
  const proposalHistory = await listOwnNeeds(creator, proposalId);
  const closedNeed = proposalHistory.find(
    (need) => need.resource_need_id === proposalNeedTwo,
  );
  if (
    proposalHistory.length !== 2 ||
    closedNeed?.state !== "closed" ||
    typeof closedNeed.closed_at !== "string"
  ) {
    throw new Error("Proposal need closure did not preserve owner history.");
  }
  await assertRpcCode(
    creator.client.rpc("update_project_resource_need", {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: proposalNeedTwo,
      p_title: "Closed need rewrite",
      p_details: null,
    }),
    "55000",
    "keep a closed need terminal",
  );

  await cancelProposal(creator, proposalId);
  await assertPublicNeeds(anonymous, proposalId, []);
  await assertRpcCode(
    creator.client.rpc("create_project_resource_need", {
      p_expected_creator_profile_id: creator.id,
      p_project_id: proposalId,
      p_title: "Post-cancel need",
      p_details: null,
    }),
    "55000",
    "reject need creation for a cancelled Proposal",
  );
  if ((await listOwnNeeds(creator, proposalId)).length !== 2) {
    throw new Error("Proposal cancellation hid creator need history.");
  }

  const tavoloId = await createTavoloDraft(creator);
  const tavoloNeedOne = await createNeed(
    creator,
    tavoloId,
    "Ladder",
    "Private integration marker gamma",
  );
  await assertPublicNeeds(anonymous, tavoloId, []);
  await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
  await assertPublicNeeds(anonymous, tavoloId, [tavoloNeedOne]);

  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  await assertPublicNeeds(anonymous, tavoloId, []);
  await updateNeed(creator, tavoloNeedOne, "Extension ladder", null);
  const tavoloNeedTwo = await createNeed(
    creator,
    tavoloId,
    "Van for transport",
    null,
  );
  await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  await assertPublicNeeds(anonymous, tavoloId, [tavoloNeedOne, tavoloNeedTwo]);
  await closeNeed(creator, tavoloNeedTwo);
  await assertPublicNeeds(anonymous, tavoloId, [tavoloNeedOne]);
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  await assertPublicNeeds(anonymous, tavoloId, []);
  await assertRpcCode(
    creator.client.rpc("update_project_resource_need", {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: tavoloNeedOne,
      p_title: "Post-end rewrite",
      p_details: null,
    }),
    "55000",
    "reject need updates for an ended Tavolo",
  );
  if ((await listOwnNeeds(creator, tavoloId)).length !== 2) {
    throw new Error("Ending a Tavolo hid creator need history.");
  }

  await verifyLifecycleNeedSerialization(creator);
  await assertIdentifierOnlyEvents();

  console.log(
    "Confirmed Project resource-need ownership, Proposal/Tavolo lifecycle visibility, terminal closure with stable history, identifier-only events, and lifecycle/mutation serialization.",
  );
}

async function verifyLifecycleNeedSerialization(creator) {
  const terminalFirstProject = await createProposalDraft(
    creator,
    "Integration Project need terminal-first race",
  );
  await publishProposal(creator, terminalFirstProject);

  let blockedCreate;
  let blockedCreateSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.cancel_proposal(
        ${creator.id}::uuid,
        ${terminalFirstProject}::uuid
      )
    `;
    blockedCreate = creator.client.rpc("create_project_resource_need", {
      p_expected_creator_profile_id: creator.id,
      p_project_id: terminalFirstProject,
      p_title: "Blocked lifecycle-race need",
      p_details: null,
    });
    blockedCreate.then(
      () => {
        blockedCreateSettled = true;
      },
      () => {
        blockedCreateSettled = true;
      },
    );
    await delay(250);
    if (blockedCreateSettled) {
      throw new Error(
        "Need creation did not wait behind the terminal Proposal transition.",
      );
    }
  });
  await assertRpcCode(
    blockedCreate,
    "55000",
    "reject a need mutation after the terminal transition wins",
  );

  const mutationFirstProject = await createProposalDraft(
    creator,
    "Integration Project need mutation-first race",
  );
  const mutationFirstNeed = await createNeed(
    creator,
    mutationFirstProject,
    "Mutation-first need",
    null,
  );
  await publishProposal(creator, mutationFirstProject);

  let blockedCancellation;
  let blockedCancellationSettled = false;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.update_project_resource_need(
        ${creator.id}::uuid,
        ${mutationFirstNeed}::uuid,
        'Serialized need update',
        null
      )
    `;
    blockedCancellation = creator.client.rpc("cancel_proposal", {
      p_expected_creator_profile_id: creator.id,
      p_proposal_id: mutationFirstProject,
    });
    blockedCancellation.then(
      () => {
        blockedCancellationSettled = true;
      },
      () => {
        blockedCancellationSettled = true;
      },
    );
    await delay(250);
    if (blockedCancellationSettled) {
      throw new Error(
        "Proposal cancellation did not wait behind the need mutation.",
      );
    }
  });
  const cancellationResult = await blockedCancellation;
  if (
    cancellationResult.error ||
    cancellationResult.data !== mutationFirstProject
  ) {
    throw safeDatabaseFailure(
      "complete a cancellation waiting behind a need update",
      cancellationResult.error ?? {},
    );
  }

  const history = await listOwnNeeds(creator, mutationFirstProject);
  if (
    history.length !== 1 ||
    history[0]?.resource_need_id !== mutationFirstNeed ||
    history[0]?.title !== "Serialized need update"
  ) {
    throw new Error(
      "The mutation-first serialization did not retain the committed need update.",
    );
  }
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function assertIdentifierOnlyEvents() {
  const [summary] = await sql`
    select
      count(*)::integer as total_events,
      count(*) filter (
        where jsonb_object_length(event.payload) = 4
          and event.payload ?& array[
            'project_id',
            'project_kind',
            'resource_need_id',
            'creator_profile_id'
          ]
      )::integer as identifier_only_events,
      count(*) filter (
        where event.payload::text ilike '%private integration marker%'
          or event.payload::text ilike '%paint and brushes%'
          or event.payload::text ilike '%extension ladder%'
      )::integer as text_leaks
    from private.outbox_events as event
    where event.event_type in (
      'project.resource_need_created',
      'project.resource_need_updated',
      'project.resource_need_closed'
    )
  `;
  if (
    summary.total_events < 1 ||
    summary.identifier_only_events !== summary.total_events ||
    summary.text_leaks !== 0
  ) {
    throw new Error(
      "Project resource-need outbox events were not identifier-only.",
    );
  }
}

async function createProposalDraft(creator, title) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: title,
    p_summary:
      "A deterministic Proposal for Project resource-need verification.",
    p_description:
      "This Project verifies stable resource needs and lifecycle authorization.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a Project-needs Proposal", error ?? {});
  }
  return data;
}

async function publishProposal(creator, proposalId) {
  const { data, error } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("publish a Project-needs Proposal", error ?? {});
  }
}

async function cancelProposal(creator, proposalId) {
  const { data, error } = await creator.client.rpc("cancel_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: proposalId,
  });
  if (error || data !== proposalId) {
    throw safeDatabaseFailure("cancel a Project-needs Proposal", error ?? {});
  }
}

async function createTavoloDraft(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration Project resource-needs Tavolo",
      p_summary:
        "A deterministic Tavolo for Project resource-need verification.",
      p_description:
        "This recurring Project verifies resource-need lifecycle authorization.",
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
      p_people_capacity: 20,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a Project-needs Tavolo", error ?? {});
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

async function createNeed(creator, projectId, title, details) {
  const { data, error } = await creator.client.rpc(
    "create_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
      p_title: title,
      p_details: details,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a Project resource need", error ?? {});
  }
  return data;
}

async function updateNeed(creator, resourceNeedId, title, details) {
  const { data, error } = await creator.client.rpc(
    "update_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_resource_need_id: resourceNeedId,
      p_title: title,
      p_details: details,
    },
  );
  if (error || data !== resourceNeedId) {
    throw safeDatabaseFailure("update a Project resource need", error ?? {});
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
    throw safeDatabaseFailure("close a Project resource need", error ?? {});
  }
}

async function listOwnNeeds(creator, projectId) {
  const { data, error } = await creator.client.rpc(
    "list_own_project_resource_needs",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list own Project resource needs", error ?? {});
  }
  return data;
}

async function listPublicNeeds(client, projectId) {
  const { data, error } = await client.rpc(
    "list_public_project_resource_needs",
    { p_project_id: projectId },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure(
      "list public Project resource needs",
      error ?? {},
    );
  }
  return data;
}

async function assertPublicNeeds(client, projectId, expectedIds) {
  const needs = await listPublicNeeds(client, projectId);
  const actualIds = needs.map((need) => need.resource_need_id);
  if (JSON.stringify(actualIds) !== JSON.stringify(expectedIds)) {
    throw new Error(
      "Public Project resource needs had unexpected visibility or order.",
    );
  }
}

async function assertRpcCode(pendingResult, expectedCode, action) {
  const result = await pendingResult;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a Project-needs profile", anchorError);
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
    throw safeDatabaseFailure("complete a Project-needs profile", updateError);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project resource-needs verifier",
  });
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
