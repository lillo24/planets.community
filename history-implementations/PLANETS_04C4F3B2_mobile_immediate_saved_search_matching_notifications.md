# PLANETS 04C4F3B2 — Mobile Immediate Saved-Search Matching Notifications

**Roadmap area:** 04C4F3 — Saved-Search Matching Notifications  
**Task type:** Flutter/mobile notification UX over 04C4F3B1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #92 — 04C4F3B1 Immediate Saved-Search Match Notification Projection
branch: codex/04c4f3b1-immediate-match-notifications
head:   78daffd8311659bb289f900594eb042802704fc2
```

PR #92 is draft and stacked on PR #91/#90/#89/#88/#87/#84/#83. Do not merge any dependency.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #92 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from PR #92 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4f3b2-mobile-matching-notifications
```

Open against:

```text
codex/04c4f3b1-immediate-match-notifications
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4F3B2_mobile_immediate_saved_search_matching_notifications.md
```

No external document is required.

---

# Product policy now fixed

Saved-search matching notifications use the MVP policy:

```text
new matching listing
→ immediate notification eligibility
→ one user-visible alert per recipient/listing
```

No digest.

No frequency selector.

No per-saved-search alert toggle.

The global existing:

```text
Matching
```

notification category controls delivery.

B1 already implements backend in-app/push eligibility and deduplication.

B2 only makes that semantic notification first-class in Flutter.

---

# Objective

Complete the mobile experience for:

```text
resource_saved_search.matched
        ↓
B1:
matching / matching_available / matching_result
        ↓
Notifications inbox
        ↓
“New listing matches one of your saved searches: Power drill”
        ↓
tap
        ↓
existing /resources/:listingId detail
```

Also expose the existing global `matching` in-app preference in Notification Settings.

---

# 1. No database migration

This is mobile-only.

Do not modify:

```text
Supabase migrations
notification constraints
matching projection
push jobs
saved-search schema
```

Consume the exact B1 inbox/preference contracts.

---

# 2. Exact B1 notification contract

Known saved-search matching row:

```text
category_slug     = matching
notification_kind = matching_available
destination_kind  = matching_result

resource_listing_id != null
resource_listing_title = safe current display enrichment

actor_profile_id = null
actor_display_name = null

project_id = null
project_kind = null
project_title = null
request_id = null
chat_id = null
message_id = null

resource_request_id = null
resource_chat_id = null
resource_chat_message_id = null
resource_agreement_id = null
resource_agreement_event_id = null
resource_exchange_event_kind = null
resource_exchange_leg_kind = null
```

Do not expect saved-search ID/filter text in the inbox.

---

# 3. Notification category

Extend:

```dart
NotificationCategory
```

with:

```text
matching
```

Wire:

```text
matching
```

`preferenceWireSlug` must return:

```text
matching
```

Unknown future categories remain `unknown`.

---

# 4. Notification kind

Extend:

```dart
NotificationKind
```

with:

```text
matchingAvailable
```

Wire:

```text
matching_available
```

Do not classify this as `isResource`.

It is a Matching-category notification that happens to target a Resource listing.

---

# 5. Destination kind

Extend:

```dart
NotificationDestinationKind
```

with:

```text
matchingResult
```

Wire:

```text
matching_result
```

---

# 6. Strict parser validation

Add a dedicated known-Matching shape to:

```text
NotificationsPayloadParser._validateKnownNotification
```

or the current equivalent.

A valid known Matching notification requires:

```text
category = matching
kind = matchingAvailable
destination = matchingResult
resourceListingId != null
```

and every unrelated Project/request/chat/agreement/actor field null.

`resourceListingTitle` is safe display enrichment and may use a localized fallback if unexpectedly absent.

Do not silently treat a malformed known Matching row as generic.

---

# 7. Known-category cross-shape rejection

Reject examples such as:

```text
category=matching + resourceRequestReceived
category=resources + matchingAvailable
matchingAvailable + resourceChat
matchingAvailable + actorProfileId
matchingAvailable + projectId
matchingAvailable + resourceRequestId
matchingAvailable without resourceListingId
```

Unknown kinds/categories may retain the existing forward-compatible generic behavior where already intended.

---

# 8. No saved-search data in model

Do not add to `AppNotification`:

```text
savedSearchId
savedSearchMatchId
savedSearchQuery
savedSearchLocality
```

