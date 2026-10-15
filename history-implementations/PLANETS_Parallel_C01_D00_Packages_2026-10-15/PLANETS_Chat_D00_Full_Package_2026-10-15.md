# PLANETS — Complete package for the existing D00 Codex chat

Version: **PARALLEL-CD-2026-10-15-v1**. Send this entire file once to **D00 only**. It contains its start instructions, the common parallel merge contract and all of its ordered implementation prompts. References to stage filenames below identify embedded sections; no other upload is required.


---

<!-- BEGIN EMBEDDED FILE: 00_START_HERE_D00.md -->

# Send this package to your existing D00 Codex chat

**Task:** Finish the Group-contact lane and add the requested Group-scoped member-to-member contact work, in parallel with the C01 chat. Follow `00_SHARED_EXECUTION_CONTRACT.md` and the eight stage prompts below. The D00 chat is the implementation owner for the complete lane, not merely a document author.

## Scope and base

Reinspect and reuse cumulative D #254 (`codex/d-integration`, last inspected `db17cd2d5eae0b502243c885e08cbe33b3472c04`) and D00–D03 ancestry. Existing code already implements representative requests, bilateral chats, multi-group consent, typed Messages/safety integration and some native QA. Reconcile current main and repair remaining work; do not rebuild D or cherry-pick only the first stage because this chat is called D00.

The **C01 chat** revises Group General/Ideas, room invitations/history, folders, links and Idea-to-Project conversion. It may merge before or after you. Your member-contact work uses already-merged Group People/roles and **does not wait for C to merge**. Do not import C's unfinished branch. If C lands, integrate its shared changes and test the combined result. The first complete, approved and validated lane may merge first; no third integration chat is required.

## Requested behavior already established

- Group Creator, Co-creator and Co-organizer may represent their Group for purposeful inter-group contact. Ordinary Group membership does not grant representation. Co-organizer contact permission is not GRP03C publishing permission.
- Inter-group communication is between authorized humans with their Group context, not automatic membership in both Groups or a public generic direct messenger.
- People in a Group may request a private conversation with another current Group person without a Project/join-request prerequisite. Recipient acceptance is explicit. This is **personal member contact**, a separate domain from acting on behalf of an organization.
- A compact profile/person sheet and understandable contextual action menu are wanted. Where relevant, participation uses the existing join mechanism, proposing collaboration uses representative contact, requesting a personal conversation uses the shared-Group consent flow, and inviting to an Idea uses C's room operation. Do not conflate their permissions because they share an icon.
- Group membership gives access to the Group's private People list under its existing rules, not a new public user directory or public disclosure of affiliations/photos.
- Invitations/requests must be clear, deliberate, recipient-visible and reportable. Selecting a person, opening a screen or completing login never sends/accepts one automatically.
- No arbitrary global user-created group chats. Multi-group coordination remains a purpose-bound, invited representative feature.
- Personal accounts remain the actors; no Group passwords, fabricated sender identities, public person ratings, new mandatory personal data or paid messaging provider.

These choices do **not** grant Group managers oversight of private member-to-member conversations. The C rule “managers can always see Ideas” applies to Group planning rooms, not all communication between Group members.

## Precise remaining approval boundary

The old D00 contract explicitly marked several choices provisional. The current instructions authorize parallel work and source merging when ready; they do not silently settle all those privacy choices. Inspect actual later user decisions already in this Codex chat/repository before reporting a gap.

Still unresolved in the supplied conversation: whether pending representative notes go to all target managers or a named representative; whether accepted chats are only the first acceptor or shared across managers; historical access after role loss/regrant/replacement; exact multi-group audience disclosure/history; and continued personal messaging/history after leaving a shared Group. Individual-to-Group proposals outside shared membership were discussed tentatively, not universally approved.

D-R00 and D-M00 provide concrete review choices and bounded provisional test directions. **Do not relabel an assistant recommendation, this package's example, existing draft code or green CI as user approval.** Finish synthetic implementation/verification for unresolved scopes, but leave those source changes isolated and unmerged until the necessary decision exists. Continue independently mergeable, approved work rather than stopping both chats. Report a narrow missing decision instead of a generic “manual approval required” banner.

This is not a fresh request to ask all 16 C questions. C's supplied General/Ideas and conversion rules are settled and belong to the other chat.

## Context from the parallel C lane that you must preserve

