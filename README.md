# PLANETS

PLANETS is a community platform for creating, discovering, and joining local collaborative activities and projects. Examples include public art, gardening, building something together, and initiatives whose proceeds are donated.

> **Current status:** architecture and repository-foundation phase. The mobile app, backend, website, and admin interface have not yet been bootstrapped.

## Product foundation

PLANETS is intended to support:

- user profiles with competences, interests, preferences, and participation history;
- creation and discovery of local proposals;
- competence-based matching and notifications;
- join requests and proposal membership;
- proposal-specific group chat after a participation threshold is reached;
- reusable templates derived from previous proposals;
- community statistics, moderation, and administration;
- an optional external meeting link rather than built-in video infrastructure.

## Planned platform

| Area | Baseline choice |
| --- | --- |
| Mobile | Flutter and Dart for Android and iOS |
| Backend | Supabase Cloud with PostgreSQL, PostGIS, Auth, Storage, Realtime, Queues, and Edge Functions |
| Public website and admin | Next.js with TypeScript |
| Web hosting | Vercel |
| Push notifications | Firebase Cloud Messaging |
| DNS | Cloudflare |
| Error monitoring | Sentry |
| Product analytics | PostHog EU, introduced when beta measurement is useful |
| Validation and delivery | GitHub Actions and Codemagic |

The detailed choices, boundaries, and deferred alternatives are documented in [`docs/architecture/core-stack.md`](docs/architecture/core-stack.md).

## Planned repository layout

```text
apps/
  mobile/             Flutter application
  web/                Next.js public website and admin interface
supabase/
  migrations/         Versioned database schema and policies
  functions/          Edge Functions and background workers
  tests/              Database and policy tests
  seed.sql             Deterministic local data
docs/
  architecture/       Accepted technical structure and boundaries
  implementation/     Implementation sequence and handoff material
tooling/               Shared development scripts
.github/workflows/     Continuous integration and deployment checks
```

This layout is planned rather than implemented. The first implementation plan will create the repository foundation and may refine details after inspecting current tooling constraints.

## Documentation

- [Core technology stack](docs/architecture/core-stack.md)
- [System design and responsibility boundaries](docs/architecture/system-design.md)
- [Implementation roadmap](docs/implementation/roadmap.md)
- [Instructions for coding agents](AGENTS.md)
- [Suggested implementation-plan sections](implementation_plan_sections_suggestions.md)

## Sources of truth

1. **Implemented behavior:** repository code, migrations, tests, and deployed configuration represented in the repository.
2. **Accepted technical direction:** repository architecture documents and future architecture decision records.
3. **Requested change:** the active implementation prompt, within its stated scope.
4. **Broader product context:** the external Google Doc **Planets Community Design** and founder discussion.

The external Google Doc contains both accepted ideas and tentative proposals. Coding agents must not treat every note in it as implemented or approved. Any external requirement needed for a task must be included in the task prompt or distilled into repository documentation.

## Development workflow

Work should proceed through small implementation plans and pull requests. Each plan must:

- inspect the current repository rather than assume a structure;
- distinguish implemented behavior from intended design;
- include tests and acceptance criteria;
- avoid production changes and secrets unless explicitly authorized;
- stop and report when a required product decision or external resource is missing.

The next planned task is **00 — Architecture and repository bootstrap**.