# PLANETS 05B — Mobile Project Participation Experience

**Roadmap area:** PLANETS 05 — Participation Lifecycle  
**Task type:** Flutter client over the canonical 05A participation backend  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main` **after PR #15 / 05A is merged**  
**05A reviewed implementation head while this prompt was written:** `fa3ef30262f4a7c441faa6f772b8758a5c6d26f8`

## Hard dependency

Do **not** begin 05B from current `main` while PR #15 is still unmerged.

Start only after:

1. PR #15 — **PLANETS 05A: project participation domain foundation** — is merged;
2. local `main` is synchronized to that merge;
3. Mobile, Web, and Database CI for the merged 05A state are green.

If 05A changes during review, inspect and use the **merged** contracts rather than assuming the head SHA above is still exact.

Before implementation, archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05B_mobile_project_participation_experience.md
```

---

# Objective

Implement the functional Flutter participation experience for both kinds of PLANETS **Progetti**:

- one-time Projects backed by `proposals`;
- recurring Projects / Tavoli backed by `recurring_activities`.

05A already provides one shared project-level participation backend. 05B must expose that behavior in the mobile app without duplicating the state machine in Flutter.

After this task:

- signed-out users can still browse Project/Tavolo detail normally;
- a user can choose **Request to join** from either one-time Project or Tavolo detail;
- sign-in and incomplete-profile setup preserve the join intent and return to the correct participation flow;
- the join request accepts an optional private message;
- pending request state is visible on project detail and can be withdrawn;
- rejected/withdrawn requests can later be retried while the project remains eligible;
- accepted/current members see that they are participating;
- accepted members can read participant-restricted operational meeting information;
- accepted members can leave;
- a member who voluntarily left or was creator-removed can request again if the project is still eligible, matching the accepted 05A behavior;
- project creators can open one shared **Participation** management screen from either Project or Tavolo;
- creators can review pending/history requests;
- creators can accept or reject pending requests;
- creators can view current/historical membership;
- creators can remove current participants;
- owner and requester state updates immediately after successful mutations;
- account switching cannot continue or reveal state from the previous identity;
- the current Profile / Browse / Home shell remains stable;
- no chat, notifications, resources, capacity/fullness, contribution verification, or web participation is implemented.

This is a functional interaction slice, not final visual design.

---

# Canonical 05A contracts

Inspect the merged generated types/migration rather than copying this section blindly.

The reviewed 05A head exposes operations equivalent to:

```text
request_to_join_project(
  p_expected_requester_profile_id,
  p_project_id,
  p_request_message?
)

withdraw_project_join_request(
  p_expected_requester_profile_id,
  p_request_id
)

accept_project_join_request(
  p_expected_creator_profile_id,
  p_request_id
)

reject_project_join_request(
  p_expected_creator_profile_id,
  p_request_id
)

leave_project(
  p_expected_participant_profile_id,
  p_membership_id
)

remove_project_member(
  p_expected_creator_profile_id,
  p_membership_id
)
```

Private read operations equivalent to:

```text
list_own_project_join_requests(
  p_expected_requester_profile_id
)

list_own_project_memberships(
  p_expected_participant_profile_id
)

list_project_join_requests(
  p_expected_creator_profile_id,
  p_project_id
)

list_project_members(
  p_expected_creator_profile_id,
  p_project_id
)

get_project_participant_meeting_details(
  p_expected_profile_id,
  p_project_id
)
```

The reviewed read payloads include concepts such as:

### Own request

```text
request_id
project_id
project_kind
status
request_message
created_at
resolved_at
```

### Own membership

```text
membership_id
project_id
project_kind
originating_request_id
membership_status
joined_at
left_at
removed_at
```

### Creator request review

```text
request_id
requester_profile_id
requester_display_name
request_message
status
created_at
resolved_at
resolved_by_profile_id
```

### Creator member review

```text
membership_id
participant_profile_id
participant_display_name
originating_request_id
membership_status
joined_at
left_at
removed_at
removed_by_profile_id
```

### Protected operational meeting data

```text
project_id
project_kind
exact_meeting_text
exact_location
```

Use the final merged schema/function signatures if they differ.

---

