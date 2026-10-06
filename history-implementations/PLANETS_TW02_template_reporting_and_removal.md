# PLANETS — TW02: template reporting and audited staff removal

## Task and outcome

Implement the second Template Workshop plan in `lillo24/planets.community`.

Users must be able to report a publicly available Proposal template, including a template linked to their own Proposal. Reports enter the existing manual moderation queue. Authorized staff can review the template and remove it from Workshop availability with a protected, attributable reason and audit trail.

Removal applies to the template identity. It does not cancel, hide or delete the source Proposal, remove an independently created Project, delete a cover object, or expose the private Bozza baseline.

Implement the backend, minimal shared mobile reporting support and the removal control in the existing dynamic admin web app. Keep the Workshop browse/detail/apply screens for TW04 and draft creation for TW03.

## Dependency base and PR instructions

Repository evidence checked on 2026-10-03:

- Current `main`: `92d93ca5a455ab853df8bc34b66fd8d69f4fb341`.
- TW01 is draft PR #127: https://github.com/lillo24/planets.community/pull/127.
- Its branch: `codex/tw01-source-linked-template-domain`.
- Its reviewed head: `342af7603f8f34b987d11073147cd5549d4b012c`.
- Final-head Validation run #37144459007 passed Database and Web; Mobile and Site were skipped.
- The separate moderation stack remains open and draft: #123 / #125 / #126. It is not part of TW01's base.

**This prompt explicitly selects TW01's exact head as the permitted predecessor base while #127 remains unmerged.** This is the alternative-base exception to the repository's normal merged-predecessor rule.

Recheck repository and PR state before editing:

1. If #127 remains unmerged at the stated head, create one isolated TW02 branch/worktree from that commit. Suggested branch: `codex/tw02-template-reporting-removal`. Open a **draft stacked PR targeting `codex/tw01-source-linked-template-domain`**, clearly identifying #127 as its predecessor.
2. If #127 has already merged unchanged, start from latest `main`, verify that TW01's contracts are present, and open a draft PR targeting `main`.
3. If the predecessor has changed materially, inspect the changes and reconcile before implementation. Do not silently adopt an incompatible public/privacy contract.
4. Do not merge #127, merge/import the separate moderation stack, rewrite another task's branch, or automatically merge TW02. Retargeting/rebasing after predecessor merge must preserve an isolated TW02 diff.

This prompt authorizes downstream implementation on the explicit base. It does not resolve #127's outstanding founder review of historical public content, reusable fields or private Bozza capture/access.

The draft/manual-review requirement overrides any default auto-merge instruction in AGENTS.md. Keep code review and shared/production deployment separate.

## Self-contained product decisions

No external design document, credential, Google Doc or production service is required.

The agreed product rules are:

- Workshop v1 contains only completed one-time Proposals; Tavoli are deferred.
- First publication automatically establishes one linked template identity. There is no submission, opt-in, independent template authoring or approval workflow.
- Public Workshop availability begins at canonical Completed: `ends_at + 24 hours`. This is elapsed time, not a claim that the event actually succeeded.
- Allowed source updates project into the same template; no independent editable template copy.
- The last saved pre-first-publication Bozza is private to the original Creator. It is not a public template, moderation evidence, staff-readable history or a v1 toggle.
- Users, including the original Creator, may report a template and explain the concern.
- Reporting does not automatically remove anything. Staff make the decision manually.
- There is no Creator withdrawal button. Self-reporting must not become automatic withdrawal.
- Template removal is distinct from source Project moderation.
- Independently created drafts/Projects remain independent; no retroactive cascading removal.
- New use of a removed template must be unavailable. TW03 will implement the atomic copy command using this removal contract.
- Do not add restoration/appeals policy, automatic sanctions, template popularity, voting or new notification categories.

## Inspect the real repository before editing

Read root AGENTS.md, applicable nested instructions, `implementation_plan_sections_suggestions.md`, and relevant architecture/development/roadmap documentation.

Important existing owners and contracts on the inspected base:

### TW01

- `supabase/migrations/20261003125831_source_linked_proposal_template_workshop.sql`.
- `docs/development/template-workshop.md`.
- `private.proposal_templates`: one unique `source_proposal_id`, immutable identity/original Creator/link time, nullable `removed_at`.
- `private.proposal_template_baselines`: immutable private title/summary/description/skills baseline. Raw access is revoked, including from client `service_role`.
- `private.is_proposal_template_publicly_eligible`: canonical source visibility + published one-time Proposal + Completed + template `removed_at is null`.
- `private.proposal_template_reusable_content` and `private.proposal_template_content_version`: sorted, allow-listed canonical content and `tw01:` SHA-256 content token.
- Public RPCs: `list_public_proposal_templates`, `get_public_proposal_template`, `list_public_proposal_template_resource_blueprints`.
- Private-history RPC: `get_own_proposal_template_baseline`, authenticated original Creator only.
- Blueprint reads reject a stale content token with `PT409`; unavailable templates return no rows.
- `supabase/tests/110_proposal_template_workshop_structure.test.sql`, `111_proposal_template_workshop_access.test.sql`.
- `scripts/verify-local-proposal-template-workshop.mjs` and `verify-local-proposal-template-backfill.mjs`.

