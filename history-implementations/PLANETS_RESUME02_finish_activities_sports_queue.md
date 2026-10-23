# PLANETS RESUME02 — finish the complete Activities & Sports queue

**User instruction for the existing Activities/Sports Codex chat. Execute all ten implementation steps; do not return another plan or stop after step 002.**

Complete the already approved programme in `history-implementations/PLANETS_ACTIVITIES_SPORTS_2026-10-23/`, from `002` through `011`. Preserve the original product/source/privacy requirements. This instruction changes the execution and approval workflow so dependent coding can continue before intermediate PR merges.

## Explicit authority and workflow override

By sending this prompt, I explicitly authorize:

- One **cumulative integration branch/worktree and PR** for this programme, preferably the existing #298 branch. Keep logical commits and per-step evidence, but do not require a separate merged PR before beginning the next dependent step.
- Using completed, locally validated predecessor code on that same branch as the dependency base. This supersedes `001_context.md`, per-step prompts and generic repository rules requiring each predecessor to be merged first or every plan to use a different worktree, for this queue only.
- Fixing routine failures, reconciling latest main, updating generated types and scoped documentation, pushing the cumulative work, and merging when the final protected checks pass.
- Reviewing the final changed migrations on my behalf and, through my **existing authenticated repository-owner GitHub account**, posting the exact `STAGING-AUTO01-REVIEW` approval required for that reviewed head/inventory. This supersedes instructions requiring me to post that comment personally or prohibiting an agent from posting it on my behalf for this scoped queue.

Preserve the review gate and all owner-identity, hash/predecessor, semantic rehearsal, data-preservation, branch-protection and required-CI controls. Review actual SQL/evidence before approving; never fabricate personal human review, impersonate the owner or weaken security checks. A new head requires fresh proof. Post approval only through an authenticated owner identity, not a different account or copied credential.

The operational dependency is **implemented and validated**, not **already merged**. Keep the cumulative PR reviewable, and perform the consolidated exact-content SQL review after completing all ready implementation. Do not spend the run waiting for intermediate approvals.

## Starting evidence — verify current state

- Repository: `lillo24/planets.community`.
- PR #298, branch `codex/actcat02-catalogue-kinds`, last inspected head `4790cf59d85534dd3d75174657527670677fbce1`, contains step 002 ACTCAT02.
- Steps 003–011 were not started in the last saved `docs/development/activities-sports-progress.md`; they were waiting for merged predecessors.
- #298's exact approval was already posted for that old head, and Validation `39874390393` was rerun. Change classification, populated migration semantics, Database and Web passed. **Mobile failed three navigation tests** in `apps/mobile/test/app/router/navigation_shell_test.dart`: the two "ACTSPLIT01 public layouts and retained Browse" variants and "ACTSPLIT01 native failures cannot become example results". They expected `External calendars · Trento` and found no matching widget. Inspect actual logs/source and diagnose the cause; do not assume whether the UI or assertion is wrong.
- No real source records were imported by step 002; no hosted source or schedule was enabled.
- Existing ACTAPI01 catalogue/import infrastructure and ACTMET01 card-open/share hooks are already present; extend them rather than rebuilding them.

Fetch latest main and inspect the current PR/head/worktree first. Read `AGENTS.md`, applicable nested instructions, `001_context.md`, every numbered plan, feature contracts and progress. Main may include new planning documents or newly merged implementation; distinguish those. Preserve Find People #297, PEOPLEHOME and MAPMOCK work and do not take over their unmerged branches.

## Execute to completion

### Repair 002, then keep going

Reproduce the three mobile failures under the repository's actual Flutter/test configuration, repair their cause and verify the affected navigation suite. Retain failure/empty/example boundaries and existing native routes. An intentionally generalized catalogue label may justify updating an obsolete expectation, but demonstrate that from current requirements and rendered behavior; do not disable tests or mechanically replace assertions to hide a regression.

Keep the already published canonical SQL history unchanged; add forward migrations if further fixes require SQL. Avoid redoing proven work solely because the original agent stopped.

### Implement the remaining numbered plans on the cumulative branch

Use their detailed requirements as the specification:

| Step | Required deliverable |
| --- | --- |
| 003 ACTUI02 | Complete Activities hub/list/detail UI, category/navigation/state handling and preserved native Tavoli entry. |
| 004 SPORTUI01 | Sports discovery/details with distinct courses/sessions, events and places to practise; useful source-backed filters and honest unknowns. |
| 005 ACTSRC02 | Shared multi-source ingestion/catalogue infrastructure, independent enable/rights gates, stable source identities, health and failure isolation. |
| 006 SPORTDATA01 | Verify and integrate the approved official Trento open sports-facilities export, then exercise repeat imports locally. |
| 007 ACTGEO01 | Canonical geographic search/filter/paging contracts using published geometry, with stable identity and privacy boundaries. |
| 008 ACTMAP01 | List/map views of the same filtered external catalogue, selection/detail navigation and existing provider/cache/budget behavior. |
| 009 SPORTAPI02 | Verify the proposed second official source and implement a useful permitted sports connector if evidence supports it. Finish generic capability and document exact source limitations when it does not. |
| 010 ACTOPS01 | Refresh/job operations, source health/freshness/failure recovery, disabled-until-configured scheduling and activation/runbook preparation. |
| 011 ACTQA01 | Combined regression, rendered/UI, backend/import/geographic/map verification, builds and final evidence/runbook. |

