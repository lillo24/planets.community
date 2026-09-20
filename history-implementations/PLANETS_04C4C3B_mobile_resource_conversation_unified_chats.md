# PLANETS 04C4C3B — Mobile Resource Conversation + Unified Chats

**Roadmap area:** 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience  
**Task type:** Flutter/mobile integration over 04C4C1/C2  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open Scambio-Dona stack:

```text
PR #78 — 04C4C3A Mobile Resource Requests + Unified Requests Inbox
branch: codex/04c4c3a-mobile-resource-requests
head:   d0925eb8fab56a28f4deeb4a32549dad9c5c210e
```

PR #78 is draft and stacked on PR #75/#73/#72/#71/#70. Do not merge any dependency.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #78 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #78 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c3b-mobile-resource-conversation
```

Open the new PR with base:

```text
codex/04c4c3a-mobile-resource-requests
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C3B_mobile_resource_conversation_unified_chats.md
```

No external document is required by Codex.

---

# Objective

Implement the mobile Resource-request conversation experience and migrate **Messages → Chats** to the unified Project/Resource chat projection already created by 04C4C2.

The user-facing flow becomes:

```text
Resource request accepted
        ↓
Messages → Chats
        ↓
Resource conversation
        ↓
owner ↔ requester human messages
```

The same chat is also reachable from the accepted Resource-request detail.

Canonical behavior:

```text
coordination open
→ both counterparties may send

agreement completed/cancelled
→ conversation remains readable
→ composer disappears / read-only notice

later new request episode
→ separate chat
```

Do not implement agreement negotiation/milestones in this slice.

---

# 1. Scope split remains

```text
04C4C3A — Resource requests + unified Requests
  implemented in PR #78

04C4C3B — Resource conversation + unified Chats
  this plan

04C4C3C — Mobile Scambio Agreement Experience
  terms proposal/counterproposal
  handoff/return milestones
  agreement timeline
  overdue state

04C4C3D — Mobile Resources Notification UX
  Resource notification models/copy/routes/preferences
```

Do not pull C3C/C3D into this PR.

---

# 2. No database migration

This is a mobile-only plan.

Use existing canonical RPCs:

```text
list_own_message_chat_items

get_own_resource_request_chat
list_own_resource_request_chat_messages
send_resource_request_chat_message

Resource-chat private Realtime:
  resource.chat_message_sent
  resource.exchange_changed
```

Do not modify SQL or generated DB contracts.

---

# 3. Unified chat domain

Add a strict mobile discriminator for the C2 unified chat projection.

Conceptually:

```text
enum MessageChatItemKind {
  projectChat
  resourceChat
}
```

Prefer a sealed typed model:

```text
sealed MessageChatItem {
  kind
  chatId
  activityAt
  displayTitle
  viewerRole
  isReadOnly

  lastVisibleMessageId?
  lastVisibleMessageBody?
  lastVisibleMessageAt?
  lastVisibleSenderProfileId?
  lastVisibleSenderDisplayName?
}