C will add automatic pinned General; configurable member Idea creation; Group-visible/invite-only Ideas with manager oversight; full earlier room history after entry and bounded former history; structured Idea invitations/notices; Group folders with Projects plus General & Ideas; separate hide/mute; Group/room links; and conversion to public Project with opt-in invitations and separately protected planning/Project history.

Do not apply C's full-history or manager-oversight predicates to member or representative chats. Do not merge its private planning messages into a contact room or give new representatives Project membership. C's member picker may call your consent-based member action once it exists; your person sheet may call C's invite-to-Idea action once C exists. Keep these as shallow integrations over each domain's canonical operations, not mutual build-time dependencies on unmerged code.

## Sequence and delivery

D-R00 decisions/current delta; D-R01 existing representative contact; D-M00 member-contact policy; D-M01 member backend; D-M02 contextual People/UI; D-R02 multi-group coordination qualification; D-R03 Messages/notifications/C integration; D-R04 final validation and source merge.

Read D-R00 and D-M00 before changing persistence. Approved independent tasks can proceed out of order where their actual dependencies permit. A policy-blocked M/D feature may remain an isolated draft while a complete approved subset merges, but must be listed as not delivered. Do not claim the whole package merged if that is not true.

<!-- END EMBEDDED FILE: 00_START_HERE_D00.md -->

---

<!-- BEGIN EMBEDDED FILE: 00_SHARED_EXECUTION_CONTRACT.md -->

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

<!-- END EMBEDDED FILE: 00_SHARED_EXECUTION_CONTRACT.md -->

---

<!-- BEGIN EMBEDDED FILE: 01_D_R00_DECISIONS_AND_DELTA.md -->

# D-R00 — Contact decision ledger and a focused revision plan

## Objective

Reuse D00's existing contract and reconcile it with actual user decisions, current main and this package. Identify **specific remaining choices**, not an open-ended product questionnaire. The user delegates implementation and Git integration, not unrequested private audiences.

## Inspect current evidence

Read #254 and current successors/comments, stage #244/#247/#249/#253, effective D code/migrations and:

- `docs/development/group-contact-contract.md`;
- `group-coordination-protocol.md` and `group-contact-mobile.md`;
- `group-contact-integration-evidence.md` and `group-contact-rollout-delta.md`;
- current Group People/roles, GRP03C, participation-pair conversations, reporting/blocking and Messages contracts;
- the C peer's current handoff, read-only, without treating its earlier source as main.

The last D cumulative report described green CI but **no completed final native journey** and no founder reference for D00's privacy table. Neither defect is repaired by changing the PR description to ready.

## Decision ledger to resolve or explicitly preserve as pending

| Topic | What is fixed | Existing/proposed candidate to evaluate; NOT automatic approval |
| --- | --- | --- |
| Acting for a Group | Creator/Co-creator/Co-organizer, real human attribution | Both existing informal/organization types; no legal-verification requirement. Confirm any actual restriction instead of inventing one. |
| Initiation | Purposeful Group-to-Group contact is wanted | Individual-to-Group without shared membership remains deferred absent explicit approval. |
| Pending audience | Recipient review is necessary | Current D exposes the request to eligible target managers, rather than a named-only representative. Which audience is approved? |
| Accepted audience | No automatic whole-Group enrollment | Current D admits sender and first accepting human only; other managers receive no chat history. Check explicit approval. |
| Representative role loss | Losing authority ends new representation | Current D also removes all past history permanently for that grant. Retained pre-exit history is an alternative; C's choice does not settle D's. |
| Replacement/regrant | No invisible takeover of another person's personal identity | Decide whether new/regranted managers ever inherit old representative history and what consent is required. Existing D grants none. |
| Multi-group audience | Explicit invitations; no automatic Group-member addition | Existing D requires named/versioned all-party confirmation in stages and a fresh room without prior history. Confirm consequential disclosure/history rules. |
| Personal member chats | Shared-Group contextual request then explicit acceptance | D-M00 settles source Group, continued messaging after exit and retained history; do not inherit D representation loss semantics. |
| Operational bounds | Bounded queries, duplicate/rate protection, safe exits | Existing exact cooldown/expiry/group-seat quotas are provisional. Centralize/test; don't present punitive or restrictive values as founder decisions. |
| Distribution/retention | No live rollout or new legal policy in this task | Record new data/recipient disclosures and actual existing deletion rules; do not invent indefinite retention, auto-deletion or legal approval. |

