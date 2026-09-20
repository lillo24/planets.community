# Resource exchange

This feature owns the authenticated mobile negotiation surface for one
Scambio-Dona agreement. PostgreSQL remains canonical; the client reads and
mutates the agreement only through the versioned Resource-exchange RPCs.

## Source map

- `domain/resource_exchange_models.dart` owns strict agreement and immutable
  terms models, canonical pointer reconciliation, and the separate mutable
  proposal draft.
- `data/resource_exchange_gateway.dart` owns exact read and mutation RPC
  contracts plus strict response parsing.
- `application/resource_exchange_controller.dart` owns agreement-bound state,
  draft baselines, role-aware actions, compare-and-swap pointers, canonical
  conflict reloads, and dependent Messages refreshes.
- `application/resource_exchange_refresh.dart` is the shared revision signal
  consumed by the controller. The Resource-chat feature remains the sole owner
  of the private Realtime subscription.
- `presentation/resource_exchange_widgets.dart` owns the persistent agreement
  card, current/pending terms sheet, proposal editor, and pre-handoff
  cancellation confirmation.
- `presentation/resource_exchange_failure_message.dart` maps failures to safe,
  localized UI copy without exposing backend diagnostics.

Each proposal or counterproposal creates a new immutable terms version. The
accepted version is the current terms; a replacement can remain pending beside
it. Handoff freezes negotiation, so `in_progress`, `completed`, and `cancelled`
agreements are read-only here.

04C4C3C1 deliberately renders only the canonical current and pending versions.
It does not label older terms as accepted/rejected/withdrawn without the event
timeline. Physical handoff, receipt, return, full history, and overdue
presentation remain 04C4C3C2; Resource notification UX remains 04C4C3D.
