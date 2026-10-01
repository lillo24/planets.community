# PLANETS 04C3D2 — Mobile Join-Acceptance Contribution Triage

**Roadmap area:** 04C3D — Acceptance Triage and Live Project Coverage  
**Task type:** Flutter/mobile integration over 04C3D1  
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
  codex/04c3d1-acceptance-contribution-triage
  e4b6d3a2da4dace419ae1474a0e2365eb7aaebcd
```

All remain intentionally open/unmerged because executable database validation is still blocked.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the stack in order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any layer;
5. branch this plan from the final PR #63 head;
6. open the new PR with base:
   `codex/04c3d1-acceptance-contribution-triage`.

Preferred branch:

```text
codex/04c3d2-mobile-acceptance-triage
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3D2_mobile_join_acceptance_contribution_triage.md
```

Do not merge any PR.

---

# Objective

Replace the current direct creator Accept action with a mandatory three-way contribution triage flow.

A pending requester may have offered:

```text
Competences / Knowledge
[ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Ladder ]
```

Before accepting the person, the creator must classify **every offered item**:

```text
Needed
Already found
Extra is fine
```

Only after every offered item is classified may the app submit the D1 eight-argument acceptance RPC.

The backend remains authoritative.

---

# 1. Existing acceptance entry points

There are currently two creator acceptance surfaces:

```text
A. CreatorParticipationScreen
   Manage participation
   → pending request card
   → Accept

B. ParticipationRequestMessageScreen
   structured request detail
   → creator Accept
```

Both must use the same triage flow.

There must be no remaining mobile path where a selected-contribution request calls the old two-argument acceptance RPC.

Reject remains unchanged.

Requester Withdraw remains unchanged.

---

# 2. One shared triage surface

Create one reusable mobile surface, preferably within the participation feature:

```text
showJoinAcceptanceTriageSheet(...)
```

A modal bottom sheet is preferred unless repository conventions strongly suggest another Material surface.

Inputs conceptually:

```text
expectedCreatorProfileId
requestId
projectId
projectKind
requesterDisplayName
```

Return conceptually:

```text
Future<bool>
```

where:

```text
true  = request was successfully accepted
false = dismissed / failed / became unavailable
```

Both creator surfaces reuse this exact component/controller.

---

# 3. Dedicated participation-side triage boundary

Do not make the acceptance domain owned by Messages.

Add a focused participation-side triage boundary, e.g.:

```text
domain/join_acceptance_triage_models.dart
data/join_acceptance_triage_gateway.dart
application/join_acceptance_triage_controller.dart
presentation/join_acceptance_triage_sheet.dart
```

Exact file names may follow repository conventions.

It may call the already-existing B1 selection read RPC:

```text
list_own_project_join_request_contribution_selections
```

and the D1 acceptance RPC:

```text
accept_project_join_request(
  creator,
  request,
  needed skills,
  already-found skills,
  extra skills,
  needed resources,
  already-found resources,
  extra resources
)
```

No direct table access.

No duplicated SQL semantics in Flutter.

---

# 4. Strict mobile model

Model each offered item with:

```text
kind
id
label
decision?
```

Kinds:

```text
skill
resource
```

Decision:

```text
needed
alreadyFound
extra
```

Use a composite logical key:

```text
(kind, id)
```

Do not key only by raw UUID/string.

Unknown backend selection kinds fail safely.

---

# 5. Lazy load on Accept

Do not preload selection details for every request card.

That would cause N+1 RPC behavior.

Instead:

```text
creator taps Accept
→ open triage sheet
→ load only that request's selections
```

This applies to Manage participation.

Messages request detail already has contribution selections loaded independently for display, but the shared triage sheet should own its canonical triage state rather than depending on Messages state.

It is acceptable for the sheet to perform its own narrow selection read.

This keeps both entry points identical and avoids stale cross-feature coupling.

---

# 6. Zero-selection requests

The mobile client may always use the D1 explicit triaged acceptance RPC.

For a request with zero offered contributions:

```text
triage sheet:
  "No contribution offers to classify."
  [Accept person]
