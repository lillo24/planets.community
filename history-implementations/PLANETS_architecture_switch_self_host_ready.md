# PLANETS — Architecture Direction Switch: Self-Hosted-Ready Production

## Purpose

Update the repository's accepted architecture and agent guidance so future implementation work is built **toward an eventual self-hosted Supabase production deployment**, without implementing that production infrastructure yet.

This is an **architecture/documentation task**, not a deployment task.

The intended sequence is now:

1. continue implementing the remaining product features;
2. complete the main UI/UX pass;
3. then build, test, and rehearse the self-hosted production infrastructure;
4. only after that proceed to final production/release readiness.

The main reason for doing this task now is to prevent upcoming feature work from unnecessarily depending on Supabase Cloud-only behavior or other provider-specific assumptions that would create migration work later.

## Current repository context

Inspect the current repository before editing.

At the time this prompt was prepared:

- the current architecture documentation still presents **Supabase Cloud** as the accepted backend deployment and **Vercel** as the selected web deployment;
- `AGENTS.md` tells implementation agents to follow those architecture documents and keep deferred alternatives deferred;
- PR #20, **06C1 — Push Installation and Delivery-Job Foundation**, has been merged, although the roadmap may still describe 06C1 as in progress;
- 06C2 has not yet been implemented;
- production self-hosting infrastructure has not been built.

Repository code, migrations, configuration, and tests remain the source of truth for implemented behavior.

## New accepted direction

Record the following as the current intended architecture direction.

### Backend

PLANETS continues to use the **Supabase/PostgreSQL platform model**:

- PostgreSQL is the canonical product record;
- Supabase Auth remains the authentication system;
- RLS, PostgreSQL constraints/functions, migrations, PostGIS, Realtime, and other currently accepted Supabase-compatible components remain valid;
- existing application code should not be rewritten merely because production hosting is expected to become self-hosted.

However:

> **The intended production backend target is now self-hosted Supabase rather than an assumption of Supabase Cloud production hosting.**

During development, managed Supabase may still be used when convenient for development, staging, testing, migration rehearsal, or temporary environments. This does not make Supabase Cloud the architectural production dependency.

### Timing

Do **not** implement the self-hosted production stack in this task.

The self-hosting infrastructure phase is intentionally deferred until after:

- the main functional feature set is implemented; and
- the main UI/UX pass is substantially complete.

Before public production release, the self-hosting phase should then cover topics such as:

- production host/VPS selection and provisioning;
- production Supabase deployment;
- HTTPS/TLS and DNS;
- secret management;
- SMTP/auth email configuration;
- backups and off-site retention;
- restore/disaster-recovery testing;
- monitoring and alerting;
- update/upgrade procedures;
- operational runbooks;
- migration/rehearsal from any managed test environment where useful;
- production client configuration/cutover strategy.

Do not prematurely choose detailed production-host implementation mechanics in this architecture-only task unless they are necessary to define a portability boundary.

## Portability rules for feature work from now on

Update the appropriate architecture/agent documentation so future implementation plans follow these rules.

### 1. Prefer portable Supabase/PostgreSQL primitives

Continue to prefer:

- canonical timestamped SQL migrations;
- PostgreSQL constraints and functions;
- RLS;
- PostGIS;
- Supabase Auth;
- Supabase Realtime;
- repository-owned code/configuration.

Do not move existing canonical domain behavior into provider-specific dashboards or manually configured cloud state when it can reasonably remain reproducible in the repository.

### 2. Avoid unnecessary Supabase Cloud-only dependencies

A new feature must not assume a Supabase Cloud-only capability is available in production unless:

- the feature genuinely requires it;
- the self-hosted equivalent has been evaluated; and
- the architecture decision is explicitly updated.

When a Supabase feature exists both in managed and self-hosted deployments, it remains acceptable.

Do **not** interpret this rule as "avoid Supabase features." The goal is portability within the Supabase ecosystem, not replacing Supabase.

### 3. Edge Functions remain allowed

Do not prohibit Supabase Edge Functions merely because production will be self-hosted.

Future Edge Function code should be:

- repository-owned;
- configurable through environment/secrets rather than hard-coded project values;
- runnable/testable in the supported local/self-hosted Supabase function environment where practical;
- not dependent on a managed-only deployment workflow as a product invariant.

Provider deployment/secrets setup may remain deferred until the infrastructure phase where appropriate.

### 4. Background jobs / queue / cron behavior

Keep durable domain/job state in canonical database-backed structures where appropriate.

If future plans use Supabase Queues, Cron, or equivalent Supabase/PostgreSQL components, ensure the implementation does not silently depend on a Supabase Cloud control-plane feature that cannot be reproduced in the intended self-hosted deployment.

Exact production scheduling/worker deployment can remain deferred until the self-hosting infrastructure phase if the feature can be implemented and tested locally without it.

### 5. Media/storage remains an explicit later decision

Do **not** commit this architecture-switch task to Supabase Cloud Storage as the permanent media solution.

Plan 08 or an earlier explicit architecture decision should evaluate the production media choice, including at least:

- self-hosted Supabase Storage; and
- an external object store such as Cloudflare R2.

The evaluation should consider bandwidth, storage cost, privacy/access control, backups, migration complexity, and operational burden.

Existing code should not be deleted or redesigned in this task merely because this decision remains open.

### 6. Client/backend endpoint portability

Do not redesign the current mobile configuration system in this architecture-only task.

However, record that before public production release the project must explicitly resolve how production clients obtain/connect to the canonical backend so infrastructure changes do not accidentally strand installed app versions.

This belongs to the later self-hosting/release preparation unless an intervening feature requires the decision earlier.

### 7. Web hosting is a separate decision

Do not couple the backend-hosting decision to Vercel.

The web surface remains separate from the mobile product and may include:

- a static informational site;
- a lightweight authenticated administration/moderation interface;
- already-implemented public web functionality where the team chooses to keep it.

Static informational pages and sufficiently client-side interfaces may use free/static hosting when appropriate.

Do not remove or rewrite the existing Next.js web implementation in this task.

Vercel should no longer be presented as an unavoidable production requirement. Web deployment remains an operational choice to be selected according to the actual web functionality retained at release.

### 8. No premature production accounts or billing

Do not create or assume:

- a production VPS;
- production Supabase instance;
- paid hosting plans;
- production Firebase/APNs credentials;
- production DNS changes;
- production secrets.

Those remain explicit later actions.

## Documentation changes

Inspect the repository and update the smallest set of authoritative files necessary.

Likely areas include:

- `docs/architecture/core-stack.md`
- `docs/architecture/system-design.md`
- `docs/implementation/roadmap.md`
- `AGENTS.md`
- an architecture decision record under `docs/architecture/decisions/` if that is the repository's established way to record a material architecture change.

Use the repository's existing ADR numbering/naming conventions if adding one. Do not guess a number without inspecting the directory.

### Core stack

Reconcile statements that currently make these look mandatory production choices:

- Supabase Cloud;
- Vercel;
- managed-services-only production direction.

Preserve the underlying Supabase/PostgreSQL architecture.

Clearly distinguish:

- **technology/platform choice**: Supabase/PostgreSQL;
- **current development/test environments**;
- **intended production hosting direction**: self-hosted Supabase;
- **deferred implementation of production infrastructure**.

### System design

Keep one canonical backend and existing responsibility boundaries.

Do not redesign product domains.

Where external effects/workers/functions are described, make wording compatible with managed development environments and the future self-hosted production environment.

### Roadmap

Reconcile roadmap state with the current repository.

In particular:

- verify PR #20 / 06C1 is merged and, if so, mark **06C1 Implemented**;
- keep **06C2** as feature/integration work rather than the production self-hosting phase;
- add or clearly identify a **self-hosted production infrastructure / deployment-readiness phase after functional features and the major UI/UX pass, but before public production release**;
- do not force the entire infrastructure implementation into an unrelated existing feature plan if a separate roadmap item is cleaner;
- keep release/store work dependent on the production infrastructure being proven.

If the existing roadmap lacks a dedicated consolidated UI/UX phase despite the project deliberately deferring visual/product polish, add a concise roadmap item or note making that sequencing explicit if doing so improves clarity without inventing product scope.

### AGENTS.md

Only change what is necessary.

Future agents should understand:

- self-hosted Supabase is the intended production target;
- production self-hosting is not to be implemented incidentally during feature plans;
- feature plans should avoid unnecessary managed-only lock-in;
- major new hosting/provider choices still require explicit architecture decisions;
- repository code/configuration/migrations should remain reproducible.

Do not bloat `AGENTS.md` with deployment instructions that belong in later infrastructure documentation.

## Important non-goals

Do not in this task:

- provision a VPS;
- add production Docker Compose/Ansible/Terraform infrastructure;
- deploy Supabase;
- migrate a database;
- change DNS;
- configure TLS;
- configure backups;
- add monitoring services;
- add production secrets;
- migrate Storage;
- change the Flutter production endpoint strategy;
- implement R2;
- implement 06C2;
- remove the existing web app;
- rewrite already-implemented features.

This task exists to make **future implementation choices compatible with the intended production direction**.

## Validation

At minimum:

- inspect all changed documentation for contradictions;
- search the repository for architecture statements that still incorrectly present Supabase Cloud or Vercel as mandatory production dependencies;
- ensure references to self-hosting consistently distinguish "intended production direction" from "already implemented";
- ensure no documentation falsely claims production infrastructure exists;
- run the repository's appropriate documentation/format checks;
- run `git diff --check`.

If an ADR is added, ensure existing architecture index documentation is updated according to repository convention.

## Deliverable / report

Return a focused report containing:

1. files changed;
2. the new architecture direction recorded;
3. which portability guardrails future feature plans must follow;
4. roadmap/status corrections, including 06C1;
5. any remaining architecture decisions intentionally deferred, especially media/storage and web deployment;
6. validation run;
7. any contradiction or implementation detail that could not be safely resolved.

Do not implement unrelated product functionality.

Archive this implementation prompt under the repository's normal `history-implementations/` convention if that is still the active workflow.
