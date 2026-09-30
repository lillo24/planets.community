# PLANETS 04C4D1 — Loan Reservation + Conflict Domain

**Roadmap area:** 04C4D — Loan Availability / Queue  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #82 — 04C4C3D Mobile Resources Notification UX
branch: codex/04c4c3d-mobile-resource-notifications
head:   80b529570faef91b9f1fd6baff9a91f41afc4942
```

Before implementation:
1. fetch current `origin/main`;
2. verify PR #82 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #82 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4d1-loan-reservation-conflicts
```

Open against:

```text
codex/04c4c3d-mobile-resource-notifications
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4D1_loan_reservation_conflict_domain.md
```

No external document is required.

---

# Product decision now fixed

For the listing resource, mutually accepted **LEND** terms create a real reservation.

Use half-open periods:

```text
[start_at, end_at)
```

So adjacent periods are compatible while overlaps are forbidden.

Examples:

```text
A: Sep 21 10:00 → Sep 25 10:00
B: Sep 25 10:00 → Sep 28 10:00
→ compatible

A: Sep 21 10:00 → Sep 25 10:00
B: Sep 24 18:00 → Sep 28 10:00
→ conflict
```

Requests and unaccepted terms do not reserve time.

Queue semantics are **not FIFO**. The owner retains control over which requests and periods to accept. The schedule/queue is the chronological sequence of compatible mutually accepted reservations.

Pre-handoff cancellation releases the reservation.

A late return does not automatically cancel later reservations. Later reservations remain valid but may be derived as **at risk** while the previous loan is overdue/unreturned.

Recurring owner-defined availability such as “available every weekend” is deferred.

---

# Objective

Establish canonical reservation/conflict truth for the existing Scambio agreement domain without duplicating agreement state.

The existing accepted current terms already contain:

```text
owner_transfer_kind
owner_lend_starts_at
owner_lend_ends_at
```

Therefore derive reservation truth from:

```text
agreement.current_terms
+ owner_transfer_kind = lend
+ agreement.lifecycle in agreed / in_progress
= active listing reservation
```

Do **not** create a second mutable reservation ledger unless repository evidence shows a correctness need.

Agreement terms/events remain the canonical audit history.

---

# 1. Reservation scope

D1 reserves only the **listing-owner resource leg**, because `resource_listings.id` is the canonical resource identity today.

Do not globally reserve:

```text
requester_transfer_kind = lend
```

because that requester-side item is currently private free text, not another canonical listing/resource ID.

Document this boundary.

---

# 2. Active reservation definition

A reservation is active iff:

```text
agreement.lifecycle_state in ('agreed', 'in_progress')
AND agreement.current_terms_id is not null
AND current_terms.owner_transfer_kind = 'lend'
```

Interval:

```text
[current_terms.owner_lend_starts_at,
 current_terms.owner_lend_ends_at)
```

Not active:

```text
pending terms
negotiating agreement
current GIVE terms
completed agreement
cancelled agreement
```

---

# 3. No FIFO entitlement

Do not implement:

```text
first request wins
automatic queue position
automatic next-borrower promotion
```

Request timestamps do not create priority rights.

Conflict enforcement only guarantees that accepted reservations are compatible.

---

# 4. Overlap rule

Two reservations on the same listing conflict iff:

```text
candidate_start < existing_end
AND existing_start < candidate_end
```

Use half-open intervals.

Adjacent end/start is allowed.

Exclude the same agreement when checking replacement terms.

---

# 5. Enforce conflict when terms are accepted

Create one forward migration evolving the latest:

```text
accept_resource_exchange_terms(...)
```

Only when pending terms have:

```text
owner_transfer_kind = lend
```

perform conflict validation before promoting pending terms to current.

On conflict:

```text
PT409
```

and:

- do not change agreement pointers;
- do not emit `terms_accepted`;
- do not emit notification/outbox/Realtime side effects;
- do not partially alter reservation state.

