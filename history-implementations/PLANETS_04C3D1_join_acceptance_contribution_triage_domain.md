# PLANETS 04C3D1 — Join-Acceptance Contribution Triage Domain

**Roadmap area:** 04C3D — Acceptance Triage and Live Project Coverage  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

This plan continues the current open stack:

```text
main
  fe3cd28cec066ff262da049f15f58dd53b3fa6aa

PR #45 — 04C3A Project Resource Needs
  codex/04c3a-project-resource-needs
  2b2aaabfbf872431b4a60a26dba5440f4b22560f

PR #52 — 04C3B1 Join-Request Contribution Selection Domain
  codex/04c3b1-join-request-contribution-selections
  410b50423f9b75126349d8d29d7767499fe73146

PR #60 — 04C3B2 Mobile Contribution Selection + Messages
  codex/04c3b2-mobile-contribution-selection
  058e8b03c8905048cff2e8e78f80b3488686fbf0

PR #61 — 04C3C1 Current Commitment Domain
  codex/04c3c1-current-participant-commitments
  4fe08a9704150babcb8de7e307f6441923768cbc

PR #62 — 04C3C2 Mobile Current Commitment Management
  codex/04c3c2-mobile-commitment-management
  682986d2bb573725fb955b297190f0091e20c0f1
```

All are intentionally open/unmerged. Required database validation remains blocked by the local Docker engine and GitHub Actions billing.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase #45 onto main;
3. rebase #52 onto #45;
4. rebase #60 onto #52;
5. rebase #61 onto #60;
6. rebase #62 onto #61;
7. preserve unrelated SITE/CI/tooling work;
8. branch this plan from the final PR #62 head;
9. open the new PR with base:
   `codex/04c3c2-mobile-commitment-management`.

Preferred branch:

```text
codex/04c3d1-acceptance-contribution-triage
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3D1_join_acceptance_contribution_triage_domain.md
```

Do not merge any PR.

---

# Objective

Change Project join acceptance so the creator must explicitly decide what each contribution offered in the join request means.

A request may contain:

```text
Competences / Knowledge
[ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Ladder ]
```

Before accepting the person, the creator classifies **every offered item** into exactly one of three outcomes:

```text
NEEDED / ACCEPT
  → this person is expected to contribute it

ALREADY FOUND
  → this person's offer is not needed

EXTRA IS FINE
  → this person may still contribute it even though it is not being accepted as a needed contribution
```

These acceptance decisions become historical facts about the request.

They are not the mutable current commitment state.

---

# 1. Product semantics

For every request-selected skill/resource:

## `needed`

Conceptual UI:

```text
Accept / Needed
```

Meaning:

```text
the creator accepts this offered contribution as something expected from this participant
```

Result at membership creation:

```text
seed a current membership commitment
```

This is also the acceptance outcome that later live-coverage work will use as the initial “this participant covers this Project need” assignment.

04C3D1 itself does not yet build the live coverage projection/drawer.

## `already_found`

Conceptual UI:

```text
Already found
```

Meaning:

```text
the person may join,
but this offered item is not expected from them
```

Result:

```text
do NOT seed a membership commitment for this item
```

The historical decision remains stored.

Do not treat this request decision itself as proof of physical delivery.

The later live-coverage slice will decide/derive the Project-level current found/needed state.

## `extra`

Conceptual UI:

```text
Bring it as extra
```

Meaning:

```text
the creator is happy for this person to contribute it,
but it was not accepted as the contribution that fulfills the Project need
```

Result:

```text
seed a current membership commitment
```

The historical `extra` distinction must survive separately so later coverage logic can distinguish:

```text
commitment exists
vs
commitment counts as need coverage
```

Do not collapse `needed` and `extra` into the same historical decision.

---

# 2. Mandatory triage

If a pending request has contribution selections:

```text
every selected item must have exactly one acceptance disposition
```

before acceptance may succeed.

The backend must enforce this.

The future mobile red-border/shake behavior is only presentation; it must not be possible to bypass triage by calling the old RPC directly.

A request with zero selected contributions may still be accepted without triage.

---

# 3. Historical decision tables

Add separate fail-closed tables equivalent to:

```text
public.project_join_request_skill_acceptance_decisions
public.project_join_request_resource_acceptance_decisions
```

Exact names may follow repository conventions.

## Skill decision

Conceptual shape:

```text
request_id
skill_id
disposition
decided_at
decided_by_profile_id
```

Primary key:

```text
(request_id, skill_id)
```

Composite FK:

```text
(request_id, skill_id)
→ project_join_request_skill_selections(request_id, skill_id)
```

This guarantees decisions can only refer to an item the requester actually selected.

## Resource decision

Conceptual shape:

```text
request_id
resource_need_id
disposition
decided_at
decided_by_profile_id
```

Composite FK to:

```text
project_join_request_resource_selections
```

Disposition values:

```text
needed
already_found
extra
```

No other status.

These are immutable acceptance-history rows.

---

# 4. Historical decisions are not current commitments

Preserve four distinct concepts:

```text
request selection
  what requester offered

acceptance decision
  what creator decided about that offer at acceptance time

membership commitment
  mutable current expectation after acceptance

future actual contribution
  one-time Project end-state attribution
```

Never rewrite request selections or acceptance decisions when current commitments later change.

---

# 5. Acceptance API

The current canonical function is:

```text
accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid
)
```

Add an explicit triaged signature equivalent to:

```text
accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid,

  p_needed_skill_ids uuid[],
  p_already_found_skill_ids uuid[],
  p_extra_skill_ids uuid[],

  p_needed_resource_need_ids uuid[],
  p_already_found_resource_need_ids uuid[],
  p_extra_resource_need_ids uuid[]
)
```

Prefer required arrays, not defaulted arrays.

Exact parameter ordering may follow repository conventions, but names must remain unambiguous.

---

# 6. Safe two-argument compatibility

Keep/redefine the two-argument overload only for requests with **zero** contribution selections.

Its behavior:

```text
zero selected skills/resources
  → acceptance works exactly as before

one or more selected contributions
  → reject atomically:
     contribution triage is required
```

This preserves older no-contribution callers while preventing bypass of mandatory triage.

Do not leave a two-argument path that accepts selected contributions.

The future mobile D2 slice should normally use the triaged signature whenever selections exist.

---

# 7. Exact partition validation

For each selection kind independently:

```text
needed
+ already_found
+ extra
```

must be an exact partition of the immutable request selections.

Reject if:

- an offered item appears in no disposition;
- an item appears in more than one disposition;
- an ID was never selected by the requester;
- null IDs appear;
- duplicates appear inside one array;
- selected count differs from classified count.

Ordering is irrelevant.

Invalid triage means:

```text
no request resolution
no decisions
no membership
no commitments
no chat activation
no event
```

---

# 8. Current-validity rule for `needed`

A creator may only classify an item as `needed` if it is still a current Project requirement at the serialized acceptance boundary.

## Proposal skill

`needed` requires:

```text
skill is still attached to this Proposal
```

Both:

```text
required
useful
```

remain acceptable.

The existing concrete Proposal lock should serialize this with skill replacement.

## Tavolo skill

Tavoli still cannot have request skill selections.

All skill triage arrays must therefore be empty.

Do not invent Tavolo skill requirements.

## Resource

`needed` requires:

```text
resource need belongs to the same Project
AND
resource need state = open
```

Lock relevant `needed` resource rows in deterministic UUID order after the established Project locks.

If the resource was closed after the request:

```text
needed → reject as stale/invalid
already_found → valid
extra → valid
```

The creator can reload/reclassify.

---

# 9. Historical options may still be `extra` or `already_found`

A request selection is historical.

If the Project requirement changed after the request:

```text
skill removed from Proposal requirements
resource need closed
```

the creator may still classify that historical offer as:

```text
already_found
or
extra
```

because these outcomes do not claim the item is still a current Project need.

Do not discard historical request selections.

---

# 10. Acceptance transaction

The triaged acceptance must remain one transaction.

Conceptual order:

```text
authenticate expected creator
→ load request
→ concrete Project lock
→ shared Project lock
→ request FOR UPDATE
→ validate creator / pending / requester / membership invariants
→ validate exact triage partition
→ serialize current-needed skill/resource validity
→ insert immutable acceptance decisions
→ mark request accepted
→ insert membership
→ membership triggers seed commitments + ensure chat
→ existing acceptance event
→ commit
```

No half-accepted state.

---

# 11. Modify C3C1 membership seeding

Current 04C3C1 behavior seeds **every** request selection as a membership commitment.

Replace that behavior for newly accepted triaged requests.

The membership seed invariant becomes:

```text
acceptance disposition = needed
  → seed commitment

acceptance disposition = extra
  → seed commitment

acceptance disposition = already_found
  → do NOT seed commitment
```

For skills and resources independently.

Do not emit a separate seed event.

The accepted membership and Project chat must remain part of the same acceptance transaction.

---

# 12. Trigger invariant

The membership-seeding trigger/helper should fail closed if a membership is inserted from a request containing selections whose acceptance decisions are incomplete.

This protects canonical membership creation even if another trusted SQL path appears later.

For a zero-selection originating request, zero acceptance decisions are valid.

Do not silently fall back to “seed everything” for new memberships.

---

# 13. Backfill existing accepted history

Existing accepted memberships in the stacked development history predate triage.

Preserve their previous semantics deterministically.

For every already-accepted request selection without a decision:

```text
backfill disposition = needed
decided_at = membership.joined_at
decided_by_profile_id = request.resolved_by_profile_id
```

This means:

```text
old behavior where all accepted selections seeded commitments
→ historical acceptance decision = needed
```

Do not backfill decisions for:

```text
pending
rejected
withdrawn
```

Do not rewrite current commitment sets during the backfill.

---

# 14. Rejoin semantics

Each request attempt owns its own acceptance decisions.

Example:

```text
Request A:
Paint → needed
membership A created
participant leaves

Request B:
Paint → already_found
Wood → extra
membership B created
```

Membership B must seed only:

```text
Wood
```

and never inherit decisions or commitments from membership A.

---

# 15. Request-history read remains unchanged

Do not alter:

```text
list_own_project_join_request_contribution_selections
```

It remains the historical “what the requester offered” read used by Messages.

Acceptance decision history is separate.

No Messages UI change in D1.

---

# 16. Optional narrow acceptance-decision read

A private requester/creator acceptance-decision read may be added if it materially improves testing/future D2 integration, conceptually:

```text
list_own_project_join_request_acceptance_decisions(
  expected_profile,
  request_id
)
```

But it is not required for the acceptance UI before submission.

If added:

- only requester or canonical creator;
- accepted requests only or empty pending result;
- current canonical labels;
- deterministic ordering;
- no public access.

Do not enlarge D1 solely for convenience.

---

# 17. Event privacy

Keep the canonical:

```text
project.join_request_accepted
```

event identifier-only.

Do not add:

- disposition arrays;
- labels;
- request message;
- resource titles;
- skill labels.

No additional user notification is required merely for storing triage history.

---

# 18. No live coverage projection yet

D1 intentionally does **not** implement:

```text
Project need covered/uncovered projection
chat needed-items drawer
system chat messages
badge/popover/shake when a need reappears
claiming a needed item from chat
manual/external found coverage
```

However, preserve `needed` versus `extra` historically so the next coverage foundation can initialize correctly.

Do not fake live coverage by setting `project_resource_needs.state = closed`.

04C3A `open/closed` remains the creator-owned need lifecycle, not “currently covered by a participant.”

---

# 19. Future live-coverage model compatibility

Design the acceptance-decision schema so the following future mapping is straightforward:

```text
needed
  → commitment exists
  → initial participant coverage assignment

extra
  → commitment exists
  → no participant coverage assignment

already_found
  → no commitment for this requester
  → later live-coverage logic determines whether coverage already comes
    from another participant or a creator/manual external-found marker
```

Do not introduce ambiguous boolean names like:

```text
accepted = true/false
```

that lose this distinction.

---

# 20. Current commitment editing remains separate

Do not change the C3C2 mobile editor in D1.

After acceptance:

```text
membership commitments remain mutable
```

The historical acceptance decisions remain unchanged.

Later slices will connect current commitments to live need coverage and organizer resets.

---

# 21. Authorization

For now, only the canonical Project creator can accept/triage requests.

Do not implement delegates/co-organizers here.

Future delegate permission expansion must be possible without changing historical decision tables.

Expected creator identity remains bound to `auth.uid()`.

---

# 22. RLS / grants

Decision tables:

- RLS enabled;
- no client policies;
- no direct anon/authenticated/service table grants;
- writes only inside trusted acceptance RPC;
- fixed/empty `search_path`;
- narrow execute grants on public RPCs.

No direct mobile table access.

---

# 23. Structural pgTAP

Cover at minimum:

- both decision tables exist;
- composite PKs;
- composite FK to corresponding immutable request-selection table;
- creator profile FK;
- disposition constraint exactly:
  `needed`, `already_found`, `extra`;
