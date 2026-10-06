# PLANETS — TW03: atomic template-to-draft creation

Date: 4 October 2026

## Objective

Implement the third Template Workshop plan in `lillo24/planets.community`.

An authenticated person can use an available completed Proposal template to create one fresh, independent, private Proposal draft. Copy reusable text, controlled skills and all open resource-need blueprints atomically. Reset event logistics, people and operational state. An ambiguous retry must recover the same draft, including after template removal or later source changes, without overwriting subsequent edits.

This task is backend-first. Workshop screens belong to TW04; editor save-on-exit belongs to DRAFT01. Include two narrow inherited TW02 corrections described below because the new copy/removal contract must be continuously verifiable.

## Exact dependency base and draft PR workflow

Repository evidence checked on 2026-10-04:

- Current `main`: `996f019f19f9fc3f661c388c30cb01d966e64d37`, including merged participant-invite PR #128.
- TW01 #127 remains open, draft and unmerged, head `342af7603f8f34b987d11073147cd5549d4b012c`, target `main`.
- TW02 #129 remains open, draft and unmerged, head `b778445550e49c08395e67c8852d649ead333821`.
- TW02 branch: `codex/tw02-template-reporting-removal`, targeting `codex/tw01-source-linked-template-domain`.
- TW02 base: exact TW01 head above.
- Hosted Validation #37188652377 passed Database, Web and Mobile at TW02's stated head; Site was skipped.
- #123/#125/#126 remain a separate draft moderation stack, outside the template dependency base.

Links:
- https://github.com/lillo24/planets.community/pull/127
- https://github.com/lillo24/planets.community/pull/129
- https://github.com/lillo24/planets.community/actions/runs/37188652377

**This prompt explicitly selects TW02 head `b778445550e49c08395e67c8852d649ead333821` as the permitted predecessor base while #127/#129 remain unmerged.** This overrides the normal merged-predecessor sequencing requirement for this task.

Before editing, recheck PR/base state and repository instructions:

1. If #129 remains at that unmerged head, create one isolated branch/worktree from that commit. Suggested branch: `codex/tw03-template-to-draft-backend`. Open a **draft stacked PR targeting `codex/tw02-template-reporting-removal`**.
2. If both predecessors have merged, use latest `main` after verifying their effective contracts. Open a draft PR targeting `main`.
3. If the predecessor has changed through integration or corrective work, inspect that change and verify the applicable contract before selecting its updated head. Do not adopt a materially changed product/privacy policy silently.
4. Do not modify another task's branch, merge/retarget the predecessor PRs, import the separate moderation stack, or merge TW03 automatically.

The specified base lacks #128's participant-invite changes. Do not import them incidentally. At later main integration, preserve their canonical admission, retry, capacity and membership-origin rules, and verify that template creation inherits no source invite or invitation membership. Read actual current main contracts before that integration.

This downstream task does not resolve TW01/TW02 founder review. Keep TW03 draft and unmerged for review of atomic copying, private provenance, retry semantics and removal concurrency. The active draft/manual-review requirement overrides AGENTS.md's default automatic merge.

## External context and accepted scope

This prompt is self-contained. No Google Doc, design dump, credential or external production service is required. Read the repository first; it is the source of truth for implemented behavior.

Accepted product rules:

- Proposals only; Tavoli are deferred.
- Publication automatically establishes one linked template identity. There is no independent template editor, submission, opt-in or approval workflow.
- New template use requires current canonical public availability and Completed at `ends_at + 24 hours`.
- The same linked identity follows allowed source changes. Published structural editing still locks at source start.
- Completed means elapsed time, not verified attendance or success.
- Bozza is private original-Creator history. Do not read or copy it when applying a template.
- The new draft belongs solely to the applying person, even if that person is the source Creator.
- Applying creates a new activity draft. It does not join the source Project or chat.
- Reporting remains manual review; staff template removal prevents new use.
- A successful earlier copy remains independent after source edit, cancellation, loss of availability or template removal.
- No Creator withdrawal, restoration, public transformation toggle or post-event outcome editor.
- No public template-use counts or derivative attribution policy is introduced by this task.

## Inspect existing owners and contracts

