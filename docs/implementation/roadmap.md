# Implementation Roadmap

**Status:** Planning baseline  
**Current implementation:** Plans 00–04B2B, 04C1–04C2, 05A, 05B, 05D, 06A, 06B, provider-independent 06C1, provider-neutral 06C2A, 06D, 07A, 07B1, 07B2B, 07B2C, and public informational SITE-00 through SITE-02 plus SITE-02W implemented; 04C3A and stacked 04C3B1/04C3B2/04C3C1/04C3C2/04C3D1/04C3D2/04C3D3A/04C3D3B1/04C3D3B2/05C1/05C2 are in progress; provider-specific 06C2B and 04C4 remain not started

This roadmap divides the first PLANETS build into reviewable Codex tasks. Each numbered item should normally become its own implementation prompt, branch, and pull request.

The ordering is intentional: security and canonical data rules are established before feature screens depend on them, product-heavy visual design is consolidated after the main functional feature set, and self-hosted production infrastructure is proven only after that UI/UX pass and before public release.

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

| ID     | Plan                                                      | Main result                                                                                                            | Dependencies           | Founder input expected                                                                                               | Status      |
| ------ | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------- |
| 00     | Architecture and repository bootstrap                     | Runnable monorepo foundation, local tooling, initial CI, development docs                                              | Documentation baseline | Tool/account installation only if automation cannot provide it                                                       | Implemented |
| 01     | Database foundation and security model (parent)           | Secure database workflow plus shared identity, audit, and outbox primitives                                            | 00                     | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 01A    | Database workflow and security harness                    | Canonical migrations, fail-closed grants, public/private boundary, PostGIS, pgTAP, generated types, and CI replay      | 00                     | None expected                                                                                                        | Implemented |
| 01B    | Identity, audit, and outbox primitives                    | Auth/profile boundary and minimal shared audit/outbox foundations                                                      | 01A                    | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 02     | Mobile and web application foundations (parent)           | Flutter app shell, Next.js public/admin shells, environments, error handling, localization and monitoring foundations  | 00–01                  | No visual polish; only resolve navigation/product-shell ambiguity if material                                        | Implemented |
| 02A    | Mobile application foundation                             | Flutter startup, Riverpod/router, typed config, Supabase/Sentry, theme, localization, and state UI                     | 01                     | None expected                                                                                                        | Implemented |
| 02B    | Web/admin application foundation                          | Next.js public/admin shells and web-side application foundations                                                       | 02A                    | None expected unless current tooling exposes a material ambiguity                                                    | Implemented |
| 03     | Authentication and profiles (parent)                      | Public browsing boundary, mobile/web email OTP, profile setup, competences/preferences, privacy-ready profile data     | 01–02                  | Initial required profile fields, visibility rules, competence taxonomy strategy                                      | Implemented |
| 03A    | Mobile Email-OTP Authentication                           | Public-first mobile numeric email OTP, Supabase session state, sign-out, and minimal profile-anchor readiness          | 02B                    | None expected                                                                                                        | Implemented |
| 03B    | Web Email-OTP Authentication                              | Web email OTP and session behavior using the canonical backend                                                         | 03A                    | None expected for this scoped work                                                                                   | Implemented |
| 03C    | Basic Profiles, Skills, and Visibility                    | Display-name onboarding, optional bio, controlled starter skills, and per-field public/private visibility              | 03B                    | Initial required fields, starter taxonomy, and basic visibility resolved; advanced profile decisions remain deferred | Implemented |
| 04     | Activity discovery/domain (parent)                        | One-time proposals plus separately scoped recurring activities                                                         | 03                     | Proposal fields, lifecycle decisions, broad location behavior                                                        | Implemented |
| 04A    | One-Time Proposals and Discovery                          | Draft/create/publish/cancel, public list/detail, requirements, location privacy, and mobile/web discovery              | 03C                    | One-time lifecycle and rough/exact location behavior resolved                                                        | Implemented |
| 04B    | Tavoli / Recurring Activities (parent)                    | Versioned weekly/monthly recurring domain plus later mobile/web experience                                             | 04A                    | Initial recurrence and lifecycle resolved; occurrence exceptions remain deferred                                     | Implemented |
| 04B1   | Tavoli / Recurring Activity Domain Foundation             | Separate recurring schema, schedule history, bounded occurrences, lifecycle, privacy, canonical APIs, and tests        | 04A                    | None expected for the defined weekly/monthly foundation                                                              | Implemented |
| 04B2   | Tavoli Mobile/Web Experience (parent)                     | Separate mobile and public-web clients over the canonical 04B1 backend                                                 | 04B1                   | Functional UX review; no recurrence expansion                                                                        | Implemented |
| 04B2A  | Tavoli Mobile Experience and Browse Integration           | Mobile browse/list/detail/create/edit/manage UI over the canonical 04B1 backend                                        | 04B1                   | Native interaction review                                                                                            | Implemented |
| 04B2B  | Public Web Tavoli Discovery                               | Read-only public web Tavoli list and detail                                                                            | 04B2A                  | Functional public-web review                                                                                         | Implemented |
| 04C    | Resources + Scambio-Dona                                  | Standalone Scambio-Dona listings plus later Project resources, requests, matching, and notifications                   | 04A                    | Transaction/handoff, taxonomy, Project contribution, and matching decisions remain split into later slices           | In progress |
| 04C1   | Scambio-Dona Listing Domain Foundation                    | Owner lifecycle, rough-location public discovery, secure RPCs, identifier-only events, and tests                       | 04A, 03C               | None for the decision-light discovery-intent foundation                                                              | Implemented |
| 04C2   | Scambio-Dona Mobile Discovery and Owner Experience        | Mobile browse/detail/create/edit/publish/close experience over the 04C1 contracts                                      | 04C1                   | Native QA deferred to the consolidated Plan 12 pass                                                                  | Implemented |
| 04C3   | Project Resource Needs and Contribution Offers (parent)   | Project needs followed by request-linked contribution offers without collapsing them into standalone listings          | 04A, 04B1, 05A         | Contribution attribution/correction semantics remain later                                                           | In progress |
| 04C3A  | Project Resource Needs Domain Foundation                  | Stable Project-owned plain-text needs, lifecycle-aware creator/public reads, identifier-only events, and tests         | 04A, 04B1, 05A         | None for the decision-light open/closed need foundation                                                              | In progress |
| 04C3B  | Join-Request Contribution Selection + Mobile/Messages     | Request-attempt selection domain followed by mobile selection and structured Messages labels                           | 04C3A, 05A, 07A        | Accepted mutable commitments remain separate                                                                         | In progress |
| 04C3B1 | Join-Request Contribution Selection Domain                | Atomic historical Proposal-skill/Project-need ID selections with private requester/creator reads                       | 04C3A, 05A, 07A        | Tavolo skills wait for a canonical recurring requirement relation                                                    | In progress |
| 04C3B2 | Mobile Selection + Rounded Messages Labels                | Flutter request-selection controls, Project-need owner UI, and structured Messages labels                              | 04C3B1                 | Native interaction review deferred to Plan 12                                                                        | In progress |
| 04C3C  | Accepted Participant Contribution Commitments (parent)    | Membership-scoped current expectations followed by a separately decided mobile management surface                      | 04C3B1, 05A            | Mobile edit location and delegated management remain separate decisions                                              | In progress |
| 04C3C1 | Current Commitment Domain Foundation                      | Membership-episode skill/resource sets, acceptance seeding, lifecycle-safe replacement, private reads, and tests       | 04C3B1, 05A            | None for participant plus canonical-creator backend ownership                                                        | In progress |
| 04C3C2 | Mobile Commitment Management                              | Participant and creator editing experience over the 04C3C1 domain                                                      | 04C3C1                 | Native interaction review; delegated/co-organizer authorization                                                      | In progress |
| 04C3D  | Acceptance Triage and Live Project Coverage (parent)      | Immutable creator acceptance decisions followed by mobile triage and current Project-need coverage coordination        | 04C3B1, 04C3C1, 05A    | External/manual coverage and delegate policy remain later decisions                                                  | In progress |
| 04C3D1 | Join-Acceptance Contribution Triage Domain                | Exact needed/already-found/extra decisions, selective commitment seeding, historical backfill, and concurrency tests   | 04C3C1                 | None for canonical-creator backend ownership                                                                         | In progress |
| 04C3D2 | Mobile Join-Acceptance Contribution Triage                | Mandatory three-way creator decision UI over every selected request contribution                                       | 04C3D1, 04C3B2, 07A    | Native interaction review; delegated/co-organizer authorization                                                      | In progress |
| 04C3D3 | Live Need Coverage + Group Coordination (parent)          | Backend live requirement truth followed by group-chat coordination and resurfacing                                      | 04C3D1, 04C3D2, 07B2C  | Delegate policy remains separate                                                                                     | In progress |
| 04C3D3A | Live Project Requirement Coverage Domain                | Participant/manual sources, exact coverage transitions, lifecycle cleanup, claim/manual/read RPCs, and tests            | 04C3D1, 04C3D2          | None for canonical creator/current-participant backend ownership                                                     | In progress |
| 04C3D3B | Group Needs Coordination + Chat Resurfacing              | Chat Needs drawer, participant claim UI, creator manual control, system messages, notifications, and attention UX       | 04C3D3A, 07B2C, 06D     | Delegate policy remains separate; native interaction review remains Plan 12                                          | In progress |
| 04C4   | Listing Requests/Handoff + Saved Search/Matching          | Post-discovery request/handoff rules plus explainable saved-search and matching behavior                               | 04C1                   | Exchange, request, handoff, contact, matching, and notification semantics                                            | Not started |
| 05     | Participation lifecycle (parent)                          | Shared project participation foundation, later mobile experience, and verified-contribution review                     | 04A, 04B1              | Capacity/fullness and later contribution/resource semantics remain unresolved                                        | In progress |
| 05A    | Project Participation Domain Foundation                   | Shared identity, private join requests, canonical membership history, protected meeting access, events, and tests      | 04A, 04B1              | No blocking decision; 07B1 derives chat activation from accepted membership                                          | Implemented |
| 05B    | Mobile Project Participation Experience                   | Join/status/withdraw, creator review, member state, leave/remove, and protected meeting UI                             | 05A                    | Functional/native UX review                                                                                          | Implemented |
| 05D    | Participation-Aware Browse and Pending Request Visibility | Own pending requests promoted in mobile Proposal/Tavolo Browse without changing public pagination                      | 04A, 04B1, 05A, 05B    | Native QA deferred to the consolidated Plan 12 pass                                                                  | Implemented |
| 05C    | One-Time Project Actual Contribution Attribution (parent)  | Derived final-commitment attribution, sparse creator corrections, and a later mobile experience                         | 05A, 04C3D3B           | Delegate scope, participant reminder/correction flow, and Tavoli finalization                                         | In progress |
| 05C1   | Actual Contribution Attribution Domain                     | Membership-at-end baseline, sparse creator overrides/additions, effort marker, secure RPCs, events, and tests           | 05A, 04C3D3B           | None for canonical creator-only one-time Project ownership                                                            | In progress |
| 05C2   | Mobile Actual Contribution Experience                      | Participant read-only visibility plus creator post-end correction UI                                                    | 05C1, 05B              | Native interaction review; participant-to-creator reminder remains a separate future follow-up                       | In progress |
| 06     | Notification backbone (parent)                            | Canonical notification projection, later mobile inbox/preferences, then device registration and push delivery          | 03–05A                 | User-facing notification UX/copy and push behavior remain later review points                                        | In progress |
| 06A    | Notification Domain and Outbox Projection Foundation      | Categories/preferences, semantic inbox records/targets, multi-consumer receipts, participation projection, secure APIs | 01B, 05A               | None expected for the defined participation foundation                                                               | Implemented |
| 06B    | Mobile In-App Notifications and Preferences               | Flutter inbox, unread state, preference controls, and structured project/request navigation                            | 06A                    | Native QA deferred by founder for a later consolidated pass; not passed or failed                                    | Implemented |
| 06C    | Push Delivery (parent)                                    | Provider-independent installation/jobs followed by Firebase mobile registration and trusted delivery                   | 06A, 06B               | Push permission timing, preview policy, and provider/account-owner setup                                             | In progress |
| 06C1   | Push Installation and Delivery-Job Foundation             | Private app installations, shared semantic resolution, independent `push.v1` projection, and recipient-level jobs      | 06A, 06B               | None; uses synthetic tokens and no provider account                                                                  | Implemented |
| 06C2   | Provider Delivery Integration (parent)                    | Provider-neutral worker protocol followed by Flutter registration and the repository-owned FCM adapter                 | 06C1                   | Firebase/APNs setup, permission timing, preview policy, credentials, and worker deployment                           | In progress |
| 06C2A  | Push Delivery Attempt and Worker-Protocol Foundation      | One-time installation fan-out, leases, safe attempt history, retries, terminal aggregation, and stale-token guards     | 06C1                   | None; uses synthetic outcomes and no provider account                                                                | Implemented |
| 06C2B  | Firebase Mobile Registration and FCM Adapter              | Flutter token/permission lifecycle plus repository-owned FCM HTTP v1 sends over the trusted 06C2A protocol             | 06C2A                  | Firebase Android/iOS config, APNs setup, permission timing, preview policy, credentials, and worker hosting          | Not started |
| 06D    | Project Chat Notification Projection and Mobile Alerts    | Message-time recipient fan-out into body-free in-app notifications and semantic push jobs, plus mobile chat alerts     | 06A, 06B, 06C1, 07B2C  | Native QA remains deferred to Plan 12; provider delivery remains 06C2B                                               | Implemented |
| 07     | Messages + Project Chat (parent)                          | Structured request items, Project-chat lifecycle authorization, and server-authorized realtime/mobile conversation     | 05A, 06A               | Native QA remains in Plan 12; later moderation overrides remain Plan 09                                              | Implemented |
| 07A    | Messages Surface and Structured Participation Requests    | Authenticated Messages inbox with canonical actionable join-request items                                              | 05A, 06A               | Functional/native UX review and final Messages information architecture                                              | Implemented |
| 07B    | Project Group Chat (parent)                               | First-accept lifecycle/authorization foundation followed by messaging, Realtime, and mobile group experience           | 05A, 07A               | Optional E2EE research remains deferred; native QA remains in Plan 12                                                | Implemented |
| 07B1   | Project Group Chat Lifecycle and Authorization Foundation | One chat per Project, first-accept activation, and ownership/membership-derived current and historical entitlement     | 05A, 07A               | None for the scoped structural foundation                                                                            | Implemented |
| 07B2   | Project Chat Messaging, Realtime and Mobile Experience    | Authorized plain-text message model, Realtime hints, mobile chat/group info, and protected meeting access              | 07B1                   | Native QA remains deferred to Plan 12; optional E2EE research remains unmerged                                       | Implemented |
| 08     | Storage and media hardening                               | Select the production media approach, then implement purpose-specific access, metadata, cleanup, and processing hooks  | 03–07                  | Profile/proposal photo visibility, retention, and self-hosted Supabase Storage versus external object storage        | Not started |
| 09     | Safety, moderation and admin                              | Reporting, blocking, content states, admin roles, moderation queue/actions, audit trail and minimal custom admin UI    | 04–08                  | Community rules, prohibited content, escalation, suspension, appeals, minimum age                                    | Not started |
| 10     | Account deletion and privacy operations                   | In-app and web deletion paths, cleanup/anonymization jobs, export groundwork, privacy documentation inputs             | 03–09                  | Legal retention and anonymization policy; legal text remains founder/legal work                                      | Not started |
| 11     | Analytics and operational foundations                     | Explicit product events, privacy scrubbing, health/queue signals, alert requirements, and incident ownership inputs    | 00–10                  | Success metrics and analytics consent/legal choices                                                                  | Not started |
| 12     | Consolidated UI/UX and native QA pass                     | Coherent visual/interaction design, accessibility, responsive behavior, and deferred native flow validation            | 00–11                  | Final visual identity, high-impact interaction decisions, and native review                                          | Not started |
| 13     | Self-hosted production infrastructure readiness           | Provisioned and rehearsed production Supabase stack, security, backups, monitoring, operations, and cutover plan       | 00–12                  | Host/account selection, billing, DNS, credentials, retention objectives, and production-operation approval           | Not started |
| 14     | Release pipeline and store readiness                      | Controlled releases over the proven production backend, signed builds, internal testing, gates, and store checklists   | 00–13                  | Provider accounts, certificates, store listings, policies, and final release approval                                | Not started |

