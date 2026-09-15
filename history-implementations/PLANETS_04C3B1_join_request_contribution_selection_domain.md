# PLANETS 04C3B1 — Join-Request Contribution Selection Domain

**Roadmap area:** PLANETS 04C3 — Project Resource Needs and Contribution Offers  
**Task type:** Backend/domain extension over 05A + 04C3A  
**Repository:** `lillo24/planets.community`

## Required base / stacking

04C3B1 depends directly on 04C3A, which is currently open as:

```text
PR #45
branch: codex/04c3a-project-resource-needs
head when this prompt was written: 59d2570be7954c3cc0847c051631042a81434dc9
```

Current `main` has advanced beyond PR #45 and GitHub currently reports #45 non-mergeable because SITE work landed after the branch was cut.

Before implementing 04C3B1:

1. fetch current `origin/main`;
2. rebase/update `codex/04c3a-project-resource-needs` onto current main;
3. preserve all current SITE/CI/tooling work;
4. update the same PR #45;
5. do **not** merge #45;
6. create the 04C3B1 branch from the rebased #45 head;
7. open the 04C3B1 PR as a **stacked PR whose base is `codex/04c3a-project-resource-needs`**, not `main`, so its review diff contains only 04C3B1.

Preferred branch:

```text
codex/04c3b1-join-request-contribution-selections
```

Do not merge either PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3B1_join_request_contribution_selection_domain.md
```

---

# Objective

Extend the canonical Project join-request domain so an applicant can select **already-defined Project contribution options** instead of typing free-form contribution categories.

Future user experience:

```text
What can you contribute?

Competences / Knowledge
[ Gardening ] [ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Wooden boards ] [ Ladder ]

Optional message
[ free text... ]
```

The selection model is ID-based:

```text
Competence/Knowledge
  → canonical skill IDs already requested by the Project

Resource/Material
  → canonical project_resource_need IDs

Free text
  → existing optional participation request message only
