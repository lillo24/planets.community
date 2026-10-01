# PLANETS 04C3B2 — Mobile Contribution Selection + Rounded Messages Labels

**Roadmap area:** PLANETS 04C3B — Join-Request Contribution Selection + Mobile/Messages  
**Task type:** Flutter/mobile integration over stacked 04C3A + 04C3B1  
**Repository:** `lillo24/planets.community`

## Required stack

This plan depends on the two currently open backend PRs:

```text
PR #45
codex/04c3a-project-resource-needs
Project Resource Needs Domain Foundation

PR #52
codex/04c3b1-join-request-contribution-selections
Join-Request Contribution Selection Domain
base = PR #45 branch
```

Known heads when this prompt was written:

```text
main:  efdd60309127602eb73a9dc9f683c9784784ffb4
PR #45: 5acd0fd75affe1486bec7dc90753aaa5bb7f1d6d
PR #52: 444a78af8445c7d1f9829f026bd51b79d210723e
```

Before implementing:

1. fetch current `origin/main`;
2. if `main` advanced, rebase/update PR #45 onto it;
3. rebase/update PR #52 onto the new PR #45 head;
4. preserve all unrelated SITE/CI/tooling work;
5. do not merge #45 or #52;
6. create this branch from the final PR #52 head;
7. open this PR as a **stacked PR based on `codex/04c3b1-join-request-contribution-selections`**, not `main`.

Preferred branch:

```text
codex/04c3b2-mobile-contribution-selection
```

Do not merge any PR in the stack.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3B2_mobile_contribution_selection_rounded_messages_labels.md
```

---

# Objective

Implement the user-facing contribution-selection experience discussed by the founder.

When somebody requests to join a Project, they should primarily **select what they can contribute from Project-defined options**, not type contribution categories.

Conceptual UI:

```text
What can you contribute?

Competences / Knowledge
[ Gardening ] [ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Wooden boards ] [ Ladder ]

Optional message
[ free text... ]

[ Send request ]
```

The structured request in Messages should then show those selections as rounded labels/chips alongside the existing optional request message.

This plan also implements the functional creator UI for defining/managing Project resource/material needs from 04C3A.

It does **not** implement mutable post-acceptance commitments. If somebody is accepted and later cannot bring something, that remains 04C3C.

---

# 1. Product rules

The application UI must reinforce these domain rules:

```text
Competence / Knowledge selection
  = select canonical Project-requested skill IDs

Resource / Material selection
  = select canonical open Project resource-need IDs

Optional request message
  = the only free-text applicant input
```

Do not add:

```text
"What else can you bring?"
free-form contribution category
free-form skill
free-form resource
quantity
price
condition
```

The creator may define resource-need titles/details because those are canonical Project requirements.

The applicant only selects from them.

---

# 2. Current competence limitation

Repository source of truth:

## Proposal

One-time Proposals already expose canonical `proposal_skills`, including:

```text
required
useful
```

Those are selectable in the join flow.

## Tavolo

Recurring activities currently have no canonical skill-requirement relation.

Therefore Tavolo join UI in this plan shows:

```text
Resources / Materials
```

only.

Do not show an empty/fake competence picker.

Do not create a Tavolo skill feature inside this mobile plan.

---

# 3. No backend redesign

Consume the stacked backend exactly as implemented.

04C3A RPCs conceptually include:

```text
create_project_resource_need
update_project_resource_need
close_project_resource_need
list_own_project_resource_needs
list_public_project_resource_needs
```

04C3B1 evolves:

```text
request_to_join_project
```

with optional:

```text
p_skill_ids
p_resource_need_ids
```

and adds:

```text
list_own_project_join_request_contribution_selections
```

Do not add a migration in B2 merely for UI convenience.

If an actual backend contract prevents a safe implementation, stop and report before modifying SQL.

---

# 4. Mobile feature boundaries

Keep responsibilities clear.

Recommended structure:

```text
features/project_resource_needs/
  domain/
  data/
  application/
  presentation/

features/participation/
  existing join-request submission
  contribution option/selection integration

features/messages/
  read-only contribution labels on structured request detail
```

Do not place standalone Scambio-Dona code in this feature.

Project resource needs are a separate Project domain.

---

# 5. Project resource-need mobile models

Add strict models equivalent to:

```text
ProjectResourceNeed {
  id
  projectId
  projectKind
  title
  details?
  state
  createdAt
  updatedAt?
  closedAt?
}
```

For public option reads, use the narrower shape actually returned by 04C3A.

State:

```text
open
closed
```

Strict parsing.

Do not infer:

```text
fulfilled
delivered
verified
```

from `closed`.

---

# 6. Project resource-needs gateway

Create a narrow Supabase RPC gateway.

Required operations:

```text
listPublic(projectId)

