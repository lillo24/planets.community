# Database development

PostgreSQL is the canonical PLANETS product record. This guide owns the local schema-change, security-test, and generated-type workflow. The current schema includes application identity, basic profiles, a controlled starter skill catalog, field visibility, one-time proposals, the Tavoli recurring-activity domain, and private audit/outbox primitives.

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

`private.audit_events` is append-oriented operational/security history rather than user analytics; generic metadata must avoid bodies, tokens, exact locations, and unnecessary personal data. `private.outbox_events` is a transaction-local handoff record whose UUID supplies a stable event identity. Its availability/publication fields and pending index prepare later dispatch without implementing a queue, retries, notifications, or provider delivery. Neither private table has direct client privileges or Data API exposure.

## Public and private schemas

`public` is the PLANETS Data API schema. It remains listed in `[api].schemas` and is the only schema where later client-facing tables, views, or routines may be defined. Listing a schema makes it API-addressable; it does not grant object access by itself.

`private` owns non-API data and implementation details. It is deliberately absent from `[api].schemas`, and `anon`, `authenticated`, and `service_role` have neither `USAGE` nor `CREATE` on it. Do not grant `service_role` broad access as a convenience: it bypasses RLS, so any future access must be narrow, explicit, and justified by the owning plan.

PostGIS is installed into the existing non-API `extensions` schema. Qualify spatial types and functions as `extensions.geography`, `extensions.st_point`, and similar names in migrations and tests. One-time proposals reserve separate optional rough and exact geography points without implementing map input or geocoding; the exact point remains in the protected meeting record.

## One-time proposals

`public.proposals` stores creator, content, schedule, IANA event time zone, and structured rough location. `public.proposal_meeting_details` is a one-to-one protected record for exact meeting text/coordinates and `public.proposal_skills` relates the proposal to existing catalog skills as `required` or `useful`.

Only `draft`, `published`, and `cancelled` are stored. `private.derive_proposal_status` derives Upcoming before `starts_at`, Happening from start until end, Just Finished from the end until exactly 24 hours later, and Completed thereafter. Normal discovery includes the first three derived states, while exact-ID detail retains published historical proposals. Retention does not create a Community template or make completed content mutable.

Authenticated complete-profile owners call expected-identity-bound create/update/publish/cancel functions; client roles have no direct table mutation privileges. Public list/detail functions are explicitly granted to `anon` and `authenticated`. List output contains rough location only. Detail returns exact text only for `public` visibility; participant-restricted text is absent from the row payload and represented by a boolean restriction flag. Publish and cancel write only proposal/actor identifiers to audit/outbox primitives and do not deliver notifications.

## Tavoli / recurring activities

`public.recurring_activities` stores persistent creator-owned Tavoli separately from one-time `proposals`. Its stored lifecycle is `draft`, `published`, `paused`, or terminal `ended`; elapsed meeting time never ends an open series. A draft may omit incomplete content or its schedule, while publication requires complete content, rough location, exact meeting information, and a schedule that can produce a future occurrence. Complete profiles are required for create, publish, and resume.

`public.recurring_activity_schedules` stores non-overlapping schedule versions. A weekly version has one ISO weekday from 1 (Monday) through 7 (Sunday); a monthly version has one day from 1 through 28. Both store local `time`, duration from 15 through 1440 minutes, a recognized IANA zone, and an inclusive `effective_from`/exclusive `effective_until` local-date range. Draft schedule replacement is allowed because no meeting history exists yet. After publication, a material schedule change must start on a future local date, closes the previous version, inserts a new open version, and records identifier-only audit/outbox metadata. A still-pending open version may be corrected in place at its existing future effective date; this neither creates a redundant version nor changes the already-effective schedule row. Direct table writes remain unavailable to clients, and a serialized trigger rejects overlapping ranges even for trusted writes.

`private.next_recurring_activity_occurrence` computes one finite next occurrence without expanding an infinite series. `private.derive_recurring_activity_occurrences` accepts only an increasing `[from, until)` window of at most five years and a limit from 1 through 100. Each candidate local date/time is converted with its stored IANA zone, so weekly and monthly wall-clock times remain stable across daylight-saving changes instead of adding fixed UTC weeks.

