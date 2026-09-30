# PLANETS 04C3A — Project Resource Needs Domain Foundation

**Roadmap area:** PLANETS 04C — Resources + Scambio-Dona  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`  
**Required base:** latest `origin/main`  
**Known current main when this prompt was written:** `83d81bda20a9dbb267f6e68eaf2788ceaa3b7d3d`

## Objective

Implement the first Project-side resource domain: **stable plain-text resource needs attached to the shared Project identity**.

This slice is intentionally independent from PR #34 / 04C2.

PR #34 contains the Scambio-Dona mobile experience and remains open because the final GitHub Actions run could not start due account billing/spending limits. 04C3A does **not** depend on 04C2; its actual dependencies are already merged:

```text
04A
04B1
05A
```

Therefore branch from current `origin/main`, not from PR #34.

The product direction supported by the design source is:

```text
Project
  seeking:
    People
    Resources

Resource examples are creator-defined requested things/help.

When a user later requests to join:
  they select what they can contribute from already-defined Project items.

Future selection UI should show two distinct selectable groups:
  1. Competences / Knowledge
     → existing Project skill/competence requirements
  2. Resources / Materials
     → stable Project resource-need IDs created by this slice

The applicant should NOT type contribution categories manually.
The existing optional join-request message remains the only free-text part.
```

Important distinction:

```text
People / participation
  remains the 05A join-request + membership domain.

Resources
  are a separate Project need domain.

A person may both join and bring resources,
but those concepts must not be collapsed into one record.
```

04C3A implements only **what the Project says it currently needs**.

A later 04C3B will attach selected need IDs to join requests and surface them in structured Messages/mobile UI.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3A_project_resource_needs_domain_foundation.md
```

Preferred branch:

```text
codex/04c3a-project-resource-needs
```

---

# 0. GitHub Actions billing state

GitHub Actions may currently be unable to start runners because of account billing/spending limits.

This does **not** block implementation.

Codex should:

- implement normally;
- run every local/repository validation available;
- attempt GitHub Validation after opening/updating the PR;
- if jobs fail before runner execution specifically because of billing, report that external blocker accurately;
- do not claim GitHub CI passed unless it actually ran and passed;
- do not merge the PR.

Do not weaken tests because hosted Actions are temporarily unavailable.

---

# 1. Product decisions vs tentative ideas

Treat these as accepted for this slice:

- Projects may explicitly request resources separately from people.
- Resource needs belong to the Project, not to Scambio-Dona listings.
- A future join requester may select requested needs they can contribute.
- Stable resource-need IDs are therefore useful now.
- Proposal and Tavolo share this Project-level concept.

Treat these as **not decided / out of scope**:

- post-acceptance UI/location for changing what a participant can still bring/help with;
- co-organizer/delegate roles and permission granularity;
- collaborative Project creation/invitations;
- external invite links and future in-app friends/contacts;
- global resource taxonomy;
- quantities;
- units;
- condition;
- monetary value;
- priority/required-vs-nice-to-have levels;
- matching score;
- whether unsolicited “extra” contributions are allowed;
- attribution/credit after completion;
- dispute/correction rules;
- whether bringing a resource consumes a participant capacity slot;
- automatic matching to Scambio-Dona listings.

Do not invent answers to those questions.

---

# 2. 04C3 split

Refine the roadmap:

```text
04C3 — Project Resource Needs and Contribution Offers (parent)

04C3A — Project Resource Needs Domain Foundation
  Project-owned stable needs, public/owner reads, lifecycle

04C3B — Join-Request Contribution Offers + Mobile/Messages Integration
  requester selects existing competence/skill IDs
  requester selects existing Project resource-need IDs
  no free-form contribution-category entry
  canonical request-linked selections/offers
  structured Messages projection
  rounded chip/label presentation beside the optional free-text message
  Project need management/display in mobile
```

04C3B may itself be split later if implementation size justifies it.

05C contribution/completion verification should depend on the request/contribution semantics from 04C3B, not merely the existence of needs.

---

# 3. Shared Project identity

Attach needs to the existing:

```text
public.projects
```

registry introduced by 05A.

One need row works identically for:

```text
project_kind = one_time
project_kind = recurring
```

Do not add separate Proposal/Tavolo need tables.

