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
  Welcome targets a 40% SafeArea center with full-path halo bounds. Both actions
  have 60dp minimum height, 16px vertical padding and a 16px gap; long labels
  wrap and short/keyboard layouts scroll rather than clipping controls.
  The first accepted Explore/Login tap disables both actions synchronously and
  starts routing in that same gesture. The next paint shows destination chrome,
  or the pending disabled action if routing is still resolving. Pending Explore
  keeps the existing sparkle glyph static, without loading a new icon. A forced
  extra Welcome paint increased cold-entry latency in native profiles, so there
  is no timer, deferred commit or additional transition. A stale Welcome gesture
  checks the pending URI and signed-out phase; the router owns newer requests.
- `tutorial_screen.dart` owns the interactive /intro playback, current public
  screen widgets, painted target lookup using stable keys, adaptive interruptible
  detail scrolling, layout/lifecycle guards, and a barrier against all underlying taps.
- `tutorial_presentation.dart` owns localized step copy, the spotlight painter,
  and clearly labelled illustrations. Examples are widgets only, never records
  injected into canonical public providers or Supabase.
- `tutorial_motion.dart` defines the explicit entering/unobscured/fading/ready
  phases, reveal timings and distance-based scroll velocity.
- `tutorial_routes.dart` owns the typed in-memory replay capability and safe
  Back/Skip return. `tutorial_pages.dart` keeps the registry's synthetic page
  harness for existing startup policy tests; production uses guided steps.

Production activates `interactive-2`. Its eleven manually paced focus states are:
introduction (no spotlight), Home Projects, first displayed Project card, its
detail/participation, browse Create, browse Drafts, Home Scambio–Dona, Scambio's
card/Create/Drafts together, Messages Requests inbox, Messages Private/Groups,
and farewell (no spotlight). Explanation text never advances on a timer.
Only Next advances; tapping the preview or explanation leaves the step unchanged.
Previous and system Back move
one state backward and restore the surface, frozen selection and scroll position.
Back on the introduction exits safely. Only the 250 ms surface commit is debounced;
Next/Previous can interrupt the detail scroll without waiting for it to finish.
Previous and Next share a 56dp bottom row; the header contains progress/Skip.
The 19sp explanation uses the theme's title style and scrolls within a bounded
pane. New surfaces first paint meaningful content (or a bounded honest fallback),
hold unobscured for 600ms, then fade scrim/holes together over 380ms. Focus changes
within one surface move only the hole/border over 180ms, keeping the current
scrim alpha and any unfinished page hold/fade. Retargeting captures the currently
visible geometry, including after interruption. Explanation reflow retains that
hole until the new real anchor is measured. Page and focus use independent
controllers, both paused by lifecycle; no same-page dimmer reset occurs.
Ordinary provider/image/layout updates remeasure without repeating page entry. Reduced motion settles after content is ready.

Selection follows the existing public browse order (Requested first when present,
then ordinary Projects), including Full, closed, photo-less and actionless items.
The selected identity is fixed for this tour. Public read waits are bounded to
25 layout probes (normally about two seconds); absent/inaccessible data uses a
labelled cover-bearing illustration. A failed/disappearing detail cannot substitute
a different real Project. Illustrations never enter providers or database records.
Advancing before the browse read resolves keeps selection active in detail; it
shows loading until that read succeeds or the bounded wait expires.
Public browse screens accept an optional tutorial-only placeholder widget; their
normal filtering and fixed Create/Drafts controls are retained. Real covers and
participation state use the existing product widgets and authorization.
Public Project loading begins during introduction, preserving current filters,
page size and the existing controller's busy guard. The first three visible
canonical summaries warm their existing `publicCoverBytesProvider` entries;
warmup failures remain errors in that cache and in the normal cover UI.
Only the first selected detail is prefetched. `ensureLoaded` coalesces by ID and
session, rejects replaced-session results and reuses ready public data. Warmup
does not replace a different detail belonging to a covered caller. Explicit
normal detail loads/retries remain fresh. No tour ID/content is persisted.

