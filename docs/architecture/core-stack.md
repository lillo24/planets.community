# Core Technology Stack

**Status:** Accepted baseline for initial implementation  
**Recorded:** 2026-09-01  
**Direction updated:** 2026-09-12

**Implementation status:** Foundations, authentication, profiles, one-time proposals, Tavoli mobile/public-web discovery, participation, in-app notifications, structured request Messages, the provider-independent push foundation, and the static informational-site foundation implemented; production self-hosting is not implemented

## Decision summary

PLANETS uses a modular Supabase/PostgreSQL architecture that can use managed environments during development while remaining reproducible for the intended self-hosted production deployment:

> **Flutter mobile app + Supabase/PostgreSQL backend with an intended self-hosted production target + a static Vite/React informational site + a Next.js discovery/admin application with independently selected hosting + Firebase Cloud Messaging + GitHub Actions/Codemagic.**

This changes the production hosting direction, not the underlying application platform. Managed Supabase may still be used for development, staging, testing, and migration rehearsal. The self-hosted production stack will be designed and proven only after the main functional build and UI/UX pass; no production infrastructure is claimed by this document. Additions or provider-specific dependencies require a demonstrated product or operational need.

The production-backend rationale and consequences are recorded in [ADR 0003](decisions/0003-self-hosted-supabase-production-direction.md). The lasting web-application responsibility split is recorded in [ADR 0004](decisions/0004-separate-static-informational-site.md).

## Goals and constraints

The stack should:

- support Android and iOS from one mobile codebase;
- keep profiles, proposals, participation, chat, notifications, and statistics synchronized;
- model highly related data without duplicating business rules across clients;
- support local discovery and future geographic queries;
- make authorization enforceable at the data layer;
- allow Codex to build infrastructure and ordinary product backbones with limited founder supervision;
- minimize unnecessary service fragmentation and managed-control-plane lock-in;
- support a small local pilot without blocking later growth;
- keep public discovery, authenticated mobile use, and administration separate where their security needs differ;
- avoid premature infrastructure such as microservices, Kubernetes, Redis, and dedicated search clusters.
- keep repository-owned backend behavior reproducible across local, managed Supabase, and the intended self-hosted Supabase environment.

## Selected tools

| Area | Tool | Responsibility |
| --- | --- | --- |
| Mobile applications | Flutter and Dart | Shared Android/iOS application |
| Mobile state and dependency boundaries | Riverpod | Feature state, dependency injection, and testable controllers |
| Mobile routing | `go_router` | Declarative navigation and deep links |
| Mobile models | Freezed and `json_serializable` | Immutable typed models and predictable serialization |
| Mobile design foundation | Material 3 with centralized design tokens | Functional, coherent default UI before brand-focused design |
| Backend platform | Supabase platform | PostgreSQL, authentication, Data API, realtime, and server-function capabilities; managed environments are allowed for development/testing and self-hosted Supabase is the intended production target |
| Database | PostgreSQL | Canonical relational data and transactional business rules |
| Geographic data | PostGIS | Radius filtering, approximate locations, and future maps/statistics |
| Authorization | PostgreSQL Row Level Security | Enforce access independently of client UI |
| Atomic server operations | PostgreSQL functions | Multi-step domain transitions close to the data |
| External integrations | Repository-owned Supabase Edge Functions or compatible workers | FCM, email, and other server-only service calls without making a managed-only deployment workflow a product invariant |
| Background processing | Database-backed state with Supabase/PostgreSQL-compatible queues and scheduling | Durable delivery, retries, cleanup, and scheduled jobs reproducible outside a managed control plane |
| Authentication | Supabase Auth | Email one-time code initially; social login only when justified |
| Realtime project chat | Supabase Realtime with PostgreSQL persistence | Project-scoped group messaging without a separate chat vendor |
| Media | Deferred production storage choice | Plan 08 must evaluate self-hosted Supabase Storage and an external object store such as Cloudflare R2 while retaining database-owned authorization metadata |
| Push notifications | Firebase Cloud Messaging | Android and iOS push delivery; iOS uses APNs through FCM |
| Transactional email | Resend | Authentication, security, and exceptional account messages |
| Public informational site | Vite, React, and TypeScript | Small static-first informational and launch website under `apps/site` |
| Public discovery | Next.js with TypeScript | Dynamic public discovery routes under `apps/web` |
| Admin interface | Next.js with TypeScript | Future authenticated moderation and administration routes under `apps/web` |
| Dynamic web components | Tailwind CSS and shadcn/ui | Fast construction of ordinary responsive pages, forms, and tables in `apps/web` |
| Web deployment | Later operational choices | `apps/site` can use ordinary static hosting; `apps/web` requires hosting compatible with the dynamic functionality retained at release |
| DNS | Cloudflare | DNS, DNSSEC, and separation between domain ownership and hosting |
| Error monitoring | Sentry with EU data location | Mobile, web, and server error/release visibility |
| Product analytics | PostHog EU | Explicit beta product events and later feature flags |
| General CI | GitHub Actions | Formatting, analysis, tests, builds, migrations, and security checks |
| Mobile build/release CI | Codemagic | Hosted macOS builds, signing, TestFlight, and Play distribution |
| Database testing | pgTAP | Constraints, functions, permissions, and RLS behavior |
| Web end-to-end testing | Playwright | Public and admin user journeys |

