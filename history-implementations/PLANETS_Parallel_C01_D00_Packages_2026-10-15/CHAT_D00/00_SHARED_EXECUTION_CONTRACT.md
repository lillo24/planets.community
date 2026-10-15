# Shared C01 / D00 execution and integration contract

**Package version: PARALLEL-CD-2026-10-15-v1.** Both chats receive this identical contract. It is part of each complete package, not a third task or a requirement to create an integration chat.

## 1. What the user authorized

The user wants the existing **C01** and **D00** Codex chats to implement their respective packages **in parallel**, inspect the latest repository themselves, reconcile intervening changes and merge their completed work. The first ready package may merge first. The second incorporates it, validates the combined result and merges. Do not wait for an absent third coordinator.

This supersedes the previous instructions that all D/member-contact work must wait for C, that neither lane may merge until one external integration task runs, and that the founder must coordinate ordinary Git conflicts. It does **not** approve unresolved privacy policy, obsolete provisional C00/D00 defaults, failing tests, deployment or silently incomplete work.

Read your entire package before implementation. The chat names identify existing conversations: **C01 owns the complete revised C lane, not just the old backend stage; D00 owns the complete D/contact lane, not just a design document.**

The desired early finish is a prioritization goal, not permission to suppress a failure, skip a meaningful gate, invent approval, or claim a time estimate. Reuse the existing implementations and focus verification on actual changes.

## 2. Live repository evidence and starting points

Repository: `lillo24/planets.community`.

Inspected on 15 October 2026:

| Item | Observed state | Meaning |
| --- | --- | --- |
| `main` | `7d4b429019f8d334468e56ca9db465f5ac23d8a8`, documentation handoffs #261 | Reference snapshot only. Fetch latest; never reset main to this SHA. |
| Batch A #243 / GRP03C #241 | Merged earlier | Reuse personal/group registration, Idea cards, named Project links and group-attributed publication. |
| C cumulative #257 | Draft, unmerged; `codex/c-integration`, `e8c5c8c7317cf0df22b9a534200586637e7b18f2` | Reuse C00–C04 ancestry. Its old access/history policy is superseded by the revised C contract. |
| D cumulative #254 | Draft, unmerged; `codex/d-integration`, `db17cd2d5eae0b502243c885e08cbe33b3472c04`; merge conflict reported | Reconcile rather than rebuild. Some D audience/history choices remain provisional; final native journey was incomplete. |