## Public informational site mini-track

This independent mini-track adds the static public launch site without changing
the dependencies or responsibilities in the main 00–14 product sequence.

| ID       | Plan                                            | Main result                                                     | Dependencies     | Founder/account-owner input expected                       | Status                                                             |
| -------- | ----------------------------------------------- | --------------------------------------------------------------- | ---------------- | ---------------------------------------------------------- | ------------------------------------------------------------------ |
| SITE-00  | Static informational site foundation            | Vite/React workspace, placeholder, root tooling, CI, and docs   | Repository state | None                                                       | Implemented in PR #23 (`8b35ea95f44be39756bb0269da369827b63178d9`) |
| SITE-01  | Public content and visual landing page          | Founder-approved content, logo, visual identity, and page shell | SITE-00          | Public contact and legal-controller details remain         | Implemented in PR #25 (`3db7492e9b4ad6a33beb5f73c3ea1c394e7cf942`) |
| SITE-02  | One-time launch waitlist                        | Consent-aware signup for one app-launch notification            | SITE-01          | Controller/contact and production Cloudflare inputs remain | Implemented                                                        |
| SITE-02W | Workers runtime migration                       | Native Worker API plus Workers Static Assets                    | SITE-02          | None; production resources remain SITE-03                  | Implemented                                                        |
| SITE-03  | Cloudflare production deployment/domain cutover | Hosted static site and authorized `planets.community` cutover   | SITE-01–SITE-02W | Provider access, DNS access, billing, and cutover approval | Not started                                                        |
| SITE-04  | Launch notification and waitlist retirement     | One launch notice followed by approved waitlist retirement      | SITE-02–SITE-03  | App-release timing and retention/deletion approval         | Deferred until app release                                         |

