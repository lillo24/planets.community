# PLANETS 04C4D2 — Mobile Loan Schedule + Availability UX

**Roadmap area:** 04C4D — Loan Availability / Queue  
**Task type:** Flutter/mobile integration over 04C4D1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #83 — 04C4D1 Loan Reservation + Conflict Domain
branch: codex/04c4d1-loan-reservation-conflicts
head:   31f7f20c5a7e476a6cf42550929896e10cb4d6df
```

PR #83 is draft, cleanly mergeable, and intentionally not merge-ready because its required database gates have not executed.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #83 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #83 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4d2-mobile-loan-schedule
```

Open against:

```text
codex/04c4d1-loan-reservation-conflicts
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4D2_mobile_loan_schedule_availability.md
```

No external document is required.

---

# Objective

Expose the 04C4D1 reservation truth in the mobile app without creating a second scheduling system.

D2 has two user-facing responsibilities:

```text
LISTING OWNER
→ view the chronological active loan schedule
→ see overdue and at-risk reservations
→ navigate to the corresponding Resource request/conversation

BOTH AGREEMENT COUNTERPARTIES
→ see whether the exact pending LEND proposal is currently available
→ avoid accepting a proposal already known to conflict
```

D2 is read-only with respect to reservation scheduling.

The only operation that actually reserves a period remains:

```text
accept_resource_exchange_terms(...)
```

No calendar drag/drop, queue reordering, automatic promotion, or reservation editing.

---

# 1. No database migration

This is mobile-only.

Use the D1 RPCs exactly:

```text
list_owned_resource_listing_loan_schedule(
  p_expected_owner_profile_id,
  p_listing_id
)

check_resource_exchange_pending_loan_availability(
  p_expected_profile_id,
  p_agreement_id,
  p_expected_pending_terms_id
)
```

Keep existing agreement RPCs and mutations unchanged.

Do not hand-edit generated database types merely for this mobile slice.

The inherited D1 database/type blocker remains a stack blocker.

---

# 2. Mobile feature boundary

Create a focused domain such as:

```text
features/resource_loans/
```

Suggested areas:

```text
domain/resource_loan_models.dart
data/resource_loan_gateway.dart
application/resource_loan_schedule_controller.dart
application/pending_loan_availability_controller.dart
presentation/resource_loan_schedule_screen.dart
presentation/resource_loan_widgets.dart
```

Exact files are Codex's choice.

Do not mix owner schedule state into general Resource listing state.

---

# 3. Owner schedule model

Strict model equivalent to:

```text
ResourceLoanReservation {
  listingId
  agreementId
  requestId
  termsId

  requesterProfileId
  requesterDisplayName

  startsAt
  endsAt

  agreementLifecycle
  isOverdue
  isAtRisk
}
```

Supported lifecycle values:

```text
agreed
in_progress
```

Reject other lifecycle values in the active schedule parser.

---

# 4. Owner schedule parser

Parse exact D1 row shape:

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

Validate:

- UUIDs;
- non-empty requester display name;
- `endsAt > startsAt`;
- lifecycle is agreed or in_progress;
- booleans are actual booleans.

Preserve backend ordering.

---

# 5. Availability model

Add:

```text
PendingLoanAvailability {
  isLend
  isAvailable
}
```

Strictly parse exactly one row.

Both values must be booleans.

---

# 6. Resource loan gateway

RPC-only methods:

```text
listOwnedSchedule(
  expectedOwnerProfileId,
  listingId
)

checkPendingAvailability(
  expectedProfileId,
  agreementId,
  expectedPendingTermsId
)
```

No direct table reads.

---

# 7. Backend truth remains authoritative

Do not locally recompute:

```text
overlap
active reservation
overdue
at-risk
```

Use D1 RPC outputs.

The mobile app may format/group dates only.

---

# 8. No FIFO language

Do not display:

```text
Queue position #1
First in line
Next automatically
```

Use:

```text
Loan schedule
Upcoming reservations
Agreed loan periods
```

This schedule is chronological, not a fairness entitlement.

---

# 9. Owner entry points

Provide schedule access without N+1 schedule reads.

## My Listings

For non-draft own listings, show:

```text
Loan schedule
```

Do not call the schedule RPC per listing card just to decide whether the button appears.

## Public Resource detail while viewer is owner

Add:

```text
View loan schedule
```

alongside existing owner actions.

Closed own listings must still allow schedule access because accepted agreements can outlive listing closure.

