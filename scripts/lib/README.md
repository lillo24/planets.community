# Local verifier helpers

This folder owns reusable Node.js helpers and their unit tests for repository
tooling.

- `external-activities/` separates bounded provider transport, canonical record
  validation and atomic import orchestration. `external-activities.test.mjs`
  uses synthetic data and fake transport. The municipal equipment connector
  works under its explicit licence; Agenda/ODH retain their recorded rights or
  coverage blocks. Live reads never fall back to examples.
- `external-operations.test.mjs` and `external-operations-verifier.mjs` qualify
  bounded independent refreshes, due cadence, safe outcomes, private inspection
  and lease/retention maintenance. The verifier runs only through the guarded
  disposable-local entry point.
- `external-activities-upgrade-verifier.mjs` supports the guarded local HTTP
  verifier with a populated predecessor-to-V2 transaction, including warmed
  imports and stable function/record identities. Its DDL and fixtures roll back.

- `release01.test.mjs` covers the separate `scripts/release/` module: migration
  drift/approval and target guards, no-op retry, backend/Play failure boundaries,
  original signing inputs, code/track selection, mock Publisher calls and Python
  artifact validators. It never uploads a real bundle or mutates hosted staging.

- `contact-native-evidence.test.mjs` exercises the actual CI evidence collector
  using tiny fictional temporary files: both driver manifests, secret redaction,
  unique checkpoint names and rejection of duplicate image-byte payloads.
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
  verification for the explicit local demo-data commands.
- `validation-paths.mjs` maps changed repository paths to the Mobile, Web, Site,
  and Database CI areas. Its tests protect the conservative shared-path and
  documentation-only boundaries used by the validation workflow.
- `demo-participant-invitations.mjs` owns the invitation part of `demo-world`:
  canonical actor transitions, stable admission identities, ignored local link
  journal, non-repairing assertions and domain snapshots. The root
  `verify-local-demo-idempotency.mjs` explicitly invokes its mutating transition
  rehearsal; ordinary verification invokes only reads. No second seed system
  or application-start hook exists.
- `demo-participation-conversations.mjs` adds two Marco/Giulia pending requests
  and stable pair follow-ups to that same demo world. Its reads verify one pair
  row, exact request bubbles, resolved history, and no invented message context;
  it never repairs during verification.
- `participation-rpc-nullability.mjs` corrects pg-meta's missing table-result
  nullability for participation APIs, MSG01's typed mixed feed and IDEA01A's
  opt-in nullable logistics. Legacy event results remain strict. Its tests
  fail on schema/type drift rather than writing partial generated types.
- The matching `*.test.mjs` files verify parsing and request authentication
  behavior or path classification with non-secret fixtures.

The authenticated-user helper is local integration tooling only. It must never
log OTPs, access or refresh tokens, API keys, Authorization headers, or database
credentials.

- `map-provider-fixture.mjs` creates a valid neutral PNG and synthetic OSM-backed
  center responses, without network access.
- `map-provider.test.mjs` verifies the pure MAP05 Edge boundary, paid-service
  zero-IO gates, fixed requests, identity checks, deadlines and safe failures.
- `verify-map-discovery-provider.mjs` adds real Auth/REST permissions, atomic
  quarter-credit races, deduplication, expiry and shutdown checks to the existing
  explicitly disposable location verifier. It restores its configuration and
  deletes only its owned cache keys; no live provider is contacted.

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

- `demo-workshop.mjs` owns TW05’s finite source inventory, stable actor/purpose request identities, canonical source/copy/report/removal phases, read-only assertions, dedicated clock transition and complete product-table snapshot digests. `demo-world.mjs` remains the single orchestrator, supplying auth, media, target safety and the shared coordination lock. The focused tests cover inventory uniqueness, request scope, elapsed-hour/DST margins and the natural approximate public label (`locality, zona indicativa`) with unchanged private fixture instructions. Editing this source does not update existing database rows; MAP-UX01 runs no seed or refresh.

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

- `project-workspace-multi-verifier.mjs` extends the workspace verifier with real
  authenticated multi-link CRUD/concurrency/legacy-compatibility checks and the
  explicit disposable-stack populated upgrade mode. It never contacts hosted
  databases or prints credential-bearing CLI output.

- `project-workspace-upgrade-verifier.mjs` owns guarded disposable-loopback reset
  rehearsals for original and populated latest-main histories. Its temporary
  migration input excludes only Batch A workspace migrations; tracked history
  stays intact. It verifies repeat-up preservation and removes only its own
  resolved temporary tree. The multi-link verifier covers real Proposal/Tavolo
  RPC paging, Add receipts, concurrent CAS, legacy coexistence and privacy.

Co-creation local support: cocreate-local-backend.mjs checks explicit disposable
ownership and every loopback endpoint before opening SQL; its test rejects
hosted/implicit targets. cocreate-local-fixtures.mjs owns only three deterministic
synthetic topics/hubs, shared by the seed command and genuine hub verifier. It
does not enable the gate or create people.
