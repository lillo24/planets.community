# PLANETS 04C4C3A — Mobile Resource Requests + Unified Requests Inbox

**Roadmap area:** 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience  
**Task type:** Flutter/mobile integration over the 04C4A/C2 request contracts  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open Scambio-Dona stack:

```text
PR #75 — 04C4C2 Unified Messages Projections + Resource Notification Projection
branch: codex/04c4c2-resource-messages-notifications
head:   cdb42ecca45964aed464fca1ac3443862e442b43
```

PR #75 is draft and stacked on PR #73/#72/#71/#70. Do not merge any dependency.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #75 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #75 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c3a-mobile-resource-requests
```

Open the new PR with base:

```text
codex/04c4c2-resource-messages-notifications
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C3A_mobile_resource_requests_unified_requests.md
```

No external document is required by Codex.

---

# Objective

Implement the first mobile Scambio-Dona interaction slice:

```text
Resource listing
→ show active-interest count
→ requester sends request + optional message
→ request appears in Messages / Requests
→ requester may withdraw while pending
→ owner may accept/reject while pending
→ both see canonical status/history
```

Also migrate the existing **Messages → Requests** tab from the old Project-only projection to the new unified C2 projection:

```text
participation_request
resource_request
```

Do **not** migrate the Chats tab in this slice.

Do **not** implement resource chat or agreement negotiation/milestones yet.

---

# 1. Scope split

04C4C3 is now split as:

```text
04C4C3A — Mobile Resource Requests + Unified Requests Inbox
  this plan

04C4C3B — Mobile Resource Conversation + Unified Chats
  resource chat list/detail/send/Realtime
  read-only after coordination closes

04C4C3C — Mobile Scambio Agreement Experience
  terms proposal/counterproposal
  accept/reject/withdraw terms
  milestone controls
  timeline
  overdue presentation

04C4C3D — Mobile Resources Notification UX
  Resources notification kinds/copy
  resource request/chat destinations
  Resources preference controls
```

Do not implement B/C/D in this PR.

---

# 2. No database migration

C3A is mobile-only.

Use the canonical contracts already present in PR #75 and lower layers.

Do not add or alter SQL/RPCs.

If a mobile need appears awkward, prefer the existing requester-history/unified-message contracts rather than introducing schema scope creep.

---

# 3. Public listing active-interest count

04C4A already extended:

```text
list_public_resource_listings
get_public_resource_listing
```

with:

```text
active_request_count
```

Update `PublicResourceListingSummary` and payload parsing.

Validate:

```text
integer >= 0
```

Do not infer requester identity from the count.

---

# 4. Active-interest UI

Show the count on:

```text
public listing card
public listing detail
```

Localized user-facing language should communicate interest, not reservation.

Examples conceptually:

```text
1 person interested
4 people interested
```

Do not say:

```text
4 reservations
4 people in queue
4 offers accepted
```

because the count is:

```text
pending
+
coordination-open accepted
```

and does not encode loan queue position.

At zero, either hide the line or show a quiet localized zero-state according to the cleanest existing card layout.

Prefer hiding it on compact cards at zero.

---

# 5. Resource-request mobile domain

Add a narrow typed resource-request domain, either as a dedicated feature or a clearly separated subdomain under resource listings.

Statuses:

```text
pending
accepted
rejected
withdrawn
listingClosed
```

Do not reuse `JoinRequestStatus`, because Project requests do not have `listing_closed` and their semantics differ.

Conceptual model:

```text
ResourceRequest {
  id
  listingId
  listingMode
  listingTitle
  listingLifecycle

  ownerProfileId
  ownerDisplayName

  requesterProfileId
  requesterDisplayName

  status
  requestMessage
  createdAt
  resolvedAt
  coordinationClosedAt?
}
```

A requester-history variant may omit requester fields when canonical RPC does not return them.

Keep parser contracts explicit.

---

# 6. Active request definition

For requester-side listing state:

```text
pending
→ active

accepted + coordinationClosedAt == null
→ active

accepted + coordinationClosedAt != null
→ historical, not active

rejected / withdrawn / listingClosed
→ historical
```

Do not treat every historical `accepted` request as still active.

---

# 7. Resource-request gateway

Add a mobile RPC-only gateway using existing canonical calls:

```text
request_resource_listing

withdraw_resource_listing_request
accept_resource_listing_request
reject_resource_listing_request

