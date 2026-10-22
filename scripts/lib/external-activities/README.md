# External activity import boundary

- `transport.mjs` owns explicit code-owned HTTPS API origins, redirect checks,
  streamed byte/request/page/lookup budgets, deadlines and capped Retry-After.
- `records.mjs` validates already mapped canonical plain-text records and exact
  occurrences. It does not parse municipal responses, HTML or recurrence prose.
- `importer.mjs` composes collection, canonical validation and atomic service-only
  persistence. It exposes the deliberately blocked official connector boundary.
- `../../import-external-activities.mjs` owns explicit CLI modes/targets and safe
  process failure reporting. No user-supplied provider URL or connector module.

Tests live in `../external-activities.test.mjs` so the existing tooling test
command discovers them. The source-independent contract, constants, target
configuration and activation gates are recorded in the ACTAPI01 runbook under
`docs/development/`. No fixture connector is reachable through the CLI.