Exact service tiers and prices are operational choices and must be rechecked when staging or production is provisioned.

## Architectural consequences

### Supabase platform with a self-hosted production target

PostgreSQL remains the canonical product record, and Supabase Auth, RLS, PostGIS, Realtime, migrations, and other Supabase-compatible components remain accepted. Existing application behavior should not be rewritten merely because production hosting is intended to be self-hosted.

Self-hosting makes PLANETS responsible for host provisioning, security hardening, PostgreSQL maintenance, backups and recovery, TLS, monitoring, scaling, and upgrades. Those responsibilities belong to a dedicated production-infrastructure phase after the main functional and UI/UX work, not to incidental feature implementation.

Managed Supabase remains acceptable for development, staging, testing, and migration rehearsal. Provider dashboards or manually configured cloud state must not become the only source of canonical behavior when migrations, repository configuration, or repository-owned functions can reproduce it.

### Portability boundary for feature work

Feature work should prefer timestamped SQL migrations, PostgreSQL constraints/functions, RLS, PostGIS, Supabase Auth, Supabase Realtime, and repository-owned code and configuration.

A feature must not assume a Supabase Cloud-only production capability unless the self-hosted equivalent has been evaluated and an explicit architecture update records why the dependency is necessary. Features available in both managed and self-hosted Supabase remain acceptable.

Supabase Edge Functions remain allowed. Their source belongs in the repository, deployment-specific values belong in environment or secret configuration, and functions should be runnable or testable in the supported local/self-hosted runtime where practical. Durable domain and delivery state should stay in canonical database-backed structures where appropriate. Queues, Cron, or equivalent components must not silently depend on a managed control plane that the intended production environment cannot reproduce.

### Web hosting is independent of backend hosting

The backend hosting direction does not select either web host. `apps/site` produces ordinary static assets and remains independently deployable; SITE-03 owns its production Cloudflare and domain-cutover decision. The Next.js `apps/web` discovery/admin deployment must match the dynamic functionality retained at release. Vercel remains an option for that application rather than an unavoidable production dependency.

### PostgreSQL is the source of truth

The application has strongly related domains: users, competences, proposals, join requests, memberships, chats, messages, notifications, reports, and statistics. PostgreSQL constraints and transactions must protect relationships and state transitions.

The clients must not be solely responsible for invariants such as:

- preventing duplicate proposal membership;
- accepting only pending join requests;
- creating one chat per eligible proposal;
- restricting messages to current proposal members;
- protecting private location and profile data;
- deriving statistics from proposal and participation history.

### Next.js is not a second backend

The public-discovery and admin application may use server-side Next.js features, but canonical authorization and domain behavior belong in PostgreSQL functions, RLS policies, or Edge Functions. Mobile and web clients must not implement competing versions of the same business rule. The static informational site has no backend or domain-rule ownership in SITE-00.

### Flutter is optimized for the primary product

The main product is a mobile application. Flutter avoids maintaining two native interfaces and matches the founder's existing experience. Web UI code is intentionally not shared because a mobile activity application, public website, and desktop moderation interface have different interaction needs.

### Feature-first mobile structure

The Flutter application should use a restrained feature-first organization with presentation, domain, and data responsibilities where useful. It must avoid ceremonial abstractions, multiple competing state-management systems, and generic base repositories without a concrete need.

