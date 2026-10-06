# PLANETS — DRAFT01: save Proposal drafts before leaving the editor

Date: 4 October 2026

## Objective

Implement the next agreed Template Workshop plan in `lillo24/planets.community`.

When a person leaves an unpublished Proposal editor with meaningful changes, save their work to the same private draft before completing the navigation. Reopening must restore the saved content. Show a localized destination snackbar, **“Bozza salvata” / “Draft saved”**, only after a genuine save succeeds.

Cover app-bar/system Back, supported back gestures, tab switches and in-app navigation away from the editor. Provide a reusable preparation contract for the later Workshop and similar-Project flows. Do not implement those screens or matching yet.

Published Proposal editing continues to require deliberate **Save changes**. Departure must never publish, save published structural changes automatically, join a Project or create a template.

## Exact base and PR workflow

Repository evidence checked on 2026-10-04:

- TW03 draft PR #132: https://github.com/lillo24/planets.community/pull/132.
- Exact head: `49742135f3fbd144abb5bce0d87d3b8ca43bacbc`.
- Branch: `codex/tw03-template-to-draft-backend`.
- Target: `codex/tw02-template-reporting-removal`, exact predecessor `b778445550e49c08395e67c8852d649ead333821`.
- TW01 #127 and TW02 #129 also remain draft and unmerged.
- Final-head Validation #37212468592 passed Database, Web, Mobile and Site. Database logs explicitly show 3,428 pgTAP assertions, 93 TW02 API assertions and 132 TW03 API assertions.
- Current main: `166a6d43a03d0fc3330e97e3be1388cc7eec65ac`.
- Main includes #128 participant-invite domain and #131 PI02 mobile sharing/invitations. They are outside the template stack's current base.

**This prompt explicitly selects TW03's exact head as the permitted dependency base while the template predecessors remain unmerged.** This is the alternative-base exception to AGENTS.md's normal merged-predecessor rule.

Recheck repository/PR state before editing:

1. If #132 remains unmerged at that head, create one isolated DRAFT01 branch/worktree from that commit. Suggested branch: `codex/draft01-save-proposal-drafts-on-exit`. Open a **draft stacked PR targeting `codex/tw03-template-to-draft-backend`**.
2. If the predecessors have merged, start from latest main after verifying their effective contracts; open a draft PR targeting main.
3. If the predecessor changed through integration/corrective work, inspect and reconcile its actual contracts before choosing the updated head. Do not silently adopt a changed privacy or lifecycle policy.
4. Do not merge/retarget predecessors, modify another task's branch, import unrelated stacks, or automatically merge this task.

Keep this PR draft and unmerged for review of save-before-navigation, truthful partial-save feedback, identity handling and retry recovery, alongside the predecessors' pending review. This overrides default auto-merge instructions.

Do not incidentally import #128/#131 into the unmerged predecessor branches. Later main integration must preserve their current router/deep-link/auth-return/admission behavior and exercise editor departure alongside incoming Project links. Inspect current main again at that integration.

## External context and settled decisions

This prompt is self-contained. No external design document, Google Doc, credentials or production services are required. Repository instructions and actual code remain the source of truth.

Accepted behavior:

- This task applies to unpublished one-time Proposal drafts, whether ordinary or created through TW03.
- Automatic saves happen at deliberate departure boundaries, not on every keystroke.
- Sparse drafts can omit publication fields. Existing draft validation and publication gates remain authoritative.
- A new untouched/empty form creates no draft and shows no saved snackbar.
- A changed existing draft can legitimately become sparse/untitled; do not treat field clearing as an empty new form to discard.
- Use one draft identity for the editing session and its retries.
- Invalid partial input must remain recoverable. The conservative default is to keep the editor open with an actionable error until the person corrects it or explicitly discards unsaved changes.
- No owner withdrawal, Bozza template, public baseline toggle or change to Completed timing.
- No save-on-exit change for Tavoli, Resources, Profile or published Proposal editing.
- No promise that asynchronous saving completes after OS force-kill, process termination or lost authorization.
- No shared database migration/reset, deployment, account/provider setup or new production service.

## Inspect the implemented ownership boundaries

