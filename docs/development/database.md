# Database development

## Account suspension validation (09C1B)

`moderation:suspension:verify:local` uses ten real OTP identities for admin-only
apply/revoke, safe own status, ordinary private RPC/Storage denial, preserved
Project/delegate/Resource history, co-manager continuity, and staff recovery.
It deliberately retains cached Project/Resource sockets across suspension,
asserts no new per-subject publication after the boundary, then checks all three
private chat topic families deny new joins and permit reauthorization on revoke.
Queued pre-boundary signals cannot be recalled. Mobile tests separately prove
cooperative teardown and discarded private state on denial/status failure.

`moderation:suspension:concurrency:verify:local` checks both lock-observed winner
orders for all six role/acceptance paths, both outbound request kinds, Resource
acceptance and Project/Resource chat send. Messages and relationships committed
first remain; suspension first prevents the new transition. Two reciprocal-admin
winner orders also prove a suspended waiting admin cannot commit the opposite
suspension. There are 24 lock-observed cases in total.

`moderation:suspension:audit:local` compares 210 public signatures against
`account-suspension-rpc-inventory.json` (187 deny, 19 public, one own-status
exception, three service/worker-only). `--inventory` prints the reviewable
replacement inventory without secrets. The audit is intentionally heuristic,
not proof that every path executes a guard; signature drift and real-auth tests
are independent checks. These commands are included in `check:db`.
They also run inside the existing change-scoped Database CI job, without adding
another recurring workflow or unrelated-area trigger.

MODINT01 adds `moderation:integration:verify:local` for combined PI01/People
authorization: all 15 new private RPCs from main deny real pre-existing suspended
sessions, while public participant preview remains deliberately anonymous but
never exposes hidden Project identifiers/titles. Fresh admission uses the
canonical restriction, block-pair, hide, lifecycle and capacity boundary;
identity-bound action replay is strictly read-only and cannot restore an ended
membership. The forward visibility migration does not rewrite PI01 history.
`moderation:integration:concurrency:verify:local` observes eight exact-blocker
lock waits across apply/admission and restriction/hide revoke recovery. The
early suspension gate denies during an uncommitted revoke; an explicit retry
after commit succeeds. Run these after fresh pgTAP, not before it. Fixtures are
synthetic and persist until reset; use `MAILPIT_URL` for a non-default local port.
Both commands are part of `check:db` and the existing Database CI job.

Suspension migration/tests preserve private immutable history and current-role
authorization. Ordinary push jobs may still deliver; no provider/09C2 delivery
semantics are added. Public content is not automatically hidden. Appeals,
minimum-age rules and retention/deletion policy remain separately deferred.

PR #120 merged the cumulative integration schema, and PR #121 added
organizer-aware capacity. 09C1A is based on approved current `main`
`11155618e0aa7bf0de62ae178f79d4c0c50ac644`, not the prompt's older candidate.
Optional MLS/E2EE work from PR #28 is intentionally absent.

PostgreSQL is the canonical PLANETS product record. This guide owns the local schema-change, security-test, and generated-type workflow. The current schema includes application identity, basic profiles, the private profile-photo and single-cover Storage/domain foundations, a controlled starter skill catalog, field visibility, one-time proposals, the Tavoli recurring-activity domain, standalone Scambio-Dona resource listings, accepted-request agreements and conversations, Project resource needs, join-request contribution selections, immutable acceptance decisions, accepted-membership commitment sets, shared project participation, structured Messages reads, the Project group-chat lifecycle/authorization foundation, the in-app notification domain, the provider-independent push installation/delivery-job foundation, the private reporting/manual-review and blocking foundations, and private audit/outbox primitives.

## Source of truth and daily workflow

07C4's candidate migration adds targeted role offers to the existing invitation
domain, not a second authority ledger. Bearer mode has a token digest and no
target; targeted mode has no token and binds a profile plus membership episode.
Only genuine recipient acceptance creates a delegate with offered/accepted
provenance. Project-first locking serializes offer acceptance with leave/removal
and capacity-sensitive step-down. No membership is silently ended.
Invitation invalidation timestamps are captured after lock waits so an offer
committed by a still-authorized Co-creator cannot break a concurrent demotion.
Current People is a restricted display-name projection; manager requests/history and pending
offers use separate bounded keyset endpoints. The older unbounded manager reads
remain compatibility contracts, but the new screen does not call them.

Run `npm run project:people:verify:local` after a clean local reset/pgTAP run to
exercise both leave/accept lock orders, duplicate acceptance, final-slot step-down,
and issuer-demotion races. Its synthetic local fixtures persist until the next reset, like
the capacity verifier. Do not run pgTAP against a verifier-populated database.

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

## Reporting and manual moderation review

### 09C1A manual consequence domain

`private.moderation_consequences` owns immutable target/type/case/affected-user
episodes; only the one-way active-to-revoked timestamp can change.
`private.moderation_consequence_actions` owns immutable apply/revoke actors,
user-facing reasons and links to ordinary append-only case notes. Both tables
have RLS, restrictive foreign keys, no client/service-role table grants, and
partial unique indexes preventing duplicate active target/type episodes.
Reapply after revoke creates a new ID. Repeated active apply/revoke commands
return safe `PT409` conflicts rather than duplicating history.

Identity-bound `apply_moderation_consequence(expected staff, case, type, reason,
note)` derives targets from reviewed/completed cases. `revoke_moderation_consequence`
requires an active episode. Both require trimmed plain-text reasons (1–2000
characters) and private notes (1–4000), recheck current moderator/admin, and
atomically append note/action/audit/outbox. A share lock on the active staff
role serializes deactivation. Neither changes case review state. Reasons,
notes and evidence never enter audit/outbox metadata or logs.

`list_own_moderation_consequences` returns a bounded keyset history (default 20,
maximum 50) to only the affected identity, including safe owned-content
reference/title and user-facing apply/revoke reasons. Project hides belong to
the immutable Creator, not delegates. `list_moderation_case_consequence_history`
is staff-only. No public/counterparty notice lookup exists.

The private active predicates are the single owners of notice, restriction,
Project-hide and listing-hide state. Requests/acceptance acquire the requester
profile interaction lock before deterministic block pairs and the existing
Project/listing lock, then revalidate restriction/hide/block/manager state.
Restriction apply holds that same profile barrier while withdrawing pending
outbound attempts under their canonical domain locks; request history records
the requester withdrawal identity, while the separate consequence action
records the staff actor. Existing accepted relationships are never unwound.

Hidden content remains in its ordinary lifecycle. Public lists/details,
capacity/Needs, public cover Storage authorization, contextual organizer/owner
photos, candidate matching and immediate match delivery exclude hidden sources.
Listing match delivery and its dispatch wrapper are volatile, allowing a shared
listing lock and a fresh snapshot before revalidation, so
hide cannot cross a new delivery commit. Historical match facts remain history.
Owner/current-manager private access, independent photo relationships and truly
public profile photos keep their existing rules. Unhide neither republishes
closed/cancelled/ended content nor resurrects withdrawn requests or removes blocks.

The six source events are `moderation.safety_notice_applied`,
`moderation.safety_notice_revoked`, `moderation.interaction_restriction_applied`,
`moderation.interaction_restriction_revoked`, `moderation.content_hide_applied`,
and `moderation.content_hide_revoked`. Payloads contain consequence/action/case,
affected-profile and optional target identifiers only. They intentionally have
no notification consumer until 09C2; existing projection workers ignore them.

Run `npm run moderation:consequences:verify:local` for real OTP/PostgREST/Storage
privacy checks and `npm run moderation:consequences:concurrency:verify:local`
for both winner orders across restriction/hide versus Project request,
Creator/Co-creator/Co-organizer acceptance and Resource request/acceptance, plus
the final-capacity-spot regression. These run at the end of `check:db`.
Tests 108–111 own schema/security, command history, integrated relationships,
and hidden public/media/matching projections. No suspension, consequence UI,
appeals, minimum-age rule or retention policy is implemented here.

### Existing evidence foundation

The private `moderation_cases` table owns one immutable typed target, its
canonically derived subject, and Project or Scambio-Dona context. The private
`moderation_reports` row owns the original reporter evidence, category and
reporter-scoped submission key; repeat delivery of one client key is
idempotent, while a fresh key can represent a later incident. Private
`moderation_case_notes` and `moderation_case_events` are append-only. Evidence
bodies remain only in report/note records and are never copied into generic
audit metadata or outbox events.

Authenticated clients use only the public security-definer operations for
submission, reporter-owned status, staff access, bounded queue/detail reads,
note append and versioned state transition. Those operations fix an empty
`search_path`, bind expected identity to `auth.uid()`, derive content authors
and counterparties server-side, validate private-object access and grant
execute only to `authenticated`. All moderation tables retain RLS as defense in
depth and grant no direct table privileges to `anon`, `authenticated`, or
`service_role`.

09A2A adds private append-only `moderation_evidence_requests` and
`moderation_evidence_responses`. An after-insert report trigger participates in
the report transaction and takes the established Project participation lock
before snapshotting the creator plus accepted membership intervals containing
case creation. The `(case_id, request_kind, recipient_profile_id)` key makes
report delivery retries harmless. Recipient RPCs expose only the assigned
request, reporter wording without reporter identity, and the caller's own
response; they never expose peers or counts. Submission locks the case before
the request so completion and first response have one deterministic boundary,
accepts only an exact client retry, and otherwise preserves the first response.
The staff-only evidence RPC returns identified submitted responses and neutral
counts. Generic audit metadata contains identifiers/counts only, and no
corroboration outbox/Realtime/push event exists.

09A2B extends the request discriminator and adds private append-only
`moderation_counterstatements`. A report-transaction trigger creates one
`resource_counterstatement` request only for supported profile, Resource
request, or Resource chat-message targets with a canonical request context.
It revalidates the listing owner/requester pair and subject rather than trusting
client-supplied recipient data; generic listing reports without that context do
not qualify. Recipient operations use a unified discriminated request list plus
a counterstatement-specific detail/submit boundary. Submission locks case then
request, revalidates the current canonical counterparty, trims and requires
10–4000 characters, accepts only an exact client retry, and preserves the first
statement. The reporter has no request/status/statement read. Current staff get
only the assigned recipient and pending/submitted statement projection.
Identifier-only audit rows omit statement bodies, and no outbox, Realtime,
notification, or Resource-domain mutation is emitted.

The first staff role is intentionally an operator/database-owner bootstrap,
never a client path. After the profile exists, run a reviewed owner session:

```sql
insert into private.moderation_staff_roles (profile_id, staff_role)
values ('00000000-0000-4000-8000-000000000000', 'admin');
```

Use the real profile UUID and record the operator change. Deactivate access by
setting `is_active = false` and `deactivated_at = statement_timestamp()`;
subsequent staff operations deny immediately. Do not grant direct moderation
table access or distribute a service-role key to make an admin browser work.

09A1/09A2A/09A2B intentionally define no sanctions, public warning, automated
hiding, blocking, suspension, or retention/deletion policy. 09B, 09C and Plan
10 own those decisions respectively.

## User blocking

`private.user_block_episodes` records append-preserved directional intervals
with one active episode per `(blocker, blocked)` direction. API roles have no
table privileges. Expected-identity `block_user`/`unblock_user` mutations and a
bounded keyset `list_own_blocked_profiles` read expose only the caller's outbound
state. `get_own_blocked_profile_status` is the matching exact-target read: it
returns zero or one active caller-owned episode and prevents mobile from paging
through the management list merely to render Block versus Unblock. No API
reveals inbound/reciprocal state, no target notification or
block-specific outbox event exists, and audit metadata contains identifiers
only. Unblock closes the active interval and never revives a request,
membership, agreement, or chat.

