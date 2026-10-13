# PLANETS GRP03C — Projects published for registered groups

## Outcome and authority boundary

Implement genuine group attribution for new one-time Projects and recurring Tavoli. An authorized representative can choose a registered group when creating a Project; public surfaces show that association, and the group's public page lists its public Projects.

Retain the real human Creator and each Project's existing organizer/participant rules. Group membership or a group role does not automatically grant powers over an associated Project. Current GRP03B role consent explicitly excludes Project powers, and the repository's accepted product decision says no Project authority inheritance is implied. This task adds an authorized publishing association, not an ownership-transfer or inherited-authority system.

The founder already chose Project-equivalent membership/role rules for persistent groups. Keep those rules and the top-right Groups entry. Do not reopen them.

## Current repository evidence

Repository: https://github.com/lillo24/planets.community

Inspected on 2026-10-13 at main `f5a3e9b38edb86710ce38d1382749542b9d3ea66`, the merge of GRP03B PR #237. Fetch latest main before starting; preserve later merged work.

Verified:
- GRP01/02 group identity, public directory/profile, Creator content lifecycle and independent staff suppression.
- GRP03A/B requests, retained memberships, independent Creator/Co-creator/Co-organizer roles, People/Team, participant/authority invitations, exact-self state and mobile/browser/native invitation flows.
- No canonical Project-to-registered-group attribution or group Project feed is implemented.
- `public.projects` is a private cross-domain identity anchor despite its schema name: one UUID shared with its concrete Proposal or Tavolo, immutable real `creator_profile_id`, source-synchronized identity and no API-role table access.
- One-time public/owner/delegated v2 contracts distinguish Ideas from Defined Projects; existing stricter v1 readers remain compatibility paths. Tavoli have separate scheduling/lifecycle models.
- Idempotent editor draft creation/recovery, template application, protected location/cover chains and draft departure already exist.
- Official starter-template organization attribution is catalog provenance. It has no registered group, Auth/Profile, source Project or participation.
- Shared/hosted migrations and native-host activation are separate from code completion.

Read root/nested `AGENTS.md`, `implementation_plan_sections_suggestions.md`, architecture records and:
- `docs/development/persistent-groups.md`, `group-membership-and-roles.md`, `grp03b-group-membership-ui.md`.
- `docs/architecture/product-decisions.md`.
- Proposal, recurring-activity, group and group-membership feature README maps.
- `docs/development/proposal-draft-departure.md`, `template-workshop.md`, `official-starter-templates.md`.
- Current canonical publish/promotion/authoring functions, including all later overrides.
- `20260908164407_project_participation_domain_foundation.sql`, `20261004200147_idempotent_editor_draft_creation.sql`, `20261008144158_map02_idempotent_editor_drafts.sql`, GRP migrations and generated contracts.
- Current Flutter gateways/controllers/editors, public group detail, public Project cards/details, and corresponding web public/share/confirmation surfaces.

Exact new names are implementation choices. Preserve established abstractions and installed dependency APIs.

## External context

**No external document, PDF, credential or hosted environment is required.** The agreed scope is included here and grounded in repository contracts. Earlier Trentino PDFs do not grant publishing authority or legal verification.

Use current version-compatible documentation when needed, especially Supabase functions/RLS. Never expose private tables or use a client service-role key to simplify integration.

## Required product behavior

### 1. Representation is explicit

A Project may have no group or one registered group in this MVP. Personal creation remains the default. Offer a compact “Publish for” / “Pubblica per” choice in unpublished Project/Tavolo authoring, with the current person's eligible groups.

Eligible representatives are the group's Creator and current Co-creators, consistent with structural group authority. Ordinary members and Co-organizers cannot assign its identity to a new Project. Representation does not require a separate participant membership.

Add a contextual Create Project action to an eligible group profile/management surface, opening existing Project/Tavolo creation with that group deliberately preselected. Preserve the usual scratch/template chooser and native navigation guards. An incoming UUID or navigation parameter is only input; the backend reauthorizes it.

Only eligible published, nonsuppressed groups with a valid accountable identity can acquire a new attribution or first-publish an attributed Project. The server checks live authority and eligibility, including after lock waits.

Do not automatically use the person's only group, copy group members/roles into a Project, or treat the group's broad territory as the Project's meeting location. Preserve all normal Project profile/photo, policy, location, capacity, resources and publication requirements. A group logo/photo is no substitute for the human publication photo gate.

### 2. Human authorship and Project control

Never replace the immutable human `creator_profile_id` with a group ID, synthetic Profile or group login. Record the verified actor who assigns/first-publishes the association through existing provenance/audit conventions.

The human Creator and that Project's explicitly accepted delegates retain their current powers. A group representative wishing to manage someone else's Project must receive an ordinary Project role through the existing flow.

