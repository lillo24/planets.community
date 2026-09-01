# PLANETS

PLANETS is a community platform for creating, discovering, and joining local collaborative activities and projects.

> **Current status:** the repository and fail-closed database workflow are bootstrapped. Minimal Flutter and Next.js applications run locally, and GitHub Actions validates the applications plus a clean Supabase migration replay and security harness. Product behavior is intentionally deferred to later roadmap plans.

## Repository

```text
apps/mobile/            Flutter application for Android and iOS
apps/web/               Next.js public website and future admin surface
supabase/               Supabase configuration, migrations, seeds, and database tests
docs/architecture/      Accepted architecture and decision records
docs/development/       Contributor setup and local workflows
docs/implementation/    Ordered implementation roadmap
.github/workflows/      Pull-request and main-branch validation
```

The root npm workspace owns Node dependencies, the pinned Supabase CLI, and cross-platform task entry points. Flutter dependencies remain owned by `apps/mobile/pubspec.yaml`.

## Start developing

Install the documented tool versions, restore dependencies, and run the ordinary checks:

```text
npm ci
npm run restore:mobile
npm run check
```

Use `npm run db:start`, `npm run dev:web`, and `npm run dev:mobile` to start the local services and applications. No application environment variables or cloud accounts are required at this stage.

See [Getting started](docs/development/getting-started.md) for prerequisites, exact setup steps, local URLs, and troubleshooting. Database contributors should also read the [database development workflow](docs/development/database.md).

## Documentation

- [Core technology stack](docs/architecture/core-stack.md)
- [System design and responsibility boundaries](docs/architecture/system-design.md)
- [Architecture decision records](docs/architecture/decisions/README.md)
- [Database development workflow](docs/development/database.md)
- [Implementation roadmap](docs/implementation/roadmap.md)
- [Instructions for coding agents](AGENTS.md)

Repository code, migrations, configuration, and tests are the source of truth for implemented behavior. Architecture documents describe the accepted technical direction; unresolved product and policy decisions remain deferred until their roadmap plans.
