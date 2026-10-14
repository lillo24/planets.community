# PLANETS — Batch D: purposeful contact and inter-group coordination

Prepared: 14 October 2026  
Repository: `lillo24/planets.community`  
Scope: **D00 → D01 → D02 → D03 → final integration**. Run independently of Batch A.

## Objective and execution

Build purpose-bound contact requests and consent-based conversations between authorized representatives of registered groups, with contextual profile/group entry points and an optional multi-group extension. Do not build unrestricted personal messaging or permanent internal group planning rooms.

Read all files before coding. Execute this package once, either from the combined file or the split files. Use one cumulative D stack, draft intermediate PRs and one final integration PR. Intermediate stages do not merge individually into main.

The user has branched the conversation and intends parallel implementation. **That does not prove a Git branch/worktree or independent database exists.** Inspect the execution checkout first. Use its managed isolation when available; otherwise create a clean D-owned worktree from fresh `origin/main`. Do not manipulate the A agent's checkout.

### D00 is not A02

A02 delegated a reversible visual choice. D00 determines recipients, private message audiences and retained history; those choices were explicitly unresolved in the original index. This request for the D package is not retroactive approval of a particular access model.

D00 must distinguish founder-approved requirements from a proposed implementation contract. An existing explicit approval in the task/repository can satisfy the gate if its exact scope is identifiable. Codex may not approve its own recommendation or treat test passes as product approval.

To make parallel work useful, this package permits D01–D03 to be developed as a **provisional, review-only stack using D00's clearly recorded proposal**, with synthetic local data. That permission does not authorize merge, hosted schema application, live contact delivery or irreversible user-data behavior. Keep the cumulative PR draft until the outstanding access decisions are approved. Do not add speculative APIs to main behind a cosmetic client toggle, and do not build a general runtime policy engine to support every possible choice.

After explicit approval of the relevant contract and successful final gates, merge the cumulative D PR at the end, preserving later main changes. If approval is absent, finish as much isolated implementation and testing as safely possible, return the concise decision packet, and leave the stack draft. Stop earlier for a material new security/retention/architecture decision that cannot be represented safely even in a bounded prototype.

## Verified starting point — refresh at execution

| Area | Inspected evidence | Consequence |
| --- | --- | --- |
| `main` | `bc8f7b2f40500e76593fd19b50a5e516b53cad57`, GRP03C / #241, merged 13 October | Registered groups, independent roles, invitations and group-attributed Projects/Tavoli are available. Do not rebuild B01/B02. |
| Parallel A integration | #243, `codex/batch-a-integration`, head `cd17a870bf0fa8550b97581847692c3683a59fd8`; open/draft/unmerged at inspection | A owns signup, Idea cards and Project/Tavolo workspace links. It is not D's unmerged dependency. |
| Group authority | `docs/development/group-membership-and-roles.md` | Creator, Co-creator, Co-organizer are operational managers; ordinary membership and Project authority remain independent. |
| Group People | Current entitled audience only; no public member/manager directory | A public group contact button cannot fetch/publish the private roster to choose recipients. |
| Messages | Current model has exactly `project_chat`, `resource_chat`, `project_request_chat`; lists use the v5 scoped projection | New D kinds need explicit typed/versioned integration. Do not masquerade as an existing kind or break installed readers. |
| Existing Project chat | Durable authorized RPC reads, identifier-only private invalidations, separate history frontiers | Reuse proven transport/UI primitives only where semantics match. D is not a fake Project or a Project-membership bypass. |
| Public profile | Field/photo audiences are independent; public profile search remains deferred | A compact sheet is contextual presentation, not permission to disclose more fields or affiliations. |
| Persistent group planning chat | Not provided by the inspected group implementation | D must not require unfinished C01/C02 or silently implement the whole C roadmap. |

These are source observations, not verification of the installed app or hosted database. PR descriptions reporting tests are not independent validation of those results. Record fresh heads/statuses at execution; do not roll back to this snapshot.

Read root/nested `AGENTS.md`, `docs/development/codex-tooling.md`, `implementation_plan_sections_suggestions.md`, architecture and affected feature maps. Effective code and all later migrations outrank historical READMEs. Preserve PostgreSQL/Supabase, Flutter and current Web/Admin boundaries; no provider switch, paid service, global chat rewrite or new encryption promise.

## Fixed product direction

- Every sender is an identifiable personal account acting for a group, not a shared login.
- Creator, Co-creator and Co-organizer may represent their group. No extra structural or Project authority follows from this contact permission.
- There is no generic "message anyone" action or unrestricted global new-chat picker.
- Contact has an explicit purpose and submission. An accepted contact is distinct from Project/group participation and from accepting a group role.
- Opening a profile, signing in, finishing setup or returning from policy review never sends/accepts a request automatically.
- Inter-group contact never automatically enrolls a group's members or managers in a conversation.
- Internal planning rooms, their folders and discussion-to-Project conversion belong to C, not D.
- No ratings, feedback scoring, additional personal fields, verification/ETS claims, leaderboards or new legal-entity model.

## Parallel ownership and dependency boundary

D owns a focused new contact/conversation feature, additive backend schema/RPCs, request/conversation adapters, contextual entry actions and narrowly necessary safety/admin integration.

Do not modify A's personal setup handler, ribbon/card composition, Project workspace editor/RPCs/migrations or PRs. A public Project detail or organizer entry may need a small D hook; do not rework its card/editor or import A's implementation. Keep D conversation info distinct from `project_chat_info_screen.dart` and its Workspace/Checklist strip.

