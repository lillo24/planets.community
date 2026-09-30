# PLANETS 04C4C2 — Unified Messages Projections + Resource Notification Projection

**Roadmap area:** 04C4C — Resource Requests + Messages  
**Task type:** Backend Messages projection + notification/push-job projection  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open Scambio-Dona stack:

```text
PR #73 — 04C4C1 Accepted Resource-Request Conversation Domain + Realtime
branch: codex/04c4c1-resource-request-conversation-domain
head:   39d8882ad0947b60dfd695ab863d3299cf612daa
```

PR #73 is currently draft and intentionally blocked by the inherited database-validation gate.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #73 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #73 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c2-resource-messages-notifications
```

Open the new PR with base:

```text
codex/04c4c1-resource-request-conversation-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C2_unified_messages_resource_notification_projection.md
```

No external document is required by Codex.

---

# Objective

Connect the canonical Scambio-Dona request/chat/agreement backend to the existing **Messages** and **notification/push-job** foundations without implementing the full Flutter Scambio experience yet.

This slice should provide:

```text
Messages / Requests
→ one unified paginated projection
   for Project participation requests
   + Scambio-Dona resource requests

Messages / Chats
→ one unified paginated projection
   for Project group chats
   + accepted resource-request chats

Resources notifications
→ request events
→ resource-chat messages
→ meaningful exchange/agreement transitions
```

The canonical domain tables remain the source of truth.

Do not create duplicate request/chat state merely for Messages.

---

# 1. Preserve existing domain RPCs

Do not remove or break:

```text
list_own_participation_request_message_items
get_own_participation_request_message_item

list_own_project_group_chats

04C4A exact/history request RPCs
04C4C1 resource chat RPCs
```

Current mobile clients still use the existing Project-specific RPCs.

Add new unified projections alongside them.

This is important for backward compatibility and stacked development.

---

# 2. Unified structured-request Messages projection

Add a read-only projection equivalent to:

```text
list_own_structured_request_message_items(
  p_expected_profile_id uuid,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_request_id uuid default null
)
```

Supported `item_kind`:

```text
participation_request
resource_request
```

Limit:

```text
1..50
```

---

# 3. Structured-request cursor

Use a complete cross-kind keyset:

```text
(activity_at, item_kind_order, request_id)
```

Newest first.

Define stable kind ordering, e.g.:

```text
participation_request = 0
resource_request      = 1
```

The caller supplies the wire `item_kind`; backend maps it to the canonical ordering.

Require either:

```text
all cursor values null
```

or:

```text
all cursor values supplied
```

Do not paginate the two domains separately and merge client-side.

---

# 4. Participation request activity semantics

Preserve the existing 07A behavior exactly:

```text
activity_at = coalesce(resolved_at, created_at)
```

Do not change existing Project participation request semantics.

---

# 5. Resource request activity semantics

For resource requests, define:

```text
activity_at =
greatest(
  created_at,
  coalesce(resolved_at, created_at),
  coalesce(coordination_closed_at, created_at)
)
```

Meaning:

- creation appears in Requests;
- accept/reject/withdraw/listing-close updates it;
- later agreement completion/cancellation may move the historical accepted request once when coordination closes;
- ordinary resource-chat messages and agreement negotiation do **not** repeatedly bubble the Requests tab.

Those belong in the Chats tab.

---

# 6. Strict discriminated request row

Return a single strict row shape with:

```text
item_kind
request_id
viewer_role

requester_profile_id
requester_display_name

status
request_message
created_at
resolved_at
activity_at

// Project branch
project_id
project_kind
project_title
project_creator_profile_id
project_creator_display_name

