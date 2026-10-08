import {
  isTemplateVersion,
  parseTemplateRemovalReceipt,
} from "./template-moderation-models";
import { isModerationState, isUuid } from "./moderation-models";
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
      if (code === "42501") return { status: "denied" };
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
