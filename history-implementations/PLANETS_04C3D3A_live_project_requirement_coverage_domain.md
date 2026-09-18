# PLANETS 04C3D3A — Live Project Requirement Coverage Domain Foundation

**Roadmap area:** 04C3D — Acceptance Triage and Live Project Coverage  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Continue the current open stack:

```text
main
  fe3cd28cec066ff262da049f15f58dd53b3fa6aa

PR #45 — 04C3A Project Resource Needs
  2b2aaabfbf872431b4a60a26dba5440f4b22560f

PR #52 — 04C3B1 Join-Request Contribution Selection Domain
  410b50423f9b75126349d8d29d7767499fe73146

PR #60 — 04C3B2 Mobile Contribution Selection + Messages
  058e8b03c8905048cff2e8e78f80b3488686fbf0

PR #61 — 04C3C1 Current Commitment Domain
  4fe08a9704150babcb8de7e307f6441923768cbc

PR #62 — 04C3C2 Mobile Current Commitment Management
  682986d2bb573725fb955b297190f0091e20c0f1

PR #63 — 04C3D1 Join-Acceptance Contribution Triage Domain
  e4b6d3a2da4dace419ae1474a0e2365eb7aaebcd

PR #64 — 04C3D2 Mobile Join-Acceptance Contribution Triage
  codex/04c3d2-mobile-acceptance-triage
  aad4e238186315d57a1d33be30b7515221c17b61
```

All remain intentionally open/unmerged because executable Database validation is still blocked by the local Docker engine and GitHub Actions billing/spending limits.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the stack in dependency order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any existing PR;
5. branch this plan from the final PR #64 head;
6. open the new PR with base:
   `codex/04c3d2-mobile-acceptance-triage`.

Preferred branch:

```text
codex/04c3d3a-live-requirement-coverage-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3D3A_live_project_requirement_coverage_domain.md
```

No external document is required by Codex; the product decisions needed for this slice are captured below.

Do not merge any PR.

---

# Objective

Introduce the canonical **live Project requirement coverage** domain.

This is distinct from:

```text
request offer
acceptance triage
current membership commitment
actual final contribution
```

The new question is:

> Does the Project currently have someone/something covering this requirement?

Examples:

```text
Paint is an open Project resource need.

Mario:
  current commitment = Paint
  live coverage      = yes

Lucia:
  current commitment = Paint
  live coverage      = no (Extra)

Project:
  Paint is covered because Mario covers it.
```

If Mario stops covering Paint and no other coverage source exists:

```text
Paint becomes needed again.
```

D3A establishes the backend truth and transition events only.

The chat drawer, system messages, notifications, attention badge/popover/shake, and final mobile coordination UI belong to D3B.

---

# 1. Canonical distinctions

Preserve all of these separately:

```text
Request selection
  → what requester offered

Acceptance decision
  → immutable needed / already_found / extra history

Membership commitment
  → mutable current expectation for one membership episode

Live coverage source
  → whether a current Project requirement is presently covered

Final actual contribution
  → one-time Project end attribution, later 05C
```

Do not infer one from another except through explicit domain rules below.

---

# 2. Acceptance-triage mapping

D1/D2 now define three acceptance dispositions.

## `needed`

At acceptance:

```text
membership commitment is seeded
AND
participant live-coverage assignment is seeded
```

So this person counts toward covering the requirement.

## `extra`

At acceptance:

```text
membership commitment is seeded
NO live-coverage assignment
```

They may still help/bring it, but they are not the source satisfying the Project requirement.

## `already_found`

At acceptance:

```text
NO membership commitment from this offer
the Project requirement remains covered
```

Implementation rule:

```text
if another tracked live coverage source already exists:
  do nothing extra

else:
  create organizer/manual external coverage
```

This captures the creator's statement that the need is already taken care of without falsely attributing it to this requester.

If the historical selected item is no longer a current Project requirement at acceptance time:

```text
do not create live coverage
```

