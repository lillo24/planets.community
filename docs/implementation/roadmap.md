# Implementation Roadmap

**Status:** Planning baseline  

07C4's revised candidate work is specified in
[`07c4-unified-project-people.md`](07c4-unified-project-people.md): targeted
recipient-accepted role offers, one bounded People surface, and explicit
self-service organizer step-down. PR #124 now targets `main` after the reviewed
05E2 merge; it remains draft and unmerged pending founder review.

The repository's `main` branch remains at the validated DEMO-B baseline. The
`codex/stack-integration-main-candidate` branch combines the accepted open
product stacks for founder review; none of the candidate-only work below is
merged to `main` yet.

| Repository state | Scope |
| --- | --- |
| Implemented on `main` | Plans through the DEMO-B baseline at `06e983bb230a7a48514095fe407250ad6d38c148`, including the earlier application foundations, Project participation/chat/notifications, Scambio-Dona listing foundation, and SITE-00 through SITE-02W |
| Implemented in the integration candidate, not `main` | Project resource needs/contribution/coverage/actual-contribution flows; Scambio-Dona requests, agreements, conversations, handoff/return, loan availability, matching, saved searches and notifications; profile photos, trust gates and covers; reporting, corroboration, counterstatements and blocking; participation-request private chats; Project delegates, Co-creator/Co-organizer authority, capacity/fullness and shared workspace; realistic demo covers; Settings and complete English/Italian localization |
| Deferred | Optional MLS/E2EE research in unmerged PR #28; provider/account work and native visual QA assigned to their later plans |
| Not started | Provider-specific 06C2B; the remaining moderation/admin surface; Plans 10–14; SITE-03 production deployment |

This roadmap divides the first PLANETS build into reviewable Codex tasks. Each numbered item should normally become its own implementation prompt, branch, and pull request.

The ordering is intentional: security and canonical data rules are established before feature screens depend on them, product-heavy visual design is consolidated after the main functional feature set, and self-hosted production infrastructure is proven only after that UI/UX pass and before public release.

## Execution model

### Template Workshop track

The agreed sequence is **TW01 → TW02 → TW03 → DRAFT01 → TW04 → SIM01 →
SIM02 → TW05**. Begin each dependent plan only after its predecessor is merged
or its branch/commit is explicitly selected as the dependency base. The TW01
base is verified current `main` at `92d93ca5a455ab853df8bc34b66fd8d69f4fb341`;
this scoped track does not refresh the unrelated historical status text above.

| Plan | Current status and boundary |
| --- | --- |
| TW01 — Source-linked Template Workshop domain | Implemented on its isolated branch, draft and unmerged for founder review of historical public content, reusable allow-list and private Bozza contract. Automatic identity at publication, latest canonical projection, Completed-only RPC catalog/detail, opaque versions, legacy backfill without fabricated drafts, and a private TW02 removal seam. [Contract](../development/template-workshop.md) |
| TW02 — Template reporting/removal | Implemented on its isolated draft branch stacked on exact TW01 head; typed reports including original-Creator self-report, narrow staff published review and audited template-only removal. Founder review and predecessor integration pending; no merge/deployment |
| TW03 — Template-to-draft creation | Implemented on its isolated draft branch stacked on exact TW02 head; atomic full-collection independent drafts, applicant-private immutable receipts, exact retries and source/removal serialization. Founder review and later main/#128 integration pending; no merge/deployment |
| DRAFT01 | Implemented on the exact TW03 draft base; meaningful sparse drafts save before departure with session binding, retry-safe creation, invalid-input blocking and truthful partial-cover feedback. Draft founder review and predecessor/main/#128/#131 integration pending. [Contract](../development/proposal-draft-departure.md) |
| TW04 — Mobile Workshop | Not started; Workshop discovery/detail/application screens and publication notice remain deferred |
| SIM01 | Not started; separate agreed successor plan, outside TW01 |
| SIM02 | Not started; separate agreed successor plan, outside TW01 |
| TW05 — Demo world | Not started; complete eight-scenario Workshop fixtures remain deferred; TW01 uses small synthetic local/test fixtures only |

### Per-plan workflow

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

- **Implemented on `main`:** merged and validated on the current mainline.
- **Implemented in integration candidate (not `main`):** complete on this
  candidate branch and awaiting founder review of the draft integration PR.
- **In progress:** an active task exists but is not complete on either state.
- **Blocked:** a required decision/resource is missing.
- **Deferred:** intentionally outside the current sequence.
- **Not started:** no implementation exists.

The snapshot table above is authoritative for repository state. Detailed rows
below retain the plan-stage terminology recorded by their focused changes.

## Ordered plans

