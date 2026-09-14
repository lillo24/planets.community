# PLANETS 06D — Project Chat Notification Projection and Mobile Alerts

**Roadmap area:** PLANETS 06 — Notification backbone  
**Task type:** Backend notification/push semantic projection + Flutter in-app notification integration  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged base when this prompt was written:** `d343afbeab79ce6132403a6e9b46aecbc375f1fd` (07B2C / PR #30)

## Objective

Connect the now-implemented Project group chat to the existing PLANETS notification backbone.

07B2B already emits one identifier-only outbox event for every durable chat message:

```text
project.chat_message_sent
```

07B2C now provides the real mobile destination:

```text
/messages/chats/:chatId
```

06A/06C already provide:

- controlled notification categories, including `chat`;
- `notifications.v1` independent outbox consumption;
- `push.v1` independent outbox consumption;
- user preferences for in-app/push channels;
- recipient-level push jobs;
- provider-neutral push delivery protocol;
- mobile notification inbox/read state/preferences/navigation.

06D should bridge these pieces.

After 06D:

```text
Project chat message sent
        ↓
project.chat_message_sent
        ↓
recipient fan-out at message send-time membership
        ├── notifications.v1
        │     └── in-app "New message in <Project>"
        │           └── /messages/chats/:chatId
        │
        └── push.v1
              └── semantic push job
                    └── future 06C2B FCM adapter
```

Do not implement Firebase/FCM delivery.

Do not include chat message bodies in notifications, push jobs, outbox receipts, logs, or Realtime payloads.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_06D_project_chat_notification_projection_mobile_alerts.md
```

---

# Current implemented facts

## Chat

PR #29 implemented:

- `public.project_chat_messages`;
- immutable plain-text message bodies;
- `project.chat_message_sent`;
- one Project chat per shared Project;
- full-history/current/former read semantics;
- private identifier-only Realtime hints.

PR #30 is merged at:

```text
d343afbeab79ce6132403a6e9b46aecbc375f1fd
```

and implements:

- mobile Project chat list/detail;
- `/messages/chats/:chatId`;
- send/history/Realtime;
- former-member read-only behavior;
- group info.

## Notifications

`public.notification_categories` already contains:

```text
participation
project_activity
matching
chat
resources
```

with `chat` user-configurable and defaulting to both in-app and push enabled.

Currently only the six participation events are mapped.

## Push

Provider-independent push infrastructure is already implemented through 06C2A.

06C2B remains not started because actual Firebase/APNs/provider setup is external context.

06D must remain fully provider-independent.

---

# 1. Notification semantics

Add one semantic notification kind:

```text
chat_message_received
```

Category:

```text
chat
```

Destination:

```text
project_chat
```

Required canonical context:

```text
project_id
project_kind
chat_id
message_id
actor_profile_id = sender
```

No:

```text
request_id
membership_id
message body
```

The mobile copy should be based only on safe existing context, e.g.:

```text
Alice sent a message in Community Garden
```

with a generic fallback such as:

```text
New project chat message
```

Never show the actual message text in the notification.

---

# 2. Recipient fan-out rule

Unlike the current six participation notification events, one chat-message event may have many recipients.

For a canonical message at timestamp `message.created_at`, notify every profile who was entitled to participate in that chat **at the time the message was sent**, excluding the sender.

Recipient set:

```text
Project creator
UNION
participants whose accepted membership interval contains message.created_at
MINUS
sender
```

For participant membership use the canonical half-open interval:

```text
joined_at <= message.created_at
and
(
  membership has no end
  or message.created_at < coalesce(left_at, removed_at)
)
```

Important consequences:

- a participant who joins after the message does **not** receive an old alert;
- a participant who was a member when the message arrived but leaves before projection still may receive the notification because they can retain/read that message;
- a former participant does not receive messages sent after their membership end;
- a rejoined participant receives notifications only for messages inside the later active interval;
- creator is eligible independent of membership;
- sender never receives their own chat notification.

Deduplicate recipients defensively.

---

# 3. Canonical chat event resolver

Add a private resolver equivalent to:

```text
resolve_chat_message_notification_event(outbox_event_id)
```

It should return **zero or more rows**, one per semantic recipient.

Validate the outbox payload against canonical state:

```text
event_type = project.chat_message_sent
chat_id
project_id
project_kind
message_id
sender_profile_id
```

Cross-check against:

- `project_chat_messages`;
- `project_group_chats`;
- `projects`;
- sender profile.

Do not trust identifiers merely because they appear in outbox JSON.

Use:

```text
message.created_at
```

as the semantic notification chronology / recipient-membership timestamp.

Do not rely on `outbox_events.created_at` for membership eligibility because the chat message timestamp is the canonical send boundary established by 07B2B's Project locking.

Resolver output should conceptually provide:

```text
category_slug = chat
notification_kind = chat_message_received
recipient_profile_id
actor_profile_id = sender
project_id
project_kind
chat_id
message_id
request_id = null
membership_id = null
destination_kind = project_chat
source_created_at = message.created_at
```

---

# 4. Extend public notification schema

Extend `public.notifications` safely.

Add nullable semantic references:

```text
chat_id
message_id
```

with proper foreign keys to:

```text
project_group_chats
project_chat_messages
```

Update constraints so the table supports both:

- existing Participation shapes unchanged;
- new Chat shape.

Chat shape must require:

```text
category_slug = chat
notification_kind = chat_message_received
destination_kind = project_chat
project_id not null
chat_id not null
message_id not null
actor_profile_id not null
request_id null
membership_id null
```

Also validate, directly or through projection invariants, that the message belongs to the chat/project and actor is its sender.

Do not weaken Participation constraints.

Update indexes for useful chat/message lookups if justified.

---

# 5. Extend recipient-level push jobs

Extend `private.push_delivery_jobs` with semantic chat references:

```text
chat_id
message_id
```

with appropriate foreign keys/indexes.

Add a Chat shape invariant equivalent to the public notification shape:

```text
category_slug = chat
notification_kind = chat_message_received
destination_kind = project_chat
project/chat/message present
request/membership absent
actor present
```

Preserve all existing Participation invariants.

No provider token or message body enters the job.

---

# 6. Extend provider-neutral worker claim context

06C2A's trusted claim currently returns semantic fields including:

```text
category_slug
notification_kind
recipient_profile_id
actor_profile_id
project_id
project_kind
request_id
membership_id
destination_kind
source_created_at
```

Extend it to return:

```text
chat_id
message_id
```

as well.

This is future 06C2B input for generic push copy/navigation.

Do not:

- call FCM;
- add Firebase packages;
- add server credentials;
- add provider-specific error handling.

Keep raw provider token exposure exactly at the existing trusted claim boundary.

---

# 7. Extend notifications.v1 projector

Update:

```text
process_notification_outbox_batch
```

to support:

```text
project.chat_message_sent
```

without regressing the six existing participation mappings.

Because chat is fan-out:

```text
one source event
→ 0..N recipient projections
```

Requirements:

- select supported chat events in the same bounded/locked batch discipline;
- use `FOR UPDATE SKIP LOCKED`;
- resolve/validate canonical chat event;
- iterate all recipients;
- evaluate each recipient's effective `chat` in-app preference independently;
- insert one notification per enabled recipient;
- count preference-disabled recipients as suppressed;
- retain idempotency through existing source+recipient+kind uniqueness;
- write **one `notifications.v1` consumer receipt only after the full event fan-out succeeds**;
- zero-recipient event still receives a consumer receipt;
- a retry after lost response creates no duplicates.

Do not mark an event consumed halfway through a failed fan-out.

---

# 8. Extend push.v1 projector

Update:

```text
process_push_outbox_batch
```

similarly.

For every semantic recipient:

- evaluate effective `chat` `push_enabled`;
- when enabled, create one recipient-level semantic push job;
- when disabled, suppress that recipient;
- no active installation is required at projection time;
- fan-out to installations remains 06C2A;
- one `push.v1` receipt only after the whole source event succeeds.

This must remain independent of in-app preference.

Explicitly test:

```text
in_app=true  push=true
in_app=true  push=false
in_app=false push=true
in_app=false push=false
```

for the chat category.

---

# 9. Historical rollout

Do not surprise users with notifications for chat messages that already existed before 06D is introduced.

During migration, acknowledge already-existing:

```text
project.chat_message_sent
```

events for both:

```text
notifications.v1
push.v1
```

without creating notifications or push jobs.

Only messages sent after the migration should enter the new notification projection.

Document this clearly.

---

# 10. Notification source index

Extend the partial notification-source outbox index to include:

```text
project.chat_message_sent
```

if the existing index shape still benefits the updated projectors.

Do not broaden it to unrelated future events.

---

# 11. Public notification inbox API

Update `list_own_notifications` output to include:

```text
chat_id
message_id
```

as nullable semantic context.

For chat notifications it should also expose the existing safe display context:

```text
project_kind
project_title
actor_profile_id
actor_display_name
```

No message body.

Existing participation output/ordering/pagination must remain unchanged.

Unread count/read mutations require no semantic change unless signature drift forces generated-type updates.

---

# 12. Mobile notification domain

Extend mobile enums:

```text
NotificationCategory.chat
NotificationKind.chatMessageReceived
NotificationDestinationKind.projectChat
```

Extend `AppNotification` with:

```text
chatId
messageId
```

nullable for participation notifications.

Maintain forward compatibility:

- unknown category/kind/destination still parses safely where existing behavior expects that;
- known Chat notification must be strictly validated.

Known chat validation requires:

```text
category = chat
kind = chatMessageReceived
destination = projectChat
projectId/projectKind/projectTitle present as required by current display/navigation conventions
chatId present
messageId present
requestId null
```

Follow actual repository actor/profile deletion behavior rather than guessing whether actor must always remain displayable.

---

# 13. Chat notification copy

Add localized safe copy.

Preferred:

```text
{actor} sent a message in {project}
```

Fallbacks should never expose raw identifiers.

Examples:

```text
New message in {project}
New project chat message
```

Do not display:

- message body;
- Realtime payload;
- message ID;
- chat ID.

No final brand-copy polish required.

---

# 14. Mobile destination

Map:

```text
chat_message_received + project_chat + chat_id
```

to:

```text
/messages/chats/:chatId
```

using the canonical 07B2C route helper.

Do not reconstruct Project chat URLs manually in multiple features.

Tapping a chat notification should retain the existing 06B behavior:

- navigation does not hard-block on transient mark-read failure;
- notification read state reconciles normally.

If the user has since left/been removed, the route still opens their authorized former-member history, including the notified message.

---

# 15. Chat preference UI

The `chat` category already exists and is user-configurable.

Expose it in the existing notification preferences screen.

Functional UI:

```text
Participation alerts
  In-app notifications [toggle]

Chat messages
  In-app notifications [toggle]
```

Still do **not** expose a Push toggle yet because actual OS/provider push is not user-facing until 06C2B.

When changing only `in_app_enabled`, preserve the loaded `push_enabled` value exactly, as 06B already does for Participation.

Extend gateway/controller APIs so both:

```text
participation
chat
```

can be updated.

Do not expose placeholder controls for:

```text
project_activity
matching
resources
```

until those categories have actual mapped behaviors.

---

# 16. Preference effects

Chat preference applies to notification projection, not the live chat itself.

If in-app Chat notifications are disabled:

- Project chat still functions;
- Realtime chat still functions;
- Messages/Chats still works;
- no notification inbox row is created.

If push is enabled independently:

- push semantic job still exists even when in-app is disabled.

Do not use notification preference to unsubscribe users from the chat's own live Realtime transport.

---

# 17. Sender exclusion

A user must not receive:

- an in-app chat notification for their own message;
- a push job for their own message.

They still receive the normal 07B2C Realtime behavior required for chat-state reconciliation.

Notification projection and chat Realtime are separate mechanisms.

---

# 18. Membership timing tests

This is critical.

Test at least:

```text
Creator C
Participant A
Participant B
```

Scenario:

1. C + A are current;
2. A sends M1;
   - C gets notification/job;
   - A does not;
3. B joins after M1;
   - B does not receive M1 notification;
4. C sends M2 while A+B current;
   - A + B get notifications/jobs;
5. A leaves;
6. C sends M3;
   - B gets notification/job;
   - A does not;
7. A rejoins;
8. B sends M4;
   - C + A get notification/jobs;
9. A later leaves again;
10. messages after second leave no longer target A.

Also test creator-as-sender exclusion.

Use `message.created_at` as the temporal authority.

---

# 19. Projection race/idempotency tests

Add coverage for:

- concurrent notification projector workers;
- concurrent push projector workers;
- lost-response retry;
- one source event with multiple recipients;
- one recipient preference disabled while another enabled;
- one recipient insert conflict/retry does not duplicate others;
- source receipt written only after complete successful fan-out;
- invalid/mismatched chat/message payload fails with no receipt;
- zero-recipient message (e.g. creator alone where sender is creator) is acknowledged safely.

Existing participation event behavior must remain contract-compatible.

---

# 20. Privacy tests

Prove notification/push structures contain no message text.

Search/assert that:

- `notifications` has no message-body column;
- `push_delivery_jobs` has no message body;
- `push_delivery_targets` has no body;
- `push_delivery_attempts` has no body;
- `project.chat_message_sent` payload remains identifier-only;
- notification list API does not return body;
- provider claim does not return body.

It is acceptable for the canonical `project_chat_messages` table itself to remain server-readable; that is the explicit MVP architecture.

---

# 21. Real local integration

Add a focused integration, e.g.:

```text
scripts/verify-local-project-chat-notifications.mjs
```

Use real authenticated users and the canonical send RPC.

Prove:

- recipient fan-out by membership-at-send-time;
- sender excluded;
- late join excluded from earlier message;
- former member excluded from later message;
- rejoin restores targeting;
- notification preference suppression;
- push preference independence;
- direct notification inbox context has chat/message IDs;
- no body leakage;
- both Proposal and Tavolo chat messages work.

The script may invoke service-role projectors exactly like existing notification/push integration harnesses.

Do not print OTPs, tokens, message bodies, meeting details, or credentials.

---

# 22. Mobile tests

Add coverage for:

## Parsing

- chat category;
- chat kind;
- project-chat destination;
- chat/message IDs;
- malformed known-chat shape rejected;
- old Participation shapes unchanged;
- unknown future values remain safe.

## Copy

- actor + Project title;
- missing safe display context fallback;
- never message body.

## Destination

- chat notification resolves to `/messages/chats/:chatId`;
- missing chat ID produces no unsafe destination;
- existing Participation destinations unchanged.

## Flow

- tapping unread chat notification navigates;
- mark-read failure does not block navigation;
- account switch remains safe;
- former-member chat route can still resolve.

## Preferences

- Participation and Chat in-app toggles render;
- changing Chat preserves `push_enabled`;
- saving one category does not mutate the other;
- no fake Push toggle;
- unmapped future categories remain hidden.

---

# 23. Generated types

Regenerate public DB types after:

- `notifications` shape change;
- notification inbox RPC output change;
- any public signature/output changes.

Private push-job tables remain private.

Zero drift required.

---

# 24. Roadmap reconciliation

First record the newly merged chat client:

```text
07B2C — Implemented
PR #30
merge commit d343afbeab79ce6132403a6e9b46aecbc375f1fd
```

Then mark the completed 07 hierarchy appropriately:

```text
07B2 — Implemented
07B — Implemented
07 — Implemented
```

Native/manual QA remains deferred to Plan 12 and is not claimed passed.

Add:

```text
06D — Project Chat Notification Projection and Mobile Alerts
```

Dependencies:

```text
06A
06B
06C1
06C2A
07B2B
07B2C
```

Status while PR open:

```text
In progress
```

06 parent remains:

```text
In progress
```

because 06C2B is still not started.

Keep:

```text
06C2B — Not started / external Firebase/APNs/provider context required
04C — Not started
05C — Not started
08 — Not started
```

Do not mark provider push complete.

---

# 25. Documentation

Update:

- notification feature README;
- database development docs;
- system design;
- roadmap;
- relevant push protocol docs.

Record:

```text
project.chat_message_sent
  → chat_message_received
  → category chat
  → project_chat destination
```

Clarify:

- message body never enters alert infrastructure;
- provider-neutral push job has enough semantic context for future 06C2B;
- mobile notification UI can navigate immediately because 07B2C exists;
- Chat in-app preference is now exposed;
- actual FCM delivery remains deferred.

---

# Non-goals

Do not implement:

- Firebase;
- APNs;
- OS notification permission;
- FCM HTTP v1;
- push foreground/background handlers;
- local OS notification display;
- rich push message previews;
- message-body notification previews;
- unread chat counts;
- chat read receipts;
- notification batching/digests;
- mention notifications;
- mute-per-project;
- direct messages;
- 04C Resources;
- 05C contribution verification.

---

# Acceptance criteria

06D is ready when:

- [ ] based on merged PR #30 main;
- [ ] exact prompt archived;
- [ ] 07B2C/07 hierarchy roadmap reconciled;
- [ ] `chat_message_received` exists;
- [ ] `project_chat` semantic destination exists;
- [ ] notifications carry `chat_id` + `message_id`;
- [ ] push jobs carry `chat_id` + `message_id`;
- [ ] trusted push claim exposes those semantic IDs;
- [ ] no message body enters notification/push structures;
- [ ] canonical event payload is revalidated against chat/message/project/sender;
- [ ] fan-out uses membership at `message.created_at`;
- [ ] sender excluded;
- [ ] late joiner excluded from old alert;
- [ ] former member excluded from post-leave alert;
- [ ] rejoin restores future targeting;
- [ ] notifications.v1 supports 0..N recipients per source event;
- [ ] push.v1 supports 0..N recipients per source event;
- [ ] one consumer receipt only after complete event fan-out;
- [ ] existing participation projection unchanged;
- [ ] in-app/push preferences remain independent;
- [ ] historical pre-06D chat events are acknowledged without retroactive alerts;
- [ ] mobile notification parses/copies/routes chat alert;
- [ ] tapping routes to canonical `/messages/chats/:chatId`;
- [ ] Chat in-app preference toggle exists;
- [ ] Push toggle remains hidden;
- [ ] Proposal + Tavolo chat notifications tested;
- [ ] pgTAP/integration/mobile tests pass;
- [ ] generated types have zero drift;
- [ ] Database/Mobile/Web/Site CI remains green;
- [ ] no native QA pass falsely claimed;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact private resolver name;
- whether to generalize projector internals through a shared resolver union or branch explicitly per event family;
- exact indexes;
- exact generic fallback copy;
- exact controller API for changing multiple supported preferences.

Stop and report before:

- copying chat message bodies into notification/push state;
- notifying the sender;
- targeting users who were not members at send time;
- changing Project chat history semantics;
- exposing Push UI before 06C2B;
- calling Firebase/provider APIs;
- weakening existing participation notification constraints;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 06D prompt;
2. chat notification resolver/fan-out;
3. extended notification schema;
4. extended push-job semantic context;
5. extended worker-claim semantic context;
6. notifications.v1 chat projection;
7. push.v1 chat projection;
8. historical rollout receipts;
9. pgTAP structure/access/fan-out/idempotency tests;
10. real local Project/Tavolo chat-notification integration;
11. mobile chat notification model/copy/destination;
12. Chat in-app preference control;
13. mobile parser/destination/preferences/flow tests;
14. generated DB types;
15. documentation/roadmap updates;
16. focused PR, preferably `codex/06d-project-chat-notifications`;
17. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **07B2C / Plan 07 roadmap reconciliation**
5. **Chat notification schema**
6. **Canonical event validation**
7. **Recipient-at-send-time fan-out**
8. **Sender exclusion**
9. **Late-join/leave/rejoin semantics**
10. **notifications.v1 projector**
11. **push.v1 projector**
12. **Preference independence**
13. **Historical rollout**
14. **Notification chat/message references**
15. **Push job chat/message references**
16. **Worker claim context**
17. **Privacy/body-exclusion guarantees**
18. **Inbox API**
19. **Mobile notification models**
20. **Mobile copy**
21. **Mobile destination**
22. **Chat preference UI**
23. **pgTAP tests**
24. **Real local integration**
25. **Mobile tests**
26. **Proposal/Tavolo coverage**
27. **Generated types/drift**
28. **Regression validation**
29. **Documentation updates**
30. **Remaining 06C2B blocker**
31. **Warnings/blockers**
32. **Commit/PR reference**
