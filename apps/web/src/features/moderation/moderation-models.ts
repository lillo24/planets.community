export const moderationQueuePageSize = 25;

export type ModerationStaffRole = "moderator" | "admin";
export type ModerationState = "received" | "under_review" | "completed";

export type ModerationQueueCursor = Readonly<{
  createdAt: string;
  caseId: string;
}>;

export type ModerationCaseSummary = Readonly<{
  caseId: string;
  state: ModerationState;
  stateVersion: number;
  createdAt: string;
  category: string;
  targetKind: string;
  targetSummary: string;
  contextSummary: string | null;
  subjectProfileId: string;
  subjectDisplayName: string;
}>;

export type ModerationCaseNote = Readonly<{
  noteId: string;
  authorProfileId: string;
  authorDisplayName: string;
  body: string;
  createdAt: string;
}>;

export type ModerationCaseEvent = Readonly<{
  eventId: string;
  actorProfileId: string;
  actorDisplayName: string;
  eventKind: "report_received" | "note_added" | "state_changed";
  fromState: ModerationState | null;
  toState: ModerationState | null;
  stateVersion: number;
  noteId: string | null;
  createdAt: string;
}>;

export type ModerationCorroborationResponse = Readonly<{
  responseId: string;
  responderProfileId: string;
  responderDisplayName: string;
  choice: "agree" | "disagree" | "unsure";
  explanation: string | null;
  createdAt: string;
}>;

export type ModerationCorroborationEvidence = Readonly<{
  invitedCount: number;
  respondedCount: number;
  pendingCount: number;
  agreeCount: number;
  disagreeCount: number;
  unsureCount: number;
  responses: ModerationCorroborationResponse[];
}>;

export type ModerationCounterstatementEvidence = Readonly<{
  requestId: string;
  recipientProfileId: string;
  recipientDisplayName: string;
  statement: string | null;
  submittedAt: string | null;
  requestedAt: string;
}>;

export type ModerationCaseDetail = Readonly<{
  caseId: string;
  state: ModerationState;
  stateVersion: number;
  createdAt: string;
  completedAt: string | null;
  category: string;
  explanation: string;
  targetKind: string;
  targetSummary: string;
  contextSummary: string | null;
  reporterProfileId: string;
  reporterDisplayName: string;
  subjectProfileId: string;
  subjectDisplayName: string;
  projectContextId: string | null;
  resourceListingContextId: string | null;
  resourceRequestContextId: string | null;
  resourceChatContextId: string | null;
  notes: ModerationCaseNote[];
  events: ModerationCaseEvent[];
  corroboration?: ModerationCorroborationEvidence | null;
  counterstatement?: ModerationCounterstatementEvidence | null;
}>;

export type ModerationQueuePage = Readonly<{
  cases: ModerationCaseSummary[];
  nextCursor?: string;
}>;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidPattern.test(value);
}

export function isModerationState(value: unknown): value is ModerationState {
  return (
    value === "received" || value === "under_review" || value === "completed"
  );
}

export function parseModerationQueue(data: unknown): ModerationCaseSummary[] {
  if (!Array.isArray(data)) throw malformed();
  return data.map((value) => {
    const row = record(value);
    return {
      caseId: uuid(row.case_id),
      state: state(row.state),
      stateVersion: integer(row.state_version),
      createdAt: timestamp(row.created_at),
      category: bounded(row.category, 80),
      targetKind: bounded(row.target_kind, 80),
      targetSummary: bounded(row.target_summary, 200),
      contextSummary: optionalBounded(row.context_summary, 200),
      subjectProfileId: uuid(row.subject_profile_id),
      subjectDisplayName: bounded(row.subject_display_name, 120),
    };
  });
}

export function parseModerationCase(
  data: unknown,
): ModerationCaseDetail | null {
  if (!Array.isArray(data) || data.length > 1) throw malformed();
  if (data.length === 0) return null;
  const row = record(data[0]);
  return {
    caseId: uuid(row.case_id),
    state: state(row.state),
    stateVersion: integer(row.state_version),
    createdAt: timestamp(row.created_at),
    completedAt: optionalTimestamp(row.completed_at),
    category: bounded(row.category, 80),
    explanation: bounded(row.explanation, 4000),
    targetKind: bounded(row.target_kind, 80),
    targetSummary: bounded(row.target_summary, 200),
    contextSummary: optionalBounded(row.context_summary, 200),
    reporterProfileId: uuid(row.reporter_profile_id),
    reporterDisplayName: bounded(row.reporter_display_name, 120),
    subjectProfileId: uuid(row.subject_profile_id),
    subjectDisplayName: bounded(row.subject_display_name, 120),
    projectContextId: optionalUuid(row.project_context_id),
    resourceListingContextId: optionalUuid(row.resource_listing_context_id),
    resourceRequestContextId: optionalUuid(row.resource_request_context_id),
    resourceChatContextId: optionalUuid(row.resource_chat_context_id),
    notes: array(row.notes).map(parseNote),
    events: array(row.events).map(parseEvent),
  };
}