| ID          | Plan                                                      | Main result                                                                                                               | Dependencies           | Founder input expected                                                                                               | Status                             |
| ----------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| 00          | Architecture and repository bootstrap                     | Runnable monorepo foundation, local tooling, initial CI, development docs                                                 | Documentation baseline | Tool/account installation only if automation cannot provide it                                                       | Implemented                        |
| 01          | Database foundation and security model (parent)           | Secure database workflow plus shared identity, audit, and outbox primitives                                               | 00                     | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented                        |
| 01A         | Database workflow and security harness                    | Canonical migrations, fail-closed grants, public/private boundary, PostGIS, pgTAP, generated types, and CI replay         | 00                     | None expected                                                                                                        | Implemented                        |
| 01B         | Identity, audit, and outbox primitives                    | Auth/profile boundary and minimal shared audit/outbox foundations                                                         | 01A                    | Confirm any security-critical ambiguity Codex cannot isolate                                                         | Implemented                        |
| 02          | Mobile and web application foundations (parent)           | Flutter app shell, Next.js public/admin shells, environments, error handling, localization and monitoring foundations     | 00–01                  | No visual polish; only resolve navigation/product-shell ambiguity if material                                        | Implemented                        |
| 02A         | Mobile application foundation                             | Flutter startup, Riverpod/router, typed config, Supabase/Sentry, theme, localization, and state UI                        | 01                     | None expected                                                                                                        | Implemented                        |
| 02B         | Web/admin application foundation                          | Next.js public/admin shells and web-side application foundations                                                          | 02A                    | None expected unless current tooling exposes a material ambiguity                                                    | Implemented                        |
| 03          | Authentication and profiles (parent)                      | Public browsing boundary, mobile/web email OTP, profile setup, competences/preferences, privacy-ready profile data        | 01–02                  | Initial required profile fields, visibility rules, competence taxonomy strategy                                      | Implemented                        |
| 03A         | Mobile Email-OTP Authentication                           | Public-first mobile numeric email OTP, Supabase session state, sign-out, and minimal profile-anchor readiness             | 02B                    | None expected                                                                                                        | Implemented                        |
| 03B         | Web Email-OTP Authentication                              | Web email OTP and session behavior using the canonical backend                                                            | 03A                    | None expected for this scoped work                                                                                   | Implemented                        |
| 03C         | Basic Profiles, Skills, and Visibility                    | Display-name onboarding, optional bio, controlled starter skills, and per-field public/private visibility                 | 03B                    | Initial required fields, starter taxonomy, and basic visibility resolved; advanced profile decisions remain deferred | Implemented                        |
| 04          | Activity discovery/domain (parent)                        | One-time proposals plus separately scoped recurring activities                                                            | 03                     | Proposal fields, lifecycle decisions, broad location behavior                                                        | Implemented                        |
| 04A         | One-Time Proposals and Discovery                          | Draft/create/publish/cancel, public list/detail, requirements, location privacy, and mobile/web discovery                 | 03C                    | One-time lifecycle and rough/exact location behavior resolved                                                        | Implemented                        |
| 04B         | Tavoli / Recurring Activities (parent)                    | Versioned weekly/monthly recurring domain plus later mobile/web experience                                                | 04A                    | Initial recurrence and lifecycle resolved; occurrence exceptions remain deferred                                     | Implemented                        |
| 04B1        | Tavoli / Recurring Activity Domain Foundation             | Separate recurring schema, schedule history, bounded occurrences, lifecycle, privacy, canonical APIs, and tests           | 04A                    | None expected for the defined weekly/monthly foundation                                                              | Implemented                        |
| 04B2        | Tavoli Mobile/Web Experience (parent)                     | Separate mobile and public-web clients over the canonical 04B1 backend                                                    | 04B1                   | Functional UX review; no recurrence expansion                                                                        | Implemented                        |
| 04B2A       | Tavoli Mobile Experience and Browse Integration           | Mobile browse/list/detail/create/edit/manage UI over the canonical 04B1 backend                                           | 04B1                   | Native interaction review                                                                                            | Implemented                        |
| 04B2B       | Public Web Tavoli Discovery                               | Read-only public web Tavoli list and detail                                                                               | 04B2A                  | Functional public-web review                                                                                         | Implemented                        |
| 04C         | Resources + Scambio-Dona                                  | Standalone Scambio-Dona listings plus later Project resources, requests, matching, and notifications                      | 04A                    | Transaction/handoff, taxonomy, Project contribution, and matching decisions remain split into later slices           | In progress                        |
| 04C1        | Scambio-Dona Listing Domain Foundation                    | Owner lifecycle, rough-location public discovery, secure RPCs, identifier-only events, and tests                          | 04A, 03C               | None for the decision-light discovery-intent foundation                                                              | Implemented                        |
| 04C2        | Scambio-Dona Mobile Discovery and Owner Experience        | Mobile browse/detail/create/edit/publish/close experience over the 04C1 contracts                                         | 04C1                   | Native QA deferred to the consolidated Plan 12 pass                                                                  | Implemented                        |
| 04C3        | Project Resource Needs and Contribution Offers (parent)   | Project needs followed by request-linked contribution offers without collapsing them into standalone listings             | 04A, 04B1, 05A         | Contribution attribution/correction semantics remain later                                                           | In progress                        |
| 04C3A       | Project Resource Needs Domain Foundation                  | Stable Project-owned plain-text needs, lifecycle-aware creator/public reads, identifier-only events, and tests            | 04A, 04B1, 05A         | None for the decision-light open/closed need foundation                                                              | In progress                        |
| 04C3B       | Join-Request Contribution Selection + Mobile/Messages     | Request-attempt selection domain followed by mobile selection and structured Messages labels                              | 04C3A, 05A, 07A        | Accepted mutable commitments remain separate                                                                         | In progress                        |
| 04C3B1      | Join-Request Contribution Selection Domain                | Atomic historical Proposal-skill/Project-need ID selections with private requester/creator reads                          | 04C3A, 05A, 07A        | Tavolo skills wait for a canonical recurring requirement relation                                                    | In progress                        |
| 04C3B2      | Mobile Selection + Rounded Messages Labels                | Flutter request-selection controls, Project-need owner UI, and structured Messages labels                                 | 04C3B1                 | Native interaction review deferred to Plan 12                                                                        | In progress                        |
| 04C3C       | Accepted Participant Contribution Commitments (parent)    | Membership-scoped current expectations followed by a separately decided mobile management surface                         | 04C3B1, 05A            | Mobile edit location and delegated management remain separate decisions                                              | In progress                        |
| 04C3C1      | Current Commitment Domain Foundation                      | Membership-episode skill/resource sets, acceptance seeding, lifecycle-safe replacement, private reads, and tests          | 04C3B1, 05A            | None for participant plus canonical-creator backend ownership                                                        | In progress                        |
| 04C3C2      | Mobile Commitment Management                              | Participant and creator editing experience over the 04C3C1 domain                                                         | 04C3C1                 | Native interaction review; delegated/co-organizer authorization                                                      | In progress                        |
| 04C3D       | Acceptance Triage and Live Project Coverage (parent)      | Immutable creator acceptance decisions followed by mobile triage and current Project-need coverage coordination           | 04C3B1, 04C3C1, 05A    | External/manual coverage and delegate policy remain later decisions                                                  | In progress                        |
| 04C3D1      | Join-Acceptance Contribution Triage Domain                | Exact needed/already-found/extra decisions, selective commitment seeding, historical backfill, and concurrency tests      | 04C3C1                 | None for canonical-creator backend ownership                                                                         | In progress                        |
| 04C3D2      | Mobile Join-Acceptance Contribution Triage                | Mandatory three-way creator decision UI over every selected request contribution                                          | 04C3D1, 04C3B2, 07A    | Native interaction review; delegated/co-organizer authorization                                                      | In progress                        |
| 04C3D3      | Live Need Coverage + Group Coordination (parent)          | Backend live requirement truth followed by group-chat coordination and resurfacing                                        | 04C3D1, 04C3D2, 07B2C  | Delegate policy remains separate                                                                                     | In progress                        |
| 04C3D3A     | Live Project Requirement Coverage Domain                  | Participant/manual sources, exact coverage transitions, lifecycle cleanup, claim/manual/read RPCs, and tests              | 04C3D1, 04C3D2         | None for canonical creator/current-participant backend ownership                                                     | In progress                        |
| 04C3D3B     | Group Needs Coordination + Chat Resurfacing               | Chat Needs drawer, participant claim UI, creator manual control, system messages, notifications, and attention UX         | 04C3D3A, 07B2C, 06D    | Delegate policy remains separate; native interaction review remains Plan 12                                          | In progress                        |
| 04C4        | Scambio-Dona Requests, Agreements and Matching (parent)   | Request intent, reliable agreement/handoff, mobile coordination, loan availability, matching, and saved searches          | 04C1                   | STACK-STABILIZATION-01 clears inherited database validation blockers; the open stack remains unmerged                | Functionally complete (open stack) |
| 04C4A       | Resource Request Domain Foundation                        | Private request episodes, multiple acceptances, active-interest count, lifecycle serialization, and history               | 04C1, DB-COMPAT-01     | None for the bounded interest-request lifecycle                                                                      | In progress                        |
| 04C4B       | Reliable Scambio Agreement + Loan/Barter Domain           | Structured counterpart terms, give/lend/barter semantics, duration, handoff, completion, and return history               | 04C4A                  | Post-handoff amendment, dispute, and liability policy remain later founder decisions                                 | In progress                        |
| 04C4C       | Resource Requests + Messages (parent)                     | Durable conversation/projections followed by split mobile request, chat, agreement, and notification experiences          | 04C4B, 07A             | Native interaction review remains in Plan 12                                                                         | In progress                        |
| 04C4C3A     | Mobile Resource Requests + Unified Requests Inbox         | Interest count, canonical request actions, and discriminated Project/Resource Requests UI                                 | 04C4C2                 | Native interaction review deferred to Plan 12                                                                        | In progress                        |
| 04C4C3B     | Mobile Resource Conversation + Unified Chats              | Resource chat list/detail/send/Realtime and read-only closed coordination                                                 | 04C4C3A, 04C4C1        | Native interaction review                                                                                            | In progress                        |
| 04C4C3C     | Mobile Scambio Agreement Experience                       | Split negotiation followed by handoff, return, timeline, and overdue presentation                                         | 04C4C3A, 04C4B         | Native interaction review and later dispute policy                                                                   | In progress                        |
| 04C4C3C1    | Mobile Scambio Agreement Negotiation                      | Immutable terms proposal/counterproposal, acceptance, rejection, withdrawal, cancellation, and conflict recovery          | 04C4C3B, 04C4B         | Native interaction review deferred to Plan 12                                                                        | In progress                        |
| 04C4C3C1-F1 | Non-null Agreement Terms Flags                            | Forward SQL contract repair for strict mobile boolean parsing, with authenticated RPC and lifecycle regressions           | 04C4C3C1, 04C4B        | No handoff, timeline, overdue UI, or notification scope                                                              | In progress                        |
| 04C4C3C2    | Mobile Handoff / Return / Timeline / Overdue              | Physical handoff and return milestones, structured agreement timeline, and overdue presentation                           | 04C4C3C1, 04C4B        | Native interaction review and later dispute policy                                                                   | In progress                        |
| 04C4C3D     | Mobile Resources Notification UX                          | Resource notification copy/destinations and Resources preference controls                                                 | 04C4C3B, 04C4C3C, 06B  | User-facing copy and native interaction review                                                                       | In progress                        |
| 04C4D       | Loan Availability / Queue                                 | Accepted listing-side loan reservations followed by mobile schedule/availability UX                                       | 04C4B                  | Recurring availability, multi-unit capacity, automatic promotion, and post-handoff amendments remain deferred        | In progress                        |
| 04C4D1      | Loan Reservation + Conflict Domain                        | Derived accepted LEND schedule, half-open conflict enforcement, owner schedule, counterpart availability                  | 04C4B, 04C4C3D         | No FIFO entitlement or public borrower calendar                                                                      | In progress                        |
| 04C4D2      | Mobile Loan Schedule + Availability UX                    | Owner schedule visualization, pending availability, and at-risk warning UX                                                | 04C4D1                 | No automatic promotion                                                                                               | In progress                        |
| 04C4E       | Project Resource Matching (parent)                        | Explainable read-time matching domain followed by mobile Project matching UX                                              | 04C3A, 04C4D1          | No private reservation inference or guaranteed availability                                                          | In progress                        |
| 04C4E1      | Explainable Project Resource Matching Domain              | Creator-only Italian lexical tiers, coarse-geography scopes, mode filters, keyset, public-safe reasons                    | 04C4D2                 | No mobile UI, saved searches, alerts, or private availability                                                        | In progress                        |
| 04C4E2      | Mobile Project Resource Matching UX                       | Mobile consumption of E1 reasons and discovery routing                                                                    | 04C4E1                 | Native interaction review remains later work                                                                         | In progress                        |
| 04C4F       | Saved Searches + Matching Notifications                   | Personal saved filters, mobile execution, published-listing projection, immediate notification projection, and mobile UX  | 04C4E2, 06A            | STACK-STABILIZATION-01 clears inherited database validation blockers; taxonomy/radius remain later work              | Functionally complete (open stack) |
| 04C4F1      | Personal Saved Resource Search Domain                     | Private exact current-filter CRUD, semantic uniqueness, keyset reads, and browse-parity predicate                         | 04C4E2                 | No mobile UI, match snapshots, events, or notification policy                                                        | In progress                        |
| 04C4F2      | Mobile Saved Resource Search Experience                   | Save/manage/run personal filters through existing public Resource browse                                                  | 04C4F1                 | Native interaction review remains Plan 12; no notification behavior                                                  | In progress                        |
| 04C4F3      | Saved Resource Search Match Notifications (parent)        | Frequency-neutral published-listing match facts followed by immediate channel projection and mobile UX                    | 04C4F1, 06A            | Open stack remains unmerged; provider delivery remains 06C2B                                                         | Functionally complete (open stack) |
| 04C4F3A     | New-Listing Match Projection                              | Historical-boundary receipts, event-time F1 matching, private versioned facts, and identifier-only derived events         | 04C4F2                 | No notification row, push job, preference, frequency, copy, or match-history UI                                      | In progress                        |
| 04C4F3B     | Immediate Saved-Search Notifications (parent)             | Immediate, per-listing-deduplicated notification delivery followed by mobile consumption                                  | 04C4F3A, 06A, 06B      | No digest, per-search toggle, or provider send                                                                       | Functionally complete (open stack) |
| 04C4F3B1    | Backend Immediate Notification Projection                 | Current-state-revalidated in-app and push-job projection under the global Matching channel preferences                    | 04C4F3A, 06A, 06B      | No Flutter changes or provider delivery                                                                              | In progress                        |
| 04C4F3B2    | Mobile Matching Notification UX                           | Matching inbox copy, destination routing, and global Matching in-app preference control                                   | 04C4F3B1               | Native interaction review remains Plan 12; provider push remains 06C2B                                               | Implemented (open PR)              |
| 05          | Participation lifecycle (parent)                          | Shared project participation foundation, later mobile experience, and verified-contribution review                        | 04A, 04B1              | Capacity/fullness and later contribution/resource semantics remain unresolved                                        | In progress                        |
| 05A         | Project Participation Domain Foundation                   | Shared identity, private join requests, canonical membership history, protected meeting access, events, and tests         | 04A, 04B1              | No blocking decision; 07B1 derives chat activation from accepted membership                                          | Implemented                        |
| 05B         | Mobile Project Participation Experience                   | Join/status/withdraw, creator review, member state, leave/remove, and protected meeting UI                                | 05A                    | Functional/native UX review                                                                                          | Implemented                        |
| 05D         | Participation-Aware Browse and Pending Request Visibility | Own pending requests promoted in mobile Proposal/Tavolo Browse without changing public pagination                         | 04A, 04B1, 05A, 05B    | Native QA deferred to the consolidated Plan 12 pass                                                                  | Implemented                        |
| 05C         | One-Time Project Actual Contribution Attribution (parent) | Derived final-commitment attribution, sparse creator corrections, and a later mobile experience                           | 05A, 04C3D3B           | Delegate scope, participant reminder/correction flow, and Tavoli finalization                                        | In progress                        |
| 05C1        | Actual Contribution Attribution Domain                    | Membership-at-end baseline, sparse creator overrides/additions, effort marker, secure RPCs, events, and tests             | 05A, 04C3D3B           | None for canonical creator-only one-time Project ownership                                                           | In progress                        |
| 05C2        | Mobile Actual Contribution Experience                     | Participant read-only visibility plus creator post-end correction UI                                                      | 05C1, 05B              | Native interaction review; participant-to-creator reminder remains a separate future follow-up                       | In progress                        |
| 06          | Notification backbone (parent)                            | Canonical notification projection, later mobile inbox/preferences, then device registration and push delivery             | 03–05A                 | User-facing notification UX/copy and push behavior remain later review points                                        | In progress                        |
| 06A         | Notification Domain and Outbox Projection Foundation      | Categories/preferences, semantic inbox records/targets, multi-consumer receipts, participation projection, secure APIs    | 01B, 05A               | None expected for the defined participation foundation                                                               | Implemented                        |
| 06B         | Mobile In-App Notifications and Preferences               | Flutter inbox, unread state, preference controls, and structured project/request navigation                               | 06A                    | Native QA deferred by founder for a later consolidated pass; not passed or failed                                    | Implemented                        |
| 06C         | Push Delivery (parent)                                    | Provider-independent installation/jobs followed by Firebase mobile registration and trusted delivery                      | 06A, 06B               | Push permission timing, preview policy, and provider/account-owner setup                                             | In progress                        |
| 06C1        | Push Installation and Delivery-Job Foundation             | Private app installations, shared semantic resolution, independent `push.v1` projection, and recipient-level jobs         | 06A, 06B               | None; uses synthetic tokens and no provider account                                                                  | Implemented                        |
| 06C2        | Provider Delivery Integration (parent)                    | Provider-neutral worker protocol followed by Flutter registration and the repository-owned FCM adapter                    | 06C1                   | Firebase/APNs setup, permission timing, preview policy, credentials, and worker deployment                           | In progress                        |
| 06C2A       | Push Delivery Attempt and Worker-Protocol Foundation      | One-time installation fan-out, leases, safe attempt history, retries, terminal aggregation, and stale-token guards        | 06C1                   | None; uses synthetic outcomes and no provider account                                                                | Implemented                        |
| 06C2B       | Firebase Mobile Registration and FCM Adapter              | Flutter token/permission lifecycle plus repository-owned FCM HTTP v1 sends over the trusted 06C2A protocol                | 06C2A                  | Firebase Android/iOS config, APNs setup, permission timing, preview policy, credentials, and worker hosting          | Not started                        |
| 06D         | Project Chat Notification Projection and Mobile Alerts    | Message-time recipient fan-out into body-free in-app notifications and semantic push jobs, plus mobile chat alerts        | 06A, 06B, 06C1, 07B2C  | Native QA remains deferred to Plan 12; provider delivery remains 06C2B                                               | Implemented                        |
| 07          | Messages + Project Chat (parent)                          | Structured request items, Project-chat lifecycle authorization, and server-authorized realtime/mobile conversation        | 05A, 06A               | Native QA remains in Plan 12; later moderation overrides remain Plan 09                                              | Implemented                        |
| 07A         | Messages Surface and Structured Participation Requests    | Authenticated Messages inbox with canonical actionable join-request items                                                 | 05A, 06A               | Functional/native UX review and final Messages information architecture                                              | Implemented                        |
| 07B         | Project Group Chat (parent)                               | First-accept lifecycle/authorization foundation followed by messaging, Realtime, and mobile group experience              | 05A, 07A               | Optional E2EE research remains deferred; native QA remains in Plan 12                                                | Implemented                        |
| 07B1        | Project Group Chat Lifecycle and Authorization Foundation | One chat per Project, first-accept activation, and ownership/membership-derived current and historical entitlement        | 05A, 07A               | None for the scoped structural foundation                                                                            | Implemented                        |
| 07B2        | Project Chat Messaging, Realtime and Mobile Experience    | Authorized plain-text message model, Realtime hints, mobile chat/group info, and protected meeting access                 | 07B1                   | Native QA remains deferred to Plan 12; optional E2EE research remains unmerged                                       | Implemented                        |
| 08          | Storage and media hardening                               | Purpose-specific storage, access, metadata, cleanup, and processing hooks                                                 | 03–07                  | Broader media retention and self-hosted Supabase Storage versus external object storage                              | In progress                        |
| 08A         | Profile Pictures (parent)                                 | Private profile-photo foundation, mobile management, authorized delivery, and trust reminders                             | 03                     | Functionally complete through 08A4B in the open stack; native UX review remains Plan 12                              | In progress                        |
| 08A1        | Profile Photo Storage + Domain Foundation                 | Private WebP bucket, owner-only immutable objects, canonical path/audience metadata, and RPCs                             | 03                     | PR #95; non-owner delivery and trust reminders remain later slices                                                   | In progress                        |
| 08A2        | Mobile Photo Upload + Profile Management                  | Deterministic 512×512 WebP production, upload/replacement/cleanup, and profile UI                                         | 08A1                   | PR #96; native interaction review remains Plan 12                                                                    | In progress                        |
| 08A3        | Photo Read Access + Interactions                          | Reusable relationship authorization and non-owner private photo delivery                                                  | 08A2                   | PR #98; organizer pending/current-participant relationship is the first interaction set                              | In progress                        |
| 08A4A       | Personal Project Trust Gates + Contextual Photos          | Canonical photo gates, creator-review avatars, and Project-context organizer delivery                                     | 08A3                   | PR #101; native device QA remains in Plan 12                                                                         | In progress                        |
| 08A4B       | Scambio-Dona Profile Photo Trust Integration              | Resource-exchange counterpart gates and contextual photo placement                                                        | 08A4A                  | Current stacked PR; native device QA remains in Plan 12                                                              | In progress                        |
| 08B         | Project + Listing Cover Images (parent)                   | One optional canonical cover for Proposals, Tavoli, and Scambio-Dona followed by separate mobile UX slices                | 08A4B                  | No multi-image gallery, chat attachment, Drive hosting, or publication requirement                                   | In progress                        |
| 08B1        | Cover Image Storage + Domain Foundation                   | Private WebP bucket, parent-bound immutable paths, canonical metadata, lifecycle-aware delivery, and nullable read fields | 08A4B                  | Open dependency PR #106; cover rendering and selection remain 08B2                                                  | In progress                        |
| 08B2A       | Proposal + Tavolo Cover Mobile UX                         | Mobile normalization, owner management, and presentation for shared Project covers                                        | 08B1                   | Open stacked PR #110; native interaction and crop review remains Plan 12; no multi-image gallery                     | In progress                        |
| 08B2B       | Scambio-Dona Cover Mobile UX                              | Shared normalization, owner management, and presentation for Resource covers and matching cards                           | 08B2A                  | Current stacked PR; native interaction and crop review remains Plan 12; no multi-image gallery                       | In progress                        |
| 09          | Safety, moderation and admin                              | Reporting, blocking, content states, admin roles, moderation queue/actions, audit trail and minimal custom admin UI      | 04–08                  | Community rules, prohibited content, escalation, suspension, appeals, minimum age                                    | In progress through 09B2           |
| 09B1        | User Blocking Domain + Enforcement                        | Private directional episodes, symmetric new-interaction barrier, pending closure, photo enforcement, and race safety     | 09A2B                  | Founder review of the stacked backend/security boundary                                                              | In focused review                  |
| 09B2        | Mobile Blocking UX                                        | Contextual Block/Unblock actions, outbound management, confirmations, cache refresh, and safe interaction-failure copy   | 09B1                   | Founder review of the stacked mobile/privacy boundary; localization-stack reconciliation                             | Implemented in focused review      |
| 10          | Account deletion and privacy operations                   | In-app and web deletion paths, cleanup/anonymization jobs, export groundwork, privacy documentation inputs               | 03–09                  | Legal retention and anonymization policy; legal text remains founder/legal work                                      | Not started                        |
| 11          | Analytics and operational foundations                     | Explicit product events, privacy scrubbing, health/queue signals, alert requirements, and incident ownership inputs      | 00–10                  | Success metrics and analytics consent/legal choices                                                                  | Not started                        |
| 12          | Consolidated UI/UX and native QA pass                     | Coherent visual/interaction design, accessibility, responsive behavior, and deferred native flow validation              | 00–11                  | Final visual identity, high-impact interaction decisions, and native review                                          | Not started                        |
| 13          | Self-hosted production infrastructure readiness           | Provisioned and rehearsed production Supabase stack, security, backups, monitoring, operations, and cutover plan         | 00–12                  | Host/account selection, billing, DNS, credentials, retention objectives, and production-operation approval           | Not started                        |
| 14          | Release pipeline and store readiness                      | Controlled releases over the proven production backend, signed builds, internal testing, gates, and store checklists     | 00–13                  | Provider accounts, certificates, store listings, policies, and final release approval                                | Not started                        |

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
- historical retention as template-source groundwork; TW01 separately establishes automatic linked identities and Completed-only reusable projections without independent template authoring;
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

