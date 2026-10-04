export type ProjectKind = "one_time" | "recurring";
export type ProjectContext = Readonly<{ id: string; kind: ProjectKind }>;
export type ParticipantPreview =
  | Readonly<{ available: false }>
  | Readonly<{ available: true; project: ProjectContext; title: string }>;
export type MembershipStatus = "current" | "left" | "removed";
export type AdmissionReceipt = Readonly<{
  projectId: string;
  membershipId: string | null;
  outcome: "joined" | "already_joined" | "creator";
  membershipStatus: MembershipStatus | null;
  replayed: boolean;
}>;
export type ParticipantAuth = Readonly<{
  account: string | null;
  phase: "signedOut" | "missingProfile" | "incompleteProfile" | "ready";
}>;
export type CurrentParticipation = Readonly<{
  current: boolean;
  creator: boolean;
}>;
export type ParticipantFailure =
  | "unavailable"
  | "full"
  | "identity"
  | "profile"
  | "input"
  | "network"
  | "malformed";

export class ParticipantError extends Error {
  constructor(readonly failure: ParticipantFailure) {
    super(`Participant invitation operation: ${failure}.`);
    this.name = "ParticipantError";
  }
}
export const participantTokenPattern = /^[A-Za-z0-9_-]{43}$/u;
export const projectIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

function malformed(): never {
  throw new ParticipantError("malformed");
}
export function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : malformed();
}
function one(value: unknown): Record<string, unknown> {
  return Array.isArray(value) && value.length === 1
    ? record(value[0])
    : malformed();
}
export function projectId(value: unknown): string {
  return typeof value === "string" && projectIdPattern.test(value)
    ? value
    : malformed();
}
export function projectKind(value: unknown): ProjectKind {
  return value === "one_time" || value === "recurring" ? value : malformed();
}
function membershipStatus(value: unknown): MembershipStatus {
  return value === "current" || value === "left" || value === "removed"
    ? value
    : malformed();
}
export function parseParticipantPreview(value: unknown): ParticipantPreview {
  const row = one(value);
  if (
    row.available === false &&
    row.project_id === null &&
    row.project_kind === null &&
    row.project_title === null
  ) {
    return { available: false };
  }
  if (
    row.available !== true ||
    typeof row.project_title !== "string" ||
    !row.project_title.trim()
  )
    return malformed();
  return {
    available: true,
    project: {
      id: projectId(row.project_id),
      kind: projectKind(row.project_kind),
    },
    title: row.project_title,
  };
}
export function parseAdmissionReceipt(value: unknown): AdmissionReceipt {
  const row = one(value);
  const id = projectId(row.project_id);
  if (typeof row.replayed !== "boolean") return malformed();
  if (row.outcome === "creator") {
    if (row.membership_id !== null || row.membership_status !== null)
      return malformed();
    return {
      projectId: id,
      membershipId: null,
      outcome: "creator",
      membershipStatus: null,
      replayed: row.replayed,
    };
  }
  if (row.outcome !== "joined" && row.outcome !== "already_joined")
    return malformed();
  return {
    projectId: id,
    membershipId: projectId(row.membership_id),
    outcome: row.outcome,
    membershipStatus: membershipStatus(row.membership_status),
    replayed: row.replayed,
  };
}
export function parseCurrentParticipation(
  memberships: unknown,
  role: unknown,
  project: ProjectContext,
): CurrentParticipation {
  if (
    !Array.isArray(memberships) ||
    typeof role !== "string" ||
    !["creator", "co_creator", "co_organizer", "none"].includes(role)
  )
    return malformed();
  const episodes = memberships.map((value) => {
    const row = record(value);
    const result = {
      id: projectId(row.membership_id),
      projectId: projectId(row.project_id),
      kind: projectKind(row.project_kind),
      status: membershipStatus(row.membership_status),
    };
    if (
      typeof row.joined_at !== "string" ||
      !Number.isFinite(Date.parse(row.joined_at))
    )
      return malformed();
    return result;
  });
  const matching = episodes.filter(
    (episode) => episode.projectId === project.id,
  );
  if (
    matching.some((episode) => episode.kind !== project.kind) ||
    new Set(episodes.map((episode) => episode.id)).size !== episodes.length ||
    matching.filter((episode) => episode.status === "current").length > 1
  )
    return malformed();
  return {
    current: matching.some((episode) => episode.status === "current"),
    creator: role === "creator",
  };
}
export function mapParticipantFailure(error: unknown): ParticipantFailure {
  if (error instanceof ParticipantError) return error.failure;
  const value =
    error && typeof error === "object"
      ? (error as { code?: unknown; message?: unknown })
      : {};
  if (value.code === "PT409")
    return value.message === "This Project is full." ? "full" : "unavailable";
  if (value.code === "42501") return "identity";
  if (value.code === "55000") return "profile";
  if (value.code === "22023") return "input";
  return "network";
}
