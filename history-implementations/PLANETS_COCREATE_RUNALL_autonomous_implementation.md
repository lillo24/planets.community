# PLANETS COCREATE-RUNALL — Autonomous implementation pack

## 0. Instruction to the executing Codex agent

Implement this whole bounded programme, not merely its first UI screen. Continue from one eligible stage to the next without routine confirmations. Implement, test, inspect, repair, commit, update the progress record, then continue. Do not stop with a plan when executable work remains. Do not promise an unattended service or bypass runtime limits: make as much verified progress as the current execution environment permits and leave a precise resumable checkpoint.

This pack supersedes the **A00-only execution restriction** in `history-implementations/PLANETS_COCREATE00_trova_persone_roadmap_and_mock.md`. Its product description remains useful. This pack also substitutes an automated A01 checkpoint for waiting for founder phone testing. It authorizes the experimental defaults below ONLY for this isolated development implementation, not as finalized production policy. It does not authorize weakening security, changing existing audiences, or replacing the repository's established product contracts.

### Delivery boundary and autonomy

- Use an isolated integration branch/worktree for this programme. Preserve unrelated work, branches, running agents, local databases and uncommitted files. Check for existing COCREATE work before creating a duplicate.
- This is an explicit workflow exception: sequential, tested stages may build on earlier commits on this integration branch without waiting for a merge into main. Make separately identifiable commits and maintain one cumulative draft PR, or a small clearly dependent PR stack if the repository workflow makes that easier. Do not mix ACTAPI01, ACTMET01 or release work into this branch.
- You may make ordinary implementation decisions, refactor the minimum necessary shared code, install project-local dependencies following repository conventions, generate additive migrations, run local services/tests/builds, commit, push the task branch and open/update its PR. Inspect dependency scripts and version compatibility; avoid unrelated upgrades.
- Do not merge this experimental multi-stage programme into main during the unattended run. Leave it ready for review. Do not deploy, publish a store build, run hosted/shared migrations, enable external delivery, spend money, change secrets/permissions, or delete unrelated files. Only the implementation plan is intended for a direct main commit by the preparing assistant.
- Use an identified disposable LOCAL backend and synthetic identities. A Sandbox UI toggle is not backend authorization. Add a server-controlled experimental availability gate, default OFF, enabled only in the owned local test setup. Reject disabled-domain reads/writes appropriately, with protected own-exit/recovery paths remaining safe. Clients cannot grant themselves enablement.
- Never disable approval controls, evade a denied command, rewrite AGENTS.md to remove safeguards, skip required checks to claim success, force-push shared branches, or use credentials outside their intended environment. A denied optional cleanup is not a blocker: leave the folder and record it.
- Routine ambiguity: choose the smallest reversible option consistent with this pack and record it. Consequential ambiguity not covered here: keep the affected feature disabled, document the exact decision needed, and continue other eligible stages. Do not turn one blocked item into a global stop.
- A failed approach needs diagnosis, not an infinite retry. After a few equivalent failures, change the approach or mark that item blocked. Do not repeatedly poll unchanged failures or invent extra features after finishing the scope.

### Evidence and prerequisites

Repository: `lillo24/planets.community`. Current main verified when preparing this pack: `62781c91323836807dad7ac4c014adac253c71e2`, 2026-10-21. Re-read current code before implementation; this is not a pinned execution base.

Inspected earlier in this conversation: `apps/mobile/lib/features/settings/`, `activities_sandbox/`, `groups/`, `group_membership/`, `group_discussions/`, `group_coordination/`, `messages/`, `app/foundation_screen.dart`, `app/router/`, and the persistent-group / General-Ideas migrations. Current main still contains the A00-only roadmap. The repository has separate registered Groups, membership, General/Ideas chats and Messages machinery; their authorization is NOT the proposed public-topic/numbered-group domain. Documentation can be historical; current migrations, code and tests decide implemented behavior.

Read `AGENTS.md`, nested instructions, `implementation_plan_sections_suggestions.md`, `docs/architecture/`, current group discussion/membership contracts, moderation/blocking/account deletion paths and affected feature READMEs. Inspect current open PRs and worktrees to avoid colliding with another agent. Do not merge another agent's unreviewed changes as a shortcut.