# Product decisions to preserve

## Progetti is the umbrella concept

One-time activities and Tavoli are both user-facing **Progetti**.

Their concrete current screens/routes remain separate in 05B because final unified Progetti information architecture is still deferred.

Do **not** merge Proposal and Tavolo client models merely to implement participation.

Participation itself should be one shared Flutter feature because the backend state machine is shared.

## Removal is not a permanent ban

The accepted 05A/product-decision behavior is:

- withdrawal does not permanently block a future request;
- rejection does not permanently block a future request;
- voluntary leave does not permanently block a future request;
- ordinary creator removal does **not** permanently block a future request.

A person can request again while the project is otherwise eligible and they have no pending request/current membership.

Do not add client-only “removed forever” behavior.

Blocking/moderation is later work.

## Membership is not verified contribution

Do not display accepted membership as:

```text
Verified contributor
Completed contribution
Badge earned
```

05C will own post-project contribution confirmation.

## No capacity

There is no:

- max participant count;
- Full/Pieno state;
- waitlist;
- quota.

Do not infer a disabled Join button from member count.

## Resources remain separate

The optional request message is plain private participation text.

Do not add structured:

- “what can you bring?” checkboxes;
- resource offers;
- donation/exchange fields.

04C owns Resources + Scambio-Dona later.

---

# Repository inspection

After 05A merges, inspect at minimum:

1. root `AGENTS.md`;
2. `apps/mobile/README.md`;
3. `apps/mobile/lib/app/README.md`;
4. `apps/mobile/lib/app/router/app_router.dart`;
5. `apps/mobile/lib/app/router/app_navigation_shell.dart`;
6. auth session/readiness/return-destination controllers;
7. profile readiness/edit flow;
8. complete Proposal Flutter feature;
9. complete recurring-activity/Tavoli Flutter feature;
10. current shared event-time helper;
11. merged 05A migration;
12. generated Database types;
13. merged 05A pgTAP + integration harness;
14. `docs/architecture/product-decisions.md`;
15. `docs/architecture/system-design.md`;
16. `docs/implementation/roadmap.md`;
17. existing Flutter widget/controller/router tests;
18. `.github/workflows/validation.yml`.

Important existing behavior:

- mobile uses one `StatefulShellRoute.indexedStack`;
- persistent bottom navigation remains **Profile / Browse / Home**;
- Proposal and Tavoli routes both live in the Browse branch;
- owner-only routes use OTP `returnTo` and complete-profile redirects;
- auth identity changes rebuild shell configuration;
- private controllers already use revision/identity checks after awaits;
- Proposal and Tavolo details are public signed-out screens;
- exact participant-restricted meeting data currently appears only as the public restricted explanation unless owner/private flows are used.

Do not weaken these patterns.

---

# 1. Shared Flutter participation feature

Add a focused feature, preferably:

```text
apps/mobile/lib/features/participation/
```

Use the established structure:

```text
domain/
data/
application/
presentation/
README.md
```

## Domain

Define strict client concepts for:

```text
ProjectKind
JoinRequestStatus
MembershipStatus
OwnProjectJoinRequest
OwnProjectMembership
CreatorProjectJoinRequest
CreatorProjectMember
ParticipantMeetingDetails
```

Exact names are Codex-owned.

`ProjectKind` should represent the backend wire values for one-time vs recurring projects.

Do not create a giant client `Project` superclass containing proposal/recurrence content.

## Data

One Supabase gateway owns the canonical 05A RPCs.

No direct reads from:

```text
projects
project_join_requests
project_memberships
```

No owner-table access.

Parse all payloads strictly and fail safely.

## Application

Use Riverpod controllers/providers for:

- own participation state;
- project-specific requester/member state;
- join/withdraw/leave commands;
- creator request/member review;
- accept/reject/remove commands;
- participant meeting-detail loading.

Every private state object is identity-bound.

---

# 2. Routing and auth intent

Participation interaction must stay inside the existing Browse branch.

Do **not** add a fourth bottom-navigation destination.

## Join routes

Prefer nested concrete routes:

```text
/proposals/:id/join
/tavoli/:id/join
```

Both render the same shared participation request screen/controller with:

- `projectId`;
- `projectKind`;
- correct detail return destination.

These routes are authenticated complete-profile management routes.

Required redirect behavior:

### Signed out

Opening:

```text
/proposals/<id>/join
```

or:

```text
/tavoli/<id>/join
```

redirects to OTP Auth with the exact safe internal `returnTo`.

After verification it returns to the join screen.

### Incomplete profile

Redirect to `/profile/edit` through the current readiness flow while preserving a way back to the requested Join flow according to existing router conventions.

Do not silently dump the user at Home.

If current profile-setup routing cannot preserve the requested post-setup join destination, implement the narrow routing fix needed and cover it with tests.

### Ready profile

Join route opens normally.

## Creator participation-management routes

Prefer:

```text
/proposals/:id/participants
/tavoli/:id/participants
```

Both render one shared creator Participation screen.

These are:

- authenticated;
- complete-profile protected;
- Browse-branch routes.

Authorization remains database-owned. A non-owner reaching the URL must receive a safe access state, not owner data.

## Route classification

Update route guards narrowly.

Static nested actions must not interfere with existing:

```text
edit
mine
create
```

and dynamic IDs.

Account identity changes must discard any retained:

- join message;
- request review;
- protected meeting data.

---

# 3. Participation state on public Project/Tavolo detail

Integrate one narrow participation panel/action area into:

- `ProposalDetailScreen`;
- `PublicRecurringActivityDetailScreen`.

Do not duplicate participation state logic inside each concrete feature.

Use a shared widget/controller adapter with `projectId` + `projectKind`.

## Signed out

Show an action equivalent to:

```text
Request to join
```

when the project presentation itself is join-relevant.

Tapping opens the concrete `/join` route so intent survives Auth.

Do not require sign-in merely to view detail.

## Ready signed-in non-creator

Derive current state from the 05A own-request and own-membership reads.

Possible states:

### No pending request / no current membership

Show:

```text
Request to join
```

Prior terminal history does not prevent a new request.

### Pending request

Show clearly:

```text
Request pending
```

and a **Withdraw request** action.

Do not allow a second request.

### Rejected or withdrawn history only

Allow a fresh **Request to join** while the project is still eligible.

A small prior-status note is acceptable but not required.

### Current membership

Show:

```text
You are participating
```

plus:

- protected operational meeting information when returned by the participant RPC;
- **Leave project** action.

Do not call this “verified contribution”.

### Historical left/removed membership only

Allow a fresh request while the project is still eligible.

Do not permanently disable Join after ordinary removal.

## Creator

Never show “Request to join” for own project.

Show a **Manage participation** action linking to the concrete participants route.

Creator may also use the shared protected-meeting boundary where useful, but do not duplicate owner meeting data if the existing owner feature already provides it.

## Closed/ineligible project

The backend owns eligibility.

Use concrete public lifecycle information to avoid presenting obviously impossible Join actions:

- one-time Proposal: cancelled or at/after end → no new request action;
- Tavolo: paused/ended → no new request action.

However do not recreate every backend rule locally as authorization.

Existing current membership/history may still be shown.

---

# 4. Join request screen

The shared join screen is functional and minimal.

Display:

- short explanation that this sends a request to the project organizer;
- optional multiline message;
- remaining/maximum length guidance if useful;
- submit action;
- safe validation/loading/error state.

05A currently bounds messages at 500 characters; use the merged canonical bound.

Trim semantics should match backend expectations.

An all-whitespace optional message should be sent as absent/null rather than a fake empty contribution.

Do not ask:

- skills;
- resources;
- phone/email;
- exact location;
- capacity;
- role.

## Submit

Call only `request_to_join_project`.

On success:

1. clear the temporary message;
2. refresh identity-bound own-request state;
3. return to the concrete project detail;
4. detail should immediately show **Request pending**.

Prevent double-submit.

A late successful response from an old authenticated identity must not update/navigate the new account's state.

---

# 5. Withdraw request

Pending requester can withdraw from detail.

Use a confirmation only if it improves clarity; do not make a reversible simple action unnecessarily cumbersome.

Call only:

```text
withdraw_project_join_request
```

After success:

- refresh own request state;
- project detail can expose Request to join again if still eligible.

No local deletion of history.

Do not hide the fact that the request is terminally withdrawn in underlying history; presentation may remain compact.

---

# 6. Creator Participation screen

One shared screen serves Proposal and Tavolo owners.

It should have two clear sections:

```text
Requests
Participants
```

Tabs/segmented control or stacked sections are both acceptable.

Do not introduce a whole new admin design system.

## Requests

Load:

```text
list_project_join_requests
```

Show at least:

- requester display name;
- private request message when present;
- submitted time;
- status.

Sort/present pending requests prominently.

For a pending request expose:

- Accept;
- Reject.

Resolved requests remain visible as history but have no decision buttons.

Do not expose:

- Auth email;
- private profile bio;
- skills unless a future explicit review requirement adds them;
- resources.

### Accept

Call:

```text
accept_project_join_request
```

On success:

- request becomes accepted;
- Participants updates immediately;
- exactly one membership appears;
- no chat UI appears.

### Reject

Call:

```text
reject_project_join_request
```

On success:

- request becomes rejected;
- no membership appears.

Prevent duplicate taps and stale post-await updates.

## Participants

Load:

```text
list_project_members
```

Show:

- display name;
- current/historical membership state;
- joined time;
- left/removed state where applicable.

Current participant:

- **Remove** action.

Historical participant:

- no Remove action.

Creator is not duplicated as a participant row.

### Remove

Use a confirmation dialog because removal affects current access to protected meeting information and later chat semantics.

Call only:

```text
remove_project_member
```

After success:

- member state updates to removed;
- protected meeting access is gone for that user;
- no client “ban forever” state is created.

---

# 7. Participant leave

A current member can leave from the participation panel on Project/Tavolo detail.

Use a confirmation dialog.

Explain concisely that leaving removes current participant access; do not make claims about future chat behavior because Plan 07 has not decided it.

Call only:

```text
leave_project
```

After success:

- current membership becomes historical;
- protected participant meeting information disappears;
- if project remains eligible, Request to join becomes available again.

Do not delete request/membership history locally.

---

# 8. Protected operational meeting information

This is a central 05B deliverable.

When the signed-in profile is:

- project creator; or
- current accepted participant,

the shared participation layer may call:

```text
get_project_participant_meeting_details
```

Use it to replace the public restricted-location explanation with the actual operational meeting information where appropriate.

## Non-members

Never call or render protected meeting data for:

- anonymous users;
- pending requesters;
- rejected/withdrawn users;
- left former members;
- removed former members;
- unrelated signed-in users.

The backend remains authoritative even if a client bug calls it.

## UI

For participant-restricted Projects:

Before acceptance:

```text
Exact location available after joining.
```

After acceptance:

show the returned exact operational meeting text.

If exact coordinates are returned but there is no map UI yet, do not invent a map. Text is enough.

## Memory/privacy

Protected data is identity-bound private state.

Clear it on:

- account switch;
- sign-out;
- leaving;
- creator removal reflected after refresh;
- disposal of the project-specific private controller where appropriate.

Never place it in:

- public card/detail domain models;
- debug logs;
- Sentry context;
- shared anonymous caches.

---

# 9. Own participation state architecture

The 05A backend exposes cross-project own request/membership lists.

Avoid an N-RPC query for every card or list item.

A reasonable design:

- one identity-bound provider loads own requests;
- one identity-bound provider loads own membership history;
- derive project-specific participation state in memory by `project_id`.

Or one combined identity-bound participation overview provider may load both.

Exact provider shape is Codex-owned.

Requirements:

- no durable persistence;
- private state cleared on identity change;
- refresh after every successful mutation;
- stale concurrent loads cannot overwrite newer state;
- public browsing remains usable if private participation state fails;
- a failure to load own participation should show a safe retry/action state rather than break the whole public detail screen.

Do not fetch participation for signed-out users.

---

# 10. Project-kind adapters

Participation is shared, but navigation/content remains concrete.

Create only narrow adapters for:

```text
ProjectKind.oneTime
ProjectKind.recurring
```

Responsibilities may include:

- detail route;
- join route;
- participants-management route;
- concrete lifecycle eligibility presentation.