**Status:** Functionally complete through 04C4F3B2 in the open stacked PR chain. STACK-STABILIZATION-01 clears the inherited database validation blockers; the stacked 04C3, 05C, and 04C4 work remains open and unmerged. Implemented 04C1–04C2 are merged.

The earlier combined scope is split so standalone public listings do not force unresolved Project contribution or post-discovery transaction rules:

##### 04C1 — Scambio-Dona Listing Domain Foundation

**Status:** Implemented in merged PR #32 (`2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42`). Depends on merged 04A and 03C.

Owns standalone owner-managed `resource_listings`, `donate`/`exchange` discovery intent, private incomplete drafts, published rough-location discovery/detail, terminal closure, expected-identity-bound owner APIs, profile-display visibility, mode/locality/literal-keyword filtering, newest-first paired keyset pagination, identifier-only publish/close events, pgTAP, local integration, generated contracts, and documentation.

`exchange` does not define lending, barter, ownership transfer, return, payment, reservation, contact, or handoff mechanics. 04C1 also adds no resource taxonomy, media, Project linkage, saved searches, matching, notifications, quantities, prices, or transaction/request records.

##### 04C2 — Scambio-Dona Mobile Discovery and Owner Experience

**Status:** Implemented in merged PR #34 (`2da76de112a860210161d64de6bceab333159c26`). Depends on merged 04C1.

