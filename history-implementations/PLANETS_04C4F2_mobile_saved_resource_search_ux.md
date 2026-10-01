# PLANETS 04C4F2 — Mobile Saved Resource Search UX

**Roadmap area:** 04C4F — Saved Searches + Matching Notifications  
**Task type:** Flutter/mobile integration over 04C4F1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #89 — 04C4F1 Personal Saved Resource Search Domain
branch: codex/04c4f1-personal-saved-resource-searches
head:   e3ca1e04d1dd53bd2e2b538732cfe1bf323559c8
```

PR #89 is draft and stacked on PR #88/#87/#84/#83. Database replay/lint/advisors/pgTAP/OTP/type-drift gates remain unresolved on the current stack.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #89 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #89 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4f2-mobile-saved-resource-searches
```

Open against:

```text
codex/04c4f1-personal-saved-resource-searches
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4F2_mobile_saved_resource_search_ux.md
```

No external document is required.

---

# Objective

Expose personal saved Scambio-Dona searches in mobile while continuing to use the existing Resource Browse implementation for actual results.

Primary flows:

```text
Resource Browse
→ choose text / Dona-Scambia / locality filters
→ Save search
→ private saved-search definition created
```

and:

```text
Resource Browse
→ Saved searches
→ Open
→ apply saved filters to existing Resource Browse
→ existing list/detail/request UX continues normally
```

Management:

```text
Saved searches
→ edit filters
→ delete
```

Do not create a second saved-search results screen.

---

# 1. No database migration

This is mobile-only.

Consume F1 RPCs:

```text
create_resource_saved_search
update_resource_saved_search
delete_resource_saved_search
get_own_resource_saved_search
list_own_resource_saved_searches
```

Run search results through the existing:

```text
list_public_resource_listings
```

via the existing Resource Browse controller/gateway.

No direct table reads.

---

# 2. Feature boundary

Create a focused private mobile feature, for example:

```text
features/resource_saved_searches/
```

Suggested areas:

```text
domain/resource_saved_search_models.dart
data/resource_saved_search_gateway.dart
application/resource_saved_search_controller.dart
presentation/resource_saved_searches_screen.dart
presentation/resource_saved_search_editor.dart
presentation/resource_saved_search_routes.dart
```

Exact split is Codex's choice.

Do not move public Resource listing state into this feature.

---

# 3. Saved-search domain model

Model:

```text
ResourceSavedSearch {
  id
  query?
  listingMode?
  locality?
  createdAt
  updatedAt
}
```

Use the existing:

```text
ResourceListingMode
```

for `donate` / `exchange` rather than defining a duplicate wire enum.

`listingMode == null` means All.

---

# 4. Filter input model

Create a mutable/input value separate from canonical row:

```text
ResourceSavedSearchInput {
  query
  listingMode?
  locality
}
```

Normalize for client validation using the same visible semantics:

```text
query.trim()
locality.trim()
```

Empty strings become absent at RPC boundary.

Require at least one non-empty/selected filter.

Max lengths:

```text
query <= 120
locality <= 120
```

Backend remains authoritative.

---

# 5. Cursor/page model

Use complete F1 cursor:

```text
ResourceSavedSearchCursor {
  updatedAt
  id
}
```

Page:

```text
items
hasMore
```

Fetch `pageSize + 1`.

Do not use offset pagination.

---

# 6. Saved-search gateway

Add strict RPC-only methods equivalent to:

```text
create(...)
update(...)
delete(...)
getOwn(...)
listOwn(...)
```

Exact F1 params:

```text
p_expected_profile_id
p_saved_search_id
p_query
p_listing_mode
p_locality
p_limit
p_cursor_updated_at
p_cursor_id
```

No direct `.from('resource_saved_searches')`.

---

# 7. Strict parser

Exact row keys:

```text
saved_search_id
query
listing_mode
locality
created_at
updated_at
```

Validate:

- UUID;
- optional query 1..120 when present;
- optional locality 1..120 when present;
- optional mode is donate/exchange;
- at least one filter present;
- timestamps parse;
- `updatedAt >= createdAt`.

Malformed private payload fails safely.

---

# 8. Failure mapping

Map:

```text
22023 → invalidInput
42501 → forbidden
PT409 → duplicate/conflict
other → unavailable
```

Exact read returning zero rows should map to not-found/unavailable according to existing private-feature convention.

Never display raw backend diagnostics.

---

# 9. Controller

Identity-bound controller state conceptually:

```text
phase
expectedProfileId
items
hasMore
failure
actionTargetId?
```

Support:

```text
load
refresh
loadMore
create
update
delete
```

Account switch/sign-out clears all private state and invalidates late responses.

