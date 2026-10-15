# PLANETS UIPOLISH01 — Single-row card skills and structured schedules

**ID:** UIPOLISH01
**Status:** Implementation prompt; not implemented by adding this file.
**Order:** Implement first, then UIPOLISH02, then UIPOLISH03, in separate implementation PRs. Reinspect latest main before each task.

## Goal

Finish the founder's original two requests: compact skill labels on cards, and a proper visual Schedule section instead of a stack of `Starts: ...` / `Ends: ...` strings. Keep data, permissions, navigation and lifecycle unchanged.

## Repository evidence

Inspected main at `9960df6dbef14bb0aace017c9ea033289b89e414` on 2026-10-15. Rebase this evidence onto latest main; do not pin implementation to this old snapshot.

- `apps/mobile/lib/features/proposals/presentation/proposal_widgets.dart`: `ProposalCard` displays `proposalSkillsTitle` and `ProposalSkillRequirements`; the latter wraps every skill with Required/Useful prefixes. It is also used by details, where complete information must remain available.
- `apps/mobile/lib/features/template_workshop/presentation/template_workshop_screens.dart`: catalog cards call `_TemplateSkills`, which wraps every label with an importance suffix. Its detail caller must not inherit card truncation.
- `apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart`: details display separate start/end/timezone strings, or `proposalScheduleText` for an Idea.
- `apps/mobile/lib/features/proposals/domain/proposal_time.dart` delegates to `apps/mobile/lib/core/time/event_time.dart`. These already convert instants into the event's timezone.
- Recurring schedule presentation lives in `features/recurring_activities/presentation/recurring_activity_widgets.dart` and `public_recurring_activities_screen.dart`; do not change recurrence rules.

## 1. Card skill preview

Apply consistently to ordinary Project cards and Template Workshop catalog cards, including their existing shared/reused appearances.

- Remove the visible `Skills we need from people` heading from cards only.
- Display plain skill names: for example `[Woodworking] [Gardening] [...]`. No Required/Useful prefix or suffix on a card.
- Use exactly one visual row. Fit up to three labels, fewer where needed; do not assume a fixed count fits. Show a final `...` label only if additional skills are hidden. Reserve room for it before committing visible labels.
- No horizontal scroller, second row, text-size reduction, clipped chips or height jump after an initial multirow paint. At large text sizes fewer labels are acceptable. For a single overlong label, constrain it safely and keep its full name accessible; do not invent a second skill.
- Preserve existing stable order and skill IDs. Do not filter out useful skills or mutate importance. Empty skills render no heading/empty container.
- Reuse one compact presentation component where appropriate. The containing card still opens its existing detail. The ellipsis is not a dead button: either inert under the card action, or invokes the same detail action. Provide localized semantics for hidden skills and retain access to the full names/list in details.
- Keep complete skill information in details, selection and management. Avoid changing the default behavior of a shared widget and accidentally truncating those callers.

Skill translation is owned by UIPOLISH02. Leave a clean label input/resolver seam; do not hard-code English names into the compact component.

## 2. Schedule presentation

Replace the Project detail's raw text block with a restrained, theme-aware schedule surface using an existing calendar/clock icon, spacing and typographic hierarchy.

- Same local day: readable localized date including year, then a prominent time range; timezone remains available as secondary text.
- Across local dates: clearly paired Start and End date/time rows or endpoints. Use a vertical layout on narrow screens; never compress a multiday event into an ambiguous single-day time range.
- Undecided/missing canonical dates: show the existing honest undecided state, with a neutral calendar icon. Do not read or display tentative/private logistics to fill gaps. Confirmed Idea dates may use the same date presentation, but the Idea must not be relabelled operational or published differently.
- Use the saved event timezone, existing conversion helpers and locale-aware formatting. Compare dates in the event timezone, not the phone timezone. Preserve years, midnight crossings and daylight-saving behavior; no UTC/device-local substitution or rounded times.
- Keep the card/list schedule summary compact. Do not place a full detail panel on every card. Avoid duplicate full date strings for same-day summaries where a shared formatter can safely improve them.
- Use the same visual language for a Tavolo's schedule and existing occurrence rows only where straightforward. Preserve recurrence description, duration, timezone, paused/ended state and every distinct occurrence. Do not rebuild occurrence generation or add a calendar service.
- Keep styling within the existing theme, bundled icons and tokens. No new image assets, dependencies, provider calls, large animations or clickable controls that have no action.

## Validation

Add/update focused widget tests with real finite constraints, not only final text assertions:

- 0, 1, 2, 3 and many skills; long labels; different priorities; ellipsis only on overflow; no priority words in card preview; complete detail list unchanged; card tap/semantics intact.
- Project and template cards at 320/360/412 logical pixels, both themes, EN/IT, normal and 2x text. Verify one row and no overflow without reducing accessible font size.
- Same-day, multiday, month/year boundary, event timezone different from device timezone, a daylight-saving boundary and undecided schedules. Preserve recurrence and Idea visibility cases.
- Search existing tests for `ProposalSkillRequirements`, card keys, `proposalScheduleText`, `template-card-`, and tutorial detail fixtures before updating expectations. Change only assertions superseded by the requested UI.

Run the repo's affected Flutter checks and `npm run check:mobile` when supported. Capture before/after on a task-owned emulator and inspect the renders; screenshots of static final states alone do not prove interaction/overflow correctness. Report exact commands, results and unrun native checks.

## Boundaries and delivery

No database, migration, authentication, sorting/filter semantics, request lifecycle, backend reads or app-store deployment changes. Do not reset shared data or overwrite the founder's installed Play app. Optional authorized physical-device commands must select `48091FDAS0041A` explicitly.

No external input is required: requirements are complete here. Screenshots from the conversation are optional visual references, not a hidden dependency, and must not be published with personal data. Follow AGENTS.md, create an isolated implementation branch and PR, and merge only through the repository's checks/workflow. State code/merge/native QA/release status separately. Update the nearest behavior documentation and report the PR and tested commit.
