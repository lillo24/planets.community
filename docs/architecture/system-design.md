# System Design and Responsibility Boundaries

**Status:** Initial accepted design  
**Implementation status:** Foundations, authentication, profiles, one-time proposals, Tavoli mobile/public-web discovery, shared project participation, notification projection, and structured participation-request Messages implemented

This document describes how the major parts of PLANETS should interact. Technology choices are recorded separately in [`core-stack.md`](core-stack.md).

## Product shape

PLANETS is primarily a mobile platform for local co-creation. Users discover or create proposals, contribute relevant competences/resources, request participation, coordinate after acceptance, and generate reusable community knowledge from completed work.

The initial system has three user-facing surfaces:

1. **Mobile application:** the full ordinary-user experience on Android and iOS.
2. **Public website:** information and selected public discovery without reproducing the whole app.
3. **Admin interface:** moderation and platform administration, isolated from normal user flows.

All surfaces use one canonical backend and data model.

## High-level structure

```text
Flutter mobile application             Next.js public/admin application
           |                                         |
           +--------------------+--------------------+
                                |
                         Supabase platform
        +-----------------------+------------------------+
        |                       |                        |
 Auth and RLS          PostgreSQL and PostGIS     Storage and Realtime
                                |
                  functions, outbox, and queues
                     |                         |
                   FCM                       Resend
                push delivery          auth/security email

             Sentry observes application failures
       PostHog later receives explicit product events
```

## Core responsibility rules

### Mobile client foundation

The Flutter process validates typed `local`, `staging`, or `production` compile-time configuration before initializing one Supabase client. Riverpod is the dependency/state boundary and `go_router` owns navigation. Optional Sentry monitoring wraps launch but cannot prevent the application from starting when monitoring itself fails. The public root does not require authentication. Mobile email-OTP request/verification, Supabase-derived session restoration, sign-out, and sanitized internal post-auth returns live in the Auth feature; magic-link/deep-link callbacks and social providers remain deferred.

Mobile source is organized by real feature ownership, supported by narrow shared `core` modules for configuration, backend access, routing, theme, monitoring, and common state UI. New layers or abstractions should appear only when a feature has concrete behavior to place in them.

### Web client foundation

The Next.js App Router separates public and admin routes with `(public)` and `(admin)` route groups while retaining one root layout. Pages and layouts remain Server Components unless an interaction or browser API requires a narrow Client Component boundary.

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

PostgreSQL is the canonical record for accounts, profiles, proposals, participation, messages, notification events, reports, and audit history.

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

### Shared project participation domain

`projects` is a private, narrow identity registry across `proposals` and `recurring_activities`. Its UUID equals the concrete activity UUID and it stores only kind, synchronized creator, and creation time. Source insert/delete triggers preserve the one-to-one invariant for migration replay and trusted fixtures; content, lifecycle, schedules, skills, and location remain solely in the concrete tables. A source with request or membership history cannot be deleted.

`project_join_requests` preserves each private `pending`, `accepted`, `rejected`, or `withdrawn` attempt and an optional trimmed 500-character requester message. A complete non-creator may request a published one-time project strictly before its end or a currently published Tavolo. There may be at most one pending attempt and no request while the person is a current member. Terminal attempts remain history, so withdrawal, rejection, voluntary leave, or creator removal permits a fresh request whenever eligibility returns.

`project_memberships` is acceptance history, not contribution proof. Acceptance atomically closes the request and creates one current membership; creator ownership is separate. Leave/removal ends a membership without deleting it, and pause/end/completion does not rewrite history. One current membership per project/profile is enforced centrally. Capacity, waitlists, participation roles, resources, badges, and creator-verified contribution remain deferred.

All mutations and private reads use expected-identity-bound project RPCs. Tables have RLS but no client grants/policies. Request messages are visible only to the requester and project creator; creator review exposes a narrow authenticated display identity but never Auth email. Protected meeting details are available only to the creator or a current accepted member. Each successful transition writes identifier-only audit/outbox events; `project.join_request_accepted` is a stable candidate input for Plan 07, but Plan 07 still owns the exact automatic-chat trigger and post-membership chat access rules.

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

