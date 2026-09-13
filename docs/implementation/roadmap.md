# Implementation Roadmap

**Status:** Planning baseline  
**Current implementation:** Plans 00–04B2B, 05A, 05B, 05D, 06A, 06B, provider-independent 06C1, provider-neutral 06C2A, 07A, and public informational SITE-00 through SITE-02 implemented; provider-specific 06C2B, 04C, and 05C remain not started

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

| ID    | Plan                                                 | Main result                                                                                                           | Dependencies           | Founder input expected                                                                                               | Status      |
| ----- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------- |
| 00    | Architecture and repository bootstrap                | Runnable monorepo foundation, local tooling, initial CI, development docs                                             | Documentation baseline | Tool/account installation only if automation cannot provide it                                                       | Implemented |
| 01    | Database foundation and security model (parent)      | Secure database workflow plus shared identity, audit, and outbox primitives                                           | 00                     | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 01A   | Database workflow and security harness               | Canonical migrations, fail-closed grants, public/private boundary, PostGIS, pgTAP, generated types, and CI replay     | 00                     | None expected                                                                                                        | Implemented |
| 01B   | Identity, audit, and outbox primitives               | Auth/profile boundary and minimal shared audit/outbox foundations                                                     | 01A                    | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented |
| 02    | Mobile and web application foundations (parent)      | Flutter app shell, Next.js public/admin shells, environments, error handling, localization and monitoring foundations | 00–01                  | No visual polish; only resolve navigation/product-shell ambiguity if material                                        | Implemented |
| 02A   | Mobile application foundation                        | Flutter startup, Riverpod/router, typed config, Supabase/Sentry, theme, localization, and state UI                    | 01                     | None expected                                                                                                        | Implemented |
| 02B   | Web/admin application foundation                     | Next.js public/admin shells and web-side application foundations                                                      | 02A                    | None expected unless current tooling exposes a material ambiguity                                                    | Implemented |
| 03    | Authentication and profiles (parent)                 | Public browsing boundary, mobile/web email OTP, profile setup, competences/preferences, privacy-ready profile data    | 01–02                  | Initial required profile fields, visibility rules, competence taxonomy strategy                                      | Implemented |
| 03A   | Mobile Email-OTP Authentication                      | Public-first mobile numeric email OTP, Supabase session state, sign-out, and minimal profile-anchor readiness         | 02B                    | None expected                                                                                                        | Implemented |
| 03B   | Web Email-OTP Authentication                         | Web email OTP and session behavior using the canonical backend                                                        | 03A                    | None expected for this scoped work                                                                                   | Implemented |
| 03C   | Basic Profiles, Skills, and Visibility               | Display-name onboarding, optional bio, controlled starter skills, and per-field public/private visibility             | 03B                    | Initial required fields, starter taxonomy, and basic visibility resolved; advanced profile decisions remain deferred | Implemented |
| 04    | Activity discovery/domain (parent)                   | One-time proposals plus separately scoped recurring activities                                                        | 03                     | Proposal fields, lifecycle decisions, broad location behavior                                                        | Implemented |
| 04A   | One-Time Proposals and Discovery                     | Draft/create/publish/cancel, public list/detail, requirements, location privacy, and mobile/web discovery             | 03C                    | One-time lifecycle and rough/exact location behavior resolved                                                        | Implemented |
| 04B   | Tavoli / Recurring Activities (parent)               | Versioned weekly/monthly recurring domain plus later mobile/web experience                                            | 04A                    | Initial recurrence and lifecycle resolved; occurrence exceptions remain deferred                                     | Implemented |
| 04B1  | Tavoli / Recurring Activity Domain Foundation        | Separate recurring schema, schedule history, bounded occurrences, lifecycle, privacy, canonical APIs, and tests       | 04A                    | None expected for the defined weekly/monthly foundation                                                              | Implemented |
| 04B2  | Tavoli Mobile/Web Experience (parent)                | Separate mobile and public-web clients over the canonical 04B1 backend                                                | 04B1                   | Functional UX review; no recurrence expansion                                                                        | Implemented |
| 04B2A | Tavoli Mobile Experience and Browse Integration      | Mobile browse/list/detail/create/edit/manage UI over the canonical 04B1 backend                                       | 04B1                   | Native interaction review                                                                                            | Implemented |
| 04B2B | Public Web Tavoli Discovery                          | Read-only public web Tavoli list and detail                                                                           | 04B2A                  | Functional public-web review                                                                                         | Implemented |
| 04C   | Resources + Scambio-Dona                             | Project needs/contributions plus donation/exchange listings and later matching/notifications                          | 04A                    | Resource types, ownership/handoff/return semantics, visibility, listing lifecycle, and matching                      | Not started |
| 05    | Participation lifecycle (parent)                     | Shared project participation foundation, later mobile experience, and verified-contribution review                    | 04A, 04B1              | Capacity/fullness and later contribution/resource semantics remain unresolved                                        | In progress |
| 05A   | Project Participation Domain Foundation              | Shared identity, private join requests, canonical membership history, protected meeting access, events, and tests     | 04A, 04B1              | No blocking decision; exact chat trigger remains Plan 07                                                             | Implemented |
| 05B   | Mobile Project Participation Experience              | Join/status/withdraw, creator review, member state, leave/remove, and protected meeting UI                            | 05A                    | Functional/native UX review                                                                                          | Implemented |
| 05D   | Participation-Aware Browse and Pending Request Visibility | Own pending requests promoted in mobile Proposal/Tavolo Browse without changing public pagination                 | 04A, 04B1, 05A, 05B   | Native QA deferred to the consolidated Plan 12 pass                                                                  | In progress |
| 05C   | Verified Project Contribution / Completion Review    | Creator confirmation of actual contribution for later stats/badges/resource attribution                               | 05A, 04C               | Contribution taxonomy, resource attribution, dispute/correction rules, and credit semantics                          | Not started |
| 06    | Notification backbone (parent)                       | Canonical notification projection, later mobile inbox/preferences, then device registration and push delivery         | 03–05A                 | User-facing notification UX/copy and push behavior remain later review points                                        | In progress |
| 06A   | Notification Domain and Outbox Projection Foundation | Categories/preferences, semantic inbox records/targets, multi-consumer receipts, participation projection, secure APIs | 01B, 05A               | None expected for the defined participation foundation                                                               | Implemented |
| 06B   | Mobile In-App Notifications and Preferences          | Flutter inbox, unread state, preference controls, and structured project/request navigation                           | 06A                    | Native QA deferred by founder for a later consolidated pass; not passed or failed                                    | Implemented |
| 06C   | Push Delivery (parent)                               | Provider-independent installation/jobs followed by Firebase mobile registration and trusted delivery                  | 06A, 06B               | Push permission timing, preview policy, and provider/account-owner setup                                             | In progress |
| 06C1  | Push Installation and Delivery-Job Foundation        | Private app installations, shared semantic resolution, independent `push.v1` projection, and recipient-level jobs    | 06A, 06B               | None; uses synthetic tokens and no provider account                                                                  | Implemented |
| 06C2  | Provider Delivery Integration (parent)               | Provider-neutral worker protocol followed by Flutter registration and the repository-owned FCM adapter               | 06C1                   | Firebase/APNs setup, permission timing, preview policy, credentials, and worker deployment                            | In progress |
| 06C2A | Push Delivery Attempt and Worker-Protocol Foundation | One-time installation fan-out, leases, safe attempt history, retries, terminal aggregation, and stale-token guards    | 06C1                   | None; uses synthetic outcomes and no provider account                                                                | Implemented |
| 06C2B | Firebase Mobile Registration and FCM Adapter         | Flutter token/permission lifecycle plus repository-owned FCM HTTP v1 sends over the trusted 06C2A protocol            | 06C2A                  | Firebase Android/iOS config, APNs setup, permission timing, preview policy, credentials, and worker hosting           | Not started |
| 07    | Messages + Project Chat (parent)                     | Structured participation-request items plus automatic project group conversations                                     | 05A, 06A               | Exact chat trigger and access/moderation after leaving or removal                                                    | In progress |
| 07A   | Messages Surface and Structured Participation Requests | Authenticated Messages inbox with canonical actionable join-request items                                            | 05A, 06A               | Functional/native UX review and final Messages information architecture                                              | Implemented |
| 07B   | Project Group Chat                                   | Automatic idempotent group chat, membership authorization, realtime text, group info, and meeting link                | 05A, 07A               | Triggering participation event plus access/moderation after leaving or removal                                       | Not started |
| 08    | Storage and media hardening                          | Select the production media approach, then implement purpose-specific access, metadata, cleanup, and processing hooks | 03–07                  | Profile/proposal photo visibility, retention, and self-hosted Supabase Storage versus external object storage         | Not started |
| 09    | Safety, moderation and admin                         | Reporting, blocking, content states, admin roles, moderation queue/actions, audit trail and minimal custom admin UI   | 04–08                  | Community rules, prohibited content, escalation, suspension, appeals, minimum age                                    | Not started |
| 10    | Account deletion and privacy operations              | In-app and web deletion paths, cleanup/anonymization jobs, export groundwork, privacy documentation inputs            | 03–09                  | Legal retention and anonymization policy; legal text remains founder/legal work                                      | Not started |
| 11    | Analytics and operational foundations                | Explicit product events, privacy scrubbing, health/queue signals, alert requirements, and incident ownership inputs   | 00–10                  | Success metrics and analytics consent/legal choices                                                                  | Not started |
| 12    | Consolidated UI/UX and native QA pass                | Coherent visual/interaction design, accessibility, responsive behavior, and deferred native flow validation           | 00–11                  | Final visual identity, high-impact interaction decisions, and native review                                          | Not started |
| 13    | Self-hosted production infrastructure readiness      | Provisioned and rehearsed production Supabase stack, security, backups, monitoring, operations, and cutover plan      | 00–12                  | Host/account selection, billing, DNS, credentials, retention objectives, and production-operation approval            | Not started |
| 14    | Release pipeline and store readiness                 | Controlled releases over the proven production backend, signed builds, internal testing, gates, and store checklists | 00–13                  | Provider accounts, certificates, store listings, policies, and final release approval                                | Not started |


