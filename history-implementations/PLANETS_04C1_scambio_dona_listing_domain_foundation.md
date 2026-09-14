# PLANETS 04C1 — Scambio-Dona Listing Domain Foundation

**Roadmap area:** PLANETS 04C — Resources + Scambio-Dona  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged base when this prompt was written:** `2197576acb47bd7cd0dd42a7f10987d7522caea5` (06D / PR #31)

## Objective

Implement the first safe, decision-light foundation for the **Scambio-Dona** pillar: owner-managed resource/item listings with public discovery.

The accepted product direction is:

```text
Home
  ├── Progetti
  └── Scambio-Dona
        ├── Scambia
        └── Dona
```

A user should eventually be able to publish something they can make available and other users should be able to discover it.

However, the product design does **not** yet define the transaction semantics behind `Scambia`.

In particular, `Scambia` might later mean or include:

- lending;
- barter;
- temporary sharing;
- another exchange arrangement.

Those rules are deliberately **not** decided yet.

Therefore 04C1 treats:

```text
donate
exchange
```

only as **listing/discovery intents**.

`exchange` must not imply any particular ownership transfer, return obligation, payment, barter ratio, reservation, or handoff workflow.

04C1 establishes only:

- canonical listing identity;
- owner lifecycle;
- public sanitized discovery/detail;
- rough location;
- simple keyword/mode/locality discovery;
- minimal audit/outbox hooks for later matching;
- secure owner APIs;
- tests and generated contracts.

It does **not** implement mobile UI yet.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C1_scambio_dona_listing_domain_foundation.md
```

Preferred branch:

```text
codex/04c1-scambio-dona-listing-foundation
```

---

# Why 04C is being split

The existing 04C roadmap item combines several domains that are related but not equivalent:

```text
A. standalone Scambio-Dona listings
B. Project resource needs
C. participant contribution offers
D. listing requests / handoff / exchange semantics
E. saved searches
F. Project ↔ listing matching
G. resource/matching notifications
```

The design source is sufficiently clear for **A**, but not yet for D.

Trying to implement all of 04C now would force Codex to invent product rules.

Use this split:

```text
04C — Resources + Scambio-Dona (parent)

04C1 — Scambio-Dona Listing Domain Foundation
04C2 — Scambio-Dona Mobile Discovery and Owner Experience
04C3 — Project Resource Needs and Contribution Offers
04C4 — Listing Requests/Handoff + Saved Search/Matching
```

04C4 is intentionally allowed to split further after founder decisions.

05C should eventually depend on the Project-resource/contribution slice rather than on unrelated listing UI.

---

# Source-of-truth product constraints

The Google design document establishes:

- Scambio-Dona as a main user-facing area;
- users can browse resources/items;
- users can publish availability;
- `Scambia` and `Dona` are the principal listing modes;
- saved searches later use a search word/type;
- future matching may connect resources with Projects;
- the exact mechanics of `Scambia` remain unresolved.

The existing catalog document contains the **skills catalog**, not an agreed resource/item taxonomy.

Therefore 04C1 must **not invent a resource category catalog**.

Do not add:

- material categories;
- condition grades;
- quantities/stock;
- monetary prices;
- barter values;
- unit types;
- loan durations;
- return dates.

Those can be added later if product design requires them.

---

# Required repository inspection

Before coding, inspect at minimum:

1. root and applicable nested `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/implementation/roadmap.md`;
5. `docs/development/database.md`;
6. 04A Proposal schema, public/owner API and rough-location privacy pattern;
7. 04B1 recurring-activity security conventions;
8. 03C profile visibility/public-display-name rules;
9. 01A/01B grant/RLS/audit/outbox conventions;
10. generated database type workflow;
11. current DB CI/integration conventions;
12. current main after PR #31.

Use current repository implementation as source of truth where implementation details differ from older planning text.

---

# 1. Canonical listing entity

Add a standalone canonical entity equivalent to:

```text
public.resource_listings
```

Use a domain name that remains valid if the eventual Italian UI says `Scambio-Dona`.

Conceptual fields:

```text
id
owner_profile_id

listing_mode
lifecycle_state

title
description

country_code
locality
administrative_area
public_location_label

created_at
updated_at
published_at
closed_at
```

No exact handoff coordinates/address.

No Project ID.

No recipient/requester ID.

No transaction state.

## Listing mode

Exactly:

```text
donate
exchange
```

Meaning in 04C1:

```text
donate
  owner is publicly offering the item/resource in the Dona discovery bucket

exchange
  owner is publicly offering the item/resource in the Scambia discovery bucket
```

Do not encode anything more.

Do not use names such as `loan`, `barter`, `sale`, `rent`, or `swap_type`.

---

# 2. Lifecycle

Use a small explicit lifecycle:

```text
draft
published
closed
```

Expected transitions:

```text
create → draft
draft → published
published → closed
```

`closed` is terminal in 04C1.

Do not implement reopen/reactivate.

A user can create a new listing later.

## Draft

- private to owner;
- editable;
- may be incomplete.

## Published

- publicly discoverable;
- owner may edit its safe listing content;
- mode may remain editable if doing so is transactionally safe;
- must satisfy publish requirements.

## Closed

- not publicly discoverable;
- retained in owner history;
- no longer editable in 04C1 except through future explicitly designed workflows.

No automatic expiry in 04C1.

The owner closes the listing when it is no longer available.

Do not infer “claimed”, “donated”, “exchanged”, or “completed” from `closed`.

---

# 3. Content fields

Keep the first schema intentionally small.

## Title

Required for publication.

Suggested bound:

```text
2..120 Unicode characters
```

## Description

Required for publication.

Suggested bound:

```text
1..5000 Unicode characters
```

Description is plain text.

It may currently contain human-written contextual details such as:

- what the item is;
- approximate condition;
- what the owner has in mind.

Do not parse those into structured business rules.

## No redundant summary requirement

Do not add a separate summary unless repository evidence strongly shows it is needed for current APIs.

Future mobile cards may truncate the description.

This keeps the domain smaller.

---

# 4. Rough location only

Reuse the established rough public-location concepts:

```text
country_code
locality
administrative_area
public_location_label
```

Publishing requires at minimum the same practical rough-location baseline used by public discovery, preferably:

```text
country_code
locality
public_location_label
```

`administrative_area` may remain optional.

Do not add:

- exact handoff address;
- exact geography point;
- phone number;
- email;
- meeting instructions.

Future request/handoff scope will decide what location/contact data is exchanged and when.

A listing is discovery content, not an appointment.

---

# 5. Owner identity and public display

A listing belongs to one human profile:

```text
owner_profile_id
```

Do not introduce organizations/legal entities here.

For public detail, expose safe owner context using the **existing profile visibility model**.

Mirror the Proposal public-detail convention:

```text
owner_profile_id
owner_display_name only when display_name visibility is public
```

Do not expose:

- Auth email;
- private bio;
- private profile fields;
- hidden contact details.

A hidden display name may result in a null public display name.

Do not weaken profile visibility because the user published a listing.

---

# 6. No direct table mutation/access

Follow the repo's current fail-closed conventions.

Prefer:

- RLS enabled;
- no ordinary direct table grants;
- public/owner reads through narrow RPCs;
- mutations only through expected-identity-bound RPCs;
- fixed/empty search path for security-definer functions.

Do not depend on frontend ownership checks.

---

# 7. Owner identity helper

Create/reuse a private helper appropriate for this domain:

```text
require_resource_listing_identity(expected_profile_id)
```

or reuse a genuinely generic existing complete-profile helper if repository evidence supports it without misleading Proposal-specific semantics.

Requirements:

- authenticated identity required;
- expected ID must equal `auth.uid()`;
- profile must exist;
- complete profile required for create/publish;
- cross-account mutations denied.

Do not couple listing ownership to chat/participation identity functions merely because both use profiles.

---

# 8. Create draft

Add an authenticated operation equivalent to:

```text
create_resource_listing_draft(
  expected_owner_profile_id,
  listing_mode,
  title?,
  description?,
  country_code?,
  locality?,
  administrative_area?,
  public_location_label?
)
```

Return listing UUID.

Requirements:

- complete profile;
- mode must be `donate` or `exchange`;
- normalize trimmed text;
- allow incomplete draft content;
- server owns timestamps.

No outbox event is required merely for draft creation.

---

# 9. Update own listing

Add:

```text
update_own_resource_listing(...)
```

Owner-only.

Allowed states:

```text
draft
published
```

When editing a published listing:

- the resulting row must still satisfy all publish requirements atomically;
- it remains published;
- do not silently unpublish it.

Closed listing update is denied.

Changing `listing_mode` between `donate` and `exchange` may be allowed while editable unless repository/product evidence gives a reason not to; if allowed, document this clearly as changing discovery intent only.

---

# 10. Publish

Add:

```text
publish_resource_listing(expected_owner_profile_id, listing_id)
```

Publish requirements:

```text
mode present/valid
title present
description present
country_code present
locality present
public_location_label present
```

Publishing a valid already-published listing may be idempotent if consistent with repository lifecycle conventions.

Only a draft can first transition to published.

Set canonical `published_at`.

Emit identifier-only:

```text
audit: resource_listing.published
outbox: resource_listing.published
```

Payload should contain only useful identifiers, e.g.:

```text
listing_id
owner_profile_id
listing_mode
```

No description/location text.

This event is future input for saved-search/matching work.

Do not project notifications now.

---

# 11. Close

Add:

```text
close_resource_listing(expected_owner_profile_id, listing_id)
```

Only an own published listing may close.

Set:

```text
lifecycle_state = closed
closed_at = transition timestamp
```

Emit identifier-only:

```text
audit: resource_listing.closed
outbox: resource_listing.closed
```

Closing does **not** mean:

- donated successfully;
- exchanged successfully;
- handed over;
- reserved;
- sold.

It means only:

> this listing is no longer publicly available.

Do not add a close reason yet.

---

# 12. Owner reads

Add narrow owner operations equivalent to:

```text
list_own_resource_listings(expected_owner_profile_id)
get_own_resource_listing(expected_owner_profile_id, listing_id)
```

Return:

- drafts;
- published;
- closed.

Include lifecycle timestamps and all owner-editable rough public content.

No transaction/request fields exist yet.

Order owner history deterministically, preferably:

```text
created_at DESC, id DESC
```

If owner history becomes paginated using repo conventions, that is acceptable but not necessary unless current architecture strongly favors it.

---

# 13. Public list

Add anonymous/authenticated public discovery:

```text
list_public_resource_listings(
  limit,
  cursor_published_at?,
  cursor_id?,
  listing_mode?,
  locality?,
  query?
)
```

Exact signature is Codex-owned.

Only:

```text
lifecycle_state = published
```

is discoverable.

## Ordering

Use:

```text
published_at DESC
id DESC
```

with paired keyset cursor.

Newest public availability first is a reasonable first functional ordering.

No recommendation/ranking engine.

## Mode filter

Optional:

```text
donate
exchange
```

Invalid modes fail explicitly.

## Locality filter

Use case-insensitive equality consistent with existing Proposal public discovery.

## Keyword query

The design explicitly anticipates later saved searches based on search word/type.

04C1 may therefore establish a **simple first keyword contract** over:

```text
title
description
```

Keep it intentionally understandable.

Recommended semantics:

- trim query;
- null/empty = no keyword filter;
- case-insensitive substring match in title OR description;
- bounded query length.

Do not introduce language-specific stemming or opaque ranking yet.

Do not add a resource taxonomy merely to improve search.

If current Postgres/security conventions make a different simple deterministic implementation materially safer, Codex may choose it and document exact semantics.

---

# 14. Public list payload

Return only safe card-level fields:

```text
listing_id
listing_mode
title
description or a safe card excerpt/full bounded description
country_code
locality
administrative_area
public_location_label
published_at
```

The API may return full bounded description and let clients truncate later.

Do not expose owner private fields.

Owner display name is not required in list cards unless the current product/public patterns strongly justify it.

Do not return draft/closed timestamps publicly.

---

# 15. Public detail

Add:

```text
get_public_resource_listing(listing_id)
```

Only published listings.

Return:

```text
listing_id
listing_mode
title
description
rough public location
published_at

owner_profile_id
owner_display_name when public under existing visibility rules
```

No:

- Auth email;
- phone;
- exact address;
- exact coordinates;
- request state;
- hidden profile fields.

Missing/non-public/closed should follow existing public exact-detail non-enumeration conventions where possible.

---

# 16. No hard delete in 04C1

Do not add a public/owner hard-delete operation.

Reasons:

- later saved-search/matching/request history may reference listing identity;
- account deletion/privacy operations are Plan 10;
- `closed` provides the required ordinary owner lifecycle.

Draft cleanup can be designed later if needed.

Do not silently cascade-delete published listing history.

---

# 17. No transaction/request model

This is a critical boundary.

Do **not** create:

```text
resource_requests
claims
reservations
transactions
exchanges
loans
handoffs
recipients
borrowers
return_due_at
payment
price
trade_offer
availability_quantity
```

Do not add “contact owner” business logic.

04C1 ends at discovery.

Future 04C4 owns what happens after somebody wants the item.

---

# 18. No Project linkage yet

Do not add:

```text
project_id
project_resource_need_id
contribution_offer_id
```

to standalone listing rows.

Project resources/contributions remain a separate later slice because:

- a Project can need resources without a marketplace listing;
- a person can offer resources as part of participation;
- standalone Scambio-Dona items can exist without a Project.

Future matching may connect these domains without making them the same record.

---

# 19. No media yet

Do not add:

- image URLs;
- storage buckets;
- upload metadata;
- attachment tables.

Plan 08 owns the production media/storage decision.

04C2 mobile UI can initially show text-only listings.

---

# 20. No saved-search/matching notifications yet

Do not add:

```text
saved searches
matching jobs
resource match notifications
```

The `resource_listing.published` identifier-only event is enough future integration groundwork.

The existing notification categories `matching` and `resources` must remain unmapped in 04C1.

Do not fabricate notification semantics.

---

# 21. Database constraints/indexes

Add indexes supporting actual first-slice access patterns.

Likely useful:

```text
owner_profile_id, created_at DESC, id DESC
published_at DESC, id DESC WHERE published
listing_mode, published_at DESC, id DESC WHERE published
locality, published_at DESC, id DESC WHERE published
```

For simple substring search, do not install a new extension solely for optimization unless repository evidence justifies it.

A later performance plan may improve search indexing.

Prioritize correctness and portability.

---

# 22. Structural pgTAP

Add tests for:

- canonical listing table;
- UUID PK;
- owner FK;
- allowed modes exactly donate/exchange;
- lifecycle exactly draft/published/closed;
- timestamp constraints;
- title/description bounds;
- rough-location bounds;
- RLS enabled;
- direct grants fail closed;
- expected public/owner RPCs;
- no transaction/request tables introduced;
- no media fields;
- no Project FK;
- no price/loan/return semantics.

---

# 23. Access/behavior pgTAP

Test:

## Draft

- owner complete profile can create;
- incomplete profile denied where required;
- cross-identity denied;
- draft not public;
- draft editable.

## Publication

- incomplete draft cannot publish;
- valid draft publishes;
- public discovery/detail sees it;
- already-published idempotency if chosen;
- outbox/audit identifier-only.

## Published edits

- owner can edit;
- result remains publishable;
- other user denied;
- changes appear publicly.

## Close

- owner closes;
- closed disappears from public list/detail;
- remains in owner history;
- second/invalid close follows deterministic lifecycle behavior;
- no “successful exchange/donation” state is invented.

## Discovery

- mode filter;
- locality filter;
- keyword title match;
- keyword description match;
- nonmatch excluded;
- stable newest-first keyset;
- paired cursor validation;
- anon and authenticated see same public listing data.

## Privacy

- public detail respects owner display-name visibility;
- Auth email never exposed;
- no exact/private location/contact data.

---

# 24. Real local integration

Add:

```text
scripts/verify-local-resource-listings.mjs
```

or equivalent.

Use at least owners A/B and anonymous/public client.

Prove:

1. A creates incomplete draft;
2. anon cannot see it;
3. cross-account B cannot edit/read private owner form;
4. incomplete publish rejected;
5. A completes and publishes a `donate` listing;
6. anonymous discovery/detail sees only safe fields;
7. owner public display-name visibility is respected;
8. A publishes an `exchange` listing;
9. mode filtering distinguishes them;
10. locality filtering works;
11. keyword search over title/description works;
12. keyset ordering/pagination is stable;
13. A edits published content safely;
14. A closes listing;
15. closed listing disappears publicly but remains in owner history;
16. outbox/audit payloads contain no description/location/contact text.

Do not print private profile data or secrets.

Wire into Database CI.

---

# 25. Generated types

Regenerate committed public database types.

Expected public contracts:

- create/update/publish/close owner RPCs;
- owner list/detail;
- public list/detail.

No private helper APIs leak into client types.

Zero drift required.

---

# 26. Documentation

Update:

- architecture/product decision docs;
- database development docs;
- roadmap;
- relevant README.

Document explicitly:

```text
Scambio-Dona listing_mode is only a discovery intent in 04C1.
```

And:

```text
exchange does NOT yet define loan/barter/return/payment/handoff mechanics.
```

Also record:

- no resource taxonomy yet;
- no media yet;
- no Project linkage yet;
- no saved-search/matching yet;
- rough public location only.

---

# 27. Roadmap reconciliation

First record 06D as merged:

```text
06D — Implemented
PR #31
merge commit 2197576acb47bd7cd0dd42a7f10987d7522caea5
```

06 remains `In progress` because 06C2B is externally blocked/not started.

Split 04C:

```text
04C — Resources + Scambio-Dona — In progress

04C1 — Scambio-Dona Listing Domain Foundation
  Status: In progress while PR open

04C2 — Scambio-Dona Mobile Discovery and Owner Experience
  Status: Not started
  Depends on 04C1

04C3 — Project Resource Needs and Contribution Offers
  Status: Not started
  Depends on 04A/04B1/05A

04C4 — Listing Requests/Handoff + Saved Search/Matching
  Status: Not started
  Depends on 04C1 and founder decisions
```

Update 05C dependency so future verified contribution work depends specifically on the Project-resource/contribution domain rather than unnecessarily blocking on all standalone listing UX.

Keep:

```text
06C2B — Not started / external provider context required
08 — Not started
09+ — Not started
```

Do not mark 04C implemented after 04C1.

---

# 28. External context

No external provider/account context is needed for 04C1.

Do not wait for:

- Firebase;
- Cloudflare;
- production self-hosting;
- storage provider decision;
- payment provider;
- legal handoff terms.

This slice should be fully local/CI testable.

---

# Non-goals

Do not implement:

- mobile Scambio-Dona screens;
- public web listing UI;
- resource taxonomy/categories;
- photos/media;
- map discovery;
- exact handoff location;
- contact exchange;
- claim/request/reservation;
- lending;
- barter;
- return tracking;
- payment/price;
- quantity/stock;
- Project resource needs;
- contribution offers;
- saved searches;
- matching;
- notifications;
- badges/stats;
- moderation.

---

# Acceptance criteria

04C1 is ready when:

- [ ] based on latest merged main containing PR #31;
- [ ] exact prompt archived;
- [ ] 04C roadmap split documented;
- [ ] listing entity exists;
- [ ] modes are exactly donate/exchange;
- [ ] exchange is documented as discovery intent only;
- [ ] lifecycle is draft/published/closed;
- [ ] close is not treated as successful transfer;
- [ ] title/description + rough location foundation exists;
- [ ] no resource taxonomy invented;
- [ ] no transaction/handoff schema introduced;
- [ ] no Project linkage introduced;
- [ ] no media fields introduced;
- [ ] owner mutations are expected-identity-bound;
- [ ] public discovery is available to anon/authenticated;
- [ ] drafts/closed never appear publicly;
- [ ] public detail obeys profile display-name visibility;
- [ ] mode/locality/keyword filters work;
- [ ] public pagination is stable keyset pagination;
- [ ] publish/close audit/outbox events are identifier-only;
- [ ] RLS/grants are fail closed;
- [ ] pgTAP passes;
- [ ] real local integration passes;
- [ ] generated types zero drift;
- [ ] Database/Mobile/Web/Site regressions remain green;
- [ ] no native QA claimed;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact SQL object/function names;
- exact reasonable text bounds if repository conventions suggest small adjustments;
- whether public cards return full bounded description or a DB-derived excerpt;
- exact simple keyword implementation;
- exact indexes;
- whether published mode changes are allowed if all invariants remain satisfied.

Stop and report before:

- defining what `exchange` legally/operationally means;
- adding loan/barter/payment/return fields;
- adding requests/claims/reservations;
- creating a resource taxonomy;
- adding exact handoff/contact data;
- implementing media/storage;
- linking standalone listings directly to Projects;
- implementing matching/saved-search notifications;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 04C1 prompt;
2. canonical Scambio-Dona listing schema;
3. owner create/update/publish/close lifecycle;
4. owner list/detail reads;
5. anonymous public list/detail;
6. mode/locality/keyword discovery;
7. rough-location privacy;
8. public owner-display visibility behavior;
9. identifier-only audit/outbox events;
10. structural/access pgTAP tests;
11. real local listing integration;
12. generated DB types;
13. documentation/roadmap split;
14. focused PR, preferably `codex/04c1-scambio-dona-listing-foundation`;
15. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **06D roadmap reconciliation**
5. **04C roadmap split**
6. **Listing schema**
7. **Mode semantics**
8. **Lifecycle semantics**
9. **Content validation**
10. **Rough-location model**
11. **Owner identity/privacy**
12. **Create draft**
13. **Update**
14. **Publish**
15. **Close**
16. **Owner reads**
17. **Public list**
18. **Keyword/mode/locality filters**
19. **Public detail**
20. **Owner display-name visibility**
21. **Pagination**
22. **Audit/outbox**
23. **RLS/grants/security**
24. **Explicit deferred transaction semantics**
25. **Explicit deferred taxonomy/media/Project linkage**
26. **pgTAP tests**
27. **Real local integration**
28. **Generated types/drift**
29. **Regression validation**
30. **Documentation updates**
31. **Warnings/blockers**
32. **Commit/PR reference**

