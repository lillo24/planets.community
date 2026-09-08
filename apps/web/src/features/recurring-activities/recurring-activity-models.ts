export type PublicRecurringActivityLifecycle = "published" | "paused" | "ended";

export type RecurrenceType = "weekly" | "monthly";

export interface PublicRecurringActivityOccurrence {
  local_starts_at: string;
  starts_at: string;
  ends_at: string;
  event_timezone: string;
}

export interface PublicRecurringActivitySummary {
  recurring_activity_id: string;
  title: string;
  summary: string;
  topic: string | null;
  country_code: string;
  locality: string;
  administrative_area: string | null;
  public_location_label: string;
  next_starts_at: string;
  next_ends_at: string;
  event_timezone: string;
}

export interface WeeklyRecurringSchedule {
  recurrence_type: "weekly";
  weekday: number;
  day_of_month: null;
  local_start_time: string;
  duration_minutes: number;
  event_timezone: string;
  schedule_effective_from: string;
}

export interface MonthlyRecurringSchedule {
  recurrence_type: "monthly";
  weekday: null;
  day_of_month: number;
  local_start_time: string;
  duration_minutes: number;
  event_timezone: string;
  schedule_effective_from: string;
}

export type PublicRecurringSchedule =
  WeeklyRecurringSchedule | MonthlyRecurringSchedule;

export type PublicRecurringExactLocation =
  { kind: "restricted" } | { kind: "public"; text: string };

export interface PublicRecurringActivityDetail {
  recurring_activity_id: string;
  creator_display_name: string | null;
  lifecycle_state: PublicRecurringActivityLifecycle;
  title: string;
  summary: string;
  description: string;
  topic: string | null;
  country_code: string;
  locality: string;
  administrative_area: string | null;
  public_location_label: string;
  schedule: PublicRecurringSchedule;
  next_occurrences: PublicRecurringActivityOccurrence[];
  exact_location: PublicRecurringExactLocation;
}

export interface RecurringActivityPageCursor {
  version: 1;
  referenceTime: string;
  nextStartsAt: string;
  recurringActivityId: string;
  locality: string | null;
}

export interface PublicRecurringActivityListRequest {
  referenceTime: string;
  locality?: string;
  cursor?: {
    nextStartsAt: string;
    recurringActivityId: string;
  };
}

export interface RecurringActivityListQuery {
  locality?: string;
  cursor?: string;
}

export type Clock = () => Date;