B1 intentionally excludes these.

The notification represents:

```text
a newly published Resource listing matched at least one saved search
```

not which search matched.

---

# 9. Notification copy

Add localized copy:

```text
New listing matches one of your saved searches: “{listingTitle}”.
```

Use concise equivalent punctuation consistent with existing app localization style.

Safe fallback:

```text
A new Resource listing matches one of your saved searches.
```

Do not expose:

```text
query
locality
number of matching searches
owner identity
loan availability
```

---

# 10. Do not imply availability

Avoid:

```text
Available now
Available to borrow
Reserved for you
Perfect match
```

A matching notification means only:

```text
new published listing matches saved Browse filters
```

The listing may later be closed, edited, requested by others, or negotiated as Give/Lend.

---

# 11. Notification destination

For:

```text
category = matching
kind = matchingAvailable
destination = matchingResult
```

with `resourceListingId`:

```text
tap → /resources/:listingId
```

Reuse the exact existing public Resource-detail route.

A tiny centralized Resource-detail route helper may be introduced if that reduces duplicate literal route construction, but do not reorganize unrelated routing.

---

# 12. Later-closed listing behavior

B1 guarantees the listing was still published when the notification was created.

It may close later.

Inbox history remains.

Tap should still use the ordinary Resource detail route and let the existing detail behavior safely show unavailable/not-found state.

Do not special-case a second listing-status preflight from Notifications.

---

# 13. Tap/read behavior

Preserve current flow:

```text
tap
→ attempt mark read
→ navigate if destination exists
```

If marking read fails:

```text
show safe failure
still navigate
```

Matching alerts must behave identically to existing actionable notifications.

---

# 14. Notification inbox list

Do not create a separate matching-alert inbox.

Matching notifications appear in the existing chronological Notifications screen.

No grouping/digest UI.

No saved-search-match count.

---

# 15. Notification icon

The existing generic notification icon is acceptable.

Do not expand scope into category-specific icon redesign unless the current notification card already has a centralized trivial category-icon mapping that must be extended for exhaustiveness.

No visual redesign required.

---

# 16. Matching preference model

`NotificationPreferencesState` must expose:

```text
matching
```

analogous to:

```text
participation
chat
resources
```

The known-category validation must now require exactly one user-configurable preference row for all four:

```text
participation
chat
resources
matching
```

---

# 17. Matching in-app setter

Add:

```text
setMatchingInApp(...)
```

using the existing generic `_setInApp(...)` path.

When mutating Matching:

```text
inAppEnabled = chosen value
pushEnabled = previously loaded canonical pushEnabled
```

Do not change push setting.

---

# 18. No push toggle UI

Current Notification Settings exposes only in-app toggles for Participation, Chat, and Resources.

Preserve that policy.

For Matching:

```text
show in-app toggle only
```

Do not add:

```text
Push toggle
Immediate/digest selector
Permission prompt
FCM setup
```

06C2B remains provider/mobile-push setup work.

---

# 19. Matching preference UI

Add a fourth section to:

```text
NotificationPreferencesScreen
```

after an appropriate divider.

Suggested heading:

```text
Saved search matches
```

Toggle title:

```text
In-app
```

Explanation:

```text
Show an alert when a newly published Scambio-Dona listing matches one of your saved searches.
```

Do not imply email.

Do not mention digest because policy is immediate-only.

---

# 20. Global preference semantics

Make it clear through copy/structure that the toggle applies globally to saved-search matching alerts.

Do not place a toggle on individual saved-search cards in B2.

All saved searches remain eligible; global Matching preference decides whether in-app notification rows are projected.

---

# 21. Existing push preference preservation

The backend Matching category already has:

```text
push_enabled
```

and B1 uses it independently.

B2 must not overwrite it when toggling in-app.

Tests must explicitly cover both:

```text
pushEnabled = true
pushEnabled = false
```

being preserved.

---

# 22. Initial preference loading

Update initial-loading/failed-loading conditions so screen requires:

```text
participation
chat
resources
matching
```

before treating the known preferences as complete.

Do not render `matching!` from a missing row.

---

# 23. Preference ordering

Use backend `sort_order` only as the canonical row property; the current screen manually groups known categories.

For this scoped UI, adding Matching as the fourth explicit section is acceptable.

Do not redesign the entire preferences screen dynamically unless needed for clean code.

