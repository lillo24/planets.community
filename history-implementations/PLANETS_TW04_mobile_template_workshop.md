# PLANETS — TW04: Mobile Template Workshop

Date: 5 October 2026  
Repository: `lillo24/planets.community`  
Task: implement completed-Proposal template browse, detail, reporting and creation of an independent draft in the Flutter mobile app.

## Outcome and authorized workflow

People can discover reusable templates from completed one-time Proposals, inspect their reusable content, report them, and use one to open a fresh private Proposal draft. Existing work is preserved before leaving its editor. Accepted copy retries reopen the same destination.

Implement this plan in one isolated branch/worktree, validate it, commit, push and open a **draft PR**. Keep it **unmerged** for founder review of Workshop presentation, prior-form preservation, retry recovery and automatic-inclusion copy, together with predecessor review. Do not deploy or change any shared database. This is an explicit exception to AGENTS.md's automatic-merge/default-main workflow.

The explicitly authorized dependency base is:

- predecessor: [DRAFT01 PR #135](https://github.com/lillo24/planets.community/pull/135);
- branch: `codex/draft01-save-proposal-drafts-on-exit`;
- exact base/head: `8062035a5cdc38ac016f64d125b7b4407b613063`;
- suggested task branch: `codex/tw04-mobile-template-workshop`;
- PR target: `codex/draft01-save-proposal-drafts-on-exit`.

Verify ancestry and the remote predecessor before branching. Do not alter its retained worktree. TW01 #127, TW02 #129, TW03 #132 and DRAFT01 #135 were all draft/unmerged when this prompt was prepared. Their inclusion in this approved stack is intentional; do not wait for them to merge solely because the general roadmap requires merged predecessors.

Main was inspected at `f291bdd017ba0509b4aba7e80dd655457c26c3bf`, including PI01 #128, PI02 #131 and PI03 #134. Main's participant links, native auth returns and browser joining are outside the selected base. Do not import those changes or the separate moderation/admin-hosting stack incidentally. Record the later integration checks. If predecessors have since merged, use then-current main only after verifying that all required contracts survived; document the actual base and target. Never guess a replacement base if the selected dependency changed incompatibly.

Read repository AGENTS.md, applicable nested instructions, architecture documents, nearest feature maps and current code before editing. The requirements below are self-contained; access to the founder's Google Doc or prior chat is unnecessary. Routine implementation choices are authorized within this scope.

## Product rules already settled

- Workshop v1 contains **one-time Proposals only**, publicly usable only at canonical **Completed: event end + 24 elapsed hours**.
- First publication automatically establishes one linked template identity. It is not a separate community authoring/submission/approval product.
- Reusable content comes from the canonical source and follows allowed published changes. Existing structural editing locks at event start; do not change lifecycle rules.
- Draft saves never create templates. Private pre-publication Bozza exists only for its original Creator through the private backend contract. **No Bozza/Final result toggle, baseline request, public history or outcome editor in TW04.**
- Reports, including self-reports, lead to manual staff review. Reporting does not itself hide/delete a template.
- No Creator withdrawal, community template editor, restore action, favorites, popularity ranking, comments or template chat.
- Applying creates a new independent private draft with ordinary publication gates. It never joins, publishes or overwrites another Project.
- PLANETS production starters must derive from real eligible completed sources. Do not fabricate live event history or add a standalone-example exception.
- Automatic similar-active-Project suggestions remain SIM01/SIM02. Do not insert active upcoming Projects into Workshop.
- The realistic eight-template demo world remains TW05. Use narrow synthetic test fixtures here; do not implement that seed task now.

## Verified predecessor behavior

TW01 migration `20261003125831_source_linked_proposal_template_workshop.sql` owns source-linked identity, public eligibility, explicit reusable projections, content tokens and original-Creator-private baseline. TW02 `20261003191351_template_reporting_and_removal.sql` owns typed template reporting, self-reporting, protected review context and audited removal. TW03 `20261004145334_template_to_draft_creation.sql` owns atomic copy and immutable applicant-private receipts.

DRAFT01 `20261004200147_idempotent_editor_draft_creation.sql` adds `create_editor_proposal_draft` and `recover_editor_proposal_draft` for ordinary first editor creation. These are distinct from template application and must not replace TW03.

DRAFT01 mobile behavior includes:

- a separate `proposalEditorSessionProvider` per screen/session; canonical ID binding survives a `/proposals/create` route;
- immutable raw-input acknowledgements, sparse-form save and invalid-input preservation;
- `DraftDepartureCoordinator` in `apps/mobile/lib/app/router/draft_departure_coordinator.dart`, router `onEnter` for outgoing route/tab navigation, and editor `onExit` for supported pops;
- explicit `noChange`, `saved`, `blocked`, `discarded`, `partial` outcomes;
- destination-only localized `Bozza salvata` / `Draft saved` after confirmed save, and precise partial-cover feedback;
- actor/session invalidation and process-memory creation recovery markers, without a force-kill guarantee;
- TW03-created drafts edited through ordinary owner read/update, independent of later source/template removal.

#135's final-head Validation run 37235921619 passed all jobs. Inspected logs show 3,437 pgTAP assertions, 42 DRAFT01 / 93 TW02 / 132 TW03 real authenticated assertions and 1,176 Flutter tests. Android debug compilation was reported locally; iOS compilation and native device gesture QA remain outstanding. These are predecessor evidence, not checks you have already run for TW04.

## Existing RPCs: consume their actual contracts

Use a dedicated narrow template gateway/models/state boundary following established Flutter/Riverpod/Supabase patterns. Do not load full Proposal owner objects and remove private fields client-side. Do not query private tables, use service-role credentials, or construct client-side eligibility rules.

| RPC | Contract on the approved base |
| --- | --- |
| `list_public_proposal_templates` | `p_limit` 1–50, default 20; paired `p_cursor_linked_at` / `p_cursor_id`; optional `p_skill_ids` up to 50 known non-null IDs with OR semantics; optional literal case-insensitive trimmed `p_query` up to 120 characters. Descending immutable `(linked_at, template_id)` keyset. |
| `get_public_proposal_template` | `p_template_id`; zero or one eligible detail row, exact content token and complete blueprint count. |
| `list_public_proposal_template_resource_blueprints` | `p_template_id`, exact `p_content_version`, `p_limit` 1–50, optional `p_cursor_need_id`; ascending source-need UUID; open need title/details only. `PT409` means refresh detail and restart blueprint pagination. |
| `create_proposal_draft_from_template` | Expected Creator, template ID, exact detail token, stable client-request UUID, explicit `p_prefill_capacity` boolean (default true). Returns one accepted receipt with destination ID, provenance, recommendations, time and `created`/`recovered` outcome. |
| `get_own_proposal_template_application` | Expected Creator + client-request UUID; zero or one applicant-only accepted receipt. No staff or source-Creator access to someone else's application. |

Public reads are granted to anon/authenticated; the current mobile navigation may still require a ready session. Preserve that app boundary without expanding auth scope. Unknown, non-Completed, cancelled, hidden or removed templates return zero public rows. Zero eligible rows are distinct from a network/parse failure.

Cards return template/source IDs, publication linkage time, title, summary, controlled skills, authorized source cover path, original Creator ID and current globally public display name. They do **not** contain detail's content token, description, capacity, duration or blueprints. Fetch real detail before applying.

Detail returns reusable text, controlled skill descriptors/importance, capacity recommendation, **numeric duration seconds that can be fractional**, cover path, provenance and blueprint count. Tokens use `tw01:` plus SHA-256 canonical content hash; they are opaque equality tokens, not chronological revisions or permissions.

Parse integer counts/capacity as integers and finite positive duration as numeric. Do not reject valid fractional duration, round it into a domain integer, label the token a timestamp, or fabricate absent fields. Skill importance is Required/Useful; use localized labels with the existing controlled taxonomy.

Resource previews need separate bounded pages. Keep every page associated with the detail token; never mix versions. A template with more than 50 open needs must be inspectable through pagination, and TW03 still copies the complete authoritative set. Do not claim that the first page is the complete blueprint list.

## Workshop entry and navigation

Add discoverable **Template Workshop / Laboratorio dei modelli** access within the existing Proposal Browse/Create flow. Use existing navigation, theme, spacing and accessibility patterns. Do not add a bottom-navigation branch or turn the current Proposals/Tavoli switcher into a new unrelated taxonomy.

Provide an entry from Proposal browsing and a clearly separate way to start creation from a template. An entry in the unpublished editor may open Workshop through guarded navigation; it must not prefill/replace the currently typed form.

Keep ordinary empty creation and My Proposals usable. Choose route names after inspecting the actual router; place static Workshop routes safely relative to `/proposals/:id`, and test matching directly. Route only opaque template/destination IDs, never private form text, report explanations, cover bytes or application receipts.

Opening Workshop from an active unpublished editor must use the existing DRAFT01 save-before-departure flow. Saving an unrelated form is not a template application. Use push/back-stack behavior that makes return to the preserved draft predictable.

The router already prepares departure. Avoid manually calling preparation and then triggering a second guard that consumes the save outcome and loses or duplicates destination feedback. If a small coordinator integration is needed, preserve one save/one destination notification and existing gesture/replay semantics. Do not rebuild the router around this feature.

## Catalog

- Show completed-event templates with clear past-event/reuse context; provide query and existing controlled-skill filters.
- Use a small page size within the backend cap, real keyset cursors and explicit Load more or the established bounded paging pattern.
- Debounce text input using the existing search approach; query/filter changes reset pages, cursor and result generation.
- Ignore old responses after query/filter/account/route changes, including while a prior page is loading. A busy flag must not silently lose the newest filter request.
- Deduplicate template IDs when appending; stable linkage order is not popularity or event-completion order.
- Distinguish first loading, genuinely empty catalog, no filter matches, first-page failure and load-more failure with retry.
- Refresh/re-entry must revalidate availability rather than permanently reuse a removed card. Preserve useful scroll/filter state where consistent with existing navigation.
- Do not show active join controls, occupancy badges or participant counts on template cards. No locality/date filter is available in this RPC; do not imply otherwise.
- Treat `linked_at` as first publication time. Do not present it as the event date or completion timestamp.

## Detail and source presentation

Show title, summary, description, skill importance, reusable resource-need text, optional recommended capacity, duration guidance and safe provenance. Make **Use template / Usa modello** the primary action, with a separate template Report entry.

Use honest copy such as “From a completed Proposal” and “Start a new draft.” Canonical Completed is elapsed time, not a verified success/result or attendance claim. Do not invent old event dates, venue, verified outcomes or PLANETS ownership.

Creator attribution uses only `creator_display_name` when globally public; use a localized neutral fallback when null. An exposed Creator UUID is not permission to fetch contextual names/photos. Workshop has no profile-photo payload; do not call source-context photo APIs or retain old names as permanent attribution.

Use the canonical source cover path through the existing authorized `cover-images` download/presentation pipeline and a fallback when missing/unreadable. Do not turn private storage into public URLs, invent privileged signed delivery, or copy the cover to the destination. Template removal does not revoke an independently public source's authorization to that same image; do not promise otherwise.

On confirmed unavailability, clear actionable stale detail/blueprints/cover presentation and disable new use/report attempts. On network failure, show a real error/retry state; do not relabel it as removal. Revalidate on return/resume/refresh using established lifecycle patterns. No continuous polling or instant cache-revocation promise is required; authoritative apply/report gates still enforce races.

A separate **View source Proposal** link may use the ordinary source detail route and its own authorization. Keep it visibly distinct from using the template; source visibility or participation rules must not be bypassed. Never infer that a completed source is joinable.

Blueprint paging must show loading/error/continuation states and the authoritative total. If an eligible page returns `PT409`, invalidate all old blueprint pages, refresh detail, and ask the user to review the new preview before use. Detect inconsistent totals/duplicate pages rather than silently marking a truncated list complete. This does not authorize an unbounded client download or changes to historical operational resource reads.

## Apply, recover and open the ordinary editor

Offer an editable **use recommended capacity** choice when a valid recommendation exists, defaulting to TW03's true behavior. Explain that it is an editable suggestion. No recommendation means no fabricated capacity. Duration is guidance only; preserve its numeric value for display/receipt handling without populating old or newly invented event instants.

Before the first mutation, freeze one application attempt: actor ID, template ID, detail content token, capacity choice and fresh request UUID. Disable/coalesce duplicate taps and keep that same immutable tuple through timeouts, read failures, retry and accepted-but-not-opened navigation.

Call `create_proposal_draft_from_template` once per attempt through the authenticated gateway. The server atomically creates the parent, skills, all fresh need IDs and private receipt. Do not locally stage a parent or loop over blueprint pages to create needs; a partial preview does not truncate server copying.

Application requires a complete profile on first acceptance, but no publication photo gate. Let the normal app/backend enforce profile readiness. An ordinary draft can remain photo-free; publishing later keeps its existing profile-photo, schedule, capacity and authority requirements. Do not add a photo requirement to Use template.

The accepted destination has:

| Field | Required behavior |
| --- | --- |
| Title/summary/description, skills/importance | Authoritative reusable content, editable in the ordinary draft. |
| Open resource blueprints | Fresh ordinary needs with fresh IDs; no source fulfillment/coverage copied. |
| Registration capacity | Recommendation only when chosen; normal editable field. |
| Organizer capacity policy | Ordinary default Off. |
| Dates/timezone/location/meeting data | TW03 resets logistics; ordinary editor defaults/fresh user input. No source venue or instants. |
| Cover | Blank destination by default. |
| People, authority, membership, invites, chat, workspace, contributions | Not copied. Current applicant is the new Creator. |
| Source/token/application receipt | Private immutable provenance, not public usage/attribution history. |
| Bozza baseline or moderation records | Never requested or copied. |

After acceptance, bind the returned destination immediately, refresh My Proposals as appropriate and open the **existing Proposal editor by that ID**. If opening or owner rereading fails, retain the accepted ID and offer Open/Retry; do not reapply to solve an editor-read failure. Read current owner content when reopening, so later edits/publication are never replaced with original template values.

Lost-response recovery must survive Workshop screen disposal/navigation within the running app, scoped to the applicant. Reuse the established process-memory opaque-marker pattern or an equally narrow state owner. Store no raw form, resource text, address, cover bytes or full receipt in plaintext preferences/telemetry. Confirmed drafts remain available through ordinary My Proposals after process restart; do not promise unimplemented durable attempt recovery.

For an uncertain attempt, check its private receipt and/or exactly replay the frozen original command. **The TW03 receipt getter does not wait on the application advisory lock: an empty read can race an in-flight transaction and is not proof that it cannot still commit.** Exact command retry serializes/rechecks server-side. Never rotate a request UUID or switch template/token/capacity because a receipt read was momentarily empty.

The accepted-receipt contract remains valid after template removal, source visibility/content changes or profile incompleteness. Preserve the mobile app's existing readiness/setup navigation; resume access when the app permits it, without treating the accepted attempt as a new copy. Do not require current public detail to reopen that private destination. When a fresh public attempt is definitively rejected as stale (`PT409`), refresh preview and obtain a new deliberate application intent; do not silently apply changed content. On `42501`, distinguish identity/profile readiness from unavailable template through existing authenticated state and revalidation. Incompatible-key `22023` is an error, not a reason to fabricate success or guess the newest draft.

A later deliberate **new** Use action may create another independent draft, but retry/open of a pending or accepted attempt must never do so. Make that distinction explicit in state and UI rather than disabling legitimate future reuse forever.

Before creating a template destination, ensure any active unpublished editor has completed DRAFT01 preparation; blocked invalid/failed input means no new application yet. An editor already preserved when entering Workshop needs no duplicate write. A retained offstage or nested editor keeps its own canonical ID/session. Never load the new template into its controller, replace typed text, delete its saved draft or confuse Back navigation with a new creation.

Publication/removal of the source after acceptance cannot block ordinary destination editing. DRAFT01 must save its later edits by destination ID, with unchanged application provenance and fresh need IDs. Forced account changes drop old UI callbacks/recovery access and never navigate or notify the next actor. An already-authorized server transaction may commit for its original actor; do not attempt cross-account cleanup.

## Reporting and automatic-inclusion explanation

Wire template Report through the existing `proposalTemplateReportTarget(templateId, label)` and `ModerationRoutes.openReport`. Report the template identity, not the source Project. Preserve the shared category/explanation form, submission retry behavior and manual-review notice.

Show Report for the original Creator too; TW02 explicitly permits template self-reports. Do not add a Creator withdrawal/delete control, claim report acceptance removed the template, or expose staff removal reasons/audit/private Bozza. Existing My Reports remains the receipt/status surface.

Unavailable new reports must show the real error; accepted report retries retain their existing server semantics. Returning from reporting should revalidate Workshop detail without erasing an accepted template-application destination.

Add concise Italian/English explanatory copy near Proposal publication: eligible published content later becomes a reusable template when the event reaches Completed, and people can reuse its text, skills and open resource-need descriptions. This explains automatic behavior; it is not an opt-in checkbox, separate submission or approval step. Do not imply structured allow-lists automatically anonymize arbitrary free text.

## Implementation boundaries

Prefer a dedicated mobile feature boundary for Workshop gateway, models, controllers, routes/screens and tests. Reuse controlled skills, authorized cover rendering, shared report UI, ordinary editor and departure coordinator through their existing interfaces. Choose concrete names after inspecting patterns.

Backend behavior is already available. Do not change eligibility, locks, atomic-copy semantics, receipts, private baseline access or reporting permissions to simplify UI. If an actual incompatible contract is found, report exact evidence and complete independent authorized work; do not invent a broad backend redesign. A minimal additive correction necessary for this flow may be implemented with a new migration and complete affected checks, clearly documented.

No new provider, embedding service, scheduler, production polling, hosting work, credential setup, shared seed, deployment or store submission is part of TW04. No public web Workshop parity is required.

## Acceptance evidence

Add meaningful tests of the new behavior, using existing fakes plus real local authenticated contracts where appropriate. Include:

1. Browse/Create entry routes resolve to Workshop; static routes do not become Proposal-ID details; ordinary create/My Proposals/Tavoli/navigation stay intact.
2. Query/skill filter payload bounds, literal/OR semantics, cursor pairs, multi-page deduplication, loading/no-results/error/retry and newest-query wins while a request is pending.
3. Cards contain only allowed fields; private attribution fallback, no contextual photo reads, missing/failed cover fallback and no public baseline call.
4. Exact detail loads before application; numeric fractional duration remains valid; capacity preference true/false and absent recommendation behave correctly.
5. More than 50 resource blueprints can be inspected in bounded pages; `PT409` resets detail/pages; total inconsistency or read failure is visible, never disguised as complete.
6. Double tap and lost response use one frozen request; an empty receipt during delayed commit leads to exact replay, not a new request.
7. Accepted-but-not-opened state recovers the same destination after leaving/reopening Workshop; owner-read failure does not recopy; later owner edits/publication remain authoritative.
8. An accepted copy reopens after template removal/source change through its private receipt; profile-readiness changes preserve accepted recovery while respecting setup routes. A genuinely new unavailable attempt is rejected. Definitive stale content requires refreshed review.
9. Copy uses TW03, including all needs beyond the visible preview; fresh IDs and reset logistics/cover/people are unchanged.
10. Dirty sparse editor → Workshop saves once before arrival and shows truthful destination feedback; return restores the same draft. Invalid input/save failure prevents departure/new copy until corrected or explicitly discarded.
11. Applying from Workshop opens a separate editor session; nested/retained old editors are not overwritten. Back, tabs/Home, rapid navigation and cover-partial outcomes retain DRAFT01 behavior without duplicate preparation/toasts.
12. Newly created template draft saves later edits through DRAFT01 after source removal without changing provenance or needs.
13. Ordinary report and original-Creator self-report use `proposal_template`; category/explanation/manual review remain intact; report acceptance does not hide content or expose staff context.
14. Removed/unavailable detail clears use/report/cover presentation on revalidation; network failure remains distinct. A source link uses ordinary source authorization.
15. Account switch or access loss during list/detail/apply/recovery ignores stale callbacks and leaks no private destination, form or success feedback to the next account.
16. Italian/English localization parity, light/dark theme, large text, screen-reader action labels, small-screen scrolling and publication explanation are verified.

Keep tests focused on contracts, races and user outcomes. Do not weaken predecessor assertions or replace meaningful authorization checks with UI visibility tests. New fixtures must be synthetic and local only.

Run Flutter localization generation, formatting, analysis and the complete existing mobile test suite using repository commands. Run available Android compilation; run iOS/native gesture checks only in a supported available environment and report missing environments precisely. Widget tests do not complete native device QA.

If this remains mobile/docs-only, preserve change-scoped hosted validation; Database/Web/Site may legitimately be skipped by current classification. Do not claim those jobs ran. Exercise the established template/report/application/DRAFT01 authenticated verifiers on an isolated loopback disposable stack for the integration seam when available; this does not require unrelated CI expansion.

If backend, generated types, root tooling or CI changes are necessary, run every affected replay/lint/advisor/pgTAP/authenticated verifier/type-drift/Web check and ensure actual hosted commands execute. Preserve existing TW02, TW03 and DRAFT01 API steps. Do not broaden CI or rewrite test fixtures simply to report higher totals. Reuse passed checks unless a new edit/failure justifies rerunning.

Use a small real local smoke journey, documenting browse → detail → report/self-report → use → owner editor → departure/reopen and accepted retry/unavailability. If runnable mobile-to-local-backend smoke is unavailable, distinguish inspected backend verifier + widget evidence from a real integrated journey and provide the precise remaining procedure.

## Documentation, review and completion

- Archive this exact supplied prompt under `history-implementations`, preserving its content.
- Update the Workshop feature README/map, Proposal/publication map, router map, `docs/development/template-workshop.md` and roadmap where behavior changed. Preserve DRAFT01's contract documentation.
- Mark TW04 implemented on its draft branch; leave SIM01, SIM02 and TW05 deferred. Do not label the whole feature merged/production-ready.
- Record parsing, pagination/version reset, attempt recovery lifetime, template-only reporting, cache revalidation and later main integration boundaries.
- Review the diff, commit only intended files, push and open the required draft stacked PR. Retain the clean checkout for founder review; no merge/deployment is authorized.
- Report exact base/head, branch/target/PR, checks actually run and CI at the final head, skipped jobs, native QA limitations and any concrete blocker.
- State founder review items: Workshop entry/detail and past-event language, preservation of prior forms, accepted retry/open versus new-copy behavior, self-report flow and automatic-inclusion explanation.
- Later predecessor/main integration must reconcile #128/#131/#134 participant links/auth returns/browser joining with guarded outgoing navigation and independent draft creation, without replacing either flow.

Complete the authorized mobile implementation and its reviewable PR; do not stop after a plan or request routine reconfirmation.
