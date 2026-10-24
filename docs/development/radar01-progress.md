# RADAR01 implementation and local qualification

Branch: `codex/radar01-automatic-local`, initially based on pulled main `4a1003c5`. Delivery is tracked by the [branch PR](https://github.com/lillo24/planets.community/pulls?q=is%3Apr+head%3Acodex%2Fradar01-automatic-local) and protected Validation. Source merge and hosted activation are separate.

Pinned parser/transport packages are delivered separately in [dependency prerequisite #319](https://github.com/lillo24/planets.community/pull/319), as required by the trusted staging policy's separation of dependencies and product SQL. No release policy was changed. The existing activity-verification entrypoint runs legacy and Radar acceptance in sequence.

## Implemented

- Four actual publisher collectors, bounded HTML/JSON-LD/RSS, safe Atom and finite iCalendar/exception adapters, robots, DNS/TLS, delays, deadlines and exact representation validators.
- Private versioned candidates/evidence and shared leases; owner-bound parser/policy-digest qualification, automatic conforming promotion, conflict holds, exact aliases and an owner command for known same-source identity corrections. The service importer cannot approve rights.
- Additive V4 type/date List/Map/facets and signed paging, retaining V1–V3. IT/EN and Rome Today/Weekend controls share canonical filters. Existing provider, map, account/Mock, analytics and participation gates remain.
- Bounded two-batch scheduling, inspection/rejection/qualification/correction and retention. The [runbook](radar01-automatic-activities.md) consolidates activation.

## Actual source evidence (2026-10-24)

| Publisher    | Collected | Factually validated | Public eligible | Held |
| ------------ | --------: | ------------------: | --------------: | ---: |
| MUSE         |        32 |                   5 |               0 |   32 |
| Santa Chiara |       106 |                  48 |               0 |  106 |
| ARCI         |         6 |                   2 |               0 |    6 |
| SUSAT        |        10 |                   1 |               0 |   10 |
| Total        |       154 |                  56 |               0 |  154 |

Each collector wrote actual private candidates on an owned non-default local backend and repeated the same extracted revision without duplicate revisions, then cleaned its configuration/data. These are per-source observations, not one simultaneous historical snapshot. Reuse/publication basis remains unresolved; owner qualification and public enablement stay OFF. No synthetic licence was used for a real publisher. Mixed Santa Chiara seasons retain null type; only named music/cinema programmes supply families.

[Aggregate evidence](evidence/radar01/publisher-qualification.json) separates families, validation reasons, retrieval times, candidate-bearing representations and publication holds. Full pages/contact paragraphs are not committed. RadarTN CSV/ZIP inputs were unavailable: no exact parity or comprehensive Trento coverage claim. UniTrento and Trento Giovani remain assessed alternatives; no replacement source hunt was needed.

## Local verification

- Full database pgTAP: 178 files, 8,642 assertions passed. The six affected suites passed 297 assertions after final qualification/alias changes. Database lint and security advisors passed; types use the standard generator.
- Real synthetic service/anonymous HTTP: old catalogue/concurrency/warmed upgrades/geography/index/cap/operator contracts and Radar promotion, version binding, null-parser denial, repeat/update, failure/absence preservation, exact aliases/owner corrections, disable, private permissions and lease recovery passed.
- Full Flutter analysis/format/tests passed: 4,369 tests and two existing opt-in skips. Android debug APK built. No iOS build or physical-device QA is claimed.
- IT/EN 320/360dp, 2x text, light/dark rendering passed. Inspected synthetic captures: [IT 320 dark](evidence/radar01/radar01-it-320-dark-filters.png), [EN 360 light](evidence/radar01/radar01-en-360-light-filters.png).
- Site tests/lint/types/build/deployment dry-run passed. Web lint/types/build/invitation checks passed. Full web tests passed 405 with two opt-in skips using two workers; the initial default-worker run had one 5s timeout under simultaneous mobile/database/Gradle load, also passing its isolated retry. No test timeout was weakened.
- Focused source tests passed. Root tooling used the real bundled Python ahead of the Windows Store alias, without test changes.

The owned backend is `planets-radar01`, ports 62821–62829, with process-only Podman settings. Its temporary config overlay is excluded from the commit and restored before delivery. Peers remain untouched. The optional official Flutter plugin could not be installed because the existing marketplace points to another source; installed SDK validation was used.

## Remaining activation

No hosted source registration/import, hosted SQL application, scheduler, paid service or public release was performed. Follow the [single activation sequence](radar01-automatic-activities.md#reproduction-and-exact-activation-sequence): authorized migrations, applicable source/field rights, exact parser/policy qualification, disabled registration and private inspection, genuine attribution/licence and public enablement, anonymous acceptance, then separately authorized target/secrets/source-set and schedule activation. Hosted application remains review-required under the existing policy.

The repository-wide Prettier check also reported six untouched pre-existing files (five Markdown files and one verifier); changed-file formatting is checked separately. No unrelated reformatting was included.