---

# 6. Listing serialization anchor

Within terms acceptance:

1. lock the agreement as today;
2. load canonical request;
3. lock the associated listing row `FOR UPDATE`;
4. load/validate pending terms;
5. check other active reservations;
6. accept only if conflict-free.

The listing row is the shared serialization point across different agreements for one listed resource.

This prevents two overlapping candidate reservations from both observing “free”.

---

# 7. Concurrent acceptance

For same listing:

```text
A pending LEND: Sep 10–12
B pending LEND: Sep 11–13
```

Concurrent acceptances must result in:

```text
one success
one PT409
```

For:

```text
A: Sep 10–12
B: Sep 12–14
```

both may succeed after serialization.

Add deterministic concurrency tests.

---

# 8. Pre-handoff replacement

Existing 04C4B permits accepted terms replacement before handoff.

If current reservation is Sep 10–12 and replacement is Sep 15–17:

- exclude the same agreement's old current reservation;
- validate the new interval against all other active reservations;
- if accepted, the new current terms become the only canonical reservation.

Do not require old+new periods simultaneously.

---

# 9. LEND → GIVE replacement

If accepted replacement changes owner leg from:

```text
lend → give
```

the agreement no longer reserves time.

No separate “release reservation” write is necessary.

---

# 10. GIVE → LEND replacement

If replacement changes:

```text
give → lend
```

run full conflict validation before acceptance.

---

# 11. Cancellation releases reservation

Existing pre-handoff agreement cancellation changes lifecycle to `cancelled`; derived reservation disappears automatically.

Evolve `cancel_resource_exchange_agreement(...)` to lock the associated listing row `FOR UPDATE` using lock ordering consistent with terms acceptance.

This makes cancellation versus a waiting new reservation deterministic.

If cancellation commits first, a waiting acceptance can observe the released slot.

---

# 12. Completion releases reservation

Completed agreements are not active reservations.

Evolve `record_resource_exchange_milestone(...)` so reservation-relevant completion serializes with the same listing row before final lifecycle closure can release the slot.

Do not otherwise change milestone semantics.

---

# 13. Listing closure

Listing closure does **not** release an accepted agreement reservation.

Existing rule remains:

```text
listing closed
≠ agreement cancelled
```

A closed listing with an agreed/in-progress LEND still has its reservation until agreement completion/cancellation.

---

# 14. Reservation history

Do not add duplicate append-only reservation history.

Historical reservation periods are already recoverable from:

```text
immutable terms versions
terms_accepted events
agreement cancellation/completion
milestone timeline
```

D1 adds scheduling truth, not another audit ledger.

---

# 15. Private conflict helper

Add a private helper equivalent to:

```text
private.resource_listing_loan_period_conflicts(
  p_listing_id uuid,
  p_exclude_agreement_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
```

Requirements:

- bounded increasing interval;
- same-listing active reservations only;
- exclude candidate agreement;
- half-open overlap;
- no client execute grant.

Add supporting indexes if needed.

---

# 16. Central active-reservation query

Centralize the canonical active reservation set via a private helper/view/function.

Conceptual row:

```text
listing_id
agreement_id
request_id
terms_id
requester_profile_id
starts_at
ends_at
agreement_lifecycle
```

Do not publicly expose counterpart details.

---

# 17. Owner schedule RPC

Add:

```text
list_owned_resource_listing_loan_schedule(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
```

Only canonical listing owner.

Return active reservations ordered:

```text
starts_at ASC
ends_at ASC
agreement_id ASC
```

Suggested fields:

```text
listing_id
agreement_id
request_id
terms_id
requester_profile_id
requester_display_name
starts_at
ends_at
agreement_lifecycle
is_overdue
is_at_risk
```

No request message, private note, requester-offer description, contact data, or chat body.

---

# 18. Owner schedule privacy

Owner may see requester display name because they are already counterparty to every accepted request/agreement on that listing.

