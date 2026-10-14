import { randomUUID } from "node:crypto";
import {
  verifyWorkspaceCollection,
  verifyWorkspaceUpgrade,
} from "./lib/project-workspace-multi-verifier.mjs";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const { apiUrl, publishableKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error("Local Supabase status did not include a database URL.");
}

const sql = postgres(databaseUrl, { max: 6 });
const anonymousClient = createClient(apiUrl, publishableKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
});

try {
  if (process.argv.includes("--upgrade"))
    await verifyWorkspaceUpgrade({ repositoryRoot, apiUrl, databaseUrl });
  else await verifyProjectWorkspace();
} finally {
  await sql.end();
}

async function verifyProjectWorkspace() {
  // Mailpit search is intentionally serialized here: six simultaneous inbox
  // polls can race the local-only message index and make a delivered OTP look
  // absent. This adds no arbitrary wait and keeps every session real.
  const creator = await signIn("workspace-creator@planets.invalid");
  const coorganizer = await signIn("workspace-coorganizer@planets.invalid");
  const cocreator = await signIn("workspace-cocreator@planets.invalid");
  const participant = await signIn("workspace-participant@planets.invalid");
  const pending = await signIn("workspace-pending@planets.invalid");
  const unrelated = await signIn("workspace-unrelated@planets.invalid");
  const groupOnly = await signIn("workspace-group-only@planets.invalid");
  await Promise.all([
    ensureCompleteProfile(creator, "Workspace Creator"),
    ensureCompleteProfile(coorganizer, "Workspace Co-organizer"),
    ensureCompleteProfile(cocreator, "Workspace Co-creator"),
    ensureCompleteProfile(participant, "Workspace Participant"),
    ensureCompleteProfile(pending, "Workspace Pending"),
    ensureCompleteProfile(unrelated, "Workspace Unrelated"),
    ensureCompleteProfile(groupOnly, "Workspace Group Only"),
  ]);
  await Promise.all(
    [
      creator,
      coorganizer,
      cocreator,
      participant,
      pending,
      unrelated,
      groupOnly,
    ].map((user) => ensureLocalProfilePhoto(user)),
  );

  const projectId = await createPublishedProposal(creator);
  const firstUrl =
    "https://drive.google.com/drive/folders/workspace-verifier-private";
  await setWorkspace(creator, projectId, firstUrl);
  await assertWorkspace(creator, projectId, firstUrl);
  await assertProjectHasNoChat(projectId);

  const coorganizerDelegateId = await grantDelegate(
    creator,
    coorganizer,
    projectId,
    "co_organizer",
  );
  const cocreatorDelegateId = await grantDelegate(
    creator,
    cocreator,
    projectId,
    "co_creator",
  );

  const coorganizerUrl = "https://nextcloud.example.org/s/workspace-verifier";
  await setWorkspace(coorganizer, projectId, coorganizerUrl);
  await assertWorkspace(creator, projectId, coorganizerUrl);
  const cocreatorUrl = "https://notion.so/workspace-verifier";
  await setWorkspace(cocreator, projectId, cocreatorUrl);
  await assertWorkspace(coorganizer, projectId, cocreatorUrl);

  const coCreatorRequest = randomUUID();
  const coCreatorLink = await rpc(cocreator, "save_project_workspace_link", {
    p_expected_manager_profile_id: cocreator.id,
    p_project_id: projectId,
    p_display_name: "Co-creator document",
    p_workspace_url: "https://example.org/co-creator",
    p_client_request_id: coCreatorRequest,
  });
  await rpc(cocreator, "remove_project_workspace_link", {
    p_expected_manager_profile_id: cocreator.id,
    p_project_id: projectId,
    p_link_id: coCreatorLink,
    p_expected_version: 1,
  });
  await rpc(creator, "change_project_delegate_role", {
    p_expected_structural_profile_id: creator.id,
    p_delegate_id: cocreatorDelegateId,
    p_authority_role: "co_organizer",
  });
  const demotedUrl = "https://dropbox.com/scl/fo/workspace-verifier";
  await setWorkspace(cocreator, projectId, demotedUrl);

  await assertRpcDenied(
    creator.client.rpc("set_project_shared_workspace", {
      p_expected_manager_profile_id: creator.id,
      p_project_id: projectId,
      p_workspace_url: "http://example.org/not-https",
    }),
    "non-HTTPS workspace",
    "22023",
  );

  const participantMembershipId = await requestAndAccept(
    participant,
    creator,
    projectId,
  );
  await assertWorkspace(participant, projectId, demotedUrl);
  await verifyWorkspaceCollection({
    sql,
    rpc,
    denied: assertRpcDenied,
    creator,
    manager: coorganizer,
    member: participant,
    projectId,
    createProject: createPublishedProposal,
    anonymousClient,
  });
  await assertRpcDenied(
    participant.client.rpc("set_project_shared_workspace", {
      p_expected_manager_profile_id: participant.id,
      p_project_id: projectId,
      p_workspace_url: "https://example.org/participant-write",
    }),
    "ordinary participant workspace mutation",
    "42501",
  );

  await rpc(pending, "request_to_join_project", {
    p_expected_requester_profile_id: pending.id,
    p_project_id: projectId,
    p_request_message: "Pending workspace verification request.",
  });
  await Promise.all([
    assertWorkspaceDenied(pending, projectId, "pending requester"),
    assertWorkspaceDenied(unrelated, projectId, "unrelated profile"),
  ]);

  await rpc(participant, "leave_project", {
    p_expected_participant_profile_id: participant.id,
    p_membership_id: participantMembershipId,
  });
  await assertWorkspaceDenied(participant, projectId, "former participant");

  const recurringId = await createPublishedTavolo(creator);
  await setWorkspace(creator, recurringId, "https://example.org/tavolo-legacy");
  await grantDelegate(creator, coorganizer, recurringId, "co_organizer");
  await grantDelegate(creator, cocreator, recurringId, "co_creator");
  const recurringMembership = await requestAndAccept(
    participant,
    creator,
    recurringId,
  );
  await verifyWorkspaceCollection({
    sql,
    rpc,
    denied: assertRpcDenied,
    creator,
    manager: coorganizer,
    member: participant,
    projectId: recurringId,
    createProject: createPublishedTavolo,
    anonymousClient,
    projectKind: "recurring_activity",
  });
  await assertWorkspaceDenied(unrelated, recurringId, "unrelated Tavolo actor");
  await rpc(creator, "remove_project_member_as_manager", {
    p_expected_manager_profile_id: creator.id,
    p_membership_id: recurringMembership,
  });
  await assertWorkspaceDenied(
    participant,
    recurringId,
    "removed Tavolo participant",
  );

  const groupId = await rpc(unrelated, "create_group_draft", {
    p_expected_profile_id: unrelated.id,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "Synthetic workspace role boundary",
      description: "Local synthetic verifier group only",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await rpc(unrelated, "set_group_publication_state", {
    p_expected_profile_id: unrelated.id,
    p_group_id: groupId,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  for (const [person, role] of [
    [pending, "co_creator"],
    [groupOnly, "co_organizer"],
  ]) {
    const [invitation] = await rpc(
      unrelated,
      "create_group_authority_invitation",
      {
        p_expected_profile_id: unrelated.id,
        p_group_id: groupId,
        p_client_request_id: randomUUID(),
        p_role: role,
      },
    );
    await rpc(person, "accept_group_authority_invitation", {
      p_expected_profile_id: person.id,
      p_client_request_id: randomUUID(),
      p_token: invitation.invite_token,
    });
  }
  const roles =
    await sql`select profile_id,delegate_role from private.group_delegates where group_id=${groupId}::uuid and revoked_at is null`;
  if (roles.length !== 2)
    throw new Error("Canonical group authority fixture is incomplete.");
  for (const person of [unrelated, pending, groupOnly]) {
    await assertWorkspaceDenied(
      person,
      projectId,
      "persistent group role alone",
    );
    await assertWorkspaceDenied(
      person,
      recurringId,
      "persistent group role alone for Tavolo",
    );
  }
  console.log(
    "Tavolo mutations/pages/privacy, removed membership and all three group-only authority roles passed.",
  );

  const coorganizerMembershipId = await requestAndAccept(
    coorganizer,
    creator,
    projectId,
  );
  await rpc(coorganizer, "leave_project", {
    p_expected_participant_profile_id: coorganizer.id,
    p_membership_id: coorganizerMembershipId,
  });
  const managerAfterLeaveUrl =
    "https://sharepoint.com/sites/workspace-verifier";
  await setWorkspace(coorganizer, projectId, managerAfterLeaveUrl);
  await assertWorkspace(coorganizer, projectId, managerAfterLeaveUrl);
  const managerPage = await rpc(coorganizer, "list_project_workspace_links", {
    p_expected_profile_id: coorganizer.id,
    p_project_id: projectId,
  });
  if (managerPage.can_manage !== true)
    throw new Error("Independent management was lost on participant leave.");

  await requestAndAccept(cocreator, creator, projectId);
  await rpc(creator, "revoke_project_delegate", {
    p_expected_owner_profile_id: creator.id,
    p_delegate_id: cocreatorDelegateId,
  });
  await assertWorkspace(cocreator, projectId, managerAfterLeaveUrl);
  await assertRpcDenied(
    cocreator.client.rpc("get_project_workspace_add_receipt", {
      p_expected_manager_profile_id: cocreator.id,
      p_project_id: projectId,
      p_client_request_id: coCreatorRequest,
    }),
    "receipt after manager revocation",
    "42501",
  );
  await assertRpcDenied(
    cocreator.client.rpc("save_project_workspace_link", {
      p_expected_manager_profile_id: cocreator.id,
      p_project_id: projectId,
      p_display_name: "Revoked",
      p_workspace_url: "https://example.org/revoked",
      p_client_request_id: randomUUID(),
    }),
    "named Add after manager revocation",
    "42501",
  );
  await assertRpcDenied(
    cocreator.client.rpc("set_project_shared_workspace", {
      p_expected_manager_profile_id: cocreator.id,
      p_project_id: projectId,
      p_workspace_url: "https://example.org/revoked-delegate-write",
    }),
    "revoked delegate workspace mutation",
    "42501",
  );

  const raceUrls = [
    "https://example.org/workspace-race-creator",
    "https://example.org/workspace-race-coorganizer",
  ];
  const raceResults = await Promise.all([
    setWorkspace(creator, projectId, raceUrls[0]),
    setWorkspace(coorganizer, projectId, raceUrls[1]),
  ]);
  if (raceResults.some((row) => !raceUrls.includes(row.workspace_url))) {
    throw new Error("Concurrent manager writes returned a non-canonical URL.");
  }
  const canonicalAfterRace = await getWorkspace(creator, projectId);
  if (
    canonicalAfterRace.length !== 1 ||
    !raceUrls.includes(canonicalAfterRace[0].workspace_url)
  ) {
    throw new Error(
      "Concurrent manager writes did not leave one canonical workspace.",
    );
  }
  const [{ workspaceCount }] = await sql`
    select count(*)::integer as "workspaceCount"
    from public.project_shared_workspaces
    where project_id = ${projectId}::uuid
  `;
  if (workspaceCount !== 1) {
    throw new Error("Concurrent manager writes created duplicate workspaces.");
  }

  await rpc(creator, "clear_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
  });
  if ((await getWorkspace(cocreator, projectId)).length !== 0) {
    throw new Error("Clearing the workspace did not remove canonical state.");
  }
  const secondClear = await rpc(creator, "clear_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
  });
  if (secondClear !== false) {
    throw new Error("Clearing an empty workspace was not idempotent.");
  }

  await assertAnonymousDenied(projectId);
  await assertNoSensitiveEventPayload([
    firstUrl,
    coorganizerUrl,
    cocreatorUrl,
    demotedUrl,
    managerAfterLeaveUrl,
    ...raceUrls,
  ]);

  if (!coorganizerDelegateId) {
    throw new Error("Co-organizer delegation did not return an identifier.");
  }
  console.log(
    "Confirmed pre-chat setup, Creator/Co-creator/Co-organizer mutation, demotion continuity, current-participant read-only access, leave/revocation independence, concurrent canonical replacement, idempotent clear, anonymous denial, and URL-free generic events.",
  );
}

async function createPublishedProposal(creator, publish = true) {
  const projectId = await rpc(creator, "create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Shared workspace verifier Project",
    p_summary: "A deterministic Project for workspace access verification.",
    p_description:
      "This Project verifies current manager and participant workspace access.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Provincia autonoma di Trento",
    p_public_location_label: "Trento",
    p_exact_meeting_text: "Workspace verifier meeting point",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (publish) {
    await rpc(creator, "publish_proposal", {
      p_expected_creator_profile_id: creator.id,
      p_proposal_id: projectId,
    });
  }
  return projectId;
}

async function createPublishedTavolo(creator, publish = true) {
  const id = await rpc(creator, "create_recurring_activity_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Workspace Tavolo verifier",
    p_summary: "Synthetic workspace verification",
    p_description: "Local synthetic recurring Project",
    p_topic: "Garden",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Trento",
    p_public_location_label: "Trento",
    p_exact_meeting_text: "Synthetic meeting point",
    p_exact_location_visibility: "participants",
    p_recurrence_type: "weekly",
    p_weekday: 2,
    p_day_of_month: null,
    p_local_start_time: "10:00",
    p_duration_minutes: 60,
    p_event_timezone: "Europe/Rome",
    p_effective_from: "2098-01-01",
    p_people_capacity: 20,
  });
  if (publish)
    await rpc(creator, "publish_recurring_activity", {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: id,
    });
  return id;
}

async function grantDelegate(creator, candidate, projectId, role) {
  const invitation = singleRow(
    await rpc(creator, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: creator.id,
      p_project_id: projectId,
      p_requested_authority_role: role,
    }),
    "workspace delegate invitation",
  );
  return rpc(candidate, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: candidate.id,
    p_token: invitation.invite_token,
  });
}

