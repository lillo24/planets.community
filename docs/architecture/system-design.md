# System Design and Responsibility Boundaries

**Status:** Initial accepted design  
**Implementation status:** Foundations, authentication, profiles, one-time proposals, Tavoli mobile/public-web discovery, shared project participation, in-app notification projection, structured participation-request Messages, Project group-chat lifecycle/durable message/mobile experience, Project-chat notification/push projection, the provider-independent push/job foundation, provider-neutral push delivery worker protocol, and the static-first informational site with its local/CI one-time waitlist boundary and native Workers runtime implemented or in focused review

This document describes how the major parts of PLANETS should interact. Technology choices are recorded separately in [`core-stack.md`](core-stack.md).

## Product shape

PLANETS is primarily a mobile platform for local co-creation. Users discover or create proposals, contribute relevant competences/resources, request participation, coordinate after acceptance, and generate reusable community knowledge from completed work.

The initial system has four user-facing responsibilities across three applications:

1. **Mobile application:** the full ordinary-user experience on Android and iOS.
2. **Public informational site:** small static-first launch and informational pages plus one purpose-limited launch-waitlist operation, without product behavior.
3. **Public discovery:** selected dynamic public discovery without reproducing the whole app.
4. **Admin interface:** moderation and platform administration, isolated from normal user flows.

Every surface that accesses product data uses one canonical backend and data model. The informational site's isolated waitlist record is not a competing product data model.

## High-level structure

```text
Vite informational site       Flutter mobile application       Next.js discovery/admin application
    static assets                         \                               /
         |                                 +-------------+---------------+
POST /api/waitlist                                       |
         |                           Supabase platform (managed development/test;
Cloudflare Worker + Static Assets            intended self-hosted production)
    |              |                    +---------------+----------------+
Turnstile         D1                    |               |                |
server check   launch_waitlist     Auth and RLS  PostgreSQL/PostGIS  Storage/Realtime
                                                       |
                                            functions, outbox, and queues
                                               |                    |
                                             FCM                  Resend
                                          push delivery      auth/security email

             Sentry observes application failures
       PostHog later receives explicit product events
```

The deployment model does not change these responsibility boundaries. All clients still use one canonical Supabase/PostgreSQL backend. Managed Supabase may support development, staging, testing, or migration rehearsal, while self-hosted Supabase is the intended production target. The production infrastructure is deferred to its dedicated roadmap phase and does not exist yet.

## Core responsibility rules

### Mobile client foundation

The Flutter process validates typed `local`, `staging`, or `production` compile-time configuration before initializing one Supabase client. Riverpod is the dependency/state boundary and `go_router` owns navigation. Optional Sentry monitoring wraps launch but cannot prevent the application from starting when monitoring itself fails. The public root does not require authentication. Mobile email-OTP request/verification, Supabase-derived session restoration, sign-out, and sanitized internal post-auth returns live in the Auth feature; magic-link/deep-link callbacks and social providers remain deferred.

Mobile source is organized by real feature ownership, supported by narrow shared `core` modules for configuration, backend access, routing, theme, monitoring, and common state UI. New layers or abstractions should appear only when a feature has concrete behavior to place in them.

### Public informational site and launch waitlist

`apps/site` is a separate Vite/React/TypeScript application that builds the
public page to ordinary static assets. It has no authentication, Supabase client,
server rendering, analytics, or product-domain behavior.

Its only dynamic operation is `POST /api/waitlist`: a native Cloudflare Worker
handler revalidates the email and explicit
one-message consent, verifies Turnstile server-side, normalizes the address, and
performs a prepared idempotent insert into D1. The record is limited to the
normalized address, creation/consent timestamps, fixed
`launch_notification_v1` purpose, and nullable SITE-04 `notified_at`. It
contains no IP address, user agent, name, location, analytics identifier, or
arbitrary request data.

The address is authorized only for one notification when the PLANETS app
launches. It is not a newsletter and cannot be reused for marketing, promotions,
recurring updates, profiling, or unrelated communication. Duplicate requests do
not reveal membership or rewrite the original record. Valid removal requests
delete the row; no shadow marketing record is retained.

Matching files use Cloudflare Workers Static Assets' asset-first path; `/api/*`
is routed to the Worker first, and there is no SPA fallback. Local
Wrangler/Miniflare state, committed D1 migrations, official Turnstile test
credentials, and mocks make the boundary reproducible without production
resources. SITE-03 still owns Cloudflare provisioning, production secrets and
hostname, legal/controller/contact inputs, deployment, and DNS. SITE-04 owns
delivery and approved retirement/retention behavior. ADR 0005 records the
waitlist boundary and ADR 0006 records the Workers runtime.