ProjectMessageChatItem
ResourceMessageChatItem
```

Do not carry a large nullable row object throughout UI code.

---

# 4. Project unified-chat branch

Strictly parse the Project branch:

```text
item_kind = project_chat
```

Require:

```text
project_id
project_kind
```

and null Resource-only fields.

Viewer role supports the exact C2 values:

```text
creator
current_member
former_member
```

Preserve `is_read_only` from the backend.

Do not re-derive Project entitlement from local membership state.

---

# 5. Resource unified-chat branch

Strictly parse:

```text
item_kind = resource_chat
```

Require:

```text
resource_request_id
resource_agreement_id
resource_listing_id
agreement_lifecycle
coordination_closed_at as appropriate
```

Project fields must be null.

Viewer role:

```text
owner
requester
```

Agreement lifecycle:

```text
negotiating
agreed
in_progress
completed
cancelled
```

Use backend `is_read_only` as canonical current chat writability.

---

# 6. Unified chat cursor

C2 pagination requires:

```text
activityAt
itemKind
chatId
```

Create a complete mobile cursor.

Never fall back to a two-part `(activityAt, chatId)` cursor.

---

# 7. Unified Chats gateway

Add a narrow read method over:

```text
list_own_message_chat_items
```

using:

```text
p_expected_profile_id
p_limit
p_cursor_activity_at
p_cursor_item_kind
p_cursor_chat_id
```

Fetch `limit + 1`, return `hasMore`.

Keep existing Project-chat list RPC/gateway intact because Project detail code and compatibility tests still depend on that domain.

---

# 8. Composite identity

Deduplicate unified chat rows by:

```text
(itemKind, chatId)
```

not by UUID alone.

Cross-domain chat UUID collisions are valid to represent safely.

---

# 9. Unified Chats controller

Add a dedicated identity-bound controller for the Messages Chats tab.

State conceptually:

```text
UnifiedChatsState {
  phase
  expectedProfileId
  items
  hasMore
  failure
  hasConnectionIssue
}
```

Support:

```text
load/refresh
loadMore
startSignals
stopSignals
```

Account switch/sign-out must:

- cancel every private subscription;
- clear all chat rows;
- reject late responses.

---

# 10. Loaded-chat Realtime subscriptions

Do not create a global chat broadcast channel.

For loaded, currently writable rows:

## Project chat

Reuse:

```text
ProjectChatGateway.subscribeToProjectChatSignals(...)
```

## Resource chat

Use the new Resource-chat gateway subscription from this plan.

Only subscribe to loaded rows.

When pagination loads more rows, synchronize subscriptions.

When a refreshed row becomes read-only or disappears, close its live subscription.

This mirrors the existing Project-chat list behavior.

---

# 11. Unified list Realtime refresh behavior

Any relevant signal for a loaded chat should schedule a **debounced canonical unified-list refresh**.

Project chat signals:

```text
project.chat_message_sent
project.requirement_needed_again
project.requirement_covered
```

Resource signals:

```text
resource.chat_message_sent
resource.exchange_changed
```

It is acceptable to refresh on all these signals even where one event does not ultimately change `activity_at`.

Do not mutate ordering/previews directly from Realtime payloads.

Backend list projection remains authoritative.

---

# 12. Connection issue behavior

Track per-loaded-chat subscription failures and expose one aggregated:

```text
hasConnectionIssue
```

for the Chats tab.

On reconnect after a disconnect:

```text
refresh unified Chats canonically
```

Do not rely on missed Realtime events being replayed.

Reuse the existing Project-chat UX pattern for the connection warning.

---

# 13. Migrate Messages → Chats

Replace the current Project-only Chats-tab list source with the new unified Chats controller.

Do not change the Requests tab added in C3A.

Mixed chronological feed:

```text
Project chat
Resource chat
Project chat
Resource chat
```

ordered by canonical C2 `activity_at`.

---

# 14. Project chat cards remain behaviorally unchanged

For `ProjectMessageChatItem` preserve the current visual semantics:

```text
Project/Tavolo title
Project kind
creator/current/read-only role chip
human-message preview
activity timestamp
```

Tap routes to the existing:

```text
/messages/chats/:chatId
```

Project chat screen.

Do not rewrite ProjectChatScreen.

---

# 15. Resource chat card

For `ResourceMessageChatItem`, show:

```text
listing title
Scambio-Dona / Resource conversation context
read-only/open status
latest human-message preview
activity timestamp
```

The unified list projection currently does not contain counterpart display names.

Do **not** make an N+1 detail call per Resource chat to obtain them.

Use only list-row fields on the card.

Counterparty names appear after opening the chat via the exact Resource-chat read.

---

# 16. Resource activity without human preview

A Resource chat may move to the top because:

```text
terms proposed
terms accepted
milestone recorded
agreement completed/cancelled
```

while its latest human preview remains unchanged or null.

That is correct.

If there is no human message, use neutral localized copy such as:

```text
No messages yet
```

Do not fabricate:

```text
"Terms changed"
"Item returned"
```

inside the message preview.

Agreement/timeline rendering belongs to C3C.

---

# 17. Resource chat route

Add a discriminator-safe route:

```text
/messages/chats/resource/:chatId
```

Keep existing Project route:

```text
/messages/chats/:chatId
```

working unchanged.

Add central route builders:

```text
projectChatRoute(...)
resourceChatRoute(...)
```

Do not break current Project notification/deep-link behavior.

---

# 18. Accepted Resource-request detail handoff

Update the C3A Resource request detail.

When:

```text
status = accepted
AND resource_chat_id != null
```

show:

```text
Open conversation
```

regardless of whether coordination is still open.

If coordination is closed, opening it shows historical read-only chat.

Do not show the button for non-accepted requests.

Do not expose agreement actions yet.

---

# 19. Resource-chat mobile models

Create a dedicated Resource chat domain.

Conceptually:

```text
enum ResourceChatViewerRole {
  owner
  requester
}