A content token identifies reusable content. It is not a chronological revision number, authorization credential, or historical archive. Identical restored content may produce the same token.

### Existing moderation

- `supabase/migrations/20260928063450_reporting_moderation_foundation.sql`.
- `private.moderation_cases` owns typed targets, subject identity, context and review state.
- `private.moderation_reports`, notes and case events retain protected append-only records.
- `public.submit_moderation_report` owns authenticated identity, bounded category/explanation, target resolution and client-submission retry idempotency.
- `list_own_moderation_reports` exposes only the reporter's safe history.
- `list_moderation_cases` / `get_moderation_case_detail` / notes / transitions use server-side staff authorization.
- Current review states are `received`, `under_review`, `completed`. Completing or reopening a case is not enforcement.
- The current submission function has a blanket `target_subject_id = reporter_id` denial. TW02 needs a **template-only exception**; preserve all other target restrictions.
- Group corroboration only applies to existing `profile` / `project_chat_message` targets with Project context.
- Scambio-Dona counterstatements only apply to their existing interaction target kinds.
- These evidence workflows must not accidentally activate for a template report.

### Clients

- Mobile: `apps/mobile/lib/features/moderation/{domain,data,application,presentation}/`.
- The shared target enum is in `domain/moderation_models.dart`; the existing report route takes a typed `ModerationReportTarget`.
- Web: `apps/web/src/features/moderation/`, including models, server reads, operations, actions and components.
- Web guards use the authenticated staff session and recheck authorization on mutations. Do not introduce a browser service-role client.
- Generated RPC types: `apps/web/src/types/database.generated.ts`.

If #123/#125/#126 have landed on an applicable authorized base, preserve and compose with their canonical restrictions/action infrastructure. Their existence as open PRs is not permission to import them. TW02 must not build a second global sanctions system or depend on unfinished hosting work.

## Required backend work

### 1. A real template report target

Extend the canonical report vocabulary with a dedicated target kind, preferably `proposal_template`, following repository naming conventions.

- Use a typed foreign key to the template identity. Do not disguise a template report as a `project` report.
- Update target-kind constraints, exactly-one-target shape constraints, immutable identity protection, narrow summaries/projections and relevant parsers together.
- Derive the subject/original Creator and source provenance on the server. Do not trust client-supplied ownership or source IDs.
- New reports must resolve an available public template through TW01's canonical eligibility predicate. Unknown, unpublished, pre-Completed, cancelled, removed or source-ineligible targets must not create a case.
- Reject arbitrary caller-supplied incident context for template reports. Source provenance is a template relationship, not an allegation against the source's members.
- Keep the original Creator as the subject even when the Creator is also the reporter; do not invent a substitute subject to bypass a constraint.
- Allow self-report only for this target kind. Preserve existing self-report prohibitions for every other kind.
- Preserve current profile/authentication gates, category vocabulary and trimmed 10–4000-character explanation rules.
- Preserve identity-bound retry semantics. An exact accepted submission retry must recover the same receipt even if the template has since been removed; it must not create another case/event or revalidate into an ambiguous failure.
- Store server-derived immutable template/source provenance and the content token observed at reporting in protected case/report context. Reuse an appropriate existing extension pattern where possible.
- Do not create a full template revision archive or copy the private Bozza. If storing any content excerpt, keep it explicitly bounded, allow-listed, server-derived and private; document why it is necessary.
- No auto-hide, removal, group invitations, counterstatement requests, notification/outbox messages or reporter-text broadcasts occur because of a template report.

Keep reporter-visible history narrow. Do not reveal other reports, staff notes, removal reasons, private Creator history or evidence-recipient identities through it.

### 2. Minimal staff review context

Provide a staff-authorized typed projection for a template case, integrated into the existing case detail.

It should identify:

- the template and source Proposal;
- original Creator attribution as permitted by staff case access;
- report-time content token and current content token, with a truthful changed-content indication;
- current template removal state;
- the current reusable published content needed to understand the report.

Use the same published-content allow-list as TW01. Keep long resource-need collections bounded/paginated with explicit version handling. A case remains reviewable after removal or loss of public availability; the staff-only projection must be intentionally authorized and must never broaden public reads.

Do not grant staff access to Bozza, participant lists, chats, exact meeting instructions, workspace links, private addresses or unrelated source records. Do not reuse the baseline RPC or grant raw-table access.

