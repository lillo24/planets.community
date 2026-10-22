# Public mock persona broker

`index.ts` reads mock-project secrets. `runtime.mjs` owns fixed **mock-only**
Auth/RPC calls and AES-GCM deliveries. `handler.mjs` owns bounded public input,
random client capability bootstrap and persona/request/generation binding.
The tests cover failures/recovery; `scripts/mock/qualify-local.mjs` exercises the
same runtime against real isolated Auth, RPC, RLS and Storage.

Deploy only to `pnolarmzxmmjtguligfc`, with this function's `verify_jwt=false`.
This is deliberately public demo access while enabled. There is no normal Auth
token verification, human eligibility list or proof of test-app installation.
Ordinary bearer tokens are rejected as broker credentials. Other functions keep
their gateway settings. The client build flag controls production presentation.

Server secrets: `MOCK_DELIVERY_KEY` (random 32-byte base64 AES key) and
`MOCK_BROKER_ENABLED=true`. The mock runtime supplies its own service credential.
Retire obsolete `MOCK_NORMAL_ORIGIN` / `MOCK_NORMAL_PUBLISHABLE_KEY` settings;
neither is read. Both the server flag and private DB marker start disabled.

POST `{ "action": "bootstrap" }` without Authorization to obtain an unguessable
256-bit `capability` and public `client_id`. Keep the capability confidentially;
send it as `X-Mock-Client` for catalog/issue/retire. The database retains SHA-256
only. Recovery encryption binds mock origin, generation, capability hash, persona
and request. Neither a guessed request UUID nor another valid capability can
retrieve or retire another client's session. Only the fixed fictional registry
can supply ordinary Auth sessions; no general account impersonation is exposed.

See the operator runbook for global/client bounds, shutdown and expiry. Endpoint
availability is public, and random installation IDs are not strong abuse identity.
Never put administrative credentials or signing material in app config/artifacts.
