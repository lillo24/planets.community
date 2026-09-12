# Database development

PostgreSQL is the canonical PLANETS product record. This guide owns the local schema-change, security-test, and generated-type workflow. The current schema includes application identity, basic profiles, a controlled starter skill catalog, field visibility, one-time proposals, the Tavoli recurring-activity domain, shared project participation and structured Messages reads, the in-app notification domain, the provider-independent push installation/delivery-job foundation, and private audit/outbox primitives.

## Source of truth and daily workflow

Timestamped SQL files under `supabase/migrations/` are the only canonical schema history. PLANETS does not maintain a parallel `supabase/schemas/` declarative representation.

Start the local stack, generate a migration with the project-scoped CLI, edit the generated SQL, and replay the complete history:

```text
npm run db:start
npx supabase migration new concise_change_name
npm run db:reset
```

Never rewrite a migration that a shared environment may have applied; add a later migration. `npm run db:reset` is destructive only to the local database selected by the explicit `--local` script flag. It applies all migrations in timestamp order and then runs `supabase/seed.sql`.

The seed file is for deterministic development/test rows without real personal data. Keep schema, grants, policies, functions, extensions, and system-managed reference data in migrations rather than seeds. It currently seeds nothing; the starter skill catalog is canonical migration data.

Later migrations should use lowercase `snake_case`, UUID primary keys for ordinary application entities unless a stronger reason exists, and the relevant `auth.users.id` for an auth-linked entity when appropriate. Timestamps use `timestamptz`; `created_at` is normally non-null with a database default, while `updated_at` is added only when useful and must be maintained server-side. Express enforceable invariants as constraints and choose each foreign key's delete behavior deliberately rather than defaulting mechanically to cascade.

There is no universal soft-delete or content-state convention. Deletion, anonymization, historical retention, and moderation state have product and legal consequences and belong to their later plans.

## Identity and shared operational primitives

Supabase Auth owns login identity in `auth.users`. `public.profiles` is the one-to-one PLANETS application identity anchor and reuses that Auth UUID as its primary key. It stores a required-on-completion display name, optional bio, and database-maintained timestamps. Completion is derived from a non-null validated display name; there is no completion flag. There is no automatic Auth signup trigger, so an Auth user without an application profile is valid until an authenticated application flow explicitly creates the anchor.

Authenticated users can insert and read only their own anchor, update only their own display name and bio, and manage only their own controlled skills and visibility rows under RLS. Catalog categories and skills are public read-only reference data. `anon` receives no direct profile grant. The exact-ID `get_public_profile(uuid)` function is the only anonymous profile boundary and returns only visibility-sanitized fields for completed profiles. `update_own_profile(...)` is the shared atomic write path for both clients; it requires the profile ID for which the form was rendered and rejects the request before mutation if that ID differs from the current `auth.uid()`.

Each new anchor receives exactly three public visibility rows for `display_name`, `bio`, and `skills`. `skill_categories` and `skills` contain seven categories and a small deterministic starter catalog; users cannot invent or mutate catalog terms. Free-text skills, proficiency, photos, location, directory search, and organizer/participant audiences are not represented yet.

The profile and audit-actor foreign keys restrict raw deletion from `auth.users`. This intentional failure guard prevents application identity or audit history from being silently destroyed before plan 10 defines cleanup, anonymization, and lawful retention. Do not replace it with cascade or nulling as an incidental feature migration.

`private.audit_events` is append-oriented operational/security history rather than user analytics; generic metadata must avoid bodies, tokens, exact locations, and unnecessary personal data. `private.outbox_events` is a transaction-local handoff record whose UUID supplies a stable event identity. `available_at` controls when a worker may consider an event. The existing `published_at` is legacy/global dispatcher metadata, not a per-consumer acknowledgement. Independent consumers record success in `private.outbox_consumer_receipts` using `(outbox_event_id, consumer_key)`, so notification projection cannot hide an event from later chat or analytics consumers. These private tables have no direct client or broad service-role privileges and no Data API exposure.

## Public and private schemas

`public` is the PLANETS Data API schema. It remains listed in `[api].schemas` and is the only schema where later client-facing tables, views, or routines may be defined. Listing a schema makes it API-addressable; it does not grant object access by itself.

