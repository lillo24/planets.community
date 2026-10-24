import { ActivityImportError } from "./transport.mjs";
import {
  attr,
  nodes,
  hasClass,
  firstClass,
  plainText,
  htmlDocument,
  htmlText,
  italianDate,
  explicitItalianDates,
  sourceDate,
  nextDate,
  wallTime,
  jsonLdEvents,
  feedEntries,
  digest,
} from "./extraction.mjs";

// These are evaluated publisher relationships, not republication grants. Owner
// database policy controls collection, field reuse, qualification and publishing.
export const radarSources = Object.freeze(
  [
    {
      sourceId: "muse-events",
      displayName: "MUSE",
      origin: "https://www.muse.it",
      paths: ["/robots.txt", "/calendario-eventi/", "/eventi/"],
      listing: "/calendario-eventi/",
      parserVersion: "muse-semantic-v1",
      relationship: "organizer",
      delayMs: 1000,
      coverage: "Published calendar entries; Trento venue only",
      rightsState: "held_no_applicable_reuse_basis",
      formats: ["html"],
    },
    {
      sourceId: "santa-chiara-events",
      displayName: "Centro Servizi Culturali Santa Chiara",
      origin: "https://www.centrosantachiara.it",
      paths: ["/robots.txt", "/", "/csc_shows"],
      listing: "/",
      parserVersion: "santa-calendar-v1",
      relationship: "organizer",
      delayMs: 10000,
      coverage:
        "Published calendar query, explicit 90-day window; Trento venues only",
      rightsState: "held_no_applicable_reuse_basis",
      formats: ["html", "json"],
    },
    {
      sourceId: "arci-trentino-events",
      displayName: "ARCI del Trentino",
      origin: "https://arcideltrentino.it",
      paths: ["/robots.txt", "/", "/eventi/"],
      listing: "/",
      parserVersion: "arci-jsonld-v1",
      relationship: "publisher",
      delayMs: 1000,
      coverage:
        "Events linked by publisher homepage, not entire regional archive",
      rightsState: "held_no_applicable_reuse_basis",
      formats: ["html", "jsonld"],
    },
    {
      sourceId: "susat-outings",
      displayName: "SUSAT",
      origin: "https://www.susat.it",
      paths: ["/robots.txt", "/feed/"],
      listing: "/feed/",
      parserVersion: "susat-rss-v1",
      relationship: "organizer",
      delayMs: 1000,
      coverage:
        "Current RSS entries; explicit outings with local departure, no destination pin",
      rightsState: "held_no_applicable_reuse_basis",
      formats: ["rss"],
    },
  ].map((s) =>
    Object.freeze({
      ...s,
      paths: Object.freeze(s.paths),
      formats: Object.freeze(s.formats),
    }),
  ),
);