```

Send six empty arrays.

Do not use the two-argument compatibility RPC from mobile after D2.

The backend compatibility overload remains for older/no-selection callers, but the new mobile path should have one acceptance contract.

---

# 7. Triage UI

Group offered items exactly as the request UI does:

```text
Competences / Knowledge

Carpentry
[ Needed ] [ Already found ] [ Extra is fine ]

Event organization
[ Needed ] [ Already found ] [ Extra is fine ]


Resources / Materials

Paint
[ Needed ] [ Already found ] [ Extra is fine ]

Ladder
[ Needed ] [ Already found ] [ Extra is fine ]
```

Each item has exactly one selected disposition or none.

Do not default all items to `needed`.

The creator must make the decision explicitly.

---

# 8. Disposition copy

Use concise localized user-facing copy.

Suggested English:

```text
Needed
Already found
Extra is fine
```

Helper semantics:

```text
Needed
  "This person is expected to help with / bring this."

Already found
  "You do not need this from this person."

Extra is fine
  "They may still help with / bring this, but it is not being used as the needed contribution."
```

Do not use wording that implies physical delivery has already happened.

`Already found` is an acceptance-time organizer classification, not final proof.

---

# 9. Mandatory classification behavior

The sheet must allow the creator to press the final Accept button even with undecided items so the interface can teach the requirement.

On an incomplete Accept attempt:

```text
DO NOT call backend
DO NOT close sheet

for every undecided item:
  → highlight the item label/container with error border
  → trigger a brief horizontal shake

announce an accessible error:
  "Decide what this person should bring or help with before accepting."
```

The shake is feedback, not the only signal.

Do not rely on animation or color alone.

---

# 10. First incomplete-attempt guidance

On the **first incomplete Accept attempt for that sheet opening**, show one contextual tooltip/popover.

Conceptual copy:

```text
Decide what this person should bring or help with before accepting.
You can change their current commitments later from Project management.
```

A manually triggered Material `Tooltip`, anchored help bubble, or equivalent accessible popover is acceptable.

Requirements:

- show only once per sheet opening;
- do not require persisted onboarding state;
- do not show repeatedly on every failed press;
- screen-reader users must receive the same information.

Do not add SharedPreferences/local-storage onboarding solely for this.

---

# 11. Error border and shake lifecycle

When an undecided item is invalidated:

```text
border = error
shake once
```

As soon as the creator chooses any disposition for that item:

```text
remove error border
```

If the creator clears/changes a decision later, validation behaves consistently.

The sheet may expose a monotonically increasing validation-attempt/pulse value so item widgets can animate only when a new incomplete submission occurs.

Do not use uncontrolled repeated animation.

---

# 12. Selection controls and accessibility

Use Material controls appropriate for mutually exclusive choices:

- `SegmentedButton`,
- `ChoiceChip`,
- or equivalent.

Requirements:

- one disposition max per offered item;
- keyboard/focus operable;
- selected state in semantics;
- labels wrap at narrow widths;
- the offered item's label remains visually distinct from its three actions;
- error state has semantic text, not red border alone.

Do not create tiny touch targets.

---

# 13. Shared controller state

Use a request-keyed identity-bound controller.

Conceptually:

```text
JoinAcceptanceTriageState {
  requestId
  expectedCreatorProfileId

  loadPhase
  selections

  decisionsByItem

  validationAttempt
  hasShownFirstGuidance

  isAccepting
  failure
}
```

Identity/account changes clear state.

Late responses from an old account/request must not populate the new session.

Dismissed sheets do not persist unsaved triage.

---

# 14. Gateway contract

Gateway methods conceptually:

```text
listSelections(
  expectedCreatorProfileId,
  requestId
)