Links: [C #257](https://github.com/lillo24/planets.community/pull/257), [D #254](https://github.com/lillo24/planets.community/pull/254), [A #243](https://github.com/lillo24/planets.community/pull/243), [GRP03C #241](https://github.com/lillo24/planets.community/pull/241).

Old C stages: #246 → #248 → #250 → #251 → #252. Old D stages: #244 → #247 → #249 → #253. Their test results qualify those exact historical sources only. Read actual current heads, comments and diffs before reusing them; follow linked successors if work has advanced.

`main` also contains STAGING01 evidence and other prompt/UI handoffs. Preserve intervening changes. Prompt files are not proof that their features have been implemented. Do not repeat an already executed staging procedure, and do not treat its authorization as permission for new migrations.

Read root/nested `AGENTS.md`, `implementation_plan_sections_suggestions.md`, relevant architecture/feature maps and effective code. In particular inspect:

- `docs/architecture/product-decisions.md` and `docs/architecture/system-design.md`;
- `docs/development/group-membership-and-roles.md` and `group-attributed-projects.md`;
- your lane's existing feature, integration, evidence and rollout documents;
- the current definitions of RPCs after **all** migrations, not only the first function declaration;
- applicable open UI-polish work before editing shared presentation.

Paths in stage prompts are navigation hints unless explicitly verified. Locate their current equivalents rather than creating duplicate owners when names have changed.

## 3. Scope ownership and common terminology

| Responsibility | C01 chat owns | D00 chat owns |
| --- | --- | --- |
| Persistent Group conversations | General, Group Ideas, room visibility/entry/history/settings | No parallel implementation |
| Invitations to Group Ideas | Canonical room invitation/capability, accept/decline, room-member picker | Reuse C action from compact person context only when available |
| Links | Group-wide, room and converted-Project handoff; external-channel guidance | Reuse link widgets only where expressly in contact scope; no new contact file-storage system |
| Conversion | Proposal/review/publication, opt-in Project invitations, protected continuous timeline | No conversion implementation or Project authority changes |
| Personal contact within a Group | Do not create a second personal messenger | Consent-based member requests and 1:1 conversations |
| Group-to-group contact | Do not import unfinished D | Representative requests, accepted chats and multi-group consent |
| Shared UI/backend boundaries | Preserve the other lane; integrate what has landed | Preserve the other lane; integrate what has landed |

A **Group manager** is its current Creator, Co-creator or Co-organizer. A **Group publisher** is its current Creator or Co-creator under GRP03C. A **Discussion Creator** is the human who starts a Group Idea, not automatically a Group manager or Project publisher. Project management/participation remains independent of Group roles.

Manager oversight of **Group Ideas** does not confer access to **personal member chats** or every **representative conversation**. A Project participant does not become a Group member. Membership, representation, room admission, personal-chat consent and public Project publication are separate grants.

Keep human attribution real. Never send as an imaginary Group account, turn an invitation into a fake human message, or use a Project join request as an authorization shortcut for private contact.

## 4. Approval and autonomy

Maintain a small decision ledger distinguishing:

- **User decision:** explicitly stated in this package or backed by an actual later user response.
- **Existing implemented contract:** verified in current main; preserve unless this task changes it.
- **Implementation choice:** reversible detail consistent with the approved behavior; decide and record without another approval pause.
- **Unresolved product/privacy decision:** not authorized merely because a draft implements it or tests pass.

C's revised General/Ideas and Option A decisions are supplied in full. Do not ask those questions again or leave the old C00 matrix labelled as the only available policy.

D's public representation roles and consent-based contact direction are approved; **the exact pending/accepted audience, former-representative history, replacement-manager history, and member-chat behavior after shared-Group exit are not all settled**. D-R00/M00 identify the precise gaps. First inspect actual approvals already available in your Codex conversation/repository; do not re-ask a question already answered. Do not broaden a Group-Idea answer to an unrelated personal or representative chat by inference.

Continue independent work when one decision is blocked. An unresolved consequential choice may remain in a clearly identified synthetic review branch; it must not be smuggled into a production-callable endpoint or merged as approved merely behind an app flag. An independently safe, complete subset may be delivered separately if its scope and exclusions are explicit. Do not call that completion of the whole package.

Ordinary naming, layout refinement, correct component reuse, conflict resolution, query implementation, tests and isolated resource setup belong to Codex. Escalate only concrete consequential gaps, new costs, missing required external evidence or demonstrable security/architecture conflicts.

## 5. Git and merge procedure — each chat owns its finish

1. Inspect your existing worktree(s), uncommitted work and stage/cumulative PRs. Preserve unrelated work. Reuse the appropriate cumulative source or a traceable successor; never restart from an old stage simply because the chat is named C01/D00.
2. Work in isolated branches/worktrees. Keep the package stages reviewable and commit/push intended files. Stage PRs may target their predecessor. They are not individually merged into main before the lane is coherent.
3. Publish your own cumulative PR and a short lane handoff early enough for the peer to inspect it. Use lane-specific documentation filenames; record actual API names, migrations, shared seams, policy gates and tested head. No recurring bot, synchronization service or third coordinator is needed.
4. Do not modify/force-push/close the peer's active branch or PR. Do not import unfinished peer code merely to get a version number. You may inspect it and use local throwaway merge-tree comparisons without changing its state.
5. Before final validation and again before merge, fetch latest main, inspect its diff, incorporate it and reconcile shared behavior. If the peer has landed, this is now the combined validation task for your lane. If the peer has not landed, finish your coherent standalone lane; do not wait solely for it.
6. Required tests/CI must correspond to the actual reconciled source. A previous green run is not evidence for changed runtime, migration order or interfaces. Reuse identical-source evidence honestly, but run changed-area and cross-lane tests when warranted.
7. Merge your cumulative result after required checks, current mergeability and scoped approval gates pass. Use existing repository merge facilities; do not bypass protection, force-push main or create a new custom merge-lock service. If main advances, reassess/revalidate before merge. If concurrent merges are detected, verify the resulting combined main and promptly prepare any required correction rather than declaring a stale head final.
8. Confirm the merge commit and effective features on main. Close superseded **own** stages only after ancestry/equivalence is proven; do not erase unfinished changes. Remove only your finished worktrees/branches and owned temporary services. Respect policy-denied cleanup; report residual paths without working around the denial.

This is authorization for source PR merges meeting the above conditions, not for blanket approval of old drafts. **No hosted database operation, deployment, store upload, DNS/billing change or real-user communication is authorized.**

## 6. Shared seams: reconcile behavior, not just conflict markers

The prior C/D comparison found overlapping Messages, unread, router, moderation, localization, generated types, package scripts and CI files. The live overlap may differ. Relevant inspected paths included:

`apps/mobile/lib/app/router/app_router.dart`; `features/messages/data/message_unread_gateway.dart`; `features/messages/presentation/messages_screen.dart`; mobile moderation models/gateway; `app_en.arb` and `app_it.arb`; Web moderation models/server/components; `apps/web/src/types/database.generated.ts`; `package.json`; `.github/workflows/validation.yml`.

Both chats may make necessary scoped edits in their own worktrees. No exclusive-file protocol is imposed. The later merger must ensure:

- **Inbox/list composition:** all implemented kinds survive union/filter/order/paging before limits. No final adapter selects only C or D and loses Project/Resource/request histories.
- **Unread and read ACK:** preserve the installed meaning of totals, count each canonical conversation/message only once, and exclude invitations/system notices from human-message counts. One history shown in a folder and via another route is not two histories. Muting and hiding are not marking read. ACK requires the actually rendered, foreground authorized frontier.
- **Realtime:** compose every relevant invalidation source, including access loss. Older authorized sockets and stale UI caches cannot grant durable content. Identity A→B→A, resume and reconnect invalidate correctly.
- **Routing/continuations:** use typed, validated contexts. Profile/setup/login may return to an action but never send, accept, join or publish it automatically. Preserve selected Group, scroll, unsent input and cancel destinations where still authorized.
- **Moderation:** retain every existing report kind, exact evidence projection and valid historical report target. Staff case access is not blanket room/chat access. Never overwrite a constraint/dispatcher and drop the peer's target types.
- **Migrations:** check the actual sorted combined sequence, not just Git merge order. Old C/D migrations interleave in time. A later correction cannot repair an earlier migration that already fails against populated peer data. Keep applied/main migrations immutable; any adjustment to your still-unshipped migration must be proven unshipped, scoped, documented and tested. No casual squash, renumber or history repair.
- **Upgrade evidence:** test clean combined replay and populated predecessor upgrades when both lanes exist. Preserve existing IDs/messages/links/grants and demonstrate no duplicate backfill or lost enum/constraint case. Regenerate types from the resulting schema, never resolve generated-file conflicts by choosing a side.
- **RPC compatibility:** inspect actual signatures before allocating new versions. Do not independently assume the same unused suffix. Retain installed legacy readers/return shapes; new kinds must not reach parsers that cannot read them.
- **Localization/CI:** preserve both key sets and verifiers; regenerate derived output through canonical tooling. Do not disable classifications, required statuses or meaningful assertions to make integration pass.

Record a compact machine-/human-readable handoff using existing repo conventions: lane, source SHA, included main SHA, migrations and applied assumptions, RPC signatures, domain kinds, UI entry points, authorization summary, commands actually run, and pending decisions. Use separate C and D filenames. The peer can read it through GitHub; the founder is not the synchronization mechanism.

## 7. Data, privacy and performance guardrails

Use the installed Flutter/Supabase/PostgreSQL architecture. No universal-chat rewrite, paid service, provider switch or broad dependency upgrade. Verify version-sensitive API/CLI behavior against installed manifests/lockfiles and current official documentation before coding. Relevant references: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Realtime authorization](https://supabase.com/docs/guides/realtime/authorization), [changelog](https://supabase.com/changelog). These references are not a reason to update dependencies.

Canonical backend authorization is mandatory for every private read/write/list/preview/unread/report/link action. Keep least-privilege grants, RLS, constrained search paths and current identity checks; privileged functions do not remove the need for explicit authorization. Roles come from current canonical records, not client claims or editable profile metadata. Do not expose service credentials in a client.

Use immutable identities/provenance, explicit current grants, scoped command UUIDs, expected versions and safe recovery. A receipt proves an earlier result, not present authority. Equal timestamps, simultaneous role/membership changes and accepted-but-lost replies need deterministic tests. Never turn an unknown result into successful empty data or reissue Add/Publish with a new key just to escape uncertainty.

All lists/history/member pickers/notification projections are bounded with stable cursors. No whole-Group client download, per-row profile/photo/role fanout or unbounded synchronous notification fanout. Use existing bounded delivery mechanisms; adding an event is not proof that an external push provider delivers it.

Private message bodies, room descriptions, manager/member rosters, invitation capabilities and link destinations stay out of public projections, templates, generic audit events, analytics and screenshots with real data. A metadata identifier can also reveal private context: return it only where authorized. Preserve photo/profile visibility independently.

No new legal verification, personal rating, point/badge formula, personal-data mandate, lawful retention period, account-deletion delay or E2EE claim. Keep existing deletion/report obligations, inventory new data and separate source correctness from distribution-policy work.

## 8. Efficient verification and local resource isolation

Use focused unit/widget/SQL/Auth tests at each stage and a full affected-area checkpoint for each final lane. Do not repeat an unchanged full suite after every documentation edit. Do not count mocks as real backend tests, widget screenshots as physical-device evidence or partial native runs as passes.

Inspect current scripts before running them. Known repository entry points include `npm run check:mobile`, `check:web`, `check:site` where affected, `check:db`, `db:types:check`, and lane-specific authenticated and populated-upgrade verifiers. `check:db` and upgrade helpers may **reset the selected local database**.

C and D must have different task-owned database project IDs, ports, temporary defines, emulator identities and mutable configuration paths. Reuse a clearly owned isolated workdir when available. Never run parallel destructive tests against the shared `planets-community` stack or change an engine/daemon used by the other chat. Both may compile concurrently; limit their own workers when host resources contend without weakening assertions or extending unexplained timeouts.

Synthetic local accounts only. Credentials/OTP tokens stay outside Git and logs. Inspect actual tool/engine paths rather than hardcoding the previous user's Windows home. Physical device ID, when an explicitly authorized non-destructive smoke is available: **48091FDAS0041A**. Do not reset/reinstall/overwrite its current app or point it at an unreviewed backend merely because it is attached. Use owned emulators by default; neither chat may seize the other's emulator.

Final evidence must cover real backend consent/history/revocation/retry boundaries, final-source Android emulator flows and actual rendered EN/IT narrow/large-text screens. Record physical Android, iOS, screen-reader and real-provider work separately when not performed. Do not treat a policy-denied deletion of an old emulator/define file as permission to bypass policy.

## 9. External context and required delivery

The required design context is embedded in each complete package. No Google Doc, earlier downloadable package, screenshot on the founder's disk or external chat transcript is required. Repository read/write/PR access and a supported isolated local test environment are required for implementation and merge. Missing optional physical/iOS/provider resources do not block unrelated code, but missing required acceptance evidence blocks the affected final gate.

No live Supabase access is required or authorized. No partner-chat API is required: inspect pushed branches/PRs, main and their repository handoffs. When a genuinely required outside source or explicit privacy decision is unavailable, identify it precisely and pause only the dependent scope; never invent it.

Return: implemented vs pending features; final PR/merge/head refs; included main/peer heads; approval/default ledger; tested commands and actual results/skips; migration/replay/preservation and cross-domain evidence; rendered/native artifact locations; exact remaining decisions/environment work; no-hosted-change confirmation; owned cleanup and residuals. Never say both packages are merged merely because your lane is merged.
