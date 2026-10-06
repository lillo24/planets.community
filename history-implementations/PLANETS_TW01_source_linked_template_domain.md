# PLANETS TW01 — Source-linked Template Workshop domain

Implement the first plan of the agreed Template Workshop track: the canonical backend foundation only.

Repository: https://github.com/lillo24/planets.community  
Inspected main: 92d93ca5a455ab853df8bc34b66fd8d69f4fb341, including merged PR #124.  
Start from current main after verifying its actual head and relevant changes. Do not select an open feature/moderation branch as a dependency without explicit authorization.

## Objective

Establish exactly one linked template identity for each published one-time Proposal, keep its reusable content consistent with the source's allowed published changes, and expose a sanitized, bounded Workshop catalog only when the source reaches canonical Completed.

Retain a narrow original-Creator-private pre-publication Bozza baseline for a possible future transformation view. Do not expose that baseline or implement a comparison UI.

This plan establishes the contracts needed by TW02 reporting/removal, TW03 template-to-draft creation and TW04 mobile Workshop. It does not implement those dependent features.

## External context

This prompt is self-contained. No Google Doc, design dump, screenshot, provider dashboard, credential or other external file is required.

The broader design and roadmap are optional background. Do not block implementation because you cannot access them. Read repository instructions, architecture and actual code before choosing implementation details.

## Current evidence and instructions to inspect

Read root AGENTS.md, applicable nested instructions, docs/architecture/core-stack.md, relevant portions of docs/architecture/system-design.md, docs/implementation/roadmap.md and implementation_plan_sections_suggestions.md.

The inspected repository has:

- Flutter/Dart mobile, canonical Supabase/PostgreSQL data, a separate Next.js discovery/admin application, and a separate Vite informational site.
- A Proposal business lifecycle of draft / published / cancelled. Upcoming / Happening / Just Finished / Completed are derived from schedule/time.
- Canonical Completed at ends_at + 24 hours. This is elapsed time, not proof that the event happened or succeeded.
- Structural published edits by Creator/current Co-creator only before starts_at; cancellation is permitted only before ends_at. Draft saving/publication remain original-Creator-only.
- Owner/management reads distinct from sanitized public reads. Public Proposal detail can contain exact meeting text when explicitly public; this does not make that field reusable template content.
- Existing bounded Proposal discovery with controlled skill filters, rough locality and literal substring query across title/summary/description. Mobile search currently trims and limits a query to 120 characters.
- Shared projects identity, registration_capacity and count_organizers_toward_capacity; capacity/social headcounts and delegated authority remain independent.
- Controlled proposal_skills with Required / Useful meaning; project_resource_needs has reusable title/details separate from commitments, coverage and actual contributions.
- Existing source covers are immutable, parent-bound canonical objects.
- No implemented Workshop catalog/application domain in the inspected feature tree.
- Source insert/identity, capacity, media/trust, Co-creator, blocking and participation behavior extended across later migrations. Inspect final definitions, not only the original Proposal migration.
- Draft PRs #123/#125 are separate moderation-consequence/suspension work in the inspected state. Do not assume they are merged prerequisites.
- Some architecture/roadmap summary text describes stale stack status. Actual code and merge history are authoritative.

Likely areas to inspect, rather than mandatory file locations:

- supabase/migrations and supabase/tests, including the original Proposal domain, source skill/resource needs, source covers, profile-photo trust, Co-creator and organizer-capacity extensions;
- apps/mobile/lib/features/proposals/domain, data and application contracts, to preserve existing API behavior even though this task adds no screens;
- shared generated database types and RPC audit/local verification tooling;
- existing public profile/cover sanitization helpers;
- docs/architecture/system-design.md and docs/implementation/roadmap.md.

Use the established feature/module boundaries and RPC-only security patterns. Choose exact table/function names after inspecting current code.

## Agreed behavior

