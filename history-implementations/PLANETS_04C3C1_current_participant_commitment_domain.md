# PLANETS 04C3C1 — Accepted Participant Current Commitment Domain Foundation

**Roadmap area:** PLANETS 04C3C — Accepted Participant Contribution Commitments  
**Task type:** Backend/domain foundation over stacked 04C3A + 04C3B1 + 04C3B2  
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

PR #60 — 04C3B2 Mobile Contribution Selection + Rounded Messages Labels
  codex/04c3b2-mobile-contribution-selection
  058e8b03c8905048cff2e8e78f80b3488686fbf0
```

All are intentionally unmerged because executable Database validation is currently unavailable.

Before implementing:

1. fetch current `origin/main`;
2. if main advanced, rebase #45 onto main;
3. rebase #52 onto the updated #45 head;
4. rebase #60 onto the updated #52 head;
5. preserve all unrelated SITE/CI/tooling work;
6. branch this plan from the final PR #60 head;
7. open this PR with base:
   `codex/04c3b2-mobile-contribution-selection`.

Preferred branch:

```text
codex/04c3c1-current-participant-commitments
```

Do not merge any PR in the stack.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3C1_current_participant_commitment_domain.md
```

---

# Objective

Introduce the canonical **current contribution commitment state for an accepted membership episode**.

This solves the product distinction discussed by the founder:

```text
Historical join request
  "When I applied, I said I could bring Paint + Ladder"

Current accepted commitment
  "I can still bring Paint, but I can no longer bring Ladder"
```

The historical request must never be rewritten.

Current commitments are a separate mutable domain.

Conceptually:

```text
Join request selections
    immutable history
          ↓ acceptance
Current membership commitments
    initialized from that request
          ↓
participant / creator can update current commitment
          ↓
future 05C verifies what was ACTUALLY contributed
```

04C3C1 is backend/domain only.

It does **not** choose whether the future mobile editing UI lives in:

- Project group-chat info;
- My Projects / organizer management;
- both.

It also does not implement delegates/co-organizers.

---

# 1. Membership episode is the canonical owner

Current commitments belong to:

```text
project_memberships.id
```

not merely:

```text
(project_id, participant_profile_id)
```

Reason:

```text
join
→ leave/remove
→ later request again
→ accept again
```

creates distinct membership episodes.

Each new accepted membership must receive its own current commitment state derived from its own originating request.

Do not let a rejoined participant inherit mutable commitments from an older membership episode.

Historical ended membership commitments remain attached to the ended membership for audit/history.

---

# 2. Domain distinctions

Keep these concepts separate:

```text
project_resource_need
  what the Project asks for

project_join_request_*_selections
  immutable selections the applicant made when requesting

project_membership_*_commitments
  mutable current accepted-participant commitment state

future verified contribution
  what the creator later confirms actually happened
```

Do not collapse any of them.

In particular:

```text
commitment != fulfilled
commitment != verified
commitment != credit/badge
```

---

# 3. Commitment tables

Add canonical relations equivalent to:

```text
public.project_membership_skill_commitments
public.project_membership_resource_commitments
```

Exact names may follow repository conventions.

## Skill commitment

Conceptual fields:

```text
membership_id
skill_id
committed_at
```

Primary/unique identity:

```text
(membership_id, skill_id)
```

FKs:

```text
membership_id → project_memberships
skill_id      → skills
```

## Resource commitment

Conceptual fields:

```text
membership_id
resource_need_id
committed_at
```

Primary/unique identity:

```text
(membership_id, resource_need_id)
```

FKs:

```text
membership_id    → project_memberships
resource_need_id → project_resource_needs
```

Use restrictive foreign keys.

No direct-delete lifecycle API is needed; the replace operation owns current set mutation.

---

# 4. Do not add fulfillment semantics

Do not add fields such as:

```text
fulfilled
delivered
verified
completed
quantity
unit
value
credit
score
confirmed_by_creator
```

Presence in a commitment relation means only:

> This accepted membership currently says/records that this participant is expected to help with this canonical item.

It is not proof of actual contribution.

05C remains the later verification domain.

---

# 5. Seed from accepted request atomically

When a new membership is inserted from an accepted request, initialize its current commitments from the historical B1 request selections:

```text
request skill selections
  → membership skill commitments

request resource selections
  → membership resource commitments
```

The initial copy is by stable IDs only.

Do not copy labels.

Do not modify/delete the request selection rows.

## Preferred invariant mechanism

Inspect the latest 07B1 acceptance/chat implementation and current trigger set.

Prefer a private `AFTER INSERT` membership trigger or another narrow DB invariant mechanism if that safely guarantees:

```text
any canonical new membership
→ initial commitments seeded from originating_request_id
```

without rewriting or weakening the current `accept_project_join_request` chat-activation behavior.

If redefining `accept_project_join_request` is cleaner after repository inspection, preserve every existing acceptance/chat invariant exactly.

Either way, acceptance + membership + chat activation + commitment initialization must be one transaction.

---

# 6. Backfill existing membership episodes

The migration must initialize commitments for memberships already present when 04C3C1 lands.

For each existing membership:

```text
originating_request_id
→ existing request skill/resource selections
→ initial commitment rows
```

This applies to both:

```text
current memberships
ended memberships
```

Older requests with zero B1 selections simply produce zero commitment rows.

Backfill must be idempotent/safe within migration replay.

---

# 7. Initial commitment state ignores later option changes

Acceptance seeds the request's historical selections even if, between request and acceptance:

- a Proposal skill was removed from current requirements;
- a resource need was renamed;
- a resource need was closed.

Reason:

The initial accepted commitment answers:

> What did this accepted person say they could contribute on the accepted request?

The mutable commitment may then be corrected afterward.

Do not silently discard accepted request selections merely because the Project's currently requested options changed.

---

# 8. Current mutation API

Add one narrow replacement RPC equivalent to:

```text
replace_project_membership_commitments(
  p_expected_actor_profile_id,
  p_membership_id,
  p_skill_ids uuid[] default '{}',
  p_resource_need_ids uuid[] default '{}'
)
```

Return the membership ID or another repository-consistent success identity.

This is a **full desired-set replacement**, not per-chip direct table mutation.

The DB owns the atomic diff.

---

# 9. Who may mutate in 04C3C1

For a **current membership only**, mutation is allowed to:

```text
A. the membership participant
B. the canonical Project creator
```

This matches the founder direction that the participant may become unable to provide something and that the Project organizer must eventually be able to correct current contribution state.

Do not implement delegates/co-organizers yet.

Do not introduce generic admin roles.

Future scoped delegate authorization may extend this permission boundary without changing the commitment table model.

Expected actor must be bound to `auth.uid()`.

---

# 10. Read authorization

Add a narrow read RPC equivalent to:

```text
list_own_project_membership_commitments(
  p_expected_profile_id,
  p_membership_id
)
```

Authorized viewers:

```text
membership participant
OR
Project creator
```

Read must work for:

```text
current membership
ended membership
```

so the last declared commitment state remains visible as history.

Unrelated profiles fail closed.

Anonymous access denied.

---

# 11. Read shape

Return one normalized row per commitment:

```text
commitment_kind
commitment_id
label
```

where:

```text
commitment_kind ∈ { skill, resource }
```

Use current canonical labels:

```text
skills.label
project_resource_needs.title
```

Do not snapshot copied labels into commitment rows.

Deterministic order:

```text
skills first in canonical catalog/category order
resources second in resource-need creation order
```

or another documented stable order consistent with B1.

---

# 12. Input limits

Mirror the B1/request contract:

```text
max 50 skill commitments
max 50 resource commitments
```

Normalize null arrays to empty where consistent.

Reject:

- null IDs;
- duplicates;
- >50 IDs per group.

Do not silently truncate.

---

# 13. Existing current commitments may be retained after options change

This is important.

