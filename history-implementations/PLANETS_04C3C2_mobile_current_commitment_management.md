# PLANETS 04C3C2 — Mobile Current Commitment Management

**Roadmap area:** PLANETS 04C3C — Accepted Participant Contribution Commitments  
**Task type:** Flutter/mobile integration over 04C3C1  
**Repository:** `lillo24/planets.community`

## Required stack

This plan depends on the current open stack:

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

PR #61 — 04C3C1 Current Commitment Domain Foundation
  codex/04c3c1-current-participant-commitments
  4fe08a9704150babcb8de7e307f6441923768cbc
```

All remain intentionally unmerged because executable Database validation is still blocked by local Docker and GitHub Actions billing.

Before implementing:

1. fetch current `origin/main`;
2. if `main` advanced, rebase PR #45 onto current main;
3. rebase PR #52 onto the new #45 head;
4. rebase PR #60 onto the new #52 head;
5. rebase PR #61 onto the new #60 head;
6. preserve all unrelated SITE/CI/tooling work;
7. do not merge any existing PR;
8. branch this plan from the final PR #61 head;
9. open this plan as a stacked PR whose base is:
   `codex/04c3c1-current-participant-commitments`.

Preferred branch:

```text
codex/04c3c2-mobile-commitment-management
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3C2_mobile_current_commitment_management.md
```

Do not merge any PR.

No external document is required by Codex: the relevant product decisions are fully captured below.

---

# Objective

Expose the canonical 04C3C1 **current accepted-participant commitment state** in the mobile app.

The key distinction must remain visible in product behavior:

```text
Request selections
  immutable historical intent
  "When I applied, I said I could bring Paint + Ladder"

Current membership commitments
  mutable current expectation
  "I can now bring Paint only"

Future 05C verification
  actual contribution
  "What did the organizer verify actually happened?"
```

04C3C2 implements only the middle layer.

Do not rewrite the historical request selections shown in Messages.

Do not add fulfillment/verification semantics.

---

# 1. Locked UI placement

Use the existing surfaces rather than introducing a new global commitment-management destination.

## Participant / former participant

Use:

```text
Project group chat
→ Group info
→ My commitments
```

Current member:

```text
My commitments
[ Carpentry ] [ Paint ]

[ Edit ]
```

Former member:

```text
Last commitments
[ Carpentry ] [ Paint ]

Read-only history
```

## Project creator

Use:

```text
Project detail / Group info
→ Manage participation
→ member card
→ Commitments
```

Current member:

```text
Mario
Current
[ Commitments ]
```

opens editable commitment modal/sheet.

Historical member:

```text
Mario
Left
[ View commitments ]
```

opens read-only history.

Do not add a top-level My Commitments/My Contributions screen.

Do not add a new bottom-nav destination.

---

# 2. Why these surfaces

The existing app already has the correct contexts:

```text
ProjectChatInfoScreen
  = ongoing member/group context
  = current/former participant role
  = protected meeting information
  = creator link to Manage participation

CreatorParticipationScreen
  = canonical organizer participant management
  = already owns membership IDs
  = current + historical member rows
```

Do not duplicate these responsibilities into a parallel management area.

---

# 3. No Project-chat backend/schema change

`ProjectChatSummary` currently does not carry a membership ID.

Do not modify chat RPCs merely to add it.

For participant/former-participant group info, resolve the relevant membership through the existing identity-bound participation state:

```text
summary.projectId
summary.projectKind

ownParticipationProvider
  → resolveProjectParticipation(...)

if viewerRole == currentMember
  → currentMembership

if viewerRole == formerMember
  → latestMembership
```

If necessary, explicitly refresh own participation when group info opens.

For creator management, `CreatorProjectMember.id` is already the membership ID.

---

# 4. Commitment mobile domain

Add strict typed models equivalent to:

```text
MembershipCommitmentKind {
  skill
  resource
}

MembershipCommitment {
  kind
  id
  label
}

MembershipCommitmentOption {
  kind
  id
  label
}
```

Keep skill/resource namespaces typed.

Do not collapse them into a single untyped string set.

Unknown backend kinds fail safely.

---

# 5. Mobile gateway

Add a narrow RPC-only gateway, preferably within the participation boundary or a focused membership-commitment sub-boundary.

Required calls:

```text
listCommitments(
  expectedProfileId,
  membershipId
)
  → list_own_project_membership_commitments

