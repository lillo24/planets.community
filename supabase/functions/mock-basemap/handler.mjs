import { boundedJson, LocationFailure } from "../location-search/provider.mjs";
import { validateTile } from "../map-provider/provider.mjs";
import { basemapTileV2 } from "../map-provider/basemap.mjs";

const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
};
const keys = ["operation", "z", "x", "y", "style", "version", "cache_only"];
const scope = /^[a-f0-9]{64}$/;

// Separate cross-issuer boundary. No CORS allowance, asserted actor, product
// selector, arbitrary URL or style is accepted. Ordinary map-provider is intact.
export function createMockBasemapHandler({
  enabled = false,
  key = "",
  authenticate,
  rpc,
  fetcher,
}) {
  return async (request) => {
    const reply = (status, data = {}, code = 200) =>
      new Response(JSON.stringify({ status, ...data }), {
        status: code,
        headers,
      });
    try {
      if (
        request.method !== "POST" ||
        new URL(request.url).search ||
        request.headers.has("origin")
      )
        return reply("invalid_request", {}, 400);
      if (!enabled) return reply("disabled");
      if (!key) return reply("unconfigured");
      let body;
      try {
        body = await boundedJson(request, 1024);
      } catch {
        return reply("invalid_request", {}, 400);
      }
      if (
        !body ||
        Array.isArray(body) ||
        Object.keys(body).length !== keys.length ||
        Object.keys(body).some((k) => !keys.includes(k)) ||
        body.operation !== "basemap_tile_v2" ||
        typeof body.cache_only !== "boolean"
      )
        return reply("invalid_request", {}, 400);
      validateTile(body);
      const authorization = request.headers.get("authorization");
      const identity = await authenticate(authorization);
      if (
        !identity ||
        !scope.test(identity.actor_scope) ||
        !scope.test(identity.client_scope)
      )
        return reply("unauthorized", {}, 401);
      const result = await basemapTileV2({
        body,
        key,
        fetcher: (url, init) =>
          (fetcher ?? fetch)(url, {
            ...init,
            signal: AbortSignal.any([init.signal, request.signal]),
          }),
        rpc: async (name, args) => {
          if (name === "reserve_basemap_tile_v2") {
            return rpc("reserve_mock_basemap_tile_v1", {
              p_actor_scope: identity.actor_scope,
              p_client_scope: identity.client_scope,
              p_z: body.z,
              p_x: body.x,
              p_y: body.y,
              p_cache_only: body.cache_only,
            });
          }
          if (name !== "finish_basemap_tile_v2")
            throw new Error("Invalid tile operation");
          // Recheck revocation/retirement after provider IO. A completed request
          // remains charged, but a retired persona never receives late pixels.
          const current = await authenticate(authorization);
          const valid =
            current?.actor_scope === identity.actor_scope &&
            current?.client_scope === identity.client_scope;
          // Finish the already-authorized public acquisition truthfully even
          // after retirement. Discarding a valid PNG would incorrectly trip
          // the shared provider failure circuit on a client Auth transition.
          // The shared cache contains no private data; never return it here
          // when the initiating session has lost its entitlement.
          const finished = await rpc("finish_mock_basemap_tile_v1", args);
          return valid ? finished : { status: "unauthorized" };
        },
      });
      if (result.status !== "ok") {
        const allowed = new Set([
          "disabled",
          "unconfigured",
          "unauthorized",
          "rate_limited",
          "budget_exhausted",
          "pending",
          "expired",
          "cache_miss",
          "unavailable",
          "provider_failure",
          "invalid_image",
          "timeout",
        ]);
        return reply(
          allowed.has(result.status) ? result.status : "unavailable",
          {
            retry_after_seconds: result.retry_after_seconds ?? 0,
          },
        );
      }
      // Never forward a reservation token, identity, RPC diagnostics or extras.
      const data = Object.fromEntries(
        [
          "cached",
          "source",
          "acquired_at",
          "expires_at",
          "server_time",
          "budget_exhausted",
          "retry_after_seconds",
          "image_base64",
        ].map((k) => [k, result[k]]),
      );
      return reply("ok", data);
    } catch (error) {
      return reply(
        error instanceof LocationFailure && error.status === "invalid_request"
          ? "invalid_request"
          : "unavailable",
        {},
        error instanceof LocationFailure && error.status === "invalid_request"
          ? 400
          : 200,
      );
    }
  };
}
