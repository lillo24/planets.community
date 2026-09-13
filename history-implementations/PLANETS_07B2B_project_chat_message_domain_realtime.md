# PLANETS 07B2B — Project Chat Message Domain and Realtime Transport

**Roadmap area:** PLANETS 07 — Messages + Project Chat  
**Task type:** Production backend/domain + secure realtime transport  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged base when this prompt was written:** `bb26ef4a518484da6f67b3309d2cfd62e4d2b483` (07B1 / PR #26)

## Objective

Implement the **production server-authorized Project group-chat message domain** on top of merged 07B1.

This plan deliberately does **not** use end-to-end encryption.

The founder has decided to defer E2EE as an optional future privacy enhancement because its operational and product complexity is not justified for the current PLANETS MVP.

Current MVP security model:

```text
Flutter
   ↓ HTTPS/TLS
Supabase API / Realtime
   ↓ authenticated profile + strict authorization
PostgreSQL chat messages
```

The backend can technically read message bodies.

Do not describe this architecture as end-to-end encrypted.

07B1 already provides:

- exactly one chat anchor per Project;
- first accepted join request creates/activates it;
- immutable Project creator entitlement;
- canonical current/former membership history;
- leave/removal/rejoin semantics;
- no message persistence yet.

07B2B adds:

- durable text messages;
- exact read-history rules;
- current-member send authorization;
- server-side pagination;
- accessible chat-list summaries for the future Messages UI;
- secure Realtime notification of new durable messages;
- identifier-only future notification/outbox hook;
- Proposal + Tavolo coverage.

The following **founder-approved history rule** is canonical for this MVP:

> Any currently accepted participant can read the full existing Project chat history, including messages sent before they first joined.

Additional consistent behavior:

- creator can always read/send once the chat exists;
- current accepted participant can read the entire existing history and send;
- after leave/removal, a former participant keeps everything they were entitled to see up to the end of their latest membership, but cannot read newer messages or send;
- if that participant later rejoins, the full accumulated chat history becomes visible again, including messages sent during the gap;
- after a later leave/removal, they retain everything through that later membership end;
- unrelated users never gain chat access.

This turns the Project chat into a durable **project coordination log**, not a set of disconnected membership-interval archives.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_07B2B_project_chat_message_domain_realtime.md
```

---

# Important: PR #28 / E2EE research is not the implementation base

PR #28:

```text
codex/07b2a-mls-e2ee-prototype
```

is useful research/prototype work, but it is intentionally **unmerged** and is now deferred.

Do not:

- merge PR #28 as part of this task;
- rebase this task onto PR #28;
- cherry-pick its OpenMLS dependency;
- copy MLS prototype code;
- add crypto-device/key-package/epoch infrastructure.

Base this task on current `main`.

Repository documentation should record the research accurately:

```text
E2EE / MLS
  researched in unmerged PR #28
  technically feasible
  deferred as optional future enhancement
  not a current MVP requirement
```

Do not delete or rewrite the remote research branch/PR unless separately instructed.

---

# Why 07B2 is split

The remaining production chat work spans two distinct layers:

```text
07B2B
  durable message domain
  authorization
  history semantics
  pagination
  secure realtime transport

07B2C
  Flutter Messages integration
  chat screen
  composer
  realtime synchronization
  group info
  project/participation/meeting navigation
```

Implement only 07B2B here.

---

# Required repository inspection

Before implementation inspect at minimum:

1. root/nested `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/implementation/roadmap.md`;
5. `docs/development/database.md`;
6. 05A participation migration and lock discipline;
7. 07A structured Messages APIs;
8. merged 07B1 migration:
   - `public.project_group_chats`;
   - creator/current/history helpers;
   - membership-at-time helper;
   - `get_own_project_group_chat`;
9. 07B1 pgTAP + real integration;
10. notification/outbox conventions;
11. Supabase local config/version and Realtime configuration;
12. generated DB-type conventions;
13. CI.

Use current repository evidence over assumptions in this prompt.

---

# 1. Product/security decision update

Update repository product decisions to supersede the previous current-E2EE requirement.

Record:

> PLANETS Project chat uses ordinary authenticated server-authorized messaging for the MVP. Transport is protected by HTTPS/TLS and database/API access is restricted by authenticated profile authorization. The PLANETS backend remains technically capable of reading stored chat messages. MLS/E2EE was prototyped in unmerged PR #28 and is deferred as an optional future privacy enhancement.

Do not claim:

- zero-knowledge messaging;
- client-only keys;
- Signal-style privacy;
- encrypted message content from PLANETS itself.

Future E2EE may introduce a new message format/version rather than being a requirement for this schema.

---

# 2. Canonical message table

Add one durable table equivalent to:

```text
public.project_chat_messages
```

Suggested concepts:

```text
id
chat_id
sender_profile_id
body
created_at
```

Exact naming is Codex-owned.

Requirements:

- UUID primary key;
- FK to `project_group_chats`;
- sender FK to `profiles`;
- centrally generated immutable timestamp;
- body canonically trimmed;
- body non-empty;
- bounded size.

Use a practical MVP text maximum, preferably around **4,000 Unicode characters**, unless repository conventions support a better existing limit.

Do not add yet:

- attachments;
- reactions;
- edit state;
- deletion state;
- reply/thread structure;
- read receipts;
- delivery receipts;
- encryption fields;
- HTML/rich-text payload;
- arbitrary JSON body.

Plain text only.

---

# 3. Message immutability

For this MVP, messages are immutable.

No public operation for:

- edit;
- delete;
- redact.

Plan 09/account-privacy work may later add moderation/deletion behavior.

Protect immutable columns from direct update.

Do not add soft-delete fields “just in case.”

---

# 4. Read authorization — full previous history for current members

07B1's `profile_was_project_member_at(...)` remains useful canonical participation history, but it is **not** the final message-read rule because current participants now receive earlier history.

Add a dedicated private message-read primitive equivalent to:

```text
private.profile_can_read_project_chat_message(
  p_project_id,
  p_profile_id,
  p_message_created_at
)
```

Canonical semantics:

## Creator

```text
creator => can read every message in the Project chat
```

## Current accepted member

```text
current member => can read every message in the Project chat
```

This explicitly includes messages earlier than their first `joined_at`.

## Former member

If there is no current membership:

```text
latest_membership_end =
  max(coalesce(left_at, removed_at))
```

Then the former participant can read messages that were available before their latest membership ended.

Conceptually:

```text
message_created_at <= latest_membership_end
```

Use database-consistent timestamp/race semantics rather than blindly copying this pseudocode.

## Rejoin

When the profile becomes current again:

```text
all existing messages become readable
```

including messages sent in the prior gap.

If they later leave again, the new latest membership end becomes their new historical visibility frontier.

## Unrelated

No accepted membership history + not creator:

```text
no access
```

This rule is intentional.

---

# 5. Leave/remove/send race correctness

A participant losing current membership and sending a message may race.

The database must establish deterministic ordering so a message cannot be successfully sent **after** membership termination merely because the client had stale UI state.

Reuse the repository's existing Project/participation locking discipline where possible.

Requirements:

- send authorization is checked transactionally;
- leave/remove and send cannot commit in an inconsistent order;
- creator send is unaffected by participant membership;
- avoid introducing a lock order that can deadlock existing participation transitions;
- do not rely on Flutter state as authorization.

Codex owns the precise locking mechanism after inspecting 05A.

Add a concurrency test.

---

# 6. Send-message RPC

Add an expected-identity-bound authenticated RPC equivalent to:

```text
send_project_chat_message(
  p_expected_profile_id,
  p_chat_id,
  p_body
)
```

Requirements:

- authenticated complete profile;
- expected identity must match current profile;
- chat must exist;
- caller must have **current chat entitlement**:
  - Project creator; or
  - current accepted participant;
- former members cannot send;
- unrelated users cannot send;
- canonical trim/length validation;
- timestamp generated server-side;
- sender ID generated from authenticated identity, never trusted from input.

Return enough canonical data for future Flutter optimistic/reconciliation behavior, preferably:

```text
message_id
chat_id
sender_profile_id
created_at
body
```

or a similarly narrow shape.

Do not return private unrelated data.

---

# 7. Identifier-only outbox hook

On successful message creation, emit an identifier-only event for future notification work.

Use a clear type such as:

```text
project.chat_message_sent
```

Payload may contain only safe identifiers/context needed later, e.g.:

```text
chat_id
project_id
project_kind
message_id
sender_profile_id
```

Do **not** include:

- message body;
- email;
- exact meeting information;
- location;
- request private text.

07B2B does **not** project this event into in-app/push notifications yet.

Do not modify current notification consumers to process it.

---

# 8. Message-history RPC

Add a bounded keyset-paginated authenticated RPC equivalent to:

```text
list_own_project_chat_messages(
  p_expected_profile_id,
  p_chat_id,
  p_limit,
  p_before_created_at?,
  p_before_message_id?
)
```

Requirements:

- expected identity bound;
- unauthorized/missing chat fails safely according to repository conventions;
- enforce the message-level read rule above;
- stable keyset order:

```text
created_at DESC
message_id DESC
```

- practical bounded limit, consistent with repository paging patterns;
- no OFFSET pagination.

Return:

```text
message_id
chat_id
sender_profile_id
sender_display_name
body
created_at
```

Optional extra public-safe sender display fields only if already canonical.

Never return Auth email.

## Current member joining late

A newly accepted current participant calling the first page must receive the newest existing messages immediately, even if all of them predate that participant's membership.

Paging backward eventually reaches the beginning of the chat.

This is a core acceptance requirement.

## Former member

The same RPC must naturally stop at the former member's latest visibility frontier and never include later messages.

---

# 9. Exact message read is optional

Do not add a single-message public RPC unless Realtime reconciliation genuinely needs it.

Prefer:

```text
Realtime signal
→ refresh/list delta from canonical history RPC
```

over proliferating APIs.

If an exact-message read materially simplifies a secure realtime flow, add it narrowly and test the same authorization helper.

Report the choice.

---

# 10. Accessible chat-list RPC

07B2C needs to populate the authenticated Messages surface with Project chats.

Add a keyset-paginated RPC equivalent to:

```text
list_own_project_group_chats(
  p_expected_profile_id,
  p_limit,
  p_before_activity_at?,
  p_before_chat_id?
)
```

Return one item per accessible chat.

Suggested fields:

```text
chat_id
project_id
project_kind
project_title
viewer_role
has_current_entitlement
has_history_entitlement
activated_at

last_visible_message_id?
last_visible_message_body?
last_visible_message_at?
last_visible_sender_profile_id?
last_visible_sender_display_name?

activity_at
```

## Visibility

A chat is visible to:

- creator;
- current member;
- former member with accepted history.

## Last visible message

For current members/creator:

```text
latest message in chat
```

For former participants:

```text
latest message they are authorized to read
```

A new inaccessible message after they leave must **not**:

- change their preview;
- change their activity ordering;
- leak that someone sent something.

## Activity ordering

Use:

```text
coalesce(last_visible_message_at, activated_at)
```

with deterministic UUID tie-break.

Do not expose membership-private data from other users.

---

# 11. Realtime is a hint, durable PostgreSQL is authoritative

Realtime must not become the message history.

Canonical flow:

```text
send RPC
  ↓
durable PostgreSQL message
  ↓
Realtime signal
  ↓
clients reconcile/fetch durable state
```

Offline/reconnect clients recover entirely through the history RPC.

No message may exist only in Realtime.

---

# 12. Preferred Realtime design

Inspect the repository's current self-hosted-compatible Supabase/Realtime version first.

Preferred architecture, if supported cleanly by the pinned stack:

```text
database INSERT
  ↓
private Supabase Realtime Broadcast
  ↓
authorized project-chat channel
  ↓
small signal payload
```

Prefer broadcasting only safe identifiers such as:

```text
chat_id
message_id
created_at
```

rather than duplicating full message bodies into ephemeral Realtime payloads.

The client can then reconcile through the durable RPC.

## Authorization

Realtime subscription must respect **current entitlement**.

A former participant may retain old chat history but must not continue receiving live new-message events after leave/removal.

Unrelated users cannot subscribe.

Do not rely only on an obscure/unpredictable client topic string as authorization.

Use server-verifiable chat/profile authorization.

## Fallback

If the repository's pinned/local self-hosted Supabase stack cannot implement private DB-triggered Broadcast safely and testably, Codex may use Postgres Changes **only with narrow RLS/SELECT authorization**.

Do not silently grant broad table access just to make Realtime easy.

If the only available implementation would materially weaken the repository's fail-closed security model, stop and report.

---

# 13. Self-hosted portability

Realtime architecture must work with the repository's intended local/self-hosted Supabase direction.

Do not make these product invariants:

- `*.supabase.co`;
- cloud-dashboard-only configuration;
- project-ref-specific APIs;
- managed-only scheduler/control-plane behavior.

Any required publication/policy/config must live in migrations/config/repository-owned setup.

---

# 14. Realtime privacy

Do not expose through Realtime:

- messages from chats the user cannot access;
- new message signals to former participants;
- request messages;
- exact meeting details;
- exact project location;
- Auth emails;
- message bodies in logs.

If using an identifier-only signal, a current client fetches the durable message after receiving it.

---

# 15. No unread model yet

Do not implement unread/read receipts in 07B2B.

The future Messages UI may show latest activity but no unread badge for group chat yet.

Avoid prematurely adding:

```text
last_read_message_id
unread_count
read_at
```

These can be a focused later enhancement.

---

# 16. Project lifecycle

Preserve 07B1 behavior:

- Proposal completion/end does not delete chat/messages;
- Tavolo pause/end does not delete chat/messages;
- Project lifecycle alone does not revoke chat entitlement.

For this MVP, creator/current participant send entitlement remains ownership/membership-based.

Do not add an automatic read-only state merely because the concrete Project is historical.

That can be revisited separately.

---

# 17. Meeting details stay separate

Do not store meeting links/details in chat messages or chat anchor metadata.

05A remains canonical for protected meeting information.

07B2C may surface the existing protected meeting API from chat/group info for current authorized users.

Former members retaining history must not gain current protected meeting information through this work.

No meeting changes are required in 07B2B.

---

# 18. Request Messages remain separate

07A participation-request items remain a distinct structured system surface.

Do not copy accepted/rejected request items into `project_chat_messages`.

Do not create fake chat messages like:

```text
"Marco requested to join"
```

in this plan.

Future system chat events can be designed separately if desired.

---

# 19. Plaintext/privacy boundary

Message bodies are server-readable in the current MVP.

Still apply strong ordinary protections:

- HTTPS/TLS in transit;
- authentication;
- expected-identity RPCs;
- RLS/fail-closed grants where direct access is technically needed;
- no public access;
- no body in audit/outbox/logs;
- self-hosted DB/backups security later in Plan 13;
- moderation/admin access only when explicitly added in Plan 09.

Do not add application-level encryption pretending to be E2EE.

---

# 20. Database indexes

Add indexes for actual access paths, likely:

```text
(chat_id, created_at DESC, id DESC)
(sender_profile_id, created_at DESC)
```

plus any justified chat-list/activity support.

Avoid premature denormalized `last_message_*` fields unless query evidence shows they are needed.

Prefer deriving last visible message correctly first.

---

# 21. Database structural tests

Add pgTAP coverage for:

- message table shape;
- immutable ID/chat/sender/timestamp;
- body validation;
- Project-chat FK;
- RLS/grants;
- no anon/public access;
- expected RPCs;
- no edit/delete RPC;
- no E2EE/key columns;
- identifier-only outbox behavior;
- Realtime authorization/config objects.

---

# 22. Database access/behavior tests

At minimum test:

## Send

- creator sends;
- current participant sends;
- former participant denied;
- removed participant denied;
- unrelated denied;
- cross-identity denied;
- empty/whitespace denied;
- oversized body denied;
- server owns sender/timestamp.

## Full historical visibility

Scenario:

```text
C creates Project
A joins
C sends M1
B joins after M1
```

B must read M1.

That is the key changed product rule.

## Leave

```text
B sees M1..M3
B leaves
C sends M4
```

B can still read M1..M3 and cannot read M4.

## Rejoin

```text
B rejoins
```

B can now read M1..M4.

If C then sends M5 while B is current, B reads it.

If B later leaves and C sends M6, B reads through M5 but not M6.

## Removal

Creator removal uses the same history frontier semantics.

## Creator

Creator reads/sends all messages regardless of participant rows.

## Unrelated

No list/chat-summary/message access.

## Pagination

- stable keyset;
- no duplicate/skipped rows with same timestamp;
- former-member boundary remains correct across pages.

## Concurrency

Race send vs leave/remove cannot allow a post-termination participant message.

---

# 23. Realtime integration test

Add a real local Supabase integration proving the chosen Realtime path.

Use two authenticated clients where possible.

Prove:

1. creator/current member subscribes;
2. authorized sender sends through RPC;
3. durable row commits;
4. subscriber receives Realtime signal;
5. subscriber can fetch the canonical new message;
6. unrelated user cannot subscribe/receive;
7. participant leaves or is removed;
8. former participant no longer receives later live signal;
9. former participant can still fetch authorized old history;
10. rejoin restores current Realtime subscription eligibility.

If deterministic CI Realtime testing requires a dedicated helper, add it.

Do not replace this entirely with unit mocks.

---

# 24. Real local end-to-end backend integration

Add or extend a focused script, preferably:

```text
scripts/verify-local-project-chat-messages.mjs
```

Cover both one-time Proposal and recurring Tavolo identity.

At minimum:

1. creator C publishes Project;
2. A requests and is accepted;
3. C sends M1;
4. B requests and is accepted later;
5. B reads M1;
6. A sends M2;
7. B reads M1/M2;
8. B leaves;
9. C sends M3;
10. B cannot read M3;
11. B rejoins;
12. B now reads M3 as previous history;
13. B sends M4;
14. creator removes B;
15. C sends M5;
16. B cannot read M5;
17. unrelated X has no access;
18. chat-list preview/activity respects B's visible frontier while former;
19. equivalent Tavolo send/read path works;
20. no message body appears in audit/outbox/log output.

---

# 25. Generated types

Regenerate public DB types.

Expected client surface includes narrow chat RPCs.

Private authorization helpers remain absent from ordinary client contracts.

Zero generated-type drift.

---

# 26. No Flutter chat UI in this plan

Do not implement production Flutter chat UI yet.

Allowed mobile changes:

- generated DB types if repository pipeline places them there;
- no routes/screens/composer;
- no Realtime Flutter subscription.

07B2C will consume the stable API.

Do not import the unmerged OpenMLS package.

---

# 27. Roadmap reconciliation

Mark:

```text
07B1 — Implemented
PR #26
bb26ef4a518484da6f67b3309d2cfd62e4d2b483
```

Record E2EE research separately:

```text
E2EE / MLS research prototype
PR #28
unmerged / deferred
technically useful research, not production dependency
```

Do not mark PR #28 implemented.

Restructure remaining chat work:

```text
07B — Project Group Chat (parent) — In progress

07B1 — Lifecycle + Authorization Foundation — Implemented

07B2 — Project Chat Messaging and Mobile Experience (parent) — In progress

07B2B — Project Chat Message Domain and Realtime Transport — In progress
07B2C — Mobile Project Chat Experience — Not started
```

07B2C should own:

- Messages-screen Project chat list integration;
- `/messages/chats/:chatId`;
- paginated bubbles/history;
- composer/send;
- Realtime reconciliation;
- read-only former-member state;
- group info;
- Project/Tavolo navigation;
- creator Participation navigation;
- current protected meeting information;
- native QA later consolidated in Plan 12.

Keep:

```text
06C2B — Not started / external provider context required
04C — Not started
05C — Not started
```

---

# 28. Documentation

Update:

- product decisions;
- system design;
- database docs;
- roadmap.

Record clearly:

## Current MVP

```text
server-authorized plaintext chat
TLS in transit
backend can technically read stored messages
```

## History

```text
current participant → full Project chat history
former participant  → everything through latest membership end
rejoin              → full accumulated history becomes visible again
creator             → full history always
```

## E2EE

```text
researched/prototyped in unmerged PR #28
deferred
optional future enhancement
```

Do not leave repository docs claiming E2EE is currently mandatory.

---

# Non-goals

Do not implement:

- E2EE/MLS;
- crypto device identities;
- Flutter chat UI;
- unread counts;
- read receipts;
- delivery receipts;
- editing/deleting messages;
- reactions;
- attachments;
- images/files;
- replies/threads;
- direct messages;
- chat notification projection;
- push notifications;
- meeting data duplication;
- moderation tools;
- search;
- production infrastructure.

---

# Acceptance criteria

07B2B is ready when:

- [ ] based on merged PR #26 `main`, not PR #28;
- [ ] exact prompt archived;
- [ ] repository docs explicitly defer E2EE;
- [ ] durable plain-text Project chat message table exists;
- [ ] no E2EE dependency/code is introduced;
- [ ] body is trimmed/non-empty/bounded;
- [ ] messages immutable;
- [ ] send RPC is expected-identity/current-entitlement-bound;
- [ ] send vs leave/remove race is deterministic;
- [ ] current accepted participant reads **all previous chat history**;
- [ ] former participant retains only messages visible through latest membership end;
- [ ] rejoin exposes accumulated gap history;
- [ ] creator always reads/sends;
- [ ] unrelated user has no access;
- [ ] stable keyset message pagination works;
- [ ] accessible chat-list summaries use only last visible message;
- [ ] inaccessible new messages do not alter former-member preview/activity;
- [ ] identifier-only outbox event contains no body;
- [ ] secure self-hosted-compatible Realtime path works;
- [ ] former members stop receiving new live events;
- [ ] durable PostgreSQL remains source of truth;
- [ ] Proposal and Tavolo covered;
- [ ] pgTAP + real local integration pass;
- [ ] generated types zero drift;
- [ ] existing Database/Mobile/Web/Site checks stay green;
- [ ] 07B2C handoff documented;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact table/RPC/helper names;
- exact page-size bounds;
- exact body limit if repository conventions strongly justify another value;
- exact lock implementation;
- Broadcast vs Postgres Changes after inspecting pinned self-hosted Supabase capability;
- exact identifier-only Realtime payload;
- exact chat-list query implementation/indexes.

Stop and report before:

- weakening access control to make Realtime easier;
- granting anonymous/public chat access;
- making former members receive new live events;
- reverting the full-history-on-join product rule;
- adding E2EE/crypto code;
- merging PR #28;
- implementing Flutter chat UI;
- adding broad message moderation/delete behavior;
- merging this PR.

---

# Deliverables

Produce:

1. exact archived 07B2B prompt;
2. chat-message schema;
3. full-history/current/former read helper;
4. current-entitlement send RPC;
5. keyset history RPC;
6. keyset accessible-chat-list RPC;
7. identifier-only message outbox event;
8. secure Realtime transport/signaling;
9. pgTAP structural/access/concurrency tests;
10. real local Proposal/Tavolo message integration;
11. real Realtime authorization integration;
12. generated types;
13. documentation/product-decision updates;
14. roadmap reconciliation;
15. explicit 07B2C handoff;
16. focused PR, preferably `codex/07b2b-project-chat-messages-realtime`;
17. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **PR #28 / E2EE deferral**
5. **Roadmap reconciliation**
6. **Message schema**
7. **Message immutability/body validation**
8. **Current-member full-history rule**
9. **Former-member history frontier**
10. **Rejoin history behavior**
11. **Creator behavior**
12. **Send RPC**
13. **Send/leave concurrency**
14. **History pagination**
15. **Accessible chat-list API**
16. **Last-visible preview/activity semantics**
17. **Realtime architecture**
18. **Realtime authorization**
19. **Self-hosted portability**
20. **Outbox event**
21. **RLS/grants/security**
22. **pgTAP tests**
23. **Real local message integration**
24. **Realtime integration**
25. **Proposal/Tavolo coverage**
26. **Generated types/drift**
27. **Existing regression validation**
28. **Documentation updates**
29. **07B2C handoff**
30. **Warnings/blockers**
31. **Commit/PR reference**