list_own_resource_listing_requests
get_resource_listing_request
```

Use exact parameter names from the repository.

No direct table access.

---

# 8. Requester history cache/controller

Use:

```text
list_own_resource_listing_requests(
  p_expected_requester_profile_id
)
```

as the canonical way to discover whether the logged-in requester already has an active request for the current listing.

Load it **once per authenticated identity**, not once per resource card.

Maintain identity-bound state and clear it on:

```text
sign-out
account switch
```

Provide a lookup:

```text
activeRequestForListing(listingId)
```

using the canonical active definition.

Do not trigger N+1 requester-history calls from public listing cards.

---

# 9. Public listing detail request state

For a ready authenticated user who is **not** the listing owner:

## No active request

Show primary action:

```text
Request
```

## Pending request

Show canonical state such as:

```text
Request pending
```

with:

```text
Withdraw request
View request
```

## Accepted + coordination open

Show:

```text
Accepted
View request
```

Do not show resource-chat/agreement controls yet.

C3B/C will add those.

## Historical completed/cancelled accepted episode

It no longer blocks a new request.

Show normal:

```text
Request
```

while history remains in Messages.

---

# 10. Owner listing detail behavior

The owner never sees the Request action on their own listing.

They still see:

```text
N interested
```

if nonzero.

Owner request management happens through:

```text
Messages → Requests
```

in C3A.

Do not add a second owner request-management surface to listing detail unless a trivial link to Messages is clearly beneficial.

Avoid duplicate business UI.

---

# 11. Request composer

Tapping Request opens a focused bottom sheet/dialog.

Fields:

```text
optional message
max 500 chars
```

Copy should make clear:

```text
this expresses interest
it does not reserve or transfer the item
```

Do not ask for:

- what the requester offers;
- give/lend choice;
- loan dates;
- duration;
- handoff location;
- contact details.

Those belong to agreement negotiation later.

---

# 12. Request creation

On submit:

```text
request_resource_listing(
  expected requester identity,
  listing ID,
  optional message
)
```

Use one mutation attempt.

During submit:

- prevent duplicate taps;
- preserve typed text;
- show progress.

After success:

1. reload requester history;
2. reload current public listing detail;
3. refresh public listing feed/count where practical;
4. refresh unified Messages Requests inbox;
5. show canonical pending state.

Do not fabricate the request locally beyond temporary progress state.

---

# 13. Duplicate/race `PT409` on creation

A duplicate active request may already exist due to another device/session.

On:

```text
PT409
```

do not retry.

Instead:

1. reload requester history;
2. reload listing detail/count;
3. refresh Messages Requests;
4. if canonical active request is found, show its current state;
5. show localized guidance such as:
   ```text
   You already have an active request for this resource.
   ```

If no canonical request can be loaded, use a safe generic conflict message.

---

# 14. Request-input failures

Map at least:

```text
22023 → invalid input
42501 → forbidden / identity changed
55000 → listing no longer requestable
P0002 → listing/request unavailable
PT409 → canonical conflict
other → unavailable
```

Never expose raw backend messages.

If listing became closed/unavailable:

- refresh detail/list;
- preserve no stale Request action.

---

# 15. Unified Messages request models

Migrate the Requests inbox to a strict discriminated model.

Conceptually:

```text
enum StructuredRequestItemKind {
  participationRequest
  resourceRequest
}
```

Use a sealed/discriminated model rather than nullable-field soup throughout the UI.

Possible shape:

```text
sealed StructuredRequestMessageItem {
  kind
  requestId
  viewerRole
  requesterProfileId
  requesterDisplayName
  requestMessage
  statusWire/domain status
  createdAt
  resolvedAt
  activityAt
}