- timestamps;
- RLS;
- no direct policies/grants;
- triaged acceptance signature exists;
- zero-selection two-arg compatibility signature exists;
- unsafe selected-contribution bypass is impossible.

---

# 24. Behavioral pgTAP

Cover:

## Exact triage

- one selected item classified `needed`;
- `extra`;
- `already_found`;
- mixed multi-item request;
- missing decision rejected;
- duplicate-across-dispositions rejected;
- unselected ID rejected;
- null rejected;
- duplicate within array rejected;
- atomic rollback.

## Membership seeding

- `needed` seeds commitment;
- `extra` seeds commitment;
- `already_found` does not;
- mixed request seeds exact subset.

## Zero selections

- two-argument acceptance remains valid;
- triaged all-empty acceptance also valid if supported.

## Needed validity

- current Proposal required skill accepted;
- current Proposal useful skill accepted;
- removed Proposal skill cannot be `needed`;
- removed skill may be `extra`/`already_found`;
- open same-Project resource may be `needed`;
- closed resource cannot be `needed`;
- closed resource may be `extra`/`already_found`;
- other-Project resource rejected.

## Authorization

- non-creator denied;
- stale expected identity denied.

## History

- request selections unchanged;
- acceptance decisions immutable;
- current commitment edits do not rewrite decisions;
- rejoin has independent decisions.

## Events

- exactly the existing acceptance event;
- no disposition/label/message leakage.

---

# 25. Concurrency tests

Add deterministic coverage for:

## Needed resource vs close

Valid serializations:

```text
accept/needed wins first
→ acceptance succeeds
→ resource may close afterward

close wins first
→ needed acceptance rejects
→ creator may retry as extra/already_found
```

## Needed Proposal skill vs skill removal

Same serialization principle.

## Accept vs withdraw

Preserve existing request-row serialization:

```text
exactly one terminal transition wins
```

No decision rows may survive a losing/rolled-back acceptance.

---

# 26. Real local integration

Add or extend a real-OTP verifier covering:

1. creator creates Proposal;
2. requester selects required/useful skills + resources;
3. creator triages a mix of:
   - needed
   - extra
   - already_found;
4. creator accepts;
5. exact immutable decision rows exist;
6. membership commitments contain only needed+extra;
7. request selections remain all original offers;
8. chat activation still occurs;
9. current commitment reads show expected seeded subset;
10. creator/participant can later edit commitments without rewriting decisions;
11. rejoin independence;
12. zero-selection two-arg compatibility;
13. stale needed skill/resource races;
14. Tavolo resource triage;
15. outbox/audit privacy.

Never print OTPs, tokens, private messages, labels, private emails, or meeting details.

Wire into `check:db` / Database CI according to existing repository conventions.

---

# 27. Generated types

Update generated TypeScript contracts for:

- triaged acceptance signature;
- any optional decision-read RPC;
- new public decision tables if generated schema includes them.

If Docker remains unavailable:

- derive only compile-required type changes carefully;
- document them as unverified;
- require canonical `db:types:check` before merge.

---

# 28. Existing mobile compatibility

D1 is backend-first.

Do not implement the mandatory triage UI yet.

But ensure the repository remains honest:

- current two-arg mobile acceptance may continue only for zero-selection requests;
- selected-contribution acceptance requires the new D2 UI before that user path is complete;
- document this stacked dependency clearly.

Do not weaken the backend just to keep the old selected-request button functional temporarily.

The next slice is:

```text
04C3D2 — Mobile Join-Acceptance Contribution Triage
```

---

# 29. 04C3D2 handoff

D2 will implement the creator UX:

```text
Requester offers:
[ Paint ]
[ Carpentry ]
[ Ladder ]

Creator must classify every chip:

Paint
[ Needed ] [ Already found ] [ Extra ]

Carpentry
[ Needed ] [ Already found ] [ Extra ]

Ladder
[ Needed ] [ Already found ] [ Extra ]
```

If Accept is pressed before all are classified:

```text
unclassified chips:
  red border
  brief shake

first occurrence:
  explanatory tooltip/popover:
  "Decide what this person should bring/help with before accepting.
   You can change their current commitments later from Project Organizer."
```

D1 must provide the atomic backend contract required for this UI.

Do not implement shake/tooltip in D1.

---

# 30. Roadmap update

