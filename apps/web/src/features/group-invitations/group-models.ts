export const groupTokenPattern = /^[A-Za-z0-9_-]{43}$/u;
export const groupIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
export type GroupRole = "creator" | "co_creator" | "co_organizer";
export type GroupAuth = Readonly<{
  account: string | null;
  phase: "signedOut" | "missingProfile" | "incompleteProfile" | "ready";
}>;
export type GroupPreview =
  | Readonly<{ available: false }>
  | Readonly<{
      available: true;
      id: string;
      name: string;
      kind: "informal" | "organization";
      role?: Exclude<GroupRole, "creator">;
      expires?: string;
    }>;
export type GroupReceipt = Readonly<{
  group: string;
  relationship: string | null;
  kind: string;
  outcome: string;
  current: string | null;
  replayed: boolean;
}>;
export type GroupCurrent = Readonly<{
  role: GroupRole | null;
  delegate: string | null;
  membership: string | null;
}>;
export type PublicGroupContent = Readonly<{
  id: string;
  name: string;
  description: string;
  kind: "informal" | "organization";
  locality: string | null;
  volunteering: boolean;
}>;
export type GroupFailure =
  | "unavailable"
  | "prerequisite"
  | "invalid"
  | "stale"
  | "setup"
  | "network"
  | "malformed";
