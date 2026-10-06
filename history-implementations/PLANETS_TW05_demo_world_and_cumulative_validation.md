# PLANETS — TW05: Realistic Workshop demo world and cumulative validation

Date: 5 October 2026  
Repository: `lillo24/planets.community`  
Task: extend the existing local demo world with realistic completed-source templates, active matching examples and the full Template Workshop/editor rehearsal.

## Outcome and authorized workflow

A developer can rebuild one local demo world, sign in as documented synthetic people, browse eight realistic completed templates, create an independent draft, see relevant upcoming Projects while editing, leave safely and return to the same draft. Reports/removal, private Bozza, copy/retry/privacy and lifecycle exclusions are reproducible. Repeat seeding preserves canonical identities and accepted history.

Implement TW05 in one isolated branch/worktree, validate, commit, push and open a **draft stacked PR**. Keep it **unmerged** for founder review of the demo/content and cumulative feature behavior, together with predecessor review. Do not deploy, seed shared databases, merge the stack or submit a store build. This explicitly overrides AGENTS.md's default-main/automatic-merge workflow.

The approved dependency base is:

- [SIM02 PR #143](https://github.com/lillo24/planets.community/pull/143);
- branch: `codex/sim02-automatic-editor-suggestions`;
- exact base/head: `08b8c4422de92d8a3f0392c920acc0766a02eaca`;
- suggested new branch: `codex/tw05-workshop-demo-and-cumulative-qa`;
- PR target: `codex/sim02-automatic-editor-suggestions`.

Verify remote head/ancestry before branching and preserve the predecessor's retained clean checkout. The inspected stack is TW01 #127 → TW02 #129 → TW03 #132 → DRAFT01 #135 → TW04 #137 → SIM01 #140 → SIM02 #143, all draft/unmerged. This prompt deliberately authorizes that stack as the dependency base; do not stop merely because the general roadmap normally waits for merged predecessors.

Main was inspected at `cbfbf0ae6de9eb73906361c5980b113ec6bc2046`, including merged PI05 #141 on top of #128/#131/#134/#138. It has newer invitation/demo tooling in the **same** demo files. Inspect those differences for ownership and later reconciliation, but do not import main's participation/auth/browser/native-link changes or the separate moderation/admin-hosting stack incidentally. Later main integration remains a separate checkpoint and must preserve both demo extensions. If predecessors have since merged, select then-current main only after verifying that all required contracts survived and record the actual base/target. Identify any incompatible predecessor revision explicitly.

Read AGENTS.md, applicable nested instructions, architecture, roadmap and current code before editing. This prompt includes the settled scope; the Google Doc/prior chat is optional background. Routine fixture, helper and reversible presentation choices within these bounds are authorized.

## Settled product rules

- **One-time Proposals only** for Workshop and similar-Project suggestions. Preserve existing Tavoli/Scambio demo scenarios without adding template semantics to them.
- A linked template identity appears automatically at first publication. Public Workshop access/application requires canonical Completed: event end + 24 elapsed hours, published/public source and no template removal.
- Completed is elapsed time, not verified success/attendance. Do not invent outcome fields, attendance, reviews or a separate “final result” editor.
- The private Bozza is the last persisted draft before first publication, original Creator only. No public toggle, baseline fabrication for legacy sources or staff exception.
- No independent template authoring/submission/approval/opt-in, Creator withdrawal/restoration or new production starter-content exception.
- Template reports, including original-Creator self-reports, lead to manual staff review. Template removal leaves its source Project, protected baseline and previously copied independent drafts intact.
- Reuse copies only canonical reusable text, controlled skills, open need text and the optional capacity recommendation. It creates fresh needs and an independent private draft; logistics, cover, people, invitations, chat/workspace/contributions and operational history are reset.
- Suggestions remain title + optional controlled skill IDs + optional rough geography. No description enrichment, AI, translation/stemming or confidence percentages. Preserve SIM01 admission/order and SIM02's five-result bound.
- Lookup does not create/save a draft. Candidate selection closes the sheet before ordinary detail navigation; DRAFT01 owns one save/recovery and truthful destination feedback.
- Ordinary profile/photo, capacity, blocking, participation and source structural locks remain canonical. No seed-only public API, production bypass or alternate Flutter data repository.

The PLANETS starter subset in this task is **explicitly synthetic local demo content**, derived from synthetic completed Proposals. It is not evidence that PLANETS organized real events or authorization to insert invented history into production.

## Verified current implementation and evidence

At the inspected SIM02 head, [Validation run 37319231494](https://github.com/lillo24/planets.community/actions/runs/37319231494) passed Change classification and Mobile; Database/Web/Site were correctly skipped for its mobile/docs-only diff. Mobile logs confirm localization, formatting, analysis and **1,274 tests**. The PR/docs report Android compilation/native smoke and local SIM01/TW02/TW03/DRAFT01 verifiers with **650 / 93 / 132 / 42** assertions. These are predecessor evidence, not TW05 checks already run; assertion totals can differ with fixture paths.

SIM02 observes raw title, selected skill IDs, valid rough geography and the controller-bound draft ID. It debounces 350 ms, isolates actor/editor generations, pauses when hidden/backgrounded/saving, supports session-local dismissal/reopening and strictly parses SIM01's 16-field preview. Modal selection awaits the route's completed future and restored editor ownership before one ordinary `/proposals/<id>` push. Preserve these seams.

The approved base already has:

- DEMO-A: opt-in Flutter presentation/prefill tooling, never automatic submission.
- DEMO-B: `scripts/lib/demo-world.mjs`, used by `demo:seed:local`, `demo:reset:local` and `demo:verify:local`.
- Three stable synthetic personas: `demo-alice@planets.invalid` (Giulia), `demo-bob@planets.invalid` (Marco), `demo-carla@planets.invalid` (Sara).
- Nine realistic Proposal/Tavolo/Scambio scenarios, canonical media, participation/request states, notifications and mural chat.
- An upcoming mural and Repair Café; **Concerto acustico nel cortile** remains **Just Finished**, ending roughly two hours ago. Add a different completed concert source instead of retiming this one.
- Strict loopback API/database/Mailpit guards, project-scoped credentials, one advisory seed lock, exact owner/title reconciliation and immutable media-version paths.
- Nine vendored licensed WebP covers and abstract profile avatars, with provenance/checksums in `scripts/demo-assets/assets.json`.
- Existing authenticated Workshop/report/application/draft/matching verifiers and two opt-in Android/backend smoke journeys.

Current main additionally has PI05's photo-free Dario/Elena, four admission-focused Proposal/Tavolo scenarios, invitation generations/receipts, retained request/leave/removal/re-entry history, a private ignored capability journal, `scripts/lib/demo-participant-invitations.mjs` and `demo:check:local`. Those contracts are not present on the selected Template base. Record later reconciliation requirements; do not overwrite, duplicate or claim to have tested PI05 from this branch.

## Inspect owners before editing

Inspect at least:

- `docs/development/demo-data.md`, `scripts/lib/demo-world.mjs` and its tests;
- `scripts/seed-local-demo-world.mjs`, `scripts/verify-local-demo-world.mjs`, package scripts, local auth/photo/status helpers and helper README;
- `scripts/demo-assets/README.md`, `assets.json` and appropriate existing covers;
- `docs/development/template-workshop.md`, `similar-active-proposals.md`, `automatic-editor-suggestions.md` and `proposal-draft-departure.md`;
- canonical Proposal/source/need/media/capacity/participation/workspace/report/application RPCs and migrations;
- TW01 Workshop/backfill, TW02 moderation, TW03 copy/upgrade, DRAFT01 creation/recovery and SIM01 matching verifiers;
- `apps/mobile/lib/features/template_workshop`, Proposal editor/suggestions, DEMO-A and current integration smoke/fixture sources;
- `docs/implementation/roadmap.md`, current path classification and `.github/workflows/validation.yml`;
- current main's PI05 demo guide/helpers/stability command and implementation record, for the later integration boundary.

Keep one demo orchestrator and target-safety boundary. A focused Workshop fixture/helper module under `scripts/lib` is reasonable; share existing auth/media/coordination instead of creating a second competing world/seeder. Avoid broad refactoring of the 2,000-line existing helper or unrelated product screens.

## Eight completed source templates

Add eight distinct completed, publicly usable **source Proposals**, in addition to the original nine scenarios. Give each human Italian title, concise summary, useful reusable instructions, selected existing controlled skills with Required/Useful importance, a sensible capacity recommendation and duration, and two or three plausible open needs where appropriate. Include at least one closed need that is deliberately omitted from reuse.

Suggested content inventory:

| Theme | Example source title | Useful reusable structure / needs |
| --- | --- | --- |
| Repair Café | Repair Café: una mattina per aggiustare piccoli oggetti | Welcome/triage, safe small repairs, closing cleanup; tools and work tables. |
| Community mural | Murale di quartiere: prepariamo e dipingiamo insieme | Agree the design, protect/prep the surface, paint in groups; drop cloths and brushes. |
| Shared flowerbed | Aiuola condivisa: piantiamo e curiamo uno spazio comune | Plan the bed, prepare soil, plant/water; hand tools and watering cans. |
| Acoustic concert | Concerto acustico di quartiere: suoniamo e prepariamo lo spazio | Short acoustic sets, simple setup, cleanup; chairs and limited audio equipment. |
| Trail cleanup | Pulizia del sentiero: raccogliamo e separiamo i rifiuti | Route briefing, safe collection/sorting, drop-off; gloves and bags. |
| Book exchange | Scambio di libri: portane uno e scopri nuove letture | Collection/display, exchange, remaining-book plan; tables and signs. |
| Community bookcase | Libreria di comunità: costruiamo un piccolo punto di scambio | Simple design, assembly/finish, safe placement; wood and hand tools. |
| Neighborhood dinner | Cena di quartiere: prepariamo e condividiamo una tavolata | Coordination, setup, shared preparation, cleanup; folding tables and serving supplies. |

Final wording/skills can follow the repository catalog. Do not add new taxonomy slugs to make a fixture match. Use safe synthetic public/meeting text and no personal phone/home addresses. Do not include real institutional permission, professional guarantees or a claimed successful outcome.

Use a small documented PLANETS demo starter subset, for example three of these sources owned by a clearly synthetic `PLANETS — demo locale` persona; the rest can use existing personas. A new complete synthetic identity/abstract photo is allowed when needed. Preserve Giulia/Marco/Sara and their existing roles/media. Never assign stock faces to synthetic people or real PLANETS staff.

The eight available templates should remain available in the baseline world. Use additional dedicated sources for cancelled/removed/version-transition cases, so a destructive rehearsal does not permanently reduce the core catalog to seven. Existing future publications also have private linked identities; “eight demo templates” describes the new core public inventory, not the total database identity count.

For each source:

1. Create/save through authenticated canonical draft APIs, with genuine draft text/skills suitable for the private baseline.
2. Set logistics, capacity, controlled skills and resource needs; reconcile an authorized cover before historical locking.
3. Publish through the ordinary actor API with its existing profile/photo gates.
4. When testing a before/after edit, make the allowed published edit while still Upcoming; retain a different original saved Bozza.
5. Age only this exact synthetic source into Completed through the established trusted local timestamp fixture mechanism.

Use comfortable time margins around start/end/+24h, Europe/Rome formatting and explicit UTC instants. Do not sleep 24 hours, add a completion flag or loosen ordinary structural locks.

## Active matching and exclusion inventory

Keep active matching fixtures separate from completed Workshop entries. Reuse the original upcoming Repair Café where its title evidence is sufficient; add a small number of focused upcoming Proposals for the missing examples.

| Case | Required observable behavior |
| --- | --- |
| Clear Repair Café, mural or flowerbed idea | Related upcoming title-topic candidate appears with and without selected tags; valid rough locality refines order. |
| Comparable available versus Full | Canonical availability is distinguishable; preserve server ordering rather than client reranking or a promised join. |
| Broader locality | Plausible same-topic candidate outside the local city can appear; its rough location is truthful. |
| Same locality + same broad skill, unrelated title | No candidate admitted by geography/skill alone. |
| Generic/weak idea or linguistic mismatch | Legitimate empty/limited result, distinct from lookup failure; no invented synonyms/translation. |
| Draft source | No template identity and no active public match. |
| Published upcoming source | Linked identity exists, no Workshop detail/application yet; may be an active match. |
| Happening / Just Finished / Completed | No similar-upcoming admission; only eligible Completed source appears in Workshop. Preserve the original Just Finished concert. |
| Cancelled formerly published source | Retained linked identity/history, absent from both public surfaces. |
| Staff-removed completed template | No catalog/detail/blueprints/new copy; source and accepted independent draft remain intact. |

Select query/candidate titles that share the server's actual retained lexical topics. For example, the existing mural title “Coloriamo insieme il muro del sottopasso” does not automatically match the different word “murale.” Use a suitable query or an additional explicit mural fixture; do not change the matcher to make demo examples pass.

Create Full through canonical capacity/organizer policy or accepted participation, not raw count/occupancy inserts. Keep a legitimate unknown-capacity case if it can be represented using the already-supported legacy fixture path; document any trusted fixture exception rather than bypassing new-publication capacity validation. Existing SIM01 tests already cover this state if no realistic baseline fixture is justified.

## Privacy, reporting, copies and version examples

Build one small, clearly documented set of additional scenarios for these seams:

- A source with a distinguishable genuine Bozza and allowed pre-start published edit. Public reusable content reflects the final canonical projection; only the original Creator can read the earlier baseline, including after template removal. Other people and staff acting as themselves remain forbidden.
- A completed source with open and closed needs, synthetic restricted meeting text, a workspace link and some ordinary participation/chat state created through canonical APIs before aging. Marker checks prove those operational fields/history do not enter template payload or copied drafts; allowed reusable free text is not automatically anonymized.
- Both an ordinary template report and original-Creator self-report, with human safe explanation and manual-review copy. Report alone does not remove anything.
- A dedicated reviewed template removed via `remove_moderation_case_template`, with a protected safe reason and stable request UUID. Use the existing report/staff read flow and reviewed token. Only a narrowly scoped local fixture role grant is allowed to provision a synthetic reviewer; no staff role for every demo person or baseline-access bypass.
- One accepted independent draft copied **before** that removal, plus the exact accepted retry afterward. Its ID/needs/content remain usable; a fresh application request afterward fails. Reports/actions/reasons retain original attribution without duplicate effects.
- A copy with capacity prefill and one opted-out case where useful. Verify reset schedule/location/timezone/cover, organizer-counting default and absence of inherited members/delegates/invitations/chat/workspace/commitments/contributions. Fresh need IDs must differ from source IDs, and closed needs stay absent.
- A draft edited/saved after copying. Its application receipt remains immutable, and reusing the accepted request must recover the same destination without resetting owner changes.

Use `create_proposal_draft_from_template` and `get_own_proposal_template_application` with stable actor-scoped request identities. Recover copies by accepted receipt/ID, not title, because the person can rename their draft. Owner-private receipts/Bozza never become public usage/count/history.

**Version-history limit:** templates project current source content; there is no public revision archive, and source structural writes are prohibited after Completed. Demonstrate the ordinary allowed edit before completion and its immutable Bozza first. To exercise a draft copied from an earlier public token versus later source projection, use a dedicated **mutating local transition check**: capture/copy version A, temporarily restore only that known synthetic source's fixture clock to Upcoming, perform a canonical authorized edit, then age it back and compare version B/independent copy. This is test clock manipulation, not an app capability or real post-event history. Do not place the core eight sources into this transition or change taxonomy globally. Existing predecessor version/locking tests may provide the mechanism.

Show stale-token refresh/reconfirmation and exact accepted retry separately: a stale first-use token fails; an already accepted exact request recovers its original draft even after source/removal changes. Never rerun application with a new UUID merely to recover an ambiguous response.

## Stable seeding, recovery and non-repairing verification

Extend the existing explicit local seed/reset/verify entry points. Keep the reset command clearly destructive to its selected disposable local database; never add app-start auto-seeding, a shared reset endpoint or remote/staging mode.

- Preserve original scenario IDs, titles, request/chat history, covers and lifecycle purposes. Seed only an exact finite inventory belonging to verified synthetic owners.
- Use stable scenario/action/request/media identities and recover committed work from canonical receipts where available. If title lookup is retained for ordinary sources, bind exact owner/known fixture titles and fail on ambiguity; no broad prefix deletion or “take first.”
- Plan interruption-safe phases for source creation, publication, needs/media, application, reports and removal. A rerun must resume missing work without a second template/baseline/draft/need/report/effective removal.
- Do not call update/publish/report/apply repeatedly merely because the command ran. Skip unchanged content/transitions, and keep accepted request payloads frozen. A different intent cannot reuse an accepted key.
- Existing completed fixtures do not need to be moved back to the future on every unchanged seed. Refresh relative time only where the existing local demonstration needs it; unchanged reusable content must keep its token. Document any clock-only snapshot exclusion explicitly.
- The verifier authenticates already-created identities and reads/asserts domain state. It never completes profiles, republishes, restores a removed template, copies drafts, sends messages or projects events to repair a failure. Local OTP/session writes are distinct from product-domain repair.
- If interactive edits/removal/cancellation break the baseline, report the exact drift. Do not silently erase owner edits, restore removed templates or hard-delete append-only receipts/history. Explain when an explicit seed can safely reconcile and when an explicit reset of this disposable stack is required.
- Use one coordinated mutation lock for seeding and transition checks. Verification must observe a documented stable world or refuse concurrent mutation; it cannot join a half-built snapshot and call it correct.
- Keep raw capabilities/tokens/OTP/database credentials out of logs, snapshots, Git and reports. Needed private local checkpoints/journals use the existing ignored/OS-temp conventions and are tied to the correct loopback target.

Add a bounded explicit mutating integration command for Workshop seed stability/transition checks, with a name consistent with existing scripts. It should seed → verify → unchanged seed → verify and compare canonical IDs/relationships, content tokens, baseline hashes, needs, copy receipts/drafts, reports/removal actions and relevant audit/outbox/notification effects. Exclude only justified authentication/time fields; do not hide duplicate product history behind an overly broad snapshot exclusion.

Include a controlled interruption after a committed copy but before seed acknowledgement, followed by failed **non-repairing** verification and seed recovery using the original key. Snapshot around failed verification to prove no product repair. Check one subsequent unchanged rerun. Existing removal/concurrency/failure-injection verifiers remain the authority for transactional rollback; do not reproduce their entire suite in the demo runner.

Keep this bounded check useful for later composition with main's PI05 `demo:check:local`, rather than introducing a second whole-world reset or competing registry. Document the integration seam and avoid duplicate CI seeding after reconciliation.

## Media and local safety

Read existing licensed activity covers from `scripts/demo-assets`, reuse suitable scenes and preserve their provenance/checksums. A missing suitable scene can use the existing honest placeholder; do not attach an unrelated image merely to fill a slot. If adding a small justified cover set, vendor it at implementation time with source/license/credit/retrieval/dimensions/size/checksum records and visual QA. Seeding/verifying after checkout must require no external network.

Use ordinary authenticated Storage + cover RPCs with immutable owned version paths and no upsert. A retry may adopt only the exact already-owned deterministic object through canonical validation. Do not insert Storage/media rows, copy source cover ownership into derived drafts or bypass start-time locks.

Use a unique local Supabase project ID and free ports in the task checkout, preserving exact original configuration bytes outside Git. Guard loopback API, database and Mailpit before reads/mutations; no fallback to a developer's shared URL. Refuse unknown targets before invoking reset. Role grants/time adjustments/direct inspection are exact local synthetic fixture exceptions, not new product authorization.

Stop the isolated stack before restoring configuration. Remove only task-owned temporary credentials/checkpoints/QA app/reverse rules/caches, preserving unrelated emulator/Gradle processes, other worktrees and journals. Keep the clean checkout retained for founder review.

## Cumulative validation and real mobile rehearsal

This is the track's cumulative checkpoint: broad local checks and one final all-area hosted Validation are explicitly in scope. Preserve normal change-scoped CI for subsequent ordinary PRs.

1. On the task's disposable stack, replay migrations cleanly and run database lint/security advisors/pgTAP, generated-type drift and the repository's complete current database/API gate (`npm run check:db`). It includes Workshop, matching, report/removal, atomic copy, draft recovery and source/participation/media/need seams. Inspect commands first; report omissions individually if environment/runtime blocks the complete gate.
2. Run the existing TW01 backfill and TW03 populated-upgrade rehearsals, preserving their before/after canonical snapshots and no-fabricated-baseline/application guarantees. Then return to a clean full migration state before final seed/rehearsal. Never run upgrade/reset on the retained developer/demo/shared database.
3. Validate the world: clean reset → ordinary domain checks → expected missing-world verification failure with no repair → seed → verify → repeated seed/verify → bounded interruption/transition check. Exercise both a fresh world and the original nine-scenario world upgraded with the new extension; preserve original IDs and unrelated sentinel rows.
4. Run tooling tests, relevant scoped formatting, mobile generated l10n/format/analysis/full tests, Web tests/lint/types/build and Site/Worker checks/build/dry run through current standard commands. Avoid broad formatting churn. Add focused pure-helper tests for time margins, target refusal, exact inventory/deduplication and request identity; rely on real API integration for product state.
5. Compile Android and run available opt-in Android/local-backend smoke with actual app/router/screens and canonical RPCs. Reuse existing Workshop/SIM02 smoke coverage where it already establishes a seam; add a narrow combined journey against the TW05 demo inventory rather than another fake repository.
6. Wire the **bounded** new demo verification/stability check into the existing Database gate/manual database command after clean pgTAP/domain mutation verifiers and before generated-type drift. Keep ordinary path classification and runtime sensible; measure the added work. Do not copy all demo/mobile native QA into every area/job.
7. At final committed head, obtain all-area hosted Validation once. Current `workflow_dispatch` classifies all areas, so use it if the PR's scoped run does not cover every area. Record exact branch/head/run and inspect each job. Do not alter the classifier merely to force all-area checks or dispatch duplicate full runs after a passing unchanged final head.

The native combined journey should cover:

- Workshop shows core Completed entries and excludes Just Finished/draft/future/cancelled/removed cases; useful search/tag filtering and public template detail/cover/open needs.
- Apply from a prior partially edited creation form without losing that prior editor; accepted exact recovery opens the same independent draft.
- Edit the derived title/tags, inspect a clear active match, close the sheet without a save, reopen/select and verify acknowledged persistence before detail/one truthful destination snackbar.
- Back returns to the same bound draft and raw form; normal detail handles Full/current visibility and existing participation/photo rules.
- A controlled save failure retains the form; retry after lost committed acknowledgement reuses the same request UUID/ID. Invalid raw input, explicit discard and partial-image outcomes remain truthful.
- Self-report/removal on a dedicated fixture: new use closes while the accepted draft remains editable; original-Creator baseline remains private. Staff review can be covered through authenticated API/admin tests if full native staff UI is not available.

Use real persistence/matching/report/application boundaries. A controlled wrapper dropping one real committed response is acceptable; record what was injected versus backend/UI evidence. Do not keep credentials in screenshots, recordings, console output or bundled artifacts. Inspect representative Italian/English layouts, long titles, keyboard/large text, covers, Full/unknown labels and modal focus where available.

Run iOS compilation and supported physical-device swipe/interactive Back/accessibility checks if the environment permits. Otherwise list each as unrun with a reproducible checklist. An Android emulator and passing widget tests do not establish iOS/device accessibility. Do not block the reviewable repository work merely because signed/public-host release infrastructure is deferred.

If cumulative validation exposes a defect, fix only a necessary scoped Template/demo/editor seam and cover it. Add a forward migration if domain behavior truly requires one; never rewrite applied migration history, weaken RLS/locks/validators, change similarity product policy or absorb an unrelated refactor to make the demo pass. Report broader independent defects with precise reproduction.

## Documentation and delivery

Update `docs/development/demo-data.md`, closest helper/integration README maps and roadmap. Add a concise TW05 evidence/reproduction record with exact inventory, owners/accounts, time/state purpose, template/copy/removal relationships, commands, read-versus-mutate behavior and native QA limitations. Keep historical validation records identifiable and update stale present-tense “SIM02/Workshop deferred” summaries where necessary.

Explain how to choose the synthetic personas, obtain a local OTP without logging it, start the app against the isolated stack, reach Workshop/suggestions, inspect accepted drafts and repeat destructive journeys safely. Document that DEMO-A prefill never submits and force-killing an app has no guaranteed unsaved-form persistence.

Inspect the final diff, commit only intended files, push and open the draft PR against the approved predecessor. Do not merge or deploy. The handoff must include:

- PR URL, branch/target, exact base/final head and clean retained checkout;
- implemented inventory and feature journeys, narrow fixes and security/privacy boundaries;
- exact checks actually run, assertion/test counts, final-head hosted all-area evidence and runtime;
- stable-seed/interruption/upgrade proofs and any justified snapshot exclusions;
- Android/native evidence versus iOS/physical/accessibility checks still outstanding;
- founder review of realistic content/PLANETS attribution, public/private boundaries, preview usefulness and draft/removal behavior;
- later main reconciliation preserving PI05 invitation/demo/stability hooks, native/auth/browser links and any then-merged moderation restrictions.

Completion means the Template track can be reviewed and rehearsed on a repeatable local world with cumulative evidence. The stack remains unmerged and later main integration/public release gates remain explicit.
