# PLANETS — SIM02: Automatic editor suggestions and safe Project navigation

Date: 5 October 2026  
Repository: `lillo24/planets.community`  
Task: connect the SIM01 lookup to the mobile unpublished Proposal editor, with quiet automatic suggestions and DRAFT01-safe navigation.

## Outcome and authorized workflow

When a person enters or changes a Proposal title and selected skill tags, the editor automatically checks for similar upcoming Projects after a short debounce. A compact inline entry says that a similar activity may already exist and offers a button to view the matches. A person can inspect a candidate through ordinary Project detail, with their current draft preserved and truthful saved feedback on the destination.

Implement SIM02 in one isolated branch/worktree, validate, commit, push and open a **draft stacked PR**. Keep it **unmerged** for founder review of presentation, dismissal/reopening, save/navigation behavior and predecessor integration. Do not deploy or change shared databases. This explicitly overrides AGENTS.md's default-main/automatic-merge workflow.

The approved dependency base is:

- [SIM01 PR #140](https://github.com/lillo24/planets.community/pull/140);
- branch: `codex/sim01-similar-active-proposal-matching`;
- exact base/head: `8effe582704324e2da159392629db95be08a66f3`;
- suggested new branch: `codex/sim02-automatic-editor-suggestions`;
- PR target: `codex/sim01-similar-active-proposal-matching`.

Verify the remote head and required ancestry before branching. Preserve the predecessor's retained clean checkout. The inspected stack is TW01 #127 → TW02 #129 → TW03 #132 → DRAFT01 #135 → TW04 #137 → SIM01 #140; all remain draft/unmerged. This prompt deliberately authorizes that dependency stack, so do not stop merely because the general roadmap normally waits for merged predecessors.

Main was inspected at `fcd2236dc620f7b768d4aec01fc5f07ee9b61d76`, including participant-link plans #128/#131/#134/#138. Do not import main's native-link/auth/browser changes or the separate moderation/admin-hosting stack incidentally. Later integration must preserve both tracks. If predecessors have since merged, use current main only after verifying that all required contracts survived and record the actual base/target. If the required remote head changed incompatibly, identify the exact dependency problem instead of silently choosing a different base.

Read AGENTS.md, applicable nested instructions, architecture, roadmap and current code before editing. This prompt carries the required product decisions directly; the Google Doc/prior chat is optional background. Routine implementation and reversible UX choices within these bounds are authorized.

## Scope and settled product rules

- **One-time Proposals only.** Enable suggestions for new unpublished editors, reopened owned drafts and independently editable drafts copied from templates.
- Title alone can yield a match. Selected controlled skill IDs refine it; they are optional. Optional rough country/locality refines the existing server order.
- Description enrichment remains deferred. Do not send summary, description, exact meeting details, coordinates, dates, cover bytes, resource needs or other private form fields to matching.
- Upcoming Projects are separate from the completed-only Workshop. Suggestions never insert active Projects into Workshop, relabel past events as joinable or turn drafts into templates.
- Similarity means “may be related,” not proof of duplication. It never blocks saving/publication, replaces the idea, applies a template or automatically joins a Project.
- Normal Project detail and participation flows retain membership/pending/request states, capacity, blocking, profile/photo requirements and manager authority.
- Published Proposal editing has no SIM02 lookup/suggestions. Preserve its current manual-save and structural-lock behavior.
- No Tavolo/Scambio-Dona matching, new join affordance in previews, direct invitation/sharing feature, AI/provider, background worker, persisted query history or new taxonomy.
- DRAFT01 remains the owner of departure persistence and truthful feedback. SIM02 lookup itself never saves or creates a draft.
- The realistic eight-template demo world and cumulative integration checkpoint remain TW05. Add only narrow deterministic fixtures needed for this task.

## Verified predecessor evidence and current seams

At the inspected exact SIM01 head, [Validation run 37303635929](https://github.com/lillo24/planets.community/actions/runs/37303635929) passed Database, Mobile, Web, Site and change classification; none was skipped. Database logs confirm 3,481 pgTAP assertions and 706 authenticated SIM01 assertions, plus 93 TW02, 132 TW03 and 42 DRAFT01 assertions. Mobile logged 1,221 tests. This is predecessor evidence, not validation already performed for SIM02.

SIM01's 11,121-row scale fixture verified indexed narrowing and deterministic top-5/top-10 ordering. Hosted topic/common/weak plans admitted 61/61/0 candidates and took 7.617/6.734/0.065 ms observationally. These measurements are not a latency guarantee. Common title topics can still admit many candidates for ranking; debounce and request discipline matter.

Inspect at least:

- `docs/development/similar-active-proposals.md` and `supabase/migrations/20261005104541_similar_active_proposal_matching.sql`;
- SIM01 SQL tests and `scripts/verify-local-similar-active-proposals.mjs`;
- `apps/mobile/lib/features/proposals/presentation/proposal_editor_screen.dart`;
- `apps/mobile/lib/features/proposals/application/proposal_controllers.dart` and `proposal_draft_session.dart`;
- `apps/mobile/lib/features/proposals/data/proposal_gateway.dart` and the current Proposal/domain failure types;
- `apps/mobile/lib/app/router/draft_departure_coordinator.dart` and `app_router.dart`;
- current discovery/detail, participation, cover-image and controlled-skill presentation patterns;
- TW04 Workshop controllers/screens and its Android integration smoke/fixture procedure;
- DRAFT01 departure/router tests, applicable README maps, mobile l10n/configuration and scoped Validation workflow.

Verify concrete paths and APIs before editing; the list identifies responsibilities rather than requiring a new file for each item.

The editor already has a UUID session independent of its route argument. `proposalEditorSessionProvider(sessionId)` retains the first canonical `boundProposalId` after a create route saves. `_ProposalForm` retains raw controllers, skill importance, pending cover and acknowledged snapshot. Router onEnter/onExit guards handle departure; the coordinator shows a localized snackbar after the destination becomes active, for the same actor only.

**Important modal boundary:** the editor's `DraftDepartureOwner.isActive` depends on mounted state, TickerMode and `ModalRoute.isCurrent`. Opening a suggestion sheet/dialog makes the editor temporarily noncurrent. Calling app-router navigation while that sheet is still open can bypass the active-owner guard. This task must close the sheet and let the editor become current before requesting Project navigation. Preserve the distinction between a temporary sheet and an actual editor departure.

## Consume the exact SIM01 contract

Use the authenticated read-only RPC `public.list_similar_active_proposals`, with the current expected actor. It is available before a saved draft or publish-ready form exists. Preserve app readiness/setup navigation; do not add a photo or publication-completeness gate for matching.

| Argument | Caller requirement |
| --- | --- |
| `p_expected_profile_id` | Current ready authenticated profile UUID, captured with the request/session revision. |
| `p_title` | Required text, at most 100 characters including whitespace. Empty/intermediate/weak valid input can return an empty list. Never truncate an overlong title to manufacture a valid lookup. |
| `p_skill_ids` | Selected controlled skill UUIDs; optional/null/empty allowed. Deduplicate and sort for stable request identity. Server maximum is 50 entries before deduplication; unknown/null IDs fail. |
| `p_country_code` | Optional rough hint; trim/uppercase and send only if valid under the existing two-letter domain rule. Omit blank/temporarily invalid input without altering the form. |
| `p_locality` | Optional rough hint, at most 120 characters including whitespace. Omit an invalid/overlong intermediate hint; do not truncate, geocode or send exact address. |
| `p_excluded_proposal_id` | The editor controller's current bound draft UUID, or null before first save. Never use the template/source ID or only the nullable route argument. |
| `p_limit` | Use 5 for this UI; server permits 1–10. No pagination or total-match count exists. |

The response is a bounded ordered list with exactly these fields: `proposal_id`, nullable `cover_object_path`, `title`, `summary`, `starts_at`, `ends_at`, `event_timezone`, `country_code`, `locality`, nullable `administrative_area`, `public_location_label`, `derived_status`, `availability`, `title_evidence`, `shared_skill_ids` and `location_relation`.

Known values are `derived_status=upcoming`; availability `available|capacity_unknown|full`; title evidence `title_topic|multiple_title_terms`; locality relation `same_locality|same_country|not_provided|other`. There is no score, confidence, creator profile, private meeting data, counts, baseline, receipt or participation relationship. Read the current contract and generated types rather than broadening it through raw-table reads.

Use a narrow typed mobile preview model. Existing full `ProposalSummary` requires data this RPC does not provide; do not fill its capacity/count/skill fields with invented zeros or reconstruct a false full domain object. Parse nullable and enum fields explicitly, keep errors distinguishable from empty results, and follow repository failure conventions. An unexpected/malformed payload must produce a safe explicit lookup failure rather than “no matches” or invented availability.

The server admits candidates only with remaining title-topic overlap, after its fixed Latin accent folding, minimum word length and Italian/English generic-word filtering. Skills and locality alone cannot admit a match; summary/description do not admit one. There is no stemming, translation or synonym matching. Do not reproduce the backend vocabulary/ranker in Flutter or label results with percentages.

Preserve server order: lexical overlap, shared skills, available/unknown/Full, rough locality/country, start and UUID. Do not sort locally to imply stronger confidence or promise that all local/free activities are present. Full and unknown-capacity candidates are legitimate preview states, not authorization to join.

## Automatic lookup and editor lifecycle

Build a small feature/controller boundary consistent with the existing app. Keep the editor integration focused on observing relevant fields and presenting state; avoid a broad editor/router refactor.

1. Scope lookup state to the current actor and editor session UUID. Separate two simultaneous/retained editors, including two create routes and two template copies. Form route reuse, disposal, sign-out, account switch and readiness/access loss must invalidate old requests, timers, results and selected-candidate callbacks.
2. Observe title, selected skill **IDs**, valid rough country/locality and current bound exclusion ID. Changing only skill importance, description, cover, dates or unrelated form fields must not issue a matching request. Stable ordering of the selected set prevents duplicate calls.
3. Use the repository's existing short debounce pattern where suitable; 350 ms is a reasonable default. Input changes immediately invalidate/hide or disable old results before waiting for the next lookup. Each response must belong to the current actor, session and effective input generation.
4. Skip a clearly empty or out-of-bounds title; valid weak/generic text may be sent and rejected naturally by the server. Do not require tags, publish-valid dates, saved logistics, a draft ID or a photo. Avoid duplicating the SQL linguistic eligibility rules.
5. Avoid repeated requests for an unchanged effective query while active. Explicit Retry, reopening/resuming after a departure or a deliberate refresh may recheck current availability. Use bounded reads only; no prefetch loop, pagination, whole-catalog download or request on each rebuild.
6. Pause/cancel scheduled work when the editor is offstage, another app page is active, the app is backgrounded, or saving/publication/departure is in progress. Ignore obsolete in-flight responses even when the transport cannot cancel them. Resume from current form state when the editor becomes active, without a timer running continuously behind Project detail or another tab.
7. A suggestion sheet may retain the current settled preview while visible; it must not initiate background keystroke polling. A real route departure invalidates old activity/selection work. Choose/document one clear rule for refreshing after returning or reopening.
8. When first save binds a canonical draft ID, update the exclusion and invalidate any old unbound query. Preserve this editor session's dismissal state. Binding during an already accepted guarded navigation must not cancel that navigation or cause a second save; separate lookup invalidation from the accepted departure intent.

Normalization for request identity must respect backend input bounds and the raw form. Do not silently shorten invalid text or mutate country/locality controllers. Optional invalid geography can be omitted while a valid title still matches; required-title/skill failures remain explicit. Do not catch authentication/SQL/network failures and return an empty success.

No matching query, partial title, private form payload or selected skills should enter URLs, durable storage, analytics or error logs. Use labels/error kinds for diagnostics. Session-local memory is enough; discard it on account/session teardown.

## Inline entry and candidate sheet

Use existing mobile components/tokens and Italian/English localization.

- Present a compact nonblocking inline entry near the title/skills context once current matches exist. Suggested copy: IT “Potrebbe esserci già un’attività simile.” / “Vedi progetti simili”; EN “A similar activity may already exist.” / “View similar Projects”. Final localized wording can follow repository style and remains founder-reviewable.
- Do not open a modal automatically, toast on every edit, announce “Duplicate found”, disable publication or replace entered text. The person chooses whether to inspect.
- Let the person dismiss suggestions and reopen them in the same editor session. Use a discoverable compact reopen affordance. Dismissal must not erase the form, persist private input or leak to another account/editor; pausing lookups until reopening is acceptable if documented.
- Loading should be quiet and localized. A settled legitimate empty result can leave the suggestion area unobtrusive. Lookup failure has an explicit, nonblocking localized Retry state distinct from no matches; ordinary edit/save/publish remain usable.
- The sheet displays at most the returned five previews with title, summary, public date/time/locality and an optional authorized cover using existing delivery/placeholder behavior. Keep long titles, small screens, large text and keyboard visibility usable.
- Availability may show a truthful Full label or unknown state. Never fabricate “spots left”, headcounts or “Join now” from this payload. Public cover rendering must use canonical parent/path authorization; no creator/profile ID is available or required.
- A reason can describe actual title/shared-tag evidence or rough locality if useful. No numerical confidence, exact-word highlight computed from a different client algorithm, “same interests” inference or guaranteed duplicates.
- If a count is shown, it is the number of returned suggestions, not all matching Projects. Avoid list-length pagination heuristics because this is top-N, not a catalog.
- A candidate action opens ordinary Project detail. Dismissing the sheet/backdrop/Back returns to the unchanged editor and does not save a draft or show saved feedback.
- Labels, semantics, focus order and dismiss/reopen controls must be accessible. Avoid repeatedly announcing results while a person types.

## Candidate navigation and DRAFT01 preservation

Use existing `/proposals/<proposalId>` detail and its normal participation actions. Do not invent a special candidate detail, matching-specific join endpoint or new return-navigation system.

Recommended flow: await the suggestion sheet's result as an opaque candidate ID; after dismissal completes and the editor is current, validate the captured actor, editor session, relevant input generation and selected result, then request one ordinary router push. Use the current project's router idioms.

**Do not push while the sheet still owns the current route.** Await the actual modal dismissal/route restoration, not a hard-coded sleep. Test that `DraftDepartureCoordinator.activeOwner` is the outgoing editor when the push is requested. Check mounted/active state and actor again; an old sheet callback must not navigate after account switch, disposal, editor replacement or a new idea.

Let the existing router guard perform departure preparation once. Do not manually call `prepare` and then independently push through the same guard, which can repeat persistence or consume/duplicate destination feedback. If a small seam fix is necessary, preserve the coordinator's ownership and cover all existing exit paths; do not bypass it or introduce a second saving mechanism.

| Departure result | Required behavior |
| --- | --- |
| Dirty valid unpublished form, successful acknowledged save | Save before detail opens, retain the same bound draft, show localized “Bozza salvata”/“Draft saved” on the destination through DRAFT01. |
| Existing saved/unchanged form or empty untouched editor | Navigate under existing guard rules; no new draft and no false newly-saved toast. |
| Invalid raw input, refused save or transport failure | Preserve the form and recovery state; ordinary keep-editing/retry/discard choices apply. Do not open detail unless DRAFT01 authorizes the departure. |
| Explicit discard | Honor existing discard behavior; no full-saved toast. |
| Draft text acknowledged but pending image not saved | Preserve DRAFT01's partial outcome/recovery and truthful image-warning feedback; never substitute an unconditional “Draft saved”. |
| Lost create/update acknowledgment | Existing exact-payload retry/reconciliation owns recovery; do not create another draft or generate a new creation request UUID. |
| Actor/readiness changes while sheet/save is pending | Invalidate callbacks/feedback and follow existing auth routing. A committed save remains owned by its original actor; never render their form/results for another actor. |

Coalesce rapid candidate taps so one choice produces one guarded navigation. Back/tab/Home interactions racing with an in-flight departure must retain DRAFT01's current competing-transition behavior, without duplicate drafts, duplicate snackbars or late pushes. Disabled/loading actions should make the chosen pending navigation understandable.

Returning from Project detail must reopen the **same editor session and draft**, including the first-created ID on a null create route, edited text/tags, dates, raw invalid input and cover recovery. Do not create a new draft from the matched Project or template. A template's removal or source changes do not alter an already independent copied draft.

A candidate can start, cancel, become Full or lose public availability between lookup and opening. The ordinary detail reload and canonical participation commands decide the outcome. Handle ordinary unavailable/error states safely; a stale preview never guarantees joining. Full/unknown availability or existing participant/pending/creator status must not be reconstructed from missing fields. Reuse ordinary own-participation/detail state; do not add raw participant/blocked-user queries to this feature.

Blocking does not necessarily hide an otherwise public candidate in SIM01. Normal join/request authority remains decisive. Do not expose inbound-block reasons or silently “fix” the backend's visibility contract in Flutter.

## Meaningful validation

Add focused tests for behavior and security/lifecycle seams, using controlled timers/futures and the repository's test patterns. Do not merely assert widget internals or mirror production code.

Cover at least:

- exact RPC arguments/bounds, nullable cover/capacity state, malformed/error versus empty response, and typed parsing without fabricated fields;
- title-only matches; selected skill-set/locality changes; importance-only and description-only edits causing no lookup; stable deduplication and debounce across several rapid input updates;
- immediate invalidation on changed input, out-of-order completion, empty/overlong title, optional invalid geography omission, and Retry using the latest eligible input;
- no match/error/loading/settled-match UI, bounded previews, dismiss/reopen and localized accessible controls;
- separate editor sessions and account switch/readiness loss/disposal with pending timer, lookup or sheet selection; no old query/result/callback becomes visible or navigates;
- inactive tab/route/background suspension and current-input refresh on return, without continuous hidden lookups;
- bound-ID exclusion after first save on a create route; preserved dismissal and no duplicate save when binding happens during accepted navigation;
- **sheet dismissal before router push with the real departure owner active**, successful dirty save and one destination snackbar, then Back to the same session/draft;
- invalid-input/save failure keeping the editor and raw input, retry recovery without duplicate drafts, unchanged/empty navigation without false feedback, explicit discard and partial-cover feedback;
- rapid double taps and a competing Back/tab transition while save is pending; stale selection after topic/account/editor change;
- template-copy editor suggestions preserving the independent draft/prior editor; published editors issuing no matching calls;
- candidate losing availability or becoming Full, and ordinary participant/pending/creator/block/profile-gate behavior through existing detail/participation seams rather than invented preview permissions.

Run mobile formatting, generated localization checks, static analysis and the full mobile test suite through repository-standard commands. Compile the supported Android artifact if the toolchain is available. Inspect current package scripts/CI rather than copying stale command names.

Run the authenticated `npm run proposal:similar:verify:local` and the current DRAFT01/TW02/TW03 seam verifiers on an **isolated disposable local stack** when available. If a seam fix affects backend/domain, cover it with appropriate database/API/generated-type validation. SIM02 is expected to need no database migration, new index or change to matching admission/ranking.

Extend/reuse the existing opt-in Android/local-backend integration smoke narrowly: type a synthetic eligible idea, inspect current matches, dismiss without a save, reopen/select, verify persistence before destination, return to the same draft and confirm ordinary candidate detail behavior. Include a controlled save-failure/retry case and first-save exclusion if practical. Use actual RPCs/screens for the persistence boundary; fakes alone do not establish native route correctness.

Preserve local configuration bytes and unique ports/project identity; never reset another worktree/shared DB. Temporary synthetic OTP tokens/defines remain outside Git, are never printed/uploaded and are deleted after use. Stop the isolated stack before restoring configuration. On a shared emulator, isolate and remove only this task's QA package/reverse rule. Record exactly what ran.

Report iOS compilation, physical-device swipe/interactive Back, native accessibility and any unavailable smoke checks precisely. Android compilation/widget tests do not establish iOS or physical-gesture correctness. Use documented remaining QA instead of claiming those checks passed.

Keep hosted validation change-scoped. A mobile/docs-only final diff may legitimately skip Database/Web/Site under existing classification; changing shared/backend/workflow files requires their affected checks. Do not expand recurring CI just to reproduce the predecessor's all-area run. Confirm required final-head jobs and skipped-area classification after the final commit.

## Documentation, delivery and founder review

Update the closest feature/navigation documentation and roadmap with the final implementation, request inputs/bounds, debounce/lifecycle/dismissal rule, no-description default, modal handoff, draft recovery/feedback and lexical limitations. Add a folder map only where it helps navigation. Preserve predecessor API/report/application documentation; do not mark the stack merged or production-ready.

Inspect the final diff and commit only intended files. Push and open the draft PR against the verified approved predecessor branch; link SIM01 and DRAFT01/TW04 dependencies. Keep the clean checkout retained for review. Do not merge, rebase unrelated branches, deploy, seed production or run a shared backfill.

The handoff must include:

- draft PR URL, branch/target, exact base and final head;
- final user behavior, relevant implementation choices and any narrow dependency/seam fix;
- exact checks actually run, final-head hosted validation, skipped areas and native/environment limitations;
- reproducible local smoke/manual QA steps and cleanup status;
- concrete founder review: wording/placement, preview usefulness and Full/unknown presentation, dismissal/reopening, modal navigation, save/discard/partial feedback and return preservation;
- remaining stack integration, physical native QA and TW05 demo/cumulative work.

Completion means a reviewable draft PR with passing affected checks and honest limitations. It does not mean this unmerged stack has been released.
