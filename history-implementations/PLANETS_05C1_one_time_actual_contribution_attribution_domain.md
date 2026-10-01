# PLANETS 05C1 — One-Time Project Actual Contribution Attribution Domain

**Roadmap area:** 05C — One-Time Project Actual Contribution Attribution  
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

PR #63 — 04C3D1 Join-Acceptance Contribution Triage
  e4b6d3a2da4dace419ae1474a0e2365eb7aaebcd

PR #64 — 04C3D2 Mobile Acceptance Triage
  aad4e238186315d57a1d33be30b7515221c17b61

PR #65 — 04C3D3A Live Requirement Coverage Domain
  f92d10aa5ad4f6f386ff07a222afbcc97db49e98

PR #66 — 04C3D3B1 Structured Resurfacing + Attention
  aed90e536cdbdc3ad6bb78dcfb55e76d2bfd860f

PR #67 — 04C3D3B2 Mobile Needs Drawer + Chat Coordination
  codex/04c3d3b2-mobile-needs-chat-coordination
  e58b6d9e975765c9df45b32ed825bfa3f4e33119
```

All remain intentionally open/unmerged because the lower database stack still requires executable Database validation.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the dependency stack in order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any existing PR;
5. branch this plan from the final PR #67 head;
6. open the new PR with base:
   `codex/04c3d3b2-mobile-needs-chat-coordination`.

Preferred branch:

```text
codex/05c1-actual-contribution-attribution-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05C1_one_time_actual_contribution_attribution_domain.md
```

No external document is required by Codex.

Do not merge any PR.

---

# Objective

Implement the canonical backend representation of **what each accepted participant actually contributed to a completed one-time Project**.

This is not a rating/review system.

The intended chain is:

```text
join-request offer
→ acceptance triage
→ mutable current commitment
→ live need coverage
→ actual contribution attribution after the Proposal ends
```

Actual contribution attribution should be mostly automatic.

For a published one-time Proposal that has ended:

```text
membership was active at Proposal ends_at
+
that membership's frozen final commitments
=
automatic actual-contribution baseline
```

The creator only manages exceptions:

```text
- "They ultimately did NOT do/bring this."
- "They did this even though it was not in their final commitment."
- "They contributed substantial effort/energy that is not well represented
   by a skill or material."
```

No positive approval/review pass is required for every participant.

---

# 1. No cron / no scheduled snapshot

Do not add:

- cron;
- background scheduler;
- end-time worker;
- delayed job whose purpose is to copy commitments at `ends_at`.

Repository invariants already provide a stable source:

```text
Proposal content:
  published Proposal cannot be edited after starts_at

Membership commitments:
  cannot change once statement_timestamp() >= ends_at
```

Therefore the automatic baseline is permanently derivable after Proposal end.

This is the canonical design.

Do not materialize a duplicate baseline merely because the Project ended.

---

# 2. Eligibility — one-time published ended Proposals only

05C1 supports only:

```text
project_kind = one_time
proposal.lifecycle_state = published
proposal.ends_at <= statement_timestamp()
```

Both derived phases are eligible:

```text
just_finished
completed
```

Do not require waiting 24 hours.

Reject:

```text
draft
published but not yet ended
cancelled
Tavolo / recurring
```

Cancelled-Proposal contribution semantics are deferred rather than guessed.

Tavoli remain explicitly deferred.

---

# 3. Automatic baseline membership eligibility

A membership episode receives automatic baseline credit only if it was active at the Proposal's exact end instant.

Use the existing half-open membership semantics.

Conceptually:

```text
membership.joined_at <= proposal.ends_at
AND
(
  membership has no end
  OR
  proposal.ends_at < membership end
)
```

where membership end is:

```text
coalesce(left_at, removed_at)
```

If:

```text
left_at = ends_at
or
removed_at = ends_at
```

the membership was not active at the end.

---

# 4. Memberships ended before Project end

If a person left/was removed before `ends_at`:

```text
automatic baseline = empty
```

Do not assume their old commitments were actual contributions.

However the creator may still manually attribute real contributions to that membership episode after the Project ends.

Example:

```text
Mario helped build the structure on Saturday,
then left the Project before the Sunday end time.

automatic baseline:
  []

creator correction/addition:
  [ Carpentry ]
  [ Substantial Effort / Energy ]