listOptions(
  expectedProfileId,
  membershipId
)
  → list_own_project_membership_commitment_options

replaceCommitments(
  expectedActorProfileId,
  membershipId,

  expectedSkillIds,
  expectedResourceNeedIds,

  desiredSkillIds,
  desiredResourceNeedIds
)
  → replace_project_membership_commitments
```

No direct commitment table reads/writes.

No Project-resource table reads.

No Proposal-skill table reads.

The options RPC is the canonical “what may be newly added now?” boundary.

---

# 6. Current-vs-option distinction

The editor must combine two different backend reads:

```text
CURRENT
list_own_project_membership_commitments
→ what this membership currently commits to
→ may include stale retained items

OPTIONS
list_own_project_membership_commitment_options
→ what this current membership may newly add now
→ current Proposal skills / open Project resource needs
```

Build the editable union keyed by:

```text
(kind, id)
```

Do not key only by raw UUID/string without kind.

---

# 7. Retained stale commitments

A commitment may currently exist even though it is no longer newly addable:

```text
skill removed from Proposal requirements
resource need later closed
```

Example:

```text
Current commitments:
[ Paint ] [ Old ladder ]

Currently addable:
[ Paint ] [ Wooden boards ]
```

The editor must show:

```text
[ Paint ✓ ]
[ Old ladder ✓ ]   ← retained historical/current commitment
[ Wooden boards ]
```

`Old ladder` must remain removable.

Explain with concise helper copy, conceptually:

```text
Some selected items are no longer requested by the Project.
You can keep or remove them. If you save after removing one, it cannot be added again.
```

Do not call it fulfilled/completed.

Do not silently remove stale commitments.

---

# 8. Stale chip behavior inside one unsaved edit

If a stale existing commitment is deselected and then reselected **before Save**, that is acceptable because no canonical removal happened yet.

The backend expected snapshot still contains the commitment.

After a successful Save that removes it:

```text
reload current commitments
reload options
```

and the item disappears because it is no longer current and is not addable.

Do not persist a removed stale option as an available chip.

---

# 9. Shared commitment modal/sheet

Use one reusable small management surface for both participant and creator flows.

A modal bottom sheet, dialog, or equivalent Material surface is acceptable.

Do not create a new global route unless repository constraints make a modal unsafe.

Inputs to the shared surface should conceptually include:

```text
membershipId
expectedProfileId
editable/readOnly
display context/name if useful
```

The backend remains authoritative for actual edit authorization.

---

# 10. Read-only mode

Read-only mode calls only:

```text
list_own_project_membership_commitments
```

and renders grouped rounded chips:

```text
Competences / Knowledge
[ Carpentry ]

Resources / Materials
[ Paint ]
```

Use read-only mode for:

- former participant viewing own last membership episode;
- creator viewing an ended member episode;
- current membership whose Project has become non-operational.

No Edit/Save controls.

---

# 11. Editable mode loading

For a current membership:

1. load current commitments;
2. load current addable options;
3. only enable editing once both authoritative reads are known.

Keep the commitment read useful even when options cannot be edited.

States should distinguish:

```text
commitment read loading/failure
option read loading/failure
editable ready
read-only lifecycle state
saving
CAS conflict
stale-option conflict
```

Do not make the surrounding group-info/participant screen fail if this section fails.

---

# 12. Options RPC lifecycle response

04C3C1 F1 intentionally rejects option editing when:

```text
membership ended
or
Project no longer operational
```

If commitments load successfully but `listOptions` returns canonical lifecycle conflict (`55000`):

```text
show commitments read-only
hide/disable Edit
show concise note:
  "These commitments can no longer be changed."
```

Do not treat this as missing commitment history.

If option loading fails because of transient/unavailable/network behavior:

- preserve the commitment read;
- show local retry;
- do not falsely declare the membership permanently read-only.

---

# 13. Participant group-info integration

Extend `ProjectChatInfoScreen`.

## Creator

Keep existing:

```text
Manage participation
```

Do not add creator membership commitments directly to group info because the creator has no membership episode.

## Current member

Resolve current membership using `ownParticipationProvider`.

Show:

```text
My commitments
[chips or "No current commitments"]

