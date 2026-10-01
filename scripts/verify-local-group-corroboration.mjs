import { randomUUID } from "node:crypto";

import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const { apiUrl, publishableKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);
if (!databaseUrl) {
  throw new Error("Local Supabase status did not expose the database URL.");
}
const sql = postgres(databaseUrl, { max: 1 });

try {
  const [reporter, subject, creator, witness, moderator] = await Promise.all([
    signIn("corroboration-reporter@planets.invalid", "corroboration reporter"),
    signIn("corroboration-subject@planets.invalid", "corroboration subject"),
    signIn("corroboration-creator@planets.invalid", "corroboration creator"),
    signIn("corroboration-witness@planets.invalid", "corroboration witness"),
    signIn("corroboration-staff@planets.invalid", "corroboration staff"),
  ]);
  await Promise.all([
    ensureProfile(reporter, "Corroboration Reporter"),
    ensureProfile(subject, "Corroboration Subject"),
    ensureProfile(creator, "Corroboration Creator"),
    ensureProfile(witness, "Corroboration Witness"),
    ensureProfile(moderator, "Corroboration Staff"),
  ]);

  const projectId = randomUUID();
  const membershipProfiles = [reporter.id, subject.id, witness.id];
  await sql.begin(async (transaction) => {
    await transaction`
      insert into public.proposals (
        id, creator_profile_id, lifecycle_state, title, starts_at, ends_at, published_at
      ) values (
        ${projectId}::uuid,
        ${creator.id}::uuid,
        'published',
        'Local corroboration verifier project',
        statement_timestamp() - interval '1 hour',
        statement_timestamp() + interval '1 day',
        statement_timestamp()
      )
    `;
    for (const participantId of membershipProfiles) {
      const requestId = randomUUID();
      await transaction`
        insert into public.project_join_requests (
          id, project_id, requester_profile_id, status, created_at,
          resolved_at, resolved_by_profile_id
        ) values (
          ${requestId}::uuid,
          ${projectId}::uuid,
          ${participantId}::uuid,
          'accepted',
          statement_timestamp() - interval '2 minutes',
          statement_timestamp() - interval '1 minute',
          ${creator.id}::uuid
        )
      `;
      await transaction`
        insert into public.project_memberships (
          project_id, participant_profile_id, originating_request_id, joined_at
        ) values (
          ${projectId}::uuid,
          ${participantId}::uuid,
          ${requestId}::uuid,
          statement_timestamp() - interval '1 minute'
        )
      `;
    }
  });

  const { data: receiptRows, error: reportError } = await reporter.client.rpc(
    "submit_moderation_report",
    {
      p_expected_reporter_profile_id: reporter.id,
      p_client_submission_id: randomUUID(),
      p_category: "other",
      p_explanation:
        "A local Project-context conduct report for private review.",
      p_target_kind: "profile",
      p_target_id: subject.id,
      p_context_kind: "project",
      p_context_id: projectId,
    },
  );
  const receipt = Array.isArray(receiptRows) ? receiptRows[0] : null;
  if (reportError || typeof receipt?.case_id !== "string") {
    throw safeFailure(
      "submit the qualifying Project report",
      reportError ?? {},
    );
  }

  const pending = await listPending(witness);
  if (pending.length !== 1 || typeof pending[0]?.request_id !== "string") {
    throw new Error("Failed to read the snapshotted witness request.");
  }
  const requestId = pending[0].request_id;
  const { data: detailRows, error: detailError } = await witness.client.rpc(
    "get_own_group_corroboration_request",
    {
      p_expected_recipient_profile_id: witness.id,
      p_request_id: requestId,
    },
  );
  const detail = Array.isArray(detailRows) ? detailRows[0] : null;
  if (
    detailError ||
    typeof detail?.explanation !== "string" ||
    Object.hasOwn(detail, "reporter_profile_id")
  ) {
    throw safeFailure(
      "read the reporter-anonymous assigned detail",
      detailError ?? {},
    );
  }

  const submissionId = randomUUID();
  const responseParams = {
    p_expected_recipient_profile_id: witness.id,
    p_request_id: requestId,
    p_client_submission_id: submissionId,
    p_choice: "unsure",
    p_explanation: null,
  };
  const { data: responseRows, error: responseError } = await witness.client.rpc(
    "submit_group_corroboration_response",
    responseParams,
  );
  const response = Array.isArray(responseRows) ? responseRows[0] : null;
  if (responseError || typeof response?.response_id !== "string") {
    throw safeFailure("submit one private response", responseError ?? {});
  }
  const { data: retryRows, error: retryError } = await witness.client.rpc(
    "submit_group_corroboration_response",
    responseParams,
  );
  if (retryError || retryRows?.[0]?.response_id !== response.response_id) {
    throw safeFailure("retry the exact private response", retryError ?? {});
  }

  const { data: subjectDetail, error: subjectDetailError } =
    await subject.client.rpc("get_own_group_corroboration_request", {
      p_expected_recipient_profile_id: subject.id,
      p_request_id: requestId,
    });
  if (subjectDetailError || subjectDetail?.length !== 0) {
    throw safeFailure(
      "hide the request from the reported subject",
      subjectDetailError ?? {},
    );
  }

  await sql`
    insert into private.moderation_staff_roles (profile_id, staff_role)
    values (${moderator.id}::uuid, 'moderator')
    on conflict (profile_id) do update
    set staff_role = 'moderator', is_active = true, deactivated_at = null
  `;
  const { data: evidenceRows, error: evidenceError } =
    await moderator.client.rpc("get_moderation_case_corroboration", {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
    });
  const evidence = Array.isArray(evidenceRows) ? evidenceRows[0] : null;
  if (
    evidenceError ||
    evidence?.invited_count !== 2 ||
    evidence?.responded_count !== 1 ||
    evidence?.responses?.[0]?.responder_profile_id !== witness.id
  ) {
    throw safeFailure(
      "read identified staff-only evidence",
      evidenceError ?? {},
    );
  }

  const { data: reviewRows, error: reviewError } = await moderator.client.rpc(
    "transition_moderation_case",
    {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
      p_expected_state_version: 0,
      p_target_state: "under_review",
    },
  );
  if (reviewError) throw safeFailure("start review", reviewError);
  const { error: completeError } = await moderator.client.rpc(
    "transition_moderation_case",
    {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
      p_expected_state_version: reviewRows?.[0]?.state_version,
      p_target_state: "completed",
    },
  );
  if (completeError) throw safeFailure("complete review", completeError);

  const creatorPending = await listPending(creator);
  if (creatorPending.length !== 0) {
    throw new Error("A completed case remained visible as pending.");
  }

  const [leak] = await sql`
    select count(*)::integer as count
    from private.audit_events
    where action like 'moderation.group_corroboration%'
      and metadata::text like any (array['%unsure%', '%recipient_profile_id%'])
  `;
  const [outbox] = await sql`
    select count(*)::integer as count
    from private.outbox_events
    where event_type like 'moderation.group_corroboration%'
  `;
  if (leak.count !== 0 || outbox.count !== 0) {
    throw new Error("Corroboration evidence escaped its private boundary.");
  }

  console.log(
    "Verified creation-time group corroboration, private final response, staff evidence, and completion behavior locally.",
  );
} finally {
  await sql.end({ timeout: 2 });
}

function signIn(email, verifierName) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName,
  });
}

async function ensureProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError && anchorError.code !== "23505") {
    throw safeFailure("create a corroboration verifier profile", anchorError);
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
  if (error)
    throw safeFailure("complete a corroboration verifier profile", error);
}

async function listPending(user) {
  const { data, error } = await user.client.rpc(
    "list_own_group_corroboration_requests",
    {
      p_expected_recipient_profile_id: user.id,
      p_pending_only: true,
      p_limit: 20,
      p_before_created_at: null,
      p_before_request_id: null,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeFailure("list pending corroboration requests", error ?? {});
  }
  return data;
}

function safeFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