ParticipationStructuredRequestItem
ResourceStructuredRequestItem
```

Exact Dart design is Codex's choice.

---

# 16. Future Groups/Invites compatibility

The Messages architecture must remain **centrally discriminated and extensible**.

Do not scatter assumptions throughout the app that structured Messages can forever contain only:

```text
participation_request
resource_request
```

Future product areas may add items such as:

```text
group_invite
project_invite
```

Do **not** implement those kinds now.

The requirement is only architectural:

- one central discriminator/parser/router boundary;
- per-kind typed rendering;
- no dozens of unrelated `if project else resource` assumptions.

Unknown backend kinds should fail safely rather than being rendered as another domain.

---

# 17. Unified request cursor model

C2 cursor requires:

```text
activityAt
itemKind
requestId
```

Create a mobile cursor with all three.

Pagination must send the complete cursor.

Do not fall back to the old:

```text
(activityAt, requestId)
```

cursor.

---

# 18. Unified Messages gateway

Migrate the Requests-list call to:

```text
list_own_structured_request_message_items
```

and exact discriminated reads to:

```text
get_own_structured_request_message_item
```

Preserve existing Project-specific gateway methods needed by the existing Project request detail/triage flow.

Do not remove them merely because unified reads now exist.

---

# 19. Request inbox deduplication

Deduplicate by composite identity:

```text
(itemKind, requestId)
```

not only UUID.

C2 explicitly supports cross-domain UUID collisions.

---

# 20. Messages Requests tab cards

Render both item kinds in the same chronological list.

## Participation request

Keep current visual semantics/regressions.

## Resource request

Show enough context:

```text
Scambio-Dona / Resource
listing title
counterparty/requester context
status
message preview
activity time
```

Use existing mode label where useful:

```text
Dona
Scambia
```

Do not introduce `Presta` listing UI yet.

---

# 21. Resource request status labels

Add localized labels for:

```text
Pending
Accepted
Rejected
Withdrawn
Listing closed
```

For `listing_closed`, use user-facing copy that means the listing was closed/unavailable, not that the user manually withdrew.

---

# 22. Resource request route

Add a discriminator-safe route.

Preferred form:

```text
/messages/requests/resource/:requestId
```

Keep the existing Project route working:

```text
/messages/requests/:requestId
```

or introduce a Project-qualified route while preserving a compatibility alias.

Do not make notifications/old deep links to Project participation requests break.

Add central route builders.

---

# 23. Resource request detail screen

Create a dedicated Resource request detail screen.

Use unified exact read or canonical resource exact read, but keep one source of truth per load.

Display:

```text
listing title
listing mode
listing lifecycle where relevant

requester
owner/counterparty

request message, if present

status
requested at
resolved at, if present
```

No agreement terms yet.

No resource chat UI yet.

---

# 24. Owner actions

For:

```text
viewerRole = owner
status = pending
```

show:

```text
Accept
Reject
```

Use the canonical 04C4A RPCs.

Acceptance only means:

```text
willing to coordinate
```

Do not use completion/reservation language.

---

# 25. Requester action

For:

```text
viewerRole = requester
status = pending
```

show:

```text
Withdraw request
```

No withdraw after accepted.

---

# 26. Accepted request detail

For `accepted`:

show a clear factual state:

```text
Accepted
```

If:

```text
coordinationClosedAt == null
```

copy can indicate coordination is open.

If non-null:

```text
coordination finished
```

Do not expose agreement completion/cancellation distinctions unless the unified request contract supplies them—it currently exposes coordination closure, not agreement lifecycle.

C3B/C will add richer agreement/chat context.

---

# 27. Resource-request mutation controller

Use an identity-safe controller keyed by:

```text
request ID
```

or an equivalent family.

Mutations:

```text
accept
reject
withdraw
```

After success:

1. reload exact canonical request;
2. refresh unified Requests inbox;
3. refresh requester history if current identity is requester;
4. refresh affected public listing count/detail where that state is currently resident.

Never update status optimistically as canonical truth.

---

# 28. Mutation race `PT409`

If another device/counterparty resolves the pending request first:

```text
PT409
```

Perform no automatic retry.

Reload exact canonical request and unified inbox.

Show localized live-region guidance equivalent to:

```text
This request changed elsewhere. The latest status has been loaded.
```

The canonical state decides which actions remain visible.

---

# 29. Existing Project participation request behavior must remain intact

Do not regress:

- contribution selection rendering;
- accept-triage sheet;
- reject;
- withdraw;
- creator/requester roles;
- status chips;
- routing from existing Project notifications;
- current Messages Project request tests.

The unified inbox is a list/projection migration, not a rewrite of the Project request-detail domain.

---

# 30. Requests tab refresh/pagination

Preserve:

- pull-to-refresh;
- load more;
- partial-error behavior;
- identity revision guards.

Use composite request cursor and composite deduplication.

A Resource mutation should be reflected after refresh without losing Project items.

---

# 31. Chats tab explicitly stays unchanged

Do **not** switch the Chats tab to:

```text
list_own_message_chat_items
```

in C3A.

Keep existing Project chat list/controller/routes.

04C4C3B will migrate Chats atomically when the resource-chat screen is implemented.

This avoids rows that navigate to a screen that does not yet exist.

---

# 32. Notification UX explicitly stays unchanged

C2 backend Resource notifications may currently render generic fallback copy.

Do not add Resource notification enums/routes/preferences in C3A.

04C4C3D owns notification UX after Resource request/chat destinations exist.

Existing generic handling must remain safe.

---

# 33. Listing count synchronization

After request state changes that affect active-interest count:

```text
create
withdraw
reject
coordination later closes
```

C3A only directly owns create/withdraw/reject/accept.

Refresh relevant resource listing state so counts do not remain obviously stale in the current session.

Acceptance keeps the request active, so count normally does not change.

Do not manually increment/decrement without canonical reload.

---

# 34. Account switching

All private Resource-request state must be identity-bound.

On account change:

- clear requester history;
- clear resource request detail;
- discard in-flight late responses;
- clear request composer mutation state;
- existing unified Messages controller must do the same.

No cross-account private request data may remain rendered.

---

# 35. Accessibility

Cover:

- active-interest count semantics;
- Request button;
- request-message field;
- status chips;
- Accept/Reject/Withdraw controls;
- loading/disabled states;
- conflict/error messages as live regions;
- long listing titles/messages;
- high text scaling.

Avoid color-only status meaning.

---

# 36. Localization

Add production localization for concepts equivalent to:

```text
{count} person interested
{count} people interested