### Dynamic web/admin client foundation

The `apps/web` Next.js App Router separates public and admin routes with `(public)` and `(admin)` route groups while retaining one root layout. Pages and layouts remain Server Components unless an interaction or browser API requires a narrow Client Component boundary.

The web application defines one public `local`, `staging`, or `production` environment contract. It exposes only the canonical Supabase URL and publishable key plus an optional Sentry client DSN; staging and production Supabase URLs require HTTPS. Typed factories use the generated public `Database` type, a browser-only client, and a new cookie-backed server client per request.

Ordinary web authentication uses an in-memory two-step numeric email-OTP flow. The browser `@supabase/ssr` client owns the cookie-backed session; Next.js Proxy validates/refreshes and propagates those cookies without authorizing or redirecting; Server Components derive trusted identity through `getClaims()`, not `getSession()`. Optional post-auth returns accept only sanitized internal paths. The application stores no pending email/code outside component memory and implements no magic-link callback, deep link, password, or social provider.

The public `/` route remains informational and reports only minimal signed-out, ready, or profile-setup-required state. The authenticated `/profile` route server-loads owner-authorized settings and hands interaction to a narrow Client Component. The reserved `/admin` route fails closed with a 404 for signed-out and ordinary authenticated users until a later plan defines admin authorization. Optional Sentry instrumentation sends no default PII and disables tracing and replay; missing Sentry configuration is a valid disabled state.

### The backend owns authorization and invariants

Clients may guide users and prevent invalid input early, but the backend must remain correct when a client is outdated, modified, interrupted, or malicious.

Use database constraints, Row Level Security, and named server operations for rules such as:

- who can see private profile or location data;
- who can edit, publish, cancel, or complete a proposal;
- whether a join request is valid;
- whether a user can become or remain a proposal member;
- when a project group chat exists;
- who can read or write that chat;
- which moderation actions an administrator can perform;
- whether repeated requests are safely idempotent.

### The database owns canonical state

PostgreSQL is the canonical record for accounts, profiles, proposals, standalone resource listings, participation, messages, notification events, reports, and audit history.

External systems such as FCM, Resend, Sentry, and PostHog are delivery or observation tools. They must not become the only record of product state.

### Identity and transaction-local operational primitives

Supabase Auth's `auth.users` row is the login identity. The matching `public.profiles` row is the stable PLANETS application identity anchor and uses the same UUID. It owns a casing-preserving display name, optional bio, and database-maintained timestamps. A profile is complete exactly when its display name is non-null after canonical validation; there is no writable completion flag. There is no signup trigger, so an Auth identity without a profile anchor remains a valid transitional state and the authenticated application flow must create its own anchor explicitly.

After mobile or web OTP verification, the application inserts the signed-in user's skeletal profile anchor. It accepts only the expected `profiles_pkey` duplicate as idempotent success and does not use update-dependent upsert behavior. Missing anchors retain a focused retry; skeletal anchors route to profile setup; only a valid display name makes the profile ready. Restored mobile and web sessions perform the same derived readiness check.

`skill_categories` and `skills` contain a deterministic, system-managed starter catalog. `profile_skills` represents owner selections and `profile_field_visibility` stores independent public/private choices for display name, bio, and skills. Defaults are public and owners retain full table access through RLS. Mobile and web both call `update_own_profile`, which binds the form's expected profile ID to the current `auth.uid()` before validating and atomically committing scalar values, deduplicated controlled skills, and all three audience choices.

Anonymous users cannot select from `profiles`. `get_public_profile(profile_id)` is the narrow exact-ID boundary for completed profiles and returns only profile ID plus visibility-sanitized display name, bio, and controlled skill descriptors. It never returns Auth email, timestamps, visibility rows, or owner-only metadata and does not provide a directory. Photo media, location, custom skills, proficiency, and organizer/participant audiences remain deferred.

Raw Auth deletion is deliberately blocked while a profile or actor-linked audit record exists. The eventual account-deletion workflow must define cleanup, anonymization, and lawful retention before removing those restrictive relationships.

### One-time proposal domain

`proposals` stores a creator-owned one-time activity, content, schedule, IANA event time zone, and rough public location. Its business lifecycle is only `draft`, `published`, or `cancelled`. Upcoming, Happening, Just Finished, and Completed are derived from `starts_at`, `ends_at`, and the current time; Just Finished begins exactly at the end and lasts until, but not including, 24 hours later. Completed proposals remain historical canonical records and may become sources for future explicit Community templates, but are not themselves mutable template records.