A current commitment may refer to a resource that later becomes closed or a Proposal skill that later stops being a current requirement.

The participant/creator must be able to **retain** such an existing commitment during an unrelated edit.

Therefore desired-set validation must distinguish:

```text
existing current commitment
vs
new addition
```

An ID in the desired set is valid when either:

```text
A. it is already a current commitment for this membership
OR
B. it is a currently selectable Project option
```

This prevents unrelated edits from forcing the removal of previously valid commitments.

---

# 14. New skill additions

For one-time Proposals, a newly added skill commitment must be a skill currently attached to the Proposal through:

```text
proposal_skills
```

Both `required` and `useful` remain valid.

For Tavoli:

```text
new skill commitment additions are not supported
```

because there is still no canonical Tavolo skill-requirement relation.

A Tavolo membership should normally have zero skill commitments.

Do not invent Tavolo skills here.

---

# 15. New resource additions

A newly added resource commitment must:

```text
belong to the same Project
state = open
```

Existing commitments may retain a resource after it later closes.

Once a closed/non-current resource commitment is removed from the membership, it cannot be newly re-added unless it becomes a valid current option under future product rules.

04C3A currently has no reopen operation, so this normally means it cannot be re-added.

---

# 16. Clearing commitments

An actor may replace the current set with:

```text
no skills
no resources
```

This is valid.

Example:

> The participant can no longer bring/help with any of the things originally selected.

Do not require at least one commitment.

Membership remains valid independently.

---

# 17. Project operational boundary

Commitments are mutable only while:

```text
membership is current
AND Project is still operational
```

Use repository lifecycle semantics.

Expected behavior:

## Proposal

Allow while:

```text
lifecycle_state = published
and statement_timestamp() < ends_at
```

This includes an event that has already started but not yet ended.

Deny after cancellation/end.

## Tavolo

Allow while:

```text
published
or paused
```

Deny after:

```text
ended
```

Paused Tavoli retain their current membership/coordination state, so commitment correction remains allowed.

Inspect actual lifecycle code and use canonical semantics if details differ.

---

# 18. Lock ordering

Preserve the established lock hierarchy.

For commitment replacement, use an order compatible with 05A/04C3A/B1, conceptually:

```text
concrete Proposal/Tavolo
→ shared Project
→ membership
→ resource-need rows
```

Do not begin by locking resource rows or membership in an order that can deadlock with:

- leave;
- remove member;
- Proposal skill update;
- resource-need close/update;
- Project lifecycle transition.

Reuse the existing participation Project-lock helper where sensible.

---

# 19. Leave/remove concurrency

Replacement racing:

```text
leave_project
remove_project_member
```

must serialize.

Valid outcomes:

### Replace wins first

```text
commitment update commits
→ leave/remove ends membership
→ final commitment state is retained as ended-membership history
```

### Leave/remove wins first

```text
membership becomes ended
→ commitment replacement rejects
```

A commitment update must never commit after observing a membership already ended.

Add concurrency coverage.

---

# 20. Resource-close concurrency

For a newly added resource commitment:

```text
replace commitments
vs
close_project_resource_need
```

must serialize.

Valid outcomes:

### Commitment validation wins first

```text
new open need committed
→ creator closes need later
→ existing commitment remains historical/current until explicitly removed
```

### Need closure wins first

```text
need is closed
→ new addition rejected
```

Use deterministic resource row lock ordering.

---

# 21. Proposal-skill update concurrency

New skill addition must serialize with Proposal skill replacement.

If skill removal wins first:

```text
new commitment addition rejected
```

If commitment validation wins first:

```text
commitment inserted
→ Proposal requirement may later be removed
→ existing commitment survives until explicitly changed
```

Use the existing Proposal row lock rather than advisory locks.

---

# 22. Idempotent/no-op replacement

If the desired sets equal the current sets:

- return success;
- do not rewrite rows unnecessarily;
- preferably do not emit a duplicate update event.

Document exact behavior.

Ordering of caller arrays must not make equal sets appear different.

