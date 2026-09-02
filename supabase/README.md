# Supabase database

This folder owns the reproducible local PLANETS database and its security validation.

- `config.toml` configures the local stack and fail-closed Data API defaults.
- `migrations/` is the canonical, timestamp-ordered SQL schema history.
- `tests/` contains native pgTAP invariants and transactional security probes.
- `seed.sql` runs after migrations during reset and currently contains no data; the system-managed starter skill catalog is migration-owned reference data.

The migrations establish database infrastructure, identity/audit/outbox primitives, and the basic profile/skill/visibility model. Tests prove security properties from a clean replay, including owner isolation and sanitized public profile reads. Contributor commands and the checklist for future objects live in the [database development guide](../docs/development/database.md).