---

# 10. Canonical post-mutation behavior

After create/update/delete, do not fabricate long-lived canonical ordering locally.

Preferred:

```text
mutation succeeds
→ reload first page canonically
```

because update changes `updated_at` and therefore list order.

---

# 11. Duplicate PT409 UX

Create duplicate:

```text
This search is already saved.
```

Do not retry.

Update collision:

```text
Another saved search already uses these filters.
```

Keep editor input open.

Do not silently merge/delete either search.

---

# 12. Private route

Add:

```text
/resources/saved-searches
```

centralized through a route helper if repository conventions support it.

Place static route before:

```text
/resources/:listingId
```

so it cannot be interpreted as listing ID.

Classify it as authenticated Resource management/private navigation.

Signed-out access uses existing auth `returnTo`.

Profile-setup behavior should follow current Resource management conventions.

---

# 13. Saved-searches entry point

Add a clear action from Resource Browse app bar:

```text
Saved searches
```

Use bookmark/search icon.

Show it when the user has a ready authenticated identity.

Do not expose private saved-search data while signed out.

No new top-level navigation tab.

---

# 14. Save-current-search action

On Resource Browse, add:

```text
Save search
```

near the existing filter/apply area when a ready authenticated identity exists.

Do not show/enable a save operation for an all-empty filter definition.

The saved definition must correspond to the visible filter controls.

---

# 15. Save action and filter application

To avoid saving filters that differ from visible results:

When user taps `Save search`:

1. read current UI controls:
   ```text
   mode choice
   query field
   locality field
   ```
2. validate at least one active filter;
3. apply those filters through:
   ```text
   PublicResourceListingsController.applyFilters(...)
   ```
4. create the saved search with the same normalized tuple;
5. show success/duplicate/failure feedback.

It is acceptable for public search results to update even if private save returns duplicate/failure.

Do not maintain separate “saved” and “applied” tuples after this action.

---

# 16. Resource Browse external filter synchronization

This is a required correctness fix.

Current `PublicResourceListingsScreen` stores:

```text
_queryController
_localityController
_modeChoice
```

locally, while canonical applied filters also live in:

```text
publicResourceListingsProvider
```

Opening a saved search will call `applyFilters(...)` externally.

Therefore add synchronization so when the provider's canonical filter tuple changes externally:

```text
modeFilter
locality
query
```

the visible controls update to match.

Requirements:

- do not overwrite unsent local edits merely because loading phase/items change;
- only sync when canonical filter tuple itself changes;
- user pressing normal Apply still behaves as today;
- opening a saved search must never show results for one filter while text fields display another.

---

# 17. Saved-search management screen

Show private list newest-update first, following backend order.

Each card shows explicit filter definition.

Example:

```text
Search
“trapano”

Mode
Scambia

Locality
Trento

[ Open ] [ Edit ] [ Delete ]
```

If a filter is absent, either omit its row or show `All` for mode.

Do not invent a saved-search name/title field.

---

# 18. Derived card summary

A compact headline may be derived for readability, for example:

```text
“trapano” · Scambia · Trento
```

or:

```text
Scambia · Trento
```

But it is presentation only.

Do not persist or edit a name.

Full explicit filters must remain visible/accessible.

---

# 19. Open saved search

`Open` must:

1. call existing:
   ```text
   publicResourceListingsProvider.notifier.applyFilters(
     mode,
     locality,
     query
   )
   ```
2. navigate to:
   ```text
   /resources
   ```

Do not call a special saved-search result RPC.

Do not copy public listing results into saved-search controller state.

---

# 20. Browse filter synchronization after Open

After navigation to Resource Browse:

- visible text fields/mode selector must show saved filters;
- results must use same filters;
- pagination continues through ordinary public Resource browse;
- saved-search ID need not remain attached to browse state.

Once opened, the user may freely edit filters.

Changing Browse filters does **not** edit the saved search automatically.

---

# 21. Edit UX

Use a compact modal/bottom sheet/dialog consistent with existing filter/form patterns.

Editable fields:

```text
Query
Mode: All / Dona / Scambia
Locality
```

No:

```text
name
notifications
frequency
radius
Project
```

Start from canonical saved row.

---

# 22. Edit validation

Require at least one filter.

Query/locality max 120.

Mode explicit.

Disable/save validation feedback for all-empty.

After successful update:

- close editor;
- reload first page;
- updated search moves according to canonical `updated_at`.

---

# 23. Delete UX

Require confirmation:

```text
Delete saved search?
This removes the saved filters.
```

Do not mention deleting Resource listings/results.

Hard delete through F1 RPC.

After success canonical reload.

