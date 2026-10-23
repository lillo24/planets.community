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
- `operations.mjs` composes sequential explicit source sets with a parent deadline,
  private cadence, independent outcomes and service-only operator projections.
  `../../operate-external-activities.mjs` owns signals and safe process exit.

Tests live in `../external-activities.test.mjs` and `../external-catalogue.test.mjs` so the existing tooling test
command discovers them. The source-independent contract, constants, target
configuration and activation gates are recorded in the ACTAPI01 runbook under
`docs/development/`. No fixture connector is reachable through the CLI.
The additive event/course/place contract and V1/V2 rollout are documented in
`docs/development/actcat02-catalogue-contract.md`.

ACTSRC02: `connectors.mjs` is the bounded code-owned source/capability resolver;
Agenda Trento remains rights-blocked. Public link origin sets are separate from
API transport origins. `transport.mjs` also owns explicit-MIME UTF-8 CSV/text
reads with the same budgets. `../external-multi-source-verifier.mjs` is invoked
only by the guarded disposable-local verifier and exercises real HTTP A/A and A/B
races and cross-source preservation. Tests are in `../external-multi-source.test.mjs`.
See the [source policy/operations contract](../../../docs/development/activities-sources.md).

`trento-facilities.mjs` owns only the licensed municipal CSV shape, controlled
sports types, published Item identity and one safe anchor-field extraction. It
never scrapes linked HTML or manufactures course/event data. The explicit local
`verify-local-trento-facilities.mjs` command qualifies real ingestion separately
from deterministic CI; captured anonymous DTOs can drive opt-in widget evidence.