```

This preserves conservative automatic attribution without erasing real earlier work.

---

# 5. Memberships ending after Project end

If the membership was active at `ends_at` and later leaves/is removed:

```text
automatic baseline remains based on the end-time membership episode
```

Later membership lifecycle changes do not alter the Project-end baseline.

Rejoin episodes remain independent.

---

# 6. Automatic contribution baseline

For an eligible membership episode:

## Skills

Automatic actual skills are the membership's final rows in:

```text
project_membership_skill_commitments
```

## Resources

Automatic actual resources are the membership's final rows in:

```text
project_membership_resource_commitments
```

This baseline includes all final commitments regardless of how they became commitments:

```text
Needed acceptance
Extra acceptance
later generic commitment addition
claim from Needs drawer
```

Live coverage is not the source of contribution credit.

An Extra commitment may therefore become a real actual contribution.

---

# 7. Coverage history is not contribution credit

Do not derive actual contribution from:

```text
project_membership_*_coverages
manual coverage
needed-again system events
coverage transition events
```

Coverage answers:

```text
"Was this Project requirement operationally taken care of?"
```

Actual attribution answers:

```text
"What did this participant actually do/bring?"
```

They are intentionally different.

---

# 8. Sparse override model

Do not copy the baseline into another table.

Store only deviations from the automatic baseline.

Preferred schema:

```text
public.project_membership_actual_skill_overrides
public.project_membership_actual_resource_overrides
public.project_membership_actual_effort_markers
```

Exact names may follow repository conventions.

---

# 9. Skill override table

Conceptual shape:

```text
membership_id uuid
skill_id uuid
is_included boolean
updated_at timestamptz
updated_by_profile_id uuid
```

Primary key:

```text
(membership_id, skill_id)
```

Meaning:

```text
no row
  → use automatic baseline truth

is_included = false
  → creator explicitly excludes an automatic-baseline skill

is_included = true
  → creator explicitly adds a non-baseline actual skill
```

Canonical mutations should keep overrides sparse:

```text
if desired truth equals baseline truth
→ remove override row
```

So redundant `true` over a baseline contribution and redundant `false` over a non-baseline item do not remain.

---

# 10. Resource override table

Same pattern:

```text
membership_id
resource_need_id
is_included
updated_at
updated_by_profile_id
```

Primary key:

```text
(membership_id, resource_need_id)
```

No baseline copy.

---

# 11. Substantial Effort / Energy marker

Add a separate canonical marker equivalent to:

```text
public.project_membership_actual_effort_markers
```

Conceptual shape:

```text
membership_id primary key
marked_at
marked_by_profile_id
```

Presence means:

```text
Substantial Effort / Energy = attributed
```

Absence means not attributed.

This is a built-in actual-contribution marker.

It is **not**:

- a skill catalog row;
- a Project resource need;
- a matching/search resource;
- a Scambio-Dona item;
- a live coverage requirement.

Do not pollute any requirement/matching taxonomy with it.

---

# 12. Effective actual-contribution truth

For each eligible membership and skill/resource ID:

```text
baseline := automatic final commitment if membership active at Project end

if sparse override exists:
  effective := override.is_included
else:
  effective := baseline
