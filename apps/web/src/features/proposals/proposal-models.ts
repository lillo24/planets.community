export type ProposalStatus =
  "upcoming" | "happening" | "just_finished" | "completed";

export type ProposalSkillImportance = "required" | "useful";

export interface ProposalSkill {
  id: string;
  slug: string;
  label: string;
  category_id: string;
  category_slug: string;
  category_label: string;
  importance: ProposalSkillImportance;
}

export interface PublicProposalSummary {
  proposal_id: string;
  cover_object_path: string | null;
  title: string;
  summary: string;
  definition_phase: "idea" | "defined";
  published_at: string | null;
  reference_time: string | null;
  starts_at: string | null;
  ends_at: string | null;
  event_timezone: string | null;
  country_code: string | null;
  locality: string | null;
  administrative_area: string | null;
  public_location_label: string | null;
  derived_status: ProposalStatus | null;
  skills: ProposalSkill[];
}

export interface PublicProposalDetail extends PublicProposalSummary {
  creator_profile_id: string;
  creator_display_name: string | null;
  description: string | null;
  exact_meeting_text: string | null;
  exact_location_restricted: boolean;
}

export interface ProposalCursor {
  publishedAt: string;
  referenceTime: string;
  id: string;
}

export interface ProposalFilters {
  locality?: string;
  query?: string;
  definitionPhase?: "idea" | "defined";
  skillId?: string;
  cursor?: ProposalCursor;
}

export interface SkillOption {
  id: string;
  label: string;
}

const statusValues = new Set<ProposalStatus>([
  "upcoming",
  "happening",
  "just_finished",
  "completed",
]);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const coverFilePattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.webp$/i;

export function parsePublicProposalSummary(
  value: unknown,
): PublicProposalSummary {
  const row = record(value);
  const proposalId = text(row.proposal_id);
  const phase = text(row.definition_phase);
  if (phase !== "idea" && phase !== "defined")
    throw new TypeError("Invalid definition phase");
  if (phase === "idea" && row.derived_status !== null)
    throw new TypeError("Idea has event status");
  const optional = phase === "idea";
  return {
    definition_phase: phase,
    published_at: row.published_at == null ? null : instant(row.published_at),
    reference_time:
      row.reference_time == null ? null : instant(row.reference_time),
    proposal_id: proposalId,
    cover_object_path: coverObjectPath(
      row.cover_object_path,
      "projects",
      proposalId,
    ),
    title: text(row.title),
    summary: text(row.summary),
    starts_at:
      optional && row.starts_at === null ? null : instant(row.starts_at),
    ends_at: optional && row.ends_at === null ? null : instant(row.ends_at),
    event_timezone: optional
      ? nullableText(row.event_timezone)
      : text(row.event_timezone),
    country_code: optional
      ? nullableText(row.country_code)
      : text(row.country_code),
    locality: optional ? nullableText(row.locality) : text(row.locality),
    administrative_area: nullableText(row.administrative_area),
    public_location_label: optional
      ? nullableText(row.public_location_label)
      : text(row.public_location_label),
    derived_status: optional ? null : status(row.derived_status),
    skills: array(row.skills).map(parseSkill),
  };
}

function coverObjectPath(
  value: unknown,
  parentSegment: "projects" | "resources",
  parentId: string,
): string | null {
  if (value === null) return null;
  const parsed = text(value);
  const parts = parsed.split("/");
  if (
    parts.length !== 4 ||
    !uuidPattern.test(parts[0] ?? "") ||
    parts[1] !== parentSegment ||
    parts[2]?.toLowerCase() !== parentId.toLowerCase() ||
    !coverFilePattern.test(parts[3] ?? "")
  ) {
    throw new TypeError("Invalid cover object path");
  }
  return parsed;
}

export function parsePublicProposalDetail(
  value: unknown,
): PublicProposalDetail {
  const row = record(value);
  return {
    ...parsePublicProposalSummary(row),
    creator_profile_id: text(row.creator_profile_id),
    creator_display_name: nullableText(row.creator_display_name),
    description:
      row.definition_phase === "idea"
        ? nullableText(row.description)
        : text(row.description),
    exact_meeting_text: nullableText(row.exact_meeting_text),
    exact_location_restricted: boolean(row.exact_location_restricted),
  };
}

export function encodeProposalCursor(cursor: ProposalCursor): string {
  return Buffer.from(
    JSON.stringify({ version: 2, ...cursor }),
    "utf8",
  ).toString("base64url");
}

export function decodeProposalCursor(
  value?: string,
): ProposalCursor | undefined {
  if (!value || value.length > 512) return undefined;
  try {
    const parsed = record(
      JSON.parse(Buffer.from(value, "base64url").toString("utf8")),
    );
    if (parsed.version !== 2 || !uuidPattern.test(text(parsed.id)))
      return undefined;
    return {
      publishedAt: instant(parsed.publishedAt),
      referenceTime: instant(parsed.referenceTime),
      id: text(parsed.id),
    };
  } catch {
    return undefined;
  }
}

function parseSkill(value: unknown): ProposalSkill {
  const row = record(value);
  const importance = text(row.importance);
  if (importance !== "required" && importance !== "useful")
    throw new TypeError("Invalid skill importance");
  return {
    id: text(row.id),
    slug: text(row.slug),
    label: text(row.label),
    category_id: text(row.category_id),
    category_slug: text(row.category_slug),
    category_label: text(row.category_label),
    importance,
  };
}

function status(value: unknown): ProposalStatus {
  const parsed = text(value) as ProposalStatus;
  if (!statusValues.has(parsed)) throw new TypeError("Invalid proposal status");
  return parsed;
}

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new TypeError("Expected object");
  return value as Record<string, unknown>;
}

function array(value: unknown): unknown[] {
  if (!Array.isArray(value)) throw new TypeError("Expected array");
  return value;
}

function text(value: unknown): string {
  if (typeof value !== "string" || value.length === 0)
    throw new TypeError("Expected text");
  return value;
}

function nullableText(value: unknown): string | null {
  return value === null ? null : text(value);
}

function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") throw new TypeError("Expected boolean");
  return value;
}

function instant(value: unknown): string {
  const parsed = text(value);
  if (Number.isNaN(Date.parse(parsed)))
    throw new TypeError("Expected timestamp");
  return parsed;
}
