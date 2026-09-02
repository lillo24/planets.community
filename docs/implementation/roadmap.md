# Implementation Roadmap

**Status:** Planning baseline  
**Current implementation:** Plans 00 and 01 implemented; plan 02A in progress

This roadmap divides the first PLANETS build into reviewable Codex tasks. Each numbered item should normally become its own implementation prompt, branch, and pull request.

The ordering is intentional: security and canonical data rules are established before feature screens depend on them, while product-heavy visual design is deferred.

## Execution model

For each implementation plan:

1. inspect the current repository and the reports from prior plans;
2. classify relevant behavior as implemented, accepted/intended, or tentative;
3. state required external context and verify whether Codex can access it;
4. implement only the scoped change;
5. add or update automated tests;
6. update repository documentation when behavior or architecture changes;
7. run the relevant validation commands;
8. open a focused pull request;
9. return a structured report covering changes, tests, assumptions, warnings, and unresolved decisions.

Do not begin a dependent plan until the prior plan is merged or its branch is explicitly selected as the base.

## Status legend

- **Not started:** no implementation exists.
- **In progress:** an active Codex task or pull request exists.
- **Blocked:** a required decision/resource is missing.
- **Implemented:** merged and validated in the repository.
- **Deferred:** intentionally outside the current sequence.

## Ordered plans

| ID | Plan | Main result | Dependencies | Founder input expected | Status |
| --- | --- | --- | --- | --- | --- |
| 00 | Architecture and repository bootstrap | Runnable monorepo foundation, local tooling, initial CI, development docs | Documentation baseline | Tool/account installation only if automation cannot provide it | Implemented |
| 01 | Database foundation and security model (parent) | Secure database workflow plus shared identity, audit, and outbox primitives | 00 | Confirm any security-critical ambiguity Codex cannot isolate | Implemented |
| 01A | Database workflow and security harness | Canonical migrations, fail-closed grants, public/private boundary, PostGIS, pgTAP, generated types, and CI replay | 00 | None expected | Implemented |
| 01B | Identity, audit, and outbox primitives | Auth/profile boundary and minimal shared audit/outbox foundations | 01A | Confirm any security-critical ambiguity Codex cannot isolate | Implemented |
| 02 | Mobile and web application foundations (parent) | Flutter app shell, Next.js public/admin shells, environments, error handling, localization and monitoring foundations | 00–01 | No visual polish; only resolve navigation/product-shell ambiguity if material | In progress |
| 02A | Mobile application foundation | Flutter startup, Riverpod/router, typed config, Supabase/Sentry, theme, localization, and state UI | 01 | None expected | In progress |
| 02B | Web/admin application foundation | Next.js public/admin shells and web-side application foundations | 02A | None expected unless current tooling exposes a material ambiguity | Not started |
| 03 | Authentication and profiles | Public browsing boundary, email OTP, profile setup, competences/preferences, privacy-ready profile data | 01–02 | Initial required profile fields, visibility rules, competence taxonomy strategy | Not started |
| 04 | Proposals and discovery | Draft/create/publish, proposal list/detail, requirements, location/filter foundations, public sanitized views | 03 | Proposal fields, lifecycle decisions, broad location behavior | Not started |
| 05 | Participation lifecycle | Join requests, review decisions, membership, leave/cancel behavior, thresholds, derived participation stats | 04 | Threshold semantics, roles, removal/withdrawal rules | Not started |
| 06 | Notification backbone | In-app notifications, preferences, device registration, outbox/queue, FCM worker, retries and deep links | 03–05 | Notification categories, priority, and copy can remain provisional unless user-facing review is needed | Not started |
| 07 | Proposal chat | Eligibility-based chat creation, membership authorization, persisted/realtime text, pagination, push events, meeting URL | 05–06 | Historical access and moderation behavior after leaving/removal | Not started |
| 08 | Storage and media hardening | Purpose-specific buckets, upload restrictions, private/public access, media metadata, cleanup and processing hooks | 03–07 | Profile/proposal photo visibility and retention choices | Not started |
| 09 | Safety, moderation and admin | Reporting, blocking, content states, admin roles, moderation queue/actions, audit trail and minimal custom admin UI | 04–08 | Community rules, prohibited content, escalation, suspension, appeals, minimum age | Not started |
| 10 | Account deletion and privacy operations | In-app and web deletion paths, cleanup/anonymization jobs, export groundwork, privacy documentation inputs | 03–09 | Legal retention and anonymization policy; legal text remains founder/legal work | Not started |
| 11 | Analytics and operational readiness | Explicit product events, privacy scrubbing, health checks, alerts, restore procedure and operational runbooks | 00–10 | Success metrics and analytics consent/legal choices | Not started |
| 12 | Release pipeline and store readiness | Staging/production deployment, signed mobile builds, internal testing, approval gates and store checklists | 00–11 | Provider accounts, billing, certificates, store listings, policies and final approval | Not started |

## Plan details

### 00 — Architecture and repository bootstrap