Add/refine:

```text
04C3D — Acceptance Triage and Live Project Coverage (parent)

04C3D1 — Join-Acceptance Contribution Triage Domain
  this plan

04C3D2 — Mobile Join-Acceptance Contribution Triage
  mandatory three-way creator decision UI

04C3D3 — Live Need Coverage + Group Coordination
  current coverage projection
  need reappearance events
  chat needed-items drawer
  claim/cover flow
  badge/popover/shake attention
```

Update 05C wording away from “creator review.”

Conceptually:

```text
05C — One-Time Project Actual Contribution Finalization

active final commitments
  → automatically become actual contribution attribution

creator/delegate
  → handles exceptions/corrections
  → adds canonical off-app contributions
  → optional Substantial Effort / Energy marker

Tavoli
  → deferred
```

Do not implement 05C in D1.

---

# 31. Documentation

Document clearly:

```text
request selection
≠ acceptance decision
≠ current commitment
≠ live Project coverage
≠ final actual contribution
```

This distinction is central.

Update database/system-design docs and roadmap.

Do not describe this as a person rating/review system.

---

# 32. GitHub Actions / Docker

Continue the established policy:

```text
local non-DB checks
  → run normally

Docker unavailable
  → DB replay/pgTAP/integration/type drift = not executed

GitHub Actions billing gate
  → attempt once
  → report external non-execution
  → no pointless rerun
```

Do not merge this or lower backend PRs before executable Database validation passes.

---

# Non-goals

Do not implement:

- mobile triage UI;
- red/shaking chips;
- first-time tooltip;
- live covered/uncovered projection;
- Project chat drawer;
- system chat messages for resurfaced needs;
- coverage attention badge/popover;
- participant claim-from-chat;
- creator manual external-found coverage;
- final actual contribution attribution;
- `Substantial Effort / Energy`;
- Tavolo completion attribution;
- delegate/co-organizer permissions;
- negative behavior/no-show reporting;
- public reviews/ratings;
- Scambio-Dona matching.

---

# Acceptance criteria

Ready for review when:

- [ ] stack is current and D1 is based on PR #62;
- [ ] exact prompt archived;
- [ ] separate skill/resource acceptance-decision tables exist;
- [ ] dispositions are exactly needed/already_found/extra;
- [ ] each decision references an actual immutable request selection;
- [ ] selected-contribution acceptance requires complete exact triage;
- [ ] zero-selection two-arg acceptance remains safe;
- [ ] `needed` requires current Project validity;
- [ ] historical `extra`/`already_found` survive requirement changes;
- [ ] needed + extra seed current commitments;
- [ ] already_found does not seed a commitment;
- [ ] membership trigger fails closed on incomplete selected-request triage;
- [ ] old accepted history is deterministically backfilled as needed;
- [ ] request-selection history remains unchanged;
- [ ] current commitment edits do not rewrite acceptance history;
- [ ] rejoin decisions are independent;
- [ ] acceptance/chat transaction behavior is preserved;
- [ ] events remain identifier-only;
- [ ] RLS/grants fail closed;
- [ ] pgTAP and real integration added;
- [ ] generated types updated where executable;
- [ ] roadmap includes D1/D2/D3;
- [ ] 05C wording reflects automatic final attribution direction;
- [ ] no mobile/live-coverage/05C implementation added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3D1 branch/base/PR**
3. **Changed files**
4. **Decision schema**
5. **Disposition semantics**
6. **Triaged acceptance RPC signature**
7. **Two-argument compatibility behavior**
8. **Exact partition validation**
9. **Needed Proposal-skill validation**
10. **Needed resource validation**
11. **Historical extra/already-found behavior**
12. **Acceptance atomicity**
13. **Membership seeding changes**
14. **Trigger fail-closed invariant**
15. **Existing-history backfill**
16. **Rejoin independence**
17. **Request-history preservation**
18. **Event/audit privacy**
19. **Authorization/RLS/grants**
20. **Concurrency behavior**
21. **pgTAP**
22. **Real OTP integration**
23. **Acceptance/chat regression**
24. **Generated types/drift**
25. **Local regression validation**
26. **Hosted Validation executed/not-executed**
27. **04C3D2 mobile handoff**
28. **04C3D3 live-coverage handoff**
29. **05C automatic-finalization handoff**
30. **Warnings/blockers**
31. **Commit/PR reference**

Do not merge any PR.