const hold = (code) => {
  throw new ActivityImportError(code);
};
const classText = (root, name) => plainText(firstClass(root, name)) || null;
const hrefs = (root, predicate) => [
  ...new Set(
    nodes(
      root,
      (n) => n.tagName === "a" && predicate(attr(n, "href") ?? ""),
    ).map((n) => attr(n, "href")),
  ),
];
const types = {
  Concerto: "music",
  Musica: "music",
  Cinema: "theatre-cinema",
  Teatro: "theatre-cinema",
  Spettacolo: "theatre-cinema",
  Incontro: "talks",
  Convegno: "talks",
  Conferenza: "talks",
  Laboratorio: "workshops",
  Mostra: "exhibitions",
  Installazione: "exhibitions",
  Escursione: "outings",
};
function base({
  id,
  title,
  url,
  type,
  venue = null,
  city = null,
  cost = null,
  access = null,
  occurrences = [],
  status = "scheduled",
  sourceCategories = [],
}) {
  return {
    upstream_id: String(id),
    title,
    canonical_url: url,
    activity_type: type,
    kind: "event",
    category: type === "outings" ? "other" : "culture",
    description: null,
    source_categories: sourceCategories,
    discipline: null,
    organizer: null,
    cost,
    audience: null,
    city,
    venue,
    address: null,
    geometry: null,
    access,
    status,
    publishable: true,
    source_modified_at: null,
    occurrences,
  };
}
function candidate(record, fields, reason = null) {
  return {
    upstream_id: record.upstream_id,
    title: record.title,
    record,
    fields,
    reason,
  };
}
export function parseMuseDetail(html, url, type) {
  const dom = htmlDocument(html),
    title = plainText(nodes(dom, (n) => n.tagName === "h1")[0]);
  const api = nodes(
    dom,
    (n) => n.tagName === "link" && attr(n, "type") === "application/json",
  )
    .map((n) => attr(n, "href"))
    .find((h) => /\/wp\/v2\/events\/\d+(?:\?|$)/.test(h ?? ""));
  const id = api?.match(/\/events\/(\d+)/)?.[1];
  if (!id || !title)
    return [
      {
        upstream_id: `held:${digest(url).slice(0, 32)}`,
        title: title || null,
        record: null,
        fields: {
          title: "h1.title",
          upstream_id: "link[type=application/json]",
        },
        reason: "missing_stable_item_identity",
      },
    ];
  const facts = {};
  const asides = nodes(dom, (n) => n.tagName === "aside");
  const panels = asides.flatMap((n) =>
    nodes(n, (r) => hasClass(r, "btn--inline-ico-alt")),
  );
  for (const row of panels.length
    ? panels
    : asides.flatMap((n) => nodes(n, (r) => r.tagName === "li"))) {
    const icon = nodes(row, (n) => n.tagName === "use")[0];
    const key = (attr(icon, "xlink:href") ?? attr(icon, "href") ?? "").replace(
      /^#/,
      "",
    );
    const value = plainText(row);
    if (value) (facts[key] ??= []).push(value);
  }
  const venue =
    [...(facts["map-pin"] ?? []), ...(facts["ico-pin"] ?? [])].join("; ") ||
    null;
  const record = base({
    id,
    title,
    url,
    type: type ?? null,
    venue,
    cost: facts["currency-eur"]?.join("; ") ?? null,
  });
  const fields = {
    title: "h1.title",
    venue:
      "aside .btn--inline-ico-alt use[href=#map-pin|#ico-pin] (linked or unlinked panel)",
    occurrences: "aside .btn--inline-ico-alt use[href=#ico-calendar|#clock]",
    cost: "aside .btn--inline-ico-alt use[href=#currency-eur]",
    activity_type:
      "https://www.muse.it/calendario-eventi/ .card .eyelet associated with exact event href",
  };
  try {
    if (!venue) hold("unverified_locality");
    if (/Predazzo|Bondone|Ledro|Genova|Belasi/i.test(venue))
      hold("outside_area");
    if (!/(?:\bMUSE\b|Palazzo delle Albere|Trento)/i.test(venue))
      hold("unverified_locality");
    record.city = "Trento";
    const dates = facts["ico-calendar"] ?? [],
      clocks = facts.clock ?? [];
    if (dates.length !== 1 || /ogni|\d+\s*[-–/]\s*\d+/i.test(dates[0]))
      hold("ambiguous_schedule");
    const explicit = explicitItalianDates(dates[0]);
    if (
      type === "exhibitions" &&
      explicit.length === 2 &&
      /dal|al|fino|[-–]/i.test(dates[0])
    ) {
      record.occurrences = [
        {
          kind: "date",
          start: explicit[0],
          end: nextDate(explicit[1]),
          timezone: "Europe/Rome",
        },
      ];
      return [candidate(record, fields)];
    }
    if (/\bdal\b|\bfino\b/i.test(dates[0])) hold("ambiguous_schedule");
    if (explicit.length > 1) {
      if (clocks.length && !/^Vedi incontri$/i.test(clocks.join(" ")))
        hold("ambiguous_schedule");
      record.occurrences = explicit.map((d) => sourceDate(d));
      return [candidate(record, fields)];
    }
    const date = explicit[0],
      occ = sourceDate(date);
    if (clocks.length === 1) {
      const m =
        /^(?:Dalle|Alle)\s+(\d{1,2})(?:[.:](\d{2}))?(?:\s+alle\s+(\d{1,2})(?:[.:](\d{2}))?)?$/i.exec(
          clocks[0],
        );
      if (!m) hold("ambiguous_schedule");
      occ.kind = "timed";
      occ.start = wallTime(date, `${m[1].padStart(2, "0")}:${m[2] ?? "00"}`);
      if (m[3])
        occ.end = wallTime(date, `${m[3].padStart(2, "0")}:${m[4] ?? "00"}`);
    } else if (clocks.length > 1) hold("ambiguous_schedule");
    record.occurrences = [occ];
    // Generic publisher labels ("Evento") truthfully retain an unknown type.
    // They do not populate an invented family facet.
    return [candidate(record, fields)];
  } catch (error) {
    if (!(error instanceof ActivityImportError)) throw error;
    return [candidate(record, fields, error.code)];
  }
}
export function parseSantaCalendar(html, origin) {
  const dom = htmlDocument(html),
    rows = nodes(dom, (n) => hasClass(n, "single_next_event"));
  if (!rows.length && !/Nessun risultato/.test(plainText(dom)))
    hold("source_record_drift");
  const result = [];
  for (const row of rows) {
    const title = classText(row, "sne_title"),
      venue = classText(row, "sne_location");
    const path = hrefs(row, (h) =>
      h.startsWith("/spettacoli/calendariospettacoli/"),
    )[0];
    // No row-order/title identity or box-office URL substituted for absent IDs.
    const id = path
      ? `${path.split("/").at(-1)}:${digest(venue ?? "").slice(0, 12)}`
      : null;
    if (!id) {
      result.push({
        upstream_id: `held:${digest(plainText(row)).slice(0, 32)}`,
        title,
        record: null,
        fields: { title: ".sne_title" },
        reason: "missing_stable_item_link",
      });
      continue;
    }
    const css = attr(row, "class") ?? "";
    // Named publisher programmes establish these families. AudiPOP and other
    // mixed seasons/colour palettes do not establish a theatre/music category.
    const type = hasClass(row, "giallo_cinema")
      ? "theatre-cinema"
      : hasClass(row, "blu_elettrico") || hasClass(row, "rosso_cardinale")
        ? "music"
        : null;
    const annotation = classText(row, "she_adv");
    const price =
      annotation &&
      /^(?:Ingresso libero|Gratuito|\d+(?:[.,]\d+)?\s*(?:€|euro))$/i.test(
        annotation,
      )
        ? annotation
        : null;
    const record = base({
      id,
      title,
      url: new URL(path, origin).href,
      type,
      venue,
      cost: price,
      access: price ? null : annotation,
      sourceCategories: [
        css.replace(/^single_next_event\s+color_rassegna\s*/, "").trim(),
      ].filter(Boolean),
    });
    let reason = null;
    try {
      if (!venue || !/\bTrento\b/.test(venue)) hold("outside_area");
      record.city = "Trento";
      const dateText = classText(row, "sne_date"),
        date = italianDate(dateText ?? "");
      const clock = /(\d{1,2})[.:](\d{2})\s*$/.exec(dateText ?? "");
      record.occurrences = [
        clock
          ? {
              kind: "timed",
              start: wallTime(date, `${clock[1].padStart(2, "0")}:${clock[2]}`),
              end: null,
              timezone: "Europe/Rome",
            }
          : sourceDate(date),
      ];
      // A mixed programme keeps its supported time/place facts and null type.
    } catch (error) {
      if (!(error instanceof ActivityImportError)) throw error;
      reason = error.code;
    }
    result.push(
      candidate(
        record,
        {
          title: ".sne_title",
          venue: ".sne_location",
          occurrences: ".sne_date",
          cost: ".she_adv (explicit price only)",
          access: ".she_adv (school/audience/access annotation)",
          activity_type: ".single_next_event publisher programme class",
        },
        reason,
      ),
    );
  }
  // Same stable show and venue retain several explicit performances, not one
  // card per title and not a fabricated continuous opening interval.
  const groups = new Map();
  for (const item of result) {
    const previous = groups.get(item.upstream_id);
    if (previous && item.record && previous.record) {
      previous.record.occurrences.push(...item.record.occurrences);
      if (item.reason) previous.reason = item.reason;
    } else if (previous) hold("duplicate_upstream_id");
    else groups.set(item.upstream_id, item);
  }
  return [...groups.values()];
}
export function parseArciDetail(html, url) {
  const dom = htmlDocument(html),
    events = jsonLdEvents(dom),
    category = classText(dom, "mec-single-event-category");
  if (!events.length) hold("source_record_drift");
  return events.map(({ value: e, locator }) => {
    const id =
      nodes(dom, (n) => n.tagName === "a")
        .map((n) => attr(n, "href"))
        .find((h) => h?.includes("?method=ical&id="))
        ?.match(/[?&]id=(\d+)/)?.[1] ?? e["@id"];
    if (!id || e.url !== url || !e.name) hold("source_record_drift");
    const type =
      Object.entries(types).find(([label]) => category?.includes(label))?.[1] ??
      null;
    const location = e.location;
    let venue = location?.name || null;
    let city =
      typeof location?.address === "object"
        ? (location.address.addressLocality ?? null)
        : null;
    const body =
      classText(dom, "mec-single-event-description") ??
      classText(dom, "mec-events-content") ??
      "";
    // Narrow publisher-specific venue phrases from the event body, excluding
    // navigation/contact addresses. No general title/city keyword inference.
    for (const [pattern, name] of [
      [/\ba Palazzo delle Albere,\s*Trento\b/i, "Palazzo delle Albere"],
      [/\bGalleria Civica(?: di)?[,\s]+Trento\b/i, "Galleria Civica"],
    ]) {
      if (!venue && !city && pattern.test(body)) {
        venue = name;
        city = "Trento";
      }
    }
    // Plugin-generated price=0 is often a default. Without visible price
    // evidence, it does not establish free admission.
    const record = base({
      id,
      title: htmlText(e.name),
      url,
      type,
      venue,
      city,
      sourceCategories: category ? [category] : [],
      status:
        e.eventStatus === "https://schema.org/EventCancelled"
          ? "cancelled"
          : "scheduled",
    });
    let reason = null;
    try {
      const occ = sourceDate(e.startDate);
      if (e.endDate) {
        const end = sourceDate(e.endDate);
        if (end.kind !== occ.kind) hold("ambiguous_schedule");
        if (
          occ.kind === "timed" &&
          Date.parse(end.start) - Date.parse(occ.start) > 86400000
        ) {
          // Exhibitions are date spans, with no promise of continuous opening.
          if (type !== "exhibitions") hold("ambiguous_schedule");
          record.occurrences = [
            {
              kind: "date",
              start: e.startDate.slice(0, 10),
              end: nextDate(e.endDate.slice(0, 10)),
              timezone: "Europe/Rome",
            },
          ];
        } else {
          occ.end = end.start;
          record.occurrences = [occ];
        }
      } else record.occurrences = [occ];
      if (!city || !/^Trento$/i.test(city)) hold("unverified_locality");
      if (!type) hold("unknown_activity_type");
    } catch (error) {
      if (!(error instanceof ActivityImportError)) throw error;
      reason = error.code;
    }
    return candidate(
      record,
      {
        title: `${locator}.name`,
        occurrences: `${locator}.startDate/endDate`,
        venue: `${locator}.location or .mec-single-event-description explicit venue/locality phrase`,
        activity_type: ".mec-single-event-category",
      },
      reason,
    );
  });
}
export function parseSusatFeed(xml) {
  return feedEntries(xml).map((item) => {
    // RSS pubDate is publication metadata, never the outing date.
    const id = /[?&]p=(\d+)$/.exec(item.id)?.[1] ?? item.id;
    const record = base({
      id,
      title: item.title,
      url: item.url,
      type: "outings",
      access: null,
    });
    let reason = null;
    try {
      const date = italianDate(item.title);
      record.occurrences = [sourceDate(date)];
      const content = htmlText(item.content);
      if (!/Zuffo|\britrovo a Trento\b/i.test(content))
        hold("unverified_local_departure");
      // Departure relevance is separate from the outing destination. No city,
      // venue or point is synthesized from a meeting point in Trento.
      record.access =
        "Partenza dal parcheggio Zuffo; destinazione esterna. Verificare iscrizione e requisiti sul sito SUSAT.";
      if (/iscrizion|prenotaz/i.test(content))
        record.access += " Iscrizione richiesta.";
      if (/non soci|per i soci|tesser/i.test(content))
        record.access += " Condizioni distinte per soci e non soci.";
    } catch (error) {
      if (!(error instanceof ActivityImportError)) throw error;
      reason = error.code;
    }
    return {
      ...candidate(
        record,
        {
          title: "rss/channel/item/title",
          occurrences: "rss/channel/item/title (explicit full date)",
          access:
            "rss/channel/item/content:encoded (departure/registration statements)",
        },
        reason,
      ),
      published_at: item.publishedAt
        ? new Date(item.publishedAt).toISOString()
        : null,
    };
  });
}