Look for actual user responses available in this chat or linked repository decision records before marking a topic unresolved. Quote the relevant response/date accurately in the ledger, without inventing a transcript URL. Keep per-row status, rationale, implementing functions and tests. A single “D approved” toggle is insufficient.

## Autonomy, review-only work and merge scope

Implement ordinary fixes, add missing tests and complete synthetic native journeys without another routine approval pause. Where a consequential row is unresolved, retain the current conservative draft candidate only as a **clearly labelled local/review test model**; do not enact it for real users or claim acceptance. Compare the minimal alternatives using two-person and role-loss examples, and report only the remaining delta.

A pending endpoint/persistence contract cannot become source-merge-ready through a client flag, unreachable button or a previous desire to finish quickly. Keep dependent runtime commits isolated. Independent corrections/tests/docs may progress; a safely isolated approved feature may be merged through a clearly scoped PR if complete. Do not mark old provisional D code approved wholesale or make C wait.

## Handoff

Commit the actual D decision ledger, scope/dependency map, source/data delta, test matrix and peer interface notes. Include one end-to-end example for ordinary member contact, one for representative contact, and one for adding a third Group. Continue D-R01/D-M00 and independently executable work. Never stop after writing a design document when implementation work is authorized and unblocked.

<!-- END EMBEDDED FILE: 01_D_R00_DECISIONS_AND_DELTA.md -->

---

<!-- BEGIN EMBEDDED FILE: 02_D_R01_REPRESENTATIVE_CONTACT.md -->

# D-R01 — Reconcile and finish the existing representative-contact implementation

## Objective and scope

Bring the already-written D01/D02 contact requests and bilateral conversations onto current main and the resolved D-R00 contract. Reuse code, receipts, tests and evidence; do not create another group-contact subsystem. This stage does not depend on C's new General/Idea domain.

## Functional behavior

A current authorized representative deliberately selects the Group they speak for and the eligible destination/purpose. Both personal identity and selected Group are shown clearly. Group provenance on an old public Project is not proof that its creator still represents that Group. Server authorization—not a frontend role badge—decides at submit, triage, accept and send.

Deliver the pending request to exactly the D-R00-approved audience. If the reviewed candidate is an eligible-manager inbox, disclose that audience to the sender before Send, keep resolved metadata narrow, and ensure only the explicitly accepting human gains the bilateral admission. If a later actual decision selects named recipients, implement that rather than leaving a hidden broad manager inbox. No Group-wide chat membership or automatic admission of replacement managers.

Explicit Send/Accept/Decline/Withdraw/Close/Leave have distinct outcomes and frozen recovery identities. Opening a public Group/Project/profile or completing OTP never sends/accepts. Received notes are requests, not fake human chat messages. Preserve purpose, sender, represented Group and safe destination context without publishing private rosters, affiliations or exact meeting details.

Only approved current admissions may read/signal/acknowledge/send, and the chosen history contract must be consistent across body, exact-message, list preview, latest timestamp, roster, unread, report context and stale cached state. Test role grant changes/revocation/regrant, account erasure, Group availability and blocking after lock waits. Do not silently keep the old permanent-history-loss choice if the founder approves retained history—or silently change it based on C.

## Preserve privacy, retries and safety

Keep sender/actor/Group IDs and request intent frozen through unknown replies. Distinguish an original receipt from current access. No duplicate request/conversation/admission on exact replay; altered input cannot reuse an accepted key. A “no result” must not disguise a failed command or a revoked route.

Use the installed canonical blocking locks/helpers and fail-closed authorization. The policy for a block involving another target manager must follow the resolved recipient model, not an arbitrary list fetched by the client. No private block direction disclosure. Reporting/withdraw/leave retain their safe scope and cannot be rate-limited into inaccessibility. Genuine report evidence is exact and case-bound; staff role alone never opens the conversation.

Retain existing Project/Resource/request conversation IDs, history and consent. Do not route all member chat through representative APIs or broaden a current-manager predicate into a universal personal-contact grant.

## Technical work

Inspect actual D migrations and affected main code; resolve current conflicts before extending the lane. Preserve legacy Requests/Chats/unread and old parser behavior. Reallocate API versions only after inspecting both lanes. Keep fixes additive where history may already be applied; follow the shared migration/replay discipline.

