# PLANETS 05C2 — Mobile Actual Contribution Experience

**Roadmap area:** 05C — One-Time Project Actual Contribution Attribution  
**Task type:** Flutter/mobile integration over 05C1  
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
  e58b6d9e975765c9df45b32ed825bfa3f4e33119

PR #68 — 05C1 One-Time Actual Contribution Attribution Domain
  codex/05c1-actual-contribution-attribution-domain
  a7f7705fada6c01ef76cd0b1993182121ad15170
```

All remain intentionally open/unmerged. Schema-heavy lower layers still require executable Database validation.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the dependency stack in order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any existing PR;
5. branch this plan from the final PR #68 head;
6. open the new PR with base:
   `codex/05c1-actual-contribution-attribution-domain`.

Preferred branch:

```text
codex/05c2-mobile-actual-contributions
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05C2_mobile_actual_contribution_experience.md
```

No external document is required by Codex.

Do not merge any PR.

---

# Objective

Expose 05C1 actual-contribution attribution in the mobile app.

This is factual contribution history, not a person review/rating.

For an ended one-time Project:

```text
participant
→ can read their actual contributions

creator
→ can read and correct each membership episode's actual contributions
```

The automatic final-commitment baseline is already owned by the backend.

Mobile does not ask the creator to positively approve every participant.

Creator editing exists only for exceptions/corrections and off-app contributions.

---

# 1. Locked mobile placement

Use the existing participation surfaces.

## Participant / former participant

Use:

```text
Project group chat
→ Group info
→ Actual contributions
```

This section is read-only.

## Creator

Use:

```text
Project detail / Group info
→ Manage participation
→ membership card
→ Actual contributions
```

This opens the same actual-contribution sheet in editable mode.

Do not add:

- new bottom-nav destination;
- global contributions screen;
- mandatory Project-completion wizard.

---

# 2. One shared per-membership sheet

Create one reusable sheet, conceptually:

```text
showActualContributionSheet(...)
```

Inputs equivalent to:

```text
expectedProfileId
membershipId
editable
participantDisplayName?
```

Mode:

```text
participant → read-only
creator     → editable
```

The backend still decides actual authorization.

Use a modal bottom sheet or equivalent existing Material pattern.

---

# 3. Participant rejoin / multiple membership episodes

Actual attribution is membership-episode scoped.

Do not silently merge or discard multiple episodes.

For the participant Group Info path:

1. use existing `ownParticipationProvider`;
2. collect **all** own `OwnProjectMembership` rows matching:
   ```text
   projectId
   projectKind = oneTime
   ```
3. sort by `joinedAt` chronologically or newest-first consistently;
4. if exactly one episode:
   - show one simple `Actual contributions` action;
5. if multiple episodes:
   - show a compact list of participation episodes;
   - each row opens that membership's actual-contribution sheet.

Example:

```text
Actual contributions

Participation 2
Joined 12 Sep
[ View ]

Participation 1
Joined 4 Sep · Left 8 Sep
[ View ]
```

Do not aggregate skill/resource/effort truth across episodes in 05C2.

Later stats/badges can decide cross-episode aggregation semantics.

---

# 4. Creator episode targeting

`CreatorProjectMember.id` is already the canonical membership ID.

Keep creator editing per existing member card.

For one participant who rejoined, separate membership rows remain separate attribution records.

Do not merge by participant profile ID.

---

# 5. One-time Projects only

Show actual-contribution UI only for:

```text
ProjectKind.oneTime
```

Do not show it for Tavoli.

The backend still rejects unsupported lifecycle states.

No Tavolo final-contribution semantics are introduced here.

---

# 6. Pre-end / unavailable behavior

The mobile surfaces do not currently have a direct canonical `actual contributions available` flag.

Do not add a database migration just to expose one.

The user may open `Actual contributions` on a one-time Project before it ends.

If the 05C1 read returns lifecycle `55000`, show a safe informational state:

```text
Actual contributions become available after this one-time Project ends.
```

For cancelled/unsupported one-time state, use copy broad enough to remain truthful, e.g.:

```text
Actual contributions are not available for this Project yet.
```

Do not show raw backend text.

Do not treat lifecycle-unavailable as an application crash.

---

# 7. Strict mobile domain

Add typed models equivalent to:

```text
ActualContributionKind {
  skill
  resource
  substantialEffort
}

ActualContributionSource {
  finalCommitment
  creatorAdded
  substantialEffort
}

ActualContribution {
  kind
  id?       // null only for substantial effort
  label?    // null only for substantial effort
  source
}