// Resource branch
resource_listing_id
resource_listing_mode
resource_listing_title
resource_listing_lifecycle
resource_owner_profile_id
resource_owner_display_name
resource_chat_id
resource_agreement_id
coordination_closed_at
```

Exact naming may follow repository conventions.

---

# 7. Request-row XOR contract

For:

```text
item_kind = participation_request
```

Require Project fields and null Resource fields.

For:

```text
item_kind = resource_request
```

Require Resource fields and null Project fields.

`resource_chat_id` / `resource_agreement_id` are:

- null before acceptance;
- non-null for accepted requests under the 04C4B/C1 invariant.

Do not fabricate chat/agreement IDs for rejected/withdrawn/listing-closed requests.

---

# 8. Resource request viewer role

Use:

```text
requester
owner
```

Participation requests preserve:

```text
requester
creator
```

The client must discriminate using `item_kind` before interpreting role values.

---

# 9. Unified exact structured-request read

Add:

```text
get_own_structured_request_message_item(
  p_expected_profile_id uuid,
  p_item_kind text,
  p_request_id uuid
)
```

Authorize exactly through the canonical underlying domain.

Fail closed for:

- unknown item kind;
- unrelated user;
- unavailable request.

Return the same discriminated row shape as the list.

Do not leak whether an unrelated UUID exists.

---

# 10. Unified Messages chat projection

Add a second read-only projection:

```text
list_own_message_chat_items(
  p_expected_profile_id uuid,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_chat_id uuid default null
)
```

Supported:

```text
project_chat
resource_chat
```

Limit 1..50.

Cursor:

```text
(activity_at, item_kind_order, chat_id)
```

with stable ordering.

This allows the future mobile Chats tab to remain one chronological feed without separately paginating Project and Resource chats.

---

# 11. Unified chat summary row

Return common fields:

```text
item_kind
chat_id
activity_at

display_title
viewer_role
is_read_only

last_visible_message_id
last_visible_message_body
last_visible_message_at
last_visible_sender_profile_id
last_visible_sender_display_name

// Project branch
project_id
project_kind

// Resource branch
resource_request_id
resource_agreement_id
resource_listing_id
agreement_lifecycle
coordination_closed_at
```

Use strict XOR between Project and Resource branches.

---

# 12. Preserve canonical chat semantics

For Project chats, unified projection must preserve the current latest canonical semantics including:

- creator/current/former visibility;
- historical frontier;
- D3B system-event contribution to `activity_at`;
- human-only preview fields.

For Resource chats, preserve 04C4C1 semantics:

- fixed counterparty history authorization;
- agreement events contribute to `activity_at`;
- completed/cancelled chat is read-only;
- human-only preview fields.

Do not weaken either authorization model.

---

# 13. Avoid duplicating domain logic unnecessarily

Codex may:

- factor private helpers;
- use safe internal SQL helpers;
- or reproduce the already-tested projection logic carefully.

But add parity tests proving unified projections agree with existing domain-specific list/read contracts.

Do not replace existing RPCs in this slice.

---

# 14. Notification category

Use the already-existing category:

```text
resources
```

for all Scambio-Dona request/chat/agreement notifications in this plan.

Do not use the existing `chat` category for resource-request chats.

Reason:

```text
chat
→ Project/community chat preference

resources
→ Scambio-Dona/resource coordination preference
```

This lets users later control resource alerts independently.

No new notification category is required.

---

# 15. Resource notification kinds

Extend `public.notifications.notification_kind` with:

```text
resource_request_received
resource_request_withdrawn
resource_request_accepted
resource_request_rejected
resource_request_listing_closed

resource_chat_message_received

resource_exchange_terms_proposed
resource_exchange_terms_accepted
resource_exchange_terms_rejected
resource_exchange_terms_withdrawn
resource_exchange_milestone_recorded
resource_exchange_cancelled
resource_exchange_completed
```

Do not add:

```text
resource_exchange_agreement_created
resource_exchange_terms_superseded
```

because:

- agreement creation is already represented to the requester by request acceptance;
- a counter-proposal produces a new `terms_proposed`, so separate superseded alert would duplicate user-facing activity.

---

# 16. Notification destinations

Add semantic destination kinds:

```text
resource_request
resource_chat
```

Mapping:

## `resource_request`

Use for:

```text
resource_request_received
resource_request_withdrawn
resource_request_rejected
resource_request_listing_closed
```

## `resource_chat`

Use for:

```text
resource_request_accepted
resource_chat_message_received
all supported resource_exchange_* notifications
```

Accepted request is routed to chat because acceptance atomically creates the chat/agreement.

---

# 17. Notification reference columns

Do not overload existing Project `request_id`, `chat_id`, or `message_id` columns.

Those have FKs to Project tables.

Add explicit resource reference columns equivalent to:

```text
resource_listing_id uuid
resource_request_id uuid
resource_chat_id uuid
resource_chat_message_id uuid
resource_agreement_id uuid
resource_agreement_event_id uuid
```

with restrictive canonical FKs.

This keeps schemas self-describing and prevents cross-domain UUID ambiguity.

---

# 18. Notification shape constraints

Extend current strict constraints so resource notifications require exact reference shapes.

Examples:

## Request received / withdrawn / rejected / listing closed

Require:

```text
resource_listing_id
resource_request_id
actor_profile_id
```

## Request accepted

Require:

```text
resource_listing_id
resource_request_id
resource_chat_id
resource_agreement_id
actor_profile_id
```

## Resource chat message

Require:

```text
resource_listing_id
resource_request_id
resource_chat_id
resource_chat_message_id
resource_agreement_id
actor_profile_id
```

## Resource exchange change

Require:

```text
resource_listing_id
resource_request_id
resource_chat_id
resource_agreement_id
resource_agreement_event_id
actor_profile_id
```

Project reference columns must be null for resource notification kinds.

Resource reference columns must be null for existing participation/Project-chat kinds.

Preserve all existing constraints.

---

# 19. Resource request event projection

Consume these 04C4A events:

```text
resource_listing.request_created
resource_listing.request_withdrawn
resource_listing.request_accepted
resource_listing.request_rejected
resource_listing.request_closed
```

Recipient rules:

```text
request_created
→ listing owner