## Public informational site mini-track

This independent mini-track adds the static public launch site without changing
the dependencies or responsibilities in the main 00–14 product sequence.

| ID      | Plan                                           | Main result                                                       | Dependencies     | Founder/account-owner input expected                    | Status                    |
| ------- | ---------------------------------------------- | ----------------------------------------------------------------- | ---------------- | ------------------------------------------------------- | ------------------------- |
| SITE-00 | Static informational site foundation           | Vite/React workspace, placeholder, root tooling, CI, and docs     | Repository state | None                                                    | Implemented in PR #23 (`8b35ea95f44be39756bb0269da369827b63178d9`) |
| SITE-01 | Public content and visual landing page          | Founder-approved content, logo, visual identity, and page shell   | SITE-00          | Public contact and legal-controller details remain      | Implemented in PR #25 (`3db7492e9b4ad6a33beb5f73c3ea1c394e7cf942`) |
| SITE-02 | One-time launch waitlist                       | Consent-aware signup for one app-launch notification              | SITE-01          | Controller/contact and production Cloudflare inputs remain | Implemented             |
| SITE-03 | Cloudflare production deployment/domain cutover | Hosted static site and authorized `planets.community` cutover     | SITE-01–SITE-02  | Provider access, DNS access, billing, and cutover approval | Not started             |
| SITE-04 | Launch notification and waitlist retirement    | One launch notice followed by approved waitlist retirement        | SITE-02–SITE-03  | App-release timing and retention/deletion approval      | Deferred until app release |