Covers must use authorized existing media delivery. If source visibility prevents normal delivery, show an honest unavailable/fallback state; do not invent a broad staff Storage bypass.

Keep Project incident/evidence context separate from source provenance. Avoid triggering corroboration reads or UI warnings merely because the template has a source Proposal.

### 3. One audited removal command

Implement one canonical authenticated staff command to remove a template referenced by a template moderation case.

- Reuse the approved base's moderator/admin authorization; verify expected actor identity inside the RPC.
- Bind case and target server-side. A forged case/template pair or non-template case must be rejected.
- Require an explicit bounded reason and identity-bound request identifier. Keep reasons in protected moderation records, not public payloads or general logs.
- Bind the action to the content the staff reviewed, using the current content token or an equivalent deliberate stale-review guard. A changed token must require review again, rather than silently removing based on an obsolete screen.
- In one transaction, establish effective removal, append its attributable action/evidence record and audit references, and return a clear receipt.
- Record actor, template/source, case, request, reviewed token, reason reference and effective time using the existing audit conventions.
- General audit/event metadata remains identifier-only where repository conventions require it. Do not log report explanations, descriptions, need text, private snapshots or reason bodies.
- Repeated delivery of the same accepted request recovers the same result without duplicate consequence/audit events. Reuse of a request identifier with incompatible inputs must be rejected.
- Recheck current staff authorization before returning a retry receipt.
- Concurrent actions from different cases/staff must produce exactly one effective template removal. Return a truthful already-removed result for a later action; do not invent a second removal time or attribute the earlier removal to the later actor.
- Preserve established source/template/case lock ordering. Document the lock contract TW03 must use for application-versus-removal serialization.
- Rollback must leave no half-removed template, orphan reason/action or false audit success.
- Removal is a separate explicit action. Receiving, noting, completing or reopening a case does not remove or restore the template.
- Do not add a restoration button/command or Creator removal permission.

Retain the template identity, baseline and necessary report/audit records. Activate TW01's `removed_at` seam rather than physically deleting linked rows.

Use the existing case-event/action extension conventions. If adding an event kind or projection field, update all strict client parsers in this change. If removal is represented by a separate typed action timeline, integrate it clearly without weakening event validation.

### 4. Public-use enforcement

After removal commits, fresh anonymous and authenticated calls must return no template from:

- catalog/search/filter pagination;
- detail;
- resource-blueprint pages, including a request with a formerly valid token;
- any template-specific media presentation or availability endpoint introduced by this change.

The shared canonical eligibility predicate remains the authority. Do not add client-only filtering or a second Completed clock.

Removal must not modify the source Proposal, public source cover authorization, source participation/chat, another template, or an independently created draft/Project. A lawful public source cover may still be accessible through the source Proposal after template removal.

Document a narrow shared eligibility/locking contract for TW03. Do not implement a fake apply endpoint or copy command merely to test a future feature.

If canonical source moderation/restrictions are present on the actual base, template reads/reporting must continue to respect them. Do not invent account sanctions or import unmerged moderation migrations to simulate this.

## Required client work

### Shared mobile reporting support

Extend the existing typed report target, gateway/controller handling, own-report parsing, localization and route helper so TW04 can open the current form for a template.

- Use the existing authenticated form, category/explanation validation, stable submission identifier and identity-change protection.
- A template report, including a self-report, receives the ordinary manual-review acknowledgement.
- Do not promise automatic deletion or call it withdrawal.
- Do not show Project-member corroboration disclosures or Scambio-Dona counterstatement disclosures for this kind.
- Use Italian/English parity and the established localization/theme/accessibility patterns.
- Exercise the target through the existing report route and tests. A new Workshop catalog/detail screen or navigation entry is not required in TW02.

### Existing dynamic admin web app

Integrate template cases and the removal action into the current queue/detail flow.

- Staff can see the safe review context, report/current revision relationship and availability state.
- Removal requires a deliberate confirmation and reason.
- Confirmation copy explains that it removes the template from Workshop and future reuse; it does not remove the source Proposal.
- Keep review-state controls separate from removal.
- Show truthful success, already-removed, stale-review and operational-error states. Refresh relevant server data after a successful action.
- Retry an ambiguous request using the same action identifier. Do not generate a new identifier for every delivery retry.
- Revalidate authenticated staff access on every mutation; handle role loss while the screen is open.
- Do not expose removal controls to ordinary users or introduce service-role browser credentials.
- Do not render user-authored content as trusted HTML.
- Do not add hosting/deployment configuration, a separate moderation dashboard or account-suspension controls.

## Migration and compatibility rules

