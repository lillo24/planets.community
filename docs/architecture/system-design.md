# System Design and Responsibility Boundaries

**Status:** Initial accepted design  
**Implementation status:** Foundations, authentication, profiles, one-time proposals, Tavoli mobile/public-web discovery, shared project participation, Project delegates and manager authorization, request contribution selections, membership commitments, join-acceptance contribution triage, participation-request private chat domain, in-app notification projection, unified structured Project/Resource Requests in mobile Messages, mobile Resource request actions, Project group-chat lifecycle/durable message/mobile experience, Project-chat notification/push projection, the provider-independent push/job foundation, provider-neutral push delivery worker protocol, and the static-first informational site with its local/CI one-time waitlist boundary and native Workers runtime implemented or in focused review

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

`resource_listing_requests` adds a separate private expression-of-interest lifecycle with `pending`, `accepted`, `rejected`, `withdrawn`, and `listing_closed` states. A requester/listing pair has at most one active pending request or accepted request whose later coordination remains open, while closed coordination and other terminal attempts remain independent history. Multiple accepted requesters are valid because request acceptance means willingness to coordinate, not reservation, agreement completion, handoff, or transfer. All mutations and private reads cross expected-identity RPC boundaries; the table has RLS without direct client policies or grants. Listing-first locks serialize creation and close, and listing-then-request locks serialize owner decisions with requester withdrawal. Public listing reads expose only the derived pending-plus-coordination-open-accepted count. Identifier-only request events deliberately precede any later Messages, conversation, or notification projection.

Every accepted request atomically owns one private `resource_exchange_agreements` anchor. Its separate `negotiating`/`agreed`/`in_progress`/`completed`/`cancelled` lifecycle preserves the accepted request decision while completion or cancellation closes that request's active coordination episode. Immutable terms versions model a required owner `give`/`lend` leg plus an optional requester `none`/`give`/`lend` leg, with bounded loan periods, server-snapshotted listing title/description, and CAS-controlled current/pending pointers. Either counterparty may propose; only the other may accept or reject, while the proposer may withdraw. The first actor-authorized structured resource milestone freezes terms. Give legs require provider and recipient statements; lend legs additionally require returned and return-received statements. The final required statement completes atomically. Cancellation is available only before the first milestone. Listing closure still affects pending requests only and does not destroy accepted private coordination.

Agreement anchors, terms, and timelines use RLS with no direct client policies or grants; hardened counterparty RPCs are the only boundary. Timeline and outbox/audit records are structured and identifier-only, while terms text, notes, loan dates, contact data, and exact locations remain private or absent. Authorized reads derive overdue return indicators from current lend terms without timers or events. One listing is one reservable lending unit: its owner-side current accepted LEND period in an agreed/in-progress agreement is the canonical half-open reservation. Listing-row serialization rejects overlapping acceptance with PT409; cancellation/completion release automatically, while listing closure does not. The owner-only chronological schedule derives overdue and later-reservation at-risk flags at read time, and counterparties can check only an exact pending version's availability. This is not FIFO, a public calendar, or a reservation ledger; requester-side free-text items are not globally reserved. Recurring availability, multi-unit capacity, automatic promotion, and post-handoff amendments remain deferred. Milestone statements record who asserted what and when; they are not independent PLANETS verification, legal judgment, liability, insurance, or reputation evidence. Disputes, matching, and further notifications remain separate future domains.

Every accepted request also atomically owns one `resource_request_chats` anchor and one immutable, human-only `resource_request_chat_messages` history. Listing owner and requester keep permanent read entitlement; both may send only while the accepted agreement coordination episode remains open. Completion or cancellation makes the chat read-only without deleting it, and listing closure does not affect an already accepted open chat. A later request episode receives a distinct chat. RPC-only exact/history/list/send boundaries provide honest human previews and activity ordered by activation, latest human message, or latest structured agreement event. Sends lock the same agreement row as completion/cancellation. Private per-profile `resource-chat:<chatId>:profile:<profileId>` Broadcast topics remain readable to the two historical counterparties so the final close refresh arrives, while send authorization remains separate. Human-message and agreement-change hints plus message audit/outbox events contain identifiers only; durable PostgreSQL state is authoritative and structured agreement events never become fake chat messages.