`private` owns non-API data and implementation details. It is deliberately absent from `[api].schemas`, and `anon`, `authenticated`, and `service_role` have neither `USAGE` nor `CREATE` on it. Do not grant `service_role` broad access as a convenience: it bypasses RLS, so any future access must be narrow, explicit, and justified by the owning plan.

PostGIS is installed into the existing non-API `extensions` schema. Qualify spatial types and functions as `extensions.geography`, `extensions.st_point`, and similar names in migrations and tests. One-time proposals reserve separate optional rough and exact geography points without implementing map input or geocoding; the exact point remains in the protected meeting record.

## One-time proposals

`public.proposals` stores creator, content, schedule, IANA event time zone, and structured rough location. `public.proposal_meeting_details` is a one-to-one protected record for exact meeting text/coordinates and `public.proposal_skills` relates the proposal to existing catalog skills as `required` or `useful`.

Only `draft`, `published`, and `cancelled` are stored. `private.derive_proposal_status` derives Upcoming before `starts_at`, Happening from start until end, Just Finished from the end until exactly 24 hours later, and Completed thereafter. Normal discovery includes the first three derived states, while exact-ID detail retains published historical proposals. Retention does not create a Community template or make completed content mutable.

Authenticated complete-profile owners call expected-identity-bound create/update/publish/cancel functions; client roles have no direct table mutation privileges. Public list/detail functions are explicitly granted to `anon` and `authenticated`. List output contains rough location only. Detail returns exact text only for `public` visibility; participant-restricted text is absent from the public row payload and represented by a boolean restriction flag. The shared participation meeting operation separately authorizes creators/current members. Publish and cancel write only proposal/actor identifiers to audit/outbox primitives and do not deliver notifications.

## Tavoli / recurring activities

`public.recurring_activities` stores persistent creator-owned Tavoli separately from one-time `proposals`. Its stored lifecycle is `draft`, `published`, `paused`, or terminal `ended`; elapsed meeting time never ends an open series. A draft may omit incomplete content or its schedule, while publication requires complete content, rough location, exact meeting information, and a schedule that can produce a future occurrence. Complete profiles are required for create, publish, and resume.

`public.recurring_activity_schedules` stores non-overlapping schedule versions. A weekly version has one ISO weekday from 1 (Monday) through 7 (Sunday); a monthly version has one day from 1 through 28. Both store local `time`, duration from 15 through 1440 minutes, a recognized IANA zone, and an inclusive `effective_from`/exclusive `effective_until` local-date range. Draft schedule replacement is allowed because no meeting history exists yet. After publication, a material schedule change must start on a future local date, closes the previous version, inserts a new open version, and records identifier-only audit/outbox metadata. A still-pending open version may be corrected in place at its existing future effective date; this neither creates a redundant version nor changes the already-effective schedule row. Direct table writes remain unavailable to clients, and a serialized trigger rejects overlapping ranges even for trusted writes.

`private.next_recurring_activity_occurrence` computes one finite next occurrence without expanding an infinite series. `private.derive_recurring_activity_occurrences` accepts only an increasing `[from, until)` window of at most five years and a limit from 1 through 100. Each candidate local date/time is converted with its stored IANA zone, so weekly and monthly wall-clock times remain stable across daylight-saving changes instead of adding fixed UTC weeks.

`public.list_public_recurring_activities` returns only active published Tavoli, ordered by derived next occurrence and deterministic ID cursor, with rough location only. Its non-null `p_reference_time` is required: a caller chooses one snapshot for page one and must reuse that exact value with every cursor from that pagination session, so occurrence boundaries cannot reorder rows between pages. `public.get_public_recurring_activity` is exact-ID detail for published, paused, or ended history; paused/ended rows have no active next occurrences. `public.list_public_recurring_activity_occurrences` exposes only bounded occurrences for currently published series. Public exact meeting text is detail-only when visibility is `public`; `participants` returns no protected value and an explicit restricted indicator. The shared participation meeting operation separately authorizes creators/current members.