Canonical relationship:

```text
project_resource_need.project_id
  → public.projects.id
```

---

# 4. Canonical table

Add a table equivalent to:

```text
public.project_resource_needs
```

Suggested concepts:

```text
id
project_id

title
details?

state

created_at
updated_at
closed_at?
```

Use UUID primary key.

## Title

Creator-defined concise need.

Examples only:

```text
Paint
Van for transport
Wooden boards
Ladder
```

Keep competence/knowledge/help concepts in the existing Project skill/competence domain where they fit. Do not duplicate a competence as a resource need merely so it can be selected later.

Do not infer a structured type from the wording.

Suggested bound:

```text
2..160 Unicode characters
```

## Details

Optional plain-text clarification.

Suggested bound:

```text
1..1000 Unicode characters when present
```

The system does not parse details into business rules.

## State

Exactly:

```text
open
closed
```

Meaning:

```text
open
  Project is still requesting this need when the Project itself is publicly/joinably active.

closed
  Project is no longer requesting this need.
```

`closed` does **not** mean fulfilled, donated, verified, delivered, or credited.

Closed is terminal in 04C3A.

No reopen operation.

---

# 5. Deliberately absent fields

Do not add:

```text
category_id
resource_type
quantity
unit
condition
priority
required_boolean
minimum_amount
maximum_amount
price
currency
due_date
contributor_profile_id
join_request_id
membership_id
resource_listing_id
fulfilled_at
verified_at
```

Do not add arbitrary JSON metadata as an escape hatch.

If later product design needs any of these, add them deliberately later.

---

# 6. Ordering

There is no user-controlled reorder in this slice.

Return needs deterministically in creation order:

```text
created_at ASC
id ASC
```

Do not add `sort_order` or drag/drop ordering yet.

---

# 7. Project lifecycle and mutability

Inspect current Proposal/Tavolo lifecycle code before implementing.

General rule:

- owner may create/update/close needs while the underlying Project is still legitimately owner-manageable;
- terminal historical Projects must not accept new need mutations.

At minimum:

## Proposal

Allow management while consistent with existing owner-editable active/draft Proposal behavior.

Deny once the Proposal is terminal/historical under current repository semantics, including cancelled or time-ended state as applicable.

## Tavolo

Allow management while consistent with current owner-editable draft/published/paused behavior.

Deny after the Tavolo is ended.

Do not rewrite the Proposal/Tavolo lifecycle model.

Do not make a resource need capable of reopening a non-joinable Project.

---

# 8. Lock ordering / concurrency

Resource-need mutations must be safe relative to Project lifecycle and participation transitions.

05A establishes concrete-source → shared-Project locking discipline.

Inspect:

```text
private.lock_project_for_participation(...)
```

and concrete Proposal/Tavolo mutation locks.

For resource needs either create a narrow helper following the same lock order, or reuse/refactor a genuinely generic helper only if that improves semantics without broad risky churn.

Do not introduce opposite lock ordering.

A lifecycle transition racing resource-need creation must resolve deterministically.

Add concurrency coverage where practical.

---

# 9. Owner identity

All mutations are expected-identity-bound.

Conceptually require:

```text
expected_creator_profile_id == auth.uid()
and
public.projects.creator_profile_id == auth.uid()
```

Cross-account mutation fails.

Use hardened security-definer search-path/grant conventions.

---

# 10. Create need

Add an authenticated RPC equivalent to:

```text
create_project_resource_need(
  p_expected_creator_profile_id,
  p_project_id,
  p_title,
  p_details?
)
```

Requirements:

- creator only;
- underlying Project in allowed mutable lifecycle;
- normalize trimmed strings;
- validate title/details bounds;
- create as `open`;
- server owns timestamps;
- stable UUID returned.

Emit identifier-only:

```text
audit: project.resource_need_created
outbox: project.resource_need_created
```

Safe payload:

```text
project_id
project_kind
resource_need_id
creator_profile_id
```

Do not include title/details.

---

# 11. Update open need

Add:

```text
update_project_resource_need(
  p_expected_creator_profile_id,
  p_resource_need_id,
  p_title,
  p_details?
)
```

Requirements:

- creator only;
- need belongs to creator's Project;
- need is `open`;
- Project remains mutable;
- validate normalized content atomically.