Edit
```

Only expose Edit when options are editable.

## Former member

Resolve `latestMembership`.

Show:

```text
Last commitments
[chips or "No commitments recorded"]
Read-only
```

Do not expose Edit.

---

# 14. Participation-state loading in group info

Group info must not assume `ownParticipationProvider` is already loaded from another screen.

For current/former participant roles:

- ensure identity-bound own participation is loaded/refreshed as necessary;
- preserve revision/account-switch protections;
- keep this loading independent from chat summary and meeting-details loading.

If membership resolution fails:

- group-info Project/chat context stays visible;
- commitment section gets local safe error/retry.

Do not modify chat authorization.

---

# 15. Rejoin behavior in participant group info

A rejoined user may have:

```text
old ended membership
new current membership
```

When viewer role is current member:

```text
use currentMembership
```

not the old episode.

When viewer role is former member:

```text
use latestMembership
```

This preserves membership-episode isolation.

Add tests.

---

# 16. Creator Manage participation integration

Do not preload commitment data for every member row.

That would introduce N+1 RPC fan-out.

Instead add a lazy action on each membership card:

```text
current:
  Commitments

left/removed:
  View commitments
```

On tap:

```text
open shared modal/sheet
→ load only that membership
```

Current membership:

- editable if options read succeeds;
- read-only if backend says Project no longer operational.

Historical membership:

- read-only.

---

# 17. Creator and participant use the same canonical editor

The shared editor must not have separate mutation logic for creator vs participant.

Both send:

```text
expectedActorProfileId = current authenticated user
membershipId = target membership
```

The backend decides whether that identity is:

```text
membership participant
or
canonical Project creator
```

Do not add client-side fake organizer roles.

---

# 18. Compare-and-swap save

04C3C1 F2 changed replacement to compare-and-swap.

When the editor loads, capture immutable expected snapshots:

```text
loadedSkillIds
loadedResourceNeedIds
```

Editable desired sets are separate:

```text
desiredSkillIds
desiredResourceNeedIds
```

On Save send:

```text
expectedSkillIds        = loadedSkillIds
expectedResourceNeedIds = loadedResourceNeedIds

desiredSkillIds
desiredResourceNeedIds
```

Never update the expected snapshot merely because the user toggles chips.

Only replace the expected snapshot after a successful canonical reload/save.

---

# 19. CAS conflict handling — SQLSTATE 40001

If Save returns:

```text
40001
Membership commitments changed since they were loaded.
```

do **not**:

- silently retry;
- automatically merge;
- overwrite the other actor;
- resubmit the user's stale desired set.

Instead:

1. reload canonical current commitments;
2. reload current addable options;
3. reset local selections to the newly loaded canonical current set;
4. show localized live-region guidance, conceptually:

```text
These commitments were changed elsewhere.
We reloaded the latest version. Review it before saving again.
```

The user may then make their edits again.

This applies equally to participant-vs-creator and same-user multi-device conflicts.

---

# 20. Stale option conflict — SQLSTATE 22023

The editor already enforces local size/duplicate constraints.

Therefore a backend `22023` during Save is expected mainly when:

```text
a newly selected skill was removed
a newly selected resource need was closed
```

between option load and mutation.

On this failure:

1. reload current commitments;
2. reload options;
3. reset selection to canonical current commitments;
4. show localized guidance:

```text
The Project's available contribution options changed.
Review the latest options and try again.
```

Do not expose backend text.

Do not silently save a subset.

---

# 21. Membership/Project became non-editable — SQLSTATE 55000

If a current editor becomes invalid because:

```text
participant left/was removed
Proposal ended/cancelled
Tavolo ended
```

during the edit:

1. reload canonical commitments;
2. stop editing;
3. show the final state read-only;
4. display concise safe copy:

```text
These commitments can no longer be changed.
```

Do not discard the readable historical commitment state.

---

# 22. Authorization/account changes

On:

```text
42501
account switch
sign-out
```

clear private commitment/editor state.

Reject late reads/saves from the previous identity.

Do not show the previous user's desired unsaved selections under the new account.

Reuse existing identity-revision patterns.

---

# 23. 50/50 limits

C1 enforces:

```text
max 50 skill commitments
max 50 resource commitments
```

Reuse or centralize the B2 50/50 constants so request selections and current commitments cannot drift.

Do not copy unexplained magic numbers.

For each group:

- selected chips remain deselectable at the limit;
- additional unselected addable chips are disabled;
- show localized maximum guidance;
- skill/resource counts are independent.

Current stale commitments count toward the desired-set limit because they remain part of the canonical set.

---

# 24. Clear-all

It is valid to deselect every current commitment.

Save:

```text
desired skills = []
desired resources = []
```

Membership itself remains unchanged.

The read view afterward should show:

```text
No current commitments
```

Do not imply the participant left the Project.

---

# 25. No-op save

If desired sets equal the loaded expected current sets:

Prefer:

```text
Save disabled
```

or close/dismiss without RPC.

If a no-op reaches the backend anyway, it is safe.

Do not fabricate a “updated” confirmation when nothing changed.

---

# 26. Current canonical labels

Both commitment and option reads return current canonical labels.

Do not snapshot labels in Flutter.

Refresh/reopen should show corrected canonical labels.

Historical request Messages continue using their own B1 current-label resolution and remain a separate historical selection set.

---

# 27. Do not alter Messages request history

The structured request detail currently shows:

```text
Can contribute
[ historical request-selection chips ]