1. Scope is one-time Proposals only. Tavoli remain outside this task.
2. Successful first publication automatically establishes a linked template. There is no template submission, approval queue, independent authoring flow or opt-in command.
3. Creating the linked record at publication does not make it publicly usable immediately. Workshop list, detail and future application eligibility require canonical Completed.
4. Each allowed edit of reusable published content updates what the linked template represents. Private draft saves never publish template content.
5. Keep the existing edit cutoff at event start and Completed timing at end + 24 hours. Do not extend editing to event end or introduce a different completion definition.
6. “Final result” means latest published idea/content, not a post-event outcome. Do not add an outcome editor, success badge or verified-event claim.
7. Private Bozza is retained for future work, but is never a public template and never appears in Workshop/application payloads.
8. Owner withdrawal is not part of the agreed design. TW02 will add manual reporting/removal, including reports by the source Creator.
9. The linked template is not a Project: no participants, delegated team, join requests, chat, commitments or occupancy.
10. A future Project created from reusable content will be independent. The version/provenance foundation here must not imply that later source edits will mutate such copies.

## Required domain foundation

### Source-linked identity

- Exactly one canonical template identity per once-published one-time source Proposal.
- No public template for a never-published draft.
- Bind source and original Creator server-side; clients cannot point a template at an arbitrary source, transfer its ownership or edit it independently.
- Establish the identity within the successful publication transaction, or an equivalently authoritative synchronous mechanism. A later client callback, eventual worker or Flutter-only hook is insufficient.
- Failed publication must leave no published-template side effect or retained “successful publication” baseline.
- Retrying existing idempotent publication must not create another template, overwrite the original baseline or duplicate source events.
- Cancelled sources remain excluded from public template use even if an internal linked record/history remains.
- Add an idempotent migration/backfill for existing published sources, including future sources awaiting completion. Previously published cancelled records may retain a non-public identity where the chosen history model needs it.
- Backfill must not fabricate historical drafts, publication edits or event outcomes.

Whether reusable content is projected directly from the current canonical source or maintained as a synchronized stored projection is your implementation choice. Do not build a second independently editable content store or an asynchronous stale-copy system.

### Reusable content and provenance

Provide a narrow reusable-content contract with a stable source/template identity and an opaque version/revision token that identifies the exact reusable payload.

The token must change when reusable content changes and remain stable for identical content. You do not need full historical version storage, per-keystroke revision records or a generic version-control subsystem. Document the version semantics so TW03 can atomically copy a consistent payload later.

Separate stable copied-content provenance from live visibility-sanitized attribution. A source author's profile privacy change must not be defeated by a stored public name/photo.

| Data | Allowed template use |
| --- | --- |
| Title, summary, description | Latest published text, within existing bounds; no invented generalized organizer guide |
| Controlled skills | Valid source skill IDs/descriptors and Required / Useful labels |
| Resource needs | Narrow reusable title/details from the current non-closed source requirements; no fulfillment, commitments or operational history |
| Registration capacity | Optional editable recommendation from the source; no usage or occupancy |
| Duration | Optional guidance derived from source duration; no old start/end instants copied as new logistics |
| Content language | Use an existing reliable source convention if present; otherwise do not fabricate a language classification or require a new field to proceed |
| Cover | Existing canonical source cover through its actual authorized source boundary; no copied Storage ownership |
| Source/template IDs and version | Honest provenance, safe source link only if currently authorized |
| Private Bozza, meeting details/coordinates, workspace/Drive/video links | Never in a public/template reuse payload |
| Members, roles, requests/offers, chat/messages, profiles of participants | Never in a reusable payload |
| Coverage, commitments, actual contributions, counts/badges | Never in a reusable payload |
| Reports, evidence, staff notes or private owner metadata | Never in public reads |

An open resource need means the source has not closed that requirement; it is not proof that a need is unmet. Do not include closed/obsolete requirements as default blueprints or infer fulfillment from need state.

Use an explicit projection allow-list. Do not serialize owner/manager detail wholesale and strip fields afterward. Free text can itself contain old dates or personal details: do not claim that this projection automatically anonymizes it. Reporting/removal will address reviewed unsafe content in TW02.

Source requirements currently have their own restricted historical/public read boundary. Add a narrowly authorized completed-template projection rather than broadly reopening historical live-need APIs.

