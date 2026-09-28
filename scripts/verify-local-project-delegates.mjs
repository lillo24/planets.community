import { createClient } from "@supabase/supabase-js";
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
  await verifyProjectDelegates();
} finally {
  await sql.end();
}

async function verifyProjectDelegates() {
  const [owner, candidateA, candidateB, requester] = await Promise.all([
    signIn("delegate-owner@planets.invalid"),
    signIn("delegate-candidate-a@planets.invalid"),
    signIn("delegate-candidate-b@planets.invalid"),
    signIn("delegate-requester@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(owner, "Delegate Owner"),
    ensureCompleteProfile(candidateA, "Delegate Candidate A"),
    ensureCompleteProfile(candidateB, "Delegate Candidate B"),
    ensureCompleteProfile(requester, "Delegate Requester"),
  ]);

  const projectId = await createPublishedProposal(owner);
  const invite = await createInvite(owner, projectId);
  if (!/^[A-Za-z0-9_-]{43}$/.test(invite.invite_token)) {
    throw new Error(
      "Delegate creation did not return a 256-bit base64url token.",
    );
  }

  const preview = await previewInvite(invite.invite_token);
  if (
    preview.is_available !== true ||
    preview.project_id !== projectId ||
    preview.project_kind !== "one_time"
  ) {
    throw new Error(
      "Anonymous invite preview did not return safe Project context.",
    );
  }
  await assertRpcDenied(
    candidateA.client.rpc("list_project_join_requests_for_manager", {
      p_expected_manager_profile_id: candidateA.id,
      p_project_id: projectId,
    }),
    "preview-only candidate manager read",
    "42501",
  );

  const attempts = await Promise.all([
    acceptInvite(candidateA, invite.invite_token),
    acceptInvite(candidateB, invite.invite_token),
  ]);
  const winners = attempts.filter((attempt) => attempt.ok);
  if (winners.length !== 1) {
    throw new Error(
      "A raced single-use invite did not produce exactly one winner.",
    );
  }
  const winner = winners[0].user;
  const loser = winner.id === candidateA.id ? candidateB : candidateA;
  const delegateId = winners[0].delegateId;
  const retry = await acceptInvite(winner, invite.invite_token);
  if (!retry.ok || retry.delegateId !== delegateId) {
    throw new Error("The winning accepter retry was not idempotent.");
  }
  await assertRpcDenied(
    loser.client.rpc("accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: loser.id,
      p_token: invite.invite_token,
    }),
    "losing invite accepter retry",
    "42501",
  );

  const [{ membershipCount, plaintextTokenCount }] = await sql`
    select
      (
        select count(*)::integer
        from public.project_memberships as membership
        where membership.participant_profile_id = ${winner.id}::uuid
      ) as "membershipCount",
      (
        select count(*)::integer
        from public.project_delegate_invitations as invitation
        where encode(invitation.token_digest, 'escape') = ${invite.invite_token}
      ) as "plaintextTokenCount"
  `;
  if (membershipCount !== 0 || plaintextTokenCount !== 0) {
    throw new Error(
      "Delegate acceptance created membership or persisted the bearer token.",
    );
  }

  const secondInvite = await createInvite(owner, projectId);
  await assertRpcDenied(
    winner.client.rpc("accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: winner.id,
      p_token: secondInvite.invite_token,
    }),
    "already-active delegate invite acceptance",
    "55000",
  );
  await assertRpcDenied(
    winner.client.rpc("create_project_delegate_invitation", {
      p_expected_owner_profile_id: winner.id,
      p_project_id: projectId,
    }),
    "delegate-created invitation",
    "42501",
  );
  await rpc(owner, "revoke_project_delegate_invitation", {
    p_expected_owner_profile_id: owner.id,
    p_invitation_id: secondInvite.invitation_id,
  });

  const requestId = await rpc(requester, "request_to_join_project", {
    p_expected_requester_profile_id: requester.id,
    p_project_id: projectId,
    p_request_message: "I can help with the delegate verification Project.",
  });
  const requests = await rpc(winner, "list_project_join_requests_for_manager", {
    p_expected_manager_profile_id: winner.id,
    p_project_id: projectId,
  });
  if (!requests.some((request) => request.request_id === requestId)) {
    throw new Error(
      "The active delegate could not see the participation request.",
    );
  }

  const requestChat = singleRow(
    await rpc(winner, "get_own_project_join_request_chat", {
      p_expected_profile_id: winner.id,
      p_request_id: requestId,
    }),
    "delegate request chat",
  );
  if (requestChat.viewer_role !== "delegate") {
    throw new Error(
      "The request chat did not identify the active delegate role.",
    );
  }
  await rpc(winner, "send_project_join_request_chat_message", {
    p_expected_profile_id: winner.id,
    p_chat_id: requestChat.chat_id,
    p_body: "Delegate organizer reply",
  });
  if (
    !(await canReceiveTopic(
      winner.id,
      "private.profile_can_receive_project_join_request_chat_topic",
      `project-request-chat:${requestChat.chat_id}:profile:${winner.id}`,
    ))
  ) {
    throw new Error("The active delegate failed private-chat Realtime auth.");
  }

  await rpc(winner, "accept_project_join_request_as_manager", {
    p_expected_manager_profile_id: winner.id,
    p_request_id: requestId,
  });
  const groupChat = singleRow(
    await rpc(winner, "get_own_project_group_chat", {
      p_expected_profile_id: winner.id,
      p_project_id: projectId,
    }),
    "delegate group chat",
  );
  if (groupChat.viewer_role !== "delegate") {
    throw new Error(
      "The Project chat did not identify the active delegate role.",
    );
  }
  await rpc(winner, "send_project_chat_message", {
    p_expected_profile_id: winner.id,
    p_chat_id: groupChat.chat_id,
    p_body: "Delegate group coordination",
  });
  if (
    !(await canReceiveTopic(
      winner.id,
      "private.profile_can_receive_project_chat_realtime_topic",
      `project-chat:${groupChat.chat_id}:profile:${winner.id}`,
    ))
  ) {
    throw new Error("The active delegate failed Project-chat Realtime auth.");
  }
  const meeting = singleRow(
    await rpc(winner, "get_project_participant_meeting_details", {
      p_expected_profile_id: winner.id,
      p_project_id: projectId,
    }),
    "delegate meeting details",
  );
  if (meeting.exact_meeting_text !== "Delegate verification location") {
    throw new Error(
      "The active delegate could not read protected meeting data.",
    );
  }

  await assertRpcDenied(
    winner.client.rpc("cancel_proposal", {
      p_expected_creator_profile_id: winner.id,
      p_proposal_id: projectId,
    }),
    "delegate owner-only lifecycle mutation",
    "42501",
  );
  await rpc(owner, "revoke_project_delegate", {
    p_expected_owner_profile_id: owner.id,
    p_delegate_id: delegateId,
  });

  await Promise.all([
    assertRpcDenied(
      winner.client.rpc("list_project_members_for_manager", {
        p_expected_manager_profile_id: winner.id,
        p_project_id: projectId,
      }),
      "revoked delegate participation read",
      "42501",
    ),
    assertRpcDenied(
      winner.client.rpc("get_own_project_join_request_chat", {
        p_expected_profile_id: winner.id,
        p_request_id: requestId,
      }),
      "revoked delegate request-chat read",
      "42501",
    ),
    assertRpcDenied(
      winner.client.rpc("get_own_project_group_chat", {
        p_expected_profile_id: winner.id,
        p_project_id: projectId,
      }),
      "revoked delegate group-chat read",
      "42501",
    ),
    assertRpcDenied(
      winner.client.rpc("get_project_participant_meeting_details", {
        p_expected_profile_id: winner.id,
        p_project_id: projectId,
      }),
      "revoked delegate meeting read",
      "42501",
    ),
  ]);
  if (
    (await canReceiveTopic(
      winner.id,
      "private.profile_can_receive_project_chat_realtime_topic",
      `project-chat:${groupChat.chat_id}:profile:${winner.id}`,
    )) ||
    (await canReceiveTopic(
      winner.id,
      "private.profile_can_receive_project_join_request_chat_topic",
      `project-request-chat:${requestChat.chat_id}:profile:${winner.id}`,
    ))
  ) {
    throw new Error("Revocation did not remove Realtime topic authorization.");
  }

  const expiredInvite = await createInvite(owner, projectId);
  await sql`
    update public.project_delegate_invitations
    set
      created_at = statement_timestamp() - interval '8 days',
      expires_at = statement_timestamp() - interval '1 day'
    where id = ${expiredInvite.invitation_id}::uuid
  `;
  const expiredPreview = await previewInvite(expiredInvite.invite_token);
  if (expiredPreview.is_available !== false) {
    throw new Error("An expired invite remained previewable.");
  }
  await assertRpcDenied(
    winner.client.rpc("accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: winner.id,
      p_token: expiredInvite.invite_token,
    }),
    "expired invite acceptance",
    "42501",
  );

  const lifecycleInvite = await createInvite(owner, projectId);
  await rpc(owner, "cancel_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: projectId,
  });
  const cancelledPreview = await previewInvite(lifecycleInvite.invite_token);
  if (cancelledPreview.is_available !== false) {
    throw new Error("A cancelled Project invite remained previewable.");
  }
  await assertRpcDenied(
    candidateA.client.rpc("accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: candidateA.id,
      p_token: lifecycleInvite.invite_token,
    }),
    "cancelled Project invite acceptance",
    "55000",
  );

  const [{ leakedTokens }] = await sql`
    select (
      select count(*)::integer
      from private.audit_events as event
      where event.action like 'project.delegate%'
        and event.metadata::text like ${`%${invite.invite_token}%`}
    ) + (
      select count(*)::integer
      from private.outbox_events as event
      where event.event_type like 'project.delegate%'
        and event.payload::text like ${`%${invite.invite_token}%`}
    ) as "leakedTokens"
  `;
  if (leakedTokens !== 0) {
    throw new Error(
      "A delegate bearer token leaked into audit/outbox metadata.",
    );
  }

  console.log(
    "Confirmed secure preview, first-winner invite races, same-user retry, no fake membership, the structural role-management boundary, delegate participation/chat/Realtime/meeting access, immediate revocation, exact expiry, lifecycle fail-closed behavior, and identifier-only events.",
  );
}

