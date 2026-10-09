# NAVPERF01 navigation evidence

The paired baseline is main `17b5ae1014607eb9c4e5ff424b3f45aab4d8efa3`, including
HERO05, MSG04, TUT04 and MAP-UX01. Changed production responsibilities are
Welcome action dispatch and the shared hero's layout boundary.

## Findings and resulting behavior

Two rapid Explore taps produced **two route-information requests** for unseen,
completed and dismissed tutorial states. Welcome now accepts one action
synchronously and disables both buttons. Routing starts in the same gesture;
the next paint shows the ready destination or pending disabled actions. Pending
Explore reuses the existing sparkle glyph. A stale Welcome gesture checks the
pending URI and Auth phase. No deferred callback can replay an old surface;
newer navigation remains router-owned. Auth/OTP, installation state and native
continuation policies retain their existing owners.

The baseline Home idle trace records **95 LayoutBuilder builds and 95
RenderStack layouts over 94 raster frames**. Its geometry was inside the
continuous orbit builder. Moving that geometry outside the builder removes
per-frame layout while preserving paint/float updates, HERO05 geometry/stars,
finite entrance, reduced motion and viewport/lifecycle suspension. The trace
counts below audit this separately from journey timing samples.

An experiment forced a Welcome acknowledgement frame before committing the
route. Cold intro chrome then took 201–258ms, with 145–196ms raster peaks. A
local plain-ripple experiment still took 255ms. Those experiments did not
justify a tap-effect change; the final code retains the existing default ink
and starts routing synchronously. There is no timer, extra acknowledgement
paint, new glyph, added route transition, speculative cache or startup prewarm.

Ordinary public routing already avoids async editor/native coordination when
there is no departure owner. No synchronous Auth/network stall was demonstrated.
Project detail Back returned to `/proposals` in every paired attempt; Messages
Requests consumed Back correctly. No router/Back policy change was needed.

## Measurement conditions and limits

Flutter 3.47.2, Dart 3.13.2, profile Android x64 APK, API 35 Google APIs; owned
`PLANETS_HERO05_NAVPERF01_QA_API35`, port 5586. Both APKs use 720×1600 pixels,
density 280, 60Hz, SwiftShader indirect software GPU and 1GiB guest memory,
normal motion, the same synthetic Proposal/detail and a fresh in-memory startup
preference per test. The emulator restarts before each APK run; installation
cache is absent/cleared only on that owned emulator. `--no-dds` avoids a Windows
device-to-host DDS websocket failure. The paired probe source/actions match.

This runs real native widgets/router/rendering with deterministic fake gateways,
without hosted credentials, network/DB reads or retained preferences. “Fresh”
means unseen tutorial/run state, not cold bootstrap or the engine's first frame.
The SDK flushes old timings for two seconds before each action. FrameTiming
samples include action/350ms continuation frames and batched timings during the
subsequent flush. Gesture-to-chrome is a harness stopwatch ending after a paint
containing the destination key; it includes scheduling overhead. Detail Back
measures the next paint of the persistent NavigationBar, with its resulting URI
recorded/asserted separately.

The separate idle trace enables build/layout profiling for 60 requested 16ms
pumps under `fullyLive`; actual raster counts differ because the engine keeps
ticking. Its instrumentation overhead is excluded from journey frame summaries.
Software-GPU/host scheduling variability prevents a universal latency/FPS claim.
Physical Android was disconnected; physical Android/iOS, live backend latency,
cold bootstrap and platform accessibility QA remain unrun.

## Reproduction and raw evidence

`before.json.gz` and `after.json.gz` contain complete SDK summaries, per-frame
build/raster arrays, chrome stopwatches, actual Back URIs and synthetic idle VM
timelines. Gzip reduces storage only; no samples are filtered. Print every
journey's before/after chrome, UI/raster p90/peak and idle counts from repo root:

```text
node docs/development/evidence/navperf01/summarize.mjs
```