Required external context: none beyond this repository for the core programme. Normal toolchain/package access and GitHub access may be needed. Use installed/pinned dependencies and current official docs if changing APIs. The Google Doc, pasted conversation, screenshots, real people, provider credentials and event feeds are not prerequisites. ACTAPI01 integration is conditional on actual merged code. Missing optional external access must not block core implementation.

Create `docs/development/cocreate-progress.md` with stage states (`pending`, `in_progress`, `implemented_unverified`, `verified`, `blocked`, `partial`), dependency, commits, exact checks, unresolved decisions and the next action. Update it after every stage and before the execution context ends. Never mark a mocked flow as a verified live-backend flow.

## 1. Product boundary and experimental defaults

These are explicit temporary choices to make unattended implementation possible. Record them in an experimental contract, separate from accepted production decisions.

1. **Navigation:** Settings > Sandbox > Co-Creation Mode, default OFF, saved locally. It takes visual precedence over Activities Split Mode without rewriting the saved Activities preference. Home shows Trova persone / Progetti / Scambia-Dona. Existing native routes remain accessible; no new bottom tab. Turning the mode off changes presentation, not backend memberships, data or permissions.
2. **Distinct objects:** a people-seeking post; a topic hub with General chat; a numbered small group with separate membership/chat. None is a native Project, registered association Group or imported event. Reuse safe primitives/components, not incompatible grants or synthetic Project records.
3. **Topics:** curated catalogue initially, not unrestricted user-created topics. Seed only synthetic LOCAL examples such as Calcetto, Giochi da tavolo and Nuovi a Trento. Production topic activation/curation stays disabled. Named hubs include broad locality; numbered groups belong to exactly one hub.
4. **Who acts:** use existing account readiness, current policy acceptance, identity, age eligibility, suspension and blocking requirements; never lower them for this experiment. Do not invent a second birthday collection or legal consent. Anonymous users may see only deliberately public catalogue/post summaries while the server experiment is enabled; chat actions require an eligible account.
5. **Joining:** explicit opt-in to hub membership, then explicit join to a small group. No automatic enrollment into all children, no implicit cross-community membership, no fixture-to-real mutation. If joining a group requires first joining its hub, explain and obtain both actions deliberately.
6. **Numbered groups:** system-assigned stable number within each hub, never reused/renumbered; no custom names. Display `Gruppo 2` with `Calcetto · Trento` context where needed. Capacity default 5, editable at creation in the experimental range 2–50, not a universal five-person rule. Count every active group participant INCLUDING its creator. Multiple group memberships are allowed. Capacity cannot be reduced below current membership.
7. **Authority:** eligible hub members may create numbered groups; the creator manages that group, not the hub. Moderation remains with existing authorized staff through proper scoped actions/evidence. No automatic private-room oversight for a hub curator. No automatic leadership transfer: if the only group manager departs, archive it and retain permitted historical access. Add transfer only if already safely supported by an appropriate canonical primitive.
8. **History:** no transcript or roster before admission. New members are explicitly informed that active joined rooms expose their earlier history; grant only within that room. On leave/removal, stop sending and access to later content immediately; allow only a frozen historical snapshot through the exit sequence when compatible with account restrictions/moderation. Rejoin creates a new episode and requires fresh eligibility; a removal prevents self-rejoin until an authorized explicit reversal. Do not reuse an old receipt as a grant. Do not change historical rules for other chat domains.
9. **Hub exit:** atomically end the person's active memberships in its child groups and revoke applicable future access, with an explicit UI warning. Archive any group orphaned by this departure. Keep other hubs, Projects and registered Groups untouched. Suspension/suppression must deny current access even through retained sockets/caches. Every read rechecks live authority.
10. **Post responses:** private structured `Interested` request, optional short note, visible only to requester and post author. States: pending, accepted, declined, withdrawn; expired/closed posts accept no new requests. The author's explicit acceptance creates/reuses one post-scoped bilateral conversation; no unsolicited DM or automatic group membership. Existing accepted chats are not silently deleted when the post closes. A fresh contact after decline requires explicit new action and abuse controls.
11. **Post lifecycle:** draft/open/closed with a configurable 30-day discovery expiry default; expiry is a query/lifecycle condition, not a retention/deletion promise. Owner can deliberately renew or close. Public content uses broad locality, never exact personal addresses/contact fields; include publication guidance. Private notes, response counts that reveal identities, invitations and exact locations never enter public summaries.
12. **Groups lifecycle:** full groups stay full, not archived; no inferred inactivity deletion. Empty/orphaned groups archive. Inactivity may be labelled but does not fabricate completion. Retention and account erasure follow existing reviewed infrastructure; do not add indefinite personal-data retention or destructive cleanup without a defined policy.
13. **Abuse controls:** bounded payloads, canonical server limits, reporting and scoped moderation, blocked-pair barriers on direct contact/admission. Shared-room blocking follows the repository's documented shared-room rule, not an invented promise that blocked users never share a public hub. No new public chat launches until these paths work. Use small documented configurable limits, not client-only throttles.
14. **Presentation/data:** clearly separate Demo fixtures from Local/backend test data. Empty/error is not permission to inject examples. No production analytics on fixtures, chat bodies or invitation links. External events remain read-only; no crowd estimates, AI matching, scraping, payments or rideshare booking.

