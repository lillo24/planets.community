import { isUuid } from "./moderation-models";

export type TemplateBlueprint = Readonly<{
  sourceNeedId: string;
  title: string;
  details: string | null;
}>;
export type TemplateRemovalReceipt = Readonly<{
  requestId: string;
  outcome: "removed" | "already_removed";
  effectiveActionId: string;
  effectiveAt: string;
  effectiveActorProfileId: string;
}>;
export type TemplateReview = Readonly<{
  templateId: string;
  sourceProposalId: string;
  originalCreatorProfileId: string;
  reportContentVersion: string;
  currentContentVersion: string;
  contentChanged: boolean;
  publiclyAvailable: boolean;
  removedAt: string | null;
  title: string;
  summary: string | null;
  description: string | null;
  skills: ReadonlyArray<{
    id: string;
    label: string;
    categoryLabel: string;
    importance: "required" | "useful";
  }>;
  capacity: number | null;
  durationSeconds: number;
  coverObjectPath: string | null;
  resourceBlueprintCount: number;
  removalAction: Readonly<{
    actionId: string;
    caseId: string;
    actorProfileId: string;
    actorDisplayName: string;
    effectiveAt: string;
    reviewedContentVersion: string;
    reason: string;
  }> | null;
}>;
export type TemplateRemovalInput = Readonly<{
  caseId: string;
  templateId: string;
  requestId: string;
  reviewedContentVersion: string;
  reason: string;
}>;
export type TemplateRemovalResult =
  | Readonly<{
      status: "removed" | "already_removed";
      receipt: TemplateRemovalReceipt;
    }>
  | Readonly<{ status: "invalid" | "denied" | "stale" | "error" }>;

export function isTemplateVersion(value: unknown): value is string {
  return typeof value === "string" && /^tw01:[0-9a-f]{64}$/u.test(value);
}

export function parseTemplateReview(data: unknown): TemplateReview {
  const r = single(data);
  const c = record(r.content);
  const a = r.removal_action === null ? null : record(r.removal_action);
  if (!Array.isArray(c.skills)) throw malformed();
  return {
    templateId: uuid(r.template_id),
    sourceProposalId: uuid(r.source_proposal_id),
    originalCreatorProfileId: uuid(r.original_creator_profile_id),
    reportContentVersion: version(r.report_content_version),
    currentContentVersion: version(r.current_content_version),
    contentChanged: boolean(r.content_changed),
    publiclyAvailable: boolean(r.publicly_available),
    removedAt: nullable(r.removed_at, timestamp),
    title: text(c.title, 100),
    summary: nullable(c.summary, (v) => text(v, 240)),
    description: nullable(c.description, (v) => text(v, 5000)),
    skills: c.skills.map((value) => {
      const skill = record(value);
      if (skill.importance !== "required" && skill.importance !== "useful")
        throw malformed();
      return {
        id: uuid(skill.id),
        label: text(skill.label, 200),
        categoryLabel: text(skill.category_label, 200),
        importance: skill.importance,
      };
    }),
    capacity: nullable(c.registration_capacity_recommendation, integer),
    durationSeconds: integer(c.duration_seconds),
    coverObjectPath: nullable(c.cover_object_path, (v) => text(v, 500)),
    resourceBlueprintCount: integer(r.resource_blueprint_count),
    removalAction: a
      ? {
          actionId: uuid(a.action_id),
          caseId: uuid(a.case_id),
          actorProfileId: uuid(a.actor_profile_id),
          actorDisplayName: text(a.actor_display_name, 120),
          effectiveAt: timestamp(a.effective_at),
          reviewedContentVersion: version(a.reviewed_content_version),
          reason: text(a.reason, 4000),
        }
      : null,
  };
}

export function parseTemplateBlueprints(data: unknown): TemplateBlueprint[] {
  if (!Array.isArray(data) || data.length > 50) throw malformed();
  return data.map((value) => {
    const r = record(value);
    return {
      sourceNeedId: uuid(r.source_need_id),
      title: text(r.title, 160),
      details: nullable(r.details, (v) => text(v, 1000)),
    };
  });
}

export function parseTemplateRemovalReceipt(
  data: unknown,
): TemplateRemovalReceipt {
  const r = single(data);
  if (r.outcome !== "removed" && r.outcome !== "already_removed")
    throw malformed();
  return {
    requestId: uuid(r.request_id),
    outcome: r.outcome,
    effectiveActionId: uuid(r.effective_action_id),
    effectiveAt: timestamp(r.effective_at),
    effectiveActorProfileId: uuid(r.effective_actor_profile_id),
  };
}

function malformed() {
  return new Error("The template moderation response was malformed.");
}
function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw malformed();
  return value as Record<string, unknown>;
}
function single(value: unknown) {
  if (!Array.isArray(value) || value.length !== 1) throw malformed();
  return record(value[0]);
}
function uuid(value: unknown) {
  if (!isUuid(value)) throw malformed();
  return value;
}
function version(value: unknown) {
  if (!isTemplateVersion(value)) throw malformed();
  return value;
}
function boolean(value: unknown) {
  if (typeof value !== "boolean") throw malformed();
  return value;
}
function integer(value: unknown) {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0)
    throw malformed();
  return value;
}
function text(value: unknown, max: number) {
  if (typeof value !== "string" || !value.length || value.length > max)
    throw malformed();
  return value;
}
function timestamp(value: unknown) {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value)))
    throw malformed();
  return value;
}
function nullable<T>(value: unknown, parse: (v: unknown) => T): T | null {
  return value === null ? null : parse(value);
}