The 04C2 Flutter client keeps Scambio-Dona in the Home pillar beside Progetti,
without changing the persistent Profile / Browse / Home navigation. Its public
list and detail are signed-out, while My Listings and create/edit routes require
a complete profile and preserve their Auth/setup return destination. The client
uses only the canonical listing RPCs; closing remains availability-only. The
04C4C3A Flutter slice renders the public derived active-interest count, keeps
requester history in identity-bound memory, and exposes canonical
Request/Withdraw and owner Accept/Reject actions through only the 04C4A RPCs.
It also consumes the 04C4C2 unified structured Requests projection. Agreement
negotiation/milestones, Resource conversation/Realtime, and Resource-specific
notification UX remain in 04C4C3C, 04C4C3B, and 04C4C3D respectively.

### Project resource-need domain

`project_resource_needs` attaches stable plain-text needs to the shared `projects` identity for both Proposals and Tavoli. A need is separate from participation, a join request, a contribution offer, and a standalone Scambio-Dona listing. It stores only a UUID, Project UUID, trimmed title, optional trimmed details, `open`/terminal `closed` state, and server-owned timestamps. Closure means the Project is no longer asking; it does not assert fulfillment, supply, delivery, verification, or credit.

Expected-identity-bound creator RPCs create, update, and close needs only while the concrete Project remains owner-manageable. They lock the concrete Proposal/Tavolo row before the shared Project and need rows, so lifecycle transitions serialize deterministically. Proposal management follows its existing draft/pre-start edit boundary; Tavolo management permits draft, published, and paused states but not ended state. Creators retain ordered open/closed history after mutation closes.

Anonymous and authenticated public reads expose only open needs while the concrete Project is currently joinable: published before `ends_at` for a Proposal and currently published for a Tavolo. Draft, cancelled, expired, paused, ended, and missing Projects return the same empty shape. The table has RLS with no client policies or direct grants; hardened RPCs are the only client boundary. Events contain only Project kind/ID, need ID, and creator ID. Taxonomy, quantities, prices, priorities, Scambio-Dona matching, accepted commitments, and notifications remain absent until focused later slices.

### Shared project participation domain

`projects` is a private, narrow identity registry across `proposals` and `recurring_activities`. Its UUID equals the concrete activity UUID and it stores only kind, synchronized creator, and creation time. Source insert/delete triggers preserve the one-to-one invariant for migration replay and trusted fixtures; content, lifecycle, schedules, skills, and location remain solely in the concrete tables. A source with request or membership history cannot be deleted.

`project_delegates` adds append-preserved co-organizer relationships without changing ownership or creating participant memberships. The immutable Project creator remains the sole owner and controls delegate invitations, revocation, core Project authoring, and lifecycle. An active delegate is a current Project manager for participation review, requester conversations, member commitment and ended-Proposal attribution operations, protected meeting data, group chat, and operational Needs coverage. Revocation immediately removes manager-only authorization and retained chat history; any independently held participant membership continues under the ordinary membership rules.

Delegate grants use seven-day, single-use, 256-bit bearer invitations. `project_delegate_invitations` stores only a SHA-256 digest and lifecycle metadata; plaintext is returned once by the owner-only creation RPC and is excluded from audit/outbox data and owner reads. Preview is non-mutating and returns one indistinguishable unavailable shape for malformed, unknown, consumed, revoked, expired, or non-operational invitations. Explicit authenticated acceptance serializes on the concrete Project, shared Project, and invitation, permits a lost-response retry only for the successful accepter, and never trusts a client-supplied Project or owner identity. New grants are allowed for published Proposals strictly before `ends_at`, and for published or paused Tavoli; draft, cancelled, ended, and elapsed Projects fail closed.