`public.list_public_recurring_activities` returns only active published Tavoli, ordered by derived next occurrence and deterministic ID cursor, with rough location only. Its non-null `p_reference_time` is required: a caller chooses one snapshot for page one and must reuse that exact value with every cursor from that pagination session, so occurrence boundaries cannot reorder rows between pages. `public.get_public_recurring_activity` is exact-ID detail for published, paused, or ended history; paused/ended rows have no active next occurrences. `public.list_public_recurring_activity_occurrences` exposes only bounded occurrences for currently published series. Public exact meeting text is detail-only when visibility is `public`; `participants` returns no protected value and an explicit restricted indicator. Participant-authorized reads remain plan 05 work.

Owners use expected-identity-bound create/update/publish/pause/resume/end and owner read operations. Repeated publish, pause, resume, and end calls are idempotent in their already-achieved state and do not duplicate audit/outbox events. Ended activities are immutable. Flutter provides the ordinary-user Tavoli experience. The public website consumes only the sanitized public list/detail functions and keeps authoring and owner management mobile-only.

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

Run focused commands while the stack is already running:

```text
npm run db:reset
npm run db:lint
npm run db:test
npm run auth:verify:local
npm run profile:verify:local
npm run proposal:verify:local
npm run recurring:verify:local
npm run db:types
npm run db:types:check
```

`db:lint` intentionally checks only `public` and `private`, avoiding warnings owned by Supabase-managed schemas or extensions. `db:types` regenerates `apps/web/src/types/database.generated.ts` from local `public`; its wrapper propagates CLI failures, rejects empty output, and normalizes only the terminal newline across hosts. The file is generated output and must not be hand-edited or formatted. `db:types:check` regenerates it and fails on a tracked diff.

`auth:verify:local` requests a numeric email OTP from local Auth, reads the new message through Mailpit's API, verifies the code, and inserts/reads the authenticated user's profile anchor through current RLS. It uses only deterministic `.invalid` test identity data and never prints the email, code, access token, or client key.

`profile:verify:local` authenticates two deterministic local users, completes one profile through the canonical operation, and proves owner reads, cross-user denial, stale-form identity rejection, an ineffective cross-user update, and anonymous exact-ID sanitization under mixed visibility. It rejects email/private-field leakage and does not print OTPs, tokens, keys, or addresses.

`proposal:verify:local` uses two complete authenticated identities plus anon to prove draft ownership, cross-user and stale-identity rejection, publish/cancel behavior, controlled skills, rough-location discovery, participant-restricted exact-location absence, and public exact-location detail. It never prints test addresses, OTPs, tokens, keys, or exact restricted content.

`recurring:verify:local` uses two complete authenticated identities plus anon to prove Tavolo draft ownership, cross-user and stale-identity rejection, required snapshot pagination, weekly/monthly discovery, participant-restricted exact-location absence, public detail-only exact location, pause/resume/end visibility, preservation of an old schedule when a future version is added, and in-place correction of that pending version. Reference windows are deterministic; the harness performs no realtime waits and never prints addresses, OTPs, tokens, keys, or protected meeting content.

`auth:web:verify:local` adds web-specific evidence after a locally configured production Next.js build. It obtains session cookies through supported `@supabase/ssr` callbacks, confirms the Server Component recognizes the authenticated session, rejects private-auth material in the rendered response, and confirms `/admin` returns 404 for signed-out and signed-in requests. It does not invent or log Supabase's cookie encoding.

`tavoli:web:verify:local` uses synthetic local OTP data and the production Next.js server to prove signed-out Tavoli list/detail rendering, rough-location and next-meeting output, exclusion of paused/ended rows from discovery, retained sanitized historical detail, exact-ID 404 behavior, and detail-only public/restricted exact-location handling. It never prints test addresses, tokens, keys, or protected meeting content.

`npm run check:db` performs reset, lint, pgTAP, the mobile/backend Auth check, the two-user profile visibility check, the proposal privacy/lifecycle check, the recurring activity recurrence/privacy/lifecycle check, type regeneration, and drift detection as one validation sequence. It assumes `npm run db:start` has already succeeded and leaves stack lifecycle to the caller. CI additionally generates local web configuration, builds Next.js, runs the web-session and public Tavoli integrations, and always stops Supabase.