Do not expose unrelated private agreement/chat content.

---

# 19. Pending availability RPC

Add a narrow counterpart-only RPC:

```text
check_resource_exchange_pending_loan_availability(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
```

Suggested return:

```text
is_lend boolean
is_available boolean
```

For pending owner GIVE:

```text
is_lend=false
is_available=true
```

For pending owner LEND, evaluate the exact pending period against other active reservations.

This is informational only.

The terms-accept transaction remains race-safe authoritative enforcement.

---

# 20. Availability privacy

The check must not reveal:

- other requester IDs;
- other agreement IDs;
- other users' loan periods;
- other private terms.

Do not expose a public reservation calendar in D1.

---

# 21. Own reservation reads

Existing agreement/current-terms reads already expose the two counterparties' own accepted loan period.

Do not add another exact reservation RPC that duplicates those values.

---

# 22. Overdue semantics

Reuse the existing backend-authoritative owner-lend overdue semantics from:

```text
get_resource_exchange_agreement
```

The owner schedule's `is_overdue` must use the same truth.

Refactor to a private helper if needed to avoid semantic drift.

---

# 23. At-risk future reservations

A later active reservation is `is_at_risk=true` when an earlier active LEND reservation on the same listing satisfies:

```text
earlier.ends_at <= later.starts_at
AND earlier is currently overdue/unreturned
```

The later reservation remains active.

Do not cancel or move it.

---

# 24. At-risk propagation

One overdue active loan may put multiple later reservations at risk.

Once the overdue loan receives canonical return receipt/completes and is no longer overdue/active:

```text
is_at_risk=false
```

on subsequent reads.

Risk is derived, not persisted.

---

# 25. No time-triggered event

Do not create:

```text
cron
timer rows
outbox event
notification
```

merely because time passes and a loan becomes overdue/at-risk.

D1 only derives current truth at read time.

---

# 26. Completed/cancelled history

Completed/cancelled reservations:

- do not block new periods;
- do not appear in active owner schedule;
- remain visible in existing agreement history.

No separate historical schedule endpoint in D1.

---

# 27. Conflict vs late return

Conflict enforcement uses agreed expected periods.

A later accepted reservation that begins after the previous expected end is valid.

If the prior borrower later fails to return on time:

```text
future reservation → at risk
```

not retroactively conflicting.

This distinction is intentional.

---

# 28. No automatic promotion

When a reservation is released:

- do not auto-accept another request;
- do not auto-accept pending terms;
- do not auto-move anyone to “first place”.

Normal negotiation remains required.

---

# 29. Schedule ordering

Owner schedule is chronological by reserved period.

Do not produce request-arrival “position #N”.

---

# 30. Multiple accepted requests

Preserve:

```text
multiple accepted requests per listing are allowed
```

They may negotiate concurrently.

Only mutually accepted listing-side LEND periods are conflict-constrained.

Do not redesign GIVE semantics or quantity semantics in D1.

---

# 31. Singular-unit assumption

Treat each listing as one reservable lending unit.

No quantity/capacity model.

Document multi-unit inventory as future work.

---

# 32. Concurrency tests — overlapping accepts

Same listing, overlapping pending LEND terms:

```text
two concurrent accepts
→ one success
→ one PT409
```

Final active set must contain no overlap.

---

# 33. Concurrency tests — adjacency

```text
A: Sep 10–12
B: Sep 12–14
```

Both succeed.

Prove half-open semantics.

---

# 34. Concurrency tests — cancellation vs acceptance

Existing A overlaps candidate B.

Race:

```text
cancel A
accept B
```

No final state may contain overlapping active reservations.

Prefer lock ordering such that B waiting behind committed cancellation can observe the released slot and succeed.

---

# 35. Concurrency tests — completion vs acceptance

Race final completion/return of A against acceptance B.

After A completes, B may occupy that interval if its acceptance observes A as inactive.

No inconsistent derived schedule.