The private symmetric predicate is reused by Project/Resource request creation
and acceptance. For Project participation, the interaction boundary is the
complete current manager set: immutable Creator plus active Co-creators and
Co-organizers. A block in either direction with any current manager denies new
request creation and every Creator/delegated-manager acceptance overload.
Revoked delegates are excluded. Activating a block closes pair-connected
pending requests using their existing withdrawn/rejected transitions, but does
not alter accepted Project membership, group chat, meeting or shared-workspace
access, or accepted Resource coordination. Public discovery and public photos
stay unchanged.
Interaction-audience photo metadata and exact Storage delivery are denied while
either block direction is active. Moderation reports, group corroboration,
Resource counterstatements, and staff review intentionally contain no block
check.

All block/request/accept operations acquire transaction-scoped advisory locks
for sorted profile pairs before domain rows. Project request/accept operations
snapshot the current manager IDs, acquire every requester/manager pair lock in
deterministic global pair order, lock the concrete/shared Project, then
revalidate both manager membership and each symmetric block barrier before
mutation. Delegate authority changes use the same Project lock, so a changed
snapshot yields the existing privacy-safe `PT409` retry conflict rather than a
stale decision. Project work then retains concrete Proposal/Tavolo → shared
Project → request order, while Resource work retains listing → request order.
Pending-close scans visit Projects and Resources in UUID order.

The mobile status/list caches are identity-bound and cleared on account change.
After Block/Unblock, only the affected target photo and Project/Resource/request
projections are invalidated. A zero-row exact result never means that the target
does not block the caller; direction-neutral `PT409` copy preserves that privacy.

## Application conflict SQLSTATEs

Application-level optimistic-concurrency and already-covered conflicts raised through PostgREST use the custom SQLSTATE `PT409`. Clients must inspect `PostgrestException.code` within the specific RPC context rather than infer a domain conflict from HTTP 409 alone, because ordinary database constraints can also map to that status. SQLSTATE `40001` is reserved for genuine PostgreSQL serialization failures and must not be authored as a PLANETS domain marker.

This separation is also a PostgREST 14 compatibility requirement: that release can retry an RPC transaction when application PL/pgSQL raises a custom `40001`. The commitment replacement, requirement claim, and actual-contribution replacement contracts therefore return `PT409` for their explicit domain conflicts without adding client or server automatic retries. Plan 13 still owns documenting and pinning the exact production/self-hosted PostgREST version; these conflict paths do not require waiting for PostgREST 16.

## Identity and shared operational primitives

Supabase Auth owns login identity in `auth.users`. `public.profiles` is the one-to-one PLANETS application identity anchor and reuses that Auth UUID as its primary key. It stores a required-on-completion display name, optional bio, and database-maintained timestamps. Completion is derived from a non-null validated display name; there is no completion flag. There is no automatic Auth signup trigger, so an Auth user without an application profile is valid until an authenticated application flow explicitly creates the anchor.

Authenticated users can insert and read only their own anchor, update only their own display name and bio, and manage only their own controlled skills and visibility rows under RLS. Catalog categories and skills are public read-only reference data. `anon` receives no direct profile grant. The exact-ID `get_public_profile(uuid)` function is the only anonymous profile boundary and returns only visibility-sanitized fields for completed profiles. `update_own_profile(...)` is the shared atomic write path for both clients; it requires the profile ID for which the form was rendered and rejects the request before mutation if that ID differs from the current `auth.uid()`.

Each new anchor receives exactly three public visibility rows for `display_name`, `bio`, and `skills`. `skill_categories` and `skills` contain seven categories and a small deterministic starter catalog; users cannot invent or mutate catalog terms. Free-text skills, proficiency, location, directory search, and generic organizer/participant audiences are not represented yet.

### Profile photo Storage and canonical metadata

Supabase Storage owns one private `profile-photos` bucket with an `image/webp` allowlist and a 250 KiB hard upload limit. The mobile client creates a 512×512 WebP, targeting roughly 100 KB, with no retained original. Objects use immutable `<profile-id>/<photo-version>.webp` paths and are uploaded with overwrite/upsert disabled. The database stores only that provider-independent path—never a Supabase hostname, full URL, signed URL, provider identifier, or image bytes.

`public.profile_photos` holds at most one current row per profile. Its audience is exactly `public` or `interactions`, defaults to `interactions`, and labels the latter “Only people I interact with.” This purpose-specific audience does not change the existing `display_name`/`bio`/`skills` `profile_field_visibility` contract. Generic non-owner reads use exact or bounded-batch metadata RPCs and permit public photos plus two composed relationship sets: the directional Project organizer-to-pending/current-participant interaction, and the Scambio-Dona listing-owner-to-pending-requester interaction. Accepted Resource requests grant symmetric owner/requester access while canonical agreement coordination remains open, including after listing closure. Rejection, withdrawal, pending `listing_closed`, completion, and cancellation end that Resource relationship unless another row independently qualifies.

08A4 treats existence of that canonical row—independent of audience—as a trust gate in `publish_proposal`, `publish_recurring_activity`, `request_to_join_project`, the actual draft-to-published transition in `publish_resource_listing`, and `request_resource_listing`. Missing photos fail with SQLSTATE `PT422`; drafts, historical rows, idempotent already-published calls, and later photo removal are unchanged. `get_project_creator_profile_photo_for_viewer(project_id)` and `get_resource_listing_owner_profile_photo_for_viewer(listing_id)` are separate narrow context boundaries: each resolves the creator/owner server-side, follows the corresponding public detail lifecycle visibility (or owner access), and returns only `profile_id`, `object_path`, and `updated_at`. Their operation-filtered exact Storage policies remain private-bucket, canonical-current-object, and non-listing; neither grants table reads nor broadens `get_profile_photo_for_viewer(profile_id)`.

Authenticated owner-only RPCs read metadata, commit an already-uploaded owner-owned path, change its audience, and clear it. Replacement locks the stable profile row, switches the canonical path, and returns the previous path. Upload and deletion always use the Storage API; SQL never inserts, updates, or deletes `storage.objects`. If upload succeeds but the database commit fails, the new object is unreferenced. If the database switch succeeds but deletion of the old object fails, the old object is orphaned while the new canonical photo remains valid. Later Plan 08 cleanup may remove objects not referenced by `profile_photos` after a safety window. Profile deletion cascades the metadata row only; Plan 10/account-deletion cleanup must separately remove physical objects through the Storage API.

### Project and Resource cover Storage

08B1 defines the separate private `cover-images` bucket for exactly one optional current cover per shared Project identity or standalone Resource listing. It accepts only `image/webp` and enforces a 512 KiB hard maximum. Object names are immutable and parent-bound: `<owner-id>/projects/<project-id>/<version>.webp` for Proposal/Tavolo or `<owner-id>/resources/<listing-id>/<version>.webp` for Scambio-Dona. The later mobile normalization target is approximately 1280×720 (16:9), roughly 200–300 KiB, with no retained original. `project_covers` and `resource_listing_covers` store only a unique provider-independent object path and timestamps; they have RLS, no row policies, and no direct API-role grants.

Authenticated owner RPCs get, commit/replace, and clear canonical cover metadata. Commit verifies expected identity, exact parent ownership and mutation lifecycle, path binding, Storage existence, Storage owner, and WebP metadata. Proposal covers are editable in draft or before a published Proposal starts; Tavolo covers are editable until the series is ended; Resource covers are editable until the listing is closed. Replacement and clear return the obsolete path for separate Storage API deletion. SQL never deletes an object, so failed post-commit cleanup can leave an orphan; scheduled orphan detection and account-deletion object cleanup remain later operational/privacy work.

Canonical Proposal, Tavolo, Resource, pending-request card, and Project/Resource match reads expose nullable `cover_object_path` without adding a URL. Public Storage access is exact-object and non-listable: it permits only a current canonical cover whose parent follows the existing public detail boundary (published Proposal; published/paused/ended Tavolo; published Resource listing). Draft, cancelled/closed, stale replaced, and cleared paths remain denied. Covers stay optional, do not satisfy profile-photo trust gates, and add no chat attachment, Drive/external image hosting, gallery, picker, processing, or rendering behavior. Run `npm run cover:verify:local` against the loopback local stack for the real Auth + Storage scenario.

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

## Scambio-Dona resource listings

`public.resource_listings` stores standalone owner-managed availability with exactly `donate` and `exchange` modes. In 04C1 those values are discovery intents only. In particular, `exchange` does not define lending, barter, ownership transfer, return, payment, reservation, contact, or handoff mechanics. Resource categories, quantities, condition grades, inline media, and Project linkage remain outside the listing row; the optional canonical cover is separate metadata, and personal saved browse filters are the separate private domain below.

The explicit lifecycle is `draft`, `published`, or terminal `closed`. Drafts may be incomplete and are private. Publication requires a 2–120-character title, 1–5000-character plain-text description, two-letter country code, locality, a rough public location label, and a current canonical owner photo. The photo check applies only to the real draft-to-published transition; draft creation/editing and already-published idempotent calls remain unchanged. `administrative_area` is optional. No exact location/address or contact field exists. Published listings remain editable only when the resulting row is still publishable; changing `listing_mode` changes only the public discovery bucket. Closing means only that the listing is no longer publicly available, retains it in owner history, and does not assert a successful donation or exchange.

The table has RLS enabled with no policies or direct `anon`, `authenticated`, or `service_role` grants. Expected-identity-bound hardened RPCs own draft creation, update, idempotent publication, terminal closure, and owner reads. Anonymous and authenticated callers use sanitized public list/detail RPCs. Discovery orders by `(published_at desc, id desc)` with a paired cursor and supports optional mode, trimmed case-insensitive locality equality, and literal case-insensitive substring search across title or description. Detail exposes the owner profile ID and display name only when the existing `display_name` visibility row is public. Publish/close audit and outbox records contain only listing/owner identifiers and the safe mode enum; no content or location text is copied, and no notification mapping is introduced.

### Personal Resource saved searches

`public.resource_saved_searches` stores private, Project-independent definitions of the current public Resource browse filters: optional query, optional `donate`/`exchange` mode, and optional locality. Query and locality are trimmed and bounded to 1–120 characters when present, mode is trimmed and lowercased, and at least one filter must remain after normalization. Query means a literal case-insensitive substring of title or description; locality means case-insensitive exact equality. There is no full-text expansion, synonym, score, taxonomy, radius, administrative-area, country, Project, request, agreement, reservation, display-name, notification, or result-snapshot field.

The table is RLS-enabled and RPC-only with no direct client or service-role grants. Every create/update/delete/read/list RPC binds `p_expected_profile_id` through the established authenticated Resource identity helper. A database unique expression over profile plus normalized filters makes semantic duplicates deterministic: create or update races produce one canonical row and SQLSTATE `PT409`, never an automatic merge. Update and hard delete lock the target row; `created_at` is stable while the trigger advances `updated_at`. Lists use a complete `(updated_at desc, id desc)` keyset with limits from 1 through 50.

`private.resource_listing_matches_saved_search_filters` mirrors the current public browse mode, locality, and literal-query semantics using listing fields only. It deliberately does not accept lifecycle state: draft or closed fields can satisfy the predicate, while current public browse independently returns only published listings. 04C4F2 executes Open through the normal mobile Resource Browse controller and `list_public_resource_listings`; later Browse edits do not mutate the personal, Project-independent saved definition.

04C4F3A consumes only future `resource_listing.published` events through the independent `saved-search-matching.v1` receipt. The migration receipts existing publication events without backfilling. The service-only projector revalidates canonical listing identity/current `published` state, locks definitions in stable order, suppresses the listing owner, and reuses the F1 predicate exactly. A definition is eligible only when its `updated_at` is no later than source `created_at`, so creating or editing a search never retroactively matches an older publication. Each new match creates one private `resource_saved_search_listing_matches` fact with source chronology and the saved-search `updated_at` version token, plus one identifier-only `resource_saved_search.matched` event. Deleting the search cascades its fact; the derived event may remain for the downstream consumer to suppress safely.