`proposal_meeting_details` physically separates exact meeting text/coordinates from the rough public location. Public list payloads never include exact meeting data. Exact-ID public detail returns exact meeting text only for `public` visibility; `participants` visibility returns no protected value and an explicit restricted flag. The shared participant boundary returns protected operational meeting information only to the creator or a current accepted participant without weakening this anonymous contract. `proposal_skills` reuses the controlled 03C catalog with `required` or `useful` meaning; no second or free-form taxonomy exists.

Complete-profile creators manage proposals only through expected-identity-bound `create_proposal_draft`, `update_own_proposal`, `publish_proposal`, and `cancel_proposal` operations. Public clients use sanitized `list_public_proposals` and `get_public_proposal`; owners use separate complete owner reads. Published content freezes when an activity starts, cancellation is terminal and permitted only before its end, and publish/cancel record content-free audit/outbox identifiers without delivering notifications.

`private.audit_events` stores append-oriented operational and security history, not product analytics. `private.outbox_events` stores transaction-local handoff records for later asynchronous work; it is not itself a queue or delivery implementation. Both remain outside the Data API with no direct client grants. Future domain operations can write them within the same transaction, while queue consumption and delivery remain owned by plan 06.

### Recurring activity domain

`recurring_activities` stores persistent creator-owned Tavoli separately from one-time proposals. Its explicit lifecycle is `draft`, `published`, `paused`, or `ended`; clock time never completes a series. Published Tavoli remain open-ended until paused or ended, paused series retain their content/history without active discovery occurrences, and ended series are terminal historical records.

`recurring_activity_schedules` stores non-overlapping versioned weekly or monthly rules as local wall-clock time plus a recognized IANA time zone. Weekly recurrence has one ISO weekday; monthly recurrence has one day from 1 through 28. A future schedule change closes the prior version at an exclusive local-date boundary and inserts a new version, so past meetings are never reinterpreted. Before that new version becomes effective, it may be corrected in place at the same boundary without creating redundant history or changing the already-effective row. Canonical helpers derive only bounded windows and calculate each UTC instant from its local date/time and zone, preserving the intended local time across daylight-saving changes.

`recurring_activity_meeting_details` physically separates exact meeting text/coordinates from structured rough public location. Anonymous discovery uses narrow list/detail operations: normal list includes only published series and requires callers to reuse one explicit reference-time snapshot across cursor pages, while exact-ID detail may retain published, paused, or ended history. Participant-restricted exact data is absent from public payloads and is available to the creator/current accepted participant only through the shared project meeting boundary.

Complete-profile creators use expected-identity-bound create/publish/resume operations; all owner mutations reject stale account-switch forms before changing data. Publication, schedule changes, pause, resume, and end record content-free audit/outbox metadata without implementing notification delivery. 04B2A provides the full Flutter Tavoli experience. 04B2B provides signed-out, read-only Next.js discovery through only the sanitized public list/detail operations; its list cursor preserves one caller-owned reference-time snapshot across pages.

### Scambio-Dona listing domain

`resource_listings` stores standalone owner-managed Scambio-Dona availability separately from Projects and participation. `donate` and `exchange` are discovery intents only: `exchange` does not define lending, barter, transfer, return, payment, reservation, contact, or handoff behavior. The stored lifecycle is `draft`, `published`, or terminal `closed`; closure means only that the listing is no longer publicly available.

Drafts may be incomplete and remain private. Publication requires a bounded plain-text title and description plus country, locality, and a public rough-location label. There is no exact address, point, contact field, media reference, resource taxonomy, quantity, price, Project foreign key, requester, or transaction state. An editable published listing must remain publishable atomically, and changing its mode changes only its discovery bucket.

Complete-profile owners use expected-identity-bound create and publish operations, while authenticated owners use the same identity boundary for update, close, and owner history. The table has RLS but no client policies or direct grants. Anonymous and authenticated clients use narrow list/detail functions; list discovery is newest-first paired keyset pagination with optional mode, case-insensitive locality equality, and literal case-insensitive title/description substring filters. Detail returns an owner display name only when the existing profile visibility row is public. Publish and close write identifier-only audit/outbox state for later consumers without projecting notifications.

The 04C2 Flutter client keeps Scambio-Dona in the Home pillar beside Progetti,
without changing the persistent Profile / Browse / Home navigation. Its public
list and detail are signed-out, while My Listings and create/edit routes require
a complete profile and preserve their Auth/setup return destination. The client
uses only the canonical listing RPCs; closing remains availability-only, and
post-listing request/contact/handoff behavior remains deferred to 04C4.

### Shared project participation domain