async function createPublishedProposal(owner) {
  const projectId = await rpc(owner, "create_proposal_draft", {
    p_expected_creator_profile_id: owner.id,
    p_title: "Delegate verification Proposal",
    p_summary: "A deterministic Project for delegate security verification.",
    p_description:
      "This Project verifies invitation, manager authorization, chat, and revocation behavior.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Delegate verification location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  await rpc(owner, "publish_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: projectId,
  });
  return projectId;
}

async function createInvite(owner, projectId) {
  return singleRow(
    await rpc(owner, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: owner.id,
      p_project_id: projectId,
    }),
    "delegate invitation",
  );
}

async function previewInvite(token) {
  const { data, error } = await anonymousClient.rpc(
    "preview_project_delegate_invitation",
    { p_token: token },
  );
  if (error) throw safeDatabaseFailure("preview a delegate invitation", error);
  return singleRow(data, "delegate invite preview");
}

async function acceptInvite(user, token) {
  const { data, error } = await user.client.rpc(
    "accept_project_delegate_invitation",
    { p_expected_delegate_profile_id: user.id, p_token: token },
  );
  return error
    ? { ok: false, user, error }
    : { ok: true, user, delegateId: data };
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

async function canReceiveTopic(profileId, functionName, topic) {
  return sql.begin(async (transaction) => {
    await transaction`
      select set_config('request.jwt.claim.sub', ${profileId}, true)
    `;
    const rows = await transaction.unsafe(
      `select ${functionName}($1::text) as allowed`,
      [topic],
    );
    return rows[0]?.allowed === true;
  });
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a delegate-test profile", anchorError);
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
    verifierName: "project-delegates",
  });
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
