import { isUuid } from "./moderation-models";

export type GroupReview = Readonly<{
  id: string;
  name: string;
  description: string;
  kind: "informal" | "organization";
  locality: string | null;
  volunteering: boolean;
  publication: "draft" | "published" | "archived";
  suppressed: boolean;
  publiclyAvailable: boolean;
  version: number;
  reportVersion: number;
  contentChanged: boolean;
  managerId: string | null;
  originalActorId: string;
  latestAction: Readonly<{
    id: string;
    actorId: string;
    reason: string;
    suppressed: boolean;
    createdAt: string;
    version: number;
  }> | null;
}>;
export type GroupSuppressionInput = Readonly<{
  caseId: string;
  groupId: string;
  requestId: string;
  version: number;
  suppressed: boolean;
  reason: string;
}>;
export type GroupSuppressionResult =
  | Readonly<{ status: "accepted"; version: number }>
  | Readonly<{ status: "invalid" | "denied" | "stale" | "error" }>;
function malformed(): never {
  throw new Error("The group moderation response was malformed.");
}
function record(v: unknown): Record<string, unknown> {
  if (!v || typeof v !== "object" || Array.isArray(v)) return malformed();
  return v as Record<string, unknown>;
}
function uuid(v: unknown): string {
  return isUuid(v) ? v : malformed();
}
function text(v: unknown, max: number): string {
  return typeof v === "string" && Array.from(v).length <= max ? v : malformed();
}
function bool(v: unknown): boolean {
  return typeof v === "boolean" ? v : malformed();
}
export function groupVersion(v: unknown): number {
  return typeof v === "number" && Number.isSafeInteger(v) && v > 0
    ? v
    : malformed();
}
function date(v: unknown): string {
  return typeof v === "string" && Number.isFinite(Date.parse(v))
    ? v
    : malformed();
}
export function parseGroupReview(value: unknown): GroupReview {
  const r = record(value);
  if (r.group_kind !== "informal" && r.group_kind !== "organization")
    return malformed();
  if (
    r.publication_state !== "draft" &&
    r.publication_state !== "published" &&
    r.publication_state !== "archived"
  )
    return malformed();
  const a =
    r.latest_suppression_action === null
      ? null
      : record(r.latest_suppression_action);
  return {
    id: uuid(r.group_id),
    name: text(r.name, 120),
    description: text(r.description, 4000),
    kind: r.group_kind,
    locality: r.locality === null ? null : text(r.locality, 120),
    volunteering: bool(r.volunteering_focus),
    publication: r.publication_state,
    suppressed: bool(r.directory_suppressed),
    publiclyAvailable: bool(r.publicly_available),
    version: groupVersion(r.version),
    reportVersion: groupVersion(r.report_version),
    contentChanged: bool(r.content_changed),
    managerId:
      r.manager_profile_id === null ? null : uuid(r.manager_profile_id),
    originalActorId: uuid(r.original_actor_id),
    latestAction: a
      ? {
          id: uuid(a.action_id),
          actorId: uuid(a.actor_id),
          reason: text(a.reason, 4000),
          suppressed: bool(a.directory_suppressed),
          createdAt: date(a.created_at),
          version: groupVersion(a.group_version),
        }
      : null,
  };
}