listOwn(
  expectedCreatorProfileId,
  projectId
)

create(
  expectedCreatorProfileId,
  projectId,
  title,
  details?
)

update(
  expectedCreatorProfileId,
  resourceNeedId,
  title,
  details?
)

close(
  expectedCreatorProfileId,
  resourceNeedId
)
```

Use only canonical RPCs.

No direct `project_resource_needs` table reads.

---

# 7. Public Project resource display

Show currently requested open resources/materials on Project detail screens for both:

```text
Proposal
Tavolo
```

Place a functional section near the Project requirements/participation area:

```text
Resources / Materials needed
[ Paint ] [ Wooden boards ] [ Ladder ]
```

Rounded chips are appropriate.

If a need has details, a compact list/card or tappable expansion is acceptable; do not cram large details into the chip itself.

If there are no current needs, the section may be omitted or show a concise empty state.

Public resource loading failure should not make the whole Project detail unusable.

Use a local safe error/retry for the section.

---

# 8. Creator resource-management entry

The creator needs to define needs before applicants can select them.

Provide an obvious action:

```text
Manage resources / materials
```

Use the existing Project creator context rather than creating a global My Resources destination.

Good entry points:

1. creator Project detail / `ProjectParticipationSection`;
2. existing owner edit/manage screen for Proposal/Tavolo.

The owner edit path is important because a Project may still be a draft.

For a newly created Project, canonical resource needs cannot exist until the Project draft has a real Project UUID.

Therefore:

```text
new unsaved Project
  → first Save Draft
  → then resource management becomes available
```

Do not invent temporary client-side resource UUIDs before Project creation.

---

# 9. Resource-management routes

Add durable protected routes equivalent to:

```text
/proposals/:id/resources
/tavoli/:id/resources
```

A shared route helper is preferred, e.g.:

```text
ProjectResourceNeedRoutes.manage(projectKind, projectId)
```

Requirements:

- authenticated;
- complete profile;
- return-to behavior follows existing protected Project routes;
- backend remains authoritative that the current user is actually creator.

Do not rely on route visibility as authorization.

---

# 10. Resource-management screen

One cross-kind functional screen is sufficient.

Show owner history:

```text
Open
[ Paint ]         Edit   Close
[ Wooden boards ] Edit   Close

Closed
[ Old ladder need ]  Closed
```

Preserve canonical backend order.

Closed rows are history and read-only.

Actions:

```text
Add need
Edit open need
Close open need
```

No reopen.

No hard delete.

No fulfillment checkbox.

---

# 11. Create/edit need UI

A dialog, bottom sheet, or small dedicated form is acceptable.

Fields:

```text
Title
Details (optional)
```

Mirror backend bounds for immediate validation.

Title/details are creator-authored Project requirements.

Do not add:

- category;
- quantity;
- unit;
- condition;
- price;
- priority;
- contributor.

On save:

- call canonical mutation;
- refresh owner list;
- refresh public need section where relevant;
- refresh join contribution options where relevant.

---

# 12. Close need UI

Use a confirmation dialog.

Copy must say the actual meaning, roughly:

```text
Close this need?

It will no longer be offered as a selectable Project need.
This does not record that it was supplied or fulfilled.
```

After success:

- keep it visible in owner history as Closed;
- remove it from public/open option reads after refresh.

No reopen control.

---

# 13. Resource management and immutable Projects

04C3A backend remains authoritative about lifecycle mutability.

Where the current Proposal/Tavolo editor already knows the Project lifecycle, disable or hide mutation controls when the Project is known terminal/immutable.

However:

- do not duplicate complex lifecycle logic inconsistently;
- direct route access must still rely on backend rejection;
- historical owner list remains readable.

Map backend lifecycle conflicts to safe localized UI.

---

# 14. Contribution option model

Add a UI/application model equivalent to:

```text
ContributionOption {
  id
  kind     // skill | resource
  label
}
```

Skill options may additionally retain Proposal importance internally if useful.

Selection state should be distinct:

```text
selectedSkillIds
selectedResourceNeedIds
```

Do not collapse different ID namespaces into one untyped set.

---

# 15. Load join contribution options

When `/.../join` opens:

## Proposal

Load:

1. canonical public Proposal detail;
2. canonical public Project resource needs.

Competence options:

```text
detail.summary.skills
```

Resource options:

```text
list_public_project_resource_needs(projectId)
```

## Tavolo

Load:

```text
list_public_project_resource_needs(projectId)
```

Skill options:

```text
none
```

Do not direct-read `proposal_skills`.

Do not load the entire global skill catalog merely to reconstruct Project requirements.

---

# 16. Option-load state

The user should not unknowingly submit a request before the Project's canonical selectable options are known.

Use clear states:

```text
loading
ready
failure
```

While initial options are loading:

- message may be editable if convenient;
- Send Request remains disabled.

On option-load failure:

- preserve entered message;
- show safe retry;
- do not silently submit an empty selection set.

If the Project legitimately has zero selectable options:

- state is `ready`;
- hide empty selection groups;
- allow the existing optional-message request flow.

---

# 17. Join selection UI

Modify the existing `JoinRequestScreen`; do not create a parallel application surface.

Recommended order:

```text
Request to join