The SITE-02 address is solely for one notification when the PLANETS app
launches. It is not a newsletter and must not be reused for marketing,
promotions, recurring product updates, profiling, or unrelated communications.
SITE-02 adds a local/CI-tested server-side waitlist handler, Turnstile
verification, and minimal D1 persistence without deploying production
resources. SITE-02W runs that handler in a native Worker beside Workers Static
Assets without changing its contract. SITE-03 provisions and verifies the
production Cloudflare resources, approved hostname, controller/contact
information, deployment, and domain cutover. SITE-04 remains responsible for
the one launch notification and approved waitlist retirement.

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

Parent plan 04 has 04A and 04B implemented while 04C is in progress through its implemented 04C1 listing foundation and current 04C2 mobile client. Shared participation depends on both concrete activity-domain foundations; standalone listings remain separate.

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

**Status:** Implemented through separately reviewed 04B1, 04B2A, and 04B2B portions.

##### 04B1 — Tavoli / Recurring Activity Domain Foundation

**Status:** Implemented in merged PR #11 (`fa33681b66a2fd83d26ddcc2247e9896910ac574`).

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

**Status:** Implemented through independently reviewed mobile and web portions.

Expected scope:

- distinguish one-time Proposals and Tavoli in Browse;
- mobile Tavoli list, detail, create, edit, pause/resume/end, and management flows;
- read-only public web Tavoli discovery;
- client tests against the canonical 04B1 contracts;
- no free-form recurrence, occurrence exceptions, participation, or chat.

###### 04B2A — Tavoli Mobile Experience and Browse Integration

**Status:** Implemented in merged PR #12 (`1d5871ced35bc56efa6758060434ec61d06f98dc`).

Owns the Flutter-only Browse integration, public Tavoli discovery, constrained
weekly/monthly authoring, future/pending schedule correction, owner lifecycle
management, identity-safe controllers, and the manual Android/iOS QA gate.
Its native Android/iOS interaction QA was confirmed passed by the founder
during the 04B2B review.

Accepted future Browse direction: when a signed-in user has a pending join
request for a Project or Tavolo, surface that item ahead of ordinary results
where practical and distinguish it with a Requested treatment. This excludes
historical rejected/withdrawn requests, does not change signed-out ordering,
and leaves ranking relative to owned/current-participation projects for later
UX work. Plan 06C1 records the direction but does not implement list enrichment,
extra RPCs, ranking, or UI.

###### 04B2B — Public Web Tavoli Discovery

**Status:** Implemented in merged PR #13 (`ccee48f68699702efeaeda160db1f27115a4d5df`).

Owns read-only public web Tavoli list/detail, route-backed Proposal/Tavoli
navigation, snapshot-safe pagination, named-zone rendering, and public-location
privacy over the canonical 04B1 APIs. It does not copy mobile owner management
or introduce participation, chat, resources, or recurrence expansion.

#### 04C — Resources + Scambio-Dona

**Status:** In progress through implemented 04C1–04C2 and the current stacked 04C3A/04C3B1/04C3B2/04C3C1/04C3C2/04C3D1/04C3D2 work. Live coverage, request/handoff, saved-search, matching, and notification slices remain later work.

The earlier combined scope is split so standalone public listings do not force unresolved Project contribution or post-discovery transaction rules:

##### 04C1 — Scambio-Dona Listing Domain Foundation

**Status:** Implemented in merged PR #32 (`2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42`). Depends on merged 04A and 03C.

