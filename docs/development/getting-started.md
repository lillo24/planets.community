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

The root lockfile covers `apps/web` and the project-scoped Supabase CLI. Do not install a global Supabase CLI or create a second lockfile under `apps/web`.

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

Stop the containers when finished:

```text
npm run db:stop
```

No remote Supabase project is linked. The committed migrations establish only the database security foundation and PostGIS; there are no product tables, policies, or seed rows yet. See the [database development workflow](database.md) before changing the schema.

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

Flutter localization source is `apps/mobile/lib/l10n/app_en.arb`. Generated Dart files are ignored and must not be edited. `npm run restore:mobile`, `npm run mobile:l10n`, and CI run `flutter gen-l10n` deterministically before analysis/tests.

## Web configuration

The Next.js application validates these public environment values before initializing Supabase or optional monitoring:

| Key                                    | Purpose                                                                               |
| -------------------------------------- | ------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_APP_ENV`                  | Exactly `local`, `staging`, or `production`                                           |
| `NEXT_PUBLIC_SUPABASE_URL`             | Canonical Supabase API URL; staging and production require HTTPS                      |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Client-safe Supabase publishable key (the local CLI may still call this the anon key) |
| `NEXT_PUBLIC_SENTRY_DSN`               | Optional client DSN; an empty value keeps Sentry disabled                             |

All four keys are deliberately public client configuration. Never substitute a Supabase service-role key or another secret. Next.js inlines `NEXT_PUBLIC_*` values at build time, so shared deployments must supply the correct environment when building. The current informational page can build without these values because it does not instantiate Supabase; requesting either Supabase factory without valid configuration fails with an actionable configuration error.

The committed example is `apps/web/.env.example`; actual `.env*` files are ignored. With local Supabase running, generate `apps/web/.env.local` from the same authoritative CLI status parser used by the mobile helper:

```text
npm run web:config:local
```

The helper writes the local API URL and client key without printing the key. Local Supabase may use HTTP. Staging and production configuration fails validation unless the Supabase URL uses HTTPS.

Sentry is disabled when `NEXT_PUBLIC_SENTRY_DSN` is empty. When supplied, the web foundation captures unhandled Next.js errors but explicitly disables default PII, tracing, profiling integrations, and session replay. Source-map upload, tunneling, request/session capture customization, and provider provisioning remain out of scope.

## Run the applications

Generate web configuration, then start the Next.js development server:

```text
npm run web:config:local
npm run dev:web
```

Open `http://localhost:3000`. The public root is informational. `/admin` intentionally returns a 404 until authentication and authorization are implemented in plan 03.

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

The command runs web tooling/unit/component tests, linting, TypeScript checking, a production Next.js build, Dart formatting verification, Flutter analysis, and Flutter widget tests. Supabase startup is separate because it provisions local containers and is slower than the frequent validation loop.

Useful focused commands are:

```text
npm run check:web
npm run check:mobile
npm run format
npm run format:check
npm run db:status
```

With the local Supabase stack running, validate a clean migration replay, schema lint, pgTAP security tests, and generated database types:

```text
npm run check:db
```

`check:db` assumes the stack is already running; it does not start or stop containers. GitHub Actions owns that lifecycle and separately validates mobile, web, and the full database workflow on pull requests and pushes to `main`.

## Environment and secrets

The mobile and web configuration contracts are documented above. Local `.env*` files, non-example mobile config files, and Supabase CLI state are ignored.

Never commit provider credentials, production database URLs, service-role keys, signing material, or local machine state. No Firebase, Vercel, Cloudflare, Resend, PostHog, or other cloud configuration is needed for this foundation; Sentry remains optional.

## Provisional mobile identifiers

The official Flutter scaffold currently uses these deliberately provisional identifiers:

- Android: `community.planets.bootstrap.planets_mobile`
- iOS: `community.planets.bootstrap.planetsMobile`

The visible application name is `PLANETS`. The founder/account owner must choose the final Android application ID and iOS bundle ID before Firebase/FCM registration, store provisioning, signing, or any other provider setup tied to application identity. Changing those identifiers is deferred; the current values do not claim ownership of a production namespace.
