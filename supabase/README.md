# Supabase database

This folder owns the reproducible local PLANETS database and its security validation.

- `config.toml` configures the local stack and fail-closed Data API defaults.
- `migrations/` is the canonical, timestamp-ordered SQL schema history.
- `tests/` contains native pgTAP invariants and transactional security probes.
- `seed.sql` runs after migrations during reset and currently contains no data.

The migrations establish database infrastructure; tests prove its security properties from a clean replay. Contributor commands and the checklist for future objects live in the [database development guide](../docs/development/database.md).