enum ResourceExchangeLifecycle {
  negotiating
  agreed
  inProgress
  completed
  cancelled
}

class ResourceChatSummary {
  chatId
  requestId
  agreementId
  listingId
  listingTitle

  viewerRole
  ownerProfileId
  ownerDisplayName
  requesterProfileId
  requesterDisplayName

  agreementLifecycle
  coordinationClosedAt
  hasSendEntitlement

  activatedAt
  activityAt

  lastVisibleMessage...
}

class ResourceChatMessage {
  messageId
  chatId
  senderProfileId
  senderDisplayName?
  body
  createdAt
}

class ResourceChatMessageCursor {
  createdAt
  messageId
}
```

Strictly validate summary lifecycle shape.

---

# 20. Resource exact-summary parser

Parse:

```text
get_own_resource_request_chat
```

Strictly validate:

- UUID fields;
- viewer role;
- agreement lifecycle;
- preview fields all-null or all-present;
- `has_send_entitlement` is boolean;
- completed/cancelled cannot be locally treated as writable even if malformed backend payload says otherwise.

Fail safely on inconsistent payload.

Backend remains canonical.

---

# 21. Resource history parser

Parse:

```text
list_own_resource_request_chat_messages
```

Validate:

- exact chat ID;
- sender ID;
- display name;
- 1..4000 canonical body;
- timestamp.

History RPC returns newest first.

UI state should store/render natural oldest-first order.

---

# 22. Resource send parser

Parse the single row returned by:

```text
send_resource_request_chat_message
```

It contains:

```text
message_id
chat_id
sender_profile_id
created_at
body
```

No sender display name is returned.

For the just-sent local row, own-message rendering can use:

```text
You
```

rather than fabricating a display name.

Canonical later reload fills normal history context.

---

# 23. Resource Realtime signal model

Add strict typed signals:

```text
ResourceChatMessageSentSignal
ResourceExchangeChangedSignal
```

## `resource.chat_message_sent`

Require:

```text
chat_id
request_id
message_id
sender_profile_id
created_at
```

No body expected.

## `resource.exchange_changed`

Require:

```text
chat_id
request_id
agreement_id
agreement_event_id
created_at
terms_id?   // optional
```

No agreement text/details expected.

Reject malformed/unknown events safely and expose connection issue rather than trusting partial payloads.

---

# 24. Resource private subscription

Subscribe to:

```text
resource-chat:<chatId>:profile:<expectedProfileId>
```

with:

```text
RealtimeChannelConfig(private: true)
```

Listen only for:

```text
resource.chat_message_sent
resource.exchange_changed
```

No client broadcast writes.

Return a closeable subscription abstraction similar to Project chat.

---

# 25. Resource chat detail controller

Use an identity- and chat-bound controller.

State:

```text
phase
expectedProfileId
chatId
summary
messages            // oldest first
hasMoreOlder
isLoadingOlder
isSending
failure
hasConnectionIssue
```

On initial load:

1. validate ready identity;
2. load exact summary;
3. load first message page;
4. validate all messages belong to chat;
5. reverse newest-first page into oldest-first UI order;
6. subscribe if the chat is currently writable.

---

# 26. Resource chat history pagination

Use:

```text
(created_at, message_id)
```

from the oldest currently loaded message as the `before` cursor.

Load older messages.

Merge/dedupe by:

```text
messageId
```

Preserve chronological UI order.

When older content is prepended, preserve scroll position like ProjectChatScreen.

---

# 27. Resource send flow

Composer max:

```text
4000
```

Do not submit blank/whitespace-only text.

One send attempt.

On success:

- merge returned sent message by ID;
- clear composer only after success;
- scroll to bottom;
- request/debounce a unified Chats refresh.

Do not rely on the Realtime echo for sender success.

---

# 28. Realtime message reconciliation

Because Realtime payload contains no body:

```text
resource.chat_message_sent
→ do not fabricate a message row
→ refresh/reconcile newest canonical message history
```

Coalesce bursts so multiple signals do not cause overlapping refresh storms.

After refresh:

- merge/dedupe by message ID;
- keep older loaded history where possible;
- update exact summary;
- refresh unified Chats list.

---

# 29. Realtime exchange-change reconciliation

On:

```text
resource.exchange_changed
```

C3B does **not** render agreement event details.

Instead:

1. reload exact Resource chat summary;
2. refresh unified Chats list;
3. if summary becomes read-only:
   - stop writable-chat subscription after processing the final signal;
   - hide composer;
   - show read-only notice.

Do not load or render the 04C4B agreement timeline yet.

---

# 30. Send `PT409` recovery

Backend uses:

```text
PT409
```

when coordination closed before the send won the race.

On `PT409`:

1. do not retry;
2. preserve unsent composer text;
3. reload exact summary;
4. refresh unified Chats;
5. if now read-only, hide composer;
6. show localized guidance:

```text
This conversation is now read-only. Your message was not sent.
```

The unsent text may remain in the field so the user does not silently lose it, but it cannot be resent while read-only.

---

# 31. Other Resource chat failures

Map at least:

```text
22023 → invalid input
42501 → forbidden
P0002 → not found if ever surfaced by canonical contract
PT409 → coordination closed/conflict
other → unavailable
```

Never expose raw backend diagnostics.

Malformed payloads are `unavailable`.

---

# 32. Reconnect catch-up

If Resource private Realtime disconnects and later reconnects:

```text
reload summary
reload/reconcile newest message page
refresh unified Chats
```

Do not assume missed events will replay.

---

# 33. Resource chat screen

Create a dedicated screen.

App bar:

```text
listing title
```

Body:

```text
human message history only
```

Show counterpart context near the top or under title:

```text
owner sees requester display name
requester sees owner display name
```

Do not show phone/email.

---

# 34. No agreement UI yet

The Resource chat exact summary includes:

```text
agreement_lifecycle
agreement_id
```

C3B may use lifecycle only to choose neutral state/read-only presentation.

Do not add:

- terms card;
- propose/counter-propose;
- accept/reject terms;
- milestone buttons;
- return controls;
- timeline cards;
- overdue warnings.

Those are C3C.

Do not show fake placeholder actions.

---

# 35. Open-state composer

When:

```text
summary.hasSendEntitlement == true
```

show normal message composer.

Use Resource-specific localization, even if presentation widget is factored/shared with Project chat.

Do not show Project Needs control in Resource chat.

---

# 36. Read-only presentation

When:

```text
hasSendEntitlement == false
```

hide composer and show a clear neutral notice:

```text
This conversation is read-only because this resource coordination has ended.
```

History remains scrollable/readable.

Do not imply:

- successful exchange if lifecycle cancelled;
- fault;
- dispute;
- rating.

---

# 37. Empty chat

If no messages exist:

```text
No messages yet.
Use this conversation to coordinate the resource exchange.
```

Only show the second sentence while send entitlement exists.

For read-only empty history, use neutral history copy.

---

# 38. Unified Chats card routing

Centralize card rendering/routing by discriminator.

```text
project_chat
→ existing Project route/card behavior

