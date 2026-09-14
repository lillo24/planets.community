# Getting started

This guide reproduces the PLANETS repository foundation on Windows, macOS, or Linux. Normal commands do not require WSL, Git Bash, Make, or a cloud account.

## Prerequisites

Install:

- Git;
- Node.js 24.20.0 LTS with npm 11.19.0;
- Flutter 3.47.2 stable, which includes Dart 3.13.2;
- Docker Desktop or another Docker-compatible runtime supported by the Supabase CLI;
- Android Studio/Android SDK only when running or building Android;
- macOS and Xcode only when running or building iOS.

The CI workflow uses these exact Node and Flutter versions. The root `package.json` accepts the Node 24/npm 11 release lines so compatible patch updates can be used locally, but using the recorded versions gives the closest reproduction.

The repository enforces LF line endings through `.gitattributes` so formatting checks behave consistently across operating systems.

The bootstrap was generated and validated with:

| Tool/framework    | Version       |
| ----------------- | ------------- |
| Node.js           | 24.20.0 LTS   |
| npm               | 11.19.0       |
| Flutter           | 3.47.2 stable |
| Dart              | 3.13.2        |
| Next.js           | 16.3.4        |
| React / React DOM | 19.2.8        |
| Vite              | 8.3.0         |
| Supabase CLI      | 2.116.0       |

Confirm the local tools before setup:

```text
git --version
node --version
npm --version
flutter --version
flutter doctor
docker version
```

Start the Docker engine before starting Supabase. Flutter may report missing Android or Xcode tooling when that platform is not installed; those tools are not required for the web application, local backend, Flutter formatting, static analysis, or widget tests.

## First setup

Clone and enter the repository:

```text
git clone https://github.com/lillo24/planets.community.git
cd planets.community
```

Restore the root Node workspace and Flutter packages:

```text
npm ci
npm run restore:mobile
```

The root lockfile covers the `apps/site` and `apps/web` npm workspaces and the project-scoped Supabase CLI. Do not install a global Supabase CLI or create a second lockfile inside either application.

## Local Supabase

Start the development-only Supabase containers and inspect their status:

```text
npm run db:start
npm run db:status
```

With the committed default configuration, the main local endpoints are:

| Service            | Address                                                   |
| ------------------ | --------------------------------------------------------- |
| API                | `http://127.0.0.1:54321`                                  |
| PostgreSQL         | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio             | `http://127.0.0.1:54323`                                  |
| Local email viewer | `http://127.0.0.1:54324`                                  |

`npm run db:status` is the authoritative source for active local endpoints and development credentials. These values are local-only and must never be reused as staging or production secrets.

Local Auth uses a PLANETS numeric-code template at `supabase/templates/magic_link.html`. Despite Supabase's template category name, it includes `{{ .Token }}` and deliberately omits `{{ .ConfirmationURL }}`, so the mobile and web flows do not require a magic-link or deep-link callback. Local codes are six digits and expire after one hour. Restart the local stack after changing Auth configuration or templates.

To exercise the complete local flow without scraping the email viewer UI, run:

```text
npm run auth:verify:local
```

The script requests a code for deterministic `.invalid` test data, reads only the new Mailpit message through its API, verifies the code, and confirms the signed-in user can insert/read exactly one own profile anchor under RLS. It does not print the email, code, session token, publishable key, or raw message.

To verify that concurrent local OTP users can make an immediate identity-bound PostgREST request, run:

```text
npm run auth:session:verify:local
```

This check binds each verified session token to a separate data client, then uses the first request to insert and read that user's own profile anchor under RLS. It does not retry authentication or print emails, codes, tokens, keys, Authorization headers, or raw messages.

To prove the basic profile security contract with two authenticated users and one anonymous client, run:

```text
npm run profile:verify:local
```

This completes one profile with mixed visibility, confirms full owner access, rejects direct cross-user access and mutation, and checks that the exact-ID anonymous payload contains only public fields and no Auth email or visibility metadata.