Do not make shared participation depend on:

- Proposal skill models;
- recurrence schedule models;
- giant copied content objects.

The final UX direction where Tavoli becomes a Project type/filter is still a later presentation plan.

Do not redesign Browse in 05B.

---

# 11. Account-switch and race safety

Follow the strongest existing Proposal/Tavoli patterns.

Every mutation receives the expected profile ID for which the screen was rendered.

After each `await`, verify:

- request revision;
- authenticated identity;
- target project/request/membership still matches.

Cases that must fail safely:

- user A opens Join, switches to user B, then old submit resolves;
- creator A opens request review, switches account, then Accept resolves;
- participant A opens Leave confirmation, switches account before command;
- old protected meeting load completes after sign-out;
- two fast Accept taps;
- two fast Withdraw taps;
- route stack retained across account change.

No private A state may render under B.

The router's identity-triggered shell rebuild must remain intact.

---

# 12. Error handling

Map expected participation failures to app-owned safe states.

Examples:

- project no longer eligible;
- request already resolved;
- current membership already changed;
- stale identity;
- forbidden/not owner;
- temporarily unavailable.

Do not show raw:

- PostgREST errors;
- SQL exception text;
- Auth IDs;
- email;
- request payload JSON;
- protected exact location.

Concurrency/state conflicts should prompt refresh, not monitoring spam.

Unexpected errors may use existing Sentry behavior with current privacy defaults.

---

# 13. Localization and accessibility

Add all new user-facing copy to localization resources.

At minimum include concepts for:

- Request to join;
- optional message;
- Send request;
- Request pending;
- Withdraw;
- Participating;
- Leave project;
- Manage participation;
- Requests;
- Participants;
- Accept;
- Reject;
- Remove participant;
- status labels;
- protected meeting information;
- safe errors/empty states;
- confirmations.

Do not hardcode production-facing English strings in widgets.

Controls need accessible labels and normal Material semantics.

Long request messages and display names must wrap without overflow.

---

# 14. No database migration expected

05B should consume merged 05A as-is.

No database migration is expected.

A forward migration is allowed only if real mobile implementation exposes a concrete correctness/security blocker that cannot be solved cleanly through the merged contracts.

Do not modify the 05A migration.

Do not change the backend simply to:

- reduce a small client mapping;
- add project titles to private participation rows;
- create a central My Participation list;
- avoid filtering own request/member history by project ID.

If a genuine blocker appears, stop normal expansion and report it.

---

# 15. No central “My Participation” directory yet

05A private own reads return project IDs/kinds, not efficient public project-card summaries.

Do not introduce an N+1 central “My joined projects” screen in 05B just to satisfy a vague notion of history.

05B participation status/history is reachable from the corresponding project detail.

A future unified Progetti/profile-history design can add a proper efficient projection if needed.

This avoids:

- one detail RPC per historical membership;
- duplicated project title snapshots;
- premature unified discovery architecture.

---

# 16. Flutter tests

Add focused unit/widget/router tests with gateway fakes.

## Domain/parsing

Cover:

- project kinds;
- request statuses;
- membership statuses;
- nullable messages/timestamps;
- malformed payloads fail safely;
- current vs historical membership derivation;
- project-specific state resolution from own lists.

## Router/auth

Cover both concrete types:

- signed-out `/proposals/:id/join` → Auth with exact returnTo;
- signed-out `/tavoli/:id/join` → Auth with exact returnTo;
- ready user reaches join screen;
- incomplete profile reaches setup and can recover intended join destination;
- `/proposals/:id/participants` creator route;
- `/tavoli/:id/participants` creator route;
- participation routes select Browse;
- bottom nav remains exactly Profile / Browse / Home;
- identity change clears private participation stack/state.

## Detail participation panel

For both Proposal and Tavolo:

- signed-out Request to join;
- creator gets Manage participation, never Join;
- no history → Join;
- pending → Pending + Withdraw;
- accepted/current → Participating + Leave;
- rejected history → can Join again if eligible;
- withdrawn history → can Join again;
- left history → can Join again;
- removed history → can Join again;
- ineligible closed project → no new request action;
- private participation-load failure does not destroy public detail.