F3A remains frequency-neutral: it creates no notification or push row, consults no preference, and exposes no match-history read API. 04C4F3B1 consumes its match events immediately through the independent `notifications.v1` and `push.v1` channels. Its private resolver requires an exact identifier-only payload, the canonical fact and saved search to remain present, the saved-search version token to remain equal, the listing still to be `published`, and the current filter predicate still to match. Stale, deleted, closed, or no-longer-matching state is safely suppressed; inconsistent canonical state fails visibly. Each channel applies the existing global `matching` preference independently and deduplicates by recipient/listing, so overlapping saved searches produce one in-app alert and one push job for a new matching listing. There is no digest, frequency setting, per-search toggle, or retrospective delivery.

`public.resource_listing_requests` stores private, episode-based expressions of interest for published listings. Its exact request states are `pending`, `accepted`, `rejected`, `withdrawn`, and `listing_closed`. A partial unique index permits at most one `pending` or coordination-open `accepted` request per requester/listing while retaining completed/cancelled coordination and other terminal attempts. An optional initial message is trimmed, blank-to-null, and capped at 500 characters. `accepted` means only that the owner is willing to coordinate: multiple accepted requests may coexist, and acceptance does not reserve an item, close the listing, expose contact details, or assert handoff/completion.

Expected-identity RPCs are the only request boundary. Creation requires a complete requester profile plus a current canonical requester photo, locks the listing before validating its published state, and rejects self/duplicate requests. A missing photo returns `PT422` without weakening the existing validation, lock, or conflict contract. Every decision locks listing then request: the requester alone may withdraw `pending`, while the canonical owner alone may accept or reject `pending`. Acceptance atomically creates the one agreement anchor. Closing a listing maps only remaining `pending` requests to `listing_closed`, preserving accepted coordination and other history. Decision races return `PT409`; PostgreSQL `40001` remains reserved for genuine serialization failures. Owner, requester-history, and requester-or-owner exact reads are private. Public list/detail expose only `active_request_count`, derived from pending plus coordination-open accepted requests. Request events contain only request/listing/owner/requester/actor IDs.

`public.resource_exchange_agreements` owns the private post-acceptance coordination lifecycle without rewriting the request's accepted decision. Immutable `resource_exchange_agreement_terms` versions use a required owner `give`/bounded-`lend` leg and optional requester `none`/`give`/bounded-`lend` leg. The database snapshots listing title/description, trims and bounds requester resource text/private notes, and uses exact current/pending pointer CAS. Either counterparty may propose; only the other party may accept or reject, and only the proposer may withdraw. Counter-proposals preserve superseded versions. Current accepted terms may change before handoff, then freeze permanently at the first resource milestone; a future mutually accepted amendment domain must preserve rather than rewrite post-handoff terms.

`public.resource_exchange_agreement_events` is an immutable structured timeline. Provider/recipient authorization is exact for owner and requester legs; give completion requires provided/received statements, while lend completion also requires returned/return-received statements. The last required statement atomically completes the agreement and closes request coordination. Either counterparty may cancel negotiating/agreed coordination only before a milestone. Completion/cancellation permits a later request episode when the listing remains published. Listing closure never cancels an accepted agreement. Counterparty-only reads expose anchors, immutable terms, and timeline display names; current lend return-overdue booleans are derived without timer events. Tables are RLS fail-closed and RPC-only. Audit/outbox payloads contain identifiers only, with no terms, notes, dates, contact, exact location, notification, or conversation projection.

`public.resource_request_chats` is the one-to-one private conversation anchor for an accepted request, created in the same acceptance transaction as its agreement and backfilled for accepted history. `public.resource_request_chat_messages` stores only immutable human-authored, trimmed 1–4000-character plain text with server timestamps. The owner and requester permanently retain RPC-only exact summary and newest-first history access; unrelated and anonymous callers fail closed. Send additionally requires complete display identity and open accepted coordination. It locks the agreement row before re-reading close state, so cancellation/completion serialized first yields `PT409`, while a send serialized first remains durable. Listing closure is deliberately absent from send entitlement. A later request episode receives another chat.

Resource-chat summaries expose the canonical request/agreement/listing and counterpart display context, current send entitlement, an honest latest-human-message preview, and activity derived from activation, the latest human message, or latest structured agreement event. History uses `(created_at, message_id)` and chat lists use `(activity_at, chat_id)` descending keysets. Per-profile private Broadcast topics use `resource-chat:<chatId>:profile:<profileId>` and authorize only the exact owner/requester even after coordination closes. `resource.chat_message_sent` and `resource.exchange_changed` are identifier-only reload hints; message bodies and agreement content stay in durable authorized reads. `resource_chat.message_sent` audit/outbox payloads contain enough IDs for later notification projection but no private text. Run `npm run resource:chat:verify:local` for real-OTP, private Realtime, privacy, lifecycle, and lock-order coverage.

`list_own_structured_request_message_items` and `get_own_structured_request_message_item` provide a strict `participation_request`/`resource_request` discriminator over the existing request domains. The unified list uses the complete descending `(activity_at, item_kind_order, request_id)` cursor; Resource request activity changes only for its request decision or later coordination close, never ordinary negotiation/chat activity. `list_own_message_chat_items` similarly combines Project and Resource summaries with `(activity_at, item_kind_order, chat_id)`. The mobile scoped wrapper `list_own_scoped_message_chat_items` preserves the same activity/order/keyset semantics while separating Private from Groups and returns canonical opposite-party ID/name only for Resource rows; all other discriminators return null for those Resource-only fields. It preserves Project creator/current/former history frontiers and system-event activity, Resource permanent counterparty history and agreement-event activity, and human-only preview fields. Existing domain-specific RPCs remain unchanged for current clients.

Generic `interactions` profile-photo authorization follows current Project relationships. The immutable Creator and active Co-creators/Co-organizers can view pending requesters and current participants; those requesters/participants can view only the immutable Creator, not every manager. Revocation, rejection, withdrawal, leave, and removal fail closed unless another current Project/Resource relationship qualifies. The same predicate protects exact canonical Storage objects, so retaining a chat or guessing an old path never creates photo access.

## Project resource needs

`public.project_resource_needs` stores Project-owned requested things/materials for either a Proposal or Tavolo through the shared `public.projects` UUID. Each row has a stable UUID, a trimmed 2–160 character title, optional trimmed 1–1000 character details, and exactly `open` or terminal `closed` state. `closed` means only that the Project is no longer asking; it does not mean fulfilled, supplied, delivered, verified, or credited. Needs have no taxonomy, type, quantity, unit, condition, price, priority, contributor, join-request, membership, Scambio-Dona listing, JSON metadata, or user-controlled ordering fields.

Creator mutations bind the expected profile to `auth.uid()` and acquire locks in the existing concrete Proposal/Tavolo → shared Project → need order. Proposal needs follow the existing draft/pre-start owner-edit boundary. Tavolo needs remain manageable while draft, published, or paused and become immutable when ended. Creator history remains readable after the Project becomes historical. Public reads re-evaluate the concrete lifecycle and return only open needs for a joinable Project, with draft/cancelled/expired/paused/ended/missing Projects all returning an empty non-enumerating result.

The table has RLS with no client policies or direct grants. Authenticated creator operations and the narrow anonymous/authenticated public read are hardened security-definer RPCs with empty search paths and explicit grants. Create, update, and close emit only Project ID/kind, resource-need ID, and creator profile ID. 04C3A does not change join requests, create accepted commitments, project notifications, or link needs to standalone Scambio-Dona listings; 04C3B1 references stable need IDs from request-linked selections.

## Join-request contribution selections

`public.project_join_request_skill_selections` and `public.project_join_request_resource_selections` store immutable ID selections for one canonical join-request attempt. Composite primary keys reject duplicates; restrictive foreign keys preserve the request, skill-catalog, and resource-need identities. No label, free-text category, quantity, unit, price, fulfillment, or accepted-commitment field is copied into these relations. Both tables have RLS with no policies or direct client/service grants.

The single `request_to_join_project` signature keeps its existing identity, Project, and optional-message arguments and adds default-empty skill/resource UUID arrays. Null arrays normalize to empty, each group is capped at 50, and null or duplicate IDs fail explicitly. A Proposal accepts only skills currently attached through `proposal_skills`, including both `required` and `useful`; a Tavolo rejects every non-empty skill array. A selected resource need must exist, be open, and belong to the same Project. Request, permanent private request-chat anchor, selections, and the unchanged body-free `project.join_requested` audit/outbox event are one transaction.

The mutation keeps the established concrete Proposal/Tavolo → shared Project lock order, then locks selected resource needs in UUID order. This serializes need closure against request validation and uses the concrete Proposal row to serialize skill replacement. `list_own_project_join_request_contribution_selections` is granted only to `authenticated`, binds expected identity, authorizes only the requester or Project creator, and resolves current canonical labels in skill-catalog order followed by resource-need creation order. Resolution and later requirement/title/state changes never delete historical IDs; later requests start with independent selections. Accepted-participant commitments are a separate membership-episode domain and contribution verification remains later work.

## Join-acceptance contribution triage

`public.project_join_request_skill_acceptance_decisions` and `public.project_join_request_resource_acceptance_decisions` preserve the canonical creator decision for every offered item in one accepted request. Each row has exactly one `needed`, `already_found`, or `extra` disposition and a deciding profile/time; its composite primary key is also constrained to an actual immutable request selection. Update/delete triggers make the history immutable. The tables enable RLS but expose no policies or direct client/service grants.

The eight-argument `accept_project_join_request` overload requires six non-null disposition arrays. For skills and resources independently, the arrays must be unique, non-null, disjoint, bounded, and an exact partition of the request selections. Only `needed` asserts current requirement validity: Proposal skills must still be attached as required/useful, Tavolo skill arrays stay empty, and needed resources are locked in UUID order and must remain open on the same Project. Historical items whose requirement was removed or need was closed may still be `extra` or `already_found`. The two-argument overload delegates with empty arrays, so it remains valid only for zero-selection requests and cannot bypass triage.

Acceptance decisions, request resolution, membership creation, commitment seeding, chat activation, and the existing identifier-only acceptance event remain one transaction. The membership trigger fails closed if any selected item lacks a decision. `needed` and `extra` seed current commitments; `already_found` does not. Existing accepted history is backfilled as `needed` at its membership join time and deciding resolver without changing current commitments. A later commitment edit or rejoin never rewrites or inherits the earlier request's decisions.

These are deliberately separate records: request selection is what the requester offered; acceptance decision is what the creator decided then; current commitment is the mutable membership expectation; live Project coverage is the current D3A operational truth; and final actual contribution is deferred to 05C. None implies physical delivery or a person rating.

## Current participant commitments

`public.project_membership_skill_commitments` and `public.project_membership_resource_commitments` store the mutable full desired set for one canonical `project_memberships.id`. Triaged acceptance seeds that membership episode only from `needed` and `extra` acceptance decisions in the same transaction, without rewriting the request/decision history or emitting a commitment-update event. The earlier migration backfilled current and ended membership episodes from their originating requests; 04C3D1 separately backfills matching historical decisions without changing those sets. Leaving or removal retains the final set; a later rejoin creates an independent membership episode and seed.

`replace_project_membership_commitments` requires both the current skill/resource ID sets the caller believes it is editing and the new desired sets. Null arrays normalize to empty, every expected or desired group is capped at 50, null and duplicate IDs fail explicitly, and caller ordering is irrelevant. Only the current participant or canonical Project creator may replace a current membership's entire set. A published Proposal remains operational until its strict `ends_at` boundary, including after it starts; a published or paused Tavolo remains operational. Existing commitments may remain after a Proposal requirement is removed or a resource need closes, and they may be removed, but a removed stale ID cannot be re-added. New Proposal skills must be current required/useful relations, Tavoli accept no new skills, and new resource IDs must be open needs of the same Project. Empty desired arrays deliberately clear the set.