Owns the primary text-only Flutter browse/detail and owner create/edit/publish/close experience over the canonical 04C1 contracts. Home exposes `Progetti` and `Scambio-Dona` as separate pillars while the persistent Profile / Browse / Home destinations remain unchanged. Public discovery/detail stays signed-out; management preserves Auth/profile-setup return intent. It introduces no request, claim, contact, transaction, or handoff flow: 04C4A now owns only the backend request lifecycle, while request UI and later agreement/handoff semantics remain in 04C4C and 04C4B. Media remains Plan 08.

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

##### 04C4 — Scambio-Dona Requests, Agreements and Matching (parent)

**Status:** Functionally complete through 04C4F3B2 in the open stacked PR chain. STACK-STABILIZATION-01 clears the inherited database validation blockers, but the stack remains open and unmerged. Depends on 04C1; post-handoff amendment and dispute decisions remain outside the accepted child plans.

This parent keeps a lightweight expression of interest separate from reliable agreement terms, physical handoff/completion, loan scheduling, Project matching, and saved-search notifications. None of those later concepts may be inferred from the 04C1 `exchange` discovery intent or from an accepted 04C4A request.

###### 04C4A — Resource Request Domain Foundation

**Status:** In progress in the current stacked backend PR, based on DB-COMPAT-01 without merging either layer. Depends on 04C1 and DB-COMPAT-01.