Complete each step's contract, meaningful checks and checkpoint, then immediately take the next ready step. A single source-specific blocker must not stop unrelated UI, schema, geographic, map, operations or QA work. Do not label a blocked/unimplemented connector complete, substitute fake live data or omit the rest of a step because one provider is unavailable.

Substantial code is required. Do not interpret building fixtures, documenting a blocked source, creating more prompts, opening a PR or writing a resume instruction as completing the programme.

## Official source scope and evidence

External network access is needed for source verification; no private Google Doc, RadarTN export, thesis crawler or uploaded volunteer-law PDF is required.

- **Approved first source:** Comune di Trento, "Impianti sportivi ad accesso libero":
  <https://www.comune.trento.it/Amministrazione/Documenti-e-dati/Dataset/Impianti-sportivi-ad-accesso-libero>
  and its official export <https://www.comune.trento.it/customexport/dataset-csv_resource-46671>.
  Planning observed an explicit CC BY 4.0 label, 116 entries across 60 named locations, with coordinates. Reconfirm actual terms/bytes; do not force those historical counts. This particular official structured export is allowed although it is CSV rather than JSON. It represents sports equipment/facilities, not courses, bookings or guaranteed-open venues. Missing description, official item link or hours must remain honest.
- **Second-source candidate:** Open Data Hub Content API. Verify current authoritative documentation, source/record/resource licensing, supported filters and actual Trento-area sports relevance. A previous broad POI query returned transport stops; broad API availability is not useful sports coverage. Do not fill Sports with unrelated tourism/transport records or silently change geography.
- **Agenda Trento:** preserve its recorded unresolved rights checkpoint. Do not copy descriptions, switch to scraping, repeatedly investigate the same placeholder terms or demand new written permission for a different dataset whose applicable licence is explicit.
- No scraping, Instagram automation, AI extraction, crawler reuse, paid subscriptions, sports-score/betting APIs, unlicensed images or public submissions in this queue.

Build source-independent functionality with deterministic synthetic inputs when needed. Exercise the permitted first source end to end on an owned disposable local backend when accessible. Verify repeat/update identities, disappearance/failure handling, attribution, source disable and anonymous read behavior. Keep tests offline from providers.

## Preserve the product and security boundaries

- Extend the canonical Flutter/Supabase/Node implementation; no parallel Sports database or new ingestion platform.
- Events, finite-term courses and undated places have distinct meaning. Keep unknown times/availability/prices unknown, one offering per course, correct season/DST/exceptions, and compatibility for released event readers.
- Public list/detail/map reads only expose licensed fields from enabled permitted sources. External public geometry never comes from protected native coordinates, city-label guesses or device GPS.
- List and map use the same query/filter contract. Reuse existing renderer/gateways, public basemap sharing, attribution, caches and budgets. No paid quota increase, public tile/geocoder fallback or new location permission.
- Native Projects, Tavoli, Resources, group/private chats, deep links and authorization remain functional. Imported activities do not create artificial organizers, memberships, bookings or native chats.
- Preserve denied analytics gates and existing instrumentation; no crowding/attendance prediction or popularity score.
- Real catalogue, explicitly labelled examples, unconfigured, empty, partial, error and stale states remain distinct. No fake fallback results, production demo seeds or false source availability.
- Use additive migrations, stable identities, strict validation, safe URLs/plain text and the existing private write/RLS/grant boundaries. Preserve installed-client contracts and original migration bytes.

## Validation, consolidated approval and merge

Run focused meaningful checks after each logical implementation stage, then the complete required set for all changed areas at the integration checkpoint. UI work needs actual rendered inspection in IT/EN, 320/360 dp, large text and relevant themes; SQL needs real disposable database/HTTP evidence; imports/maps need actual contract/update/privacy/failure checks. Run the appropriate Android build and generated-type checks. Missing physical Android/iOS access must be reported accurately, but must not halt independent coding.

At completion, reconcile latest main, resolve conflicts, run required checks, regenerate the final migration review request, inspect all SQL/security/preservation evidence, and post the exact approval on my behalf through the existing owner account. Run/monitor the PR's required Validation, fix failures and refresh exact approval after changed heads. Merge only when genuinely green and current. Use #298 as the cumulative main-targeted PR if still appropriate, with title/description rewritten around the final implemented scope. Avoid premature intermediate merges or duplicate feature PRs.

If the other integration merges while you work, include only its **merged** main changes, reconcile shared mobile/generated-type/workflow areas and rerun affected checks. Never borrow another runner's unmerged code or erase it.

No manual hosted migration/import/source or scheduler enablement, production deployment, store upload, billing or destructive shared operation is newly authorized. Existing authorized staging automation keeps its rules. Prepare precise activation commands and configuration; keep new hosted sources/jobs OFF. Phone commands target `48091FDAS0041A`.

## Continue rather than repeatedly handing back control

Make reasonable implementation decisions and fix test/tooling/merge failures yourself. Keep concise progress updates and a durable per-step status while continuing the task. Do not end the turn after a step, commit, successful local check, review-required CI result or triggered rerun when more authorized work is possible.

If an actual permission/authentication restriction, consequential unresolved decision, unavailable platform or explicit automatic-approval rejection cannot be resolved within scope, complete every independent task and report one precise final blocker with the prepared reviewable result. Do not weaken the gate or pretend the source/merge/deployment occurred.

Final response: all ten step statuses; exact cumulative PR/head/merge; actual useful real-source counts versus synthetic data; completed UI/import/map behavior; current checks/builds and evidence; hosted source/scheduler state; device QA; exact remaining activation actions. Do not claim "all done" while ready dependent implementation remains unattempted.