The SITE-02 address is solely for one notification when the PLANETS app
launches. It is not a newsletter and must not be reused for marketing,
promotions, recurring product updates, profiling, or unrelated communications.
SITE-02 adds a local/CI-tested Cloudflare Pages Function, server-side Turnstile
verification, and minimal D1 persistence without deploying production
resources. SITE-03 provisions and verifies the production Cloudflare resources,
approved hostname, controller/contact information, deployment, and domain
cutover. SITE-04 remains responsible for the one launch notification and
approved waitlist retirement.

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

Parent plan 04 is implemented through 04A and 04B. Shared participation depends on both concrete domain foundations while 04C remains separate.

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

**Status:** Not started and not implemented by 04B1.

PLANETS still needs an explicit domain for material resources that a project may request, receive as donations, exchange, or use on loan. The accepted Scambio-Dona direction also includes standalone donation and exchange listings, with saved searches/notifications and matching between listings and project needs considered later. A scoped plan must first define resource types, contributor/owner relationships, handoff/return lifecycle, listing visibility/history, and matching semantics. This gap is recorded so resources are not silently collapsed into skills, Tavoli topics, or free-form join-request fields.

04C is not a dependency for the 05A participation foundation or 05B mobile participation UI. Stable join-request IDs allow future resource-offer rows to attach without equating contribution with membership. The 05C verified-contribution plan does depend on resolving relevant contribution/resource semantics.

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

