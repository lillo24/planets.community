# PLANETS AUTHQA-01 — OTP bootstrap and Home status

Investigate and repair the concrete normal-app observation from 09C2B1 live QA: Home showed a signed-in state and an account-setup error together, while Settings/private moderation history worked. Complete a focused Auth fix with a demonstrated regression and real normal-app OTP validation. Do not repeat the completed private-history QA campaign or begin another moderation feature.

## Exact starting point

Repository: `lillo24/planets.community`.

- Required base: [draft PR #142](https://github.com/lillo24/planets.community/pull/142), `420efa00bcd00d0c0f632444946d640a0aab2a88`.
- Predecessor branch: `codex/09c2b1-private-moderation-history`.
- Create an isolated worktree/branch `codex/authqa01-otp-bootstrap-status`, with a draft PR targeting that predecessor branch.
- Verify the required base and inherited #139 → #136 → #133 → #130 → #126 → #125 → #123 ancestry. Inspect remote movement before continuing; do not substitute current `main` or silently import other task changes.

Read `AGENTS.md`, the Auth/router/profile documentation, `docs/development/moderation-private-history-09c2b1-review.md`, and [the completed live-QA evidence](https://github.com/lillo24/planets.community/pull/142#issuecomment-5996639732).

#142's live QA is complete for its stated scope: real own-history/switch/suspension smoke passed, as did the scoped local Database/Auth sequence and 1,131 Mobile tests. Hosted Mobile/Database run 37321315149 passed on `c03585cf3bef57a4eb87b7a0c6ceb1e52a0b35cd`; publication head 420efa changes only documentation/screenshots and was not rerun. Preserve that distinction. The Home observation and founder EN/IT presentation/copy review remain separate outstanding items.

Leave this PR and the whole stack draft, unmerged and undeployed. No hosting/resource/billing/DNS changes, dependency upgrades, main integration, moderation policy, notification delivery, appeals or minimum-age work. Historical database/Auth/Realtime incidents remain unexplained; this task does not retroactively explain them.

## 1. Establish the actual failure

Inspect these existing boundaries and their tests:

- `features/auth/data/auth_gateway.dart`: SDK `verifyOTP` and Auth-state stream;
- `features/auth/application/auth_session_controller.dart`: snapshot handling, bootstrap revisions, account-status/profile checks and return values;
- `features/auth/application/auth_command_controller.dart`: OTP verification, profile completion, retry, cancellation, pending destination and command failure;
- `features/auth/presentation/auth_status.dart`: Home's session state plus independent command error;
- router and profile-anchor gateways, plus the existing test fakes.

There is a specific source-level candidate, **not a confirmed diagnosis**: a successful SDK OTP can emit an Auth event whose bootstrap overlaps the command's explicit `bootstrap(..., ensureProfile: true)`. A superseded bootstrap currently returns `false`; the command can map that to `profileSetup`, while another bootstrap ultimately reaches `ready`. Home also renders command failures in its ready-session branch.

Use controlled completers/event ordering to test that candidate on the required base. Exercise Auth-event delivery before, during and after explicit command bootstrap, for existing complete and newly created/incomplete profiles. Trace which revision wins and whether a genuine failure, supersession or fixture problem produced the native observation. Do not assume the PKCE harness repair caused it; production Auth was unchanged by that repair.

Collect only safe state transitions, operation/revision tags, synthetic identity labels, failure kinds and backend result codes. Do not log OTPs, sessions, tokens, emails tied to real users or private moderation reasons. Inspect canonical profile-anchor/readiness results rather than inferring onboarding success from a working history screen.

Bound the reproduction matrix before starting. A targeted pass does not explain an earlier failure. If this candidate is disproved, investigate the actual retained/native state within the same bounded task; do not apply a speculative UI suppression or launch an indefinite rerun campaign.

## 2. Repair the demonstrated cause

Apply the smallest change that makes command completion, session readiness and displayed outcome agree under the demonstrated schedule. Reuse the existing Auth/session architecture; do not add a second authentication state machine.

Required invariants:

- A superseded operation is distinguishable from a genuine account/profile failure; it cannot manufacture an obsolete account-setup error after the same identity successfully settles.
- A new account still gets its canonical profile anchor and incomplete-profile route. Event convergence must not skip required setup work.
- Fresh account-status validation still precedes ordinary private access. Suspension and account-check failure remain fail-closed; `ready` must not be asserted merely because OTP verification succeeded.
- Invalid/expired OTP, genuine profile/bootstrap failure and failed sign-out retain their meaningful safe error and recovery behavior. Do not hide every error whenever a session is ready or clear unrelated current failures.
- Cancellation, sign-out, account switching and later Auth events invalidate obsolete work. A delayed success/failure for account A cannot overwrite account B or a signed-out/suspended state.
- Pending return destinations, request/resend behavior, retry and session cleanup remain coherent. No arbitrary delay, automatic retry-until-green or weakened deadline substitutes for coordination.

Keep SQL, RLS and suspension allowlists unchanged unless an independently demonstrated backend defect makes a narrowly justified repair necessary. A presentation symptom does not justify relaxing authorization.

## 3. Add meaningful regressions

Demonstrate that the key regression fails on the base for the observed reason and passes after repair. Model the real SDK Auth event and command together; do not rely exclusively on a fake that never emits that event.

Cover the relevant overlapping bootstrap orders, complete versus incomplete/new profiles, genuine account/profile failure, suspension/status failure, cancellation/sign-out/switch during pending work, and Home's final rendered outcome. Include at least one controller/router/widget integration assertion that a successfully settled account does not show the stale setup error, while genuine current errors remain visible.

Assert final identity, session/command state and destination, not only one intermediate boolean. Avoid tests that mirror a chosen implementation without demonstrating the broken behavior.

## 4. Validate through the normal app

Use the repository-pinned runtime (`.nvmrc` currently Node 24.21.0) and Flutter/tool versions. Prepare a fresh task-owned backend and synthetic accounts; back up exact original local configuration before changing it. Confirm project ownership and free ports before startup/reset. Never start/reset/stop the restored shared stack or reuse an old startup command blindly.

The earlier task received `rejected: blocked by policy` for agent startup. If that restriction still applies, complete isolated configuration and read-only checks first, then provide a concrete supported startup handoff with the resolved checkout path and task project/ports. Explain the actual rejection; do not bypass it through wrappers/elevation or repeatedly ask whether I am ready. Continue backend-dependent work only after actual startup is verified.

Use **normal `lib/main.dart` and its real OTP-entry UI** on an available Android emulator with monitoring disabled. Verify an existing complete account, new/incomplete account setup, sign-out/sign-in and account switching. Check the resulting Home message, intended profile/destination, Settings and private notices. Confirm active suspension still routes through the narrow status screen and cannot open ordinary account settings/history. A dedicated harness that signs in before mounting the app is not sufficient for this bug.

Use the actual local backend, real synthetic OTPs and canonical account/profile status reads. Run the relevant authenticated session/suspension checks and a focused own-history regression smoke; do not rebuild the whole previous campaign without a changed dependency or failure justifying it. Capture concise synthetic EN/IT normal-Home evidence and exact execution results. Preserve any failed attempts and fixes separately.

Run full Mobile localization/format/analyze/tests and Android compilation, plus required checks for any changed/shared paths. Verify actual final-source hosted classification/results; accurately report skips. If later publication changes only documentation, prove source equivalence and distinguish tested-source CI from publication-head status—do not waive a merge gate or label unrun checks passed.

## 5. Deliver and close the task

Write `docs/development/authqa01-otp-bootstrap-and-home-status.md` with the demonstrated cause or remaining uncertainty, before/after trigger, regression evidence, real normal-app results, exact base/tested/publication SHAs and actual CI outcomes. Update the nearest Auth documentation. Archive this exact prompt as `history-implementations/PLANETS_AUTHQA01_OTP_bootstrap_and_Home_status.md`.

Do not rewrite #142's Home failure as a successful historical run. Link this separate disposition. Keep its founder copy/presentation review and later counterparty-warning/delivery decisions pending; they are not automatically approved by an Auth fix. Physical-device, iOS, TalkBack/VoiceOver and hardware-keyboard checks remain unrun unless actually exercised here.

Commit, push and open the draft stacked PR. Restore original configuration byte-for-byte, stop only task-owned services with backups retained, restore emulator settings/session state and verify clean checkouts. Finish with the PR URL, exact head, cause/fix, actual tests, unresolved limits and the next concrete founder decision. If the native symptom cannot be explained within the bounded reproduction, report that plainly instead of inventing a fix.
