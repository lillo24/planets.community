import {
  isModerationState,
  isUuid,
  parseModerationCase,
} from "./moderation-models";
import {
  parseConsequenceCommand,
  parseConsequenceHistory,
  type ConsequenceActionResult,
  type ConsequenceFailureKind,
} from "./moderation-consequence-models";
import {
  isTemplateVersion,
  parseTemplateRemovalReceipt,
} from "./template-moderation-models";
import {
  requireModerationStaff,
  type ModerationServerClientFactory,
} from "./moderation-server";

export async function addModerationNote(
  input: Readonly<{ caseId: string; body: string }>,
  createClient?: ModerationServerClientFactory,
): Promise<void> {
  const body = input.body.trim();
  if (!isUuid(input.caseId) || body.length < 1 || body.length > 4000) {
    throw new Error("The moderation note is invalid.");
  }
  const access = await requireModerationStaff(createClient);
  if (!access) throw new Error("Moderation staff access is required.");
  const result = await access.client.rpc("add_moderation_case_note", {
    p_expected_staff_profile_id: access.profileId,
    p_case_id: input.caseId,
    p_body: body,
  });
  if (result.error) throw new Error("The moderation note could not be added.");
}

export async function transitionModerationCase(
  input: Readonly<{
    caseId: string;
    expectedStateVersion: number;
    targetState: string;
  }>,
  createClient?: ModerationServerClientFactory,
): Promise<void> {
  if (
    !isUuid(input.caseId) ||
    !Number.isSafeInteger(input.expectedStateVersion) ||
    input.expectedStateVersion < 0 ||
    !isModerationState(input.targetState) ||
    input.targetState === "received"
  ) {
    throw new Error("The moderation transition is invalid.");
  }
  const access = await requireModerationStaff(createClient);
  if (!access) throw new Error("Moderation staff access is required.");
  const result = await access.client.rpc("transition_moderation_case", {
    p_expected_staff_profile_id: access.profileId,
    p_case_id: input.caseId,
    p_expected_state_version: input.expectedStateVersion,
    p_target_state: input.targetState,
  });
  if (result.error)
    throw new Error("The moderation case could not be updated.");
}

// This request boundary never returns SQL messages, notes, reasons or identity
// claims. Database RPCs remain the final authority, including mid-submit changes.
export async function performModerationConsequence(
  input: unknown,
  createClient?: ModerationServerClientFactory,
): Promise<ConsequenceActionResult> {
  const command = parseConsequenceCommand(input);
  if (!command) return failure("invalid_input");
  try {
    const access = await requireModerationStaff(createClient);
    if (!access) return failure("unauthorized");
    if (command.type === "account_suspension" && access.role !== "admin")
      return failure("unauthorized");
    const caseResult = await access.client.rpc("get_moderation_case_detail", {
      p_expected_staff_profile_id: access.profileId,
      p_case_id: command.caseId,
    });
    if (caseResult.error)
      return failure(mapConsequenceFailure(caseResult.error));
    const detail = parseModerationCase(caseResult.data);
    if (!detail || detail.caseId !== command.caseId) return failure("stale");
    if (command.mode === "apply") {
      if (detail.state === "received") return failure("review_required");
      if (
        command.type === "content_hide" &&
        detail.targetKind !== "project" &&
        detail.targetKind !== "resource_listing"
      )
        return failure("incompatible_target");
      if (
        command.type === "account_suspension" &&
        detail.subjectProfileId === access.profileId
      )
        return failure("self_suspension");
    } else {
      // Bind revoke to the rendered case and authoritative type. A forged ID or
      // type must not revoke another case or route suspension via the generic RPC.
      const history = await access.client.rpc(
        "list_moderation_case_consequence_history",
        {
          p_expected_staff_profile_id: access.profileId,
          p_case_id: command.caseId,
        },
      );
      if (history.error) return failure(mapConsequenceFailure(history.error));
      const episode = parseConsequenceHistory(history.data).find(
        (item) => item.consequenceId === command.consequenceId,
      );
      if (!episode) return failure("stale");
      if (episode.type !== command.type) return failure("incompatible_target");
      if (episode.revokedAt !== null) return failure("already_revoked");
    }
    const params: Record<string, unknown> = {
      p_expected_staff_profile_id: access.profileId,
      p_user_reason: command.userReason,
      p_internal_note: command.internalNote,
    };
    let rpc: string;
    if (command.mode === "apply") {
      params.p_case_id = command.caseId;
      rpc =
        command.type === "account_suspension"
          ? "apply_account_suspension"
          : "apply_moderation_consequence";
      if (command.type !== "account_suspension")
        params.p_consequence_type = command.type;
    } else {
      params.p_consequence_id = command.consequenceId;
      rpc =
        command.type === "account_suspension"
          ? "revoke_account_suspension"
          : "revoke_moderation_consequence";
    }
    const result = await access.client.rpc(rpc, params);
    if (result.error) return failure(mapConsequenceFailure(result.error));
    if (!isUuid(result.data)) return failure("unavailable");
    return {
      status: "success",
      kind: command.mode === "apply" ? "applied" : "revoked",
    };
  } catch {
    // Network/malformed responses at the request boundary are explicit failures;
    // do not log private moderation text or report an unconfirmed command as OK.
    return failure("unavailable");
  }
}