Read root/nested AGENTS.md, `implementation_plan_sections_suggestions.md`, relevant architecture/roadmap sections and `docs/development/template-workshop.md`.

Inspect the effective functions after all migrations, not only their first definitions.

Relevant implemented boundaries:

- `20261003125831_source_linked_proposal_template_workshop.sql`: template identities, immutable private baseline, shared `private.is_proposal_template_publicly_usable`, canonical reusable payload and `tw01:` SHA-256 content tokens.
- `20261003191351_template_reporting_and_removal.sql`: typed reports, template-only self-report, staff review and `remove_moderation_case_template`.
- Removal locks source `public.proposals`, then `private.proposal_templates`, then its moderation case. The copy command must use the same source/template order and recheck after waiting.
- `private.proposal_template_reusable_content` returns sorted controlled skills and the complete open need collection. Public detail/pages intentionally do not return the full collection at once.
- `create_proposal_draft` and `private.replace_proposal_content` own ordinary draft initialization/validation.
- `20260930140814_organizer_aware_capacity_headcount.sql` provides the current capacity-aware draft overload, `registration_capacity` and `count_organizers_toward_capacity`.
- Proposal insertion creates the shared `public.projects` anchor through canonical registration triggers.
- `20260915090235_project_resource_needs_domain_foundation.sql` and later effective functions own ordinary draft need mutation, validation, source/Project locks and identifier-only need events.
- Normal draft creation requires the canonical complete-profile identity gate. Photo is required at publication, not ordinary draft creation.
- `get_own_proposal` / own-resource-needs reads and the current editor must consume the resulting draft through existing contracts.
- `apps/web/src/types/database.generated.ts` is generated; update it through the repository generator.

Preserve profile-photo/publication safeguards, capacity/social-headcount rules, source visibility, blocking, role consent, private chat/workspace boundaries, audit/outbox conventions and any restrictions canonical on the actual authorized base.

## Two narrow TW02 corrections included here

### Numeric duration parsing

TW01 defines `duration_seconds numeric` and calculates `extract(epoch from ends_at - starts_at)`. Valid timestamptz schedules can yield fractional seconds. TW02's `apps/web/src/features/moderation/template-moderation-models.ts` currently parses this field with its nonnegative safe-integer helper.

Fix the duration parser to accept the valid finite positive numeric domain without rounding the backend payload or changing its content token. Keep capacity and blueprint counts integer-validated.

Add a focused regression for a valid duration such as `7200.001`, plus invalid/nonfinite/zero/negative duration cases. Verify that the staff review surface can handle such a valid payload. Do not change publication time precision or impose a whole-second policy.

### Actual hosted API validation

At TW02's inspected head, `.github/workflows/validation.yml` does **not** invoke `npm run moderation:verify:local`. The 93 TW02 authenticated API checks are reached by that command, but not by the existing hosted Database job's Proposal verifier. TW02's docs/script comments incorrectly describe them as hosted coverage.

Wire the existing moderation verifier and the new TW03 authenticated verifier into the actual scoped Database validation path. Use a clear existing command or explicit job step, and confirm execution in final-head job logs.

Correct the documentation/comments to distinguish TW02's reported local API results from what its historical hosted run actually executed. Do not retroactively claim the missing checks ran at the old head.

Keep this a focused coverage correction. Do not weaken checks, redesign CI, remove regression tests, or broaden unrelated path filters. If the current classifier runs other areas because the workflow itself changed, follow that existing classification.

## Canonical apply command

Add one narrow authenticated RPC for creating a Proposal draft from a template. Choose its name and storage layout using the repository conventions; document the complete contract.

Required input semantics:

- expected current applicant/Creator profile ID;
- template ID;
- exact content token shown by the caller's preview;
- a client-generated UUID identifying this explicit create action;
- an explicit capacity-prefill choice, if offered.

Do not accept a client-supplied content payload, source Creator, source need IDs to transplant, arbitrary source ID, destination Project, publication flag or existing draft to overwrite.

Use a documented conservative capacity default: prefill the source's valid registration-capacity recommendation by default, with an explicit option to leave it unset. A legacy null recommendation remains null. Bind this option into retry identity. Organizer counting always begins with the ordinary default Off.

