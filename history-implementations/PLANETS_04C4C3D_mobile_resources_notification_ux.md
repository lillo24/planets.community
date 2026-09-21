# PLANETS 04C4C3D — Mobile Resources Notification UX

**Roadmap area:** 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience  
**Task type:** Flutter/mobile notification models, copy, routes, and Resources preference UX  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #81 — 04C4C3C2 Mobile Handoff / Return / Timeline / Overdue
branch: codex/04c4c3c2-mobile-handoff-timeline-overdue
head:   bacc9e4d1985a2fac702fca06d6dbe862fb0f477
```

Before implementation:
1. fetch current `origin/main`;
2. verify PR #81 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #81 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c3d-mobile-resource-notifications
```

Open against:

```text
codex/04c4c3c2-mobile-handoff-timeline-overdue
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C3D_mobile_resources_notification_ux.md
```

No external document is required.

---

# Objective

Finish the mobile Scambio-Dona notification experience over the backend projection already implemented in 04C4C2.

The backend already supports:

```text
category = resources

destination:
  resource_request
  resource_chat
```

and these kinds:

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

This slice must:

```text
parse Resource notifications strictly
→ show localized meaningful copy
→ route into existing Resource request/chat screens
→ expose Resources in-app notification preference
```

No SQL/projector changes.

---

# 1. No database migration

Use existing:

```text
list_own_notifications
list_own_notification_preferences
set_own_notification_preference
```

Do not alter notifications/outbox/push schemas.

---

# 2. Notification category

Extend:

```text
NotificationCategory
```

with:

```text
resources
```

Wire:

```text
resources → NotificationCategory.resources
```

Keep `unknown` for future categories.

---

# 3. Resource notification kinds

Add typed kinds:

```text
resourceRequestReceived
resourceRequestWithdrawn
resourceRequestAccepted
resourceRequestRejected
resourceRequestListingClosed

resourceChatMessageReceived

resourceExchangeTermsProposed
resourceExchangeTermsAccepted
resourceExchangeTermsRejected
resourceExchangeTermsWithdrawn
resourceExchangeMilestoneRecorded
resourceExchangeCancelled
resourceExchangeCompleted
```

Keep `unknown`.

Centralize wire mapping.

---

# 4. Resource destinations

Extend:

```text
NotificationDestinationKind
```

with:

```text
resourceRequest
resourceChat
```

Wire:

```text
resource_request
resource_chat
```

---

# 5. Resource notification context

Add fields already returned by `list_own_notifications`:

```text
resourceListingId
resourceListingTitle
resourceRequestId
resourceChatId
resourceChatMessageId
resourceAgreementId
resourceAgreementEventId
resourceExchangeEventKind
resourceExchangeLegKind
```

Do not add or fetch:
- request text;
- chat body;
- private agreement note;
- requester resource description;
- lend dates;
- contact details.

---

# 6. Resource event metadata

Supported event kinds relevant to Resource notifications:

```text
terms_proposed
terms_accepted
terms_rejected
terms_withdrawn

resource_provided
resource_received
resource_returned
resource_return_received

agreement_cancelled
agreement_completed
```

Add a small strict leg enum if useful:

```text
owner_resource
requester_resource
```

Only milestone notifications require leg metadata.

---

# 7. Strict Resource shape validation

For every known:

```text
category = resources
```

require:

```text
resourceListingId
resourceListingTitle
resourceRequestId
actorProfileId
```

Project-only fields must be null:

```text
projectId
projectKind
projectTitle
requestId
chatId
messageId
```

Then validate exact shape per notification kind.

---

# 8. Request notification shapes

For:

```text
resourceRequestReceived
resourceRequestWithdrawn
resourceRequestRejected
resourceRequestListingClosed
```

require:

```text
destination = resourceRequest
resourceListingId
resourceRequestId
```

Require null:

```text
resourceChatId
resourceChatMessageId
resourceAgreementId
resourceAgreementEventId
resourceExchangeEventKind
resourceExchangeLegKind
```

---

# 9. Accepted request shape

For:

```text
resourceRequestAccepted
```

require:

```text
destination = resourceChat
resourceListingId
resourceRequestId
resourceChatId
resourceAgreementId
```

Require null chat-message/agreement-event metadata.