Owners use expected-identity-bound create/update/publish/pause/resume/end and owner read operations. Repeated publish, pause, resume, and end calls are idempotent in their already-achieved state and do not duplicate audit/outbox events. Ended activities are immutable. Flutter provides the ordinary-user Tavoli experience. The public website consumes only the sanitized public list/detail functions and keeps authoring and owner management mobile-only.

## Shared project participation

`public.projects` is a private identity registry whose UUID equals one concrete `proposals.id` or `recurring_activities.id`. It stores only the concrete kind, synchronized creator, and source creation timestamp. Insert triggers register every future trusted source insert; ownership/ID changes are rejected; deletion removes the registry only when no request or membership history exists. It is not a public directory.

`public.project_join_requests` preserves private attempts with one of `pending`, `accepted`, `rejected`, or `withdrawn`. Optional requester messages are trimmed and capped at 500 characters. `public.project_memberships` records exactly one accepted request origin and preserves current, voluntarily-left, and creator-removed history. Partial unique indexes enforce at most one pending request and one current membership for each project/profile.

Authenticated clients use `request_to_join_project`, `withdraw_project_join_request`, `accept_project_join_request`, `reject_project_join_request`, `leave_project`, and `remove_project_member`; the tables themselves have no client privileges or RLS policies. All operations bind an expected rendered identity to `auth.uid()`, validate creator/requester/member ownership, and lock in a consistent source-project-row order. Request/accept eligibility uses the concrete lifecycle: a published one-time project accepts strictly before `ends_at`; a Tavolo accepts only while published. Pause/end/completion preserve membership history.

Requester, creator-review, own-membership, and creator-member-history reads are separate narrow operations. Request messages never become public, and the creator projection contains display name but no Auth email. `get_project_participant_meeting_details` returns only exact operational meeting text/point and concrete kind to the creator or a current accepted participant. Every transition adds an identifier-only audit/outbox event; no delivery, chat, resource contribution, capacity, badge, or contribution verification is implemented here.

## Structured participation-request Messages

`list_own_participation_request_message_items` and
`get_own_participation_request_message_item` project canonical join-request
history for the requester or Project creator only. They resolve current
Proposal/Tavolo title and narrow participant display names, expose the private
request message only inside that authorized relationship, and return no Auth
email, exact meeting data, notification payload, or unrelated profile fields.
Missing and unauthorized exact IDs use one fail-closed response.

The list accepts 1 through 50 rows and a paired nullable
`(p_cursor_activity_at, p_cursor_request_id)` cursor. It orders by resolution-or-
creation activity descending and request ID descending; expression indexes
support both outgoing requester and incoming creator paths. The routines are
fixed-search-path security definers granted only to `authenticated`. They add no
table grants, generic message/thread table, or durable copy. Request mutations
remain the 05A operations.

## Notification domain and outbox projection

`public.notification_categories` is the system-managed catalog for `participation`, `project_activity`, `matching`, `chat`, and `resources`. The initial categories default both in-app and future push preferences to enabled and are user-configurable. Only `participation` has event mappings today. `public.profile_notification_preferences` stores sparse per-profile/category overrides; an absent row deliberately inherits the current category defaults. `list_own_notification_preferences` returns all effective categories, while `set_own_notification_preference` changes only one category and binds the form identity to `auth.uid()`.

`public.notifications` stores recipient, category, semantic kind, source event, structured destination, relevant actor/request/membership identifiers, source chronology, and read state. It stores no message copy or source JSON. The six supported kinds are participation request received/withdrawn/accepted/rejected and participant left/removed. All four request-specific kinds retain `request_id` and target `participation_request`, a backend-route-agnostic reference to the future structured Messages item; the inbox returns that request ID with safe context. Participant-left targets the creator's `project_participation` overview, while participant-removed targets `project_detail`. Project kind and current title are resolved through the shared registry and concrete table by the inbox operation. The recipient-private workflow may return the current actor display name because the request/membership relationship authorizes that identity context, without weakening the anonymous public-profile boundary. Notifications remain alerts and do not own request acceptance or rejection.