What can you contribute?

Competences / Knowledge
[ FilterChip ][ FilterChip ]...

Resources / Materials
[ FilterChip ][ FilterChip ]...

Optional message
[text area]

Send request
```

Use multi-select chips.

For Proposal skills, optionally distinguish:

```text
Required
Useful
```

through subtle text/grouping if already natural in the Proposal UI, but selection is allowed for both.

Do not make `required` mean the requester must select it.

Do not make any contribution selection mandatory unless future product design explicitly says so.

---

# 18. Accessibility for chips

Each selectable contribution must expose:

- readable label;
- selected/unselected semantic state;
- tap target;
- focus/keyboard behavior supported by Material controls.

Do not communicate selection only by color.

Separate group headings must be screen-reader readable:

```text
Competences / Knowledge
Resources / Materials
```

---

# 19. Submit through canonical request RPC

Extend mobile participation gateway/controller:

```text
requestToJoin(
  expectedRequesterProfileId,
  projectId,
  message,
  skillIds,
  resourceNeedIds
)
```

Send canonical ID arrays.

Normalize deterministic ordering before RPC if convenient.

Do not submit label strings.

Do not perform selection inserts from the client.

The single RPC is the atomic boundary.

---

# 20. Backward-safe controller behavior

Existing call sites/tests that do not supply contribution arrays should remain easy to support.

Use defaults at the Dart layer where sensible:

```text
skillIds = empty
resourceNeedIds = empty
```

Do not force unrelated callers to manufacture empty mutable sets.

---

# 21. Stale option race

A need or Proposal skill can change after the join screen loads.

The backend may reject the request.

On contribution-validation failure:

- retain the optional message;
- refresh contribution options;
- intersect current selected IDs with options that still exist;
- show a safe localized message such as:
  `The Project requirements changed. Review your selections and try again.`

Do not expose raw SQL/PostgREST errors.

Do not create a request with silently invalid/stale IDs.

---

# 22. Account-switch safety

The join form contains private intent.

If identity changes while the form is open or a request is in flight:

- discard selected contribution IDs;
- discard private message according to existing auth-route safety behavior;
- reject late responses from the previous identity;
- never submit under the new account using old form state.

Owner resource-management state must similarly clear on identity change.

---

# 23. Messages gateway selection read

Extend Messages data boundary with:

```text
listContributionSelections(
  expectedProfileId,
  requestId
)
```

calling only:

```text
list_own_project_join_request_contribution_selections
```

Parse strictly into:

```text
RequestContributionSelection {
  kind
  id
  label
}
```

Known kinds:

```text
skill
resource
```

Unknown known-domain values fail safely.

---

# 24. Messages detail controller

Do not make Accept/Reject/Withdraw depend on successful chip loading.

The canonical request detail remains primary.

Recommended state:

```text
item
selectionPhase
selections
selectionFailure
```

Loading behavior:

1. load canonical request item;
2. load contribution selections independently;
3. if selection read fails:
   - retain request item;
   - retain action buttons;
   - show a local contribution-context error/retry.

Account-switch and request-ID race protections must apply to both item and selections.

---

# 25. Rounded labels in Messages

On participation request detail, add a section before/near the free-text message:

```text
Can contribute

Competences / Knowledge
[ Gardening ] [ Carpentry ]