Owns private episode-based `pending`/`accepted`/`rejected`/`withdrawn`/`listing_closed` request decisions, one coordination-open request per requester/listing, multiple accepted requesters, optional bounded private context, expected-identity mutations and private history, a public pending-plus-coordination-open-accepted interest count, listing-close serialization, identifier-only events, PT409 application conflicts, pgTAP, real-OTP integration, and generated contracts. Acceptance means only willingness to coordinate: 04C4B now attaches a separate agreement anchor, but acceptance still does not reserve or close the listing, disclose contact information, or assert handoff/completion.

###### 04C4B — Reliable Scambio Agreement + Loan/Barter Domain

**Status:** In progress in the current stacked backend PR, based on open 04C4A PR #71 without merging either layer. Depends on 04C4A.

Owns one agreement anchor per accepted request, immutable two-leg `give`/`lend` terms, optional requester `none`/`give`/`lend` consideration, bounded loan periods, server-owned listing snapshots, CAS negotiation, actor-authorized structured handoff/receipt/return milestones, automatic completion, pre-handoff cancellation, coordination closure, repeat requests, counterparty-only history, derived overdue indicators, and identifier-only events. Request status remains accepted history. Terms freeze at the first milestone; post-handoff amendments and dispute/liability consequences remain future structured work.

###### 04C4C — Resource Requests + Messages (parent)

**Status:** In progress through the current stacked 04C4C2 backend slice. Depends on 04C4B and the existing Messages foundation.

This parent separates the durable accepted-request conversation, notification/Messages projection, and mobile request/agreement/chat experience so every client uses the canonical 04C4A/04C4B state.

###### 04C4C1 — Accepted Resource-Request Conversation Domain + Realtime

**Status:** In progress in the current stacked backend PR, based on open 04C4B PR #72 without merging either layer. Depends on 04C4B.

Owns one private chat per accepted request episode, immutable human-only messages, permanent counterparty history, open-coordination send authorization serialized against agreement completion/cancellation, honest human previews with agreement-aware activity, private per-profile identifier-only message/agreement Realtime hints, identifier-only message outbox state, and focused pgTAP/real-OTP/concurrency coverage. Listing closure does not disable an accepted open chat; completion/cancellation makes it read-only. It adds no mobile UI, structured Messages item, notification projection, push, fake system message, or generic DM behavior.

###### 04C4C2 — Resource Request Messages + Notification Projection

**Status:** In progress in the current stacked backend PR, based on open 04C4C1 PR #73 without merging either layer. Depends on 04C4C1 and the existing Messages/notification foundations.

Owns discriminated cross-domain Requests and Chats projections with complete three-part keysets while preserving the existing Project and Resource domain reads. It maps supported Resource request, chat, and agreement events into the existing `resources` preference category, strict `resource_request`/`resource_chat` destinations, body-free in-app notifications, and provider-neutral push jobs. Resolvers validate identifier-only payloads against canonical rows and derive the opposite counterparty; historical Resource outbox rows are receipted without alert backfill. Mobile copy, routes, and Resources preference controls remain 04C4C3.

###### 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience

**Status:** In progress through stacked 04C4C3C1. Depends on 04C4C1 and 04C4C2.

This mobile parent is split so request actions, Resource chat, agreement work,
and notification UX land only with their canonical backend dependency.

###### 04C4C3A — Mobile Resource Requests + Unified Requests Inbox

**Status:** In progress in open PR #78, based on open 04C4C2 PR #75. Depends on 04C4C2.

Owns “N interested,” requester Request/Withdraw, owner Accept/Reject, strict
identity-bound requester history, canonical conflict refresh, a dedicated
Resource request route, and the discriminated Project/Resource Requests inbox.
Resource conversation remains in the dependent 04C4C3B layer; Resource
notification UX remains deferred to 04C4C3D.

###### 04C4C3B — Mobile Resource Conversation + Unified Chats

**Status:** In progress in open PR #79, based on open 04C4C3A PR #78. Depends on 04C4C3A and 04C4C1.

Owns strict Project/Resource unified Chats, Resource chat list/detail/send and
private Realtime, canonical reconnect reconciliation, accepted-request routing,
and read-only history after coordination closes. Resource chat renders human
messages only; the structured agreement timeline remains deferred to 04C4C3C.
The central typed chat discriminator is an extension point for future Groups,
but no Group domain or flow is implemented here.

###### 04C4C3C — Mobile Scambio Agreement Experience

**Status:** In progress through stacked 04C4C3C2. Depends on 04C4C3A and 04C4B.

This mobile agreement surface is split so negotiation can land independently
from physical handoff and the event timeline.

###### 04C4C3C1 — Mobile Scambio Agreement Negotiation

**Status:** In progress in open PR #80, based on open 04C4C3B PR #79. Depends on 04C4C3B and 04C4B.

Owns strict current/pending immutable terms, proposal and counterproposal,
accept/reject/withdraw, pre-handoff cancellation, compare-and-swap conflict
recovery, and the agreement card embedded in Resource chat. Counterproposals
create new immutable versions. Handoff freezes terms. This slice deliberately
does not label older historical versions without the event timeline.

###### 04C4C3C2 — Mobile Handoff / Return / Timeline / Overdue

**Status:** In progress in the current stacked mobile PR, based on open 04C4C3C1 PR #80. Depends on 04C4C3C1 and 04C4B.

Owns participant-confirmed handoff/receipt/return controls, the structured
agreement timeline, historical outcome labels, automatic completion UX, and
backend-derived non-punitive overdue presentation. Post-handoff amendments,
extensions, disputes, damage, fault, and liability remain future scope.

###### 04C4C3D — Mobile Resources Notification UX

**Status:** In progress in the current stacked mobile PR, based on open
04C4C3C2 PR #81. Depends on the mobile destinations established by
04C4C3B/04C4C3C and the existing notification foundation.

Owns strict Resource notification kinds/context, localized non-adjudicative
copy, Resource request/chat destinations, and the Resources in-app preference.
It completes the currently scoped 04C4C3A → 04C4C3B → 04C4C3C1 →
04C4C3C2 → 04C4C3D mobile implementation chain while its stacked PRs remain
open. The stored Resources push preference is preserved, but a push toggle and
provider delivery UX are not added here. Native interaction review remains
Plan 12; post-handoff amendments/disputes and Resource matching remain later
work. Future Groups, group invitations, Project invitations, and external
invite links remain a separate roadmap family; 04C4C3A preserves only the
central discriminated Messages extension boundary.

###### 04C4D — Loan Availability / Queue

**Status:** In progress through stacked 04C4D1 and mobile 04C4D2. Depends on 04C4B and the current 04C4C3D stack.

###### 04C4D1 — Loan Reservation + Conflict Domain

**Status:** Open PR #83 above open 04C4C3D PR #82; neither PR is merged. STACK-STABILIZATION-01 clears D1's inherited database reset/lint/advisors/pgTAP/type-drift/OTP blockers at the top of the stack.