To prove the one-time proposal lifecycle and rough/exact location privacy contract with two complete authenticated users plus anon, run:

```text
npm run proposal:verify:local
```

This creates private drafts, rejects cross-user and stale-identity mutation, publishes restricted and public-location proposals, verifies sanitized list/detail behavior and controlled skills, then confirms cancellation removes a proposal from normal discovery. It does not print credentials, OTPs, session tokens, or restricted meeting values.

After generating web configuration and building the web application, the companion web check obtains its cookie state through `@supabase/ssr`, requests the running Next.js application, and proves the Server Component sees the authenticated session while `/admin` remains 404:

```text
npm run web:config:local
npm run build --workspace @planets/web
npm run auth:web:verify:local
npm run tavoli:web:verify:local
```

The Tavoli web check creates synthetic active, paused, and ended series and
proves the production server's signed-out HTML preserves exact-location
privacy. These integration commands do not automate browser or native UI
interaction.

For a manual mobile check, run the app, choose **Sign in**, enter a non-personal test address, and open the local email viewer at `http://127.0.0.1:54324`. Confirm the newest message shows a six-digit code and no sign-in link, paste the code into the app, and confirm a skeletal account is taken to profile setup. Save a mixed-visibility profile with categorized skills, reopen and edit it, restart the app to check completed-profile restoration, verify `/` remains public after sign-out, and confirm a signed-out `/profile` return resumes safely after sign-in. Then verify signed-out proposal browse/detail, each temporal badge, restricted/public exact-location copy, filtering and pagination; sign in with a complete profile and exercise create/save draft/restore/edit/publish/cancel/my-proposals, including disabled post-start editing and a cross-account stale-form switch. This native interaction is a manual QA step; the integration command verifies the backend behavior only.

For a manual web check, open `/profile` while signed out and confirm the return goes through `/auth`. Request and paste the newest local six-digit code, complete and edit the categorized profile form, exercise public/private choices, refresh `/profile` to confirm persistence, then sign out and confirm `/` remains public. Check `/proposals` and an exact-ID detail signed out, including locality/skill filters, pagination, Just Finished styling, and both exact-location privacy modes. Then check the home links and Proposal/Tavoli switcher, `/tavoli` locality filtering and More Tavoli cursor, active weekly/monthly details, named-zone times, both exact-location modes, paused/ended historical detail, 404 behavior, narrow layout, and rendered source privacy. Refreshing during code entry intentionally returns to email entry because pending email/code state is memory-only. `/admin` must return 404 both before and after sign-in.

Stop the containers when finished:

```text
npm run db:stop
```

No remote Supabase project is linked. The committed migrations establish the database security foundation, identity/audit/outbox primitives, basic profile fields, controlled skills, visibility rules, one-time proposals, and PostGIS. See the [database development workflow](database.md) before changing the schema.

## Mobile configuration

The Flutter app accepts compile-time values through `--dart-define-from-file`. Its required keys are:

| Key                        | Purpose                                                                               |
| -------------------------- | ------------------------------------------------------------------------------------- |
| `APP_ENV`                  | Exactly `local`, `staging`, or `production`                                           |
| `SUPABASE_URL`             | Canonical Supabase API URL; staging and production require HTTPS                      |
| `SUPABASE_PUBLISHABLE_KEY` | Client-safe Supabase publishable key (the local CLI may still call this the anon key) |
| `SENTRY_DSN`               | Optional client DSN; an empty value keeps Sentry disabled                             |

Committed examples live in `apps/mobile/config/*.example.json`. Actual `local.json`, `staging.json`, and `production.json` files are ignored. Never put a Supabase service-role key in a mobile config file.

With local Supabase running, generate `apps/mobile/config/local.json` from the CLI's authoritative status output:

```text
npm run mobile:config:local
```

The helper writes the API URL and local client key without printing the key. For an Android emulator, replace the host-only loopback address with Android's host alias while preserving the CLI-reported port and credentials:

```text
npm run mobile:config:local -- --host 10.0.2.2
```