## Join form

- optional message;
- max-length validation according to merged 05A;
- whitespace-only becomes absent;
- submit disables during mutation;
- duplicate submit prevented;
- success returns to detail and pending state appears;
- stale identity after await does not update/navigation-leak.

## Owner review

- pending requests prominent;
- request message visible only in owner screen;
- accept;
- reject;
- resolved history has no action;
- accepted request appears in members;
- current member Remove;
- historical left/removed member no Remove;
- creator does not appear as membership;
- unauthorized/non-owner safe state.

## Leave/remove

- leave confirmation;
- leave refreshes state;
- removal confirmation;
- removal refreshes owner/member state;
- removed/left user can request again when eligible;
- no permanent-ban presentation.

## Protected meeting access

- anonymous sees restricted explanation only;
- pending sees restricted explanation;
- accepted current member sees protected text;
- creator sees authorized operational detail where integrated;
- leave removes protected text;
- removal removes protected text after state refresh;
- account switch clears protected data;
- protected text never appears in public card model/widgets/log assertions.

---

# 17. Real backend evidence and integration

Do not duplicate the complete multi-user state machine in Flutter tests.

The merged 05A local integration harness remains authoritative backend evidence for:

- request/accept/reject;
- concurrency;
- leave/remove;
- protected meeting access;
- both project kinds;
- privacy.

Keep it green.

If useful, extend an existing Flutter/integration abstraction only for client routing/state; do not add a fragile device E2E framework solely for this plan.

---

# 18. Validation

Run and keep green:

- Flutter localization generation;
- Dart formatting;
- Flutter analyze;
- all mobile tests;
- all web tests/tooling/lint/typecheck/build;
- migration replay;
- DB lint;
- all pgTAP assertions;
- Auth/profile/Proposal/Tavolo/participation integrations;
- public web Tavoli integration;
- generated type drift;
- `git diff --check`.

No hosted provider account is required.

---

# 19. Documentation and roadmap

Add:

```text
apps/mobile/lib/features/participation/README.md
```

Document:

- shared participation feature boundary;
- concrete Proposal/Tavolo adapters;
- canonical 05A RPC use;
- private identity-bound state;
- join/withdraw/member lifecycle presentation;
- owner review;
- protected operational meeting data;
- removal/re-request behavior;
- deferred chat/resources/capacity/contribution verification.

Update mobile route documentation.

Update roadmap while PR is open:

- 05A → `Implemented` with actual merge reference after it exists;
- 05B → `In progress`;
- parent 05 → `In progress`;
- 05C → `Not started`;
- 04C Resources + Scambio-Dona → `Not started`;
- Plan 06 remains blocked/dependent according to roadmap ordering;
- Plan 07 remains unresolved on exact chat trigger/access rules.

Do not claim final Progetti unified information architecture is implemented.

---

# 20. Manual native QA gate

Leave the PR unmerged for native review.

Test on Android at minimum; iOS where available.

Checklist:

1. signed-out Proposal detail → Request to join → OTP → return to Join;
2. signed-out Tavolo detail → same;
3. incomplete profile setup → intended Join flow recovery;
4. optional message keyboard/scrolling;
5. send one-time Project request;
6. pending state visible on detail;
7. withdraw and request again;
8. send Tavolo request;
9. creator opens Participation;
10. creator sees private requester message;
11. accept request;
12. requester detail becomes Participating;
13. participant-restricted exact meeting information becomes visible;
14. participant leaves;
15. exact protected information disappears;
16. requester can request again after leave;
17. creator accepts again;
18. creator removes participant;
19. protected information disappears;
20. removed user can request again while project eligible;
21. creator rejects a request;
22. rejected user can later retry;
23. one-time ended/cancelled Project does not offer new request;
24. paused/ended Tavolo does not offer new request;
25. account switch while Join form has text;
26. account switch while creator request review is open;
27. back navigation through Join/Participants/detail;
28. bottom nav remains Profile / Browse / Home;
29. Proposal/Tavoli Browse state is not reset unnecessarily;
30. no chat/notification/resource UI appears.

Record manual QA separately from automated implementation status.

---

# Non-goals

Do not implement:

- web participation;
- central My Participation directory;
- chat or chat creation;
- notification delivery;
- resource contribution fields;
- Scambio-Dona;
- capacity/fullness/waitlist;
- participant roles/co-organizers;
- invitations;
- public member directory;
- verified contribution/completion review;
- stats/badges/privileges;
- Online/In-Presence schema/UI;
- final unified Progetti discovery redesign;
- maps/media/payments;
- moderation/blocking;
- legal-entity participation;
- final visual design.

---

# Acceptance criteria

05B is ready for review when:

- [ ] based on merged 05A `main`, not the unmerged PR branch;
- [ ] exact prompt archived;
- [ ] one shared Flutter participation feature serves Proposal and Tavolo;
- [ ] no fourth bottom-navigation destination;
- [ ] public detail remains signed-out accessible;
- [ ] concrete `/join` routes preserve OTP returnTo;
- [ ] incomplete-profile flow preserves/reaches intended Join flow;
- [ ] optional private request message works;
- [ ] pending request state/withdraw works;
- [ ] rejected/withdrawn/left/removed history can request again when eligible;
- [ ] current membership state is shown;
- [ ] current participant can leave;
- [ ] creator can review request history;
- [ ] creator can accept/reject pending requests;
- [ ] creator can review current/historical members;
- [ ] creator can remove current member;
- [ ] creator is not duplicated as membership;
- [ ] current accepted participant can read protected operational meeting data;
- [ ] pending/historical/unrelated users cannot render protected data;
- [ ] leave/removal clears protected data from UI state;
- [ ] account switch clears request/member/protected state;
- [ ] all mutations carry expected identity;
- [ ] stale post-await operations cannot affect new account;
- [ ] public detail failure remains independent from private participation-state failure;
- [ ] no chat/notifications/resources/capacity/contribution verification is faked;
- [ ] Flutter/Web/Database validation remains green;
- [ ] native QA remains an explicit pre-merge gate;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact Dart class/provider names;
- nested route implementation;
- join form layout;
- stacked sections vs tabs on creator Participation;
- narrow project-kind adapter shape;
- whether own request/membership reads use one or two providers;
- exact safe status copy;
- confirmation-dialog presentation.

Stop and report before:

- changing 05A state semantics in Flutter;
- treating creator removal as permanent ban;
- adding capacity/fullness;
- adding structured resources;
- creating chat;
- adding web participation;
- adding a central My Participation N+1 screen;
- redesigning Proposal/Tavolo discovery into final Progetti IA;
- weakening protected meeting privacy;
- adding a database migration without a concrete blocker;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 05B prompt;
2. shared Flutter participation domain/data/application feature;
3. strict 05A RPC gateway;
4. identity-bound own participation state;
5. Proposal/Tavolo participation panel integration;
6. concrete authenticated Join routes;
7. optional-message join flow;
8. pending/withdraw/re-request flow;
9. current membership/leave flow;
10. protected participant meeting-info UI;
11. shared creator Participation review screen;
12. accept/reject/remove flow;
13. account-switch/race safety;
14. localization/accessibility;
15. focused unit/widget/router tests;
16. mobile documentation + roadmap update;
17. focused PR, preferably `codex/05b-mobile-project-participation`;
18. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Participation feature architecture**
5. **05A RPC gateway**
6. **Routes/auth returnTo**
7. **Own participation-state design**
8. **Proposal detail integration**
9. **Tavolo detail integration**
10. **Join request/message flow**
11. **Pending/withdraw/re-request behavior**
12. **Membership/leave behavior**
13. **Creator request review**
14. **Creator member review/removal**
15. **Protected operational meeting information**
16. **Removal/re-request semantics**
17. **Account-switch/race safety**
18. **Localization/accessibility**
19. **Tests**
20. **05A backend integration/regression evidence**
21. **Validation/CI**
22. **Documentation/roadmap**
23. **Manual native QA remaining**
24. **Deferred 05C / 04C work**
25. **Warnings/blockers for Plans 06/07**
26. **Commit/PR reference**

Do not report web participation, chat, notifications, resources, capacity, contribution verification, Online/In-Presence, badges, or final Progetti discovery as implemented.
