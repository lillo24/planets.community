export class PreviewFailure extends Error {
  constructor(status) {
    super(status);
    this.status = status;
  }
}
export const WIDTH = 512,
  HEIGHT = 256,
  MAX_BYTES = 524288,
  RESERVED_CREDITS = 4;
const equal = (a, b) => a.length === b.length && a.every((v, i) => v === b[i]);
export function validatePng(bytes) {
  if (
    !(bytes instanceof Uint8Array) ||
    bytes.length < 45 ||
    bytes.length > MAX_BYTES ||
    !equal(bytes.slice(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]) ||
    !equal(bytes.slice(12, 24), [73, 72, 68, 82, 0, 0, 2, 0, 0, 0, 1, 0]) ||
    !equal(bytes.slice(-12), [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130])
  )
    throw new PreviewFailure("invalid_image");
  return bytes;
}
export async function boundedBytes(response, limit = MAX_BYTES) {
  const declared = response.headers.get("content-length");
  if (declared && (!/^\d+$/.test(declared) || Number(declared) > limit))
    throw new PreviewFailure("invalid_image");
  if (!response.body) throw new PreviewFailure("invalid_image");
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > limit) throw new PreviewFailure("invalid_image");
      chunks.push(value);
    }
  } finally {
    await reader.cancel();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}
export async function renderStatic({
  projection,
  key,
  enabled = false,
  fetcher = fetch,
}) {
  if (!enabled) throw new PreviewFailure("disabled");
  if (!key) throw new PreviewFailure("unconfigured");
  const p = projection?.place;
  if (
    !p ||
    !Number.isFinite(p.latitude) ||
    !Number.isFinite(p.longitude) ||
    Math.abs(p.latitude) > 90 ||
    Math.abs(p.longitude) > 180 ||
    !["locality", "address", "amenity"].includes(p.kind) ||
    !["area", "exact"].includes(projection.scope) ||
    (projection.scope === "area") !== (p.kind === "locality")
  )
    throw new PreviewFailure("invalid_request");
  const url = new URL("https://maps.geoapify.com/v1/staticmap");
  url.search = new URLSearchParams({
    style: "osm-carto",
    width: String(WIDTH),
    height: String(HEIGHT),
    scaleFactor: "1",
    format: "png",
    pitch: "0",
    bearing: "0",
    attribution: "default",
    center: "lonlat:" + p.longitude + "," + p.latitude,
    zoom: projection.scope === "area" ? "10" : "16",
    apiKey: key,
    ...(projection.scope === "exact"
      ? {
          marker:
            "lonlat:" +
            p.longitude +
            "," +
            p.latitude +
            ";type:circle;size:32;shadow:no",
        }
      : {}),
  }).toString();
  try {
    const response = await fetcher(url, {
      redirect: "error",
      signal: AbortSignal.timeout(4000),
    });
    if (response.status === 429) throw new PreviewFailure("quota");
    if (
      !response.ok ||
      response.headers.get("content-type")?.split(";")[0].trim() !== "image/png"
    )
      throw new PreviewFailure("invalid_image");
    return validatePng(await boundedBytes(response));
  } catch (error) {
    if (error instanceof PreviewFailure) throw error;
    throw new PreviewFailure(
      error?.name === "TimeoutError" || error?.name === "AbortError"
        ? "timeout"
        : "unavailable",
    );
  }
}
