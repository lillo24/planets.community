# Startup entry and installation tutorial

This module owns ordinary signed-out entry and the device-local introduction.
It does not own Auth, profile readiness, native-link delivery or product actions.

- `startup_flow.dart` owns the explicit tutorial version, approved page registry,
  installation preference store, run-only entry/defer flags and sanitized resume
  destinations. Bootstrap restores its preference before launching the app.
- `welcome_screen.dart` uses the shared `core/widgets/planets_hero.dart` native
  circular orbits/stars around the unchanged bundled founder logo. After the
  finite upward entrance, the shared website-speed planet rotations and logo
  float continue while visible. Both clocks pause when hidden/backgrounded;
  reduced motion settles immediately without ticking. Actions
  are available throughout, and a failed asset load keeps them available.
- `tutorial_screen.dart` owns the interactive /intro playback, current public
  screen widgets, painted target lookup using stable keys, short interruptible
  scrolling, timer/lifecycle guards, and a barrier against all underlying taps.
- `tutorial_presentation.dart` owns localized step copy, the spotlight painter,
  and clearly labelled illustrations. Examples are widgets only, never records
  injected into canonical public providers or Supabase.
- `tutorial_routes.dart` owns the typed in-memory replay capability and safe
  Back/Skip return. `tutorial_pages.dart` keeps the registry's synthetic page
  harness for existing startup policy tests; production uses guided steps.

Production activates `interactive-1` with fourteen four-second explanations and
an explicit final **Start exploring** action. Timing starts only after the target
is painted and scrolling/loading finishes. Public content waits are bounded:
empty, offline, full, unavailable or actionless Projects/Resources use a labelled
illustration. Next interrupts scrolling, taps are debounced, and reduced motion
uses immediate focus. Header controls and explanations wrap/scroll at large text.
Messages mounts its existing frame and scope selector with `controlsOnly: true`:
guest states remain truthful; ready conversations, inboxes and subscriptions are
never mounted. Underlying controls are excluded from semantics and gestures;
only the tutorial's accessible explanation, Next, Back and Skip remain actionable.

`planets.startup.completedTutorialVersion` remains the only persisted startup key.
A bare version records completed; `dismissed:<version>` records deliberate Skip.
Legacy bare versions remain readable. Only version/status is persisted, never
identity, selected Project IDs, return destinations or invitation/OTP data.
Finish and Skip navigate only after the local write succeeds. Errors remain
visible/retryable. Back, background interruption, account replacement and external
navigation do not write a status. First Explore and successful ordinary initial
Login offer an unseen version; restored sessions and explicit native/Auth journeys
retain the existing deferral policy. Completion/dismissal is installation-wide.

HELP01 can call the same audited route after either completion or dismissal:

```dart
await TutorialRoutes.replay(context, returnTo: '/help');
```

Replay uses a typed `extra`, not a query flag, keeps the caller on the router stack,
and pops back on Finish, Skip or Back. Its sanitized safe return is a fallback if
there is no caller to pop to. It does not erase or write installation status and
does not bypass any Auth guard. No second navigator or native-link listener exists.

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
