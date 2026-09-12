# Architecture decision records

This folder records material technical decisions whose rationale should survive the pull request that introduced them. Generated defaults and easily reversible implementation details do not need ADRs.

## Convention

- Name records `NNNN-short-title.md` with monotonically increasing four-digit identifiers.
- Copy `0000-template.md` and replace every placeholder.
- Use one of `Proposed`, `Accepted`, `Superseded`, or `Deprecated` as the status.
- Record the decision date as `YYYY-MM-DD`.
- Link a superseding or superseded record when a decision changes; do not rewrite accepted history to hide the prior choice.
- Include alternatives only when they clarify a meaningful tradeoff.

## Records

- [0001 — Root npm workspace and task entry point](0001-root-npm-workspace.md)
- [0002 — Canonical migrations and fail-closed database access](0002-canonical-migrations-and-fail-closed-database-access.md)
- [0003 — Self-hosted Supabase production direction](0003-self-hosted-supabase-production-direction.md)