The immutable `already_found` history remains.

---

# 3. Coverage is not the 04C3A open/closed lifecycle

Do not change:

```text
project_resource_needs.state
```

to represent coverage.

`open / closed` remains the creator-owned lifecycle of whether the need itself exists.

Coverage is dynamic operational state:

```text
open + uncovered
  → currently needed

open + covered
  → requirement exists but is currently taken care of

closed
  → no longer an active requirement
```

Likewise, Proposal skill attachment remains the requirement lifecycle; coverage is separate.

---

# 4. Current Project requirements

Coverage only applies to requirements that currently exist.

## Proposal / one-time

Skills:

```text
current public.proposal_skills rows
required + useful
```

Resources:

```text
public.project_resource_needs
state = open
```

## Tavolo / recurring

Skills:

```text
none
```

Resources:

```text
open Project resource needs
```

Do not invent Tavolo skill requirements.

---

# 5. Operational lifecycle

Live coverage mutations/reads are available only while the Project is operational.

Use the same operational semantics as C3C1 unless current repository evidence requires a narrower invariant:

## Proposal

```text
lifecycle_state = published
and statement_timestamp() < ends_at
```

## Tavolo

```text
published
or paused
```

After Proposal end/cancellation or Tavolo end:

```text
live coordination stops
```

Final contribution handling is later 05C.

Do not emit “needed again” because a Project ended.

---

# 6. Participant coverage tables

Add fail-closed relations equivalent to:

```text
public.project_membership_skill_coverages
public.project_membership_resource_coverages
```

Exact names may follow repository conventions.

## Skill coverage

Conceptual fields:

```text
membership_id
skill_id
covered_at
```

Primary key:

```text
(membership_id, skill_id)
```

Coverage must imply an existing membership skill commitment.

Prefer a composite restrictive FK:

```text
(membership_id, skill_id)
→ project_membership_skill_commitments
```

## Resource coverage

Conceptual fields:

```text
membership_id
resource_need_id
covered_at
```

Primary key:

```text
(membership_id, resource_need_id)
```

Coverage must imply an existing membership resource commitment.

Prefer a composite restrictive FK to the commitment table.

This gives the invariant:

```text
participant coverage ⇒ participant commitment
```

but not the reverse.

---

# 7. Organizer/manual external coverage tables

Add separate manual coverage markers.

Conceptually:

```text
public.project_manual_skill_coverages
public.project_manual_resource_coverages
```

They represent:

```text
the organizer knows this requirement is covered,
but not by a tracked participant coverage assignment
```

Typical origins:

- D1 `already_found` when no tracked source exists;
- later explicit organizer “found outside the app” action.

## Manual skill coverage

Conceptual fields:

```text
project_id
skill_id
marked_at
marked_by_profile_id
originating_request_id nullable
```

Unique identity:

```text
(project_id, skill_id)
```

Do not require the current `proposal_skills` row as a restrictive FK because Proposal skill requirements may be removed/re-added; instead validate current requirement status inside canonical mutations and clear live coverage when the requirement is removed.

## Manual resource coverage

Conceptual fields:

```text
resource_need_id
marked_at
marked_by_profile_id
originating_request_id nullable
```

Resource need already owns the Project relation.

One current manual marker per resource need.

---

# 8. Coverage truth

A current requirement is:

```text
covered
```

iff at least one current live source exists:

```text
participant coverage assignment
OR
manual/external coverage marker
```

Multiple participant coverage assignments are valid.

Example:

```text
Paint:
Mario covers
Lucia covers

Mario drops
→ Paint remains covered by Lucia
```

This supports redundancy accepted by the organizer.

Do not enforce exactly one provider.

---

# 9. Generic commitment edits do not automatically create coverage

C3C2 lets participants/creators add current commitments after acceptance.

Important rule:

```text
adding a commitment through generic commitment management
≠ automatically claiming the Project need
```

Such an addition is effectively “extra” until an explicit coverage action occurs.

