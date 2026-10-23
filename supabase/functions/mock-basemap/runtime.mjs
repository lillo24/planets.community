import { boundedJson } from "../location-search/provider.mjs";
import { createMockBasemapHandler } from "./handler.mjs";

export const MOCK_ORIGIN = "https://pnolarmzxmmjtguligfc.supabase.co";
export const NORMAL_ORIGIN = "https://cllpvruvrrvxczjitlqd.supabase.co";

// Fixed remote trust anchors; tests translate these exact URLs to two independent
// disposable local realms through an injected transport. No caller URL is used.
export function createRuntime({
  enabled = false,
  normalOrigin,
  service = "",
  mockPublicKey = "",
  key = "",
  fetcher = fetch,
}) {
  const json = async (url, headers, body, maximum = 400000) => {
    const response = await fetcher(url, {
      method: body === undefined ? "GET" : "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(2000),
      redirect: "error",
      cache: "no-store",
    });
    if (!response.ok) return null;
    return boundedJson(response, maximum);
  };
  return createMockBasemapHandler({
    enabled: enabled && normalOrigin === NORMAL_ORIGIN,
    key:
      service && /^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(mockPublicKey)
        ? key
        : "",
    authenticate: async (authorization) => {
      if (
        !authorization ||
        !/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(
          authorization,
        ) ||
        authorization.length > 8192
      )
        return null;
      const headers = { apikey: mockPublicKey, Authorization: authorization };
      const user = await json(
        MOCK_ORIGIN + "/auth/v1/user",
        headers,
        undefined,
        16384,
      );
      if (!user?.id) return null;
      // PostgREST verifies this same bearer against mock signing keys. The SQL
      // verifier checks auth.sessions, active delivery, persona and environment.
      return json(
        MOCK_ORIGIN + "/rest/v1/rpc/mock_basemap_identity_v1",
        headers,
        {},
        1024,
      );
    },
    rpc: async (name, args) => {
      if (
        ![
          "reserve_mock_basemap_tile_v1",
          "finish_mock_basemap_tile_v1",
        ].includes(name)
      )
        throw new Error("Invalid tile operation");
      const value = await json(
        NORMAL_ORIGIN + "/rest/v1/rpc/" + name,
        { apikey: service, Authorization: "Bearer " + service },
        args,
      );
      if (!value) throw new Error("Mock tile metering unavailable");
      return value;
    },
    fetcher,
  });
}