### Synchronization across canonical mutations

Audit all current write paths that change reusable content:

- first publication;
- Creator and Co-creator published structural edits, including compatibility RPC overloads;
- controlled skill replacement;
- source need create/update/close;
- permitted cover set/change/clear;
- source capacity changes used as template recommendations;
- cancellation or other applicable source visibility changes.

A source change must not leave a mixed/stale reusable payload or version when a read succeeds after that change commits. A public read should observe one consistent database snapshot. Shared logic may live in triggers/private helpers/canonical RPCs as appropriate.

Keep authorization and lock ordering in their current owning domain. Avoid unnecessary new locks or trigger recursion that could deadlock source publication, resource management, covers, delegates or capacity operations. Do not alter published-event edit eligibility.

A private draft update has no linked public template content effect. Once published, allowed changes update the same linked identity; they do not generate new catalog entries.

Source dates determine eligibility. Do not persist a second clock-driven “completed” flag or add a scheduled job merely to make a source appear. Visibility must change correctly at the canonical time boundary without another source write.

### Removal/visibility seam for TW02

Include the minimal canonical state/predicate seam that TW02 can use to remove a template from public use.

- Template public eligibility combines source kind, once-published/published lifecycle, canonical Completed, current canonical source visibility restrictions if present, and template removal state.
- This predicate must be shared by list/detail and suitable for reuse by TW03 application.
- Clients cannot reset removal, reactivate a template or make a non-eligible source publicly usable.
- This task does not expose a public owner withdrawal or staff removal command; TW02 owns those workflows.
- Trusted local test fixtures may exercise removal state to prove the access boundary.
- Do not include removed/non-eligible records in counts/search metadata that reveal protected content.
- Do not leak a source hidden by any moderation contract that has actually become canonical on the current base.

If #123/#125 remain outside main, do not import them or make TW01 wait for unrelated admin/hosting work. Compose with the source visibility primitives actually available and leave a clear seam for TW02. If a new inseparable dependency genuinely appears, report the exact missing contract rather than treating a plan label as sufficient justification to stop.

## Private Bozza baseline

The purpose is future comparison, not publishing private working material.

- Capture one narrow pre-publication baseline from the latest persisted draft immediately before the first successful draft-to-published transition.
- Capture it transactionally with that transition, before lifecycle change erases the distinction.
- This is the latest saved pre-publication draft, not the earliest idea and not a claim about a completed outcome.
- Retain minimal comparison content: title/summary/description and skill selections, with reusable source-need text only if needed for the chosen comparison contract.
- Do not include meeting details, workspace/chat/participant data, profile credentials or media bytes. Do not snapshot owner-detail responses wholesale.
- Protect it for the immutable original Creator. Existing Co-creator authority over a published source does not give access to the original private Bozza.
- If you add a baseline read RPC, bind expected identity server-side and expose it only to the original Creator under applicable current restriction gates. Anonymous users, unrelated users, participants and delegates receive no baseline. Do not add a new general staff-access path for it.
- Later published edits and publication retries do not overwrite it.
- Existing records backfilled without a genuine retained baseline have no baseline; represent that honestly.
- Follow existing account/retention protections. Do not introduce a new public retention claim, silently grant broader access or change account-deletion behavior.
- Do not add a public comparison endpoint, toggle, timeline or generic draft-history authoring system.

If the existing publication flow saves source text and cover in separate steps, capture the actual last persisted content at the successful first publication. Do not invent a different earlier version. Preserve the current cover-before-publication/photo/capacity safeguards.

## Public catalog and detail RPCs

Use the established RPC-only style and deliberate anonymous/authenticated public access.

Catalog requirements:

- eligible completed one-time source templates only;
- slim card projection rather than nested private/source history;
- bounded page size, with the existing 1–50 convention where appropriate;
- stable deterministic keyset pagination using server-derived ordering and a unique tie-breaker;
- bounded literal text search and controlled-skill filters, following existing query validation conventions;
- filter/cursor validation that does not accept arbitrary client SQL or unbounded queries;
- no popularity ranking, social occupancy, live Join state or automatic-similarity engine;
- no source drafts, future sources, Happening/Just Finished, cancelled or removed sources;
- public profile attribution sanitized under global visibility rules, never current-group contextual name permission.