One listing is one reservable unit. Mutually accepted listing-owner LEND terms
in an agreed or in-progress agreement are the sole active reservation truth;
pending terms, requester-side free-text LEND, completed/cancelled agreements,
and listing closure do not create or remove a second ledger. Half-open periods
may touch but not overlap. Terms acceptance serializes on the listing row and
returns PT409 for conflicts. The owner receives a private chronological active
schedule with existing overdue semantics and read-time at-risk derivation;
counterparties can check only their exact pending proposal's availability.
Neither request arrival nor release confers FIFO priority or automatic
promotion. Agreement terms/events remain the audit history.

###### 04C4D2 — Mobile Loan Schedule + Availability UX

**Status:** In progress above PR #83. STACK-STABILIZATION-01 clears the inherited D1 database-gate blockers at the top of the open stack; neither D1 nor D2 is merged.

Consume only `list_owned_resource_listing_loan_schedule`,
`check_resource_exchange_pending_loan_availability`, and existing
`get_resource_exchange_agreement` /
`list_resource_exchange_agreement_terms` RPCs. Owner calendar, pending
availability, and at-risk warning UX belong here, not in D1. Recurring owner
availability, multi-unit capacity, automatic promotion, and post-handoff
extensions/amendments remain deferred. 04C4E may consume D1's internal
availability truth for matching but must not expose private reservation dates.

The mobile owner schedule is chronological, not a FIFO entitlement, and remains
reachable for closed listings whose accepted agreements survive closure. A
pending immutable owner-side LEND proposal gets a private exact-version
availability preflight; GIVE and requester-side-only LEND do not. Accepted
listing-side LEND terms remain the sole reservation truth, and backend Accept
remains authoritative even when a preflight is unavailable. A future at-risk
reservation is still valid; the warning only says an earlier return has not yet
been confirmed.

###### 04C4E — Project Resource Matching

**Status:** In progress through stacked 04C4E2. The E1 backend matcher is PR #87; STACK-STABILIZATION-01 clears its inherited database-gate blockers at the top of the open stack. Depends on 04C3A and the public-listing domain; D1 private reservations remain deliberately outside match eligibility.

04C4E1 adds a creator-only, read-time Italian lexical matcher for an open need and published listing. Strongest text reason is title phrase, then title/details lexemes in listing title/description; coarse locality/area/country reasons and an explicit scope refine ordering. Full keyset pagination and optional Dona/Scambia filtering return public listing fields only. Matching does not guarantee physical availability, imply fulfillment, award contribution credit, or emit events. It does not inspect D1 private loan dates because the need has no canonical LEND period. STACK-STABILIZATION-01 clears the inherited replay/lint/advisors/pgTAP/type-drift/OTP blockers at the top of the current draft stack.

###### 04C4E1 — Explainable Project Resource Matching Domain

**Status:** In progress on a stacked PR based on 04C4D2. Creator-only backend matching, with no persisted match state.

###### 04C4E2 — Mobile Project Resource Matching UX

**Status:** In progress on stacked mobile PR #88 based on PR #87. It exposes matching only from creator-managed open needs, keeps explicit geography and Dona/Scambia filters visible, localizes discrete match reasons, and routes results to the existing public Resource detail and request flow.

The first version is lexical and explainable, with no score, synonyms/taxonomy,
private availability inference, saved search, or direct
Project-need-to-Resource-request relation. PR #87 still owns E1's pending final
database gates, and stacked mobile PR #88 owns E2. The saved-search sequence
continues above that exact stack with F1 in PR #89, F2 in PR #90, F3A in PR #91,
F3B1 in PR #92, and F3B2 in this PR.

###### 04C4F — Saved Searches + Matching Notifications

**Status:** Functionally complete through 04C4F3B2 in this open stacked PR, not merged. STACK-STABILIZATION-01 clears the inherited database validation blockers; F1 is open on PR #89, F2 is PR #90, F3A is PR #91, and F3B1 is PR #92.

04C4F1 persists personal, Project-independent definitions of exactly the current Resource browse query, Dona/Scambia mode, and locality filters. Query remains literal case-insensitive title/description substring matching; locality remains trimmed case-insensitive exact equality. Definitions are private, semantic duplicates return `PT409`, and no match result, listing snapshot, Project relation, event, notification toggle, frequency, or copy is stored.

###### 04C4F1 — Personal Saved Resource Search Domain

**Status:** In progress on PR #89, based on stacked mobile PR #88 (`2824e9b2a0a891473aecc3d19e0460bf63c55713`). STACK-STABILIZATION-01 clears the inherited database replay, lint, advisors, pgTAP, OTP, and generated-type blockers at the top of the stack.

Owns RPC-only CRUD, hard delete, `(updated_at desc, id desc)` pagination, database-enforced normalized uniqueness, and the field-only predicate that mirrors current browse filters. The predicate is lifecycle-independent by design; callers must separately require a published listing.

###### 04C4F2 — Mobile Saved Resource Search Experience

**Status:** In progress on PR #90, based on exact 04C4F1 head `e3ca1e04d1dd53bd2e2b538732cfe1bf323559c8` from PR #89.

Consumes F1 RPC-only CRUD and executes Open through the existing Resource Browse controller and `list_public_resource_listings` RPC. Definitions remain personal and Project-independent. Editing Browse controls after Open does not mutate the saved definition, and F2 adds no alternate matching semantics, notification behavior, alert toggle, or delivery frequency.

###### 04C4F3 — Saved Resource Search Match Notifications (parent)

**Status:** Functionally complete through 04C4F3B2 in the open stack; none of this status claims merge or final validation.

F3A and F3B deliberately separate frequency-neutral match provenance from user-visible delivery. Both reuse the F1 predicate only after canonical listing validation; neither introduces Project matching or private loan-availability semantics.

###### 04C4F3A — Saved-Search New-Listing Match Projection

**Status:** In progress on PR #91 at `2f3334568421e63f608c032628ae2612227d7f6d`, stacked above PR #90.

Consumes future `resource_listing.published` events with independent `saved-search-matching.v1` receipts. Historical publication events are receipted without backfill. Current published listings fan out through the exact F1 predicate only to definitions whose `updated_at` predates the source event, excluding the listing owner. Private facts retain source chronology and the saved-search version token; identifier-only `resource_saved_search.matched` events contain no filters or listing text. F3A creates no notification/push row, preference, copy, frequency, or client match-history API.

###### 04C4F3B — Immediate Saved-Search Notifications

**Status:** Functionally complete through 04C4F3B2 in the open stack. The fixed policy is immediate delivery, not a digest or user-selectable frequency.

One user-visible alert is eligible per recipient/new matching listing even when multiple saved searches match. All saved searches participate; there is no per-search notification toggle. The existing global Matching category controls in-app and push eligibility independently.

###### 04C4F3B1 — Backend Immediate Notification Projection

**Status:** In progress on PR #92, based on exact 04C4F3A head `2f3334568421e63f608c032628ae2612227d7f6d` from PR #91.

Consumes future `resource_saved_search.matched` events through independent `notifications.v1` and `push.v1` receipts. It revalidates the private fact, saved-search version/current filters, and current published listing before projecting `matching_available` to `matching_result`. Missing or stale delivery state is safely suppressed; inconsistent canonical state fails visibly. Notification rows and immediately available push jobs retain only the listing reference and are unique by recipient/listing, so overlapping definitions cannot duplicate either channel. Historical match events are receipted without backfill. Provider delivery remains outside this plan.

###### 04C4F3B2 — Mobile Matching Notification UX

**Status:** Implemented in open PR #93, based on exact 04C4F3B1 head `78daffd8311659bb289f900594eb042802704fc2` from PR #92; not merged. STACK-STABILIZATION-01 clears the inherited database validation blockers at the top of the stack.

Consumes the B1 contract in Flutter: category `matching`, kind `matching_available`, destination `matching_result`, listing identifier, and optional safe resolved listing title. It owns localized inbox copy, routing to the existing public Resource detail flow, and the global Matching in-app control while preserving the hidden canonical push value. It adds no digest, frequency selector, per-search toggle, provider integration, or extra inbox read.

