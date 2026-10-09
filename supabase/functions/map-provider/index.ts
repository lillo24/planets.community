import { createMapProviderHandler } from "./handler.mjs";
import { boundedJson } from "../location-search/provider.mjs";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
Deno.serve(
  createMapProviderHandler({
    centersEnabled: Deno.env.get("LOCATION_MAP_CENTERS_ENABLED") === "true",
    tilesEnabled: Deno.env.get("LOCATION_MAP_TILES_ENABLED") === "true",
    key: Deno.env.get("GEOAPIFY_MAPS_KEY") ?? "",
    authenticate: async (authorization: string | null) => {
      if (!authorization?.startsWith("Bearer ")) return null;
      const response = await fetch(url + "/auth/v1/user", {
        headers: { apikey: serviceKey, Authorization: authorization },
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      });
      if (!response.ok) return null;
      return (await boundedJson(response, 16384)).id ?? null;
    },
    rpc: async (name: string, args: unknown) => {
      const allowed = [
        "reserve_map_provider_v1",
        "finish_map_provider_v1",
        "resolve_map_center_v1",
      ];
      if (!allowed.includes(name)) throw new Error("Invalid adapter operation");
      const response = await fetch(url + "/rest/v1/rpc/" + name, {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: "Bearer " + serviceKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      });
      const data = await boundedJson(response, 400000);
      if (!response.ok) throw new Error("Map metering unavailable");
      return data;
    },
  }),
);
