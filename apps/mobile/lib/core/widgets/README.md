# Shared mobile widgets

This folder owns small presentation primitives reused across feature boundaries.

- `planets_hero.dart` shares the bundled PLANETS logo, stars and circular native
  orbit painter between Welcome and Home. `PlanetsOrbitMotion` matches the
  informative site's `apps/site/src/styles.css` / `App.tsx`: pink far orbit
  12 seconds clockwise, cyan outer orbit 16 seconds counterclockwise, gold inner
  orbit 18 seconds clockwise, all linear; the logo floats every 8 seconds using
  CSS ease-in-out with a calm 6px vertical float and no logo rotation. One
  repeating 144-second clock keeps these phases continuous. Welcome retains
  its settled center at 40% of the SafeArea on ordinary portrait phones. Its
  complete upward entrance path, rings, halos and floating logo fit the actual
  canvas left above the 60dp-minimum actions; short/scaled layouts shrink it.
  Home retains its original upper center by transferring up to 24px of bottom
  scroll padding into the artwork-to-card gap. Growing both the minimum content
  height and column by the same amount preserves centering space and gives 24px more
  visible ring-to-card clearance on ordinary phones, without shifting the hero.
  Large text and short screens give that extra decoration space back. The scroll
  viewport still fills the body, and the painter reaches its top boundary.
  Both surfaces pause without advancing hidden time when backgrounded, covered
  by another route, disabled by TickerMode, or scrolled outside the viewport.
  Reduced motion renders the initial orbit phases and settled entrance without
  ticking. Welcome adds its finite upward entrance; Home uses a smaller settled
  composition without replaying that entrance. Artwork ignores touches; Home
  places opaque, naturally sized cards above it and reduces decoration on
  short/scaled screens.
  `PlanetsHero.farewell` is isolated to the tutorial finale: it rises gently
  from 50% to 44% of its usable canvas over the existing 2.2-second entrance
  clock, fits rings on short displays and retains the same orbits/logo float.

- `planets_starfield.dart` owns the shared seeded irregular star map: roughly
  one star per 2,400 logical square pixels, bounded to 8–100, with modest radius
  and opacity variation and separation-based scattering. Four size/distribution maps are
  cached; rebuilding/evicting a size regenerates identical coordinates from
  seed `0x504c414e`. Home/Welcome weight the lower visible backdrop; Home samples
  only above the first opaque card, avoiding stars wasted behind it. The finite
  Welcome drift settles onto those sampled coordinates. Only that entrance moves stars;
  orbit ticking does not on Home/Welcome. Farewell alone uses the existing
  144-second orbit clock for continuous downward star travel at 2–4 whole wraps
  per cycle, with radius-aware offscreen wrapping. It pauses with the artwork
  and is static under reduced motion. No image, network or additional clock is involved.

- `empty_state.dart`, `error_state.dart`, and `loading_state.dart` provide the
  standard asynchronous screen states.
- `async_data_presentation.dart` keeps nullable async screens consistent:
  not-yet-started/loading and different-target states render loading, only
  explicit same-target failures render errors, retained same-target data stays
  visible, and ready-without-data remains a domain-specific absent state.
- `requested_badge.dart` renders the shared Requested marker used by discovery
  surfaces.
- `browse_filter_button.dart` discloses secondary discovery controls, announces
  expanded state, and marks applied filters with a badge. The screen owns the
  disclosure state; toggling never applies or clears a filter.
- `tag_multi_select.dart` provides the controlled compact tag summary and
  bounded searchable category sheet used by Profile and Proposal filters. The
  caller owns committed selection state; staged mode applies changes only when
  requested by discovery filters. Clear/Apply or Done actions stack with a small
  gap when their labels cannot fit horizontally, including enlarged text.
