# AUTHQA01 — OTP bootstrap and normal Home status

## Scope and exact ancestry

This is a separate, draft, unmerged, undeployed Auth disposition for the normal
Home observation in [#142's completed live QA](https://github.com/lillo24/planets.community/pull/142#issuecomment-5996639732).
It does not change that historical observation into a passing run or repeat the
private-history campaign. Required base: `420efa00bcd00d0c0f632444946d640a0aab2a88`;
branch: `codex/authqa01-otp-bootstrap-status`; PR target:
`codex/09c2b1-private-moderation-history`, not `main`.

Remote draft/open heads and `git merge-base --is-ancestor` were checked before
implementation. The base remained unchanged during native validation.

| PR   | Inherited head                             |
| ---- | ------------------------------------------ |
| #142 | `420efa00bcd00d0c0f632444946d640a0aab2a88` |
| #139 | `9a9476e3b74d9783ad74d4184baae74367020c62` |
| #136 | `b8ab159b5bcb643b477cdaa60b0484b7ad0d0e8f` |
| #133 | `2ae80181ee9ed9cb52012d7b0ad73897330a2c49` |
| #130 | `99e95f90d0105cc3049fa9b76965f328104d8e4b` |
| #126 | `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7` |
| #125 | `c0548a25d39ddc77a92bc02514c83a01f731e9ae` |
| #123 | `010471320779ffb5edaa7546b12cdc8f14809d2d` |

#142's hosted run 37321315149 passed Mobile/Database on
`c03585cf3bef57a4eb87b7a0c6ceb1e52a0b35cd`; Web/Site skipped. Its publication
420efa changed documentation/screenshots only, with equivalent non-documentation
trees, and was not rerun. Those are inherited results, not this task's CI.

## Demonstrated cause and repair

The source candidate was confirmed, not assumed. On unchanged base Auth source,
the controlled regression returned `false` where successful convergence was
expected. The normal-main Android reproduction then independently failed with
`AuthFailureKind.profileSetup` while the same account reached `ready`.

Safe native transition trace (no OTP/session/token/email/reason dumps):

```text
command: verifyingCode -> completingProfile
session: signedOut -> checkingAccount -> checkingAccount
command: idle, failure=profileSetup, session=checkingAccount
session: checkingProfile -> ready, command failure still profileSetup
normal Home assertion: expected no command failure; actual profileSetup
```

The resolved GoTrue SDK saves the session and publishes `signedIn` inside
`verifyOTP` before returning its response. Its asynchronous event delivery can
arrive after PLANETS starts the command bootstrap. The newer snapshot bootstrap
invalidates that bootstrap's revision. The old boolean `false` conflated genuine
failure with supersession; the command manufactured a setup error. Home correctly
rendered its independent command failure alongside session readiness.

`AuthSessionController` now distinguishes completed/failed/superseded work and
lets OTP/profile retry follow the newest same-identity operation. The replacement
inherits unfinished anchor creation, but still performs fresh suspension/status
validation before profile work. Following an existing operation does not issue
another RPC or retry until green. Sign-out/account changes and abandoned command
revisions reject old completions. Verification returning after a later sign-out
or different identity cannot start an obsolete account bootstrap.

Ordinary `bootstrap` retains its boolean interface. Home, SDK gateway, router,
profile editing, SQL, RLS, status deadline and suspension allowlists are unchanged.
Genuine profile/account failures remain explicit and recoverable; genuine
sign-out errors still render on ready Home. No error blanket suppression, delay,
dependency upgrade, monitoring or policy change was introduced. Production PKCE
was not changed by this fix or by #142's dedicated-harness repair.

## Bounded regression and native campaign

Before implementation the bound was five event positions (before explicit work,
during account check, during ensure, during readiness, after completion) by three
canonical states (missing/incomplete/complete), plus focused failure/invalidation
cases. The regression file covers that 15-case matrix, the original trigger,
status/ensure/readiness failures, later suspension and cancellation/sign-out/
switch while both SDK verification and bootstrap are pending. Home/router widget
tests drive actual email/code controls, check final identity/destination/command
state, new-account anchor state, and a visible current sign-out failure.

The final focused invalidation cases additionally demonstrated two failures in
the first repair for A → signed out → A (old verification and old bootstrap
accepted), and three obsolete SDK-error cases (sign-out/different-account/
same-account return). A session-owned identity epoch now rejects them, including
the error continuation; all 33 focused controller/widget tests pass. This is not
an independent authentication state machine or an authorization exemption.

Native bound: one base reproduction, one first-repair full smoke, and one final
source smoke justified by the independently failing invalidation regressions,
not an indefinite rerun campaign. The base smoke deliberately stopped at its first
contradictory Home outcome. All three compile the dedicated integration entrypoint
which calls **normal `lib/main.dart`**: normal startup, real production gateway,
normal router/provider composition, real six-digit email/code UI; no app gateway
overrides and no pre-mount app login. A separate synthetic staff client only
arranges and revokes the focused local consequences.

On 2026-10-05, `emulator-5554`, Android 17/API 37, x86_64, 1344×2992, density 480,
font scale 1.0, monitoring and demo tools disabled:

- Base reproduction: failed as expected on stale `profileSetup`; screenshot
  retained separately from repaired evidence.
- First repaired `flutter drive --no-pub --driver=test_driver/otp_home_driver.dart
--target=integration_test/otp_home_test.dart -d emulator-5554
--dart-define-from-file=config/local.json`: exit 0, native test passed (1m38s).
- Complete A: real OTP → canonical complete profile read → ready Home with no
  stale error. English/Italian Home screenshots inspected; copy/presentation is
  evidence, not founder approval.
- Settings → own notice → Back: real applied synthetic notice visible to A.
  Sign-out → B through a protected destination preserves `/settings/notices`;
  B has different identity, genuine empty own history, no A reason, coherent Home.
- Never-created C: real OTP produces canonical anchor with null display name,
  setup-required Home, `/profile/edit`, actual name entry/Save → canonical saved
  name and fresh ready state. C then signs out.
- A signs in again with active suspension: narrow account-status screen; direct
  Settings/history attempts remain denied. Canonical own-status read confirms
  active suspension. Staff revocation + Check status again restores fresh ready
  Home without stale command failure.
- Native cleanup revoked the temporary notice/suspension, signed out, and
  restored the previous language preference even on the base failure.

Final source `51bef936ce70ecf5085baea46debc5daf097efc0` repeated all the above
flows against a second freshly prepared synthetic fixture set on the disposable
task-owned `emulator-5556` (Android 17/API 37, x86_64, 1344×2992, density 480,
font scale 1.0, no enabled accessibility service). Same driver/target/config
command, changing only `-d emulator-5556`: **exit 0**, native test passed (37s),
Android assembly passed (140.1s). Canonical reads explicitly confirmed complete A,
new C's missing → incomplete → complete transition and A's active suspension.
No app authentication was performed before normal startup/UI entry. Monitoring
and demo tools remained disabled. Final-source EN/IT screenshots were visually
inspected and replace only the repaired samples; the base failure stays separate:

- [Base contradictory Home, EN](screenshots/authqa01/normal-home-base-error-en.png)
- [Final-source coherent Home, EN](screenshots/authqa01/normal-home-fixed-en.png)
- [Final-source coherent Home, IT](screenshots/authqa01/normal-home-fixed-it.png)

## Local backend, actual failures and checks

Pinned runtime: Node **24.21.0** downloaded to a task-local temp directory and
verified against official SHA256 checksums (not a global upgrade); Flutter 3.47.2,
Dart 3.13.2; Supabase CLI 2.118.0-beta.39. `npm ci`/`flutter pub get` did not change
lockfiles. Inherited npm audit reported eight high vulnerabilities; no broad
dependency repair was attempted in this Auth task. Android builds retain
inherited Java/KGP compatibility warnings; they are not new Auth failures.

Fresh owned project `planets-community-authqa01-qa`: API 54511, DB 54512, shadow
54510, Studio 54513, Mailpit 54514, analytics 54517, pooler 54519, inspector 8103.
Ports and absence of task containers were checked first. Original TOML,
Android local properties and generated DB types were backed up before setup;
mobile local config was originally absent. The supported pinned `npm run db:start`
succeeded on this task. The earlier policy rejection is not recast as a success;
no wrapper, elevation or restriction bypass was used. Shared/other-task stacks
were neither reset nor stopped. Fresh startup replayed all inherited migrations
and seed; no schema or backend implementation was changed.

Actual local authenticated checks:

- `auth:verify:local`: passed; real numeric OTP and exactly one owned anchor.
- `auth:session:verify:local`: passed; concurrent identity-bound PostgREST access.
- `moderation:suspension:audit:local`: passed, 193 public signatures, one narrow
  own-status exception and filtered canonical private broadcasters.
- `moderation:suspension:verify:local`: first attempt failed at the **pre-suspension
  baseline** waiting for a committed private Project signal. Task Realtime health
  was healthy; that signal miss remains unexplained. One controlled retry failed
  earlier with `apply_moderation_consequence` PT409. A read-only probe confirmed
  exactly one active synthetic verifier safety-notice episode remained. That
  episode was explicitly revoked through the canonical operation as the synthetic
  verifier admin; nothing was deleted/reset. The subsequent bounded validation
  passed: ten identities, private/storage/domain denial, preserved relations and
  co-manager access, staff recovery, topic denial and cached socket suppression.
  This does not explain or rewrite historical DB/Auth/Realtime incidents.
- Initial new widget test used the wrong expected English label; corrected to
  repository localization `Complete profile`, without changing production copy.
  Initial analysis found six missing-brace infos only in new device test/driver;
  mechanical targeted `dart fix` repaired them. Final analysis: no issues.
- Mobile localization and formatting (including integration test/driver): passed.
- First repair full Mobile suite: 1,159 tests passed. Normal `flutter run -t
lib/main.dart` Android compilation and a DTD hot restart passed. The debug
  connection subsequently dropped; that device-process change is unexplained.
  A same-AVD read-only second-instance attempt was rejected by the emulator (all
  instances would have to be read-only). Instead, a new task-only AVD
  `Planets_AUTHQA01_20261005` was created from the already installed
  `system-images;android-37.1;google_apis_playstore_ps16k;x86_64`, headless on port 5556. Its initial automatic-GPU cold boot stalled offline; that owned process
  was stopped. One bounded software-rendering alternative boot succeeded and
  supported the final smoke above. The original AVD was not saved or reset, and
  no SDK was downloaded. These device/debug incidents remain distinct from the
  demonstrated Auth race.
- Final-source Mobile localization and format: passed, 429 Dart files unchanged;
  analysis: no issues; full `flutter test --no-pub --reporter expanded`: exit 0,
  **1,164 tests passed** (4m52s). The final native result is recorded above.
- Final source separately compiled and launched normal `lib/main.dart` with
  `flutter run --no-pub -t lib/main.dart -d emulator-5556
--dart-define-from-file=config/local.json`: Android assembly passed (127.3s).
  DTD discovered this checkout's app; hot restart passed (5.492s), runtime-error
  inspection returned none. The task-owned app was intentionally force-stopped
  after validation; the Flutter process then exited 0. That expected disconnect
  is distinct from the unexplained earlier shared-device connection loss.

## Source publication, hosted CI and cleanup

Draft [PR #144](https://github.com/lillo24/planets.community/pull/144) targets the
required predecessor, not `main`. Exact implementation/tested source:
`51bef936ce70ecf5085baea46debc5daf097efc0`. The predecessor remained at required
base `420efa00bcd00d0c0f632444946d640a0aab2a88` and both PRs remained draft/open;
#144 was cleanly mergeable when checked.

[Hosted run 37335681872](https://github.com/lillo24/planets.community/actions/runs/37335681872)
completed successfully on that exact source. Change classification and Mobile
**passed**; Web, Site and Database **skipped**, not passed. Mobile ran localization,
formatting, analysis (no issues) and **1,164 passing tests**. No hosted rerun or CI
availability exception was used. SQL/RLS, Supabase, Web, Site, shared packages and
CI configuration trees are identical to the required base.

Final publication adds this evidence and final-source screenshots only. Its exact
head and proven source-tree equivalence are recorded in #144's final evidence
comment, avoiding a self-referential commit SHA in this document. Publication
uses `[skip ci]` to avoid another cumulative-PR Mobile run on identical tested
source; no hosted checks are claimed on that publication head. This is not a CI
waiver or merge-gate relaxation; the entire stack must stay draft.

Cleanup completed using `supabase stop --project-id
planets-community-authqa01-qa`, with default **backup=true** (no `--all` or
`--no-backup`). No task Supabase containers or owned emulator/Flutter-run processes
remain; its database, Edge Runtime and Storage backup volumes are retained. Shared
`planets-community` and the other
task's `planets-community-tw05` database containers still run. They were not
stopped/reset by this task.

Original configuration was restored byte-for-byte, with SHA256 matching the
pre-change backups:

| File                                       | Original/restored SHA256                                           |
| ------------------------------------------ | ------------------------------------------------------------------ |
| `supabase/config.toml`                     | `2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6` |
| `apps/mobile/android/local.properties`     | `F8A3FC9601911028A4743367276791D7BCB6ED87C44B6B2220229D7520A69A47` |
| `apps/web/src/types/database.generated.ts` | `97F6304D448C8C4840BBD4BA8DE2F9ACD06EFFD06E7CF6756F3897EC8E8A93F5` |

Generated ignored `apps/mobile/config/local.json` was originally absent and is
absent again; a synthetic public-configuration copy is retained outside Git with
the original backups/logs/screenshots in
`C:/Users/leona/AppData/Local/Temp/planets-authqa01-backup-b67d9db967d64929a4faff3acbe71482`.
No OTP, private key or session token was published.

Device cleanup restored the language and signed out. Only owned emulator 5556
was closed; original emulator 5554 remains available. The supported AVD deletion
removed the task's registry entry but reported partial cleanup; residual disposable
userdata remains inside that exact backup directory, unregistered, with no owned
QEMU process. The original AVD was not deleted or snapshot-saved. The isolated
worktree/branch is retained for the required draft review/fix-ups, not merged-plan
debris. Main remains clean at `cbfbf0ae6de9eb73906361c5980b113ec6bc2046`;
the task checkout is checked clean after the documentation-only publication.

## Remaining limits and next founder decision

Physical devices, iOS, TalkBack/VoiceOver and hardware keyboards were not run.
Historical infrastructure incidents remain unexplained. No production deployment,
external resource, billing, DNS, moderation-policy, warning/delivery, appeals or
minimum-age work was authorized or performed.

Next concrete founder action: review the retained **EN/IT private-history copy
and presentation** from #142 and this separate normal-Home evidence. Approving
the Auth repair does not approve that copy review or counterparty-warning/
delivery policy. Stack integration/merge remains a separately authorized task.
