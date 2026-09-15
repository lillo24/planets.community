# Local verifier helpers

This folder owns reusable Node.js helpers and their unit tests for repository
tooling.

- `local-supabase-status.mjs` reads and validates project-scoped Supabase CLI
  status without exposing credentials.
- `local-authenticated-user.mjs` completes local Mailpit OTP authentication and
  returns a separate data client whose access-token callback is bound to the
  verified session JWT. This prevents immediate REST/RPC calls from falling
  back to the publishable key as their Bearer value.
- The matching `*.test.mjs` files verify parsing and request authentication
  behavior with non-secret fixtures.

The authenticated-user helper is local integration tooling only. It must never
log OTPs, access or refresh tokens, API keys, Authorization headers, or database
credentials.