Mobile and web share `https://planets.community/invite/project/<token>` as the
canonical invitation route. The website remains a complete fallback and only
an explicit authenticated client action accepts. Flutter resolves exact
current-user owner/delegate/none state before showing participation actions,
uses one Manage project hub for manager operations, and lists active delegated
Projects separately from owned Projects. Android/iOS claim only the invite path
when their production app identities are associated; website association
endpoints fail closed until those external signing identifiers are configured.

`project_join_requests` preserves each private `pending`, `accepted`, `rejected`, or `withdrawn` attempt and an optional trimmed 500-character requester message. Optional child rows retain canonical skill and resource-need IDs selected for that exact attempt. Proposal selections must be current `required` or `useful` skills; Tavolo skill arrays are empty-only because no canonical recurring skill-requirement relation exists. Resource selections must be open and belong to the same Project. Request, child rows, and the unchanged identifier-only event commit atomically under concrete Project → shared Project → ordered resource-need locks.

A requester or current Project manager can resolve the historical IDs to current canonical skill labels and need titles through one narrow expected-identity RPC; no selection table is client-readable. Withdrawal, rejection, acceptance, later requirement removal, need renaming, and need closure preserve the rows. A complete non-owner may request a published one-time project strictly before its end or a currently published Tavolo. There may be at most one pending attempt and no request while the person is a current member. Terminal attempts remain history, so withdrawal, rejection, voluntary leave, or manager removal permits a fresh request with an independent selection set whenever eligibility returns.

`project_join_request_skill_acceptance_decisions` and `project_join_request_resource_acceptance_decisions` preserve the accepting manager's immutable classification of every selected offer as `needed`, `already_found`, or `extra`. Triaged acceptance requires an exact partition. `needed` must still be a current Proposal requirement or open same-Project resource at the serialized boundary; historical removed/closed selections may remain `extra` or `already_found`. A two-argument compatibility call accepts only requests with zero selections. Decisions, request resolution, membership insertion, chat activation, and the existing identifier-only event commit atomically. Legacy creator-named acceptance calls remain owner-only compatibility boundaries; delegate-capable clients use manager-named RPCs and expected-manager parameters.

`project_memberships` is acceptance history, not contribution proof or mutable availability. Acceptance atomically closes the request and creates one current membership; its trigger fails closed on incomplete selected-request decisions and seeds the membership's mutable current commitments only from `needed` and `extra`. `already_found` remains historical without seeding a commitment. Leave/removal ends a membership without deleting it, and pause/end/completion does not rewrite selection, decision, or commitment history. One current membership per project/profile is enforced centrally. A rejoin owns independent decisions and commitments.

Request selection (what was offered), acceptance decision (what the manager decided at that acceptance), current commitment (the mutable membership expectation), live Project requirement coverage (current participant/manual sources), and final actual contribution are five separate concepts. None alone proves delivery or rates the person. D3A keeps coverage separate from the requirement `open`/`closed` lifecycle and exposes it only through expected-identity-bound participant claims, manager-manual coverage, and current manager/member reads; D3B owns chat coordination and resurfacing, while one-time final attribution remains 05C.

All mutations and private reads use expected-identity-bound project RPCs. Tables have RLS but no client grants/policies. Request messages are visible only to the requester and current Project managers; manager review exposes a narrow authenticated display identity but never Auth email. Protected meeting details are available only to a current manager or current accepted member. Each successful transition writes identifier-only audit/outbox events; acceptance adds no disposition arrays, labels, or message text, while exact live-source transitions add only Project/requirement/actor and optional membership identifiers. In 07B1, insertion of the canonical accepted membership also ensures the one Project group-chat anchor transactionally; it does not consume or repurpose the accepted outbox event.

### Unified structured-request Messages

