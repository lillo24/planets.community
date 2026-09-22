# Resource loans

This feature presents the 04C4D1 backend-derived listing-owner loan schedule
and an informational preflight for one exact pending owner-side LEND terms
version. It never computes conflicts locally or mutates a reservation.

## Source map

- `domain/resource_loan_models.dart` owns the active reservation and pending
  availability value models.
- `data/resource_loan_gateway.dart` is the only backend adapter. It calls the
  two D1 RPCs and rejects malformed rows; schedule order is preserved.
- `application/resource_loan_controllers.dart` owns identity/listing-bound
  schedule state and identity/agreement/pending-version-bound preflight state.
- `presentation/resource_loan_schedule_screen.dart` owns the protected owner
  timeline and navigation to the matching Resource request.

The schedule reloads on entry, pull-to-refresh, and app resume; it does not
poll or add a chat subscription. The existing Resource-chat subscription causes
the canonical Resource-exchange controller to refresh; its pending pointer
drives preflight invalidation. A known conflict disables Accept, while a failed
preflight leaves the backend's authoritative acceptance check available. PT409
from the preflight triggers a canonical reload without replaying the stale
terms ID. Future at-risk reservations remain valid and are not FIFO positions.
