# Resource exchange

UIPOLISH03 presentation keeps one canonical primary agreement action and moves
History/cancellation to a labelled menu with the same eligibility/confirmation.
Progress remains a visible secondary action. `ResourceExchangeFeedback` owns the
existing warning precedence and safe copy, composed above the chat summary so
warnings are never inside the menu. State, negotiation and milestone rules stay
in the existing controller/domain. See the UIPOLISH03 development record.

This feature owns the authenticated mobile negotiation surface for one
Scambio-Dona agreement. PostgreSQL remains canonical; the client reads and
mutates the agreement only through the versioned Resource-exchange RPCs.

## Source map

- `domain/resource_exchange_models.dart` owns strict agreement, immutable
  terms, event, historical-outcome, milestone-action, and leg-progress models;
  canonical cross-read reconciliation; and the separate mutable proposal
  draft.
- `data/resource_exchange_gateway.dart` owns exact read and mutation RPC
  contracts plus strict response parsing.
- `application/resource_exchange_controller.dart` owns agreement-bound state,
  draft baselines, role-aware actions, compare-and-swap pointers, typed
  milestone mutations, the bounded cross-read retry, canonical conflict
  reloads, and dependent Resource chat/Chats/Requests refreshes.
- `application/resource_exchange_refresh.dart` is the shared revision signal
  consumed by the controller. The Resource-chat feature remains the sole owner
  of the private Realtime subscription.
- `presentation/resource_exchange_widgets.dart` owns the persistent agreement
  card, current/pending terms sheet, proposal editor, pre-handoff cancellation,
  handoff progress and confirmations, durable history, immutable terms
  drill-down, and overdue presentation.
- `presentation/resource_exchange_failure_message.dart` maps failures to safe,
  localized UI copy without exposing backend diagnostics.

The adjacent `resource_loans/` feature consumes the canonical pending terms
pointer to show listing-owner LEND availability. It shares this feature's
existing refresh signal; it does not own another Realtime subscription.

Each proposal or counterproposal creates a new immutable terms version. The
accepted version is the current terms; a replacement can remain pending beside
it. Handoff freezes negotiation, so `in_progress`, `completed`, and `cancelled`
agreements are read-only here.

The terms-history RPC always projects `is_current` and `is_pending` as non-null
JSON booleans. The canonical agreement's `current_terms_id` and
`pending_terms_id` UUID pointers remain nullable; the flags are `false` when a
nullable pointer does not identify that terms row. The mobile parser keeps this
contract strict and rejects null, missing, or non-boolean flags.

04C4C3C2 adds the canonical event read and physical milestone write contracts.
Milestones are participant-confirmed statements, not independent verification;
completion is automatic after every required give/lend leg is complete. The
backend overdue booleans are authoritative and are presented as neutral return
guidance without penalties or fault. Handoff amendments, extensions, disputes,
damage handling, and liability remain future work. Resource notification UX
remains 04C4C3D.

Agreement, terms, and events are separate RPC reads. An obvious mixed snapshot
is retried once. If history still cannot be trusted, the last good agreement is
kept visible and milestone controls stay disabled until a later canonical
refresh succeeds. Resource chat continues to own the single private Realtime
subscription and coalesces its exchange signals through the shared refresh
revision.

UIAUDIT02 renders the existing private-note audience disclosure as ordinary
wrapping content directly below its field, so helper/counter line limits cannot
hide its audience statement. Agreement labels consistently use the listing noun;
no stored term, private-note permission or negotiation rule changes.