## Main data domains

| Domain                  | Responsibility                                                                                              | Important relationships                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Authentication identity | Login identity, verified contact method, session                                                            | Linked one-to-one with an application profile                                             |
| Profiles                | Display identity, competences, interests, preferences, visibility settings                                  | User, skills, participation history, media                                                |
| Skills/competences      | Controlled taxonomy used by users and proposals                                                             | Many-to-many with profiles and proposal requirements                                      |
| One-time proposals      | Creator-owned content, schedule, rough/exact location separation, stored lifecycle, derived temporal status | Creator, controlled skill requirements, future participation, future template source      |
| Recurring activities    | Persistent Tavoli, versioned weekly/monthly schedules, bounded occurrences, rough/exact privacy, lifecycle  | Separate from one-time proposals; Flutter experience and public web discovery implemented |
| Participation           | Shared project identity, private requests/decisions, current membership and retained history                | Profile and concrete one-time/recurring project; source for authorization and later stats |
| Messages                | Authenticated structured participation-request inbox/detail; future project conversations                   | Canonical join requests now; separate project chat/message state in 07B                   |
| Project chat            | One project-scoped group conversation when its future trigger and access rules are defined                   | Project and authorized participants                                                       |
| Notifications           | Controlled categories/preferences and recipient in-app records; later device delivery                       | Recipient, per-consumer source event receipt, optional project/request/membership         |
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
7. the project group chat becomes available after the future Plan 07 trigger is satisfied;
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

Proposal/project chat will be created automatically by an idempotent backend operation and is not gated by a fixed threshold of three. There is no user-facing manual Create Chat action, and project completion does not delete chat or message history.

The participation foundation emits `project.join_request_accepted` as a stable candidate event without creating chat. Plan 07 must still finalize which participation event triggers automatic creation and authorization after a participant leaves, is removed, blocked, or suspended. Any future participation threshold for a different business rule must not be reused implicitly as the chat rule.

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
- later device tokens, platform metadata, delivery jobs/attempts, and delivery timestamps.

The first notification projection owns the six participation events emitted by the
shared project-participation domain. A service-only, concurrency-safe projector locks
available source events with `SKIP LOCKED`, resolves recipients from canonical request,
membership, and project rows, applies the recipient's effective in-app preference, and
records the stable `notifications.v1` consumer receipt. Notification uniqueness and
the receipt together make retries idempotent. The outbox `published_at` field is not a
consumer acknowledgement: notification processing must not prevent future chat,
analytics, or other independent consumers from observing the same event.

Notification rows contain kinds and identifiers, not canonical English copy. The
authenticated inbox resolves only safe current project title/kind and workflow-authorized
actor display name. It never returns source JSON, join-request messages, exact meeting
information, email, tokens, or audit metadata. The authenticated Flutter client
provides the identity-bound in-app inbox, unread badge/read actions, semantic
navigation, and Participation in-app preference over those narrow routines.
Device registration, push delivery, and matching/resource/chat notifications
remain later work.

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

Project group chat remains a distinct, intentionally narrow later domain:

- one conversation per eligible project;
- persisted text messages;
- paginated history;
- realtime updates;
- current-membership authorization;
- basic message/content reporting;
- push notifications with safe previews;
- optional external meeting URL.

Initially excluded:

- general direct messages;
- independent group creation;
- voice/video infrastructure;
- voice messages;
- typing indicators;
- reactions;
- end-to-end encryption;
- complex read-receipt state.

The system must define what happens when a participant leaves, is removed, is blocked, or is suspended. Historical access should not be guessed by the client.

## Media and storage

Media should be divided by purpose and access policy rather than stored in one unrestricted bucket.

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

apps/web/
  Next.js public site and authenticated admin interface

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

The exact generated folders inside Flutter and Next.js should be chosen by implementation plan 00 after the toolchains are initialized.

## Initial non-goals

The foundation does not include:

- full desktop/web parity with the mobile app;
- microservices;
- self-hosted infrastructure;
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