---

# 24. Account-switch safety

Existing notification controllers already clear private state on identity change.

Ensure Matching additions participate in the same map and cannot leave previous-account preference or inbox data visible.

No separate Matching controller.

---

# 25. Unknown-category behavior

Adding Matching as known must not regress forward-compatible handling of truly unknown notification rows.

Known Matching malformed shape:

```text
reject
```

Truly unknown future category/kind:

```text
retain existing generic behavior
```

where the parser currently permits it.

---

# 26. Existing Resources behavior

Do not fold Matching into:

```text
NotificationCategory.resources
```

Do not route matching through Resource-request/chat copy.

Matching remains independent:

```text
category = matching
destination = matching_result
```

even though its destination is a Resource listing.

---

# 27. Copy/title fallback

Primary:

```text
New listing matches one of your saved searches: “Power drill”.
```

Fallback if title enrichment is absent:

```text
A new Resource listing matches one of your saved searches.
```

Do not use awkward “unknown resource” phrasing.

---

# 28. Accessibility

The existing notification card semantics already include:

```text
notification copy + read/unread state
```

Matching notifications should use the same path.

Long listing titles must wrap and remain usable at high text scale.

No color-only semantics.

---

# 29. Localization

Add production strings equivalent to:

```text
Saved search matches

Show an alert when a newly published Scambio-Dona listing matches one of your saved searches.

New listing matches one of your saved searches: “{listing}”.
A new Resource listing matches one of your saved searches.
```

No hard-coded production copy outside ARB.

---

# 30. Parser tests — valid Matching

Add focused test with exact B1 row:

```text
category_slug = matching
notification_kind = matching_available
destination_kind = matching_result
resource_listing_id = UUID
resource_listing_title = title
all unrelated refs null
```

Assert strict typed result.

---

# 31. Parser tests — malformed known Matching

Cover at least:

```text
missing listing ID
wrong destination
wrong category
unexpected actor ID
unexpected project ID
unexpected request ID
unexpected Resource request/chat/agreement ID
unexpected exchange event/leg
```

Known malformed rows must fail using the established parser behavior.

---

# 32. Parser test — title fallback

If `resource_listing_title = null` while structural Matching references remain valid:

- parsing may remain valid as safe display enrichment is optional;
- copy must use the generic saved-search-match fallback.

Do not weaken required `resourceListingId`.

---

# 33. Category/preference parser tests

Cover:

```text
category_slug = matching
```

for:

```text
NotificationCategory.matching
preferenceWireSlug == matching
```

Preference row remains strict across:

```text
sortOrder
inAppEnabled
pushEnabled
hasOverride
userConfigurable
```

---

# 34. Copy tests

Cover:

```text
matchingAvailable + title
→ specific copy

matchingAvailable + no title
→ generic copy
```

Assert no filter/search/private data appears.

---

# 35. Destination tests

Cover:

```text
matchingAvailable + matchingResult + listing ID
→ /resources/:listingId
```

Reject route for wrong destination, missing listing ID, or wrong Matching kind.

---

# 36. Tap/read flow tests

Matching notification:

```text
unread + tap
→ mark read
→ navigate listing
```

and:

```text
mark-read failure
→ safe feedback
→ still navigate
```

Preserve unread-count behavior.

---

# 37. Preferences controller tests

Update known-preference fixtures to include Matching.

Cover:

- load all four categories;
- missing Matching row → failure;
- duplicate Matching row → failure;
- `setMatchingInApp(true/false)`;
- canonical reload;
- rollback on failure;
- push=true preserved;
- push=false preserved;
- account switch invalidates late operation.

---

# 38. Preferences screen tests

Cover:

```text
Saved search matches
matching-in-app-toggle
explanation copy
```

Toggle calls Matching category only.

Existing Participation/Chat/Resources sections remain unchanged.

High text scaling and long explanation must remain usable.

---

# 39. Notifications flow regression

Inbox containing mixed:

```text
Participation
Chat
Resources
Matching
```

must load/render/paginate without category interference.

Matching notification remains independently markable/readable.

---

# 40. No saved-search N+1 reads

Rendering Matching notifications uses only:

```text
list_own_notifications
```

data.

Do not fetch saved search, match fact, or listing detail merely to build inbox copy.

Listing detail is fetched only after navigation.

---