### Public discovery without temporary accounts

Visitors should be able to browse sanitized public proposal data without signing in. Supabase's unauthenticated role and explicit public views/RLS policies should support this. Authentication is requested only for actions such as creating, joining, messaging, or managing an account.

### Email OTP first

Initial authentication should use verified email one-time codes. This avoids password-reset support and the configuration burden of launching Google and Apple sign-in together. Apple and Google sign-in can be added as a pair when onboarding evidence supports it.

The mobile and web flows request and verify a six-digit code in their own UI. Supabase Auth is the only session authority; clients do not persist a parallel login flag, pending email, or OTP. `/` stays public, while optional post-auth return locations must be sanitized internal paths. Web sessions use `@supabase/ssr` cookies, Proxy performs refresh/propagation only, and trusted server identity comes from verified claims rather than `getSession()`. Magic-link/deep-link callbacks, passwords, social providers, and admin authorization remain deferred.

### Basic profiles and controlled skills

Profile completion is derived from a trimmed, valid display name rather than a writable completion flag. A bio and controlled starter skills are optional. Display name, bio, and skills each have an independent `public` or `private` audience, defaulting to public; owners always retain full access. Both clients use one atomic PostgreSQL operation for scalar fields, skills, and visibility. Anonymous profile reads use an exact profile ID and return only the sanitized public projection—never Auth email, owner-only rows, or visibility settings.

The initial seven-category skill catalog is deliberately small and system-managed. Free-text skills, proficiency, search/directory behavior, photo media, location, and role-specific audiences remain later decisions rather than implicit extensions of this model.

### Structured request Messages and project-scoped chat

The mobile Messages surface presents join requests as persistent structured actionable items backed by canonical participation state; notifications are alerts, and requests do not become free-form chat messages. Project group chat is separate and will be created automatically by one idempotent backend operation. There is no manual Create Chat action, and no fixed three-person threshold controls availability. Plan 07B still owns the exact participation event and post-membership authorization. Ending a project retains its chat and messages. General direct messaging, calls, reactions, typing indicators, and end-to-end encryption are outside the initial backbone.

An optional meeting URL should be stored or exposed from the project chat. PLANETS should not implement video infrastructure or provider OAuth integrations initially.

### Notification delivery uses an outbox and queue

A domain transaction records what happened and appends a notification event. A background worker sends push or email with retry and idempotency. External delivery must not determine whether the underlying proposal operation succeeds.

The provider-independent push foundation consumes the canonical domain outbox as its own `push.v1` consumer, alongside `notifications.v1`. It resolves the shared participation semantics, applies only `push_enabled`, and creates one private recipient-level job without consulting in-app notification rows or active installations. Installation registration uses opaque client-generated UUIDs and private provider tokens. Firebase SDKs, provider credentials, permission UI, per-installation attempts, and actual delivery remain owned by 06C2.

The initial channel hierarchy is:

1. in-app notifications;
2. push notifications for important events;
3. email for authentication, security, and exceptional account communication.

Routine matching and chat activity should not produce parallel email noise by default.

### Location is map-ready but list-first

The first implementation should store structured administrative location data and an optional approximate PostGIS point. Exact meeting information, when needed, must be separate and restricted to authorized participants.

A visual map SDK and production geocoding provider are deferred. List and distance filters can validate the product before introducing map costs and privacy complexity.

### Derived statistics remain derived

Participation statistics and future badges should be computed from canonical proposal and membership history. Cached counters or materialized views may be introduced only after measurement shows a need.

## Environment model

### Local

- Supabase CLI and local containers;
- deterministic seed data;
- fake/test service integrations;
- no production credentials;
- safe database reset and full migration replay.

### Staging

- separate Supabase environment, which may be managed while useful for testing or migration rehearsal;
- separate Firebase configuration;
- independently selected preview/staging web deployments;
- test users and test push devices;
- staging Sentry environment;
- production-like migrations and smoke tests.

### Production

- independently configured self-hosted Supabase, Firebase/APNs, email, monitoring, and analytics resources;
- web hosts selected separately for the static informational site and the dynamic discovery/admin functionality retained at release;
- EU data locations where supported and appropriate;
- secrets stored in appropriate secret-management facilities, never in the repository;
- explicit approval gates for migrations, destructive actions, mobile-store submission, and other irreversible operations.

