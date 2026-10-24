import { createHash } from "node:crypto";
import { parse, parseFragment } from "parse5";
import { XMLParser, XMLValidator } from "fast-xml-parser";
import ICAL from "ical.js";
import { ActivityImportError } from "./transport.mjs";

export const activityTypes = Object.freeze([
  "music",
  "theatre-cinema",
  "talks",
  "workshops",
  "social",
  "exhibitions",
  "outings",
]);
export const digest = (text) => createHash("sha256").update(text).digest("hex");
const fail = (code = "invalid_payload") => {
  throw new ActivityImportError(code);
};
export const attr = (node, name) =>
  node?.attrs?.find((a) => a.name === name)?.value;
export const hasClass = (node, name) =>
  (attr(node, "class") ?? "").split(/\s+/).includes(name);
export function nodes(root, predicate) {
  const found = [],
    pending = [root];
  let count = 0;
  while (pending.length) {
    const node = pending.pop();
    if (++count > 100_000) fail("limit_exceeded");
    if (predicate(node)) found.push(node);
    pending.push(...[...(node.childNodes ?? [])].reverse());
  }
  return found;
}
export function plainText(node) {
  if (!node) return "";
  // Script/iframe/noscript contents are never evidence or executable inputs.
  if (["script", "style", "iframe", "noscript"].includes(node.tagName))
    return "";
  if (node.nodeName === "#text") return node.value;
  return (node.childNodes ?? [])
    .map(plainText)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}
export const htmlText = (value) =>
  plainText(parseFragment(String(value ?? "")));
export function htmlDocument(value) {
  if (typeof value !== "string" || Buffer.byteLength(value) > 2_097_152) fail();
  const document = parse(value);
  nodes(document, () => false); // Bound tree size before source recipes run.
  return document;
}
export const firstClass = (root, name) =>
  nodes(root, (n) => hasClass(n, name))[0];

// Intl/IANA wall-time conversion explicitly rejects nonexistent and ambiguous
// DST times. An explicit source offset is required to disambiguate fall-back.
export function wallTime(date, clock, timezone = "Europe/Rome") {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    !/^\d{2}:\d{2}(?::\d{2})?$/.test(clock)
  )
    fail("ambiguous_schedule");
  const wall = `${date}T${clock.length === 5 ? clock + ":00" : clock}`;
  const target = Date.parse(wall + "Z");
  if (
    !Number.isFinite(target) ||
    new Date(target).toISOString().slice(0, 19) !== wall
  )
    fail("ambiguous_schedule");
  let format;
  try {
    format = new Intl.DateTimeFormat("sv-SE", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    });
  } catch {
    fail("ambiguous_schedule");
  }
  const matches = new Set();
  for (const shift of [-86400000, 0, 86400000]) {
    const probe = target + shift;
    const parts = Object.fromEntries(
      format.formatToParts(probe).map((p) => [p.type, p.value]),
    );
    const asWall = Date.parse(
      `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}Z`,
    );
    const instant = target - (asWall - probe);
    const check = Object.fromEntries(
      format.formatToParts(instant).map((p) => [p.type, p.value]),
    );
    if (
      `${check.year}-${check.month}-${check.day}T${check.hour}:${check.minute}:${check.second}` ===
      wall
    )
      matches.add(instant);
  }
  if (matches.size !== 1) fail("ambiguous_schedule");
  return new Date([...matches][0]).toISOString();
}
export function sourceDate(value, timezone = "Europe/Rome") {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value ?? "")) {
    const parsed = new Date(value + "T00:00:00Z");
    if (
      !Number.isFinite(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== value
    )
      fail("ambiguous_schedule");
    return { kind: "date", start: value, end: null, timezone };
  }
  if (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})$/.test(
      value ?? "",
    ) &&
    Number.isFinite(Date.parse(value))
  ) {
    sourceDate(value.slice(0, 10), timezone);
    return {
      kind: "timed",
      start: new Date(value).toISOString(),
      end: null,
      timezone,
    };
  }
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/.test(value ?? ""))
    return {
      kind: "timed",
      start: wallTime(value.slice(0, 10), value.slice(11), timezone),
      end: null,
      timezone,
    };
  fail("ambiguous_schedule");
}
export const nextDate = (date) =>
  new Date(Date.parse(date + "T00:00:00Z") + 86400000)
    .toISOString()
    .slice(0, 10);