---

# 23. Mutation event

For a real current-set change, emit a content-free event such as:

```text
project.membership_commitments_updated
```

Audit/outbox metadata should contain identifiers only, conceptually:

```text
project_id
project_kind
membership_id
participant_profile_id
actor_profile_id
```

Do not include:

- skill IDs;
- resource-need IDs;
- labels;
- counts if unnecessary;
- message text.

No notification projection in C1.

---

# 24. Initialization should not emit a second user notification event

Membership acceptance already has canonical participation/chat behavior.

Do not create an additional user-facing commitment-initialized notification/outbox event merely because the initial rows are seeded.

Initial commitment seeding is part of membership creation.

Only later mutable changes need their own identifier-only mutation event.

---

# 25. Ended membership history

When a participant:

```text
leaves
or
is removed
```

do not delete commitment rows.

The last current state becomes read-only history for that membership episode.

The participant and Project creator may still read it.

Do not automatically mark anything as fulfilled.

---

# 26. Rejoin semantics

If a former participant later:

```text
submits a new request
→ creator accepts
→ new project_memberships row
```

the new membership gets a fresh commitment set derived from the **new request selections**.

Do not copy commitments from the old membership.

This must be tested.

---

# 27. Request history remains immutable

Updating current commitments must not alter:

```text
project_join_request_skill_selections
project_join_request_resource_selections
```

A request detail in Messages must continue showing what was originally selected.

Future mobile commitment UI may display both:

```text
Requested originally
Current commitment
```

without ambiguity.

---

# 28. No creator/delegate UI yet

04C3C1 is backend only.

Do not modify Flutter to choose:

- group chat info;
- My Projects;
- participant management.

Do not create a commitment-edit route.

Do not implement delegate permissions.

A later 04C3C2 will decide/expose the mobile management surface.

---

# 29. No delegated organizer schema

Do not add:

```text
project_admins
project_delegates
roles
permissions
permission JSON
```

inside this plan.

Delegated Project management is broader than contribution commitments and should be designed separately.

The current creator authorization should be written so a future scoped-authorization helper can expand it without replacing commitment tables.

---

# 30. RLS / grants

Both commitment tables:

- RLS enabled;
- no client policies;
- no direct anon/authenticated/service table privileges;
- mutation/read through hardened RPCs;
- fixed/empty security-definer search paths;
- narrow explicit grants.

No public commitment read.

---

# 31. Structural pgTAP

Cover at minimum:

- both tables exist;
- composite PKs;
- restrictive membership/skill/resource FKs;
- timestamps;
- RLS;
- no policies/direct grants;
- expected read/mutation RPC signatures;
- no fulfillment/verification/quantity/status fields;
- no delegate/admin tables;
- max-input validation exists;
- identifier-only update event contract.

---

# 32. Behavioral pgTAP

Cover:

## Acceptance initialization

- Proposal accepted request with skill/resource selections seeds exact current commitments;
- empty-selection request seeds none;
- Tavolo resource selection seeds correctly;
- request-selection rows remain unchanged.

## Authorization

- participant can read;
- creator can read;
- unrelated denied;
- participant can replace own;
- creator can replace member's;
- unrelated denied;
- stale expected identity denied.

## Mutation

- remove one original commitment;
- clear all;
- add a newly current Proposal skill;
- add a newly open Project resource;
- >50/duplicates/null rejected atomically.

## Existing stale commitments

- remove Proposal skill after acceptance: existing commitment still readable/retainable;
- close resource after acceptance: existing commitment still readable/retainable;
- once removed, stale option cannot be newly re-added.

## End lifecycle

- leave preserves final commitments;
- remove preserves final commitments;
- ended membership cannot mutate.

## Rejoin

- second membership seeds only new request selections;
- old membership's commitments remain separate.

## Events

- update event identifier-only;
- no labels/arrays/text leakage;
- no event for no-op if that is the chosen contract.

---

# 33. Concurrency pgTAP/integration

Add focused deterministic races for:

1. replace vs leave;
2. replace vs creator removal;
3. new resource addition vs resource close;
4. new Proposal skill addition vs Proposal skill removal.

Each must produce one valid serialization.

Do not use arbitrary sleeps as the correctness mechanism where DB locks can prove behavior; existing integration style may use short observation delays only to assert that a competing operation is blocked.

---

# 34. Real local integration

Add a verifier such as:

```text
scripts/verify-local-project-membership-commitments.mjs
```

Use real OTP identities and the canonical shared local auth helper.

Suggested flow:

1. creator publishes Proposal with skill requirements;
2. creator creates open resource needs;
3. requester submits request selecting skill + resource;
4. creator accepts;
5. membership current commitments equal request selections;
6. request historical selections still equal original selections;
7. participant removes one current commitment;
8. creator reads updated state;
9. participant adds another currently valid option;
10. creator replaces state as organizer;
11. Proposal skill removed / need closed after existing commitment;
12. existing commitment can remain;
13. after explicit removal, stale option cannot be re-added;
14. leave or remove preserves last state but blocks later edit;
15. new request/reaccept creates new membership with independent commitments;
16. cover Tavolo resource-only case;
17. assert identifier-only mutation events;
18. run concurrency cases.

Never print:

- OTP;
- access token;
- private message;
- commitment labels;
- private emails;
- protected meeting information.

Wire into `check:db` and Database CI.

---

# 35. Generated types

Regenerate public DB types.

Expected additions:

```text
project_membership_skill_commitments
project_membership_resource_commitments
replace_project_membership_commitments
list_own_project_membership_commitments
```

plus any private invariant helper remains private.

Do not hand-edit generated output when a real generator is available.

If Docker and hosted Actions are still unavailable:

- derive compile-required types carefully;
- mark them explicitly unverified;
- require canonical `db:types:check` before merge.

---

# 36. Existing acceptance/chat regression

Because commitment initialization touches membership creation, explicitly prove existing behavior remains unchanged:

- accept request;
- exactly one membership;
- chat activates on first accepted member;
- repeated/invalid acceptance still fails as before;
- creator/current/former chat authorization unchanged;
- no message history semantics change;
- no notification payload changes.

Do not rewrite chat behavior.

---

# 37. Documentation / roadmap split

Refine 04C3C:

```text
04C3C — Accepted Participant Contribution Commitments (parent)

04C3C1 — Current Commitment Domain Foundation
  this plan
  membership-scoped mutable state

04C3C2 — Mobile Commitment Management
  not started
  decides/exposes editing surface
  participant + creator UX

Delegated Project management
  separate future product/authorization plan
```

Do not prematurely decide group-info vs My Projects.

Update 05C to remain after 04C3C current commitments.

Document:

```text
request selections = historical intent
membership commitments = mutable current expectation
05C = verified actual contribution
```

---

# 38. Stack status

Roadmap/docs must report accurately:

```text
04C3A  PR #45 open/unmerged
04C3B1 PR #52 open/unmerged
04C3B2 PR #60 open/unmerged
04C3C1 this stacked PR in progress
```

Do not mark any unmerged plan implemented.

---

# 39. GitHub Actions billing / local Docker

Hosted Actions may still be blocked before runner startup by billing/spending limits.

Local Docker may still be unavailable.

Continue implementation and local non-DB validation.

Report separately:

```text
executed and passed
executed and failed
not executed due external infrastructure
```

Do not merge this backend stack until migration replay, pgTAP, integration, and generated-type drift execute successfully.

Do not repeatedly rerun a workflow that cannot start due billing.

---

# Non-goals

Do not implement:

- commitment Flutter UI;
- group-chat info commitment modal;
- My Projects commitment editor;
- delegate/co-organizer roles;
- generic Project administrators;
- final contribution verification;
- fulfilled/delivered state;
- badges/stats;
- quantities/units;
- free-form contribution categories;
- Tavolo skill requirements;
- notifications for commitment changes;
- Scambio-Dona matching/linkage.

