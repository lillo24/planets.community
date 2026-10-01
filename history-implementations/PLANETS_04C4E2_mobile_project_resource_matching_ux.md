# PLANETS 04C4E2 — Mobile Project Resource Matching UX

**Roadmap area:** 04C4E — Project Resource Matching  
**Task type:** Flutter/mobile integration over 04C4E1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #87 — 04C4E1 Explainable Project Resource Matching Domain
branch: codex/04c4e1-project-resource-matching-domain
head:   6a3eda6e245382257109e3443b0171a87bde9b8b
```

PR #87 is draft and stacked on PR #84/#83. The inherited database gates are still not green on the final stack.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #87 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #87 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4e2-mobile-project-resource-matching
```

Open against:

```text
codex/04c4e1-project-resource-matching-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4E2_mobile_project_resource_matching_ux.md
```

No external document is required.

---

# Objective

Expose the creator-only 04C4E1 matcher from the existing Project Resource Needs management surface.

Primary flow:

```text
Creator manages Project resource needs
        ↓
Open need
        ↓
Find matching resources
        ↓
Explainable ranked Scambio-Dona listings
        ↓
Open existing Resource listing detail
        ↓
use normal Resource request/agreement flow if desired
```

Do not duplicate Scambio-Dona request, chat, agreement, loan schedule, or handoff UI.

---

# 1. No database migration

This is mobile-only.

Use exactly:

```text
list_project_resource_need_listing_matches
```

Do not add SQL or direct table reads.

The inherited PR #87/#83 DB gates remain hard blockers for eventual stack merge.

---

# 2. Entry point

The existing creator screen is:

```text
ProjectResourceNeedsScreen
```

For each:

```text
need.isOpen == true
```

add a creator action:

```text
Find matching resources
```

Keep existing:

```text
Edit
Close
```

Closed needs remain read-only and get no matching action.

Do not add matching controls to the public `ProjectResourceNeedsSection` in E2.

---

# 3. Matching route

Add a centralized route builder equivalent to:

```text
ProjectResourceNeedRoutes.matches(
  projectKind,
  projectId,
  resourceNeedId
)
```

Preferred route shapes:

```text
/proposals/:projectId/resources/:resourceNeedId/matches
/tavoli/:projectId/resources/:resourceNeedId/matches
```

Do not expose creator profile ID in URL.

The screen remains backend-authorized.

---

# 4. Match domain model

Create a focused typed domain under the Project resource-needs feature or a small matching subfeature.

Conceptually:

```text
ProjectResourceListingMatch {
  resourceNeedId

  listingId
  listingMode
  title
  description

  countryCode
  locality
  administrativeArea?
  publicLocationLabel

  publishedAt
  activeRequestCount

  textMatchKind
  locationMatchKind
}
```

Do not add owner/private reservation fields.

---

# 5. Text match enum

Strictly model:

```text
titlePhrase
needTitleInListingTitle
needTitleInListingDescription
needDetailsInListingTitle
needDetailsInListingDescription
```

Unknown value → parsing failure.

Do not invent a numeric score.

---

# 6. Location match enum

Strictly model:

```text
sameLocality
sameAdministrativeArea
sameCountry
otherOrUnknown
```

Unknown value → parsing failure.

---

# 7. Filter enums

Location scope:

```text
sameLocality
sameAdministrativeArea
sameCountry
anywhere
```

Wire exactly:

```text
same_locality
same_administrative_area
same_country
anywhere
```

Listing mode filter:

```text
all
donate
exchange
```

`all` sends:

```text
p_listing_mode = null
```

Do not add `lend`.

---

# 8. Default filters

Initial screen defaults:

```text
location scope = anywhere
listing mode = all
```

These choices must be visible in the UI.

Reason:

- draft Projects may not yet have locality/area/country;
- `anywhere` never silently fails because Project geography is incomplete;
- E1 ranking still puts same locality/area/country ahead of distant results.

Do not silently narrow or widen after load.

---

# 9. Match cursor

Model the complete E1 keyset:

```text
ProjectResourceMatchCursor {
  textMatchKind
  locationMatchKind
  publishedAt
  listingId
}
```

Pagination must send all four cursor values.

Never paginate by listing ID/time alone.

---

# 10. Matching gateway

Add one RPC-only method equivalent to:

```text
listMatches(
  expectedCreatorProfileId,
  resourceNeedId,
  locationScope,
  listingMode,
  limit,
  cursor
)
```

Call exactly:

```text
list_project_resource_need_listing_matches
```

Parameters must match E1:

```text
p_expected_creator_profile_id
p_resource_need_id
p_location_scope
p_limit
p_listing_mode
p_cursor_text_match_kind
p_cursor_location_match_kind
p_cursor_published_at
p_cursor_listing_id
```

Fetch `pageSize + 1`, return `hasMore`.

No direct table access.

---

# 11. Strict parser

Validate exact/public-safe row shape.

At minimum:

- all UUIDs;
- listing mode;
- non-empty title/description/location label;
- country code shape;
- optional locality/admin area shape;
- timestamp;
- non-negative `active_request_count`;
- strict text match enum;
- strict location match enum;
- exact `resource_need_id` expected by controller.

Malformed rows fail safely.

---

# 12. Controller scope

Use identity + resourceNeedId + filters bound state.

Conceptually:

```text
phase
expectedCreatorProfileId
projectId
resourceNeedId

locationScope
listingMode

items
hasMore
failure
```

Support:

```text
load
refresh
loadMore
setLocationScope
setListingMode
```

Filter change resets pagination and loads first page.

---

# 13. Identity safety

On account switch/sign-out:

- clear matches immediately;
- invalidate in-flight requests;
- discard late responses;
- never leave creator-only match data rendered for another identity.

---

# 14. Need identity safety

The route already knows the `resourceNeedId`.

Use the current own-needs state where available to show source need title/details, but the backend remains authoritative.

If the need no longer exists/is closed between screens, the match RPC may fail.

Do not continue showing stale match results as if still valid after canonical failure.

---

# 15. Matching screen header

Show the source need clearly:

```text
Matching resources

Need:
Trapano a percussione

Optional details...
```

If source need details are not locally available on deep link, it is acceptable to show a generic title until the own-needs controller loads the canonical need.

Do not add another backend matcher/detail RPC just to duplicate need fields.

---

# 16. Filter UI

Expose visible filters near the top.

## Location

Use a compact selector:

```text
Anywhere
Same country
Same area
Same locality
```

## Mode

```text
All
Dona
Scambia
```

Do not hide filters behind implicit heuristics.

---

# 17. Missing-location backend failure

Narrow location scope can legitimately fail when the Project lacks required geography.

Backend currently uses a lifecycle/state failure for this and other ineligible states.

Do not inspect or display raw SQL messages.

Use safe guidance such as:

```text
Matching isn't available with the current Project state or location filter.
Try a broader location filter or check the Project details.
```

Keep the selected filter visible.

Do not automatically switch to `anywhere`.

---

# 18. Match card

Reuse the visual language of existing public Resource listing cards where practical, but add matching reasons.

Show:

```text
listing title
Dona / Scambia badge
description preview
rough public location
active-interest count
published date if currently useful

Why it matches:
[text reason]
[location reason]
```

Do not show hidden score/percentage.

---

# 19. Text reason copy

Map stable E1 enums to localized, concise explanations.

Conceptually:

```text
titlePhrase
→ Need phrase appears in the listing title

needTitleInListingTitle
→ Need keywords match the listing title

needTitleInListingDescription
→ Need keywords match the listing description

needDetailsInListingTitle
→ Need details match the listing title

needDetailsInListingDescription
→ Need details match the listing description
```

Do not say “AI matched this”.

---

# 20. Location reason copy

Map:

```text
sameLocality
→ Same locality

sameAdministrativeArea
→ Same area

sameCountry
→ Same country

otherOrUnknown
→ Other / location not comparable
```

---

# 21. Ordering

Render backend order exactly.

Do not re-score or sort locally.

Backend already orders by:

```text
text tier
→ location tier
→ published time
→ listing ID
```

---

# 22. Open existing Resource listing

Tapping a match card routes to existing:

```text
/resources/:listingId
```

From there use the normal Resource request flow if appropriate.

Do not create a special “request from Project” mutation in E2.

Do not auto-link a resulting Resource request to the Project need.

---

# 23. Own listing match

E1 may return a listing owned by the Project creator.

Do not silently filter it client-side.

The existing Resource detail already prevents self-request.

Preserve backend truth.

---