```

04C3B1 owns the **backend/request-history contract only**.

A later 04C3B2 will implement:

- Flutter selection chips;
- request screen integration;
- rounded labels/chips in structured Messages;
- Project resource-need owner UI.

---

# 1. Important product boundaries

Accepted now:

- contribution categories are selected, not typed;
- skill and resource selections are distinct groups;
- selections belong to one join-request attempt;
- the optional existing request message remains free text;
- selection rows survive request resolution as history;
- resource selections refer to stable 04C3A need IDs;
- skill selections refer to controlled skill IDs;
- requester and Project creator can inspect selections.

Not implemented now:

- changing contribution commitments after acceptance;
- “what I can still bring now” mutable participant state;
- creator/delegate editing of accepted commitments;
- final verification of what was actually contributed;
- unsolicited extra/free-form contributions;
- quantities;
- resource matching;
- notification payload expansion;
- delegate/co-organizer roles.

The future post-acceptance mutable commitment must be a **separate canonical concept** from the historical request selections.

Do not mutate historical request selections later to represent availability changes.

---

# 2. Current Project competence limitation

Current repository source of truth:

- one-time Proposals have canonical `proposal_skills`;
- those skills have controlled catalog IDs and `required` / `useful` importance;
- current Tavoli/recurring activities do **not** have an equivalent canonical skill-requirement relation.

Therefore:

## Proposal

A requester may select skill IDs that are currently attached to that Proposal.

Both:

```text
required
useful
```

are valid selectable contribution options.

## Tavolo

Skill-selection input must currently be empty.

Do not invent:

```text
recurring_activity_skills
tavolo_skills
```

inside this plan.

Resource/material selection works for both Proposal and Tavolo through 04C3A.

Document this implementation limitation clearly.

A later focused plan may give Tavoli canonical competence requirements if the product wants that.

---

# 3. Historical request-selection tables

Add private/fail-closed canonical relations equivalent to:

```text
public.project_join_request_skill_selections
public.project_join_request_resource_selections
```

Exact names are Codex-owned.

## Skill selection

Conceptual fields:

```text
request_id
skill_id
selected_at
```

Canonical uniqueness:

```text
(request_id, skill_id)
```

FKs:

```text
request_id → project_join_requests
skill_id   → skills
```

Do **not** FK to `proposal_skills`, because the Proposal's requirements may later change while the historical request selection must remain.

At insertion time, validate that the skill was a current requested Proposal skill.

## Resource selection

Conceptual fields:

```text
request_id
resource_need_id
selected_at
```

Canonical uniqueness:

```text
(request_id, resource_need_id)
```

FKs:

```text
request_id       → project_join_requests
resource_need_id → project_resource_needs
```

At insertion time, validate:

- resource need belongs to the same Project;
- need is currently `open`.

Do not delete selections when a need later closes.

---

# 4. Direct access / RLS

Follow fail-closed conventions.

For both selection tables:

- RLS enabled;
- no direct `anon` / `authenticated` table reads;
- no direct client inserts/updates/deletes;
- ordinary clients use narrow RPCs only.

Selection rows are request-private context.

Only:

```text
requester
Project creator
```

may read them through the authorized API.

Do not expose selections anonymously through Proposal/Tavolo discovery.

---

# 5. Extend request creation atomically

Evolve:

```text
request_to_join_project(...)
```

so it can atomically accept optional selection arrays.

Conceptual signature:

```text
request_to_join_project(
  p_expected_requester_profile_id,
  p_project_id,
  p_request_message default null,
  p_skill_ids uuid[] default empty,
  p_resource_need_ids uuid[] default empty
)
```

Exact parameter names may differ.

Important:

- preserve backward compatibility for existing callers that submit only identity/project/message;
- old mobile behavior must still create a normal request with zero contribution selections;
- avoid ambiguous overloaded PostgREST signatures.

Prefer replacing the old function cleanly with one defaulted signature rather than keeping ambiguous overloads.

Regenerate types accordingly.

---

# 6. Input normalization / limits

Treat null arrays as empty if consistent with repository RPC conventions.

Reject duplicate IDs explicitly.

Add reasonable abuse bounds, e.g.:

```text
max 50 skill selections
max 50 resource selections
```

or a smaller repository-consistent bound.

No ordering semantics are encoded by caller array order.

Selections should later display in canonical catalog/need order.

---

# 7. Skill validation

For a one-time Proposal:

every selected skill ID must be present in:

```text
proposal_skills
```

for the same Project at the request transaction boundary.

A globally valid skill that the Proposal did not request must be rejected.

For recurring Tavolo:

```text
non-empty p_skill_ids → reject
```

with a clear domain error.

Do not silently discard unsupported Tavolo skill selections.

Do not let clients claim arbitrary catalog skills as Project-requested contributions.

---

# 8. Resource validation

Every selected resource need must:

```text
belong to p_project_id
state = open
```

at the canonical request transaction boundary.

Reject:

- a need from another Project;
- a closed need;
- an unknown need.

Do not allow a client to submit arbitrary UUIDs and silently ignore invalid rows.

---

# 9. Locking / race safety

Selection validation must serialize with the same Project lifecycle boundary as request creation.

Existing `request_to_join_project` already enters the 05A Project participation lock discipline.

Preserve that.

For resource selections:

after the Project lock is acquired, lock/validate selected resource-need rows in a mode that serializes correctly with 04C3A update/close operations.

Lock order must remain:

```text
concrete Proposal/Tavolo
→ shared Project
→ resource need rows
```

Do not introduce the opposite order.

Required race behavior:

```text
request selects open need
vs
creator closes that need
```

must produce one valid serialization:

A:
```text
request transaction validates/selects first
→ request selection commits
→ creator closes need later
→ historical request keeps the selection
```

or B:
```text
creator closes first
→ request validation rejects the now-closed need
```

No request may commit a selection that was already closed before its validation boundary.

Skill selection must likewise remain coherent with Proposal-skill edits using the existing Proposal row locking discipline.

---

# 10. Atomicity

Request + selections are one transaction.

If any selected skill/resource is invalid:

```text
no join request row
no selection rows
no outbox event
```

may remain committed.

Do not create a request first and then attempt best-effort contribution inserts from Flutter.

The database owns the atomic boundary.

---

# 11. Event behavior

Preserve the existing canonical:

```text
project.join_requested
```

event contract unless a minimal identifier-only addition is truly required.

Preferred:

- keep event payload unchanged;
- do not include arrays of skill/resource IDs;
- do not include labels;
- do not include request message.

Notifications continue to alert that a join request exists.

The structured Messages detail can resolve canonical selections separately.

This avoids unnecessary private contribution context in the general outbox.

---

# 12. Historical semantics

Selections belong to the request attempt.

They remain after:

```text
withdrawn
rejected
accepted
```

Do not delete them on any resolution.

A future new join request after withdrawal/rejection/leave is a new request ID with independent selections.

Do not copy old selections automatically into a later request.

---

# 13. Do not create mutable accepted commitments yet

When a request is accepted in 04C3B1:

```text
request selections remain historical
membership is created exactly as today
```

Do not create or update:

```text
current_contributions
participant_commitments
fulfilled_resources
```

yet.

Future scope will introduce a mutable accepted-participant commitment model so availability can change without rewriting request history.

Document this handoff explicitly.

---

# 14. Authorized read RPC

Add a narrow RPC equivalent to:

```text
list_own_project_join_request_contribution_selections(
  p_expected_profile_id,
  p_request_id
)
```

Authorization:

```text
request requester
OR
Project creator
```

Everyone else fails closed.

Return one normalized row per selection:

```text
selection_kind
selection_id
label
```

where:

```text
selection_kind ∈ { skill, resource }
```

Optional safe fields may include skill importance/category or current resource-need state only if they materially help the later UI.

Keep the base contract small.

Recommended ordering:

```text
skills first in canonical catalog/category order
resources second in need creation order
```

or another deterministic documented order.

Do not expose Auth email/private profile data.

---

# 15. Label semantics

The read RPC may resolve the **current canonical label/title** by selection ID.

Do not duplicate free-form label text into request-selection rows merely for presentation.

This intentionally preserves ID-based selection.

Consequences:

- if a Project resource need title is corrected later, historical request UI may show the corrected canonical title;
- the stable selected need ID remains unchanged.

Do not add label snapshots in this slice unless repository evidence shows a hard requirement.

---

# 16. Structured Messages integration — backend only

04C3B1 may expose contribution-selection context to the existing structured request detail boundary in one of two clean ways:

### Preferred A

Keep the existing request-message RPC unchanged and let 04C3B2 call the new authorized contribution-selection RPC alongside it.

### Acceptable B

Extend only the exact request-detail RPC with a compact typed contribution field if doing so substantially simplifies the client without bloating inbox pagination.

Do **not** add per-request selection aggregates to every inbox list row unless there is a strong reason.

The inbox list should remain efficient.

No Flutter UI changes in 04C3B1.

---

# 17. Existing participation transitions

Regression-test:

```text
withdraw_project_join_request
accept_project_join_request
reject_project_join_request
leave_project
remove_project_member
```

They must retain current behavior.

Accept/reject/withdraw must preserve selection history.

No contribution logic may change membership authorization or chat activation.

---

# 18. Proposal skill changes after request

Historical skill-selection rows must remain even if the Proposal creator later removes that skill from current `proposal_skills`.

Do not cascade historical selection deletion through the current requirement relation.

The skill catalog row itself remains canonical.

No snapshot label required.

---

# 19. Resource need changes after request

Historical resource-selection rows remain if the need is later:

```text
renamed
closed
```

Do not block ordinary 04C3A update/close merely because a pending/resolved request references the need.

Future mutable accepted commitments are separate.

---

# 20. Public option discovery

04C3B1 does not need a new global options endpoint if existing canonical reads are sufficient.

For later mobile:

## Proposal competence options

Use canonical public Proposal detail skills already returned from Proposal discovery/detail.

## Resource options

Use 04C3A:

```text
list_public_project_resource_needs(project_id)
```

## Tavolo competence options

None currently exist because recurring activities have no canonical skill requirements.

Do not add redundant APIs solely for symmetry.

---

# 21. pgTAP structure tests

Cover:

- both selection tables;
- exact columns;
- PK/unique constraints;
- FKs;
- RLS enabled;
- no direct grants/policies;
- new request RPC signature/default compatibility;
- authorized selection-read RPC;
- no generic free-text contribution column;
- no quantity/unit/price fields;
- no accepted-commitment table;
- no unsolicited-offer table.

---

# 22. pgTAP behavior tests

At minimum:

## Backward compatibility

Existing 3-argument request flow succeeds with zero selections.

## Proposal skills

- attached required skill valid;
- attached useful skill valid;
- unrelated global skill rejected;
- duplicate skill ID rejected.

## Tavolo skills

- empty allowed;
- non-empty rejected.

## Resources

- open same-Project need valid;
- other-Project need rejected;
- closed need rejected;
- duplicate resource ID rejected.

## Atomicity

One invalid selection causes no request and no selection rows.

## Authorization

- requester can read own selections;
- Project creator can read them;
- unrelated user denied;
- anonymous denied.

## Resolution history

- withdraw preserves;
- reject preserves;
- accept preserves.

## Re-request

A later request starts with independent selections.

## Privacy/event

`project.join_requested` remains message/selection-body-free.

---

# 23. Concurrency tests

Add focused race coverage:

### Need close vs request

Verify both serializations described above.

### Proposal skill update vs request

If current Proposal mutation APIs can remove/change skills concurrently, prove request skill validation cannot observe an impossible half-state.

Reuse existing Project/concrete-row locking instead of inventing advisory locks.

---

# 24. Real local integration

Add or extend a focused verifier such as:

```text
scripts/verify-local-project-contribution-selections.mjs
```

Use real OTP users through the canonical shared auth helper.

Cover:

1. creator publishes Proposal with required/useful skills;
2. creator creates open resource needs through 04C3A;
3. requester submits join request selecting one skill + one resource;
4. canonical rows created atomically;
5. requester/creator can read selection labels;
6. unrelated cannot;
7. invalid unrelated skill rejected with no request;
8. closed/other-Project resource rejected;
9. withdraw preserves selection history;
10. new request has independent selection set;
11. acceptance preserves history and creates membership unchanged;
12. Tavolo resource selection works;
13. Tavolo non-empty skill selection is rejected;
14. outbox remains identifier-only/private-content-free.

Wire it into `check:db` and Database CI.

If GitHub Actions cannot start due billing, report external non-execution accurately.

---

# 25. Generated types

Regenerate public DB types when executable.

Expected changes include:

- two selection tables;
- evolved `request_to_join_project` optional selection args;
- authorized selection-read RPC.

Do not hand-edit generated types if a working database generator is available.

If Docker remains unavailable and hosted Actions cannot run:

- derive temporary type changes carefully if needed for repository build;
- mark them explicitly unverified;
- require `db:types:check` before either stacked PR is merged.

---

# 26. Roadmap split

Refine:

```text
04C3 — Project Resource Needs and Contribution Offers

