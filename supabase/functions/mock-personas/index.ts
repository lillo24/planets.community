import { createRuntime } from "./runtime.mjs";
Deno.serve(createRuntime({
  enabled: Deno.env.get("MOCK_BROKER_ENABLED") === "true",
  service: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  normalKey: Deno.env.get("MOCK_NORMAL_PUBLISHABLE_KEY") ?? "",
  deliveryKey: Deno.env.get("MOCK_DELIVERY_KEY") ?? "",
  normalOrigin: Deno.env.get("MOCK_NORMAL_ORIGIN") ?? "",
  mockOrigin: Deno.env.get("SUPABASE_URL") ?? "",
}));