Resources / Materials
[ Paint ] [ Ladder ]
```

Use rounded Material chips.

Only show groups that have selections.

If there are zero selections:

- omit the section or show concise `No contributions selected`;
- do not fabricate values.

Then retain the existing optional message section:

```text
Message
...
```

This matches the founder preference that the structured contribution labels and free-text message are visible together.

---

# 26. Historical labels

B1 resolves **current canonical labels**.

The mobile client must not cache a permanent request-time label snapshot.

Refresh should be able to show:

- corrected skill label;
- renamed resource need title;

while the selected canonical ID remains historical.

Do not display the current open/closed state unless the B1 read contract actually returns it.

---

# 27. Messages inbox list

Do not add every contribution chip to the main Messages list.

Keep the inbox scannable.

Rounded contribution labels belong in the request **detail**.

No additional per-row RPC fan-out on the inbox.

---

# 28. Participation management screen

Do not duplicate contribution chips across every creator participant-management row in this plan.

The canonical structured request detail in Messages is the review surface.

If an existing creator review row naturally has a `View request` action, it may link to the Messages request detail.

Do not introduce another parallel contribution-review implementation.

---

# 29. Public resource chips vs request chips

Use a shared visual primitive if useful, but keep semantics distinct:

```text
Project detail resource chip
  = Project currently asks for this resource

Messages request contribution chip
  = requester selected this item on that historical request attempt
