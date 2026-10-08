# Server function boundaries

`location-search/` owns the authenticated MAP01 search/selection adapter.
`provider.mjs` normalizes the fixed Geoapify autocomplete response;
`handler.mjs` validates scope and reserves canonical database budgets;
`index.ts` supplies Edge runtime Auth/REST transport and server-only secrets.
The per-function `.env.example` is disabled and contains no key.

Pure module fixtures run through `scripts/lib/location-search.test.mjs` in the
normal tooling/Web gate, without external traffic. PostgreSQL owns receipts,
durable writes, permissions and hard budgets. See the [contract and runbook](../../docs/development/map01-geoapify-location.md).
