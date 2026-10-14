import { isUuid } from "./moderation-models";

export type GroupContactEvidence = Readonly<{
  kind:
    | "group_contact_request"
    | "group_contact_message"
    | "group_coordination_proposal";
  targetId: string;
  humanId: string;
  sourceGroupId: string;
  targetGroupId: string | null;
  purpose: "idea" | "collaboration" | null;
  title: string | null;
  body: string;
  createdAt: string;
}>;

export function parseGroupContactEvidence(
  value: unknown,
): GroupContactEvidence {
  const fail = (): never => {
    throw new Error("The contact case evidence was malformed.");
  };
  if (!value || typeof value !== "object" || Array.isArray(value))
    return fail();
  const row = value as Record<string, unknown>;
  const keys = [
    "kind",
    "target_id",
    "human_id",
    "source_group_id",
    "target_group_id",
    "purpose",
    "title",
    "body",
    "created_at",
  ];
  if (
    Object.keys(row).length !== keys.length ||
    keys.some((key) => !(key in row))
  )
    return fail();
  if (
    (row.kind !== "group_contact_request" &&
      row.kind !== "group_contact_message" &&
      row.kind !== "group_coordination_proposal") ||
    !isUuid(row.target_id) ||
    !isUuid(row.human_id) ||
    !isUuid(row.source_group_id) ||
    typeof row.body !== "string" ||
    Array.from(row.body).length < 1 ||
    Array.from(row.body).length > 4000 ||
    typeof row.created_at !== "string" ||
    !Number.isFinite(Date.parse(row.created_at))
  )
    return fail();
  if (row.kind === "group_contact_request") {
    if (
      !isUuid(row.target_group_id) ||
      (row.purpose !== "idea" && row.purpose !== "collaboration") ||
      typeof row.title !== "string" ||
      Array.from(row.title).length < 1 ||
      Array.from(row.title).length > 120 ||
      Array.from(row.body).length > 1000
    )
      return fail();
  } else if (row.kind === "group_coordination_proposal") {
    if (
      row.target_group_id !== null ||
      row.purpose !== null ||
      typeof row.title !== "string" ||
      Array.from(row.title).length < 1 ||
      Array.from(row.title).length > 120 ||
      Array.from(row.body).length > 1000
    )
      return fail();
  } else if (
    row.target_group_id !== null ||
    row.purpose !== null ||
    row.title !== null
  )
    return fail();
  return {
    kind: row.kind,
    targetId: row.target_id,
    humanId: row.human_id,
    sourceGroupId: row.source_group_id,
    targetGroupId: row.target_group_id as string | null,
    purpose: row.purpose as GroupContactEvidence["purpose"],
    title: row.title as string | null,
    body: row.body,
    createdAt: row.created_at,
  };
}