Emit identifier-only:

```text
project.resource_need_updated
```

Do not allow update of closed needs.

---

# 12. Close need

Add:

```text
close_project_resource_need(
  p_expected_creator_profile_id,
  p_resource_need_id
)
```

Requirements:

- creator only;
- currently open;
- Project lifecycle permits the transition;
- set canonical `closed_at`;
- state becomes `closed`;
- terminal in this slice.

Emit identifier-only:

```text
project.resource_need_closed
```

Closing does not record who supplied it or whether it was fulfilled.

---

# 13. Owner list

Add:

```text
list_own_project_resource_needs(
  p_expected_creator_profile_id,
  p_project_id
)
```

Creator only.

Return all open + closed needs:

```text
resource_need_id
project_id
project_kind
title
details
state
created_at
updated_at
closed_at
```

Order:

```text
created_at ASC
resource_need_id ASC
```

Historical Project owners may still read need history after mutation is no longer allowed.

---

# 14. Public/current-project list

Add anonymous/authenticated RPC equivalent to:

```text
list_public_project_resource_needs(p_project_id)
```

Purpose: show what a currently joinable Project is requesting before somebody requests to join.

Return only open needs and only while the underlying Project is currently joinable/public under canonical 05A lifecycle semantics.

Use actual repository semantics after inspection.

For draft/cancelled/expired/ended/paused-nonjoinable/missing Projects, prefer a non-enumerating empty result or the established public unavailable behavior.

Do not leak private draft needs.

Return:

```text
resource_need_id
title
details
created_at
```

No private owner/contact context.

---

# 15. No global Project-resource feed yet

Do not create a standalone all-Project resource-needs discovery feed.

Users discover Projects normally, then view that Project's needs.

Cross-Project matching belongs later.

---

# 16. No Scambio-Dona linkage

Do not add `resource_listing_id`.

Standalone Scambio-Dona listings and Project needs remain separate canonical records.

Future 04C4 matching may relate them without merging them.

---

# 17. No contribution offers yet

Do not modify in 04C3A:

```text
project_join_requests
request_to_join_project(...)
07A structured Messages contracts
Participation mobile UI
```

Do not add requester/contributor IDs to needs.

04C3B will create request-linked selection/offer records referencing stable 04C3A need IDs.

---

# 18. No unsolicited extra contributions

The design notes make extra contributions beyond requested things tentative.

Start later with:

```text
requester may select from existing open requested needs
```

Do not add free-form unsolicited offers now.


---

# 18A. Selection-first contract for 04C3B

04C3A must make the later applicant UX naturally selection-based.

The intended future join-request UI is conceptually:

```text
What can you contribute?

Competences / Knowledge
[ Gardening ] [ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Wooden boards ] [ Ladder ]

Optional message
[ free text... ]
```

The exact visual component may be chips/tags/rounded labels, but the important domain rule is:

```text
contribution selections reference canonical IDs
```

not duplicated strings.

For competences/knowledge, reuse the existing canonical skill/competence IDs already attached to the Project.

For resources/materials, use the stable `project_resource_need.id` created by 04C3A.

04C3B should later display the selected items as rounded labels/chips inside the structured participation-request Messages item, alongside the existing optional request message.

Do not add a generic free-text “what can you bring?” contribution field.

---

# 19. Stable identity/history

Never delete a need as ordinary lifecycle behavior.

Closed needs remain owner-readable because future request/contribution/history rows may reference the UUID.

No hard-delete RPC.


The stable-ID choice also prepares a later post-acceptance correction flow: if a participant originally selected something they could contribute but later cannot, the canonical contribution/commitment state should eventually be editable without rewriting historical request text. That mutable post-acceptance state belongs to later contribution-management scope, not 04C3A.

---

# 20. Public lifecycle race

Public reads must not show an open need for a Project that crossed into a non-joinable state.

Do not rely only on `need.state = open`.

Evaluate underlying concrete Project lifecycle/time at read time.

Test both Project kinds.

---

# 21. Events/privacy

Events:

```text
project.resource_need_created
project.resource_need_updated
project.resource_need_closed
```

Audit/outbox payloads remain identifier-only.

Do not include title, details, location, meeting data, or email.