```

Do not accidentally make historical chips interactive.

---

# 30. Resource mutation invalidation

After creator create/update/close:

Refresh/invalidate narrowly:

```text
owner resource needs
public resource needs for project
```

Any currently open join flow for the same Project will still be protected by backend stale validation; cross-screen realtime synchronization is not required.

Do not add Realtime solely for resource needs.

---

# 31. Localization

Add all production copy through existing l10n.

At minimum:

```text
What can you contribute?
Competences / Knowledge
Resources / Materials
No contribution options
Project requirements changed
Manage resources / materials
Resources / Materials needed
Add need
Edit need
Close need
Open
Closed
Resource need title
Details (optional)
close confirmation / non-fulfillment explanation
contribution selection loading/error/retry
Can contribute
No contributions selected
```

Do not hard-code Italian/English UI strings.

---

# 32. Tests — resource-needs mobile layer

Add parser/gateway/controller/widget coverage for:

- public open needs;
- owner open/closed history;
- create;
- edit;
- close;
- safe errors;
- closed read-only state;
- account switching;
- no direct table access.

---

# 33. Tests — join contribution options

Cover:

## Proposal

- skill + resource groups render;
- required/useful skills are both selectable;
- multiple selections;
- deselection;
- canonical IDs sent;
- labels not sent.

## Tavolo

- resources render;
- competence group absent;
- canonical resource IDs sent.

## Zero options

- request remains possible with optional message.

## Loading/failure

- send disabled until options known;
- retry;
- message retained.

## Stale backend rejection

- options reload;
- invalid selections are pruned;
- message retained;
- safe error shown.

---

# 34. Tests — Messages contribution labels

Cover:

- skill chips;
- resource chips;
- both groups;
- zero selections;
- canonical ordering from gateway preserved;
- long labels wrap safely;
- selection fetch failure does not hide request or Accept/Reject/Withdraw;
- retry selection fetch;
- account switch clears selection context;
- resolved historical requests still display selections.

---

# 35. Routing tests

Cover protected resource management for both Project kinds:

```text
/proposals/:id/resources
/tavoli/:id/resources
```

Signed out:

```text
→ auth with exact returnTo
```

Incomplete profile:

```text
→ profile setup with return destination
```

Ready identity:

```text
→ resource management
```

Public Project detail and existing participation routes must remain unchanged.

---

# 36. Existing participation regression

Retain all current behaviors:

- request with only message;
- withdraw;
- creator Accept/Reject;
- membership creation;
- chat activation;
- leave/remove;
- pending request Browse promotion;
- Messages list;
- protected meeting details.

The new selection UI is additive to request creation.

---

# 37. Database validation status

The backend stack remains unmerged and executable Database validation may still be blocked by:

- local Docker/WSL unavailable;
- GitHub Actions billing/spending gate.

Do not claim backend validation passed unless it executes.

B2 itself should add no DB migration, so automated Flutter validation can still be meaningful.

If hosted Actions cannot start, report:

```text
not executed due external billing
```

rather than test failure.

---

# 38. Native QA

Physical-device QA remains deferred to Plan 12.

Add Plan-12 checklist items:

- chip selection touch targets;
- wrapping on small screens;
- keyboard behavior with optional message;
- screen reader selected state;
- resource-management dialog/sheet;
- long resource labels;
- join stale-option recovery;
- Messages chip wrapping.

Do not claim native QA passed.

---

# 39. Roadmap/docs

Update stacked status accurately:

```text
04C3A — PR #45 open/unmerged
04C3B1 — PR #52 open/unmerged
04C3B2 — In progress in this stacked PR
04C3C — Not started
```

Do not mark 04C3A/B1 implemented until they are actually merged and executable DB validation has passed.

Document the mobile behavior:

```text
join requester selects canonical chips
optional message remains free text
Messages detail shows rounded historical selection chips
```

Document Tavolo resource-only limitation.

---

# 40. Stacked Git hygiene

This is important while Actions are unavailable.

Before opening/updating B2:

- ensure #45 is based on current main;
- ensure #52 is based on current #45 head;
- branch B2 from current #52 head;
- PR B2 base must be:
  `codex/04c3b1-join-request-contribution-selections`.

If main advances later:

```text
rebase #45 onto main
→ rebase #52 onto #45
→ rebase B2 onto #52
```

Preserve all three focused diffs.

Do not merge any layer until backend validation is available and green.

---

# Non-goals

Do not implement:

- mutable accepted participant commitments;
- post-acceptance change modal;
- co-organizer/delegate permissions;
- final contribution verification;
- Tavolo competence requirements;
- free-form contribution categories;
- quantities/units/prices;
- unsolicited offers;
- matching;
- resource notifications;
- Scambio-Dona linkage;
- final visual redesign.

---

# Acceptance criteria

Ready when:

- [ ] stack is current and focused;
- [ ] B2 branches from PR #52 head;
- [ ] public Project details show open resource/material needs;
- [ ] creator can manage resource needs for Proposal and Tavolo;
- [ ] draft owners can reach resource management after canonical draft exists;
- [ ] creator can add/edit/close needs;
- [ ] closed is shown as historical, not fulfilled;
- [ ] join Proposal shows selectable Project skills + resources;
- [ ] join Tavolo shows resources only;
- [ ] selections are chips/multi-select, not typed categories;
- [ ] optional request message remains free text;
- [ ] request RPC receives IDs only;
- [ ] submit waits until options are known;
- [ ] stale option rejection refreshes/prunes safely;
- [ ] Messages detail shows rounded skill/resource labels;
- [ ] Messages action buttons remain usable if selection read fails;
- [ ] zero-selection requests still work;
- [ ] account switching clears private state;
- [ ] localization/accessibility included;
- [ ] no DB migration added without genuine blocker;
- [ ] Flutter tests/analyze/build pass where executable;
- [ ] backend CI status reported truthfully;
- [ ] no native QA falsely claimed;
- [ ] no PR in the stack is merged.

---

# Autonomy and stop conditions

Codex may decide:

- exact Flutter feature/file names;
- FilterChip/InputChip choice;
- dialog vs bottom sheet for resource editing;
- exact placement of public resource section;
- exact creator management button placement;
- controller/state class names;
- reasonable localized copy.

Stop and report before:

- adding new backend semantics;
- adding Tavolo skill requirements;
- making selections mandatory;
- adding free-form contribution fields;
- creating mutable post-acceptance commitments;
- implementing delegate roles;
- rewriting historical request selections;
- merging any stacked PR.

---

# Deliverables

1. Current three-layer stack reconciliation.
2. Exact archived 04C3B2 prompt.
3. Mobile Project-resource models/gateway/controllers.
4. Public Project resource section.
5. Creator resource-management routes/screen.
6. Add/edit/close need UI.
7. Join contribution option loader.
8. Proposal skill + resource chip selection.
9. Tavolo resource-only selection.
10. Contribution-aware participation gateway/controller.
11. Messages selection gateway/models/controller state.
12. Rounded skill/resource labels in request detail.
13. Localization/accessibility.
14. Parser/controller/router/widget tests.
15. Plan-12 QA checklist.
16. Docs/roadmap updates.
17. Focused stacked PR.
18. Structured completion report.

Do not merge any PR.

---

# Completion report

Return:

1. **Stack/base status (#45/#52/B2)**
2. **B2 branch/base/PR**
3. **Changed files**
4. **GitHub Actions billing status**
5. **Mobile feature architecture**
6. **Project resource-needs gateway/models**
7. **Public Project resource display**
8. **Creator resource-management entry**
9. **Resource management screen**
10. **Create/edit/close flows**
11. **Join option loading**
12. **Proposal competence selection**
13. **Tavolo resource-only behavior**
14. **Resource/material selection**
15. **Atomic request submission IDs**
16. **Stale-option recovery**
17. **Optional message preservation**
18. **Messages selection read**
19. **Rounded Messages labels**
20. **Selection-read partial failure behavior**
21. **Account-switch safety**
22. **Routing/auth return flow**
23. **Localization/accessibility**
24. **Existing participation/chat regression**
25. **Flutter tests/build**
26. **Backend/DB validation executed or external blocker**
27. **Deferred native QA**
28. **04C3C handoff**
29. **Warnings/blockers**
30. **Commit/PR reference**