Owns standalone owner-managed `resource_listings`, `donate`/`exchange` discovery intent, private incomplete drafts, published rough-location discovery/detail, terminal closure, expected-identity-bound owner APIs, profile-display visibility, mode/locality/literal-keyword filtering, newest-first paired keyset pagination, identifier-only publish/close events, pgTAP, local integration, generated contracts, and documentation.

`exchange` does not define lending, barter, ownership transfer, return, payment, reservation, contact, or handoff mechanics. 04C1 also adds no resource taxonomy, media, Project linkage, saved searches, matching, notifications, quantities, prices, or transaction/request records.

##### 04C2 — Scambio-Dona Mobile Discovery and Owner Experience

**Status:** Implemented in merged PR #34 (`2da76de112a860210161d64de6bceab333159c26`). Depends on merged 04C1.

Owns the primary text-only Flutter browse/detail and owner create/edit/publish/close experience over the canonical 04C1 contracts. Home exposes `Progetti` and `Scambio-Dona` as separate pillars while the persistent Profile / Browse / Home destinations remain unchanged. Public discovery/detail stays signed-out; management preserves Auth/profile-setup return intent. No request, claim, contact, transaction, or handoff flow is introduced; those semantics remain 04C4. Media remains Plan 08.

##### 04C3 — Project Resource Needs and Contribution Offers (parent)

**Status:** In progress through stacked 04C3A, 04C3B1, 04C3B2, 04C3C1, 04C3C2, open PR #63 for 04C3D1, and the current 04C3D2 mobile work. Depends on 04A, 04B1, and 05A.

This parent keeps Project-owned needs and later request-linked contribution offers separate from standalone Scambio-Dona listings and from accepted membership.

###### 04C3A — Project Resource Needs Domain Foundation

**Status:** Open in PR #45, rebased onto current `main`, and intentionally unmerged while executable Database validation is unavailable. Depends on merged 04A, 04B1, and 05A.

Owns stable UUID needs attached to `public.projects`, bounded plain-text title/optional details, exact `open`/terminal `closed` state, creator-only lifecycle-aware mutations, retained creator history, currently-joinable public reads, identifier-only events, restrictive grants, pgTAP, real Proposal/Tavolo integration, concurrency coverage, and generated contracts. Closure means only that the Project is no longer asking; no fulfillment or attribution is inferred.

04C3A adds no taxonomy, quantity/unit/price/priority, contributor/request/membership linkage, free-form offers, Messages/mobile changes, notifications, or Scambio-Dona linkage.

###### 04C3B — Join-Request Contribution Selection + Mobile/Messages (parent)

**Status:** In progress through the stacked 04C3B2 mobile layer. Depends on 04C3A, 05A, and 07A.

This parent lets a requester select canonical Project competence/skill IDs and open Project resource-need IDs, attaches those selections to the stable join request, and later shows them as structured labels in Messages/mobile beside the existing optional request message. It must not introduce a generic free-text contribution category.

###### 04C3B1 — Join-Request Contribution Selection Domain

**Status:** Open in PR #52, rebased onto the current PR #45 head, and intentionally unmerged while executable Database validation is unavailable.

Owns immutable request-attempt skill/resource ID relations, an optional-array evolution of the existing atomic join-request RPC, Proposal current-requirement and open same-Project need validation, empty-only Tavolo skill input, requester/creator-only current-label resolution, retained withdraw/reject/accept history, unchanged identifier-only events, and focused pgTAP/real-OTP/concurrency coverage. Existing three-argument callers create zero selections. Later Proposal-skill removal, need rename, and need closure preserve the selected IDs.

04C3B1 adds no Flutter UI, Tavolo skill-requirement relation, free-form contribution category, quantity/price, unsolicited offer, mutable accepted commitment, verification, notification expansion, matching, or Scambio-Dona link.

###### 04C3B2 — Mobile Selection + Rounded Messages Labels

**Status:** In progress in the current stacked mobile PR, based on PR #52 without merging any layer. Depends on 04C3B1.

The scoped Flutter layer adds independent public open-need sections on Proposal/Tavolo detail, expected-identity creator add/edit/terminal-close history, and protected `/proposals/:id/resources` / `/tavoli/:id/resources` routes. Join requesters select canonical Proposal-skill and open Project-need IDs with Material chips while retaining the optional private message; Tavoli remain resource-only until a separate plan defines canonical recurring skill requirements. Submission waits for canonical options, and stale backend validation reloads/prunes IDs without discarding the message.

Structured Messages detail independently resolves current canonical labels for historical request selections and renders rounded skill/resource groups beside the existing message. A selection-read failure stays local and never hides Accept/Reject/Withdraw. Inbox rows do not fan out selection reads. 04C3B2 adds no migration, Tavolo skill relation, accepted commitment, fulfillment inference, Realtime, notification, or Scambio-Dona linkage.

###### 04C3C — Accepted Participant Contribution Commitments (parent)

**Status:** In progress through the current stacked 04C3C2 mobile layer. Depends on 04C3B1 and 05A.

Request selections remain immutable historical intent. Membership commitments are the separate mutable current expectation owned by one accepted membership episode. Verified actual contribution remains later in 05C.

###### 04C3C1 — Current Commitment Domain Foundation

**Status:** In progress in stacked backend PR #61, based on open PR #60 without merging any layer. Depends on 04C3B1 and 05A.

Owns fail-closed membership-scoped skill/resource commitment relations, atomic acceptance seeding and existing-membership backfill, participant/canonical-creator compare-and-swap full-set replacement, current-or-ended private commitment reads, current-membership addable-option snapshots with canonical labels, Proposal/Tavolo lifecycle and current-option validation for additions, retained stale commitments, identifier-only update events without notifications, and focused pgTAP/real-OTP/concurrency coverage. Replacement requires the caller's loaded current IDs so participant and creator cannot silently overwrite stale edits. It does not rewrite request selections or add fulfillment, verification, delegation, quantities, Tavolo skill requirements, Flutter UI, or Scambio-Dona linkage.

###### 04C3C2 — Mobile Commitment Management

**Status:** In progress in the current stacked mobile PR, based on open PR #61 without merging any layer. Depends on 04C3C1.

Uses Project-chat group info for current-participant `My commitments` editing and former-participant `Last commitments` history, resolving the current episode after a rejoin and the latest ended episode for a former member. Creator Manage participation adds lazy per-membership actions and reuses the same editor without per-row RPC fan-out. Current/final commitment reads stay separate from addable options; retained stale commitments remain explicit and removable; writes preserve loaded expected snapshots for compare-and-swap recovery. Messages request selections remain immutable historical intent. Native Android/iOS interaction review is deferred to Plan 12, and delegated/co-organizer Project management remains a separate future product and authorization plan.

###### 04C3D — Acceptance Triage and Live Project Coverage (parent)

**Status:** In progress through open PR #63 for 04C3D1 and the current stacked 04C3D2 mobile layer. Depends on 04C3B1, 04C3C1, and 05A.

This parent keeps five states explicit: request selection is the requester's historical offer; acceptance decision is the organizer's immutable decision at one acceptance; current commitment is the membership's mutable expectation; live Project coverage is the current need-to-participant/external state; final actual contribution is the later one-time completion attribution. None is a person rating, and no earlier layer is proof of delivery.

###### 04C3D1 — Join-Acceptance Contribution Triage Domain