Request
Request this resource
Optional message
Sending a request shows interest. It does not reserve the resource.

Request pending
Accepted
Rejected
Withdrawn
Listing closed
Coordination open
Coordination finished

Withdraw request
Accept request
Reject request

You already have an active request for this resource.
This request changed elsewhere. The latest status has been loaded.

Unable to send request.
Unable to update request.
Unable to load request.

Resource request
Requested at {date}
Resolved at {date}
```

Use ARB/pluralization support rather than manual English plural logic where available.

---

# 37. Tests — resource listing parsing/UI

Cover:

- active request count parsing;
- negative/malformed count rejected;
- card nonzero count;
- card zero behavior;
- detail count;
- owner has no Request action;
- non-owner no-active request has Request;
- pending state;
- accepted-open state;
- historical accepted coordination closed allows a new Request.

---

# 38. Tests — resource request gateway

Cover exact RPC names/params for:

```text
create
withdraw
accept
reject
requester history
exact request
```

Parser coverage for all five statuses and coordination closure.

No direct table calls.

---

# 39. Tests — requester history/controller

Cover:

- one identity load;
- active pending lookup;
- active accepted/open lookup;
- accepted/closed historical excluded from active;
- terminal statuses excluded;
- multiple episodes same listing;
- newest active canonical episode;
- account switch clears state;
- late old-account response ignored.

---

# 40. Tests — request creation

Cover:

- optional message;
- blank message;
- 500-char boundary;
- progress/double-submit guard;
- success refreshes history/listing/Messages;
- PT409 reloads active request without retry;
- 55000 refreshes unavailable listing state;
- identity change.

---

# 41. Tests — unified request models/gateway

Cover:

- Project discriminator;
- Resource discriminator;
- strict XOR parsing;
- viewer roles:
  - requester
  - creator
  - owner;
- resource status parsing including `listing_closed`;
- Resource chat/agreement IDs null before acceptance;
- non-null accepted shape;
- three-part cursor params;
- unknown kind fails safely.

---

# 42. Tests — unified inbox controller

Cover:

- mixed Project + Resource page ordering;
- load more;
- same request UUID across two item kinds;
- composite dedupe;
- complete cursor from final item;
- refresh;
- partial failure;
- account switch.

---

# 43. Tests — Messages Requests UI

Cover:

- existing Project request card unchanged;
- Resource request card;
- status labels;
- request message preview;
- routing to correct domain detail;
- mixed list ordering;
- Project participation detail still works;
- no Resource chat row added to Chats in C3A.

---

# 44. Tests — Resource request detail

Cover:

## Requester

```text
pending → Withdraw
accepted → no Withdraw
rejected/withdrawn/listingClosed → read-only
```

## Owner

```text
pending → Accept + Reject
non-pending → read-only
```

Also:

- optional message hidden when null;
- dates;
- PT409 canonical reload;
- forbidden/not-found safe state;
- high text scale.

---

# 45. Router tests

Cover:

```text
/messages/requests/resource/:requestId
```

plus preservation of existing Project request deep link.

Future structured kinds must not require changing unrelated route parsing everywhere.

---

# 46. No Groups implementation, but keep extensibility

Recent product design adds future persistent Groups and structured invitations.

Do not implement:

```text
Groups
group_invite
project_invite
WhatsApp invite links
```

in C3A.

Only preserve the discriminated Messages architecture so those can later become additional typed items without redesigning this feature.

---

# 47. Documentation / roadmap

Refine 04C4C3:

```text
04C4C3A — Mobile Resource Requests + Unified Requests Inbox
  this plan

