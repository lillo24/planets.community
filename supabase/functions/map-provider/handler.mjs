import {
  autocomplete,
  boundedJson,
  LocationFailure,
  normalizeQuery,
} from "../location-search/provider.mjs";
import { fetchTile, validateTile, validateTilePng } from "./provider.mjs";

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const headers = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};
const reply = (status, data = {}, code = 200) =>
  new Response(JSON.stringify({ status, ...data }), {
    status: code,
    headers: { ...headers, "Content-Type": "application/json" },
  });
const digest = async (text) =>
  Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)),
    ),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
const base64 = (bytes) => {
  let text = "";
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text);
};
const unbase64 = (text) => {
  if (typeof text !== "string" || text.length > 350000)
    throw new LocationFailure("invalid_image");
  return validateTilePng(
    Uint8Array.from(atob(text.replace(/\s/g, "")), (c) => c.charCodeAt(0)),
  );
};

// New API boundary: no item/revision/slot/editor receipts, caller coordinates,
// provider IDs, arbitrary URLs, IP headers or user claims are admitted.
export function createMapProviderHandler({
  tilesEnabled = false,
  centersEnabled = false,
  key = "",
  authenticate,
  rpc,
  fetcher,
  metric = () => {},
}) {
  return async (request) => {
    let status = "unavailable",
      claim,
      cacheKey;
    const respond = (value, data = {}, code = 200) => {
      status = value;
      return reply(value, data, code);
    };
    try {
      if (request.method === "OPTIONS")
        return new Response(null, { status: 204, headers });
      if (request.method !== "POST" || new URL(request.url).search)
        return respond("invalid_request", {}, 400);
      if (!tilesEnabled && !centersEnabled) return respond("disabled");
      if (!key) return respond("unconfigured");
      let body;
      try {
        body = await boundedJson(request, 2048);
      } catch {
        return respond("invalid_request", {}, 400);
      }
      const allowed =
        body?.operation === "tile"
          ? [
              "operation",
              "expected_profile_id",
              "z",
              "x",
              "y",
              "style",
              "version",
            ]
          : body?.operation === "search"
            ? ["operation", "expected_profile_id", "query", "language"]
            : body?.operation === "resolve"
              ? ["operation", "expected_profile_id", "suggestion_id"]
              : [];
      if (
        !body ||
        typeof body !== "object" ||
        Array.isArray(body) ||
        !allowed.length ||
        Object.keys(body).some((k) => !allowed.includes(k)) ||
        !uuid.test(body.expected_profile_id)
      ) {
        return respond("invalid_request", {}, 400);
      }
      const isTile = body.operation === "tile";
      if (isTile ? !tilesEnabled : !centersEnabled) return respond("disabled");
      let query, tile;
      if (isTile) tile = validateTile(body);
      else if (body.operation === "search") {
        query = normalizeQuery(body.query);
        if (!["it", "en"].includes(body.language))
          return respond("invalid_request", {}, 400);
      } else if (!uuid.test(body.suggestion_id))
        return respond("invalid_request", {}, 400);
      const actor = await authenticate(request.headers.get("Authorization"));
      if (!actor) return respond("guest_disabled", {}, 401);
      if (!uuid.test(actor) || actor !== body.expected_profile_id)
        return respond("unauthorized", {}, 403);
      if (body.operation === "resolve") {
        const resolved = await rpc("resolve_map_center_v1", {
          p_actor: actor,
          p_suggestion: body.suggestion_id,
        });
        return respond(
          resolved.status,
          resolved.status === "ok" ? { center: resolved.center } : {},
        );
      }
      cacheKey = await digest(
        isTile
          ? `tile:v1:osm-carto:${tile.z}:${tile.x}:${tile.y}`
          : `center:v1:${actor}:${body.language}:${query}`,
      );
      claim = await rpc("reserve_map_provider_v1", {
        p_actor: actor,
        p_kind: isTile ? "tile" : "center",
        p_cache_key: cacheKey,
      });
      if (claim.status !== "ok") return respond(claim.status);
      if (!isTile) {
        if (claim.cached)
          return respond("ok", { suggestions: claim.suggestions });
        // Reuse only the fixed upstream adapter/sanitizer, never the item editor API.
        const places = await autocomplete({
          query,
          language: body.language,
          key,
          enabled: centersEnabled,
          fetcher,
        });
        const centers = places.map((p) => ({
          label: p.label,
          latitude: p.latitude,
          longitude: p.longitude,
          country_code: "it",
        }));
        const finished = await rpc("finish_map_provider_v1", {
          p_cache_key: cacheKey,
          p_token: claim.token,
          p_centers: centers,
        });
        claim = null;
        return respond(
          finished.status,
          finished.status === "ok" ? { suggestions: finished.suggestions } : {},
        );
      }
      const bytes = claim.cached
        ? unbase64(claim.image_base64)
        : await fetchTile({
            tile: { ...tile, style: "osm-carto", version: 1 },
            key,
            enabled: tilesEnabled,
            fetcher,
          });
      if (!claim.cached) {
        const finished = await rpc("finish_map_provider_v1", {
          p_cache_key: cacheKey,
          p_token: claim.token,
          p_image_base64: base64(bytes),
        });
        claim = null;
        if (finished.status !== "ok") return respond(finished.status);
      }
      status = "ok";
      // Binary transport avoids functions_client UTF-8 decoding of image/png.
      return new Response(bytes, {
        headers: { ...headers, "Content-Type": "application/octet-stream" },
      });
    } catch (error) {
      if (claim && !claim.cached && cacheKey) {
        try {
          await rpc("finish_map_provider_v1", {
            p_cache_key: cacheKey,
            p_token: claim.token,
          });
        } catch {
          /* Report the explicit failed operation; never send stale bytes. */
        }
      }
      const invalid =
        error instanceof LocationFailure && error.status === "invalid_request";
      return respond(
        invalid ? "invalid_request" : "unavailable",
        {},
        invalid ? 400 : 200,
      );
    } finally {
      // Fixed status counters only: no queries/labels, coordinates, keys, actors,
      // Authorization/request/error objects or provider payloads are logged.
      metric(status);
    }
  };
}