The authenticated mobile Requests tab is a discriminated projection of
canonical `project_join_requests` and `resource_listing_requests`, not a second
message or request-copy store. Narrow expected-identity-bound unified list and
exact RPCs return an item only to its requester or concrete Project
creator/Resource owner, including the authorized private message, display
identities, state, domain context, and activity chronology. Missing and
unauthorized exact IDs fail identically.

The inbox uses bounded `(activity_at, item_kind, request_id)` keyset pagination
and the same composite identity for client deduplication. The centralized sealed
model/parser rejects unknown discriminators, invalid viewer roles, and mixed
Project/Resource payload shapes. This boundary may later gain explicit Group or
invitation variants without spreading kind checks through unrelated routes; no
Group or invitation feature is implemented.

Project creators retain the existing 05A/04C3D2 actions. Resource owners may
Accept/Reject and Resource requesters may Withdraw through the 04C4A boundary;
each mutation reloads canonical detail and affected projections. Resolved items
remain read-only history. `/messages`, `/messages/requests/:requestId`, and
`/messages/requests/resource/:requestId` belong to Home and require a complete
authenticated profile. The Chats tab remains Project-only until 04C4C3B.

### Participation-request private conversation domain

Every `project_join_requests` episode owns one permanent private
`project_join_request_chats` anchor from request creation, including historical
rows backfilled at their canonical `created_at`. The optional 500-character
request note remains the structured Request feed item; it is never copied into
`project_join_request_chat_messages`. Human follow-ups are immutable,
canonically trimmed plain text of 1 through 4,000 Unicode characters with a
server-owned timestamp. Both tables use restrictive foreign keys, RLS without
client policies, and no direct client or broad service-role privileges.

Only the requester and a current Project manager can resolve the exact
conversation, page its strict Request/message feed, or receive its private
`project-request-chat:<chat-id>:profile:<profile-id>` Broadcast hints. Sending is
available only while the canonical request is pending. It takes the established
concrete-Project, shared-Project, then request-row locks, so accept, reject, and
withdraw races deterministically preserve a send serialized first and reject a
send serialized after resolution. Terminal episodes retain readable history;
accepted detail also exposes the separately authorized Project group-chat ID.

Durable audit/outbox event `project.join_request_chat_message_sent` and Realtime
hints contain identifiers/timestamps only. Existing notification/push
projectors deliberately ignore this new event until 07C1B owns its projection.
The existing unified Requests projection is unchanged, and
`list_own_message_chat_items` is intentionally unchanged; 07C1B owns the mobile
conversation UI and unified Chats inclusion.

### Project group-chat lifecycle and authorization foundation

`project_group_chats` is one private structural anchor per shared `projects` row.
The first accepted join request creates it inside the same transaction as the
canonical membership; later acceptances and rejoins conflict safely onto the
same chat. Existing membership history is reconciled from its earliest
`joined_at`. Project completion, Tavolo pause/end, and membership termination do
not delete the anchor.

Chat authorization derives from immutable Project ownership, active delegate
relationships, and append-preserved `project_memberships`; there is no chat-member
mirror. The owner and active delegates have current organizer entitlement. Current accepted participants
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

The owner, every active delegate, and every current accepted participant can read the complete durable
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

Coverage resurfacing extends that same private channel without weakening the
human message model. D3A's canonical transition transaction creates one
identifier-only immutable `project_chat_system_events` row only for
`project.requirement_needed_again` when the Project chat already exists, and
broadcasts both needed-again and covered refresh signals only to profiles with
current entitlement at the serialized transition. Covered transitions have no
durable system item. The mixed chat feed owns cross-kind keyset ordering and
applies the established creator/current/former history frontier while resolving
current requirement labels at read time.

Current creator/member attention is a separate durable cursor, not chat unread
or notification read state. The attention read combines system events after the
profile's explicit event-time/UUID frontier with current canonical truth: the
requirement must still exist, remain uncovered, and belong to an operational
Project. A monotonic acknowledgement through one loaded event cannot consume a
later transition serialized behind it. Former members retain authorized system
history but cannot read or mutate current coordination attention.

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