Message
...
```

Keep it unchanged.

Do not replace those chips with current commitments.

The user should conceptually be able to have:

```text
Request:
  [ Paint ] [ Ladder ]

Current commitment:
  [ Paint ]
```

without contradiction.

---

# 28. No notifications/Realtimes

Do not add:

- commitment-change notifications;
- push;
- Realtime subscription.

CAS protects concurrent edits.

A manual refresh/reopen is sufficient for this slice.

Future product work may decide whether commitment changes should alert another actor.

---

# 29. Failure mapping

Extend safe mobile failure mapping with distinct semantics:

```text
40001 → staleEdit
22023 → optionsChanged / invalid canonical option
42501 → forbidden / identity changed
55000 → noLongerEditable
P0002 → unavailable/notFound
other → unavailable
```

Do not show raw PostgREST diagnostics.

Do not map `40001` to generic network retry.

---

# 30. Suggested state architecture

Use one focused membership-commitment controller family keyed by membership ID or equivalent.

Conceptually:

```text
MembershipCommitmentState {
  membershipId
  expectedProfileId

  readPhase
  commitments

  optionsPhase
  options

  expectedSkillIds
  expectedResourceIds

  desiredSkillIds
  desiredResourceIds

  savePhase
  failure
}
```

Avoid coupling commitment edit state to the global chat controller.

The creator and participant surfaces should both consume the same controller/editor component.

---

# 31. Modal lifecycle

When opening an editor:

- start from canonical loaded current commitments;
- do not reuse unsaved selections from a prior dismissed modal;
- dismiss without Save = no backend change.

After successful Save:

- reload canonical commitment/options state;
- close modal or show saved state according to the cleanest existing mobile convention;
- refresh visible summary chips.

Do not persist drafts of commitment edits to disk.

---

# 32. Accessibility

Commitment chips must expose:

- label;
- selected state;
- enabled/disabled state;
- keyboard/focus behavior.

For retained stale commitments, do not communicate “no longer addable” by color alone.

Provide text/semantics.

CAS/option/lifecycle errors should use live regions.

Long labels must wrap without horizontal overflow.

---

# 33. Localization

Add production copy through l10n.

At minimum cover concepts equivalent to:

```text
My commitments
Last commitments
Commitments
View commitments
Edit commitments
No current commitments
No commitments recorded
Competences / Knowledge
Resources / Materials
No longer requested
If removed, this option cannot be added again
Maximum {count} selections
Save commitments
Commitments changed elsewhere
Latest commitments reloaded
Available contribution options changed
These commitments can no longer be changed
Unable to load commitments
Unable to load editable options
Try again
```

Do not hard-code copy in widgets.

---

# 34. Tests — gateway/parsers

Cover:

- skill/resource commitment parsing;
- skill/resource option parsing;
- unknown kind fails safely;
- exact RPC names;
- six-argument CAS mutation payload;
- expected arrays are sent separately from desired arrays;
- deterministic sorted arrays where useful;
- no direct table access.

---

# 35. Tests — controller

Cover:

## Load

- commitments + options ready;
- commitments ready / transient options failure;
- lifecycle `55000` options failure becomes read-only;
- ended membership read-only.

## Edit

- union of current commitments and addable options;
- retained stale item remains selected/removable;
- stale item can be toggled off/on before persistence;
- after successful removal/reload it disappears;
- clear-all.

## Limits

- 50 skills;
- 50 resources;
- independent limits;
- stale selected commitments count toward limits.

## Save

- expected snapshot remains original while toggling;
- desired snapshot changes;
- correct six arrays/IDs sent;
- no-op guarded.

## CAS conflict

- 40001 reloads canonical state;
- stale desired changes are not auto-resubmitted.

## Option conflict

- 22023 reloads state/options;
- stale desired set is not silently partially applied.

## Lifecycle

- 55000 becomes final read-only state.

## Identity

- account switch clears state and rejects late responses.

---

# 36. Tests — participant group info

Cover:

- current member resolves `currentMembership`;
- rejoined member uses new current membership episode;
- current member sees current chips;
- current member can open Edit;
- former member resolves `latestMembership`;
- former member sees last commitments read-only;
- zero commitments;
- commitment failure is local to section;
- group info/open Project/meeting controls remain functional;
- creator still sees Manage participation rather than fake creator commitment state.

Do not change chat-history authorization tests.

---

# 37. Tests — creator Manage participation

Cover:

- current membership card has Commitments action;
- historical member has View commitments;
- tapping one member loads only that membership;
- no per-card commitment RPC fan-out;
- creator can edit current membership;
- creator views historical read-only;
- member display/status remains visible;
- remove-member action remains unchanged;
- CAS conflict from participant edit is handled safely.

---

# 38. Native QA deferred to Plan 12

Add checklist items:

- modal/bottom-sheet sizing;
- chip wrapping at small widths/text scaling;
- selected/stale semantics with screen reader;
- 50-item scrolling/performance;
- participant group-info edit;
- creator member edit;
- CAS conflict recovery;
- option-changed recovery;
- membership ending while editor open;
- keyboard/focus behavior;
- account switch while modal open.

Do not claim physical-device QA passed.

---

# 39. No DB migration

04C3C2 should consume PR #61's final backend contract.

No database migration is expected.

If the mobile implementation reveals an actual backend contract blocker, stop and report before modifying SQL.

Do not silently extend PR #61 semantics from this branch.

---

# 40. Documentation / roadmap

Update:

```text
04C3C1 — PR #61 open/unmerged
04C3C2 — current stacked mobile PR, in progress
```

Document final chosen mobile placement:

```text
participant/former participant
  → Project chat group info