Reuse D's local native harness but repair its demonstrated driver/scroll/lifecycle failures with tests, not longer unexplained waits or relaxed assertions. Identify what was injected (fixture Auth, response loss, mocked launcher) versus genuine real-backend UI interaction.

## Acceptance

Real synthetic accounts from separate Groups; every manager role; ordinary member denial of representation; multiple possible represented Groups; self/duplicate targeting; two target acceptors racing; source/target role changes; block/consent/retry/closed state; approved old-history/replacement behavior; no public/private data cross-leak; several list/history pages; exact reported-message evidence. Complete the final native contact journey or clearly leave that qualification outstanding for D-R04.

Code for unresolved recipient/history choices stays review-only. Once decisions and tests are resolved, include it in the final D cumulative result; do not independently merge obsolete D01/D02 stages.

<!-- END EMBEDDED FILE: 02_D_R01_REPRESENTATIVE_CONTACT.md -->

---

<!-- BEGIN EMBEDDED FILE: 03_D_M00_MEMBER_CHAT_CONTRACT.md -->

# D-M00 — Private conversations between Group members: focused contract

## Objective

Define the smallest consent-based member-to-member feature the user requested. It can be built against current main's Group People/roles before C lands. This is **not** a Group-representative conversation and **not** an Idea invitation.

## Fixed requested flow

A current Group person opens that Group's authorized People list, selects another current person, and chooses **Request conversation**. An optional bounded introductory note may accompany the request. The recipient sees the real sender, the shared Group context and Accept/Decline. Only their explicit acceptance starts an ordinary private human conversation. No Project request, fake Project, membership admission or manager endorsement is required.

Current Group managers may use this as people; their Group role does not give them oversight of other people's member chats. No publicly searchable people/contact directory or permission to contact arbitrary IDs. Request delivery is consent to receive a request, not unlimited free-form chat before acceptance.

## Specify and resolve before a production-capable implementation merges

1. **Shared context:** which existing Group relationship grants request eligibility (use canonical Group People rather than only ordinary member rows)? A pair may share multiple Groups. The selected origin Group must be visible to both; do not disclose other shared/private affiliations unnecessarily.
2. **Pending and accepted lifetime:** must both remain in that origin Group at request acceptance? After acceptance and either person leaves, do new messages stop or may the independently consented personal chat continue? The supplied conversation does not choose this. Do not copy D's representative revocation or C's room-history policy into a personal conversation without explicit approval.
3. **History and rejoin:** after loss of shared membership, rejection, Close, Leave or Block, who keeps previously received history, through which immutable boundary, and can a new membership silently revive sending? Keep ordinary retained history distinct from data deletion. No retroactive history opening to other Group members.
4. **Conversation identity:** how are repeat requests, A→B/B→A simultaneous requests and several shared Groups deduplicated? Prefer one stable canonical personal conversation per deliberately chosen approved scope, but do not merge it into the existing Project requester/creator conversation or another group's chat without consent.
5. **Request limits:** use neutral bounded note/message sizes, deduplication, server rate limiting and a sane re-contact policy consistent with existing safety controls. Exact cooldowns are configurable documented operational values; a substantive permanent rejection/ban policy needs approval. Exit/report operations remain available.

## Concrete provisional review candidate

For synthetic implementation and comparison, the narrow candidate is: current source Group People at request and acceptance; named pair only; no manager oversight; sending permitted while both retain that source Group relationship; when it ends, preserve only authorized pre-end history read-only and stop notices; new eligibility does not silently revive a terminated episode. A durable pair/scope record can support a fresh explicit request later. This **is a candidate, not a recorded user decision**. An independently consented chat continuing after Group exit is a materially different alternative.

Where actual approval already exists in this Codex conversation/repository, use it and do not re-ask. Otherwise record the exact missing lifetime/history choice and keep dependent runtime source isolated until it is settled. Continue independent D fixes, UI prototypes and synthetic tests.

## Output

A compact actor/state/history matrix, source-of-truth and idempotency design, entry/action copy, privacy/report/mute/notification behavior, no-new-grants list and testable worked example. Identify actual owner modules after inspecting the repo; no prescribed table/class names or general chat refactor. D-M01/M02 may proceed with clearly isolated synthetic work, but no silent source merge of an unresolved private audience.

<!-- END EMBEDDED FILE: 03_D_M00_MEMBER_CHAT_CONTRACT.md -->