`projects` is a private, narrow identity registry across `proposals` and `recurring_activities`. Its UUID equals the concrete activity UUID and it stores only kind, synchronized creator, and creation time. Source insert/delete triggers preserve the one-to-one invariant for migration replay and trusted fixtures; content, lifecycle, schedules, skills, and location remain solely in the concrete tables. A source with request or membership history cannot be deleted.

`project_join_requests` preserves each private `pending`, `accepted`, `rejected`, or `withdrawn` attempt and an optional trimmed 500-character requester message. A complete non-creator may request a published one-time project strictly before its end or a currently published Tavolo. There may be at most one pending attempt and no request while the person is a current member. Terminal attempts remain history, so withdrawal, rejection, voluntary leave, or creator removal permits a fresh request whenever eligibility returns.

`project_memberships` is acceptance history, not contribution proof. Acceptance atomically closes the request and creates one current membership; creator ownership is separate. Leave/removal ends a membership without deleting it, and pause/end/completion does not rewrite history. One current membership per project/profile is enforced centrally. Capacity, waitlists, participation roles, resources, badges, and creator-verified contribution remain deferred.

All mutations and private reads use expected-identity-bound project RPCs. Tables have RLS but no client grants/policies. Request messages are visible only to the requester and project creator; creator review exposes a narrow authenticated display identity but never Auth email. Protected meeting details are available only to the creator or a current accepted member. Each successful transition writes identifier-only audit/outbox events. In 07B1, insertion of the canonical accepted membership also ensures the one Project group-chat anchor transactionally; it does not consume or repurpose the accepted outbox event.

### Structured participation-request Messages

The authenticated mobile Messages surface is a projection of canonical
`project_join_requests`, not a second message or request-copy store. Narrow
expected-identity-bound list and exact RPCs return a request only to its
requester or the concrete Project creator, including the authorized private
request message, current Proposal/Tavolo title, both display identities, state,
and activity chronology. Missing and unauthorized exact IDs fail identically.

The inbox uses bounded `(activity_at, request_id)` keyset pagination where
`activity_at` is resolution time or creation time for a pending request.
Creators may Accept/Reject and requesters may Withdraw through the existing 05A
transitions; the client reloads canonical state and synchronizes its existing
05B participation view. Resolved items remain read-only history. The routes
`/messages` and `/messages/requests/:requestId` belong to Home and require a
complete authenticated profile. No unread badge, generic chat message, thread,
or group-chat authorization is introduced by 07A.

### Project group-chat lifecycle and authorization foundation

`project_group_chats` is one private structural anchor per shared `projects` row.
The first accepted join request creates it inside the same transaction as the
canonical membership; later acceptances and rejoins conflict safely onto the
same chat. Existing membership history is reconciled from its earliest
`joined_at`. Project completion, Tavolo pause/end, and membership termination do
not delete the anchor.

Chat authorization derives from immutable Project ownership and append-preserved
`project_memberships`; there is no chat-member mirror. The creator always has
current and historical organizer entitlement. Current accepted participants
have current/send entitlement. Leave or removal ends it immediately while each
half-open `[joined_at, ended_at)` interval remains available for future
history-at-time checks; rejoin creates another interval and preserves the gap.
The expected-identity `get_own_project_group_chat` RPC exposes only the anchor,
Project kind, viewer role, and entitlement booleans to a creator, current
member, or former member. Missing and unrelated lookups fail identically.

07B1 stores no message bodies, encryption material, meeting details, or chat
participant rows and configures no Realtime transport. MLS/E2EE was technically
prototyped in unmerged PR #28 but is deferred as an optional future privacy
enhancement and is not a production dependency for the MVP.

### Project group-chat message domain and Realtime transport

The MVP stores immutable, canonically trimmed plain-text messages in
`project_chat_messages`. HTTPS/TLS protects transport and expected-identity RPCs,
database constraints, private helpers, RLS, and fail-closed grants enforce
ordinary server authorization. The PLANETS backend can technically read message
bodies; this architecture is not end-to-end encrypted.

The creator and every current accepted participant can read the complete durable
chat history, including messages from before a participant's first join. A
former participant can read only messages created through the end of their
latest membership. Rejoin restores the full accumulated history, including the
gap, and a later leave/removal advances the retained frontier. Current
entitlement—not historical visibility—is required to send or receive live
signals. Proposal/Tavolo lifecycle changes alone do not make the chat read-only.

`send_project_chat_message` acquires the established concrete-Project then
shared-Project lock before checking current entitlement and assigning the server
timestamp. Leave and removal record their boundary after the same lock, making
send/termination races deterministic. History and chat-list APIs use bounded
descending keysets; former-member previews and activity derive only from the
latest message that viewer may read.

