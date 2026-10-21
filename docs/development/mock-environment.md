# Mock environment operations and readiness

The access correction `00_MOCK_ACCESS_CORRECTION_Open_Test_App.md` supersedes
human enrollment and normal-login restrictions in the three archived prompts.
This document describes the corrected source, not a deployment claim. Live
observations and outstanding qualification are recorded separately.

## Targets and ownership

Mock: `planets-mock`, `pnolarmzxmmjtguligfc`, eu-west-1, created with a confirmed
zero additional monthly cost. Normal staging `cllpvruvrrvxczjitlqd` remains
protected and unchanged. The canonical normal migration gap is reported, never
deployed by this task. Generation is `mock-world-2026-10-21-v1`.

`node scripts/mock/operator.mjs inventory` reports the sorted canonical source
inventory/hash, normalizing CRLF. Mock controls are separate from canonical
migrations. Do not use an ordinary hosted `db push`, reset or automatic reseed.

## Setup

The ignored private JSON operator config contains `projectRef`, `apiUrl`,
`normalOrigin`, `publishableKey`, exactly matching the fixed independent targets.
`MOCK_DATABASE_URL` and `MOCK_SERVICE_ROLE_KEY` are private process inputs, never
mobile defines, command arguments or reports. No human access list is needed.

1. Verify the mock project, zero cost and independently confirmed marker.
2. Run `node scripts/mock/operator.mjs dry-run <private-config>`.
3. Run `node scripts/mock/operator.mjs setup <private-config>` for missing,
   hash-recorded canonical migrations and separate controls. Upgrade legacy
   controls only with issuance disabled. It revokes their recorded mock sessions
   and removes obsolete human-ownership tables/functions, preserving world data.
4. Run `node scripts/mock/world.mjs <private-config>` and then
   `node scripts/mock/verify.mjs <private-config>`. Only Auth provisioning and
   control receipts are privileged; real persona sessions exercise domain rules,
   RPCs, Storage and ordinary permissions. Existing receipts preserve edits.
5. Keep signup, interactive email/SMS/provider login, credential takeover, push
   workers, outbound webhooks and external analytics disabled in the mock target.
   The sparse `supabase/mock/auth-config.toml` is the reviewed Auth baseline.
6. Deploy the reviewed public broker to the mock target only. Configure its
   random `MOCK_DELIVERY_KEY`; remove obsolete normal-origin/key broker settings.
   Enable the DB marker and `MOCK_BROKER_ENABLED` only for actual public bootstrap,
   fixed-persona session, RPC/Storage, recovery/isolation and shutdown smoke tests.
   Leave availability off if qualification fails.

Giulia, Marco, Sara, Dario and Elena are fictional ordinary Auth users. Dario
keeps no photo. There is no staff account. Two real Groups, General/Ideas,
Projects/Tavoli/history, Scambio/donation, contacts, conversations, templates and
licensed media form one shared fictional community. Do not enter personal data.
There is no automatic reset or per-person copy. Missing registered users or
identity/receipt drift fails loudly and requires reviewing that exact account.

## Public broker

The `/functions/v1/mock-personas` function has its own `verify_jwt=false` because
the demo is public. It never contacts normal Auth or treats an APK flag as a
secret. No arbitrary email, account UUID, role, issuer, project or redirect is
accepted. Ordinary normal/persona bearer tokens are not broker capabilities.

POST `{ "action": "bootstrap" }` to obtain `capability` and public `client_id`.
Store the random 256-bit capability confidentially and send `X-Mock-Client` for:

- `{ "action": "catalog" }`: fixed available fictional personas and realm.
- `{ "action": "issue", "persona_key": "giulia", "request_id": "<UUID>" }`:
  ordinary mock Auth bootstrap, exact persona/client/request/generation binding.
- Same original issue request: recover its encrypted delivery for two minutes;
  pending does not silently issue a new selection. Changed payloads conflict.
- `{ "action": "retire", "persona_key": "giulia", "request_id": "<UUID>" }`:
  retire only that client's operation/session; pre-claim cancellation creates a
  bounded tombstone. Shared-persona global logout is never used by the client.