04C4C3B — Mobile Resource Conversation + Unified Chats
  not started

04C4C3C — Mobile Scambio Agreement Experience
  not started

04C4C3D — Mobile Resources Notification UX
  not started
```

Document that future Groups/invites are a separate roadmap family and only architectural extensibility is preserved here.

Do not implement them.

---

# 48. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused Flutter tests and formatting.

No database changes are expected.

The inherited stacked database blockers remain blockers for eventual stack merge, but C3A itself should not add a new DB gate.

Attempt hosted Validation once.

If GitHub again fails to allocate a runner because of account payment/spending-limit status:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL migrations;
- Resource chat mobile screen;
- unified Chats migration;
- agreement terms UI;
- proposal/counterproposal UI;
- milestone/handoff/return UI;
- agreement timeline UI;
- overdue UI;
- Resources notification copy/routes/preferences;
- push provider delivery;
- Dona policy redesign;
- first-class `Presta` listing UI;
- loan calendar/queue;
- Project matching;
- saved searches;
- Groups;
- group/project invitation flows;
- WhatsApp sharing;
- generic DMs.

---

# Acceptance criteria

Ready for review when:

- [ ] based on PR #75;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] public listings parse/display `active_request_count`;
- [ ] Resource-request domain is distinct from Project join requests;
- [ ] requester history is loaded once per identity, not per card;
- [ ] active request derivation handles coordination closure correctly;
- [ ] non-owner can create Resource request with optional message;
- [ ] owner cannot self-request;
- [ ] pending requester can withdraw;
- [ ] pending owner can accept/reject;
- [ ] PT409 reloads canonical state with no retry;
- [ ] successful mutations refresh canonical count/history/inbox;
- [ ] Messages Requests tab uses unified C2 projection;
- [ ] unified cursor includes activity/kind/request ID;
- [ ] dedupe uses `(kind, requestId)`;
- [ ] Project request behavior/triage remains intact;
- [ ] Resource request detail screen exists;
- [ ] Resource routes are discriminator-safe;
- [ ] existing Project request deep links remain valid;
- [ ] Chats tab remains Project-only in C3A;
- [ ] Resource notification UX remains deferred;
- [ ] structured Messages architecture remains extensible for future invite kinds;
- [ ] localization/accessibility complete;
- [ ] focused/mobile regression tests pass;
- [ ] debug APK passes;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C4C3A branch/base/PR**
3. **Changed files**
4. **Active-interest model/parsing**
5. **Listing card/detail interest UI**
6. **Resource-request domain models**
7. **Resource-request gateway**
8. **Requester-history cache**
9. **Active-request derivation**
10. **Request composer**
11. **Request creation**
12. **Creation PT409 recovery**
13. **Requester withdraw**
14. **Owner accept**
15. **Owner reject**
16. **Mutation conflict recovery**
17. **Canonical refresh behavior**
18. **Unified structured-request models**
19. **Future discriminator extensibility**
20. **Unified Requests gateway**
21. **Unified cursor**
22. **Composite deduplication**
23. **Messages Requests UI**
24. **Project request regression**
25. **Resource request route/detail**
26. **Chats-tab non-change**
27. **Notification-UX non-change**
28. **Account-switch safety**
29. **Localization/accessibility**
30. **Gateway/controller/widget tests**
31. **Router tests**
32. **Local regression validation**
33. **Hosted Validation executed/not-executed**
34. **04C4C3B handoff**
35. **04C4C3C handoff**
36. **04C4C3D handoff**
37. **Groups/invites future-compatibility handoff**
38. **Warnings/blockers**
39. **Commit/PR reference**

Do not merge any PR.
