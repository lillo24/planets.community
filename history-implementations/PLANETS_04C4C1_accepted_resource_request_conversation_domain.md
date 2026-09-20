# PLANETS 04C4C1 — Accepted Resource-Request Conversation Domain + Realtime

**Roadmap area:** 04C4C — Resource Requests + Messages  
**Task type:** Backend conversation/Realtime foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #72 — 04C4B Reliable Scambio Agreement + Loan/Barter Domain
branch: codex/04c4b-reliable-scambio-agreement-domain
head:   c2fa1e2084178817eaad2c1d301a0112567550b8
```

Its dependency stack remains open/unmerged.

Before implementation:

1. fetch current `origin/main`;
2. confirm PR #72 still points to the expected head, or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #72 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c1-resource-request-conversation-domain
```

Open the new PR against:

```text
codex/04c4b-reliable-scambio-agreement-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C1_accepted_resource_request_conversation_domain.md
```

No external document is required.

---

# Objective

Create the private two-party conversation domain for an **accepted Scambio-Dona request**.

This is not a generic DM feature.

```text
resource listing request
        ↓
owner accepts
        ↓
accepted request
        ├── exchange agreement exists
        └── resource-request chat exists
```

Send entitlement follows the agreement coordination episode:

```text
coordination open
→ owner + requester may send

agreement completed/cancelled
→ chat becomes read-only

history remains readable
```

A later request episode creates a separate conversation.

Listing closure does not terminate an already-accepted/open conversation.

---

# 1. Separate chat domain

Do not reuse `project_group_chats` or `project_chat_messages`.

Create resource-request-specific tables because authorization derives from:

```text
resource_listing_requests
resource_listings
resource_exchange_agreements
```

Reuse Project-chat patterns, not Project tables.

---

# 2. Chat anchor

Add a private table equivalent to:

```text
public.resource_request_chats
```

Fields:

```text
id uuid primary key
request_id uuid unique not null
activated_at timestamptz not null
```

Counterparties derive from canonical request/listing ownership.

No duplicated chat-members table.

---

# 3. Atomic activation on request acceptance

Create a forward migration replacing the **latest PR #72** definition of:

```text
accept_resource_listing_request(...)
```

When `pending → accepted`, one transaction must guarantee:

```text
exactly one resource_exchange_agreement
exactly one resource_request_chat
```

Prefer the request acceptance timestamp as `activated_at`.

No committed accepted request may exist without both anchors.

---

# 4. Backfill accepted requests

Create exactly one chat for every existing:

```text
status = accepted
```

including requests whose agreement is already completed/cancelled.

They are immediately read-only when `coordination_closed_at` is non-null.

Do not create chats for pending/rejected/withdrawn/listing_closed requests.

Backfill must be idempotent.

---

# 5. Human message table

Add:

```text
public.resource_request_chat_messages
```

Fields equivalent to:

```text
id uuid primary key
chat_id uuid not null
sender_profile_id uuid not null
body text not null
created_at timestamptz not null
```

Use the Project-chat plaintext convention:

```text
trimmed
1..4000 characters
server timestamp
```

Messages are immutable.

---

# 6. Message immutability

Reject direct update/delete with a trigger.

No edit/delete behavior here.

Future moderation should use separate moderation state rather than rewriting message history.

---

# 7. Historical read entitlement

The two fixed counterparties can read the entire request-conversation history permanently:

```text
listing owner
request requester
```

This remains true after:

```text
agreement completion
agreement cancellation
listing closure
```

No former-member-style time frontier is needed.

Unrelated users must fail closed.

---

# 8. Send entitlement

Both counterparties may send only while:

```text
request.status = accepted
AND request.coordination_closed_at IS NULL
AND agreement.lifecycle_state not in ('completed', 'cancelled')
```

Listing lifecycle does not control accepted conversation sending.

Therefore:

```text
listing closed + open accepted agreement
→ chat still sendable
```

---

# 9. Send vs coordination-close serialization

A send must lock the same `resource_exchange_agreements` row used by completion/cancellation.

Valid ordering:

```text
send locks first
→ message commits
→ close happens later
```

or:

```text
completion/cancel locks first
→ coordination closes
→ later send rejected
```

Never allow a committed message after canonical close ordering.