PostgreSQL remains the message history. A successful send also publishes an
identifier-only private Supabase Broadcast signal to one chat/profile topic for
each profile entitled at that locked transition. Realtime authorization binds
the topic to `auth.uid()` and current chat entitlement. Per-profile fan-out means
an old cached socket receives no later signal after leave/removal; reconnecting
as a former member also fails authorization. Clients reconcile through durable
history after a signal or reconnect. Message bodies are absent from Realtime,
outbox payloads, and audit records. The message outbox event is reserved for a
future projector and existing notification/push consumers ignore it.

### Clients use shared operations rather than duplicate workflows

Safe simple reads may query authorized views/tables directly. Multi-step or security-sensitive changes should use named backend operations, for example:

- `publish_proposal`
- `request_to_join_project`
- `withdraw_project_join_request`
- `accept_project_join_request`
- `reject_project_join_request`
- `leave_project`
- `remove_project_member`
- `cancel_proposal`
- `complete_proposal`
- `block_user`
- `report_content`
- `delete_account`

The participation operations above and one-time proposal operations are concrete. Remaining names and signatures will be defined during their owning schema plans. The key rule is that Flutter and Next.js must call the same canonical transition rather than reproduce its steps independently.

### Next.js is a client and delivery surface

Next.js may perform server rendering, protect admin routes, and call backend operations from server components/actions. It must not become a parallel domain backend with rules unavailable to mobile.

### External effects are asynchronous where possible

A proposal action should commit its canonical database result without depending on an external push/email request succeeding at the same moment.

The preferred sequence is:

1. validate and perform the domain transition in a database transaction;
2. record one or more domain/notification outbox events;
3. enqueue delivery work;
4. deliver through FCM or email;
5. record success, failure, and retry state with idempotency protection.

Edge Functions and background workers remain valid implementation choices when their source is repository-owned, deployment-specific values come from environment/secrets, and they can run or be tested in the supported local/self-hosted Supabase environment where practical. Canonical domain and durable job state should remain database-backed where appropriate. Queue or scheduling implementations must not require an unreproducible managed control-plane action as a production invariant.

## Main data domains

| Domain                  | Responsibility                                                                                              | Important relationships                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Authentication identity | Login identity, verified contact method, session                                                            | Linked one-to-one with an application profile                                             |
| Profiles                | Display identity, competences, interests, preferences, visibility settings                                  | User, skills, participation history, media                                                |
| Skills/competences      | Controlled taxonomy used by users and proposals                                                             | Many-to-many with profiles and proposal requirements                                      |
| One-time proposals      | Creator-owned content, schedule, rough/exact location separation, stored lifecycle, derived temporal status | Creator, controlled skill requirements, future participation, future template source      |
| Recurring activities    | Persistent Tavoli, versioned weekly/monthly schedules, bounded occurrences, rough/exact privacy, lifecycle  | Separate from one-time proposals; Flutter experience and public web discovery implemented |
| Resource listings       | Standalone Scambio-Dona owner lifecycle, rough-location discovery, and sanitized public detail             | Profile owner only; no Project, transaction, taxonomy, media, request, or handoff linkage  |
| Participation           | Shared project identity, private requests/decisions, current membership and retained history                | Profile and concrete one-time/recurring project; source for authorization and later stats |
| Messages                | Authenticated structured participation-request inbox/detail; future mobile Project-chat entry points        | Canonical join requests in 07A; separate Project-chat domain                              |
| Project chat            | Structural anchor, immutable message history, authorized list/send APIs, and private Realtime hints         | Creator plus current/former participants under canonical membership-time rules            |
| Notifications           | Controlled categories/preferences, recipient in-app records, private installations, and recipient push jobs | Recipient, per-consumer source event receipt, optional project/request/membership         |
| Templates               | Reusable proposal structure derived from approved past/community content                                    | Source proposal, attribution, moderation/publication state                                |
| Community statistics    | Aggregated views over canonical activity and participation                                                  | Proposal type, location, participation, time                                              |
| Moderation              | Reports, blocks, content status, actions, internal notes, appeals if introduced                             | Users, proposals, messages, media, administrators                                         |
| Audit/operations        | Security-relevant and administrative action history                                                         | Actor, target, action, timestamps, metadata                                               |

Later schema plans must extend this model deliberately and record unresolved product choices instead of guessing them.

## Public and private data separation

A row being accessible through the Supabase API does not mean all of its columns should be public. Public browsing should rely on deliberately sanitized views or narrow tables.

### Potentially public

Depending on visibility rules:

- proposal title, summary, broad location, category, and status;
- requested competences/resources;
- public creator/profile summary;
- participant count without private membership details;
- approved proposal media;
- reusable community templates and aggregate statistics.

