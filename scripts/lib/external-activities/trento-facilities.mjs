import { ActivityImportError } from "./transport.mjs";
import { publicActivityUrl } from "./records.mjs";

export const trentoFacilitiesSource = Object.freeze({
  sourceId: "trento-open-sports-facilities",
  displayName: "Comune di Trento",
  parserVersion: "trento-free-facilities-csv-v1",
  origin: "https://www.comune.trento.it",
  resourceUrl:
    "https://www.comune.trento.it/customexport/dataset-csv_resource-46671",
  datasetUrl:
    "https://www.comune.trento.it/Amministrazione/Documenti-e-dati/Dataset/Impianti-sportivi-ad-accesso-libero",
  licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
});
const columns = [
  "Item",
  "Tipo di impianto",
  "Luogo",
  "Ingresso da",
  "Link",
  "Coordinate GPS",
  "Note",
];
const disciplines = Object.freeze({
  "Calcio/Calcetto": "football",
  "Percorsi vita e salute": "fitness",
  "Ping pong": "table-tennis",
  Pallacanestro: "basketball",
  Scacchiera: "chess",
  Pallavolo: "volleyball",
  Fitness: "fitness",
  Tennis: "tennis",
  "Pattini a rotelle": "skating",
  Bocce: "bocce",
});
function invalid() {
  throw new ActivityImportError("invalid_payload");
}

// Strict bounded RFC4180-style export parser. Quoted commas, doubled quotes,
// embedded CR/LF and a UTF-8 BOM are supported; ambiguous/truncated rows fail.
export function parseMunicipalCsv(text) {
  if (
    typeof text !== "string" ||
    text.length > 2097152 ||
    /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)
  )
    invalid();
  text = text.replace(/^\ufeff/, "");
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  let closed = false;
  function cell() {
    if (field.length > 12000 || row.length >= 7) invalid();
    row.push(field);
    field = "";
    closed = false;
  }
  function line() {
    cell();
    rows.push(row);
    row = [];
    if (rows.length > 2001) invalid();
  }
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else field += c;
    } else if (c === ",") cell();
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      line();
    } else if (closed) invalid();
    else if (c === '"') {
      if (field) invalid();
      quoted = true;
    } else field += c;
    if (field.length > 12000) invalid();
  }
  if (quoted) invalid();
  if (field || row.length || closed) line();
  const header = rows.shift()?.map((s) => s.trim().normalize("NFC"));
  if (
    !header ||
    header.length !== columns.length ||
    new Set(header).size !== columns.length ||
    columns.some((key) => !header.includes(key))
  )
    invalid();
  if (!rows.length || rows.some((r) => r.length !== columns.length)) invalid();
  return rows.map((r) =>
    Object.fromEntries(header.map((key, i) => [key, r[i]])),
  );
}