**Status:** In progress in open PR #63, based on open PR #62 without merging any layer. Depends on 04C3C1.

Owns immutable per-selection `needed`/`already_found`/`extra` decisions, exact-partition triaged acceptance, current-validity checks only for `needed`, zero-selection-only two-argument compatibility, selective needed-plus-extra commitment seeding, a fail-closed membership trigger, deterministic existing-history backfill, independent rejoins, identifier-only events, and focused pgTAP/real-OTP/concurrency coverage. It does not add mobile UI, live coverage, fulfillment, final attribution, delegates, or ratings.

###### 04C3D2 — Mobile Join-Acceptance Contribution Triage

**Status:** In progress in the current stacked mobile PR, based on open PR #63 without merging any layer. Depends on 04C3D1, 04C3B2, and 07A.

Adds one participation-owned triage sheet shared by Manage participation and Messages request detail. It lazily reads only the tapped request, requires the canonical Project creator to classify every offered skill/resource as Needed, Already found, or Extra, and calls only the explicit triaged backend overload, including six empty arrays for zero offers. Unclassified items receive an accessible error border, brief reduced-motion-safe shake, and one explanatory tooltip. Safe stale-need/conflict/authorization recovery preserves the backend's exact-partition authority; surrounding participation, Messages, inbox, and chat projections reload canonically after the flow.

###### 04C3D3 — Live Need Coverage + Group Coordination (parent)

**Status:** In progress through open PR #65 for 04C3D3A and the current stacked 04C3D3B1 backend layer. Depends on 04C3D1, 04C3D2, and the Project-chat experience.

Owns the current coverage projection, initialization from `needed` decisions, need-reappearance events, chat needed-items coordination, participant claim flow, creator manual-found control, and attention behavior without reinterpreting the 04C3A `open`/`closed` lifecycle as coverage.

###### 04C3D3A — Live Project Requirement Coverage Domain

**Status:** In progress in open PR #65, based on open PR #64 without merging any layer. Depends on 04C3D1 and 04C3D2.

Owns fail-closed participant and manual/external coverage sources, deterministic history backfill, acceptance initialization, membership/commitment/requirement cleanup, exact identifier-only covered and needed-again transitions, Project-level serialization, current-participant claim with optional atomic commitment creation, creator manual coverage control, and a private creator/current-member normalized read. `extra` commitments remain uncovered until explicitly claimed; conservative `already_found` creates a manual source only when no tracked live source exists. Public discovery, provider identities, chat UI, notifications, final contribution, and delegate permissions remain outside this layer.

###### 04C3D3B — Group Needs Coordination + Chat Resurfacing

**Status:** In progress through the current stacked 04C3D3B1 backend layer. Depends on 04C3D3A, 07B2C, and 06D.

Owns the structured group projection and mobile coordination experience built on D3A. It uses canonical coverage reads/mutations and must not read coverage tables directly, fake system users, copy localized text into history, or expose provider identities.

###### 04C3D3B1 — Structured Group Need Resurfacing + Attention Domain

**Status:** In progress in the current stacked backend PR, based on open PR #65 without merging any layer. Depends on 04C3D3A and the Project-chat message/Realtime domain.

Adds immutable identifier-only `requirement_needed_again` system history, one historically authorized mixed message/system feed, current-entitlement Realtime coverage signals on the existing private chat topic, system-aware chat-list activity, and a per-profile monotonic acknowledgement frontier whose attention remains true only for current uncovered operational requirements. Human chat messages remain sender-required and unchanged. No global notification projection or mobile UI is added.

###### 04C3D3B2 — Mobile Needs Drawer + Chat Coordination

**Status:** In progress in the current stacked mobile PR, based on open PR #66 without merging the lower stack. Depends on 04C3D3B1 and 04C3D3A.

Project chat detail now consumes the strict mixed human/system feed and exact three-part keyset cursor. Current creators and participants get a composer-side Needs control backed by independent RPC-only coverage and attention state, an upward scroll-controlled drawer, participant claim or creator manual-coverage actions, persistent resurfacing attention, and an explicit-frontier acknowledgement only after refreshed current Needs render. Former members keep authorized historical system cards but perform no live-Needs reads. All three Realtime hints reuse the existing private chat topic; native drawer, animation, accessibility, multi-device race, restart, and lifecycle interaction review is deferred to Plan 12 and is not marked passed or failed here.

##### 04C4 — Listing Requests/Handoff + Saved Search/Matching

**Status:** Not started. Depends on 04C1 and founder decisions and may split further.

Future scope must resolve what happens after discovery, including exchange/request/handoff/contact behavior, saved-search contracts, explainable matching, and resource notification semantics. It must not infer those rules from the 04C1 `exchange` discovery intent.

04C is not a dependency for the 05A participation foundation or 05B mobile participation UI. Stable join-request and Project resource-need IDs let 04C3B1 selections attach without equating contribution with membership. The 05C actual-finalization plan follows the complete 04C3D3A/D3B1/D3B2 live coverage and group-coordination flow and the final active commitment set rather than merely request selections, acceptance history, coverage or system-resurfacing history, 04C3A need rows, unrelated standalone listing UI, or 04C4 transaction/matching work.

### 05 — Participation lifecycle

**Goal:** Make one-time Projects and Tavoli collaborative through one canonical participation model while keeping their content/lifecycle tables separate.

#### 05A — Project Participation Domain Foundation

**Status:** Implemented in merged PR #15 (`4e73849c297ccedf10c296940675ee01bd11785b`).

Owns:

- a private shared project identity whose UUID equals the concrete Proposal/Tavolo UUID;
- source backfill and insert/delete/ownership invariants without a content mega-table;
- private, bounded-message join-request attempts and retained decision history;
- acceptance-backed membership history with one current membership per project/profile;
- expected-identity-bound request/withdraw/accept/reject/leave/remove operations;
- concrete lifecycle eligibility, including one-time end-time and Tavolo pause/end behavior;
- requester/creator/member private reads and creator/current-member protected meeting access;
- identifier-only audit/outbox events, pgTAP, real multi-user integration, and generated types.

05A does not implement UI, notification delivery, chat, capacity/fullness, resources, online/in-person schema, contribution verification, badges, or denormalized counters. Its canonical accepted membership and append-preserved intervals are the source used by 07B1 chat activation and authorization; the existing accepted outbox event remains unchanged for independent consumers.

#### 05B — Mobile Project Participation Experience

**Status:** Implemented in merged PR #16 (`09d62276faec4c50ab5d45cd3930975c5a49a6b7`) after founder merge approval. The repository has no recorded native QA checklist result, so this roadmap does not assert a native pass or fail.

Mobile scope:

- Join with an optional request message;
- own request status and withdrawal;
- creator request review and accept/reject;
- current/historical member state;
- participant leave and creator removal;
- participant-authorized operational meeting information.

This client must consume the 05A operations and must not reproduce participation rules locally.

#### 05D — Participation-Aware Browse and Pending Request Visibility

**Status:** Implemented in merged PR #24 (`82ca32ab4020bc9107ea33beb3ad551ff48bcafc`). Depends on 04A, 04B1, 05A, and 05B.

