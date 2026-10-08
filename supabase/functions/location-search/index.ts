import { createHandler, locationRpcFailure } from "./handler.mjs";
import { boundedJson } from "./provider.mjs";

const enabled = Deno.env.get("LOCATION_SEARCH_ENABLED") === "true";
const key = Deno.env.get("GEOAPIFY_API_KEY") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Runtime-provided secrets stay server-side. Explicit Auth validation also works
// on self-hosted runtimes where gateway JWT verification is configured differently.
Deno.serve(
  createHandler({
    enabled,
    key,
    authenticate: async (authorization: string | null) => {
      if (!authorization?.startsWith("Bearer ")) return null;
      const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: { apikey: serviceKey, Authorization: authorization },
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      });
      if (!response.ok) return null;
      return (await boundedJson(response, 16384)).id ?? null;
    },
    rpc: async (name: string, args: unknown) => {
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      });
      const result = await boundedJson(response, 32768);
      if (!response.ok) {
        throw locationRpcFailure(result.code);
      }
      return result;
    },
  }),
);