---

<!-- BEGIN EMBEDDED FILE: 04_D_M01_MEMBER_CHAT_BACKEND.md -->

# D-M01 — Canonical Group-member conversation requests and private chat

## Objective

Implement D-M00's resolved member-contact state machine, reusing the repository's narrow messaging/receipt/read infrastructure where it genuinely matches. Do not broaden representative or Project request permissions. Runtime source remains review-only for any unresolved D-M00 history/lifetime rule.

## Request and consent

Authenticate the expected real actor, verify the selected Group and both people's canonical eligibility, and enforce Block/rate/deduplication rules server-side. Only the named target may accept/decline. Targeted request previews disclose only the approved sender/shared Group/context/note and no unrelated roster or hidden profile/photo fields. Own withdraw and known-request reporting remain usable through their safe contracts.

Request creation must not create a Project, Group membership, delegate role, Idea admission, empty public profile or free-form conversation with unsolicited messages. Accept atomically creates/reuses only the approved member-pair conversation/admission episode and the receipt. Return current and historical state separately.

Handle simultaneous reversed requests, duplicate Accept, lost response, expired/withdrawn/declined request, Group leave/role loss during lock waits and account deletion. Freeze command identity and exact intent; never create two conversations by allocating a new key after uncertainty. Avoid new actors or membership state in JWT/user-editable metadata.

## Message and lifetime rules

Keep member contact a separate typed conversation kind or equivalently isolated canonical authorization owner. Reuse pure transport/feed UI primitives where possible; do not copy grant semantics from D. Enforce the chosen current/retained-history predicate across list/preview/body/latest activity/people/unread/ACK/subscriptions/exact message reads. An original request's UUID is not permanent authority.

Each message is immutable human-authored text under the repository's current messaging contract. Apply bounded history with a deterministic tie-breaker/sequence, genuine incoming-human unread and foreground snapshot ACK. Back-history access on re-entry, Close and loss of Group context follows the approved M00 rule. Do not choose between active-after-exit and read-only-after-exit merely to get tests green.

## Delivery and safety

Provide actionable member-contact requests in the canonical Requests surface and a clear activity notification using existing delivery facilities. New human messages follow approved notification/mute behavior without adding copies to the activity inbox contrary to the existing message-alert separation. Hidden/collapsed UI is not unsubscribe or read. Former/ineligible recipients receive no notices beyond the approved lifetime contract; queued delivery rechecks eligibility.

Private realtime emits minimal recipient-authorized invalidations, not message content to a shared Group channel. Group managers cannot subscribe to members' personal conversation bodies. Account/role/membership changes clear private caches and invalidate old request/read tokens. Late A→B→A results do not restore prior state.

Block/Report must exist before release. Preserve exact case-bound evidence and known-content reporting after the user's read grant ends, without rereading all chat contents. Do not assume an unmerged suspension/retention subsystem exists; integrate canonical merged controls and document remaining independent rollout work.

## Compatibility, migration and evidence

Forward migration with least-privilege explicit grants/RLS and no new public roster APIs. Preserve existing Group, C, representative, Project/Resource and request records. Stable IDs, raw provenance and no new account-deletion blockers unless deliberately approved. Regenerate types, add bounded real-Auth/SQL tests and populated upgrade fixtures. Test a member who is also a manager so personal/representative scopes cannot be confused.

Acceptance corpus: two legitimate current Group people, outsider, pending Group applicant, former person, co-manager, staff, blocked pair, two shared Groups, role/membership changes, duplicate/reversed request and accept, several pages, old client, received-note report and lost response. Include explicit **manager cannot read another member's 1:1 chat** checks even while that manager may read all C Ideas.

No paid provider, encrypted-message architecture rewrite, external file access, real-user messages or hosted operations.

<!-- END EMBEDDED FILE: 04_D_M01_MEMBER_CHAT_BACKEND.md -->

---

<!-- BEGIN EMBEDDED FILE: 05_D_M02_MEMBER_ACTIONS_UI.md -->

# D-M02 — Compact People/profile actions, personal request inbox and chat UI

## Objective

Make the approved member-contact and existing representative workflows discoverable without an unrestricted “message anyone” button. Reuse current Group People, sanitized profile/photo and Messages components. Depends on D-M01 for functional member contact; can prototype while its precise contract is reviewed.

## Contextual action sheet

