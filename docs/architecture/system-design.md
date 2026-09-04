# System Design and Responsibility Boundaries

**Status:** Initial accepted design  
**Implementation status:** Foundations, authentication, profiles, and one-time proposals implemented; recurring-activity domain foundation in progress

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
- when a proposal chat exists;
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

`proposal_meeting_details` physically separates exact meeting text/coordinates from the rough public location. Public list payloads never include exact meeting data. Exact-ID public detail returns exact meeting text only for `public` visibility; `participants` visibility returns no protected value and an explicit restricted flag. Plan 05 may add a participant-authorized boundary without weakening this anonymous contract. `proposal_skills` reuses the controlled 03C catalog with `required` or `useful` meaning; no second or free-form taxonomy exists.

Complete-profile creators manage proposals only through expected-identity-bound `create_proposal_draft`, `update_own_proposal`, `publish_proposal`, and `cancel_proposal` operations. Public clients use sanitized `list_public_proposals` and `get_public_proposal`; owners use separate complete owner reads. Published content freezes when an activity starts, cancellation is terminal and permitted only before its end, and publish/cancel record content-free audit/outbox identifiers without delivering notifications.

`private.audit_events` stores append-oriented operational and security history, not product analytics. `private.outbox_events` stores transaction-local handoff records for later asynchronous work; it is not itself a queue or delivery implementation. Both remain outside the Data API with no direct client grants. Future domain operations can write them within the same transaction, while queue consumption and delivery remain owned by plan 06.

### Recurring activity domain

`recurring_activities` stores persistent creator-owned Tavoli separately from one-time proposals. Its explicit lifecycle is `draft`, `published`, `paused`, or `ended`; clock time never completes a series. Published Tavoli remain open-ended until paused or ended, paused series retain their content/history without active discovery occurrences, and ended series are terminal historical records.

`recurring_activity_schedules` stores non-overlapping versioned weekly or monthly rules as local wall-clock time plus a recognized IANA time zone. Weekly recurrence has one ISO weekday; monthly recurrence has one day from 1 through 28. A future schedule change closes the prior version at an exclusive local-date boundary and inserts a new version, so past meetings are never reinterpreted. Before that new version becomes effective, it may be corrected in place at the same boundary without creating redundant history or changing the already-effective row. Canonical helpers derive only bounded windows and calculate each UTC instant from its local date/time and zone, preserving the intended local time across daylight-saving changes.

`recurring_activity_meeting_details` physically separates exact meeting text/coordinates from structured rough public location. Anonymous discovery uses narrow list/detail operations: normal list includes only published series and requires callers to reuse one explicit reference-time snapshot across cursor pages, while exact-ID detail may retain published, paused, or ended history. Participant-restricted exact data is absent from public payloads; participant-authorized access remains plan 05 work.

Complete-profile creators use expected-identity-bound create/publish/resume operations; all owner mutations reject stale account-switch forms before changing data. Publication, schedule changes, pause, resume, and end record content-free audit/outbox metadata without implementing notification delivery. 04B1 intentionally exposes no Tavoli mobile or web UI; 04B2 owns those client experiences.

### Clients use shared operations rather than duplicate workflows

Safe simple reads may query authorized views/tables directly. Multi-step or security-sensitive changes should use named backend operations, for example:

- `publish_proposal`
- `request_to_join_proposal`
- `withdraw_join_request`
- `accept_join_request`
- `reject_join_request`
- `leave_proposal`
- `cancel_proposal`
- `complete_proposal`
- `block_user`
- `report_content`
- `delete_account`

The remaining names and signatures will be defined during their schema plans. One-time proposal operations are now concrete as described above. The key rule is that Flutter and Next.js must call the same canonical transition rather than reproduce its steps independently.

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

| Domain                  | Responsibility                                                                                              | Important relationships                                                              |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Authentication identity | Login identity, verified contact method, session                                                            | Linked one-to-one with an application profile                                        |
| Profiles                | Display identity, competences, interests, preferences, visibility settings                                  | User, skills, participation history, media                                           |
| Skills/competences      | Controlled taxonomy used by users and proposals                                                             | Many-to-many with profiles and proposal requirements                                 |
| One-time proposals      | Creator-owned content, schedule, rough/exact location separation, stored lifecycle, derived temporal status | Creator, controlled skill requirements, future participation, future template source |
| Recurring activities    | Persistent Tavoli, versioned weekly/monthly schedules, bounded occurrences, rough/exact privacy, lifecycle  | Separate from one-time proposals; UI deferred to 04B2                                |
| Participation           | Requests, decisions, membership, roles, history                                                             | User and proposal; source for stats and authorization                                |
| Chat                    | One proposal-scoped conversation when eligible                                                              | Proposal and current authorized members                                              |
| Messages                | Persisted communication within a proposal chat                                                              | Chat, sender, moderation/deletion state                                              |
| Notifications           | In-app records, preferences, device tokens, delivery attempts                                               | Recipient, source event, optional proposal/request/message                           |
| Templates               | Reusable proposal structure derived from approved past/community content                                    | Source proposal, attribution, moderation/publication state                           |
| Community statistics    | Aggregated views over canonical activity and participation                                                  | Proposal type, location, participation, time                                         |
| Moderation              | Reports, blocks, content status, actions, internal notes, appeals if introduced                             | Users, proposals, messages, media, administrators                                    |
| Audit/operations        | Security-relevant and administrative action history                                                         | Actor, target, action, timestamps, metadata                                          |

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
- exact meeting details in a separate protected record, visible publicly only when explicitly configured; participant access is deferred to plan 05.

Continuous location tracking is not part of the product foundation.

## Proposal lifecycle

The product document establishes the following general flow:

1. a user creates a proposal from scratch or from a reusable template;
2. the proposal becomes discoverable after publication;
3. users request to participate;
4. matching may notify users whose competences are relevant;
5. the proposal owner reviews participation requests;
6. accepted users become members;
7. the proposal-specific chat becomes available after its participation condition is met;
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

Plans 05/07 must still define the exact participation event that triggers automatic creation and authorization after a participant leaves, is removed, blocked, or suspended. Any future participation threshold for a different business rule must not be reused implicitly as the chat rule.

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

- notification categories;
- per-user preferences;
- in-app notification records;
- device tokens and platform metadata;
- outbox events;
- delivery jobs/attempts;
- idempotency keys;
- deep-link target data;
- delivery and read timestamps.

### Initial channels

- **In-app:** canonical ordinary notification experience.
- **Push:** join requests, decisions, important proposal activity, and selected matching/chat events according to preferences.
- **Email:** authentication, security, and exceptional account communication.

A failed push does not remove the in-app notification or roll back the domain action.

## Proposal chat

Chat is intentionally narrow:

- one conversation per eligible proposal;
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
