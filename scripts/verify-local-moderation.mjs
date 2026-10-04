import { verifyTemplateModeration } from "./verify-local-template-moderation.mjs";
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
if (!databaseUrl)
  throw new Error("Local Supabase status did not expose the database URL.");
const sql = postgres(databaseUrl, { max: 1 });

try {
  const [reporter, subject, moderator] = await Promise.all([
    signIn("moderation-reporter@planets.invalid", "moderation reporter"),
    signIn("moderation-subject@planets.invalid", "moderation subject"),
    signIn("moderation-staff@planets.invalid", "moderation staff"),
  ]);
  await Promise.all([
    ensureProfile(reporter, "Moderation Reporter", "private"),
    ensureProfile(subject, "Moderation Subject", "public"),
    ensureProfile(moderator, "Moderation Staff", "private"),
  ]);

  await expectRpcCode(
    moderator.client.rpc("list_moderation_cases", {
      p_expected_staff_profile_id: moderator.id,
      p_state: null,
      p_limit: 10,
      p_before_created_at: null,
      p_before_case_id: null,
    }),
    "42501",
    "deny an ordinary authenticated queue read",
  );

  const explanation = "A local verifier report requiring manual review.";
  const { data: receiptRows, error: reportError } = await reporter.client.rpc(
    "submit_moderation_report",
    {
      p_expected_reporter_profile_id: reporter.id,
      p_client_submission_id: randomUUID(),
      p_category: "other",
      p_explanation: explanation,
      p_target_kind: "profile",
      p_target_id: subject.id,
      p_context_kind: null,
      p_context_id: null,
    },
  );
  const receipt = Array.isArray(receiptRows) ? receiptRows[0] : null;
  if (reportError || typeof receipt?.case_id !== "string") {
    throw safeFailure(
      "submit an authenticated moderation report",
      reportError ?? {},
    );
  }

  const { data: ownReports, error: ownError } = await reporter.client.rpc(
    "list_own_moderation_reports",
    {
      p_expected_reporter_profile_id: reporter.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_report_id: null,
    },
  );
  if (
    ownError ||
    !Array.isArray(ownReports) ||
    !ownReports.some((row) => row.report_id === receipt.report_id)
  ) {
    throw safeFailure(
      "read the reporter-owned status projection",
      ownError ?? {},
    );
  }
  const { data: subjectReports, error: subjectReportsError } =
    await subject.client.rpc("list_own_moderation_reports", {
      p_expected_reporter_profile_id: subject.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_report_id: null,
    });
  if (
    subjectReportsError ||
    !Array.isArray(subjectReports) ||
    subjectReports.length !== 0
  ) {
    throw safeFailure(
      "keep reports hidden from the reported profile",
      subjectReportsError ?? {},
    );
  }

  await sql`
    insert into private.moderation_staff_roles (profile_id, staff_role, is_active, deactivated_at)
    values (${moderator.id}::uuid, 'moderator', true, null)
    on conflict (profile_id) do update
    set staff_role = 'moderator', is_active = true, deactivated_at = null
  `;

  const { data: accessRows, error: accessError } = await moderator.client.rpc(
    "get_own_moderation_staff_access",
    { p_expected_profile_id: moderator.id },
  );
  if (accessError || accessRows?.[0]?.staff_role !== "moderator") {
    throw safeFailure(
      "authorize an operator-provisioned moderator",
      accessError ?? {},
    );
  }
  const { data: detailRows, error: detailError } = await moderator.client.rpc(
    "get_moderation_case_detail",
    { p_expected_staff_profile_id: moderator.id, p_case_id: receipt.case_id },
  );
  const detail = Array.isArray(detailRows) ? detailRows[0] : null;
  if (
    detailError ||
    detail?.reporter_profile_id !== reporter.id ||
    detail?.subject_profile_id !== subject.id
  ) {
    throw safeFailure("read the staff-only moderation case", detailError ?? {});
  }

  const noteBody = "Local verifier private staff note.";
  const { error: noteError } = await moderator.client.rpc(
    "add_moderation_case_note",
    {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
      p_body: noteBody,
    },
  );
  if (noteError)
    throw safeFailure("append a staff-only moderation note", noteError);

  const targetState =
    detail.state === "under_review" ? "completed" : "under_review";
  const { error: transitionError } = await moderator.client.rpc(
    "transition_moderation_case",
    {
      p_expected_staff_profile_id: moderator.id,
      p_case_id: receipt.case_id,
      p_expected_state_version: detail.state_version,
      p_target_state: targetState,
    },
  );
  if (transitionError)
    throw safeFailure(
      "transition the moderation review state",
      transitionError,
    );

  const [leakedAudit] = await sql`
    select count(*)::integer as count
    from private.audit_events
    where action like 'moderation.%'
      and metadata::text like any (array[${`%${explanation}%`}, ${`%${noteBody}%`}])
  `;
  const [moderationOutbox] = await sql`
    select count(*)::integer as count
    from private.outbox_events
    where event_type like 'moderation.%'
  `;
  if (leakedAudit.count !== 0 || moderationOutbox.count !== 0) {
    throw new Error(
      "Moderation evidence leaked into a generic audit or outbox record.",
    );
  }

  await sql`
    update private.moderation_staff_roles
    set is_active = false, deactivated_at = statement_timestamp()
    where profile_id = ${moderator.id}::uuid
  `;
  await expectRpcCode(
    moderator.client.rpc("list_moderation_cases", {
      p_expected_staff_profile_id: moderator.id,
      p_state: null,
      p_limit: 10,
      p_before_created_at: null,
      p_before_case_id: null,
    }),
    "42501",
    "deny the next queue read after staff revocation",
  );

  console.log(
    "Verified authenticated reporting, private staff review, and immediate role revocation locally.",
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

async function ensureProfile(user, displayName, displayNameAudience) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError && anchorError.code !== "23505") {
    throw safeFailure("create a moderation verifier profile", anchorError);
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: displayNameAudience,
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error) throw safeFailure("complete a moderation verifier profile", error);
}

async function expectRpcCode(operation, expectedCode, action) {
  const { error } = await operation;
  if (error?.code !== expectedCode) throw safeFailure(action, error ?? {});
}

function safeFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

// The existing hosted moderation verifier also exercises TW02 authenticated enforcement.
await verifyTemplateModeration();
