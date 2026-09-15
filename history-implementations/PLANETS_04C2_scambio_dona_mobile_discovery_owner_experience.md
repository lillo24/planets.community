# PLANETS 04C2 — Scambio-Dona Mobile Discovery and Owner Experience

**Roadmap area:** PLANETS 04C — Resources + Scambio-Dona  
**Task type:** Flutter mobile client over merged 04C1 contracts  
**Repository:** `lillo24/planets.community`  
**Required base:** latest `origin/main`  
**Known merged 04C1 commit when this prompt was written:** `2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42` (PR #32)

## Objective

Implement the first complete **mobile Scambio-Dona experience** over the 04C1 listing domain.

04C1 already provides the canonical backend:

- standalone `resource_listings`;
- `donate` / `exchange` discovery intents;
- `draft → published → closed`;
- owner create/update/publish/close RPCs;
- owner list/detail RPCs;
- anonymous/authenticated public discovery/detail;
- mode/locality/keyword filters;
- newest-first paired keyset pagination;
- rough public location only;
- public owner display name only when profile visibility allows it;
- no requests, claims, reservations, handoff, loan, barter, payment, return, quantity, taxonomy, media, Project linkage, saved-search, matching, or notification semantics.

04C2 must make that domain usable in Flutter **without inventing any of those deferred concepts**.

After this task, a user should be able to:

```text
Home
  ├── Progetti
  └── Scambio-Dona
        ↓
      public listings
        ├── filter All / Dona / Scambia
        ├── search text
        ├── filter locality
        ├── open published listing
        ├── My listings
        └── Create listing
```

Owner flow:

```text
Create/Edit
  → Save draft
  → Publish
  → later edit while published
  → Close when no longer available
```

Do not implement the next-person interaction flow yet.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C2_scambio_dona_mobile_discovery_owner_experience.md
```

Preferred branch:

```text
codex/04c2-scambio-dona-mobile
```

---

# 0. Base and concurrent-work safety

Start from the **current remote `origin/main`**, not a stale local `main`.

Known 04C1 merge:

```text
PR #32
2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42
```

Other repository work may advance `main` concurrently.

Before coding:

1. fetch remote;
2. inspect current `origin/main`;
3. branch/worktree from current remote main;
4. preserve all work already merged after 04C1;
5. do not reset/clean unrelated founder worktrees.

If `main` advanced, that is normal. Reconcile documentation/routes/scripts semantically rather than reverting later work.

---

# 1. Current information architecture

The current mobile shell has exactly three persistent bottom destinations:

```text
Profile / Browse / Home
```

Keep them unchanged.

Current Browse is the Projects/Tavoli discovery branch.

Do **not** add Scambio-Dona as a third item inside the existing Projects/Tavoli switcher merely because that switcher already exists.

The accepted higher-level product direction is:

```text
Home
  ├── Progetti
  └── Scambio-Dona
```

Therefore 04C2 should add a functional Scambio-Dona entry from **Home**.

The final Home animation/visual design is not part of this plan.

A simple theme-driven pair of entry cards/buttons is sufficient:

```text
Progetti
Scambio-Dona
```

`Progetti` continues to enter the existing Browse Projects/Tavoli experience.

`Scambio-Dona` opens the new listing discovery route.

Do not redesign the bottom nav or final Home branding.

---

# 2. Route structure

Use an internal durable route family such as:

```text
/resources
/resources/mine
/resources/create
/resources/:listingId
/resources/:listingId/edit
```

The UI may display `Scambio-Dona`, `Dona`, and `Scambia`; internal route naming does not need to be Italian.

Recommended routing placement:

- `/resources` and child routes live in the **Home branch**, so the Home bottom destination remains selected while using this top-level pillar.
- public list/detail remain accessible before login;
- owner-management routes require auth;
- create/edit/mine require a complete profile through the existing router conventions.

Public:

```text
/resources
/resources/:listingId
```

Protected:

```text
/resources/mine
/resources/create
/resources/:listingId/edit
```

Update route-classification/return-destination logic so:

- signed-out user opening My/Create/Edit is sent through OTP auth with the intended return destination;
- incomplete-profile user is sent through profile setup;
- ready user returns to the requested resource-management route;
- public list/detail never require authentication.

Do not accidentally classify `/resources/:id` as management.

---

# 3. Mobile feature boundary

Create a dedicated feature, preferably:

```text
apps/mobile/lib/features/resource_listings/
  domain/
  data/
  application/
  presentation/
```

or another repository-consistent name.

Do not put this inside Projects/Participation.

The domains are intentionally separate.

Suggested ownership:

```text
domain
  listing models
  mode/lifecycle enums
  cursors/filter model

data
  Supabase RPC gateway

application
  public discovery controller
  public detail controller
  own-listings controller
  editor/controller

presentation
  public list
  public detail
  own listings
  editor
  shared cards/widgets
```

---

# 4. Backend contracts

Use only the merged 04C1 public RPCs.

Inspect generated types/current migration for exact signatures, but conceptually:

```text
create_resource_listing_draft
update_own_resource_listing
publish_resource_listing
close_resource_listing

list_own_resource_listings
get_own_resource_listing

list_public_resource_listings
get_public_resource_listing
```

Do not direct-read or mutate `resource_listings`.

Do not add a database migration merely for mobile convenience unless a genuine blocker is discovered.

If a backend contract is genuinely insufficient, stop and report before broadening scope.

---

# 5. Domain models and parsing

Add strict typed models.

## Mode

```text
donate
exchange
```

User-facing copy:

```text
donate   → Dona
exchange → Scambia
```

Do not relabel `exchange` as “Loan”, “Barter”, “Swap”, or equivalent.

## Lifecycle

```text
draft
published
closed
```

## Public summary

Conceptually:

```text
id
mode
title
description
countryCode
locality
administrativeArea?
publicLocationLabel
publishedAt
```

## Public detail

Public summary fields plus:

```text
ownerProfileId
ownerDisplayName?
```

## Owner listing

All owner-editable content plus:

```text
lifecycle
createdAt
updatedAt
publishedAt?
closedAt?
```

## Public cursor

```text
publishedAt + listingId
```

Strictly validate known enum values and required fields.

Do not silently turn malformed known rows into plausible listings.

---

# 6. Public discovery controller

Public discovery must work signed out.

State should own:

```text
items
phase
hasMore

modeFilter?       // null / donate / exchange
locality
query

cursor
```

Required behavior:

- initial load;
- pull-to-refresh;
- paired keyset load-more;
- ID dedupe across page boundaries;
- deterministic backend order;
- apply filters by resetting pagination;
- safe failure that preserves already loaded rows where appropriate;
- no identity requirement.

Do not implement client-side ranking.

Do not locally search already-loaded rows as if that were canonical search.

Filters must call the backend.

---

# 7. Discovery UI

Create `/resources` functional screen.

App bar:

```text
Scambio-Dona
[My listings]
```

Body:

1. mode selector;
2. keyword field;
3. locality field;
4. Apply/Search action;
5. published listing results;
6. load-more control.

Floating action or clear action:

```text
Create listing
```

## Mode selector

Use:

```text
All
Dona
Scambia
```

A SegmentedButton/chips/dropdown is acceptable.

Do not introduce subtypes beneath Scambia.

## Keyword

Map directly to the 04C1 backend literal case-insensitive title/description search.

Do not claim fuzzy/semantic search.

## Locality

Use the existing backend case-insensitive locality equality contract.

## Applying filters

Avoid firing a network request on every keystroke unless existing app conventions strongly support debounce.

A clear Apply/Search action is acceptable and easier to reason about.

---

# 8. Listing cards

Each public listing card should communicate:

- `Dona` or `Scambia`;
- title;
- short/truncated description;
- public location label;
- optional locality context if useful;
- publication recency/date if useful.

Use the existing theme.

Do not invent final visual identity.

No:

- price;
- quantity;
- condition badge;
- image placeholder implying media support;
- owner contact button;
- availability count;
- “Reserve”;
- “Claim”;
- “Request”.

Tap opens:

```text
/resources/:listingId
```

---

# 9. Empty/error/loading states

Reuse shared app components where appropriate.

Examples:

```text
No listings found
Try changing the search or filters.
```

If there are genuinely no listings:

```text
Nothing in Scambio-Dona yet.
```

Copy can be improved/localized.

Partial-page load failure must not erase already loaded results.

---

# 10. Public detail

`/resources/:listingId` loads through:

```text
get_public_resource_listing
```

Show:

- mode;
- title;
- full description;
- rough public location;
- public owner display name only when returned by backend;
- published date if useful.

Do not display:

- owner email;
- exact handoff location;
- contact information;
- phone;
- hidden display name;
- invented profile fallback.

If `ownerDisplayName == null`, simply omit the owner name.

## No interaction CTA yet

For a listing the current viewer does not own, do **not** show:

```text
Request
Claim
Reserve
Message owner
Borrow
Trade
Buy
```

04C4 will define what happens next.

A functional read-only public detail is correct for 04C2.

## Owner viewing their own public listing

If the authenticated profile ID equals `ownerProfileId`, it is acceptable to show an Edit shortcut.

My Listings remains the canonical management entry.

---

# 11. My Listings

`/resources/mine` is authenticated/complete-profile-only.

Load:

```text
list_own_resource_listings
```

Show all:

```text
draft
published
closed
```

Each card:

- mode;
- title or safe draft placeholder;
- lifecycle;
- public location if present;
- useful timestamp.

Use a clear status badge.

Preserve backend canonical ordering.

Do not silently reorder by lifecycle.

---

# 12. Editor model

Use one editor for create/edit.

Fields:

```text
mode
title
description
countryCode
locality
administrativeArea
publicLocationLabel
```

No extra fields.

In particular do not add:

- taxonomy/category;
- condition;
- quantity;
- unit;
- price;
- desired trade;
- loan duration;
- return date;
- exact address;
- phone/email;
- images.

---

# 13. Create flow

Do not create an empty draft merely by opening the create screen.

Keep initial form state local until the user chooses an action.

Provide:

```text
Save draft
Publish
```

## Save draft

For new listing:

```text
create_resource_listing_draft(...)
```

Draft may be incomplete according to backend rules.

On success:

- canonical listing ID is known;
- transition editor to edit-existing mode;
- refresh/invalidate My Listings.

## Publish new listing

Recommended flow:

```text
client validates obvious publish-required fields
→ create draft
→ publish returned ID
```

If publish fails after draft creation:

- do not lose the draft;
- keep editor on that listing;
- explain safely that the draft was saved but could not be published;
- do not create a second draft on retry.

---

# 14. Edit flow

`/resources/:listingId/edit` loads canonical owner detail through:

```text
get_own_resource_listing
```

Editable states:

```text
draft
published
```

Closed is terminal/read-only.

## Draft actions

```text
Save draft
Publish
```

## Published actions

```text
Save changes
Close listing
```

It is acceptable to continue allowing mode changes between Dona/Scambia because 04C1 defines them as discovery intent only.

Published save must preserve backend publication requirements.

Do not offer “Unpublish”.

---

# 15. Close flow

For a published owner listing, expose:

```text
Close listing
```

Use a confirmation dialog.

Copy must make the actual semantics clear:

> This removes the listing from public discovery. It does not record whether a donation or exchange happened.

Do not ask whether the item was donated/exchanged or who received it.

After success:

- refresh owner list;
- refresh public discovery/detail;
- editor becomes terminal/read-only or returns to My Listings.

No reopen action.

---

# 16. Client-side validation

Mirror obvious backend constraints.

At publication:

```text
mode valid
title 2..120
description 1..5000
country code 2 letters
locality non-empty
public location label non-empty
```

Draft save may allow missing content.

Backend remains canonical.

Do not expose raw Postgres/Supabase errors.

---

# 17. Country/location inputs

Do not add geocoding or map SDKs.

Use simple functional fields:

```text
Country code
Locality
Administrative area (optional)
Public location label
```

Normalize obvious country-code presentation to uppercase if appropriate.

Do not collect exact location.

---

# 18. Identity/account-switch safety

Public discovery/detail can remain public-state oriented.

Private owner/editor state is identity-sensitive.

On identity change:

- clear My Listings;
- clear owner-detail/editor canonical data;
- reject late owner RPC responses from the previous identity;
- never flash user A drafts to user B.

Add explicit tests.

Do not make public discovery unnecessarily auth-bound.

---

# 19. Refresh/invalidation rules

After successful:

## save draft

Refresh:

```text
own listings
```

## publish / published edit / close

Refresh:

```text
own listings
public discovery
public detail where relevant
```

Use narrow Riverpod coordination consistent with repository patterns.

---

# 20. Home integration

Update the current functional Home screen.

Keep:

- notifications button;
- messages button;
- auth status;
- bottom navigation.

Expand the current single Projects CTA into two clear pillar entries:

```text
Progetti
Scambio-Dona
```

`Progetti` retains existing navigation into Browse.

`Scambio-Dona` opens `/resources`.

Do not implement the future rotating PNG/SVG animation.

Do not redesign Profile/Browse/Home.

---

# 21. Existing Browse behavior

Do not change the existing Projects/Tavoli switcher beyond necessary navigation-test updates.

Scambio-Dona is not a Tavolo/Proposal type.

No map mode.

No final Progetti IA redesign in this task.

---

# 22. Localization

All new user-facing copy goes through the existing localization system.

Cover at minimum:

- Scambio-Dona;
- Dona;
- Scambia;
- All;
- search;
- locality;
- My listings;
- Create listing;
- Edit listing;
- Save draft;
- Publish;
- Save changes;
- Close listing;
- lifecycle labels;
- loading/empty/errors;
- field labels;
- validation;
- close confirmation and semantics.

No hard-coded production strings.

---

# 23. Accessibility

At minimum:

- mode selector has semantic labels;
- cards expose mode/title/location coherently;
- lifecycle is not color-only;
- fields have labels/errors;
- close dialog is screen-reader/keyboard usable;
- shared loading/error components remain accessible.

---

# 24. Tests — parsing/gateway

Add coverage for:

- public summary parsing;
- nullable owner display name;
- owner listing across lifecycles;
- unknown mode/lifecycle rejection;
- cursor pairing;
- RPC parameter mapping;
- no direct table access.

---

# 25. Tests — public discovery

Cover:

- signed-out discovery;
- initial load;
- Dona / Scambia / All;
- keyword;
- locality;
- combined filters;
- reset/reapply;
- keyset load-more;
- dedupe;
- stable order;
- safe initial/load-more error;
- empty state;
- public detail;
- owner display name present/absent;
- no interaction/request CTA.

---

# 26. Tests — routing/auth

Verify public:

```text
/resources
/resources/:id
```

work signed out.

Verify protected:

```text
/resources/mine
/resources/create
/resources/:id/edit
```

route through auth/profile setup correctly and preserve return destinations.

Existing Proposal/Tavolo/Messages/Notifications routing must remain unchanged.

---

# 27. Tests — owner flow

Cover:

- create screen does not create on open;
- incomplete content saves draft;
- returned ID becomes editor identity;
- valid create+publish;
- publish failure after draft creation retains same draft;
- draft edit/save/publish;
- published edit;
- mode switch changes discovery intent only;
- close confirmation;
- closed listing disappears publicly and remains owner-visible;
- closed editor terminal/read-only;
- no successful-transfer semantics;
- account switch clears private state and rejects stale responses.

---

# 28. Widget tests

Add functional widget coverage for:

- Home Progetti + Scambio-Dona;
- public card;
- mode selector;
- filters;
- detail;
- My Listings;
- editor draft/published/closed states;
- safe errors;
- validation;
- no media/category/price/claim UI.

---

# 29. Native QA

Comprehensive native QA remains deferred to Plan 12.

Require automated Flutter validation and Android build where standard.

Do not claim physical-device QA passed.

Add a Plan-12 checklist for:

- signed-out browse;
- auth return-to management;
- keyboard/forms;
- pagination;
- close confirmation;
- account switching;
- accessibility;
- small screens.

---

# 30. Roadmap/docs

Record:

```text
04C1 — Implemented
PR #32
merge commit 2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42
```

While this PR is open:

```text
04C2 — In progress
```

Keep:

```text
04C — In progress
04C3 — Not started
04C4 — Not started
```

Keep all later-main SITE/06/07 statuses.

Document mobile IA:

```text
Home
  → Progetti
  → Scambio-Dona
```

and that 04C2 still has no post-listing interaction flow.

---

# 31. Validation

Run repository-standard checks:

- Flutter localization generation;
- Dart format;
- Flutter analyze;
- full Flutter tests;
- new resource-listing tests;
- Android debug build where standard;
- Web regression;
- Site/Workers regression;
- Database/generated-type checks unchanged/green;
- root format check;
- `git diff --check`.

No external credentials required.

---

# Non-goals

Do not implement:

- request/claim/reservation;
- contact owner;
- listing direct messages;
- handoff;
- lending;
- barter rules;
- returns;
- payments/prices;
- quantity/stock;
- taxonomy/categories;
- condition grades;
- photos/media;
- map/geocoding;
- Project resource needs;
- contribution offers;
- saved searches;
- matching;
- resource notifications;
- web listing UI;
- moderation;
- final visual redesign.

---

# Acceptance criteria

04C2 is ready when:

- [ ] based on latest `origin/main` containing merged PR #32;
- [ ] exact prompt archived;
- [ ] Home exposes Progetti + Scambio-Dona without changing bottom-nav count;
- [ ] `/resources` public discovery exists;
- [ ] `/resources/:id` public detail exists;
- [ ] `/resources/mine`, `/create`, `/edit` are protected;
- [ ] signed-out public browse/detail works;
- [ ] All/Dona/Scambia works;
- [ ] keyword/locality filters use backend;
- [ ] keyset pagination works;
- [ ] cards/detail expose only 04C1 fields;
- [ ] no interaction/request CTA exists;
- [ ] My Listings shows draft/published/closed;
- [ ] create screen does not create empty draft on open;
- [ ] incomplete listing can save draft;
- [ ] valid listing can publish;
- [ ] failed publish after draft creation does not duplicate draft;
- [ ] published listing can edit;
- [ ] close requires confirmation;
- [ ] close copy does not imply successful transfer;
- [ ] closed listing is terminal/read-only;
- [ ] owner display-name privacy follows backend output;
- [ ] no taxonomy/media/price/quantity/loan/barter/return UI;
- [ ] account switching clears private state;
- [ ] localization/accessibility added;
- [ ] Flutter/router/widget tests pass;
- [ ] Web/Site/Database regressions stay green;
- [ ] no native QA pass falsely claimed;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact feature/file names;
- exact theme-driven card layout;
- segmented control vs chips/dropdown;
- My Listings sections vs one list;
- safe date formatting;
- owner Edit shortcut;
- controller state shapes.

Stop and report before:

- inventing post-listing interaction semantics;
- adding contact/request/claim UI;
- adding taxonomy/media;
- adding Project linkage;
- redesigning bottom nav;
- turning Scambio-Dona into a Proposal/Tavolo subtype;
- changing 04C1 lifecycle/mode semantics;
- adding backend migrations without a real blocker;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 04C2 prompt;
2. Flutter domain models;
3. Supabase RPC gateway;
4. public discovery/detail controllers;
5. owner list/editor controllers;
6. Home Scambio-Dona entry;
7. public list/detail;
8. My Listings;
9. create/edit/publish/close flow;
10. auth/profile route protection;
11. localization/accessibility;
12. parser/gateway/controller/router/widget tests;
13. Plan-12 QA checklist;
14. docs/roadmap update;
15. focused PR, preferably `codex/04c2-scambio-dona-mobile`;
16. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **04C1 roadmap reconciliation**
5. **Feature architecture**
6. **Routes/auth**
7. **Home integration**
8. **Models/parsing**
9. **Gateway/RPCs**
10. **Public discovery controller**
11. **Mode filter**
12. **Keyword/locality filters**
13. **Pagination**
14. **Public list UI**
15. **Public detail UI**
16. **Owner display-name privacy**
17. **My Listings**
18. **Editor state**
19. **Create draft**
20. **Publish**
21. **Published edit**
22. **Close**
23. **Closed terminal state**
24. **Account-switch safety**
25. **Localization/accessibility**
26. **Deferred request/handoff semantics**
27. **Absent taxonomy/media/price/etc.**
28. **Flutter/router/widget tests**
29. **Regression validation**
30. **Deferred native QA**
31. **Warnings/blockers**
32. **Commit/PR reference**