Leaving the group or losing its role blocks new representation and first publication of pending group-attributed drafts. It does not rewrite authorship or remove separately held Project roles. Group membership, invitations and Project participation/chat remain independent.

Group attribution conveys which registered group the Project was published for. It is not an ETS/identity verification badge, legal accreditation or proof that all group members participate.

### 3. Draft binding and first publication

Store draft selection canonically, privately and recoverably. Support setting, changing or clearing the chosen group while the Project is unpublished and the caller is its real Creator.

New/change-to-group commands require current representation rights. Clearing an unpublished association remains available to its Project Creator after group-role loss, so a retained personal draft is not trapped. Saving ordinary private draft content must not destroy it merely because its group is temporarily unavailable.

Preserve selected group and its confirmed revision across editor reload, draft departure, cover/location saves and valid recovery. A failed association save is explicit; do not show it as saved or silently publish as personal.

If content creation/save and association use multiple commands, document truthful partial outcomes and recover the same draft ID before continuing. Do not create another Project after a lost response. Prefer an atomic initial group binding where it fits the existing idempotent creation seam; preserve legacy signatures/callers.

Once first publication succeeds, freeze the Project-to-group association as publication provenance. No retrofit of existing published personal Projects or switching published Projects between groups in this stage. Ordinary published edits, Idea promotion, Tavolo pause/resume/end, cancellation/completion and existing personal management remain governed by Project rules.

Any published association must have passed live group representation validation at its actual first publication. Guard **every** applicable server path: Defined publication, Idea publication, recurring publication, legacy overloads and source-level transitions. An older client must not bypass this check for an attributed draft.

Publication and group eligibility/authority changes must serialize correctly. Revocation/archive/suppression racing with publication can produce a neutral stale/denied result; it must not leave a falsely authorized association or partially published Project.

### 4. Templates and recovery

Template reuse creates a new personally authored draft. Never copy the source Project's group association, representative, roles, members or invitations.

A user may deliberately select their own eligible group when creating from any template. That selection is independent of source attribution and participates in the new draft's own command/recovery state.

Preserve official starter attribution exactly as catalog provenance. Do not convert “Planets Community Official” into a registered group or assign it to new Projects.

Freeze request UUID/actor/intent while a command is unresolved. Exact retries return the same accepted destination/association outcome; changed accepted intent fails explicitly. Reload current private state after recovery, since a receipt is not a current representation grant.

## Canonical data and public reads

Choose a minimal stable association owned by the shared Project anchor, with group UUID, appropriate draft/frozen-publication state/version and real actor provenance. Support both concrete Project kinds without duplicating a second ownership system.

Preserve existing group, source identity, policy, role, staff suppression and account-erasure guarantees. Do not add unconditional personal-account deletion blockers, new retention policy, group takeover or cascading destruction of Project history.

Use additive migrations, private/RLS storage, explicit grants and narrow identity-bound writes. Privileged functions use fixed safe search paths, qualified objects and actual Auth/role checks. Record identifier-only audit events; no text, contact details, raw request bodies or secrets in generic metadata.

A compact exact/bounded-batch public attribution projection may be preferable to changing every existing public Project RPC. Inspect current consumers before choosing. Avoid per-card role calls, unbounded directory downloads, raw-table reads and broad return-shape changes.

Public attribution is returned only for a canonically public Project. Group name/type/navigation use only the current canonical public group allowlist. Do not expose an unpublished/suppressed/orphaned group's current content, manager identity or suppression reason through a Project badge.

If the group later becomes unavailable, preserve private publication provenance and keep the Project's existing lifecycle/access rules. Its public group label/link becomes a neutral unavailable association; do not expose a hidden group UUID/name or erase the human Creator. Restoring public eligibility restores the public association on fresh read. Do not automatically cancel/hide Projects or close chats because their group page is hidden.

Do not claim immediate offline/cross-device revocation of previously authorized public metadata. Revalidate through current controller patterns; successful canonical absence/denial clears the affected group label/context without substituting cached private content.

Add a bounded public group Project feed with stable paired keyset pagination and indexed group/Project lookups. It must enforce both current group public eligibility and each concrete source's canonical public eligibility, including Idea/Defined and recurring distinctions. No draft/private planner, protected venue, participant, request, staff or commitment data.

Use immutable publication ordering plus a unique ID tie-breaker, or another documented equally stable key. Keep page/filter state fixed during paging; refresh when needed. Group feed semantics must not invent completion or reveal an otherwise excluded source. Counts remain truthful and bounded; no fabricated popularity or member totals.

## Mobile and existing web integration

