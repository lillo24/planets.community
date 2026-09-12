# 0003 — Self-hosted Supabase production direction

- **Status:** Accepted
- **Date:** 2026-09-12

## Context

The original core-stack baseline selected Supabase Cloud and Vercel to minimize early operating work. PLANETS now intends to run its canonical production backend on self-hosted Supabase, but the main product features and consolidated UI/UX work should be completed before production infrastructure is selected, built, and rehearsed.

Changing the hosting model must not trigger an unnecessary rewrite of the accepted Supabase/PostgreSQL application architecture. At the same time, upcoming feature work must not create hidden dependencies on a managed control plane that the intended production environment cannot reproduce.

## Decision

Self-hosted Supabase is the intended production backend target. PostgreSQL remains the canonical product record, and Supabase Auth, RLS, migrations, PostGIS, Realtime, Edge Functions, and other components available in the supported self-hosted platform remain accepted.

Managed Supabase environments may still be used for development, staging, testing, migration rehearsal, or other temporary non-production purposes. They do not define a permanent production dependency.

Feature work will prefer portable Supabase/PostgreSQL primitives and repository-owned migrations, functions, and configuration. A new Supabase Cloud-only production dependency requires an evaluation of the self-hosted equivalent and an explicit architecture update. Edge Functions remain allowed when their code is repository-owned, deployment values are configurable, and local/self-hosted execution can be tested where practical. Durable domain and job state should remain database-backed where appropriate; queues and schedules must not rely silently on a managed-only control plane.

Production self-hosting will be implemented in a dedicated roadmap phase after the main functional feature set and consolidated UI/UX pass, and before public production release. That phase will select and provision the host, deploy and secure Supabase, configure HTTPS/DNS/secrets/SMTP, prove backups and disaster recovery, add monitoring and update procedures, rehearse migration where useful, and define the production client endpoint/cutover strategy. This ADR does not select those mechanics or claim that the infrastructure exists.

The backend-hosting decision does not select the web host. Vercel remains an allowed option, while the release plan will choose static or Next.js-compatible hosting according to the public/admin functionality retained. Plan 08 will separately choose between self-hosted Supabase Storage and an external object store such as Cloudflare R2 after evaluating cost, privacy/access control, backups, migration complexity, and operational burden.

## Alternatives considered

- **Keep Supabase Cloud as the assumed production backend:** lower operational responsibility, but contrary to the selected ownership/portability direction and liable to encourage managed-only dependencies.
- **Replace Supabase with a custom backend:** unnecessary because the accepted PostgreSQL, Auth, RLS, Realtime, and function boundaries remain compatible with the intended target.
- **Build production infrastructure immediately:** would force host and operational choices before the feature set and UI/UX have stabilized.
- **Couple backend self-hosting to a fixed web or media provider:** would combine independent decisions whose requirements and operating costs should be evaluated separately.

## Consequences

Future plans must keep backend behavior reproducible and flag managed-only assumptions before implementation. Temporary managed environments remain useful and require no application rewrite.

PLANETS accepts the later operational responsibility for host security, availability, backups, recovery, monitoring, scaling, and upgrades. Public release and store work now depend on the dedicated self-hosted production phase being implemented and successfully rehearsed.

Media/storage, web hosting, detailed infrastructure topology, and mobile backend-endpoint cutover mechanics remain explicit later decisions rather than defaults introduced by this change.