---

# 10. Resource chat message shape

For:

```text
resourceChatMessageReceived
```

require:

```text
destination = resourceChat
resourceListingId
resourceRequestId
resourceChatId
resourceChatMessageId
resourceAgreementId
```

No agreement-event metadata.

Never expect a body.

---

# 11. Resource exchange notification shape

For all supported `resourceExchange*` kinds require:

```text
destination = resourceChat
resourceListingId
resourceRequestId
resourceChatId
resourceAgreementId
resourceAgreementEventId
resourceExchangeEventKind
```

For milestone:

```text
resourceExchangeLegKind != null
event kind ∈:
  resource_provided
  resource_received
  resource_returned
  resource_return_received
```

For non-milestone Resource exchange notifications:

```text
resourceExchangeLegKind == null
```

---

# 12. Kind/event consistency

Require:

```text
resourceExchangeTermsProposed  → terms_proposed
resourceExchangeTermsAccepted  → terms_accepted
resourceExchangeTermsRejected  → terms_rejected
resourceExchangeTermsWithdrawn → terms_withdrawn
resourceExchangeCancelled      → agreement_cancelled
resourceExchangeCompleted      → agreement_completed
```

Milestone notification accepts only the four milestone event kinds.

Malformed known Resource rows fail safely.

---

# 13. Unknown compatibility

Unknown future category/kind may still render generic notification copy where safe.

But malformed **known** Resource rows must not silently downgrade to generic copy.

---

# 14. Request copy

Add localized copy.

Conceptually:

```text
Anna is interested in “Power drill”.
Anna withdrew their request for “Power drill”.
Your request for “Power drill” was accepted.
Your request for “Power drill” was declined.
“Power drill” was closed before your request was accepted.
```

Acceptance must not imply reservation/handoff/completion.

---

# 15. Resource chat copy

For:

```text
resourceChatMessageReceived
```

use:

```text
Anna sent a message about “Power drill”.
```

Never include body preview.

Provide localized actor/title fallbacks.

---

# 16. Terms transition copy

Conceptually:

```text
Anna proposed exchange terms for “Power drill”.
Anna accepted the exchange terms for “Power drill”.
Anna rejected the proposed terms for “Power drill”.
Anna withdrew their terms proposal for “Power drill”.
```

No private terms content.

---

# 17. Milestone-copy principle

Milestone rows are user-recorded statements, not independent PLANETS verification.

Use:

```text
Anna marked...
Anna confirmed...
```

Avoid:

```text
PLANETS verified...
Anna proved...
```

---

# 18. Owner-resource milestone copy

For `owner_resource`, the listed Resource is the leg.

Map:

```text
resource_provided
→ actor marked “Power drill” as handed over

resource_received
→ actor confirmed receiving “Power drill”

resource_returned
→ actor marked “Power drill” as returned

resource_return_received
→ actor confirmed “Power drill” was returned
```

---

# 19. Requester-resource milestone copy

The safe notification projection does not expose the private requester-resource description.

Therefore use generic leg wording:

```text
Anna marked their exchange item as handed over.
Marco confirmed receiving the other exchange item.
Anna marked their exchange item as returned.
Marco confirmed the other exchange item was returned.
```

Do not fetch agreement terms per notification.

No N+1 private reads.

---

# 20. Cancelled/completed copy

Cancelled:

```text
Anna cancelled the coordination for “Power drill”.
```

or safe generic actor fallback.

Completed:

```text
The exchange for “Power drill” was completed.
```

Keep cancellation/completion distinct.

No fault/reputation language.

---

# 21. Resource request destination

For:

```text
destination = resourceRequest
```

route to:

```text
resourceRequestMessageRoute(resourceRequestId)
```

Existing route:

```text
/messages/requests/resource/:requestId
```

Do not route only to public listing.

---

# 22. Resource chat destination

For:

```text
resourceRequestAccepted
resourceChatMessageReceived
all resourceExchange*
```

route to:

```text
resourceChatRoute(resourceChatId)
```

Existing route:

```text
/messages/chats/resource/:chatId
```

The destination already contains agreement/handoff/timeline UX.

No deep-anchor implementation in this slice.

---

# 23. Destination safety

Known rows with missing required IDs should fail strict parsing.