acceptWithTriage(
  expectedCreatorProfileId,
  requestId,

  neededSkillIds,
  alreadyFoundSkillIds,
  extraSkillIds,

  neededResourceNeedIds,
  alreadyFoundResourceNeedIds,
  extraResourceNeedIds
)
```

Sort each outbound ID array deterministically.

Do not send labels.

Do not send request message text.

No direct table reads/writes.

---

# 15. Partition construction

The controller, not the widget, should construct the six sets from item decisions.

Before mutation it must locally guarantee:

```text
every loaded selection has exactly one decision
```

The D1 backend then independently guarantees the same invariant.

Do not silently classify omitted items.

Do not silently drop malformed items.

---

# 16. Backend `22023` during acceptance

After local classification is complete, `22023` should normally mean the Project changed since the requester originally offered the item—for example:

```text
Needed skill removed from Proposal
Needed resource closed
```

Do not show raw database text.

Show safe guidance, conceptually:

```text
The Project needs changed.
Review the items marked Needed before accepting.
```

Keep the sheet open.

Preserve the creator's decisions.

Do not automatically turn `Needed` into `Already found` or `Extra`.

If helpful, visually flag the currently `Needed` decisions for review, but do not claim the client knows which specific item the backend rejected unless there is canonical evidence.

No automatic retry.

---

# 17. Conflict `55000`

If acceptance loses a race because:

```text
request withdrawn
request already resolved elsewhere
requester already became current member
Project is no longer accepting
```

map to a safe conflict state.

Then:

```text
stop accepting
surface "This request can no longer be accepted."
return false / allow caller to refresh
```

Do not continue editing a terminal request indefinitely.

The calling surface should refresh canonical state.

---

# 18. Authorization `42501`

If creator identity is no longer authorized:

- clear/private-fail the sheet;
- do not preserve decisions into another account;
- do not expose raw diagnostics.

Account switch/sign-out should close or render the sheet unavailable according to the existing auth-route pattern.

---

# 19. Successful acceptance

On success:

```text
backend:
  stores immutable decisions
  accepts request
  creates membership
  seeds needed+extra commitments
  activates/ensures chat
```

Mobile:

1. close triage sheet with `true`;
2. caller refreshes canonical surrounding UI;
3. Project-chat refresh signal is triggered so the new chat/member state can appear.

Do not fabricate commitment state locally.

Reload from canonical participation/messages state.

---

# 20. Manage participation integration

Change the current pending request `Accept` button.

Current:

```text
Accept
→ creatorParticipationController.accept(...)
```

New:

```text
Accept
→ show shared triage sheet
→ if success:
     reload CreatorParticipationScreen state
     refresh Project chat signal
```

Reject remains direct.

Do not load triage data until Accept is tapped.

The request card itself does not need to show all contribution chips.

---

# 21. Messages request-detail integration

Current creator action:

```text
Accept
→ messagesDetailProvider.accept()
```

Replace only the acceptance path.

New:

```text
Accept
→ show same shared triage sheet
→ if success:
     reload the canonical request detail
     refresh Messages inbox
     refresh creator participation state if currently loaded for same Project
     refresh Project chat signal
```

Reject remains in the Messages controller.

Requester Withdraw remains in the Messages controller.

The historical contribution chips shown in the request detail remain unchanged.

---

# 22. Remove/retire direct two-arg mobile acceptance

After D2, search the mobile repository for all calls to:

```text
accept_project_join_request
```

Ensure production Flutter only uses the explicit D1 triaged signature.

If existing `ParticipationGateway.acceptRequest` or `MessagesGateway.accept` remains as a two-argument production path, either:

- evolve it to the explicit triage contract, or
- remove it if the new shared gateway owns acceptance.

Do not leave an unused-but-callable production helper that can accidentally restore bypass semantics later.

Backend two-arg compatibility stays untouched.

---

# 23. Current Messages selection controller remains useful

Do not remove the existing B2 Messages selection read.

It remains responsible for displaying:

```text
what the requester originally offered
```

inside structured Messages.

The triage sheet's own read is action-local.

No acceptance-decision history UI is required in D2.

---

# 24. No current commitment UI change

C3C2 already provides:

```text
participant group info
→ current commitments

creator Manage participation
→ member commitments
```

Do not modify that editor in D2 except for shared constants/types if genuinely useful.

Once accepted, the backend-seeded commitments appear through the existing canonical reads.

No manual client seeding.

---

# 25. Tavolo behavior

Tavolo requests currently support:

```text
resources only
```

The shared triage sheet should naturally show:

```text
Resources / Materials
```

with no fake competence section.

All three dispositions are available for resource offers.

Do not add Tavolo skill support.

---

# 26. Copy about later changes

The first-time guidance should be accurate to the implemented C3C2 flow.

Prefer wording equivalent to:

```text
You can change this participant's current commitments later from Project management.
```

Do not imply historical acceptance decisions themselves are editable.

Important distinction:

```text
acceptance triage = immutable history
current commitments = editable later
```

---

# 27. Localization

Add all production copy through l10n.

At minimum:

```text
Review contribution offers
Before accepting {name}, decide what each offer means.
Needed
Already found
Extra is fine

