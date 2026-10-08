# UI-NEXT-01 — Welcome, first-run infrastructure and navigation

Scope: slice 1 of the sequential UI batch, from
`PLANETS_UI_NEXT_01_startup_navigation.md`. Earlier compact Browse/cover and
Scambio polish were already merged; they were not reimplemented. MSG02/#155
and the Template Workshop integration/#146 were verified merged before editing.

## Traceability and status

- Actual fetched base: `9cd024cc38c02b0333a32f8abe71fdc9681df548`.
- Isolated branch: `codex/ui-next01-startup`.
- Implementation/source validation commit: `29af9422be2efd9dca034eec9fe4e3623c2d43d4`.
- PR into `main`: [#156](https://github.com/lillo24/planets.community/pull/156).
- Final branch head and its hosted checks are recorded by that PR's immutable
  commit/check metadata; the source checkpoint above contains all code/tests.
- Merge: pending the repository's native pre-merge QA gate and required CI.

Tutorial infrastructure is code-ready but content/activation is deliberately
deferred. The approved production registry is empty and never displays or marks
a placeholder complete. No Google/Apple activation, schema/migration, backend
reset/seed/mutation verifier, hosting/deployment or production setup is included.
The founder checkout, phone session and retained demo backend were left intact.

## Implemented behavior and ownership

- `app/startup/` owns branded ordinary signed-out entry, separate Flutter
  orbit/star motion, reduced-motion/lifecycle behavior, local tutorial version
  persistence and sanitized continuation. The logo asset is a byte-for-byte copy
  of the founder's website PNG (SHA256
  `89e7f0ab4f98988fea99559f059665bf3ecf59d8f3e03d9879dea4702eebd367`).
- Explore enters public Home without creating an anonymous account and suppresses
  Welcome for the current run. Login keeps numeric email OTP. Stored session
  restoration/readiness precedes signed-out actions; restoration failures show
  retry. A same-actor token refresh keeps established readiness/navigation.
- The router composes the existing native-link and draft-departure seams.
  Explicit/public/protected continuations bypass Welcome and defer a configured
  tutorial. Duplicate native OTP/setup deliveries retain their existing forms.
- `/messages` alone is public/contextual. Login/cancel returns to this root;
  incomplete profiles can complete or cancel setup there without private reads.
  Private loaders mount only for a ready identity. All descendants remain guarded.
- Profile setup Save always resumes its authorized destination. Cancel chooses
  the public project parent, either invitation preview, Messages root, stable
  Profile for a ready editor, or a safe public ancestor/Home. It never retries
  a Join action or the incomplete Profile/setup loop.
- Native popping is enabled only when the actual preceding route is the safe
  cancellation destination. Profile editing uses an explicit Flutter Material
  page: the resolved GoRouter 18 app-type adapter otherwise supplied a page with
  no transition/edge detector. No whole-screen gesture handler was introduced.
- Home removes only its Auth testing card and envelope. Notifications, Settings,
  public discovery and bottom unread badges remain. Settings offers a labelled
  Messages row when Browse occupies the third slot; there is no fourth branch.
- Debug Settings can reset only the startup completion key and run-only flags.
  Auth, language/navigation preferences and backend records are unaffected.

The startup [module contract](../../apps/mobile/lib/app/startup/README.md) owns
the key/version and future approved-content instructions. Auth, Messages,
Settings and app documentation were synchronized with their changed behavior.

## Validation

`npm run check:mobile` passed: localization generation, Dart formatting (491
files, zero changes), Flutter analysis (no issues) and **1,496 passing tests,
two existing opt-in skips**. `git diff --check` and the staged diff review passed.
Change-scoped hosted CI is recorded on PR #156 for its final branch head. No
Web/Site/Database code or contract changed, so their unrelated suites were not
run locally. Required hosted checks must pass before merge.
The test suite covers cold signed-out entry, restored identity/readiness, restore
errors/retry, Explore/Home revisits, ready/incomplete OTP return, empty and
synthetic tutorial registries, Finish/cancel/write failure/retry/version restart,
motion pause, reduced motion, short/scaled EN/IT screens and missing assets.

Router/domain regressions cover public Messages versus protected descendants,
setup save/cancel for Proposal/Tavolo origins and both invitation families,
duplicate native OTP continuations, Notifications return destinations, identity
changes and stale async work, unread boundaries and same-actor token refresh.
Existing UI tests now enter through Welcome/Profile/bottom navigation instead of
the deliberately removed Home controls; their domain assertions were preserved.

Native Android presentation was exercised on a newly started temporary read-only
Pixel 9 Pro XL emulator session, explicitly selected as `emulator-5580`. The
debug-only `test_support/ui_next01_rehearsal.dart` uses deterministic gateways and
a reserved `.invalid` URL. OTP and Save were fixture operations, not email or
database integration. Its procedures are in the
[rehearsal README](../../apps/mobile/test_support/README.md).

Observed Android journeys:

1. Settled Welcome logo/orbits and immediately available actions.
2. Login, native email keyboard/input, keyboard Back, then Auth Back to Home
   without replaying Welcome.
3. Signed-out Messages with its tab selected and contextual Login.
4. Fixture OTP returning to the incomplete-profile Messages root.
5. Setup toolbar Back and Android system Back both returning to Messages.
6. A draft display name surviving hot reload; fixture Save completing readiness
   and opening the Messages inbox.

An Android debug APK was built and installed through the rehearsal launch. Local
captures include Welcome, keyboard, signed-out Messages and setup Save. iOS edge
swipes are verified in platform-configured widget tests for pushed Messages setup
and ordinary ready Profile editing; no iOS device/simulator run is claimed on this
Windows host. HTTPS OS association/dispatch, live OTP delivery and provider sign-in
are not established by these fixture/widget checks.

The app README explicitly requires: "Native Android/iOS navigation, keyboard and
hot-reload QA remains a separate, manual pre-merge gate; automated widget tests
are not a substitute." Android presentation QA above is complete; native iOS
QA remains required on an iOS-capable host/device, or requires an explicit user
waiver before merge. Reproduce Messages → setup → edge/toolbar Back and ready
Profile → edit → edge/toolbar Back, native keyboard dismissal and draft retention
through hot reload. Widget gesture tests do not waive this gate. The task-owned
Flutter session and temporary emulator were stopped after captures; the worktree
is retained while its PR requires QA.

## Safe reproduction and next slice

Use the opted-in fixture harness on a disposable emulator to reproduce keyboard,
OTP, setup Back/Save and hot reload without any backend operation. For configured
normal-app read QA, use an already signed-out spare installation and the retained
seed: Explore, revisit Home/Profile/public project detail, open Messages, enter
Auth and cancel. Do not regenerate/reset/reseed the founder's stack for these
checks. Real account/profile writes require the appropriate QA account/journey;
this record does not claim they were exercised by the fixture harness.

The next batch slice should start from the merged PR/latest `main`, preserving
`app/router/` native/draft seams, `app/startup/` dormant content boundary,
`foundation_screen.dart`, the stable navigation preference/three branches and
the existing public Proposal/Tavolo/resource presentation modules. Owner-list
redesign, form redesign, Maps and later batch slices remain outside this change.
