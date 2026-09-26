# PLANETS 04C4F3B1 — Immediate Saved-Search Match Notification Projection

**Roadmap area:** 04C4F3 — Saved-Search Matching Notifications  
**Task type:** Backend notification + push-job projection  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #91 — 04C4F3A Saved-Search New-Listing Match Projection
branch: codex/04c4f3a-saved-search-match-projection
head:   2f3334568421e63f608c032628ae2612227d7f6d
```

PR #91 is draft and stacked on PR #90/#89/#88/#87/#84/#83. Do not merge any dependency.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #91 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #91 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4f3b1-immediate-match-notifications
```

Open against:

```text
codex/04c4f3a-saved-search-match-projection
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4F3B1_immediate_saved_search_match_notification_projection.md
```

No external document is required.

---

# Product decision now fixed

Saved-search match alerts use the simple eBay-style first version:

```text
new matching Resource listing published
→ immediate notification eligibility
→ one notification for that new listing
```

No digest.

No daily batching.

No user-selectable frequency.

“Immediate” here means:

```text
resource_saved_search.matched becomes available immediately
→ notifications.v1 may project an in-app row immediately
→ push.v1 may project an immediately available push job
```

Actual provider delivery still depends on the existing/future push worker/provider path; F3B1 must not claim OS push delivery that 06C2B has not implemented.

---

# 1. One notification per listing, not per saved search

F3A deliberately keeps:

```text
one match fact / match event per saved search
```

because the underlying provenance matters.

However if the same listing matches two saved searches owned by the same user:

```text
Search A → listing X
Search B → listing X
```

user-visible delivery must be:

```text
ONE matching notification for listing X
ONE matching push job for listing X
```

not two.

Deduplicate only at delivery/projection.

Do not collapse or delete the underlying F3A match facts/events.

---

# 2. Existing notification semantics to activate

Use the matching semantics already anticipated by the push foundation:

```text
category_slug     = matching
notification_kind = matching_available
destination_kind  = matching_result
```

Do not introduce a second competing naming scheme.

`matching_result` currently resolves to a matched Resource listing in this first implementation.

---

# 3. No mobile work in B1

B1 is backend-only.

Do not modify Flutter notification parsing/copy/preferences/routes here.

04C4F3B2 will consume the B1 contract.

---

# 4. No saved-search notification columns

Do not copy saved-search query/locality/filter text into:

```text
public.notifications
private.push_delivery_jobs
```

Do not add public notification columns for:

```text
saved_search_id
saved_search_match_id
```

The source outbox event and private F3A fact provide trusted provenance.

User-visible semantic context requires only:

```text
recipient
Resource listing
matching category/kind/destination
source chronology
```

---

# 5. Matching notification row shape

A saved-search match notification must have:

```text
category_slug = matching
notification_kind = matching_available
destination_kind = matching_result

recipient_profile_id != null
resource_listing_id != null

actor_profile_id = null

project_id = null
request_id = null
membership_id = null
chat_id = null
message_id = null

resource_request_id = null
resource_chat_id = null
resource_chat_message_id = null
resource_agreement_id = null
resource_agreement_event_id = null
```

No actor is needed.

The listing owner is not the “actor” of the saved-search alert.

---

# 6. Matching push-job shape

Provider-neutral push job uses the same semantic shape:

```text
category_slug = matching
notification_kind = matching_available
destination_kind = matching_result
resource_listing_id != null
```

All Project/request/chat/agreement references null.

No listing title/body is copied into the job.

---

# 7. Resolver helper

Add a private resolver equivalent to:

```text
private.resolve_saved_search_matching_notification_event(
  p_outbox_event_id uuid
)
```

returning the same provider-neutral row shape consumed by:

```text
private.resolve_notification_event
```

No client/service direct execute grant unless existing resolver conventions require service access indirectly through the public projector.

---

# 8. Exact source-event payload

Support only:

```text
resource_saved_search.matched
```

with exact identifier-only payload:

```text
saved_search_match_id
saved_search_id
recipient_profile_id
listing_id
```

Require exactly these keys.

Parse all as UUID.

Unexpected/missing/additional keys → `55000`.

---

# 9. Canonical match resolution

Resolve:

```text
private.resource_saved_search_listing_matches
```

using:

```text
saved_search_match_id
```

Then resolve current:

```text
public.resource_saved_searches
public.resource_listings
```

Validate canonical identities:

```text
payload saved_search_id == fact.saved_search_id
payload recipient_profile_id == fact.recipient_profile_id
payload listing_id == fact.listing_id

saved_search.id == fact.saved_search_id
saved_search.profile_id == fact.recipient_profile_id
listing.id == fact.listing_id

source_event.created_at == fact.matched_at
```

Do not trust payload-only context.

---

# 10. Missing fact is legitimate suppression

If the F3A private match fact no longer exists because the saved search was deleted:

```text
return zero resolved rows
```

Do not raise.

Do not reconstruct from the outbox payload.

This is the intended F3A→B handoff.

---

# 11. Stale saved-search version suppression

Require:

```text
saved_search.updated_at = fact.saved_search_updated_at
```

If not:

```text
return zero rows
```

An edited saved search must not receive an alert created for its previous definition.

---

# 12. Current listing must remain published

Require at delivery-resolution time:

```text
listing.lifecycle_state = published
```

If closed:

```text
return zero rows
```

Do not generate a notification that immediately routes to an unavailable public listing.

---

# 13. Re-evaluate current filter match

Even if F3A matched the listing at publication time, published listing content is editable.

Before delivery require current listing fields still satisfy the unchanged current saved search via:

```text
private.resource_listing_matches_saved_search_filters(...)
```

using:

```text
listing.listing_mode
listing.title
listing.description
listing.locality

saved_search.listing_mode
saved_search.query
saved_search.locality
```

If it no longer matches:

```text
return zero rows
```

This avoids stale alerts after listing edits.

---

# 14. Self-owner fail-safe

Require:

```text
saved_search.profile_id <> listing.owner_profile_id
```

F3A already suppresses self-owned matches.

If an inconsistent fact violates that invariant:

```text
fail visibly
```

rather than creating an alert.

---

# 15. Resolved matching row

For a valid current match return exactly one semantic row:

```text
category_slug = matching
notification_kind = matching_available
recipient_profile_id = fact.recipient_profile_id
actor_profile_id = null

all Project references = null
resource_listing_id = fact.listing_id
all other Resource references = null

destination_kind = matching_result
source_created_at = source_event.created_at
```

---

# 16. Extend shared resolver

Extend:

```text
private.resolve_notification_event
```

so:

```text
resource_saved_search.matched
```

routes to the new matching resolver.

Existing Participation, Chat, Resource request/chat/exchange behavior must remain unchanged.

---

# 17. Historical F3A match events: no notification backfill

At B1 migration time:

For every pre-existing:

```text
resource_saved_search.matched
```

write:

```text
notifications.v1
push.v1
```

consumer receipts.

Do not create historical alerts or push jobs.

Immediate notifications begin from the B1 rollout boundary.

This mirrors previous notification-domain rollout behavior.

---

# 18. Extend notification source index

Extend the notification-source partial index to include:

```text
resource_saved_search.matched
```

Do not remove prior source event types.

---

# 19. Extend notifications schema

Evolve current constraints forward.

Add allowed:

```text
notification_kind = matching_available
destination_kind = matching_result
```

Category relation:

```text
category_slug = matching
↔
notification_kind = matching_available
```

Destination relation:

```text
matching_available
↔
matching_result
```

---

# 20. Matching reference shape

Extend `notifications_reference_shape_valid` with a dedicated matching branch.

Matching row requires:

```text
category_slug = matching
notification_kind = matching_available
destination_kind = matching_result

resource_listing_id not null

actor/project/request/membership/chat/message null
resource request/chat/agreement references null
```

Do not weaken existing Participation/Chat/Resources shape checks.

---

# 21. One in-app notification per recipient/listing

Add a partial unique index equivalent to:

```text
UNIQUE(
  recipient_profile_id,
  resource_listing_id,
  notification_kind
)
WHERE category_slug = 'matching'
  AND notification_kind = 'matching_available'
```

This deduplicates:

```text
same listing
+ same recipient
+ multiple matching saved searches
```

Do not deduplicate different listings.

---

# 22. Matching notification insertion conflict handling

Current notification projector uses a targeted conflict clause on:

```text
(source_outbox_event_id, recipient_profile_id, notification_kind)
```

That does not catch the new cross-source recipient/listing uniqueness.

Therefore special-case matching insertion or otherwise safely support both uniqueness boundaries.

Preferred:

## Matching rows

```text
INSERT ...
ON CONFLICT DO NOTHING
```

then inspect row count.

## Existing categories

Preserve their current targeted idempotency behavior.

Do not globally hide unexpected uniqueness bugs in unrelated categories.