```

Effort:

```text
effective effort := marker exists
```

This rule is canonical.

---

# 13. Participant/creator read

Add a read equivalent to:

```text
list_project_membership_actual_contributions(
  p_expected_profile_id uuid,
  p_membership_id uuid
)
```

Authorize only:

```text
membership participant
OR
canonical Project creator
```

Future delegates may extend this later.

No public read.

---

# 14. Actual-contribution read shape

Return a normalized strict row set conceptually:

```text
contribution_kind
contribution_id
label
attribution_source
```

Kinds:

```text
skill
resource
substantial_effort
```

For skill/resource:

```text
contribution_id = canonical UUID
label = current canonical label/title
```

For `substantial_effort`:

```text
contribution_id = NULL
label = NULL
```

The client localizes the built-in effort label.

Do not invent a fake UUID or fake catalog row.

---

# 15. Attribution source

Return/source-classify contributions as:

```text
final_commitment
creator_added
substantial_effort
```

A baseline item restored after an earlier exclusion should again resolve as:

```text
final_commitment
```

because the sparse override returns to baseline.

This source is factual provenance, not a quality score.

---

# 16. Read with zero contributions

If a valid membership has no effective actual contributions:

```text
return empty row set
```

That is valid.

Do not imply:

- no-show;
- bad behavior;
- failed participant;
- negative rating.

Negative reports remain a separate future moderation feature.

---

# 17. Creator contribution options read

Add a creator-only read equivalent to:

```text
list_project_membership_actual_contribution_options(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid
)
```

This supplies addable canonical skill/resource labels for future 05C2 editing.

No participant needs this mutation-options read.

---

# 18. Skill options

For one-time Proposal:

```text
current final proposal_skills
UNION
membership's automatic-baseline skill commitments
```

Why include baseline stale skills:

A participant may have retained a skill commitment that was removed from Proposal requirements before the event started.

The automatic baseline may therefore contain it.

The creator must be able to:

```text
exclude it
later undo that exclusion
```

without the skill disappearing from the correction surface.

Both `required` and `useful` Proposal skills are valid.

Do not allow arbitrary global catalog skills that were never associated with the Project/baseline.

---

# 19. Resource options

Allow:

```text
all project_resource_needs belonging to this Project
```

regardless of `open/closed`.

Actual contribution is historical fact after Project completion; a resource need being closed does not make the canonical resource identity disappear.

Baseline resource commitments are naturally included because they reference same-Project needs.

Do not allow another Project's resource need.

---

# 20. Creator-only CAS replacement RPC

Add an atomic full-set mutation equivalent to:

```text
replace_project_membership_actual_contributions(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid,

  p_expected_skill_ids uuid[],
  p_expected_resource_need_ids uuid[],
  p_expected_substantial_effort boolean,

  p_skill_ids uuid[],
  p_resource_need_ids uuid[],
  p_substantial_effort boolean
)
```

Exact parameter order may follow repository conventions.

All arguments required.

No unsafe partial-update overload.

---

# 21. Why CAS again

Even creator-only MVP can have:

```text
two devices
two tabs
future delegated organizer
```

Do not reintroduce last-writer-wins.

After locks:

1. derive canonical current effective actual skill/resource/effort set;
2. compare with expected snapshot order-insensitively;
3. if mismatch:
   ```text
   SQLSTATE 40001
   "Actual contributions changed since they were loaded."
   ```
4. no writes/events on conflict.

Same pattern as C3C1.

---

# 22. Desired-set validation

Independent limits:

```text
max 50 skill actual contributions
max 50 resource actual contributions
```

Keep parity with commitment/request limits.

Reject:

- null IDs;
- duplicates;
- cross-Project resources;
- unsupported skill additions.

Order irrelevant.

Boolean effort values required/non-null.

---

# 23. Skill desired-set rule

A desired skill is valid if:

```text
it belongs to the membership's automatic baseline
OR
it is a final/current Proposal skill
```

This allows:

- retaining stale baseline skill;
- removing stale baseline skill;
- restoring stale baseline after exclusion;
- adding a current Project skill that the participant did outside the commitment flow.

Do not allow arbitrary catalog skills.

---

# 24. Resource desired-set rule

A desired resource is valid if:

```text
resource_need.project_id = membership.project_id
```

Open/closed state does not matter after end.

Do not allow cross-Project IDs.

---

# 25. Reconcile sparse overrides

Given:

```text
baseline set
desired effective set
```

normalize to sparse truth.

For every relevant ID:

```text
baseline=true, desired=true
→ no override

baseline=true, desired=false
→ override false

baseline=false, desired=true
→ override true

baseline=false, desired=false
→ no override
```

Delete stale redundant override rows.

No separate baseline snapshot.

---

# 26. Effort reconciliation

```text
desired effort = true
→ ensure effort marker