**Goal:** Create a boring, reproducible development foundation without implementing product behavior.

Expected scope:

- initialize the Flutter app under `apps/mobile`;
- initialize the Next.js TypeScript app under `apps/web`;
- initialize Supabase local-development files;
- establish root scripts or a lightweight task runner for common commands;
- add formatting, linting, analysis, type-checking, and smoke-test commands;
- add initial GitHub Actions validation;
- create environment-example files without secrets;
- document prerequisites and local startup;
- establish architecture decision record conventions;
- preserve the technology and system boundaries already documented.

Non-goals:

- authentication flows;
- final database schema;
- production provider creation;
- polished visual design;
- app-store signing;
- product features.

The output should leave a new contributor able to clone the repository, install documented prerequisites, start local services, and run validation.

### 01 — Database foundation and security model

**Goal:** Establish the conventions every later feature relies on.

This parent plan was completed through two independently reviewed pull requests. Both 01A and 01B are merged.

#### 01A — Database workflow and security harness

Expected scope:

- canonical timestamped SQL migrations and reset-from-zero validation;
- fail-closed `public` object grants and an unexposed `private` schema;
- RLS and default-privilege pgTAP invariants;
- PostGIS enablement in a non-public extension schema;
- generated public database types and type-drift validation;
- full local database validation in CI.

Non-goals include identity/profile data, product tables, audit events, outbox records, notification behavior, and location records.

#### 01B — Identity, audit, and outbox primitives

Expected scope:

- schema ownership and naming conventions;
- Supabase Auth identity to application-profile relationship;
- timestamps, identifiers, soft-delete/content-state conventions where justified;
- role/test identities for policy testing;
- audit-event and transactional-outbox primitives;
- policies and pgTAP coverage for the new shared primitives.

01B depends on merged 01A and should not prematurely define feature tables or product behavior. Together, 01A and 01B create the secure patterns and minimal shared primitives used by later domain migrations.

### 02 — Mobile and web application foundations

**Goal:** Provide stable application shells that later plans can extend without redesigning architecture.

This parent plan is split into two independently reviewed pull requests. It remains in progress until both 02A and 02B are merged; completing 02A alone does not unblock plan 03.

#### 02A — Mobile application foundation

Expected scope:

- restrained feature-first Flutter organization;
- Riverpod 3 and `go_router` foundations;
- typed local/staging/production configuration;
- ordered Supabase initialization and optional privacy-safe Sentry startup;
- neutral Material 3 tokens and responsive basics;
- generated localization and reusable loading/error/empty states;
- local configuration tooling, tests, CI, and mobile development documentation.

02A intentionally excludes auth/profile/product behavior, final navigation, deep links, schema work, and final branding.

#### 02B — Web/admin application foundation

Expected scope:

- Next.js public and admin route groups;
- web-side typed environment and Supabase boundaries;
- Tailwind/shadcn foundation where compatible with the installed Next.js version;
- server/client rendering conventions;
- privacy-safe web monitoring, common states, tests, CI, and documentation.

02B must be prepared from the merged 02A result and current version-matched Next.js documentation rather than from older assumptions.

### 03 — Authentication and profiles

**Goal:** Introduce real users without forcing authentication for public discovery.

Expected scope:

- anonymous/public read boundary;
- email OTP request and verification;
- application profile creation/completion;
- logout/session recovery;
- profile fields and private/public separation;
- competence and interest relationships;
- notification/privacy preference foundations;
- profile edit and basic display screens;
- authorization and RLS tests;
- account-deletion entry point may be a disabled/placeholder path until plan 10, but must not be forgotten.

### 04 — Proposals and discovery

**Goal:** Implement the first core co-creation domain.

Expected scope:

- proposal schema and explicit lifecycle;
- draft creation and editing;
- publish/cancel permissions as defined by scope;
- competence/resource requirements;
- broad and restricted location representation;
- paginated public/authenticated list and detail queries;
- useful filters, including competence relevance where the data permits;
- sanitized public views;
- template-source groundwork without full community-template publishing;
- functional Flutter UI with limited design decisions;
- database, repository/controller, widget, and integration tests.

### 05 — Participation lifecycle

**Goal:** Make proposals collaborative through one canonical state machine.

Expected scope:

- join request creation, withdrawal, acceptance, and rejection;
- duplicate/race protection;
- membership and role records;
- leave, removal, and proposal-state interactions as decided;
- owner review interface;
- participant counts and history-derived stats;
- configurable/default participation threshold;
- canonical backend functions for sensitive transitions;
- outbox events for later notifications;
- full RLS/state-transition tests.

### 06 — Notification backbone

**Goal:** Deliver domain events without coupling external services to transactions.

Expected scope:

- categories and centralized preferences;
- in-app notification records and inbox;
- device-token lifecycle;
- transactional outbox consumption;
- queue worker and retry/idempotency strategy;
- FCM integration using secret placeholders and mocks;
- deep-link payload/version conventions;
- safe previews that avoid private content leakage;
- observable delivery attempts;
- local/staging behavior that cannot accidentally notify production users.