Replacement follows concrete Proposal/Tavolo → shared Project → membership → UUID-ordered resource locks, serializing leave/removal, need closure, and Proposal-skill replacement against additions. Once the membership is locked, replacement compares the expected sets to the canonical rows as an order-insensitive compare-and-swap. A stale snapshot fails with SQLSTATE `PT409` before desired-option validation or writes, so participant and creator cannot silently overwrite one another; 04C3C2 must pass the IDs returned by its loaded commitment read as the expected snapshot. If expected, desired, and canonical sets are identical, the call succeeds without rewriting timestamps or emitting an event. A real change emits exactly one `project.membership_commitments_updated` audit/outbox event containing only Project ID/kind, membership ID, participant profile ID, and actor profile ID; it has no notification projection. `list_own_project_membership_commitments` authorizes only the participant or creator for current or ended episodes and resolves the membership's retained current/final IDs with current canonical labels.

`list_own_project_membership_commitment_options` is the separate participant/creator-only read for what a current membership may newly add now. It requires the same operational Proposal/Tavolo boundary as replacement, returns current required/useful Proposal skills plus open same-Project needs, returns only open needs for Tavoli, and remains available while a Tavolo is paused. Removed skills and closed needs remain visible through the commitment-history read when retained but are absent from this options read. Options use the same skill-catalog-then-need-creation ordering. The read is an advisory snapshot with no locks or events; options may become stale, and replacement remains responsible for atomic revalidation. Both tables are fail-closed behind hardened RPCs with RLS, no policies, and no direct client/service grants. This foundation adds no quantity, fulfillment, delivery, verification, credit, delegation, Flutter UI, or Scambio-Dona linkage.

## Live Project requirement coverage

`public.project_membership_skill_coverages` and `public.project_membership_resource_coverages` are current participant sources whose composite restrictive foreign keys require matching membership commitments. `public.project_manual_skill_coverages` and `public.project_manual_resource_coverages` are independent creator-recorded external sources with optional accepted-request provenance. The four tables enable RLS, expose no policies or direct client/service grants, and are never client-read directly. Coverage is separate from the 04C3A requirement lifecycle: an open requirement is covered when at least one current participant or manual source exists; closing a resource or removing a Proposal skill deletes its sources without changing historical commitments or emitting a false resurfacing transition.

Triaged acceptance now initializes live state in the same transaction after commitment seeding. Current `needed` items create participant coverage, `extra` creates only a commitment, and a current `already_found` item creates a manual source only when no tracked source exists. Existing D1 history is backfilled under the same current-membership, current-requirement, and operational-lifecycle rules without emitting transition events. Membership leave/removal and covered commitment deletion release participant sources; the exact last-source transition for a still-current operational requirement emits `project.requirement_needed_again`. A first source emits `project.requirement_covered`; redundant sources emit neither duplicate. Both events contain only Project, requirement, actor, and optional membership identifiers.

`claim_project_requirement` serializes through concrete Proposal/Tavolo → shared Project → membership → resource row. A current accepted participant may claim only a current uncovered requirement; the first claimant wins and later claims fail with SQLSTATE `PT409`. Claim reuses an existing extra commitment or atomically creates a missing one within the independent 50-skill/50-resource limits, emitting the existing commitment event only for a created commitment. `set_project_requirement_manual_coverage` lets only the canonical creator idempotently add or clear an independent external source. `list_project_live_requirement_coverage` is available only while the Project is operational and only to its creator or a current participant; it returns current labels, skill importance, total/manual/viewer booleans, deterministic skill-then-resource ordering, and no provider identities. Public discovery is unchanged. The D3B2 mobile UI, global notifications, and final contribution attribution remain separate.

## Shared project participation

`public.projects` is the private cross-kind Project anchor whose UUID equals one concrete `proposals.id` or `recurring_activities.id`. It stores the concrete kind, synchronized Creator, source creation timestamp, one nullable `registration_capacity`, and the non-null `count_organizers_toward_capacity` policy shared by both Project kinds. The 05E1 migration renames the earlier `people_capacity` column without rewriting history and backfills the policy to `false`. Insert triggers register every future trusted source insert; ownership/ID changes are rejected; deletion removes the registry only when no request or membership history exists. It is not a public directory and has no direct client grants.

Organizers are the immutable original Creator plus active delegated Co-creators and Co-organizers. Ordinary participants are current memberships (`left_at is null` and `removed_at is null`) excluding those organizer profiles. With the policy off, `capacity_used_count` equals ordinary participants; with it on, unique organizers are added. `social_people_count` is the union of organizers and current memberships, so authority-only organizers are visible and organizer-participants are counted once. The raw current-membership count remains available to managers but is not capacity usage. All values come from `private.project_registration_capacity_snapshot`; none is stored as a counter. Registration capacity is constrained to 1–100,000 when present. Null preserves incomplete drafts and pre-05E published Projects as unspecified legacy state, and the next structural save requires a value. Proposal and Tavolo publication always requires registration capacity.

`list_public_project_capacity_statuses` exposes bounded aggregate-only registration usage and unique social headcount for public Project IDs, `list_project_capacity_statuses_for_structural_actor` supplies exact editor/management state to Creators and Co-creators, and `get_project_capacity_for_manager` supplies the participation screen to any current manager. The established concrete-source → shared-Project lock order serializes structural changes with participation. The same shared row serializes delegate activation/revocation and organizer-counting toggles. Capacity cannot be reduced below proposed usage; enabling organizer counting and authority changes fail with `PT409` when their post-change snapshot would exceed capacity. Pending-request insertion and every transition to a current membership recheck fullness while the shared Project row is locked, except that an already-counted or excluded organizer may independently join without adding usage. Failed acceptance rolls back request resolution, triage, membership, chat, coverage, and events. Leave/removal frees an ordinary-participant spot with no counter maintenance. Null-capacity legacy rows retain prior request/accept behavior. There is no waitlist, reservation, automatic promotion, per-occurrence Tavolo limit, size band, or popularity ranking.

`public.project_join_requests` preserves private attempts with one of `pending`, `accepted`, `rejected`, or `withdrawn`. Optional requester messages are trimmed and capped at 500 characters. `public.project_memberships` records exactly one accepted request origin and preserves current, voluntarily-left, and creator-removed history. Partial unique indexes enforce at most one pending request and one current membership for each project/profile.

Authenticated clients use `request_to_join_project`, `withdraw_project_join_request`, manager-named accept/reject/remove operations, `leave_project`, and owner-only compatibility operations; the tables themselves have no client privileges or RLS policies. All operations bind an expected rendered identity to `auth.uid()`, validate manager/requester/member authorization, and lock in a consistent source-project-row order. Request/accept eligibility uses the concrete lifecycle: a published one-time project accepts strictly before `ends_at`; a Tavolo accepts only while published. Pause/end/completion preserve membership history. The two-argument acceptance path works only for requests with no contribution selections.

Requester, manager-review, own-membership, and manager-member-history reads are separate narrow operations. Request messages never become public, and the manager projection contains display name but no Auth email. The separate request-selection and accepted-membership-commitment reads expose only current canonical labels to their authorized requester/participant or manager. `get_project_participant_meeting_details` returns only exact operational meeting text/point and concrete kind to a current manager or current accepted participant. Every participation transition adds an identifier-only audit/outbox event. The later 07B1 migration derives chat activation from canonical membership insertion without changing those event contracts; badges remain deferred.

## Project delegates and manager authorization

`public.project_delegates` stores append-preserved Co-creator/Co-organizer relationships against the shared `public.projects` identity. An active row makes that profile an operational Project manager without creating `project_memberships`; the immutable original Creator remains canonical attribution and is never a delegated row. A partial unique index permits only one active relationship per Project/profile. The relationship preserves its accepted invitation, actual grantor, initial role, current role, and optional revocation, while `public.project_delegate_role_changes` appends every promotion/demotion actor and transition. Existing pre-07C2C relationships backfill as Co-organizer.

`public.project_delegate_invitations` stores one seven-day, single-use role grant. Creation returns a 32-byte random base64url token once; only `digest(token, 'sha256')`, Project/original-Creator identifiers, the actual issuer, requested role, timestamps, and resolution metadata persist. Structural listing never returns a token. The two-argument creation overload remains a Co-organizer compatibility path, so pending pre-07C2C links preserve Co-organizer semantics. Anonymous/authenticated preview is non-mutating and returns one null-context unavailable row for malformed, unknown, consumed, revoked, expired, non-operational, or stale-issuer tokens. Acceptance requires a complete authenticated profile, serializes through the concrete/shared Project and invite row, rechecks current issuer structural authority, and is idempotent only for the same successful accepter.

`private.profile_is_project_manager` is the central Creator/Co-creator/Co-organizer operational predicate; `private.profile_has_project_structural_authority` narrows that to Creator/Co-creator. Structural RPCs create/revoke role-aware invitations, list grants, revoke delegated authority, and atomically promote/demote. A demotion or revocation that removes Co-creator authority atomically invalidates every pending invitation issued by that actor. Manager-named RPCs continue to cover participation, contribution, Needs, requester/group chat, and protected meeting access for both delegated roles. `get_own_project_management_role` returns only creator/co_creator/co_organizer/none for one exact Project; delegated discovery includes the caller's role. Co-creators may edit already-published Proposals/Tavoli and use the existing non-destructive lifecycle operations under the Creator's existing state/time validation. Draft creation/publication remain original-Creator-only. Authority changes never touch participation rows.

| Capability                                       | Creator     | Co-creator | Co-organizer |
| ------------------------------------------------ | ----------- | ---------- | ------------ |
| Operational participant management               | Yes         | Yes        | Yes          |
| Existing organizer chats / Needs / contributions | Yes         | Yes        | Yes          |
| Manage the private shared workspace link         | Yes         | Yes        | Yes          |
| Edit an existing Project where lifecycle permits | Yes         | Yes        | No           |
| Cancel Proposal / pause, resume, or end Tavolo   | Yes         | Yes        | No           |
| Manage Co-organizers                             | Yes         | Yes        | No           |
| Manage Co-creators                               | Yes         | Yes        | No           |
| Change original Creator                          | No transfer | No         | No           |

All three delegated-authority tables use RLS with no policies or direct grants. Invite/delegate/role transitions emit only Project, invitation, relationship, role, actor, and profile identifiers under `project.delegate_*` events; bearer values, display names, titles, and messages are excluded. Authoring/lifecycle events identify the actual acting Co-creator while the concrete Project retains the original Creator. Invite/share/deep-link setup is documented in [Project delegate invite links](project-invite-links.md). Final production package, signing, Team, and bundle identities plus profile-photo rule integration remain external/convergence work rather than database configuration.

## Project shared workspace

`public.project_shared_workspaces` stores zero or one trimmed absolute HTTPS URL
per `public.projects` row. The table is RLS-enabled with no policies and no
direct Data API privileges; authenticated clients use only
`get_own_project_shared_workspace`, `set_project_shared_workspace`, and
`clear_project_shared_workspace`. Reads bind the expected profile to Auth and
require either `private.profile_is_project_manager` or a current membership.
Writes serialize on the Project row and require the current manager predicate,
so Creator, Co-creator, and Co-organizer have the same workspace authority.
Chat existence is deliberately irrelevant, allowing pre-chat configuration.

The URL is capped at 2,048 characters, must be trimmed absolute HTTPS with a
host and without whitespace, control characters, or user-info credentials, and
never appears in public Proposal/Tavolo reads, audit events, or outbox payloads.
No Drive API, OAuth token, provider identifier, file, or attachment is stored;
the external service remains responsible for content and permissions.

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

## Participation-request private chat

`public.project_join_request_chats` stores one opaque chat ID, unique restrictive
request foreign key, and `activated_at` equal to the canonical request
`created_at`. The migration backfills every existing request episode and an
`AFTER INSERT` trigger makes every later `request_to_join_project` call create
the anchor in the same transaction as its request and contribution selections.
Anchors remain after accept, reject, or withdraw and cannot be mutated.

