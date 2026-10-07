# Startup entry and installation tutorial

This module owns ordinary signed-out entry and the device-local introduction.
It does not own Auth, profile readiness, native-link delivery or product actions.

- `startup_flow.dart` owns the explicit tutorial version, approved page registry,
  installation preference store, run-only entry/defer flags and sanitized resume
  destinations. Bootstrap restores its preference before launching the app.
- `welcome_screen.dart` uses the shared `core/widgets/planets_hero.dart` native
  orbits/stars around the unchanged bundled founder logo. Its finite motion
  stops when hidden/backgrounded; reduced motion settles immediately. Actions
  are available throughout, and a failed asset load keeps them available.
- `tutorial_screen.dart` composes approved page builders and writes completion
  only after Finish on the final page. Cancel/Back defers for the current run;
  read/write failures remain explicit and retryable.

The production `TutorialRegistry(version: '1', pages: [])` is intentionally
dormant: there are no approved pages, no placeholder and no completion write.
Future approved content belongs in this registry; bump its explicit version
only when that content should be offered again. Synthetic pages belong in tests
or an explicitly opted-in debug harness, never in the production registry.

`planets.startup.completedTutorialVersion` is the only persisted startup key.
It is device-local, independent of login/account changes, with no backend or
account/cross-device synchronization. Explore suppresses Welcome for the current
run; restoring a session never completes a tutorial. Explicit destinations and
external journeys bypass Welcome and defer a tutorial. Ordinary successful Auth
or profile completion can insert a configured tutorial before their original
sanitized destination. There is no second native-link listener or navigator.

Successful explicit logout reports `AuthCommandState.didSignOut`; the existing
router resets only `hasEntered` and opens Welcome after Auth clears private
stacks. Failure, expired sessions and abandoned late commands do not reopen it.
Explore then suppresses Welcome again, including across background/resume.
Tutorial completion and the current-run tutorial deferral are untouched.

Debug builds expose **Reset welcome and tutorial (development)** in Settings.
It removes only this key and the current-run flags; Auth, language/navigation
preferences and backend data are untouched. Signed-out QA returns to Welcome;
an authenticated session continues normally. The reset does not ship in profile
or release builds.