Tapping a person in an authorized Group context opens a compact sheet, not necessarily a new full-screen profile. Use visible action text plus an accessible icon/menu. Show only actions justified by the actor, target and real context:

- **Request conversation:** current shared-Group person, M00/M01 consent flow.
- **Invite to an Idea:** the C-owned room invitation action, with eligible room/picker checks; it is not a personal chat or a Project join. Do not implement a second invitation domain. If C has not landed, omit this optional action until the later integrator can compose it; no dead controls or cross-branch imports.
- **Propose collaboration / idea to Group:** approved representative D flow, showing which Group the actor represents and the actual recipient audience. A member-only personal request must not expose Group-wide manager triage.
- **Ask to participate:** only where there is a specific relevant Project/Group join destination, through its normal canonical consent/review/capacity rules.
- Existing view/report/block actions retain their current scopes and privacy.

Do not automatically expose private Group affiliations from a public Project profile sheet. A public Project publisher need not currently represent the attributed Group; reread authorization before showing a contact-as-representative action. No generic “Etc.” catchall that opens unintended contact types.

## Requests and conversations

Show sender/context, bounded introductory note, current status and explicit Accept/Decline/Withdraw. Requests remain actionable invitations, not fabricated human messages. Opening the sheet/composer, selecting a recipient, signing in or completing a profile never submits. Preserve unsent text and cancel destinations within the current actor's session, reject stale actions after switch/leave, and surface unknown delivery/recovery honestly.

After valid acceptance, member 1:1 chats belong in the existing **Private** conversation organization (unless an already-approved current layout provides an equivalent), with discreet shared-Group context—not inside C's manager-visible General/Ideas area. Representative chats identify both human and represented Group; do not label a personal chat as official Group speech. Every view consumes the correct domain's private gateway.

Implement unread, foreground ACK, notification destinations, mute where approved, read-only/closed/unavailable states and paged history. Preview/title/identity photos must use existing authorized projections. A disclosure label is not permission to fetch a hidden photo or roster.

## Native and UI evidence

Actual EN/IT narrow/large-text sheets, long names and notes, keyboard/focus/Back, request cancel/retry, two accounts, target acceptance, blocked/unavailable state, switching Group context and the resolved leave/history behavior. Show an ordinary Group member can use member contact but cannot send as a Group or publish a Project. Show a Group manager can inspect C Ideas but not others' member chats.

Use the repository's actual widgets and a completed real-backend Android journey before final merge; mocks/prototypes do not certify consent. Keep missing C-specific action integration as an explicit peer handoff, not a dependency that stalls the entire D lane. The later merger must compose it when both are present.

<!-- END EMBEDDED FILE: 05_D_M02_MEMBER_ACTIONS_UI.md -->

---

<!-- BEGIN EMBEDDED FILE: 06_D_R02_MULTI_GROUP_COORDINATION.md -->

# D-R02 — Finish and qualify multi-group representative coordination

## Objective

Reuse existing D03 and complete its policy/implementation/native qualification. This is not a general channel/group-chat creation feature and does not inherit C's conversion or room history rules.

## Required invariants

Only correctly authorized human representatives may propose/join the approved collaboration audience. Ordinary members cannot claim a Group seat; no manager may consent on behalf of another human. Identify who represents which Group. Revalidate the current grant and actual group context after lock waits; Project publication provenance is not current representation.

Adding an external Group changes the private audience. Follow the exact disclosure and old-history decision resolved in D-R00. The existing conservative prototype uses a **fresh** conversation and a newly authored summary, not copied bilateral/C history; all selected humans confirm the exact audience version. Keep that a review candidate until approved, rather than saying C's “full earlier history” authorizes its opposite here.

If the exact-version model is approved, seat changes, substitutions, regrant, expired proposals or altered participants invalidate stale confirmations. Final activation is one transaction/receipt and creates only the agreed admissions. No partial consent can open body/roster/history. Bound seat/request counts and pages; no unlimited nested chat builders or recursive coordination proposals.

## History, links and independent domains

Do not copy earlier bilateral messages, Group Idea messages, private draft/workspace links, read states, report bodies or implied endorsements to newly added representatives. Source links/IDs/titles are visible only after independent source authorization. New room authorization is separate from original bilateral and Group/Project memberships; exit from one does not accidentally create or revive the other.

