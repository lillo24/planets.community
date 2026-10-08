import {
  autocomplete,
  boundedJson,
  LocationFailure,
  normalizeQuery,
} from "./provider.mjs";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const reply = (status, data = {}, code = 200) =>
  new Response(JSON.stringify({ status, ...data }), {
    status: code,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });

// Dependencies keep credentials, auth, metering and HTTP fakeable independently.
export function createHandler({
  enabled = false,
  key = "",
  authenticate,
  rpc,
  fetcher,
  metric = () => {},
}) {
  return async (request) => {
    let status = "server_failure";
    const respond = (value, data = {}, code = 200) => {
      status = value;
      return reply(value, data, code);
    };
    try {
      if (request.method !== "POST" || new URL(request.url).search)
        return respond("invalid_request", {}, 400);
      if (!enabled) return respond("disabled");
      if (!key) return respond("unconfigured");
      const actor = await authenticate(request.headers.get("Authorization"));
      if (!actor || !uuid.test(actor)) return respond("unauthorized", {}, 401);
      const body = await boundedJson(request, 4096);
      const allowed = [
        "operation",
        "expected_profile_id",
        "item_kind",
        "item_id",
        "revision",
        "slot",
        "session_token",
        "query",
        "language",
        "receipt_id",
      ];
      if (
        !body ||
        typeof body !== "object" ||
        Array.isArray(body) ||
        Object.keys(body).some((k) => !allowed.includes(k)) ||
        body.expected_profile_id !== actor ||
        !uuid.test(body.item_id) ||
        !["one_time", "recurring", "resource"].includes(body.item_kind) ||
        !Number.isSafeInteger(body.revision) ||
        body.revision < 0 ||
        !(body.item_kind === "resource"
          ? body.slot === "public"
          : ["area", "exact"].includes(body.slot)) ||
        typeof body.session_token !== "string" ||
        !uuid.test(body.session_token)
      )
        throw new LocationFailure("invalid_request");
      const scope = {
        p_actor: actor,
        p_kind: body.item_kind,
        p_item: body.item_id,
        p_revision: body.revision,
        p_slot: body.slot,
        p_session: body.session_token,
      };
      if (body.operation === "resolve") {
        if (
          !uuid.test(body.receipt_id) ||
          body.query != null ||
          body.language != null
        )
          throw new LocationFailure("invalid_request");
        const result = await rpc("resolve_location_selection_v1", {
          ...scope,
          p_receipt: body.receipt_id,
        });
        status = result.status;
        return reply(
          status,
          status === "ok" ? { selection: result.selection } : {},
        );
      }
      if (
        body.operation !== "search" ||
        body.receipt_id != null ||
        !["it", "en"].includes(body.language)
      )
        throw new LocationFailure("invalid_request");
      const query = normalizeQuery(body.query);
      // No search text reaches PostgreSQL. Hash is server-derived; it is used
      // only in a five-minute actor/item/session cache, never analytics.
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(`${body.language}\n${query}`),
      );
      const hash = Array.from(new Uint8Array(digest), (b) =>
        b.toString(16).padStart(2, "0"),
      ).join("");
      const reserved = await rpc("reserve_location_search_v1", {
        ...scope,
        p_query_hash: hash,
      });
      if (reserved.status !== "ok") {
        status = reserved.status;
        return reply(status);
      }
      if (reserved.cached) {
        status = "ok";
        return reply("ok", { suggestions: reserved.suggestions });
      }
      const places = await autocomplete({
        query,
        language: body.language,
        key,
        enabled,
        fetcher,
      });
      const result = await rpc("issue_location_selections_v1", {
        p_batch: reserved.batch_id,
        p_places: places,
      });
      status = result.status;
      return reply(
        status,
        status === "ok" ? { suggestions: result.suggestions } : {},
      );
    } catch (error) {
      status =
        error instanceof LocationFailure
          ? error.status
          : "metering_unavailable";
      return reply(status, {}, status === "invalid_request" ? 400 : 200);
    } finally {
      // Counts/status only. Never log request objects, URLs, errors, labels,
      // receipts, actors, JWTs, coordinates or provider payloads.
      metric(status);
    }
  };
}
