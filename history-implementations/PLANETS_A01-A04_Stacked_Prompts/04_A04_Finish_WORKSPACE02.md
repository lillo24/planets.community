# A04 — Integrate and harden WORKSPACE02 named links (original implementation plan)

**Status at archive:** Complete Batch A merged through PR #243; original WORKSPACE02 PR #216 is merged. Current docs/development/workspace02-named-links.md and migrations define actual behavior.

## Goal

Reuse the pre-existing multiple named private workspace-link work instead of starting another implementation. Every currently entitled Project/Tavolo participant can open Workspace beside the existing Checklist/organization controls even if it is empty; appropriate current Project managers can add/edit/remove separately named HTTPS links to Docs, Sheets, Drive folders, calls and other providers.

## Starting point in original request

WORKSPACE02 PR #216 was draft/open/conflicted when the stacked handoff was written. Its inspected head was 11daa1ba4c9f616e0c63806cdf3a2092994ec822. The A04 agent needed to inspect and import its source, preserve later main changes and test the integrated result, not merge #216 early or overwrite its branch.

## Required behavior

- Named entries with lightweight deterministic name/domain-based Material icons; no uploaded PNGs, favicon scraping, extra provider APIs, OAuth or Drive permission changes.
- HTTPS-only validated destinations; user confirms hostname. Recheck actor, current entitlement, item identity and destination after confirmation.
- Reader versus manager rights are enforced server-side. Former, pending, removed, unrelated accounts cannot read private names/URLs.
- Workspace remains independently openable in empty/loading/error states; failures are not displayed as false empty collections. Link collection is lazy-loaded with server-side bounded keyset pagination.
- Single-link installed RPC contracts keep their existing signatures and shapes: old-client set/clear affects only a designated entry and never silently wipes additional named links.
- New Add actions survive ambiguous post-commit responses with actor/Project/request identity and frozen intent, so a lost-response retry does not duplicate an entry. Edits/removes use conflict-safe item versions and explicit refresh.

## Data/migration rules

Upgrade existing shared workspace records in place with stable link IDs/names. Preserve URLs/timestamps, Project scopes and private grants. Because original migration timestamp predates some already-applied main migrations, test **both fresh ordered replay and populated latest-main upgrade** without rewriting historical migration files or resetting shared databases. Check generated types, compatibility and actual effective RPC definitions.

## Required tests

Actor matrix (Creator, Co-creator, Co-organizer, current member, former member, pending, unrelated), repeated/ambiguous writes, stale mutation conflict, pagination ties, cross-Project access denial, old/new clients in parallel, identity changes and late responses, no public/template/outbox leaks, valid/icon-lookalike destination handling, mobile checklist coexistence and local real-auth/RPC verification. Run final cumulative mobile/web/database and appropriate native test journeys.

## Deployment boundary

Source merge authorized as part of Batch A only. Hosted schema migration, activation and Play release were **separate** decisions. See [#216](https://github.com/lillo24/planets.community/pull/216), [#243](https://github.com/lillo24/planets.community/pull/243) and current WORKSPACE02 contract.
