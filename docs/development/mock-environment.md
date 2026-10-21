# Mock environment operations and readiness

The three archived MOCK prompts remain the acceptance contract. This runbook
describes the implementation and must not be read as a hosted-readiness claim.

## Targets and source

Dedicated zero-additional-cost project created 2026-10-21 in the connected free
Planets Community organization: `planets-mock`, `pnolarmzxmmjtguligfc`, eu-west-1.
Protected normal project: `planets-staging`, `cllpvruvrrvxczjitlqd`. Neither normal
staging nor production migrations/data are changed by this package.

Generation: `mock-world-2026-10-21-v1`. Its finite fixture clock is anchored once
in `mock_control.environment.anchored_at`. Run
`node scripts/mock/operator.mjs inventory` for the current sorted canonical
migration count/SHA256. Hashes normalize CRLF to LF. The source inventory is
recorded separately from the connector's application-time migration timestamps;
do not use ordinary `db push` on the dedicated mock project.

## Operator setup

Use a private JSON file outside Git containing only `projectRef`, `apiUrl`,
`normalOrigin`, `publishableKey`. The first three must equal the recorded targets;
the last must be the dedicated project's client-safe `sb_publishable_` key.
Supply `MOCK_DATABASE_URL` and `MOCK_SERVICE_ROLE_KEY` through private environment
storage; never print them or put them in mobile config/arguments.

1. Independently verify the project identity and zero cost. Apply
   `supabase/mock/marker.sql` to this dedicated target only. Separately insert
   its exact project ref, generation, reviewed inventory fingerprint and
   `operator_confirmed=true`. The default kill switch stays disabled.
2. Run `node scripts/mock/operator.mjs dry-run <private-config>`.
3. Run `node scripts/mock/operator.mjs setup <private-config>`. It applies only
   demonstrably missing canonical source migrations and the separate mock
   controls, recording source hashes atomically. Unknown/drifting targets fail.
4. Run `node scripts/mock/world.mjs <private-config>`, then
   `node scripts/mock/verify.mjs <private-config>`. Seed uses ordinary persona
   sessions for profiles, consent, relationships, chat, covers and avatars.
   Only Auth provisioning and private control receipts are privileged. One
   narrowly audited completed-history clock adjustment never disables triggers.
5. Re-run seed and verify on a disposable copy before relying on repeat behavior.
   Existing receipts skip completed operations, preserving tester edits. Missing
   registered Auth users or unexpected identity drift require operator review;
   they are never silently recreated/adopted. The verifier never repairs state.

Fixture personas are exact registered Giulia, Marco, Sara, Dario and Elena UUIDs
from `scripts/mock/world.mjs`, with fictional `personas.planets.invalid` emails.
There is no staff persona. Dario retains no photo. Scenario descriptions explain
possible uses, not permanent roles: tester changes can alter relationships.
Two real Groups, General/Ideas, canonical participation/contact conversations,
Project/Tavolo, donation/exchange, licensed bundled media and automatic reusable
templates form one shared fictional community. Do not enter personal information.

## Enrollment and offboarding

An approved private roster is an array of exact
`{"issuer":"https://cllpvruvrrvxczjitlqd.supabase.co/auth/v1","user_id":"<verified UUID>"}`
objects. It is not a Play-email list. All approved closed testers must be mapped
to their actual PLANETS Auth identities; no public-signup auto-enrollment exists.

Run `node scripts/mock/operator.mjs enroll <private-config> <approved-roster>`
for safe bounded bulk enrollment (1–500 distinct identities). Report only counts,
never roster contents or real emails. Offboard with
`node scripts/mock/operator.mjs offboard <private-config> <tester-UUID>`.
This immediately denies catalog/issuance and deletes only this tester's recorded
refresh sessions. Bearer access lasts until JWT expiry, configured no more than
one hour. Client sign-out alone is not immediate bearer invalidation.

Run `node scripts/mock/operator.mjs maintenance <private-config>` on demand:
expired delivery ciphertext is removed and retired audit/rate records older than
seven days are removed. Active session ownership records remain for offboarding.
There is no startup/periodic seeding or shared-world destructive reset. Recovery
requires reviewing the exact failed receipt/account; preserve shared test work.

## Broker contract and activation

Deploy `supabase/functions/mock-personas` only to the dedicated mock project,
with a **per-function** `verify_jwt=false` exception because it accepts normal
Auth tokens. Every action independently validates the token using the fixed
normal Auth `/user`, then checks the private current roster. Other functions are
unchanged. Configure server secrets documented in the function's README.

