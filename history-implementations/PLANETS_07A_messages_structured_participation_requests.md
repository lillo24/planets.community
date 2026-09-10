# PLANETS 07A — Messages Surface and Structured Participation Requests

**Roadmap area:** PLANETS 07 — Messages + Project Chat  
**Task type:** Flutter Messages surface plus narrow canonical request-message read APIs  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged 06A base:** `6c3168b17845b2b2567ef42864c3e0f73eb6db97`

## Objective

Implement the first real **Messages** experience in PLANETS.

07A owns **structured participation-request items only**.

A join request should have a persistent user-facing home in Messages, analogous to an actionable templated request item:

```text
Messages
└── Mario wants to join “Community Garden”
    “Ciao, posso aiutare sabato…”
    [Accept] [Reject]
```

The item is **not a copied/free-form chat message**. Its canonical state remains `project_join_requests`, and all actions continue to call the existing 05A participation transitions.

After 07A:

- authenticated users have `/messages`;
- sent and received join requests appear as structured Messages items;
- `/messages/requests/:requestId` opens an exact request item;
- the private requester message is visible only to requester and project creator;
- creator pending items expose Accept / Reject;
- requester pending items expose Withdraw;
- resolved requests remain visible with canonical state;
- Project/Tavolo context and safe counterpart identity are shown;
- 06A target `participation_request + request_id` has its final mobile destination for later 06B;
- the existing Participation screen remains the secondary organizer overview/history surface;
- no group chat, free-form DM, notification UI, push delivery, resources, or final navigation redesign is introduced.

This is **07A only**. **07B — Project Group Chat** remains later.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_07A_messages_structured_participation_requests.md
```

---

## Why 07A comes before 06B

06A stores request-related notification targets as:

```text
destination_kind = participation_request
request_id = <canonical request UUID>
```

Notifications are alerts only.

Implementing 06B first would force a temporary fallback destination. Building 07A first lets 06B map that target directly to:

```text
/messages/requests/:requestId
```

from day one.

---

# Inspect before changing anything

Work from latest merged `main`.

Inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/development/database.md`;
5. `docs/implementation/roadmap.md`;
6. merged 05A participation migration/tests/integration;
7. merged 05B Flutter participation feature;
8. merged 06A notification migration/tests/integration;
9. generated database types;
10. mobile router/navigation shell/Home;
11. Auth/profile-readiness/returnTo behavior;
12. Proposal/Tavolo detail and Participation routes;
13. Flutter localization/test conventions;
14. CI workflow.

Current facts:

- 05B merged at `09d62276faec4c50ab5d45cd3930975c5a49a6b7`;
- 06A merged at `6c3168b17845b2b2567ef42864c3e0f73eb6db97`;
- 06A final CI is green;
- request notifications retain canonical `request_id`;
- 05A owns request/withdraw/accept/reject/member state;
- 05B owns current participation UI;
- bottom nav remains Profile / Browse / Home;
- no group-chat schema exists;
- no general Messages table exists;
- final app information architecture is still deferred.

---

# Product boundary

## Messages is the primary request-arrival surface

A new join request should conceptually **arrive in Messages**.

The creator should not have to discover it only through:

```text
Project -> Manage participation -> Requests
```

The existing Participation screen remains for:

- full request history;
- participants;
- leave/remove history;
- organizer management.

## Structured item, not chat

Do not copy the request into a generic text-message row.

Do not parse text to infer participation.

Do not create a pre-acceptance conversation.

The structured item is a presentation of canonical `project_join_requests`.

## Group chat is separate

07A does not implement:

- project conversations;
- group-chat membership;
- persisted chat messages;
- Realtime;
- meeting links;
- group info.

Those belong to 07B.

---

# 1. Backend Messages read APIs

05A has project-specific owner reads and requester-own reads, but no efficient cross-project Messages inbox.

Add a focused forward migration with **read APIs only** where possible.

Do not redesign participation tables.

## No duplicate message table

Do not create a durable request-copy table.

Prefer computed/narrow RPCs over a second synchronized representation.

## Inbox API

Add an authenticated operation equivalent to:

```text
list_own_participation_request_message_items(
  p_expected_profile_id,
  p_limit,
  p_cursor_activity_at?,
  p_cursor_request_id?
)
```

Return requests where the current profile is either:

```text
requester
OR
creator of the target project
```

Return at least:

```text
request_id
project_id
project_kind
project_title

viewer_role          -- requester | creator

requester_profile_id
requester_display_name
creator_profile_id
creator_display_name

request_message
status
created_at
resolved_at
activity_at
```

A reasonable `activity_at` is:

```text
coalesce(resolved_at, created_at)
```