No undo requirement in F2.

---

# 24. Empty saved-search list

Use:

```text
No saved searches yet.
Set filters in Scambio-Dona and save a search to reuse it later.
```

Provide an action:

```text
Browse resources
```

→ `/resources`.

---

# 25. Pagination

List uses backend order:

```text
updated_at DESC
id DESC
```

Load more preserves current rows and deduplicates by saved-search ID.

Use backend cursor from final item.

No local resort beyond preserving canonical order.

---

# 26. Refresh

Pull-to-refresh saved searches.

Reload from first page.

No Realtime.

No polling.

---

# 27. Authentication/privacy

Saved searches are private.

On account switch:

- clear previous list;
- close/discard private editor state where possible through existing shell/router reset;
- reject late network responses.

No public/signed-out list route.

---

# 28. Public Resource Browse remains public

Do not make `/resources` authenticated just because Save/Saved Searches actions exist.

Signed-out users can continue:

```text
browse
filter
open listings
```

Private actions are simply unavailable until authenticated.

Do not regress public-first discovery.

---

# 29. Profile-photo reminder boundary

Do not add profile-photo reminders to merely saving/opening searches.

Saved search is not participation/trust-sensitive.

---

# 30. No notification UX yet

Do not display:

```text
Notify me
Alerts on/off
Daily
Immediately
Push
```

F1 has no notification fields.

F3 owns all matching notification semantics.

---

# 31. No match count

Do not add a stored/current:

```text
12 matches
```

to saved-search cards unless it comes from actually executing the public search.

F2 does not need to execute every saved search on list load.

Avoid N+1 public searches.

---

# 32. No preview listings per saved search

Do not fetch a first matching listing for each saved search.

The management list shows definitions only.

`Open` runs the search once.

---

# 33. No Project integration

Do not expose saved searches from:

```text
Project resource matcher
Project needs
Project chat Needs
```

Personal saved browse searches remain separate from 04C4E.

---

# 34. No automatic persistence of ordinary browse filters

Changing Resource Browse filters does not automatically create/update a saved search.

Only explicit:

```text
Save search
```

persists.

---

# 35. No automatic saved-search edit after Open

When a saved search is opened and the user changes Browse filters:

```text
saved search stays unchanged
```

To persist those changes, user explicitly saves a new search or returns to Saved Searches and edits one.

Do not infer intent.

---

# 36. Accessibility

Cover:

- Saved Searches app-bar action;
- Save Search action;
- search-card semantic summary;
- explicit filter labels;
- Open/Edit/Delete buttons;
- delete confirmation;
- duplicate/error live regions;
- load more;
- empty state;
- high text scaling;
- long query/locality.

Do not rely on icon/color alone.

---

# 37. Localization

Add strings equivalent to:

```text
Saved searches
Save search
Search saved.
This search is already saved.
Another saved search already uses these filters.
Unable to save this search.

Query
Mode
Locality
All
Dona
Scambia

Open search
Edit search
Delete search
Delete saved search?
This removes the saved filters.

No saved searches yet.
Set filters in Scambio-Dona and save a search to reuse it later.
Browse resources

At least one filter is required.
Unable to load saved searches.
Unable to update saved search.
Unable to delete saved search.
```

No hard-coded production copy outside ARB.

---

# 38. Tests — model/parser

Cover:

- query-only;
- mode-only;
- locality-only;
- all filters;
- normalized canonical payload;
- all-empty row rejected;
- invalid UUID;
- invalid mode;
- overlong/empty-present strings;
- invalid timestamps/order.

---

# 39. Tests — gateway

Verify exact five F1 RPC names/contracts.

Verify:

```text
mode null → p_listing_mode null
blank UI strings → null
```

List uses `limit + 1` and paired cursor.

No direct table reads.

---

# 40. Tests — controller

Cover:

- initial load;
- load more;
- refresh;
- create;
- duplicate create PT409;
- update;
- duplicate update PT409;
- delete;
- canonical first-page reload after mutation;
- account switch;
- stale response ignored;
- concurrent busy-action guard.

---

# 41. Tests — management screen

Cover:

- loading;
- empty;
- cards with every filter combination;
- derived summary;
- open;
- edit;
- delete confirmation;
- mutation progress;
- duplicate/failure feedback;
- load more;
- refresh;
- long content/high text scale.

---

# 42. Tests — Resource Browse Save action

Cover:

- signed-out public browse still works;
- authenticated browse shows Save/Saved Searches;
- all-empty filters cannot be saved;
- Save reads current visible controls;
- Save applies the exact same filters;
- successful create feedback;
- duplicate feedback;
- public results still update if save fails/duplicates.

---