The command must:

1. Establish current expected authenticated identity and applicable canonical account/private-access restrictions.
2. Validate bounded inputs and bind the request key to the applicant and immutable create intent.
3. Recover an already accepted exact request before requiring the source/template to remain available.
4. For a first creation, require the ordinary complete-profile draft-creation gate.
5. Resolve template/source on the server, acquire source then template locks, and recheck current identity/restrictions and canonical eligibility after any wait.
6. Capture one complete canonical reusable payload after locking; calculate and compare its token with the supplied preview token.
7. Create the new ordinary private draft, skills, fresh open needs and immutable private application provenance in one transaction.
8. Return a narrow receipt sufficient to open the existing editor and recover retries.

Unavailable/unknown/pre-Completed/cancelled/removed/source-ineligible templates must create nothing. A token mismatch on an otherwise eligible first application must fail clearly, preferably using existing `PT409`, so the caller can refresh and deliberately confirm again.

A token is a content identifier, not authorization. Do not treat holding it as permission or change TW01's token formula to accommodate selected copy options.

## Exact copy and reset rules

| Field/state | New draft behavior |
| --- | --- |
| Title, summary, description | Copy the canonical published reusable text, within ordinary draft validation |
| Controlled skills | Copy IDs and Required/Useful importance; retain live controlled catalog semantics |
| Open source resource needs | Copy every blueprint's title/details into a new open need with a fresh UUID |
| Closed source needs | Omit |
| Registration capacity | Apply the explicit prefill choice; preserve a valid recommendation or null |
| Organizer counting toggle | Off, irrespective of the source setting |
| Duration | Return/retain a recommendation for later editor use; do not generate event dates |
| Dates, timezone, country/locality, rough location and public location label | Unset; no old logistics or invented location defaults |
| Exact meeting text/coordinates | Unset; ordinary new-draft privacy defaults |
| Source cover | Preview remains source-authorized; new draft has no inherited cover path/object |
| Creator | Current applicant; no source ownership/delegation transfer |
| Participants, pending requests, roles, role offers and invitations | None inherited |
| Chat, messages, attendance and membership history | None inherited; normal new-draft domain behavior only |
| Workspace/Drive links and operational notes | None inherited |
| Resource listings, offers, selections, commitments, coverage and actual contributions | None inherited |
| Lifecycle/publication/cancellation timestamps | Fresh draft; unpublished and uncancelled |
| Private Bozza, reports, staff reasons and removal records | Never copied |

Source need IDs are provenance at most, never destination identities. Do not recreate fulfilled/closed needs or infer taxonomy, quantity, pricing or contribution semantics from plain text.

A new Creator may normally contribute one organizer/social-headcount identity. Derive fresh capacity/headcount through the ordinary domain; do not force all counts to zero merely because memberships were not copied. Organizer counting Off means that Creator does not consume a registration slot.

Do not clone `public.projects` wholesale. Initialize its anchor and policies through ordinary creation so future schema additions cannot silently inherit source operations.

Copy the full canonical collection inside the transaction, including more than one public page of needs. Do not reconstruct the draft from whatever paginated subset the UI happened to load.

Keep the captured payload consistent across text, skills, needs, capacity and duration. Build destination writes from that captured state; do not recompute different parts after source/catalog changes. Use existing validation/helpers without bypassing policy. If internal bulk insertion is necessary, preserve the resulting resource-need semantics and audit/outbox behavior.

## Atomicity, concurrency and independence

Use the TW02 lock contract: source Proposal before template, held until the copy transaction commits or rolls back. Keep request advisory-lock namespaces separate from source/moderation/profile lock namespaces. Preserve any earlier canonical profile/restriction locks on an integrated base.

Define and test the two ordered outcomes:

- Copy gets source/template locks first and commits: one independent draft exists; removal can then complete and close further new use.
- Removal gets those locks first and commits: a later first application fails eligibility and creates nothing.

Recheck state after waiting. Do not use a pre-wait eligibility result, stale `statement_timestamp` assumption, or client preview as the final authority.

