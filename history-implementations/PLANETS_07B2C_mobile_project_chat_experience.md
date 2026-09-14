# PLANETS 07B2C — Mobile Project Chat Experience

**Roadmap area:** PLANETS 07 — Messages + Project Chat  
**Task type:** Flutter mobile client over merged 07B1/07B2B contracts  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged 07B2B base when this prompt was written:** `f044a59e3746530a02a754bfa95843ff28572738` (PR #29)

## Objective

Implement the first complete **mobile Project group-chat experience** over the merged server-authorized message domain.

Backend behavior is already canonical:

- one Project chat is created by the first accepted join request;
- Proposal and Tavolo share the same Project-level chat abstraction;
- creator can always read/send;
- current accepted participants can read the **full existing chat history**, including messages from before they joined;
- former participants retain history only through the end of their latest membership and cannot send;
- rejoin restores full accumulated history, including the gap;
- PostgreSQL is authoritative;
- Realtime provides private identifier-only hints;
- message bodies are server-readable plaintext protected by ordinary authenticated authorization/TLS;
- E2EE/MLS research remains deferred in unmerged PR #28 and is not part of this implementation.

07B2C should make this usable in Flutter without redesigning final PLANETS visual identity.

After this task, an authenticated user should be able to:

```text
Home
  → Messages
      → Chats
          → Project chat
              → read history
              → send if current
              → receive new-message updates
              → open group/project info
      → Requests
          → existing 07A participation-request experience
```

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_07B2C_mobile_project_chat_experience.md
```

---

# Current repository facts

Work from current merged `main`.

07B2B / PR #29 is merged at:

```text
f044a59e3746530a02a754bfa95843ff28572738
```

07B2B exposes the canonical public chat RPCs:

```text
list_own_project_group_chats(...)
list_own_project_chat_messages(...)
send_project_chat_message(...)
```

The chat list returns viewer-safe latest-visible message/activity context.

The message list is keyset-paginated newest-first.

Realtime uses private per-chat/per-profile Broadcast topics conceptually equivalent to:

```text
project-chat:<chatId>:profile:<profileId>
```

and payloads contain identifiers/timestamps only, not bodies.

07B1 also exposes:

```text
get_own_project_group_chat(...)
```

but 07B2C should prefer the richer 07B2B list/history contracts where applicable.

The existing mobile Messages feature currently owns:

```text
/messages
/messages/requests/:requestId
```

and is in the Home branch.

The persistent bottom navigation remains:

```text
Profile / Browse / Home
```

Do not add a fourth tab.

The current router already treats `/messages` as an auth/profile-protected Home-branch surface.

Participation already exposes a Flutter gateway for:

```text
get_project_participant_meeting_details
```

and existing routes for:

- Proposal/Tavolo detail;
- creator Participation/member management.

Reuse those.

---

# 1. Scope split

07B2C is the mobile functional chat experience.

It owns:

- chat models/parsing;
- Supabase chat gateway;
- chat-list controller;
- chat-detail/history controller;
- send flow;
- Realtime subscription/reconciliation;
- Messages-screen integration;
- chat screen;
- group/project info screen or sheet;
- Proposal/Tavolo navigation;
- creator Participation navigation;
- protected meeting details for currently entitled users;
- localization/accessibility;
- Flutter tests.

It does **not** own:

- backend schema changes unless a genuine blocker is discovered;
- unread counts;
- read receipts;
- delivery receipts;
- attachments;
- reactions;
- edit/delete;
- typing/presence;
- push notification projection;
- E2EE;
- final visual redesign.

---

# 2. Messages information architecture

Keep `Messages` as the existing authenticated Home-branch surface.

Do not mix Project chats and structured participation requests into one ambiguous chronological feed.

Use a simple functional split:

```text
Messages
  [ Chats ] [ Requests ]
```

A Material `TabBar`, segmented control, or similarly standard theme-driven control is acceptable.

Default to **Chats** once at least one accessible Project chat exists.

If there are no chats but request items exist, it is acceptable to default to Requests if that is cleaner and deterministic.

Do not add a new bottom-navigation destination.

## Chats tab

Shows items from:

```text
list_own_project_group_chats
```

sorted exactly by backend `activity_at`.

Each card/list tile should show at minimum:

- Project/Tavolo title;
- Project-kind context where useful;
- last visible message preview if one exists;
- sender display name where useful;
- activity time;
- role/read-only indication when viewer is a former member.

Do not fabricate unread state.

## Requests tab

Preserve the existing 07A request inbox behavior and pagination.

Do not regress Accept/Reject/Withdraw or notification routing.

---

# 3. Stable chat route

Add:

```text
/messages/chats/:chatId
```

to the existing Home branch.

Provide a route helper equivalent to:

```dart
projectChatRoute(chatId)
```

Update `isMessagesPath(...)` so auth/profile return destinations continue to work.

The route must:

- require authentication;
- require complete profile through existing router behavior;
- survive OTP/profile completion return flow;
- be safe on account switching.

No project ID needs to be encoded in the route; resolve it from canonical chat data.

---

# 4. Domain models

Add strict models for:

## Chat summary

Equivalent concepts:

```text
chatId
projectId
projectKind
projectTitle
viewerRole
hasCurrentEntitlement
hasHistoryEntitlement
activatedAt

lastVisibleMessageId?
lastVisibleMessageBody?
lastVisibleMessageAt?
lastVisibleSenderProfileId?
lastVisibleSenderDisplayName?

activityAt
```

## Chat message

Equivalent concepts:

```text
messageId
chatId
senderProfileId
senderDisplayName
body
createdAt
```

## Cursor

Chat-list cursor:

```text
activityAt + chatId
```

Message-history cursor:

```text
createdAt + messageId
```

Strictly parse required fields.

Nullable last-message fields must remain internally consistent.

Do not silently accept malformed backend payloads.

---

# 5. Chat gateway

Create a dedicated mobile Project-chat Supabase boundary.

Prefer a separate feature boundary such as:

```text
features/project_chat/
```

rather than bloating the 07A structured-request gateway.

The gateway should own only:

```text
listOwnProjectChats
listOwnProjectChatMessages
sendProjectChatMessage
subscribeToProjectChatSignals
```

Exact class/file naming is Codex-owned.

Do not direct-read `project_chat_messages`.

Use the public RPCs.

Realtime is only a signal channel.

---

# 6. Chat-list controller

Implement identity-bound Riverpod state following the established Messages/Notifications patterns.

Required behavior:

- initial load;
- pull-to-refresh;
- keyset load-more;
- dedupe by `chatId`;
- deterministic backend order;
- safe empty/loading/error states;
- identity revision protection;
- account switch clears immediately;
- late responses from old identity discarded.

The controller should not maintain unread counts.

## Reconciliation

When a visible chat receives a new-message signal while the user is on the Messages screen, refresh/reconcile the chat list so:

- preview updates;
- activity order updates.

Do not reorder based solely on the Realtime payload.

Canonical list RPC remains authoritative.

A lightweight throttled refresh is acceptable if several signals arrive close together.

---

# 7. Chat-detail/history controller

The backend returns newest-first pages.

The UI should present conversation order naturally:

```text
oldest
  ↓
newest
```

For the first backend page:

1. load newest N messages;
2. reverse/transform for visual ascending display.

For older pages:

- fetch using the oldest loaded backend cursor;
- prepend older messages;
- preserve scroll position where practical.

Maintain:

```text
hasMoreOlder
isLoadingOlder
isSending
```

Dedupe by `messageId`.

Do not use OFFSET or client-side guessed pagination.

---

# 8. Initial scroll behavior

When opening a chat:

- load the newest page;
- render with newest message at the bottom;
- scroll to bottom after initial successful layout.

When loading older history at the top:

- do not jump the user back to bottom;
- preserve viewport position as reasonably possible.

Do not implement complex reverse-list tricks if they make pagination brittle.

Use the simplest stable Flutter approach supported by tests.

---

# 9. Send behavior

Composer is available only when:

```text
hasCurrentEntitlement == true
```

Creator is current-entitled by backend definition.

Input rules should mirror backend:

- trim;
- no blank/whitespace-only submission;
- max 4,000 characters;
- plain text;
- multiline allowed.

## Submission

Prefer a conservative canonical flow:

```text
user taps send
→ disable duplicate submit briefly
→ call send RPC
→ insert/reconcile returned canonical message by ID
→ clear composer on success
→ Realtime duplicate hint later is harmless
```

Do not require an optimistic temporary fake-message ID unless it clearly improves the current implementation.

On failure:

- keep the typed text;
- show safe localized error;
- allow retry.

Do not display raw backend diagnostics.

---

# 10. Realtime subscription

Inspect the currently pinned `supabase_flutter` API and implement the private Broadcast subscription compatible with the backend.

Topic must exactly match the backend convention for:

```text
chatId
current profile ID
```

Requirements:

- private/authenticated channel;
- subscribe only while current entitlement exists;
- listen only for the Project chat new-message event;
- payload is treated as a hint;
- on valid hint, reconcile/fetch durable state;
- dedupe by canonical message ID;
- clean unsubscribe on screen/controller disposal;
- clean unsubscribe on identity change;
- clean unsubscribe if entitlement refresh changes to former-member/read-only state;
- reconnect should reload canonical history.

Do not trust payload body because there is no body in the Broadcast payload.

---

# 11. Realtime race/reconnect behavior

Handle these cases:

## Own send

The send RPC returns the canonical row and also causes a Realtime hint.

Result:

```text
one message in UI
```

not duplicates.

## Signal before list refresh

If a signal arrives while a history load is in progress:

- do not corrupt pagination;
- schedule/reconcile safely.

## Missed signal/offline

On reconnect/resume/explicit refresh:

- history RPC catches up.

## Leave/remove elsewhere

A user's entitlement may change on another device.

If Realtime channel errors/authorization changes or a canonical refresh reveals former-member status:

- stop composer;
- stop live subscription;
- retain authorized historical messages;
- render read-only state.

No tight polling is needed.

---

# 12. Chat screen UI

Functional MVP screen:

```text
AppBar:
  Project title
  info action

Body:
  older-history loader
  message bubbles/list
  safe loading/error states

Bottom:
  composer if current
  read-only former-member notice if not current
```

## Message grouping

Differentiate:

```text
my message
other participant message
```

using theme-driven alignment/surface treatment.

Show sender display name for other people's messages.

Do not invent final brand colors.

## Timestamps

Use concise localized time/date.

Avoid repeating a full timestamp on every line if standard grouping can keep the UI readable.

Functional clarity matters more than polish.

## Accessibility

Message semantics should expose:

- sender;
- message text;
- time.

Composer/send button must have accessible labels.

Do not rely only on color/alignment to identify read-only state.

---

# 13. Former-member read-only state

Former participant:

- can open chat;
- can read only backend-authorized retained history;
- has no composer;
- has no Realtime live subscription;
- sees a clear localized notice equivalent to:

```text
You are no longer participating in this project. This chat is read-only.
```

Do not show inaccessible-new-message placeholders such as:

```text
3 newer messages hidden
```

That would leak activity.

Chat-list preview/order already prevents that leak.

---

# 14. Newly accepted/current participant history

This is an explicit product acceptance case.

Scenario:

```text
M1
M2
M3
--- B joins ---
M4
```

When B opens the chat, B sees:

```text
M1
M2
M3
M4
```

No “you joined here” cutoff.

Do not client-filter history by membership timestamp.

The server already implements the approved rule.

---

# 15. Rejoin behavior

If a former participant rejoins:

- next canonical chat-list/history refresh returns current entitlement;
- composer becomes available;
- full accumulated history becomes visible;
- subscribe to Realtime again.

Do not create a new chat route/thread.

Same canonical `chatId`.

---

# 16. Group info / project context

Add a simple group-info destination from the chat AppBar.

This can be:

- a dedicated `/messages/chats/:chatId/info` route; or
- a full-screen/modal sheet if it integrates better.

Prefer a route if it improves testability/deep-navigation consistency.

Show safe context:

- Project/Tavolo title;
- kind;
- viewer role/status;
- button to open Project/Tavolo detail.

Do not duplicate project content into chat state beyond the canonical chat-summary fields.

---

# 17. Participation access from group info

For creator:

show an action equivalent to:

```text
Manage participation
```

using the existing:

```text
ParticipationRoutes.participants(projectKind, projectId)
```

Do not rebuild member-management UI inside chat.

For ordinary participants/former participants, do not expose creator-only Participation management.

This placement is functional; Plan 12 may redesign it later.

---

# 18. Protected meeting details from chat/group info

Reuse the existing Participation gateway:

```text
getParticipantMeetingDetails(
  expectedProfileId,
  projectId
)
```

Do not duplicate meeting data into chat.

## Current entitled users

Creator/current participant may load/display available exact meeting information according to the existing backend authorization.

Prefer lazy load from group info rather than automatically loading exact meeting details just because the chat opens.

Display:

- exact meeting text;
- location representation only through existing safe UI conventions.

Do not log it.

## Former participant

Do not call/show protected current meeting details merely because they have historical chat access.

No fallback to cached meeting details from old state.

Identity/entitlement changes should clear private meeting details.

---

# 19. Project navigation

Use:

```text
ParticipationRoutes.detail(projectKind, projectId)
```

for the Project/Tavolo action.

Do not reproduce Proposal/Tavolo route logic in chat feature.

---

# 20. Messages Chats + Requests implementation

Do not discard 07A state.

The Messages screen should coordinate two independent controller families:

```text
Project chats
Structured requests
```

Each keeps independent:

- pagination;
- error state;
- refresh state.

A failure in Chats must not make Requests unusable and vice versa.

If using tabs, load each lazily or in parallel according to simplest stable implementation.

Pull-to-refresh should refresh the visible tab.

A top-level refresh of both is acceptable if not wasteful.

---

# 21. Empty states

Chats:

```text
No project chats yet
Chats appear after a join request is accepted.
```

Copy can be localized/adjusted.

Requests:

preserve existing empty state semantics.

If both are empty, the two-tab structure may remain; no special combined empty design is required.

---

# 22. Error handling

Map backend/network/format failures into existing safe mobile failure patterns.

Do not expose:

- PostgreSQL messages;
- Supabase internals;
- stack traces;
- topic strings;
- Auth IDs.

For recoverable Realtime failure:

- keep durable loaded messages;
- show subtle connection/retry state if useful;
- allow manual refresh;
- do not make the screen unusable.

---

# 23. Account switching

This is security-critical.

On profile identity change:

- clear chat-list state;
- clear chat-detail state;
- clear composer text belonging to the old identity where practical;
- unsubscribe Realtime;
- clear protected meeting details;
- reject late RPC responses;
- rebuild through the existing router identity reset.

No user A chat content may flash for user B.

Add explicit tests.

---

# 24. Lifecycle integration

When existing participation actions succeed in this device:

## Accept request as creator

The first acceptance may create the chat.

Refresh/invalidate:

- Project chat list;
- Messages Chats tab.

## Leave project

Refresh/invalidate:

- chat summaries;
- current open chat entitlement if applicable.

## Remove member

Creator's own entitlement stays current.

The removed user's other device will reconcile independently.

## Rejoin acceptance

Refresh/invalidate same canonical chat.

Prefer narrow Riverpod invalidation/hooks rather than tight presentation-feature coupling.

---

# 25. Notifications

Do not implement chat notification projection in 07B2C.

Existing notification categories already include future chat space, but `project.chat_message_sent` is intentionally not projected yet.

Do not create fake in-app notifications client-side.

A later focused notification follow-up may consume the outbox event.

---

# 26. No unread badge

Do not infer unread state from:

- latest timestamp;
- screen open time;
- local memory.

There is no canonical read model yet.

Therefore:

- no unread dot;
- no unread count;
- no bold “unread” styling.

A later backend read-marker plan can add it properly.

---

# 27. No message mutation

Do not add:

- long-press edit;
- delete;
- copy-to-moderation;
- reactions;
- reply;
- attachment picker.

Copy-to-clipboard may be omitted unless repository conventions already make it trivial; it is not required.

---

# 28. Localization

Add all user-facing strings to the existing localization system.

At minimum cover:

- Chats;
- Requests;
- Project chat;
- no chats;
- load older;
- send;
- message placeholder;
- read-only former-member notice;
- connection/retry safe copy;
- group info;
- open project;
- manage participation;
- meeting details;
- generic send/load failures.

No hard-coded English in production widgets.

---

# 29. Flutter architecture

Prefer a dedicated feature:

```text
apps/mobile/lib/features/project_chat/
  domain/
  data/
  application/
  presentation/
```

while integrating entry points into existing `messages/`.

Suggested ownership:

```text
project_chat/domain
  models/cursors

project_chat/data
  RPC + Realtime gateway

project_chat/application
  chat list controller
  chat detail controller

project_chat/presentation
  chat screen
  group info screen
  routes/helpers
```

Do not move 07A structured-request code unnecessarily.

---

# 30. Chat-list tests

Add domain/controller/widget tests covering:

- signed-out/protected route behavior through router tests;
- initial list load;
- newest activity order from backend;
- preview rendering;
- no-message chat;
- creator/current/former role presentation;
- former read-only indicator;
- keyset load more;
- dedupe;
- safe failure;
- refresh;
- account switch;
- late response rejection;
- no unread UI.

---

# 31. Chat-detail tests

Cover:

## History

- newest backend page renders oldest→newest;
- load older prepends;
- same-timestamp messages stable;
- no duplicates.

## Current participant

- composer visible;
- can send;
- returned canonical message appears once;
- typed text clears only on success;
- send failure retains text.

## Full prior history

- current member renders pre-join messages returned by server.

## Former participant

- composer absent;
- read-only notice;
- authorized history remains;
- no Realtime subscription.

## Rejoin/current transition

- composer/subscription restored after canonical state refresh.

## Creator

- send/group-info/Participation action available.

---

# 32. Realtime tests

Use fakes for controller/widget edge cases but also preserve a narrow integration test where practical.

At minimum test controller behavior:

- signal triggers canonical reconciliation;
- own-send + signal dedupes;
- duplicate signals harmless;
- signal during load does not corrupt pagination;
- dispose unsubscribes;
- account switch unsubscribes;
- current→former unsubscribes;
- reconnect triggers durable catch-up.

If clean local mobile integration against Realtime is already supported by repository infrastructure, add a focused one.

Do not make Flutter tests depend on internet/external Supabase.

---

# 33. Group-info tests

Cover:

- Project/Tavolo title/kind;
- open Project/Tavolo route;
- creator sees Manage participation;
- non-creator does not;
- current entitled user can request meeting details;
- former does not request/show meeting details;
- identity change clears private meeting state;
- meeting backend failure is safe and does not break chat history.

---

# 34. Router tests

Add:

```text
/messages/chats/:chatId
```

and optional info route.

Verify:

- signed out → OTP auth with exact return destination;
- incomplete profile → profile setup preserving return;
- ready profile opens route;
- identity swap reconstructs protected branch;
- existing request/notification routes unchanged.

---

# 35. Native QA status

As previously decided, comprehensive native QA is deferred to Plan 12.

Therefore:

- automated Flutter/widget/controller tests are required;
- Android build/analyze/tests required;
- iOS compile where current CI supports it;
- do not block this implementation solely on manual-device QA;
- do not claim native QA passed.

Document a concise manual checklist for Plan 12.

---

# 36. Documentation and roadmap

Update:

- `apps/mobile/lib/features/messages/README.md`;
- new Project-chat feature README if useful;
- navigation docs;
- roadmap.

Mark:

```text
07B2B — Implemented
PR #29
merge commit f044a59e3746530a02a754bfa95843ff28572738
```

Keep E2EE research:

```text
PR #28 — unmerged/deferred optional research
```

While this PR is open:

```text
07B2C — In progress
```

After eventual merge it may be marked Implemented, but do not mark 07 parent fully complete unless all explicitly tracked 07 scope is actually satisfied.

Keep:

```text
06C2B — Not started / external provider context required
04C — Not started
05C — Not started
```

---

# 37. Validation

Run repository-standard validation.

At minimum:

- Dart format;
- localization generation/check;
- Flutter analyze;
- all existing Flutter tests;
- new chat tests;
- Android debug build if standard/available;
- Web regressions;
- SITE regressions;
- Database/generated-type checks should remain green;
- `git diff --check`.

No external provider credentials required.

---

# Non-goals

Do not implement:

- E2EE/MLS;
- unread/read markers;
- push/chat notification projection;
- attachments;
- media;
- reactions;
- replies;
- editing/deleting;
- direct messaging;
- typing indicators;
- presence;
- calls;
- voice messages;
- final visual identity;
- Plan 09 moderation;
- 04C Resources;
- 05C contribution verification;
- 06C2B Firebase provider work.

---

# Acceptance criteria

07B2C is ready when:

- [ ] based on merged PR #29 main;
- [ ] exact prompt archived;
- [ ] `/messages/chats/:chatId` exists and is protected;
- [ ] Messages provides clear Chats/Requests access;
- [ ] existing 07A Requests behavior remains intact;
- [ ] chat summaries paginate correctly;
- [ ] last-visible previews render safely;
- [ ] newest history opens at bottom in natural order;
- [ ] older-history keyset pagination works;
- [ ] current participant sees full pre-join history returned by backend;
- [ ] current participant can send;
- [ ] own send + Realtime hint produces one visible message;
- [ ] durable reconciliation handles missed/duplicate signals;
- [ ] former participant is read-only;
- [ ] former participant has no live subscription;
- [ ] rejoin restores composer/live subscription after refresh;
- [ ] creator retains send access;
- [ ] group info links to Project/Tavolo;
- [ ] creator group info links to Participation;
- [ ] current entitled user may load protected meeting details;
- [ ] former user cannot load protected meeting details;
- [ ] account switching clears all private chat/meeting state and subscriptions;
- [ ] no unread state is fabricated;
- [ ] no E2EE code/dependency is introduced;
- [ ] localization/accessibility coverage added;
- [ ] automated Flutter tests pass;
- [ ] repository regression CI stays green;
- [ ] no native QA pass falsely claimed;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact feature file names;
- TabBar vs segmented control;
- exact functional message-bubble styling;
- exact scroll implementation;
- exact controller state shapes;
- whether group info is a route or full-screen sheet;
- exact Realtime reconnection/throttle mechanics compatible with current `supabase_flutter`.

Stop and report before:

- changing backend history semantics;
- adding unread/read receipts;
- adding E2EE;
- granting former users meeting details;
- relying on Realtime as message persistence;
- exposing raw backend errors;
- redesigning bottom navigation;
- implementing a final visual design system;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 07B2C prompt;
2. Project-chat mobile domain models;
3. Supabase RPC/Realtime gateway;
4. identity-safe chat-list controller;
5. identity-safe chat-detail/history/send controller;
6. Chats/Requests Messages integration;
7. `/messages/chats/:chatId` route;
8. functional chat screen;
9. older-history pagination;
10. current-member composer/send flow;
11. former-member read-only state;
12. private Realtime reconciliation;
13. group info;
14. Project/Tavolo navigation;
15. creator Participation action;
16. protected meeting-detail integration;
17. localization/accessibility;
18. Flutter/router/controller/widget tests;
19. documentation/roadmap reconciliation;
20. Plan-12 manual QA checklist;
21. focused PR, preferably `codex/07b2c-mobile-project-chat`;
22. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **07B2B roadmap reconciliation**
5. **Feature architecture**
6. **Chat models/parsing**
7. **Gateway/RPC contracts**
8. **Messages Chats/Requests IA**
9. **Chat-list controller**
10. **Chat-list pagination**
11. **Chat route**
12. **History controller**
13. **History ordering/pagination**
14. **Full pre-join history UX**
15. **Send flow**
16. **Realtime subscription**
17. **Realtime reconciliation/deduplication**
18. **Reconnect behavior**
19. **Former-member read-only behavior**
20. **Rejoin behavior**
21. **Creator behavior**
22. **Group info**
23. **Project/Tavolo navigation**
24. **Participation navigation**
25. **Protected meeting details**
26. **Account-switch/race safety**
27. **Localization/accessibility**
28. **Flutter/router/widget tests**
29. **Regression validation**
30. **Deferred native QA**
31. **Remaining chat non-goals**
32. **Warnings/blockers**
33. **Commit/PR reference**