This avoids losing the D1 distinction between:

```text
needed
vs
extra
```

Removing a commitment that currently supplies participant coverage **does** remove that coverage.

---

# 10. Acceptance integration

Evolve the D1 triaged acceptance transaction without changing its historical decision semantics.

After the new membership exists and needed/extra commitments have been seeded:

## `needed`

For each current-valid needed item:

```text
insert participant coverage assignment for new membership
```

## `extra`

```text
no coverage assignment
```

## `already_found`

For each still-current requirement:

```text
if total live coverage source count > 0:
  no-op

else:
  insert manual/external coverage marker
  marked_by = accepting creator
  originating_request_id = accepted request
```

The entire accept flow remains one transaction:

```text
decisions
request resolution
membership
commitment seeding
chat activation
coverage initialization
acceptance event
```

No half-state.

---

# 11. Existing-history backfill

Migration backfill must establish current coverage without changing historical commitments/decisions.

Process conceptually:

## Participant coverage

For current membership episodes:

```text
acceptance decision = needed
AND matching current commitment exists
AND requirement is currently active
→ insert participant coverage
```

Do not seed coverage from:

```text
extra
already_found
```

## Already-found manual coverage

After participant coverage backfill:

For applicable accepted `already_found` decisions where the requirement is currently active and operational:

```text
if no live source exists
→ create one manual marker
```

Use a deterministic historical source when multiple accepted requests contain `already_found`, e.g. the latest relevant acceptance decision.

Do not emit user-facing coverage-transition events during migration backfill.

---

# 12. Proposal skill removal must kill live coverage

This is critical.

If a Proposal skill requirement is removed:

```text
participant coverage for that Project+skill
manual coverage for that Project+skill
```

must stop being live.

Do not emit `needed_again` because the requirement itself no longer exists.

If the same skill is later re-added to the Proposal:

```text
it starts uncovered
```

unless someone explicitly covers it again.

Do not let stale old coverage resurrect.

Inspect the canonical Proposal skill replacement mutation and integrate this cleanup transactionally with its existing lock order.

Do not delete the membership commitment merely because the Proposal requirement was removed; C3C1 intentionally allows stale current commitments to survive.

---

# 13. Resource closing must stop live coverage

When an open Project resource need is closed:

```text
participant resource coverage
manual resource coverage
```

must stop being live.

Prefer cleaning the coverage rows transactionally as part of the canonical close operation.

Do not emit `needed_again` because a closed need is not currently required.

Do not reinterpret close as fulfillment.

If a reopen feature is introduced later, a reopened need should not silently inherit obsolete old coverage.

---

# 14. Removing a covered commitment

Evolve:

```text
replace_project_membership_commitments
```

so that before it removes a commitment, it removes any participant coverage assignment for that exact item.

After coverage removal:

```text
if another live source remains:
  requirement remains covered

if no source remains
AND requirement still exists
AND Project is operational:
  requirement becomes needed again
```

Then continue the commitment replacement.

Preserve the existing C3C1 compare-and-swap semantics.

Coverage cleanup and commitment replacement are one transaction.

---

# 15. Membership leave/removal

When a current membership ends because the participant:

```text
leaves
or
is removed
```

all participant coverage assignments owned by that membership cease.

Commitment rows remain as the ended membership's history, as C3C1 requires.

For each removed live coverage source:

```text
if it was the last source for an active operational requirement
→ emit needed-again transition
```

Preserve existing membership/chat history behavior.

Use a safe trigger or narrow canonical mutation integration according to repository structure.

---

# 16. Coverage transition events

Emit identifier-only canonical events for real transitions.

Suggested event names:

```text
project.requirement_covered
project.requirement_needed_again
```

Payload metadata conceptually:

```text
project_id
project_kind
requirement_kind   // skill | resource
requirement_id
actor_profile_id
```

Optional identifier-only source metadata is acceptable if clearly needed, e.g.:

```text
membership_id
```

Do not include:

- labels;
- resource titles;
- skill labels;
- request messages;
- user display names.

---

# 17. Transition rules

## Covered

Emit:

```text
project.requirement_covered
```

only when total live-source count transitions:

```text
0 → >0
```

Adding redundant second coverage does not emit another covered transition.

## Needed again

Emit:

```text
project.requirement_needed_again
```

only when:

```text
>0 → 0
```

AND the requirement still exists and Project is operational.

This is the future D3B trigger for:

- group system message;
- notification;
- Needs-button attention.

Do not emit needed-again when:

- requirement itself is removed;
- resource is closed;
- Project ended/cancelled.

---

# 18. Serialization / lock strategy

Coverage-source count transitions must be race-safe.

Prefer the existing Project-level lock hierarchy rather than introducing advisory locks.

Conceptually preserve:

```text
concrete Proposal/Tavolo
→ shared Project
→ membership when applicable
→ resource-need row when applicable
```

All live coverage changes for one Project should serialize through the shared Project mutation lock so two simultaneous source removals cannot both miss the `>0 → 0` transition.

Do not reverse 04C3A/C3C1/D1 lock ordering.

---

# 19. Participant claim RPC

Add an authenticated RPC equivalent to:

```text
claim_project_requirement(
  p_expected_participant_profile_id uuid,
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid
)
```

Exact naming may follow repository conventions.

Only a **current accepted participant** may claim.

Creator ownership alone is not a participant claim.

Supported requirement kinds:

```text
skill
resource
```

Tavolo skill claims reject.

---

# 20. Claim semantics

The requirement must be:

```text
current
operational
currently uncovered
```

If already covered:

```text
reject with a stable conflict
```

This protects the chat-drawer race where two people tap “I can bring this” simultaneously.

The first serialized claimant wins.

The second reloads and sees it covered.

---

# 21. Claim may create the commitment

If the participant already has the matching current commitment:

```text
add coverage only
```

This converts an existing “extra” commitment into a live covering source.

If the participant does not have the commitment:

```text
atomically add the commitment
then add coverage
```

Respect the existing independent maximum:

```text
50 skills
50 resources
```

If claim creates a commitment, emit the existing identifier-only:

```text
project.membership_commitments_updated
```

event according to C3C1 conventions.

Then emit `project.requirement_covered` only if this claim caused `0 → >0`.

---

# 22. Claim versus commitment editor concurrency

Claim must serialize with C3C1 commitment replacement through the membership/Project locks.

Required outcomes:

## Claim wins

```text
claim adds commitment/coverage
→ stale C3C2 editor save sees changed commitment set
→ existing CAS returns 40001
```

## Commitment replacement wins

```text
claim observes latest canonical commitment state
→ proceeds or rejects according to current requirement/coverage
```

Do not bypass C3C1's lost-update protection.

---

# 23. Creator manual coverage RPC

Add a creator-only RPC equivalent to:

```text
set_project_requirement_manual_coverage(
  p_expected_creator_profile_id uuid,
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid,
  p_is_covered boolean
)
```

This supports:

```text
"We found this outside the app."
```

and later:

```text
"Actually that source is no longer available."
```

No delegates yet.

---

# 24. Manual coverage behavior

## Set true

Requirement must be current and Project operational.

If manual marker already exists:

```text
idempotent success
```

If participant coverage already exists:

```text
manual marker may still be created
```

because the creator is explicitly recording an independent external source.

Only emit `requirement_covered` if total source count was previously zero.

## Set false

Remove the manual marker if present.

If another source remains:

```text
still covered
```

If no source remains and requirement is still active/operational:

```text
emit requirement_needed_again
```

No commitment rows are changed.

---

# 25. Acceptance `already_found` is conservative

The automatic `already_found` behavior differs slightly from an explicit manual-cover action:

```text
if another tracked coverage source already exists:
  do not create redundant manual marker

if none exists:
  create manual marker
```