## 2. Execution order and common acceptance gate

Default order: **A00 → A01 → B01 → B02 → C01 → C02 → C03 → C04 → D01 → D02 → D03 → Q00**. B and C are independent after A01. A blocked B stage must not prevent starting C. D02 needs B/C; D03's provider portion depends on implemented ACTAPI01, not on its plan merely existing.

Do not reimplement an already completed stage: audit its diff and tests against this pack, fix gaps, record evidence and continue. Split internally oversized stages into reviewable subcommits without dropping requirements. Preserve one owner for shared migrations, router, localization and Messages projections when parallelizing.

Every data-changing stage requires additive migration replay/upgrade tests on the disposable local stack, authorization/negative tests, idempotency/retry tests, concurrency tests where relevant, and regression checks for affected existing domains. Every UI stage requires strict parsing, state/account invalidation, loading/empty/error, narrow/large-text EN/IT coverage and appropriate build/analysis checks. Use current repository commands rather than guessing.

### A00 prompt — Sandbox shell and coherent previews

Implement or complete the original COCREATE00 A00 UI: saved mode, Home entries, Trova persone Posts/Communities views, fictional post composer/preview, hub preview, General preview and numbered-group previews. Reuse navigation and style patterns. Preserve Activities Split, tutorial baseline, bottom-right shortcut, protected drafts and deep links.

Deliver a navigable mock with explicit Demo labels, no backend writes and no false join/publication success. Test default-off, restore/write failures, both-mode precedence, Back/scroll, app restart, account changes and switching mode while a detail is open. Later stages may add real-data mode but must preserve explicit preview separation.

### A01 prompt — Automated design checkpoint and experimental foundation

Do not wait for founder phone review. Inspect rendered screens where available; record what was not inspected. Fix obvious overflow/navigation defects. Document the temporary policy defaults above and a compact object/access matrix. Leave final Project/Event/Tavolo classification unresolved and unchanged.

Create the minimal server experiment gate and local test activation if needed by B/C, with disabled/default and direct-call rejection tests. Define strict typed identities for posts/hubs/numbered groups and domain-specific routing without creating an oversized abstraction framework. Record reuse decisions for chat, unread, moderation, idempotency and membership. No existing registered Group becomes a topic hub implicitly.

### B01 prompt — People-seeking posts, consent and bilateral contact backend

Implement canonical post create/edit/publish/close/renew, bounded public discovery, owner management, source-safe broad locality/topic filters and deterministic cursor paging. Define draft/public/private fields explicitly. Add optimistic versioning and immutable command identity for uncertain retries. Public reads must enforce lifecycle/moderation before pagination.

