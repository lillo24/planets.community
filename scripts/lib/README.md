# Local verifier helpers

`account-suspension-audit.mjs` traces qualified SQL function calls to account gates
and classifies each public signature. Its unit tests reject missing/cyclic gates;
the local audit compares against the committed RPC inventory and rejects private
broadcasters bypassing suspended-recipient filtering. It is deliberately a
heuristic source audit, complemented by pgTAP and real-auth/race/Realtime tests.

This folder owns reusable Node.js helpers and their unit tests for repository
tooling.

- `local-supabase-status.mjs` reads and validates project-scoped Supabase CLI
  status without exposing credentials.
- `local-authenticated-user.mjs` completes local Mailpit OTP authentication and
  returns a separate data client whose access-token callback is bound to the
  verified session JWT. This prevents immediate REST/RPC calls from falling
  back to the publishable key as their Bearer value.
  Its optional `shouldCreateUser` defaults to true for fixture setup; read-only
  demo verification passes false after checking existing identities.
- `demo-world.mjs` owns the stable synthetic persona/scenario registry, exact
  legacy-title adoption, strict loopback-only target guard, time-relative
  dataset orchestration, canonical profile/cover uploads, and focused
  verification for the explicit local demo-data commands. Public discovery
  verification traverses canonical cursor pages: unrelated verifier fixtures
  may share Trento, so demo records need not appear in the first page. Failed,
  malformed or repeated pages fail explicitly; verification never repairs data.
- `validation-paths.mjs` maps changed repository paths to the Mobile, Web, Site,
  and Database CI areas. Its tests protect the conservative shared-path and
  documentation-only boundaries used by the validation workflow.
- `demo-participant-invitations.mjs` owns the invitation part of `demo-world`:
  canonical actor transitions, stable admission identities, ignored local link
  journal, non-repairing assertions and domain snapshots. The root
  `verify-local-demo-idempotency.mjs` explicitly invokes its mutating transition
  rehearsal; ordinary verification invokes only reads. No second seed system
  or application-start hook exists.

- `membership-race-evidence.mjs` owns the membership verifier's loopback guards,
  bounded fresh-fixture campaign arguments, exact-winner lock observation and
  allowlisted end-state constraint diagnostics. Its tests distinguish real
  blocking from pending promises, unrelated/ambiguous waits and observer errors,
  and preserve microsecond timestamp comparisons without logging raw errors.
- `demo-participation-conversations.mjs` adds two Marco/Giulia pending requests
  and stable pair follow-ups to that same demo world. Its reads verify one pair
  row, exact request bubbles, resolved history, and no invented message context;
  it never repairs during verification.
- `participation-rpc-nullability.mjs` corrects pg-meta's missing table-result
  nullability for participation APIs and MSG01's typed mixed feed. Its tests
  fail on schema/type drift rather than writing partial generated types.
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

- `demo-workshop.mjs` owns TW05’s finite source inventory, stable actor/purpose request identities, canonical source/copy/report/removal phases, read-only assertions, dedicated clock transition and complete product-table snapshot digests. `demo-world.mjs` remains the single orchestrator, supplying auth, media, target safety and the shared coordination lock. The focused tests cover inventory uniqueness, request scope and elapsed-hour/DST margins.

TW-STACK01 composes invitation and Workshop projections against their exact
combined finite event inventory. Verification reuses only existing identities;
profile/content/preferences are reconciled only when changed during explicit
seed. Snapshots discover every current public/private base table, including new
invitation history, and exclude relative clocks only for exact named fixtures.
See [combined stability and upgrades](../../docs/development/template-stack-integration.md).

## UI-NEXT-02 demo drafts

`demo-drafts.mjs` adds/verifies four ordinary private drafts through canonical
owner RPCs. A host-local opaque receipt journal recovers interrupted creation
without overwriting owner edits or fabricating idempotency for Tavolo/Resource
RPCs. `demo-drafts.test.mjs` exercises unchanged reruns, lost receipts and committed
unknown-outcome recovery. `demo-world.mjs` composes this inventory under its
existing advisory lock; read-only verification never repairs destinations.