Do not return email, exact meeting data, bio, skills, notification payload, audit metadata, or resources.

## Exact item API

Add an operation equivalent to:

```text
get_own_participation_request_message_item(
  p_expected_profile_id,
  p_request_id
)
```

Authorized only for:

- requester;
- project creator.

Unrelated users must fail closed without useful private existence leakage.

---

# 2. Pagination

Use keyset ordering:

```text
activity_at DESC, request_id DESC
```

Requirements:

- bounded page size;
- both cursor fields required together;
- stable deterministic ordering;
- no offset pagination;
- no N project-specific requests from the Flutter inbox.

Do not add Messages unread state in 07A.

Notification unread state is not a substitute for Messages read state.

---

# 3. Private request-message visibility

`request_message` may be returned only to:

- requester;
- project creator.

It must never appear in:

- public Project/Tavolo data;
- notifications;
- unrelated users;
- logs/monitoring;
- future group-chat state.

Do not weaken `get_public_profile`.

---

# 4. Identity and security

Every Messages RPC binds:

```text
p_expected_profile_id == auth.uid()
```

Do not trust client-supplied viewer role, creator, requester, or project kind.

All security-definer functions:

- fixed/empty `search_path`;
- fully-qualified objects;
- explicit grants;
- authenticated-only client access.

No direct table grants are needed.

---

# 5. Flutter feature

Add:

```text
apps/mobile/lib/features/messages/
```

using the existing feature-first structure.

Suggested domain concepts:

```text
ParticipationRequestMessageItem
MessageViewerRole
ParticipationRequestStatus
MessagesPage
```

A narrow sealed `MessagesInboxItem` with only a `participationRequest` case is acceptable if it clearly prepares for 07B without fake fields.

Gateway owns:

- Messages inbox read;
- exact request-item read;
- existing 05A withdraw / accept / reject RPCs.

Reuse existing participation mutation mapping where sensible; do not create duplicate business logic.

---

# 6. Routing and navigation

Keep bottom navigation exactly:

```text
Profile / Browse / Home
```

Do **not** add a fourth Messages tab.

Put Messages in the existing **Home branch**:

```text
/messages
/messages/requests/:requestId
```

Future-compatible reserved shape:

```text
/messages/projects/:projectId   -- 07B only; do not implement now
```

## Auth

Messages routes require authentication.

Signed out → OTP Auth with exact safe `returnTo`.

After Auth/profile readiness, return to requested Messages route.

## Home entry

Expose Messages clearly from Home via at least one obvious action:

- Home app-bar Messages icon; or
- clear Messages button/card.

Do not add it to every screen.

No unread badge is needed in 07A.

---

# 7. Messages inbox UI

Implement `/messages`.

Current item type is only structured participation requests.

Each card should show:

- project title;
- Project/Tavolo distinction where useful;
- viewer-appropriate counterpart/context;
- request status;
- request-message preview when present;
- activity/submission time.

Creator example:

```text
Mario wants to join “Community Garden”
```

Requester example:

```text
Your request to join “Community Garden”
```

Support loading, empty, safe error/retry, pull-to-refresh, and load-more.

Do not use Realtime yet.

---

# 8. Exact request item UI

Implement:

```text
/messages/requests/:requestId
```

Show:

- project title/kind;
- requester name;
- creator name where useful;
- full private requester message;
- submitted time;
- current status;
- resolved time if present;
- context-specific actions;
- View project.

Map View project by project kind to:

```text
/proposals/:id
/tavoli/:id
```

Do not expose protected meeting details here.

---

# 9. Creator actions

If:

```text
viewer_role = creator
status = pending
```

show:

```text
Accept
Reject
```

Call only:

```text
accept_project_join_request
reject_project_join_request
```

After success:

- refresh exact item;
- refresh inbox;
- invalidate/refresh relevant 05B participation state;
- do not create group chat.

Prevent duplicate taps.

If another device already resolved the request, reload and show canonical state.

---

# 10. Requester action

If:

```text
viewer_role = requester
status = pending
```

show:

```text
Withdraw request
```

Call only:

```text
withdraw_project_join_request
```

After success:

- show Withdrawn;
- keep item in Messages history;
- refresh relevant 05B participation state.

Requester must not see Accept/Reject.

---

# 11. Resolved request history

Accepted/rejected/withdrawn items remain in Messages.

Do not delete or convert them into chat.

Accepted:

- show Accepted;
- View project;
- no Chat button until 07B.

Rejected/withdrawn:

- read-only historical state;
- re-request remains available later from project detail if eligible.

---

# 12. Participation screen relationship

Do not remove the existing Participation screen.

It remains the secondary organizer overview for:

- all requests;
- participants;
- removed/left history;
- member removal.

Messages is now the primary persistent arrival/action surface for a new request.

Optional: creator request item may include:

```text
Open participation overview
```

Do not move Participation under group info yet; record that for 07B.

---

# 13. 06A notification handoff

Expose one narrow route helper equivalent to:

```text
participationRequestMessageRoute(requestId)
```

returning:

```text
/messages/requests/:requestId
```

06B will later map:

```text
destination_kind = participation_request
request_id != null
```

to this route.

07A must **not** read notifications.

Messages must work even if:

- in-app notifications are disabled;
- no notification row exists;
- the request predates 06A.

---

# 14. State synchronization with 05B

07A and 05B display the same canonical participation state.

After Accept/Reject/Withdraw:

- refresh Messages item/inbox;
- invalidate/refresh own participation state where relevant;
- invalidate/refresh creator Participation state where relevant.

Do not create a second durable local participation cache.

---

# 15. Account-switch and race safety

Messages state is private and identity-bound.

Clear on sign-out/account switch.

After async operations validate:

- controller revision;
- current identity;
- request target.

Cover:

- old inbox page finishing under another account;
- old request detail after account switch;
- Accept/Reject/Withdraw resolving after identity change.

No private data from account A may render under B.

---

# 16. Error handling

Expected conflicts should reload canonical state.

Use safe errors for:

- already-resolved request;
- no longer authorized;
- stale identity;
- temporary failure.

Never render raw SQL/PostgREST messages, email, Auth state, private JSON, or exact meeting data.

---

# 17. Localization/accessibility

Localize at least:

- Messages;
- no requests yet;
- incoming/outgoing request titles;
- Pending / Accepted / Rejected / Withdrawn;
- Accept / Reject / Withdraw;
- View project;
- submitted/resolved labels;
- safe errors.

Long names/titles/messages must wrap safely.

---

# 18. Database tests

Add focused pgTAP coverage.

Test:

- requester sees own item;
- creator sees incoming item;
- unrelated/anon cannot;
- cross-account expected identity fails;
- private request message visible to requester+creator only;
- no email/exact meeting/audit/outbox payload;
- one-time and Tavolo project context;
- pending/accepted/rejected/withdrawn;
- correct viewer role;
- stable `activity_at, request_id` keyset pagination;
- cursor validation;
- authenticated-only execute grants;
- fixed search paths;
- no new public request directory.

Do not duplicate the full 05A mutation state-machine tests.

---

# 19. Flutter tests

Cover:

## Routing

- `/messages` → Home branch;
- `/messages/requests/:id` → Home branch;
- bottom nav still Profile/Browse/Home;
- signed-out → Auth with returnTo;
- post-auth/profile readiness returns correctly;
- account switch clears private Messages state.

## Inbox

- creator incoming copy;
- requester outgoing copy;
- message preview;
- Project/Tavolo context;
- pending/resolved statuses;
- empty/loading/error/retry;
- pagination and refresh.

## Detail/actions

- full private request message;
- creator pending → Accept/Reject only;
- requester pending → Withdraw only;
- accepted/rejected/withdrawn are historical;
- View project mapping;
- duplicate taps blocked;
- conflicts reload canonical state;
- stale post-await result discarded.

## Notification handoff helper

```text
request_id -> /messages/requests/:requestId
```

---

# 20. Real local integration

Add or extend a focused local script, preferably:

```text
scripts/verify-local-messages.mjs
```

Use creator A, requester B, unrelated C.

Prove:

1. B requests one-time Project with private message;
2. A and B both see the structured item;
3. C cannot;
4. A/B see private message;
5. A accepts;
6. both see Accepted;
7. membership exists through existing 05A behavior;
8. Tavolo request has correct context;
9. requester withdraws;
10. both see Withdrawn;
11. public/unrelated boundaries never expose request message.

Do not print OTPs, tokens, private request text, or protected meeting data.

---

# 21. No duplicate Messages schema

A forward migration for read RPCs is expected.

Do not create:

```text
messages
message_threads
request_message_copies
```

for 07A.

If a durable index/table is genuinely required for correctness, stop and explain why canonical request queries cannot serve this scope.

---

# 22. Validation

Keep green:

- migration replay;
- DB lint;
- all pgTAP;
- Auth/profile/Proposal/Tavolo integrations;
- participation integration;
- notification integration;
- new Messages integration;
- generated type drift;
- Flutter localization/format/analyze/tests;
- Web tests/lint/typecheck/build;
- `git diff --check`.

---

# 23. Documentation / roadmap

Update:

- mobile README/navigation docs;
- new Messages feature README;
- product decisions;
- system design;
- database docs;
- roadmap.

