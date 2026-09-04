# Implementation Roadmap

**Status:** Planning baseline  
**Current implementation:** Plans 00–04A implemented; plan 04B1 in progress

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

| ID  | Plan                                            | Main result                                                                                                              | Dependencies           | Founder input expected                                                                                               | Status      |
| --- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------- |
| 00  | Architecture and repository bootstrap           | Runnable monorepo foundation, local tooling, initial CI, development docs                                                | Documentation baseline | Tool/account installation only if automation cannot provide it                                                       | Implemented |
| 01  | Database foundation and security model (parent) | Secure database workflow plus shared identity, audit, and outbox primitives                                              | 00                     | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 01A | Database workflow and security harness          | Canonical migrations, fail-closed grants, public/private boundary, PostGIS, pgTAP, generated types, and CI replay        | 00                     | None expected                                                                                                        | Implemented |
| 01B | Identity, audit, and outbox primitives          | Auth/profile boundary and minimal shared audit/outbox foundations                                                        | 01A                    | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 02  | Mobile and web application foundations (parent) | Flutter app shell, Next.js public/admin shells, environments, error handling, localization and monitoring foundations    | 00–01                  | No visual polish; only resolve navigation/product-shell ambiguity if material                                        | Implemented |
| 02A | Mobile application foundation                   | Flutter startup, Riverpod/router, typed config, Supabase/Sentry, theme, localization, and state UI                       | 01                     | None expected                                                                                                        | Implemented |
| 02B | Web/admin application foundation                | Next.js public/admin shells and web-side application foundations                                                         | 02A                    | None expected unless current tooling exposes a material ambiguity                                                    | Implemented |
| 03  | Authentication and profiles (parent)            | Public browsing boundary, mobile/web email OTP, profile setup, competences/preferences, privacy-ready profile data       | 01–02                  | Initial required profile fields, visibility rules, competence taxonomy strategy                                      | Implemented |
| 03A | Mobile Email-OTP Authentication                 | Public-first mobile numeric email OTP, Supabase session state, sign-out, and minimal profile-anchor readiness            | 02B                    | None expected                                                                                                        | Implemented |
| 03B | Web Email-OTP Authentication                    | Web email OTP and session behavior using the canonical backend                                                           | 03A                    | None expected for this scoped work                                                                                   | Implemented |
| 03C | Basic Profiles, Skills, and Visibility          | Display-name onboarding, optional bio, controlled starter skills, and per-field public/private visibility                | 03B                    | Initial required fields, starter taxonomy, and basic visibility resolved; advanced profile decisions remain deferred | Implemented |
| 04  | Activity discovery/domain (parent)              | One-time proposals plus separately scoped recurring activities                                                           | 03                     | Proposal fields, lifecycle decisions, broad location behavior                                                        | In progress |
| 04A | One-Time Proposals and Discovery                | Draft/create/publish/cancel, public list/detail, requirements, location privacy, and mobile/web discovery                | 03C                    | One-time lifecycle and rough/exact location behavior resolved                                                        | Implemented |
| 04B | Tavoli / Recurring Activities (parent)          | Versioned weekly/monthly recurring domain plus later mobile/web experience                                                | 04A                    | Initial recurrence and lifecycle resolved; occurrence exceptions remain deferred                                     | In progress |
| 04B1 | Tavoli / Recurring Activity Domain Foundation  | Separate recurring schema, schedule history, bounded occurrences, lifecycle, privacy, canonical APIs, and tests          | 04A                    | None expected for the defined weekly/monthly foundation                                                              | In progress |
| 04B2 | Tavoli Mobile/Web Experience                   | Browse/list/detail/create/edit/manage UI over the canonical 04B1 backend                                                  | 04B1                   | Functional UX review; no recurrence expansion                                                                        | Not started |
| 04C | Material Resources                              | Explicit requested/donated/loaned material-resource domain and later activity integration                               | 04A                    | Resource types, contribution/ownership semantics, visibility, and lifecycle                                           | Not started |
| 05  | Participation lifecycle                         | Join requests, review decisions, membership, leave/cancel behavior, non-chat participation rules, derived stats          | 04A                    | Roles, removal/withdrawal rules, and any non-chat participation thresholds                                           | Not started |
| 06  | Notification backbone                           | In-app notifications, preferences, device registration, outbox/queue, FCM worker, retries and deep links                 | 03–05                  | Notification categories, priority, and copy can remain provisional unless user-facing review is needed               | Not started |
| 07  | Proposal chat                                   | Automatic idempotent chat creation, membership authorization, persisted/realtime text, pagination, push, meeting URL     | 05–06                  | Triggering participation event plus access/moderation after leaving or removal                                       | Not started |
| 08  | Storage and media hardening                     | Purpose-specific buckets, upload restrictions, private/public access, media metadata, cleanup and processing hooks       | 03–07                  | Profile/proposal photo visibility and retention choices                                                              | Not started |
| 09  | Safety, moderation and admin                    | Reporting, blocking, content states, admin roles, moderation queue/actions, audit trail and minimal custom admin UI      | 04–08                  | Community rules, prohibited content, escalation, suspension, appeals, minimum age                                    | Not started |
| 10  | Account deletion and privacy operations         | In-app and web deletion paths, cleanup/anonymization jobs, export groundwork, privacy documentation inputs               | 03–09                  | Legal retention and anonymization policy; legal text remains founder/legal work                                      | Not started |
| 11  | Analytics and operational readiness             | Explicit product events, privacy scrubbing, health checks, alerts, restore procedure and operational runbooks            | 00–10                  | Success metrics and analytics consent/legal choices                                                                  | Not started |
| 12  | Release pipeline and store readiness            | Staging/production deployment, signed mobile builds, internal testing, approval gates and store checklists               | 00–11                  | Provider accounts, billing, certificates, store listings, policies and final approval                                | Not started |

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