04C3A — Project Resource Needs Domain Foundation
  PR #45
  open / pending executable DB validation while Actions/local Docker unavailable

04C3B — Join-Request Contribution Selection + Mobile/Messages
  parent

04C3B1 — Join-Request Contribution Selection Domain
  this plan

04C3B2 — Mobile Selection + Rounded Messages Labels
  not started
```

Future, separate:

```text
04C3C — Accepted Participant Contribution Commitments
```

That future slice owns:

- changing what an accepted participant can still bring/help with;
- management location (group info vs My Projects);
- creator/delegate mutation permissions.

05C final verification remains later than mutable accepted commitments.

---

# 27. GitHub Actions billing handling

GitHub hosted Actions may remain unavailable.

Do not let that stop implementation.

But distinguish clearly:

```text
local test passed
CI test passed
CI not executed
```

Never label an unstarted workflow as green.

Do not merge stacked PRs until their required database validation can execute successfully.

---

# Non-goals

Do not implement:

- Flutter UI;
- rounded chips yet;
- Project resource-need owner UI;
- Tavolo skill requirements;
- free-form contribution categories;
- unsolicited extra offers;
- mutable accepted commitments;
- delegate roles;
- final contribution verification;
- quantity/unit/price;
- matching/notifications;
- Scambio-Dona linkage.

---

# Acceptance criteria

- [ ] PR #45 first rebased onto current main and preserved;
- [ ] 04C3B1 is a focused stacked PR based on PR #45 branch;
- [ ] old request callers remain compatible;
- [ ] selection arrays are optional;
- [ ] contribution categories are ID selections, not free text;
- [ ] Proposal requested skills only are selectable;
- [ ] Tavolo skill input is currently empty-only;
- [ ] open same-Project resource needs only are selectable;
- [ ] duplicates rejected;
- [ ] request + selections atomic;
- [ ] lock order is compatible with 04C3A/05A;
- [ ] requester/creator-only selection read exists;
- [ ] selections survive withdraw/reject/accept;
- [ ] repeated join attempt gets independent selections;
- [ ] existing membership/chat semantics unchanged;
- [ ] no accepted mutable commitment model yet;
- [ ] no selection/private text added to general outbox;
- [ ] pgTAP + integration tests added;
- [ ] generated types updated where executable;
- [ ] hosted CI status reported truthfully;
- [ ] neither PR merged.

---

# Deliverables

1. Rebased/update PR #45 without merging.
2. Exact archived 04C3B1 prompt.
3. Request-linked skill selection table.
4. Request-linked resource selection table.
5. Atomic extended request RPC.
6. Skill/resource validation.
7. Authorized contribution-selection read RPC.
8. Historical selection preservation.
9. pgTAP + concurrency tests.
10. Real Proposal/Tavolo integration.
11. Generated type updates.
12. Roadmap 04C3B1/B2 + future commitment handoff.
13. Focused stacked PR.
14. Structured completion report.

---

# Completion report

Return:

1. **PR #45 rebase status**
2. **04C3B1 branch/base/PR**
3. **Changed files**
4. **GitHub Actions billing status**
5. **Selection schema**
6. **Request RPC evolution/backward compatibility**
7. **Proposal skill validation**
8. **Tavolo skill limitation**
9. **Resource-need validation**
10. **Atomicity**
11. **Lock/concurrency behavior**
12. **Requester/creator read authorization**
13. **Selection label resolution**
14. **Withdraw/reject/accept history**
15. **Re-request behavior**
16. **Outbox/privacy**
17. **Existing participation/chat regression**
18. **pgTAP**
19. **Concurrency tests**
20. **Real local integration**
21. **Generated types/drift**
22. **Local regression validation**
23. **GitHub Validation executed/not-executed status**
24. **04C3B2 handoff**
25. **Future mutable accepted-commitment handoff**
26. **Warnings/blockers**
27. **Commit/PR reference**

Do not merge either PR.