This prevents an “Already found” response that merely refers to an existing participant from accidentally keeping the need covered forever after that participant later drops.

An explicit creator `set manual coverage = true` does create the independent marker.

---

# 26. Authorized coverage read

Add a private operational read equivalent to:

```text
list_project_live_requirement_coverage(
  p_expected_profile_id uuid,
  p_project_id uuid
)
```

Authorized viewers:

```text
canonical Project creator
OR current accepted participant
```

Former members denied.

Anonymous denied.

---

# 27. Coverage read shape

Return one normalized row per current requirement:

```text
requirement_kind
requirement_id
label
importance
is_covered
viewer_is_covering
is_manually_covered
```

Where:

```text
requirement_kind ∈ { skill, resource }
```

`importance`:

```text
required / useful for Proposal skills
null for resource needs
```

Current canonical labels only.

Deterministic ordering:

```text
skills first by catalog/category order
resources second by resource creation order
```

For creator:

```text
viewer_is_covering = false
```

unless repository conventions define otherwise; creator is not a membership episode.

Do not return provider display names in this slice.

---

# 28. Read is current operational state only

The read should fail/return unavailable according to repository conventions when the Project is no longer operational.

It is not historical coverage.

Historical accepted commitments remain available through C3C.

Final contribution history is later 05C.

---

# 29. Public discovery remains unchanged

Do not modify anonymous/public Proposal/Tavolo discovery in D3A.

Covered requirements may still be visible/selectable in the existing public/join experience for now.

Acceptance triage can classify later offers as:

```text
Already found
Extra
```

D3B or a later discovery-polish slice may expose coverage hints publicly.

Do not silently alter public pagination/contracts here.

---

# 30. No participant names in coverage state

D3A answers:

```text
covered?
do I cover it?
manual/external source?
```

It does not expose:

```text
who else covers it
```

This keeps the group coordination contract narrow.

If later UI needs provider identities, design a separate authorized group-member view.

---

# 31. RLS / grants

All coverage tables:

- RLS enabled;
- no direct client policies;
- no direct anon/authenticated/service table privileges;
- public mutations/reads through hardened RPCs only;
- private helpers not executable by client roles;
- fixed/empty `search_path`;
- expected identity checks.

No anonymous coverage reads.

---

# 32. Structural pgTAP

Cover at minimum:

- participant skill/resource coverage tables;
- manual skill/resource coverage tables;
- PKs/FKs;
- participant coverage implies matching commitment;
- manual-marker uniqueness;
- originating request provenance nullable;
- RLS;
- no direct policies/grants;
- claim RPC signature;
- manual coverage RPC signature;
- live coverage read signature;
- identifier-only event helper contract.

---

# 33. Behavioral pgTAP — acceptance mapping

Cover:

```text
needed
→ commitment + participant coverage

extra
→ commitment only

already_found with existing participant coverage
→ no new manual marker

already_found without existing coverage
→ manual marker

already_found for stale/non-current requirement
→ no live coverage
```

Mixed requests must produce exact expected state.

Acceptance decision rows remain unchanged.

---

# 34. Behavioral pgTAP — live truth

Cover:

- one participant source → covered;
- two participant sources → covered;
- one source removed while another remains → still covered/no needed-again event;
- last participant source removed → uncovered + one needed-again event;
- manual source preserves coverage after participant source removal;
- clearing last manual source → uncovered + needed-again;
- redundant source add emits no duplicate covered transition.

---

# 35. Behavioral pgTAP — commitment interaction

Cover:

- generic commitment addition does not create coverage;
- covered commitment removal removes participant coverage;
- stale commitment may remain without coverage after requirement removal;
- claim with existing extra commitment adds coverage only;
- claim without commitment adds commitment + coverage;
- claim respects 50/50 commitment limits;
- claim on already-covered requirement conflicts.

---

# 36. Behavioral pgTAP — lifecycle cleanup

Cover:

- participant leave removes all their live coverage;
- creator removal removes all their live coverage;
- ended membership commitments remain historical;
- removed Proposal skill clears coverage without needed-again event;
- re-added Proposal skill starts uncovered;
- closed resource clears/invalidates coverage without needed-again;
- Project end prevents further live-coverage mutation.

---

# 37. Concurrency coverage

Add deterministic races for at least:

## Two participants claim same uncovered requirement

```text
one claim commits
one claim conflicts
exactly one 0→covered transition
```

## Participant claim vs commitment replacement

Preserve CAS behavior described above.

## Last two coverage sources removed concurrently

Project-level serialization must yield:

```text
exactly one needed-again transition
```

not zero and not duplicates.

## Manual clear vs participant claim

Valid serializations:

```text
claim first:
  manual clear leaves participant coverage → still covered

manual clear first:
  needed-again may occur
  then claim covers again
```

Events must reflect real ordered transitions.

## Coverage removal vs resource close / Proposal skill removal

If requirement-removal wins:

```text
no needed-again event
```

If coverage removal wins while requirement is still current:

```text
needed-again may emit
then requirement may be removed
```

Both are valid serializations.

---

# 38. Real OTP integration

Add a focused verifier, or extend existing contribution/commitment verifiers cleanly.

Cover real authenticated flows:

1. creator publishes Proposal with skills/resources;
2. requester offers mixed items;
3. creator accepts with needed/extra/already-found;
4. verify acceptance decisions unchanged;
5. verify commitments;
6. verify coverage mapping;
7. second participant can provide redundant needed coverage;
8. remove one source, still covered;
9. remove last source, needed-again event;
10. current participant claims uncovered requirement;
11. claim creates commitment if needed;
12. extra commitment can later claim;
13. creator marks external/manual covered;
14. participant drops while manual keeps coverage;
15. creator clears manual → needed again;
16. Proposal skill removal/re-add does not resurrect old coverage;
17. resource close suppresses resurfacing;
18. Tavolo resource-only coverage;
19. rejoin uses new membership episode;
20. events contain identifiers only.

Never print OTPs, access tokens, private messages, labels, private emails, or protected meeting details.

Wire into Database validation/check scripts according to current conventions.

---

# 39. Generated types

Update generated public types for:

- coverage tables where included;
- live coverage read RPC;
- claim RPC;
- manual coverage RPC;
- any evolved acceptance/commitment signatures if changed.

If canonical generation remains blocked:

- derive compile-required deltas carefully;
- mark them explicitly unverified;
- keep `db:types:check` a hard pre-merge gate.

---

# 40. Documentation / roadmap split

Refine D3:

```text
04C3D3 — Live Need Coverage + Group Coordination (parent)

04C3D3A — Live Project Requirement Coverage Domain
  this plan

04C3D3B — Group Needs Coordination + Chat Resurfacing
  not started
  - chat-bottom Needs button
  - upward drawer
  - participant claim action
  - system message when needed again
  - notification / attention badge-popover-shake
  - creator manual-found control
  - per-user attention acknowledgement if needed
```

Update 05C dependency wording to remain after the live coverage/group-coordination flow.

Do not implement D3B here.

---

# 41. D3B handoff contract

D3B should be able to rely on:

```text
list_project_live_requirement_coverage
```

for current canonical state.

The chat drawer can filter:

```text
is_covered = false
```

Participant button:

```text
claim_project_requirement
```

Creator action:

```text
set_project_requirement_manual_coverage
```

Future system-message/notification projection uses:

```text
project.requirement_needed_again
```

and optionally:

```text
project.requirement_covered
```

D3A should make these contracts sufficient without requiring direct table reads.

---

# 42. 05C handoff

Do not implement actual contribution finalization here.

Preserve the planned rule:

```text
one-time Project ends
→ remaining active membership commitments become default actual contribution attribution
```

Coverage history does not replace commitments for final attribution.

A participant may have:

```text
Extra commitment
→ not a live need coverage source
→ still potentially a real final contribution
```

