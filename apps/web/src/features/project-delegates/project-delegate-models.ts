export type ProjectKind = "one_time" | "recurring";
export type ProjectDelegatedAuthorityRole = "co_organizer" | "co_creator";

export type ProjectDelegateInvitePreview =
  | Readonly<{ isAvailable: false }>
  | Readonly<{
      isAvailable: true;
      projectId: string;
      projectKind: ProjectKind;
      projectTitle: string;
      ownerDisplayName: string | null;
      issuerDisplayName: string | null;
      expiresAt: string;
      requestedAuthorityRole: ProjectDelegatedAuthorityRole;
    }>;

export type ProjectDelegateAcceptFailure =
  "owner" | "alreadyDelegate" | "unavailable";

export function parseProjectDelegateInvitePreview(
  value: unknown,
): ProjectDelegateInvitePreview {
  if (!isRecord(value) || typeof value.is_available !== "boolean") {
    throw new Error("Project delegate invitation preview was malformed.");
  }
  if (!value.is_available) return { isAvailable: false };

  const projectKind = value.project_kind;
  const requestedAuthorityRole = value.requested_authority_role;
  const issuerDisplayName =
    value.issuer_display_name === undefined
      ? value.owner_display_name
      : value.issuer_display_name;
  if (
    !isUuid(value.project_id) ||
    (projectKind !== "one_time" && projectKind !== "recurring") ||
    typeof value.project_title !== "string" ||
    value.project_title.length === 0 ||
    (value.owner_display_name !== null &&
      typeof value.owner_display_name !== "string") ||
    (issuerDisplayName !== null && typeof issuerDisplayName !== "string") ||
    typeof value.expires_at !== "string" ||
    Number.isNaN(Date.parse(value.expires_at)) ||
    (requestedAuthorityRole !== "co_organizer" &&
      requestedAuthorityRole !== "co_creator")
  ) {
    throw new Error("Project delegate invitation preview was malformed.");
  }

  return {
    isAvailable: true,
    projectId: value.project_id,
    projectKind,
    projectTitle: value.project_title,
    ownerDisplayName: value.owner_display_name,
    issuerDisplayName,
    expiresAt: value.expires_at,
    requestedAuthorityRole,
  };
}

export function mapProjectDelegateAcceptFailure(
  error: unknown,
): ProjectDelegateAcceptFailure {
  const message =
    isRecord(error) && typeof error.message === "string" ? error.message : "";
  if (
    message ===
      "A Project owner cannot accept their own delegate invitation." ||
    message ===
      "The original Project Creator cannot accept delegated authority."
  ) {
    return "owner";
  }
  if (
    message === "This profile is already an active delegate for the Project." ||
    message ===
      "This profile already has active delegated authority for the Project."
  ) {
    return "alreadyDelegate";
  }
  return "unavailable";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(
      value,
    )
  );
}