Non-owners must not see this action.

---

# 10. Route

Add protected owner route:

```text
/resources/:listingId/loan-schedule
```

or centralized equivalent.

Use a route builder.

Do not put requester IDs in route.

---

# 11. Owner schedule controller

Identity + listing bound.

Conceptual state:

```text
phase
expectedOwnerProfileId
listingId
items
failure
```

Support:

```text
load
refresh
handleAppResumed
```

No pagination.

---

# 12. Account-switch safety

On sign-out/account switch:

- clear schedule state;
- clear pending availability state;
- invalidate late responses.

No previous-account requester names or periods may remain visible.

---

# 13. Schedule screen

Use a chronological timeline/list, not a heavy month-grid calendar.

Suggested:

```text
Loan schedule — Power drill

Sep 24, 10:00 → Sep 26, 18:00
Anna
Terms agreed
[ Open request ]

Sep 27, 09:00 → Sep 29, 18:00
Marco
At risk
[ Open request ]
```

No drag/drop or direct date editing.

---

# 14. Schedule card

Show:

```text
requester display name
start date/time
end date/time
agreement lifecycle:
  Terms agreed
  Exchange in progress
```

Also independently show:

```text
Overdue
At risk
```

when backend booleans say so.

Do not conflate overdue and at-risk.

---

# 15. Overdue copy

Use factual wording:

```text
Return overdue
The expected return time has passed.
```

No fault inference.

---

# 16. At-risk copy

Use:

```text
At risk
An earlier loan has not yet been confirmed returned.
This reservation is still valid.
```

Do not label accepted future reservation as:

```text
Cancelled
Unavailable
Conflict
```

---

# 17. Schedule navigation

Each row has `requestId`.

Provide:

```text
Open request
```

using:

```text
resourceRequestMessageRoute(requestId)
```

Do not perform N+1 exact chat reads for `chatId`.

---

# 18. Empty schedule

Use:

```text
No active loan reservations.
Accepted loan periods will appear here.
```

Do not imply there are no pending requests/proposals.

---

# 19. Listing lifecycle/mode boundary

Schedule remains reachable for:

```text
published
closed
```

own listings.

Draft may hide schedule action.

Do not use current listing mode (`donate`/`exchange`) as reservation truth.

Agreement terms are canonical.

---

# 20. No public availability leak

Do not expose schedule, borrower names, or loan dates to non-owner public listing screens.

Public matching/availability belongs to later 04C4E design.

---

# 21. Pending availability integration

Check availability only when:

```text
pendingTerms != null
AND pendingTerms.ownerTransferKind == lend
```

Use exact:

```text
agreementId
pendingTerms.termsId
```

Do not check arbitrary unsaved drafts.

---

# 22. Availability controller

Identity/agreement/pending-version bound.

Conceptual state:

```text
idle
loading
ready
failure

expectedProfileId
agreementId
pendingTermsId
availability
```

When canonical pending terms ID changes:

- invalidate old result;
- check the new pending LEND version once.

When pending terms disappear or owner kind becomes GIVE:

- clear availability state.

---

# 23. Realtime boundary

Do not create another Realtime subscription.

Existing Resource-chat subscription already causes canonical Resource-exchange refresh.

When agreement snapshot changes pending terms pointer:

```text
availability controller re-checks exact new pending LEND version
```

No polling.

---

# 24. Available state UX

For pending owner-side LEND:

```text
Dates currently available
No accepted loan overlaps this period.
Availability is checked again when you accept.
```

Make clear it is a preflight snapshot.

---

# 25. Conflict state UX

If:

```text
isLend = true
isAvailable = false
```

show:

```text
These dates conflict with another accepted loan.
Choose different dates before accepting.
```

Do not reveal other borrower or dates.

---

# 26. Accept button behavior

For pending proposal from counterparty:

## availability = false

Disable `Accept`.

Keep:

```text
Reject
Counter-propose
```

## availability = true

Accept enabled.

Backend can still race and return PT409.

## availability loading/failed

Do not permanently block Accept.

Show:

```text
Couldn't verify availability right now.
Acceptance will check again.
```

Backend acceptance remains authoritative.

---

# 27. Proposer behavior

If current user proposed conflicting terms:

- show conflict warning;
- keep Edit/Counter-propose;
- keep Withdraw;
- no automatic edit/withdraw.

---

# 28. GIVE/requester-LEND boundary