function entities(value) {
  return value.replace(
    /&(#x[0-9a-f]+|#\d+|amp|quot|apos|lt|gt);/gi,
    (_, entity) => {
      const named = { amp: "&", quot: '"', apos: "'", lt: "<", gt: ">" };
      if (!entity.startsWith("#")) return named[entity.toLowerCase()];
      const n = entity.toLowerCase().startsWith("#x")
        ? parseInt(entity.slice(2), 16)
        : Number(entity.slice(1));
      if (n <= 0 || n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) invalid();
      return String.fromCodePoint(n);
    },
  );
}

// The only HTML accepted is this one published CSV field. No document scraping,
// DOM execution, page following or feed-discovered network destination exists.
export function municipalPlaceLink(value) {
  const text = value.trim();
  if (!text) return null;
  const anchor = /^<a\s+([^<>]+)>([^<>]*)<\/a>$/i.exec(text);
  if (!anchor) invalid();
  const attrs = anchor[1];
  const seen = new Set();
  let href;
  let offset = 0;
  for (const match of attrs.matchAll(/([a-z]+)\s*=\s*(["'])(.*?)\2/gi)) {
    if (attrs.slice(offset, match.index).trim()) invalid();
    const key = match[1].toLowerCase();
    if (!["href", "target", "title", "rel"].includes(key) || seen.has(key))
      invalid();
    // The live export includes trailing attribute whitespace (Item 57).
    // Trim only its boundaries; internal whitespace and unsafe URLs still fail.
    seen.add(key);
    if (key === "href") href = entities(match[3]).trim();
    offset = match.index + match[0].length;
  }
  if (attrs.slice(offset).trim() || !href) invalid();
  let url;
  try {
    url = publicActivityUrl(href);
  } catch (error) {
    if (error instanceof ActivityImportError && error.code === "invalid_record")
      invalid();
    throw error;
  }
  if (
    url.origin !== trentoFacilitiesSource.origin ||
    url.search ||
    url.hash ||
    !/^\/Vivere-il-Comune\/Luoghi\/[^/?#]+$/.test(url.pathname) ||
    /%(2f|5c|00)/i.test(url.pathname)
  )
    invalid();
  return url.href;
}

function plain(value, max, required = false) {
  const result = value
    .trim()
    .normalize("NFC")
    .replace(/[\t\r\n ]+/g, " ");
  if ((required && !result) || result.length > max || /[<>]/.test(result))
    invalid();
  return result || null;
}

export function mapTrentoFacilities(text) {
  const rows = parseMunicipalCsv(text);
  const ids = new Set();
  const places = new Set();
  let missingLinks = 0;
  let missingGeometry = 0;
  let unknownTypes = 0;
  const entries = rows.map((row) => {
    const id = row.Item.trim();
    if (!/^(0|[1-9]\d{0,11})$/.test(id) || ids.has(id)) invalid();
    ids.add(id);
    const type = plain(row["Tipo di impianto"], 100, true);
    const venue = plain(row.Luogo, 180, true);
    places.add(venue);
    const entrance = plain(row["Ingresso da"], 500);
    const description = plain(row.Note, 12000);
    const link = municipalPlaceLink(row.Link);
    if (!link) missingLinks++;
    let geometry = null;
    if (row["Coordinate GPS"].trim()) {
      const point = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/.exec(
        row["Coordinate GPS"],
      );
      if (!point) invalid();
      const latitude = Number(point[1]);
      const longitude = Number(point[2]);
      // Source supplies latitude,longitude, never a private/native/GPS location.
      // This broad sanity box catches axis swaps/outliers, not city boundaries.
      if (
        latitude < 45.8 ||
        latitude > 46.3 ||
        longitude < 10.9 ||
        longitude > 11.4
      )
        invalid();
      geometry = {
        latitude,
        longitude,
        precision: "venue",
        provenance_url: trentoFacilitiesSource.datasetUrl,
      };
    } else missingGeometry++;
    const discipline = disciplines[type] ?? "other-sports";
    if (!Object.hasOwn(disciplines, type)) unknownTypes++;
    const title = `${type} · ${venue}`;
    if (title.length > 300) invalid();
    return {
      record: {
        upstream_id: id,
        kind: "place",
        title,
        description,
        category: "sports",
        discipline,
        source_categories: [type],
        canonical_url: link ?? trentoFacilitiesSource.datasetUrl,
        link_scope: link ? "item" : "dataset",
        geometry,
        city: "Trento",
        venue,
        address: null,
        organizer: null,
        cost: null,
        audience: null,
        access: `Accesso libero nelle aree verdi comunali.${entrance ? ` Ingresso indicato dalla fonte: ${entrance}.` : ""} Orari e disponibilità non verificati.`,
        status: "scheduled",
        publishable: true,
        occurrences: [],
      },
    };
  });
  return {
    complete: true,
    entries,
    summary: {
      equipment_records: entries.length,
      named_places: places.size,
      dataset_links: missingLinks,
      missing_geometry: missingGeometry,
      unknown_types: unknownTypes,
    },
  };
}

export function trentoFacilitiesConnector() {
  return {
    sourceId: trentoFacilitiesSource.sourceId,
    kinds: ["place"],
    origins: [trentoFacilitiesSource.origin],
    officialOrigin: trentoFacilitiesSource.origin,
    publicLinkOrigins: [trentoFacilitiesSource.origin],
    apiPathPrefix: "/customexport/",
    async collect({ transport }) {
      const resource = await transport.text(
        trentoFacilitiesSource.resourceUrl,
        { contentTypes: ["text/csv"] },
      );
      if (resource.notModified) invalid();
      return mapTrentoFacilities(resource.value);
    },
  };
}
