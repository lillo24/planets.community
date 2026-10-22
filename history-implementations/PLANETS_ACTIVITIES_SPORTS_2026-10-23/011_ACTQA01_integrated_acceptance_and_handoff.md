# ACTQA01 — finish, inspect and hand over the Activities/Sports programme

Read [001_context.md](001_context.md) and the current queue progress before starting. This step validates/fixes the **actually merged portions** of 002–010. Do not claim blocked source integrations passed; do not stop integrated UI/map verification solely because a source or phone is unavailable.

## Outcome

Deliver an integrated, inspectable Activities/Sports experience with working catalogue kinds, source infrastructure, public geographic search and List/Map navigation. Fix regressions discovered by the end-to-end journey. Produce one concise evidence-backed handoff that tells the founder what works, what real data was tested and what owner setup remains.

This is an acceptance and repair step, not permission to redesign the app, add new products, weaken failed tests or deploy production. If previous required core steps did not merge, record that scope as incomplete and validate the independent completed path honestly.

## Integrated local journey

Use the repository's supported disposable local backend and current mobile configuration. Protect existing user stacks/worktrees and avoid shared resets. Establish an explicit fixture realm; do not seed fake data into the real public catalogue.

1. Start mode OFF. Verify baseline Home/Browse, native Projects/Tavoli/Resources, Messages and tutorial behavior are intact. Turn Activities Split Mode ON through actual Settings; verify persistence according to existing preference rules.
2. Open Activities and All/Sports/Culture. Verify native Tavoli entry/creation/participation/chat/map remain their real native flow. External search and counts must not imply they searched native Tavoli.
3. Exercise event, course/recurring offering and place contracts, including no-description/no-next-session/locality-only/no-geometry/source-disabled/expired cases using clearly identified synthetic source fixtures. Check course term/weekly schedule/date-only semantics across Rome DST and expired-season exclusion.
4. If 006 is live-verified, run a bounded real municipal export import into the disposable catalogue with documented local rights configuration. Record actual fetched/accepted/rejected counts and source scope; render at least one actual place/card/detail and any dataset-level-link fallback. Repeat the import and show stable canonical UUIDs/no duplicates/revision behavior. Never require the old 116-row count.
5. If 009 provides a verified useful second source, show that its source identities/licences/types remain distinct. Simulate one-source failure/disable and show healthy other-source results, with truthful partial health. If 009 is blocked/no eligible coverage, record that and use synthetic two-source evidence for isolation only.
6. From Sports/Places apply discipline + text and, where appropriate, date filters. Page beyond the first result set. Switch List → Map without losing category/kind/query/filter state. Search a new area/radius; test two entries at one coordinate, cluster chooser, Load more and late/stale requests. Open a pin's **external** detail, return to Map, return to List and verify retained state.
7. Compare the full filtered map set to the valid geometry-bearing subset of the same filtered list. A venue/park with several equipment entries must not become a count of several distinct parks. Missing geometry never gets a fake pin. No exact native private location becomes public.
8. Exercise official information/dataset links and current copy/share actions, missing/unsafe link handling, stale/cancelled/removed detail states and source-disable refresh. No fake booking, native membership/chat, crowds/availability label or false success.
9. Background/resume, account/readiness transition and toggle OFF invalidate old work correctly. Flag-disabled map providers and denied analytics produce **zero new external provider/analytics attempts** in the controlled journey. Public backend reads remain possible under their approved contracts.

## Visual and platform evidence

Capture and inspect actual rendered Activities, Sports/Courses, Sports/Places, a place detail, course detail, map/cluster/detail-back flow, empty/unconfigured, partial/stale and unavailable states. Use the repository's current evidence conventions; label synthetic and real-source captures accurately. Cover IT/EN, light/dark, 320/360 dp and 2× text on dense cases. Fix overflow, poor touch targets, unreadable tags, filter clutter, misleading labels and needless operational prose.

Run supported Android build/smoke checks. If a physical phone is available, target **`48091FDAS0041A`** explicitly; do not guess a different device. Do not wait indefinitely for phone review or a broken emulator. State native Android/iOS limitations separately. Test screenshots are not proof of a shipped store release, hosted configuration or physical-device behavior.

Do not commit screenshots with personal/payment information, secret-bearing terminal output, raw contact-rich upstream data or giant generated build folders. Internal temporary evidence can stay local; preserve intended safe review artifacts through repository conventions.

## Required automated verification

Use checks appropriate to the actual changes/repair diff and inherited risks. At this final cross-layer checkpoint run the complete supported validation selection covering the merged catalogue/source/geography/mobile changes, including migration replay, SQL/RLS/advisors, generated-type consistency, importer/tooling tests, public/service HTTP integration, formatting/analysis, mobile/controller/router/map regression suites and Android build where supported. Run additional web/site checks when public/shared generated contracts or root/workflow dependencies affect them; do not repeatedly rerun unchanged unrelated suites after they pass.

Normal CI must remain independent of live municipal/ODH availability. Preserve all mandatory checks; a baseline failure or unavailable tool must be identified with path/command/result and cannot be silently reclassified as passed. Keep real-data source checks opt-in and bounded.

Inspect the final diff and source contracts against current `main`, not just the initial planning snapshot. Fix actual regressions in this focused acceptance PR, rebase/update from latest main and merge when required checks pass. If no repair is needed, an evidence/runbook/progress PR is sufficient; do not make cosmetic changes merely to create code churn.

## Durable handoff

Write/update `docs/development/activities-sports-progress.md` and a concise final runbook under `docs/development/` using existing documentation conventions. Include:

- Per-plan implemented/merged/partial/blocked status with PRs and actual merge SHAs.
- Current public contracts, source IDs/coverage/licence evidence, import commands, freshness and disable behavior.
- Actual local source counts/repeat evidence and whether a useful second API/course source exists. Distinguish live API success from sports/course coverage and synthetic contracts.
- Local run/build commands, evidence paths and exact checks/results. Include a short phone review checklist only; do not make its completion a hidden prerequisite for all merged work.
- A concrete ordered owner setup list, based on actual repository tooling: unapplied migrations/configuration, source registration/rights metadata, initial hosted import, public anonymous-read verification, scheduler enablement and any app build/release needs. Manual hosted activation/deployment still requires separate authorization. Do not label local imports as live user data.
- Immediate source-disable/scheduler-stop/rollback instructions, with no secrets or fictional commands.
- Known source/rights/coverage/SDK/phone/environment limits and an exact next step for each. A blocked Agenda Trento connector or course-data gap should remain explicit without hiding completed Sports-place/UI/map work.

Clean up only task-owned merged branches/worktrees under repository rules. Respect an approval/cleanup block and report the remaining path instead of working around it. Preserve any unmerged repair branch with an exact resume note.

## Final response

Give the founder a concise result table for 002–011, links to PRs and the final handoff/evidence, the most useful visible changes, and remaining owner/source/native-QA limits. Separately state **code merged / local real data verified / hosted active / scheduled / deployed**. Do not say “all done” when a stage is partial, tests failed or only fixture evidence exists. If ready work remains and execution budget is available, continue the queue instead of ending at this report.