- Add a new forward migration; do not rewrite TW01 or applied moderation history.
- Inspect effective functions/constraints on the actual base before replacing a function definition.
- Preserve every existing report target, retry behavior, staff gate and evidence workflow; new template support must not downgrade older behavior.
- Make constraint/index/function changes safe for existing cases and reports. Do not fabricate template reports, removal events or historical reasons during upgrade.
- Raw private tables/helpers remain inaccessible to public/anon/authenticated/client service-role use as appropriate; RPCs perform internal authorization with hardened search paths.
- Regenerate types and update RPC/security verifier inventories when needed.
- Do not migrate, reset, backfill or deploy a shared/staging/production environment.
- Use deterministic synthetic local fixtures only. Realistic cumulative demo content belongs to TW05.

## Validation and acceptance evidence

Use meaningful database, authenticated API/concurrency and client tests. Do not treat a mock-only report/action test as proof of authorization or atomicity.

Required cases:

1. Another authenticated user and the original Creator can each report an eligible completed template; self-report of existing non-template targets still fails.
2. Unknown, pre-Completed, cancelled, removed, unpublished and canonically unavailable template targets create no case or side effects.
3. Wrong expected identity, unauthenticated callers, ordinary users posing as staff, revoked staff and forged case/target pairs fail.
4. Report retries produce one case/report/event and recover their receipt after subsequent removal.
5. Template reports create no corroboration/counterstatement requests, notifications or member-visible reporter text.
6. Staff can review narrow template context after removal, while Bozza and unrelated private source fields remain inaccessible.
7. Changed reusable content is detected; stale-review removal fails clearly and refreshed review can proceed.
8. Removal updates availability and protected action/reason/audit records atomically. Failure injection rolls all of them back.
9. Same-request retries and concurrent removals from two cases/staff do not duplicate effective action/audit records or overwrite attribution.
10. Removed templates disappear from all public reads and blueprint pages even with an old valid content token; no cover path leaks through a template payload.
11. The source Proposal and its legitimate cover delivery remain unchanged. Original Creator baseline access still works; non-Creators and staff do not acquire baseline access.
12. Completing/reopening a case does not change removal state; there is no self-service withdrawal or implicit restoration.
13. Migration replay/upgrade retains legacy reports and all existing target types, evidence workflows and private privileges.
14. Mobile form, self-report receipt, retry/identity handling, safe own-report parsing and Italian/English copy work.
15. Web authorization, parsing, confirmation/reason, stale review, ambiguous retry, already-removed and failure states work.

Relevant established commands on the inspected base include:

- `npm run db:reset`, `npm run db:lint`, `npm run db:advisors`, `npm run db:test`.
- `npm run moderation:verify:local`, `npm run moderation:corroboration:verify:local`, `npm run moderation:counterstatement:verify:local`.
- `node scripts/verify-local-proposal-template-workshop.mjs`.
- `node scripts/verify-local-proposal-template-backfill.mjs`.
- `npm run proposal:verify:local`, `npm run cover:verify:local` where affected.
- `npm run db:types` followed by the repository's generated-type drift check at a clean committed state.
- `npm run test:tooling`, `npm run check:web`, `npm run format:check:web`.
- `npm run check:mobile`, plus an appropriate Flutter compile check if client/build changes warrant it.

Add a local-only authenticated template reporting/removal verifier following the existing scripts' safety guards. Run it and the affected regression checks. Keep resets and destructive fixture setup local. Use change-scoped CI; Site checks and unrelated platform builds are not automatically required.

Record exact commands, counts, outcomes and limitations. Do not report a check as passed unless run. Inspect final-head hosted CI; Database/Web/Mobile are relevant to this task. Explain any legitimately skipped job. Do not repeatedly run full unrelated integration suites without a concrete reason.

## Documentation and deliverables

Update the nearest relevant documentation:

- `docs/development/template-workshop.md`: report target, self-report exception, staff projection, removal/retry/revision/lock semantics and media boundaries.
- Existing moderation feature README maps and development/security docs as needed.
- Architecture/roadmap sections narrowly, marking TW02 implemented and TW03/TW04 deferred truthfully.
- Generated types and relevant verifier documentation.

Archive this supplied prompt **verbatim** under the repository's `history-implementations` convention. Do not replace it with a summary or run a formatter that changes the archived prompt.

Finish with:

- the draft PR link and target branch;
- exact base and final head;
- short implementation summary;
- validation evidence and material limitations;
- the explicit manual-review items and any predecessor integration work;
- confirmation that no merge/shared migration/deployment occurred.

Manual review covers the narrow self-report exception, staff-only published-content access, attribution/reason retention and template-only removal semantics. Keep both TW01 and TW02 unmerged if the predecessor still awaits review.

Choose routine implementation details from repository evidence without asking permission. Surface only a concrete consequential conflict that cannot preserve these product/security rules. Do not stop because optional design files, production credentials, starter content or unrelated hosting/moderation plans are absent.

