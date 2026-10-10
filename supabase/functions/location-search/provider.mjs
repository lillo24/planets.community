// Pure adapter shared by the Edge runtime and synthetic Node tests.
/**
 * @typedef {object} VerifiedPlace
 * @property {"geoapify"} provider
 * @property {"locality"|"address"|"amenity"} kind
 * @property {string} result_type
 * @property {string} label
 * @property {"IT"} country_code
 * @property {string} locality
 * @property {string|null} administrative_area
 * @property {number} latitude
 * @property {number} longitude
 * @property {number|null} confidence
 * @property {"openstreetmap"} source
 * @property {string} attribution
 * @property {string} source_license
 * Database issuance adds verified_at; no provider IDs or opaque JSON survive.
 */
export class LocationFailure extends Error {
  constructor(status) {
    super(status);
    this.status = status;
  }
}

export function normalizeQuery(value) {
  if (typeof value !== "string") throw new LocationFailure("invalid_request");
  const query = value.normalize("NFC").trim().replace(/\s+/gu, " ");
  if (
    query.length < 2 ||
    query.length > 160 ||
    /[\u0000-\u001f\u007f]/u.test(value)
  ) {
    throw new LocationFailure("invalid_request");
  }
  return query;
}

function component(value, maximum = 120) {
  if (
    typeof value !== "string" ||
    !value.trim() ||
    value.length > maximum ||
    /[\u0000-\u001f\u007f<>]/u.test(value)
  ) {
    throw new LocationFailure("malformed_response");
  }
  return value.trim();
}

export function normalizeResults(payload, language) {
  if (
    !payload ||
    !Array.isArray(payload.results) ||
    payload.results.length > 5
  ) {
    throw new LocationFailure("malformed_response");
  }
  const seen = new Set();
  return payload.results
    .map((raw) => {
      if (!raw || raw.country_code !== "it")
        throw new LocationFailure("invalid_country");
      // Only OSM-backed autocomplete geocoding is admitted in MAP01. No Places
      // directory, opaque datasource object, ID, categories or opening hours.
      if (raw.datasource?.sourcename !== "openstreetmap")
        throw new LocationFailure("unsupported_source");
      const broad = [
        "city",
        "suburb",
        "district",
        "postcode",
        "county",
        "state",
      ].includes(raw.result_type);
      const exact = ["building", "street", "amenity"].includes(raw.result_type);
      if (!broad && !exact) throw new LocationFailure("unsupported_place");
      const locality = component(
        raw.city ??
          (broad
            ? (raw.suburb ??
              raw.district ??
              raw.postcode ??
              raw.county ??
              raw.state)
            : undefined),
      );
      const administrativeArea = [raw.county, raw.state]
        .filter((value) => value != null)
        .map((value) => component(value));
      const region = [...new Set(administrativeArea)].join(", ") || null;
      const label = broad
        ? component(
            [
              ...new Set(
                [
                  locality,
                  region,
                  language === "it" ? "Italia" : "Italy",
                ].filter(Boolean),
              ),
            ].join(", "),
            180,
          )
        : component(raw.formatted, 180);
      if (
        typeof raw.lat !== "number" ||
        !Number.isFinite(raw.lat) ||
        raw.lat < -90 ||
        raw.lat > 90 ||
        typeof raw.lon !== "number" ||
        !Number.isFinite(raw.lon) ||
        raw.lon < -180 ||
        raw.lon > 180
      ) {
        throw new LocationFailure("malformed_response");
      }
      const confidence = raw.rank?.confidence ?? null;
      if (
        confidence !== null &&
        (typeof confidence !== "number" ||
          !Number.isFinite(confidence) ||
          confidence < 0 ||
          confidence > 1)
      ) {
        throw new LocationFailure("malformed_response");
      }
      const place = {
        provider: "geoapify",
        kind: broad
          ? "locality"
          : raw.result_type === "amenity"
            ? "amenity"
            : "address",
        result_type: raw.result_type,
        label,
        country_code: "IT",
        locality,
        administrative_area: region,
        latitude: raw.lat,
        longitude: raw.lon,
        confidence,
        source: "openstreetmap",
        attribution: "Powered by Geoapify | © OpenStreetMap contributors",
        source_license: "https://www.openstreetmap.org/copyright",
      };
      const key = JSON.stringify(place);
      if (seen.has(key)) return null;
      seen.add(key);
      return place;
    })
    .filter(Boolean);
}

export async function boundedJson(response, maximum, timeoutMs = 2000) {
  if (!response.body) throw new LocationFailure("malformed_response");
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  let expired = false;
  const timer = setTimeout(() => {
    expired = true;
    void reader.cancel().catch(() => {});
  }, timeoutMs);
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (expired) throw new LocationFailure("timeout");
      if (done) break;
      length += value.byteLength;
      if (length > maximum) throw new LocationFailure("malformed_response");
      chunks.push(value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    try {
      return JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      );
    } catch {
      throw new LocationFailure("malformed_response");
    }
  } finally {
    clearTimeout(timer);
    await reader.cancel().catch(() => {});
  }
}

export async function autocomplete({
  query,
  language,
  key,
  enabled,
  fetcher = fetch,
}) {
  if (!enabled) throw new LocationFailure("disabled");
  if (!key) throw new LocationFailure("unconfigured");
  if (!["it", "en"].includes(language))
    throw new LocationFailure("invalid_request");
  const url = new URL("https://api.geoapify.com/v1/geocode/autocomplete");
  url.search = new URLSearchParams({
    text: normalizeQuery(query),
    lang: language,
    filter: "countrycode:it",
    bias: "proximity:11.1217,46.0748",
    limit: "5",
    format: "json",
    apiKey: key,
  }).toString();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3500);
  try {
    // No caller headers, user position, arbitrary URL or retries; redirects could
    // disclose the key and therefore fail instead of being followed.
    const response = await fetcher(url, {
      signal: controller.signal,
      redirect: "error",
    });
    if ([401, 403].includes(response.status))
      throw new LocationFailure("invalid_credentials");
    if (response.status === 429) throw new LocationFailure("provider_quota");
    if (!response.ok) throw new LocationFailure("provider_http");
    return normalizeResults(await boundedJson(response, 65536), language);
  } catch (error) {
    if (error instanceof LocationFailure) throw error;
    throw new LocationFailure(
      controller.signal.aborted ? "timeout" : "offline",
    );
  } finally {
    clearTimeout(timer);
  }
}