The opt-in [probe instructions](../../../../apps/mobile/integration_test/README.md#navigation-profile-probe)
describe build/run/cache isolation. Probes add no release telemetry or dependency.

The native journey covers unseen Explore→intro→Back, completed Explore→Home,
three Home↔Projects/detail/Back and Home↔Scambio rounds, Messages Requests/Back,
and Welcome→Login→Back. Widget tests add dismissed tutorial, rapid/competing
actions, stale visible Welcome gestures and newer destinations. Existing full
mobile regressions cover logout, Auth/OTP, browser/native project links, draft
departure, tutorial readiness/reveal and hero lifecycle/layout.

## Final results and local validation

- `npm run check:mobile`: localization generation, formatting, analysis and
  **1,951 passing tests, two existing skips** on the final source.
- Focused navigation/hero suite: **30 passing tests**; integration/driver
  formatting and Node summarizer syntax/runtime checks also pass.
- Final Android profile probe: all three tests pass, covering the journeys above.
  Every detail Back records `/proposals`. A prior attempt was discarded after
  the emulator's boot-time theme update recreated its activity and detached the
  host driver; the saved sample comes from one stable activity/isolate.
- Before APK SHA-256:
  `de5c6f7821baf9c0252e12bdbcdd943201698e66263006fe85ad266644ed3c43`.
  Final APK SHA-256:
  `abc86268988559d03ac6720feeb519f124aed82aac6c74e10859824da37772a9`.

Final idle counts are **95→0 LayoutBuilder builds and RenderStack layouts**,
over 94/91 raster frames. Cold intro raster peak is 45.93→44.08ms, but its
chrome stopwatch is 85.73→128.17ms. Completed Home is 79.33→99.18ms; other
journeys also vary. The evidence supports removal of redundant layout and
single-action/first-paint correctness, **not a universal latency improvement**.

The complete paired table below is generated by `summarize.mjs`; each duration
cell is before / after in milliseconds.

All durations in ms; each cell is before / after. Index 0 is first use, 1 and 2 are repeats.

| Journey | Tap to chrome | UI p90 | UI peak | Raster p90 | Raster peak |
| --- | ---: | ---: | ---: | ---: | ---: |
| fresh-explore-intro | 85.73 / 128.17 | 4.45 / 5.26 | 8.66 / 13.31 | 18.28 / 26.84 | 45.93 / 44.08 |
| completed-explore-home | 79.33 / 99.18 | 3.45 / 2.67 | 4.22 / 13.81 | 24.86 / 21.88 | 33.19 / 30.74 |
| home-projects-0 | 101.40 / 159.80 | 11.14 / 18.34 | 15.92 / 30.56 | 32.27 / 24.60 | 100.06 / 133.79 |
| project-detail-0 | 79.70 / 138.11 | 4.45 / 5.20 | 9.69 / 16.36 | 22.68 / 27.15 | 33.20 / 28.30 |
| detail-back-0 | 65.30 / 30.42 | 0.78 / 2.36 | 2.63 / 4.33 | 24.29 / 33.88 | 63.30 / 81.34 |
| projects-home-0 | 77.84 / 87.78 | 2.67 / 5.17 | 7.86 / 5.53 | 17.23 / 21.55 | 22.88 / 35.36 |
| home-resources-0 | 78.25 / 130.47 | 3.61 / 4.79 | 3.80 / 6.79 | 24.31 / 24.64 | 27.56 / 30.76 |
| resources-home-0 | 64.93 / 89.38 | 1.45 / 2.50 | 2.85 / 7.65 | 22.87 / 20.14 | 23.98 / 30.18 |
| home-projects-1 | 66.39 / 115.45 | 3.58 / 6.45 | 9.82 / 10.37 | 21.78 / 28.72 | 24.71 / 32.86 |
| project-detail-1 | 79.41 / 122.94 | 4.56 / 5.65 | 6.49 / 10.33 | 18.69 / 19.97 | 22.22 / 23.02 |
| detail-back-1 | 49.96 / 38.71 | 1.47 / 2.53 | 2.92 / 5.10 | 19.74 / 28.11 | 19.90 / 29.29 |
| projects-home-1 | 94.42 / 89.41 | 3.54 / 3.26 | 3.61 / 14.16 | 20.32 / 34.22 | 22.34 / 36.85 |
| home-resources-1 | 96.69 / 104.63 | 2.39 / 3.62 | 9.40 / 10.12 | 16.71 / 19.38 | 22.26 / 35.97 |
| resources-home-1 | 58.18 / 126.86 | 2.97 / 4.63 | 3.40 / 6.55 | 25.61 / 23.55 | 37.67 / 36.83 |
| home-projects-2 | 53.38 / 85.13 | 3.18 / 3.46 | 3.72 / 9.68 | 19.17 / 26.31 | 19.50 / 38.16 |
| project-detail-2 | 74.16 / 71.13 | 9.32 / 1.65 | 9.32 / 6.25 | 19.25 / 26.30 | 19.25 / 35.86 |
| detail-back-2 | 35.06 / 36.23 | 0.96 / 3.38 | 3.03 / 3.73 | 35.77 / 24.85 | 37.24 / 25.31 |
| projects-home-2 | 65.55 / 63.91 | 3.77 / 2.82 | 5.28 / 5.98 | 19.35 / 21.51 | 23.15 / 24.64 |
| home-resources-2 | 66.10 / 95.16 | 3.14 / 7.31 | 6.48 / 22.61 | 27.00 / 31.38 | 28.11 / 36.31 |
| resources-home-2 | 80.71 / 169.87 | 1.38 / 2.66 | 3.01 / 5.91 | 17.40 / 40.35 | 19.85 / 45.76 |
| welcome-login | 64.63 / 108.92 | 2.79 / 8.19 | 4.38 / 14.39 | 22.05 / 39.05 | 28.15 / 40.13 |

Idle trace event counts (separate diagnostic window):

| Begin event | Before | After |
| --- | ---: | ---: |
| GPURasterizer::Draw | 94 | 91 |
| LayoutBuilder | 95 | 0 |
| RenderStack | 95 | 0 |
| Stack | 95 | 92 |
| AnimatedBuilder | 103 | 94 |

Back 0: /proposals / /proposals

Back 1: /proposals / /proposals

Back 2: /proposals / /proposals
