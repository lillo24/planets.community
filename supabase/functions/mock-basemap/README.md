# Mock public basemap boundary

`handler.mjs` owns the image-only POST schema and reserve/fetch/finish sequence.
`runtime.mjs` owns the two fixed trust anchors, mock Auth/session proof and
normal service-only metering transport. `index.ts` binds those adapters to Deno.

This function deploys on **normal staging**, separately from `map-provider`.
Only this function has `verify_jwt=false`: every request authenticates inside
the handler against mock Auth and the mock-only `mock_basemap_identity_v1` RPC.
Its request contains fixed osm-carto XYZ/version/cache-only fields and no actor,
item, search, location record or provider URL. No browser Origin is accepted.

The two reservation/finish RPCs share normal staging's canonical global ledger,
public cache, TTL, circuit and licenses. Mock-only caps cannot increase that
ceiling. Provider bytes are bounded to 256 KiB/256px with no redirects/retries.
Cache responses are no-store and contain only v2 public-source metadata/pixels.

Defaults are disabled. See `.env.example` and the
[activation, rollback and evidence runbook](../../../docs/development/mapmock01-public-basemap.md).
No deployment or spending activation is implied by source installation.