resource_chat
→ Resource route/card
```

Do not scatter binary assumptions across unrelated files.

Future persistent Groups may introduce another chat kind later.

Do **not** implement Groups now.

---

# 39. Future Groups compatibility

Keep the unified chat discriminator architecture extendable.

A future product area may add:

```text
group_chat
```

for persistent informal Groups.

C3B should require adding one typed branch at a central parser/card/router boundary, not rewriting every Messages component.

No Group domain, membership, invite, WhatsApp or group-chat implementation belongs here.

---

# 40. Project Chat regression requirements

The migration of the Chats list must not change:

- Project chat route;
- Project chat detail behavior;
- Needs drawer;
- system event rendering;
- former-member read-only history;
- Project Realtime;
- pagination;
- info screen;
- current Project chat tests.

Only the **Messages Chats list source** changes to unified C2 projection.

---

# 41. Unified chat list Project Realtime

For writable loaded Project rows, reuse existing Project private signal subscriptions.

Do not duplicate Project-chat signal parsing.

When Project signals arrive:

```text
debounce unified list refresh
```

Existing Project detail-specific refresh behavior remains owned by ProjectChatController.

---

# 42. Unified chat list Resource Realtime

For writable loaded Resource rows, subscribe using ResourceChatGateway.

On either Resource signal:

```text
debounce unified list refresh
```

If an exchange-change refresh turns the row read-only, close its list subscription after the canonical refresh.

---

# 43. Subscription scale

Subscribe only to currently loaded writable chat rows.

Do not prefetch/subscribe to every historical chat in the account.

As `loadMore` expands the loaded window:

```text
add needed subscriptions
```

When refresh removes rows:

```text
close stale subscriptions
```

---

# 44. App/account lifecycle

On sign-out/account switch:

- close all list subscriptions;
- close Resource detail subscription;
- clear unified Chats state;
- clear Resource chat detail state;
- ignore late responses.

If there is an established app-resume hook/pattern, refresh active Resource chat + unified Chats on resume.

Do not invent a background polling loop.

---

# 45. Localization

Add concepts equivalent to:

```text
Resource conversation
Resource exchange
Owner
Requester

