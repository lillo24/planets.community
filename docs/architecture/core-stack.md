# Core Technology Stack

**Status:** Accepted baseline for initial implementation  
**Recorded:** 2026-09-01  
**Implementation status:** Foundations, authentication, profiles, and one-time proposals implemented; recurring-activity domain foundation in progress

## Decision summary

PLANETS will begin as a managed, modular monolith:

> **Flutter mobile app + Supabase/PostgreSQL backend + Next.js website/admin + Vercel hosting + Firebase Cloud Messaging + GitHub Actions/Codemagic.**

This baseline favors rapid automation, strong relational data guarantees, and low operational burden. It is not a permanent prohibition on other tools; additions require a demonstrated product or operational need.

## Goals and constraints

The stack should:

- support Android and iOS from one mobile codebase;
- keep profiles, proposals, participation, chat, notifications, and statistics synchronized;
- model highly related data without duplicating business rules across clients;
- support local discovery and future geographic queries;
- make authorization enforceable at the data layer;
- allow Codex to build infrastructure and ordinary product backbones with limited founder supervision;
- minimize server maintenance, deployment work, and fragmented vendors;
- support a small local pilot without blocking later growth;
- keep public discovery, authenticated mobile use, and administration separate where their security needs differ;
- avoid premature infrastructure such as microservices, Kubernetes, Redis, and dedicated search clusters.

## Selected tools

| Area | Tool | Responsibility |
| --- | --- | --- |
| Mobile applications | Flutter and Dart | Shared Android/iOS application |
| Mobile state and dependency boundaries | Riverpod | Feature state, dependency injection, and testable controllers |
| Mobile routing | `go_router` | Declarative navigation and deep links |
| Mobile models | Freezed and `json_serializable` | Immutable typed models and predictable serialization |
| Mobile design foundation | Material 3 with centralized design tokens | Functional, coherent default UI before brand-focused design |
| Backend platform | Supabase Cloud | Managed database, authentication, storage, realtime, server functions, queues, and scheduled work |
| Database | PostgreSQL | Canonical relational data and transactional business rules |
| Geographic data | PostGIS | Radius filtering, approximate locations, and future maps/statistics |
| Authorization | PostgreSQL Row Level Security | Enforce access independently of client UI |
| Atomic server operations | PostgreSQL functions | Multi-step domain transitions close to the data |
| External integrations | Supabase Edge Functions | FCM, email, and other server-only service calls |
| Background processing | Supabase Queues and Cron | Durable delivery, retries, cleanup, and scheduled jobs |
| Authentication | Supabase Auth | Email one-time code initially; social login only when justified |
| Realtime proposal chat | Supabase Realtime with PostgreSQL persistence | Proposal-scoped messaging without a separate chat vendor |
| Media | Supabase Storage | Profile and proposal files with policy-controlled access |
| Push notifications | Firebase Cloud Messaging | Android and iOS push delivery; iOS uses APNs through FCM |
| Transactional email | Resend | Authentication, security, and exceptional account messages |
| Public website | Next.js with TypeScript | Informational and discovery-oriented web presence |
| Admin interface | Next.js with TypeScript | Separate authenticated moderation and administration routes |
| Web components | Tailwind CSS and shadcn/ui | Fast construction of ordinary responsive pages, forms, and tables |
| Web deployment | Vercel | Git-based preview and production deployments for Next.js |
| DNS | Cloudflare | DNS, DNSSEC, and separation between domain ownership and hosting |
| Error monitoring | Sentry with EU data location | Mobile, web, and server error/release visibility |
| Product analytics | PostHog EU | Explicit beta product events and later feature flags |
| General CI | GitHub Actions | Formatting, analysis, tests, builds, migrations, and security checks |
| Mobile build/release CI | Codemagic | Hosted macOS builds, signing, TestFlight, and Play distribution |
| Database testing | pgTAP | Constraints, functions, permissions, and RLS behavior |
| Web end-to-end testing | Playwright | Public and admin user journeys |

Exact service tiers and prices are operational choices and must be rechecked when staging or production is provisioned.

## Architectural consequences

### Managed services over a general-purpose VPS

Hostinger or another VPS could run the system, but it would make PLANETS responsible for operating Linux, PostgreSQL, backups, TLS, reverse proxies, storage, realtime infrastructure, monitoring, upgrades, and recovery. That conflicts with the automation goal.

A VPS or self-hosted Supabase remains an option only after a measured requirement makes the additional operational burden worthwhile.

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

The public website and admin interface may use server-side Next.js features, but canonical authorization and domain behavior belong in PostgreSQL functions, RLS policies, or Edge Functions. Mobile and web clients must not implement competing versions of the same business rule.

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

### Proposal-scoped chat only

Chat belongs to a proposal and will be created automatically by one idempotent backend operation. There is no manual Create Chat action, and no fixed three-person threshold controls availability. Plans 05/07 still own the exact participation event and post-membership authorization. Ending a project retains its chat and messages. General direct messaging, calls, reactions, typing indicators, and end-to-end encryption are outside the initial backbone.

An optional meeting URL should be stored or exposed from the proposal chat. PLANETS should not implement video infrastructure or provider OAuth integrations initially.

### Notification delivery uses an outbox and queue

A domain transaction records what happened and appends a notification event. A background worker sends push or email with retry and idempotency. External delivery must not determine whether the underlying proposal operation succeeds.

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

- separate Supabase project;
- separate Firebase configuration;
- preview/staging web deployment;
- test users and test push devices;
- staging Sentry environment;
- production-like migrations and smoke tests.

### Production

- independently configured Supabase, Firebase/APNs, Vercel, Resend, Sentry, and analytics resources;
- EU data locations where supported and appropriate;
- secrets stored in provider secret managers, never in the repository;
- explicit approval gates for migrations, destructive actions, mobile-store submission, and other irreversible operations.

## Deferred alternatives

| Alternative | Why deferred | Reconsider when |
| --- | --- | --- |
| Hostinger/general VPS | High continuing operations and security responsibility | Cost, regulation, or infrastructure control clearly outweighs managed-service value |
| Self-hosted Supabase | Removes managed operations while preserving platform complexity | A concrete hosting or compliance requirement exists |
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
