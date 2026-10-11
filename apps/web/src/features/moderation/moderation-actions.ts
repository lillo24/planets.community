"use server";

import { revalidatePath } from "next/cache";

import {
  setGroupSuppression,
  removeModerationTemplate,
  addModerationNote,
  transitionModerationCase,
} from "./moderation-operations";

export async function setGroupSuppressionAction(
  input: import("./group-moderation-models").GroupSuppressionInput,
) {
  const result = await setGroupSuppression(input);
  if (result.status === "accepted" || result.status === "stale")
    revalidatePath(`/admin/cases/${input.caseId}`);
  return result;
}

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