Detail requirements:

- exact template lookup through the same eligibility predicate;
- explicit allowed reusable fields and safe provenance;
- protected meeting/operational fields absent from the schema/payload, even when an existing source public detail happens to allow exact meeting text;
- unavailable/removed/unknown IDs use the repository's normal privacy-safe result/error conventions;
- resource blueprints bounded/paginated or otherwise explicitly bounded with completeness semantics; do not silently truncate reusable content;
- no unbounded member/profile or related-history hydration;
- safe source link and cover presentation only under current authorization.

Catalog content language, rough locality context or original event metadata may be added only where the agreed reusable/past-event presentation genuinely needs it and it is already safe/public. Keep exact logistics out. Do not introduce a new schema requirement solely to support optional embellishment.

Source covers can remain accessible through the original Proposal if that source independently remains public. Template removal is not automatic deletion of the source. Ensure any template-specific cover projection/delivery respects template eligibility without weakening the original source's legitimate access or pretending a shared image has become globally inaccessible.

## Security, compatibility and migration requirements

- Add new migrations; do not edit applied migration history.
- Preserve current canonical RPC signatures/overloads and return shapes unless a narrow change is unavoidable and every caller is updated.
- Use the existing hardened security-definer/search_path/RLS/grant conventions.
- No browser/mobile service-role credential or direct raw-table access for normal clients.
- Private helpers/baseline/revision internals must not become callable through broad grants.
- Keep original-Creator publication and current Co-creator structural authority distinct.
- Preserve profile-photo gates, registration-capacity constraints, organizer union semantics, blocking, chat/People privacy, notification/outbox behavior and covers.
- New logs/audit/outbox data must be identifier-only where existing conventions require it. Do not emit source descriptions or private baseline text into logs.
- No copied participant names/photos as attribution. Public profile sanitization is live.
- If main has acquired suspension/visibility enforcement since this prompt was prepared, use the approved canonical gates on the relevant reads/writes. Do not fork an enforcement policy.
- Update generated DB types and RPC audit/verifier expectations where the new contracts require it.
- Keep the work local/repository-only. No shared database reset/migration, production backfill, deployment, DNS, credentials or provider changes.

## Explicit non-goals

Do not implement:

- TW02 report target/forms/staff controls beyond the minimal removal seam;
- TW03 template-to-draft creation;
- Workshop mobile screens or navigation/publication notice UI;
- save-on-exit/autosave snackbar;
- active-Project matching or editor suggestions;
- Tavolo templates, standalone templates or defaults lacking genuine completed sources;
- volunteer submission, staff template approval or owner withdrawal;
- public Bozza comparison or post-event outcome authoring;
- rankings, ratings, comments, favorites, template chat, AI/embeddings or payments;
- the complete eight-scenario demo world, which belongs to TW05;
- a production worker/polling service or hosting changes.

Use small local/test fixtures now. Do not modify or regenerate the real demo world unnecessarily to make this foundation pass.

## Testing and validation

Add meaningful tests for the new data/security behavior, then run the smallest complete set covering every changed area.

Required evidence:

1. Clean local migration replay and database validation, generated types and relevant RPC audit/local verifiers.
2. First publication creates one linked identity; repeat publication does not duplicate it or baseline/events; failed publication leaves no new publication side effects.
3. Private draft saves, missing-photo/capacity publication failures and unauthorized publication retain their previous behavior.
4. Allowed Creator/Co-creator changes update reusable content/version. A Co-organizer, participant, revoked delegate or wrong identity cannot use template internals to bypass source management.
5. Skill/resource/cover/capacity changes remain consistent; closing a source requirement removes its default blueprint without claiming fulfillment.
6. Source becomes eligible precisely at canonical Completed, not publication/start/end/Just Finished. A time advance without a mutation is sufficient.
7. Stable bounded catalog pagination, query/skill validation and appropriate no-result versus failure behavior.
8. Public payload schema rejects/leaves out private Bozza, protected meeting data, workspace links, participant state, contributions and staff evidence. Test with deliberately distinctive fixture values.
9. Original Creator can access the retained baseline if a read exists; others cannot. Later edits/retries do not overwrite it. Backfilled sources cannot claim a fabricated baseline.
10. Cancellation, trusted removal-state fixtures and any actual canonical source visibility restriction prevent list/detail access, including exact-ID bypass.
11. Publication/source-edit/concurrent lifecycle behavior remains transactionally consistent. Add a focused concurrency verifier if the chosen synchronization/locking introduces races not meaningfully covered by ordinary tests.
12. Public cover metadata/delivery honors its actual source/template boundaries; baseline/public reads do not expose private owner media.
13. Existing Proposal, resource, cover, capacity/delegate and source-trust regressions relevant to the changed hooks pass.
14. Formatting and git diff --check, appropriate web/mobile type/static/test checks if generated APIs or callers changed, and final-head hosted Validation.

Do not rerun unrelated expensive suites merely because this is a new PR. Database source hooks require meaningful cumulative database verification; client-only areas that remain unaffected need not receive invented changes to force CI execution.

Report exact commands/results, skipped checks and limitations. A skipped hosted job is not an executed passing job. Do not claim a device check or production migration was performed.

## Documentation and traceability

- Document template identity, automatic synchronization, canonical eligibility/version semantics, public allow-list, private Bozza capture and removal seam.
- Update the nearest feature/domain map, architecture and roadmap. Reconcile obsolete template-specific statements such as “future explicit submissions” with this agreed automatic source-linked design.
- Avoid rewriting unrelated roadmap/history or making blanket stale-status corrections outside the necessary sections.
- Add the agreed TW01 → TW02 → TW03 → DRAFT01 → TW04 → SIM01 → SIM02 → TW05 track with implemented/deferred statuses stated truthfully.
- Record decisions necessary for later TW02/TW03 to consume the contract; do not scatter unwritten assumptions across client code.
- Archive the supplied prompt exactly using the repository's history-implementations convention.

## Autonomy and concrete stop conditions

Choose routine table/function structure, projection strategy, stable ordering and version-token implementation using repository evidence. No need to ask about conservative implementation details.

Do not silently change public disclosure, source lifecycle, account retention, original-Creator baseline access or the distinction between template/source/derived Project.

Stop and report a concrete consequential conflict if implementation cannot preserve those rules, needs unavailable required external context, or genuinely depends on an inaccessible approved predecessor. Explain the affected command/invariant and alternatives. Do not stop merely because optional Google Docs, production credentials, starter content or unrelated admin-hosting work are absent.

No production starter content is required in TW01. No legal terms are drafted here.

## Workflow and deliverables

- Use one isolated branch/worktree according to repository workflow, based on verified current main.
- Implement the domain, migrations, tests, generated types/audit changes and scoped docs.
- Run required checks, inspect the complete diff and open a focused **draft PR**.
- Keep that PR **draft and unmerged**. This explicitly overrides the repository default automatic-merge instruction for this task.
- The concrete founder-review scope is the new public catalog of historical Proposal content, its safe reusable field set, and the private Bozza capture/access contract. TW02/TW03 should consume the reviewed contract.
- Do not deploy, apply shared migrations, merge other PRs or start the next plan.
- Do not delete an active worktree needed for this review. Follow normal recoverable cleanup after later authorized merge.

Completion report:

1. Branch, actual base and final head; draft PR link/target.
2. What exists now versus what remains for TW02/TW03/TW04.
3. Actual schema/RPC names and source-linked/version/backfill strategy.
4. How every relevant mutation stays synchronized and which lock order is preserved.
5. Public payload allow-list and baseline actor matrix.
6. Baseline capture semantics and honest treatment of legacy records.
7. Migration/security implications and exact local/hosted check results.
8. Any unresolved founder decision or environmental limitation, with a precise explanation.
9. Confirm draft/unmerged status and that no shared migration, deployment or production backfill occurred.