### 07 — Proposal chat

**Goal:** Enable narrow, proposal-specific coordination.

Expected scope:

- exactly one eligible chat per proposal;
- transactional creation when the chosen threshold condition is reached;
- member authorization and historical-access behavior;
- persisted text messages and pagination;
- Supabase Realtime subscription handling;
- send deduplication/error recovery;
- message reporting/deletion-state groundwork;
- push-notification events;
- optional externally created meeting URL;
- no direct messages, calls, reactions, typing indicators, or end-to-end encryption.

### 08 — Storage and media hardening

**Goal:** Support user media without treating storage URLs as authorization.

Expected scope:

- bucket separation by purpose/access;
- file-size and MIME limits;
- database media records and ownership;
- policy-tested uploads, reads, replacements, and deletion;
- private delivery through authenticated or short-lived access;
- thumbnail/metadata-processing hooks where appropriate;
- cleanup jobs and dangling-file detection;
- moderation/publication state;
- safe placeholder UI rather than polished galleries.

### 09 — Safety, moderation and admin

**Goal:** Meet the minimum backbone needed before public user-generated content is released.

Expected scope:

- report and block operations;
- supported target types and reason codes;
- content visibility/moderation states;
- admin/moderator roles with least privilege;
- moderation queue, detail view, and actions;
- internal notes and auditable action history;
- suspension/restriction effects across proposals, participation, and chat;
- rate-limit/abuse hooks;
- support-contact/community-rules surfaces;
- tests that ordinary users cannot access administrative data or actions.

### 10 — Account deletion and privacy operations

**Goal:** Make deletion and privacy behavior operational rather than policy text only.

Expected scope:

- authenticated in-app deletion request and confirmation;
- public web deletion-request resource;
- revocation/session handling;
- immediate versus delayed deletion mechanics;
- cleanup/anonymization based on the approved policy;
- effect on owned proposals, memberships, messages, media, notifications, and audit records;
- retryable cleanup jobs;
- administrator visibility without exposing deleted personal data;
- data-export groundwork if selected;
- store-compliance checklist inputs.

### 11 — Analytics and operational readiness

**Goal:** Observe product behavior and operate failures without collecting unnecessary content.

Expected scope:

- explicit PostHog event vocabulary tied to product questions;
- no automatic capture/session replay by default;
- Sentry scrubbing and environment/release metadata;
- health and queue-lag checks;
- alert thresholds and ownership;
- database backup verification and restore rehearsal documentation;
- billing/spend-alert checklist;
- incident and rollback runbooks;
- dependency/security update process.

### 12 — Release pipeline and store readiness

**Goal:** Produce controlled staging and production releases.

Expected scope:

- environment-specific Supabase, web, Firebase, email, monitoring, and analytics configuration;
- migration and Edge Function deployment workflow;
- Vercel preview/staging/production behavior;
- Codemagic Android and iOS build pipelines;
- signing/certificate placeholders and secure setup instructions;
- TestFlight and Play internal-testing distribution;
- manual approval gates for production and store submission;
- versioning and release notes;
- privacy/data-safety/store-review checklists;
- smoke tests and rollback paths.

## Work Codex can perform with low supervision

Codex can usually implement:

- repository and local-tooling foundations;
- schemas, constraints, functions, policies, and automated tests after product states are defined;
- ordinary Flutter and Next.js shells/components;
- authentication plumbing;
- CRUD and pagination;
- join-request mechanics;
- notification/outbox/queue infrastructure;
- proposal-scoped chat infrastructure;
- storage policies;
- moderation/admin mechanics;
- CI, documentation, fixtures, and runbooks.

## Work requiring founder or account-owner action

Codex cannot independently supply or approve:

- service accounts, billing, domains, certificates, and production secrets;
- Apple/Google developer enrollment;
- product taxonomy and final user-facing policy decisions;
- moderation, retention, minimum-age, and legal rules;
- privacy policy, terms, and app-store declarations;
- final visual identity and high-impact UX decisions;
- the donation/payment model;
- production deployment approval.

For provider setup, Codex should prepare exact instructions and placeholders. It must stop rather than fabricate inaccessible credentials or claim an external resource was configured.

## Decision gates

A plan should pause before implementation when ambiguity can change security, irreversible data structure, legal behavior, or the central user flow. It should not pause for low-risk implementation details that can be selected consistently with repository conventions.

Major gates currently expected:

1. profile/location visibility before plans 03–04 are finalized;
2. proposal and participation state semantics before plans 04–05;
3. chat access after membership changes before plan 07;
4. moderation/minimum-age policy before plan 09 is complete;
5. retention/anonymization policy before plan 10;
6. success metrics and analytics legal basis before plan 11;
7. production accounts, store material, and approvals before plan 12.

## Immediate next action

Complete and merge **02A — Mobile application foundation**, then prepare **02B — Web/admin application foundation** from the actual merged result. Keep parent plan 02 in progress and do not start plan 03 until both portions are merged.
