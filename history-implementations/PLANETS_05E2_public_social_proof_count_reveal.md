# PLANETS 05E2 — Public Social-Proof Count Reveal Threshold

## Objective

Add the agreed PLANETS social-proof rule:

> Public Project cards/details should not expose very low exact involvement counts before they become socially meaningful.

This is a **presentation rule**, not a capacity or popularity-domain rewrite.

Exact aggregate counts remain available internally to organizers/managers, capacity enforcement, future popularity/ranking, and authorized tests/analytics.

The public mobile UI reveals exact attendance/social counts only after a capacity-scaled threshold.

## Repository / branch requirement

Repository:

```text
lillo24/planets.community
```

PR #121 — `05E1: Add organizer-aware capacity and public headcount` — is merged.

Required exact base:

```text
11155618e0aa7bf0de62ae178f79d4c0c50ac644
```

Required base branch:

```text
main
```

Create:

```text
codex/05e2-public-social-proof-threshold
```

Open a **draft PR targeting `main`**.

Do not create another stacked PR. Do not merge the 05E2 PR.

Before work, verify current/fetched `main` is exactly:

```text
11155618e0aa7bf0de62ae178f79d4c0c50ac644
```

If `main` moved, stop and report the new SHA rather than silently using a stale base.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05E2_public_social_proof_count_reveal.md
```

## Current repository behavior

At current `main`, 05E1 is implemented.

`ProjectCapacitySnapshot` already contains:

- `registrationCapacity`
- `countOrganizersTowardCapacity`
- `currentParticipantCount`
- `ordinaryParticipantCount`
- `organizerCount`
- `capacityUsedCount`
- `socialPeopleCount`
- `spotsRemaining`
- `isFull`

Current domain validation already enforces the 05E1 relationship:

```text
socialPeopleCount == ordinaryParticipantCount + organizerCount
```

Do not change canonical 05E1 counting semantics.

The shared:

```text
apps/mobile/lib/features/participation/presentation/project_capacity_label.dart
```

currently always renders exact values.

Verified current usages include:

- Proposal card
- Proposal public detail
- Tavolo card
- Tavolo public detail
- `ProjectParticipationSection`
- `CreatorParticipationScreen`

This means the implementation must not globally hide values for managers.

Prefer an explicit presentation mode or equivalent clear API, conceptually:

```text
public
managerExact
```

`CreatorParticipationScreen` must stay exact.

`ProjectParticipationSection` already resolves the viewer's management role, so use that existing knowledge where appropriate to avoid contradictory hidden/exact copies for managers.

## Product decision

Do not show weak/negative social proof such as:

```text
1 / 20
1 person involved
```

or equivalent.

The Project may still advertise intended capacity and organizer presence, but exact joined/involved numbers stay hidden until socially meaningful.

Do not show copy like:

- `No one interested yet`
- `Only 1 person`
- `1 / 20 people`

before reveal.

## Reveal threshold

Use one deterministic capacity-scaled rule:

```text
threshold =
  if registration_capacity is null:
    3
  else:
    min(
      registration_capacity,
      max(3, ceil(registration_capacity * 0.20))
    )
```

Examples:

```text
capacity 10  -> threshold 3
capacity 20  -> threshold 4
capacity 100 -> threshold 20
```

Do not persist this threshold.

It is derived presentation policy.

## What count qualifies for reveal?

The immutable Creator alone must not move the Project toward public count reveal.

Use:

```text
non_creator_people_involved =
  max(social_people_count - 1, 0)
```

Then:

```text
reveal_exact_public_count =
  is_full
  OR non_creator_people_involved >= threshold
