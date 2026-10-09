# Server function boundaries

`location-search/` owns the authenticated MAP01 search/selection adapter.
`provider.mjs` normalizes the fixed Geoapify autocomplete response;
`handler.mjs` validates scope and reserves canonical database budgets;
`index.ts` supplies Edge runtime Auth/REST transport and server-only secrets.
The per-function `.env.example` is disabled and contains no key.

Pure module fixtures run through `scripts/lib/location-search.test.mjs` in the
normal tooling/Web gate, without external traffic. PostgreSQL owns receipts,
durable writes, permissions and hard budgets. See the [contract and runbook](../../docs/development/map01-geoapify-location.md).

location-preview/ owns MAP03's disabled static-image endpoint. provider.mjs fixes
upstream options and bounds PNGs; handler.mjs validates identifiers/view, reads
current public/user authorization, reserves credits and rechecks before delivery;
index.ts supplies separate anonymous/user/service transports and server secrets.
See [MAP03](../../docs/development/map03-location-previews.md).

`map-provider/` owns MAP05's separate authenticated center/selection and fixed
XYZ tile adapter. It shares the exact quarter-credit account ceiling with the
two existing adapters, accepts no arbitrary URL or client actor claims, and
ships disabled. Its README maps the pure handler, upstream bounds and Deno
bindings; [MAP05](../../docs/development/map05-interactive-discovery.md) owns
activation, guest restrictions, transient caching and shutdown.
