# TUT03 guided tour fidelity

Implemented from `PLANETS_TUT03_guided_tour_fidelity_fix.md`, starting at
`4f158f323ebdfacbc9e86b66072ac91c80118ddd` on `codex/tut03-guided-tour-fidelity`.
Before the PR, the change was rebased onto merged MAP02 at
`9d5e882e681dc2958b2a8be873d733654fc2ee47`; all 77 startup/tutorial/navigation/Help
tests passed on that integrated base. Both sets of appended localization entries
were preserved. A subsequent rebase integrated merged POLICY01 at
`9ae1222a161632d258e052450ce653035f07643c`; all 102 startup/tutorial/navigation/Help
and policy tests passed, as did formatting and analysis. Upstream policy guards,
test fixtures and localization content/formatting were preserved.
Final-head Mobile CI is required before merge.
The existing `/intro` coordinator and typed Help replay remain the owners.

The corrected `interactive-2` tour waits for Next/overlay input. Previous and system
Back restore the preceding surface; the first Back exits safely. Full Projects are
eligible for selection: the first displayed public Project identity is frozen,
and its public detail scrolls slowly to Join or truthful participation status.
The Project browse controls precede an explicit Home/Scambio transition. Scambio's
listing, Create and Drafts use three separate holes in one explanation.
Introduction/farewell have no spotlight, and body/Needs/modes are never targeted.
Illustrations have a bundled licensed cover and cannot write product records.

See [startup ownership and reproducible commands](../../apps/mobile/lib/app/startup/README.md)
and [cover provenance](../../apps/mobile/assets/tutorial/README.md).

## Android visual evidence

On 2026-10-08, the two backend-free integration journeys passed on the separately
created `PLANETS_TUT03_QA_API35` Android 15 / API 35 Pixel 6 emulator at
1080×2400 using Flutter 3.47.2 / Dart 3.13.2 (the CI-pinned versions).
The first traversed the empty guest/fallback tour; the second selected
the first Full fake-gateway Project, read its real product detail widgets and
traversed a real listing widget in Scambio. These are controlled fixture reads,
not live backend or founder-device QA. The screenshot host driver captured the
actual rendered frames, and the images below were visually inspected.

- [Home before entering Scambio](evidence/tut03/home-resources.png): orbit hero and
  the actual Scambio–Dona Home card, with one focus.
- [Scambio simultaneous focus](evidence/tut03/resources.png): labelled photo-bearing
  fallback, Create FAB and My listings/Drafts as three separate outlined holes;
  modes and search remain outside the focus.
- [Full Project participation](evidence/tut03/full-project.png): the canonical
  capacity/closed state and “No spots available,” without a fabricated Join action.

The native test asserts group geometry and zero create/publish mutations; its
complete/Skip/Previous and large-text regressions are covered by focused widget
tests. Shared devices and the retained demo database were not touched. The task
emulator was stopped and deleted after captures. Native iOS, physical-device
motion, TalkBack/VoiceOver and live public media reads remain unverified.

## Automated checks

Focused regressions cover manual 16-second holds, rapid taps, every Previous step,
the first Full Project and feed reorder, slow scroll/background interruption,
Back during scroll, actual guest Join interception, covered empty/unavailable
fallbacks, disappearing detail, guest/ready Messages privacy, English/Italian at
320 px and 2× text in light/dark with reduced motion, account replacement,
Help replay/return, local write failure/retry and corrected-version reoffer.
Two final regressions cover Next before the public feed resolves and late Needs
layout after participation focus has settled. The latter reproduced a stale
spotlight; detail scroll-metric notifications now refresh the actual control.
All 79 focused startup/tutorial/navigation/Help tests passed with these guards.

The required local gate is `npm run check:mobile` (localization, formatting,
analysis and the complete mobile test suite): 1,725 tests passed with the two
existing opt-in backend tests skipped. The 53 focused startup/tutorial/Help
regressions were rerun after restricting scroll keys to the tour. An additional
rapid replay-Finish regression passed after adding the single-exit guard; it proves
a stacked replay caller cannot be popped twice and installation status stays intact.
The early analyzer run identified
three formatting lints, which were fixed. A parallel rerun was interrupted under
host memory pressure; only the completed final rerun counts as validation.
Android captures preceded these final asynchronous-read/layout guards; their
behavior is covered by the focused tests, rather than a second native replay.
GitHub's existing path classifier selects Mobile for this change and leaves
unaffected Database/Web/Site jobs skipped. No CI configuration was changed.
