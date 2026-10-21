import { createRuntime } from "./runtime.mjs";
Deno.serve(createRuntime({
  enabled: Deno.env.get("MOCK_BROKER_ENABLED") === "true",
  service: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  deliveryKey: Deno.env.get("MOCK_DELIVERY_KEY") ?? "",
  mockOrigin: Deno.env.get("SUPABASE_URL") ?? "",
}));
