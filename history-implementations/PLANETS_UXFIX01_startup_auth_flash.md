# PLANETS UXFIX01 — Remove the Explore/Log in flash at startup

**Plan ID:** `UXFIX01`  
**Status:** Pending implementation — this file is a Codex handoff prompt, **not evidence that the fix is implemented**.  
**Scope:** Narrow Flutter startup/authentication bug fix. Work from the latest `main` of `lillo24/planets.community`; incorporate subsequent changes already merged there. Do not make unrelated UI changes.

## Objective

On an ordinary cold launch or process restart, a user with a valid saved session must **never see the signed-out Welcome screen** (`Explore App / Log in`) before Home appears. Show a minimal, branded PLANETS loading state while the initial session is genuinely unresolved, then navigate directly to the correct destination. A genuinely signed-out user should see Welcome; a restoration failure should show an actionable retry. Do **not** add an artificial fixed-duration splash or delay navigation after the state is known.

The user sees, in the installed Android app, a brief Welcome screen with `Explore App / Log in` followed by Home. This is the reproduction target, even though earlier tests/fixes reported success. Verify whether the installed build contains the relevant fixes; do not confuse a published build that is behind `main` with a current-code regression.

## Verified repository starting points (reinspect after updating `main`)

- `apps/mobile/lib/bootstrap/bootstrap.dart` awaits Supabase initialization and other persisted preferences, then starts `PlanetsApp`.
- `apps/mobile/lib/app/planets_app.dart` currently starts `authSessionProvider.notifier.start()` from a microtask in `initState`, after the router can be created/rendered.
- `apps/mobile/lib/features/auth/application/auth_session_controller.dart` starts in `AuthSessionPhase.restoring`, subscribes to `authStateChanges` and separately reads `currentSnapshot`; inspect their event ordering and distinguish a definitive signed-out outcome from an interim/unresolved state.
- `apps/mobile/lib/app/router/app_router.dart` currently redirects ordinary `/` to `/welcome` if `!startupFlow.hasEntered && session.identity == null` **before** its generic `restoring/restorationFailed` redirect guard. This is one plausible source of incorrect early navigation, but establish the full cause rather than assuming this condition alone explains all visible frames.
- `apps/mobile/lib/app/startup/welcome_screen.dart` already renders `AuthStatus` when phase is not `signedOut`, but this does not prevent transient `signedOut -> ready` renders. `apps/mobile/lib/features/auth/presentation/auth_status.dart` already has restoration and retry UI.
- `apps/mobile/test/app/startup/startup_navigation_test.dart` contains a restored-identity test, but it does not comprehensively assert the entire startup frame sequence. Read the related router/auth tests and `apps/mobile/lib/app/startup/README.md`.

## Required behavior

1. **Unknown/restoring:** ordinary root startup displays only a lightweight branded loading UI (bundled/local PLANETS logo and a restrained progress indicator, accessible, works in light/dark themes). No Explore/Log in controls, guest page, private page content, or bottom navigation may flash. Keep the native splash-to-Flutter handoff visually reasonable; reuse existing assets/styles rather than adding dependencies or heavy animations.
2. **Restored authenticated session:** go to Home with no intermediate guest welcome, even if initial auth events or profile-readiness checks complete on later frames. Keep existing profile setup and policy requirements intact.
3. **Definitively signed out:** show the normal Welcome with working Explore and Log in actions. Once the user chooses Explore, do not show Welcome again on returning to Home in that run. Explicit successful logout must still reopen Welcome once; passive expiry must retain the existing documented policy.
4. **Restoration error:** show a non-guest failure state with existing safe explanation and retry; do not silently treat an error as sign-out or spin indefinitely.
5. **Navigation/continuation:** do not intercept actual external deep links, native invitation URLs, requested public/protected destinations, live OTP/profile forms, tutorial replay, policy acceptance, or preserved `returnTo`. The new startup presentation applies to ordinary launch; it must not add a separate persistent navigation stack, reset the installation tutorial, or introduce duplicate native-link listeners.
6. **Performance/robustness:** no timer-based masking, no unnecessary backend round trip, no redundant auth controller start, and no routing loops. Determine when Supabase's restored initial session is authoritative (including `initialSession`/snapshot ordering, if relevant). Avoid displaying a false signed-out phase just because one early read is empty when the initial auth recovery is still pending. Ensure every waiting state has a legitimate exit or retry.

Choose the smallest coherent fix after reproducing the frame sequence. A root-only startup gate or routing placeholder may be appropriate, but verify interaction with `StartupFlow.hasEntered` and its explicit-journey deferral: merely adding a `/loading` route could inadvertently suppress Welcome/tutorial for real guests.

## Validation and regression tests

Add **frame-by-frame** tests (not only `pumpAndSettle` final assertions) to cover:

- Cold launch with a restored valid session; delayed initial auth event and delayed profile readiness: no painted Welcome actions or guest Home before Home is ready.
- The specifically observed transition where early startup information is incomplete, followed by a valid identity; ensure the earliest frames are loading rather than signed-out.
- Truly signed-out fresh install, expired/invalid session, restoration error and successful retry.
- Incomplete profile, same-user token refresh, successful explicit sign-out, and return to Home after Explore.
- Cold and warm external invitation/auth links, native continuation/OTP return targets, and unchanged tutorial entry behavior.

Use existing fake gateways and test harnesses where possible. Validate `flutter test` on the focused tests and `npm run check:mobile` or the repo's current equivalent. Record what passed and what could not be run. If feasible, perform an Android cold-process relaunch smoke test on a disposable emulator with a retained authenticated QA session; capture the first visible frames or another convincing frame trace. For optional physical-phone testing, the device ID is `48091FDAS0041A`: identify the installed package/build version and do not uninstall, clear data, sign out, or overwrite the user's Play Store testing app without explicit approval. An old installed release is not evidence of a new regression on current `main`.

## Non-goals and safeguards

No Supabase database changes, production configuration, policy changes, tutorial redesign, navigation-tab redesign, store publication or production deployment. Preserve all existing public/private access boundaries. Keep the change focused on Flutter startup state, presentation, routing, and tests.

## Delivery

Implement on a focused branch; create a PR with a concise explanation of the **confirmed** root cause, before/after frame behavior, the regression test, and commands/results. Follow the repo's normal required CI/merge flow if everything passes; do not publish a new Play release automatically. Flag any material uncertainty or unverified physical-device behavior. Explain that a merged fix requires a **new app build/release** before the installed Play version can benefit.