desired effort = false
→ remove effort marker
```

No-op if already in desired state.

---

# 27. No-op behavior

If:

```text
expected = current
desired = current
```

return success without:

- override rewrites;
- effort timestamp rewrite;
- audit event;
- outbox event.

If expected is stale, reject with `40001` even when desired happens to equal newer canonical state.

---

# 28. Mutation timing / Project locking

Actual-contribution mutation is available only after valid one-time Proposal end.

Preserve lock order:

```text
concrete Proposal
→ shared Project
→ membership
→ resource rows if needed
```

Do not conflict with established participation/C3C/D3 locking.

Because Proposal content is immutable after start and commitments are frozen after end, this is mainly to serialize correction writers and protect canonical relationships.

---

# 29. Creator-only mutation authorization

For now:

```text
canonical Project creator only
```

Participant cannot directly change actual attribution.

Future delegates with contribution-management permission may be added later.

Do not implement delegate infrastructure here.

---

# 30. Participant correction/reminder is future

Do not implement:

- participant edit;
- participant dispute state;
- approval workflow;
- group vote;
- claim-survey.

Product direction:

```text
if participant notices a mistake
→ they may later use a private "remind creator" flow
```

That follow-up can use message/popup/notification UX later.

For 05C1, participant read-only visibility is sufficient.

---

# 31. Rejoin episode isolation

Each membership episode has independent actual attribution.

Example:

```text
membership A
  ended before Project end
  automatic baseline empty
  creator manually credits Carpentry

membership B
  active at Project end
  automatic baseline Paint
```

Do not merge episodes in canonical storage.

Later profile stats may aggregate them.

---

# 32. Automatic baseline uses membership-at-end, not current status today

Important:

```text
membership active at ends_at
```

is historical and stable.

If that membership leaves after the Proposal ended:

```text
baseline remains
```

Do not recompute automatic eligibility from today's `current` membership status.

Use the timestamp interval.

---

# 33. Actual contribution update event

Emit exactly one identifier-only event for a real mutation:

```text
project.actual_contributions_updated
```

Payload conceptually:

```text
project_id
project_kind = one_time
membership_id
participant_profile_id
actor_profile_id
```

Do not include:

- contribution labels;
- contribution ID arrays;
- effort text;
- request message;
- display names.

This event can support future stats/badges/notifications without leaking detail.

---

# 34. No event for automatic baseline

The automatic baseline is derived state.

Do not emit one event per final commitment merely because time passed.

No Project-end worker exists.

Only explicit creator corrections/additions emit the update event.

---

# 35. Stats/badges remain downstream

Do not implement:

- profile counters;
- badges;
- leaderboards;
- community scores.

05C1 only establishes canonical actual attribution.

A later stats/badge slice may read this domain or consume update events.

---

# 36. Cancellation remains deferred

For:

```text
proposal.lifecycle_state = cancelled
```

05C1 actual attribution APIs reject/unavailable.

Do not guess whether partial work before cancellation should receive automatic credit.

This can be designed later if needed.

---

# 37. No Tavolo final attribution

Recurring/Tavolo actual-contribution finalization remains deferred.

All 05C1 reads/mutations should fail closed for:

```text
project_kind = recurring
```

Do not infer finalization from participant leave or Tavolo end.

---

# 38. Project-wide "unattributed need" review is not canonical coverage history

Do not try to reconstruct:

```text
"which needs were uncovered exactly at ends_at"
```

from live-coverage tables in this slice.

The creator's later completion UI may highlight Project requirements that have no participant actual attribution, but that is an attribution aid—not a claim about exact end-time live coverage history.

Do not create a second coverage-history model inside 05C1.

---

# 39. RLS / grants

Override/effort tables:

- RLS enabled;
- no client policies;
- no direct anon/authenticated/service table grants;
- public client access only through hardened reads/mutation RPCs;
- fixed/empty search paths;
- private helpers not client-executable.

No public actual-contribution API.

---

# 40. Structural pgTAP

Cover at minimum:

- skill override table;
- resource override table;
- effort marker table;
- PKs/FKs/indexes;
- actor-profile FKs;
- sparse boolean override field;
- RLS;
- no direct policies/table grants;
- actual-contribution read RPC;
- options RPC;
- CAS replacement RPC exact signature/default absence;
- no Tavolo overload.

---

# 41. Behavioral pgTAP — automatic baseline

Cover:

1. membership active at end + skill commitment → automatic skill;
2. active at end + resource commitment → automatic resource;
3. Needed vs Extra coverage history does not matter;
4. membership left before end → no automatic baseline;
5. membership removed before end → no automatic baseline;
6. membership leaves after end → baseline remains;
7. membership removed after end → baseline remains;
8. exact membership end = Proposal end → not active at end;
9. rejoin episodes isolated.

---

# 42. Behavioral pgTAP — overrides

Cover:

```text
baseline true + desired false
→ sparse false override

baseline false + desired true
→ sparse true override