---

# 23. Suppressed duplicate accounting

When a valid matching source resolves but an existing matching notification already exists for the same recipient/listing:

```text
inserted_count = 0
```

count it as:

```text
notifications_suppressed += 1
```

or another clearly documented suppression count consistent with projector return semantics.

Still receipt that source event.

---

# 24. Matching preference — in-app

Use existing category:

```text
notification_categories.slug = matching
```

and current effective preference resolution:

```text
profile override
or category default
```

No new preference table/column.

If effective:

```text
in_app_enabled = false
```

create no notification and count suppressed.

Receipt the source event normally.

---

# 25. Immediate in-app behavior

No scheduling/digest state.

For valid unsuppressed match event:

```text
public.process_notification_outbox_batch
```

creates notification as soon as that available event is processed.

Notification:

```text
created_at = source match event created_at
```

which preserves listing-publication chronology from F3A.

---

# 26. Push-job constraint update

Evolve:

```text
push_delivery_jobs_resource_shape_valid
```

so Resource-linked context may be used by:

```text
category = resources
```

with the existing Resource shapes **or**

```text
category = matching
kind = matching_available
destination = matching_result
resource_listing_id != null
all other Resource refs null
actor/project refs null
```

For unrelated categories, Resource references remain null.

Do not weaken Resource-category invariants.

---

# 27. One push job per recipient/listing

Add partial unique index analogous to notifications:

```text
recipient_profile_id
resource_listing_id
notification_kind

WHERE category_slug = matching
  AND notification_kind = matching_available
```

This prevents duplicate push jobs when one listing matches multiple saved searches.

---

# 28. Matching push insertion conflict handling

As with in-app notifications:

Matching push insertion must safely handle:

```text
source-event idempotency
+
recipient/listing dedupe
```

without causing a unique-violation failure.

Special-case matching `ON CONFLICT DO NOTHING`.

Preserve existing behavior for unrelated categories.

---

# 29. Suppressed push duplicate accounting

If the same recipient/listing already has a matching push job:

```text
jobs_suppressed += 1
```

Still receipt the match source event for `push.v1`.

---

# 30. Matching preference — push

Use existing effective:

```text
matching.push_enabled
```

No per-search push toggle.

If disabled:

```text
no push job
source receives push.v1 receipt
```

---

# 31. Immediate push eligibility

For a valid match event with push enabled:

```text
push job available_at = statement_timestamp()
```

following the current push projector convention.

No digest delay.

Do not implement Firebase/provider delivery here.

---

# 32. Existing push protocol compatibility

Do not break the existing generic push protocol fixtures using:

```text
category = matching
notification_kind = matching_available
destination_kind = matching_result
```

Those placeholders should now align with real matching semantics.

Update tests only where the new stricter matching Resource-listing shape requires fixture context.

Do not weaken production constraints solely to preserve synthetic tests.

---

# 33. Public notification inbox projection

Existing:

```text
list_own_notifications
```

already returns:

```text
resource_listing_id
resource_listing_title
```

No signature extension should be necessary.

Ensure matching notifications safely return:

```text
resource_listing_id
resource_listing_title
```

with Project/actor/request/agreement fields null.

Do not expose saved-search filters.

---

# 34. Listing title behavior

Inbox can resolve current:

```text
resource_listing_title
```

from the listing table.

Do not snapshot title into notification row.

If title later changes while listing remains published, inbox may show the current title, consistent with current Resource notification projection behavior.

B2 will localize copy from this safe title.

---

# 35. Notification survives later saved-search deletion

Once an in-app notification was validly created:

```text
saved search later deleted
```

does not need to delete historical notification row.

The source match was valid at delivery time.

Do not add a notification→saved-search FK.

---

# 36. Notification survives later listing closure

A notification may remain in inbox history after the listing is later closed.

Do not delete notification history.

B2's destination may then open a Resource detail that reports unavailable/not found through existing behavior.

The resolver only prevents stale creation when closure happened **before** projection.

---

# 37. Resolver privacy

Do not expose:

```text
saved search query
locality
saved-search match ID
listing description
owner contact
loan reservations
```

through resolver/projector rows.

Only safe semantic listing ID reaches notification/push context.

---

# 38. Structural pgTAP

Cover:

- matching kind allowed;
- matching destination allowed;
- category↔kind invariant;
- kind↔destination invariant;
- exact matching reference shape;
- notification recipient/listing dedupe index;
- push recipient/listing dedupe index;
- matching resolver exists/private/fixed path;
- shared resolver routes match source;
- notification/push projectors include source type;
- historical notifications/push receipts;
- matching category catalog reused, not recreated.

