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
  const [owner, requester, outsider, moderator] = await Promise.all([
    signIn("counterstatement-owner@planets.invalid", "Resource owner"),
    signIn("counterstatement-requester@planets.invalid", "Resource requester"),
    signIn("counterstatement-outsider@planets.invalid", "unrelated user"),
    signIn("counterstatement-staff@planets.invalid", "moderation staff"),
  ]);
  await Promise.all([
    ensureProfile(owner, "Counterstatement Owner"),
    ensureProfile(requester, "Counterstatement Requester"),
    ensureProfile(outsider, "Counterstatement Outsider"),
    ensureProfile(moderator, "Counterstatement Staff"),
  ]);

  const listingId = randomUUID();
  const resourceRequestId = randomUUID();
  await sql.begin(async (transaction) => {
    await transaction`
      insert into public.resource_listings (
        id, owner_profile_id, listing_mode, lifecycle_state, title,
        description, country_code, locality, public_location_label, published_at
      ) values (
        ${listingId}::uuid,
        ${owner.id}::uuid,
        'exchange',
        'published',
        'Local counterstatement verifier resource',
        'A deterministic local Resource episode for evidence verification.',
        'IT',
        'Trento',
        'Trento',
        statement_timestamp() - interval '1 day'
      )
    `;
    await transaction`
      insert into public.resource_listing_requests (
        id, listing_id, requester_profile_id, status, created_at,
        resolved_at, resolved_by_profile_id
      ) values (
        ${resourceRequestId}::uuid,
        ${listingId}::uuid,
        ${requester.id}::uuid,
        'accepted',
        statement_timestamp() - interval '2 hours',
        statement_timestamp() - interval '1 hour',
        ${owner.id}::uuid
      )
    `;
  });

  const reportExplanation =
    "A local Resource counterparty report requiring private manual review.";
  const { data: receiptRows, error: reportError } = await owner.client.rpc(
    "submit_moderation_report",
    {
      p_expected_reporter_profile_id: owner.id,
      p_client_submission_id: randomUUID(),
      p_category: "other",
      p_explanation: reportExplanation,
      p_target_kind: "resource_request",
      p_target_id: resourceRequestId,
      p_context_kind: null,
      p_context_id: null,
    },
  );
  const receipt = Array.isArray(receiptRows) ? receiptRows[0] : null;
  if (reportError || typeof receipt?.case_id !== "string") {
    throw safeFailure(
      "submit the qualifying Resource report",
      reportError ?? {},
    );
  }

  const { data: pending, error: pendingError } = await requester.client.rpc(
    "list_own_moderation_evidence_requests",
    {
      p_expected_recipient_profile_id: requester.id,
      p_pending_only: true,
      p_limit: 1,
    },
  );
  const request = Array.isArray(pending) ? pending[0] : null;
  if (
    pendingError ||
    request?.request_kind !== "resource_counterstatement" ||
    typeof request?.request_id !== "string"
  ) {
    throw safeFailure("read the subject pending evidence", pendingError ?? {});
  }

  const { data: detailRows, error: detailError } = await requester.client.rpc(
    "get_own_resource_counterstatement_request",
    {
      p_expected_recipient_profile_id: requester.id,
      p_request_id: request.request_id,
    },
  );
  const detail = Array.isArray(detailRows) ? detailRows[0] : null;
  if (
    detailError ||
    detail?.explanation !== reportExplanation ||
    Object.hasOwn(detail ?? {}, "reporter_profile_id")
  ) {
    throw safeFailure(
      "read the assigned private accusation",
      detailError ?? {},
    );
  }

  for (const deniedUser of [owner, outsider]) {
    const { data, error } = await deniedUser.client.rpc(
      "get_own_resource_counterstatement_request",
      {
        p_expected_recipient_profile_id: deniedUser.id,
        p_request_id: request.request_id,
      },
    );
    if (error || !Array.isArray(data) || data.length !== 0) {
      throw safeFailure("hide evidence from an unassigned user", error ?? {});
    }
  }

  const statement =
    "My private version adds context for the moderation team's manual review.";
  const submissionId = randomUUID();
  const submissionParams = {
    p_expected_recipient_profile_id: requester.id,
    p_request_id: request.request_id,
    p_client_submission_id: submissionId,
    p_statement: statement,
  };
  const { data: responseRows, error: responseError } =
    await requester.client.rpc(
      "submit_resource_counterstatement",
      submissionParams,
    );
  const response = Array.isArray(responseRows) ? responseRows[0] : null;
  if (responseError || typeof response?.counterstatement_id !== "string") {
    throw safeFailure(
      "submit one private counterstatement",
      responseError ?? {},
    );
  }
  const { data: retryRows, error: retryError } = await requester.client.rpc(
    "submit_resource_counterstatement",
    submissionParams,
  );
  if (
    retryError ||
    retryRows?.[0]?.counterstatement_id !== response.counterstatement_id
  ) {
    throw safeFailure("retry the exact counterstatement", retryError ?? {});
  }

  await sql`
    insert into private.moderation_staff_roles (profile_id, staff_role)
    values (${moderator.id}::uuid, 'moderator')
    on conflict (profile_id) do update
    set staff_role = 'moderator', is_active = true, deactivated_at = null
  `;
  const { data: evidenceRows, error: evidenceError } =
    await moderator.client.rpc("get_moderation_case_counterstatement", {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
    });
  const evidence = Array.isArray(evidenceRows) ? evidenceRows[0] : null;
  if (
    evidenceError ||
    evidence?.recipient_profile_id !== requester.id ||
    evidence?.statement !== statement
  ) {
    throw safeFailure(
      "read the staff-only counterstatement",
      evidenceError ?? {},
    );
  }

  const [resourceState] = await sql`
    select status, listing_id
    from public.resource_listing_requests
    where id = ${resourceRequestId}::uuid
  `;
  const [leakedAudit] = await sql`
    select count(*)::integer as count
    from private.audit_events
    where action like 'moderation.resource_counterstatement%'
      and metadata::text like any (
        array[${`%${reportExplanation}%`}, ${`%${statement}%`}]
      )
  `;
  const [moderationOutbox] = await sql`
    select count(*)::integer as count
    from private.outbox_events
    where event_type like 'moderation.resource_counterstatement%'
      or payload::text like ${`%${statement}%`}
  `;
  if (
    resourceState?.status !== "accepted" ||
    resourceState?.listing_id !== listingId ||
    leakedAudit.count !== 0 ||
    moderationOutbox.count !== 0
  ) {
    throw new Error(
      "Counterstatement evidence changed Resource state or escaped its private boundary.",
    );
  }

  console.log(
    "Verified canonical Resource counterstatement creation, subject-only immutable submission, staff evidence, and privacy boundaries locally.",
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
    throw safeFailure(
      "create a counterstatement verifier profile",
      anchorError,
    );
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
    throw safeFailure("complete a counterstatement verifier profile", error);
  }
}

function safeFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