`public.project_join_request_chat_messages` stores immutable human-authored
messages with restrictive chat/sender foreign keys, canonical surrounding-space
trimming, a 1–4,000 Unicode-character limit, and a server-owned timestamp.
Neither the optional request note nor any state transition is copied into this
table. Both request-chat tables have RLS enabled without policies or direct
client/service privileges, are absent from Postgres Changes, and are accessible
only through expected-identity security-definer RPCs.

`get_own_project_join_request_chat` accepts a request ID and returns exact
Project kind/title, requester/creator display identities, request state and
note, canonical timestamps, read-only/send entitlement, and the canonical
Project group-chat ID only after acceptance. Missing and unauthorized requests
fail identically. `list_own_project_join_request_chat_items` returns exactly one
structured `request` row plus zero or more `message` rows under a strict field
XOR and descending `(created_at, item_kind_order, item_id)` cursor. The existing
structured Requests and unified Chats RPCs remain unchanged for 07C1B.

`send_project_join_request_chat_message` authorizes only the requester or
Project creator and only while the request is pending. It follows the canonical
concrete-Project → shared Project → request-row lock order used by participation
resolution, assigning `clock_timestamp()` afterward. A send serialized before
accept/reject/withdraw commits; a waiting send observes the terminal status and
fails with `PT409`. Resolved counterparties retain exact/feed read access.

Each send writes identifier-only audit/outbox event
`project.join_request_chat_message_sent` and calls `realtime.send` with only
chat/request/message IDs and creation time for both exact counterparties. A
receive-only policy authorizes private
`project-request-chat:<chat-id>:profile:<profile-id>` topics against
`auth.uid()`. Existing notification/push processors have no mapping for this
event and safely leave it for 07C1B. Run
`npm run project:request:chat:verify:local` for real-OTP, private Realtime,
privacy, strict feed, accepted group-chat continuation, and send/accept race
coverage.

## Project group-chat lifecycle, messages, and Realtime

`public.project_group_chats` stores only an opaque UUID, the unique shared
Project identity, earliest accepted-membership activation time, and physical
creation time. It has RLS enabled with no policies or direct client/service
grants. The first `project_memberships` insert transactionally calls a private
conflict-safe ensure helper, so acceptance cannot commit without the chat anchor
and later acceptance/rejoin retains the same ID. A private idempotent
reconciliation helper backfills any Project with earlier membership history and
uses `min(joined_at)` as logical activation. Project and chat identities are
immutable, and a validation trigger forbids anchors without membership history.

Private helpers answer creator status, current membership, any accepted history,
membership at a timestamp, and current/historical chat entitlement. Participant
intervals are half-open `[joined_at, coalesce(left_at, removed_at))`; separate
rejoins remain separate rows and gaps remain observable. The Project creator is
authorized independently through immutable ownership. Leave/removal therefore
changes entitlement without a chat mutation, and Project completion or Tavolo
pause/end does not delete the anchor.

`get_own_project_group_chat` is the client-facing 07B1 anchor contract. It binds
the expected profile to `auth.uid()` and returns only chat/Project IDs, Project
kind, activation time, viewer role, and current/history booleans to the creator
or someone with accepted membership history. Missing, pre-activation, and
unrelated lookups fail with the same unavailable response. 07A request Messages
remain separate. There is no chat-member mirror, meeting-detail copy, or Flutter
chat state.

`public.project_chat_messages` is the 07B2B durable source of truth. It stores a
database-generated UUID, restrictive chat/sender foreign keys, canonically
trimmed plain text of 1 through 4,000 Unicode characters, and a server-owned
timestamp. Messages are immutable: there is no update/delete operation or
soft-delete placeholder, and a trigger rejects ordinary owner DML mutations.
The table has RLS enabled but no policies or direct client/service grants. Its
indexes match `(chat_id, created_at desc, id desc)` keyset history and the sender
foreign-key path. Attachments, reactions, replies, receipts, unread state,
rich text, and encryption fields remain absent.

`private.profile_can_read_project_chat_message` implements the approved durable
coordination-log rule. The creator and a current accepted participant read every
message, including pre-first-join history. A former participant reads messages
through `max(coalesce(left_at, removed_at))` for their latest ended membership.
Rejoin makes all accumulated history visible, including the gap; a later end
advances the frontier. `list_own_project_chat_messages` returns safe sender
display context with a paired descending timestamp/UUID cursor. No exact-message
RPC exists because Realtime consumers refresh durable history.

`send_project_chat_message` requires an authenticated complete expected profile,
the creator or a current membership, a valid chat, and a canonical body. It
acquires `lock_project_for_participation`, preserving the established concrete
source then shared Project lock order, and assigns `clock_timestamp()` only
after that lock. Leave/removal now assign their end boundary after the same lock.
Therefore a send serialized first remains inside the former-member frontier,
while a send waiting behind termination rechecks entitlement and fails.

`list_own_project_group_chats` returns one creator/current/former-visible chat
using a bounded `(activity_at, chat_id)` keyset. Preview and activity are derived
from the latest message the viewer can read or the chat activation time. A new
message beyond a former member's frontier neither changes their preview nor
reveals activity.

Each successful send records `project.chat_message_sent` in the private outbox
with only chat, Project kind/ID, message ID, and sender profile ID. The 06D
notification and push projectors consume it through canonical message-time
recipient resolution without copying the body. The same transaction calls
`realtime.send` with only chat ID, message ID, and creation time on private
`project-chat:<chat-id>:profile:<profile-id>` topics for the creator and current
members. A `realtime.messages` SELECT policy verifies `auth.uid()`, exact topic,
and current entitlement; there is no client Broadcast-send policy and the
message table is not in a Postgres Changes publication. Per-profile addressing
prevents an already-connected former client from receiving new signals even
though Supabase caches channel authorization for a connection. Durable RPCs,
not Realtime, recover all history after disconnect.

The application supplies only `chat_id`, `message_id`, and `created_at` to
`realtime.send`. The pinned Realtime stack adds its own opaque message `id` as
transport metadata to the stored and received signal, so the resulting payload
still contains identifiers/timestamps only. Consumers ignore that transport ID
for domain reconciliation and fetch by the durable `message_id`.

The authenticated role receives `EXECUTE` only on the fail-closed private topic
predicate so Realtime can evaluate that policy. It still has no `USAGE` on the
unexposed `private` schema, no direct Data API route to the predicate, and no
private-table grant; all other chat-message helpers remain owner-only.

### Structured requirement resurfacing and attention

`public.project_chat_system_events` is a separate immutable, fail-closed
history relation; `project_chat_messages.sender_profile_id` remains required
and human sends retain their existing behavior. Each system row represents only
`requirement_needed_again`, stores a strict skill-or-resource reference, and has
one unique restrictive reference to the exact private D3A outbox event. It
stores no body or label. The mixed-feed read resolves the current canonical
`skills.label` or `project_resource_needs.title`, so requirement removal or
closure does not erase historical group context.

D3A's coverage-transition helper now assigns one canonical `clock_timestamp`,
writes audit/outbox provenance, and, when an existing chat is present,
synchronously creates the needed-again system row and calls `realtime.send` in
the same transaction. Covered transitions send only a refresh signal and never
create durable system history. A transition without a chat retains its
audit/outbox records but neither creates a chat nor broadcasts. Current creator
and accepted-member recipients reuse the existing
`project-chat:<chat-id>:profile:<profile-id>` topic. Payloads contain only chat,
Project, requirement, event, and time identifiers. Membership coverage release
runs after the leave/removal boundary is stored, so a departing profile neither
receives nor gains history for the later system item.

`list_own_project_chat_feed` owns cross-table pagination with the complete
`(created_at, item_kind, item_id)` cursor and an explicit message-before-system
tie-break. It applies the same creator/current/former frontier helper as human
history and returns a strict discriminated row: message sender/body fields and
system requirement fields are mutually exclusive. The old message-only read
remains available until D3B2 migrates. `list_own_project_group_chats` keeps its
human preview fields honest while `activity_at` considers the newest visible
human or system item; post-frontier events do not move a former member's chat.

`public.project_chat_requirement_attention_receipts` stores one fail-closed
`(chat_id, profile_id)` cursor with both event time and UUID constrained to an
event in that chat. `get_own_project_requirement_attention` is current-group
only and reports an unseen item only while its requirement is still current,
uncovered, and operational. Re-cover, requirement removal/closure, or Project
end suppresses attention without deleting history. The acknowledgement RPC
locks through the same concrete Project → shared Project order and advances the
cursor monotonically to the exact event supplied by the client; a later event
serialized concurrently remains unseen. Chat opening, message loading, and
Realtime connection do not acknowledge attention. These receipts are separate
from notification-inbox `read_at`, and D3B1 adds no global notification or push
projection.

This is ordinary authenticated server-authorized messaging over HTTPS/TLS. The
backend can technically read stored bodies, so it must not be described as
E2EE. MLS research remains in unmerged PR #28 and is deferred as an optional
future versioned privacy enhancement.

## Notification domain and outbox projection

`public.notification_categories` is the system-managed catalog for `participation`, `project_activity`, `matching`, `chat`, and `resources`. The initial categories default both in-app and future push preferences to enabled and are user-configurable. `participation` maps the six 05A transitions, `chat` maps Project chat messages, `resources` maps supported Scambio-Dona request, chat, and agreement events, and `matching` maps immediate saved-search match availability. `public.profile_notification_preferences` stores sparse per-profile/category overrides; an absent row deliberately inherits the current category defaults. `list_own_notification_preferences` returns all effective categories, while `set_own_notification_preference` changes only one category and binds the form identity to `auth.uid()`.

`public.notifications` stores recipient, category, semantic kind, source event, structured destination, relevant actor and domain identifiers, source chronology, and read state. It stores no message copy or source JSON. Project kinds remain the six participation kinds plus `chat_message_received`: all four request-specific kinds retain `request_id` and target `participation_request`; participant-left targets `project_participation`; participant-removed targets `project_detail`; and chat targets `project_chat` with restrictive `chat_id`/`message_id` references. Project kind/title and authorized actor display name are resolved by the recipient-private inbox without weakening the anonymous public-profile boundary. Notifications remain alerts and do not own participation, request, agreement, or chat actions.

Resource alerts use separate restrictive listing/request/chat/message/agreement/event references instead of overloading Project UUID columns. Request creation/withdrawal targets the owner, decisions/listing closure target the requester, and Resource messages or supported agreement changes target only the opposite fixed counterparty. Request acceptance and every agreement/chat alert route to `resource_chat`; other request alerts route to `resource_request`. Agreement creation and terms-superseded events deliberately produce no alert. Matching alerts use `matching_available`, target `matching_result`, and retain only the listing reference; neither the notification nor its inbox projection exposes the saved-search identifier or private filters. The recipient-owned inbox may resolve the safe listing title and canonical agreement event/leg enums, but never returns request messages, chat bodies, private terms/notes, lending dates, contact details, saved-search filters, or outbox payloads. Existing supported Resource and saved-search-match events are migration-time receipted for `notifications.v1` and `push.v1` without retrospective alerts.

`process_notification_outbox_batch` is executable only by `service_role`. It selects supported available participation, chat, Resource, and saved-search-match events, ignores `published_at`, excludes `notifications.v1` receipts, and uses `FOR UPDATE SKIP LOCKED` for concurrent workers. Participation events retain their existing one-recipient mapping. A chat event may resolve to zero or many recipients: the Project creator plus accepted memberships whose half-open interval contains `project_chat_messages.created_at`, with the sender excluded and recipient identities deduplicated. Each recipient independently applies the effective in-app preference. Matching events are revalidated at processing time and deduplicated by recipient/listing across overlapping saved searches. The source receipt is written only after the whole fan-out succeeds, including safe zero-recipient/suppressed outcomes; per-recipient uniqueness keeps lost-response retries idempotent. Mapping inconsistencies fail visibly and produce no guessed rows or receipt. Historical supported events are receipted without alert backfill, while unsupported event types remain untouched.

