# PLANETS 04C4F3A — Saved-Search New-Listing Match Projection

**Roadmap area:** 04C4F — Saved Searches + Matching Notifications  
**Task type:** Backend/domain event projection foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #90 — 04C4F2 Mobile Saved Resource Search UX
branch: codex/04c4f2-mobile-saved-resource-searches
head:   94705a1225519af81987dc530c0f56a8a60509ad
```

PR #90 is draft and stacked on PR #89/#88/#87/#84/#83. Current-stack database replay/lint/advisors/pgTAP/OTP/type-drift gates remain unresolved.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #90 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #90 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4f3a-saved-search-match-projection
```

Open against:

```text
codex/04c4f2-mobile-saved-resource-searches
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4F3A_saved_search_new_listing_match_projection.md
```

No external document is required.

---

# Why F3 is split

Notification frequency is still a product decision.

Do **not** choose yet between:

```text
immediate alert
daily digest
periodic digest
user-selectable frequency
```

Split:

```text
04C4F3 — Saved-Search Matching Notifications (parent)

04C4F3A — Saved-Search New-Listing Match Projection
  this plan
  frequency-neutral durable matching facts/events

04C4F3B — Matching Notification Policy + Mobile UX
  later
  immediate/digest policy
  notification projection/copy/preferences
  mobile notification controls
```

F3A must be reusable by any F3B policy without schema redesign.

---

# Objective

Consume future canonical:

```text
resource_listing.published
```

outbox events and determine which existing personal saved searches matched the newly published listing **at publication time**.

For each eligible match:

```text
published listing event
        ↓
current saved-search definition existed before publication
        ↓
F1 predicate matches listing
        ↓
private durable match fact
        ↓
identifier-only resource_saved_search.matched outbox event
```

F3A creates **no user notification**.

---

# 1. Source event

Consume only:

```text
resource_listing.published
```

from:

```text
private.outbox_events
```

Use an independent consumer receipt key:

```text
saved-search-matching.v1
```

Do not use `notifications.v1`, `push.v1`, or outbox `published_at` as this consumer's acknowledgement.

---

# 2. Historical source events must not backfill

At migration time, receipt all pre-existing:

```text
resource_listing.published
```

events for:

```text
saved-search-matching.v1
```

without generating saved-search matches.

Reason: saved searches mean “new listings from now on”, not retroactive matching against old publication events.

Use the same explicit historical-backfill boundary pattern already used by notification consumers.

---

# 3. Frequency-neutral match fact

Add a private durable table equivalent to:

```text
private.resource_saved_search_listing_matches
```

Suggested columns:

```text
id uuid primary key
source_outbox_event_id uuid not null
saved_search_id uuid not null
saved_search_updated_at timestamptz not null
recipient_profile_id uuid not null
listing_id uuid not null
matched_at timestamptz not null
```

This is internal projection state/provenance, not a public match-results feature.

---

# 4. Foreign keys / deletion behavior

Recommended:

```text
source_outbox_event_id
→ private.outbox_events(id)
ON DELETE RESTRICT

saved_search_id
→ public.resource_saved_searches(id)
ON DELETE CASCADE

recipient_profile_id
→ public.profiles(id)
ON DELETE CASCADE

listing_id
→ public.resource_listings(id)
ON DELETE RESTRICT
```

If a user deletes a saved search before F3B delivers an alert, its private match facts disappear and F3B must safely suppress the now-orphaned identifier event.

Do not prevent saved-search deletion because of pending match projection.

---

# 5. Match uniqueness

Enforce:

```text
UNIQUE(saved_search_id, listing_id)
```

and source-provenance uniqueness equivalent to:

```text
UNIQUE(source_outbox_event_id, saved_search_id)
```

One publication/listing creates at most one fact per saved search.

No duplicate facts on retries.

---

# 6. Match timestamp

Set:

```text
matched_at = source resource_listing.published event created_at
```

not projector wall-clock time.

This represents when the listing actually appeared.

---

# 7. Saved-search version token

Copy:

```text
saved_search.updated_at
```

into:

```text
saved_search_updated_at
```

at match creation.

This is not saved-search history. It is a version token for F3B.

Before later user-visible delivery, F3B can require:

```text
current saved search exists
AND current updated_at == match.saved_search_updated_at
```

so an edited search does not receive an old-definition alert.

---

# 8. Event-time eligibility

A saved search is eligible only if:

```text
saved_search.updated_at <= source_event.created_at
```

Critical consequences:

## Search created after listing publication

No retroactive match.

## Search edited after listing publication but before delayed F3A processing

Skip the older source event.