---

# 39. Resolver pgTAP — valid match

Create:

```text
current saved search
current F3A fact
published matching listing
resource_saved_search.matched source
```

Resolver returns one row:

```text
matching
matching_available
matching_result
correct recipient
correct listing
null actor/project/request/chat/agreement refs
source chronology
```

---

# 40. Resolver pgTAP — deleted fact/search

Cover:

```text
fact missing due deleted search
→ zero rows
```

No guessed notification.

---

# 41. Resolver pgTAP — stale search version

Current saved search updated after fact:

```text
updated_at != saved_search_updated_at
→ zero rows
```

---

# 42. Resolver pgTAP — listing closure

Listing closed before notification projection:

```text
→ zero rows
```

---

# 43. Resolver pgTAP — listing no longer matches

Edit published listing so its current fields fail the saved-search predicate.

Expected:

```text
→ zero rows
```

---

# 44. Resolver pgTAP — payload mismatch

Wrong:

```text
saved_search_match_id
saved_search_id
recipient_profile_id
listing_id
```

or additional/missing keys:

```text
→ 55000
```

No receipt after projector transaction failure.

---

# 45. In-app immediate projection pgTAP

With matching in-app enabled:

```text
match event
→ process_notification_outbox_batch
→ one notification
→ notifications.v1 receipt
```

Notification chronology equals match event chronology.

---

# 46. In-app preference suppression pgTAP

Matching in-app disabled:

```text
zero notification
one notifications.v1 receipt
suppressed count
```

No later backfill merely by re-enabling.

---

# 47. Multi-search same-listing dedupe pgTAP

Same user owns two saved searches both matching one listing.

F3A creates two match events.

Notification projector processes both.

Expected:

```text
ONE matching notification
TWO notifications.v1 source receipts
```

Second duplicate is safely suppressed.

---

# 48. Different listings remain distinct

One search matches two separately published listings.

Expected:

```text
TWO notifications
```

No over-deduplication.

---

# 49. Push immediate projection pgTAP

With push enabled:

```text
match event
→ process_push_outbox_batch
→ one matching push job
→ push.v1 receipt
```

No provider network call.

---

# 50. Push preference suppression pgTAP

Matching push disabled:

```text
zero push job
push.v1 receipt
suppressed count
```

---

# 51. Multi-search push dedupe pgTAP

Two saved searches same user/listing:

```text
ONE push job
TWO push.v1 source receipts
```

---

# 52. Channel independence

For one source match event:

```text
in-app disabled
push enabled
```

must produce:

```text
no notification
one push job
both independent receipts
```

And vice versa.

No channel derives eligibility from the other's rows.

---

# 53. Historical no-backfill pgTAP

Pre-B1 `resource_saved_search.matched` events:

```text
notifications.v1 receipt
push.v1 receipt
zero notification
zero push job
```

Future event projects normally.

---

# 54. Projector idempotency

Repeated notification/push batch calls:

```text
no duplicate rows/jobs
no duplicate receipts
```

---

# 55. Concurrency

Concurrent `notifications.v1` workers and concurrent `push.v1` workers:

- use existing `FOR UPDATE SKIP LOCKED`;
- process each source once per consumer;
- cannot create duplicate recipient/listing delivery.

Include focused concurrency verification where practical.

---

# 56. Real service/OTP verifier

Extend/add focused verifier:

1. create recipient + listing owner identities;
2. create two saved searches that both match one listing;
3. publish listing;
4. run F3A;
5. run notification projector;
6. verify one in-app notification;
7. run push projector;
8. verify one push job;
9. verify both match-source receipts for both channels;
10. test matching preference suppression independently;
11. stale search edit suppression;
12. search deletion suppression;
13. listing edit no-longer-match suppression;
14. listing close suppression;
15. no private saved-search content in notifications/jobs/events.

Never log OTP/tokens/private filter content except controlled fixture assertions.

---

# 57. Generated types

Regenerate/update generated DB types only for changed public API signatures, if any.

If no public RPC signature changes, type file may legitimately remain unchanged.

Do not hand-edit unrelated inherited D1 type drift.

Report current drift honestly.

---

# 58. Documentation / roadmap

Update:

```text
04C4F3A — PR #91
04C4F3B — Immediate Saved-Search Notifications

04C4F3B1 — Backend Immediate Notification Projection
  this PR

04C4F3B2 — Mobile Matching Notification UX
  next
```