---

# Acceptance criteria

Ready for review when:

- [ ] stack rebased correctly and C1 is based on PR #60;
- [ ] exact prompt archived;
- [ ] commitments are membership-episode-scoped;
- [ ] skill/resource current tables exist;
- [ ] acceptance seeds initial state from immutable request selections;
- [ ] existing memberships are backfilled;
- [ ] request history is never rewritten;
- [ ] participant and creator may mutate current membership state;
- [ ] unrelated users may not read/mutate;
- [ ] former memberships remain readable but immutable;
- [ ] rejoin gets an independent fresh state;
- [ ] existing stale commitments may be retained;
- [ ] newly added skills/resources must be current valid options;
- [ ] removed stale options cannot be re-added;
- [ ] clear-all is allowed;
- [ ] Proposal happening-before-end remains editable;
- [ ] paused Tavolo remains editable;
- [ ] ended/cancelled Project commitment mutation denied;
- [ ] max 50 per group, duplicates/null rejected;
- [ ] lock order is compatible with participation/resource/Proposal mutations;
- [ ] leave/remove/need-close/skill-update races are tested;
- [ ] mutation events contain identifiers only;
- [ ] initial acceptance does not create redundant user notification events;
- [ ] acceptance/chat behavior regresses cleanly;
- [ ] RLS/grants fail closed;
- [ ] pgTAP + real integration added;
- [ ] generated types updated where executable;
- [ ] hosted CI status reported truthfully;
- [ ] no Flutter UI/delegate roles added;
- [ ] no PR merged.

---

# Autonomy / stop conditions

Codex may decide:

- exact table/function/trigger names;
- whether initialization is best enforced by membership trigger or safe acceptance-function extension;
- exact timestamp column naming;
- exact deterministic read ordering;
- narrow private helper structure.

Stop and report before:

- adding delegate/co-organizer roles;
- choosing final mobile edit location;
- adding fulfillment/verification;
- altering historical request-selection semantics;
- changing membership/chat history rules;
- making commitment data public;
- adding notifications;
- merging any PR.

---

# Deliverables

1. stack reconciliation;
2. exact archived C1 prompt;
3. membership skill commitment table;
4. membership resource commitment table;
5. acceptance initialization invariant;
6. existing-membership backfill;
7. participant/creator replacement RPC;
8. participant/creator authorized read RPC;
9. lifecycle + current-option validation;
10. identifier-only mutation event;
11. pgTAP structure/access/behavior/concurrency;
12. real Proposal/Tavolo commitment integration;
13. acceptance/chat regression coverage;
14. generated types;
15. docs/roadmap 04C3C1/C2 split;
16. focused stacked PR;
17. structured completion report.

Do not merge any PR.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3C1 branch/base/PR**
3. **Changed files**
4. **GitHub Actions / Docker status**
5. **Commitment schema**
6. **Membership-episode ownership**
7. **Acceptance initialization**
8. **Existing-membership backfill**
9. **Request-history preservation**
10. **Participant mutation authorization**
11. **Creator mutation authorization**
12. **Read authorization**
13. **Current canonical label resolution**
14. **Input limits**
15. **Existing stale commitment retention**
16. **New skill-addition validation**
17. **New resource-addition validation**
18. **Clear-all behavior**
19. **Proposal lifecycle behavior**
20. **Tavolo lifecycle behavior**
21. **Lock ordering**
22. **Leave/remove concurrency**
23. **Resource-close concurrency**
24. **Proposal-skill concurrency**
25. **Ended membership history**
26. **Rejoin independence**
27. **Audit/outbox privacy**
28. **No-op behavior**
29. **pgTAP**
30. **Real local integration**
31. **Acceptance/chat regression**
32. **Generated types/drift**
33. **Local regression validation**
34. **Hosted Validation executed/not-executed**
35. **04C3C2 mobile handoff**
36. **Delegated-management handoff**
37. **Warnings/blockers**
38. **Commit/PR reference**
