# Mobile demo tools

This folder owns opt-in presentation helpers for fast local and staging demos.
It does not own persisted demo records or a separate application environment.

- `demo_tools.dart` exposes the single provider backed by validated app
  configuration.
- `demo_widgets.dart` owns the reusable shell indicator and form preset action.

Feature editors keep their own synthetic values because each form is the source
of truth for the fields it can safely mutate. Presets only change local form
state; they never save, publish, authenticate, or call a gateway.