# 24. Availability wording

Do not label a match:

```text
Available to borrow
Free on Project date
Available now
```

E1 intentionally ignores private loan reservations.

Use neutral discovery wording only.

Concrete LEND-period availability remains D1/D2 behavior during agreement negotiation.

---

# 25. Active-interest count

Show the existing public-safe count using existing Resource discovery copy/components where practical.

It means interest/current coordination, not reservation count or queue position.

Do not call it:

```text
people ahead of you
queue length
reservations
```

---

# 26. Empty state

For zero matches under current filters:

```text
No matching resources found.
Try a broader location or include both Dona and Scambia.
```

If already `anywhere + all`:

```text
No matching published resources found yet.
```

---

# 27. Pagination

Preserve current items while loading more.

Deduplicate by `listingId`.

Use the final accepted item as the complete four-part cursor.

Do not recompute cursor ranks in Flutter.

---

# 28. Pull-to-refresh

Support refresh using the same selected filters.

Matches are read-time derived, so listing content/lifecycle/count changes should appear on refresh.

---

# 29. No Realtime/polling

Do not add Realtime, background polling, or timer refresh.

Matching is user-invoked derived search.

---

# 30. Error mapping

Map safely:

```text
22023 → invalid filter/input
42501 → forbidden/identity changed
55000 → Project/need/location state unavailable
P0002 → need not found
other → unavailable
```

No raw backend diagnostics.

---

# 31. Creator-only boundary

Do not add matching actions to:

```text
public Proposal detail
public Tavolo detail
participant Needs drawer
```

E2 attaches matching only to creator `ProjectResourceNeedsScreen`.

---

# 32. No Project-need mutation from matches

A match must not automatically:

```text
close the need
mark it covered
claim the need
create a contribution commitment
```

Project-need state is unchanged.

---

# 33. No Resource-request metadata coupling

When the user opens a match and sends a Resource request, do not inject Project/resource-need IDs into request text or schema.

No 04C4 request-domain changes.

---

# 34. No saved search yet

Do not add:

```text
Save this search
Notify me
Follow this need
```

Those belong to 04C4F.

---

# 35. Accessibility

Cover:

- source need heading;
- filter groups/selected states;
- match reason semantics;
- location reason;
- mode badge;
- interest count;
- card action;
- load-more state;
- empty/error state;
- high text scaling;
- long titles/descriptions.

No color-only match strength.

---

# 36. Localization

Add production strings equivalent to:

```text
Find matching resources
Matching resources
Why it matches

Anywhere
Same country
Same area
Same locality

All
Dona
Scambia

Need phrase appears in the listing title
Need keywords match the listing title
Need keywords match the listing description
Need details match the listing title
Need details match the listing description

Same locality
Same area
Same country
Other / location not comparable

No matching resources found.
Try a broader location or include both Dona and Scambia.
No matching published resources found yet.

Matching isn't available with the current Project state or location filter.
Try a broader location filter or check the Project details.

Unable to load matching resources.
Load more
```

No hard-coded production English outside ARB.

---

# 37. Tests — parser

Cover:

- all five text kinds;
- all four location kinds;
- donate/exchange;
- optional geography;
- active-request count;
- malformed UUID;
- negative count;
- invalid enums;
- mismatched `resource_need_id`.

---

# 38. Tests — gateway

Verify exact RPC and parameters, null mode behavior, and complete four-part cursor.

No direct table reads.

---

# 39. Tests — controller

Cover:

- initial `anywhere + all`;
- load;
- refresh;
- load more;
- filter reset;
- dedupe;
- backend order preservation;
- failure behavior;
- account switch;
- stale late response.

---

# 40. Tests — creator needs integration

Open need shows `Find matching resources`.

Closed need does not.

Existing Edit/Close behavior remains.

Proposal and Tavolo routes use correct kind.

---

# 41. Tests — matching screen

Cover:

- source need context;
- visible default filters;
- filter changes;
- listing cards;
- all text/location reason labels;
- interest count;
- filtered empty state;
- broad empty state;
- error/retry;
- load more;
- pull refresh;
- long text/high scaling.

---

# 42. Tests — routing

Cover:

```text
/proposals/:projectId/resources/:needId/matches
/tavoli/:projectId/resources/:needId/matches
```

and:

```text
match card → /resources/:listingId
```