All responses are no-store. Input is limited to 1 KiB, catalog to 12, ciphertext
to 16 KiB and delivery to two minutes. Every catalog/claim/finish checks the kill
switch and registered client hash. Global per-minute limits are bootstrap 60,
catalog 600, fresh issue 30, and new retirement tombstones 120. Client limits are
catalog 60, fresh issue 6 and new tombstones 12 per minute. There is one OTP
exchange per persona, one pending request per client, at most 32 global pending
operations, 10,000 client capabilities and 20,000 delivery/tombstone records.
Rate state has fixed rows per client/action rather than unbounded minute rows.
These ceilings do not depend on installation-ID honesty. The public demo can
still be capacity-limited; random IDs are not verified people or strong abuse
prevention. Existing platform protections remain; no paid identity service is used.

Run `node scripts/mock/operator.mjs maintenance <private-config>` on demand to
remove expired ciphertext and retired audit records older than seven days.
Do not erase the shared world to address resource pressure.

## Shutdown and production

Keep `ENABLE_CLOSED_TEST_MOCK=false` in ordinary/production builds. The old
`ENABLE_DEMO_TOOLS` remains false in distributable builds. UI removal alone
does not disable the public endpoint or previously issued data access.

Run `node scripts/mock/operator.mjs shutdown <private-config>` and set the
mock-only `MOCK_BROKER_ENABLED=false`. The guarded DB action disables issuance
and deletes refresh sessions of registered mock personas only, without deleting
world data or touching normal sessions. Already-issued bearer tokens retain
their remaining lifetime, configured at most one hour. Wait that lifetime before
claiming authenticated mock data-plane expiry. Verify old clients cannot obtain
fresh sessions. Public fictional browse data remains public under canonical RLS.

## Database connectivity and private CI operator

The seeder requires a persistent PostgreSQL session/advisory lock and real
transactions. Management SQL calls cannot replace it. Local pooler IPv4 endpoints
accepted TCP but did not answer PostgreSQL SSL negotiation on 5432/6543. Network
restrictions were open and bans absent. No cached mock DB password existed.
Changing a password does not remedy that observed pre-authentication failure.

Available management access can issue a five-minute `cli_login_postgres` login
through the supported CLI endpoint. The operator accepts that exact mock session
pooler identity on 5432 and initializes all four real pooled sessions with
`SET SESSION ROLE postgres`, matching the pinned CLI. Startup-option role hints
were not preserved by the hosted pooler. Every guard verifies current_user;
an unexpected connection closure aborts the operator rather than silently
reconnecting without initialization. Query overrides, transaction
pooler ports and normal identities are rejected. No permanent password is changed.
A permanent mock-password rotation requires separate explicit approval.

The opt-in `qa-mock-hosted` workflow uses a network-capable GitHub-owned host.
Its temporary private `PLANETS_MOCK_OPERATOR` JSON secret contains exact source
SHA `source`, temporary session `databaseUrl`, `expiresAt`, mock-only `serviceKey`
and `publishableKey`. Create it immediately before dispatch and remove afterward.
It never receives a management token or normal credential. It verifies disabled
marker/migration receipts, upgrades mock controls, seeds and verifies. Artifacts
contain counts/provenance only. An expired login fails closed; use another
temporary login instead of substituting normal or permanent credentials.

## Qualification

`node --test scripts/mock/*.test.mjs supabase/functions/mock-personas/*.test.mjs`
checks broker/target boundaries. The explicit `qa-mock-backend` workflow runs
`scripts/mock/qualify-local.mjs` against two new disposable independently keyed
Supabase stacks. It proves ordinary Auth/RPC/RLS/Storage, fixed personas, client
recovery/request guessing, global limits, credential protections, non-destructive
legacy upgrade and shutdown. It never contacts or resets a hosted environment.
The native opt-in gate must separately prove guest entry/switch/restart/No,
retained normal account restoration, real interactions, production gating and
rendered EN/IT light/dark 320dp/2x behavior. Historical enrollment-based passes
do not qualify the corrected access model. Report source/code, hosted public-mock
readiness and signed release artifacts separately. No Play upload is authorized.