Do not evaluate it against the newer definition and pretend that definition existed earlier.

---

# 9. Search update resets the future boundary

After `update_resource_saved_search(...)`, the new `updated_at` means only publication events at or after that timestamp may match the new definition.

Do not backfill old listings after editing a search.

---

# 10. Saved-search deletion

If the search is deleted before source processing:

```text
no match
```

No reconstruction or deleted-search history.

---

# 11. Reuse F1 predicate exactly

Use:

```text
private.resource_listing_matches_saved_search_filters(...)
```

for each eligible search.

Do not duplicate filter semantics.

Personal saved-search matching remains:

```text
literal case-insensitive query substring
exact case-insensitive locality
optional donate/exchange mode
```

Do not use the 04C4E Project lexical matcher.

---

# 12. Listing eligibility at projection time

Resolve the canonical listing row by ID.

Only create facts if it is currently:

```text
lifecycle_state = published
```

If a listing was published and then closed before delayed F3A processing:

```text
receipt source event
create zero matches
```

Do not create stale alert sources for unavailable listings.

---

# 13. Canonical source-event validation

Do not blindly trust source payload.

Resolve canonical listing and verify identifier facts from the event are consistent where applicable:

```text
listing_id
owner_profile_id
listing_mode
```

If payload/canonical identity is inconsistent:

```text
fail visibly
do not guess
do not receipt
```

A listing merely being closed later is not an identity inconsistency; it is valid zero-match suppression.

---

# 14. Self-owned listing suppression

Do not create a match when:

```text
saved_search.profile_id == listing.owner_profile_id
```

Users do not need alerts for their own newly published listing.

Manual Resource Browse remains unchanged and may still show own listing.

---

# 15. Private match facts only

Do not add client read RPCs for match facts in F3A.

No authenticated RLS policy.

No public match-history API.

Match facts are trusted backend projection state only.

---

# 16. Derived match outbox event

For every newly created match fact emit exactly one:

```text
resource_saved_search.matched
```

to:

```text
private.outbox_events
```

Identifier-only payload:

```text
saved_search_match_id
saved_search_id
recipient_profile_id
listing_id
```

Optionally include:

```text
source_listing_outbox_event_id
```

for provenance.

Do not include query, locality, listing title/description, email, or tokens.

---

# 17. Derived event chronology

Prefer:

```text
created_at = source listing-published event created_at
```

so downstream immediate/digest policy sees true publication chronology.

Do not replace source chronology with projector runtime.

---

# 18. Match event is not a notification

F3A must not insert into:

```text
public.notifications
private.push_delivery_jobs
```

and must not consult:

```text
matching in_app_enabled
matching push_enabled
```

Preference/frequency belongs to F3B.

---

# 19. Existing matching category

The notification catalog already has:

```text
matching
```

Do not modify it in F3A.

Do not add notification kinds yet.

---

# 20. Independent projector function

Add a service-role-only RPC equivalent to:

```text
process_resource_saved_search_matching_outbox_batch(
  p_limit integer default 100
)
```

Suggested return:

```text
processed_count integer
matches_created integer
matches_suppressed integer
```

No authenticated/anon execution.

---

# 21. Batch validation

Require:

```text
p_limit between 1 and 100
```

Invalid → `22023`.

---

# 22. Worker concurrency

Select eligible unreceipted source events:

```text
event_type = resource_listing.published
available_at <= statement_timestamp()
no saved-search-matching.v1 receipt
```

Order:

```text
created_at
id
```

Use:

```text
FOR UPDATE SKIP LOCKED
```

consistent with existing outbox consumers.

Multiple workers must not duplicate facts.

---

# 23. Source receipt timing

Write:

```text
saved-search-matching.v1
```

receipt only after the whole source-event fan-out succeeds.

This includes:

```text
zero saved searches
all nonmatching
self-owned-only
listing already closed
successful N-match fan-out
```

Mapping inconsistency/error:

```text
no receipt
transaction fails
retry remains possible
```

---

# 24. Zero-match events

A valid publication with zero eligible saved searches is still successfully processed.

Write consumer receipt.

Do not emit fake match events.

---

# 25. Atomicity

For each source event these must stay transactionally consistent:

```text
match facts
derived resource_saved_search.matched events
source consumer receipt
```

No receipt may claim success while some fan-out was lost.

---

# 26. Idempotency

Rollback retry is safe.

Committed response loss is safe because source receipt prevents reprocessing.

Uniqueness gives defense in depth.

---

# 27. Search edited after fact creation

F3A does not delete a prior fact merely because the search is later edited.

