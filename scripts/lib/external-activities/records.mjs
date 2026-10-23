import { ActivityImportError } from "./transport.mjs";
import { normalizeGeometry, normalizeSchedule } from "./catalogue.mjs";

const fields = [
  "kind",
  "schedule",
  "geometry",
  "level",
  "access",
  "link_scope",
  "upstream_id",
  "title",
  "description",
  "canonical_url",
  "category",
  "source_categories",
  "discipline",
  "organizer",
  "cost",
  "audience",
  "city",
  "venue",
  "address",
  "status",
  "publishable",
  "source_modified_at",
  "occurrences",
];
const timed =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;
const dateOnly = /^\d{4}-\d{2}-\d{2}$/;
const slug = /^[a-z][a-z0-9-]{0,63}$/;
function invalid() {
  throw new ActivityImportError("invalid_record");
}
function text(value, max, required = false) {
  if (value == null && !required) return null;
  if (typeof value === "string" && !required && !value.trim()) return null;
  if (
    typeof value !== "string" ||
    value.length > max ||
    (required && !value.trim()) ||
    /<[\/]?[!A-Za-z][^>]*>|[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(
      value,
    )
  )
    invalid();
  return value;
}
export function publicActivityUrl(value) {
  if (
    typeof value !== "string" ||
    value.length > 2048 ||
    /[\s<>\u0000-\u001f\u007f]/.test(value)
  )
    invalid();
  let url;
  try {
    url = new URL(value);
  } catch {
    invalid();
  }
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.port ||
    !/^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$/i.test(url.hostname) ||
    /\.(localhost|local|internal)$/i.test(url.hostname)
  )
    invalid();
  return url;
}
function validDate(value, isTimed) {
  if (typeof value !== "string" || !(isTimed ? timed : dateOnly).test(value))
    invalid();
  const [year, month, day] = value.slice(0, 10).split("-").map(Number);
  const check = new Date(value.slice(0, 10) + "T00:00:00Z");
  if (
    !Number.isFinite(check.getTime()) ||
    check.getUTCFullYear() !== year ||
    check.getUTCMonth() + 1 !== month ||
    check.getUTCDate() !== day ||
    !Number.isFinite(Date.parse(value))
  )
    invalid();
  return value;
}
function occurrence(value) {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).some(
      (key) => !["kind", "start", "end", "timezone"].includes(key),
    ) ||
    !["timed", "date", "all_day"].includes(value.kind)
  )
    invalid();
  if (typeof value.timezone !== "string" || value.timezone.length > 100)
    invalid();
  try {
    new Intl.DateTimeFormat("en", { timeZone: value.timezone });
  } catch {
    invalid();
  }
  const start = validDate(value.start, value.kind === "timed");
  const end =
    value.end == null ? null : validDate(value.end, value.kind === "timed");
  if (
    end != null &&
    (value.kind === "timed"
      ? Date.parse(end) < Date.parse(start)
      : end <= start)
  )
    invalid();
  return { kind: value.kind, start, end, timezone: value.timezone };
}

// This validates an already mapped canonical record. It is deliberately not a
// municipal payload parser, HTML extractor or recurrence inference engine.
export function normalizeActivity(input, officialOrigin) {
  if (
    !input ||
    typeof input !== "object" ||
    Array.isArray(input) ||
    Object.keys(input).some((key) => !fields.includes(key))
  )
    invalid();
  const url = publicActivityUrl(input.canonical_url);
  const origins = Array.isArray(officialOrigin)
    ? officialOrigin
    : [officialOrigin];
  if (
    origins.length < 1 ||
    origins.length > 5 ||
    !origins.some(
      (origin) =>
        url.origin === origin && input.canonical_url.startsWith(origin + "/"),
    ) ||
    (input.link_scope != null &&
      !["item", "dataset"].includes(input.link_scope))
  )
    invalid();
  if (
    !["sports", "culture", "other"].includes(input.category) ||
    !["scheduled", "cancelled", "unpublished"].includes(input.status) ||
    typeof input.publishable !== "boolean"
  )
    invalid();
  if (
    !Array.isArray(input.source_categories) ||
    input.source_categories.length > 12 ||
    !Array.isArray(input.occurrences) ||
    input.occurrences.length > 200
  )
    invalid();
  const discipline = text(input.discipline, 64);
  if (discipline != null && !slug.test(discipline)) invalid();
  const kind = input.kind ?? "event";
  if (
    !["event", "course", "place"].includes(kind) ||
    (kind !== "course" && input.schedule != null) ||
    (kind === "place" && input.occurrences.length !== 0)
  )
    invalid();
  const geometry = normalizeGeometry(input.geometry, origins);
  if (geometry) publicActivityUrl(geometry.provenance_url);
  const occurrences = [
    ...new Map(
      input.occurrences.map((value) => {
        const normalized = occurrence(value);
        return [JSON.stringify(normalized), normalized];
      }),
    ).entries(),
  ]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, value]) => value);
  return {
    kind,
    ...(input.link_scope == null ? {} : { link_scope: input.link_scope }),
    schedule: normalizeSchedule(input.schedule, text),
    geometry,
    level: text(input.level, 2000),
    access: text(input.access, 2000),
    upstream_id: text(input.upstream_id, 200, true),
    title: text(input.title, 300, true),
    description: text(input.description, 12000),
    canonical_url: url.href,
    category: input.category,
    source_categories: [
      ...new Set(
        input.source_categories.map((value) => text(value, 100, true)),
      ),
    ].sort(),
    discipline,
    organizer: text(input.organizer, 500),
    cost: text(input.cost, 2000),
    audience: text(input.audience, 2000),
    city: text(input.city, 500),
    venue: text(input.venue, 500),
    address: text(input.address, 500),
    status: input.status,
    publishable: input.publishable,
    source_modified_at:
      input.source_modified_at == null
        ? null
        : validDate(input.source_modified_at, true),
    occurrences,
  };
}
