# Supabase database

This folder owns the reproducible local PLANETS database and its security validation.

- `config.toml` configures the local stack and fail-closed Data API defaults.
- `migrations/` is the canonical, timestamp-ordered SQL schema history.
- `tests/` contains native pgTAP invariants and transactional security probes.
- `seed.sql` runs after migrations during reset and currently contains no data; the system-managed starter skill catalog is migration-owned reference data.

The migrations establish database infrastructure, identity/audit/outbox primitives, profiles, Proposal/Tavolo discovery, shared participation, the canonical notification domain, and the private provider-independent push installation/delivery-job foundation. Tests prove security properties from a clean replay, including owner isolation, sanitized public reads, recipient-only notification APIs, private provider-token handling, channel-independent projection, and per-consumer outbox idempotency. Contributor commands and the checklist for future objects live in the [database development guide](../docs/development/database.md).
