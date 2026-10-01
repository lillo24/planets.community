# PLANETS 04C4F1 — Personal Saved Resource Search Domain

**Roadmap area:** 04C4F — Saved Searches + Matching Notifications  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #88 — 04C4E2 Mobile Project Resource Matching UX
branch: codex/04c4e2-mobile-project-resource-matching
head:   2824e9b2a0a891473aecc3d19e0460bf63c55713
```

PR #88 is draft and stacked on PR #87/#84/#83. The inherited database replay/lint/advisors/pgTAP/OTP/type-drift gates remain unresolved.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #88 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #88 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4f1-personal-saved-resource-searches
```

Open against:

```text
codex/04c4e2-mobile-project-resource-matching
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4F1_personal_saved_resource_search_domain.md
```

No external document is required.

---

# Product scope now fixed

Saved searches are **personal and independent from Projects**.

First version saves exactly the current Scambio-Dona public discovery filters:

```text
text query
listing mode: All / Dona / Scambia
locality
```

This is eBay-style personal search persistence.

Do not link a saved search to:

```text
Project
Project resource need
agreement
request
loan reservation
```

Project-need matching remains 04C4E.

---

# 1. Split 04C4F

Refine the roadmap:

```text
04C4F — Saved Searches + Matching Notifications (parent)

04C4F1 — Personal Saved Resource Search Domain
  this plan

04C4F2 — Mobile Saved Search UX
  later

04C4F3 — New-Listing Match Projection + Notifications
  later
```

F1 deliberately does **not** decide:

```text
immediate vs digest notifications
notification frequency
push copy
notification enablement toggle
```

Those belong to F3.

---

# 2. No persisted match results

Persist only saved filter definitions.

Do not create:

```text
saved_search_matches
matched_listing_ids
last_match_snapshot
notification rows
```

Current matches are still derived from published listings.

F3 later evaluates new `resource_listing.published` events against saved searches.

---

# 3. Saved-search table

Add a private/RLS-protected table equivalent to:

```text
resource_saved_searches
```

Fields:

```text
id uuid primary key
profile_id uuid not null → profiles(id)

query text null
listing_mode text null
locality text null

created_at timestamptz not null
updated_at timestamptz not null
```

No Project ID.

No notification-enabled field in F1.

No user-defined display name in F1.

The mobile UI can derive a readable description from the filters.

---

# 4. Canonical filter semantics

Saved search filters must mirror the existing public Resource discovery contract:

## query

```text
trimmed
1..120 if present
case-insensitive literal substring
matches listing.title OR listing.description
```

## locality

```text
trimmed
1..120 if present
case-insensitive exact equality against listing.locality
```

## listing_mode

```text
null
donate
exchange
```

Normalize mode to lowercase.

Do not add:

```text
lend
radius
administrative area
country
taxonomy
tags
```

in F1.

---

# 5. At least one active filter

Reject a saved search where all are null after normalization:

```text
query = null
listing_mode = null
locality = null
```

Use:

```text
22023
```

This prevents a meaningless “all Resource listings everywhere” subscription source.

Any one filter is sufficient:

```text
query only
mode only
locality only
```

---

# 6. Case-insensitive duplicate prevention

A profile cannot own two semantically identical searches.

These must count as duplicates:

```text
query "Trapano" vs "trapano"
locality "Trento" vs " trento "
same mode
```

Use a database-enforced unique expression/index over normalized values, conceptually:

```text
profile_id
lower(coalesce(query, ''))
coalesce(listing_mode, '')
lower(coalesce(locality, ''))
```

Do not rely only on application pre-checks.

---

# 7. Duplicate conflict code

Create/update that would collide with another saved search returns:

```text
PT409
```

Do not leak a raw unique-constraint error to clients.

No automatic merge of the two records.

---

# 8. Saved-search immutability boundary

Saved searches are ordinary user preferences, not historical legal records.

Allow update and hard delete.

Do not create immutable version history.

Do not write audit/outbox events merely for every saved-search edit in F1 unless a repository-wide mandatory mutation invariant requires it.

F3 notifications concern matching listings, not search-edit history.

---

# 9. Updated timestamp

Use a trigger/private helper so:

```text
updated_at
```

changes canonically on updates.