ActualContributionOption {
  kind      // skill | resource only
  id
  label
}
```

Unknown kinds/sources fail safely.

Do not create a fake ID for Substantial Effort / Energy.

---

# 8. Localized effort marker

Backend returns:

```text
kind = substantial_effort
id = null
label = null
```

Flutter supplies localized copy:

```text
Substantial Effort / Energy
```

This is a built-in contribution marker.

Do not model it as a resource chip or skill catalog item.

---

# 9. Actual-contribution gateway

Add a narrow RPC-only gateway.

Required calls:

```text
listActualContributions(
  expectedProfileId,
  membershipId
)
→ list_project_membership_actual_contributions

listActualContributionOptions(
  expectedCreatorProfileId,
  membershipId
)
→ list_project_membership_actual_contribution_options

replaceActualContributions(
  expectedCreatorProfileId,
  membershipId,

  expectedSkillIds,
  expectedResourceIds,
  expectedSubstantialEffort,

  desiredSkillIds,
  desiredResourceIds,
  desiredSubstantialEffort
)
→ replace_project_membership_actual_contributions
```

No direct table access.

---

# 10. Read-only presentation

Group contributions into:

```text
Competences / Knowledge
[ Carpentry ] [ Event organization ]

Resources / Materials
[ Paint ] [ Wooden boards ]

Other contribution
[ Substantial Effort / Energy ]
```

Omit empty groups.

If all are empty:

```text
No actual contributions recorded.
```

This must remain neutral.

Do not imply:

- no-show;
- poor participant;
- negative review;
- misconduct.

---

# 11. Attribution-source presentation

Preserve the source in the mobile model.

Default read-only participant UX should focus on the factual resulting contribution rather than cluttering every chip.

It is acceptable to show a subtle source note where useful, especially in creator edit mode:

```text
From final commitment
Added by organizer
```

Do not phrase `creator_added` as:

```text
verified
approved
rated
```

The contribution itself is the canonical factual attribution.

---

# 12. Creator editor initial state

Editable sheet loads:

1. current effective actual contributions;
2. canonical creator options.

Capture expected snapshot from the current effective read:

```text
expectedSkillIds
expectedResourceIds
expectedSubstantialEffort
```

Initialize desired state to the same effective set.

The creator sees the already-automatic final commitments as selected.

No separate “approve all” operation exists.

---

# 13. Editor options union

Skills/resources shown in the editor come from:

```text
05C1 options read
```

Current selected contributions must remain represented even if a parser/order difference occurs.

Build keyed union using:

```text
(kind, id)
```

Do not key only by UUID.

The built-in effort option is appended client-side as its own dedicated toggle/control.

---

# 14. Creator edit semantics

The creator may:

```text
unselect selected skill/resource
→ exclude a contribution that did not actually happen

select unselected canonical skill/resource
→ add a contribution that happened outside the final commitment flow

