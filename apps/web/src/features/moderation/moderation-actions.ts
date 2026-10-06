"use server";

import { revalidatePath } from "next/cache";

import {
  removeModerationTemplate,
  addModerationNote,
  performModerationConsequence,
  transitionModerationCase,
} from "./moderation-operations";
import {
  parseConsequenceForm,
  type ConsequenceActionResult,
} from "./moderation-consequence-models";

export async function addModerationNoteAction(formData: FormData) {
  const caseId = formData.get("caseId");
  const body = formData.get("body");
  await addModerationNote({
    caseId: typeof caseId === "string" ? caseId : "",
    body: typeof body === "string" ? body : "",
  });
  revalidatePath(`/admin/cases/${caseId}`);
}

export async function transitionModerationCaseAction(formData: FormData) {
  const caseId = formData.get("caseId");
  const expectedStateVersion = Number(formData.get("expectedStateVersion"));
  const targetState = formData.get("targetState");
  await transitionModerationCase({
    caseId: typeof caseId === "string" ? caseId : "",
    expectedStateVersion,
    targetState: typeof targetState === "string" ? targetState : "",
  });
  revalidatePath("/admin");
  revalidatePath(`/admin/cases/${caseId}`);
}

export async function moderationConsequenceAction(
  _previous: ConsequenceActionResult,
  formData: FormData,
): Promise<ConsequenceActionResult> {
  const command = parseConsequenceForm(formData);
  if (!command) return { status: "error", kind: "invalid_input" };
  const result = await performModerationConsequence(command);
  // Re-render with fresh case/staff state after success or stale/conflict/role
  // failures. Only validated IDs reach a path; never reuse browser staff claims.
  revalidatePath("/admin");
  revalidatePath(`/admin/cases/${command.caseId}`);
  return result;
}

export async function removeModerationTemplateAction(
  input: import("./template-moderation-models").TemplateRemovalInput,
) {
  const result = await removeModerationTemplate(input);
  if (result.status === "removed" || result.status === "already_removed") {
    revalidatePath("/admin");
    revalidatePath(`/admin/cases/${input.caseId}`);
  }
  return result;
}