### Authenticated/private

Examples include:

- email and authentication identity;
- notification/device data;
- private profile fields and restricted photos;
- join-request messages and decision history;
- exact meeting details;
- private proposal media;
- full membership lists where not public;
- moderation evidence, internal notes, and audit metadata.

### Location rule

Broad public location and exact operational location must not be represented as one value that the UI merely truncates. They should be distinct fields or records with independent policies.

The one-time proposal model includes:

- country and administrative region;
- municipality and/or postal code;
- optional approximate PostGIS point for future search;
- a public display label;
- exact meeting details in a separate protected record, visible publicly only when explicitly configured or through the creator/current-participant operation.

Continuous location tracking is not part of the product foundation.

## Proposal lifecycle

The product document establishes the following general flow:

1. a user creates a proposal from scratch or from a reusable template;
2. the proposal becomes discoverable after publication;
3. users request to participate;
4. matching may notify users whose competences are relevant;
5. the proposal owner reviews participation requests;
6. accepted users become members;
7. the first accepted join request transactionally activates the canonical project group chat;
8. participants coordinate and may share an external meeting link;
9. a completed proposal can contribute to templates and aggregate community information.

The exact state machine is a product decision to be formalized before feature implementation. Likely states include draft, published/open, active, completed, cancelled, and moderated/hidden, but these names must not be treated as final until an implementation plan records them.

### Required lifecycle properties

Regardless of final state names:

- transitions must be explicit and validated;
- terminal and reversible states must be distinguished;
- ownership changes, if allowed, must be explicit;
- repeated commands must not duplicate members, chats, notifications, or statistics;
- membership/history records must preserve enough information for derived stats and moderation;
- deleting or suspending an account must not corrupt historical proposals;
- templates must copy approved reusable fields rather than stay invisibly coupled to mutable source content.

### Participation and automatic chat

The first successful `accept_project_join_request` inserts canonical membership and transactionally ensures exactly one Project group-chat anchor. Creator plus first participant is sufficient; there is no fixed threshold or user-facing Create Chat action. Project completion and membership termination do not delete the anchor.

Current/send entitlement derives from ownership or a current membership. Former participants retain historical entitlement for their exact accepted membership intervals, and rejoins remain separate intervals. Blocking, suspension, and moderation overrides remain Plan 09. Any future participation threshold for another business rule must not be reused as the chat rule.

### Participation-aware mobile Browse

Authenticated mobile Proposal and Tavolo Browse compose two independent reads:
the unchanged cursor-paginated public feed and an expected-identity-bound,
requester-only projection of current pending requests that still meet the same
public lifecycle and filter rules. Requested cards are rendered first and
deduplicated visually, while the raw public pages remain the sole source of
cursors and `hasMore`. A private projection failure degrades to the public feed;
identity/filter revisions prevent stale cards from crossing sessions or filters.
The projection contains only sanitized public card fields plus request ID/time,
never request messages or exact meeting data. Signed-out mobile discovery and
the public Next.js experience remain unpersonalized.

## Matching

Initial matching should be deterministic and explainable:

- users select competences/interests from a controlled taxonomy;
- proposals mark competences as useful or required;
- matching compares those relationships plus notification preferences and broad geographic eligibility;
- users can understand why they received a suggestion.

Do not begin with AI matching. More advanced ranking can be added after there is enough real data to identify failures in exact/tag-based matching.

## Notifications

Notifications are a centralized domain, not custom preference logic embedded in every feature.

### Canonical parts

- controlled notification categories and default channel settings;
- sparse per-profile category overrides, with absent rows inheriting catalog defaults;
- recipient-owned semantic in-app notification records and read timestamps;
- private outbox events plus generic per-consumer receipts;
- structured semantic targets that clients map to workflow items or routes without storing client URLs;
- private app-installation registrations and recipient-level push delivery jobs;
- private per-installation delivery targets, expiring leases, append-only attempts, and aggregate completion timestamps.

Notification projection owns the six participation events emitted by the shared
project-participation domain and `project.chat_message_sent`. Service-only,
concurrency-safe projectors lock available source events with `SKIP LOCKED`,
revalidate canonical state, apply each recipient's effective channel preference,
and record stable consumer receipts only after a complete event fan-out.
Notification/job uniqueness and the receipt together make retries idempotent. The
outbox `published_at` field is not a consumer acknowledgement: notification
processing must not prevent future analytics or other independent consumers from
observing the same event.