No notification projection in 04C3A.

Existing `resources` / `matching` categories remain unmapped.

---

# 22. RLS/grants

Follow fail-closed conventions:

- RLS enabled;
- no ordinary direct mutation;
- preferably no direct ordinary reads;
- narrow public/owner RPCs;
- private helpers unavailable to clients;
- explicit function grants;
- fixed/empty security-definer search paths.

Do not weaken `public.projects` privacy.

---

# 23. Indexes

Add only useful access-path indexes, likely:

```text
(project_id, created_at ASC, id ASC)

(project_id, created_at ASC, id ASC)
  WHERE state = 'open'
```

Avoid taxonomy/search indexes.

---

# 24. Structural pgTAP

Cover:

- table/PK/Project FK;
- exact open/closed state;
- title/details validation;
- timestamp/state consistency;
- RLS/grants;
- expected RPCs;
- no hard-delete RPC;
- no taxonomy/quantity/unit/price/priority;
- no contributor/request/membership fields;
- no Scambio-Dona FK;
- identifier-only event contract.

---

# 25. Access/behavior pgTAP

Test:

- Proposal creator create;
- Tavolo creator create;
- unrelated/stale identity denial;
- draft owner visibility and public hiding;
- publication makes open needs publicly visible;
- update reflects publicly;
- close removes public visibility but preserves owner history;
- closed cannot update/reclose/reopen;
- non-joinable Proposal hides needs;
- paused/non-joinable Tavolo hides needs;
- resume restores still-open needs if canonical;
- ended Tavolo hides needs;
- terminal Project mutation denied;
- closing never deletes identity.

---

# 26. Concurrency

Add a deterministic concurrency test for Project lifecycle transition vs need creation/update.

Valid serialization:

- need mutation commits before terminal transition, then Project becomes terminal and public view hides it; or
- terminal transition wins and need mutation is rejected.

No mutation may commit as though Project were mutable after terminal transition committed.

---

# 27. Real local integration

Add:

```text
scripts/verify-local-project-resource-needs.mjs
```

Use real OTP-authenticated users via the current shared authenticated-user helper.

Cover Proposal + Tavolo.

Suggested flow:

1. creator A creates Proposal draft;
2. A creates N1/N2;
3. unrelated B cannot mutate;
4. anon cannot see draft needs;
5. A publishes Proposal;
6. anon sees open N1/N2 in stable order;
7. A updates N1;
8. public reflects update;
9. A closes N2;
10. public sees N1 only;
11. owner still sees N1/N2 with N2 closed;
12. Proposal becomes non-joinable/terminal;
13. public sees no needs and new mutation is denied;
14. repeat representative recurring Tavolo lifecycle, including pause/resume if canonical;
15. prove audit/outbox contain no title/details.

Wire into `check:db` and Database workflow.

Do not print need text, OTPs, tokens, meeting details, or credentials unnecessarily.

---

# 28. Generated types

Regenerate committed public DB types.

Expected public contracts:

```text
create_project_resource_need
update_project_resource_need
close_project_resource_need
list_own_project_resource_needs
list_public_project_resource_needs
```

Private helpers stay private.

Preserve current CI-auth Supabase CLI/tooling state.

---

# 29. Documentation

Update product decisions, system design, database docs, roadmap, and relevant README.

Document:

```text
Project resource need
  != participant
  != join request
  != contribution offer
  != Scambio-Dona listing
```

And:

```text
open/closed means whether the Project is still asking.
closed does not mean fulfilled/verified.
```

Stable need IDs intentionally prepare 04C3B.

---

# 30. Roadmap reconciliation

Current main documentation is stale relative to active branches; reconcile carefully.

Record:

```text
04C1 — Implemented
PR #32
merge commit 2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42
```

Record 04C2 accurately without claiming implementation:

```text
04C2 — In progress
PR #34
implementation/rebase complete
final hosted Validation pending because GitHub Actions runners are unavailable due billing/spending limits
```

Split 04C3:

```text
04C3 — Project Resource Needs and Contribution Offers — In progress

04C3A — Project Resource Needs Domain Foundation
  In progress while this PR is open

04C3B — Join-Request Contribution Offers + Mobile/Messages Integration
  Not started
  Depends on 04C3A
```

