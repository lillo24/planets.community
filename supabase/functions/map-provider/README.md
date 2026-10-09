# MAP05 provider boundary

`handler.mjs` owns a strict authenticated search/resolve/tile API with injectable
Auth, service-only quota/cache RPCs and upstream transport. It does not reuse
MAP01 editor sessions or mutate listing locations. Guests are always denied;
forwarded IPs and installation identifiers have no authority.

`provider.mjs` accepts only osm-carto v1 XYZ tiles, zoom 7–18, 256×256 PNG,
256 KiB maximum, fixed HTTPS Geoapify URL, no redirects, 3.5s deadline and no
retries/prefetch. Autocomplete shares only MAP01's fixed Italy/Trento upstream
normalizer, discarding provider IDs before the five-minute actor-local cache.

`index.ts` binds the pure handler to Deno environment configuration and Supabase
Auth/REST, compatible with local/self-hosted runtimes. All flags and credentials
are absent/disabled by default. See the MAP05 activation runbook before enabling
`LOCATION_MAP_CENTERS_ENABLED`, `LOCATION_MAP_TILES_ENABLED`, `GEOAPIFY_MAPS_KEY`
or the database account-wide gate. No client key or public provider URL exists.

The disabled `.env.example` is the configuration template. The
[activation runbook](../../../docs/development/map05-interactive-discovery.md)
also describes the shared quarter-unit ledger, TTL validity versus physical
pruning, guest restrictions, license gates and shutdown/rotation order.
