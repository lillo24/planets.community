# Mock persona broker

`index.ts` reads mock-project secrets and serves `runtime.mjs`. `runtime.mjs`
owns fixed-origin Auth/RPC calls and AES-GCM recovery deliveries. `handler.mjs`
owns bounded public input, tester authorization and request/persona binding.
`handler.test.mjs` covers safe public failure and recovery boundaries. The
two-realm integration driver exercises the same runtime against genuine local
Auth and Data APIs, with independent signing keys.

Deploy **only** to `pnolarmzxmmjtguligfc` with this function's `verify_jwt=false`:
the normal issuer differs from the mock gateway's issuer. The handler checks
the normal Auth `/user` endpoint and enrollment before every operation. Other
functions retain their own gateway settings.

Server secrets: `MOCK_NORMAL_PUBLISHABLE_KEY` (public normal client key),
`MOCK_NORMAL_ORIGIN=https://cllpvruvrrvxczjitlqd.supabase.co`,
`MOCK_DELIVERY_KEY` (random 32-byte base64 AES key), and `MOCK_BROKER_ENABLED=true`.
The service-role credential is supplied by the mock runtime, never normal Auth.
Both the environment flag and database marker must enable issuance. Both start
disabled. Never put any server secret in mobile config, logs or screenshots.