return desired to baseline
→ override row removed
```

Test both skills/resources.

Effective read must always reflect:

```text
baseline overridden by sparse correction
```

---

# 43. Behavioral pgTAP — stale baseline skill

Create a realistic stale baseline:

```text
participant committed skill
creator removed skill requirement before Proposal starts
participant retained stale commitment
Proposal ends
```

Then test:

- automatic baseline still credits it;
- creator may exclude it;
- creator may later restore it;
- it remains available for correction because it is baseline;
- arbitrary unrelated catalog skill still rejected.

---

# 44. Behavioral pgTAP — resource options

Cover:

- open same-Project resource addition;
- closed same-Project resource addition;
- baseline stale/closed resource retained/restored;
- other-Project resource rejected.

---

# 45. Behavioral pgTAP — effort marker

Cover:

- false → true;
- true → false;
- no-op true → true through full-set replacement;
- no duplicate marker;
- effort does not create:
  - skill row;
  - resource need;
  - coverage source;
  - matching state.

---

# 46. Behavioral pgTAP — lifecycle/auth

Cover:

- creator read after end;
- participant own read after end;
- unrelated profile denied;
- participant mutation denied;
- pre-end read/mutation rejected;
- cancelled rejected;
- Tavolo rejected;
- draft rejected;
- anonymous denied.

---

# 47. CAS tests

Cover:

```text
creator device A loads set X
creator device B loads set X

A saves Y
B saves Z using expected X
→ B receives 40001
→ Y remains canonical
```

Also:

- stale expected + desired equals current → still 40001;
- no-op emits no event;
- conflict writes no override/effort/event side effects.

---

# 48. Concurrency with post-end membership lifecycle

A participant may leave after `ends_at`.

Test creator actual-contribution correction racing with post-end leave/removal.

Both orderings must preserve the same automatic baseline because eligibility is evaluated at `ends_at`, not today's status.

Do not let post-end membership ending erase actual attribution.

Use canonical lock order.

---

# 49. Real OTP integration

Add a focused verifier covering:

1. creator publishes one-time Proposal;
2. participants join and acquire mixed Needed/Extra/later commitments;
3. one membership leaves before end;
4. another remains active through end;
5. move Proposal past end using test fixture/control consistent with current verifier conventions;
6. participant/creator reads automatic baseline;
7. coverage history does not alter attribution baseline;
8. creator removes a baseline item;
9. creator adds a current Proposal skill not in final commitment;
10. creator adds same-Project resource not in final commitment;
11. creator marks Substantial Effort / Energy;
12. participant sees own corrected result;
13. creator CAS conflict with two authenticated sessions;
14. post-end leave does not change baseline;
15. ended-before-end membership can receive creator-added real contribution;
16. Tavolo rejected;
17. event payload identifier-only;
18. no public leakage.

Never log:

- OTPs;
- access tokens;
- private messages;
- contribution labels in event payload dumps;
- private emails;
- protected meeting details.

Wire into Database validation/check scripts according to repository conventions.

---

# 50. Generated types

Update generated types for:

- override relations;
- effort relation;
- actual-contribution read RPC;
- options read RPC;
- CAS replace RPC.

If canonical generation remains unavailable:

- derive compile-required deltas carefully;
- mark them explicitly unverified;
- keep `db:types:check` as hard pre-merge gate.

---

# 51. Documentation / roadmap split

Refine roadmap:

```text
05C — One-Time Project Actual Contribution Attribution (parent)

05C1 — Actual Contribution Attribution Domain
  this plan
  automatic frozen final-commitment baseline
  sparse creator overrides
  off-app canonical additions
  Substantial Effort / Energy

05C2 — Mobile Actual Contribution Experience
  not started
  participant read-only contribution view
  creator correction UI
  post-end contribution management
```

Possible later follow-up, not part of 05C1/05C2:

```text
participant → Remind creator
private request/message/popup/notification
```

Group contribution claims/surveys remain a speculative future feature and should not enter the roadmap as required scope.

---

# 52. 05C2 handoff

D2/mobile should be able to rely on:

```text
list_project_membership_actual_contributions
list_project_membership_actual_contribution_options
replace_project_membership_actual_contributions
```

plus existing:

```text
list_project_members
own membership state
Project chat/group-info surfaces
```

Likely mobile placement:

```text
participant/former participant
→ Project group info
→ Actual contributions (read-only)

