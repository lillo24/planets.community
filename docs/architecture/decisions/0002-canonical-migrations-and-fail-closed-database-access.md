# 0002 — Canonical migrations and fail-closed database access

- **Status:** Accepted
- **Date:** 2026-09-01

## Context

PLANETS will expose selected PostgreSQL objects through Supabase's Data API. Supabase platform defaults have historically granted new `public` objects to API roles, PostgreSQL grants new routines to `PUBLIC`, and RLS is separate from object privileges. A forgotten grant or RLS step could therefore create an unintended API surface, while parallel declarative and migration representations could drift.

## Decision

Timestamped SQL migrations are the only canonical database schema history. Local reset and CI replay that history from zero; no parallel declarative schema files are maintained.

`public` is API-facing and `private` is excluded from configured API schemas. New `postgres`-owned objects in either schema receive no default privileges for `anon`, `authenticated`, `service_role`, or PostgreSQL `PUBLIC`. Client access requires explicit per-object grants. Ordinary PLANETS tables in `public` must enable RLS, enforced by a pgTAP catalog invariant in CI. Database types are generated from the migrated local `public` schema and checked for drift.

PostGIS is installed in the non-API `extensions` schema so spatial support does not add extension-owned objects to `public`.

## Alternatives considered

- Keeping Supabase's automatic grants would reduce migration statements but make accidental exposure the default and would not address PostgreSQL's `PUBLIC EXECUTE` routine default.
- Relying on RLS alone would leave grants overly broad and is ineffective for a table where RLS was forgotten or for unprotected routines.
- An event trigger that automatically enables RLS or rewrites grants would hide security behavior from the creating migration and add privileged trigger machinery.
- Maintaining declarative schemas alongside migrations would duplicate the schema source of truth without a demonstrated need.

## Consequences

Every exposed table, sequence, view, or routine needs reviewed grants in its migration, and every ordinary public table needs RLS and policy tests. Missing access fails loudly with a database permission error. The default-privilege rules depend on the creator role, so changing the migration owner requires matching rules and probe coverage. CI takes longer because it starts Supabase and performs a full reset, pgTAP run, lint, and generated-type drift check.