Correct 06A to:

```text
Implemented — PR #17
6c3168b17845b2b2567ef42864c3e0f73eb6db97
```

Keep:

```text
06 parent — In progress
06B — Not started
06C — Not started
```

While this PR is open:

```text
07 parent — In progress
07A — In progress
07B — Not started
```

Document that 07A is intentionally sequenced before 06B so notification request targets have their real destination.

Docs must say:

- Messages = primary persistent request arrival/action surface;
- Participation = secondary organizer overview/history;
- group chat = later accepted-participant conversation.

Do not claim Participation has moved under group info yet.

---

# 24. Manual native QA gate

Leave PR unmerged.

Android minimum; iOS where available.

Check:

1. signed-out Home → Messages → OTP → returns to Messages;
2. Messages shortcut is obvious;
3. bottom nav unchanged;
4. requester sends Project request with message;
5. creator sees incoming item;
6. creator sees full private message;
7. requester sees outgoing item;
8. creator Accept;
9. both show Accepted;
10. existing Project detail shows participation correctly;
11. second request → Reject;
12. both show Rejected;
13. Tavolo context works;
14. requester Withdraw from Messages;
15. both show Withdrawn;
16. Participation overview still works;
17. View project works for Proposal and Tavolo;
18. back navigation;
19. pull-to-refresh;
20. account switch while inbox/detail/action open;
21. unrelated account cannot open copied request URL;
22. no notification UI;
23. no free-form pre-acceptance chat;
24. no group chat;
25. private request text never appears in public project UI.

---

# Non-goals

Do not implement:

- 06B notification UI;
- 06C FCM/device delivery;
- project group chat;
- free-form DMs;
- pre-acceptance replies;
- Messages unread receipts;
- group info;
- moving Participation under group info;
- resources;
- capacity/fullness;
- verified contribution;
- final bottom-nav/Progetti redesign;
- web Messages;
- media/maps/payments/moderation.

---

# Acceptance criteria

07A is ready when:

- [ ] based on merged 06A;
- [ ] prompt archived;
- [ ] `/messages` and `/messages/requests/:id` exist;
- [ ] Messages stays in Home branch;
- [ ] no fourth bottom tab;
- [ ] Home clearly exposes Messages;
- [ ] requester and creator both see canonical request item;
- [ ] unrelated users cannot;
- [ ] private message visible only to requester/creator;
- [ ] Proposal and Tavolo both work;
- [ ] keyset inbox pagination is stable;
- [ ] creator pending item supports Accept/Reject;
- [ ] requester pending item supports Withdraw;
- [ ] resolved items remain historical;
- [ ] actions use existing 05A RPCs;
- [ ] no duplicated message/request table;
- [ ] 05B participation state stays synchronized;
- [ ] `participation_request + request_id` has exact Messages route;
- [ ] Messages does not depend on notification existence/preferences;
- [ ] Participation remains secondary overview;
- [ ] no group chat;
- [ ] account-switch/race safety covered;
- [ ] Mobile/Web/Database CI green;
- [ ] native QA remains pre-merge;
- [ ] PR remains unmerged.

---

# Deliverables

Produce:

1. exact archived prompt;
2. cross-project request-message inbox RPC;
3. exact request-message detail RPC;
4. pgTAP authorization/privacy/pagination tests;
5. generated DB types;
6. Flutter Messages feature;
7. `/messages` inbox;
8. `/messages/requests/:id` detail;
9. Home Messages entry;
10. creator Accept/Reject;
11. requester Withdraw;
12. Project/Tavolo navigation;
13. reusable request-route helper for 06B;
14. identity/race-safe controllers;
15. Flutter/router/widget tests;
16. real local Messages integration;
17. docs/roadmap reconciliation;
18. focused PR, preferably `codex/07a-messages-structured-participation-requests`;
19. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Messages backend read model**
5. **Authorization/privacy**
6. **Inbox pagination**
7. **Flutter Messages architecture**
8. **Routes/Home integration**
9. **Creator incoming-request UX**
10. **Requester outgoing-request UX**
11. **Accept/Reject**
12. **Withdraw**
13. **Resolved history**
14. **Proposal/Tavolo context/navigation**
15. **05B synchronization**
16. **06A notification-target handoff**
17. **Account-switch/race safety**
18. **Localization/accessibility**
19. **pgTAP tests**
20. **Flutter tests**
21. **Real local Messages integration**
22. **Regression validation**
23. **06A roadmap completion**
24. **06B handoff**
25. **07B handoff**
26. **Manual native QA remaining**
27. **Warnings/blockers**
28. **Commit/PR reference**