`saved_search_updated_at` records the matched definition version.

F3B must suppress delivery if current `updated_at` no longer equals it.

---

# 28. Search deleted after fact creation

Recommended FK cascade removes the private match fact.

Already-created identifier-only outbox event may remain.

F3B must resolve canonical match row and treat missing row as suppressed, not reconstruct state.

---

# 29. Listing closes after fact creation

F3B must revalidate:

```text
listing.lifecycle_state = published
```

before user-visible delivery.

F3A cannot retroactively retract all emitted identifier events.

---

# 30. No match-history UI

Do not build:

```text
Matched listings
Saved-search match history
```

client APIs/UI in F3A.

Saved search Open already runs current Browse results.

---

# 31. No Project coupling

Do not consume Project needs or 04C4E matcher.

This projector is only for personal F1 saved Resource Browse searches.

---

# 32. No private loan availability coupling

Do not inspect reservations, overdue, at-risk, or agreement terms.

Published Resource discovery remains the saved-search basis.

---

# 33. Consumer independence

`saved-search-matching.v1` processing must not create or require:

```text
notifications.v1
push.v1
```

receipts.

Existing notification/push receipts must not suppress F3A.

---

# 34. Source-event index

Add or extend a partial index if needed for efficient:

```text
resource_listing.published
```

available/unreceipted scanning.

Do not regress other consumer indexes.

---

# 35. Historical-receipt test

Verify pre-migration `resource_listing.published` events receive only the new consumer receipt and create no match facts.

Future events match normally.

---

# 36. Structural pgTAP

Cover:

- private match-fact table;
- columns/FKs;
- cascade/restrict behavior;
- uniqueness;
- no client grants;
- no public read RPC;
- derived event type;
- service-role processor;
- fixed search path;
- consumer key;
- historical receipt backfill;
- no notification-kind/schema modification.

---

# 37. Behavioral pgTAP — basic matching

Cover:

```text
query-only
mode-only
locality-only
all filters
```

Publish matching listing → fact + derived event.

Nonmatching search → none.

---

# 38. Multiple searches/recipients

One listing may match:

```text
multiple users
multiple saved searches for one user
```

Create one fact per matching saved search.

Do not collapse per user in F3A; F3B may later group notifications.

---

# 39. Self-owned suppression test

Own saved search matching own listing → zero fact.

Other users' matching searches still get facts.

---

# 40. Event-time creation test

Publication event first, saved search created later before projector runs.

Expected zero match because search did not exist at publication time.

---

# 41. Event-time update test

Saved search exists, listing published, saved search edited before delayed processing.

Expected zero match from older source event.

Do not use new definition retroactively.

---

# 42. Future event after update

After edit, publish a new listing matching the new definition.

Expected match with:

```text
saved_search_updated_at == current saved_search.updated_at
```

---

# 43. Deleted search test

Delete saved search before processing source event.

Expected zero match.

---

# 44. Closed listing before processing

Publish then close listing before F3A processor.

Expected source receipt + zero facts.

---

# 45. Payload validation test

Tampered/wrong payload identifiers:

```text
wrong owner
wrong mode
inconsistent listing identity
```

must fail with no receipt.

---

# 46. Identifier-only derived event test

Assert only allowed ID keys appear.

Fixture query/locality/title/description values must not appear in serialized match payload.

---

# 47. Consumer independence test

New consumer receipt neither creates nor requires `notifications.v1`/`push.v1`.

Existing receipts do not hide source event from F3A.

---

# 48. Idempotency test

Process same batch again.

Expected no duplicate facts/events and one receipt.

---

# 49. Batch bounds

Cover:

```text
1
100
0 / >100 → 22023
```

Verify source ordering.

---

# 50. Concurrency

Where feasible, run two service-role workers concurrently.

Expected:

```text
FOR UPDATE SKIP LOCKED
each source processed once
no duplicate facts/events
```

---

# 51. Real OTP/service verifier

Add focused verifier:

1. sign in multiple users;
2. create saved searches;
3. publish listings;
4. invoke F3A processor with trusted service client;
5. verify match/nonmatch;
6. self-owner suppression;
7. search-created-after-event suppression;
8. search-update event-time boundary;
9. closed-before-processing suppression;
10. idempotent second run;
11. identifier-only payload;
12. independent consumer receipts.

Never log OTP/tokens or private saved-search values beyond controlled fixture assertions.

---

# 52. Generated types

Update/regenerate public API types for the service-role processor if required.

Private match table does not need client-side mobile modeling.

Do not claim drift passed without a full clean replay.

`db:types:check` remains a hard pre-merge gate.

---

