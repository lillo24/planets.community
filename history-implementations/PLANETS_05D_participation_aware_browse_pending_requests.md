# PLANETS 05D — Participation-Aware Browse and Pending Request Visibility

**Roadmap area:** PLANETS 05 — Participation Lifecycle / discovery follow-up  
**Task type:** Authenticated mobile discovery enhancement over existing 04A/04B/05A/05B behavior  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known merged 06C2A base when this prompt was written:** `fa6a61574d4c91ca128d7958ee3c7a7c01ac8e33`

## Objective

Make a user's **pending join requests visible directly in Browse**, without requiring them to open each Project/Tavolo detail.

Accepted product direction:

> When an authenticated user has a **pending join request** for a Project/Tavolo, that item should be surfaced ahead of ordinary discovery results where practical and visually distinguished, for example with a **Requested** badge and/or special border.

The key behavior is:

```text
Browse
┌──────────────────────────────────────┐
│ Requested                            │
│ [ Requested ] Community Garden       │
│ [ Requested ] Weekly Culture Tavolo  │
└──────────────────────────────────────┘

Other projects
...
```

The user should immediately understand:

> “I already requested to join this.”

This task is deliberately narrow.

After 05D:

- signed-in mobile Browse shows matching **pending-request** Projects/Tavoli at the top;
- pending items are visually marked with a localized `Requested` state;
- pending items do not also appear lower in the ordinary feed;
- a pending project is surfaced even if its normal public position would have placed it on a later pagination page;
- current Browse filters apply consistently to both the Requested section and ordinary results;
- rejected, withdrawn, accepted, left, and removed history is **not** labeled Requested;
- signed-out public Browse ordering and APIs remain unchanged;
- ordinary public cursor pagination remains unchanged;
- pending-request enrichment failure never makes public Browse unusable;
- account switching cannot leak another user's requested projects;
- no final discovery/Progetti redesign is introduced.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05D_participation_aware_browse_pending_requests.md
```

---

# Why this should not be a client-side sort

The existing public feeds are independently cursor-paginated.

If Flutter only did:

```text
sort(currentlyLoadedPage, pendingFirst)
```

a pending request whose project normally appears on page 3 would still be invisible until page 3 loads.

That fails the product goal.

Do **not** rewrite the anonymous public-list cursor/order either.

Instead use two conceptual streams:

```text
authenticated pending-request cards
        +
ordinary public paginated feed
```

Then render:

```text
pending section first
ordinary feed second, excluding duplicate pending IDs
```

This preserves stable public pagination while making pending requests globally visible within the current filtered discovery context.

---

# External context

None required.

Do not wait for:

- Firebase;
- self-hosted production infrastructure;
- 04C Resources;
- 05C contribution semantics;
- 07B chat decisions.

---

# Repository state and required inspection

Work from latest merged `main`.

Inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/implementation/roadmap.md`;
5. merged 04A Proposal public-list/detail APIs;
6. merged 04B1 recurring public-list/detail APIs;
7. current Proposal Flutter gateway/controller/models/screens;
8. current Tavoli Flutter gateway/controller/models/screens;
9. merged 05A join-request state/read APIs;
10. merged 05B `ownParticipationProvider`, commands, and detail integration;
11. current Browse Proposal/Tavolo switcher behavior;
12. filter models and pagination cursors;
13. generated DB types;
14. relevant mobile/router/widget tests;
15. CI.

Important current facts:

- public Proposal Browse uses cursor pagination independent of participation state;
- public Tavoli Browse uses cursor pagination independent of participation state;
- 05A exposes canonical private join-request history;
- 05B already loads all of the current user's requests/memberships into an identity-bound participation controller;
- request status is canonical:
  - pending;
  - accepted;
  - rejected;
  - withdrawn;
- leave/removal is membership history, not a pending request;
- a user may request again later when eligible after ordinary withdrawal/rejection/leave/removal;
- only the **currently pending request** qualifies for the Requested Browse treatment;
- no Realtime requirement exists for this follow-up;
- public/signed-out discovery must stay usable without authentication.

---