---

# 36. Replacement tests

A reserves Sep 10–12.

B reserves Sep 15–17.

A replacement:

```text
Sep 16–18 → PT409
Sep 12–15 → success
```

The second is adjacent to both intervals.

---

# 37. PT409 convention

Use `PT409` for reservation conflicts.

Never introduce custom `40001`.

No automatic retry.

---

# 38. Outbox/Realtime behavior

Conflict failure emits no accepted-terms event or notification.

Successful acceptance continues using the existing 04C4B event path.

Do not add `reservation_created` events when reservation is derived from accepted terms.

---

# 39. RLS / grants

New public RPCs must:

- be expected-identity bound;
- use fixed/empty search path;
- derive authorization canonically;
- fail closed;
- expose only bounded fields.

Private helpers get no client grants.

No public reservation table is expected.

---

# 40. Structural pgTAP

Cover:

- forward migration;
- latest accept-terms listing serialization;
- conflict helper security/signature;
- owner schedule RPC;
- pending availability RPC;
- private helpers/grants;
- no custom `40001`;
- supporting indexes.

---

# 41. Behavioral pgTAP — reservation activation

Cover:

```text
pending request → none
accepted request/no terms → none
pending LEND proposal → none
accepted GIVE → none
accepted LEND → active
in_progress LEND → active
completed LEND → released
cancelled LEND → released
```

---

# 42. Behavioral pgTAP — overlap matrix

Cover:

- start inside;
- end inside;
- candidate contains existing;
- existing contains candidate;
- exact same period;
- adjacent before;
- adjacent after;
- different listing;
- self replacement exclusion.

---

# 43. Owner schedule pgTAP

Owner sees only active LEND reservations, chronologically, with requester display context and derived overdue/risk.

Unrelated user denied.

Requester denied owner schedule.

Anonymous denied.

---

# 44. Availability pgTAP

For exact pending version:

```text
GIVE → is_lend=false, available=true
LEND free → available=true
LEND conflict → available=false
```

Both agreement counterparties may call.

Unrelated/anonymous denied.

Stale/wrong pending terms ID fails safely.

---

# 45. At-risk pgTAP

Scenario:

```text
A accepted Sep 10–12
B accepted Sep 12–14
```

At a time after A's expected end, with no canonical return receipt:

```text
A.is_overdue = true
B.is_at_risk = true
```

After A's return receipt/completion:

```text
A disappears from active schedule
B.is_at_risk = false
```

No persistent risk flag.

---

# 46. Real OTP/concurrency verifier

Extend the Resource agreement verifier or add a focused D1 verifier covering:

1. create one listing;
2. multiple accepted requests;
3. pending LEND does not reserve;
4. first accepted LEND appears in owner schedule;
5. overlapping second acceptance PT409;
6. adjacent reservation succeeds;
7. different listing no conflict;
8. conflicting replacement;
9. compatible replacement;
10. LEND→GIVE release;
11. cancellation release;
12. listing close preserves active reservation;
13. completion release;
14. concurrent overlap race one success;
15. cancellation-vs-acceptance;
16. completion-vs-acceptance;
17. owner schedule authorization/privacy;
18. pending availability authorization/privacy;
19. overdue/at-risk derivation where practical.

Never log OTP/token/private note/request message/chat body/requester offer text.

---

# 47. Generated types

Regenerate/update types for new public RPCs.

If local Supabase is stale/unavailable:

- do not claim drift passed;
- update only compile-required contracts carefully;
- report drift unexecuted;
- retain it as hard pre-merge gate.

---

# 48. Roadmap update

Split:

```text
04C4D — Loan Availability / Queue

04C4D1 — Loan Reservation + Conflict Domain
  this plan

04C4D2 — Mobile Loan Calendar / Queue
  owner schedule visualization
  pending proposal availability
  at-risk warning UX
```

Deferred:

```text
recurring owner availability windows
multi-unit capacity
automatic promotion
post-handoff extensions/amendments
```

---

# 49. 04C4D2 handoff

D2 should consume:

```text
list_owned_resource_listing_loan_schedule
check_resource_exchange_pending_loan_availability

existing:
get_resource_exchange_agreement
list_resource_exchange_agreement_terms
```

No direct table reads.

---

# 50. 04C4E handoff

D1 establishes stable availability truth that future matching can use internally.

Do not implement Project matching or leak private reservation dates publicly.

---

# 51. Validation

Run repository equivalents of:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

node --check <verifier>
npm run check:web
npm run check:site
npm run check:mobile
git diff --check
```

Attempt focused real OTP/concurrency verification.

Attempt hosted Validation once.

If GitHub cannot allocate a runner due the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

This DB-heavy PR must not merge until clean replay, lint/advisors, pgTAP, focused integration/concurrency, and generated-type drift all execute green.

---

# Non-goals

Do not implement:
- Flutter queue/calendar UI;
- public reservation calendar;
- public borrower identities;
- FIFO priority;
- automatic next-request promotion;
- recurring availability windows;
- multi-unit quantity;
- requester free-text item reservation;
- post-handoff amendments;
- disputes/moderation;
- overdue/risk notifications;
- Project matching;
- saved searches;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #82;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] no duplicate mutable reservation ledger;
- [ ] active reservation derives from accepted listing-side LEND current terms;
- [ ] half-open interval semantics;
- [ ] adjacent periods allowed;
- [ ] overlapping accepted LEND periods blocked;
- [ ] pending proposals do not reserve;
- [ ] no FIFO/request-time priority;
- [ ] listing row serializes cross-agreement acceptance;
- [ ] concurrent overlap accepts yield one success/one PT409;
- [ ] same-agreement replacement excludes old period;
- [ ] LEND→GIVE releases;
- [ ] cancellation releases;
- [ ] completion releases;
- [ ] listing close preserves active reservation;
- [ ] owner schedule RPC exists;
- [ ] pending availability RPC is privacy-safe;
- [ ] overdue truth matches existing agreement read;
- [ ] future reservations derive at-risk;
- [ ] at-risk never auto-cancels;
- [ ] no timer/cron risk event;
- [ ] no automatic queue promotion;
- [ ] requester text-only LEND leg not globally reserved;
- [ ] PT409 convention preserved;
- [ ] failed acceptance emits no accepted side effects;
- [ ] pgTAP/concurrency/OTP coverage added;
- [ ] generated types updated where executable;
- [ ] no D2/E/F scope creep;
- [ ] no PR merged.

---

# Completion report

Return:
1. Stack/base status
2. 04C4D1 branch/base/PR
3. Changed files
4. Reservation canonical-source decision
5. Active reservation definition
6. Half-open overlap rule
7. Accept-terms conflict enforcement
8. Listing serialization/lock order
9. Concurrent acceptance behavior
10. LEND→LEND replacement
11. LEND→GIVE replacement
12. GIVE→LEND replacement
13. Cancellation release
14. Completion release
15. Listing-close behavior
16. Private conflict helper
17. Owner schedule RPC
18. Owner schedule privacy
19. Pending availability RPC
20. Availability privacy
21. Overdue semantic reuse
22. At-risk derivation
23. No timer/event behavior
24. No FIFO/automatic promotion
25. Requester-leg reservation boundary
26. PT409 behavior
27. Outbox/Realtime behavior
28. RLS/grants
29. Structural pgTAP
30. Conflict pgTAP
31. Owner schedule pgTAP
32. Availability pgTAP
33. At-risk pgTAP
34. Concurrency tests
35. Real OTP integration
36. Generated types/drift
37. Local regression validation
38. Hosted Validation executed/not-executed
39. 04C4D2 handoff
40. 04C4E handoff
41. Warnings/blockers
42. Commit/PR reference

Do not merge any PR.