```

This preserves 05E1 role semantics:

- participant counts
- Co-organizer counts
- Co-creator counts
- organizer+participant overlap counts once
- promotion that preserves `socialPeopleCount` does not change reveal state
- Creator alone does not unlock social proof

`isFull` always overrides hiding.

## Distinction from capacity

This rule must not affect:

- whether someone can request to join
- registration-capacity enforcement
- `capacityUsedCount`
- `spotsRemaining`
- organizer counting toggle
- delegated authority
- manager blocking
- server concurrency
- lifecycle

A Project may be joinable while exact public social count is hidden.

## Distinction from popularity

Do not hide, zero, or mutate canonical `socialPeopleCount`.

Future popularity uses the real value:

```text
popularity_people_count = social_people_count
```

Do not implement popularity score, Popular tag, sorting, ranking, normalization, or size boost.

## Public UI before threshold

Before reveal, show useful capacity information without exposing exact current participant/social numerators.

If organizers are excluded from registration capacity, suitable semantics are:

```text
Up to 20 participants · +3 organizers
```

Do not show:

```text
2 / 20 participants
5 people involved
```

before threshold.

If organizers count toward capacity, use wording such as:

```text
Capacity 20 · 3 organizers included
```

Do not label mixed capacity usage as “participants”.

Exact copy/layout is implementation-owned, but semantics must remain clear.

## Public UI after threshold

Once revealed, show exact 05E1 values.

Example, organizers excluded:

```text
6 / 20 participants · +2 organizers
8 people involved
```

If organizers count toward capacity, make that clear rather than mislabeling mixed usage.

`socialPeopleCount` must remain the exact unique total.

## Full Projects

Canonical full Projects always expose `Full`.

Do not alter `isFull`.

Exact breakdown may also be shown when full.

## Legacy/null capacity

If:

```text
registrationCapacity == null
```

threshold is:

```text
3 non-Creator people
```

Before threshold:

- keep `Capacity not set`
- keep organizer count
- hide exact social involvement count
- do not invent a capacity

## Private / manager UX

Managers/organizers always retain exact current counts.

Do not hide values in:

- Creator/manager Participation
- Project editor/settings
- Project Team management
- internal capacity validation
- private organizer workflows

Current `CreatorParticipationScreen` already renders a capacity label plus exact manager summary; preserve that.

The public detail also includes `ProjectParticipationSection`, which already knows whether the viewer is a manager. Avoid a final UI where a manager sees nearby contradictory hidden/exact values.

## Scope of public surfaces

Apply consistently to current mobile:

- Proposal browse cards
- Proposal public detail
- Tavolo browse cards
- Tavolo public detail
- public-facing capacity inside `ProjectParticipationSection`

Likely areas to inspect:

```text
apps/mobile/lib/features/participation/domain/project_capacity.dart
apps/mobile/lib/features/participation/presentation/project_capacity_label.dart
apps/mobile/lib/features/participation/presentation/project_participation_section.dart
apps/mobile/lib/features/participation/presentation/creator_participation_screen.dart
apps/mobile/lib/features/proposals/presentation/proposal_widgets.dart
apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart
apps/mobile/lib/features/recurring_activities/presentation/recurring_activity_widgets.dart
apps/mobile/lib/features/recurring_activities/presentation/public_recurring_activities_screen.dart
```

These are areas to inspect, not mandatory modification targets.

If Next.js public discovery still does not expose these 05E1 counts, do not add a new web capacity feature solely for 05E2.

Document the rule for future web parity.

## Implementation direction

Prefer a pure shared helper, e.g. repository-consistent equivalents of:

```dart
int publicSocialProofRevealThreshold(int? registrationCapacity)