---

# 10. Identity requirement

Read requires authenticated canonical counterparty identity.

Send additionally requires a complete profile/display identity, consistent with Project chat.

No phone/email exposure.

---

# 11. Send RPC

Add:

```text
send_resource_request_chat_message(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_body text
)
```

Return:

```text
message_id
chat_id
sender_profile_id
created_at
body
```

Validate identity, counterparty membership, open coordination and body bounds.

Closed coordination should map to a stable lifecycle-unavailable failure, not custom `40001`.

---

# 12. History RPC

Add newest-first keyset history:

```text
list_own_resource_request_chat_messages(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_message_id uuid default null
)
```

Limit 1..50.

Cursor:

```text
(created_at, message_id)
```

Return sender display context and body.

---

# 13. Exact chat summary

Add:

```text
get_own_resource_request_chat(
  p_expected_profile_id uuid,
  p_chat_id uuid
)
```

Return at least:

```text
chat_id
request_id
agreement_id
listing_id
listing_title

viewer_role                // owner | requester
owner_profile_id
owner_display_name
requester_profile_id
requester_display_name

agreement_lifecycle
coordination_closed_at
has_send_entitlement

activated_at

last_visible_message_id
last_visible_message_body
last_visible_message_at
last_visible_sender_profile_id
last_visible_sender_display_name

activity_at
```

Do not copy the request's initial private message here unless current repository conventions clearly require it.

---

# 14. Resource-chat list

Add:

```text
list_own_resource_request_chats(
  p_expected_profile_id uuid,
  p_limit integer,
  p_before_activity_at timestamptz default null,
  p_before_chat_id uuid default null
)
```

Stable descending cursor:

```text
(activity_at, chat_id)
```

Use the same summary shape.

This remains resource-chat-specific. Do not build a unified Project+Resource pagination layer yet.

---

# 15. Activity semantics

Define:

```text
activity_at =
max(
  activated_at,
  latest human resource-chat message time,
  latest resource_exchange_agreement_event time
)
```

Agreement changes should therefore bubble the conversation in future Messages UI.

But:

```text
last_visible_message_*
```

must remain honest human-message preview fields.

Never put fake agreement/system copy in them.

---

# 16. Agreement timeline remains canonical

Do not duplicate 04C4B events into the human message table.

Future mobile can render:

```text
human chat
+
current agreement card
+
structured agreement timeline
```

No fake system user.

---

# 17. Realtime topic

Add private per-profile topic:

```text
resource-chat:<chatId>:profile:<profileId>
```

Use a canonical helper and strict parsing.

Do not reuse Project-chat topics.

---

# 18. Realtime authorization

Only listing owner and request requester may subscribe to their exact profile-specific topic.

Topic-read authorization remains valid even after coordination closes.

Reason:

- final completion/cancellation refresh must reach an already-open client;
- history remains authorized;
- human send RPC separately enforces read-only state.

Do not grant client-side generic broadcast writes.

---

# 19. Human-message Realtime

Successful send broadcasts:

```text
resource.chat_message_sent
```

Identifier-only payload:

```text
chat_id
request_id
message_id
sender_profile_id
created_at
```

No message body.

Broadcast to both counterparties' private topics.

Also emit an identifier-only outbox/audit event suitable for later notification projection, e.g.:

```text
resource_chat.message_sent
```

Keep final naming stable/documented.

---

# 20. Agreement-change Realtime bridge

Evolve the latest 04C4B agreement-event recorder so that when a resource chat exists, each agreement transition also emits a private refresh hint to both counterparties.

Use a generic event such as:

```text
resource.exchange_changed
```

Identifier-only payload:

```text
chat_id
request_id
agreement_id
agreement_event_id
terms_id?     // when relevant
created_at
```

`event_kind` may be included if useful for routing, but no terms content.

Realtime is only a hint to reload durable state.

---

# 21. Final completion/cancellation signal

Completion/cancellation must still broadcast in the same transaction even though they close send entitlement.

Because topic authorization is counterpart-based, both users remain authorized to receive that final refresh.

---

# 22. No system rows in human message table

Do not insert agreement events as chat messages.

Human table = human-authored text only.

Agreement timeline = structured canonical domain history.

---

# 23. Closed coordination behavior