async function requestAndAccept(participant, manager, projectId) {
  const requestId = await rpc(participant, "request_to_join_project", {
    p_expected_requester_profile_id: participant.id,
    p_project_id: projectId,
    p_request_message: "Workspace verifier participation request.",
  });
  return rpc(manager, "accept_project_join_request_as_manager", {
    p_expected_manager_profile_id: manager.id,
    p_request_id: requestId,
  });
}

async function getWorkspace(user, projectId) {
  return rpc(user, "get_own_project_shared_workspace", {
    p_expected_profile_id: user.id,
    p_project_id: projectId,
  });
}

async function setWorkspace(user, projectId, workspaceUrl) {
  return singleRow(
    await rpc(user, "set_project_shared_workspace", {
      p_expected_manager_profile_id: user.id,
      p_project_id: projectId,
      p_workspace_url: workspaceUrl,
    }),
    "workspace replacement",
  );
}

async function assertWorkspace(user, projectId, expectedUrl) {
  const row = singleRow(await getWorkspace(user, projectId), "workspace read");
  if (row.project_id !== projectId || row.workspace_url !== expectedUrl) {
    throw new Error("Workspace read did not return canonical state.");
  }
}

async function assertWorkspaceDenied(user, projectId, label) {
  await assertRpcDenied(
    user.client.rpc("get_own_project_shared_workspace", {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
    }),
    label,
    "42501",
  );
  await assertRpcDenied(
    user.client.rpc("get_project_workspace_link", {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
      p_link_id: "fa000000-0000-4000-8000-000000000000",
    }),
    `${label} item`,
    "42501",
  );
  await assertRpcDenied(
    user.client.rpc("get_project_workspace_add_receipt", {
      p_expected_manager_profile_id: user.id,
      p_project_id: projectId,
      p_client_request_id: randomUUID(),
    }),
    `${label} receipt`,
    "42501",
  );
  await assertRpcDenied(
    user.client.rpc("list_project_workspace_links", {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
    }),
    `${label} list`,
    "42501",
  );
  await assertRpcDenied(
    user.client.rpc("save_project_workspace_link", {
      p_expected_manager_profile_id: user.id,
      p_project_id: projectId,
      p_display_name: "Denied",
      p_workspace_url: "https://example.org",
      p_client_request_id: randomUUID(),
    }),
    `${label} add`,
    "42501",
  );
  await assertRpcDenied(
    user.client.rpc("remove_project_workspace_link", {
      p_expected_manager_profile_id: user.id,
      p_project_id: projectId,
      p_link_id: "fa000000-0000-4000-8000-000000000000",
      p_expected_version: 1,
    }),
    `${label} remove`,
    "42501",
  );
}