# 1. Authenticated pending-request discovery APIs

Add narrow expected-identity-bound reads for pending requested cards.

Prefer two domain-aligned APIs rather than a large JSON union.

Equivalent contracts:

```text
list_own_pending_requested_proposals(
  p_expected_profile_id,
  p_locality?,
  p_skill_ids?
)
```

and:

```text
list_own_pending_requested_recurring_activities(
  p_expected_profile_id,
  p_reference_time,
  p_locality?
)
```

Exact names are Codex-owned.

These RPCs exist for the **current authenticated user's own pending requests only**.

Do not change the anonymous public list RPC signatures or behavior.

---

# 2. Pending Proposal semantics

The pending Proposal read should return the same safe card-level information needed by the existing mobile public Proposal card, plus only the private viewer context needed for this feature.

At minimum include concepts equivalent to:

```text
proposal_id
request_id
request_created_at

title
summary
starts_at
ends_at
derived_status

country_code
locality
administrative_area?
public_location_label?

skills
```

Use the existing public/sanitized semantics for project content.

Never return:

- exact meeting text;
- exact coordinates;
- private requester message;
- email;
- protected profile fields.

## Public eligibility

A pending Proposal should appear in the Requested Browse section only while it would otherwise be a valid public discovery item under current lifecycle/time rules.

Do not use Browse as historical request storage.

If a proposal is cancelled/expired/outside current public discovery, Messages/request history remains the place to find that request.

## Filters

Apply the same Proposal filter meaning currently used in public Browse:

- locality;
- selected skill IDs.

A filtered Browse should not pin a requested Proposal that does not match the active filters.

---

# 3. Pending Tavolo semantics

Return enough sanitized data to render the existing public recurring card without performing one detail RPC per pending activity.

Prefer including the public schedule/cadence fields the mobile card requires, equivalent to:

```text
recurring_activity_id
request_id
request_created_at

title
summary
topic?

country_code
locality
administrative_area?
public_location_label?

next_starts_at
next_ends_at
event_timezone

recurrence_type
weekday?
day_of_month?
local_start_time
duration_minutes
schedule_effective_from
```

Exact output may follow current recurring public-list/detail structures.

Do not expose exact meeting details.

## Public eligibility

Only include Tavoli that are currently part of public discovery according to existing lifecycle/occurrence rules.

Paused/ended/non-discoverable Tavoli should not remain pinned merely because a historical pending request row exists.

Messages remains the request-history surface.

## Filters

Apply the same current Tavoli locality filter.

---

# 4. Pending-request selection

Both APIs must select only:

```text
project_join_requests.status = pending
requester_profile_id = authenticated expected profile
```

Do not label:

- accepted;
- rejected;
- withdrawn;
- historical membership;
- left;
- removed

as Requested.

The canonical database invariants already prevent multiple current pending requests for the same profile/project; do not invent a second state.

---

# 5. Ordering inside Requested

The important ranking decision is:

```text
Requested section before ordinary feed
```

Exact ordering **within** Requested is not a major product decision.

Use a deterministic simple order, preferably:

```text
request_created_at DESC
project_id DESC
```

or another clear documented order.

Do not modify ordinary public ordering.

---

# 6. Security

The new reads are authenticated-only and expected-identity-bound.

Requirements:

- `p_expected_profile_id == auth.uid()`;
- profile identity must exist;
- only own pending requests;
- no creator-side incoming requests in this endpoint;
- fixed/empty search path for security-definer routines;
- explicit grants;
- no direct table grants.

Anonymous users must not be able to call the personalized reads.

Do not weaken existing public discovery functions.

---

# 7. Mobile architecture

Do not create a second participation state machine.

Use the existing Proposal/Tavoli feature boundaries for card models, and existing Auth/Participation state for identity coordination.

Possible design:

```text
PublicProposalsState
  requestedItems
  ordinaryItems

PublicRecurringActivitiesState
  requestedItems
  ordinaryItems
```

or a narrow companion provider if that better preserves existing controllers.

Either is acceptable.

Requirements:

- pending items loaded only for a ready authenticated profile;
- signed-out users make no personalized-request RPC;
- identity changes immediately clear personalized cards;
- ordinary public results can succeed independently of pending-card failure.

---

# 8. Failure isolation

The personalized Requested section is an enhancement, not a requirement for public discovery.

If:

```text
public feed succeeds
pending-request read fails
```

then:

- show the public feed normally;
- omit Requested enrichment;
- do not replace Browse with a full-screen error.

A subtle retry path may be added if useful, but do not clutter the first functional UI.

If the public feed itself fails, preserve current error behavior.

---

# 9. Loading strategy

For a ready authenticated user, load:

```text
public first page
pending requested matching current filters
```

in parallel where practical.

The Requested section should not require paging; the expected number of current pending requests is naturally bounded by user behavior.

Still avoid arbitrary unbounded database reads if repository conventions require a sane maximum. If adding a limit, make it generous and deterministic and report the choice.

Do not paginate the Requested section unless repository evidence demonstrates a real need.

---

# 10. Deduplication

A requested project can also occur naturally in the ordinary public feed.

Render it exactly once.

Maintain:

```text
requestedIds
```

and omit matching IDs from ordinary visible cards.

Important:

- do not alter the public cursor based on visual deduplication;
- `hasMore` continues to use the raw public page result;
- later pages must also dedupe requested IDs;
- reaching the end of the public feed remains correct.

A visible page may contain fewer ordinary cards because requested duplicates were removed; that is acceptable.

Do not fetch extra hidden public pages merely to hit an exact visual count.

---

# 11. Filters

When Proposal/Tavolo filters change:

1. invalidate the old personalized Requested section;
2. load matching requested cards with the new filters;
3. reset the ordinary public cursor;
4. load the ordinary first page;
5. dedupe.

Do not briefly display requested items from stale filters under the new filter state.

Identity and filter revision checks must reject late responses.

---

# 12. Refresh and participation-state changes

Pull-to-refresh should refresh both:

- personalized Requested section;
- ordinary public first page.

When this device performs a participation mutation that changes the current user's request state:

```text
request
withdraw
```

the Browse requested state should become refreshable/invalidated immediately.

Prefer narrow provider invalidation/listening over tight cross-feature presentation coupling.

Examples:

- user requests from detail → returning to Browse should show the item as Requested without requiring app restart;
- user withdraws → it should leave Requested after canonical state refresh.

Creator-side accept/reject on another device does not require Realtime in 05D. The next Browse refresh/re-entry may reconcile it.

---

# 13. UI

For both Proposal and Tavolo list experiences, render a distinct section at the top when non-empty.

Suggested structure:

```text
Requested
[card]
[card]

All projects / Other projects
[ordinary cards]
```

Exact secondary heading may follow current screen copy.

## Requested visual treatment

Use restrained theme-driven distinction:

- localized `Requested` badge/chip;
- and/or theme outline/border emphasis.

Do not introduce final brand colors.

Do not make the card look disabled.

It remains tappable and opens the existing project detail.

The detail screen remains the canonical place to:

- inspect pending status;
- withdraw;
- see other participation state.

## Accessibility

The Requested state must not rely only on border color.

Screen readers should receive a semantic indication equivalent to:

```text
Requested to join
```

---

# 14. No accepted/participating promotion yet

Do not expand this follow-up into a full personalized ranking engine.

Specifically do not automatically add:

- `Participating`;
- `Owned by you`;
- `Rejected`;
- `Previously joined`;
- recommendation scores

to the top section.

Those may become part of later unified Progetti discovery/product design.

05D implements only the explicit Pending Requested requirement.

---

# 15. Proposal/Tavolo product hierarchy

The broader accepted direction remains:

```text
Progetti
  includes Tavoli as a project type/filter
```

but the current app still has separate Proposal/Tavoli browse implementations.

Do not use 05D to perform the final Progetti IA migration.

Implement the requested-state behavior cleanly across both existing surfaces so it can later be reused by a unified feed.

---

# 16. Public web

Do not personalize the public Next.js discovery in 05D.

Web regression tests/build must stay green, but no signed-in requested-state UI is required there.