The default `127.0.0.1` URL is appropriate for an iOS Simulator on the same Mac. A physical device needs a reachable development-machine hostname and may require host firewall/local-network setup. Android and iOS allow local HTTP only in debug builds; Profile and Release retain their normal transport security.

Sentry is disabled when `SENTRY_DSN` is empty. Supplying a DSN enables error monitoring, while personal-data collection, tracing, replay, screenshots, failed-request capture, and HTTP breadcrumbs are explicitly disabled in this foundation. No Sentry account is required locally.

The mobile Auth feature does not log or report email addresses, OTPs, or session tokens. Its 30-second resend countdown is only a UI convenience; Supabase Auth remains authoritative for request and verification limits.

Flutter localization source is `apps/mobile/lib/l10n/app_en.arb`. Generated Dart files are ignored and must not be edited. `npm run restore:mobile`, `npm run mobile:l10n`, and CI run `flutter gen-l10n` deterministically before analysis/tests.

## Web configuration

The Next.js application validates these public environment values before initializing Supabase or optional monitoring:

| Key                                    | Purpose                                                                               |
| -------------------------------------- | ------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_APP_ENV`                  | Exactly `local`, `staging`, or `production`                                           |
| `NEXT_PUBLIC_SUPABASE_URL`             | Canonical Supabase API URL; staging and production require HTTPS                      |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Client-safe Supabase publishable key (the local CLI may still call this the anon key) |
| `NEXT_PUBLIC_SENTRY_DSN`               | Optional client DSN; an empty value keeps Sentry disabled                             |

All four keys are deliberately public client configuration. Never substitute a Supabase service-role key or another secret. Next.js inlines `NEXT_PUBLIC_*` values at build time, so shared deployments must supply the correct environment when building. The production build can complete without these values, but running `/` or `/auth` instantiates the request-scoped Auth client and therefore requires valid configuration. Invalid configuration fails with an actionable error.

The committed example is `apps/web/.env.example`; actual `.env*` files are ignored. With local Supabase running, generate `apps/web/.env.local` from the same authoritative CLI status parser used by the mobile helper:

```text
npm run web:config:local
```

The helper writes the local API URL and client key without printing the key. Local Supabase may use HTTP. Staging and production configuration fails validation unless the Supabase URL uses HTTPS.

Sentry is disabled when `NEXT_PUBLIC_SENTRY_DSN` is empty. When supplied, the web foundation captures unhandled Next.js errors but explicitly disables default PII, tracing, profiling integrations, and session replay. Source-map upload, tunneling, request/session capture customization, and provider provisioning remain out of scope.

## Run the applications

For static layout work, start the standalone public informational site:

```text
npm run dev:site
```

Open `http://localhost:5173`. This Vite-only server does not run the waitlist
endpoint. To exercise the complete local flow, create the ignored Wrangler
runtime variables, apply the D1 migration, and start Cloudflare's local Workers
runtime:

```text
Copy-Item apps/site/.dev.vars.example apps/site/.dev.vars   # PowerShell
cp apps/site/.dev.vars.example apps/site/.dev.vars          # macOS/Linux
npm run waitlist:migrate:local
npm run dev:site:waitlist
```

Open `http://localhost:8788`. This path builds the same static application with
Cloudflare's public Turnstile test site key, loads the matching server-side test
secret and explicit testing mode from the ignored `apps/site/.dev.vars`, and sends
`POST /api/waitlist` through the native local Worker to local D1. Matching files
are served through Workers Static Assets without entering the Worker. It does not
use a Cloudflare account or a remote database. Inspect or remove deterministic
local rows with:

```text
npm run waitlist:inspect:local
npm run waitlist:delete-smoke:local
npm run waitlist:reset:local
```

The static production assets remain in `apps/site/dist/`. SITE-02W defines the
native Worker and Static Assets binding contract; production Cloudflare
resources, hostname, secrets, deployment, and DNS remain deferred to SITE-03. See
`apps/site/README.md` for the data boundary, manual removal procedure, and
cutover blockers.