toggle Substantial Effort / Energy
→ add/remove the built-in effort attribution
```

Do not expose the sparse override implementation to the user.

The UI edits the **effective actual set**.

---

# 15. No need to distinguish baseline mechanics in controls

The backend normalizes effective desired truth into sparse overrides.

Flutter should not attempt to calculate:

```text
baseline true/false
override row needed/not needed
```

It simply sends:

```text
expected effective set
desired effective set
```

Backend owns sparse reconciliation.

---

# 16. Independent 50/50 limits

Reuse/centralize existing:

```text
participationSkillSelectionMax = 50
participationResourceNeedSelectionMax = 50
```

Actual contribution desired sets use the same independent limits.

Substantial Effort / Energy does not count toward either.

At the limit:

- selected items remain deselectable;
- additional unselected items disabled;
- localized maximum guidance shown.

Do not copy unexplained magic numbers.

---

# 17. Clear-all

Creator may remove all skill/resource actual contributions and turn effort off.

This yields:

```text
No actual contributions recorded.
```

It does not:

- remove membership history;
- mark no-show;
- create a negative report.

---

# 18. No-op save

If desired equals expected:

```text
disable Save
```

or dismiss without mutation.

Do not show “updated” when nothing changed.

Backend no-op remains safe.

---

# 19. CAS save

Send exactly the loaded expected snapshot:

```text
expectedSkillIds
expectedResourceIds
expectedSubstantialEffort
```

and current UI desired state:

```text
desiredSkillIds
desiredResourceIds
desiredSubstantialEffort
```

Do not update expected values while toggling controls.

Expected changes only after a successful canonical reload/save.

---

# 20. `40001` stale-edit recovery

If another creator device/future delegate changes attribution first:

```text
40001
```

Do not:

- auto-merge;
- silently overwrite;
- retry stale desired state.

Instead:

1. reload actual contributions;
2. reload creator options;
3. reset desired state to canonical latest result;
4. show localized live-region guidance:

```text
These actual contributions changed elsewhere.
We loaded the latest version. Review it before saving again.
```

The creator then edits again explicitly.

---

# 21. `22023` invalid/stale desired set

Although Project skill/resource identities should be stable after end, use safe recovery.

On `22023`:

1. reload current effective actual contributions;
2. reload options;
3. reset draft to canonical current result;
4. show:

```text
The available contribution options changed.
Review the latest version and try again.
```

Do not expose raw PostgREST diagnostics.

Do not silently save a subset.

---

# 22. Lifecycle `55000`

When read/options/mutation returns lifecycle unavailable:

```text
show read/unavailable informational state
disable editing
```

Copy should cover:

- Project not ended yet;
- cancelled Project;
- unsupported lifecycle.

Suggested:

```text
Actual contributions are available after an eligible one-time Project ends.
```

Do not invent a separate cancelled-project attribution behavior.

---

# 23. Authorization/account changes

On:

```text
42501
sign-out
account switch
```

clear private state.

Reject late responses from the old identity.

Do not show one account's contribution state after switching profiles.

Reuse current revision/identity patterns.

---

# 24. Focused controller

Use a membership-keyed controller family.

Conceptual state:

```text
ActualContributionState {
  membershipId
  expectedProfileId

  readPhase
  contributions

  optionsPhase
  options

  expectedSkillIds
  expectedResourceIds
  expectedSubstantialEffort

  desiredSkillIds
  desiredResourceIds
  desiredSubstantialEffort

  isSaving
  failure
  limitReachedKind
}
```

Participant read-only mode:

```text
read only
options not requested
```

Creator editable mode:

```text
read + options
```

---

# 25. Failure domains

Distinguish at least:

```text
staleEdit        // 40001
optionsChanged   // 22023
forbidden        // 42501
notAvailable     // 55000
notFound         // P0002
unavailable      // other/transient
```

A transient options failure should preserve the actual-contribution read.

Do not make readable history disappear because editing options failed.

---

# 26. Shared sheet modes

## Participant read-only

Only call:

```text
list_project_membership_actual_contributions
```

No options/mutation.

## Creator editable

Call:

```text
actual read
+
options read
```

If actual read succeeds but options fail transiently:

```text
show factual contribution state
show local retry for editing
```

If options lifecycle says unavailable:

```text
show factual state if available
editing disabled
```

---

# 27. Participant Group Info integration

For:

```text
summary.projectKind == oneTime
summary.isCreator == false
```

add a new section after current/last commitments or at another nearby natural location:

```text
Actual contributions
```

Do not replace the existing commitments section.

Both remain useful:

```text
Commitments
→ what was expected before/during Project

Actual contributions
→ what is attributed after Project completion
```

---

# 28. Participant episode picker

After `ownParticipationProvider` is loaded, gather all matching membership episodes.

For one episode:

```text
Actual contributions
[ View ]
```

For multiple episodes:

```text
Actual contributions

Joined 12 Sep
Current/Left/Removed + relevant date
[ View ]

Joined 4 Sep
Left 8 Sep
[ View ]
```

Use existing membership timestamps/status.

Do not preload actual contributions for every episode.

Load only the episode the user opens.

No N+1 contribution reads.

---

# 29. Current membership after Project end

A one-time membership may still have status:

```text
current
```

after `ends_at`.

That does not make contributions editable by the participant.

Actual contributions remain read-only.

Do not infer contribution mutability from membership current/ended status.

---

# 30. Creator Manage participation integration

For:

```text
widget.projectKind == ProjectKind.oneTime
```

each membership card gets an additional action:

```text
Actual contributions
```

This action targets:

```text
CreatorProjectMember.id
```

and opens the shared sheet with:

```text
editable = true
```

Do not preload contribution reads for every member card.

No N+1.

---

# 31. Creator pre-end behavior

The action may exist before Project end because the current screen lacks a canonical end-eligibility flag.

On open, backend may return `55000`.

Render:

```text
Actual contributions are available after the Project ends.
```

This is preferable to adding an unrelated Proposal-status dependency merely to hide the button.

If repo evidence provides a clean existing derived-status source already loaded by this screen, Codex may hide/disable pre-end action, but do not add new network coupling solely for that polish.

---

# 32. Creator multiple membership rows

Keep each row independent.

If the same person rejoined:

```text
Mario — joined 12 Sep
[ Actual contributions ]