# 53. Validation wiring

Wire focused F3A pgTAP/verifier into repository validation conventions where appropriate.

Do not create hosted rerun loops while GitHub runner allocation is unavailable.

---

# 54. Documentation / roadmap

Update:

```text
04C4F1 — PR #89
04C4F2 — PR #90

04C4F3 — Saved-Search Matching Notifications
04C4F3A — New-Listing Match Projection
  this PR
04C4F3B — Notification Policy + Mobile UX
  later
```

Document:

```text
frequency-neutral
no historical listing backfill
search edits affect only future publications
self-owned listings suppressed
F1 predicate reused
identifier-only match event
```

---

# 55. F3B handoff contract

F3B consumes:

```text
resource_saved_search.matched
```

and resolves:

```text
private.resource_saved_search_listing_matches
current saved search
current listing
```

Before user-visible delivery require:

```text
match row still exists
saved search still exists
saved_search.updated_at == match.saved_search_updated_at
listing.lifecycle_state == published
```

Only then apply matching notification preference/frequency policy.

---

# 56. Frequency decision intentionally deferred

Do not add:

```text
frequency enum
digest scheduling
immediate notification
per-search notify toggle
matching notification kind
Flutter notification copy
```

in F3A.

Founder/user decision comes before F3B.

---

# 57. Validation

Run repository equivalents of:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

node --check <F3A verifier>
npm run check:web
npm run check:site
npm run check:mobile
git diff --check
```

Attempt focused service/OTP/concurrency verification.

Attempt hosted Validation once.

If GitHub cannot allocate a runner due the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

This DB-heavy PR must not merge until its own and inherited current-stack DB/type gates execute green.

---

# Non-goals

Do not implement:

- public/mobile match history;
- in-app notification rows;
- notification copy;
- matching preference UI;
- push jobs;
- immediate-vs-digest choice;
- digest scheduler;
- per-search alert toggle;
- Project matching notifications;
- Project-linked saved searches;
- loan availability matching;
- taxonomy/radius;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #90;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] independent `saved-search-matching.v1` consumer;
- [ ] historical listing events receipted without backfill;
- [ ] private durable match-fact table;
- [ ] saved-search version token captured;
- [ ] one match per saved-search/listing;
- [ ] no client match-fact access;
- [ ] F1 predicate reused exactly;
- [ ] only current published listings create facts;
- [ ] saved search must predate source event;
- [ ] search edits do not retroactively match older events;
- [ ] deleted search cannot match;
- [ ] self-owned listing suppressed;
- [ ] one identifier-only `resource_saved_search.matched` event per fact;
- [ ] no notification row;
- [ ] no push job;
- [ ] no matching preference consultation;
- [ ] source fan-out + receipt atomic;
- [ ] valid zero-match event still receipted;
- [ ] payload/canonical inconsistency fails without receipt;
- [ ] independent consumer receipts preserved;
- [ ] retries/concurrent workers idempotent;
- [ ] focused pgTAP/event-time/privacy/concurrency coverage;
- [ ] service/OTP verifier;
- [ ] generated types updated where executable;
- [ ] inherited DB blockers reported honestly;
- [ ] no F3B scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4F3A branch/base/PR
3. Changed files
4. Consumer/source event
5. Historical no-backfill receipt
6. Private match-fact table
7. Foreign-key/delete behavior
8. Match uniqueness
9. Match chronology
10. Saved-search version token
11. Event-time eligibility
12. Search-update boundary
13. Search-delete behavior
14. F1 predicate reuse
15. Listing lifecycle revalidation
16. Source payload validation
17. Self-owned suppression
18. Derived match outbox event
19. Identifier-only payload
20. Frequency-neutral boundary
21. Service-role processor
22. Worker locking/SKIP LOCKED
23. Source receipt timing
24. Zero-match handling
25. Atomicity/idempotency
26. Search-edited-after-match handoff
27. Search-deleted-after-match handoff
28. Listing-closed-after-match handoff
29. Consumer independence
30. Structural pgTAP
31. Basic matching pgTAP
32. Multi-search/recipient pgTAP
33. Self-owner pgTAP
34. Event-time create/update pgTAP
35. Delete/closed-listing pgTAP
36. Payload/privacy pgTAP
37. Idempotency/batch pgTAP
38. Concurrency coverage
39. Real OTP/service verifier
40. Generated types/drift
41. Local regression validation
42. Hosted Validation executed/not-executed
43. Inherited DB-gate status
44. 04C4F3B handoff
45. Frequency-decision status
46. Warnings/blockers
47. Commit/PR reference

Do not merge any PR.