Destination resolver remains defensive for unknown notifications and returns null where no valid route exists.

Never build malformed routes from null IDs.

---

# 24. Tap/read behavior

Preserve:

```text
tap
→ mark read
→ update unread count/state
→ navigate
```

If mark-read fails but route is valid, preserve existing navigation behavior.

Notifications are alerts, not domain-action buttons.

---

# 25. Resources preference category

Extend preference state to include:

```text
participation
chat
resources
```

Require exactly one configurable Resources preference from canonical backend rows.

Missing/duplicate/non-configurable known categories fail safely.

---

# 26. Resources in-app toggle

Add a third preference section:

```text
Resource activity

[ In-app notifications ]

Requests, Resource conversations, and exchange updates.
```

Use canonical setter:

```text
category_slug = resources
```

When changing in-app:

```text
preserve previous canonical pushEnabled
```

---

# 27. No push toggle in C3D

Do not add a Resource-only push toggle.

Current mobile preference UI does not expose push toggles for Participation/Project chat either, and provider delivery UX is a separate concern.

C3D should:

```text
show Resources in-app toggle
preserve push_enabled unchanged
```

Document the boundary.

---

# 28. Preference controller refactor

Prefer a generic known-category preference structure rather than copy/pasting a third independent mutation flow.

For example:

```text
Map<NotificationCategory, NotificationPreference>
```

or equivalent.

Preserve readable accessors/tests if useful.

Unknown categories must not become configurable automatically.

---

# 29. Preference optimistic update/rollback

Preserve current behavior:

```text
optimistic in-app toggle
→ backend setter
→ canonical preferences reload
→ safe rollback/reload on failure
```

Changing Resources must not mutate Participation or Chat.

Account switch invalidates in-flight operations.

---

# 30. Existing Project regressions

Do not regress:

- Participation notification parsing/copy/routes;
- participant left/removed;
- Project chat message notifications;
- unread count;
- mark one/all read;
- pagination;
- existing preference toggles.

---

# 31. Privacy

Notification UX must not fetch/display:

- request message;
- Resource chat body;
- private note;
- requester resource description;
- lend dates;
- exact handoff location;
- phone/email.

Use the safe inbox projection only.

---

# 32. Notification-list presentation

Keep Resource alerts in the existing chronological Notifications screen.

No separate Resource inbox.

Optional Resource-specific iconography is fine if consistent with existing UI.

Do not rely on color alone.

---

# 33. Accessibility

Cover:
- notification semantic labels;
- Resource title and event meaning;
- read/unread state;
- Resources preference heading/toggle;
- error live regions;
- long titles/actor names;
- high text scaling.

Never expose raw IDs to semantics.

---

# 34. Localization

Add production strings for all Resource notification kinds/fallbacks.

Preserve distinctions:

```text
request accepted ≠ handed over
terms accepted ≠ completed
milestone statement ≠ independent verification
cancelled ≠ completed
```

No hard-coded production English outside ARB.

---

# 35. Tests — enums/wire parsing

Cover:
- `resources`;
- all 13 Resource notification kinds;
- `resource_request`;
- `resource_chat`;
- event/leg parsing;
- unknown fallback.

---

# 36. Tests — Resource fields

Cover:
- all Resource UUID fields;
- listing title;
- event kind;
- leg kind;
- malformed UUID;
- illegal mixed Project+Resource context.

---

# 37. Tests — exact shape matrix

Cover each Resource notification kind with valid and invalid rows.

Known malformed Resource notifications should throw `FormatException`.

---

# 38. Tests — event consistency

Examples:

```text
terms-proposed notification + terms_accepted event → invalid
milestone + null leg → invalid
milestone + terms_proposed event → invalid
completed + agreement_completed → valid
```

---

# 39. Tests — copy

Cover actor/title-present and fallback paths.

Milestone copy covers:

```text
4 milestone event kinds × 2 leg kinds
```

Requester-resource copy must never invent private item names.

---

# 40. Tests — destinations

Cover:

```text
Resource request kinds
→ /messages/requests/resource/:requestId

accepted/chat/exchange kinds
→ /messages/chats/resource/:chatId
```

Existing Project destinations remain unchanged.

---

# 41. Tests — tap flow

Resource unread notification:

```text
prepareTap
→ mark read
→ unread decrement
→ correct route
```

Preserve navigation on read failure according to current behavior.

---

# 42. Tests — preference parsing/state

Canonical list contains:

```text
participation
chat
resources
```

Cover:
- exactly one of each;
- missing Resources;
- duplicate Resources;
- non-configurable Resources;
- unknown extra category;
- account switch.

Unknown extra categories should not break known-category state unless repository conventions explicitly require otherwise.

---

# 43. Tests — Resources mutation

Verify:

```text
resources in-app true → false
resources in-app false → true
```

RPC receives:

```text
category_slug = resources
in_app_enabled = chosen value
push_enabled = previous canonical value
```

Other categories unchanged.

---

# 44. Tests — preference UI

Verify three sections:

```text
Participation
Chat messages
Resource activity
```

Resource toggle:
- canonical initial value;
- disabled during save;
- rollback/error;
- high-text-scale accessibility.

No push toggle.

---

# 45. Documentation / roadmap

Mark:

```text
04C4C3A — Resource requests + unified Requests
04C4C3B — Resource conversation + unified Chats
04C4C3C1 — Agreement negotiation
04C4C3C2 — Handoff/return/timeline/overdue
04C4C3D — Mobile Resources Notification UX
  this PR
```

Document that this completes the current 04C4C mobile chain.

Also document:

```text
Resources in-app preference is exposed.
Stored push preference is preserved.
Dedicated push-toggle/provider UX remains future work.
```

---

# 46. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused notification suites and formatting.

No DB migration.

The local Supabase instance may still be behind the migration stack. Do not reset or mutate the shared local DB solely for this mobile-only slice.

Attempt hosted Validation once.

If runner allocation again fails because of the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:
- SQL/projector changes;
- push provider delivery;
- notification body previews;
- mobile push toggles;
- new agreement behavior;
- post-handoff amendments;
- disputes/moderation;
- loan queue/calendar;
- Dona redesign;
- Project matching;
- saved searches;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #81;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] Resources category typed;
- [ ] all Resource notification kinds typed;
- [ ] Resource destinations typed;
- [ ] all safe Resource context parsed;
- [ ] strict per-kind shape validation;
- [ ] milestone kind/event/leg consistency enforced;
- [ ] Project/Resource field mixing rejected;
- [ ] localized request copy;
- [ ] localized Resource-chat copy;
- [ ] localized terms-transition copy;
- [ ] milestone copy is factual/non-adjudicative;
- [ ] requester-leg milestone copy never invents private item name;
- [ ] cancellation/completion distinct;
- [ ] request alerts route to Resource request detail;
- [ ] accepted/chat/exchange alerts route to Resource chat;
- [ ] mark-read/tap behavior preserved;
- [ ] Resources in-app preference exposed;
- [ ] changing Resources preserves push setting;
- [ ] no Resource-only push toggle;
- [ ] Project notification behavior preserved;
- [ ] no private notification N+1 reads;
- [ ] account-switch safety preserved;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] no PR merged.

---

# Completion report

Return:
1. Stack/base status
2. 04C4C3D branch/base/PR
3. Changed files
4. Resources category model
5. Resource notification kinds
6. Resource destination kinds
7. Resource context fields
8. Resource event/leg models
9. Request-shape validation
10. Accepted-request shape validation
11. Resource-chat shape validation
12. Exchange-shape validation
13. Kind/event consistency
14. Project/Resource XOR validation
15. Resource request copy
16. Resource-chat copy
17. Terms-transition copy
18. Milestone copy
19. Cancellation/completion copy
20. Resource-request routes
21. Resource-chat routes
22. Mark-read/tap behavior
23. Resources preference model/state
24. Resources in-app mutation
25. Push-setting preservation
26. No-push-toggle boundary
27. Preferences UI
28. Privacy guarantees
29. Account-switch safety
30. Parser/shape tests
31. Copy tests
32. Destination/tap tests
33. Preference controller/UI tests
34. Existing Project notification regression
35. Localization/accessibility
36. Local regression validation
37. Hosted Validation executed/not-executed
38. 04C4C completion / next-roadmap handoff
39. Warnings/blockers
40. Commit/PR reference

Do not merge any PR.