const lifecycleValues = new Set<PublicRecurringActivityLifecycle>([
  "published",
  "paused",
  "ended",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const instantPattern =
  /^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
const localTimestampPattern =
  /^\d{4}-\d{2}-\d{2}[T ](?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?$/;
const localTimePattern = /^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

export function parsePublicRecurringActivitySummary(
  value: unknown,
): PublicRecurringActivitySummary {
  const row = record(value);
  rejectListLocationFields(row);
  const startsAt = instant(row.next_starts_at);
  const endsAt = instant(row.next_ends_at);
  if (Date.parse(endsAt) <= Date.parse(startsAt)) {
    throw new TypeError("Invalid recurring activity occurrence");
  }

  return {
    recurring_activity_id: uuid(row.recurring_activity_id),
    title: text(row.title),
    summary: text(row.summary),
    topic: nullableText(row.topic),
    country_code: countryCode(row.country_code),
    locality: text(row.locality),
    administrative_area: nullableText(row.administrative_area),
    public_location_label: text(row.public_location_label),
    next_starts_at: startsAt,
    next_ends_at: endsAt,
    event_timezone: timeZone(row.event_timezone),
  };
}

export function parsePublicRecurringActivityDetail(
  value: unknown,
): PublicRecurringActivityDetail {
  const row = record(value);
  const lifecycle = recurringLifecycle(row.lifecycle_state);
  const schedule = recurringSchedule(row);
  const occurrences = array(row.next_occurrences).map(parseOccurrence);

  if (
    occurrences.some(
      (occurrence) => occurrence.event_timezone !== schedule.event_timezone,
    )
  ) {
    throw new TypeError("Invalid recurring activity occurrence time zone");
  }
  if (lifecycle !== "published" && occurrences.length !== 0) {
    throw new TypeError("Inactive recurring activity has occurrences");
  }
  if (lifecycle === "published" && occurrences.length === 0) {
    throw new TypeError("Active recurring activity has no occurrence");
  }
  if (occurrences.length > 20) {
    throw new TypeError("Too many recurring activity occurrences");
  }

  const isRestricted = boolean(row.exact_location_restricted);
  const exactMeetingText = row.exact_meeting_text;
  const exactLocation: PublicRecurringExactLocation = isRestricted
    ? restrictedLocation(exactMeetingText)
    : { kind: "public", text: text(exactMeetingText) };

  return {
    recurring_activity_id: uuid(row.recurring_activity_id),
    creator_display_name: nullableText(row.creator_display_name),
    lifecycle_state: lifecycle,
    title: text(row.title),
    summary: text(row.summary),
    description: text(row.description),
    topic: nullableText(row.topic),
    country_code: countryCode(row.country_code),
    locality: text(row.locality),
    administrative_area: nullableText(row.administrative_area),
    public_location_label: text(row.public_location_label),
    schedule,
    next_occurrences: occurrences,
    exact_location: exactLocation,
  };
}

export function normalizeRecurringActivityLocality(
  value?: string,
): string | undefined {
  return value?.trim().slice(0, 120) || undefined;
}

export function createPublicRecurringActivityListRequest(
  query: RecurringActivityListQuery,
  clock: Clock = () => new Date(),
): PublicRecurringActivityListRequest {
  const locality = normalizeRecurringActivityLocality(query.locality);
  const cursor = decodeRecurringActivityCursor(query.cursor);

  if (cursor && cursor.locality === (locality ?? null)) {
    return {
      referenceTime: cursor.referenceTime,
      locality,
      cursor: {
        nextStartsAt: cursor.nextStartsAt,
        recurringActivityId: cursor.recurringActivityId,
      },
    };
  }

  return {
    referenceTime: clockInstant(clock),
    locality,
  };
}

export function encodeRecurringActivityCursor(
  cursor: RecurringActivityPageCursor,
): string {
  const validated = parseCursor(cursor);
  return Buffer.from(JSON.stringify(validated), "utf8").toString("base64url");
}

export function decodeRecurringActivityCursor(
  value?: string,
): RecurringActivityPageCursor | undefined {
  if (!value || value.length > 1024) return undefined;
  try {
    return parseCursor(
      JSON.parse(Buffer.from(value, "base64url").toString("utf8")),
    );
  } catch {
    return undefined;
  }
}

export function isRecurringActivityUuid(value: string): boolean {
  return uuidPattern.test(value);
}

function recurringSchedule(
  row: Record<string, unknown>,
): PublicRecurringSchedule {
  const recurrenceType = text(row.recurrence_type);
  const common = {
    local_start_time: localTime(row.local_start_time),
    duration_minutes: boundedInteger(row.duration_minutes, 15, 1440),
    event_timezone: timeZone(row.event_timezone),
    schedule_effective_from: calendarDate(row.schedule_effective_from),
  };

  if (recurrenceType === "weekly") {
    if (row.day_of_month !== null) {
      throw new TypeError("Invalid weekly recurring schedule");
    }
    return {
      recurrence_type: "weekly",
      weekday: boundedInteger(row.weekday, 1, 7),
      day_of_month: null,
      ...common,
    };
  }
  if (recurrenceType === "monthly") {
    if (row.weekday !== null) {
      throw new TypeError("Invalid monthly recurring schedule");
    }
    return {
      recurrence_type: "monthly",
      weekday: null,
      day_of_month: boundedInteger(row.day_of_month, 1, 28),
      ...common,
    };
  }
  throw new TypeError("Invalid recurring schedule type");
}

function parseOccurrence(value: unknown): PublicRecurringActivityOccurrence {
  const row = record(value);
  const startsAt = instant(row.starts_at);
  const endsAt = instant(row.ends_at);
  if (Date.parse(endsAt) <= Date.parse(startsAt)) {
    throw new TypeError("Invalid recurring activity occurrence");
  }
  return {
    local_starts_at: localTimestamp(row.local_starts_at),
    starts_at: startsAt,
    ends_at: endsAt,
    event_timezone: timeZone(row.event_timezone),
  };
}

function parseCursor(value: unknown): RecurringActivityPageCursor {
  const row = record(value);
  if (row.version !== 1) throw new TypeError("Invalid cursor version");
  const locality = row.locality;
  if (
    locality !== null &&
    (typeof locality !== "string" ||
      normalizeRecurringActivityLocality(locality) !== locality)
  ) {
    throw new TypeError("Invalid cursor locality");
  }
  return {
    version: 1,
    referenceTime: instant(row.referenceTime),
    nextStartsAt: instant(row.nextStartsAt),
    recurringActivityId: uuid(row.recurringActivityId),
    locality,
  };
}

function rejectListLocationFields(row: Record<string, unknown>) {
  if (
    "exact_meeting_text" in row ||
    "exact_location_restricted" in row ||
    "exact_location" in row
  ) {
    throw new TypeError("Unexpected recurring activity list field");
  }
}

function restrictedLocation(value: unknown): { kind: "restricted" } {
  if (value !== null) {
    throw new TypeError("Invalid restricted recurring activity location");
  }
  return { kind: "restricted" };
}

function clockInstant(clock: Clock): string {
  const value = clock();
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new TypeError("Invalid recurring activity clock");
  }
  return value.toISOString();
}

function recurringLifecycle(value: unknown): PublicRecurringActivityLifecycle {
  const parsed = text(value) as PublicRecurringActivityLifecycle;
  if (!lifecycleValues.has(parsed)) {
    throw new TypeError("Invalid recurring activity lifecycle");
  }
  return parsed;
}

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError("Expected recurring activity object");
  }
  return value as Record<string, unknown>;
}