Chat-message projection cross-checks the payload's Project kind/ID, chat, message,
and sender against canonical rows. Recipients are the creator plus accepted
memberships whose half-open interval contains `project_chat_messages.created_at`,
with the sender excluded and duplicate identities collapsed. One event may
therefore create zero, one, or many in-app notifications and push jobs. A late join
does not receive an earlier alert, a leave/removal ends future targeting, and a
rejoin restores targeting for later messages. Existing chat events are receipted at
06D rollout without retroactive delivery.

Notification rows contain kinds and identifiers, not canonical English copy. The
authenticated inbox resolves only safe current project title/kind and workflow-authorized
actor display name. It never returns source JSON, join-request messages, exact meeting
information, email, tokens, or audit metadata. The authenticated Flutter client
provides the identity-bound in-app inbox, unread badge/read actions, semantic
navigation, and Participation/Chat in-app preferences over those narrow routines.
The same private resolver now supplies those validated semantic facts to both
`notifications.v1` and `push.v1`. The push projector independently applies only
`push_enabled`, writes one private recipient-level job, and records its own receipt;
it does not depend on a `public.notifications` row or active installation. Private
installation registrations are expected-identity-bound, use opaque installation
UUIDs, and never expose provider tokens to ordinary clients. Historical supported
events are receipted for `push.v1` at rollout so they are not delivered later.

The 06C2A protocol fans each available job out once to the recipient's then-active
installations. Later registrations do not receive that historical event. A trusted
worker claims pending targets with `SKIP LOCKED`, receives a short expiring lease and
the current private token generation, and atomically creates an attempt. Delivery
results must match the current unexpired lease and claimed generation. Delivered,
invalid-token, permanent-failure, and no-longer-registered outcomes are terminal;
transient failures return to a bounded future schedule. Expired work is reclaimable
under a new lease, stale responses fail, and the job completes once all targets are
terminal or immediately as `no_targets`. Invalid-token cleanup disables an
installation only when its current owner and token generation still match. These
routines live in the unexposed `private` schema, are executable only by direct-
database `service_role`, and grant no worker table access.

Notification rows and push jobs carry nullable `chat_id`/`message_id` semantic
references for the `project_chat` destination. The inbox and trusted claim contract
return those identifiers but no message body. Flutter renders generic safe chat copy
from actor/Project display context and routes to `/messages/chats/:chatId`; the Push
control remains hidden.

Firebase mobile registration, push permission timing and UI, server-side provider
credentials, OAuth/FCM sends, safe provider previews, environment safeguards, and
the repository-owned runnable adapter remain 06C2B work. Matching/resource and
additional chat notification kinds remain later work.

The request received, withdrawn, accepted, and rejected notifications retain the
canonical `request_id` and use the `participation_request` destination. That target is
the backend-route-agnostic bridge to the persistent actionable item in Messages;
the notification remains an alert and never owns Accept/Reject. `participant_left`
targets the creator's `project_participation` overview, while `participant_removed`
targets `project_detail`. The current Participation screen remains the creator's
secondary overview/history surface rather than the primary arrival point for a new
request.

### Initial channels

- **In-app:** canonical ordinary notification experience.
- **Push:** join requests, decisions, important proposal activity, and selected matching/chat events according to preferences.
- **Email:** authentication, security, and exceptional account communication.

A failed push does not remove the in-app notification or roll back the domain action.

## Messages and project chat

Messages will eventually provide an authenticated communication surface containing
both structured participation-request items and project group conversations. A join
request item is backed directly by `project_join_requests`, may show its private
requester message to the authorized creator, and reflects canonical request state.
Accept/Reject continues to call the participation transition functions; the item is
not copied into a free-form chat message.

The 07B1 Project-chat foundation now provides:

- one structural conversation anchor per Project after first acceptance;
- creator, current-member, and former-member entitlement derived from canonical history;
- exact half-open membership intervals for future time-authorized reads;
- retention across leave, removal, rejoin gaps, Project completion, and Tavolo pause/end;
- no chat-participant mirror, copied meeting details, message state, or transport.

07B2B owns server-readable message persistence, paginated authorized history,
chat-list summaries, and private identifier-only Realtime hints under the
approved full-history rule. Merged 07B2C owns the mobile group chat/info
experience and meeting-link access through the existing protected operation.
06D projects safe body-free Project-chat alerts into the notification and push
backbones. General direct
messages, independent group creation, calls, voice messages, typing indicators,
reactions, and complex read receipts remain excluded. Plan 09 may later
override ordinary entitlement for blocking, suspension, or moderation; clients
must not invent those rules.

## Media and storage

Media should be divided by purpose and access policy rather than stored in one unrestricted bucket.