If owner leg is GIVE:

- no availability check;
- no availability UI.

If only requester leg is LEND:

- no listing availability check.

D1 reserves only the canonical listing-owner resource.

---

# 29. Availability stale PT409

If availability RPC returns PT409:

1. do not retry old terms ID;
2. request canonical agreement refresh;
3. clear old availability;
4. when new snapshot arrives, check new pending LEND once.

No stale intent replay.

---

# 30. Availability other failures

Map safely:

```text
42501 → forbidden/identity changed
PT409 → stale pending version
other → unavailable
```

No raw backend diagnostics.

Availability failure must not break chat or terms review.

---

# 31. Acceptance conflict recovery

Existing Accept may return PT409.

After canonical reload:

- if same pending LEND still exists;
- and availability becomes false;

show:

```text
These dates are no longer available.
Review the proposal and choose another period.
```

No automatic acceptance retry.

If pending terms changed/disappeared, retain generic stale-agreement guidance.

---

# 32. Counter-proposal after conflict

Existing terms editor remains canonical workflow.

User changes dates and submits a new immutable proposal.

Availability is checked only after the new proposal becomes canonical pending state.

Do not add arbitrary-draft scheduling API.

---

# 33. Schedule refresh behavior

Owner schedule refreshes on:

```text
screen load
pull-to-refresh
app resume
screen re-entry where current navigation pattern supports it
```

Do not subscribe to every Resource chat merely for schedule freshness.

No background polling.

---

# 34. No schedule mutations

D2 performs no reservation mutations.

Cancellation, terms replacement, handoff/return/completion remain in existing agreement UX.

Canonical schedule reflects them after reload.

---

# 35. Accessibility

Cover:

- schedule row semantic label;
- requester name;
- start/end labels;
- overdue vs at-risk;
- explicit “still valid” risk meaning;
- availability warning live region;
- unknown/error availability;
- disabled Accept reason;
- high text scaling;
- long listing/requester names.

No color-only status.

---

# 36. Localization

Add localized strings equivalent to:

```text
Loan schedule
View loan schedule
No active loan reservations.
Accepted loan periods will appear here.

Terms agreed
Exchange in progress
Return overdue
At risk
An earlier loan has not yet been confirmed returned.
This reservation is still valid.

Dates currently available
No accepted loan overlaps this period.
Availability is checked again when you accept.

These dates conflict with another accepted loan.
Choose different dates before accepting.

Couldn't verify availability right now.
Acceptance will check again.

These dates are no longer available.
Review the proposal and choose another period.

Open request
Start
Expected return
```

No hard-coded production copy.

---

# 37. Tests — schedule parser

Cover:

- agreed;
- in-progress;
- overdue;
- at-risk;
- both booleans independent;
- invalid UUID;
- empty requester name;
- end <= start;
- unsupported lifecycle;
- malformed booleans.

---

# 38. Tests — gateway

Verify exact RPC names/params for:

```text
list_owned_resource_listing_loan_schedule
check_resource_exchange_pending_loan_availability
```

No direct table reads.

Availability parser requires exactly one row.

---

# 39. Tests — schedule controller

Cover:

- initial load;
- refresh;
- empty;
- failure;
- app resume;
- account switch;
- stale late response;
- listing target switch.

---

# 40. Tests — schedule UI

Cover:

- chronological rows;
- requester;
- date range;
- agreed/in-progress labels;
- overdue;
- at-risk;
- at-risk says still valid;
- empty state;
- open request route;
- long text/high scale.

---

# 41. Tests — owner entry points

Cover:

```text
My Listings:
draft → no schedule action
published → schedule action
closed → schedule action

Public detail:
owner → schedule action
non-owner → no schedule action
```

No per-card schedule load.

---

# 42. Tests — availability controller

Cover:

- no pending → idle;
- pending GIVE → no RPC;
- pending owner LEND → check;
- available;
- conflict;
- pending ID change clears old result;
- PT409 refreshes canonical agreement without old retry;
- unavailable failure;
- account switch;
- refresh bursts coalesced.

---

# 43. Tests — negotiation integration

Counterparty pending owner-LEND:

```text
available=true → Accept enabled
available=false → Accept disabled
loading/failure → Accept remains available
```

Proposer conflict:

```text
warning shown
edit/counter remains
```

Owner GIVE/requester-only LEND:

```text
no listing availability UI
```

---

# 44. Tests — race UX

Simulate:

```text
preflight available
→ Accept
→ PT409
→ canonical reload
→ same pending terms
→ availability false
```

Expected:
- no retry;
- pending stays;
- specific unavailable-dates guidance;
- counter-propose available.

---

# 45. Existing regression

Do not regress:

- Resource listing/request;
- Resource chat;
- agreement negotiation;
- milestones/timeline;
- overdue;
- Resource notifications;
- owner listing editor;
- Project Messages/chat.

---

# 46. Documentation / roadmap

Update:

```text
04C4D1 — Loan Reservation + Conflict Domain
  PR #83, DB gates blocked

04C4D2 — Mobile Loan Schedule + Availability UX
  this PR
```

Document:

```text
accepted listing-side LEND → reservation
owner schedule chronological, not FIFO
pending immutable LEND proposal gets private availability preflight
backend acceptance remains authoritative
at-risk future reservation remains valid
```

Deferred:
- recurring owner availability;
- arbitrary draft date search;
- multi-unit capacity;
- automatic promotion.

---

# 47. 04C4E handoff

Next roadmap item after D2:

```text
04C4E — Project Resource Matching
```

Do not implement matching in D2.

D1 availability truth may later feed matching, subject to explicit privacy/threshold design.

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

Run focused Resource-loan/Resource-exchange tests and formatting.

No DB migration is expected.

Do not reset or mutate the shared local Supabase solely for D2.

PR #83's DB reset/lint/advisors/pgTAP/type-drift/OTP gates remain inherited hard blockers for eventual stack merge.

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
- month-grid editing;
- drag/drop reservations;
- reservation mutation UI;
- FIFO positions;
- automatic promotion;
- public loan calendar;
- arbitrary unsaved-draft availability search;
- recurring owner availability;
- multi-unit inventory;
- requester free-text resource scheduling;
- new overdue/risk notifications;
- post-handoff amendments;
- disputes/moderation;
- Project matching;
- saved searches;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #83;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] strict schedule/availability models;
- [ ] owner schedule gateway uses D1 RPC only;
- [ ] pending availability gateway uses D1 RPC only;
- [ ] owner schedule reachable from owner listing surfaces;
- [ ] closed own listing schedule remains reachable;
- [ ] non-owner cannot see schedule action;
- [ ] no N+1 schedule calls;
- [ ] chronological, non-FIFO schedule;
- [ ] schedule shows requester/range/lifecycle/overdue/at-risk;
- [ ] at-risk explicitly remains valid;
- [ ] schedule row navigates to Resource request;
- [ ] no public reservation disclosure;
- [ ] pending owner-LEND triggers exact availability check;
- [ ] pending GIVE does not check;
- [ ] requester-side-only LEND does not check;
- [ ] known conflict disables Accept but keeps reject/counter;
- [ ] availability failure does not permanently block Accept;
- [ ] backend Accept remains authoritative;
- [ ] PT409 stale availability never retries old terms;
- [ ] Accept conflict can show specific unavailable-dates guidance;
- [ ] no second Realtime subscription;
- [ ] schedule refreshes without polling;
- [ ] account switching clears private state;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] inherited D1 DB blocker documented honestly;
- [ ] no PR merged.

---

# Completion report

Return:
1. Stack/base status
2. 04C4D2 branch/base/PR
3. Changed files
4. Loan schedule domain model
5. Availability domain model
6. Resource loan gateway
7. Schedule parser
8. Availability parser
9. Owner schedule controller
10. Account-switch safety
11. Owner listing entry points
12. Loan schedule route
13. Loan schedule screen
14. Schedule card semantics
15. Overdue presentation
16. At-risk presentation
17. Schedule-to-request navigation
18. Empty schedule
19. Public privacy boundary
20. Pending availability controller
21. Agreement refresh integration
22. Available-state UX
23. Conflict-state UX
24. Availability-failure UX
25. Accept-button behavior
26. Proposer conflict behavior
27. GIVE/requester-LEND boundary
28. Availability PT409 recovery
29. Acceptance-conflict recovery
30. No-polling/Realtime boundary
31. Localization/accessibility
32. Gateway/parser tests
33. Schedule controller/UI tests
34. Availability controller/UI tests
35. Existing Resource regression
36. Local regression validation
37. Hosted Validation executed/not-executed
38. Inherited D1 DB-gate status
39. 04C4E handoff
40. Warnings/blockers
41. Commit/PR reference

Do not merge any PR.