Authenticated users use expected-identity-bound functions for keyset-paginated inbox reads, unread count, mark-one, mark-all, and preferences. Notification/category/preference tables use RLS with no direct client policies or table grants. Inbox results omit outbox IDs/payloads, private request messages, exact meeting text or coordinates, emails, tokens, and audit data.

## Push installation, delivery jobs, and worker protocol

`private.resolve_participation_notification_event` keeps the existing six participation mappings. Project-chat, three Resource, and saved-search-matching resolvers require exact identifier-only payloads, cross-check canonical source rows, and derive recipients from domain ownership rather than trusting payload recipients. The saved-search resolver additionally revalidates the stored match version, current listing lifecycle, and current filter predicate. `private.resolve_notification_event` provides their common provider-neutral result to both projectors so channel mappings cannot drift. Public/client and broad service roles cannot execute these private helpers. Existing projector signatures, result counts, and consumer keys remain unchanged.

`private.push_installations` represents app installations by opaque client-generated UUID, current profile, Android/iOS platform, server-owned `fcm` provider, a private bounded token, and a positive monotonic `token_version`. Authenticated clients can only call the expected-identity-bound `register_own_push_installation` and `unregister_own_push_installation` functions. Same-token refresh and same-token account transfer keep the version stable. Rotation, token clearing, reactivation, and current-generation invalid-token cleanup advance it. Registration still atomically handles token reuse and ownership transfer; unregister clears the token before disabling the row. Neither routine returns token text or version, and there is no token-listing API or direct client table access.

`private.push_delivery_jobs` stores one recipient-level semantic job per source event, recipient, and kind, with strict mutually exclusive Project, Resource coordination, or listing-only matching reference shapes. It intentionally stores no provider token, raw outbox payload, saved-search identifier/filter, request/message body, agreement terms, exact meeting data, or per-device attempt. `process_push_outbox_batch` is service-only, selects available supported Project, Resource, and saved-search-match events with `FOR UPDATE SKIP LOCKED`, reuses the shared resolver, applies only each recipient's effective `push_enabled` value, and records `push.v1` success after complete fan-out. Matching jobs are immediately available and deduplicated by recipient/listing across overlapping saved searches. The projector does not query installations or depend on `public.notifications`; in-app and push preference combinations remain independent. Migration-time `push.v1` receipts cover already-existing supported events so provider delivery cannot unexpectedly replay historical activity. Delivery results never rewrite those projection receipts. Provider delivery, push-preview policy, and mobile matching copy/routes remain separate work.

`private.prepare_push_delivery_jobs` locks available, unprepared jobs with `FOR UPDATE SKIP LOCKED` and snapshots their recipient's active installations exactly once. Each snapshot becomes one `private.push_delivery_targets` row containing only installation identity, platform/provider, schedule, status, attempt count, and lease state. The token remains solely on the installation. Registrations after `fanout_at` do not receive historical work. A job without active installations completes immediately with `no_targets`; otherwise it completes with `delivered_or_terminal` only after every target reaches `delivered`, `invalid_token`, `permanent_failure`, or `no_longer_registered`.

`private.claim_push_delivery_targets` validates bounded worker/batch/lease inputs, first retires stale ownership snapshots, then uses `FOR UPDATE SKIP LOCKED` to assign distinct pending targets. Claim increments the target attempt number, creates one unfinished `private.push_delivery_attempts` row atomically, and returns a fresh UUID lease plus semantic job context—including nullable chat/message IDs—and the installation's current raw token/version. It never returns a chat body. The raw token exists only in this private routine response; jobs, targets, attempts, public APIs, ordinary generated types, and logs do not contain it. The service role has `USAGE` on the unexposed `private` schema and `EXECUTE` on the three worker entry points, but no table privileges. A trusted worker must therefore use a direct PostgreSQL connection; `private` is intentionally absent from the Data API exposed-schema list.

`private.record_push_delivery_result` requires the current target, opaque lease, and claimed token version. Results after lease expiry are rejected, even before reclaim. Expired targets can be reclaimed under a new lease and attempt, and an old response cannot overwrite that state. `transient_failure` finishes the attempt, clears the lease, and moves the target to a caller-supplied bounded positive future delay; exponential/jitter policy remains adapter-owned. `delivered` and `permanent_failure` are terminal. `invalid_token` is terminal and disables the installation only when its current owner and token version still match the claim, so an in-flight stale response cannot clear a rotated token. Attempt rows retain bounded message IDs/error codes and outcome chronology, never tokens, raw provider responses, notification content, or private project/request fields.

Plan 06C2B owns Firebase Android/iOS configuration, APNs/Firebase iOS setup, a push-permission timing decision, a safe push-preview policy, and server-side FCM HTTP v1 credentials stored as secrets. Flutter must persist a random installation UUID, register only after authenticated readiness and token availability, refresh on token changes, unregister on sign-out/account switching where possible, and recover by registering the current token after restart. The repository-owned adapter must claim through the 06C2A private routines, map FCM HTTP v1 outcomes, choose bounded retry/backoff, never log tokens or credential/body content, and remain deployable beside self-hosted Supabase. Managed Supabase is acceptable for development/staging, but no hosted project reference, `supabase.co` endpoint, managed scheduler, Edge Function, or provider network call is part of 06C2A.

## Fail-closed access

The local config pins `auto_expose_new_tables = false`. The foundation migration also changes PostgreSQL default privileges for objects created by the `postgres` role in `public` and `private`:

- tables and sequences grant nothing to PostgreSQL `PUBLIC`, `anon`, `authenticated`, or `service_role`;
- functions grant no `EXECUTE`, including PostgreSQL's built-in `PUBLIC EXECUTE` default;
- client roles cannot create objects in `public`;
- the owner retains its inherent owner privileges.

Default privileges are scoped to the object creator. Supabase migrations run as `postgres`, and the pgTAP probes assert that ownership assumption. PostgreSQL's built-in routine grant is global rather than schema-local, so removing `PUBLIC EXECUTE` intentionally applies to every future function created by `postgres`; each callable function must opt in explicitly. If a future migration runner creates PLANETS objects as another role, add and test equivalent `ALTER DEFAULT PRIVILEGES FOR ROLE ...` rules before using it.

Plan 06C2A is the deliberate private-schema resolution exception: `service_role` receives schema `USAGE` only so a direct PostgreSQL worker can resolve the three explicitly granted protocol routines. Plan 07B2B separately grants `authenticated` execution of one fail-closed Realtime policy predicate without granting schema `USAGE`, so it is evaluable only through the stored policy rather than exposed as a client RPC. The schema remains absent from the Data API configuration, `anon` retains no schema access, `authenticated` retains no schema access, the aggregate helper remains owner-only, and every private table remains ungranted.

For every future ordinary table in `public`, keep the following in one reviewed migration:

1. create the table and constraints;
2. enable RLS explicitly with `alter table ... enable row level security`;
3. add policies for the intended actors and operations;
4. grant only the exact table privileges each actor needs;
5. grant only the required sequence privileges when inserts depend on a sequence;
6. add pgTAP coverage for grants, denials, policies, and relevant concurrency/constraint behavior.

For a client-callable function, review its security mode, explicitly grant `EXECUTE` only to intended roles, and test every other role's denial. This includes extension/PostGIS functions if a later feature calls one directly as a non-owner role. Every `SECURITY DEFINER` function requires a concrete need, a controlled `search_path`, explicit execution grants, tests, and no caller-controlled schema resolution. Do not rely on RLS to compensate for an excessive object grant, and do not rely on a UI to hide data.

## Tests, lint, and generated types

The native pgTAP files under `supabase/tests/` verify:

- the private schema boundary for `anon` and `authenticated`, plus the service role's routine-only worker exception with no table grants;
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
- organizer-aware registration-capacity shape and bounds, draft/legacy null behavior, default-off policy, ordinary-participant/organizer/social-union derivation, public aggregate privacy, publication and structural-edit validation, request/accept fullness, delegate and toggle conflicts, failed-operation rollback, natural spot release, and concurrent participant/delegate/toggle serialization.
- delegated-authority invitation/relationship/history constraints and grants, digest-only token storage, exact expiry, role-aware single-use race/retry behavior, stale-issuer invalidation, operational versus structural authorization, participation independence, Co-creator authoring/lifecycle access, chat/Realtime access, and identifier-only events.
- controlled notification categories/defaults, sparse owner preferences, participation plus Project-chat semantic constraints, send-time multi-recipient fan-out, sender exclusion, private multi-consumer receipts, projector idempotency/concurrency, suppression receipts, own-only inbox/read state, privacy, and service/client grants.
- private push installation constraints/grants, expected-identity registration and unregister behavior, token rotation/reuse and account transfer, provider-token privacy, shared semantic resolution, recipient-level job constraints, six-event mapping, all four channel-preference combinations, independent receipts, historical rollout, retries, and service-only projection.
- monotonic token generations, one-time fan-out, zero-target completion, target/attempt constraints, service-only private worker grants, concurrent leases, crash reclaim, stale-result rejection, transient scheduling, every terminal outcome, rotation-safe invalid-token cleanup, transfer-before-claim handling, aggregate completion, and protocol-history privacy.
- structured Messages read shape, requester/current-manager authorization, fail-closed exact lookup, Proposal/Tavolo context, private-message isolation, bounded keyset pagination, and routine grants.
- requester-only pending Proposal/Tavolo card projections, public eligibility and filters, deterministic request ordering, resolved/lifecycle omission, sanitized output, and hardened routine grants.
- one-chat-per-participation-request anchoring/backfill, structured-note versus human-message XOR, counterparty-only exact/feed/send access, resolved read-only history, accepted Project-chat continuation, immutable bodies, identifier-only private Realtime, and send/resolution serialization.
- immutable Project-chat message shape, canonical body limits, restrictive foreign keys, RPC-only access, full-history/current/former/rejoin rules, visible-frontier pagination and previews, identifier-only outbox payloads, private Realtime authorization, and send/termination serialization.
- Project-chat notification/push message-time recipients, late-join/leave/rejoin boundaries, zero-to-many event fan-out, independent channel preferences, body-free chat/message context, rollout receipts, Proposal/Tavolo behavior, and projector concurrency/idempotency.
- Scambio-Dona listing shape, exact mode/lifecycle constraints, restrictive ownership, private drafts/closed history, publish/edit/close behavior, rough-location and owner-display privacy, public filters/keyset ordering, and identifier-only audit/outbox payloads.
- Scambio-Dona request shape, exact request lifecycle and active uniqueness, bounded private messages, owner/requester authorization, multiple acceptance, derived public interest counts, retained close history, identifier-only events, PT409 conflicts, and decision/listing/duplicate serialization.
- unified Project/Resource Requests and Chats parity, complete discriminator-aware keysets, strict branch XOR, Resource notification/push references and destinations, canonical counterparty routing, Resources preferences, historical no-backfill receipts, and body-free projection state.
- Project resource-need shape, stable Project foreign keys, exact open/closed semantics, title/details bounds, creator identity, Proposal/Tavolo lifecycle visibility, retained owner history, restrictive grants, identifier-only events, and lifecycle/mutation serialization.
- join-request skill/resource selection shape, restrictive historical foreign keys, duplicate/size bounds, Proposal/Tavolo validation, atomic request creation, requester/manager reads, retained resolved history, current canonical label resolution, unchanged identifier-only events, and need/skill mutation serialization.
- membership-episode skill/resource commitment shape, acceptance seeding, retained ended history and rejoin isolation, participant/manager commitment and addable-option reads, guarded mutation, full-set/no-op semantics, stale-option retention/removal, paused-Tavolo and other lifecycle validity, read-event absence, identifier-only mutation events without notifications, and leave/removal/need/skill serialization.