Role loss/replacement/leave/close/Block/group lifecycle follow the approved D contract, including how still-entitled peers read history. Do not silently choose C's read-only former access or old D's complete former denial. A manager's **Idea oversight** never admits them to this coordination room. Safe decline/leave/report cannot be trapped behind a lost content grant.

## Known evidence gap to repair

The last #254 report had partial real native interaction but no complete final native test result; driver loss and loading-only audience captures were not qualified. Reproduce with an owned emulator/backend and stable harness. Repair observable lifecycle/driver issues without weakening the audience checks or claiming a screenshot means acceptance occurred. Record injected fixtures and final source SHA.

Complete one full path with at least three synthetic Groups: bilateral request/accept, add third Group, claims/review/consent, declined or changed audience, lost final reply and recovery, resulting empty/fresh history, real send, private source denial, role loss/regrant, report/block and exit. Capture final EN/IT small-screen audience/composer/denied states after loads finish.

## Deliverables and gates

Retained/revised D03 code and types; decision-reference ledger; real-Auth/SQL race and populated-upgrade evidence; complete final-source native result; updated exact-message/report/notification compatibility docs. If audience/history approval is still missing, keep this dependent scope isolated and review-only while independent work continues. Tests cannot turn provisional policy into approval.

<!-- END EMBEDDED FILE: 06_D_R02_MULTI_GROUP_COORDINATION.md -->

---

<!-- BEGIN EMBEDDED FILE: 07_D_R03_INBOX_NOTICES_INTEGRATION.md -->

# D-R03 — Requests, private/contact chats, notices and current-main integration

## Objective

Make all approved D/M features coexist with existing Project/Resource conversations and C **when C is on main**. This stage is owned by the D00 chat; no third coordinator exists. C can merge first or later.

## Required behavior

1. Compose the actual current Requests/Chats/unread interfaces. The prior draft introduced Requests v3/Chats v6/unread v2 while old C used a separate discussion summary; those numbers are historical, not available-slot instructions. Inspect current effective signatures and version only where required. Legacy clients must not receive unsupported new kinds.
2. Preserve distinct types for Idea invitation, member-contact request, representative request, coordination consent and Project/Resource request. Filter/union before paging; stable keys include domain, not UUID alone. No disappearing requests after the first page, duplicated human unread, or forced Project request used for member consent.
3. Preserve all canonical human-message counts and existing read semantics. Activity notices and membership/invitation state are not fake chat messages. Use independently authorized ACK frontiers; a request modal or collapsed Group folder does not read a conversation. Source/Project continuity from C cannot double-count history or hide D unread.
4. Deliver explicit member/representative contact and coordination invitations in Requests plus the approved in-app notice flow. Keep ordinary chat notifications separated from the activity inbox, preserve per-conversation mute and hidden-state semantics, and do not claim external OS push is live without actual configured delivery. Notification previews/taps reauthorize; no notes, private participants or invite tokens in broad payloads.
5. Combine all account activity and access-invalidation hints. Never replace the peer's listener with yours. Clear appropriate private state on identity switch, leave, role loss and forbidden reads, including A→B→A and offline cached routes. Keep each domain's lifetime rules independent.
6. Preserve exact typed report targets, staff evidence dispatchers and own report history. Existing C reports must survive D constraint changes and vice versa, including in populated upgrades. A shared report UI grants no cross-conversation browsing rights.
7. When C is present, compose the current Group People/compact sheet with both **Invite to Idea** (C) and **Request conversation** (M), exposing each only when authorized. Preserve C folders, General pin, hide/mute and conversion. D private personal chats never become room content visible to Group managers. When C is absent, keep D/M functional using current Group People and document the optional action seam for the later C merger.
8. Reconcile localization, router setup/cancel paths, generated schema types, scripts and CI by semantics, not whole-file ours/theirs. Read incoming UI-polish changes and keep their behavior. No universal contact/search directory or unrelated navigation redesign.

## Migration and final-main hazards

Exercise the actual sorted sequence of both lanes' migrations and inspect final definitions, grants and constraints. Old C and D timestamps interleave. Test populated peer records before applying your cumulative branch: report constraints, group roles, Block helpers, unread wrappers and statement dependencies must remain valid at **each** step, not just after a final repair migration. Never modify an applied main migration as a shortcut.

Use a forward, version-compatible reconciliation strategy from the real code. A conflict-free Git merge or green isolated D suite is insufficient if the combined schema erases C kinds. Generate types from the resulting database. Record which peer/main SHA was incorporated; absence of C is explicit, not a fake empty C runtime response.