Generated DB types may change because of the new RPCs.

---

# 17. Database tests

Add focused pgTAP coverage.

## Proposal pending read

Test:

- own pending request returned;
- other user's pending request not returned;
- creator-side incoming request not returned as own Requested;
- rejected omitted;
- withdrawn omitted;
- accepted omitted;
- cancelled/non-public Proposal omitted;
- locality filter;
- skill filter;
- no exact meeting/private request message;
- anon denied;
- cross-account expected identity denied.

## Tavolo pending read

Test:

- own pending request returned;
- unrelated omitted;
- resolved request statuses omitted;
- published/discoverable returned;
- paused/ended/non-discoverable omitted according to current public rules;
- locality filter;
- recurrence/card schedule fields correct;
- exact meeting omitted;
- auth/grants hardened.

## Stable ordering

Verify deterministic requested ordering.

Do not alter/test a new ordering for the public list because public ordering is intentionally unchanged.

---

# 18. Real local integration

Add a focused integration harness or extend participation integration cleanly.

Prefer a focused script such as:

```text
scripts/verify-local-participation-browse.mjs
```

Use requester A, another user B, and creator C.

Prove:

1. C publishes multiple Proposals with enough chronology that one requested Proposal would not naturally be first;
2. A requests the later-position Proposal;
3. personalized requested Proposal read returns it immediately;
4. public list order itself is unchanged;
5. B cannot read A's requested state;
6. A withdraws and it disappears;
7. A submits another request and creator accepts; accepted item is not returned as Requested;
8. equivalent published Tavolo pending request appears;
9. paused/ended Tavolo behavior follows public eligibility;
10. filters affect requested read consistently;
11. no private request message/exact location leaks.

Do not print private request messages, OTPs, tokens, or protected meeting data.

---

# 19. Flutter tests

Add controller/domain/widget coverage.

## Signed out

- no personalized pending RPC;
- public list unchanged;
- no Requested section.

## Signed in

- pending requested Proposal appears above ordinary Proposal cards;
- pending Tavolo appears above ordinary Tavoli;
- `Requested` indicator visible;
- card remains tappable;
- pending project removed from ordinary section;
- pending project is visible even if absent from first ordinary mocked page.

## Status semantics

- only pending is promoted;
- accepted/rejected/withdrawn not treated Requested.

## Pagination

- requested IDs deduped from first page;
- requested IDs deduped from later pages;
- public cursor uses raw page tail, not filtered visual list tail;
- `hasMore` remains based on raw page length;
- no duplicate cards.

## Filters

- filter change clears stale requested section;
- matching requested cards reload;
- late old-filter response discarded.

## Failure isolation

- pending RPC failure + successful public feed => public cards still render;
- public-feed failure preserves current error UX.

## Identity

- account switch clears requested cards immediately;
- late A response cannot render for B.

## Mutation refresh

- request/withdraw flow invalidates or refreshes Requested state appropriately.

---

# 20. No native QA gate for continued automation

The founder has chosen to defer comprehensive native QA until the later consolidated UI/UX/native QA phase.

Therefore:

- add automated Flutter/widget/integration coverage now;
- document useful manual checks;
- do **not** block merge solely on missing native device QA for this follow-up;
- do not claim native QA passed.

This is consistent with the roadmap's later consolidated QA phase.

---

# 21. Roadmap reconciliation

First correct merged push status:

```text
06C2A — Implemented
PR #22
fa6a61574d4c91ca128d7958ee3c7a7c01ac8e33
```

Keep:

```text
06C2B — Not started / external provider context required
```

Add this participation follow-up as:

```text
05D — Participation-Aware Browse and Pending Request Visibility
```

While the PR is open:

```text
05D — In progress
```

Dependencies:

```text
04A
04B1
05A
05B
```

05 parent remains `In progress` because 05C is still outstanding.

Keep:

```text
04C — Not started
05C — Not started
07B — Not started
```

Preserve:

```text
06B native QA deferred for later consolidated pass
```

Also keep 06C2B blocked on Firebase/provider context rather than pretending it has been implemented.