| Domain                     | Responsibility                                                                                                   | Important relationships                                                                                        |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Authentication identity    | Login identity, verified contact method, session                                                                 | Linked one-to-one with an application profile                                                                  |
| Profiles                   | Display identity, competences, interests, preferences, visibility settings                                       | User, skills, participation history, media                                                                     |
| Skills/competences         | Controlled taxonomy used by users and proposals                                                                  | Many-to-many with profiles and proposal requirements                                                           |
| One-time proposals         | Creator-owned content, schedule, rough/exact location separation, stored lifecycle, derived temporal status      | Creator, controlled skill requirements, future participation, future template source                           |
| Recurring activities       | Persistent Tavoli, versioned weekly/monthly schedules, bounded occurrences, rough/exact privacy, lifecycle       | Separate from one-time proposals; Flutter experience and public web discovery implemented                      |
| Resource listings          | Standalone Scambio-Dona lifecycle, rough-location discovery, sanitized detail, and derived active-interest count | Profile owner plus separate private Resource request episodes; no Project, taxonomy, media, or handoff linkage |
| Resource request chat      | Accepted-request human history, authorized summaries/send, and private Realtime refresh hints                    | One request/agreement episode; permanent owner/requester read and open-coordination send                       |
| Participation              | Shared project identity, private requests/decisions, current membership and retained history                     | Profile and concrete one-time/recurring project; source for authorization and later stats                      |
| Project delegates          | Owner-issued single-use invitations and current manager authorization                                             | Shared Project identity; separate from immutable ownership and participation membership                       |
| Participation request chat | Pending-request human history, structured request-note feed, exact authorized state, and private Realtime hints  | One join-request episode; permanent requester/current-manager read and pending-only send                       |
| Messages                   | Authenticated discriminated Project/Resource Requests plus the existing Project-only Chats tab                   | Canonical request domains; complete three-part cursor; Resource chats remain 04C4C3B                           |
| Project chat               | Structural anchor, immutable message history, authorized list/send APIs, and private Realtime hints              | Owner/active delegates plus current/former participants under canonical membership-time rules                  |
| Notifications              | Controlled categories/preferences, recipient in-app records, private installations, and recipient push jobs      | Recipient, per-consumer source event receipt, optional project/request/membership                              |
| Templates                  | Reusable proposal structure derived from approved past/community content                                         | Source proposal, attribution, moderation/publication state                                                     |
| Community statistics       | Aggregated views over canonical activity and participation                                                       | Proposal type, location, participation, time                                                                   |
| Moderation                 | Reports, blocks, content status, actions, internal notes, appeals if introduced                                  | Users, proposals, messages, media, administrators                                                              |
| Audit/operations           | Security-relevant and administrative action history                                                              | Actor, target, action, timestamps, metadata                                                                    |

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
3. users request to participate and that request episode gains a private requester/organizer conversation;
4. matching may notify users whose competences are relevant;
5. a current Project manager reviews participation requests while either counterparty may follow up until resolution;
6. accepted users become members and the request conversation becomes read-only;
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
requester message to an authorized current manager, and reflects canonical request state.
Accept/Reject continues to call the participation transition functions; the item is
not copied into a free-form chat message.

07C1A adds one private requester/organizer conversation per participation-request
episode at request creation. Its feed keeps that canonical Request item distinct
from later human messages, allows both counterparties to send only while pending,
and retains read-only history after accept/reject/withdraw. Acceptance links to,
but never merges with, the separate Project group chat. The backend contract is
implemented; 07C1B owns mobile routes, rendering, live refresh, unified Chats
projection, and any notification/push consumption.

The 07B1 Project-chat foundation now provides:

- one structural conversation anchor per Project after first acceptance;
- owner, active-delegate, current-member, and former-member entitlement derived from canonical history;
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