## Tests

Mixed corpus with more than one page per conversation/request kind, two Groups, member and representative accounts, multiple origins, hidden/muted Idea, pending Project invitation, closed/left chats and distinct reports. Check totals/ordering/paging, no protected context leak, current and old client contracts, account switch, consent, Group/Project independence and cross-lane role-loss rules. Run real combined upgrade/Auth/native checks where both lanes are present; otherwise finish D-only qualification and publish exact C integration requirements.

<!-- END EMBEDDED FILE: 07_D_R03_INBOX_NOTICES_INTEGRATION.md -->

---

<!-- BEGIN EMBEDDED FILE: 08_D_R04_VALIDATE_AND_MERGE.md -->

# D-R04 — Final D/M qualification, latest-main reconciliation and scoped merge

## Objective

Finish the D00 chat's implementation lane and merge its complete, approved, tested cumulative result. Do not wait for C solely because it is named earlier. Do not merge unresolved privacy choices merely because main is technically mergeable.

## Completion checklist

- D-R00 and M00 ledgers identify actual approvals for every enabled request audience and accepted/history/lifetime rule. Supported user choices are implemented; previous provisional behavior isn't relabelled approved. Any remaining consequential choice has a concrete isolated scope, candidate and missing decision.
- Representative contact works for the approved Group roles/purposes; member contact works for legitimate shared-Group people without a Project; no private manager oversight or public people directory is introduced; multi-group consent/history matches the actual agreed audience rule.
- Existing D ancestry is retained or traceably superseded; no competing member, representative or C room subsystem. Final UI clearly distinguishes the flows and gives usable consent/report/exit and truthful failure recovery.
- Real clean and populated schema qualification passes, preserving main and all implemented peer data and installed legacy contracts. Run duplicate/lost-response/concurrency, role/membership/Block/erasure, exact history, notification and generated-type checks.
- Full affected Mobile/Web/Database and Site as required by actual scope; required CI on final integrated source. Complete actual Android emulator contact/member/coordination journeys with observable assertions and inspected EN/IT narrow/large-text frames. Fix or report the previous unfinished native flow; never promote partial screenshots to a pass.

## C coexistence and final merge

Fetch latest main again. If revised C has landed, reconcile all D/M shared seams with it and run the combined regression corpus: General/Ideas/invitations/history, manager oversight, private member contact, representative contact/coordination, conversion and Project-only newcomer. Required public/legacy reads must not expose any planning/member/representative private data. If C has not landed, finish a coherent D/M standalone lane and publish its precise interface handoff; C becomes the later integrator.

Use #254 or a traceable successor. Its old conflict status and old CI are not current qualification. Merge one completed D/M cumulative source PR once its actual approval/test gates are satisfied. Re-fetch immediately before merge; incorporate intervening main and revalidate affected behavior. Verify the resulting main and report which peer SHA it includes.

The user does not need to approve routine implementation or textual/semantic conflict repair. Genuine privacy/product choices are different. If one feature still lacks approval, keep its runtime isolated/unmerged. You may submit a separately complete, approved subset only when dependency isolation is proven and the final scope is explicit; **do not call it the whole D/M package**. A feature flag is not an approval substitute. C may still finish and merge independently.

## No external changes and cleanup

No hosted migration, provider setup, real-user invite/message, release/store upload, DNS/billing action or destructive shared database command. Physical device `48091FDAS0041A` is not an automatic test target; use owned emulators and report optional physical/iOS/accessibility/provider work separately.

Delete/stop only D-owned finished worktrees, branches, fixture files and services whose incorporation is proven. Preserve peer active work and policy-denied artifacts. Do not force-delete blocked emulator/define files or restart an engine being used by C.

## Required report

Final PR and merge SHA (or precise blocking state); incorporated base and C head; per-stage delivered/pending checklist; actual recipient/current/history matrix and approval references; migrations/contracts and both standalone/combined test evidence; full native result vs unrun physical/iOS checks; remaining privacy/distribution choices; no-hosted-change confirmation; cleanup/residuals. Include a short note for the founder's later final-main review: which cross-domain invariants to inspect and which functions/tests prove them.

<!-- END EMBEDDED FILE: 08_D_R04_VALIDATE_AND_MERGE.md -->