Update 05C dependency to 04C3B where appropriate.

Preserve all current SITE and CI/tooling work from `main`.

Do not mark 04C complete.

---

# 31. Actions-unavailable handling

After opening the PR, attempt normal Validation.

If GitHub says jobs cannot start due billing/spending:

- leave PR open;
- report exact run/status;
- distinguish “not executed” from “failed tests”;
- do not keep rerunning pointlessly;
- do not modify correct code because of an external billing failure.

Run all local checks available.

If local Docker is also unavailable, report exactly which DB checks could not execute.

---

# Non-goals

Do not implement:

- 04C2 mobile code;
- taxonomy/categories;
- quantity/unit/price/priority;
- fulfillment;
- contributor attribution;
- join-request contribution selection;
- unsolicited offers;
- Messages changes;
- mobile Project resource UI;
- Scambio-Dona matching;
- saved searches;
- resource notifications;
- media;
- verified completion/credit;
- badges/stats.

---

# Acceptance criteria

- [ ] based on latest `origin/main`, not PR #34;
- [ ] exact prompt archived;
- [ ] shared Project-level need table exists;
- [ ] Proposal + Tavolo both use it;
- [ ] stable need UUIDs;
- [ ] title + optional details only;
- [ ] state exactly open/closed;
- [ ] closed does not mean fulfilled;
- [ ] no taxonomy/quantity/price/priority;
- [ ] creator-only expected-identity mutations;
- [ ] safe lifecycle/lock ordering;
- [ ] owner historical open/closed list;
- [ ] public sees open needs only for currently joinable Projects;
- [ ] draft/non-joinable needs do not leak;
- [ ] close preserves identity;
- [ ] no join-request/contributor linkage;
- [ ] no Scambio-Dona linkage;
- [ ] identifier-only events;
- [ ] RLS/grants fail closed;
- [ ] pgTAP added;
- [ ] real Proposal/Tavolo integration added;
- [ ] concurrency behavior tested;
- [ ] generated types updated where executable;
- [ ] roadmap split to 04C3A/04C3B;
- [ ] GitHub CI status reported truthfully if Actions cannot start;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide exact names, nearby text bounds, lock-helper shape, public empty-vs-unavailable convention, and indexes after inspecting current repository conventions.

Stop and report before:

- adding taxonomy;
- adding quantity/unit/price/priority;
- defining fulfilled semantics;
- linking contributor/requester to a need;
- changing `request_to_join_project`;
- implementing unsolicited offers;
- linking needs directly to Scambio-Dona listings;
- weakening lifecycle/authorization;
- implementing mobile UI;
- merging the PR.

---

# Deliverables

1. Exact archived 04C3A prompt.
2. Project resource-need schema.
3. Safe lifecycle/locking helper if required.
4. Creator create/update/close RPCs.
5. Creator history/list RPC.
6. Public current-needs RPC.
7. Identifier-only audit/outbox.
8. Structural/access/concurrency pgTAP.
9. Real Proposal/Tavolo integration.
10. Generated DB types.
11. Docs/roadmap 04C3 split.
12. Focused PR, preferably `codex/04c3a-project-resource-needs`.
13. Structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **GitHub Actions billing status**
5. **04C1/04C2 roadmap reconciliation**
6. **04C3A/04C3B split**
7. **Resource-need schema**
8. **Plain-text/no-taxonomy decision**
9. **Open/closed semantics**
10. **Project identity relationship**
11. **Proposal lifecycle behavior**
12. **Tavolo lifecycle behavior**
13. **Lock/concurrency design**
14. **Creator identity/security**
15. **Create need**
16. **Update need**
17. **Close need**
18. **Owner list/history**
19. **Public current-needs read**
20. **Public privacy/non-enumeration**
21. **Stable identity/history**
22. **Audit/outbox events**
23. **Explicit absence of contribution offers**
24. **Explicit absence of Scambio-Dona linkage**
25. **RLS/grants**
26. **pgTAP**
27. **Concurrency tests**
28. **Real local Proposal/Tavolo integration**
29. **Generated types/drift**
30. **Local regression validation**
31. **GitHub Validation result or external non-execution blocker**
32. **Documentation updates**
33. **Warnings/blockers**
34. **Commit/PR reference**