This parent plan was completed through two independently reviewed pull requests. Both 02A and 02B are merged.

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

This parent plan was completed through three independently reviewed portions:

- **03A — Mobile Email-OTP Authentication:** implemented numeric-code mobile Auth, sessions, sign-out, and the minimal profile anchor;
- **03B — Web Email-OTP Authentication:** implemented public-first web OTP and cookie-backed SSR session behavior;
- **03C — Basic Profiles, Skills, and Visibility:** implemented display name as the only required field, optional bio, a controlled starter taxonomy, and independent public/private visibility for display name, bio, and skills.

Parent plan 03 is implemented. Advanced profile media, location, organizer-only audiences, and notification preferences remain deferred to their dedicated later plans.

Expected scope:

- anonymous/public read boundary;
- email OTP request and verification;
- application profile creation/completion;
- logout/session recovery;
- profile fields and private/public separation;
- competence/skill relationships;
- profile visibility settings;
- profile edit and basic display screens;
- authorization and RLS tests.

### 04 — Activity discovery/domain

**Goal:** Implement activity discovery through independently reviewable one-time and recurring models.

Parent plan 04 remains in progress while recurring activities are outstanding. Plan 05 depends on implemented 04A one-time proposals, not on future 04B recurrence work.

#### 04A — One-Time Proposals and Discovery

**Status:** Implemented in merged PR #10 (`38341f8e8f2febe09cb5ba05efdf6d448a3d3836`).

Expected scope:

- one-time proposal schema with stored `draft`, `published`, and `cancelled` lifecycle;
- time-derived Upcoming, Happening, Just Finished, and Completed status, including the exact 24-hour Just Finished window;
- draft creation and editing;
- publish/cancel permissions as defined by scope;
- required/useful relationships to the existing controlled skill catalog;
- separate public rough location and protected exact meeting records;
- paginated public/authenticated list and detail queries;
- locality and skill filters;
- sanitized public list/detail functions and owner management functions;
- historical retention as future template-source groundwork, without mutable template records;
- functional Flutter browse/detail/create/edit/my-proposals UI and read-only Next.js discovery;
- database, repository/controller, widget, and integration tests.

#### 04B — Tavoli / Recurring Activities

**Status:** In progress through separately reviewed 04B1 and 04B2 portions.

##### 04B1 — Tavoli / Recurring Activity Domain Foundation

**Status:** In progress in its focused backend/domain pull request.

Expected scope:

- a recurring activity schema physically separate from one-time proposals;
- `draft`, `published`, `paused`, and terminal `ended` lifecycle;
- versioned weekly/monthly local-wall-clock schedules;
- monthly days limited to 1–28 and centrally validated IANA time zones;
- bounded next/window occurrence derivation with daylight-saving coverage;
- separate rough public and protected exact meeting location;
- expected-identity-bound owner mutations, sanitized public APIs, and owner history APIs;
- pgTAP, real two-user/anonymous integration, generated types, and documentation;
- no Tavoli mobile or web UI, participation, chat, notification delivery, or material resources.

##### 04B2 — Tavoli Mobile/Web Experience

**Status:** Not started; depends on reviewed and merged 04B1.

Expected scope:

- distinguish one-time Proposals and Tavoli in Browse;
- mobile Tavoli list, detail, create, edit, pause/resume/end, and management flows;
- read-only public web Tavoli discovery;
- client tests against the canonical 04B1 contracts;
- no free-form recurrence, occurrence exceptions, participation, or chat.

#### 04C — Material Resources

**Status:** Not started and not implemented by 04B1.

PLANETS still needs an explicit domain for material resources that an activity may request, receive as donations, or use on loan. A later scoped plan must define resource types, contributor/owner relationships, handoff/return lifecycle, visibility, and historical behavior before schema or UI is introduced. This gap is recorded so it is not silently collapsed into skills or Tavoli topics.

Neither 04B nor 04C is currently a hard dependency for beginning plan 05 after implemented 04A. A future accepted product decision may revise ordering, but this roadmap does not speculate that material resources must precede participation.

### 05 — Participation lifecycle

**Goal:** Make proposals collaborative through one canonical state machine.

Expected scope:

- join request creation, withdrawal, acceptance, and rejection;
- duplicate/race protection;
- membership and role records;
- leave, removal, and proposal-state interactions as decided;
- owner review interface;
- participant counts and history-derived stats;
- any explicitly selected non-chat participation threshold or activation rule;
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

- exactly one automatically created eligible chat per proposal;
- transactional idempotent creation at the participation event finalized with plans 05/07, without a fixed three-person gate or manual Create Chat action;
- member authorization and historical-access behavior;
- retention of chat/messages when a project ends;
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

1. recurrence expansion/exception semantics before extending beyond the bounded 04B1 weekly/monthly model; 04A rough/exact location visibility is resolved;
2. participation state semantics before plan 05; one-time proposal lifecycle is resolved in 04A;
3. chat access after membership changes before plan 07;
4. moderation/minimum-age policy before plan 09 is complete;
5. retention/anonymization policy before plan 10;
6. success metrics and analytics legal basis before plan 11;
7. production accounts, store material, and approvals before plan 12.

## Immediate next action

Complete, validate, and review **04B1 — Tavoli / Recurring Activity Domain Foundation** without merging from the implementation task. After 04B1 merges, 04B2 may build the Tavoli client experience; plan 05 may proceed independently from implemented 04A.