- Add the representation chooser to existing unpublished authoring with an explicit personal option. Reuse bounded eligible-group reads and safe actor-scoped state.
- Recheck role on mutation/readback, clear unauthorized choices without silently rewriting canonical binding, and provide an explicit personal/unavailable-group resolution.
- Preserve draft departure, unsent raw location input, resource editor handoffs, covers, template/similar flows and current policy/photo return behavior. Opening Create alone or selecting a group must not generate a meaningless empty draft.
- Display compact truthful group attribution on ordinary public Project/Tavolo detail and relevant cards. Preserve existing human-organizer/avatar rules; do not replace them with an invented group identity.
- Add public Projects/Tavoli to the group profile using existing card/navigation behavior, bounded paging, real empty/loading/error states and preserved scroll windows. Avoid repeating the group name unnecessarily inside its own feed.
- Group members still explicitly join each Project through ordinary requests or Project participant links. A group link joins the persistent group only.
- Add matching attribution/feed presentation to existing public web Project/group/share surfaces where they already render those entities. Do not build a full web authoring/admin-directory product or change the informational Site merely for parity.
- Keep group toolbar placement, invitation/capability handling, My groups, People/Team and report paths intact. No new bottom tab or Map provider call.

Follow feature-owned typed models/gateways/controllers and EN/IT localization. Reject malformed nullable attribution payloads and unsupported kinds. Distinguish no association, unavailable public association, access denial and transport/setup failure.

Server writes remain canonical. Missing RPCs are setup failures, never empty groups or “saved personally” fallbacks. Do not show a published-for-group confirmation until the canonical publication/association result is confirmed.

## Validation and acceptance

Use a confirmed disposable local stack and fictional groups/people. Required evidence:

1. Clean replay, lint/advisors, generated API/type parity and populated upgrade preservation of all existing groups, Projects/Tavoli, drafts/receipts, templates, locations/planning, participation/roles, chats, reports and policy records.
2. Actor matrix: group Creator/Co-creator, Co-organizer/member, unrelated person, revoked representative, incomplete account and staff alone. Genuine Project Creator remains mandatory for draft association/publication.
3. Personal creation unchanged; authorized scratch/template group creation for Idea, Defined and recurring sources; group selection survives saved/recovered drafts.
4. Exact create/association/publication retry, changed intent, partial-save recovery, no duplicate Project, stale association and account-change/late-response behavior.
5. Independent-connection publication versus group-role loss, archive/suppression/account eligibility; no bypass by old publish overload or direct source transition.
6. Clearing a draft's group after role loss; first-publication freeze; later Project edits/promotion/lifecycle retain existing authority and provenance.
7. Template copies inherit no group authority/association; official starters remain separate. No automatic group-member/organizer insertion or new chat/notification.
8. Public detail/batch/group-feed privacy, tied pagination, Ideas/Defined/Tavoli, hidden/cancelled/unavailable sources, no private location/planner/manager/history leakage.
9. Group hide/restore changes public attribution visibility independently of Project membership/lifecycle; group roles grant no existing Project permissions.
10. Real Android local journey: group-context creation → retained draft → publication → public attribution → group feed → separate Project joining. Inspect EN/IT at 320dp/2x text and a normal width.
11. Relevant web public attribution/share/group-detail regression and browser read-only journey, with no capability-bearing screenshots.

Use repository commands after inspecting package.json: Database replay/lint/advisors/tests/types, relevant group/Project/delegate/template/invitation verifiers, tooling, `check:mobile` and `check:web`. Add a focused repeatable real Auth/PostgREST attribution/race verifier and include it in Database validation. Run every affected area; avoid unrelated expensive suites without a reason.

Physical phone `48091FDAS0041A` may be used only with an explicitly reviewed configuration. Report unrun physical/TalkBack/iOS/native-host checks precisely. Emulator screenshots do not prove them; inaccessible founder QA is not an arbitrary merge gate.

## Documentation, workflow and rollout

Update group/Project contracts and source-map READMEs with the representation/permission matrix, draft/publication boundary, immutable association, public unavailable behavior, receipt recovery, feed semantics and template independence. Keep existing group-role warnings accurate: there is still no inherited Project authority.

Use one isolated branch/worktree, implement, validate, inspect the diff, commit/push/open a focused PR and follow current automatic-merge rules after required CI passes. Integrate latest main before merging. Clean only task-owned paths through Git tooling without traversing dependency junctions.

No hosted migrations/deployment, domain/native association activation, signing/store upload, registry import, real organization seed data or provider/billing change. Document separately authorized migration application/API parity and public/Creator/representative/feed smoke checks before client distribution.

Resolve routine choices from current patterns. If implementing the requested publishing association truly requires changing immutable Creator identity, granting group-wide Project authority or transferring published Projects, stop with the concrete conflict; those are separate consequential permission choices, not incidental implementation details.

Return a concise report with PR/final commit/merge status, migrations, implemented creation/attribution/feed behavior, exact validation and UI evidence, any limited compatibility changes, pending hosted rollout and honest limitations. Deliver working tested integration, not a schema sketch.

