# Final D gate — Reconcile parallel work, validate, review and merge

This gate covers only Batch D and its necessary integration seams. Do not implement A, C or E as part of finishing D.

## Fresh source and review gate

Fetch current main and the actual A integration status. Reconcile later merged changes into the cumulative D head; do not cherry-pick unfinished A or close its PRs. Review the complete diff against fresh main, including later migration definitions that may override earlier D helpers.

Check D00's explicit approval record for recipient scope, history/role loss, multi-group consent and any other material unresolved policies. Codex-generated recommendations, a user asking to receive the prompts, screenshots or passing tests are not approval. Without it, keep the completed/provisional cumulative PR draft and report the small concrete review table. Do not activate D using a client-only flag or relabel the provisional code production-ready.

With approval, update the implementation to match the exact accepted contract, remove obsolete prototype paths and rerun affected gates before considering merge. A D03-only unresolved choice need not trigger a redesign of D01/D02; isolate it honestly and seek approval for a smaller release rather than silently dropping it from "all complete."

## Parallel integration checks

If A landed, verify together:

- A01 personal setup offer never hijacks a D contact/invitation continuation; returning from setup still requires explicit Send/Accept.
- A03 Idea/Requested card layout and truthful lifecycle remain intact; D touches only the intended contextual detail action.
- A04 Workspace paging, recovery and Checklist strip still work for existing Projects/Tavoli. D does not borrow their access by pretending to be a Project chat.
- Group-attributed Project publication stays independent of D representation/admission. Contact cannot publish or edit on behalf of a group.
- Messages request kinds, conversation projection versions, legacy parsers, unread summaries and exact routes remain coherent.
- Localization, generated contracts, deletion/safety inventories, package scripts and CI coverage include both implementations.

If A remains unmerged, test D against current main and state that combined A+D runtime testing has not occurred. Do not block safe isolated development on unfinished A. Whichever approved stack merges later owns the combined check before its own merge.

## Local validation

Use the pinned repository's actual commands after inspecting `package.json`, CLI help and the local project selector. Run relevant Mobile, Web/generated-contract and Database checks; shared schema/Messages changes are not mobile-only. Standard entry points to verify include `npm run check:mobile`, `npm run check:web`, `npm run check:db` and `npm run db:types:check`; do not run a guessed script or claim it passed from this prompt.

Database reset/upgrade tests are confined to the task-owned disposable loopback stack. Verify empty replay, populated current-main upgrade, installed-client compatibility and repeat migration-up. With both A and D present, prove the effective combined schema does not lose either side's functions, grants or constraints. Generate types from that schema; do not hand-resolve generated files.

Run focused real-Auth/PostgREST concurrency, RLS and direct-access tests for D. Test transport-loss recovery, revocation while connected, preview/unread leakage, request spam controls, all-party consent and the exact D00 history policy. Tests must exercise actual denied actors, not just privileged fixtures. Reuse normal path classification and required statuses; no CI weakening, broad unrelated dependency changes or repeated release campaign after every small stage.

## Native journey and safety evidence

On a task-owned Android emulator with synthetic local users/groups, execute and inspect: group/Project context → explicit purpose/source group → send → another group's request review → accept → chat → read/unread → decline/withdraw/retry → role loss/block/report → multi-group consent → fresh conversation with no inherited history.

Include auth/setup/policy continuation, account switching with late replies, background/reconnect, scrolling multiple pages, keyboard/Back, English/Italian, long names and enlarged text. Prove another group manager who did not accept cannot read the accepted chat; prove a replacement manager cannot obtain it through inbox previews/unread.

Physical device `48091FDAS0041A` is optional and only safe with reviewed configuration. Do not replace/wipe its Play app or claim a physical/iOS/screen-reader pass from widget tests. Missing emulator/backend execution blocks a claim of fully qualified source merge; keep drafts with exact limitations. Production provider access is not required for these local tests.

Review whether the new contact/message audiences require policy/privacy/store-disclosure wording before distribution. Produce a specific rollout delta rather than silently rewriting legal terms or claiming legal compliance. New reporting/deletion routes must be implemented and locally testable; unresolved consequential retention rules remain an approval blocker.

## Merge and cleanup

Only after D00's required decisions are approved, the selected D scope passes local/native/required CI and the fresh head/base is correct, merge one cumulative D integration PR through the allowed repository method. Do not bypass failing/missing checks or push directly to main. Main may advance while CI runs: reconcile and rerun affected checks instead of racing the other stack.

Verify the resulting remote main includes the intended D source. Reconcile D stage PRs by actual ancestry/content; an incorporated or superseded PR is not necessarily itself merged. Close/delete only verified D-owned redundant branches/worktrees. Leave A, C, #216/#243, unrelated drafts, dirty work, devices and other agents' services alone. Stop only task-owned local resources, preserving normal backups and secrets.

No hosted database migration, deployment, real contact/message delivery, provider change or Play upload is part of this gate. Source merge and activation remain separate. The rollout handoff identifies backend-before-client ordering, compatible RPC versions, configuration needs and remaining approval/device checks.

## Completion report

Return:

1. D00–D03 status, explicit decision approvals or remaining review items, and whether D is provisional or merge-qualified.
2. Stage and integration PR/head references; final main SHA only when actually merged.
3. Current A/base status, integration conflicts resolved and combined checks actually run.
4. Recipient/history/role-loss and multi-party consent rules implemented, with one short example.
5. Migrations, versioned API/legacy compatibility, pagination/unread, safety/report/deletion and idempotency results.
6. Exact local commands, CI references, native screenshots/journeys and unrun physical/iOS/accessibility checks.
7. Cleanup, retained resources and separate hosted rollout steps.

Do not finish with an unsupported "all done." A tested review-only stack awaiting explicit access approval is a useful deliverable; identify that limit precisely instead of either abandoning the implementation or inventing consent.