Owns requester-only, expected-identity pending-card reads plus the mobile
Proposal/Tavolo `Requested` sections. Public list contracts, cursors, ordering,
and signed-out discovery remain unchanged; private request messages, exact
meeting data, creator-side incoming requests, resolved request history, and
non-public projects are excluded. Native Android/iOS QA is deferred to the
consolidated Plan 12 pass and is not marked passed or failed here.

#### 05C — One-Time Project Actual Contribution Attribution

**Status:** In progress through stacked 05C2. Neither PR #68 nor its 05C2 mobile dependent is merged.

For a one-time Project, the final commitments of each membership episode active at the exact Proposal end instant become actual contribution attribution automatically. Request selections, acceptance decisions, earlier commitment snapshots, and live coverage are not themselves final attribution. Tavoli finalization, delegated management, ratings/reviews, statistics/badges, and participant disputes remain deferred.

##### 05C1 — Actual Contribution Attribution Domain

PR #68 remains open and unmerged. It owns the derivable frozen final-commitment baseline for ended published one-time Proposals, exact half-open membership-at-end eligibility, sparse creator exclusions/additions, the separate Substantial Effort / Energy marker, participant/creator reads, creator-only option and compare-and-swap replacement RPCs, identifier-only update events, and focused pgTAP/real-OTP/concurrency coverage. No Project-end worker or copied baseline is introduced. Memberships ended before Proposal end start from an empty baseline but can receive explicit creator attribution; post-end leave/removal does not erase baseline eligibility; rejoin episodes stay independent.

##### 05C2 — Mobile Actual Contribution Experience

**Status:** In progress as a mobile PR stacked on PR #68.

Adds participant/former-participant read-only actual-contribution visibility at Project chat → Group info → Actual contributions, preserving every membership episode independently. The creator's Manage participation member cards open the same membership-scoped sheet in editable mode, starting with automatic final commitments already selected and supporting canonical off-app additions plus the dedicated effort toggle. The mobile boundary consumes only the 05C1 read/options/CAS APIs, keeps expected and desired snapshots separate, and reloads canonical state after saves and stale-edit/options races without adding a mandatory Project-wide approval state. Tavoli remain excluded. A private participant-to-creator “remind creator” request/message/popup/notification remains a possible later follow-up rather than required 05C1/05C2 scope; cross-episode statistics/badges and group contribution surveys remain downstream or speculative.

Future project-presentation work must also represent Tavoli as a Progetti type/filter in the final information architecture and implement the accepted Online/In-Presence mode. Neither is a participation-table field in 05A.

The former combined Plan 05 scope is now split across the four portions above. Remaining parent outcomes include:

- join request creation, withdrawal, acceptance, and rejection;
- duplicate/race protection;
- membership and role records;
- leave, removal, and proposal-state interactions as decided;
- owner review interface (05B);
- participant counts and history-derived stats after their product semantics are selected;
- any explicitly selected non-chat participation threshold or activation rule;
- canonical backend functions for sensitive transitions;
- outbox events for later notifications;
- full RLS/state-transition tests.

### 06 — Notification backbone

**Goal:** Deliver domain events without coupling external services to transactions.

**Status:** In progress. 06A, 06B, provider-independent 06C1, provider-neutral 06C2A, and 06D are implemented; provider-specific 06C2B remains not started.

#### 06A — Notification Domain and Outbox Projection Foundation

**Status:** Implemented in PR #17 (`6c3168b17845b2b2567ef42864c3e0f73eb6db97`).

Owns:

- controlled categories, default in-app/future-push settings, and sparse per-profile overrides;
- canonical recipient-specific semantic notification records and structured request/project targets;
- generic private per-consumer outbox receipts without treating `published_at` as a global consume switch;
- service-only, concurrency-safe/idempotent projection for the six 05A participation events;
- preference suppression that still records successful notification-consumer processing;
- expected-identity-bound keyset inbox, unread, mark-one, mark-all, and preference APIs;
- safe project/actor presentation context, pgTAP, local integration, generated types, and CI.

06A depends on the 01B identity/outbox primitives and implemented 05A participation events. It does not depend on 05C or independent 04C resource work. Existing supported events are not automatically backfilled when support is introduced. The accepted event remains available to independent consumers; 07B1 activates the chat transactionally from canonical membership and does not consume or globally acknowledge it.

#### 06B — Mobile In-App Notifications and Preferences

**Status:** Implemented in PR #19 (`c459b185a0a7f8ae78bd8587301fcc3460a851d3`). Native Android/iOS QA was deferred by the founder for a later consolidated QA pass; it has not been marked passed or failed.

Implemented scope:

- Flutter inbox and unread badge;
- mark-one/mark-all interactions;
- Participation in-app preference UI preserving the hidden future-push value;
- structured Proposal/Tavolo project navigation and deep links;
- request-specific target handling through the implemented 07A Messages item;
- ready-identity/action/pull refresh without timers or Realtime.

#### 06C — Push Delivery (parent)

**Status:** In progress because provider-specific 06C2B remains not started.

#### 06C1 — Push Installation and Delivery-Job Foundation

**Status:** Implemented in PR #20 (`f7b88ee61c2471fcb4bff04e968403886dff1e27`).

Owns:

- private opaque app-installation registration with expected-identity-bound register/unregister operations;
- atomic token rotation/reuse and installation ownership transfer without exposing provider tokens;
- one shared canonical resolver for the six supported participation events;
- independent service-only `push.v1` projection based only on `push_enabled`;
- one private recipient-level semantic job without raw source payload, token, request content, or exact meeting data;
- independent suppression receipts, historical-event rollout receipts, concurrency/idempotency, pgTAP, local integration, generated types, and CI;
- no Firebase package, provider configuration, Edge Function, permission UI, or network delivery.

An event may remain push-enabled while its in-app preference is disabled, in
which case 06A deliberately records the notification-consumer receipt without
creating a `public.notifications` row. Therefore 06C must not treat the in-app
row as the complete set of push-eligible occurrences. It must either consume
the domain outbox independently while reusing one canonical event mapping, or
introduce a channel-neutral occurrence layer before fan-out; it must not copy
and silently diverge the participation mapping in a second worker. Plan 06C1
implements the independent-consumer/shared-resolver option.

#### 06C2 — Provider Delivery Integration (parent)

**Status:** In progress because provider-specific 06C2B remains not started.

#### 06C2A — Push Delivery Attempt and Worker-Protocol Foundation

**Status:** Implemented in merged PR #22 (`fa6a61574d4c91ca128d7958ee3c7a7c01ac8e33`).

Owns:

- monotonic private installation token generations;
- one-time, concurrency-safe recipient-job fan-out to then-active installations;
- private per-installation targets with bounded scheduling and expiring leases;
- append-only attempt history with safe bounded provider metadata and no token/content copies;
- `delivered`, `invalid_token`, `transient_failure`, `permanent_failure`, and `no_longer_registered` handling;
- stale lease rejection, expired-lease reclaim, rotation-safe invalid-token cleanup, and terminal job aggregation;
- private-schema service-only worker routines with no direct worker table access;
- pgTAP, a real local fake-worker integration, generated-type drift checks, documentation, and CI;
- no provider SDK/configuration, credentials, network sends, Edge Function, or mobile changes.

The protocol uses only portable PostgreSQL/Supabase primitives. It assumes neither a
managed scheduler nor a hosted project, and leaves provider deployment to 06C2B and
production self-hosting to Plan 13.