Changes to reusable content before the locked snapshot must produce a token conflict. A snapshot accepted by the transaction must not mix old text with newer needs. Source visibility or applicant restrictions acquired on a later integrated base must participate in the same effective checks.

Any failure during draft, skills, need, provenance, receipt or required event/audit writes rolls everything back. No partial draft or half-copied resource list may survive.

After successful copying:

- source changes/removal do not update or delete the derived draft;
- editing the derived draft does not write to the source/template;
- publication still requires the applicant's ordinary profile/photo/content/schedule/capacity gates;
- the derived Proposal gets its own template identity only at its own first publication through TW01's normal trigger;
- any baseline captured then is that new Creator's saved pre-publication draft, not the source Creator's private Bozza.

Do not loosen source structural locks to manufacture test updates after Completed. Trusted local timestamp/content adjustments used by concurrency tests must stay explicit and synthetic.

## Idempotency and private provenance

Persist an identity-bound creation receipt and immutable provenance containing at least applicant, request, new Proposal, source/template IDs, accepted content token, options and acceptance time. Retain the accepted capacity/duration recommendations if needed for truthful retry/editor handoff.

- Same applicant + same request + same immutable intent returns the same draft/receipt.
- Changing template, preview token or copy options under the same accepted request key fails explicitly.
- Concurrent duplicate delivery creates one draft, one set of needs and one set of required audit/event effects.
- The same request UUID from a different applicant is a separate identity scope and never reveals another applicant's receipt.
- An accepted exact retry still recovers the original draft after template removal, source changes or source availability loss.
- If the applicant edits or publishes the draft, retry does not replace text, reopen it, recreate needs or restore initial state.
- A fresh explicit action with a new UUID may create another independent draft; avoid permanent one-draft-per-user/template deduplication.
- Check current identity and applicable private-access restrictions before receipt recovery. An old key cannot bypass an account restriction.
- If an actual existing discard/delete path makes the resulting draft unavailable, return a truthful recoverable/unavailable result under that contract; never resurrect it or create a replacement on retry.

Keep provenance/receipts private to the applying Creator through narrow authorized access. No anonymous reads, raw client table access, staff exception, global derivative graph, source-creator “who used my template” list or public usage count.

Do not store immutable source display names/profile photos or report reasons in provenance. Do not create a separate full source revision archive. The independent draft itself contains the accepted copied content.

Use the repository's retention/deletion conventions; do not introduce broad account-retention policy or source-to-derived cascading deletion.

Return a documented receipt with new Proposal ID, accepted source/template/token, recommendation/option values needed by the later UI and a truthful created/recovered outcome. Owner reads must expose the current edited draft, not an initial snapshot pretending to be current.

## Security, events and migration discipline

- The new RPC is authenticated only, with expected-identity checks and hardened search path. Internal projection/copy helpers authorize no standalone client access.
- Private application/receipt tables use RLS and explicit revoked raw privileges, consistent with the base; no service-role browser workaround.
- Preserve ordinary owner-only draft/needs/editor reads and existing published read policies.
- Creating a private draft exposes no new template/public Proposal and sends no publication, participant, matching or source-member notification.
- Preserve ordinary identifier-only resource/audit/outbox effects where necessary; do not log copied text, skill labels, need details, private snapshots or profile identifiers beyond existing approved conventions.
- New retries produce no duplicate event/audit effects.
- Add a forward migration. Do not rewrite TW01/TW02/applied migrations or fabricate applications for existing templates.
- Existing templates, reports/removals and legacy baselines remain unchanged by upgrade.
- Regenerate public types and update relevant RPC-security/verifier inventories.
- No shared/staging/production migration/reset/backfill, deployment, credentials or provider configuration.

## Acceptance tests and validation

Use real authenticated API and overlapping database transactions as well as structural/security tests.

Required evidence:

1. Another eligible authenticated profile and the source Creator can each apply an available completed template; each new draft has the applicant as sole Creator.
2. Exact title/summary/description and controlled skill importance copy correctly. All open needs, including more than 50, copy with fresh IDs; closed needs do not.
3. Capacity prefill on/off/null works; organizer counting stays Off and fresh headcount follows the normal Creator rules.
4. No schedule, timezone, location, meeting details, cover, people/roles/invites/chat/workspace/contribution/private-baseline data leaks into the draft.
5. Duration recommendations preserve valid fractional values. The corrected staff parser accepts them and rejects invalid/nonfinite values without weakening integer count checks.
6. Unavailable/pre-Completed/cancelled/removed/unknown/source-ineligible templates create no records/events. Test the exact Completed boundary.
7. Wrong identity, anonymous calls, incomplete-profile first creation, forged input and any current canonical restriction fail safely.
8. Profile-photo-free ordinary draft creation remains allowed, while publication still fails its ordinary photo gate.
9. Stale preview token fails before any writes; coherent refreshed application succeeds.
10. Concurrent identical requests and timeout/retry recovery create one draft/set of needs/provenance/effects. Incompatible accepted request reuse fails.
11. Accepted retries after removal/source change and after applicant editing/publication recover the same result without modifying it.
12. New request ID creates a second independent draft; another account cannot read/recover the first account's receipt.
13. Test both copy-first and removal-first transaction outcomes using controlled lock barriers, including a wait followed by fresh eligibility/token checks.
14. Inject failure after partial destination writes and in a required receipt/event write; all new rows and effects roll back.
15. Source and derived edits are independent; source removal leaves an accepted draft usable by its owner. New publication creates its own template identity/baseline through ordinary gates.
16. Existing TW01 public/baseline privacy and TW02 reporting/removal/retry/authorization behavior remain intact.
17. Replay/upgrade preserves existing ordinary drafts, reports, removal attribution and baseline records; no historical apply receipts are invented.
18. Future main integration preserves #128's participant-invite semantics and no source invitations appear on a derived draft.

Use a local-only verifier with synthetic identities, loopback API/database/mailbox guards and deterministic coordination. Avoid fixed sleeps as concurrency proof or production credentials.

Relevant established commands include:

- `npm run db:reset`, `npm run db:lint`, `npm run db:advisors`, `npm run db:test`.
- `npm run proposal:verify:local`, `npm run moderation:verify:local`.
- `npm run moderation:corroboration:verify:local`, `npm run moderation:counterstatement:verify:local` where the shared regression paths are affected.
- `npm run project:resource-needs:verify:local`, `npm run project:capacity:verify:local`, `npm run cover:verify:local` as affected.
- Existing TW01 backfill and TW02 forward-upgrade rehearsals, adapted only where the new migration makes that necessary.
- `npm run db:types` and the clean committed generated-type drift check.
- `npm run check:web`, `npm run format:check:web`, `git diff --check`.
- The new TW03 authenticated copy/removal verifier.

Run change-scoped checks and actual final-head CI. Database must execute TW02 and TW03's authenticated verifiers, not only structural pgTAP. Inspect logs for that execution and report exact counts/outcomes. Follow the current classifier for other jobs; do not claim skipped Mobile/Site/device builds ran.

If no Flutter/platform files change, native builds are not required solely because this backend contract will later have a mobile consumer. Do not expand this plan into mobile Workshop screens to make a job run.

## Documentation and final deliverables

Update `docs/development/template-workshop.md` with the exact RPC/input/receipt/error contract, copy/reset table, retry behavior, actor permissions, private provenance, removal lock order, upgrade behavior and validation evidence. Document current content-token limitations and fractional-duration semantics.

Correct the inherited TW02 hosted-coverage statement and script comments without rewriting historical results. State what ran locally at #129 and what now runs in CI.

Update nearest source-folder maps, relevant security/database docs, generated types and roadmap narrowly. Mark TW03 implemented; DRAFT01/TW04/SIM01/SIM02/TW05 remain deferred.

Archive this supplied prompt **verbatim** using `history-implementations` conventions; preserve its exact bytes.

Finish with the draft PR link/target, exact base/final head, changes, tests/CI counts and limitations, pending manual review/integration, and confirmation that no merge/shared migration/deployment occurred. Keep the worktree clean and retained for review.

Choose routine internal implementation details autonomously. Surface a concrete consequential conflict only if these agreed privacy, creation, retry or removal semantics cannot be preserved. Do not stop for optional design files, production content, credentials, unrelated hosting work or an unimported moderation stack.

