# Shared mobile widgets

This folder owns small presentation primitives reused across feature boundaries.

- `planets_hero.dart` shares the bundled PLANETS logo, stars and circular native
  orbit painter between Welcome and Home. `PlanetsOrbitMotion` matches the
  informative site's `apps/site/src/styles.css` / `App.tsx`: pink far orbit
  12 seconds clockwise, cyan outer orbit 16 seconds counterclockwise, gold inner
  orbit 18 seconds clockwise, all linear; the logo floats every 8 seconds using
  CSS ease-in-out with a calm 6px vertical float and no logo rotation. One
  repeating 144-second clock keeps these phases continuous. The settled hero
  sits slightly higher on both surfaces (27% of Welcome's available screen
  height, 62% of Home's decorative area, with Home's artwork lifted by another
  6% of that area into the existing scroll padding); rings scale to retain
  top-edge room for their planets on shorter layouts, leaving more breathing
  room below the logo without moving functional actions.
  Both surfaces pause without advancing hidden time when backgrounded, covered
  by another route, disabled by TickerMode, or scrolled outside the viewport.
  Reduced motion renders the initial orbit phases and settled entrance without
  ticking. Welcome adds its finite upward entrance; Home uses a smaller settled
  composition without replaying that entrance. Artwork ignores touches; Home
  places opaque, naturally sized cards above it and reduces decoration on
  short/scaled screens.

- `empty_state.dart`, `error_state.dart`, and `loading_state.dart` provide the
  standard asynchronous screen states.
  Empty state keeps its centered compact presentation and scrolls when a short
  allocated viewport (including native keyboard transitions) or enlarged text
  cannot contain its icon/copy. It does not dismiss the keyboard or alter Auth.
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