Run focused commands while the stack is already running:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run auth:verify:local
npm run auth:session:verify:local
npm run profile:verify:local
npm run proposal:verify:local
npm run recurring:verify:local
npm run participation:verify:local
npm run participation:browse:verify:local
npm run project:capacity:verify:local
npm run project:delegates:verify:local
npm run project:workspace:verify:local
npm run notification:verify:local
npm run push:delivery:verify:local
npm run push:verify:local
npm run messages:verify:local
npm run project:chat:verify:local
npm run project:chat:messages:verify:local
npm run project:chat:notifications:verify:local
npm run resource:listings:verify:local
npm run resource:saved-searches:verify:local
npm run resource:saved-search-matching:verify:local
npm run resource:saved-search-notifications:verify:local
npm run resource:listings:requests:verify:local
npm run resource:agreements:verify:local
npm run resource:loan-reservations:verify:local
npm run resource:chat:verify:local
npm run resource:messages-notifications:verify:local
npm run project:resource-needs:verify:local
npm run project:resource-matching:verify:local
npm run project:contribution-selections:verify:local
npm run project:membership-commitments:verify:local
npm run moderation:verify:local
npm run moderation:corroboration:verify:local
npm run moderation:counterstatement:verify:local
npm run blocking:verify:local
npm run moderation:consequences:verify:local
npm run moderation:consequences:concurrency:verify:local
npm run db:types
npm run db:types:check
```

`db:lint` intentionally checks only `public` and `private`, avoiding warnings owned by Supabase-managed schemas or extensions. `db:advisors` runs the local Supabase security advisor, reports warning-or-higher findings, and fails the validation on an error-level security finding. `db:types` regenerates `apps/web/src/types/database.generated.ts` from local `public`; its wrapper propagates CLI failures, rejects empty output, applies the tested PI01 participation RPC nullability contract (`scripts/lib/participation-rpc-nullability.mjs`), and normalizes the terminal newline across hosts. pg-meta cannot infer nullable `RETURNS TABLE` columns, so that bounded correction keeps request origins and new preview/admission/resolution outputs truthful and fails on missing/changed fields. The file is generated output and must not be hand-edited or formatted. `db:types:check` regenerates it and fails on a tracked diff.

`auth:verify:local` requests a numeric email OTP from local Auth, reads the new message through Mailpit's API, verifies the code, and inserts/reads the authenticated user's profile anchor through current RLS. It uses only deterministic `.invalid` test identity data and never prints the email, code, access token, or client key.

`auth:session:verify:local` authenticates three deterministic local users concurrently and binds a separate data client to each verified session token. Each user's first PostgREST request inserts and reads that user's own profile anchor, proving immediate identity-bound RLS behavior without authentication retries or arbitrary waits. It never prints emails, OTPs, session tokens, client keys, Authorization headers, or database credentials.

The repository temporarily pins the exact prerelease Supabase CLI `2.118.0-beta.39` for local and CI validation because it bundles [PostgREST v16.3](https://github.com/PostgREST/postgrest/releases/tag/v16.3), which fixes the upstream sporadic `PGRST303 JWT issued at future` defect present in the prior local runtime. This does not configure staging or production. Replace the prerelease with the first stable CLI that bundles PostgREST v16.3 or later, then run the complete Database workflow before accepting that update.

`profile:verify:local` authenticates two deterministic local users, completes one profile through the canonical operation, and proves owner reads, cross-user denial, stale-form identity rejection, an ineffective cross-user update, and anonymous exact-ID sanitization under mixed visibility. It rejects email/private-field leakage and does not print OTPs, tokens, keys, or addresses.

`profile:photo:verify:local` authenticates two deterministic local users and exercises the real local Supabase Storage API. It proves owner-only immutable WebP uploads/downloads/deletes, rejection of cross-profile paths, unsupported MIME, oversized files, overwrite/update, cross-user reads, and anonymous reads; it also verifies canonical commit, the privacy-preserving `interactions` audience, audience changes that remain private, replacement return values, serialized concurrent commits, clear, and Storage API cleanup. It never prints OTPs, tokens, keys, object contents, or database credentials.

`proposal:verify:local` uses two complete authenticated identities plus anon to prove draft ownership, cross-user and stale-identity rejection, publish/cancel behavior, controlled skills, rough-location discovery, participant-restricted exact-location absence, and public exact-location detail. It never prints test addresses, OTPs, tokens, keys, or exact restricted content.

`recurring:verify:local` uses two complete authenticated identities plus anon to prove Tavolo draft ownership, cross-user and stale-identity rejection, required snapshot pagination, weekly/monthly discovery, participant-restricted exact-location absence, public detail-only exact location, pause/resume/end visibility, preservation of an old schedule when a future version is added, and in-place correction of that pending version. Reference windows are deterministic; the harness performs no realtime waits and never prints addresses, OTPs, tokens, keys, or protected meeting content.

`participation:verify:local` uses a creator, requester, unrelated authenticated user, and anon across one future Proposal and Tavolo. It proves private request review, stale-identity rejection, single acceptance, leave/re-request/reject, pause/resume membership preservation, creator removal/re-request, end-history preservation, protected meeting authorization, and unchanged anonymous detail privacy. It never logs OTPs, tokens, request messages, or protected meeting values.

`participation:browse:verify:local` uses requester A, unrelated user B, and
creator C across multiple future Proposals and one Tavolo. It proves immediate
pending promotion without changing public order, expected-identity isolation,
locality/skill filtering, withdrawal and acceptance removal, pause/resume/end
eligibility, and sanitized card payloads. It never logs OTPs, tokens, keys,
request messages, or protected meeting values.

`project:capacity:verify:local` uses a disposable local Project with two
pending requests and two independent authenticated database transactions to
race the single remaining participant spot. Exactly one acceptance commits;
the other returns `PT409`, the losing request remains pending, and canonical
occupancy never exceeds capacity. Run it only against a reset disposable local
stack; it prints no credentials, request text, private profile data, or
protected meeting information.

`notification:verify:local` uses three complete authenticated identities, a service-role client, and one narrow direct local-database assertion. It proves pre-projection absence, concurrent projector idempotency, request/accept/withdraw/reject/leave mappings, stable request IDs and `participation_request` targets, cross-account denial, structured safe context, unread/read changes, preference suppression with a receipt, later re-enable behavior, and coexistence with an independent synthetic consumer receipt. It never logs OTPs, keys, database URLs, request messages, or protected meeting values.

`notification:project:local` is the narrower native-QA companion. It derives
the service credential only from the current local Supabase status, drains the
service-only notification projector after a tester creates participation
transitions, and prints only processed/created/suppressed aggregate counts. It
must not be embedded in or called by Flutter; the 06B feature README documents
the deterministic local profiles and device-QA sequence.

`push:verify:local` uses three complete authenticated identities, synthetic provider tokens, the two service-only projectors, and narrow local-database assertions. It proves idempotent registration, rotation, account transfer, owner-only unregister, independent in-app/push preferences, concurrent push projection, semantic job privacy, retry idempotency, suppression receipts, consumer coexistence, and unsupported-event preservation. It prints no tokens, keys, request messages, or meeting values.

`push:project:local` is a trusted local helper that derives the service credential only from current local Supabase status, invokes the service-only push projector, and prints aggregate processed/created/suppressed counts. It must never be embedded in or called by Flutter.

`push:delivery:verify:local` is a real direct-database fake worker and must run immediately after a clean reset/pgTAP pass, before integrations create unprepared push jobs. It concurrently prepares synthetic jobs and claims two installations, records fake delivered/transient results, advances the retry schedule without waiting, reclaims under a new lease, rejects the old response, verifies safe attempt history and completion, exercises stale invalid-token rotation protection, retires a transfer-before-claim target, and verifies `no_targets`. It makes no provider/network call and prints no token, credential, database URL, message, or meeting value.

`messages:verify:local` uses a Project creator, requester, unrelated authenticated user, and anon across a Proposal and Tavolo. It proves requester/creator structured reads and private-message visibility, identical unauthorized/missing exact failures, anonymous denial, canonical Accept/Withdraw history, both project contexts, chronology, narrow output, and unchanged public privacy. It never prints OTPs, tokens, keys, request messages, or meeting values.

`project:chat:verify:local` uses a creator, participants A/B, and an unrelated identity with real local Auth plus narrow direct-database assertions. It proves no pre-acceptance chat, first-accept activation, later reuse, concurrent two-request acceptance with one chat, creator/current/former entitlement, half-open leave/removal intervals, a preserved rejoin gap, stable chat identity, unrelated denial, all-members-ended retention, and shared Proposal/Tavolo behavior across pause/resume/end. It logs no OTPs, tokens, database URLs, request messages, meeting details, or secrets.

`project:chat:messages:verify:local` uses four real authenticated clients, private Supabase Realtime Broadcast channels, and narrow direct-database transactions. It proves durable signal reconciliation, full pre-join history, former-member frontiers, rejoin gap visibility, last-visible previews/activity, current-only subscriptions, no post-leave/removal signal, Proposal/Tavolo behavior, identifier-only outbox state, and both serialization outcomes for send versus leave/removal. It logs no OTPs, tokens, database URLs, message bodies, private request text, or meeting details.

`project:request:chat:verify:local` uses a Project creator, requester, and unrelated real authenticated user with private Supabase Realtime Broadcast channels and one narrow direct-database race. It proves atomic request/chat creation, the structured initial note, strict mixed-feed pagination, exact counterparty access, unrelated denial, identifier-only events/hints, send/accept serialization, durable resolved history, and the accepted Project group-chat continuation. It logs no OTPs, tokens, keys, database URLs, request notes, message bodies, or meeting details.

`project:delegates:verify:local` uses four real OTP-authenticated profiles, an anonymous preview client, and narrow direct-database assertions. Its 07C2A race/secrecy evidence remains applicable to the backward-compatible Co-organizer overload; the integration-renumbered pgTAP tests 091–097 cover delegate structure/access, Co-creator/Co-organizer role and provenance, stale-issuer invalidation, participation independence, and authoring/lifecycle behavior. The verifier prints no OTPs, bearer tokens, keys, database URLs, messages, or meeting values.

`project:workspace:verify:local` uses six real OTP-authenticated profiles and
narrow local-database assertions. It proves pre-chat setup, all-manager
replacement, demotion continuity, participant read-only access, leave and
delegate-revocation independence, one-row concurrent replacement, idempotent
clear, anonymous denial, and URL-free generic event payloads. It refuses
non-loopback Supabase targets and prints no URL, OTP, token, key, database URL,
request message, or meeting value.

`project:chat:notifications:verify:local` uses three real authenticated clients,
canonical join/leave/rejoin/send RPCs, both service-only projectors, and narrow
direct-database assertions. It proves send-time Proposal/Tavolo fan-out, sender
exclusion, late-join and former-member exclusion, rejoin targeting, concurrent
idempotent processing, independent Chat in-app/push preferences, safe inbox
chat/message context, complete receipts, and identifier-only/body-free alert
state. It prints no OTPs, tokens, keys, database URLs, message bodies, request
messages, or meeting details.

`resource:listings:verify:local` uses two real authenticated owners, an anonymous client, and narrow direct-database assertions. It proves private incomplete drafts, cross-account denial, publish requirements and idempotency, safe public card/detail shape, display-name visibility, mode/locality/literal-keyword filters, paired newest-first pagination, safe published edits, terminal closure with retained owner history, and identifier-only audit/outbox payloads. It never prints OTPs, tokens, keys, database URLs, listing content, locations, emails, or private profile data.

`resource:saved-searches:verify:local` uses two real OTP identities, an anonymous client, and bounded direct-database predicate assertions. It proves normalized query-only/mode-only/locality-only/all-filter CRUD, cross-profile isolation, exact/list keysets, public-browse parity, literal-not-lexical behavior, hard delete, and one-success/one-`PT409` outcomes for concurrent duplicate creates and updates. It never prints OTPs, tokens, keys, database URLs, or private search content.

`resource:saved-search-matching:verify:local` uses three real OTP identities, two trusted service clients, and narrow direct-database assertions. It proves rollout no-backfill receipts, multi-search/multi-recipient fan-out, self-owned suppression, search-created/edited event-time boundaries, future matching with an exact version token, closed-before-processing suppression, identifier-only chronology-preserving events, notification/push receipt independence, idempotency, and two concurrent bounded workers. It never prints OTPs, tokens, keys, database URLs, private saved-search values, listing content, locations, emails, or payload dumps.

`resource:saved-search-notifications:verify:local` uses two real OTP identities, concurrent notification and push workers, and narrow direct-database assertions. It proves one immediate in-app row and one immediately available push job for two overlapping saved searches, independent global Matching channel preferences, exact receipt coverage, safe inbox shape, current-state suppression after search edits/deletion and listing edits/closure, delivery-history retention, and retry idempotency. It never prints OTPs, tokens, keys, database URLs, private saved-search values, listing content, locations, emails, or payload dumps.

`resource:listings:requests:verify:local` uses an owner, five requesters, an unrelated authenticated identity, anonymous access, and narrow direct-database transactions. It proves four-party interest counts, private owner/requester history, multiple acceptance, rejection, withdrawal, close-time pending resolution with accepted history retention, request-by-ID isolation, identifier-only events, and deterministic accept-versus-withdraw, reject-versus-withdraw, request-versus-close, and duplicate-request serialization. It never prints OTPs, tokens, keys, database URLs, request messages, private emails, or protected profile data.

`resource:agreements:verify:local` uses real authenticated counterparties, an unrelated identity, anonymous access, and narrow direct-database transactions. It proves atomic accepted-request anchors, immutable listing snapshots and counter-proposals, counterparty-only reads, structured two-leg milestones, automatic completion, repeat requests, derived lending overdue truth, pre-handoff cancellation, accepted coordination after listing closure, identifier-only events, and deterministic competing-proposal, accept-versus-counter-proposal, cancel-versus-first-milestone, and final-milestone serialization. It never prints OTPs, tokens, keys, database URLs, private notes, resource descriptions, snapshot descriptions, loan timestamps, emails, contact data, or timeline dumps.

`resource:loan-reservations:verify:local` verifies the 04C4D1 listing-side lending contract with real OTP-authenticated owner/requesters and direct-database concurrency probes. The reservation is derived from accepted current owner LEND terms on an agreed/in-progress agreement, not a second ledger. It checks half-open overlap versus adjacency, replacement, GIVE release, cancellation/completion release, closed-listing retention, owner-only schedule and derived overdue/at-risk, and exact-pending counterpart availability without printing loan dates, terms, OTPs, tokens, keys, private text, or database URLs. The listing row is the serialization anchor; pending checks are informational only. The requester-side free-text LEND leg is not globally reserved, and one listing represents one reservable unit. There is no FIFO entitlement, auto-promotion, timer, or at-risk notification. A migration encountering pre-existing overlapping active owner-side LEND terms fails for manual data resolution rather than silently choosing a winner.

`resource:messages-notifications:verify:local` uses real authenticated owner, requester, and unrelated identities plus narrow direct-database assertions. It proves discriminated Project/Resource Requests and Chats reads, same-UUID domain safety, exact Resource anchors, agreement-aware activity with human-only previews, canonical request/chat/terms/milestone/completion recipients, safe milestone enums, Resources preference suppression, independent receipts, provider-neutral body-free jobs, pre-receipted no-backfill behavior, and unrelated-user denial. It never prints OTPs, tokens, keys, database URLs, request messages, chat bodies, private terms, lending dates, contact details, or inbox dumps.

`project:resource-needs:verify:local` uses a real authenticated creator, an unrelated authenticated identity, an anonymous client, and narrow direct-database transactions across a Proposal and Tavolo. It proves draft/public visibility, stable ordered needs, cross-account and stale-identity denial, updates, terminal closure with owner history, Proposal cancellation, Tavolo pause/resume/end behavior, identifier-only events, and both lifecycle-first and mutation-first lock serialization. It never prints OTPs, tokens, keys, database URLs, need text, emails, or private Project data.

`project:resource-matching:verify:local` uses real OTP identities for a Project creator and a listing owner plus an anonymous client. It checks creator-only access, public-safe explanation/count parity, explicit mode, and read-time closure; pgTAP supplies the lexical, geography, and lifecycle matrix. It does not print OTPs, tokens, database URLs, or private Resource data. The matcher uses built-in Italian FTS without a synonym dictionary, so cross-language or semantically equivalent terms without shared lexemes are not matches. Neither Project event dates nor D1 private loan reservations are availability signals.

`project:contribution-selections:verify:local` uses three real OTP-authenticated identities plus narrow direct-database transactions across Proposals and a Tavolo. It proves required/useful Proposal selections, resource-only Tavolo behavior, invalid skill/resource rejection, requester/creator-only reads, backward-compatible empty selections, mandatory exact acceptance triage, exact decision/commitment subsets, post-acceptance commitment edits without history rewrites, independent rejoins, chat activation, identifier-only events, and both serialization outcomes for needed acceptance versus resource closure/Proposal-skill removal plus withdrawal-first request serialization. It never prints OTPs, tokens, keys, database URLs, request messages, selection/decision labels, emails, or private Project data.

`project:membership-commitments:verify:local` uses three real OTP-authenticated identities plus narrow direct-database transactions across Proposals and a Tavolo. It proves atomic acceptance seeding, participant/creator-only current and ended reads, authorized addable-option snapshots including paused Tavoli and stale-option omission, full desired-set replacement and no-op preservation, creator clearing, stale-option retention/removal, independent rejoin episodes, Proposal/Tavolo lifecycle rules, read-event absence, exact identifier-only mutation events without notifications, and both serialization outcomes for replacement versus leave, removal, resource closure, and Proposal-skill removal. It never prints OTPs, tokens, keys, database URLs, request text, commitment labels, emails, or private Project data.

The membership verifier refuses non-loopback API, PostgreSQL and Mailpit URLs;
the project-scoped CLI status remains the source of backend endpoints. Each
race runs one pending HTTP loser against a fresh fixture while the authenticated
SQL winner holds its canonical locks. It releases the winner only after
`pg_stat_activity` reports one lock waiter whose `pg_blocking_pids` includes that
exact winner PID. Pending promises, unrelated/ambiguous waits and observer-query
failures cannot satisfy the assertion. RPC-name matching is intentionally absent:
wide PostgREST query text can be truncated before the function name. Observation
has a monotonic 10-second deadline with 20 ms polling; local SQL statements and
the leave/removal HTTP losers have 15-second timeouts. These are verifier-only
limits, not domain retries or production configuration.

For a bounded campaign, run
`npm run project:membership-commitments:verify:local -- --race-iterations=10`.
No argument means one iteration; only integers 1–20 are accepted. Each iteration
creates four new accepted memberships for both leave/removal versus replacement
orders. Other verifier flows still run once. The first failure stops the campaign;
it never retries the failed operation. Failure-only evidence contains the operation,
order/stage, synthetic membership/actor IDs, exact membership timestamps, database
clock samples, observed lock PIDs and identifier-scoped occupancy/coverage/event
counts. Committed row snapshots are explicitly distinguished from a failed UPDATE
tuple. Only the known eight-field constraint tuple is parsed from error details;
unexpected/missing details remain unavailable, never raw payloads. The parser
compares timestamps at microsecond precision and identifies each violated clause.
The original DEPSEC-01 `23514` remains unresolved; see
[DBRACE-01 evidence and limits](dbrace01-membership-end-state-regression.md).

`demo:seed:local` is the explicit trusted local demo-world command. It reuses
the authenticated-user helper and canonical domain/media RPCs, coordinates
concurrent runs with one database advisory lock, uploads vendored WebP profile
and cover fixtures through authenticated Storage, refreshes only the relative
Proposal clock fields, and drains the existing notification projector. Exact
legacy `DEMO · ...` titles owned by the expected demo identities are adopted in
place; ambiguous matches fail, and direct local SQL is used only for this
narrow migration plus frozen-history repair. `demo:verify:local` checks the
connected read/security/media contract. `demo:reset:local` deliberately runs
the existing local-only database reset before seeding; normal `db:reset` still
does not auto-seed demo rows. The commands reject remote and production targets,
work offline after checkout, and never print OTPs, credentials, protected
locations, or message bodies.

`moderation:verify:local` authenticates a reporter, reported profile, and staff
profile through real local OTP sessions. It proves ordinary-user queue denial,
public-profile report submission, reporter-only status, reported-user
isolation, operator-provisioned staff access, detail/note/state operations,
identifier-only generic audit/outbox behavior, and immediate denial after role
deactivation. It never prints emails, OTPs, tokens, keys, database URLs, report
explanations, note bodies, or moderation records.

`moderation:corroboration:verify:local` authenticates a Project reporter,
reported profile, creator, eligible member, and staff profile. It creates a
deterministic local membership cohort, proves reporter-anonymous recipient
detail, exact response retry, reported-subject denial, staff-only identified
evidence, completed-case pending suppression, and the absence of sensitive
audit/outbox projection. It prints no emails, OTPs, tokens, keys, database
URLs, report wording, response content, or evidence records.

`moderation:counterstatement:verify:local` authenticates canonical Resource
counterparties, an unrelated profile, and staff. It proves automatic request
creation, subject-only reporter-anonymous detail, exact immutable retry,
unrelated/reporter denial, staff-only pending/submitted evidence, unchanged
Resource-domain state, and body-free audit/outbox records. It prints no emails,
OTPs, tokens, keys, database URLs, report wording, statement content, or
evidence records.

`blocking:verify:local` uses direct local authenticated transactions and holds
the canonical pair lock across four contenders. It proves block-first Project
and Resource request creation waits, returns `PT409`, and leaves no pending row;
it also proves Project and Resource acceptance that commits first is preserved
as current membership or open agreement/chat when the subsequent block
activates. It prints no identities, tokens, messages, or database URL.

`auth:web:verify:local` adds web-specific evidence after a locally configured production Next.js build. It obtains session cookies through supported `@supabase/ssr` callbacks, confirms the Server Component recognizes the authenticated session, rejects private-auth material in the rendered response, and confirms `/admin` returns 404 for signed-out and ordinary signed-in requests. It does not invent or log Supabase's cookie encoding.

`tavoli:web:verify:local` uses synthetic local OTP data and the production Next.js server to prove signed-out Tavoli list/detail rendering, rough-location and next-meeting output, exclusion of paused/ended rows from discovery, retained sanitized historical detail, exact-ID 404 behavior, and detail-only public/restricted exact-location handling. It never prints test addresses, tokens, keys, or protected meeting content.

`npm run check:db` performs reset, lint, advisors, pgTAP, the real fake push-delivery worker protocol, the mobile/backend Auth check, the deterministic immediate-session/RLS check, the two-user profile visibility check, the proposal privacy/lifecycle check, the recurring activity recurrence/privacy/lifecycle check, the multi-user Project participation, delegate, shared-workspace, participation-request chat, and participation-aware Browse checks, notification/push projection, structured Messages integration, Project-chat lifecycle/message/notification integrations, the Scambio-Dona listing, saved-search, request, agreement, chat, and unified Messages/notification integrations, the Project resource-need and matching integrations, contribution-selection, acceptance-triage, membership-commitment, coverage, resurfacing, and actual-contribution integrations, moderation evidence integrations, user-block pair-serialization races, type regeneration, and drift detection as one validation sequence. It assumes `npm run db:start` has already succeeded and leaves stack lifecycle to the caller. CI additionally generates local web configuration, builds Next.js, runs the web-session and public Tavoli integrations, and always stops Supabase.