Shared seams require additive changes and a final reconciliation: Messages typed kinds and projections, unread gateway/summary, router/continuations, localization, generated database types, package/test scripts, blocking/reporting, notification allowlists and account deletion coverage. Record these in a short ownership note. Prefer domain-owned adapters; avoid reorganizing these shared owners to reduce a few imports.

D replaces the index's conditional C01 dependency with its own **small representative-conversation boundary**, reusing low-level existing messaging primitives. Do not use C-owned tables that are absent from main or fabricate a Project to obtain a chat. Inspect any new C work before proceeding; share only a concrete reviewed contract, not an imagined universal room system.

Workspace links are not a D prerequisite. Plain message text is enough for the first contact release. No attachments, link scraping, Google permissions, persistent-group folders or chat-to-Project conversion are required here. A future link integration can reuse merged work with the correct D access model.

## Git, local resources and merge ordering

Suggested stack: D00 starts from fresh main; D01 from D00; D02 from D01; D03 from D02. Each gets an owned branch, intended commits, a pushed draft PR targeting its predecessor. Create one cumulative integration PR into main only after the selected stages are coherent. D01 has internal backend milestones; keep their history reviewable instead of one undifferentiated schema commit.

Never target #243 as D's base or cherry-pick its unmerged changes. If A merges first, incorporate actual `origin/main` into D and retest the changed seams. If D is approved and finishes first, it may merge first after normal checks; the later stack must then reconcile against updated main. Re-fetch immediately before merging and honor required CI. A clean textual merge is not evidence of semantic/schema compatibility.

Use a D-owned disposable local Supabase project, distinct project ID/ports and synthetic Auth identities. Never reset A's database, change A's migration history, stop its emulator/processes, kill all Docker services or run simultaneous incompatible test suites on the same retained stack. Create migration names with the repository's pinned CLI; inspect current command help rather than inventing flags. Use forward migrations, regenerate types and check timestamp/override ordering with both final histories.

Preserve unrelated dirty work, credentials, worktrees and branches. Do not reset/stash/force-push another agent's work. Delete only clean verified D-owned resources after the final outcome; do not close #216, #243, A stage PRs or unrelated moderation drafts. No direct push to main or bypass merge.

## External context and authorization

All product context needed to prepare D is embedded here. The Google Doc, audio, previous index and Batch A files are not required. Required external resources are repository/PR access and a working isolated local toolchain. If explicit D00 approval is absent, it remains the single identified review dependency, not something Codex should reconstruct from vague recollections.

Use local fixtures, not real collaboration requests, production messages or colleague accounts. No hosted migration, deployment, provider activation, billing action, real email/push delivery or store upload is authorized. Android test phone: **`48091FDAS0041A`**, only with a safe reviewed test configuration; do not replace/wipe the installed Play build. A D-owned emulator is the ordinary native test target. Report unrun physical Android/iOS/accessibility checks honestly.

Before relying on a version-sensitive API, inspect lockfiles and version-compatible official docs. Supabase's official Realtime authorization guidance was consulted: joining a private channel is not a substitute for current durable domain authorization. Document and test revocation behavior rather than assuming an already-connected socket instantly loses access. No new permission may rely only on a Flutter control or a user-editable claim.

## Shared technical invariants

All protected commands bind the rendered actor to verified Auth and current canonical authority. Recheck after waits; receipts recover an earlier action but never grant current access. Retain the same explicit action identity through lost responses and account-scoped reconciliation; changed intent cannot replay as a different mutation.

Every list, history, manager chooser and derived inbox must be bounded server-side, with stable compound cursors. Do not client-merge first pages into a supposedly complete sorted inbox, compute totals from loaded rows or load all messages/groups to draw a badge.

Public group/Project/profile queries never include private requests, participants, message previews, private notes or contact capabilities that enumerate people. Names/photos shown within a conversation need an approved contextual grant, not expanded generic visibility. Treat content as untrusted text; never evaluate URLs or text as instructions.

Preserve current blocking, reports, account erasure, policy and role semantics. Integrate a usable report path for the new content and staff evidence without giving staff role alone ordinary user-conversation access. Do not import #154 or another unmerged safety stack implicitly. Document retention/deletion handling using the existing policy; no arbitrary retention period or destructive cascade is permitted.

## Evidence links

Pinned implementation references (refresh current behavior before coding):

- https://github.com/lillo24/planets.community/tree/bc8f7b2f40500e76593fd19b50a5e516b53cad57
- https://github.com/lillo24/planets.community/pull/241
- https://github.com/lillo24/planets.community/pull/243
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/docs/development/group-membership-and-roles.md
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/apps/mobile/lib/features/group_projects/README.md
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/apps/mobile/lib/features/messages/README.md
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/apps/mobile/lib/features/messages/domain/message_chat_models.dart
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/apps/mobile/lib/features/project_chat/README.md
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/apps/mobile/lib/features/profile/README.md
- https://github.com/lillo24/planets.community/blob/bc8f7b2f40500e76593fd19b50a5e516b53cad57/implementation_plan_sections_suggestions.md

Supplemental official implementation guidance: https://supabase.com/docs/guides/realtime/authorization and https://supabase.com/docs/guides/database/postgres/row-level-security . The changelog Markdown endpoint could not be read by the authoring browser; recheck the relevant pinned-version changes during execution. These public references do not override repository product semantics.