bool shouldRevealPublicProjectCounts(ProjectCapacitySnapshot capacity)
```

Keep threshold logic out of Proposal/Tavolo-specific widgets.

Use one shared presentation boundary.

Because `ProjectCapacityLabel` is shared with manager UI, add explicit presentation mode or equivalent, e.g.:

```text
ProjectCapacityPresentation.public
ProjectCapacityPresentation.managerExact
```

Do not make the pure helper depend on Riverpod/Auth if callers already know context.

## Current screen composition

Proposal/Tavolo detail currently renders an early `ProjectCapacityLabel` and later `ProjectParticipationSection`, which renders another capacity label.

Inspect this duplication.

Do not expand into a large detail-screen redesign, but avoid contradictory social-proof states for one viewer.

Acceptable approaches:

- both public copies use the same public policy
- manager participation switches to exact while the earlier label remains clearly public
- remove an obviously redundant duplicate only if it is a small safe cleanup

## Acceptance examples

### A — capacity 20, early

```text
registration capacity: 20
organizers: 1 Creator
social people: 2
non-Creator people: 1
threshold: 4
```

Public:

```text
Up to 20 participants · +1 organizer
```

No exact `2 people involved`.

### B — capacity 20, reveal reached

```text
social people: 5
non-Creator people: 4
threshold: 4
```

Reveal exact counts.

### C — capacity 10

Threshold = 3.

Creator + 2 others: hide.
Creator + 3 others: reveal.

### D — capacity 100

Threshold = 20.

Do not show `8 / 100` publicly.

### E — participant promoted to Co-organizer

If `socialPeopleCount` remains 5 before/after promotion, reveal state must not change.

### F — authority-only organizers

```text
Creator
2 authority-only Co-organizers
1 ordinary participant
```

Unique social people = 4.

At capacity 20:

```text
non-Creator people = 3
threshold = 4
```

Hide exact social count, but organizer count remains visible.

### G — tiny capacity

Capacity 1 -> threshold 1.
Capacity 2 -> threshold 2.

Creator alone does not reveal exact social proof.

Canonical `isFull` still overrides hiding.

## Localization

Add concise English/Italian strings as needed.

Good conceptual copy:

English:

- `Up to {capacity} participants`
- `{count} organizers`
- `{count} organizers included`

Italian should be natural, not mechanical.

Do not add negative wording.

Maintain ARB structural/placeholder parity.

Current main begins this task at 1,241 English / 1,241 Italian keys; report final parity/count rather than assuming it remains unchanged.

## Tests

### Pure helper/domain

Cover:

- null capacity -> 3
- capacity 1
- capacity 2
- capacity 10 -> 3
- capacity 20 -> 4
- capacity 100 -> 20
- ceil behavior
- Creator excluded
- organizers count via `socialPeopleCount`
- overlap stays unique
- full override

### Shared label/presentation

Cover:

- public low count hides participant numerator
- public low count hides social count
- organizer count remains visible
- threshold boundary reveals
- one below threshold hides
- full shows Full
- null capacity
- organizer-counting OFF wording
- organizer-counting ON wording
- `managerExact` always shows exact values below public threshold

### Proposal/Tavolo

Cover:

- Proposal card
- Proposal detail
- Tavolo card
- Tavolo detail
- public participation section

Ensure all share one policy.

### Manager regression

Verify:

- Creator Participation remains exact below threshold
- Co-creator/Co-organizer manager context remains exact where role is known
- 05E1 editor/toggle tests remain green
- join/capacity behavior unchanged

## Documentation

Update:

- participation README
- system design
- roadmap 05E / 05E2 subsection

Document:

- presentation-only rule
- formula
- Creator excluded from threshold progress
- organizers count socially
- exact canonical counts remain internal
- popularity still uses exact `socialPeopleCount`
- ranking remains deferred

Suggested identifier:

```text
05E2 — Public Social-Proof Count Reveal
```

## No database migration expected

Normally this needs **no migration**.

05E1 already provides all required aggregates.

If a genuinely missing datum is discovered, stop and report it instead of inventing persistent state.

Do not store:

- threshold
- reveal state
- public snapshots

## Validation

Run at minimum:

- focused `project_capacity` tests
- focused capacity-label/presentation tests
- Proposal public tests
- Tavolo public tests
- manager Participation regressions
- `npm run check:mobile`
- `npm run check:web`
- localization parity/tests
- `npm run format:check`
- `git diff --check`

Because no DB change is expected, a DB rewrite is unnecessary unless implementation unexpectedly touches DB contracts.

Still follow ordinary repository PR validation.

Build Android debug APK if part of the normal mobile workflow.

Allow normal hosted Validation and report per-job status.

## Non-goals

Do not implement:

- final popularity/ranking
- Popular tag
- size normalization
- Small/Large filters
- Template Workshop/Market
- combined chat/participants screen
- waitlist
- new capacity semantics
- organizer-capacity toggle changes
- new database count storage
- unrelated notification/snackbar polish

## Acceptance criteria

- [ ] exact base `11155618e0aa7bf0de62ae178f79d4c0c50ac644`
- [ ] branch starts from `main`
- [ ] draft PR targets `main`
- [ ] one shared deterministic reveal helper
- [ ] threshold = 20% with min 3 and capacity cap
- [ ] Creator excluded from threshold progress
- [ ] Co-creators/Co-organizers count socially
- [ ] role changes preserving `socialPeopleCount` preserve reveal state
- [ ] low public counts hidden
- [ ] no negative low-count copy
- [ ] organizer count remains public
- [ ] exact social count revealed at threshold
- [ ] Full always visible
- [ ] managers retain exact counts
- [ ] canonical `socialPeopleCount` unchanged
- [ ] popularity input remains exact social count
- [ ] Proposal/Tavolo/shared participation use one policy
- [ ] no contradictory manager presentation
- [ ] no migration/persisted reveal state
- [ ] English/Italian parity passes
- [ ] 05E1 regressions pass
- [ ] PR remains unmerged

## Completion report

Return:

1. branch/base/head
2. draft PR link and target
3. exact threshold helper/formula
4. pre-threshold presentation
5. post-threshold presentation
6. organizer behavior
7. Full override
8. null-capacity behavior
9. manager/private exact behavior
10. how duplicated/shared detail capacity presentation was handled
11. key files
12. localization final counts/parity
13. focused tests
14. `check:mobile` test count/result
15. web/site/database validation actually run
16. APK result if built
17. hosted CI result
18. blockers before future popularity/ranking or combined people/chat work

Do not merge the 05E2 PR.