Preserve existing Resource-need management routes.

---

# 43. Tests — privacy/product boundaries

Assert UI never shows:

```text
reservation dates
borrower identities
overdue/at-risk loan state
match confidence percentage
AI score
queue position
```

Assert card tap does not auto-create Resource request.

Assert match selection does not close/cover Project need.

---

# 44. Existing regression

Do not regress:

- Project Resource Need create/edit/close;
- public needs display;
- Project Needs drawer;
- contribution selection;
- Resource listing browse/detail/request;
- loan schedule;
- Messages;
- agreement/handoff.

---

# 45. Documentation / roadmap

Update:

```text
04C4E1 — PR #87, backend matcher, DB final gates pending
04C4E2 — Mobile Project Resource Matching UX
  this PR
```

Document first-version limitations:

```text
creator-only
lexical/explainable
no score
no synonyms/taxonomy
no private availability inference
no saved search
no direct Project↔Resource-request relation
```

After E2, 04C4E is functionally complete in the open stack.

---

# 46. 04C4F handoff

Next roadmap item:

```text
04C4F — Saved Searches + Matching Notifications
```

Potential future entry points:

- save personal Resource discovery query;
- optionally follow a Project resource need's matching query;
- notify on newly published compatible listings.

Do not implement this in E2.

---

# 47. Validation

Run:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused matching/resource-needs/router tests and formatting.

No DB migration is expected.

Do not reset/delete Docker data or mutate the shared local Supabase solely for E2.

PR #87/#83 database replay/lint/advisors/pgTAP/OTP/type-drift checks remain inherited hard blockers for eventual stack merge.

Attempt hosted Validation once.

If runner allocation fails due the known GitHub billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- public/participant matching;
- match score/percentage;
- AI/embedding/vector matching;
- synonym dictionary;
- global taxonomy;
- distance/geocoding;
- private loan availability display;
- saved searches;
- matching notifications;
- push;
- Project need auto-close/coverage;
- direct Project-need↔Resource-request relation;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #87;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] creator open needs expose Find matching resources;
- [ ] closed needs do not;
- [ ] Proposal/Tavolo matching routes exist;
- [ ] strict match models/enums exist;
- [ ] exact E1 RPC gateway exists;
- [ ] complete four-part cursor;
- [ ] default filters visibly `anywhere + all`;
- [ ] filter changes reset pagination;
- [ ] no silent geography widening;
- [ ] match cards show localized text/location reasons;
- [ ] no numeric score/confidence;
- [ ] backend ordering preserved;
- [ ] active-interest count retains correct meaning;
- [ ] card opens existing Resource detail;
- [ ] no special request mutation created;
- [ ] no Project need mutation from match selection;
- [ ] no private reservation information displayed;
- [ ] no availability guarantee copy;
- [ ] no Realtime/polling;
- [ ] account switching clears creator-private state;
- [ ] accessibility/localization complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] inherited DB blocker documented honestly;
- [ ] no 04C4F scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4E2 branch/base/PR
3. Changed files
4. Match domain model
5. Text-match enum
6. Location-match enum
7. Filter models
8. Match cursor
9. Matching gateway
10. Strict parser
11. Matching controller
12. Identity/account-switch safety
13. Creator Resource-needs entry point
14. Proposal/Tavolo matching routes
15. Matching screen
16. Default filter behavior
17. Geography filter UX
18. Dona/Scambia filter UX
19. Missing-location/state failure UX
20. Match-card presentation
21. Text-match reason copy
22. Location-reason copy
23. Backend-order preservation
24. Active-interest count presentation
25. Resource-detail navigation
26. Own-listing behavior
27. Availability/privacy boundary
28. Empty states
29. Pagination/deduplication
30. Pull-to-refresh
31. No-Realtime boundary
32. Error mapping
33. Project-need non-mutation guarantee
34. Resource-request non-coupling guarantee
35. Localization/accessibility
36. Parser/gateway tests
37. Controller tests
38. Resource-needs integration tests
39. Matching-screen/router tests
40. Privacy/product-boundary tests
41. Existing regression
42. Local regression validation
43. Hosted Validation executed/not-executed
44. Inherited E1/D1 DB-gate status
45. 04C4F handoff
46. Warnings/blockers
47. Commit/PR reference

Do not merge any PR.