Read root/nested AGENTS.md, `implementation_plan_sections_suggestions.md`, relevant architecture/roadmap/development documentation and the effective code.

Important inspected files/contracts:

- `apps/mobile/lib/features/proposals/presentation/proposal_editor_screen.dart`: form owns raw TextEditingControllers, skill importance, dates, capacity text, organizer toggle, location/privacy and pending cover change.
- Its current `_save` validates then saves/publishes and navigates to `/proposals/mine`. There is no editor save-before-exit guard.
- `application/proposal_controllers.dart`: owner/structural identity and revision checks, ordinary draft create/update, cover orchestration and partial-save recovery.
- `data/proposal_gateway.dart`: canonical RPC calls; ordinary `create_proposal_draft` currently has no stable client creation-request key.
- `domain/proposal_models.dart` and `proposal_time.dart`: sparse draft validation, supplied-value limits, timezone/date handling and published structural locks.
- `apps/mobile/lib/app/router/app_router.dart`: nested Proposal routes in a `StatefulShellRoute.indexedStack`; account changes replace retained private stacks.
- `app_navigation_shell.dart`: direct `goBranch` calls retain Profile/Browse pages, while Home uses its initial location. A tab change can leave an editor without popping its route.
- `apps/mobile/lib/app/planets_app.dart`: application router and localization host.
- `features/cover_media/`: local add/replace/remove selection, processed image bytes and draft-first canonical upload/commit reconciliation.
- Existing editor/controller/gateway/cover/router tests and fake backends.
- `20261004145334_template_to_draft_creation.sql`: TW03 application receipts and existing private draft creation.
- `docs/development/template-workshop.md`: TW01/TW02/TW03 contracts and pending integration.

Existing behavior to address deliberately:

- Form state lives in widgets; preserving a widget across tabs is not backend persistence.
- A single global editor controller may be reused by retained/nested editor routes. Session ownership must prevent a different editor's record/result from taking over the current form.
- A new form is initially addressed by `/proposals/create` and no Proposal ID. After the first save, the session must bind to the returned ID. Do not leave the current route's ID-matching logic stuck in loading or make subsequent saves create another draft.
- `int.tryParse` currently converts capacity text into an optional integer. Invalid typed text must not be silently saved as null.
- Title length one, partial country codes, unknown timezone, invalid capacity and inverted dates can fail ordinary draft validation despite being meaningful work.
- Draft creation is permitted without a profile photo; publication still requires one.
- Cover failure may occur after core content has committed. Existing partial-save state retains the same draft; a null return alone is not proof that nothing was saved.
- Existing tab tests retain Proposal and Profile field values. Update only the unpublished Proposal expectations needed for this new persistence behavior; Profile/Tavolo behavior remains unchanged.

Keep responsibilities in focused feature/application/navigation modules. Avoid a broad rewrite of the large editor or app router.

## Editing-session and dirty-state contract

Create a clear, identity-bound editing session with:

- current actor, session identity and optional existing Proposal ID;
- original/canonically acknowledged form state;
- raw current field values, skill importance, date/privacy/toggle selections and cover revision;
- current dirty revision and save-in-flight state;
- stable first-creation/recovery identity when no Proposal exists.

Choose concrete model/provider structure from repository patterns.

Dirty detection must cover all editable draft content and cover add/change/removal. Compare against the acknowledged state, not only title presence or the last attempted save. Default untouched timezone/privacy values alone do not make a new blank form meaningful.

Capture an immutable form/cover revision for each save. An acknowledgement may mark only that captured revision clean. Late responses cannot clear newer edits, change the current account/session or consume a newer pending cover choice.

Serialize saves per session. Manual Save draft, automatic departure save and optional later Publish must share the same draft identity and avoid overlapping writes. Either freeze editing during the departure save or keep the navigation pending until the latest edits are durably acknowledged.

Returning to a retained/newly rebuilt editor must use the same bound Proposal ID and show acknowledged text, skills, dates/location, capacity/toggle/privacy and canonical cover. Preserve still-unsaved form/cover state when a save failed and the editor remains open.

