import {
  isUuid,
  type ModerationCaseDetail,
  type ModerationStaffRole,
} from "./moderation-models";

export const consequenceTypes = [
  "safety_notice",
  "interaction_restriction",
  "content_hide",
  "account_suspension",
] as const;
export type ConsequenceType = (typeof consequenceTypes)[number];
export type ConsequenceAction = Readonly<{
  actionId: string;
  kind: "applied" | "revoked";
  userReason: string;
  noteId: string;
  actorProfileId: string;
  createdAt: string;
}>;
export type ConsequenceEpisode = Readonly<{
  consequenceId: string;
  type: ConsequenceType;
  affectedProfileId: string;
  projectId: string | null;
  resourceListingId: string | null;
  appliedAt: string;
  revokedAt: string | null;
  actions: ConsequenceAction[];
}>;
export type ConsequenceChoice = Readonly<{
  mode: "apply" | "revoke";
  type: ConsequenceType;
  consequenceId?: string;
  label: string;
  effect: string;
}>;
export const consequenceFailureKinds = [
  "unauthorized",
  "review_required",
  "incompatible_target",
  "duplicate",
  "already_revoked",
  "self_suspension",
  "stale",
  "invalid_input",
  "unavailable",
] as const;
export type ConsequenceFailureKind = (typeof consequenceFailureKinds)[number];
export type ConsequenceActionResult =
  | Readonly<{ status: "idle" }>
  | Readonly<{ status: "success"; kind: "applied" | "revoked" }>
  | Readonly<{ status: "error"; kind: ConsequenceFailureKind }>;
export type ConsequenceCommand = Readonly<{
  mode: "apply" | "revoke";
  caseId: string;
  type: ConsequenceType;
  consequenceId?: string;
  userReason: string;
  internalNote: string;
}>;

export function isConsequenceType(value: unknown): value is ConsequenceType {
  return consequenceTypes.some((type) => type === value);
}

export function parseConsequenceHistory(data: unknown): ConsequenceEpisode[] {
  if (!Array.isArray(data)) throw malformed();
  const episodes = new Map<string, ConsequenceEpisode>();
  const actionIds = new Set<string>();
  for (const value of data) {
    const row = record(value);
    if (!isConsequenceType(row.consequence_type)) throw malformed();
    const snapshot: ConsequenceEpisode = {
      consequenceId: uuid(row.consequence_id),
      type: row.consequence_type,
      affectedProfileId: uuid(row.affected_profile_id),
      projectId: nullableUuid(row.project_id),
      resourceListingId: nullableUuid(row.resource_listing_id),
      appliedAt: timestamp(row.applied_at),
      revokedAt: row.revoked_at === null ? null : timestamp(row.revoked_at),
      actions: [],
    };
    if (
      (snapshot.type === "content_hide"
        ? Number(snapshot.projectId !== null) +
            Number(snapshot.resourceListingId !== null) !==
          1
        : snapshot.projectId !== null || snapshot.resourceListingId !== null) ||
      (snapshot.revokedAt !== null &&
        Date.parse(snapshot.revokedAt) < Date.parse(snapshot.appliedAt))
    )
      throw malformed();
    let episode = episodes.get(snapshot.consequenceId);
    if (episode) {
      const { actions: ignoredActions, ...existing } = episode;
      const { actions: ignoredSnapshotActions, ...incoming } = snapshot;
      void ignoredActions;
      void ignoredSnapshotActions;
      if (JSON.stringify(existing) !== JSON.stringify(incoming))
        throw malformed();
    } else {
      episode = snapshot;
      episodes.set(snapshot.consequenceId, episode);
    }
    if (row.action_kind !== "applied" && row.action_kind !== "revoked")
      throw malformed();
    const action: ConsequenceAction = {
      actionId: uuid(row.action_id),
      kind: row.action_kind,
      userReason: boundedText(row.user_reason, 2000),
      noteId: uuid(row.note_id),
      actorProfileId: uuid(row.actor_profile_id),
      createdAt: timestamp(row.action_at),
    };
    if (
      actionIds.has(action.actionId) ||
      episode.actions.some((other) => other.kind === action.kind)
    )
      throw malformed();
    actionIds.add(action.actionId);
    episode.actions.push(action);
  }
  for (const episode of episodes.values()) {
    if (
      !episode.actions.some((action) => action.kind === "applied") ||
      episode.actions.some((action) => action.kind === "revoked") !==
        (episode.revokedAt !== null)
    )
      throw malformed();
    // Episode order, then apply/revoke order; wall-clock rollback must not invert
    // the immutable command sequence or falsely imply an action never happened.
    episode.actions.sort((a, b) =>
      a.kind === b.kind ? 0 : a.kind === "applied" ? -1 : 1,
    );
  }
  return [...episodes.values()].sort(
    (a, b) =>
      Date.parse(a.appliedAt) - Date.parse(b.appliedAt) ||
      a.consequenceId.localeCompare(b.consequenceId),
  );
}