creator
  → Manage participation member card

shared modal
  → current commitments
  → options
  → CAS replacement
```

Document that delegate/co-organizer permissions remain later work.

Do not mark C1/C2 implemented until merged.

---

# 41. Stacked Git hygiene

Keep the chain focused:

```text
main
→ #45
→ #52
→ #60
→ #61
→ C2
```

If main advances:

```text
rebase #45 onto main
→ #52 onto #45
→ #60 onto #52
→ #61 onto #60
→ C2 onto #61
```

Preserve every focused diff.

Open C2 against:

```text
codex/04c3c1-current-participant-commitments
```

not `main`.

Do not merge any layer while required backend validation remains unavailable.

---

# 42. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
npm run format:check
git diff --check
```

No DB migration is introduced by C2, but the stack's backend gates remain unresolved.

Attempt GitHub Validation once.

If runner startup is still blocked by billing/spending:

```text
CI not executed due external billing
```

Do not call it a test failure and do not rerun pointlessly.

---

# Non-goals

Do not implement:

- delegate/co-organizer roles;
- permission matrices;
- Project-admin schema;
- final contribution verification;
- fulfillment/delivery state;
- badges/stats;
- Tavolo skill requirements;
- commitment notifications;
- commitment Realtime;
- editing historical request selections;
- free-form contribution categories;
- quantities/units/prices;
- Scambio-Dona matching/linkage;
- final visual redesign.

