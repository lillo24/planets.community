# PLANETS — Batch C: lightweight internal group planning discussions

Prepared: 14 October 2026
Repository: lillo24/planets.community
Scope: C00 permission contract → C01 backend → C02 grouped chat UI → C03 named links → C04 discussion-to-Project → final integration.

## Execution request

Read every document in this directory before editing. The founder asked for the C implementation stack to run **in parallel** with other PLANETS feature work. This grants branch/worktree isolation, **not permission to overwrite another stack**. Implement the four functional stages on their own C-owned cumulative stack, keeping intermediate PRs draft and one eventual cumulative integration PR. Do not reimplement A, B or D.

At creation, current main is 58c5b184c6a83bcca4b3ca950be13d3a08bd1a84. A01–A04 landed in [Batch A PR #243](https://github.com/lillo24/planets.community/pull/243); WORKSPACE02 / #216 is now merged. Group attribution / GRP03C landed in [PR #241](https://github.com/lillo24/planets.community/pull/241). Batch D contact and inter-group conversation prompts have been archived under history-implementations/PLANETS_D00-D03_Parallel_Prompts. Treat these facts as **snapshot evidence**, not permission to roll back or ignore later commits.

## What C means

**A permanent registered Group can contain one or more lightweight named planning discussions, presented under that Group inside Messages, with optional named links. An authorized Group Project publisher can create an Idea/Project from a discussion through explicit normal drafting.**

C does **not** mean an unrestricted new-chat picker, personal DMs, public group chat search, automatically enrolling all group members in every room, creating fake Projects to get a chat, or making messages public when an Idea is published.

Example: Trento Green has a private discussion named "Parco". Participants exchange messages and plan with a meeting/document link. An authorized human representative chooses "Create Project from discussion", reviews an Idea draft, and deliberately publishes or saves. The original room/history and group members remain separate from the resulting Project participants and chat.

## Actual implemented dependencies — refresh first

1. GRP03A/B: registered Groups, canonical current membership episodes, Creator/Co-creator/Co-organizer roles, private People and invitations. Group membership and Project membership are distinct. See docs/development/group-membership-and-roles.md and apps/mobile/lib/features/group_membership/README.md.
2. GRP03C: explicit registered-group attribution of Projects and Tavoli, actor-bound creation receipts and Project publication; the human Project Creator remains immutable. **Only Group Creator/Co-creator currently has canonical group-publishing representation. Co-organizer contact authority does not grant Project publishing.** See docs/development/group-attributed-projects.md.
3. Project chat: auth-scoped canonical history, send receipts, identifier-only Realtime hints and scoped reports. It is **not** a permanent Group chat. See apps/mobile/lib/features/project_chat/.
4. Messages: current Private/Groups views, server-paged chat projections, durable unread/read acknowledgement, identity-bound refresh. Inspect current kinds and evolving RPCs instead of assuming a fixed v5 list.
5. WORKSPACE02: multiple private named Project links with bounded pages, stable add receipts, edit versions and hostname confirmation; these rights are Project-scoped, so C03 needs a separate group-discussion ownership boundary.
6. Parallel D: Purposeful contact requests and representative conversations, with separate intended private audience and new message kind. Its D00 approval and release status must be inspected. C must not import D's unmerged code or decide D's recipient/history policy.

## Product decisions and boundary

Approved: group-scoped discussions, a visually lightweight one-level grouping/folder in Messages, reusable non-image icons for documents/sheets/calls, explicit Create Idea/Project from discussion, no universal DMs, no arbitrary unrelated chat, no automatic Project member enrolment, and no exposure of planning history on publication.

**Not yet approved:** precise room membership/invitation policy, whether all group members may enter a default General room, history for newly invited/rejoined participants, room creation/administration rights, manager succession, archiving/suppression read rules, and any retention/deletion expansion. These are *material authorization decisions*.

C00 produces a clear permissions/history matrix, distinguishes settled requirements from a **provisional restrictive proposal**, and records its approval status. An explicit founder approval of a particular model in the task/repository can satisfy this gate if scoped and cited. Passing tests or Codex's recommendation cannot approve its own access policy.

To make parallel work practical, C01–C04 may be developed and locally exercised as a **provisional review-only stack**, using C00's documented least-privilege model and synthetic Auth identities. Without explicit approval of the access/history contract, the cumulative PR remains **draft and unmerged**; no shared/hosted DB migration, real user data, deployment or public activation. Stop earlier if a security/lifecycle decision cannot even be safely isolated. An unrelated reversible UI choice may be made by Codex.

## Git branches, race avoidance and merge

The conversation branch is not evidence that a Git branch was created. Inspect current checkout/worktrees and origin before coding. If no C-owned branch exists, create one from fresh origin/main in a managed, isolated C-owned worktree. Suggested stack:

- C00 from latest main; draft PR to main.
- C01 from C00; draft PR to C00.
- C02 from C01; draft PR to C01.
- C03 from C02; draft PR to C02.
- C04 from C03; draft PR to C03.
- One cumulative integration PR based on actual latest main, **only merge after C00 authority and final gates**.

Do not push directly to main, reset/stash/rebase another agent's branches, amend their commits or close their PRs. Do not assume another stack will merge in any particular order. The C-owned worktree, local Supabase project ID/ports, fixture email inbox and emulator must be separate from A/D and retained developer resources. Avoid global Docker/cache cleanup. Source merge order is decided by actual readiness; whichever stack merges later reconciles against new main.

**Shared contention areas:** Messages discriminators and projected inbox/unread, navigation/router, localization, generated DB types, report/blocking/notifications, package scripts/migration timestamps, and Account deletion. C can initially own a separate bounded Group-discussion feed/destination rather than independently replacing an existing global unified messages RPC. When D lands, reconcile the intended conversation kind and unread contract once. No client-side global mixing of separately capped first pages into a falsely complete sorted inbox. Document exact merge conflicts and cumulative schema effects.

C must not touch A's onboarding/Idea ribbons/Project workspace migration except narrow reuse of component/presentation APIs. Do not cherry-pick D's speculative access model into C; no generic universal room abstraction if the existing types are domain-specific. Use domain-owned group_discussion endpoints/adapters and a small shared seam only when evidence requires.

## Security, data and UX invariants

All protected operations authenticate an actual personal actor and verify canonical Group role/membership/room admission on the backend, including after lock waits. A member's Group episode and room admission should not silently confer Project chat membership. Avoid cross-room and cross-group leaks in history, unread counts, notification previews, Realtime hints, report evidence, public group pages, templates, logs and generic events. Staff visibility requires explicit report authority, not ordinary user access.

All list/message/link reads use bounded keyset pages with stable tie-breakers and deliberate Load more / anchored older messages. No all-groups/all-rooms/all-messages preload, per-row backend fan-out or unstable recombination across unmerged APIs. Replay a frozen actor/action/intent for ambiguous writes. Client state is account-scoped and invalidated on A → B → A, profile/policy changes and permission revocation.

Private Realtime is a hint; durable RPC remains the authority. Follow existing moderation/report/blocking, policy, account erasure and retention rules without manufacturing deletion periods. EN/IT, accessibility, 320px layouts and existing Messages navigation are mandatory.

## Native QA and rollout

Physical Android identifier: 48091FDAS0041A, but run against it only after reviewing installed build/test data and explicit test-safe setup. An owned emulator plus an owned local backend is the ordinary source-merge QA. Do not wipe or replace the installed Play test build. iOS, TalkBack and physical QA must be reported accurately if not run.

Local destructive SQL reset/upgrade must point at an identified disposable C-owned Supabase instance; never staging/production/shared. Apply forward-only schema changes and regenerate database types. Source merge is not hosted migration. No Google Drive provider access/credentials, downloads, paid APIs, deployment or store submission is needed or authorized.

## Completion deliverables

Each stage includes code/tests/docs, a draft PR/head and exact validation results. C00 remains available as reviewable permission matrix. Final report: implemented stage statuses, approval evidence or remaining decision gate, merged integration PR/commit **only if actually merged**, native test evidence, schema/compatibility changes, conflicts with D/A, unrun tests and external rollout steps. Do not claim a group chat feature is released merely because source was merged.

Read root/nested AGENTS.md, docs/development/codex-tooling.md, implementation_plan_sections_suggestions.md, current feature README/ADRs, generated contract owners, and effective later SQL migrations before choosing methods. No required outside document; this prompt contains necessary product context.