function failure(kind: ConsequenceFailureKind): ConsequenceActionResult {
  return { status: "error", kind };
}
function mapConsequenceFailure(error: unknown): ConsequenceFailureKind {
  if (!error || typeof error !== "object") return "unavailable";
  const { code, message } = error as { code?: unknown; message?: unknown };
  if (code === "42501" || code === "PT403")
    return message === "An admin cannot suspend their own account."
      ? "self_suspension"
      : "unauthorized";
  if (code === "P0002") return "stale";
  if (code === "23505") return "duplicate";
  if (code === "22023")
    return message ===
      "Content hide requires a Project or Resource listing case."
      ? "incompatible_target"
      : "invalid_input";
  if (code === "PT409") {
    if (message === "The case must be reviewed before applying a consequence.")
      return "review_required";
    if (
      message === "The consequence is no longer active." ||
      message === "The account suspension is no longer active."
    )
      return "already_revoked";
    if (
      message === "An active consequence already exists for this target." ||
      message === "An active account suspension already exists."
    )
      return "duplicate";
    return "stale";
  }
  return "unavailable";
}
// This is an explicit enforcement action; ordinary review transitions stay separate.
export async function removeModerationTemplate(
  input: import("./template-moderation-models").TemplateRemovalInput,
  createClient?: ModerationServerClientFactory,
): Promise<import("./template-moderation-models").TemplateRemovalResult> {
  const reason = input.reason.trim();
  if (
    !isUuid(input.caseId) ||
    !isUuid(input.templateId) ||
    !isUuid(input.requestId) ||
    !isTemplateVersion(input.reviewedContentVersion) ||
    reason.length < 10 ||
    reason.length > 4000
  )
    return { status: "invalid" };
  const access = await requireModerationStaff(createClient);
  if (!access) return { status: "denied" };
  try {
    const result = await access.client.rpc("remove_moderation_case_template", {
      p_expected_staff_profile_id: access.profileId,
      p_case_id: input.caseId,
      p_template_id: input.templateId,
      p_client_request_id: input.requestId,
      p_reviewed_content_version: input.reviewedContentVersion,
      p_reason: reason,
    });
    if (result.error) {
      const code =
        typeof result.error === "object" && "code" in result.error
          ? result.error.code
          : null;
      if (code === "42501" || code === "PT403") return { status: "denied" };
      if (code === "PT409") return { status: "stale" };
      if (code === "22023") return { status: "invalid" };
      return { status: "error" };
    }
    const receipt = parseTemplateRemovalReceipt(result.data);
    return { status: receipt.outcome, receipt };
  } catch {
    // A transport/malformed-result failure is ambiguous: UI retains the same
    // request and frozen inputs for receipt recovery, never reports success.
    return { status: "error" };
  }
}