#### 06C2B — Firebase Mobile Registration and FCM Adapter

**Status:** Not started.

External context required:

- Firebase Android and iOS app configuration;
- APNs/Firebase iOS setup;
- the real push-permission timing decision;
- the safe push-preview policy;
- server-side FCM HTTP v1 credentials stored as secrets.

06C2B owns the official Flutter Firebase Messaging integration, persisted random
installation UUID, OS permission flow, token refresh/register/unregister lifecycle,
sign-in/account switching, foreground/background/open behavior, and push preference
UI. Its repository-owned trusted worker will authenticate/send through FCM HTTP v1
using only the 06C2A claim/result protocol, apply adapter-owned retry-delay policy,
map invalid/permanent/transient provider outcomes, enforce safe payload/preview and
environment rules, and remain deployable in the supported self-hosted environment.

Request-specific 06A notifications carry `request_id` and the semantic `participation_request` target for the implemented 07A Messages item. They remain alerts and do not own Accept/Reject. Plan 07B owns group-chat behavior; 06A does not turn `project.join_request_accepted` into a chat rule.

06C2B is feature/integration work, not the production self-hosting phase. Its repository-owned worker must remain configurable and runnable/testable in the supported local or self-hosted environment; provider credentials and production deployment remain later account-owner/infrastructure work.

#### 06D — Project Chat Notification Projection and Mobile Alerts

**Status:** Implemented in merged PR #31 (`2197576acb47bd7cd0dd42a7f10987d7522caea5`). Depends on merged 07B2C/PR #30 plus 06A, 06B, and 06C1.

The scoped bridge revalidates identifier-only `project.chat_message_sent`
events, resolves the creator and accepted memberships at the canonical message
timestamp, excludes the sender, and fans one source event out to zero or more
body-free in-app notifications and semantic push jobs. Each channel applies its
own Chat preference and receipts the event only after complete fan-out. The
mobile inbox adds safe localized chat copy, the canonical
`/messages/chats/:chatId` destination, and a Chat in-app toggle while Push stays
hidden. Historical chat events are acknowledged without alert backfill.

Firebase/provider calls, message-body previews, unread/read receipts, batching,
mentions, per-project mute controls, and native QA remain outside 06D. Native QA
continues to belong to Plan 12; provider setup and delivery remain 06C2B.

### 07 — Messages + Project Chat

**Goal:** Give users one authenticated communication area for structured participation requests and later project-group coordination without duplicating canonical participation state.

**Status:** Implemented through merged 07B2C/PR #30. The parent combines the request-oriented Messages surface, accepted-participant chat lifecycle/authorization, durable messaging/Realtime, and the mobile group-chat experience.

#### 07A — Messages Surface and Structured Participation Request Items

**Status:** Implemented in PR #18 (`08e3d29e8bb72f498d6f1453fdcdf190f16c7e7e`).

Implemented scope:

- authenticated Messages inbox/surface;
- persistent actionable join-request items backed by canonical `project_join_requests`;
- authorized requester-message display;
- request state changes rendered without duplicating participation state;
- Accept/Reject actions calling the existing 05A transitions;
- resolution of the notification `participation_request` target to the corresponding item;
- no requirement that a request become a free-form chat message.

The existing Participation overview remains the organizer's secondary full-history and member-management surface.

#### 07B — Project Group Chat (parent)

**Status:** Implemented through merged 07B2C.

The parent is split between the canonical lifecycle/authorization anchor, the
production server-authorized message/Realtime domain, and the later mobile
experience.

##### 07B1 — Project Group Chat Lifecycle and Authorization Foundation

**Status:** Implemented in PR #26 (`bb26ef4a518484da6f67b3309d2cfd62e4d2b483`). Depends on 05A and 07A.

Scoped foundation:

- the first accepted join request transactionally activates one chat anchor;
- creator plus first accepted participant is sufficient, with no fixed threshold;
- later acceptances and rejoins reuse the same Project chat;
- current/send and historical entitlement derive from ownership plus canonical membership intervals;
- leave/removal ends current entitlement while preserving half-open history intervals and rejoin gaps;
- Project completion and Tavolo pause/end retain the anchor;
- existing membership history is reconciled deterministically;
- no message body, chat-member mirror, Realtime, Flutter chat UI, meeting copy, or new notification/push behavior.

##### 07B2 — Project Chat Messaging and Mobile Experience (parent)

**Status:** Implemented through merged 07B2C. Depends on 07B1.

The MVP uses ordinary authenticated server-authorized plain-text Project chat.
HTTPS/TLS protects transport, while the backend remains technically capable of
reading stored bodies. A current participant receives the full existing chat
history; a former participant retains history through their latest membership
end; rejoin restores the full accumulated history. MLS/E2EE was technically
prototyped in unmerged PR #28 and is deferred as an optional future privacy
enhancement, not a production dependency.

###### 07B2B — Project Chat Message Domain and Realtime Transport

**Status:** Implemented in PR #29
(`f044a59e3746530a02a754bfa95843ff28572738`).

Scoped backend/domain work:

- immutable bounded plain-text messages for Proposal and Tavolo chats;
- current-entitlement send authorization serialized with leave/removal;
- full-history/current/former/rejoin read semantics;
- descending keyset history and accessible-chat summaries using last visible activity;
- identifier-only `project.chat_message_sent` outbox events;
- private, per-profile Project-chat Broadcast hints with current-entitlement authorization;
- durable PostgreSQL reconciliation for offline/reconnect clients;
- pgTAP, concurrency, Proposal/Tavolo, and real local Realtime integration;
- no Flutter chat UI, notification projection, push behavior, meeting-data copy, or E2EE code.

###### 07B2C — Mobile Project Chat Experience

**Status:** Implemented in PR #30
(`d343afbeab79ce6132403a6e9b46aecbc375f1fd`). Depends on merged 07B2B.

The mobile scope owns Messages-screen Project-chat integration,
`/messages/chats/:chatId`, paginated bubbles/history, composer/send, Realtime
reconciliation, former-member read-only state, group information,
Proposal/Tavolo navigation, creator Participation navigation, and access to the
existing protected meeting operation for current users. Native UX QA remains in
the consolidated Plan 12 pass. Blocking, suspension, moderation overrides, and
reporting policy remain Plan 09; direct messages, calls, reactions, attachments,
unread/read receipts, and typing indicators remain excluded.

###### Deferred E2EE / MLS research prototype

PR #28 (`codex/07b2a-mls-e2ee-prototype`) is intentionally unmerged. It records
technically useful MLS feasibility research but is deferred and is neither an
implemented roadmap item nor a dependency of the MVP message schema.

### 08 — Storage and media hardening

**Goal:** Support user media without treating storage URLs as authorization.

Expected scope:

- an explicit production media decision comparing self-hosted Supabase Storage with an external object store such as Cloudflare R2;
- evaluation of bandwidth and storage cost, privacy/access control, backup coverage, migration complexity, and operational burden;
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

### 11 — Analytics and operational foundations

**Goal:** Observe product behavior and operate failures without collecting unnecessary content.

Expected scope:

- explicit PostHog event vocabulary tied to product questions;
- no automatic capture/session replay by default;
- Sentry scrubbing and environment/release metadata;
- application health and queue-lag signal definitions;
- alert requirements and incident ownership inputs for the production-infrastructure phase;
- billing/spend-alert checklist;
- dependency/security update process.

