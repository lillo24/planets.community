# Public informational site

This package owns the small public informational and launch website. Vite still
builds the page as static assets. The only dynamic boundary is the narrow
Cloudflare Worker at `POST /api/waitlist`, backed by D1 and protected by
Turnstile. Cloudflare Workers Static Assets serves the built page without
invoking Worker code for matching files. The package is independent from
`apps/web`, which owns dynamic public discovery and the future authenticated
admin surface.

## Waitlist purpose and data boundary

The waitlist exists solely to send one email when the PLANETS Android/iOS app
becomes available. It is not a newsletter, and its data must not be reused for
advertising, promotions, recurring updates, profiling, or unrelated messages.

The `launch_waitlist` table stores only:

- the trimmed, lower-cased email address as its primary key;
- `created_at` and `consented_at` ISO timestamps;
- the fixed consent version `launch_notification_v1`;
- nullable `notified_at`, reserved for SITE-04.

It does not store a name, IP address, user agent, location, marketing
preferences, profile information, analytics identifier, Turnstile token, or
arbitrary request payload. Application errors and logs must not include the
submitted address or Turnstile token/secret.

Duplicate normalized addresses receive the same successful response as a new
address. The original row is preserved, including its timestamps and any future
`notified_at` value.

## Local setup

Install the root workspace first. Then create the ignored local runtime file
from the committed example:

```text
npm ci
Copy-Item apps/site/.dev.vars.example apps/site/.dev.vars   # PowerShell
cp apps/site/.dev.vars.example apps/site/.dev.vars          # macOS/Linux
npm run waitlist:migrate:local
npm run dev:site:waitlist
```

Open `http://localhost:8788`. The local build uses Cloudflare's documented
always-pass Turnstile test site key, and `.dev.vars.example` supplies the
matching documented test secret. `TURNSTILE_TESTING_MODE=true` accepts only a
successful response carrying Cloudflare's testing-key marker and the documented
synthetic `example.com` hostname; production mode instead requires exact action
and hostname matches. These test credentials exercise the integration but do not
prove production Turnstile configuration. Never put a real Turnstile secret in a
`VITE_*` variable or any committed file.

The ordinary `npm run dev:site` command remains useful for static layout work,
but it has no Worker runtime and therefore cannot complete a signup.

Useful local data commands are:

```text
npm run waitlist:inspect:local
npm run waitlist:delete-smoke:local
npm run waitlist:reset:local
```

`waitlist:delete-smoke:local` removes only
`local-smoke@planets.invalid`. `waitlist:reset:local` deletes every row from the
local D1 database; it never targets a remote database. Wrangler keeps local D1
state under the ignored `apps/site/.wrangler/` directory. To reproduce a clean
database, remove that local state and rerun `npm run waitlist:migrate:local`.

Run the complete package validation with:

```text
npm run check:site
```

The client suite covers validation, explicit consent, request/loading,
success, and failure states. The Cloudflare runtime suite applies the committed
D1 migration and covers native Worker routing, static-asset fallback, endpoint
validation, Turnstile outcomes, minimal storage, duplicates, constraints, and
privacy-safe failures. It uses mocks and local Miniflare bindings; CI needs no
Cloudflare account or production secret. The validation gate also performs a
dry-run Worker bundle with the static-assets and D1 bindings.

## Removal before launch

Once the approved public/privacy contact exists, an operator receiving a valid
removal request should delete the row rather than retain a shadow suppression or
marketing record:

1. Confirm the request using the approved operating procedure; do not copy the
   address into issue trackers, ordinary logs, or shared chat.
2. Normalize the requested address by trimming surrounding whitespace and
   lower-casing it, exactly like the endpoint.
3. In the Cloudflare D1 console for the production `WAITLIST_DB`, run a
   parameter-equivalent deletion:

   ```sql
   DELETE FROM launch_waitlist WHERE email = '<normalized address>';
   SELECT changes() AS deleted_rows;
   ```

   If the address contains a single quote, escape it as two single quotes in
   the SQL literal. Use the console rather than placing personal data in shell
   history.

4. Expect `deleted_rows` to be `0` or `1`; anything else is an incident
   because the address is the primary key. Do not retain the address merely to
   record that it was removed.

The approved contact, controller identity, request-confirmation procedure, and
access/audit ownership are production inputs, not decisions made by SITE-02.

## Production boundary for SITE-03

The production Worker is deployed at
`https://planets-public-site.developer-planets-community.workers.dev`. Its
`wrangler.jsonc` owns the production D1 binding and these non-secret runtime
variables:

- `TURNSTILE_EXPECTED_ACTION=waitlist_signup`;
- `TURNSTILE_EXPECTED_HOSTNAME=planets-public-site.developer-planets-community.workers.dev`;
- `TURNSTILE_TESTING_MODE=false`.

The expected Workers Builds settings are:

- repository root directory `/`;
- build command `npm ci && npm run build --workspace @planets/site`;
- deploy command `npm run deploy --workspace @planets/site`;
- production branch `main`, with non-production branch builds and public
  preview URLs enabled only if the account owner intentionally approves them.

Before domain cutover SITE-03 must:

- verify that the production D1 database remains bound as `WAITLIST_DB` and has
  the committed migrations applied;
- verify the production Turnstile widget for the exact public hostname and
  action `waitlist_signup`;
- configure the public `VITE_TURNSTILE_SITE_KEY` only as a Workers Builds build
  variable and `TURNSTILE_SECRET_KEY` only as a Cloudflare Worker runtime
  Secret; never commit either value;
- keep the non-secret Turnstile runtime variables in `wrangler.jsonc`, including
  `TURNSTILE_TESTING_MODE=false`; test mode and official dummy keys must never
  be present in the production environment;
- decide whether the temporary `workers.dev` route and version preview URLs are
  enabled, and protect previews with Cloudflare Access if they must not be
  public;
- supply the approved legal-controller details, public/privacy contact, removal
  verification procedure, access owner, and retention/retirement decision;
- verify the deployed static assets, endpoint binding, migration, duplicate
  behavior, failure behavior, logs, and real production Turnstile flow before
  changing DNS.

Do not cut over SITE-03 while any of those items is unresolved. SITE-02 does not
deploy, change DNS, create production resources, send the launch notification,
configure Resend, add analytics, or authorize waitlist reuse.

## Files

- `index.html` owns document metadata and the primary-logo preload.
- `public/brand/planets-logo.png` is the unchanged founder-supplied logo.
- `src/App.tsx` owns the page landmarks, content, and privacy copy.
- `src/WaitlistForm.tsx` owns accessible client validation and request states.
- `src/TurnstileWidget.tsx` loads and renders Turnstile only when configured.
- `src/waitlist-api.ts` owns the same-origin client request boundary.
- `src/email-validation.ts` owns the shared email-format check.
- `worker/index.ts` owns the native Worker router. `/api/*` reaches it before
  assets, while matching static files use Cloudflare's asset-first path.
- `worker/waitlist.ts` owns server validation, Siteverify, and prepared D1
  persistence.
- `migrations/` owns reproducible D1 schema history.
- `wrangler.jsonc` owns the native Worker, Static Assets, and local-compatible
  D1 binding contract; its all-zero database ID is deliberately not a
  production resource.
- `vitest.cloudflare.config.ts` and `worker/__tests__/` own Cloudflare runtime
  tests.