---

# 22. Documentation

Update relevant mobile/database/product docs.

Record the exact accepted behavior:

- pending own requests are surfaced before ordinary Browse results;
- they are visually marked Requested;
- only pending status qualifies;
- current filters apply;
- public/signed-out ordering stays unchanged;
- ordinary public cursor semantics stay unchanged;
- Messages remains request history/action surface;
- Browse treatment is a convenience/status signal, not canonical participation state.

---

# Non-goals

Do not implement:

- final unified Progetti feed;
- accepted-member ranking;
- owned-project ranking;
- recommendation/matching algorithms;
- web personalization;
- maps;
- Realtime participation updates;
- 04C Resources/Scambio-Dona;
- 05C verified contributions;
- 06C2B Firebase integration;
- 07B group chat;
- final UI polish.

---

# Acceptance criteria

05D is ready when:

- [ ] based on merged PR #22 main;
- [ ] exact prompt archived;
- [ ] new reads are authenticated/expected-identity-bound;
- [ ] only own pending requests are returned;
- [ ] sanitized Proposal requested cards support active Proposal filters;
- [ ] sanitized Tavolo requested cards support active Tavolo filters;
- [ ] requested items obey current public eligibility;
- [ ] no exact/private data leaks;
- [ ] public list RPC/order/cursors remain unchanged;
- [ ] signed-out Browse makes no personalized call;
- [ ] requested section appears before ordinary results;
- [ ] Requested status has visible + accessible treatment;
- [ ] pending item can appear even when absent from first normal page;
- [ ] requested IDs are deduped from all ordinary loaded pages;
- [ ] public pagination remains cursor-correct after visual dedupe;
- [ ] rejected/withdrawn/accepted are not promoted;
- [ ] filters refresh both streams safely;
- [ ] pending-read failures do not break public Browse;
- [ ] account switching clears private requested state;
- [ ] request/withdraw mutations refresh/invalidate Browse state;
- [ ] Proposal and Tavolo automated coverage passes;
- [ ] Web/Mobile/Database CI stays green;
- [ ] no native QA pass is falsely claimed;
- [ ] 06C2A roadmap status corrected;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact RPC names;
- exact Requested section heading;
- badge vs badge+border presentation;
- requested-section internal ordering;
- whether requested state is integrated into existing browse controllers or a narrow companion provider;
- exact sane maximum pending-request result count if one is needed.

Stop and report before:

- changing anonymous public-list ordering/cursor semantics;
- implementing a full personalized ranking algorithm;
- adding accepted/owned/member promotion beyond pending Requested;
- leaking private participation/request fields into public models;
- doing one unbounded per-item detail request for every historical request;
- implementing final Progetti IA;
- implementing Firebase/chat/resources;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 05D prompt;
2. pending requested Proposal read;
3. pending requested Tavolo read;
4. secure pgTAP coverage;
5. real local participation-aware Browse integration;
6. generated DB types;
7. Proposal mobile Requested section;
8. Tavolo mobile Requested section;
9. deduplication preserving public cursors;
10. filter/refresh/identity safety;
11. localized/accessibility treatment;
12. Flutter controller/widget tests;
13. documentation/roadmap reconciliation;
14. focused PR, preferably `codex/05d-participation-aware-browse`;
15. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **06C2A roadmap reconciliation**
5. **Pending Proposal read**
6. **Pending Tavolo read**
7. **Authorization/privacy**
8. **Public eligibility semantics**
9. **Filter semantics**
10. **Requested ordering**
11. **Proposal Browse integration**
12. **Tavolo Browse integration**
13. **Requested visual/accessibility treatment**
14. **Deduplication**
15. **Pagination correctness**
16. **Failure isolation**
17. **Participation mutation refresh**
18. **Account-switch/race safety**
19. **pgTAP tests**
20. **Real local integration**
21. **Flutter tests**
22. **Generated types/drift**
23. **Existing regression validation**
24. **Deferred native QA status**
25. **Remaining 06C2B external blocker**
26. **Warnings/blockers**
27. **Commit/PR reference**