Implement the interest state machine and accepted post-scoped conversation from default 10, with participant-only history/send, leave/close, read/unread and reportable message evidence. Reuse existing chat infrastructure only if its audience and lifecycle fit; otherwise use a distinct typed conversation and preserve existing RPC contracts. One author cannot read another author's requests; public readers cannot read notes or transcripts. No self-requests or automatic retransmission on login return.

Integrate scoped blocking, suspension, erased identities, private invalidation and existing moderation capabilities. Test duplicate acceptance, crossed withdraw/accept, changed-intent retry, post expiry/closure races, rejected users, data leakage and account deletion compatibility. No public deployment.

### B02 prompt — Posts mobile journey and accepted-contact Messages

Replace default Posts fixtures with backend results only when the experiment backend is available; retain a separate explicit Demo action. Build search/filter/paging, post detail, create/edit/publish, My posts, close/renew, Interested/withdraw and author response management. Consent screens explain what acceptance opens.

Integrate eligible requests and accepted contacts with existing Messages/Requests using additive, strictly typed projections. No duplicate entries, fabricated unread totals or unsolicited DM. Preserve draft input across auth/policy flow without auto-submit; clear private state on identity/access changes. Provide reports and safe exit paths. Test the two-account author/requester journey, expired posts, errors and exact retry recovery.

### C01 prompt — Topic hubs, membership and General backend

Implement curated public hub summaries with stable IDs/topic/locality, explicit join/leave, bounded member projections only for entitled viewers, and one General chat per hub. Authorize each operation independently from registered Groups and Projects. Use local fixtures to exercise multiple hubs.

Implement history/read/unread, immutable sends, membership episodes, mute, reconnect invalidation, report/evidence and moderator lifecycle actions. General membership must follow active hub membership; no implicit child grants. If child groups are not implemented yet, provide an explicit transaction extension point and complete/test hub-exit cascading in C03 before final acceptance.

Test anonymous/prejoin denial, current and former member history, removed-user self-rejoin denial, new episode behavior, blocked actors, suspension, staff without membership, feature disabled and exact retry. Preserve released chat signatures or add versioned readers.

### C02 prompt — Hub discovery, join and General chat UI

Build Communities browsing/filter/detail, deliberate join, clear audience/history disclosure and General access after canonical admission. Include leave warning, mute, reporting and failure recovery. Use existing chat rendering/paging/read-viewport components when compatible. Joined General chats appear once in Messages Groups; browsing a preview never acknowledges messages.

Maintain independent topic/locality context, auth continuations, account-bound caching and reliable reconnect. No public message preview/roster before membership. When backend gate is OFF show unavailable or deliberate Demo, not fake live chat. Verify guest → sign-in → explicit join → chat → leave with separate users.

### C03 prompt — Numbered groups, capacity and isolated conversations backend

Implement atomic create/join/leave/remove/archive with stable per-hub numbering. Allocate number, group/chat anchor and creator membership transactionally. Idempotent retry returns the same number; failed creation must not produce a second room. Do not derive the next number from visible list length or reuse deleted numbers.

Join requires active hub membership and checks group lifecycle, moderation, removal, blocks and capacity within the canonical locking transaction. Race two eligible users for one seat: exactly one succeeds. Duplicate joins do not consume another seat. Creator counts as a participant. Capacity changes serialize with joins and never overfill.

Implement private group messaging, admitted People, full/available summaries, frozen former history, membership/source invalidation and manager actions. Complete atomic hub-leave cascades and orphan handling. Summary counts and actual grants must agree; no user list/transcript leaks in discovery. Test lock order, join/leave/close races, concurrent numbering, removal/rejoin and stale receipts. Extend deletion/moderation safely.

### C04 prompt — Numbered groups UI and Messages integration

Expose numbered groups inside hub detail with canonical occupied/capacity and availability; create with capacity, join, leave, creator removal/capacity/archive and member-only chat/People. Keep naming automatic. An error while joining must not show success; ambiguous delivery retains the original command until resolved.

Joined small groups appear in existing Messages Groups with hub/locality context and stable conversation identity. Folder presentation is optional; avoid building a second inbox. Reuse canonical counts/read rules, prevent duplicate placement, respect mute and immediately remove inaccessible cached content. Mode-off must not trap existing members: Messages and own-exit remain reachable, with no auth bypass.

