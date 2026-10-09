# Static participant invitation trial

This is LINK-HOST-03's provisional client-only target inside `@planets/web`.
It is not the production route owner. Next discovery/admin, authority invitations,
the informational Site, and native associations remain separate.

- `main.tsx` supplies History navigation, a single SDK browser client/controller,
  verified Auth/profile loading and identity-bound cleanup to the shared views.
  Profile setup uses the shared form's `nameOnly` mode: name and Continue only.
  Biography, skills and visibility are kept as loaded and can be personalized
  later in the app. One explicit Join click on the preview continues through
  login/name setup to a verified confirmation; no second Join is requested.
  The preview shows public title/description and an optional canonical cover
  inline. Auth/profile use one header back arrow, which cancels pending Join.
  Verified confirmation offers Open PLANETS and store badges; absent listing
  URLs leave the badges disabled and labelled Coming soon.
- `join-continuation.ts` holds that pending request in tab memory only, bound to
  the actual locally verified OTP subject or the already verified signed-in
  account. Cancel, Back, reload and identity/context changes clear it. Link
  opening and Auth restoration remain read-only. `onboarding.test.tsx` exercises
  the actual host, shared forms/controller and mocked Supabase boundaries.
- `routes.ts` owns exact trial paths and narrows the canonical safe-return parser.
- `public-config.ts` / `vite.config.mts` accept only the documented public keys,
  build static assets and reject Next/vinext/server-only runtime modules.
- `worker.ts`, `wrangler.jsonc` and `public/_headers` provide exact GET/HEAD,
  404/method/privacy contracts. The Worker only delivers a generic static shell.
  Matching emitted `/assets/*` files bypass it; missing files reach its 404.
- `trial.test.ts` checks HTTP/config/return contracts. `check-build.mjs` builds
  with a synthetic public key for CI; that artifact must not be deployed.
- `local-stack.mjs` copies canonical migrations into an ignored, task-owned
  backend and guards its start/stop. `browser-fixture.ts` prepares disposable
  projects/accounts and a private loopback launch/OTP helper. It refuses reseeding
  an existing fixture instead of resetting a stack.
- `local-integration.test.ts` opt-in exercises real local OTP/profile/admission
  adapters; it explicitly does not substitute for a browser journey.
- `artifact.mjs` / `artifact.test.ts` distinguish SDK key-type literals from
  credential-shaped values and reject local artifacts/source-map directives.
- `deploy.mjs` parses Wrangler JSONC and guards the fixed staging name, public
  artifact and existing-version ownership. `cloudflare.mjs` reads existing OAuth
  privately. `http-probe.mjs`
  verifies local/hosted contracts; `hosted-cpu.mjs` records bounded request windows
  and reads aggregate CPU for the exact version without request logging.

Setup, commands, session semantics, proof gaps and removal instructions live in
[the trial record](../../../docs/development/link-host03-static-invitation-trial.md).
All local credentials, capabilities, OTP output, deploy logs and measurement
journals stay under ignored `.wrangler/` or `.env.trial-*` files. Do not attach
those files, screenshots with capability-bearing chrome, or raw mailbox output.
