import { LocationFailure } from "../location-search/provider.mjs";

export function validateTile(value) {
  if (
    !value ||
    value.style !== "osm-carto" ||
    value.version !== 1 ||
    !Number.isSafeInteger(value.z) ||
    value.z < 7 ||
    value.z > 18 ||
    !Number.isSafeInteger(value.x) ||
    !Number.isSafeInteger(value.y) ||
    value.x < 0 ||
    value.y < 0 ||
    value.x >= 2 ** value.z ||
    value.y >= 2 ** value.z
  ) {
    throw new LocationFailure("invalid_request");
  }
  return { z: value.z, x: value.x, y: value.y };
}

export function validateTilePng(bytes) {
  const hex = (part) =>
    Array.from(part, (b) => b.toString(16).padStart(2, "0")).join("");
  if (
    !(bytes instanceof Uint8Array) ||
    bytes.length < 45 ||
    bytes.length > 262144 ||
    hex(bytes.subarray(0, 8)) !== "89504e470d0a1a0a" ||
    hex(bytes.subarray(12, 24)) !== "494844520000010000000100" ||
    hex(bytes.subarray(-12)) !== "0000000049454e44ae426082"
  ) {
    throw new LocationFailure("invalid_image");
  }
  return bytes;
}

export async function fetchTile({
  tile,
  key,
  enabled,
  fetcher = fetch,
  timeoutMs = 3500,
}) {
  if (!enabled) throw new LocationFailure("disabled");
  if (!key) throw new LocationFailure("unconfigured");
  const { z, x, y } = validateTile(tile);
  const url = new URL(
    `https://api.geoapify.com/v1/tile/osm-carto/${z}/${x}/${y}.png`,
  );
  url.searchParams.set("apiKey", key);
  const controller = new AbortController();
  let timer, reader;
  const expired = new Promise((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      void reader?.cancel().catch(() => {});
      reject(new LocationFailure("timeout"));
    }, timeoutMs);
  });
  try {
    return await Promise.race([
      expired,
      (async () => {
        const response = await fetcher(url, {
          signal: controller.signal,
          redirect: "error",
          cache: "no-store",
          headers: { Accept: "image/png" },
        });
        if (
          !response.ok ||
          response.headers.get("content-type")?.split(";")[0].trim() !==
            "image/png" ||
          Number(response.headers.get("content-length") ?? 0) > 262144 ||
          !response.body
        ) {
          throw new LocationFailure("provider_failure");
        }
        reader = response.body.getReader();
        const chunks = [];
        let length = 0;
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          length += value.byteLength;
          if (length > 262144) throw new LocationFailure("invalid_image");
          chunks.push(value);
        }
        const bytes = new Uint8Array(length);
        let offset = 0;
        for (const chunk of chunks) {
          bytes.set(chunk, offset);
          offset += chunk.length;
        }
        return validateTilePng(bytes);
      })(),
    ]);
  } catch (error) {
    if (error instanceof LocationFailure) throw error;
    throw new LocationFailure("provider_failure");
  } finally {
    clearTimeout(timer);
    void reader?.cancel().catch(() => {});
    controller.abort();
  }
}