---

# Acceptance criteria

Ready for review when:

- [ ] stack is current and C2 is based on PR #61;
- [ ] exact prompt archived;
- [ ] no DB migration added;
- [ ] membership commitment gateway uses only C1 RPCs;
- [ ] participant current membership resolves through existing participation state;
- [ ] former participant resolves latest ended membership;
- [ ] creator manages by existing membership IDs in Manage participation;
- [ ] no chat backend/schema change;
- [ ] no N+1 creator member reads;
- [ ] one shared commitment modal/editor is reused;
- [ ] current commitments and addable options remain distinct;
- [ ] retained stale commitments are visible/removable;
- [ ] persisted removal prevents stale item reappearing as addable;
- [ ] current member may edit;
- [ ] former member is read-only;
- [ ] current non-operational Project becomes read-only;
- [ ] creator can edit current member commitments;
- [ ] creator historical membership is read-only;
- [ ] CAS expected snapshot is captured at load;
- [ ] user toggles affect only desired set;
- [ ] `40001` reloads and requires explicit review;
- [ ] no automatic stale overwrite/retry;
- [ ] `22023` refreshes changed options safely;
- [ ] `55000` transitions to read-only;
- [ ] clear-all supported;
- [ ] 50/50 limits enforced;
- [ ] account switching clears private state;
- [ ] Messages request-history chips remain unchanged;
- [ ] localization/accessibility included;
- [ ] comprehensive Flutter tests pass;
- [ ] native QA remains deferred;
- [ ] hosted CI status reported truthfully;
- [ ] no PR merged.

---

# Autonomy / stop conditions

Codex may decide:

- exact controller/file names;
- dialog vs modal bottom sheet;
- exact compact visual treatment for stale retained chips;
- whether current chips are previewed inline or only inside the modal, provided group info still communicates current commitment state;
- reasonable localized copy.

Stop and report before:

- adding delegate/co-organizer roles;
- modifying Project-chat backend schemas;
- changing C1 database semantics;
- auto-merging CAS conflicts;
- adding notifications/Realtime;
- editing historical request selections;
- adding verification/fulfillment;
- merging any PR.

---

# Deliverables

1. current stack reconciliation;
2. exact archived C2 prompt;
3. strict membership commitment models;
4. RPC-only commitment gateway;
5. identity-bound commitment controller;
6. shared read/edit modal;
7. participant group-info current/former integration;
8. creator Manage-participation integration;
9. stale-retained commitment treatment;
10. 50/50 selection limits;
11. six-argument CAS save;
12. 40001/22023/55000 recovery;
13. account-switch safety;
14. localization/accessibility;
15. gateway/controller/widget tests;
16. Plan-12 QA checklist;
17. roadmap/docs update;
18. focused stacked PR;
19. structured completion report.

Do not merge any PR.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3C2 branch/base/PR**
3. **Changed files**
4. **GitHub Actions billing status**
5. **Mobile commitment architecture**
6. **Gateway/RPC usage**
7. **Participant membership resolution**
8. **Former-member resolution**
9. **Creator membership targeting**
10. **Group-info commitment section**
11. **Manage-participation integration**
12. **Shared modal/editor**
13. **Current vs addable option merge**
14. **Retained stale commitment UX**
15. **50/50 limits**
16. **Clear-all behavior**
17. **CAS expected/desired snapshots**
18. **40001 conflict recovery**
19. **22023 option-change recovery**
20. **55000 lifecycle/read-only recovery**
21. **Account-switch safety**
22. **Messages historical-request preservation**
23. **Localization/accessibility**
24. **No DB/chat schema changes**
25. **Flutter/router/widget tests**
26. **Local regression validation**
27. **Hosted Validation executed/not-executed**
28. **Deferred native QA**
29. **Delegate/co-organizer handoff**
30. **05C verification handoff**
31. **Warnings/blockers**
32. **Commit/PR reference**