`process_notification_outbox_batch` is executable only by `service_role`. It selects only the six supported and available participation events, ignores `published_at`, excludes `notifications.v1` receipts, and uses `FOR UPDATE SKIP LOCKED` for concurrent workers. Each event is validated against canonical request, membership, and project rows rather than trusting payload text. An enabled preference creates at most one notification under a database uniqueness constraint; a disabled preference creates none but still records its consumer receipt. Mapping inconsistencies fail the batch visibly and create neither guessed notifications nor success-shaped receipts. Events that existed before the notification migration are receipted for `notifications.v1` without historical notification backfill, while unsupported event types remain untouched.

Authenticated users use expected-identity-bound functions for keyset-paginated inbox reads, unread count, mark-one, mark-all, and preferences. Notification/category/preference tables use RLS with no direct client policies or table grants. Inbox results omit outbox IDs/payloads, private request messages, exact meeting text or coordinates, emails, tokens, and audit data.

## Push installation and delivery-job foundation

`private.resolve_participation_notification_event` validates each supported participation outbox event against canonical requests, memberships, project identity, and actors, then returns the provider-neutral recipient, kind, destination, references, and source chronology. Both projectors use this resolver so the six mappings cannot silently drift. The existing `process_notification_outbox_batch` signature, return shape, preference behavior, and `notifications.v1` receipt contract remain unchanged.

`private.push_installations` represents app installations by opaque client-generated UUID, current profile, Android/iOS platform, server-owned `fcm` provider, and a private bounded token. Authenticated clients can only call the expected-identity-bound `register_own_push_installation` and `unregister_own_push_installation` functions. Registration atomically handles idempotent refresh, token rotation/reuse, and installation ownership transfer; unregister clears the token before disabling the row. Neither routine returns token text, and there is no token-listing API or direct client table access.

`private.push_delivery_jobs` stores one recipient-level semantic job per source event, recipient, and kind. It intentionally stores no provider token, raw outbox payload, request message, exact meeting data, or per-device attempt. `process_push_outbox_batch` is service-only, selects available supported events with `FOR UPDATE SKIP LOCKED`, reuses the shared resolver, applies only the effective `push_enabled` value, and records `push.v1` success whether it creates or suppresses the job. It does not query installations or depend on `public.notifications`. Migration-time `push.v1` receipts cover already-existing supported events so provider delivery cannot unexpectedly replay historical activity.

Plan 06C2 owns Firebase Android/iOS configuration, APNs/Firebase iOS setup, a push-permission timing decision, a safe push-preview policy, and server-side FCM HTTP v1 credentials stored as secrets. Its Flutter scope includes random installation UUID persistence, official Firebase Messaging integration, token refresh/register/unregister lifecycles, account switching, OS permissions, foreground/background/open handling, and push preference UI. Its trusted worker scope includes claiming recipient jobs, resolving active installations, per-installation attempts, OAuth/provider sends, retry/backoff/idempotency, invalid-token cleanup, safe payloads, `no_targets`, and environment safeguards. No part of that provider-specific delivery exists in 06C1.

## Fail-closed access

The local config pins `auto_expose_new_tables = false`. The foundation migration also changes PostgreSQL default privileges for objects created by the `postgres` role in `public` and `private`:

- tables and sequences grant nothing to PostgreSQL `PUBLIC`, `anon`, `authenticated`, or `service_role`;
- functions grant no `EXECUTE`, including PostgreSQL's built-in `PUBLIC EXECUTE` default;
- client roles cannot create objects in `public`;
- the owner retains its inherent owner privileges.

Default privileges are scoped to the object creator. Supabase migrations run as `postgres`, and the pgTAP probes assert that ownership assumption. PostgreSQL's built-in routine grant is global rather than schema-local, so removing `PUBLIC EXECUTE` intentionally applies to every future function created by `postgres`; each callable function must opt in explicitly. If a future migration runner creates PLANETS objects as another role, add and test equivalent `ALTER DEFAULT PRIVILEGES FOR ROLE ...` rules before using it.

For every future ordinary table in `public`, keep the following in one reviewed migration:

1. create the table and constraints;
2. enable RLS explicitly with `alter table ... enable row level security`;
3. add policies for the intended actors and operations;
4. grant only the exact table privileges each actor needs;
5. grant only the required sequence privileges when inserts depend on a sequence;
6. add pgTAP coverage for grants, denials, policies, and relevant concurrency/constraint behavior.

