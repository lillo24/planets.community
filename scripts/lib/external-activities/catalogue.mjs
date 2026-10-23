import { ActivityImportError } from "./transport.mjs";

const invalid = () => {
  throw new ActivityImportError("invalid_record");
};
function object(value, keys) {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).some((key) => !keys.includes(key))
  )
    invalid();
}
export function catalogueDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value))
    invalid();
  const date = new Date(value + "T00:00:00Z");
  if (
    !Number.isFinite(date.getTime()) ||
    date.toISOString().slice(0, 10) !== value
  )
    invalid();
  return value;
}
export function normalizeGeometry(value, officialOrigin) {
  if (value == null) return null;
  object(value, ["latitude", "longitude", "precision", "provenance_url"]);
  if (
    typeof value.latitude !== "number" ||
    !Number.isFinite(value.latitude) ||
    Math.abs(value.latitude) > 90 ||
    typeof value.longitude !== "number" ||
    !Number.isFinite(value.longitude) ||
    Math.abs(value.longitude) > 180 ||
    !["venue", "locality"].includes(value.precision) ||
    typeof value.provenance_url !== "string" ||
    !(Array.isArray(officialOrigin) ? officialOrigin : [officialOrigin]).some(
      (origin) => value.provenance_url.startsWith(origin + "/"),
    )
  )
    invalid();
  return {
    latitude: value.latitude,
    longitude: value.longitude,
    precision: value.precision,
    provenance_url: value.provenance_url,
  };
}
export function normalizeSchedule(value, plainText) {
  if (value == null) return null;
  object(value, [
    "season_start",
    "season_end",
    "timezone",
    "text",
    "weekly",
    "exceptions",
  ]);
  const start =
    value.season_start == null ? null : catalogueDate(value.season_start);
  const end = value.season_end == null ? null : catalogueDate(value.season_end);
  if (
    start &&
    end &&
    (end < start || Date.parse(end) - Date.parse(start) > 366 * 86400000)
  )
    invalid();
  const timezone = value.timezone ?? null;
  if (timezone != null) {
    if (typeof timezone !== "string" || timezone.length > 100) invalid();
    try {
      new Intl.DateTimeFormat("en", { timeZone: timezone });
    } catch {
      invalid();
    }
  }
  let weekly = null;
  if (value.weekly != null) {
    object(value.weekly, ["days", "start_time", "end_time"]);
    const { days, start_time: from, end_time: to = null } = value.weekly;
    const clock = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
    if (
      !start ||
      !end ||
      !timezone ||
      !Array.isArray(days) ||
      !days.length ||
      days.length > 7 ||
      days.some((day) => !Number.isInteger(day) || day < 1 || day > 7) ||
      new Set(days).size !== days.length ||
      typeof from !== "string" ||
      !clock.test(from) ||
      (to != null && (typeof to !== "string" || !clock.test(to) || to <= from))
    )
      invalid();
    weekly = {
      days: [...days].sort((a, b) => a - b),
      start_time: from,
      end_time: to,
    };
  }
  const exceptions = value.exceptions ?? [];
  if (!Array.isArray(exceptions) || exceptions.length > 200) invalid();
  const dates = exceptions.map(catalogueDate);
  if (dates.some((date) => !start || !end || date < start || date > end))
    invalid();
  return {
    season_start: start,
    season_end: end,
    timezone,
    text: plainText(value.text, 2000),
    weekly,
    exceptions: [...new Set(dates)].sort(),
  };
}
