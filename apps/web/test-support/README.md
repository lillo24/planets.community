# Disposable web integration checks

`pi03-local-smoke.test.ts` is an explicit opt-in verifier using the production
participant gateway and a built Next.js server. Ordinary Vitest and hosted Web
CI skip it; it requires a dedicated `planets-community-pi03` Supabase stack on
ports 58620–58629, a production build with matching `.env.local`, and free port 3153. It refuses other project IDs/API ports.

For isolation, temporarily set `supabase/config.toml` project ID to
`planets-community-pi03`, replace ports 54320–54329 with 58620–58629, and set the
Edge inspector port to 8683. Check those ports are free first and retain the
original config for restoration. Start with `npm run db:start`. Never reuse a
shared/staging/production backend or reset another local task's stack.

The verifier requests a synthetic six-digit OTP through local Mailpit, checks
profile-anchor/incomplete/complete states, seeds disposable Project/request
history, verifies real RPC admission/replay/re-entry and GET/prefetch/response
headers, and shuts down its Next server. Fixture setup/assertions use local
PostgreSQL; admission and own reads use a publishable-key, verified recipient
session through the production gateway. It prints no credentials or tokens.

From the repository root, with the dedicated config in place:

```powershell
npm run db:reset
npm run web:config:local
npm run build --workspace @planets/web
$env:PI03_LOCAL_SMOKE = '1'
npm exec --workspace @planets/web --call "vitest run test-support/pi03-local-smoke.test.ts"
Remove-Item Env:PI03_LOCAL_SMOKE
```

Reset only this disposable stack before repeating: fixed synthetic fixture IDs
persist. Restore the original `supabase/config.toml`, remove generated local
configuration, and stop this project's containers/volumes after verification.
This checks HTTP and gateway behavior; it does not automate browser OTP entry
or prove Android/iOS HTTPS delivery. See the [PI03 implementation record](../../../docs/implementation/pi03-browser-participant-invitations.md)
for manual browser QA and remaining PI04/PI05 work.
