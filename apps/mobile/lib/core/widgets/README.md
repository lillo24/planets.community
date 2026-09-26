# Shared mobile widgets

This folder owns small presentation primitives reused across feature boundaries.

- `empty_state.dart`, `error_state.dart`, and `loading_state.dart` provide the
  standard asynchronous screen states.
- `async_data_presentation.dart` keeps nullable async screens consistent:
  not-yet-started/loading states render loading, only explicit failures render
  errors, retained data stays visible, and ready-without-data remains a
  domain-specific absent state.
- `requested_badge.dart` renders the shared Requested marker used by discovery
  surfaces.
- `tag_multi_select.dart` provides the controlled compact tag summary and
  bounded searchable category sheet used by Profile and Proposal filters. The
  caller owns committed selection state; staged mode applies changes only when
  requested by discovery filters.