On every detail page entry the cover/title remain visible briefly, then the real
sections scroll linearly at a maximum 500 logical pixels per second, stopping
at the real Join action or truthful Full/participation status. Body and Needs text
are not spotlighted. Reflow, backgrounding, Next/Previous, account replacement and
disposal invalidate old probes/scroll callbacks. Reduced motion uses immediate
focus. PageStorage belongs to the tour and is never persisted beyond it.
Detail scroll-metric changes refresh focus after late section layout updates, so
the spotlight follows the real participation control without another data read.
The opt-in tutorial preview lays out the same real sections eagerly so it can
measure the actual target distance in one continuous motion. Ordinary detail
retains its lazy list. Short and long descriptions therefore take proportional
time rather than a fixed crawl or repeated small seek animations.

Scambio has three separate outlined holes: first listing, fixed Create FAB,
and fixed My listings/Drafts action. The card is revealed by scrolling only its
list; its visible hole is clipped above the FAB so it cannot overlap that control.
Toolbar Drafts/Requests targets measure the rendered Icon, add 3px breathing room
and clamp inside the surface. Other targets add 6px once, before clamping;
the painter applies no extra global inflation.
Messages uses its existing frame and scope selector with `controlsOnly: true`:
all identities see explicitly labelled fictional, inert conversation examples;
conversations, inboxes, photo readers and subscriptions never mount. Requests focus
shows the Private example, then the selector focus shows Groups through a local
`previewScope`, leaving remembered Messages navigation untouched. The example
label/content remain in semantics; preview controls have no pointer actions.
Other underlying pages remain excluded from semantics and gestures. Tutorial explanation,
Next, Previous and Skip stay accessible outside the barrier and wrap/scroll at large
text. Farewell requires explicit **Start exploring**; Skip remains a dismissal.
Farewell alone uses `PlanetsHero.farewell`: a small ascent from 50% to 44% of
its canvas, bounded rings, unchanged orbit/float periods and continuously
descending seeded stars at 21–36 whole crossings per 144-second phase
(4.00–6.86 seconds each), with radius-padded offscreen wrapping.
The existing motion clocks pause hidden/backgrounded;
reduced motion is a static settled composition. Home/Welcome retain their
approved positions, entrance and star behavior.

The fallback cover is the unchanged licensed `garden-tools.webp` demo fixture,
bundled under `assets/tutorial`. Its provenance and checksum are recorded in that
folder's README and the original `scripts/demo-assets/assets.json`.

Focused regressions live in `test/app/startup/interactive_tutorial_test.dart` and
`startup_flow_test.dart`; Help replay coverage remains in `help_flow_test.dart`.
Android visual smoke uses the existing integration-test harness and an isolated,
task-owned emulator, with no shared database or device mutations:

```powershell
flutter drive -d <owned-emulator-id> --driver=test_driver/tutorial_screenshots.dart --target=integration_test/tutorial_smoke_test.dart --dart-define=TUT04_SCREENSHOTS=true
```

The host driver saves PNGs under `build/tutorial-screenshots` for the actual Home
transition, Scambio grouped focus, covered fallback, introduction and Full Project.
Without the define, `flutter test integration_test/tutorial_smoke_test.dart -d
<owned-emulator-id>` runs the same non-destructive guest journeys without captures.
These fake-gateway native tests validate layout/interaction, not live backend reads
or physical Android/iOS devices. `npm run check:mobile` remains the full local gate.

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
and pops back on Finish, Skip or Back from the introduction. Its sanitized safe return is a fallback if
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

TUT05 multi-frame capture uses `integration_test/tutorial_visual_probe_test.dart`
and `test_driver/tutorial_visual_probe.dart`. See
[the evidence record](../../../../../docs/development/evidence/tut05/README.md) for
before/after sources, capture commands, phase/alpha records and native QA limits.
