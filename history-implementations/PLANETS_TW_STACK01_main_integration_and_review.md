# PLANETS — TW-STACK01: Integrate the Template stack with main for review

Date: 5 October 2026  
Repository: `lillo24/planets.community`  
Task: produce one reviewable integration branch containing the completed Template Workshop track and current main's participant-invitation track.

## Outcome and authorization

The eight Template plans are implemented in draft PRs. This task reconciles their cumulative head with current main, validates the combined database/router/demo behavior and opens a **draft integration PR targeting main**.

Create one isolated branch/worktree, integrate, fix necessary conflicts/seams, validate, commit and push. Keep the integration PR **draft and unmerged** for founder review. This prompt authorizes a merge into the isolated integration branch; it does **not** authorize merging main or predecessor PRs, marking founder review approved, deploying, migrating/seeding a shared database or publishing store builds. This explicitly overrides AGENTS.md's automatic-merge default.

Selected inputs:

| Role | Branch / reference | Exact inspected commit |
| --- | --- | --- |
| Integration base / PR target | `main` | `cbfbf0ae6de9eb73906361c5980b113ec6bc2046` |
| Complete Template source | `codex/tw05-workshop-demo-and-cumulative-qa`, [PR #145](https://github.com/lillo24/planets.community/pull/145) | `63bfb83120af76af404055a9999d3298181f3c34` |
| Common ancestor | Former main after #124 | `92d93ca5a455ab853df8bc34b66fd8d69f4fb341` |
| Suggested integration branch | `codex/tw-stack01-main-integration` | Create from the verified base |

Start from main and merge the exact complete Template head, preserving both histories. Do not cherry-pick individual plan commits or merge eight PRs independently to construct this candidate. Before work, verify remote refs and ancestry and record actual inputs. The inspected comparison is diverged: 11 Template-side commits and 6 main-side commits since the common ancestor.

If main has advanced, inspect its additional changes and integrate then-current main only when they fit the selected scope; record the new base and validate affected interactions. If a required Template head changed incompatibly, identify the dependency change rather than silently mixing revisions. Preserve retained predecessor checkouts/branches and any uncommitted user work. Use an already isolated managed checkout instead of making a nested worktree unnecessarily.

The Template source includes:

| Plan | Draft PR | Included head |
| --- | --- | --- |
| TW01 source-linked domain | [#127](https://github.com/lillo24/planets.community/pull/127) | `342af7603f8f34b987d11073147cd5549d4b012c` |
| TW02 reporting/removal | [#129](https://github.com/lillo24/planets.community/pull/129) | `b778445550e49c08395e67c8852d649ead333821` |
| TW03 atomic template copy | [#132](https://github.com/lillo24/planets.community/pull/132) | `49742135f3fbd144abb5bce0d87d3b8ca43bacbc` |
| DRAFT01 departure save | [#135](https://github.com/lillo24/planets.community/pull/135) | `8062035a5cdc38ac016f64d125b7b4407b613063` |
| TW04 mobile Workshop | [#137](https://github.com/lillo24/planets.community/pull/137) | `2905d8a95227a151edb8c8b712b1fbb424f9f459` |
| SIM01 matching backend | [#140](https://github.com/lillo24/planets.community/pull/140) | `8effe582704324e2da159392629db95be08a66f3` |
| SIM02 editor suggestions | [#143](https://github.com/lillo24/planets.community/pull/143) | `08b8c4422de92d8a3f0392c920acc0766a02eaca` |
| TW05 demo/cumulative QA | [#145](https://github.com/lillo24/planets.community/pull/145) | `63bfb83120af76af404055a9999d3298181f3c34` |

Main includes PI01–PI05 (#128/#131/#134/#138/#141). Do not import the separate open moderation/suspension/admin-hosting/dependency/race/private-history/AUTHQA stack (#123 onward through #144) or unrelated old open branches. Their pending work is not evidence that it belongs in this integration. Compose with restrictions only if they are actually merged into the selected main.

Read current AGENTS.md, nested instructions, architecture, roadmap and actual implementation before resolving conflicts. The Google Doc/prior chat is optional background. Routine integration choices within these contracts are authorized; keep consequential product decisions pending for founder review.

## Evidence and scope

[Final-head TW05 Validation 37337040505](https://github.com/lillo24/planets.community/actions/runs/37337040505) passed Change classification, Database, Mobile, Web and Site at the exact source head. Database logs confirm 3,481 pgTAP assertions, SIM01/TW02/TW03/DRAFT01 706/93/132/42 assertions and the bounded 74-table Workshop check in 9.7s. The PR records 1,274 Mobile, 28 tooling, 162 Web, 53 Site/Worker tests, three Android journeys and TW01/TW03 upgrades.

These are predecessor results, not validation of the merged candidate. Do not add branch assertion totals together or promise that an automatic merge preserves behavior. Integrated tables/test counts will differ.

Preserve all settled Template rules: one-time Proposals; identity at publication; Completed at end +24h; canonical public eligibility and source structural locks; private original-Creator Bozza; manual report/removal with no Creator withdrawal; atomic independent copies and private exact-retry receipts; title/controlled-skill/rough-geography matching with five narrow previews; no description enrichment or automatic joining; DRAFT01's bound sessions and truthful save/discard/partial feedback.

Preserve all main invitation rules: direct participant admission is distinct from authority invitation and ordinary public sharing; identity-scoped exact action retries; immutable membership origin/episode history; retained superseded ordinary request/offers/chat; profile-ready photo-free direct joining without bypassing ordinary publication/request photo gates; canonical capacity/blocking and no inherited commitments; native/browser continuations and capability redaction.

Integration is not a new feature/content/visual-polish plan. Necessary fixes belong at their existing owners; do not broaden the matching algorithm, taxonomy, moderation policy or release infrastructure.

## Conflict owners and inspection

Both sides changed at least these shared areas: `app_router.dart`, public Proposal detail/discovery, EN/IT catalogs, pubspec/lock, generated database types, demo world/helpers/tests, root package scripts, Validation and documentation. The inspected overlap contains 16 paths, but inspect the actual merge rather than treating this list as complete.

| Boundary | Inspect and preserve |
| --- | --- |
| Router/auth/native links | Main's `native_project_links.dart`, `_NativeRoutingConfig`, external-link deduplication/auth-continuation handling; Template `DraftDepartureCoordinator`, editor onExit, Workshop routes and session lifetimes. |
| Canonical database | Both migration sets, RPC grants/result shapes, membership origin/admission schema, template/baseline/report/copy/editor receipts and matching locks/eligibility. |
| Types/dependencies | Main's `generate-database-types.mjs` and `participation-rpc-nullability.mjs`; all Template RPC types; merged manifests and regenerated lockfiles. |
| Shared demo | `demo-world.mjs`, `demo-participant-invitations.mjs`, `demo-workshop.mjs`, both bounded runners, exact registry, profiles/media, shared locking and non-repairing verification. |
| Notification projection | Main's `20261005111132_delegated_participation_notification_actor.sql` and `111_delegated_notification_actors.test.sql`; TW05's documented producer failure and scoped demo projector. |
| Validation/docs | Preserve both authenticated/API/demo gates with one sensible orchestration and current factual status; historical evidence remains attributable to its original head. |

Resolve semantically. Avoid blanket “ours/theirs” selection, hand-editing generated types or dropping one branch's tests/routes/scripts to make the merge compile. Inspect nested web instructions before relevant web changes.

## Router integration: preserve both entry responsibilities

**Verified hazard:** main constructs `GoRouter.routingConfig` using `_NativeRoutingConfig`. Its `value` getter returns a new RoutingConfig without `onEnter` when the incoming URI is an ordinary internal route. That is deliberate native-only hook scoping on main. The Template router instead passes DRAFT01's coordinator as `onEnter` for ordinary departures.

A naive merge that puts both behaviors in the native wrapper's original hook can therefore disable draft saving for ordinary navigation. Keeping only the Template router can lose main's native-link/auth behavior. Fix this composition explicitly and document its owner.

Required behavior:

- DRAFT01 preparation runs for actual ordinary editor departures: candidate detail, Workshop, Back/pop, tab/Home, push/go/replace/restore. Only the active editor owns it.
- Native validation/deduplication applies to appropriate external incoming links. Repeated current links preserve the existing invite/OTP/profile form and do not create a new draft save or overwrite continuation.
- A valid new native Project/invitation link while a dirty editor is active uses the ordinary save guard before the actual departure. Invalid input/save failure blocks safely; a delayed link cannot push after actor/session changes.
- Native redirects/normalization and asynchronous guarded replay do not cause two saves, lost push completers, duplicate feedback or redirect loops. Preserve RouteInformation/extra/history and the coordinator's competing-transition behavior.
- Commit callbacks must compose: native external-auth cancellation and DRAFT01 destination feedback run only after an allowed committed transition. A blocked/canceled transition must not run either as a false success.
- Auth/profile setup continuations, supported URI allow-lists, invalid-link safe routes and capability privacy remain intact.
- Workshop management readiness and published-editor manual-save behavior survive the combined routing configuration.
- SIM02 still awaits actual modal completion/restored editor ownership before one ordinary detail push. A candidate preview never adds an `intent=join` marker or participant capability and never automatically joins.

Do not create a second draft-saving mechanism. Add meaningful router tests for internal navigation with the native wrapper enabled, incoming-link departure, duplicate/invalid link, save failure/retry, canceled/competing navigation and account switch. Retain main's existing native tests and Template's real-owner/modal/departure tests.

## Notification defect: verify the existing main correction

TW05 reports that global `process_notification_outbox_batch` can fail with `55000` after the blocking verifier emits a delegated-manager `project.join_request_rejected`. That failure is real on the isolated Template base's legacy resolver.

**Current main already addresses this seam.** Migration `20261005111132_delegated_participation_notification_actor.sql` uses canonical `resolved_by_profile_id` for acceptance/rejection and `removed_by_profile_id` for removal, validates the recorded resolution and payload actor, and retains historical attribution after delegate revocation. Its nine-assertion pgTAP file covers both Project kinds, in-app/push projection, idempotency, forged actor denial and resolver grants.

Keep that migration/tests and verify the integrated final resolver. Do not add a duplicate migration that repeats the same fix or edit previously applied migrations.

Reproduce the TW05 producer path on the integrated disposable stack: run the relevant blocking/domain producers, then invoke the **global canonical worker** under its existing authorized worker role. Confirm delegated rejection projects, plus preserved acceptance/removal attribution, idempotency and invalid-actor refusal. Do not use TW05's non-demo row locks, delete offending events or fabricate receipts to claim the global defect is fixed.

Scoped **demo** projection may remain for ownership isolation: its exact finite inventory should include both demo extensions and leave unrelated queues byte-equivalent. That is separate from the unrestricted projector regression above. If a genuinely different failure remains, record the exact producer/event/code, make only a necessary forward fix and keep fail-loud validation.

## One combined demo world

Compose both helpers under the existing orchestrator/target guard. Preserve the original nine scenarios/three personas, PI05's Dario/Elena and four admission scenarios, and TW05's eight core Completed sources plus ten support sources and synthetic PLANETS/reviewer identities.

- Preserve original IDs, media, titles, request/chat/notification history and the original Just Finished concert. Core Completed clocks/content/tokens/Bozza remain stable.
- Dario/Elena remain photo-free as designed; do not route them through a blanket profile-photo completion loop. PLANETS/reviewer avatars stay synthetic and staff privilege stays limited to the documented reviewer.
- Keep PI05's generation/capability journal and stable admission action identities; never print raw links/tokens or replace/revoke baseline generations silently.
- Keep Workshop's editor creation/application/report/removal keys, owner-renamed independent copies and fresh needs. Source lookup must exclude accepted application destinations.
- Invitation/admission provenance is not copied into a template-derived draft, even when the source has real direct participants or current/revoked links.
- Verification remains read-only for product state. Missing world/drift/interruption must fail without completing profiles, admitting members, projecting notifications, applying or restoring templates.
- Retain one coordinated mutation lock and shared stable verification boundary. TW05 already supports `coordinationSql`/`withLocalDemoWorldLock`; compose PI05 transitions/checkpoints without nested-connection lock failures or disabling locks.
- Snapshot current product tables/columns dynamically. Do not hard-code 74 tables or exclude all new PI05 tables. Preserve membership origins, receipts, secret destruction, reports/baselines/copies and notifications in stability checks.
- Keep narrow documented clock exclusions only on exact relative-time fixtures. Core Completed and copied draft timestamps/history remain fully compared.
- Plain seed does not reset, erase owner copy edits, restore removed templates or recreate accepted intents. Safe target validation runs before a destructive explicit reset.

Keep both standalone bounded checks usable, but compose a sensible cumulative runner so CI does not seed the complete combined world twice unnecessarily. Preserve **both** interruption proofs: committed direct admission before acknowledgement, and committed template copy before acknowledgement. Verification after interruption must not repair; recovery reuses the original receipt/action and an unchanged rerun preserves history.

Run each destructive native journey on its documented fresh narrow fixture or a fresh combined rehearsal stack. TW05 established that standalone SIM02's original single-visible-Repair-candidate assumption fails on the populated world, while its own fresh fixture and the combined TW05 journey pass. Do not “fix” that by changing matcher order/filters or deleting legitimate demo candidates. If adapting the test to the combined world, select the intended canonical ID and verify bounded order explicitly.

Document inventory counts by purpose instead of treating eight core templates as the total public catalog or treating every scenario as a Proposal.

## Migration replay and populated upgrades

Keep both immutable migration histories and unique timestamps. Add a new forward migration only for an actual integration defect.

The histories interleave: main's PI01 migration `20261003125732` precedes TW01 `20261003125831`, and main's PI05 notification migration `20261005111132` follows SIM01 `20261005104541`. A database with either complete history already applied can therefore have pending migrations older than its last applied timestamp. Verify the pinned CLI's supported local migration-up option for that case. Do not rename migrations, rewrite history rows, reset a populated rehearsal or assume “up from the last timestamp” applied everything.

On isolated disposable databases, validate:

1. Clean replay of the combined migration history and all security/domain tests.
2. **Populated main → integrated:** seed main/PI05 first, snapshot existing canonical state, apply pending Template migrations without reset. Preserve invitation generations/secrets/admission receipts, origin episodes, retained requests/offers/chat, notifications and existing source IDs. Legacy once-published sources gain identities without invented Bozza/events/applications.
3. **Populated Template → integrated:** seed TW05 first, snapshot old canonical state, apply pending main migrations without reset. Preserve template IDs/tokens/baselines, reports/removal attribution, independent copies/needs/editor receipts and unrelated sentinel rows. Existing ordinary membership origins remain valid; PI01's new nullable invitation-origin column must not rewrite them as direct admissions.
4. Rerun permitted migration/seed checks and verify no duplicate history or fabricated legacy records. Newly added nullable/default columns need a documented expected projection; compare existing content fully instead of claiming byte equivalence across changed schemas.

Retain the existing TW01/TW03 upgrade/backfill checks where they remain meaningful, but do not substitute them for these two divergent populated upgrade paths.

Regenerate public types from the integrated database using main's canonical generator and documented participation-nullability correction. Preserve all Template RPCs, admission result shapes and nullable `originating_request_id`. Do not retain one side's generated file as the final result. Regenerate lockfiles from the merged manifests through standard tooling.

## Validation and concrete review evidence

Run the repository's complete integrated local database gate, lint/security advisors/pgTAP, authenticated invitation/Workshop/report/copy/draft/matching/participation/blocking/media/need verifiers, both populated upgrades, both demo stability/transition/interruption paths and generated-type drift. Keep new combined checks bounded and wired to the appropriate Database/manual gate.

Run tooling tests; mobile l10n/format/analysis/full tests; Web tests/lint/types/build including browser admission/template admin; Site/Worker checks/build/dry run; scoped formatting and diff checks. Measure added runtime and preserve ordinary path classification/required status behavior. Do not weaken coverage, hide an error as an empty result or change global test timeouts merely to get green CI.

Compile Android and run available real Android/local-backend journeys against the **integrated** app/database:

- Workshop copy/recovery → title/tag match → fully closed modal → guarded save/ordinary detail → Back to the same draft.
- Incoming native link while dirty, duplicate link during OTP/profile continuation, invalid input/save failure and same-session return.
- Photo-free direct invitation admission, existing/pending/full/blocked state and membership/chat continuity, for Proposal/Tavolo where applicable.
- Template-copy independence from source participant links, staff removal and private baseline/report boundaries.

Use real canonical RPCs/screens; explicit one-response transport injection is allowed for retry proofs but must be distinguished from backend evidence.

Run the available local browser invite/OTP/profile/confirmation/handoff rehearsal from PI05 with integrated sources, and verify ordinary public detail does not become direct admission. Exercise template staff review/removal through the existing admin surface or authenticated API; do not import the separate unmerged admin-consequence stack to obtain a screen.

Record which browser/native/device checks were run. iOS compilation, physical-device Back/swipe, TalkBack/VoiceOver/hardware-keyboard and real public-host/signed-device association are separate gates if unavailable. Local routing/HTTP probes do not establish OS association or public hosting. Do not provision hosting/signing/account services incidentally.

Use a unique project ID/ports and synthetic loopback identities, preserve exact configuration bytes, and never reset another checkout/shared database. Keep credentials/capabilities out of Git/logs/screenshots and remove task-only credential-bearing build/cache artifacts. Stop the task stack before restoring configuration; preserve other packages/reverse rules/Gradle processes.

After the final commit, obtain one all-area hosted Validation on the exact integration head and inspect every job. The existing manual workflow selects all areas if scoped PR classification does not. Predecessor results are not integrated evidence. Repeat full validation only after relevant fixes/new final code, not on an unchanged green head.

## Handoff and review boundary

Update the closest router/demo/database/CI documentation and roadmap with the **integration candidate** status. Add a focused integration record: inputs, semantic conflict decisions, combined contract/upgrade proofs, projector regression, exact commands/results/runtime, native/browser evidence and remaining QA. Keep historical records tied to original heads; add a current cross-reference explaining that the TW05 resolver defect is resolved by main only once the integrated regression passes.

Inspect the final diff, verify the final branch contains both selected inputs as ancestors, commit only intended files, push and open one **draft PR targeting main**. Link the eight source PRs and main PI01–PI05 dependencies. Leave predecessor PRs/checkouts intact; do not mass-retarget, close or force-push them during this task.

Founder review remains unapproved unless explicitly recorded: historical public/reusable content, private Bozza, self-report/staff-only removal, independent copy/retry, Workshop wording/presentation, Full/unknown matching and locality/linguistic limits, dismiss/reopen and save/discard/partial-image navigation, synthetic PLANETS attribution.

The final handoff should give:

- draft integration PR URL, actual base, imported Template head and final head;
- code/contract changes needed for integration and proof both histories survived;
- exact integrated checks, both populated upgrade results and all-area hosted run;
- remaining founder/device/public-release gates and any separately reproduced unresolved defect;
- clean retained checkout and cleanup/configuration status.

This task ends with a reviewable integrated candidate. Main merging, predecessor cleanup and deployment remain later explicit actions.
