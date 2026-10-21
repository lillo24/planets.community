# PLANETS DRAFTFIX01 — Verify and resolve the Drafts loading failure

**ID:** DRAFTFIX01  
**Status:** Pending investigation/implementation; this document is not evidence that the reported phone failure is fixed.  
**Repository:** `lillo24/planets.community`  
**Starting point inspected:** `main` at `f244c431d1ecfb21a6eb78073d8ef5d36a792218` (2026-10-21). Start execution from latest main, not an old UI-polish branch.

## Goal

Determine whether the previously reported Projects-only Drafts loading error is already resolved by a later owner-list adapter fix. If it persists, reproduce and fix its actual cause without losing drafts, weakening authorization, or converting failure into an empty/success state. A verification-and-regression-only outcome is valid if the relevant fix is already merged.

The founder's screenshot showed `Le mie bozze`, the `Progetti` filter selected, and:

> Impossibile aggiornare le bozze di Progetti. Riprova per ottenere l'elenco completo.

Other draft kinds were not demonstrated failing. Do not assume all draft loaders fail or that the screenshot proves drafts were lost.

## Current evidence and important newer change

UIPOLISH01/#262, UIPOLISH02/#264 and UIPOLISH03/#268 are merged. Their scope excluded this loading failure. Preserve their UI, localization and template recovery changes.

Verified source paths:

- `apps/mobile/lib/features/drafts/presentation/drafts_screen.dart`: starts the three owner reads, renders source-specific errors, supports contextual type filters and retry, and refreshes the edited source on return.
- `apps/mobile/lib/features/drafts/application/own_drafts.dart`: projects the current actor's owner collections into unpublished Project/Tavolo/Donate/Exchange cards, sorted by update time; it does not query a separate drafts service.
- `apps/mobile/lib/features/proposals/data/proposal_gateway.dart`: `listOwnProposals` calls `readOwnerCollection` for `list_own_proposals_v2`, then loads structural capacity information and parses the owner records. A successful owner RPC alone does not prove the entire load succeeded.
- `apps/mobile/lib/core/backend/owner_collection.dart`: latest inspected main explicitly calls `.order(idColumn, ascending: true)` with a `gt` continuation and rejects non-advancing IDs. At the UIPOLISH03 merge `5c3d50b48c16b0f6fc4879b11c8621a8086f78e8`, this call was `.order(idColumn)` without explicit direction. The newer code comments identify the resolved client's descending default as the issue.
- `apps/mobile/test/core/backend/owner_collection_test.dart`: already tests the real Supabase/PostgREST request adapter using mocked HTTP, including the explicit ascending query; separate collector tests cover more than 1,000 records and failed/non-advancing later pages. These are not live hosted-database tests.
- `features/recurring_activities/data/recurring_activity_gateway.dart` and `features/resource_listings/data/resource_listing_gateway.dart` reuse the same owner-collection helper.
- Read `features/drafts/README.md`, the owner controllers/parsers, current migrations and the most recent implementation records as needed.

The old transport ordering conflicts with the collector's increasing-ID invariant and can explain an owner load failing when more than one record is returned. This is a strong candidate, not a confirmed diagnosis of the founder's installed build. Check the installed build/source and actual failing stage before claiming that user's failure is resolved. Do not reimplement an ascending-order change already present.

## Investigation, then the smallest necessary change

1. Record the starting SHA and locate existing Drafts/gateway/controller tests. Inspect repository instructions and current dependency lockfiles. Establish the source of each displayed error, not only the screen that displays it.
2. Use synthetic data to reproduce the earlier adapter failure and verify current behavior through the actual gateway path. Include at least two owner records in reverse UUID order and mixed draft/published records; a one-record fixture can miss this defect. Avoid reverting working main code or running old code against shared data.
3. Test the Drafts screen with the current owner adapter and expected capacity responses, not only a fake gateway returning ready-made models. Distinguish owner RPC transport errors, paging/order failures, malformed/null owner fields, capacity lookup failures and actor/readiness changes.
4. If current main passes, document the existing fixing change and add only meaningful missing regressions or evidence. Do not manufacture a new app change to satisfy the task name. Report separately whether the original installed build was checked.
5. If it still fails, capture safe diagnostic context, establish a failing regression, and fix the narrow responsible layer. Do not use blanket catch-and-return-empty, ignore broken rows, strip the completeness guard, remove capacity checks, or broaden private reads. Diagnose deployment/schema mismatch rather than automatically falling back to obsolete RPCs.