For a client-callable function, review its security mode, explicitly grant `EXECUTE` only to intended roles, and test every other role's denial. This includes extension/PostGIS functions if a later feature calls one directly as a non-owner role. A later `SECURITY DEFINER` function requires a concrete need, a controlled `search_path`, explicit execution grants, tests, and no caller-controlled schema resolution; this foundation adds none. Do not rely on RLS to compensate for an excessive object grant, and do not rely on a UI to hide data.

## Tests, lint, and generated types

The native pgTAP files under `supabase/tests/` verify:

- the private schema boundary for all three Data API roles;
- PostGIS installation, non-public placement, type availability, and a basic spatial operation;
- an invariant that rejects any ordinary PLANETS table in `public` without RLS;
- disposable `postgres`-owned table, sequence, and function probes with no implicit client privileges;
- removal of those probes by transaction rollback.
- the profile anchor's Auth relationship, derived completion, constraints, canonical timestamps, and restrictive deletion;
- catalog/reference-data invariants, atomic profile updates, field defaults, grants, function hardening, and RLS policies;
- two deterministic fake Auth identities exercising owner access, cross-user denial, and mixed-visibility sanitized reads;
- audit/outbox constraints, defaults, indexes, restrictive actor deletion, and private client denial.
- one-time proposal constraints, lifecycle/status boundaries, owner/cross-account access, expected-identity protection, rough/exact privacy, skill relationships, function hardening, pagination, and historical retention.
- recurring activity constraints, owner isolation, stale expected identity, weekly/monthly wall-clock recurrence, Rome DST changes, bounded occurrence windows, non-overlapping schedule history, pause/resume/end transitions, public privacy, and function hardening.
- shared project registry synchronization, request/membership state and uniqueness, concrete lifecycle eligibility, stale identity, private read projections, participant meeting authorization, retained history, deletion protection, and content-free audit/outbox events.
- controlled notification categories/defaults, sparse owner preferences, semantic notification constraints, six participation recipient mappings, private multi-consumer receipts, projector idempotency/concurrency, suppression receipts, own-only inbox/read state, privacy, and service/client grants.
- private push installation constraints/grants, expected-identity registration and unregister behavior, token rotation/reuse and account transfer, provider-token privacy, shared semantic resolution, recipient-level job constraints, six-event mapping, all four channel-preference combinations, independent receipts, historical rollout, retries, and service-only projection.
- structured Messages read shape, requester/creator authorization, fail-closed exact lookup, Proposal/Tavolo context, private-message isolation, bounded keyset pagination, and routine grants.

Run focused commands while the stack is already running:

```text
npm run db:reset
npm run db:lint
npm run db:test
npm run auth:verify:local
npm run profile:verify:local
npm run proposal:verify:local
npm run recurring:verify:local
npm run participation:verify:local
npm run notification:verify:local
npm run push:verify:local
npm run messages:verify:local
npm run db:types
npm run db:types:check
```

`db:lint` intentionally checks only `public` and `private`, avoiding warnings owned by Supabase-managed schemas or extensions. `db:types` regenerates `apps/web/src/types/database.generated.ts` from local `public`; its wrapper propagates CLI failures, rejects empty output, and normalizes only the terminal newline across hosts. The file is generated output and must not be hand-edited or formatted. `db:types:check` regenerates it and fails on a tracked diff.

`auth:verify:local` requests a numeric email OTP from local Auth, reads the new message through Mailpit's API, verifies the code, and inserts/reads the authenticated user's profile anchor through current RLS. It uses only deterministic `.invalid` test identity data and never prints the email, code, access token, or client key.

`profile:verify:local` authenticates two deterministic local users, completes one profile through the canonical operation, and proves owner reads, cross-user denial, stale-form identity rejection, an ineffective cross-user update, and anonymous exact-ID sanitization under mixed visibility. It rejects email/private-field leakage and does not print OTPs, tokens, keys, or addresses.