request_withdrawn
→ listing owner

request_accepted
→ requester

request_rejected
→ requester

request_closed
→ requester
```

Actor is the canonical event actor.

---

# 20. Resource chat message projection

Consume:

```text
resource_chat.message_sent
```

Recipient:

```text
the other fixed chat counterparty
```

Never the sender.

Resolve from canonical message/chat/request/listing state.

Do not trust payload recipient IDs blindly.

Notification contains no chat body.

---

# 21. Resource exchange projection

Consume:

```text
resource_exchange.terms_proposed
resource_exchange.terms_accepted
resource_exchange.terms_rejected
resource_exchange.terms_withdrawn
resource_exchange.milestone_recorded
resource_exchange.agreement_cancelled
resource_exchange.agreement_completed
```

Recipient:

```text
the counterparty other than actor_profile_id
```

One recipient per event.

Resolve agreement/request/listing/chat/agreement-event from canonical rows and validate payload IDs.

Do not project:

```text
resource_exchange.agreement_created
resource_exchange.terms_superseded
```

---

# 22. Milestone notification detail

Use one notification kind:

```text
resource_exchange_milestone_recorded
```

Do not create four notification kinds.

Reference:

```text
resource_agreement_event_id
```

The private notification inbox read may join the canonical event and return:

```text
resource_exchange_event_kind
resource_exchange_leg_kind
```

for later localized client copy.

No private terms content is copied into the notification row.

---

# 23. Extend notification inbox read

Evolve latest:

```text
list_own_notifications(...)
```

to return existing fields plus:

```text
resource_listing_id
resource_listing_title

resource_request_id
resource_chat_id
resource_chat_message_id
resource_agreement_id
resource_agreement_event_id