const months = [
  "gennaio",
  "febbraio",
  "marzo",
  "aprile",
  "maggio",
  "giugno",
  "luglio",
  "agosto",
  "settembre",
  "ottobre",
  "novembre",
  "dicembre",
];
export function italianDate(text) {
  const match =
    /(?:^|\s)(\d{1,2})\s+(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre),?\s+(\d{4})(?:\s|$)/i.exec(
      text,
    );
  if (!match) fail("ambiguous_schedule");
  const date = `${match[3]}-${String(months.indexOf(match[2].toLowerCase()) + 1).padStart(2, "0")}-${match[1].padStart(2, "0")}`;
  sourceDate(date);
  return date;
}

export function explicitItalianDates(text) {
  const expression =
    /(\d{1,2})\s+(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)(?:,?\s+(\d{4}))?/gi;
  const matches = [...text.matchAll(expression)];
  const years = [...new Set(matches.map((m) => m[3]).filter(Boolean))];
  if (!matches.length || matches.length > 200 || !years.length)
    fail("ambiguous_schedule");
  let previous = null;
  return matches.map((m) => {
    const year = m[3] ?? (years.length === 1 ? years[0] : null);
    if (!year) fail("ambiguous_schedule");
    const date = italianDate(`${m[1]} ${m[2]} ${year}`);
    if (previous && date < previous) fail("ambiguous_schedule");
    previous = date;
    return date;
  });
}

// XML entities/DTD are prohibited before validation or parsing. No resolver,
// network expansion, remote context or XInclude operation is implemented.
export function feedEntries(xml) {
  if (
    typeof xml !== "string" ||
    /<!\s*(?:DOCTYPE|ENTITY)/i.test(xml) ||
    /<\s*(?:\w+:)?include\b/i.test(xml) ||
    XMLValidator.validate(xml) !== true
  )
    fail("unsafe_xml");
  let parsed;
  try {
    parsed = new XMLParser({
      ignoreAttributes: false,
      processEntities: false,
      parseTagValue: false,
      trimValues: true,
      maxNestedTags: 40,
      removeNSPrefix: true,
    }).parse(xml);
  } catch {
    fail("invalid_payload");
  }
  const array = (v) => (v == null ? [] : Array.isArray(v) ? v : [v]);
  const string = (v) =>
    typeof v === "string"
      ? htmlText(v)
      : typeof v?.["#text"] === "string"
        ? htmlText(v["#text"])
        : null;
  const items = parsed.rss
    ? array(parsed.rss.channel?.item).map((item) => ({
        id: string(item.guid) ?? string(item.link),
        url: string(item.link),
        title: string(item.title),
        publishedAt: string(item.pubDate),
        content:
          item.encoded ?? item["content:encoded"] ?? item.description ?? "",
      }))
    : parsed.feed
      ? array(parsed.feed.entry).map((item) => ({
          id: string(item.id),
          url: array(item.link).find(
            (l) => !l["@_rel"] || l["@_rel"] === "alternate",
          )?.["@_href"],
          title: string(item.title),
          publishedAt: string(item.published),
          modifiedAt: string(item.updated),
          content:
            item.content?.["#text"] ?? item.content ?? item.summary ?? "",
        }))
      : fail();
  if (items.length > 2000 || items.some((i) => !i.id || !i.url || !i.title))
    fail();
  return items;
}

export function jsonLdEvents(document) {
  const events = [],
    pending = [];
  for (const node of nodes(
    document,
    (n) =>
      n.tagName === "script" &&
      attr(n, "type")?.toLowerCase() === "application/ld+json",
  )) {
    try {
      pending.push({
        value: JSON.parse(
          (node.childNodes ?? []).map((n) => n.value ?? "").join(""),
        ),
        depth: 0,
        locator: `script[type=application/ld+json]:${events.length}`,
      });
    } catch {
      fail("invalid_jsonld");
    }
  }
  let count = 0;
  while (pending.length) {
    const { value, depth, locator } = pending.pop();
    if (++count > 10000 || depth > 30) fail("limit_exceeded");
    if (!value || typeof value !== "object") continue;
    if (Array.isArray(value)) {
      value.forEach((v, i) =>
        pending.push({
          value: v,
          depth: depth + 1,
          locator: `${locator}[${i}]`,
        }),
      );
      continue;
    }
    const types = Array.isArray(value["@type"])
      ? value["@type"]
      : [value["@type"]];
    if (types.some((t) => typeof t === "string" && /(?:^|\/)\w*Event$/.test(t)))
      events.push({ value, locator });
    for (const key of ["@graph", "subEvent"])
      if (value[key])
        pending.push({
          value: value[key],
          depth: depth + 1,
          locator: `${locator}.${key}`,
        });
  }
  return events;
}