This distinction is important.

`Substantial Effort / Energy` remains later 05C.

Tavolo final attribution remains deferred.

---

# 43. GitHub Actions / Docker policy

Continue the established policy:

```text
local non-DB checks
  → execute normally

Docker unavailable
  → migration replay / DB lint / advisors / pgTAP / real integrations /
    generated-type drift = not executed

GitHub Actions billing gate
  → attempt once
  → classify as external non-execution
  → no pointless rerun
```

Do not merge D3A or lower backend layers until required executable Database validation succeeds.

---

# Non-goals

Do not implement:

- Flutter chat Needs button;
- upward needs drawer;
- system chat messages;
- in-app/push notification projection;
- badge/popover/shake attention UI;
- per-user “seen resurfaced need” receipts;
- public coverage hints;
- provider names;
- delegate/co-organizer permissions;
- final actual contribution attribution;
- Substantial Effort / Energy;
- Tavolo skill requirements;
- negative/no-show reporting;
- public reviews/ratings;
- Scambio-Dona matching.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and D3A based on PR #64;
- [ ] exact prompt archived;
- [ ] participant skill/resource coverage sources exist;
- [ ] manual/external skill/resource coverage sources exist;
- [ ] coverage is separate from resource open/closed;
- [ ] `needed` acceptance seeds participant coverage;
- [ ] `extra` acceptance does not seed coverage;
- [ ] `already_found` keeps current requirement covered without redundant manual source when tracked coverage already exists;
- [ ] historical stale `already_found` creates no live coverage;
- [ ] existing D1 history backfilled deterministically;
- [ ] generic commitment additions do not automatically cover requirements;
- [ ] covered commitment removal releases coverage;
- [ ] membership leave/removal releases coverage;
- [ ] Proposal skill removal prevents later coverage resurrection;
- [ ] resource close prevents stale coverage reuse;
- [ ] current participant can claim uncovered requirement;
- [ ] claim may atomically create missing commitment;
- [ ] creator can set/clear manual external coverage;
- [ ] multiple participant sources supported;
- [ ] exact 0→covered event emitted once;
- [ ] exact covered→0 needed-again event emitted once;
- [ ] requirement removal/Project end does not create false needed-again events;
- [ ] current creator/member authorized coverage read exists;
- [ ] no former/public coverage read;
- [ ] RLS/grants fail closed;
- [ ] concurrency tests added;
- [ ] real OTP integration added;
- [ ] generated types updated where executable;
- [ ] roadmap split into D3A/D3B;
- [ ] no D3B/05C UI added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3D3A branch/base/PR**
3. **Changed files**
4. **Coverage-source schema**
5. **Manual/external coverage schema**
6. **Coverage truth rule**
7. **Needed acceptance mapping**
8. **Extra acceptance mapping**
9. **Already-found acceptance mapping**
10. **Existing-history backfill**
11. **Generic commitment-add behavior**
12. **Covered commitment removal**
13. **Membership leave/remove behavior**
14. **Proposal skill removal/re-add behavior**
15. **Resource close behavior**
16. **Participant claim RPC**
17. **Claim-created commitment behavior**
18. **Creator manual coverage RPC**
19. **Authorized coverage read**
20. **Coverage read shape**
21. **Covered transition event**
22. **Needed-again transition event**
23. **Audit/outbox privacy**
24. **Lock ordering**
25. **Claim-vs-claim concurrency**
26. **Claim-vs-CAS concurrency**
27. **Last-source removal concurrency**
28. **Manual-vs-participant concurrency**
29. **Requirement-removal race behavior**
30. **pgTAP**
31. **Real OTP integration**
32. **Acceptance/commitment/chat regressions**
33. **Generated types/drift**
34. **Local regression validation**
35. **Hosted Validation executed/not-executed**
36. **04C3D3B handoff**
37. **05C handoff**
38. **Warnings/blockers**
39. **Commit/PR reference**

Do not merge any PR.