Global resource taxonomy/tags, Dona-specific UI/policy refinement, post-handoff mutually accepted amendments, dispute/liability handling, and social “what we did together” profile history remain future work and are not blockers for 04C4B.

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

#### 05E — Project People Capacity and Fullness

**Status:** Implemented in the integration candidate; not merged to `main`.

Stores one nullable `people_capacity` on the shared private Project row for
both Proposals and Tavoli. Capacity is total people: the immutable original
Creator counts once and each current membership counts once, while delegated
authority alone and pending or historical participation do not count. Public
aggregate reads derive occupancy without exposing member identities. Null is
preserved only for drafts and legacy published Projects, which remain uncapped
until their next structural edit requires a value; all new publication
requires 1–100,000 people.

Join-request and membership-insertion triggers enforce fullness while holding
the shared Project lock, so every acceptance path is protected and concurrent
final-spot accepts cannot overbook. Leaving or removal frees a spot by ending
the canonical membership; no counter or waitlist is introduced. Proposal and
Tavolo editors, public cards/details, join actions, and manager participation
render the same capacity snapshot and map a stale full-state race explicitly.
Size-band filters, normalized popularity, per-occurrence Tavolo limits, and
Template Workshop/Market ranking remain deferred.

##### 05E1 — Organizer-aware registration capacity and public headcount

**Status:** Implemented and merged in PR #121.

Renames the shared field to `registration_capacity` and adds a default-off
setting controlling whether the Creator and active Co-creators/Co-organizers
use registration spots. Ordinary participants exclude active organizers;
public/social headcount is the unique union of organizers and current
memberships. Authority and membership remain independent, and one person is
never counted twice.

The existing Project lock serializes participant acceptance, authority
activation/revocation, capacity edits, and organizer-counting changes. Public
cards/details show registration usage, organizer breakdown, and unique people
involved. Editors and Project Team confirmations explain the policy. This
slice does not add ranking, size bands, waitlists, per-occurrence Tavolo
limits, or a combined participant/organizer chat model.

##### 05E2 — Public Social-Proof Count Reveal

**Status:** Implemented and merged in PR #122.

Adds one shared mobile presentation policy to Proposal/Tavolo cards and public
participation. Reveal exact usage and social counts when canonical `isFull` is
true or `max(socialPeopleCount - 1, 0)` reaches `3` for null capacity, otherwise
`min(registrationCapacity, max(3, ceil(registrationCapacity * 0.20)))`.
The Creator does not advance reveal; active Co-creators/Co-organizers count
socially, and overlap stays unique. Before reveal, show intended capacity and
organizer presence. Full stays visible, null capacity stays unspecified, and
managers retain exact counts. Details use one role-aware participation label.

The rule is derived and presentation-only: canonical aggregates, registration
enforcement, join eligibility, and concurrency remain unchanged, with no
migration or persisted reveal state. Future popularity uses exact
`socialPeopleCount`; ranking, normalization, size filters, and combined
people/chat work remain deferred. Future web count UI must follow this policy;
no web capacity feature is added here.

#### 05C — One-Time Project Actual Contribution Attribution

**Status:** In progress through stacked 05C2. Neither PR #68 nor its 05C2 mobile dependent is merged.

For a one-time Project, the final commitments of each membership episode active at the exact Proposal end instant become actual contribution attribution automatically. Request selections, acceptance decisions, earlier commitment snapshots, and live coverage are not themselves final attribution. Tavoli finalization, delegated management, ratings/reviews, statistics/badges, and participant disputes remain deferred.

##### 05C1 — Actual Contribution Attribution Domain

PR #68 remains open and unmerged. It owns the derivable frozen final-commitment baseline for ended published one-time Proposals, exact half-open membership-at-end eligibility, sparse creator exclusions/additions, the separate Substantial Effort / Energy marker, participant/creator reads, creator-only option and compare-and-swap replacement RPCs, identifier-only update events, and focused pgTAP/real-OTP/concurrency coverage. No Project-end worker or copied baseline is introduced. Memberships ended before Proposal end start from an empty baseline but can receive explicit creator attribution; post-end leave/removal does not erase baseline eligibility; rejoin episodes stay independent.

##### 05C2 — Mobile Actual Contribution Experience

**Status:** In progress as a mobile PR stacked on PR #68.

Adds participant/former-participant read-only actual-contribution visibility at Project chat → Group info → Actual contributions, preserving every membership episode independently. The creator's Manage participation member cards open the same membership-scoped sheet in editable mode, starting with automatic final commitments already selected and supporting canonical off-app additions plus the dedicated effort toggle. The mobile boundary consumes only the 05C1 read/options/CAS APIs, keeps expected and desired snapshots separate, and reloads canonical state after saves and stale-edit/options races without adding a mandatory Project-wide approval state. Tavoli remain excluded. A private participant-to-creator “remind creator” request/message/popup/notification remains a possible later follow-up rather than required 05C1/05C2 scope; cross-episode statistics/badges and group contribution surveys remain downstream or speculative.

Technical compatibility patch DB-COMPAT-01 is stacked above 05C2. It reserves PostgreSQL SQLSTATE `40001` for genuine serialization failures and uses PostgREST custom SQLSTATE `PT409` for explicit application conflicts. 04C4A/04C4B follow that convention for request, negotiation, and milestone races; conversations, queues, matching, and notifications remain isolated in 04C4C–04C4F.

Future project-presentation work must also represent Tavoli as a Progetti type/filter in the final information architecture and implement the accepted Online/In-Presence mode. Neither is a participation-table field in 05A.

The former combined Plan 05 scope is now split across the portions above. Remaining parent outcomes include:

- join request creation, withdrawal, acceptance, and rejection;
- duplicate/race protection;
- membership and role records;
- leave, removal, and proposal-state interactions as decided;
- owner review interface (05B);
- history-derived statistics beyond 05E's current aggregate occupancy;
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

#### 07C3 — Shared Project Workspace + Group Organization Tools

**Status:** Implemented in the integration candidate; not merged to `main`.
Depends on the integrated 07C2E delegated-authority stack.

Adds one private provider-neutral HTTPS workspace URL per Project. Creator,
Co-creator, and Co-organizer may manage it before or after chat activation;
current managers and current participants may read it, while historical or
unrelated profiles fail closed. Mobile Project Manage provides Add/Open/Edit,
Group info provides the durable current-group section, and Project chat moves
the existing Needs control into a horizontally scrollable Needs/Workspace
organization strip above history. The external provider owns content and
permissions. OAuth, Drive API integration, PLANETS file storage, attachments,
Realtime workspace events, public web UI, and media/demo work remain excluded.

### 08 — Storage and media hardening

**Goal:** Support user media without treating storage URLs as authorization.

**Status:** Functionally complete through 08A4B in the current open stacked PR chain, with 08B1 in progress as the single-cover backend/domain slice. PR #95 owns the 08A1 profile-photo foundation, PR #96 owns mobile photo management, PR #98 owns authorized generic viewer delivery, PR #101 owns personal Project trust gates and contextual placement, and the 08A4B dependency applies the separate Scambio-Dona trust/relationship matrix. Native-device UX review remains deferred to Plan 12. The selected portable Supabase Storage boundary now covers profile photos and purpose-specific single covers; broader media storage remains a separate decision.

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

#### 08A — Profile Pictures

08A is split into reviewable slices:

