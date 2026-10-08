import { createPreviewHandler } from "./handler.mjs";
import { boundedJson } from "../location-search/provider.mjs";
import { PreviewFailure } from "./provider.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
async function call(
  name: string,
  args: unknown,
  authorization: string,
  key: string,
) {
  const response = await fetch(supabaseUrl + "/rest/v1/rpc/" + name, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(2000),
    redirect: "error",
  });
  const data = await boundedJson(response, 750000);
  if (!response.ok)
    throw new PreviewFailure(
      data.code === "42501" ? "unauthorized" : "unavailable",
    );
  return data;
}
Deno.serve(
  createPreviewHandler({
    enabled: Deno.env.get("LOCATION_PREVIEW_ENABLED") === "true",
    key: Deno.env.get("GEOAPIFY_STATIC_MAPS_KEY") ?? "",
    authenticate: async (authorization: string | null) => {
      if (!authorization?.startsWith("Bearer ")) return null;
      const response = await fetch(supabaseUrl + "/auth/v1/user", {
        headers: { apikey: anonKey, Authorization: authorization },
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      });
      if (!response.ok) return null;
      return (await boundedJson(response, 16384)).id ?? null;
    },
    read: (args: unknown, authorization: string | null) =>
      call(
        "get_location_preview_v1",
        args,
        authorization ?? "Bearer " + anonKey,
        anonKey,
      ),
    rpc: (name: string, args: unknown) =>
      call(name, args, "Bearer " + serviceKey, serviceKey),
  }),
);