export function parseModerationCorroboration(
  data: unknown,
): ModerationCorroborationEvidence {
  if (!Array.isArray(data) || data.length !== 1) throw malformed();
  const row = record(data[0]);
  return {
    invitedCount: integer(row.invited_count),
    respondedCount: integer(row.responded_count),
    pendingCount: integer(row.pending_count),
    agreeCount: integer(row.agree_count),
    disagreeCount: integer(row.disagree_count),
    unsureCount: integer(row.unsure_count),
    responses: array(row.responses).map(parseCorroborationResponse),
  };
}

export function parseModerationCounterstatement(
  data: unknown,
): ModerationCounterstatementEvidence | null {
  if (!Array.isArray(data) || data.length > 1) throw malformed();
  if (data.length === 0) return null;
  const row = record(data[0]);
  const statement = optionalBounded(row.statement, 4000);
  const submittedAt = optionalTimestamp(row.submitted_at);
  if ((statement === null) !== (submittedAt === null)) throw malformed();
  return {
    requestId: uuid(row.request_id),
    recipientProfileId: uuid(row.recipient_profile_id),
    recipientDisplayName: bounded(row.recipient_display_name, 120),
    statement,
    submittedAt,
    requestedAt: timestamp(row.requested_at),
  };
}

export function encodeModerationCursor(cursor: ModerationQueueCursor): string {
  return Buffer.from(JSON.stringify(cursor), "utf8").toString("base64url");
}

export function decodeModerationCursor(
  value: string | undefined,
): ModerationQueueCursor | undefined {
  if (!value) return undefined;
  try {
    const parsed = JSON.parse(
      Buffer.from(value, "base64url").toString("utf8"),
    ) as unknown;
    const row = record(parsed);
    return { createdAt: timestamp(row.createdAt), caseId: uuid(row.caseId) };
  } catch {
    return undefined;
  }
}

function parseNote(value: unknown): ModerationCaseNote {
  const row = record(value);
  return {
    noteId: uuid(row.note_id),
    authorProfileId: uuid(row.author_profile_id),
    authorDisplayName: bounded(row.author_display_name, 120),
    body: bounded(row.body, 4000),
    createdAt: timestamp(row.created_at),
  };
}

function parseEvent(value: unknown): ModerationCaseEvent {
  const row = record(value);
  const eventKind = row.event_kind;
  if (
    eventKind !== "report_received" &&
    eventKind !== "note_added" &&
    eventKind !== "state_changed"
  ) {
    throw malformed();
  }
  return {
    eventId: uuid(row.event_id),
    actorProfileId: uuid(row.actor_profile_id),
    actorDisplayName: bounded(row.actor_display_name, 120),
    eventKind,
    fromState: row.from_state === null ? null : state(row.from_state),
    toState: row.to_state === null ? null : state(row.to_state),
    stateVersion: integer(row.state_version),
    noteId: optionalUuid(row.note_id),
    createdAt: timestamp(row.created_at),
  };
}

function parseCorroborationResponse(
  value: unknown,
): ModerationCorroborationResponse {
  const row = record(value);
  const choice = row.choice;
  if (choice !== "agree" && choice !== "disagree" && choice !== "unsure") {
    throw malformed();
  }
  return {
    responseId: uuid(row.response_id),
    responderProfileId: uuid(row.responder_profile_id),
    responderDisplayName: bounded(row.responder_display_name, 120),
    choice,
    explanation: optionalBounded(row.explanation, 4000),
    createdAt: timestamp(row.created_at),
  };
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw malformed();
  }
  return value as Record<string, unknown>;
}

function array(value: unknown): unknown[] {
  if (!Array.isArray(value)) throw malformed();
  return value;
}

function bounded(value: unknown, maxLength: number): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > maxLength ||
    value.trim() !== value
  ) {
    throw malformed();
  }
  return value;
}

function optionalBounded(value: unknown, maxLength: number): string | null {
  return value === null ? null : bounded(value, maxLength);
}

function uuid(value: unknown): string {
  if (!isUuid(value)) throw malformed();
  return value;
}

function optionalUuid(value: unknown): string | null {
  return value === null ? null : uuid(value);
}

function state(value: unknown): ModerationState {
  if (!isModerationState(value)) throw malformed();
  return value;
}

function integer(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw malformed();
  }
  return value;
}

function timestamp(value: unknown): string {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw malformed();
  }
  return value;
}

function optionalTimestamp(value: unknown): string | null {
  return value === null ? null : timestamp(value);
}

function malformed(): Error {
  return new Error("The moderation response was malformed.");
}
