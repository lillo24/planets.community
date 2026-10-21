import { createHandler } from "./handler.mjs";

Deno.serve(
  createHandler({
    policySource: Deno.env.get("PLANETS_CLIENT_COMPATIBILITY_POLICY") ?? "",
  }),
);