function array(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    throw new TypeError("Expected recurring activity array");
  }
  return value;
}

function text(value: unknown): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new TypeError("Expected recurring activity text");
  }
  return value;
}

function nullableText(value: unknown): string | null {
  return value === null ? null : text(value);
}

function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") {
    throw new TypeError("Expected recurring activity boolean");
  }
  return value;
}

function uuid(value: unknown): string {
  const parsed = text(value);
  if (!isRecurringActivityUuid(parsed)) {
    throw new TypeError("Expected recurring activity UUID");
  }
  return parsed;
}

function instant(value: unknown): string {
  const parsed = text(value);
  if (
    !instantPattern.test(parsed) ||
    Number.isNaN(Date.parse(parsed)) ||
    !isCalendarDate(parsed.slice(0, 10))
  ) {
    throw new TypeError("Expected recurring activity timestamp");
  }
  return parsed;
}

function localTimestamp(value: unknown): string {
  const parsed = text(value);
  if (
    !localTimestampPattern.test(parsed) ||
    Number.isNaN(Date.parse(`${parsed.replace(" ", "T")}Z`)) ||
    !isCalendarDate(parsed.slice(0, 10))
  ) {
    throw new TypeError("Expected recurring activity local timestamp");
  }
  return parsed;
}

function localTime(value: unknown): string {
  const parsed = text(value);
  if (!localTimePattern.test(parsed)) {
    throw new TypeError("Expected recurring activity local time");
  }
  return parsed;
}

function calendarDate(value: unknown): string {
  const parsed = text(value);
  if (!isCalendarDate(parsed)) {
    throw new TypeError("Expected recurring activity date");
  }
  return parsed;
}

function isCalendarDate(value: string): boolean {
  if (!datePattern.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const candidate = new Date(Date.UTC(year, month - 1, day));
  return !(
    candidate.getUTCFullYear() !== year ||
    candidate.getUTCMonth() !== month - 1 ||
    candidate.getUTCDate() !== day
  );
}

function timeZone(value: unknown): string {
  const parsed = text(value);
  if (parsed.length > 100) {
    throw new TypeError("Invalid recurring activity time zone");
  }
  try {
    new Intl.DateTimeFormat("en", { timeZone: parsed }).format(0);
  } catch {
    throw new TypeError("Invalid recurring activity time zone");
  }
  return parsed;
}

function countryCode(value: unknown): string {
  const parsed = text(value);
  if (!/^[A-Z]{2}$/.test(parsed)) {
    throw new TypeError("Invalid recurring activity country code");
  }
  return parsed;
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new TypeError("Invalid recurring activity number");
  }
  return value;
}
