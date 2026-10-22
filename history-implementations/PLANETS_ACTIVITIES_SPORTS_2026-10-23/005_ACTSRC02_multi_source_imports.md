# ACTSRC02 — independent official sources on one catalogue

Read [001_context.md](001_context.md). Depends on merged 002. Extend the existing importer; do not replace it with a new ingestion platform. After merging, continue to 006.

## Evidence and objective

ACTAPI01 has a one-enabled-source unique index, a single-source public list query, source-scoped leases/versions, a connector resolver that always blocks Agenda Trento, and a runner/workflow hard-coded to that source. It already bounds destinations, bytes, pages, retries and runtime and atomically persists complete imports.

Support a small set of independently configured official adapters and public catalogue reads across their eligible records. A failed or rights-blocked event source must not disable a healthy sports-place source or all catalogue reads.

## Required extension

- Remove the one-active-source restriction **in a new migration**, preserving existing rows and safety constraints. Keep a code-owned bounded connector registry; there is no public arbitrary-source URL or dynamic plugin installation.
- Keep source ID distinct from connector type, upstream ID, native identity and category. An external source can support one or several listing kinds under an explicit declared capability. Use the 002 canonical contracts; do not embed provider shape in Flutter.
- Retain per-source rights/enabled gates, attribution/licence reference, canonical page origins, lease/run isolation, source versions and observation freshness. Only owner configuration can approve/enable publication; service import credentials do not acquire that power.
- API transport destinations and public source links are separate policies. For an aggregator API, an official information page may live on a documented provider/organizer origin different from the API host. Allow only validated, bounded, source-specific HTTPS origin sets or an equivalent narrow policy. Do not globally weaken link/SSRF rules or accept any URL returned by a feed.
- Add a narrow text/CSV decoding path for **006's official municipal export**, while retaining existing HTTPS/redirect/path/decompressed-size/timeout/request budgets. Read a successful exact resource with an explicit accepted content type. No general HTML scraper, arbitrary uploaded CSV ingestion, archive execution or feed-controlled destination discovery.
- Canonical normalization covers events/courses/places and optional descriptions/public geometry from 002. A complete source traversal is explicit; per-record rejection reasons remain counted and bounded. Fail whole snapshots for structural errors/duplicate IDs/unexplained truncated responses, rather than publishing a sudden empty catalogue as success.
- Preserve stable UUID/revision behavior on repeat/update. No cross-source fuzzy merging, URL-only deduplication or deleting records merely absent from one run. Two sources using the same upstream string are still distinct identities; two equipment records at one official page must remain distinct.
- Runs remain atomic and fenced **per source**. Concurrent A/B imports may proceed under bounded execution; concurrent A/A claims retain lease exclusion. Disabling A during a run prevents A's obsolete completion without affecting B. Do not expose database-owner functions or raw run/config tables publicly.
- Public extended list/detail/facets query all eligible sources before bounded pagination. Cursors bind complete filters, reference time and an appropriate source-set/version snapshot. Enabling/disabling, source updates or eligibility changes must invalidate/refresh safely; a stale cursor must never restore a disabled source.
- Preserve old event-reader compatibility from 002, including deterministic event ordering if multiple event sources become eligible. Test the old RPCs rather than dropping them because today's sources are disabled.
- Aggregate health truthfully: healthy results plus a source failure are **partial/degraded**, not total empty/unconfigured. All failed/unconfigured, successfully empty and never-synchronized are distinct. Public health exposes only useful sanitized status/count metadata; private errors, internal URLs and detailed source configuration stay private. A good source must not update another source's record freshness.
- Adapt Dart payload parsing/state and compact health UI as needed. Preserve retained healthy results on one-source trouble, stale-response fencing and inactive/off gates. Do not make client refresh launch upstream imports.

## CLI contract and setup

Preserve explicit `--source`, dry-run/apply and target-verification discipline. Add a bounded allow-listed source-set operation only if useful; one command per explicit source is sufficient for this step. Agenda Trento still returns its distinct rights-checkpoint error. Unknown source, disabled source, no configured sources, malformed source and successful zero eligible records are different outcomes.

Provide an owner-readable source template/evidence record with official metadata/resource URL, supported kinds/coverage, parser version, licence/attribution, allowed origins, freshness policy and activation/disable commands. Keep secrets out. Source metadata can be committed; enabled hosted configuration cannot.

## Verification and done

Use synthetic adapters and a disposable database for:

1. Two sources with colliding upstream strings, repeated unchanged/changed runs and distinct canonical identities.
2. One healthy plus one malformed/rate-limited/rights-blocked source; healthy results remain readable, aggregate health is partial and process results identify failure.
3. A/A exclusion, A/B concurrency, obsolete completion and a mid-run disable. No partial/failed snapshot wipes valid data.
4. Multi-source paging/facets, source-set cursor invalidation, per-record expiry and source-specific rights disable on list/detail.
5. Anonymous read projections, denied private/source writes, URL-origin rejection, CSV MIME/size/encoding limits and transport budgets.
6. Dart health parsing/UI and old event contracts.

Run affected tooling/SQL/HTTP/mobile checks, generate database types and required CI. Document the extended contracts, source ownership and existing limits. Update progress and merge normally. No live data, hosted migrations/imports or schedule activation is required for completion.