export function radarConnector(sourceId) {
  const source = radarSources.find((s) => s.sourceId === sourceId);
  if (!source) hold("unknown_source");
  return {
    ...source,
    radar: true,
    kinds: ["event"],
    origins: [source.origin],
    publicLinkOrigins: [source.origin],
    officialOrigin: source.origin,
    apiPathPrefix: "/",
    allowedPaths: source.paths,
    async collect({ document, window }) {
      const listing = source.origin + source.listing;
      if (sourceId === "susat-outings")
        return {
          complete: true,
          candidates: await document(listing, "rss", parseSusatFeed),
        };
      if (sourceId === "santa-chiara-events") {
        // The POST URL/field come from the publisher's own load_shows function.
        const format = (d) =>
          new Intl.DateTimeFormat("en-GB", {
            timeZone: "Europe/Rome",
            day: "2-digit",
            month: "2-digit",
            year: "numeric",
          }).format(new Date(d));
        const form = new URLSearchParams({
          "date-range": `${format(window.start)} - ${format(window.end)}`,
        }).toString();
        return {
          complete: true,
          candidates: await document(
            source.origin + "/csc_shows",
            "json",
            (value) => {
              if (typeof value?.correct !== "string")
                hold("source_record_drift");
              return parseSantaCalendar(value.correct, source.origin);
            },
            { form },
          ),
        };
      }
      const links = await document(listing, "html", (html) => {
        const dom = htmlDocument(html);
        if (sourceId === "muse-events")
          return hrefs(dom, (h) =>
            h.startsWith(source.origin + "/eventi/"),
          ).map((url) => {
            const anchor = nodes(
              dom,
              (n) => n.tagName === "a" && attr(n, "href") === url,
            )[0];
            return {
              url,
              type: types[classText(anchor.parentNode, "eyelet")] ?? null,
            };
          });
        return hrefs(dom, (h) => h.startsWith(source.origin + "/eventi/")).map(
          (url) => ({ url }),
        );
      });
      if (!links.length || links.length > 60) hold("source_record_drift");
      const candidates = [];
      for (const link of links)
        candidates.push(
          ...(await document(
            link.url,
            "html",
            (html) =>
              sourceId === "muse-events"
                ? parseMuseDetail(html, link.url, link.type)
                : parseArciDetail(html, link.url),
            { context: link.type ?? null },
          )),
        );
      return { complete: true, candidates };
    },
  };
}