After completion/cancellation:

```text
history readable
summary still listed
agreement history readable
send disabled
```

Do not delete/archive the chat out of existence.

---

# 24. Repeat-request isolation

One chat belongs to one request episode.

Never reuse a chat because:

```text
same listing
same owner/requester pair
same people
```

A later request creates a new conversation.

---

# 25. Listing closure

Listing closure:

```text
pending requests → listing_closed, no chat
accepted/open request → chat remains available/sendable
accepted/closed coordination → chat remains historical/read-only
```

---

# 26. Privacy

No public resource chat API.

No anonymous chat/history access.

No unrelated-user access.

Never expose in Realtime/outbox:

- chat body;
- private agreement note;
- requester resource description;
- phone/email;
- exact handoff location.

Private summary may include counterpart display names.

---

# 27. RLS/grants

Chat/message tables:

- RLS on;
- no direct client table policies;
- revoke public/anon/authenticated/service table privileges;
- RPC-only access;
- fixed/empty search paths.

Realtime policy grants only required private broadcast read authorization.

---

# 28. PT409 convention

Preserve:

```text
PT409 = explicit application stale/race conflict
40001 = genuine PostgreSQL serialization failure
```

Do not introduce custom `40001`.

---

# 29. Structural pgTAP

Cover:

- chat table;
- one request per chat;
- message table;
- body constraints;
- message immutability;
- indexes;
- RLS/no direct grants;
- Realtime topic helper/policy;
- send/history/exact/list RPC signatures;
- latest request-accept creates agreement+chat;
- agreement event recorder has safe Realtime bridge.

---

# 30. Behavioral pgTAP — activation/backfill

Cover:

- accepted request creates chat;
- agreement+chat created atomically with acceptance;
- existing accepted requests backfilled;
- no chat for non-accepted requests;
- one chat per request;
- repeated request episode gets distinct chat.

---

# 31. Behavioral pgTAP — authorization

Cover:

- owner reads/sends while open;
- requester reads/sends while open;
- unrelated denied;
- anonymous denied;
- listing closure does not disable open chat;
- completion/cancellation disables send;
- history remains readable afterward.

---

# 32. Behavioral pgTAP — bodies

Cover:

- trim;
- empty rejected;
- >4000 rejected;
- sender derived from auth identity;
- update/delete rejected;
- server timestamp.

---

# 33. Behavioral pgTAP — list/activity

Cover:

- no-message chat activity starts at activation;
- terms proposal bumps activity;
- milestone bumps activity;
- human message bumps activity;
- human preview remains human-only;
- agreement events never appear as fake message text;
- stable list/history pagination.

---

# 34. Concurrency — send vs cancellation

Test both serialization outcomes.

Never commit a message after canonical cancellation boundary.

---

# 35. Concurrency — send vs automatic completion

Race one human send against the final required agreement milestone.

Valid:

```text
send first, then completion
```

or:

```text
completion first, send rejected
```

No post-close committed message.

---

# 36. Acceptance concurrency

Request acceptance races must still produce:

```text
one accepted request
one agreement
one chat
```

No duplicate anchor.

---

# 37. Real OTP/Realtime verifier

Cover at least:

1. pending request has no chat;
2. owner accepts;
3. agreement+chat exist;
4. both counterparties subscribe to exact private topics;
5. unrelated user cannot subscribe;
6. requester sends;
7. owner receives identifier-only message signal;
8. signal has no body;
9. durable history returns body;
10. owner/requester agreement mutation produces exchange-refresh signal;
11. private agreement content absent from signal;
12. listing closes while coordination open and send still works;
13. final milestone completes agreement;
14. both receive final refresh;
15. later send denied;
16. both still read history;
17. chat summary is read-only;
18. a later accepted request episode gets another chat.

Never log OTPs, tokens, message bodies, private notes, requester resource descriptions, loan timestamps or contact data.

---

# 38. Outbox compatibility

Human message event must contain enough identifiers for a later notification projection to resolve the opposite counterparty.

Do not create notifications in C1.

Agreement events remain 04C4B events; do not duplicate them merely for notifications.

---

# 39. Generated types

Update/regenerate types for chat/message tables and RPCs.

If Supabase remains unavailable:

- derive only compile-required deltas carefully;
- state drift is unverified;
- retain `db:types:check` as hard pre-merge gate.

---

# 40. Roadmap split

Refine 04C4C to:

```text
04C4C — Resource Requests + Messages (parent)

04C4C1 — Accepted Resource-Request Conversation Domain + Realtime
  this plan

04C4C2 — Resource Request Messages + Notification Projection
  structured resource-request Messages items
  Resources-category notification projection
  semantic destinations
  resource chat alerts

04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience
  Request / Withdraw
  owner Accept / Reject
  N interested
  Messages request cards
  resource chat
  agreement negotiation/milestones
```

Do not implement C2/C3 here.

---

# 41. C2 handoff

Provide stable contracts for:

```text
resource request exact/history
resource chat summaries
resource chat history/send
resource chat Realtime
resource exchange refresh Realtime
resource chat message outbox
```

C2 can project request/decision/message alerts without direct table access.

---

# 42. C3 handoff

Mobile should later support:

```text
Scambio listing detail → Request

Messages / Requests → resource request

accepted request → resource chat

resource chat:
- human messages
- agreement card
- terms negotiation
- milestone controls
- structured timeline
```

No Flutter work here.

---

# 43. Validation

Run available:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new verifier>
git diff --check
```

Run SQL parsing.

Attempt hosted Validation once.

If GitHub again cannot allocate a runner because of billing/spending limits, report:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because this is schema-heavy, do not merge until clean replay, DB lint/advisors, pgTAP, real OTP/Realtime integration and generated-type drift all execute green.

---

# Non-goals

Do not implement:

- Flutter request/chat/agreement UI;
- structured resource-request Messages cards;
- notification projection;
- push;
- generic DMs;
- attachments;
- reactions;
- typing indicators;
- read receipts;
- contact disclosure;
- exact handoff location;
- fake system messages;
- loan queue/calendar;
- matching;
- saved searches;
- disputes/moderation;
- post-handoff amendments.

---

# Acceptance criteria

- [ ] based on PR #72;
- [ ] exact prompt archived;
- [ ] separate resource-request chat anchor;
- [ ] separate immutable message table;
- [ ] one chat per accepted request;
- [ ] accept creates agreement+chat atomically;
- [ ] existing accepted requests backfilled;
- [ ] only counterparties read history;
- [ ] open coordination required to send;
- [ ] listing closure does not disable accepted open chat;
- [ ] completion/cancellation makes chat read-only;
- [ ] send serializes against close;
- [ ] body canonical and <=4000 chars;
- [ ] exact/history/list RPCs;
- [ ] agreement events influence `activity_at`;
- [ ] human preview fields stay human-only;
- [ ] private per-profile Realtime;
- [ ] only counterparties subscribe;
- [ ] message Realtime contains no body;
- [ ] agreement-change Realtime contains identifiers only;
- [ ] final close signal still delivered;
- [ ] no fake system sender/message;
- [ ] RLS/grants fail closed;
- [ ] PT409 convention preserved;
- [ ] pgTAP/concurrency/Realtime verifier added;
- [ ] generated types updated where executable;
- [ ] no C2/C3 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4C1 branch/base/PR
3. Changed files
4. Chat anchor schema
5. Atomic request-accept activation
6. Accepted-request backfill
7. Message schema
8. Message immutability/body limits
9. Historical read authorization
10. Send entitlement
11. Send-vs-close locking
12. Send RPC
13. History RPC
14. Exact chat summary
15. Resource chat list
16. Activity/preview semantics
17. Realtime topic
18. Realtime authorization
19. Human-message Realtime
20. Agreement-change Realtime
21. Final completion/cancellation signal
22. Read-only closed behavior
23. Repeat-request isolation
24. Listing-close behavior
25. Privacy/RLS/grants
26. PT409 behavior
27. pgTAP
28. Send-vs-cancel concurrency
29. Send-vs-completion concurrency
30. Acceptance concurrency
31. Real OTP/Realtime integration
32. Outbox contract
33. Generated types/drift
34. Local regression validation
35. Hosted Validation executed/not-executed
36. 04C4C2 handoff
37. 04C4C3 handoff
38. Warnings/blockers
39. Commit/PR reference

Do not merge any PR.