Mario — left 8 Sep
[ Actual contributions ]
```

Do not merge them in this screen.

The joined/status dates already disambiguate the episodes.

---

# 33. Effort visual treatment

Use a dedicated chip/toggle distinct enough to communicate that it is a special built-in attribution.

Example:

```text
Other contribution
[✓] Substantial Effort / Energy
```

Do not place it under Resources / Materials.

Do not use any fake resource iconography suggesting a physical item.

---

# 34. Participant transparency

A participant sees creator corrections as current canonical attribution.

No participant editing.

No Accept/Dispute buttons.

No public score.

No qualitative judgment field.

Future:

```text
Remind creator
```

is explicitly outside this slice.

---

# 35. Successful creator save

After mutation success:

1. reload canonical actual contributions;
2. reload options;
3. update expected snapshot;
4. clear dirty/error state.

The sheet may stay open showing saved state or close according to the cleanest existing contribution/commitment pattern.

Prefer consistency with `membership_commitment_sheet.dart`.

Do not fabricate final state locally.

---

# 36. Dismissal behavior

Closing an editable sheet without Save:

```text
no backend change
```

Do not persist drafts to local storage.

Reopening starts from canonical actual-contribution state.

---

# 37. Localization

Add production copy through l10n.

At minimum concepts equivalent to:

```text
Actual contributions
View actual contributions
Edit actual contributions

Competences / Knowledge
Resources / Materials
Other contribution
Substantial Effort / Energy

No actual contributions recorded.
From final commitment
Added by organizer

Actual contributions are available after an eligible one-time Project ends.
Unable to load actual contributions.
Unable to load contribution options.
Unable to update actual contributions.

These actual contributions changed elsewhere.
We loaded the latest version. Review it before saving again.

The available contribution options changed.
Review the latest version and try again.

Maximum {count} selections
Save contributions
Clear all
Try again

Participation joined {date}
Left {date}
Removed {date}
```

No hard-coded production copy.

---

# 38. Accessibility

Contribution chips/controls:

- label;
- selected state;
- enabled/disabled state;
- keyboard/focus behavior.

Effort toggle:

- full localized semantic label;
- selected state.

Episode picker:

- clearly associates joined/end dates with View action.

Errors/conflicts:

- live-region announcements.

Long labels:

- wrap without horizontal overflow.

---

# 39. Tests — domain/parser/gateway

Cover:

- skill contribution parsing;
- resource parsing;
- effort parsing with null ID/label;
- invalid effort row shape;
- unknown kind;
- unknown attribution source;
- options parsing;
- exact read RPC;
- exact options RPC;
- exact eight-argument CAS mutation;
- expected vs desired arrays separate;
- deterministic array ordering;
- effort boolean mapping;
- no direct table access.

---

# 40. Tests — controller read mode

Cover:

- skill/resource/effort read;
- empty contribution list;
- participant read-only mode performs no options call;
- `55000` maps to notAvailable;
- transient failure;
- account switch clears state;
- late response ignored.

---

# 41. Tests — controller edit mode

Cover:

## Load

- actual + options ready;
- actual ready / options transient failure;
- lifecycle unavailable;
- effort initial false/true.

## Toggle

- skill;
- resource;
- effort;
- changing desired state does not change expected snapshot.

## Limits

- 50 skills;
- 50 resources;
- independent limits;
- effort excluded from count.

## Save

- correct expected/desired arrays/effort sent;
- clear-all;
- no-op guarded;
- successful reload.

---

# 42. Tests — CAS/error recovery

Cover:

```text
40001
→ reload latest
→ discard stale local draft
→ conflict guidance

