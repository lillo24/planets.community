# PLANETS 06A — Notification Domain and Outbox Projection Foundation

**Roadmap area:** PLANETS 06 — Notification Backbone  
**Task type:** Canonical backend/domain foundation before notification UI or external push delivery  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known merged 05B base when this prompt was written:** `09d62276faec4c50ab5d45cd3930975c5a49a6b7`

## Objective

Implement the canonical notification domain and the first deterministic projection from existing PLANETS outbox events into durable **in-app notification records**.

This is **06A only**.

After this task:

- notifications have one canonical PostgreSQL representation;
- notification categories/preferences are centralized;
- existing participation outbox events can be projected idempotently into recipient-specific notification records;
- multiple concurrent projector calls cannot duplicate notifications;
- notification projection has its own consumer receipt and does not hijack the outbox for future chat/analytics consumers;
- users have narrow authenticated APIs for:
  - listing their notifications;
  - unread count;
  - marking one notification read;
  - marking all notifications read;
  - reading/updating category preferences;
- notification records contain semantic IDs/state, not private request messages or protected meeting data;
- inbox reads can expose only safe presentation context such as project title/kind and authorized actor display name;
- unsupported outbox event types are ignored without blocking or being falsely consumed by the notification projector;
- no push delivery, FCM, device token, Flutter inbox, email notification, matching notification, resource notification, or chat notification is implemented yet.

Split Plan 06 into:

- **06A — Notification Domain and Outbox Projection Foundation** — this task;
- **06B — Mobile In-App Notifications and Preferences** — future;
- **06C — Device Registration and FCM Push Delivery** — future.

Do not merge the PR from the implementation task.

Before implementation, preserve this exact prompt unchanged at:

```text
history-implementations/PLANETS_06A_notification_domain_outbox_projection_foundation.md
```

---

# Repository state and required inspection

Work from the latest merged `main`.

Before changing anything, inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/core-stack.md`;
3. `docs/architecture/system-design.md`;
4. `docs/architecture/product-decisions.md`;
5. `docs/development/database.md`;
6. `docs/development/codex-tooling.md`;
7. `docs/implementation/roadmap.md`;
8. `supabase/migrations/20260901211937_identity_audit_outbox_primitives.sql`;
9. all current uses of `private.outbox_events`;
10. the merged 05A participation migration and tests;
11. the merged 05B mobile feature only for future deep-link/route context;
12. current generated database types;
13. database integration scripts and package scripts;
14. `.github/workflows/validation.yml`.

Important current facts:

- 05A is merged.
- 05B is merged in PR #16 at `09d62276faec4c50ab5d45cd3930975c5a49a6b7`.
- PR #16 automated Mobile, Web, and Database CI are green.
- Preserve the repository’s actual manual-native-QA status for 05B; do not invent a QA result while updating documentation.
- 05C remains future work and depends on Resources/Scambio-Dona semantics.
- 05C must **not** block Plan 06.
- Existing `private.outbox_events` is a transaction-local handoff primitive with:
  - UUID event identity;
  - `event_type`;
  - JSON object payload;
  - `created_at`;
  - `available_at`;
  - nullable `published_at`.
- The outbox is private and has no Data API/client grants.
- Existing Proposal, Tavolo, and participation mutations already write outbox events.
- Current participation events include:
  - `project.join_requested`;
  - `project.join_request_withdrawn`;
  - `project.join_request_accepted`;
  - `project.join_request_rejected`;
  - `project.participant_left`;
  - `project.participant_removed`.
- `project.join_request_accepted` remains a candidate signal for Plan 07 chat, but Plan 07 owns the exact chat trigger.
- Therefore notification processing must **not** make these outbox events unavailable to a future independent consumer.
- No `supabase/functions` feature exists yet; do not add external worker infrastructure merely because a later plan will need it.

Use Supabase/Postgres skills and current official guidance where useful, but repository contracts and tests are authoritative.

---

# Architecture principle

There are three distinct concepts:

```text
Domain event
    ↓
private.outbox_events

Notification projection
    ↓
recipient-specific canonical notification

Push delivery
    ↓
