# PLANETS SCHED01 — Compact calendar and independently selectable date/time

**Implementation prompt for Codex.** Start from latest `main` of `lillo24/planets.community`; read `AGENTS.md`, `implementation_plan_sections_suggestions.md` and current Project, CHECK01 and time/date documentation. This is a **cross-layer change**, separate from profile media and participation-count presentation. Open one focused PR; do not merge or deploy production automatically.

## Product outcome

Project details should show a visually compact schedule. A same-day event may read **`24 ott · 14:00–18:00`**; a multi-day event should show **`24 ott → 26 ott`**, with times beneath/alongside the corresponding days when known. Prefer one horizontal row on ordinary phone widths, but wrap/stack gracefully for narrow screens, localization and large accessibility text. Dates and arrow communicate order: do not show visually redundant `Inizio` and `Fine` labels (keep explicit start/end semantics for screen readers). Remove the raw `Europe/Rome` line from standard public calendar display; preserve timezone correctness and show a user-friendly zone cue only when relevant for a different locale/timezone or DST ambiguity.

**Separate selecting a calendar date from selecting a clock time** in one-time Project creation/editing. A user may select a known single day or a start/end **date range**, leave the time explicitly **`Orario da definire`** / **`Time to be confirmed`**, and **publish that Project**; selecting a date must not immediately force a time-picker dialog. Users can later specify or change a complete start/end time and the display updates. Do not create fictitious `00:00` start times, placeholder UTC instants or a hidden default duration for a published date-only schedule.

A Project with known dates but unknown times is not necessarily an unformed Idea. Support a published Project with this clear public date-only state without silently relabeling it an Idea; preserve the separate Idea vs Defined / publication concepts and their authorization, or stop with the precise conflict if that is impossible without founder input. Treat the whole event time as unknown until both start/end clock values form a valid exact interval; avoid publishing a misleading half-known range. Existing exact-timed Projects retain their precise canonical times and history.

## Repository facts to inspect

- `apps/mobile/lib/core/widgets/event_schedule.dart`: shared `EventSchedule` vertically lists multi-day start/end labels and prints raw timezone. Proposal and Tavolo detail reuse it.
- `apps/mobile/lib/features/proposals/presentation/proposal_editor_screen.dart`: `_pickDateTime` immediately calls `showTimePicker` after `showDatePicker`, while start/end date controls already use `ProposalControlPair`.
- `apps/mobile/lib/features/project_organization/presentation/project_organization_sheet.dart`: private schedule editor likewise requires date and time. CHECK01 `docs/development/check01-project-organization.md` requires finite ordered official timestamps and separates unconfirmed private planning from public official logistics.
- `apps/mobile/lib/features/proposals/domain/proposal_models.dart`, associated gateway and Supabase mutations represent exact start/end instants or absence. Published Defined Projects currently depend on exact schedule for promotion/status; Tavoli have a separate recurring date/time model.
- Status/expiration, feed ordering, public sanitized projections, templates, join availability, map discovery, notifications, web/share readers, reporting and old-client compatibility may depend on these timestamps. Audit before choosing a representation.

## Required work and guardrails

1. Implement the horizontal, responsive and localized read-only calendar component for exact schedules in Project detail (and compatible Tavoli displays) without changing the canonical meaning of timestamps. Test same day, multi-day, cross-midnight, DST offset change, guest view, foreign timezones and text scaling.
2. Create a date-first editor affordance with an independent, optional time step: choose/change/clear known day(s), then optionally enter/edit both clock endpoints. Show an explicit unset-time choice. Do not accidentally erase a selected date when a user cancels the time picker. Apply consistently to the normal Project editor and the relevant Project Organization scheduling flow, respecting the latter's current proposed-vs-confirmed boundary.
3. Add the smallest **explicit** date-only schedule representation and public read path necessary for a published one-time Project, with additive schema/RPC/mobile/web changes if required. Keep old exact records unchanged; represent date-only information as actual local dates with timezone context, **not** made-up timestamps. Maintain a strict distinction between private unconfirmed planning and information explicitly chosen for public display; do not leak CHECK01 private proposals.
4. Define/test safe validation and lifecycle behavior for a date-only published Project: date ordering, a future date at publication, safe updates when the day passes without an exact time, no automatic claims that the activity is Happening/Completed at an invented hour, no fake countdown/deadline/reminder, and correct join/discovery behavior. Later confirmation of both clock values must produce a valid timezone-aware instant range without shifting the selected local day. If these status/automation rules require a substantial new product decision not already resolved here, implement the independent calendar UI and return a specific blocker instead of fabricating semantics.
5. Preserve all existing official schedule permissions, private organization confirmation, old clients, draft and published-idea behavior, and Tavoli recurrence. Do not turn every private suggestion into a public date. Use an additive reviewed migration only if needed, with locally replayable SQL/RLS/REST verification and rollout ordering documented.

## Acceptance and tests

- Public same-day/multi-day displays are compact, correctly ordered and do not print raw `Europe/Rome` in ordinary cases; screen readers still identify both endpoints.
- A user can choose `24 ottobre` and publish a Project with **time unspecified**, and viewers see the real date plus `Orario da definire`, never a fabricated clock. Later choosing 14:00–18:00 produces the correct explicit range.
- No regression for confirmed exact-time Projects, Ideas, Organization proposal/confirmation, Tavoli recurrence, public site, messages/joins, feed/map ordering and existing old-client API contracts.
- Test DST gaps/folds, midnight crossing, null/unknown date, same-day, multi-day, timezone changes and updates around passing dates. Include Flutter widgets, domain/gateway, relevant backend migration/SQL/REST and web builds as impacted; report all commands/results, limits and rollout requirements.
- Update the closest schedule model/documentation and IT/EN localization. PR remains open for review. Stop if a genuine unresolved lifecycle/security decision would otherwise be hidden by a fake timestamp.

**External context:** No external account, screenshot, document or credential is required. This prompt carries the user's accepted UX; `Planets Community Design` is optional background, never assumed accessible to Codex.