`proposal:verify:local` uses two complete authenticated identities plus anon to prove draft ownership, cross-user and stale-identity rejection, publish/cancel behavior, controlled skills, rough-location discovery, participant-restricted exact-location absence, and public exact-location detail. It never prints test addresses, OTPs, tokens, keys, or exact restricted content.

`recurring:verify:local` uses two complete authenticated identities plus anon to prove Tavolo draft ownership, cross-user and stale-identity rejection, required snapshot pagination, weekly/monthly discovery, participant-restricted exact-location absence, public detail-only exact location, pause/resume/end visibility, preservation of an old schedule when a future version is added, and in-place correction of that pending version. Reference windows are deterministic; the harness performs no realtime waits and never prints addresses, OTPs, tokens, keys, or protected meeting content.

`participation:verify:local` uses a creator, requester, unrelated authenticated user, and anon across one future Proposal and Tavolo. It proves private request review, stale-identity rejection, single acceptance, leave/re-request/reject, pause/resume membership preservation, creator removal/re-request, end-history preservation, protected meeting authorization, and unchanged anonymous detail privacy. It never logs OTPs, tokens, request messages, or protected meeting values.

`notification:verify:local` uses three complete authenticated identities, a service-role client, and one narrow direct local-database assertion. It proves pre-projection absence, concurrent projector idempotency, request/accept/withdraw/reject/leave mappings, stable request IDs and `participation_request` targets, cross-account denial, structured safe context, unread/read changes, preference suppression with a receipt, later re-enable behavior, and coexistence with an independent synthetic consumer receipt. It never logs OTPs, keys, database URLs, request messages, or protected meeting values.

`notification:project:local` is the narrower native-QA companion. It derives
the service credential only from the current local Supabase status, drains the
service-only notification projector after a tester creates participation
transitions, and prints only processed/created/suppressed aggregate counts. It
must not be embedded in or called by Flutter; the 06B feature README documents
the deterministic local profiles and device-QA sequence.

`push:verify:local` uses three complete authenticated identities, synthetic provider tokens, the two service-only projectors, and narrow local-database assertions. It proves idempotent registration, rotation, account transfer, owner-only unregister, independent in-app/push preferences, concurrent push projection, semantic job privacy, retry idempotency, suppression receipts, consumer coexistence, and unsupported-event preservation. It prints no tokens, keys, request messages, or meeting values.

`push:project:local` is a trusted local helper that derives the service credential only from current local Supabase status, invokes the service-only push projector, and prints aggregate processed/created/suppressed counts. It must never be embedded in or called by Flutter.

`messages:verify:local` uses a Project creator, requester, unrelated authenticated user, and anon across a Proposal and Tavolo. It proves requester/creator structured reads and private-message visibility, identical unauthorized/missing exact failures, anonymous denial, canonical Accept/Withdraw history, both project contexts, chronology, narrow output, and unchanged public privacy. It never prints OTPs, tokens, keys, request messages, or meeting values.

`auth:web:verify:local` adds web-specific evidence after a locally configured production Next.js build. It obtains session cookies through supported `@supabase/ssr` callbacks, confirms the Server Component recognizes the authenticated session, rejects private-auth material in the rendered response, and confirms `/admin` returns 404 for signed-out and signed-in requests. It does not invent or log Supabase's cookie encoding.

`tavoli:web:verify:local` uses synthetic local OTP data and the production Next.js server to prove signed-out Tavoli list/detail rendering, rough-location and next-meeting output, exclusion of paused/ended rows from discovery, retained sanitized historical detail, exact-ID 404 behavior, and detail-only public/restricted exact-location handling. It never prints test addresses, tokens, keys, or protected meeting content.

`npm run check:db` performs reset, lint, pgTAP, the mobile/backend Auth check, the two-user profile visibility check, the proposal privacy/lifecycle check, the recurring activity recurrence/privacy/lifecycle check, the multi-user project-participation check, notification projection, push-foundation integration, structured Messages integration, type regeneration, and drift detection as one validation sequence. It assumes `npm run db:start` has already succeeded and leaves stack lifecycle to the caller. CI additionally generates local web configuration, builds Next.js, runs the web-session and public Tavoli integrations, and always stops Supabase.