# 43. Tests — external filter synchronization

Cover:

```text
Browse initially query=A
saved search Open applies query=B/locality=C/mode=exchange
→ provider state = B/C/exchange
→ visible text fields = B/C
→ selected mode = exchange
→ result RPC uses B/C/exchange
```

Also verify:

- provider phase/item-only changes do not overwrite unsent local text edits;
- normal manual Apply still updates both provider and controls coherently.

---

# 44. Tests — routes/auth

Cover:

```text
/resources/saved-searches
```

- authenticated ready → screen;
- signed out → auth with returnTo;
- profile setup follows current Resource management convention;
- route does not collide with `/resources/:listingId`.

Opening saved search returns to `/resources`.

---

# 45. Existing regression

Do not regress:

- signed-out Resource browse;
- public filters/pagination;
- My Listings;
- Resource listing detail/request;
- loan schedule;
- Project matching;
- app router;
- auth returnTo.

---

# 46. Documentation / roadmap

Update:

```text
04C4F1 — PR #89, DB gates pending
04C4F2 — Mobile Saved Resource Search UX
  this PR
04C4F3 — New-Listing Match Projection + Notifications
  next
```

Document:

```text
saved searches are personal and Project-independent
Open reuses normal Resource Browse
editing Browse after Open does not mutate saved definition
no notifications/frequency yet
```

---

# 47. F3 handoff

After F2, F3 owns:

```text
resource_listing.published
→ evaluate private saved-search predicate
→ idempotent saved-search match delivery
→ in-app notification projection
→ alert preference/frequency decision
```

F2 must not add any alert fields or UI.

---

# 48. Validation

Run:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused saved-search + Resource browse/router tests and formatting.

No DB migration is expected.

Do not mutate/reset local Supabase solely for F2.

PR #89/#87/#83 DB replay/lint/advisors/pgTAP/OTP/type-drift gates remain inherited hard blockers.

Attempt hosted Validation once.

If GitHub cannot allocate a runner because of the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- notification toggle;
- notification frequency;
- notification projection;
- push;
- saved-search result snapshots;
- per-search match counts;
- per-search listing previews;
- automatic saving;
- Project-linked searches;
- Project-need subscriptions;
- radius/taxonomy/tags;
- loan availability filters;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #89;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] strict saved-search model/parser;
- [ ] five F1 RPCs integrated;
- [ ] private identity-bound controller;
- [ ] `/resources/saved-searches` route exists;
- [ ] signed-out Resource Browse remains public;
- [ ] authenticated Browse exposes Saved Searches;
- [ ] Save Search persists current visible filter tuple;
- [ ] Save Search applies same filters to normal Browse;
- [ ] all-empty search cannot be saved;
- [ ] duplicate create/update has safe PT409 UX;
- [ ] Saved Searches screen supports list/load-more/refresh;
- [ ] Open reuses existing Resource Browse controller;
- [ ] no duplicate results screen;
- [ ] Browse visible controls synchronize after external saved-filter apply;
- [ ] unsent edits are not overwritten by unrelated provider state changes;
- [ ] edit supports only query/mode/locality;
- [ ] delete confirmation/hard delete;
- [ ] Browse changes after Open do not mutate saved definition;
- [ ] no N+1 saved-search result/count requests;
- [ ] no notification UI/fields;
- [ ] account switching clears private state;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] inherited DB blockers documented honestly;
- [ ] no F3 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4F2 branch/base/PR
3. Changed files
4. Saved-search domain model
5. Input/validation model
6. Cursor/page model
7. Saved-search gateway
8. Strict parser
9. Failure mapping
10. Saved-search controller
11. Canonical post-mutation reload
12. Duplicate PT409 UX
13. Private route/auth behavior
14. Resource Browse Saved Searches entry
15. Save-current-search action
16. Save/apply synchronization
17. External Browse-filter control synchronization
18. Saved Searches management screen
19. Saved-search card presentation
20. Open-search behavior
21. Browse state after Open
22. Edit UX
23. Edit validation
24. Delete UX
25. Empty state
26. Pagination/refresh
27. Account-switch privacy
28. Signed-out public Browse regression
29. No-notification boundary
30. No-N+1/count/preview boundary
31. No-Project coupling
32. Localization/accessibility
33. Model/parser tests
34. Gateway tests
35. Controller tests
36. Management-screen tests
37. Browse Save-action tests
38. External-filter-sync tests
39. Router/auth tests
40. Existing Resource regression
41. Local regression validation
42. Hosted Validation executed/not-executed
43. Inherited DB-gate status
44. 04C4F3 handoff
45. Warnings/blockers
46. Commit/PR reference

Do not merge any PR.