export class GroupError extends Error {
  constructor(readonly kind: GroupFailure) {
    super("Group operation failed.");
  }
}
export function groupFailure(error: unknown): GroupFailure {
  if (error instanceof GroupError) return error.kind;
  const code =
    typeof error === "object" && error !== null && "code" in error
      ? error.code
      : null;
  switch (code) {
    case "42501":
      return "unavailable";
    case "55000":
      return "prerequisite";
    case "22023":
      return "invalid";
    case "PT409":
      return "stale";
    case "PGRST202":
    case "42883":
      return "setup";
    default:
      return "network";
  }
}
export function groupFailureMessage(failure: GroupFailure): string {
  switch (failure) {
    case "unavailable":
      return "This group interaction is unavailable.";
    case "prerequisite":
      return "Complete your profile, then try again.";
    case "invalid":
      return "Please review the invitation and try again.";
    case "stale":
      return "This invitation or action has changed. Check the latest details and try again.";
    case "setup":
      return "Group joining is not configured on this service yet. Please try again later.";
    case "malformed":
    case "network":
      return "We couldn't complete this check. Please try again.";
  }
}
export function oneGroupRow(
  value: unknown,
  optional = false,
): Record<string, unknown> | null {
  if (
    !Array.isArray(value) ||
    value.length > 1 ||
    (!optional && value.length !== 1)
  )
    throw new GroupError("malformed");
  if (!value.length) return null;
  const row: unknown = value[0];
  if (!row || typeof row !== "object" || Array.isArray(row))
    throw new GroupError("malformed");
  return row as Record<string, unknown>;
}
export function groupId(value: unknown): string {
  if (typeof value !== "string" || !groupIdPattern.test(value))
    throw new GroupError("malformed");
  return value;
}
function nullable<T>(
  row: Record<string, unknown>,
  key: string,
  parse: (v: unknown) => T,
): T | null {
  if (!(key in row)) throw new GroupError("malformed");
  return row[key] === null ? null : parse(row[key]);
}
export function groupText(value: unknown, max: number): string {
  if (typeof value !== "string" || [...value].length > max)
    throw new GroupError("malformed");
  return value;
}
export function groupRole(value: unknown): GroupRole {
  if (value !== "creator" && value !== "co_creator" && value !== "co_organizer")
    throw new GroupError("malformed");
  return value;
}
function kind(value: unknown): "informal" | "organization" {
  if (value !== "informal" && value !== "organization")
    throw new GroupError("malformed");
  return value;
}
function timestamp(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/(Z|[+-]\d\d:\d\d)$/u.test(value) ||
    !Number.isFinite(Date.parse(value))
  )
    throw new GroupError("malformed");
  return value;
}
export function parseGroupPreview(
  value: unknown,
  authority: boolean,
): GroupPreview {
  const r = oneGroupRow(value)!;
  if (typeof r.available !== "boolean") throw new GroupError("malformed");
  const id = nullable(r, "group_id", groupId),
    name = nullable(r, "group_name", (v) => groupText(v, 120)),
    type = nullable(r, "group_kind", kind);
  const role = authority ? nullable(r, "offered_role", groupRole) : null,
    expires = authority ? nullable(r, "expires_at", timestamp) : null;
  if (!r.available) {
    if ([id, name, type, role, expires].some((v) => v !== null))
      throw new GroupError("malformed");
    return { available: false };
  }
  if (
    !id ||
    name === null ||
    !type ||
    (authority && (!role || role === "creator" || !expires))
  )
    throw new GroupError("malformed");
  return {
    available: true,
    id,
    name,
    kind: type,
    ...(role && role !== "creator" ? { role } : {}),
    ...(expires ? { expires } : {}),
  };
}
export function consentVersion(preview: GroupPreview): string | null {
  return preview.available
    ? `${preview.id}/${preview.role ?? ""}/${preview.expires ?? ""}`
    : null;
}
export function parseGroupReceipt(value: unknown): GroupReceipt {
  const r = oneGroupRow(value)!;
  const current = nullable(r, "current_status", (v) => groupText(v, 40));
  if (
    (current !== null &&
      ![
        "pending",
        "accepted",
        "rejected",
        "withdrawn",
        "current",
        "left",
        "removed",
        "co_creator",
        "co_organizer",
        "revoked",
        "declined",
        "expired",
      ].includes(current)) ||
    typeof r.replayed !== "boolean"
  )
    throw new GroupError("malformed");
  const relationship = nullable(r, "relationship_id", groupId),
    relationKind = groupText(r.relationship_kind, 40),
    outcome = groupText(r.outcome, 40);
  if (
    ![
      "requested",
      "withdrawn",
      "joined",
      "rejected",
      "left",
      "removed",
      "current",
      "revoked",
      "already_joined",
      "creator",
      "offered",
      "accepted",
      "declined",
      "co_creator",
      "co_organizer",
    ].includes(outcome) ||
    ![
      "creator",
      "request",
      "membership",
      "delegate",
      "authority_invitation",
      "participant_invitation",
    ].includes(relationKind)
  )
    throw new GroupError("malformed");
  nullable(r, "expires_at", timestamp);
  return {
    group: groupId(r.group_id),
    relationship,
    kind: relationKind,
    outcome,
    current,
    replayed: r.replayed,
  };
}
export function parseGroupCurrent(value: unknown): GroupCurrent {
  const r = oneGroupRow(value)!;
  const role = nullable(r, "authority_role", groupRole),
    delegate = nullable(r, "delegate_id", groupId),
    membership = nullable(r, "current_membership_id", groupId);
  const status = nullable(r, "membership_status", (v) => groupText(v, 40));
  if (
    (membership === null) !== (status === null) ||
    (status !== null && status !== "current") ||
    (role === "creator" && delegate !== null) ||
    (role !== null && role !== "creator" && delegate === null)
  )
    throw new GroupError("malformed");
  return { role, delegate, membership };
}
export function parsePublicGroup(value: unknown): PublicGroupContent | null {
  const r = oneGroupRow(value, true);
  if (!r) return null;
  if (typeof r.volunteering_focus !== "boolean")
    throw new GroupError("malformed");
  return {
    id: groupId(r.group_id),
    name: groupText(r.name, 120),
    description: groupText(r.description, 4000),
    kind: kind(r.group_kind),
    locality: nullable(r, "locality", (v) => groupText(v, 120)),
    volunteering: r.volunteering_focus,
  };
}