async function assertAnonymousDenied(projectId) {
  const { data, error } = await anonymousClient.rpc(
    "get_own_project_shared_workspace",
    {
      p_expected_profile_id: "00000000-0000-4000-8000-000000000001",
      p_project_id: projectId,
    },
  );
  if (data !== null || error?.code !== "42501") {
    throw new Error("Anonymous workspace read did not fail closed.");
  }
}

async function assertProjectHasNoChat(projectId) {
  const [{ chatCount }] = await sql`
    select count(*)::integer as "chatCount"
    from public.project_group_chats
    where project_id = ${projectId}::uuid
  `;
  if (chatCount !== 0) {
    throw new Error("Workspace setup unexpectedly required a Project chat.");
  }
}

async function assertNoSensitiveEventPayload(urls) {
  for (const url of urls) {
    const [{ leakedCount }] = await sql`
      select (
        select count(*)::integer
        from private.audit_events as event
        where event.metadata::text like ${`%${url}%`}
      ) + (
        select count(*)::integer
        from private.outbox_events as event
        where event.payload::text like ${`%${url}%`}
      ) as "leakedCount"
    `;
    if (leakedCount !== 0) {
      throw new Error("A raw workspace URL leaked into generic event data.");
    }
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a workspace-test profile", anchorError);
    }
  }
  await rpc(user, "update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
}

function signIn(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "project-workspace",
  });
}

async function rpc(user, name, params) {
  const { data, error } = await user.client.rpc(name, params);
  if (error) throw safeDatabaseFailure(name, error);
  return data;
}

async function assertRpcDenied(promise, label, expectedCode) {
  const { data, error } = await promise;
  if (data !== null || error?.code !== expectedCode) {
    throw new Error(`${label} did not fail with ${expectedCode}.`);
  }
}

function singleRow(data, label) {
  if (!Array.isArray(data) || data.length !== 1) {
    throw new Error(`${label} did not return exactly one row.`);
  }
  return data[0];
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