creator
→ Manage participation
→ member card
→ Actual contributions
→ edit after Project end
```

Do not implement mobile UI in 05C1.

---

# 53. 05C2 correction UX expectation

Backend design must support a future creator editor starting with:

```text
automatic final commitments
```

already selected.

Creator can then:

```text
uncheck something that did not happen
check canonical Project item that happened outside app
toggle Substantial Effort / Energy
```

No mandatory review/approval button for every person.

The backend should not require a Project-wide "review completed" state.

---

# 54. Validation policy

Run all available non-DB checks.

At minimum:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new/changed verifier>
git diff --check
```

Run SQL parse checks without Docker if available.

Attempt hosted Validation once.

If GitHub refuses runner startup because of billing/spending limits:

```text
not executed due external infrastructure
```

No pointless rerun.

Because 05C1 is schema-heavy, do not merge until:

- clean migration replay;
- DB lint/advisors;
- pgTAP;
- real OTP integration;
- generated-type drift

actually execute green.

---

# Non-goals

Do not implement:

- mobile 05C2 UI;
- participant mutation/dispute;
- participant "remind creator" workflow;
- group contribution survey;
- public ratings/reviews;
- no-show/problem reports;
- stats/badges;
- creator self-contribution/organizer credit;
- cancelled-Proposal contribution policy;
- Tavolo actual-contribution finalization;
- global notifications/push;
- free-form contribution text;
- new skill/resource taxonomy;
- coverage-history reconstruction.

Creator/organizer participation itself can be recognized separately later from Project ownership; do not invent a fake creator membership.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and 05C1 based on PR #67;
- [ ] exact prompt archived;
- [ ] one-time published ended Proposal is the only supported lifecycle;
- [ ] no cron/snapshot job added;
- [ ] automatic baseline derives from frozen final commitments;
- [ ] only membership episode active at `ends_at` gets automatic baseline;
- [ ] ended-before-end membership gets empty baseline;
- [ ] post-end leave/remove does not change baseline eligibility;
- [ ] skill/resource sparse override tables exist;
- [ ] Substantial Effort / Energy uses separate marker;
- [ ] effort is not a fake Project resource/skill;
- [ ] effective truth is baseline + sparse override;
- [ ] participant/creator read exists;
- [ ] creator-only options read exists;
- [ ] creator-only CAS replacement exists;
- [ ] CAS expected/desired includes effort state;
- [ ] skill additions limited to final Project skills or baseline skills;
- [ ] resource additions limited to same Project;
- [ ] closed Project resources may be attributed;
- [ ] stale baseline skill/resource can be excluded/restored;
- [ ] overrides normalize away when returning to baseline;
- [ ] no-op rewrites/events avoided;
- [ ] real changes emit one identifier-only update event;
- [ ] no event emitted merely because Proposal time ended;
- [ ] participant mutation denied;
- [ ] Tavolo/cancelled/pre-end rejected;
- [ ] RLS/grants fail closed;
- [ ] pgTAP and real integration added;
- [ ] generated types updated where executable;
- [ ] roadmap split into 05C1/05C2;
- [ ] no 05C2 UI/stats/moderation added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **05C1 branch/base/PR**
3. **Changed files**
4. **Automatic baseline rule**
5. **Membership-at-end rule**
6. **Ended-before-end behavior**
7. **Post-end leave/remove behavior**
8. **Skill override schema**
9. **Resource override schema**
10. **Substantial Effort / Energy schema**
11. **Effective attribution rule**
12. **Actual-contribution read RPC**
13. **Read authorization**
14. **Attribution-source behavior**
15. **Creator options read**
16. **Skill option/addition rules**
17. **Resource option/addition rules**
18. **CAS replacement signature**
19. **CAS conflict behavior**
20. **Sparse override reconciliation**
21. **Effort reconciliation**
22. **No-op behavior**
23. **Rejoin episode isolation**
24. **Cancelled/Tavolo handling**
25. **Update event/privacy**
26. **RLS/grants**
27. **pgTAP**
28. **Real OTP integration**
29. **Post-end lifecycle concurrency**
30. **Generated types/drift**
31. **Local regression validation**
32. **Hosted Validation executed/not-executed**
33. **05C2 handoff**
34. **Reminder-creator future handoff**
35. **Warnings/blockers**
36. **Commit/PR reference**

Do not merge any PR.
