# Instructions for Coding Agents

This file applies to the whole repository unless a more specific `AGENTS.md` is added in a subdirectory.

## Project context

PLANETS is an early-stage community platform for creating, discovering, and joining local collaborative activities/projects. The primary product will be a Flutter Android/iOS application using one shared Supabase backend. A Next.js application will provide the public website and a separate authenticated admin interface.

The repository is currently in the architecture/bootstrap phase. Do not claim a product feature is implemented unless repository code and tests demonstrate it.

## Read before changing code

1. the active task/implementation prompt;
2. the current repository tree and relevant existing implementation;
3. [`docs/architecture/core-stack.md`](docs/architecture/core-stack.md);
4. [`docs/architecture/system-design.md`](docs/architecture/system-design.md);
5. [`docs/implementation/roadmap.md`](docs/implementation/roadmap.md);
6. relevant architecture decision records and feature documentation added later.

Do not assume the repository still matches an older prompt or report. Inspect it.

## Sources of truth and conflicts

Use this order when deciding what currently exists:

1. repository code, migrations, configuration, and tests;
2. merged repository documentation and architecture decision records;
3. the active task prompt for the requested change;
4. external product/design material explicitly supplied with the task.

The external Google Doc **Planets Community Design** contains broad product thinking, including tentative ideas. It is not evidence that a feature exists. Do not assume access to it. When an implementation depends on external context that is unavailable, stop and report what is missing rather than guessing.

When code and documentation disagree about implemented behavior, code/tests win for the current state. Report the mismatch and update stale documentation when it is within scope.

## General working rules

- Keep changes focused on the active plan.
- Prefer simple, conventional implementations over speculative abstractions.
- Preserve working behavior outside the task scope.
- Do not redesign user-facing flows unless the task requires it.
- Do not add major dependencies without explaining the concrete need.
- Do not introduce a second tool that duplicates an established responsibility.
- Avoid placeholder architecture that creates ongoing maintenance without serving current behavior.
- Record important assumptions in the pull request/report and in repository documentation when they affect future work.
- Mark deferred behavior explicitly; do not silently implement a different product interpretation.
- Update tests and documentation together with behavior.

## Architecture guardrails

The accepted baseline is:

- Flutter/Dart mobile application;
- Riverpod and `go_router`;
- Supabase Cloud;
- PostgreSQL and PostGIS;
- Row Level Security;
- database functions for atomic domain transitions;
- Edge Functions for trusted external integrations;
- outbox/queues for retryable external side effects;
- Supabase Realtime for proposal-scoped chat;
- Supabase Storage for media;
- Firebase Cloud Messaging for push;
- Next.js/TypeScript for the public website and admin interface;
- Vercel for web deployment;
- GitHub Actions for validation and Codemagic for mobile release builds.

Do not replace these choices during ordinary implementation. A material change requires evidence, alternatives, migration/operational analysis, and an architecture-document/ADR update.

### Backend rules

- PostgreSQL is the canonical product record.
- Enable and test RLS for every table exposed through Supabase APIs.
- Security-sensitive defaults fail closed.
- Use constraints for invariants that the database can express directly.
- Use named backend operations for multi-step or security-sensitive transitions.
- Make retried operations idempotent where duplication would cause harm.
- Do not make clients coordinate partial writes that should be one transaction.
- Do not put service-role credentials in Flutter, browser bundles, committed files, examples, logs, or test fixtures.
- Treat Next.js as a client/delivery surface, not a competing domain backend.
- Keep public views deliberately narrow; do not expose private columns and rely on UI hiding.
- Keep broad public location separate from exact restricted meeting data.
- Derive participation statistics from canonical history before adding mutable counters.
- Queue external notification/email effects rather than coupling them to the domain transaction.

### Flutter rules