22023
→ reload actual/options
→ discard stale local draft
→ options-changed guidance
```

Also:

- no automatic resubmit;
- forbidden clears private state;
- notAvailable disables edit.

---

# 43. Tests — participant Group Info

Cover:

- one-time participant gets Actual contributions section;
- recurring/Tavolo does not;
- one membership → simple View;
- multiple membership episodes → separate rows;
- episode rows sorted deterministically;
- opening one episode loads only that episode;
- no N+1 contribution calls;
- current membership after Project end remains read-only;
- empty contribution result;
- pre-end unavailable informational state;
- existing commitments section unchanged;
- meeting details/open Project behavior unchanged.

---

# 44. Tests — creator Manage participation

Cover:

- one-time member card has Actual contributions action;
- recurring/Tavolo member card does not;
- current membership can edit actual attribution after end;
- historical membership can also be edited after end;
- ended-before-end episode may receive creator-added contribution;
- separate rejoin membership rows remain separate;
- tapping one member loads only that membership;
- no per-row contribution fan-out;
- commitment/remove buttons remain unchanged.

---

# 45. Tests — shared sheet widgets

Cover:

- read-only grouping;
- effort group;
- empty state;
- editor starts from current effective set;
- options not selected unless actual read says selected;
- skill/resource toggles;
- effort toggle;
- max guidance;
- save enabled only when dirty;
- saving progress;
- conflict notice;
- lifecycle-unavailable state;
- transient options retry;
- long labels/text scaling.

---

# 46. Native QA deferred to Plan 12

Add checks for:

- actual-contribution sheet sizing;
- long skill/resource labels;
- effort marker presentation;
- 50-option scrolling/performance;
- participant one-episode flow;
- participant multiple-episode picker;
- creator current/historical membership edit;
- pre-end informational state;
- CAS conflict recovery;
- account switch while sheet open;
- text scaling;
- TalkBack/VoiceOver;
- keyboard/focus behavior.

Do not claim physical-device QA passed.

---

# 47. Documentation / roadmap

Update accurately:

```text
05C1 — PR #68 open/unmerged
05C2 — this stacked mobile PR
```

Document mobile placement:

```text
participant:
Project chat → Group info → Actual contributions → membership episode

creator:
Manage participation → member card → Actual contributions
```

Document that:

- participant editing is not supported;
- reminder-to-creator remains future;
- Tavoli remain deferred;
- stats/badges remain downstream.

Do not mark 05C implemented until merged.

---

# 48. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run formatting and focused tests.

No DB migration is expected in 05C2.

The inherited 05C1/backend stack still requires executable Database validation before merge.

Attempt hosted Validation once.

If runner startup is again rejected due billing/spending limits:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- participant mutation/dispute;
- participant Remind creator workflow;
- group claim/survey for contribution credit;
- public contribution profile/stats;
- badges;
- leaderboards;
- negative/no-show reports;
- public ratings/reviews;
- creator self-contribution credit;
- cancelled Proposal attribution;
- Tavolo final attribution;
- push/global notifications;
- free-form contribution text.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and 05C2 based on PR #68;
- [ ] exact prompt archived;
- [ ] no DB migration added;
- [ ] strict actual-contribution models exist;
- [ ] RPC-only gateway uses 05C1 contracts;
- [ ] one shared per-membership sheet exists;
- [ ] participant mode is read-only;
- [ ] creator mode is editable;
- [ ] effort is a dedicated built-in control, not fake skill/resource;
- [ ] one-time only UI;
- [ ] pre-end lifecycle unavailable handled safely;
- [ ] participant Group Info shows Actual contributions;
- [ ] participant multiple episodes remain distinct;
- [ ] no participant episode aggregation invented;
- [ ] creator member card targets exact membership ID;
- [ ] no N+1 member/episode contribution reads;
- [ ] expected CAS snapshot captured from loaded effective state;
- [ ] desired toggles do not mutate expected state;
- [ ] 50/50 limits enforced independently;
- [ ] clear-all supported;
- [ ] no-op save blocked;
- [ ] 40001 reloads canonical latest state;
- [ ] no stale auto-merge/retry;
- [ ] 22023 reloads latest options/state;
- [ ] account switching clears private state;
- [ ] commitments UI remains unchanged;
- [ ] no participant editing/reminder/stats/moderation added;
- [ ] localization/accessibility complete;
- [ ] comprehensive Flutter tests pass;
- [ ] debug APK passes;
- [ ] native QA deferred;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **05C2 branch/base/PR**
3. **Changed files**
4. **Mobile actual-contribution architecture**
5. **Domain models**
6. **RPC gateway**
7. **Participant read-only behavior**
8. **Participant multiple-episode behavior**
9. **Creator exact-membership targeting**
10. **Shared actual-contribution sheet**
11. **Skill/resource grouping**
12. **Substantial Effort / Energy UI**
13. **Attribution-source handling**
14. **Creator editor initial state**
15. **Options union**
16. **50/50 limits**
17. **Clear-all/no-op behavior**
18. **CAS expected/desired snapshot**
19. **40001 conflict recovery**
20. **22023 options recovery**
21. **Lifecycle-unavailable behavior**
22. **Account-switch safety**
23. **Group Info integration**
24. **Manage participation integration**
25. **No N+1 behavior**
26. **Commitment UI regression**
27. **Tavolo exclusion**
28. **Localization/accessibility**
29. **Gateway/controller/widget tests**
30. **Local regression validation**
31. **Hosted Validation executed/not-executed**
32. **Deferred native QA**
33. **Reminder-creator future handoff**
34. **Stats/badges future handoff**
35. **Warnings/blockers**
36. **Commit/PR reference**

Do not merge any PR.