- **08A1 — Profile Photo Storage + Domain Foundation (PR #95):** repository-defined private `profile-photos` bucket, immutable owner-only WebP object paths, one canonical object-path/audience row, and expected-identity-bound owner RPCs. This slice stores `public` or `interactions` (“Only people I interact with”), defaults to `interactions`, and implements no non-owner delivery.
- **08A2 — Mobile Photo Upload + Profile Management (PR #96):** deterministic crop/resize/compression to 512×512 WebP targeting roughly 100 KB, upload with `upsert = false`, canonical replacement, cleanup attempts, and independent owner profile management UI.
- **08A3 — Photo Read Access + “Only people I interact with” (PR #98):** reusable exact/batch authorization and private delivery. The first interaction set is an organizer viewing a subject with a pending join request or current membership in any Project/Tavolo that organizer creates; ended/historical, co-participant, and reverse-direction relationships do not qualify.
- **08A4A — Personal Project Trust Gates + Contextual Photos (PR #101):** canonical-photo gates on person-created Proposal/Tavolo publication and join requests; localized preflight guidance; batch applicant avatars with relationship-ending invalidation; and a distinct public-Project organizer-photo context that does not broaden generic profile visibility.
- **08A4B — Scambio-Dona Profile Photo Trust Integration (current stacked PR):** gates only Resource listing publication and new requests, provides exact public-listing owner context, grants owner-to-pending-requester and symmetric accepted/open coordination visibility, and places owner/requester/chat avatars with relationship-ending cache invalidation without changing the 08A4A Project matrix.

08A1 keeps the bucket private, enforces `image/webp` and a 250 KiB hard limit, stores paths rather than URLs, retains no original, and leaves public/interactions reads, mobile UI, trust reminders, scheduled orphan cleanup, and account-deletion object cleanup to their owning follow-ups.

#### 08B — Project + Listing Cover Images

08B is split by the shared secure foundation and later mobile experiences:

- **08B1 — Cover Image Storage + Domain Foundation (open dependency PR #106):** purpose-specific private `cover-images` Storage, immutable owner/parent-bound WebP paths, one optional canonical Project or Resource cover, lifecycle-aware exact public delivery, nullable canonical read fields, strict client parsing, and real local Auth + Storage verification. It persists object paths rather than URLs and leaves physical orphan/account-deletion cleanup operationally deferred.
- **08B2A — Proposal + Tavolo Cover Mobile UX (current stacked PR):** reusable gallery selection and fixed 16:9 crop, off-isolate WebP normalization, editor-local add/change/remove state, draft-first save/publish orchestration, immutable-path loading/cache, and cover/fallback presentation across Proposal/Tavolo public and owner surfaces.
- **08B2B — Scambio-Dona Cover Mobile UX (not started):** equivalent Resource-listing normalization, management, and presentation over the separate Resource metadata.

08B1 targets one approximately 1280×720 16:9 WebP, roughly 200–300 KiB with a 512 KiB hard limit. It does not add galleries, originals, chat attachments, Google Drive/external image hosting, remote URLs, moderation UI, demo-world imagery, or a cover requirement at publication. Those exclusions keep cover media separate from 08A profile-photo audience and trust semantics.

### 09 — Safety, moderation and admin

**Goal:** Meet the minimum backbone needed before public user-generated content is released.

#### 09A1 — Reporting + manual-review foundation

**Status:** Implemented in the current stacked PR.

- private typed cases, append-only reports/notes/events, canonical subject and
  Project/Scambio-Dona context derivation, and retry-safe submission;
- authenticated Flutter report actions, explicit manual-review/privacy copy,
  and a narrow owner-only status list;
- private operator-managed `moderator`/`admin` roles and bounded canonical
  queue/detail/note/versioned-transition operations;
- a staff-only Next.js `/admin` queue and detail surface with no enforcement
  controls;
- identifier-only generic audit records and no moderation outbox event;
- no automatic content/account consequence.

Parent Plan 09 remains in progress. Its next explicit boundaries are:

- **09A2A — Project group corroboration (implemented in this stacked PR):**
  creation-time creator/accepted-member snapshots for qualifying
  person/conduct reports, reporter-anonymous explanation reads, one private
  Agree/Disagree/Unsure response, and staff-only identified evidence/counts;
  membership is only an eligibility proxy and evidence has no automatic
  consequence;
- **09A2B — Scambio-Dona counterstatement (implemented in this stacked PR):**
  automatic requests only for supported targets with canonical Resource
  request context, one private immutable canonical-counterparty statement,
  unified mobile Review Requests prompting/history, and staff-only
  pending/submitted evidence; no reporter read, Resource mutation,
  notification, or automatic consequence;
- **09B1 — User blocking domain + enforcement (implemented in the current open stack):**
  directional history, symmetric new-interaction enforcement, pending request
  closure, interaction-photo denial, and concurrency safety;
- **09B2 — Mobile blocking UX (implemented in review after 09B1):** confirmed
  contextual actions, outbound management, focused cache refresh, and
  direction-neutral interaction failure copy;
- **09C — Moderation consequences:** restrictions, content states and
  suspension, followed by escalation and appeals after founder policy
  decisions;
- **09D — Minimum age:** approved eligibility policy and enforcement.

Plan 10 remains the owner of report/evidence retention, account deletion, and
anonymization behavior.

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

Deferred 07C3 native checklist:

- paste/edit Google Drive and generic HTTPS links, malformed links, and very
  long share URLs;
- confirm Cancel/Open behavior and external Drive app/browser launch on Android
  and iOS, including a missing-app/browser fallback and offline state;
- verify current-participant leave and Co-organizer revocation while chat,
  Group info, or the workspace editor is open;
- verify Co-creator demotion, manager-without-participation access, and account
  switching while a private workspace hostname is visible;
- verify the organization-tools strip on narrow phone/tablet layouts, long
  localized labels, and the relocated Needs attention indicator;
- verify VoiceOver/TalkBack destination announcement, Needs versus Workspace
  navigation, text scaling, and focus behavior.

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

Deferred 08B2A native checklist:

- verify Android and iOS gallery permissions, cancellation, and source-read
  recovery without creating a hidden draft;
- verify the fixed 16:9 crop gesture, small-screen layout, high text scaling,
  screen-reader labels, and progress/error announcements;
- verify representative phone photos normalize promptly without visible UI
  jank and remain below the 512 KiB hard limit;
- verify portrait, landscape, and very large sources plus app background/resume
  during selection, crop, processing, and upload;
- verify create, replace, remove, retry-after-partial-save, and publish ordering
  against the local Auth + Storage stack on both platforms, including slow and
  offline upload recovery;
- verify public and owner card/detail loading, fallback, error, and path-change
  refresh behavior on constrained networks, multi-cover scrolling performance,
  anonymous public reads, and signed-in draft reads;
- verify light/dark themes and narrow-phone/tablet layouts;
- verify account switching during owner-cover selection/loading never exposes
  or applies the prior account's pending or draft image;
- verify TalkBack and VoiceOver crop/action controls on both platforms.

Additional 08B2B Resource checklist:

- verify Android/iOS gallery selection and fixed 16:9 crop gestures with large
  item photos;
- verify slow/offline new-listing upload, retry against the retained draft,
  replacement, and removal;
- verify public Scambio-Dona scrolling and Project-resource matching cards with
  many immutable cover paths;
- verify light/dark themes, narrow-phone/tablet layouts, and clear visual
  distinction between the Resource cover and owner avatar;
- verify an account switch with a draft editor open never exposes or applies
  the prior owner's private cover;
- verify restrained TalkBack/VoiceOver cover semantics and editor actions.

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

Complete and review the stacked **04C4C3C2 — Mobile Handoff / Return / Timeline / Overdue**
on open 04C4C3C1 PR #80, which remains based on open 04C4C3B PR #79 and open
04C4C3A PR #78, without merging it or the lower stack. 04C1 is implemented in merged PR #32
(`2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42`) and 04C2 is implemented in
merged PR #34 (`2da76de112a860210161d64de6bceab333159c26`).
06D is implemented in merged PR #31, while 06 remains in
progress because provider-specific 06C2B is not started. Optional E2EE/MLS
research remains unmerged and deferred in PR #28. The stacked 04C3/05C work
remains open and unmerged beneath DB-COMPAT-01; the 04C4A→04C4C2 stack remains
open beneath 04C4C3C2, while 04C4D1/04C4D2/04C4E1/04C4E2 are open and stacked
and 04C4F1 is open on PR #89 above PR #88, 04C4F2 is open on PR #90, 04C4F3A is open on PR #91, 04C4F3B1 is open on PR #92, and 04C4F3B2 is in progress in this PR. Plan 06C2B remains
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