resource_exchange_event_kind
resource_exchange_leg_kind
```

Resolve titles/event metadata only for recipient-owned rows.

Do not return:

- request message;
- chat body;
- private agreement note;
- requester resource description;
- loan timestamps;
- exact handoff/contact details.

---

# 24. Existing mobile backward compatibility

Do not require current mobile code to understand the new fields.

The current parser already falls back for unknown categories/kinds rather than crashing.

Do not modify Flutter notification routing/copy in C2.

04C4C3 will add proper Resources-category models, copy, destinations, and preference UI.

---

# 25. Notification resolver pattern

Follow the existing hardened architecture:

```text
identifier-only outbox event
→ private resolver validates exact payload
→ joins canonical source rows
→ derives legitimate recipient
→ returns normalized semantic alert
```

Do not create notifications directly in request/chat/agreement transactions.

---

# 26. Resource event resolvers

Add private resolvers equivalent to:

```text
resolve_resource_request_notification_event
resolve_resource_chat_notification_event
resolve_resource_exchange_notification_event
```

or another clean split.

Evolve:

```text
private.resolve_notification_event(...)
```

to normalize Project and Resource sources.

Each resolver must:

- validate event type;
- validate exact identifier-only payload shape;
- parse UUIDs safely;
- compare payload IDs with canonical rows;
- derive recipient canonically;
- return no private copy.

---

# 27. Projector event filters

Expand:

```text
private.outbox_events_notification_sources_available_idx
process_notification_outbox_batch
process_push_outbox_batch
```

to consume exactly the supported Resource event types.

Preserve:

- bounded batches;
- `SKIP LOCKED`;
- independent `notifications.v1` / `push.v1` receipts;
- idempotency.

---

# 28. Historical no-backfill policy

Do **not** create retrospective alerts from Resource events that already exist before this migration.

Before the new projector consumes them, create:

```text
notifications.v1
push.v1
```

receipts for existing supported Resource outbox events.

This matches the 06D historical Project-chat policy.

Events created after the migration project normally.

---

# 29. Provider-neutral push jobs

Extend `private.push_delivery_jobs` with:

```text
resource_listing_id
resource_request_id
resource_chat_id
resource_chat_message_id
resource_agreement_id
resource_agreement_event_id
```

Use:

```text
category_slug = resources
```

Keep jobs body-free.

No Firebase/provider send implementation and no push-preview policy changes.

---

# 30. Push shape constraints

Preserve strict existing Project job constraints.

Add strict Resource shapes mirroring the notification rows.

Project refs null for Resource jobs.

Resource refs null for Project jobs.

Do not weaken everything into generic nullable identifiers.

---

# 31. Preference behavior

Use the existing `resources` category's:

```text
in_app_enabled
push_enabled
```

effective preference.

No second preference system.

Current mobile may not yet expose Resources preferences; C3 owns that UI.

---

# 32. Unified Requests parity tests

Prove:

- every authorized existing participation-request item appears exactly once;
- every authorized resource request appears exactly once;
- unrelated items do not appear;
- exact unified read agrees with canonical domain exact read;
- same UUID in different request domains remains safe because `item_kind` disambiguates it.

---

# 33. Unified Requests pagination tests

Create same-timestamp ties across both item kinds.

Verify no duplicates/skips over page boundaries.

Use all cursor components.

---

# 34. Unified Chats parity tests

Compare existing:

```text
Project chat list
Resource chat list
```

with unified list.

Preserve exact activity and read-only semantics.

Agreement/system activity may affect ordering, but human preview remains human-only.

---

# 35. Unified Chats pagination tests

Create activity ties between Project and Resource chats.

Verify deterministic no-duplicate/no-skip pagination.

---

# 36. Notification structural pgTAP

Cover:

- new kinds;
- resources category constraint;
- destinations;
- resource FK columns;
- Project-vs-Resource XOR;
- push-job resource columns;
- inbox result shape;
- private resolvers;
- expanded partial source index.

---

# 37. Notification behavior — requests

Cover:

```text
created → owner
withdrawn → owner
accepted → requester / resource_chat
rejected → requester
listing_closed → requester
```

Verify category, IDs, privacy, preference suppression, receipts, idempotency.

---

# 38. Notification behavior — resource chat

Cover:

```text
resource_chat.message_sent
→ opposite counterparty only
```

Verify sender excluded, body absent, resource message/chat IDs present, Project refs null.

---

# 39. Notification behavior — exchange

Cover all supported exchange events.

Verify:

- other counterparty only;
- actor excluded;
- agreement event canonical;
- private event kind/leg can be returned through authorized inbox context;
- no private terms copy.

Verify no alerts for `agreement_created` or `terms_superseded`.

---

# 40. Historical receipt tests

Verify old supported Resource outbox events are receipted by both consumers without creating:

```text
public.notifications
private.push_delivery_jobs
```

New events project normally.

---

# 41. Push-job tests

Representative resource events:

- push disabled → suppression + receipt;
- push enabled → one semantic body-free job;
- correct Resource references;
- no Project refs;
- rerun idempotent.

No provider call.

---

# 42. Real authenticated integration

Add a focused verifier covering:

1. one Project participation request;
2. one Resource request;
3. unified Requests returns both;
4. exact discriminated lookup;
5. Project + Resource chat in unified Chats;
6. agreement event changes Resource chat activity;
7. human preview remains human-only;
8. request-created owner notification;
9. accepted requester notification to Resource chat;
10. Resource chat message alert only opposite counterparty;
11. terms-proposed alert only other party;
12. milestone notification references event without private terms;
13. completed agreement notification;
14. Resources preference suppression;
15. body-free provider-neutral push job;
16. historical no-backfill receipts;
17. unrelated user cannot read private resource request/chat data;
18. notification inbox leaks no request/chat/terms bodies.

Never log OTPs, tokens, request messages, chat bodies, private terms, lending dates, or contact information.

---

# 43. Notifications remain alerts

Do not add domain mutations to notification rows.

Accept/Reject/Withdraw/terms/milestone actions still call canonical 04C4 RPCs from C3.

---

# 44. No Flutter Messages migration yet

Do not migrate the current mobile Requests/Chats tabs in this slice.

Current clients continue using existing Project-specific RPCs.

C3 will switch to the unified projections together with the Resource screens/routes.

---

# 45. Generated types

Regenerate/update contracts for:

- unified request list/exact;
- unified chat list;
- notification Resource columns/output;
- new public RPCs.

If Supabase remains unavailable, derive only compile-required deltas carefully and keep type-drift verification as a hard merge blocker.

---

# 46. Documentation / roadmap

Document:

```text
04C4C1 — resource conversation domain
04C4C2 — unified Messages + Resource notifications
04C4C3 — mobile Scambio request/agreement/conversation experience
```

Document that:

- Resources notification category is now mapped;
- pre-existing Resource outbox history is not backfilled into alerts;
- Resource push jobs are provider-neutral only;
- mobile Resources notification copy/routes/preferences remain C3.

No product Google Doc update is needed.

---

# 47. C3 handoff

C3 should be able to consume:

```text
list_own_structured_request_message_items
get_own_structured_request_message_item
list_own_message_chat_items