Document fixed policy:

```text
immediate, not digest
one user-visible alert per new matching listing
multiple saved searches do not duplicate delivery
global Matching category controls channels
no per-search mute yet
```

---

# 59. B2 handoff contract

B2 will receive inbox rows with:

```text
category_slug = matching
notification_kind = matching_available
destination_kind = matching_result

resource_listing_id
resource_listing_title
```

Everything else unrelated is null.

B2 should:

- parse matching category/kind/destination strictly;
- copy: “New listing matches one of your saved searches: {title}”;
- tap → existing `/resources/:listingId`;
- add Matching in-app toggle to preferences;
- preserve current stored push value;
- not add provider/push-toggle UX unless 06C2B later owns it.

---

# 60. No per-search notification toggle

B1 does not alter F1 saved-search schema.

All saved searches participate in immediate matching delivery.

The global:

```text
matching
```

notification preference controls delivery channels.

Per-search mute/alert controls are future refinement, not MVP F3B.

---

# 61. Validation

Run repository equivalents:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

node --check <matching notification verifier>
npm run check:web
npm run check:site
npm run check:mobile
git diff --check
```

Run focused F3A/F3B1 notification/push pgTAP and service verification.

Attempt hosted Validation once.

If GitHub cannot allocate a runner because of the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Do not merge until B1 and inherited required DB gates are either green or explicitly dispositioned under repository policy.

---

# Non-goals

Do not implement:

- Flutter notification UI changes;
- digest;
- scheduled batching;
- notification frequency enum;
- per-search notification toggle;
- Firebase/APNs provider send;
- push permission UI;
- saved-search match history UI;
- Project matching notifications;
- Project-linked saved searches;
- loan availability alerts;
- taxonomy/radius;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #91;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] immediate policy documented;
- [ ] matching category reused;
- [ ] `matching_available` kind activated;
- [ ] `matching_result` destination activated;
- [ ] exact matching notification shape enforced;
- [ ] matching push-job shape enforced;
- [ ] resolver validates F3A source/fact/search/listing;
- [ ] deleted match/search suppresses safely;
- [ ] stale search version suppresses;
- [ ] closed listing suppresses;
- [ ] current listing must still match saved filter;
- [ ] self-owner invariant validated;
- [ ] historical match events receipted without backfill;
- [ ] notification projector consumes future match events;
- [ ] push projector consumes future match events;
- [ ] existing matching category preferences control each channel;
- [ ] one notification per recipient/listing;
- [ ] one push job per recipient/listing;
- [ ] multiple saved searches retain underlying facts/events;
- [ ] duplicate source events are individually receipted;
- [ ] different matching listings each notify;
- [ ] channel independence preserved;
- [ ] no saved-search text copied to notification/push;
- [ ] no provider network send;
- [ ] focused pgTAP/concurrency/service verifier;
- [ ] generated-type state honest;
- [ ] no B2 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4F3B1 branch/base/PR
3. Changed files
4. Immediate-policy implementation
5. Matching notification semantics
6. Matching notification row shape
7. Matching push-job shape
8. Matching resolver helper
9. Source-payload validation
10. Canonical match/search/listing validation
11. Missing-fact suppression
12. Stale-search suppression
13. Listing-lifecycle suppression
14. Current-filter revalidation
15. Self-owner fail-safe
16. Shared resolver integration
17. Historical no-backfill behavior
18. Notification schema constraints
19. Notification recipient/listing dedupe
20. Notification insertion conflict handling
21. In-app matching preference behavior
22. Immediate in-app chronology
23. Push schema constraints
24. Push recipient/listing dedupe
25. Push insertion conflict handling
26. Push preference behavior
27. Immediate push-job eligibility
28. Existing push-protocol compatibility
29. Inbox projection fields
30. Privacy guarantees
31. Structural pgTAP
32. Resolver pgTAP
33. In-app projection pgTAP
34. Multi-search notification dedupe pgTAP
35. Push projection/dedupe pgTAP
36. Preference/channel-independence pgTAP
37. Historical/idempotency pgTAP
38. Concurrency coverage
39. Real service/OTP verifier
40. Generated types/drift
41. Local regression validation
42. Hosted Validation executed/not-executed
43. Inherited DB-gate status
44. 04C4F3B2 handoff
45. Per-search-toggle boundary
46. Warnings/blockers
47. Commit/PR reference

Do not merge any PR.

