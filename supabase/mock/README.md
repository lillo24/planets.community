# Separate mock controls

This folder is deliberately outside canonical product migrations.

- `marker.sql` creates an unacknowledged target marker; the operator must verify
  the exact independent mock project and reviewed source hash before acknowledging it.
- `control.sql` installs the private client capabilities, persona registry and receipts, narrow service-only
  broker functions and mock-only Auth credential guards. Its delivery hook rejects
  external Auth email/SMS while preserving admin link generation and ordinary verification.
- `auth-config.toml` declares only the reviewed hosted Auth changes. Preview its
  sparse diff after checking the disabled marker, then push only to the exact mock
  ref. Unspecified provider settings are never copied from the local template.

See `docs/development/mock-environment.md` for operator setup and readiness.