04C4A request mutations
04C4B agreement reads/mutations
04C4C1 chat reads/send/Realtime

list_own_notifications with Resource context
```

C3 owns:

- Request/Withdraw;
- owner Accept/Reject;
- N interested;
- unified Requests tab;
- unified Chats tab;
- Resource chat screen;
- agreement proposal/counterproposal;
- milestones/timeline;
- Resources notification copy/routes/preferences.

---

# 48. Validation policy

Run available:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new verifier>
git diff --check
```

Run SQL grammar parse checks.

Attempt hosted Validation once.

If GitHub fails before runner allocation due the known account billing/spending-limit issue, record:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because this changes notification/push projectors and database contracts, do not merge until clean replay, lint/advisors, pgTAP, authenticated integration and generated-type drift execute green.

---

# Non-goals

Do not implement:

- Flutter Resource request UI;
- Flutter unified Messages UI;
- Flutter Resource chat/agreement UI;
- Resources notification copy/routes/preferences in mobile;
- Firebase/provider delivery;
- push preview policy;
- generic DMs;
- read receipts;
- loan queue/calendar;
- matching;
- saved searches;
- disputes/moderation;
- post-handoff amendments.

---

# Acceptance criteria

- [ ] based on PR #73;
- [ ] exact prompt archived;
- [ ] existing domain-specific RPCs remain compatible;
- [ ] unified request list/exact exist;
- [ ] strict request discriminator/XOR;
- [ ] stable cross-kind request pagination;
- [ ] unified chat list exists;
- [ ] strict Project/Resource chat discriminator;
- [ ] stable cross-kind chat pagination;
- [ ] Project authorization unchanged;
- [ ] Resource authorization unchanged;
- [ ] Resources category activated;
- [ ] request/chat/exchange notification kinds supported;
- [ ] agreement-created/terms-superseded do not duplicate alerts;
- [ ] explicit Resource notification FK columns;
- [ ] strict Project-vs-Resource shapes;
- [ ] safe Resource context returned by notification inbox;
- [ ] no private body/terms copied into notification state;
- [ ] old Resource events receipted without alert backfill;
- [ ] notification + push projectors consume new events;
- [ ] provider-neutral Resource push jobs body-free;
- [ ] preferences and idempotency preserved;
- [ ] no Flutter C3 scope creep;
- [ ] pgTAP/integration/type drift coverage added;
- [ ] no custom `40001`;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4C2 branch/base/PR
3. Changed files
4. Unified request projection
5. Unified request cursor
6. Request discriminator/XOR
7. Unified exact request read
8. Unified chat projection
9. Unified chat cursor
10. Project-chat parity
11. Resource-chat parity
12. Resources notification category
13. Notification kinds
14. Destination semantics
15. Notification Resource columns
16. Notification shape constraints
17. Request-event resolver
18. Resource-chat resolver
19. Exchange-event resolver
20. Recipient behavior
21. Milestone event metadata
22. Notification inbox Resource context
23. Historical no-backfill receipts
24. Notification projector changes
25. Push projector changes
26. Provider-neutral push-job Resource schema
27. Preference behavior
28. Privacy/body-free guarantees
29. Unified projection pgTAP
30. Notification pgTAP
31. Push-job tests
32. Real integration
33. Existing mobile backward compatibility
34. Generated types/drift
35. Local regression validation
36. Hosted Validation executed/not-executed
37. 04C4C3 handoff
38. Warnings/blockers
39. Commit/PR reference

Do not merge any PR.
