export type ProjectKind = "one_time" | "recurring";

export type ProjectDelegateInvitePreview =
  | Readonly<{ isAvailable: false }>
  | Readonly<{
      isAvailable: true;
      projectId: string;
      projectKind: ProjectKind;
      projectTitle: string;
      ownerDisplayName: string | null;
      expiresAt: string;
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
  if (
    !isUuid(value.project_id) ||
    (projectKind !== "one_time" && projectKind !== "recurring") ||
    typeof value.project_title !== "string" ||
    value.project_title.length === 0 ||
    (value.owner_display_name !== null &&
      typeof value.owner_display_name !== "string") ||
    typeof value.expires_at !== "string" ||
    Number.isNaN(Date.parse(value.expires_at))
  ) {
    throw new Error("Project delegate invitation preview was malformed.");
  }

  return {
    isAvailable: true,
    projectId: value.project_id,
    projectKind,
    projectTitle: value.project_title,
    ownerDisplayName: value.owner_display_name,
    expiresAt: value.expires_at,
  };
}

export function mapProjectDelegateAcceptFailure(
  error: unknown,
): ProjectDelegateAcceptFailure {
  const message =
    isRecord(error) && typeof error.message === "string" ? error.message : "";
  if (
    message === "A Project owner cannot accept their own delegate invitation."
  ) {
    return "owner";
  }
  if (
    message === "This profile is already an active delegate for the Project."
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