device/provider attempts
```

06A owns only the first transition:

```text
outbox event -> in-app notification record
```

06C will later own:

```text
notification -> FCM delivery attempts
```

Do not make Firebase the canonical notification store.

Do not make Flutter responsible for interpreting raw outbox events.

Do not write notification rows directly inside every existing participation mutation.

The notification domain should project centrally from committed domain events.

---

# 1. Notification categories

Introduce a controlled system-managed category catalog or an equivalently strict centralized representation.

At minimum establish categories capable of supporting the accepted product direction:

```text
participation
project_activity
matching
chat
resources
```

Only `participation` needs to generate notifications in 06A.

The remaining categories are forward-compatible placeholders for later owning plans; do not fabricate events for them.

A strong model may include:

- category slug;
- stable sort order;
- default in-app enabled;
- default push enabled;
- whether user-configurable.

Exact schema is Codex-owned.

Do not use free-form user-created categories.

Do not introduce email as a normal product-notification channel. Current system direction reserves ordinary email primarily for Auth/security/exceptional account communication.

---

# 2. Notification preferences

Add per-profile category preference overrides.

A user should not need rows for every category in order for defaults to work.

Prefer a model equivalent to:

```text
notification_categories
profile_notification_preferences
```

with absent profile override meaning “use category default”.

Store enough future channel information for 06C, for example:

```text
in_app_enabled
push_enabled
```

but 06A does not deliver push.

## Required semantics

- profile owns only their preferences;
- category defaults apply when no override exists;
- new future categories can be introduced without old clients sending a complete replacement set;
- one profile/category has at most one override;
- preference changes do not delete existing notification history;
- disabling a category affects future projection/delivery, not already-created notification rows.

Prefer one narrow per-category mutation such as:

```text
set_own_notification_preference(
  expected_profile_id,
  category,
  in_app_enabled,
  push_enabled
)
```

rather than a replace-all operation that could erase categories unknown to an older client.

Exact signature is Codex-owned.

---

# 3. Canonical notifications

Add a durable user-owned notification table.

A notification represents:

> one recipient-specific semantic notification derived from one canonical source event.

At minimum preserve:

- notification UUID;
- recipient profile ID;
- category;
- notification kind;
- source outbox event ID;
- optional project ID;
- optional actor profile ID;
- optional request/membership IDs when genuinely needed;
- created timestamp;
- read timestamp.

Exact fields are Codex-owned.

## Semantic, not rendered-copy storage

Prefer semantic notification state over storing a fully rendered English sentence.

Example:

```text
kind = participation_request_received
project_id = ...
actor_profile_id = ...
```

The future client can localize:

```text
Alex requested to join Community Garden
```

without making English copy canonical database state.

The inbox read API may return safe resolved context such as:

- project kind;
- current project title;
- actor display name where the recipient is authorized to know it.

Do not persist or expose:

- join-request message;
- exact meeting text;
- exact coordinates;
- profile bio;
- Auth email;
- tokens;
- device identifiers;
- chat message body;
- arbitrary source-event JSON.

## Kinds for current participation events

Map current 05A outbox events to stable notification kinds equivalent to:

```text
participation_request_received
participation_request_withdrawn
participation_request_accepted
participation_request_rejected
participant_left
participant_removed
```

Exact enum/text names are Codex-owned.

All belong to category:

```text
participation
```

Do not create notification kinds for Proposal/Tavolo publication unless a concrete recipient/product rule exists.

---

# 4. Recipient mapping

Implement one central trusted mapping for currently supported events.

Use canonical database rows to validate/resolve recipients rather than trusting arbitrary payload text.

## `project.join_requested`

Recipient:

```text
project creator
```

Actor:

```text
requester
```

Suggested structured destination:

```text
project_participation
```

## `project.join_request_withdrawn`

Recipient:

```text
project creator
```

Actor:

```text
requester
```

Destination:

```text
project_participation
```

## `project.join_request_accepted`

Recipient:

```text
requester / accepted participant
```

Actor:

```text
project creator
```

Destination:

```text
project_detail
```

## `project.join_request_rejected`

Recipient:

```text
requester
```

Actor:

```text
project creator
```

Destination:

```text
project_detail
```

## `project.participant_left`

Recipient:

```text
project creator
```

Actor:

```text
participant who left
```

Destination:

```text
project_participation
```

## `project.participant_removed`

Recipient:

```text
removed participant
```

Actor:

```text
project creator
```

Destination:

```text
project_detail
```

Do not generate a notification when recipient resolution is impossible or contradicts canonical state.

Fail safely and surface the projection problem to the trusted caller/tests rather than sending to a guessed recipient.

---

# 5. Structured deep-link target

Do not store literal Flutter URLs as canonical notification data.

Store/derive a small structured target such as:

```text
destination_kind = project_detail | project_participation
project_id
project_kind
```

`project_kind` is already available through the shared `projects` registry.

06B will map this structured target onto current concrete routes:

```text
/proposals/:id
/tavoli/:id
/proposals/:id/participants
/tavoli/:id/participants
```

This keeps backend notification semantics independent of later Progetti UI reorganization.

Do not implement deep-link navigation in 06A.

---

# 6. Idempotency and multi-consumer outbox semantics

This is a critical architecture requirement.

The existing `private.outbox_events.published_at` is **not sufficient as a per-consumer acknowledgement** once multiple downstream consumers exist.

Future consumers may include:

- notifications;
- automatic chat provisioning;
- analytics/operational projections.

Do not make notification projection “consume” the event in a way that prevents Plan 07 from independently observing it.

Introduce a generic private consumer-receipt mechanism, preferably equivalent to:

```text
private.outbox_consumer_receipts
```

with concepts such as:

```text
outbox_event_id
consumer_key
processed_at
```

and a unique/primary key equivalent to:

```text
(outbox_event_id, consumer_key)
```

Use a stable notification projector consumer key, for example:

```text
notifications.v1
```

Exact naming is Codex-owned.

## `published_at`

Do not repurpose or remove the existing field casually.

Document its status clearly.

For 06A, notification idempotency should rely on consumer-specific receipt + notification uniqueness, not a global published flag.

If repository evidence supports a safe generic definition for `published_at`, document it without making it a destructive single-consumer acknowledgement.

## Notification uniqueness

Also enforce a database-level uniqueness invariant so the same source event cannot create duplicate notification rows for the same recipient/kind.

Do not rely only on the receipt table.

---

# 7. Projector operation

Implement a trusted batch projection operation.

A strong design is a function equivalent to:

```text
process_notification_outbox_batch(limit)
```

that:

1. selects only supported notification-source event types;
2. requires `available_at <= now()`;
3. ignores already-receipted events for `notifications.v1`;
4. uses row locking / `FOR UPDATE SKIP LOCKED` or an equivalent concurrency-safe design;
5. resolves canonical recipient/context;
6. checks the recipient’s effective in-app category preference;
7. inserts zero or one appropriate notification for the event;
8. records the notification consumer receipt;
9. returns only operational counts/IDs suitable for a trusted worker.

The operation must be safe under:

- two concurrent callers;
- process retry after success response is lost;
- existing duplicate source-event attempt;
- preference-disabled recipient.

## Preference-disabled events

If effective `in_app_enabled = false`:

- create no notification;
- record the event as successfully processed by the notification consumer.

Otherwise the same disabled event would be reconsidered forever.

The historical source event remains intact.

## Execution grants

Do not expose projector execution to:

```text
anon
authenticated
```

If the operation must live in `public` to be callable later by a service worker/Edge Function, grant execution only to a trusted role such as `service_role` and test denial for ordinary API roles.

A private internal function plus a narrowly exposed service-role wrapper is acceptable.

Do not use service-role credentials in mobile or web clients.

---

# 8. Unsupported events

The outbox already contains events that are not notification sources.

The projector must filter to its explicitly supported event types.

Do not:

- mark every outbox event as notification-processed;
- fail because `proposal.published` is not mapped;
- repeatedly scan irrelevant events inefficiently;
- invent notifications without recipient rules.

Future owning plans may add mappings with migrations.

When a future event type becomes supported, that plan must decide explicitly whether historical pre-support events should be backfilled. 06A does not automatically notify users about old events.

---

# 9. Inbox read API

Provide a narrow authenticated inbox list operation.

Use cursor/keyset pagination.

A likely contract:

```text
list_own_notifications(
  expected_profile_id,
  limit,
  cursor_created_at?,
  cursor_id?
)
```

Order:

```text
created_at DESC, id DESC
```

Return at least:

- notification ID;
- category;
- kind;
- created_at;
- read_at;
- project ID;
- project kind;
- structured destination kind;
- project title where resolvable;
- actor display name where authorized/resolvable.

Do not return raw source payload.

## Actor display identity

This is a recipient-private workflow.

For participation notifications, recipient already has a legitimate participation relationship to the actor:

- creator reviewing requester;
- requester receiving creator decision;
- creator observing participant leave;
- removed participant observing creator action.

It is acceptable for the inbox projection/read boundary to return the relevant current display name even if anonymous profile visibility would hide it, as long as this remains a narrow authenticated workflow.

Do not weaken `get_public_profile`.

If actor display name later becomes unavailable due to deletion/anonymization, return null/generic context safely.

## Project title

Resolve through the shared `projects` registry to the concrete Proposal/Tavolo.

Do not duplicate project title into the shared project registry.

A notification must remain readable even if display context cannot be resolved; return safe nullable context rather than leaking/throwing unnecessarily.

---

# 10. Unread and read operations

Provide narrow authenticated operations for:

```text
get_own_unread_notification_count
mark_notification_read
mark_all_notifications_read
```

Exact names are Codex-owned.

Requirements:

- expected profile identity bound to `auth.uid()`;
- user cannot mutate another recipient’s notification;
- marking read is idempotent;
- repeated mark-all is idempotent;
- `read_at` never moves backwards;
- no unread count from another user can be inferred.

Do not add notification deletion in 06A.

Retention/deletion policy belongs to later privacy/account-deletion work.

---

# 11. Preference read API

Provide:

```text
list/get_own_notification_preferences
```

returning all current controlled categories with effective values, even when the profile has no override row.

Future 06B should not need to know category database defaults itself.

Return concepts such as:

- category slug;
- effective in-app enabled;
- effective push enabled;
- whether an explicit override exists if useful.

Do not store localized UI copy in database unless repository conventions strongly justify it.

---

# 12. Security / RLS

Apply the established fail-closed model.

## Notification table

Authenticated users may read only their own notifications through the chosen narrow boundary.

Prefer:

- RLS enabled;
- no direct insert/update/delete grants;
- named read/mutation functions for inbox operations.

If direct own-row select is materially simpler and remains safe, justify it; RPC boundaries are preferred for normalized presentation context.

## Preferences

Profile owners can access/mutate only their own preferences.

Expected-identity-bound RPC remains authoritative.

## Private projection infrastructure

Keep:

- outbox consumer receipts;
- projector helper state;
- source outbox;

outside ordinary Data API access.

No anon/authenticated grants.

All `SECURITY DEFINER` functions:

- fixed/empty `search_path`;
- fully qualify objects;
- have explicit execute grants;
- reject unauthorized identities/roles centrally.

Index all policy/FK/cursor paths.

---

# 13. Audit behavior

Notification read/unread changes do not need security audit events by default.

Preference changes may be ordinary product state and likewise need not generate audit noise unless current repository policy says otherwise.

Do not recursively write notification outbox events when projecting notifications.

Avoid an event loop:

```text
outbox -> notification -> outbox -> notification...
```

Projection receipts are operational state, not user-visible audit history.

---

# 14. Current notification privacy rules

06A must never put the following into notification rows, projector receipts, or inbox payloads:

- join-request message;
- exact meeting text;
- exact location coordinates;
- email;
- OTP;
- session/access/refresh tokens;
- profile bio;
- chat message body;
- arbitrary resource description;
- raw provider/backend errors.

For future push previews, 06C should be able to produce a generic safe preview using notification kind even when the device is locked.

06A should therefore not require sensitive content to make a notification intelligible.

---

# 15. No notification UI in 06A

Do not add Flutter notification inbox/settings yet.

Do not add:

- bell icon;
- unread badge;
- notification route;
- notification deep-link handling;
- preferences toggles;
- mobile polling/realtime;
- push permission prompt.

These belong to 06B/06C.

Allowed client changes:

- generated database types;
- compile fixes caused by generated schema;
- no feature UI.

---

# 16. No FCM/device infrastructure in 06A

Do not implement:

- Firebase Messaging SDK;
- device token table;
- APNs registration;
- FCM service account;
- Edge Function push worker;
- delivery attempts/retry table;
- push permission UI;
- production secrets;
- email product notifications.

06C owns these.

06A should leave clear canonical data for 06C to consume later.

---

# 17. Database tests

Add comprehensive pgTAP coverage.

At minimum test:

## Categories/preferences

- controlled categories exist;
- category uniqueness;
- defaults work without profile override rows;
- owner can read effective preferences;
- owner can update one category;
- cross-account preference reads/mutations fail;
- unknown category fails;
- new override does not affect other categories.

## Notifications

- notification table constraints;
- recipient FK;
- supported kind/category consistency;
- source outbox FK;
- cursor indexes;
- own-only privacy;
- ordinary clients cannot insert/update arbitrary notification rows;
- source payload/private data is not copied.

## Consumer receipts

- generic receipt table is private;
- one receipt per event/consumer;
- notification consumer key stable;
- receipt cannot be client-written;
- notification projector does not prevent a different consumer key from later receiving the same event.

## Projector mapping

For every current participation event:

- correct recipient;
- correct kind;
- correct category;
- correct structured destination;
- project kind resolved correctly for Proposal and Tavolo where applicable.

## Idempotency/concurrency

- same event processed twice produces one notification;
- two projector calls cannot duplicate;
- existing notification + retried projector cannot duplicate;
- preference-disabled event creates no notification but is receipted;
- unsupported outbox event remains untouched by notification consumer.

## Read state

- unread count;
- mark one read;
- repeated mark read;
- mark all;
- cross-user mark denied;
- pagination order stable.

## Privacy

Assert notification/inbox records contain none of:

- private request message;
- exact meeting text/location;
- email;
- source JSON blobs.

## Grants

- anon cannot read notification/preferences;
- authenticated cannot execute service projector;
- service-role projector grant only if required;
- security-definer search paths hardened.

---

# 18. Real local integration harness

Add a focused script, preferably:

```text
scripts/verify-local-notifications.mjs
```

Use current Auth/profile/project/participation helpers where practical without turning tests into a shared framework project.

Use:

- creator A;
- requester B;
- unrelated C.

Prove at minimum:

1. B requests to join A’s project;
2. no notification exists before projector runs;
3. trusted projector processes event;
4. A receives exactly one `participation_request_received`;
5. C cannot read A/B notifications;
6. rerunning projector creates no duplicate;
7. A accepts B;
8. projector creates exactly one accepted notification for B;
9. B reads inbox context and structured project target;
10. B marks notification read and unread count changes;
11. preference disable for participation prevents a later in-app notification;
12. disabled event is still notification-consumer receipted;
13. re-enable affects future events only;
14. withdrawal/rejection path maps correctly;
15. participant-left or participant-removed path maps correctly;
16. notification payload/read output contains no private request message or exact meeting information;
17. another synthetic consumer receipt can coexist for the same source outbox event, proving multi-consumer semantics.

Do not print:

- OTPs;
- tokens;
- request messages;
- protected meeting data.

Use deterministic identifiers/timestamps where feasible.

---

# 19. Validation

Keep all current checks green:

- migration replay from zero;
- DB lint;
- all pgTAP tests;
- Auth integration;
- profile integration;
- Proposal integration;
- recurring activity integration;
- participation integration;
- new notification integration;
- public web Tavoli integration;
- generated database types and zero drift;
- Flutter localization/format/analyze/tests;
- Web tooling/tests/lint/typecheck/build;
- `git diff --check`.

No external Firebase/provider account is required.

---

# 20. Documentation and roadmap reconciliation

Update:

- `docs/architecture/system-design.md`;
- `docs/development/database.md`;
- `docs/implementation/roadmap.md`;
- Supabase README/package scripts where needed.

## 05B status

Mark 05B **Implemented** with PR #16 / merge SHA:

```text
09d62276faec4c50ab5d45cd3930975c5a49a6b7
```

Preserve the actual manual native QA status from repository evidence; do not manufacture a pass/fail value.

05C remains `Not started`.

Parent 05 may remain `In progress` because 05C exists, but this must not block Plan 06.

## Split Plan 06

Record:

### 06 — Notification Backbone (parent)

`In progress`

### 06A — Notification Domain and Outbox Projection Foundation

`In progress`

### 06B — Mobile In-App Notifications and Preferences

`Not started`

Future scope:

- Flutter inbox;
- unread badge;
- mark read/all;
- preference UI;
- structured project navigation/deep links;
- safe refresh/realtime strategy.

### 06C — Device Registration and FCM Push Delivery

`Not started`

Future scope:

- device token lifecycle;
- platform/installation metadata;
- notification delivery jobs/attempts;
- FCM worker;
- retries/backoff/idempotency;
- invalid-token cleanup;
- secret/config separation;
- push permission integration;
- safe previews;
- local/staging no-production-send protections.

## Dependencies

Clarify that 06A depends on implemented participation events (05A) and core identity/outbox foundations, **not on 05C**.

04C Resources + Scambio-Dona remains independent.

Plan 07 chat should depend on the required completed notification portions, but do not decide its exact trigger in 06A.

---

# Non-goals

Do not implement:

- Flutter notification UI;
- web notification UI;
- push/device registration;
- FCM/APNs;
- email product notifications;
- realtime notification subscription;
- matching notifications;
- resource/Scambio-Dona notifications;
- chat notifications;
- project reminder/calendar notifications;
- notification deletion/retention cleanup;
- analytics;
- final chat trigger;
- 05C contribution verification;
- 04C resources;
- final unified Progetti UI.

---

# Acceptance criteria

06A is ready for review when:

- [ ] based on latest merged `main`;
- [ ] exact prompt archived;
- [ ] notification categories are centralized/controlled;
- [ ] per-profile category defaults + overrides work;
- [ ] canonical recipient-specific notification records exist;
- [ ] current six participation event types have explicit notification mapping;
- [ ] unsupported event types are not accidentally consumed;
- [ ] notification rows contain semantic safe state, not private source content;
- [ ] structured project destination is backend-route-agnostic;
- [ ] generic per-consumer outbox receipts exist;
- [ ] notification processing does not prevent future independent consumers;
- [ ] projector is concurrency-safe and idempotent;
- [ ] disabled in-app preference suppresses future projection and records successful consumer processing;
- [ ] inbox list is keyset paginated;
- [ ] unread count/read-one/read-all work;
- [ ] inbox can return safe project/actor presentation context;
- [ ] cross-account notification/preference access fails;
- [ ] ordinary clients cannot execute projector;
- [ ] no FCM/device/mobile UI is introduced;
- [ ] pgTAP coverage passes;
- [ ] real local notification projection integration passes;
- [ ] generated types have zero drift;
- [ ] existing Mobile/Web/Database CI stays green;
- [ ] roadmap records 06A/06B/06C split and 05B merge;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide ordinary implementation details such as:

- exact category/kind table vs checked-text representation;
- exact notification table name;
- receipt table name;
- projector helper decomposition;
- service-role wrapper shape;
- cursor page size;
- exact semantic destination enum/text;
- nullable context columns;
- indexes;
- whether effective preferences are returned via SQL function/view.

Stop and report before:

- marking outbox globally consumed in a way that prevents future consumers;
- storing private join messages/exact locations in notifications;
- granting projector to authenticated/anon;
- adding Firebase/device infrastructure;
- adding Flutter notification UI;
- changing participation event semantics;
- implementing matching/resource/chat notifications;
- making 05C a prerequisite for 06A;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 06A prompt;
2. controlled notification categories;
3. per-profile preference override model;
4. canonical notification schema;
5. generic outbox consumer-receipt mechanism;
6. current participation event-to-notification mapping;
7. concurrency-safe/idempotent notification projector;
8. safe structured project targets;
9. inbox list/unread/read APIs;
10. preference read/update APIs;
11. RLS/grant/security-definer hardening;
12. pgTAP tests;
13. real local notification integration harness;
14. generated database types;
15. documentation/roadmap 06A/06B/06C split;
16. focused PR, preferably `codex/06a-notification-domain-outbox-projection`;
17. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Notification category design**
5. **Preference model**
6. **Notification schema**
7. **Semantic notification kinds**
8. **Participation-event recipient mapping**
9. **Structured destination model**
10. **Outbox multi-consumer receipt design**
11. **Projector concurrency/idempotency**
12. **Preference suppression behavior**
13. **Inbox list/pagination**
14. **Unread/read operations**
15. **Safe presentation context**
16. **RLS/grants/security**
17. **Privacy guarantees**
18. **pgTAP tests**
19. **Real notification integration**
20. **Generated types/drift**
21. **Existing regression validation**
22. **05B roadmap reconciliation**
23. **06B handoff**
24. **06C handoff**
25. **Warnings/blockers for Plan 07**
26. **Commit/PR reference**

Do not report Flutter notification UI, FCM/device delivery, matching/resource/chat notifications, 05C, or 04C as implemented.
