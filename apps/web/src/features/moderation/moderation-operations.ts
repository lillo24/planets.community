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