Generate web configuration, then start the Next.js development server:

```text
npm run web:config:local
npm run dev:web
```

Open `http://localhost:3000`. The root stays public and shows minimal session status; `/auth` provides numeric email-OTP sign-in; `/profile` provides authenticated basic profile setup/editing; `/proposals` and `/proposals/[id]` provide signed-out read-only one-time proposal discovery; `/tavoli` and `/tavoli/[id]` provide separate signed-out recurring-activity discovery. Pending email/code values remain only in memory, and server-rendered session state uses cookie-backed Supabase SSR with verified claims. The request Proxy only refreshes and propagates session cookies. `/admin` intentionally returns 404 even for an ordinary authenticated user until a later plan defines admin authorization.

With an Android emulator, iOS Simulator, or physical device available, start Flutter:

```text
npm run dev:mobile
```

`dev:mobile` loads `apps/mobile/config/local.json`; generate it first as described above. Use `flutter devices` to inspect available devices. iOS builds require macOS/Xcode; Android builds require a configured Android SDK.

## Validate and format

Run all ordinary web and mobile validation:

```text
npm run check
```

The command runs web tooling/unit/component tests, linting, TypeScript checking, a production Next.js build, informational-site client and Cloudflare runtime tests, site lint/type checking/static build, Dart formatting verification, Flutter analysis, and Flutter widget tests. Supabase startup is separate because it provisions local containers and is slower than the frequent validation loop.

Useful focused commands are:

```text
npm run check:web
npm run check:site
npm run check:mobile
npm run format
npm run format:check
npm run db:status
```

With the local Supabase stack running, validate a clean migration replay, schema lint, pgTAP security tests, and generated database types:

```text
npm run check:db
```

`check:db` assumes the stack is already running; it does not start or stop containers. It includes the deterministic immediate-session/RLS check, the two-user mixed-visibility, proposal privacy/lifecycle, and recurring-activity harnesses. GitHub Actions owns the stack lifecycle and separately validates mobile, the dynamic web application, the informational site's client and local Cloudflare/D1 boundary, the database workflow, the built web Auth session check, and signed-out Tavoli HTTP privacy on pull requests and pushes to `main`.

Hosted email delivery is not configured by this repository. Before staging or production use, the account owner must configure a production SMTP provider and the equivalent numeric OTP template in the hosted Supabase project, then verify the hosted project's current Auth email restrictions and rate limits. Do not claim hosted Auth is ready from the local template alone.

## Environment and secrets

The mobile and dynamic-web configuration contracts are documented above. The
informational site's browser-visible build variable is
`VITE_TURNSTILE_SITE_KEY`; it must contain only the public Turnstile site key.
The Worker requires the server-only `TURNSTILE_SECRET_KEY`,
`TURNSTILE_EXPECTED_ACTION`, `TURNSTILE_EXPECTED_HOSTNAME`, and
`TURNSTILE_TESTING_MODE` bindings plus the `WAITLIST_DB` D1 binding.
Production must set testing mode to `false`; only that mode requires exact
action and hostname verification. The committed waitlist-local mode and
`.dev.vars.example` use only Cloudflare's official test credentials and an
explicit `true` testing mode.

Actual `.dev.vars`, other local `.env*` files, non-example mobile config files,
and provider CLI state are ignored. Never commit provider credentials,
production database URLs, service-role keys, signing material, or local machine
state. SITE-02 needs no remote Cloudflare resource, Resend setup, analytics, or
tracking; Sentry remains optional elsewhere.

## Provisional mobile identifiers

The official Flutter scaffold currently uses these deliberately provisional identifiers:

- Android: `community.planets.bootstrap.planets_mobile`
- iOS: `community.planets.bootstrap.planetsMobile`

The visible application name is `PLANETS`. The founder/account owner must choose the final Android application ID and iOS bundle ID before Firebase/FCM registration, store provisioning, signing, or any other provider setup tied to application identity. Changing those identifiers is deferred; the current values do not claim ownership of a production namespace.