Test two people competing for last seat, member leaving/reopening a seat, hub departure, removed member, account A→B→A, reconnect and navigation restoration. Inspect narrow/large-text screens.

### D01 prompt — Structured recruitment in hub General

Allow a current small-group manager to deliberately post a structured `Gruppo N cerca X persone` card to its hub General. The canonical reference points to the room; capacity/availability is resolved from current backend state rather than trusted text. One active recruitment per room, idempotent posting, documented configurable cooldown and no mass push notifications.

Joining from the card uses the same atomic admission operation as C03. Full/archived/suppressed/expired/retracted recruitment becomes non-actionable; never delete or rewrite unrelated human messages. Recheck permission and capacity on tap even for stale cards. A seat reopening does not automatically spam/repost. Test concurrency, stale render, removal, replay, reporting and mute/read behavior. Non-human recruitment must not silently inflate human-message unread metrics.

### D02 prompt — Explicit links between posts, groups and native Projects

Implement reviewed source linking, not destructive conversion or membership copying. A post author can link an authorized existing numbered group, or deliberately create one after joining its hub; accepted respondents receive a consent-preserving option to join, not automatic membership. A source title/note does not grant access.

A small-group manager can start an ordinary personal Project draft through the existing editor, with a minimal source reference. Do not copy private conversations, notes, rosters or exact locations into public drafts. Publication follows native Project rules; creator authority in one domain does not become authority in another. Linking a Project does not enroll crew members.

Use idempotent draft creation and safe returns. Test lost responses, source access loss, stale links, unauthorized linking, draft cancellation and no automatic enrollment. Do not create a new Event domain or reclassify Tavoli.

### D03 prompt — Simple discovery filters and optional official-event handoff

Implement explicit, understandable topic/locality/text filters and deterministic ordering for posts/hubs/groups. Use explicit open-seat filters where canonical capacity exists. Reuse known controlled topics; preserve freeform optional intent without inventing a universal skills ontology.

When a real ACTAPI01 model/routes/official source data are present on the execution base, add an explicit event-detail action to compose a people-seeking post with a public event reference, editable reviewed public text and no automatic publication/join. Validate target availability and keep provider events read-only. Do not implement ACTAPI01 here or guess its schema.

If ACTAPI01 is absent, complete ordinary discovery and tests, document the provider extension as blocked/partial, and continue Q00. Do not fabricate an API, fake a functioning event link, implement scraping, call AI, build inferred-affinity ranking, or infer popularity/crowding from clicks.

### Q00 prompt — Integrated qualification, repair and handoff

Run the end-to-end synthetic journey: enable local backend and Sandbox mode; author post; second account expresses interest; author accepts; scoped contact works; both join hub; create numbered group; fill all but one seat; post recruitment; compete for last seat; verify one winner; leave/rejoin/remove/hub exit; inspect Messages/unread and report handling. Verify mode OFF and existing Project/Tavolo/registered Group/Resource journeys remain intact.

Replay all new migrations from a clean disposable baseline and test upgrade from the actual pre-programme base. Run required repository DB/security/tooling/mobile checks, analysis, relevant builds and rendered evidence. Exercise blocked/suspended/erased accounts, public projections, current/previous membership and retained sockets. Do not make unrelated failing checks green by weakening them.

Native device ID, only when actually available: `48091FDAS0041A`. Do not guess a connected device, disrupt a personal installation without appropriate authorization, or claim Android/iOS QA that was not performed. Native review is deferred, not a reason to abandon automated verification.

Finish the cumulative PR, progress ledger and a handoff with: stage status; actual commits/PR; exact passed/failed/not-run checks; experimental defaults needing founder review; local run/configuration commands; screenshots where available; unresolved blockers; deployment status; and the precise next task. Distinguish implemented, verified, merge-ready and deployed. Keep backend activation OFF outside the isolated local environment. Stop only when all eligible work is verified, genuine remaining blockers prevent progress, or the execution runtime ends—not merely because one stage is complete.