export const consequenceLabels: Record<ConsequenceType, string> = {
  safety_notice: "Safety notice",
  interaction_restriction: "Interaction restriction",
  content_hide: "Content hide",
  account_suspension: "Account suspension",
};

export function consequenceChoices(
  detail: ModerationCaseDetail,
  episodes: readonly ConsequenceEpisode[],
  role: ModerationStaffRole,
  staffProfileId: string,
): ConsequenceChoice[] {
  const contentNoun =
    detail.targetKind === "project" ? "Project" : "Resource listing";
  const choices: ConsequenceChoice[] = [];
  for (const type of consequenceTypes) {
    if (type === "account_suspension" && role !== "admin") continue;
    const active = episodes.find(
      (episode) => episode.type === type && episode.revokedAt === null,
    );
    if (active) {
      choices.push({
        mode: "revoke",
        type,
        consequenceId: active.consequenceId,
        label: revokeLabels[type],
        effect: revokeEffects[type],
      });
    } else if (
      detail.state !== "received" &&
      isUuid(detail.subjectProfileId) &&
      (type !== "content_hide" ||
        detail.targetKind === "project" ||
        detail.targetKind === "resource_listing") &&
      (type !== "account_suspension" ||
        detail.subjectProfileId !== staffProfileId)
    ) {
      choices.push({
        mode: "apply",
        type,
        label:
          type === "content_hide"
            ? `Hide ${contentNoun.toLowerCase()}`
            : applyLabels[type],
        effect:
          type === "content_hide"
            ? `Removes the reported ${contentNoun} from public discovery and detail. Stops new requests and pending acceptance while hidden; existing pending requests remain pending. Accepted relationships and history remain; the owner lifecycle is unchanged.`
            : applyEffects[type],
      });
    }
  }
  return choices;
}

const applyLabels: Record<ConsequenceType, string> = {
  safety_notice: "Apply safety notice",
  interaction_restriction: "Restrict new interactions",
  content_hide: "Hide content",
  account_suspension: "Suspend account",
};
const revokeLabels: Record<ConsequenceType, string> = {
  safety_notice: "Remove safety notice",
  interaction_restriction: "Remove interaction restriction",
  content_hide: "Unhide content",
  account_suspension: "Unsuspend account",
};
const applyEffects: Record<ConsequenceType, string> = {
  safety_notice:
    "Records a moderator-confirmed safety notice. It does not itself restrict the account or create a public badge. Contextual warning UX is separate.",
  interaction_restriction:
    "Prevents this user from starting new Project join and Scambio-Dona Resource requests, and withdraws their current pending outbound requests. Existing memberships, chats and accepted Resource coordination remain.",
  content_hide:
    "Removes the reported content from public discovery without changing its owner lifecycle.",
  account_suspension:
    "Admin only. Disables ordinary signed-in/private PLANETS access and withdraws pending outbound Project/Resource requests. Existing memberships, roles, content, messages and agreements remain stored. Public content is not automatically hidden. The user sees the supplied reason on the suspension screen.",
};
const revokeEffects: Record<ConsequenceType, string> = {
  safety_notice:
    "Removes this safety notice only. Other consequences and blocks remain unchanged.",
  interaction_restriction:
    "Future new interactions may become possible, subject to other rules. Previously withdrawn requests are not restored; unrelated consequences and blocks remain.",
  content_hide:
    "Removes this moderation visibility barrier only. Cancelled, closed or ended owner lifecycles are not reversed; other consequences and blocks remain.",
  account_suspension:
    "Signed-in access may resume subject to ordinary authorization. Other restrictions, blocks and content hides remain. Withdrawn requests, revoked roles and ended relationships are not recreated.",
};

