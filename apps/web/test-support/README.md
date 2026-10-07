# Disposable web integration checks

- `modint01-browser-fixture.ts` requires `MODINT01_LOCAL_REHEARSAL=1`, the
  owned MODINT01 backend/ports and its ignored fixture journal. It starts the
  production Next server on 3119 and a log-free local launcher on 3118. Normal
  browser OTP/profile/join is required: it injects no session or admission.
  Prepare with `node apps/web/scripts/seed-local-hosting-qa.mjs --disposable-modint01`
  after the database gate, then run the launcher from the repository root.
  Generated Web configuration and a production build are required. Never publish
  the journal, OTP mailbox, private case note bodies or bearer URLs.
- `public-host-harness.ts` owns the loopback-only Site/Web routing rehearsal;
  `public-host-harness.test.ts` verifies precedence and streaming transport with
  stand-in owners. This is not an adopted production proxy or Site Worker.
- `pi04-browser-fixture.ts` seeds synthetic Projects in the explicitly opted-in
  `planets-community-pi04` stack (58720–58729), runs production Next and Site
  stand-in owners (3155/3156) behind the public-origin harness (3154), and captures
  same-account mobile rediscovery state. Secrets stay in ignored local files.
- `pi04-host-probe.ts` checks production HTTP association, privacy, Next transport
  and 404 contracts at that fixed disposable origin. Enabled associations use
  synthetic identifiers; they do not verify a device or public host.
- `pi03-local-smoke.test.ts` owns the earlier gateway/HTTP integration described
  below; ordinary Vitest skips its opt-in backend check.
- `pi05-browser-fixture.ts` requires `PI05_LOCAL_REHEARSAL=1` and the owned
  `planets-community-pi05` stack (58920–58929). It retrieves the seeded current
  Proposal/Tavolo links, runs production Next and disposable Site owners
  (3175/3176) behind the harness (3174), and supplies private local launch/OTP
  pages plus safe independent canonical status. Its explicit CLI departure and
  revocation operations use authenticated APIs. Ignored fixture files are private.
  `pi04-host-probe.ts` also accepts the exact PI05 origin with a required fixture
  UUID. The [PI05 record](../../../docs/implementation/pi05-integration-qa-and-demo-data.md)
  owns commands and case-level evidence; these helpers prove no public deployment.

The [PI04 record](../../../docs/implementation/pi04-native-links-and-public-host-readiness.md#local-reproduction-and-evidence)
owns exact isolation/configuration, browser/capture/probe commands, cleanup and
evidence limits. Do not run both fixtures against the same backend or rebuild
`.next` while its production server is being used for QA.

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

## Combined Template/PI05 browser rehearsal

`pi05-browser-fixture.ts` retains its opt-in `PI05_LOCAL_REHEARSAL=1` and narrow
PI05 guard, and additionally accepts only the owned TW-STACK01 project
`planets-community-tw-stack01` on API 54921/Mailpit 54924. It uses the same
production Next/loopback ingress on 3174–3176, synthetic identities, private
capability journal and log-free OTP helper. This is opt-in QA, not hosting or
OS association. Use the generated local web config and production build first,
then launch from the repository root with `node apps/web/test-support/pi05-browser-fixture.ts`.
Do not reuse journals across reset worlds; prepare new references explicitly.
See [integrated browser/native evidence and cleanup](../../../docs/development/template-stack-integration.md).
