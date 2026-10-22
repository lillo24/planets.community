# Mock Mode

This feature owns closed-test realm/session switching and the shared account
selection boundary. Ordinary product features continue to own their canonical
domain behavior through the active Supabase client.

- `domain/mock_models.dart`: bounded broker catalog and public operation bindings;
  token bootstraps deliberately redact their string representation.
- `data/mock_client_capability.dart`: private random capability persistence and lazy guest bootstrap; no normal Auth dependency.
- `data/mock_mode_store.dart`: one atomic installation preference record containing
  version-2 mode/client/persona/realm/request/revision metadata and retained-account presence, never credentials. Legacy mock keys retire without clearing normal sessions.
- `data/mock_session_access.dart`: public client-capability broker calls and
  real candidate-session/profile validation on a non-active mock client.
- `application/mock_mode_coordinator.dart`: one serialized switching owner and
  recovery state; a monotone revision fences late/ABA completions.
- `presentation/mock_realm_host.dart`: replaces the complete root provider/router
  scope on activation, keeping installation preferences and normal Auth outside
  the discarded product scope.

Core `secure_session_storage.dart` owns platform credential persistence and
legacy normal-session migration. `realm_transport.dart` fences old captured
gateways and keeps normal Auth maintenance separate from normal product traffic.
See `docs/development/mock-environment.md` for the fixed server contract and
readiness limits. `presentation/mock_accounts_screen.dart` is the shared initial
and Help selector, with localized exploration scenarios, current-account state,
catalog invalidation and no credential copying. The CI-only native release
target qualifies this same coordinator and actual backend clients.
