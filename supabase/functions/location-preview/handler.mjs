import { boundedJson } from "../location-search/provider.mjs";
import { PreviewFailure, renderStatic, validatePng } from "./provider.mjs";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const headers = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "X-Content-Type-Options": "nosniff",
};
const reply = (status, code = 200) =>
  new Response(JSON.stringify({ status }), {
    status: code,
    headers: { ...headers, "Content-Type": "application/json" },
  });
const toBase64 = (bytes) => {
  let text = "";
  for (const value of bytes) text += String.fromCharCode(value);
  return btoa(text);
};
const fromBase64 = (text) => {
  if (typeof text !== "string" || text.length > 710000)
    throw new PreviewFailure("invalid_image");
  return validatePng(
    Uint8Array.from(atob(text.replace(/\s/g, "")), (c) => c.charCodeAt(0)),
  );
};

// The request contains identifiers/view only. Auth and both canonical reads are
// independent of service-only credit/cache RPCs. No protected image is cached.
export function createPreviewHandler({
  enabled = false,
  key = "",
  authenticate,
  read,
  rpc,
  fetcher,
}) {
  return async (request) => {
    let claim,
      projection,
      cacheable = false;
    try {
      if (request.method === "OPTIONS")
        return new Response(null, { status: 204, headers });
      if (request.method !== "POST" || new URL(request.url).search)
        return reply("invalid_request", 400);
      if (!enabled) return reply("disabled");
      if (!key) return reply("unconfigured");
      const body = await boundedJson(request, 2048);
      const allowed = [
        "item_kind",
        "item_id",
        "view",
        "expected_profile_id",
        "revision",
        "image_key",
      ];
      if (
        !body ||
        typeof body !== "object" ||
        Array.isArray(body) ||
        Object.keys(body).some((k) => !allowed.includes(k)) ||
        !["one_time", "recurring", "resource"].includes(body.item_kind) ||
        !uuid.test(body.item_id) ||
        !["card", "public_detail", "protected_detail"].includes(body.view) ||
        !Number.isSafeInteger(body.revision) ||
        body.revision < 0 ||
        typeof body.image_key !== "string" ||
        !/^[a-f0-9]{64}$/.test(body.image_key)
      )
        return reply("invalid_request", 400);
      let actor = null;
      if (body.view === "protected_detail") {
        actor = await authenticate(request.headers.get("Authorization"));
        if (
          !actor ||
          actor !== body.expected_profile_id ||
          !uuid.test(actor) ||
          body.item_kind === "resource"
        )
          return reply("unauthorized", 403);
      } else if (body.expected_profile_id != null)
        return reply("invalid_request", 400);
      const authorization =
        body.view === "protected_detail"
          ? request.headers.get("Authorization")
          : null;
      const args = {
        p_kind: body.item_kind,
        p_item: body.item_id,
        p_view: body.view,
        p_expected_profile_id: actor,
      };
      projection = await read(args, authorization);
      if (!projection?.place) return reply("unavailable");
      if (
        projection.revision !== body.revision ||
        projection.image_key !== body.image_key
      )
        return reply("stale", 409);
      if (
        projection.item_kind !== body.item_kind ||
        projection.item_id !== body.item_id ||
        (body.view === "card" &&
          body.item_kind !== "resource" &&
          projection.scope !== "area") ||
        (body.view !== "protected_detail" && projection.audience !== "public")
      )
        return reply("unauthorized", 403);
      cacheable =
        projection.audience === "public" && projection.scope === "area";
      claim = await rpc("reserve_location_preview_v1", {
        p_image_key: projection.image_key,
        p_cacheable: cacheable,
        p_actor: actor,
      });
      if (claim.status !== "ok") return reply(claim.status);
      const bytes = claim.cached
        ? fromBase64(claim.image_base64)
        : await renderStatic({ projection, key, enabled, fetcher });
      // Recheck after upstream/cache I/O. Visibility/role/revision changes cannot
      // release bytes for the earlier authorization snapshot.
      const current = await read(args, authorization);
      if (
        !current?.place ||
        current.revision !== projection.revision ||
        current.image_key !== projection.image_key ||
        current.audience !== projection.audience
      )
        throw new PreviewFailure("stale");
      if (!claim.cached && cacheable) {
        await rpc("finish_location_preview_v1", {
          p_image_key: projection.image_key,
          p_token: claim.token,
          p_image_base64: toBase64(bytes),
        });
        claim = null;
      }
      // functions_client 2.7.1 decodes image/png as UTF-8; use its binary transport.
      return new Response(bytes, {
        headers: { ...headers, "Content-Type": "application/octet-stream" },
      });
    } catch (error) {
      if (claim && !claim.cached && cacheable && projection) {
        try {
          await rpc("finish_location_preview_v1", {
            p_image_key: projection.image_key,
            p_token: claim.token,
            p_image_base64: null,
          });
        } catch {
          /* Explicit failed response below; no image or success fallback. */
        }
      }
      return reply(
        error instanceof PreviewFailure
          ? error.status
          : error?.status === "unauthorized"
            ? "unauthorized"
            : "unavailable",
      );
    }
  };
}