# 41. No per-search preference lookup

Do not read F1 saved-search rows from Notification Settings.

Global Matching category preference is sufficient.

---

# 42. Saved-search management regression

F2 Saved Searches screen remains unchanged.

Do not add bell icons, per-search alert toggles, or frequency selectors.

---

# 43. Immediate policy documentation

Mobile docs should state:

```text
saved-search match notifications are immediate/non-digest
one backend notification per new matching listing
multiple saved searches may underlie one alert
global Matching category controls in-app eligibility
```

Do not claim provider push is operational until 06C2B exists.

---

# 44. Push wording boundary

Because B1 creates provider-neutral push jobs but provider integration is not complete, avoid user-visible settings copy such as:

```text
Push notifications are enabled
You will receive phone alerts
```

B2 exposes only the in-app Matching toggle.

---

# 45. Documentation / roadmap

Update:

```text
04C4F3A — PR #91
04C4F3B1 — PR #92
04C4F3B2 — Mobile Immediate Saved-Search Matching Notifications
  this PR
```

After B2:

```text
04C4F is functionally complete in the open stack.
04C4 Scambio-Dona functional chain is complete in the open stack.
```

Do not mark merged/validated while the PR stack and inherited gates remain open.

---

# 46. Validation

Run:

```text
flutter gen-l10n
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused notification parser/copy/destination/preferences/flow tests.

No DB reset is required for this mobile-only slice.

Do not claim inherited DB gates are fixed.

Attempt hosted Validation once.

If GitHub cannot allocate a runner due the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- notification projection changes;
- digest/frequency settings;
- per-saved-search alert toggle;
- push toggle UI;
- Firebase/APNs provider integration;
- push permission UI;
- OS notification preview policy;
- saved-search match-history screen;
- Project matching alerts;
- loan-availability alerts;
- taxonomy/radius;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #92;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] `matching` is a first-class NotificationCategory;
- [ ] `matching_available` is typed;
- [ ] `matching_result` is typed;
- [ ] Matching known shape is strict;
- [ ] malformed known Matching rows are rejected;
- [ ] no saved-search IDs/filter data added to AppNotification;
- [ ] localized specific matching copy;
- [ ] safe generic title fallback;
- [ ] copy does not imply physical availability;
- [ ] tap routes to existing Resource listing detail;
- [ ] mark-read failure still navigates;
- [ ] matching notifications remain in existing inbox;
- [ ] preferences require all four known categories;
- [ ] `setMatchingInApp` exists;
- [ ] Matching in-app toggle is visible;
- [ ] toggle preserves canonical pushEnabled;
- [ ] no push toggle/frequency UI;
- [ ] no per-search toggle;
- [ ] no N+1 saved-search/listing reads for inbox rendering;
- [ ] account-switch safety preserved;
- [ ] localization/accessibility complete;
- [ ] focused parser/copy/destination/preferences tests pass;
- [ ] full mobile regression passes;
- [ ] debug APK passes;
- [ ] inherited DB/hosted blockers reported honestly;
- [ ] 04C4F/04C4 marked functionally complete only in open-stack terms;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4F3B2 branch/base/PR
3. Changed files
4. Matching category model
5. Matching notification kind
6. Matching destination kind
7. Strict Matching parser shape
8. Cross-shape rejection
9. No-saved-search-data boundary
10. Matching notification copy
11. Generic copy fallback
12. Availability wording boundary
13. Destination route
14. Tap/read behavior
15. Existing inbox integration
16. Matching preference state
17. Matching in-app setter
18. Push-value preservation
19. No-push-toggle boundary
20. Preferences UI section
21. Global-vs-per-search semantics
22. Known-preference completeness
23. Account-switch safety
24. Unknown-category compatibility
25. Resources-category regression
26. Accessibility/localization
27. Matching parser tests
28. Preference parser/category tests
29. Copy tests
30. Destination tests
31. Tap/read flow tests
32. Preferences controller tests
33. Preferences screen tests
34. Mixed-inbox regression
35. No-N+1 behavior
36. Saved-search management regression
37. Immediate-policy documentation
38. Provider-push wording boundary
39. Local regression validation
40. Hosted Validation executed/not-executed
41. Inherited DB-gate status
42. 04C4F completion status
43. 04C4 completion status
44. Warnings/blockers
45. Commit/PR reference

Do not merge any PR.