The production host, topology, deployment automation, HTTPS/DNS, SMTP, backups, off-site retention, restore testing, monitoring, upgrades, migration rehearsal, and client cutover strategy are not implemented. The production client endpoint strategy must be resolved before public release so infrastructure changes do not strand installed application versions.

## Deferred alternatives

| Alternative | Why deferred | Reconsider when |
| --- | --- | --- |
| Specific production host/VPS and topology | Selection requires current cost, location, capacity, security, and operational evidence | The dedicated self-hosted production-infrastructure phase begins |
| Supabase Cloud as the permanent production backend | It would reintroduce a managed control-plane dependency that the current direction avoids | A demonstrated requirement outweighs portability and an ADR updates the direction |
| Firebase SQL Connect | Credible relational alternative, but a newer and more provider-specific application layer | Its ecosystem or generated client workflow offers a clear project advantage |
| Firestore | Less natural fit for transactional, strongly relational workflows | A separate document/event use case appears |
| Expo/React Native | Reduces language count but would discard existing Flutter experience | Full web/mobile sharing becomes more important than Flutter continuity |
| Custom NestJS/Django API | Duplicates many platform capabilities and adds deployment surface | Domain needs can no longer be represented safely through database functions and Edge Functions |
| Flutter Web for public/admin web | Weaker fit for SEO, conventional document pages, and dense desktop admin tools | A contained internal tool benefits materially from Dart/UI reuse |
| Retool/Directus/Strapi/react-admin | Adds another authorization and data abstraction | Admin breadth grows beyond a small purpose-built moderation interface |
| Stream/Sendbird | Extra vendor and cost for a deliberately limited chat model | Chat becomes a major product with advanced messaging requirements |
| Google Maps/Mapbox/MapLibre UI | Not needed for initial list-first validation | A visual map becomes a tested product requirement |
| Algolia/Elasticsearch/Meilisearch | PostgreSQL search and indexes should cover the initial corpus | Search quality or scale is measured as insufficient |
| Redis | No current cache, rate-limit, or distributed-lock requirement | PostgreSQL/platform facilities become inadequate under measured load |
| Kubernetes or microservices | Operational complexity without current scale or team need | Independent scaling or deployment boundaries are demonstrated |
| Full offline-first synchronization | Substantial conflict and data-consistency complexity | Field use without reliable connectivity is a core validated requirement |
| Built-in video calling | Expensive infrastructure unrelated to the first product hypothesis | Video coordination becomes strategically central |
| Direct payment/donation processing | Business, legal, and accounting behavior is unresolved | The donation model and responsible legal entity are defined |
| AI matching or moderation | Deterministic taxonomy and human moderation are easier to validate | Data and measured limitations justify ML/LLM support |

## Architecture decisions still required

- Plan 08 must choose the production media backend after comparing self-hosted Supabase Storage and an external object store such as Cloudflare R2 for bandwidth and storage cost, privacy/access control, backups, migration complexity, and operational burden.
- The self-hosting phase must select the host, deployment and update mechanics, backup/restore design, monitoring, and migration/cutover procedure.
- SITE-03 must select the informational site's production Cloudflare configuration and domain cutover; the dynamic discovery/admin host must be selected independently according to the Next.js functionality retained at release.
- Before public release, the client/backend endpoint and cutover strategy must prevent infrastructure changes from accidentally stranding installed mobile versions.

## Product decisions still required

The technical baseline does not resolve founder-owned policy and design choices, including:

- expanded competence/resource taxonomy and proficiency semantics;
- proposal lifecycle states and cancellation/completion rules;
- membership threshold semantics;
- approximate versus exact location visibility;
- profile photo and media visibility beyond the implemented basic field audiences;
- notification categories and copy;
- minimum age and identity expectations;
- prohibited content, moderation actions, appeals, and response targets;
- deletion, anonymization, and lawful retention rules;
- donation/payment behavior;
- visual identity and polished interaction design.

Implementation plans should isolate these decisions and proceed autonomously only where a safe default is explicitly documented.

## Changing this baseline

A material change should include:

1. the problem demonstrated by the current architecture;
2. alternatives considered;
3. migration and operational costs;
4. security and data implications;
5. an architecture decision record or an update to this document;
6. corresponding changes to the implementation roadmap and agent instructions.