export function parseConsequenceCommand(
  input: unknown,
): ConsequenceCommand | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const row = input as Record<string, unknown>;
  const keys = [
    "mode",
    "caseId",
    "type",
    "userReason",
    "internalNote",
    ...(row.mode === "revoke" ? ["consequenceId"] : []),
  ];
  if (
    Object.keys(row).length !== keys.length ||
    Object.keys(row).some((key) => !keys.includes(key)) ||
    (row.mode !== "apply" && row.mode !== "revoke") ||
    !isUuid(row.caseId) ||
    !isConsequenceType(row.type) ||
    typeof row.userReason !== "string" ||
    typeof row.internalNote !== "string" ||
    (row.mode === "revoke" && !isUuid(row.consequenceId))
  )
    return null;
  const userReason = row.userReason.trim();
  const internalNote = row.internalNote.trim();
  if (
    !userReason ||
    !internalNote ||
    Array.from(userReason).length > 2000 ||
    Array.from(internalNote).length > 4000
  )
    return null;
  return {
    mode: row.mode,
    caseId: row.caseId,
    type: row.type,
    userReason,
    internalNote,
    ...(row.mode === "revoke"
      ? { consequenceId: row.consequenceId as string }
      : {}),
  };
}

export function parseConsequenceForm(
  form: FormData,
): ConsequenceCommand | null {
  const input: Record<string, unknown> = {};
  for (const [key, value] of form.entries()) {
    // Next.js adds its own action transport metadata to progressively enhanced forms.
    if (key.startsWith("$ACTION_")) continue;
    if (key in input || typeof value !== "string") return null;
    input[key] = value;
  }
  return parseConsequenceCommand(input);
}

export function parseConsequenceActionResult(
  input: unknown,
): ConsequenceActionResult {
  if (input && typeof input === "object" && !Array.isArray(input)) {
    const row = input as Record<string, unknown>;
    // Idle is only a local initial state, never a confirmed server response.
    if (Object.keys(row).length === 2) {
      if (
        row.status === "success" &&
        (row.kind === "applied" || row.kind === "revoked")
      )
        return { status: "success", kind: row.kind };
      if (
        row.status === "error" &&
        consequenceFailureKinds.some((kind) => kind === row.kind)
      )
        return { status: "error", kind: row.kind as ConsequenceFailureKind };
    }
  }
  return { status: "error", kind: "unavailable" };
}

export const consequenceErrors: Record<ConsequenceFailureKind, string> = {
  unauthorized:
    "Current moderation authority is unavailable or changed. Reload the case; no consequence was changed.",
  review_required:
    "Start review before applying a consequence. Reload the current case state.",
  incompatible_target:
    "This consequence is not valid for the reported target. Reload the case.",
  duplicate:
    "An active consequence already exists for this target, possibly from another case. Reload this case; its history is not the subject's global history.",
  already_revoked:
    "This consequence is already revoked. Reload the case before acting again.",
  self_suspension: "Another admin is required to suspend this account.",
  stale: "The case or consequence is no longer available. Reload the case.",
  invalid_input:
    "Enter a plain-text reason of 1–2,000 characters and a separate private note of 1–4,000 characters. Check the selected action.",
  unavailable:
    "The consequence operation could not be confirmed. Reload to check current state before retrying.",
};

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw malformed();
  return value as Record<string, unknown>;
}
function uuid(value: unknown): string {
  if (!isUuid(value)) throw malformed();
  return value;
}
function nullableUuid(value: unknown): string | null {
  return value === null ? null : uuid(value);
}
function timestamp(value: unknown): string {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value)))
    throw malformed();
  return value;
}
// History is immutable stored plain text: preserve whitespace rather than
// requiring every caller to have used this Web form's normalization.
function boundedText(value: unknown, max: number): string {
  if (typeof value !== "string" || !value || Array.from(value).length > max)
    throw malformed();
  return value;
}
function malformed(): Error {
  return new Error("The moderation consequence response was malformed.");
}