`created_at` remains unchanged.

---

# 10. Identity helper

Use the existing authenticated profile identity boundary where possible.

Every public RPC takes:

```text
p_expected_profile_id
```

and verifies it matches the authenticated profile.

Do not authorize using a profile ID supplied without auth.

---

# 11. Create RPC

Add:

```text
create_resource_saved_search(
  p_expected_profile_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text
)
returns uuid
```

Normalize/validate all fields server-side.

Return the created saved-search ID.

Duplicate → PT409.

---

# 12. Update RPC

Add:

```text
update_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text
)
returns uuid
```

Only owner may update.

Apply same normalization/validation as create.

Duplicate-after-update → PT409.

No CAS/version field required for this non-critical personal preference in F1.

---

# 13. Delete RPC

Add:

```text
delete_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid
)
returns uuid
```

Only owner.

Hard delete is acceptable.

Future F3 notifications must not require the search row to exist forever.

Do not cascade into Resource listings or other domains.

---

# 14. Exact read RPC

Add:

```text
get_own_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid
)
```

Return one owned row or no row/fail closed according to repository convention.

Suggested fields:

```text
saved_search_id
query
listing_mode
locality
created_at
updated_at
```

No profile ID needs to be returned to the same owner unless useful.

---

# 15. List RPC

Add bounded keyset:

```text
list_own_resource_saved_searches(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null
)
```

Order:

```text
updated_at DESC
id DESC
```

Limit:

```text
1..50
```

Cursor values must be both null or both supplied.

---

# 16. Search-result execution is not a new RPC

Do not create a duplicate “run saved search” listing query.

F2 can execute a saved search using the existing public discovery contract:

```text
list_public_resource_listings(
  mode,
  locality,
  query
)
```

A saved search is just a canonical reusable filter definition.

---

# 17. Reusable private predicate for F3

Add a private helper equivalent to:

```text
private.resource_listing_matches_saved_search_filters(
  p_listing_mode text,
  p_listing_title text,
  p_listing_description text,
  p_listing_locality text,
  p_saved_listing_mode text,
  p_saved_query text,
  p_saved_locality text
)
returns boolean
```

It must implement **exactly** the current public discovery semantics:

```text
mode:
  null OR listing mode exact

locality:
  null OR lower(listing.locality) = lower(saved locality)

query:
  null OR literal case-insensitive substring in title OR description
```

No FTS, stemming, Project matcher tiers, synonyms, or scoring.

---

# 18. Browse/saved-search parity

Add tests proving the private predicate produces the same inclusion decision as:

```text
list_public_resource_listings
```

for representative combinations.

The saved-search notification matcher in F3 must not drift from what the user sees when manually running the same filters.

---

# 19. Literal query semantics

Important distinction:

04C4E Project matching is lexical/Italian FTS.

Personal saved Resource searches in F1 follow the **existing Resource browse search**, which is literal case-insensitive substring matching.

Do not reuse E1's lexical matcher for personal saved searches.

Examples:

```text
saved query = "trapano"
listing title = "Trapano Bosch"
→ match

saved query = "drill"
listing title = "Trapano Bosch"
→ no match

saved query = "Bosch 18"
listing description contains "Bosch 18V"
→ match
```

---

# 20. Listing eligibility for future matching

The private saved-search predicate evaluates filter fields only.

F3 must separately require:

```text
listing.lifecycle_state = published
```

F1 need not persist lifecycle eligibility into the search.

---

# 21. No Project coupling

Do not add:

```text
project_id
resource_need_id
project_kind
```

to saved searches.

Do not allow “save this Project need matcher” in F1.

If product later wants followed Project-needs, model it separately rather than overloading personal browse saved searches.

---

# 22. No availability coupling

Do not save or infer:

```text
loan period
available dates
overdue
at-risk
borrower queue
```

Saved search current filters do not contain those concepts.

---

# 23. No notification preference yet

Do not add:

```text
notifications_enabled
frequency
last_notified_at
digest_window
```

to F1.

F3 will decide alert policy with the notification backbone.

This keeps F1 stable regardless of immediate vs digest alerts.

---

# 24. No taxonomy/radius yet

Do not add schema placeholders for speculative future filters.

Future migrations can extend saved search definitions with:

```text
radius
global resource tags/categories
additional location fields
```

when those product models actually exist.

---

# 25. Mutation concurrency

Database uniqueness must make concurrent duplicate creates deterministic:

```text
one succeeds
one PT409
```

Likewise two updates racing toward the same normalized filter tuple must not leave duplicates.

Add focused concurrency coverage where feasible.

---

# 26. Delete/update races

For:

```text
update vs delete
```

serialize on the saved-search row.

Final state may be either updated or deleted depending on lock winner, but must not:

- update another profile's row;
- recreate deleted data implicitly;
- leak raw DB conflict details.

Use standard row locking.

---

# 27. RLS/table grants

Enable RLS.

Prefer RPC-only client access, consistent with sensitive/private domain style:

```text
revoke direct table privileges
```

Public functions are expected-identity bound.

Anonymous has no access.

Private predicate/helpers have no client execute grant.

---

# 28. Ownership/privacy

One profile can never:

- list another profile's saved searches;
- read exact saved search by guessed UUID;
- update/delete another search.

Search text/locality are private account preferences.

Do not expose them publicly.

---

# 29. No outbox matching event yet

Do not consume:

```text
resource_listing.published
```

in F1.

Do not create:

```text
resource_saved_search.matched
```

events or notifications.

F3 owns event projection/delivery.

---

# 30. Structural pgTAP

Cover:

- table/constraints;
- RLS enabled;
- direct grants denied;
- identity-bound CRUD/list RPCs;
- private predicate;
- timestamp trigger;
- normalized duplicate unique index;
- fixed search paths;
- authenticated grants only;
- no notification/frequency columns;
- no Project foreign key.

---

# 31. Behavioral pgTAP — create

Cover:

```text
query only
mode only
locality only
all three
```

Reject:

```text
all empty
query >120
locality >120
invalid mode
```

Verify trimming and mode normalization.

---

# 32. Behavioral pgTAP — duplicates

Cover semantic duplicates with:

- case differences;
- surrounding whitespace;
- null combinations.

Duplicate create/update → PT409.

Different mode/locality/query remains distinct.

---

# 33. Behavioral pgTAP — ownership

Cover:

- owner list/read/update/delete;
- unrelated user denied;
- anonymous denied;
- guessed UUID non-leak.

---

# 34. Behavioral pgTAP — list pagination

Create multiple searches with tied timestamps where practical.

Verify:

```text
updated_at DESC
id DESC
```

paired cursor prevents duplicate/skip.

Invalid partial cursor → 22023.

---

# 35. Behavioral pgTAP — predicate parity

Test combinations against current public Resource discovery:

```text
query only
locality only
mode only
query + locality
query + mode
locality + mode
all three
```

Case-insensitive semantics must agree.

---

# 36. Behavioral pgTAP — literal vs lexical

Prove saved-search query remains literal:

```text
"trapano" matches "Trapano Bosch"
"drill" does not match "Trapano Bosch"
```

Do not accidentally inherit E1 Italian stemming/synonyms.

---

# 37. Behavioral pgTAP — lifecycle independence

Predicate may match filter values of a closed/draft listing, but the **public browse RPC** only returns published listings.

Document/test that F3 must combine:

```text
published lifecycle
AND saved-search predicate
```

Do not embed hidden lifecycle state into saved search definition.

---

# 38. Concurrency verifier

Extend an existing Resource verifier or add focused real-OTP verifier covering:

1. two authenticated users;
2. create/read/list own searches;
3. normalization;
4. duplicate PT409;
5. update;
6. delete;
7. cross-user isolation;
8. list cursor;
9. predicate parity with public Resource browse;
10. concurrent duplicate creation if feasible.

Never log:

- OTP/token;
- private search query/locality in error dumps beyond bounded test fixture constants;
- unrelated profile data.

---

# 39. Generated types

Regenerate/update database types for the new public RPCs.

Because inherited Docker/current-stack DB validation is unresolved:

- do not claim type drift passed unless run against a clean replay of the full current stack;
- do not fabricate success;
- keep final `db:types:check` a hard pre-merge gate.

---

# 40. Documentation / roadmap

Update:

```text
04C4E1 — PR #87, final DB gates pending
04C4E2 — PR #88

04C4F — Saved Searches + Matching Notifications
04C4F1 — Personal Saved Resource Search Domain
  this PR
04C4F2 — Mobile Saved Search UX
  next
04C4F3 — New-Listing Match Projection + Notifications
  later
```

Document first-version filters exactly:

```text
text query
Dona/Scambia mode
locality
```

Document saved searches as personal and Project-independent.

---

# 41. F2 handoff

F2 should consume:

```text
create_resource_saved_search
update_resource_saved_search
delete_resource_saved_search
get_own_resource_saved_search
list_own_resource_saved_searches
```

and execute the saved filters through the existing:

```text
list_public_resource_listings
```

No special matching-result table/API is required.

Likely UX:

```text
Resource Browse filters
→ Save search

Saved searches
→ tap → open Resource Browse with those filters
→ edit/delete
```

---

# 42. F3 handoff

F3 should reuse:

```text
private.resource_listing_matches_saved_search_filters(...)
```

on canonical:

```text
resource_listing.published
```

events.

F3 must separately decide:

- alerts enabled UX;
- immediate vs digest frequency;
- notification category/copy;
- dedupe/idempotency;
- push interaction.

Do not decide these in F1.

---

# 43. Validation

Run repository equivalents of:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

node --check <saved-search verifier>
npm run check:web
npm run check:site
npm run check:mobile
git diff --check
```

Attempt focused real-OTP/concurrency verification.

Attempt hosted Validation once.

If GitHub cannot allocate a runner due the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

This DB-heavy PR must not merge until its own and inherited current-stack database/type gates execute green.

---

# Non-goals

Do not implement:

- Flutter saved-search UI;
- notification enablement;
- notification frequency;
- notification projection;
- push;
- match-result persistence;
- Project-linked saved searches;
- Project resource-need follow/subscription;
- E1 lexical matching semantics;
- synonyms/taxonomy;
- radius;
- country/admin-area saved filters;
- loan availability filters;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #88;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] private saved-search table exists;
- [ ] saved search belongs to one profile only;
- [ ] fields are exactly query/mode/locality plus metadata;
- [ ] no Project linkage;
- [ ] no notification/frequency fields;
- [ ] at least one filter required;
- [ ] normalization mirrors public Resource browse;
- [ ] duplicate normalized searches blocked;
- [ ] duplicate conflict uses PT409;
- [ ] create/update/delete/read/list RPCs exist;
- [ ] list uses bounded keyset pagination;
- [ ] hard delete supported;
- [ ] no immutable history/versioning;
- [ ] private reusable saved-search predicate exists;
- [ ] predicate mirrors current Resource browse semantics;
- [ ] personal query remains literal substring matching, not E1 FTS;
- [ ] no private loan/availability coupling;
- [ ] RLS/direct grants fail closed;
- [ ] cross-user privacy tested;
- [ ] duplicate concurrency tested where feasible;
- [ ] predicate/browse parity tested;
- [ ] generated types updated where executable;
- [ ] own and inherited DB blockers reported honestly;
- [ ] no F2/F3 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4F1 branch/base/PR
3. Changed files
4. Saved-search table
5. Filter fields/scope
6. Normalization
7. All-empty rejection
8. Duplicate uniqueness
9. PT409 duplicate behavior
10. Create RPC
11. Update RPC
12. Delete RPC
13. Exact read RPC
14. List/keyset RPC
15. Timestamp behavior
16. Hard-delete/history decision
17. Private matching predicate
18. Public browse parity
19. Literal-query semantics
20. Project-independence
21. Availability independence
22. No-notification-field boundary
23. No-taxonomy/radius boundary
24. RLS/grants
25. Ownership/privacy
26. Mutation concurrency
27. Structural pgTAP
28. Create/validation pgTAP
29. Duplicate pgTAP
30. Ownership pgTAP
31. Pagination pgTAP
32. Predicate parity pgTAP
33. Literal-vs-lexical pgTAP
34. Real OTP/concurrency verifier
35. Generated types/drift
36. Local regression validation
37. Hosted Validation executed/not-executed
38. Inherited DB-gate status
39. 04C4F2 handoff
40. 04C4F3 handoff
41. Warnings/blockers
42. Commit/PR reference

Do not merge any PR.