### 12 — Consolidated UI/UX and native QA pass

**Goal:** Turn the implemented functional surfaces into one coherent, accessible product experience before production infrastructure is finalized.

Expected scope:

- founder-approved visual identity and centralized design-token refinement;
- interaction, navigation, loading, empty, error, and recovery consistency across implemented mobile features;
- accessibility, localization, keyboard, text-scaling, and supported-screen-size review;
- consolidated Android/iOS validation, including native checks intentionally deferred by earlier feature plans;
- focused public-web/admin polish for the functionality retained at release, without forcing mobile parity;
- regression coverage for behavior changed during the pass.

This phase refines accepted flows; it must not silently decide unresolved authorization, lifecycle, policy, or data-retention behavior.

Deferred 04C2 native checklist:

- verify signed-out Scambio-Dona list and detail on Android and iOS;
- verify OTP and incomplete-profile return to My Listings, Create, and Edit;
- verify editor keyboard traversal, validation, and small-screen scrolling;
- verify pull-to-refresh and paired-keyset load-more behavior;
- verify the close confirmation copy and terminal read-only state;
- verify account switching never flashes the prior owner's drafts;
- verify screen-reader labels, text scaling, contrast, and non-color lifecycle
  cues.

Deferred 04C3B2 native checklist:

- verify contribution-chip touch targets and selected/unselected screen-reader
  state on Android and iOS;
- verify long skill/resource labels and both chip groups wrap without overflow
  on supported small screens and text scales;
- verify keyboard traversal between chips and the optional private message;
- verify add/edit resource-need dialogs, validation, keyboard insets, and close
  confirmation copy, including that Closed never implies fulfilled;
- verify Proposal join shows both current skill requirements and open resource
  needs while Tavolo join remains resource-only;
- verify a changed/closed option produces safe stale-option recovery, prunes
  only invalid selections, and retains the private message;
- verify Messages request-detail chips wrap and remain visible for resolved
  historical requests;
- verify a Messages selection-read failure leaves Accept/Reject/Withdraw usable;
- verify account switching with join/owner/message screens open never exposes
  the prior account's message, selections, or creator history.

### 13 — Self-hosted production infrastructure readiness

**Goal:** Build, secure, test, and rehearse the intended self-hosted Supabase production environment after the main feature and UI/UX work, before public release.

Expected scope:

- production host/VPS evaluation, selection, provisioning, and capacity baseline;
- production Supabase deployment using reviewed, reproducible infrastructure configuration;
- HTTPS/TLS, DNS, firewall/network exposure, and secret management;
- production SMTP/Auth email configuration;
- database and media backup design with off-site retention;
- restore and disaster-recovery testing against stated recovery objectives;
- monitoring, alerting, queue/worker visibility, and incident ownership;
- pinned update/upgrade procedures and operational runbooks;
- migration rehearsal from any managed test environment where useful;
- production client endpoint/configuration and cutover strategy that avoids stranding installed versions;
- security, load, smoke, rollback, and failure-recovery rehearsals.

This phase is not implemented by the architecture-direction change. It must not assume a production host, paid plan, DNS state, or credential before the founder/account owner selects and authorizes it.

### 14 — Release pipeline and store readiness

**Goal:** Produce controlled staging and public releases only after the self-hosted production environment has been proven.

Expected scope:

- release promotion over the rehearsed environment-specific Supabase, Firebase, email, monitoring, and analytics configuration;
- migration and repository-owned Edge Function/worker release workflow against the proven production stack;
- an independently selected web deployment workflow matching the static, client-side, server-rendered, and authenticated functionality retained at release;
- Codemagic Android and iOS build pipelines;
- signing/certificate placeholders and secure setup instructions;
- TestFlight and Play internal-testing distribution;
- manual approval gates for production and store submission;
- versioning and release notes;
- privacy/data-safety/store-review checklists;
- smoke tests and rollback paths.

Public production and store release remain blocked until Plan 13's deployment, backup/restore, monitoring, upgrade, and client-cutover procedures have been exercised successfully.

## Work Codex can perform with low supervision

Codex can usually implement:

- repository and local-tooling foundations;
- schemas, constraints, functions, policies, and automated tests after product states are defined;
- ordinary Flutter and Next.js shells/components;
- authentication plumbing;
- CRUD and pagination;
- join-request mechanics;
- notification/outbox/queue infrastructure;
- structured request Messages and project-scoped chat infrastructure;
- storage policies;
- moderation/admin mechanics;
- reproducible self-hosting configuration and non-production rehearsals after the required host and policy choices are supplied;
- CI, documentation, fixtures, and runbooks.

## Work requiring founder or account-owner action

Codex cannot independently supply or approve:

- production host/provider selection, service accounts, billing, domains, certificates, and production secrets;
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
2. capacity/fullness before introducing limits; the core request/membership state semantics are resolved in 05A;
3. any future reopening of E2EE, message-format migration, or historical-key behavior requires a focused architecture/product decision; the MVP server-readable/full-history rule is resolved;
4. moderation/minimum-age policy before plan 09 is complete;
5. retention/anonymization policy before plan 10;
6. success metrics and analytics legal basis before plan 11;
7. production media backend before Plan 08 commits to permanent storage behavior;
8. production host, recovery objectives, accounts, billing, DNS, and operational approval before Plan 13 provisions production infrastructure;
9. store material, policies, certificates, and final release approval before Plan 14.

## Immediate next action

Complete and review the stacked **04C3D3A — Live Project Requirement Coverage Domain**
without merging it, PR #64, PR #63, PR #62, PR #61, PR #60, PR #52, or their 04C3A base PR #45. 04C1 is implemented in merged PR #32
(`2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42`) and 04C2 is implemented in
merged PR #34 (`2da76de112a860210161d64de6bceab333159c26`).
06D is implemented in merged PR #31, while 06 remains in
progress because provider-specific 06C2B is not started. Optional E2EE/MLS
research remains unmerged and deferred in PR #28. PR #45 (04C3A), PR #52
(04C3B1), PR #60 (04C3B2), PR #61 (04C3C1), PR #62 (04C3C2), PR #63 (04C3D1), and PR #64 (04C3D2) remain open and unmerged beneath
the in-progress 04C3D3A stack; 04C3D3B, 04C4, and 05C remain not started. 05C waits specifically
for the complete live coverage/group-coordination flow and final active commitments after 04C3D3B rather than standalone
listing UI, request selection, acceptance history, or 04C3A need existence. Plan 06C2B remains
not started and requires Firebase/APNs configuration, push permission and
preview decisions, server-side FCM credentials, and a self-host-compatible
worker deployment target. Deferred native Android/iOS checks from implemented
feature plans belong in the consolidated Plan 12 QA pass. Production
self-hosting does not begin until Plan 13, after the main functional work and
Plan 12 UI/UX pass.

The independent public informational mini-track has SITE-00 implemented in
merged PR #23, SITE-01 in merged PR #25, SITE-02 implemented as the
privacy-minimal local/CI waitlist boundary, and SITE-02W implemented as its
native Workers runtime. Production Worker/D1/Turnstile resources,
the exact hostname, approved controller/legal copy, a public/privacy contact,
removal-request operations ownership, and waitlist retirement/retention remain
required inputs before SITE-03 can cut over the domain.