05A does not implement UI, notification delivery, chat, capacity/fullness, resources, online/in-person schema, contribution verification, badges, or denormalized counters. `project.join_request_accepted` is a stable Plan 07 candidate event, but Plan 07 still owns the exact automatic-chat trigger and access after membership changes.

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

**Status:** In progress in the current implementation PR. Depends on 04A, 04B1, 05A, and 05B.

Owns requester-only, expected-identity pending-card reads plus the mobile
Proposal/Tavolo `Requested` sections. Public list contracts, cursors, ordering,
and signed-out discovery remain unchanged; private request messages, exact
meeting data, creator-side incoming requests, resolved request history, and
non-public projects are excluded. Native Android/iOS QA is deferred to the
consolidated Plan 12 pass and is not marked passed or failed here.

#### 05C — Verified Project Contribution / Completion Review

**Status:** Not started.

Future scope records the 08/09 direction that the creator confirms who actually contributed after completion. It may later support contribution history, derived statistics, badges, and resource/help attribution, but membership acceptance alone is not proof. Taxonomy, resource linkage, correction/dispute behavior, and credit semantics remain founder-owned decisions; 05C must not be inferred from 05A history.

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

**Status:** In progress. 06A, 06B, provider-independent 06C1, and provider-neutral 06C2A are implemented; provider-specific 06C2B remains not started.

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

06A depends on the 01B identity/outbox primitives and implemented 05A participation events. It does not depend on 05C or independent 04C resource work. Existing supported events are not automatically backfilled when support is introduced. Unsupported events, including the accepted event's possible future chat use, remain available to other consumers.

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

### 07 — Messages + Project Chat

**Goal:** Give users one authenticated communication area for structured participation requests and later project-group coordination without duplicating canonical participation state.

**Status:** In progress through 07A. This parent is split between the request-oriented Messages surface and the distinct accepted-participant group chat.

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

#### 07B — Project Group Chat

**Status:** Not started.

Future scope:

- exactly one automatically created eligible group conversation per project;
- transactional idempotent creation at the participation event finalized with plans 05/07, without a fixed three-person gate or manual Create Chat action;
- member authorization and historical-access behavior;
- retention of chat/messages when a project ends;
- persisted text messages and pagination;
- Supabase Realtime subscription handling;
- send deduplication/error recovery;
- group information with a route to the Participation overview;
- message reporting/deletion-state groundwork;
- push-notification events;
- optional externally created meeting URL;
- no direct messages, calls, reactions, typing indicators, or end-to-end encryption.

The exact automatic group-chat trigger and whether Participation is a direct group action or a group-info action remain deferred to 07B.

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
3. group-chat trigger and access after membership changes before plan 07B;
4. moderation/minimum-age policy before plan 09 is complete;
5. retention/anonymization policy before plan 10;
6. success metrics and analytics legal basis before plan 11;
7. production media backend before Plan 08 commits to permanent storage behavior;
8. production host, recovery objectives, accounts, billing, DNS, and operational approval before Plan 13 provisions production infrastructure;
9. store material, policies, certificates, and final release approval before Plan 14.

## Immediate next action

Complete and review **05D — Participation-Aware Browse and Pending Request Visibility** without changing public discovery ordering or introducing broader personalization. **04C — Resources + Scambio-Dona** remains independently available; 05C waits for contribution/resource decisions. Plan 06C2B requires Firebase/APNs configuration, push permission and preview decisions, server-side FCM credentials, and a self-host-compatible worker deployment target. Plan 07B still requires the exact automatic-chat trigger and post-membership access decisions. Deferred native Android/iOS checks from implemented feature plans belong in the consolidated Plan 12 QA pass. Production self-hosting does not begin until Plan 13, after the main functional work and Plan 12 UI/UX pass.

The independent public informational mini-track has SITE-00 implemented in
merged PR #23, SITE-01 in merged PR #25, and SITE-02 implemented as the
privacy-minimal local/CI waitlist boundary. Production D1/Turnstile resources,
the exact hostname, approved controller/legal copy, a public/privacy contact,
removal-request operations ownership, and waitlist retirement/retention remain
required inputs before SITE-03 can cut over the domain.