- Organize primarily by feature.
- Separate presentation, state/controller, and data access responsibilities where useful.
- Use Riverpod as the state/dependency mechanism; do not add Bloc, Provider, or a service locator beside it without an approved reason.
- Use `go_router` for navigation and deep links.
- Prefer immutable typed models and explicit serialization.
- Keep shared/core folders small and genuinely cross-feature.
- Do not create generic base repositories, use cases, or wrappers mechanically.
- Build accessible functional UI with centralized tokens; polished brand/design decisions may be deferred.
- Handle loading, empty, recoverable error, and unauthorized states explicitly.

### Next.js rules

- Keep public and admin routes visibly separated.
- Prefer server components by default and client components only where interaction requires them.
- Never expose server secrets to browser code.
- Admin UI must call authorized canonical operations rather than edit sensitive tables through unrestricted client access.
- Preserve ordinary web accessibility, semantic HTML, responsive behavior, and keyboard operation.
- The public website is not required to reproduce the whole mobile app.

### Product-scope rules

Unless a task explicitly changes the decision, do not introduce:

- a general-purpose VPS or self-hosted production stack;
- microservices, Kubernetes, Redis, or a dedicated search cluster;
- full offline-first synchronization;
- direct messaging unrelated to proposals;
- built-in voice/video infrastructure;
- AI matching or AI moderation;
- direct payment/donation processing;
- a visual map SDK as a foundation dependency;
- advanced chat features such as reactions, typing indicators, or read receipts;
- social login before its provider and store implications are intentionally addressed.

## Testing and validation

Run all checks relevant to the changed areas and report exact commands/results.

Expected categories as the repository is bootstrapped:

### Flutter

- formatting;
- static analysis;
- unit tests;
- widget tests;
- selected integration tests.

### Next.js/TypeScript

- formatting/linting;
- TypeScript checks;
- unit/component tests;
- production build;
- Playwright tests for critical flows when present.

### Supabase/PostgreSQL

- start the local stack;
- apply every migration from an empty database;
- load deterministic seed data where relevant;
- run pgTAP tests;
- test RLS as the relevant actor types rather than only as an administrator/service role;
- verify generated database types when schema changes affect them.

### Edge Functions

- formatting/type checks;
- unit tests with mocked providers;
- retry and idempotency tests for background delivery.

Do not state that checks passed if they were not run. Explain environment/tool limitations and distinguish them from failures.

## Migrations and data safety

- Never edit an already-applied production migration to change history; add a new migration.
- During pre-production bootstrap, squashing may be acceptable only when the active plan explicitly permits it and no shared environment depends on the history.
- Make destructive changes explicit.
- Include migration rollback/recovery implications in the report.
- Seed data must be deterministic and contain no real personal data.
- Do not run destructive commands against staging or production unless explicitly authorized.

## External services, secrets, and production

Coding agents may create configuration templates, scripts, and setup documentation. They must not fabricate or expose:

- Supabase production keys;
- Firebase/APNs credentials;
- Vercel, Cloudflare, Resend, Sentry, or PostHog secrets;
- Apple/Google developer credentials or signing material;
- production database URLs;
- domain ownership or billing configuration.

When manual account-owner action is required, provide precise steps and continue with everything that can be implemented safely without the credential.

Do not claim an external service is configured unless it was verified through an accessible tool or repository evidence.

## When to stop for a decision

Stop and report before committing to an assumption that materially changes:

- authorization or exposure of personal data;
- irreversible schema/data behavior;
- proposal/participation state semantics;
- chat access after membership changes;
- moderation, retention, deletion, or minimum-age policy;
- payment/legal behavior;
- production infrastructure or significant recurring cost;
- a central user-facing product flow.

Do not stop for minor implementation details that can be selected consistently with the current architecture, task acceptance criteria, and common engineering practice.

## Pull request and completion report

A completed task should provide:

1. concise summary of what changed;
2. relevant files/areas changed;
3. architecture and product decisions made;
4. migrations/security implications;
5. commands and tests run, including failures or omissions;
6. external/manual setup still required;
7. known limitations and deferred work;
8. any decision that should block the next roadmap plan.

Keep the pull request focused. Do not combine unrelated roadmap plans merely because they touch the same repository.