The production object store is intentionally unresolved. Plan 08 must evaluate at least self-hosted Supabase Storage and an external object store such as Cloudflare R2, including bandwidth and storage cost, privacy/access control, backup coverage, migration complexity, and operating burden. Until that decision is accepted, clients and domain rules must not treat a Supabase Cloud Storage URL or dashboard-configured bucket as the permanent authorization boundary.

Expected categories include:

- public proposal media;
- private/restricted profile media;
- private proposal or meeting media;
- moderation evidence.

Required controls include:

- MIME and size restrictions;
- authenticated authorization for private objects;
- short-lived access where appropriate;
- deletion/cleanup when owning records are removed;
- metadata removal where location leakage is possible;
- moderation/publication status for user-generated public media.

The database stores canonical media metadata and authorization context. A storage URL alone is not authorization.

## Templates and community data

A template should be an explicit reusable representation, not simply “load the old proposal and mutate it.” This permits:

- stable attribution to a source proposal;
- removal of private or event-specific details;
- moderation before community publication;
- versioning or deprecation later;
- analytics on template reuse.

Community statistics should be derived from canonical records through SQL views initially. Examples may include counts by category, broad location, time, completion state, and participation. Materialized views or cached aggregates are deferred until measured performance requires them.

## Administration and moderation

Administrative tools are separate from normal user flows but use the same canonical backend.

The minimum moderation backbone before public user-generated content should include:

- reporting of users, proposals, messages, and supported media;
- user blocking;
- content visibility/moderation states;
- moderation queue and filters;
- administrator roles and least-privilege policies;
- action reasons and internal notes;
- auditable administrative actions;
- account suspension/restriction;
- support contact and community rules;
- account deletion and data cleanup/anonymization workflow.

Codex can build this machinery, but founders must define prohibited content, escalation, appeals, retention, minimum age, and response expectations.

Direct database editing through Supabase Studio is acceptable for development. It is not the long-term moderation interface and should not be required for routine production operations.

## Security baseline

Every implementation plan must consider:

- RLS enabled and tested for every exposed table;
- service-role credentials restricted to trusted server environments;
- no production secrets in source control or client bundles;
- validation at server boundaries;
- rate limiting/abuse controls for exposed mutations;
- idempotency for retried operations;
- auditability for privileged actions;
- safe logging without message bodies, tokens, exact locations, or unnecessary personal data;
- controlled file access and cleanup;
- dependency and secret scanning;
- separate local, staging, and production resources;
- restoration procedures, not merely nominal backups.

Production clients must connect through explicit environment configuration. Before public release, the self-hosting/release work must define a backend endpoint and cutover strategy that does not accidentally strand installed mobile versions; the current client configuration system is not redesigned by this architecture change.

Security-sensitive defaults should fail closed. A missing policy must not silently make data public.

## Reliability and test priorities

The first releases do not need distributed-system complexity, but they do need deterministic correctness.

Priority tests include:

- applying all migrations from an empty local database;
- constraints and state transitions;
- RLS matrices for anonymous users, ordinary users, proposal creators, members, blocked users, moderators, and service workers;
- idempotent acceptance/chat/notification operations;
- queue retry behavior with mocked external providers;
- public views excluding private columns;
- deletion/suspension effects;
- Flutter controller/repository behavior;
- critical public/admin browser journeys.

## Planned repository ownership

```text
apps/mobile/
  Flutter presentation and client-side application behavior

apps/site/
  Static public informational and launch website, one Cloudflare waitlist endpoint,
  and D1 migrations

apps/web/
  Next.js public discovery and authenticated admin interface

supabase/migrations/
  Canonical schema, constraints, indexes, functions, triggers, views, and RLS

supabase/functions/
  Server-only integrations and background workers

supabase/tests/
  pgTAP and integration tests for database behavior

docs/architecture/
  Accepted technical decisions and boundaries

docs/implementation/
  Ordered implementation work and status
```

The exact generated folders inside Flutter and Next.js were chosen by implementation plan 00. The informational site's restrained Vite structure is recorded in ADR 0004, and its isolated one-time waitlist boundary in ADR 0005.

## Initial non-goals

The foundation does not include:

- full desktop/web parity with the mobile app;
- microservices;
- production self-hosted infrastructure during feature plans or the main UI/UX pass; it belongs to the dedicated pre-release infrastructure phase;
- built-in video calling;
- direct messaging unrelated to proposals;
- full offline synchronization;
- AI matching or AI moderation;
- payment or donation processing;
- a visual map as a launch requirement;
- advanced search infrastructure;
- a general-purpose CMS;
- sophisticated gamification before canonical participation history exists.

These can be reconsidered through explicit architecture/product decisions when evidence supports them.