Needed helper
Already found helper
Extra helper

Accept person
Decide every contribution first.
You can change current commitments later from Project management.

Project needs changed. Review the items marked Needed.
This request can no longer be accepted.
Unable to load contribution offers.
Try again.
```

No hard-coded production strings.

---

# 28. Motion/accessibility

Respect reduced-motion/accessibility behavior where available.

The shake should be:

- short;
- subtle;
- non-looping;
- non-blocking.

If motion is reduced/disabled, retain the red/error border and semantic error without requiring animation.

The first-time tooltip/popover must be focus/semantics accessible.

---

# 29. Tests — parser/gateway

Cover:

- skill selection parsing;
- resource selection parsing;
- unknown kind fails safely;
- exact B1 selection RPC;
- exact D1 eight-argument accept RPC;
- six arrays mapped correctly;
- labels never submitted;
- deterministic ordering;
- all-empty acceptance;
- no direct table access.

---

# 30. Tests — controller

Cover:

## Load

- skill/resource selections load;
- zero selections ready;
- read failure;
- identity switch clears state;
- late old-account response ignored.

## Decisions

- assign Needed;
- assign Already found;
- assign Extra;
- changing disposition replaces previous one;
- skill/resource same raw ID remain distinct if fixture supports it.

## Mandatory validation

- incomplete accept does not call gateway;
- validation attempt increments;
- undecided items marked invalid;
- deciding an invalid item clears its error;
- first guidance only once per sheet opening/state lifecycle.

## Mutation

- complete mixed partition submits exact six sets;
- zero-selection request submits six empty arrays;
- success returns accepted;
- no duplicate IDs.

## Backend failures

- `22023` preserves decisions and asks review;
- `55000` becomes terminal conflict;
- `42501` becomes forbidden;
- unknown error safe/unavailable.

---

# 31. Tests — triage sheet interaction

Widget tests should verify:

- groups render correctly;
- zero-selection state;
- all three dispositions selectable;
- exactly one selected per item;
- Accept with incomplete state:
  - no RPC;
  - error border;
  - shake trigger/state;
  - accessible error;
  - first-time tooltip/popover;
- repeated incomplete attempt does not repeat first-time guidance;
- completing decisions enables successful acceptance path;
- long labels wrap;
- loading/failure/retry;
- accepting progress state;
- account switch safety.

Avoid tests that depend on exact animation frame pixel positions where state/semantics can prove the behavior more robustly.

---

# 32. Tests — Manage participation

Cover:

```text
Accept on pending card
→ opens triage sheet
→ only tapped request loads selections
```

No per-row fan-out.

After successful triaged acceptance:

- request becomes accepted/removed from pending position according to canonical data;
- member appears;
- Reject behavior unchanged;
- Project chat refresh emitted.

---

# 33. Tests — Messages detail

Cover:

- creator Accept opens same triage sheet;
- requester never sees triage;
- Reject unchanged;
- Withdraw unchanged;
- historical request-selection chips remain visible;
- successful triaged acceptance reloads canonical detail;
- inbox synchronization still occurs;
- creator participation refreshes if relevant;
- chat refresh occurs;
- selection-read failure in the Messages display does not silently bypass triage—the action-local triage read must succeed before acceptance.

---

# 34. Native QA deferred to Plan 12

Add checks for physical Android/iOS:

- bottom-sheet sizing;
- long contribution labels;
- 3-option controls at narrow widths;
- shake subtlety;
- red/error border visibility;
- reduced-motion behavior;
- tooltip/popover positioning;
- TalkBack/VoiceOver reading of item + selected disposition + error;
- keyboard/focus order;
- two acceptance entry points;
- zero-selection request;
- Project-needs-changed rejection;
- account switch while sheet is open.

Do not claim native QA passed.

---

# 35. No database migration

D2 must consume PR #63 as-is.

No SQL migration is expected.

If mobile implementation discovers a genuine backend contract blocker, stop and report before modifying database code.

Do not silently patch D1 from the D2 branch.

---

# 36. Documentation / roadmap

Update roadmap status accurately:

```text
04C3D1 — PR #63 open/unmerged
04C3D2 — this mobile PR in progress
04C3D3 — not started
```

Document both creator entry points.

Do not mark D1 or D2 implemented before merge.

---

# 37. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run repository formatting checks and distinguish any pre-existing Site formatter issues from D2 changes.

Attempt hosted Validation once.

If GitHub runner startup is still rejected due billing/spending limit:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

The lower backend stack still requires executable Database validation before merge.

---

# Non-goals

Do not implement:

- live Project need coverage;
- needed-again detection;
- chat Needs button/drawer;
- system chat resurfacing messages;
- notification/badge/popover for resurfaced needs;
- participant claim-from-chat;
- final actual contribution attribution;
- Substantial Effort / Energy;
- delegate/co-organizer permissions;
- negative/no-show reporting;
- Tavolo skill requirements;
- acceptance-decision history UI;
- public ratings/reviews.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and D2 based on PR #63;
- [ ] exact prompt archived;
- [ ] no DB migration added;
- [ ] one shared participation-side triage controller/sheet exists;
- [ ] both creator acceptance entry points use it;
- [ ] contribution selections load lazily;
- [ ] no N+1 request-selection reads;
- [ ] Needed / Already found / Extra modeled distinctly;
- [ ] no default disposition;
- [ ] every offered item must be classified locally;
- [ ] incomplete Accept never calls backend;
- [ ] undecided item shows error border;
- [ ] undecided item receives one brief shake per failed attempt;
- [ ] first incomplete attempt shows one accessible guidance tooltip/popover;
- [ ] later attempts do not repeat onboarding guidance;
- [ ] eight-argument RPC is the only production mobile accept path;
- [ ] zero-selection requests submit six empty arrays safely;
- [ ] `22023` keeps decisions and prompts review;
- [ ] `55000` handles terminal request conflict safely;
- [ ] account switching clears triage;
- [ ] successful accept refreshes surrounding canonical state;
- [ ] Messages request-history chips unchanged;
- [ ] Reject/Withdraw unchanged;
- [ ] Tavolo remains resource-only;
- [ ] localization/accessibility included;
- [ ] Flutter tests and debug APK pass;
- [ ] native QA deferred;
- [ ] no PR merged.

---

# Deliverables

1. stack reconciliation;
2. archived D2 prompt;
3. triage domain models;
4. RPC-only triage gateway;
5. request-keyed identity-bound controller;
6. shared triage sheet;
7. mandatory validation feedback;
8. red-border/shake behavior;
9. first-attempt tooltip/popover;
10. Manage participation integration;
11. Messages-detail integration;
12. eight-array acceptance mutation;
13. safe backend error mapping;
14. localization/accessibility;
15. comprehensive Flutter tests;
16. docs/roadmap update;
17. focused stacked PR;
18. structured completion report.

Do not merge any PR.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3D2 branch/base/PR**
3. **Changed files**
4. **Mobile triage architecture**
5. **Selection-read gateway**
6. **Eight-argument acceptance gateway**
7. **Triage domain model**
8. **Lazy loading / no N+1**
9. **Needed behavior**
10. **Already-found behavior**
11. **Extra behavior**
12. **Mandatory classification**
13. **Error border**
14. **Shake behavior**
15. **First-attempt guidance**
16. **Zero-selection behavior**
17. **22023 stale-need recovery**
18. **55000 conflict recovery**
19. **Account-switch safety**
20. **Manage participation integration**
21. **Messages-detail integration**
22. **Removal of direct two-arg mobile accept paths**
23. **Reject/Withdraw regression**
24. **Messages history preservation**
25. **Tavolo resource-only behavior**
26. **Localization/accessibility**
27. **Flutter/widget/controller/gateway tests**
28. **Local regression validation**
29. **Hosted Validation executed/not-executed**
30. **Deferred native QA**
31. **04C3D3 handoff**
32. **05C handoff**
33. **Warnings/blockers**
34. **Commit/PR reference**