// Bounded RFC5545 subset. Unsupported RRULEs are held, never guessed. Finite
// weekly/daily recurrences retain one UID with explicit exceptions/overrides.
export function calendarEntries(
  text,
  { timezone = "Europe/Rome", maxOccurrences = 200 } = {},
) {
  if (typeof text !== "string" || Buffer.byteLength(text) > 2_097_152) fail();
  let calendar;
  try {
    calendar = new ICAL.Component(ICAL.parse(text));
  } catch {
    fail("invalid_calendar");
  }
  if (calendar.name !== "vcalendar") fail("invalid_calendar");
  const components = calendar.getAllSubcomponents("vevent");
  if (components.length > 2000) fail("limit_exceeded");
  const result = [],
    ids = new Set();
  const convert = (time, prop) => {
    if (!time) fail("ambiguous_schedule");
    const tz =
      prop?.getParameter("tzid") ??
      (time.zone?.tzid === "UTC" ? "UTC" : timezone);
    return sourceDate(time.toString(), tz);
  };
  for (const component of components.filter(
    (c) => !c.hasProperty("recurrence-id"),
  )) {
    const uid = component.getFirstPropertyValue("uid");
    if (typeof uid !== "string" || !uid || ids.has(uid))
      fail("duplicate_upstream_id");
    ids.add(uid);
    const event = new ICAL.Event(component);
    const start = event.startDate;
    const rule = component.getFirstPropertyValue("rrule");
    if (
      rule &&
      (Object.keys(rule.parts).some((k) => k !== "BYDAY") ||
        (rule.parts.BYDAY &&
          (rule.parts.BYDAY.length > 7 ||
            rule.parts.BYDAY.some((d) => !/^(MO|TU|WE|TH|FR|SA|SU)$/.test(d)))))
    )
      fail("unsupported_schedule");
    if (
      rule &&
      ((!rule.count && !rule.until) ||
        !["DAILY", "WEEKLY"].includes(rule.freq) ||
        rule.count > maxOccurrences ||
        (rule.until &&
          rule.until.subtractDate(start).toSeconds() > 366 * 86400))
    )
      fail("unsupported_schedule");
    for (const override of components.filter(
      (c) =>
        c.getFirstPropertyValue("uid") === uid &&
        c.hasProperty("recurrence-id"),
    ))
      event.relateException(new ICAL.Event(override));
    const iterator = event.iterator(),
      occurrences = [];
    let time,
      iterations = 0;
    while ((time = iterator.next())) {
      if (++iterations > maxOccurrences) fail("limit_exceeded");
      const detail = event.getOccurrenceDetails(time);
      if (detail.item.component.getFirstPropertyValue("status") === "CANCELLED")
        continue;
      const occ = convert(
        detail.startDate,
        component.getFirstProperty("dtstart"),
      );
      if (detail.endDate) {
        const end = convert(
          detail.endDate,
          component.getFirstProperty("dtend") ??
            component.getFirstProperty("dtstart"),
        );
        if (end.kind !== occ.kind) fail("unsupported_schedule");
        occ.end = end.start;
      }
      occurrences.push(occ);
      if (!event.isRecurring()) break;
    }
    result.push({
      id: uid,
      title: component.getFirstPropertyValue("summary"),
      url: component.getFirstPropertyValue("url"),
      location: component.getFirstPropertyValue("location"),
      status: component.getFirstPropertyValue("status"),
      occurrences,
    });
  }
  if (
    components.some(
      (c) =>
        c.hasProperty("recurrence-id") &&
        !ids.has(c.getFirstPropertyValue("uid")),
    )
  )
    fail("unsupported_schedule");
  return result;
}
