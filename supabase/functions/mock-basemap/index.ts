import { createRuntime } from "./runtime.mjs";
Deno.serve(
  createRuntime({
    enabled:
      Deno.env.get("LOCATION_MOCK_BASEMAP_ENABLED") === "true" &&
      Deno.env.get("LOCATION_MAP_TILES_ENABLED") === "true",
    normalOrigin: Deno.env.get("SUPABASE_URL") ?? "",
    service: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    mockPublicKey: Deno.env.get("MOCK_SUPABASE_PUBLISHABLE_KEY") ?? "",
    key: Deno.env.get("GEOAPIFY_MAPS_KEY") ?? "",
  }),
);
