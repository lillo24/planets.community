# Shared mobile widgets

This folder owns small presentation primitives reused across feature boundaries.

- `planets_hero.dart` shares the bundled PLANETS logo and native orbit/star
  painter between Welcome and Home. Welcome has a finite entrance that respects
  reduced motion, lifecycle and TickerMode; Home is a settled smaller composition
  with no animation controller. Artwork ignores touches; Home places opaque,
  naturally sized cards above it and reduces decoration on short/scaled screens.

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
