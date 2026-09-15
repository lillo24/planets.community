# PLANETS

PLANETS is a community platform for creating, discovering, and joining local collaborative activities and projects.

> **Current status:** repository/application foundations, email OTP, profiles, Proposal/Tavolo discovery, shared participation, Project chat/notifications, and standalone Scambio-Dona listing/mobile foundations are implemented. Project resource needs and later contribution offers are being delivered as separate follow-up slices.

## Repository

```text
apps/mobile/            Flutter application for Android and iOS
apps/site/              Static-first public launch site with one waitlist endpoint
apps/web/               Next.js public discovery and future admin surface
supabase/               Supabase configuration, migrations, seeds, and database tests
docs/architecture/      Accepted architecture and decision records
docs/development/       Contributor setup and local workflows
docs/implementation/    Ordered implementation roadmap
.github/workflows/      Change-aware pull-request and manual validation
```

The root npm workspace owns Node dependencies for `apps/site` and `apps/web`, the pinned Supabase CLI, and cross-platform task entry points. Flutter dependencies remain owned by `apps/mobile/pubspec.yaml`.

## Start developing

Install the documented tool versions, restore dependencies, and run the ordinary checks:

```text
npm ci
npm run restore:mobile
npm run check
```

Use `npm run db:start`, `npm run mobile:config:local`, and `npm run dev:mobile` for the locally configured Flutter app. Use `npm run web:config:local` before `npm run dev:web` for the dynamic web application. For the public site, `npm run dev:site` serves static UI work and `npm run dev:site:waitlist` runs the complete local Workers Static Assets/Worker/D1 flow after its documented setup. No cloud account is required for the local workflow.

See [Getting started](docs/development/getting-started.md) for prerequisites, exact setup steps, local URLs, and troubleshooting. Database contributors should also read the [database development workflow](docs/development/database.md).

## Documentation

- [Core technology stack](docs/architecture/core-stack.md)
- [System design and responsibility boundaries](docs/architecture/system-design.md)
- [Architecture decision records](docs/architecture/decisions/README.md)
- [Database development workflow](docs/development/database.md)
- [Continuous integration](docs/development/ci.md)
- [Codex tooling policy](docs/development/codex-tooling.md)
- [Implementation roadmap](docs/implementation/roadmap.md)
- [Instructions for coding agents](AGENTS.md)

Repository code, migrations, configuration, and tests are the source of truth for implemented behavior. Architecture documents describe the accepted technical direction; unresolved product and policy decisions remain deferred until their roadmap plans.