POST JSON to the exact `/functions/v1/mock-personas` endpoint over TLS:

- `{"action":"catalog"}` returns bounded `personas`, `project_ref`, `generation`.
- `{"action":"issue","persona_key":"giulia","request_id":"<UUID>"}`
  returns exact persona/user/request/realm binding plus ordinary access/refresh
  bootstrap tokens. Never log, copy or screenshot this response.
- Reuse that exact request to recover the same encrypted delivery for two minutes.
  `pending` means retry the same selection; changed-persona reuse conflicts.
- `retire` uses the same persona/request fields and revokes only that candidate.
  Expired/unresolved delivery requires explicit retirement/retry, not a silent
  new selection. Auth issuance is not claimed exactly once across crashes.

All responses are `no-store`. Inputs are limited to 1 KiB, the catalog to 12,
catalog access to 60/minute per tester, issuance to 6/minute per tester and 32
active operations globally, with one exchange at a time per shared persona.
Service secrets, generated OTPs and reusable credentials never reach the app.
Session bootstrap is retained encrypted for delivery only; a random 32-byte
server key binds ciphertext to tester/request/persona. The trusted normal origin
cannot be supplied by a caller.

Before activation, disable public signup, SMTP/email/SMS delivery, provider login,
push workers, outbound webhooks and external analytics in this mock target. No
normal provider secrets are copied. Mock-only Auth triggers prevent registered
persona credential/email/provider/MFA mutation while allowing ordinary profile
edits. Genuine Auth verification must prove their compatibility before enabling
hosted use. Optional basemaps stay unavailable without separate configuration.

The sparse `supabase/mock/auth-config.toml` is the reviewed Auth baseline. After
checking the exact disabled marker, copy it into a private CLI work directory,
preview `supabase config diff --project-ref pnolarmzxmmjtguligfc --workdir <private>`,
then push only that reviewed diff. Never push the local development template.
The private SQL delivery hook returns an error for email/SMS; only
`supabase_auth_admin` receives usage/execute, and ordinary users receive neither.
The interactive email provider is disabled, while server-side admin link
generation plus standard verification remains supported. The CLI cannot switch
the platform's SMS-provider selector off; phone signup/login is disabled and the
send-SMS hook rejects provider delivery. No carrier credentials are installed.
This behavior is portable to GoTrue's Postgres hooks, documented in
[Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks).

`mock-hosted-auth-proof.json` records the actual managed Auth check: ordinary
no-mail link/verification and exact UUID passed; direct email OTP returned 422
`email_provider_disabled`. The temporary synthetic probe was removed. Four
broker secret digests matched the private supplied values, with
`MOCK_BROKER_ENABLED=false`. This proves Auth configuration only. It does not
prove a seeded world, approved enrollment or a hosted tester-to-broker journey.
The current seeder requires a persistent session-pooler Postgres connection for
its advisory lock and transaction semantics. Management SQL calls are not a
substitute for that connection. The passwordless CLI path timed out here;
provide the exact mock session-pooler credential or run the reviewed operator
from a host where it is available. Do not fake SQL locks, reset the shared world,
grant an unreviewed execution endpoint or use the normal staging credential.

Enable the database marker and `MOCK_BROKER_ENABLED` only after configuration,
entire approved roster, fixture/media verification and hosted smoke tests pass.
The mobile capability remains off in ordinary builds and until this is proven.

## Qualification

`node --test scripts/mock/*.test.mjs supabase/functions/mock-personas/*.test.mjs`
tests target/broker failures. With a disposable Docker resource slot, run
`PLANETS_DISPOSABLE_QA=1 node scripts/mock/qualify-local.mjs` (PowerShell sets the
environment variable separately). The opt-in `qa-mock-backend` CI label runs the
same genuine two-realm qualification without any hosted/provider secrets.
Its transport maps only the two fixed production-shaped origins to the two
owned loopback stacks; Auth, RPC, RLS and Storage remain real. It deliberately
overrides the pinned CLI's shared local opaque API-key defaults through supported
`auth.publishable_key`, `auth.secret_key`, `auth.jwt_secret` environment references
and separate asymmetric signing-key files. All values stay in private child
environments and task-owned files; both credential sets must differ.
It deliberately
overlaps profile UUIDs and tests token rejection in both directions, same-persona
independent refresh sessions, encrypted recovery, server credential guards and
offboarding. It stops only its newly created disposable stacks.

Code, hosted enrollment/readiness, native evidence and signed-release readiness
are reported separately. Missing Docker, credentials, roster, signing or version
inputs never qualify as a pass. No Play upload is authorized.