Any diagnostic additions must be bounded and non-sensitive: operation/stage, source kind and safe error category/code. No tokens, full responses, personal draft text, identities, private URLs or raw SQL errors in public UI/logs. Reuse existing logging conventions; no new telemetry service.

## Behavior to preserve

- Show only the ready current actor's unpublished owned records. Published history and delegated management remain separate. No previous-account cards or late completions after logout/account replacement.
- Selected types retain their existing OR semantics; no selection means all four. Keep source-specific loading/failure and retry. Success in one source must not falsely certify another failed source, or erase its error.
- Exhaust bounded owner pages without skips, duplicates or looping; preserve final presentation ordering. Honor capacity batch limits and distinguish empty authorized results from malformed/incomplete responses.
- Reopening, editing, saving and returning from a draft preserve filters/scroll and refresh the appropriate source. A template-created draft remains the same backend record; do not create another one to repair discovery.
- Keep template receipt recovery, frozen request IDs and actor-bound acknowledgements from UIPOLISH02. Do not confuse a creation receipt with successful Drafts-list loading.
- Do not delete, recreate, publish or modify the founder's saved drafts during investigation.

## Validation

Use the existing harnesses and add missing cases, without duplicating already comprehensive tests:

- Empty, one and multiple owner records; multiple pages and an API-cap boundary; explicit ascending transport plus correct continuation; later-page failure/non-advancing IDs remain failures.
- Projects-only Drafts, all types, mixed sources with one failing, retry success, mixed draft/published/Idea records and valid incomplete drafts.
- Relevant owner parser/capacity edge cases, including missing or malformed required fields. Do not invent defaults that change meaning.
- Account/readiness replacement during loading, stale replies and editor return; template application -> same draft visible in Drafts -> reopen/edit -> return without duplication.
- Run affected Flutter tests, formatting/analysis and `npm run check:mobile` or the current repository equivalent. Use a disposable local backend for any needed real RPC/schema checks. If database code genuinely changes, add a forward migration and run the relevant database/authorization/upgrade checks; do not rewrite applied history.

For native validation, use synthetic identities and a task-owned environment. Record exact build/source, backend and test route. Do not reset shared Supabase data, alter provider settings or overwrite the founder's installed app.

## Carried-forward UI validation and cleanup

UIPOLISH03 reported 3,507 passing mobile tests, two skips, 148 targeted tests and 28 native captures. Native 2x text with the software keyboard and native landscape still lacked validation; widget constraints are not a substitute.

If a stable task-owned emulator or already-approved native runner is available, perform a bounded follow-up of the touched chat/workshop/group/detail layouts at 2x text with keyboard open and in landscape. Inspect scrolling, reachable actions and composer visibility. Keep this as verification, not another broad UI redesign. Record the exact scenarios that passed; report unavailable/crashing configurations explicitly. Do not repeatedly repair a failing Windows AVD or touch peer processes. A newly discovered consequential layout defect warrants a separately scoped fix rather than being hidden by this Drafts task.

The automatic approval review blocked deletion of UIPOLISH02's leftover build cache and temporary baseline folder. Leave these blocked targets untouched. Do not retry the same deletion via another tool, renamed path, elevated permissions or alternate launcher. They are housekeeping, not proof of a source/build defect. Do not overwrite them with new work; report retained paths if known, without claiming cleanup succeeded.

## External context and access

No external design document or original screenshot is needed: the observed error and relevant requirements are recorded here. Repository/local synthetic testing can proceed without the founder's phone.

Confirmation of the original installed-build failure requires its build/version/backend context and authorized device access or sanitized diagnostics. Optional physical-device commands must explicitly select `48091FDAS0041A`; no uninstall, clear-data, sign-out, account writes or replacement of the Play installation without explicit approval. If that context is unavailable and is needed to distinguish remaining causes, stop that verification portion and report exactly what is missing. Do not request raw credentials or pretend local success proves the original environment is fixed.

## Scope, stop conditions and delivery

One focused investigation/fix PR, following AGENTS.md. Direct main commits are authorized for this handoff document only, not implementation code. No deployment, store upload, hosted migration execution, production data repair, broad UI rewrite, new draft storage or permissions changes.

If a repair requires changing who owns or may read drafts, destructive data operations, an incompatible contract or other product decisions, stop and present the evidence/options before proceeding. Treat unavailable native access as an explicit validation limit, not a reason to invent a fix.

Return: verified cause (or remaining hypotheses), whether newer main already fixed it, relevant source/build SHAs, minimal changed areas, exact regression/check results, original-device verification status, carried-forward native matrix status, retained blocked cleanup targets, PR/merge status and any separate deployment requirement. Do not claim the user's installed app is updated merely because main passes.