No messages yet.
Use this conversation to coordinate the resource exchange.

This conversation is read-only because this resource coordination has ended.
This conversation is now read-only. Your message was not sent.

Message
Send
Load older messages
Unable to load conversation.
Unable to send message.
Connection issue. Refresh to check for new messages.

Open conversation
```

Reuse existing date formatting/patterns.

No hard-coded production copy.

---

# 46. Accessibility

Cover:

- chat cards as buttons;
- Project vs Resource context in semantics;
- read-only chip/state;
- message sender/body/time semantics;
- composer;
- send progress;
- connection warning live region;
- send-conflict notice live region;
- high text scaling;
- long listing titles/messages.

Do not use color alone to indicate read-only state.

---

# 47. Tests — unified chat models/gateway

Cover:

- Project branch strict parse;
- Resource branch strict parse;
- cross-branch null/XOR validation;
- all Project viewer roles;
- owner/requester Resource roles;
- all agreement lifecycle values;
- preview all-null/all-present;
- three-part chat cursor params;
- same chat UUID in two kinds;
- unknown item kind fails safely.

---

# 48. Tests — unified Chats controller

Cover:

- mixed chronological page;
- load more;
- composite dedupe;
- equal timestamp cross-kind order preserved from backend;
- refresh;
- partial failure;
- account switch;
- only loaded writable rows subscribed;
- stale subscriptions closed;
- signal burst debounce;
- reconnect canonical refresh.

---

# 49. Tests — Messages Chats UI

Cover:

- existing Project card behavior unchanged;
- Resource card;
- Resource read-only state;
- human preview;
- no-message preview;
- agreement activity can reorder card without changing preview;
- Project route;
- Resource route;
- mixed pagination;
- no agreement/system fake message copy.

---

# 50. Tests — Resource gateway/parser

Cover exact RPC contracts:

```text
get_own_resource_request_chat
list_own_resource_request_chat_messages
send_resource_request_chat_message
```

and private topic subscription:

```text
resource-chat:<chatId>:profile:<profileId>
```

Strict signal parsing for both event types.

Malformed signal → connection issue, never partial state mutation.

---

# 51. Tests — Resource detail controller

Cover:

- load summary + messages;
- newest-to-oldest conversion;
- load older;
- dedupe;
- send success;
- sender Realtime echo does not duplicate;
- remote message signal causes canonical refresh;
- exchange signal refreshes summary;
- completion/cancellation turns read-only;
- reconnect catch-up;
- account switch;
- late response ignored.

---

# 52. Tests — send conflicts

Cover:

```text
PT409
→ no retry
→ composer text preserved
→ summary reload
→ unified Chats reload
→ read-only UI if canonical state closed
```

Also 22023/42501/unavailable mappings.

---

# 53. Tests — Resource chat screen

Cover:

- owner/requester counterpart display;
- human bubbles;
- own-message "You";
- no messages;
- open composer;
- read-only notice;
- load older;
- sending progress;
- failed send preservation;
- connection warning;
- high text scale/long body.

---

# 54. Tests — C3A Resource request handoff

Accepted Resource request detail:

```text
chatId present
→ Open conversation
```

Coordination closed still opens read-only history.

Pending/rejected/withdrawn/listing-closed do not show it.

---

# 55. Router tests

Cover:

```text
/messages/chats/resource/:chatId
```

and preserve:

```text
/messages/chats/:chatId
```

for Project chats.

No collision/misrouting.

---

# 56. Documentation / roadmap

Update:

```text
04C4C3A — PR #78, Resource requests + unified Requests
04C4C3B — this PR, Resource conversation + unified Chats
04C4C3C — Mobile Scambio Agreement Experience
04C4C3D — Mobile Resources Notification UX
```

Document that Resource chat currently renders human messages only; structured agreement history remains canonical backend state but is not shown until C3C.

Document future Groups compatibility only as an extension point, not implemented scope.

---

# 57. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused Flutter tests and formatting.

No DB migration is expected.

The inherited stacked DB/hosted CI constraints remain outside C3B itself.

Attempt hosted Validation once.

If GitHub again cannot allocate a runner because of account payment/spending-limit status:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- agreement terms proposal UI;
- counterproposal UI;
- terms accept/reject/withdraw UI;
- milestone/handoff/return UI;
- agreement timeline UI;
- overdue UI;
- Resource notification copy/routes/preferences;
- push-provider delivery;
- generic DMs;
- read receipts;
- typing indicators;
- attachments;
- reactions;
- Dona policy redesign;
- first-class Presta listing UI;
- loan availability/queue;
- matching;
- saved searches;
- Groups;
- group/project invite flows;
- WhatsApp migration/invite features.

---

# Acceptance criteria

Ready for review when:

- [ ] based on PR #78;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] strict unified Project/Resource chat models exist;
- [ ] unified chat cursor has activity/kind/chat ID;
- [ ] dedupe uses `(kind, chatId)`;
- [ ] Messages Chats tab uses C2 unified projection;
- [ ] Project chat cards/routes remain behaviorally unchanged;
- [ ] Resource chat cards/routes exist;
- [ ] no N+1 Resource exact-read from chat cards;
- [ ] Resource chat exact/history/send gateway exists;
- [ ] private Resource Realtime subscription exists;
- [ ] Realtime message signal never fabricates body;
- [ ] exchange-change signal refreshes summary/list only;
- [ ] Resource history is permanent for counterparties;
- [ ] composer shown only while send entitlement true;
- [ ] completed/cancelled coordination renders read-only history;
- [ ] PT409 send conflict performs no retry and preserves text;
- [ ] history pagination/deduplication correct;
- [ ] sender Realtime echo does not duplicate sent message;
- [ ] reconnect performs canonical catch-up;
- [ ] accepted Resource request can open conversation;
- [ ] Project Chat detail/Needs/Realtime regressions preserved;
- [ ] only loaded writable chats have list subscriptions;
- [ ] account switching closes subscriptions/clears private state;
- [ ] no agreement/notification/Groups scope creep;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C4C3B branch/base/PR**
3. **Changed files**
4. **Unified chat domain model**
5. **Project chat branch parsing**
6. **Resource chat branch parsing**
7. **Unified chat cursor/deduplication**
8. **Unified Chats gateway**
9. **Unified Chats controller**
10. **Project list subscription reuse**
11. **Resource list subscriptions**
12. **Realtime debounced list refresh**
13. **Messages Chats UI**
14. **Project chat regression**
15. **Resource chat card**
16. **Resource chat route**
17. **Accepted-request Open conversation handoff**
18. **Resource chat domain models**
19. **Resource chat gateway**
20. **Resource exact-summary parsing**
21. **Resource history/send parsing**
22. **Resource Realtime signal parsing**
23. **Resource detail controller**
24. **History pagination/deduplication**
25. **Send behavior**
26. **PT409 send-conflict recovery**
27. **Message Realtime reconciliation**
28. **Exchange-change reconciliation**
29. **Read-only closed coordination**
30. **Reconnect catch-up**
31. **Account-switch safety**
32. **Localization/accessibility**
33. **Gateway/controller/widget tests**
34. **Router tests**
35. **Local regression validation**
36. **Hosted Validation executed/not-executed**
37. **04C4C3C handoff**
38. **04C4C3D handoff**
39. **Groups/chat future-compatibility handoff**
40. **Warnings/blockers**
41. **Commit/PR reference**

Do not merge any PR.