Do not silently load an unrelated “latest draft” or deduplicate by title/time. A fresh explicit Create action can start another draft; resuming this session must not.

## Retry-safe first creation and recovery

The inspected ordinary create RPC is not identity/request-idempotent. Client debouncing alone cannot prevent duplicate drafts after the first response is lost.

Add the smallest canonical first-creation/recovery contract necessary for ordinary editor drafts:

- Bind creation to expected actor plus a stable client request UUID and the accepted initial content intent.
- Use ordinary complete-profile draft creation and validation; preserve all existing overloads/callers.
- Exact retries recover the same Proposal ID without reapplying the initial payload after later edits/publication.
- Incompatible accepted-key reuse fails explicitly.
- Another account cannot read/recover this account's receipt.
- Create and record recovery identity atomically; failures produce no orphan draft or success receipt.
- A narrow owner-authorized recovery read may resolve an ambiguous request without requiring a new create action.
- Keep private receipt data narrow; do not create a full edit history, broad retention policy or public usage record.
- Minimal actor/request/Proposal recovery markers may be retained through the existing local-storage abstraction where needed. Do not store exact meeting text, addresses or cover bytes in unprotected settings as a shortcut.

After resolving first creation, subsequent saves address that existing Proposal. Freeze/recover the original create intent before applying newer edits to the recovered ID; do not change its request key automatically after a timeout.

Use current identity/private-access rules before recovery. No staff/public/service-role bypass. No automatic re-creation of an unavailable recorded destination.

TW03 drafts already have an ID and immutable template provenance. Open/update that ordinary draft directly. Do not rerun `create_proposal_draft_from_template`, recopy needs, overwrite its application receipt or require the source template to remain available.

Use existing validation/creation helpers and forward migrations if this narrow backend addition is needed. Do not relax publication or draft constraints to avoid handling unfinished input.

## Save-before-navigation coordination

Provide one reusable, awaitable draft-departure preparation contract that returns an explicit outcome: no change, confirmed saved, blocked/failed, deliberate unsaved discard, or accurately handled partial save.

Wire the same contract into:

- app-bar Back;
- Android/system Back and the supported back-gesture path;
- actual route removals/replacements affecting the editor;
- shell tab changes, including Home's stack-reset path;
- in-app outgoing navigation from the editor, including its resource-management destination;
- future explicit Workshop/similar-Project callers without implementing those features here.

A pop guard alone is insufficient for `goBranch` or explicit `go`/push navigation. Saving in `dispose` or after the route already popped cannot protect the form.

Use APIs supported by the repository's resolved Flutter/go_router versions. Handle gesture cancellation, route/dialog distinctions and reentrancy correctly. A date picker, tag sheet, cover cropper or other temporary form subflow must not trigger a false editor departure or “Draft saved” snackbar.

Departure behavior:

1. No dirty meaningful work: navigate normally; no write/snackbar.
2. Dirty valid draft: keep the editor/session available, save the captured latest state, then perform the original requested navigation once.
3. Invalid input or save failure: remain in the editor with preserved raw input and actionable correction/retry/discard options; no success message.
4. Rapid repeated departure requests: one coordinated save and one final navigation. Ignore/coalesce further requests while departure is pending; do not create competing destination actions.
5. Manual Save/Publish already in flight: join/wait or block safely; do not start a second create/save.
6. Cancelled navigation/gesture: no abandoned pending navigation or duplicate feedback.

Preserve intended Back destinations and shell state. Do not always replace a requested Project/detail navigation with My Proposals.

Register only the active editor/session as a departure owner. An inactive retained editor must not intercept navigation between unrelated screens or write after a later account change.

Explicit discard means abandoning **unsaved editing changes**. It does not delete a persisted draft, remove a template, undo an already committed operation or erase TW03 provenance. Keep ambiguous accepted-creation recovery resolvable; do not forget its identity then retry through a new create request.

## Sparse and invalid input

Save title plus selected tags without requiring summary/description, dates, location, meeting data or capacity. Tags-only and other valid sparse forms should follow ordinary backend draft rules.

Validate raw supplied values before constructing a payload that would lose them:

- Do not convert invalid capacity text into a successful null-capacity save.
- Do not silently drop a one-character title, invalid country/timezone or reversed dates.
- Do not replace the person's text with defaults simply to pass validation.
- Do not interpret invalid timezone text as a request to shift stored UTC instants.

For an input the canonical draft cannot represent, keep the editor open. Explain the affected field and offer correction/retry or deliberate discard of unsaved changes. Leave the raw value available.

A local-only recovery mechanism is optional, not a reason to loosen server validation. If used, define ownership, cleanup and sensitive-data protection; label local recovery distinctly from backend save. Never show the ordinary saved message solely because data was cached on the device.

## Cover and partial-save behavior

Reuse current processing, Storage ownership/path constraints and reconciliation. Do not create an alternate upload path or copy a source template cover.

- Cover-only meaningful work may initialize one ordinary sparse private draft.
- Preserve the known draft ID as soon as core creation/save is confirmed.
- Successful cover replacement/removal acknowledges the specific cover revision and refreshes canonical preview state.
- Optional-cover failure after core save does not cause another parent creation or loss of pending processed image state.
- Default to keeping the editor open with the existing recoverable draft and retryable image.
- If the person deliberately leaves without the pending cover change, state the partial outcome honestly, e.g. draft content saved but image change not saved. Do not show plain “Bozza salvata” as if the whole requested state succeeded.
- A failed read/reconciliation or ambiguous commit must not be disguised as a complete save.
- Best-effort stale-object cleanup remains distinct from canonical save success.
- Do not run asynchronous final-save logic from widget disposal or promise unfinished media recovery after force-kill.

No new cover format, crop design, bucket, limits or dependency is needed for this task.

## Destination feedback and reopening

Deliver the saved snackbar through a destination-capable app/shell mechanism, after navigation commits and while the same expected account remains current.

- Italian: `Bozza salvata`.
- English: `Draft saved`.
- Use the existing theme, accessibility and snackbar conventions; top/bottom placement is a routine implementation choice.
- Emit once per confirmed departure/save revision.
- Do not queue a stale snackbar for a later account or show it over the outgoing editor.
- Do not show success for empty/unchanged forms, failed/uncertain saves, explicit unsaved discard, published editing or publication.
- Distinguish partial-cover/device-only recovery with accurate localized copy.
- Reopening via retained tab or ordinary owned-draft edit route restores the same canonical draft. A route rebuild must not reload the original empty new-form state over the saved record.
- An existing template-derived draft remains editable through normal owner reads even after source/template removal.

Make the departure outcome reusable by later callers so opening a similar Project can first preserve the draft and then show saved feedback on that Project page.

## Identity, auth and lifecycle safeguards

Carry the expected actor/session through every await and RPC. Drop stale UI callbacks, pending navigation and notifications on account change or session invalidation.

A forced sign-out/auth/access redirect must not be trapped indefinitely by a draft guard or attempt to save under a new identity. Let the security transition proceed; clear private in-memory state and do not claim a save that was not confirmed.

If an already authorized old-account request committed before identity changed, it remains that account's private draft. Do not display or mutate it in the next account's session.

Do not expose private form text/location/media in telemetry, route URLs, logs, snackbar bodies or generic settings storage. Recovery keys/IDs are not authorization.

Published Proposal paths remain deliberate Save changes with current Creator/Co-creator authority, start-time structural lock and ordinary cancellation policy. New departure hooks must not call that mutation path.

Draft saves create no template identity/baseline, publication, participant/chat admission, matching notification or source/member event. TW01 publication and original-Creator baseline capture remain unchanged.

## Validation and acceptance evidence

Add focused controller/session/gateway/widget/router tests and real authenticated checks for any new backend creation/recovery contract.

Required cases:

1. Title plus tags saves sparsely on app-bar Back, reaches the original destination and shows one localized saved snackbar.
2. System Back and supported gesture behavior preserve work; cancelled gesture/navigation creates no incorrect success.
3. Tab switches save even though the editor route is retained; return shows the same draft and fields.
4. Home's branch reset and in-app detail/resource navigation go through the same preparation contract.
5. Untouched/empty/whitespace-only new form creates no draft or snackbar; unchanged saved drafts produce no extra write/message.
6. Existing draft clearing/editing, tags-only and cover-only meaningful cases follow ordinary sparse rules.
7. One-character title, invalid capacity text, partial country/timezone and reversed dates remain visible with blocked departure; correction/retry succeeds.
8. Failed first save, lost creation response, duplicate delivery and recovery use one Proposal ID. A fresh explicit Create action can create a different draft.
9. Rapid Back/tab actions and overlapping manual save use one save/navigation; stale acknowledgements do not clear newer input.
10. Pending cover failure after core save retains the same draft and retryable image; complete retry and deliberate partial departure have truthful distinct feedback.
11. Read/reconciliation failures do not produce success-shaped fallback feedback.
12. Rebuild/reopen restores fields/skills/dates/location/privacy/capacity/toggle/cover through the bound ID; there is no new-form loading loop.
13. Account switch/sign-out during save does not leak/mutate the old form or show its saved message to another identity; auth redirects complete.
14. Another retained/nested editor cannot take over this session or save its content to the wrong Proposal.
15. Published Creator/Co-creator editing, authority loss/start-time locks and deliberate Save changes remain unchanged; no automatic publication/template creation.
16. Open a real TW03-created draft by its ID, save/reopen it after template removal, and verify that its application receipt and copied need IDs stay unchanged.
17. New backend receipt/RPC access is owner-only, atomic and retry-safe; incomplete-profile/identity/publication/photo rules remain canonical.
18. Italian/English parity, accessibility, existing Profile/Tavolo retention, Browse back-stack and cover tests pass.
19. At later main integration, exercise #128/#131 Project links, native/auth-return navigation and admission behavior without losing an active draft or changing invite semantics.

Use deterministic delayed fake responses and controlled real backend retries. Do not prove concurrency with arbitrary sleeps or reduce existing tests to avoid failures.

Relevant commands on the base include:

- `npm run check:mobile` (l10n, Dart formatting, analyze and Flutter tests).
- Appropriate targeted editor/router/cover tests during development.
- Available Android compile/APK check for changed navigation behavior; iOS compile/device checks where supported. Clearly report unavailable native gesture/device checks rather than claiming them passed.
- If adding the ordinary creation/recovery backend contract: `npm run db:reset`, `db:lint`, `db:advisors`, `db:test`, its local-only authenticated verifier, `proposal:verify:local`, `template:apply:verify:local`, affected cover/profile/capacity checks.
- `npm run moderation:verify:local` when the shared TW03/removal regression path is affected.
- `npm run db:types` and clean committed type-drift verification; Web typecheck/tests as affected.
- `npm run format:check:web` / `git diff --check` for changed scripts/docs/types.

Run the smallest complete checks for every changed area and final-head hosted CI. Wire any new authorization/retry verifier into the actual Database job path; preserve TW02/TW03's existing hosted execution. Follow current scoped classification; do not claim skipped jobs or unavailable device checks ran.

Keep fixture data synthetic and all reset/upgrade/verifier operations loopback/local-only. No production/demo-world regeneration is needed here.

## Documentation and delivery

Document the editing-session owner, dirty/meaningful rules, first-create/retry/recovery semantics, guarded navigation types, invalid-input behavior, cover partial outcomes, snackbar delivery and forced-auth limitations in the nearest feature/router/development docs.

Update relevant folder README maps, generated types and architecture/roadmap narrowly. Mark DRAFT01 implemented; TW04/SIM01/SIM02/TW05 remain deferred. Do not rewrite unrelated implementation history or add legal retention rules.

Archive this supplied prompt **verbatim** using `history-implementations` conventions; preserve exact bytes.

Finish with the draft PR link/target, exact base/head, concise behavior summary, actual local/hosted validation and native limitations, pending founder/predecessor/main integration and confirmation that no merge/shared migration/deployment occurred. Keep the worktree clean and retained for review.

Choose routine module/UI/placement details autonomously. Surface a consequential conflict only if these agreed identity, privacy, sparse-save or recovery rules cannot be preserved. Do not stop for optional design files, credentials, starter content or unrelated hosting/moderation work.

