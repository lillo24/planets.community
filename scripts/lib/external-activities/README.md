# External activity import boundary

- `transport.mjs` owns explicit code-owned HTTPS API origins, redirect checks,
  streamed byte/request/page/lookup budgets, deadlines and capped Retry-After.
- `records.mjs` validates already mapped canonical plain-text records and exact
  occurrences. It does not parse municipal responses, HTML or recurrence prose.
- `catalogue.mjs` validates bounded course terms/weekly rules/exceptions and
  explicitly published venue/locality geometry. It never derives prose or GPS.
- `importer.mjs` composes collection, canonical validation and atomic service-only
  persistence. It exposes the deliberately blocked official connector boundary.
- `../../import-external-activities.mjs` owns explicit CLI modes/targets and safe
  process failure reporting. No user-supplied provider URL or connector module.

Tests live in `../external-activities.test.mjs` and `../external-catalogue.test.mjs` so the existing tooling test
command discovers them. The source-independent contract, constants, target
configuration and activation gates are recorded in the ACTAPI01 runbook under
`docs/development/`. No fixture connector is reachable through the CLI.
The additive event/course/place contract and V1/V2 rollout are documented in
`docs/development/actcat02-catalogue-contract.md`.
