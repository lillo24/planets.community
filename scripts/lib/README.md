# Local verifier helpers

This folder owns reusable Node.js helpers and their unit tests for repository
tooling.

- `local-supabase-status.mjs` reads and validates project-scoped Supabase CLI
  status without exposing credentials.
- `local-authenticated-user.mjs` completes local Mailpit OTP authentication and
  returns a separate data client whose access-token callback is bound to the
  verified session JWT. This prevents immediate REST/RPC calls from falling
  back to the publishable key as their Bearer value.
- `demo-world.mjs` owns the stable synthetic persona/scenario registry, exact
  legacy-title adoption, strict loopback-only target guard, time-relative
  dataset orchestration, canonical profile/cover uploads, and focused
  verification for the explicit local demo-data commands.
- `validation-paths.mjs` maps changed repository paths to the Mobile, Web, Site,
  and Database CI areas. Its tests protect the conservative shared-path and
  documentation-only boundaries used by the validation workflow.
- The matching `*.test.mjs` files verify parsing and request authentication
  behavior or path classification with non-secret fixtures.

The authenticated-user helper is local integration tooling only. It must never
log OTPs, access or refresh tokens, API keys, Authorization headers, or database
credentials.

The demo-world helper is also trusted local tooling. It reads vendored WebP
fixtures from `scripts/demo-assets`, so seeding stays offline after checkout.
It uses ordinary authenticated clients for domain and Storage/RPC media
mutations, the service role only for the existing notification projector, and
a direct local PostgreSQL connection only for coordination, stable lookups,
exact legacy-demo migration, verification, and controlled repair of naturally
frozen demo history. It never inserts canonical media or Storage rows directly.
The legacy migration rewrites only three exact immutable demo chat bodies in a
local trigger-suppressed transaction, preserving message IDs and notification
references without changing production trigger definitions.
Deterministic media uploads never use upsert; a rerun may reuse only an exact
already-owned version path left by an interrupted commit, which the canonical
RPC revalidates before adoption.
