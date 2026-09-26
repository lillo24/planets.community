# Scambio-Dona mobile boundary

This feature owns the Flutter discovery and owner-management experience for
standalone Scambio-Dona listings. It stays separate from Projects,
Participation, and Project resources.

- `domain/resource_listing_models.dart` owns strict listing modes,
  lifecycles, public/owner shapes, cursors, inputs, and client-side validation.
- `data/resource_listing_gateway.dart` is the only backend adapter. It calls
  the eight canonical 04C1 RPCs and parses their narrow payloads; it never
  accesses `resource_listings` directly.
- `application/resource_listing_controllers.dart` owns public pagination and
  filters, public detail, identity-bound owner history, editor lifecycle, stale
  response rejection, and focused refresh coordination.
- `presentation/public_resource_listings_screen.dart` owns signed-out
  discovery, public detail, the sanitized active-interest count, and the
  authenticated non-owner entry point into the adjacent `resource_requests/`
  feature.
- `presentation/own_resource_listings_screen.dart` owns the canonical
  draft/published/closed owner history and the non-draft owner entry point to
  the adjacent private `resource_loans/` schedule.
- `presentation/resource_listing_editor_screen.dart` owns the local
  create/edit form, draft/publish actions, and terminal close flow.
- `presentation/resource_listing_widgets.dart` owns shared mode/lifecycle,
  location, date, card, and safe-error presentation.

Opening Create keeps the form local and does not create a row. A new Publish
creates one draft and then publishes that exact ID; if publication fails, the
controller retains the ID so a retry cannot create a second draft. Public
discovery uses backend mode/locality/literal-keyword filters and paired
`published_at + listing_id` keyset pagination. Query and locality changes share
a 350-millisecond debounce, submit and mode changes flush immediately, and the
controller retains current cards with a subtle progress indicator while a
replacement page loads. Revision checks ignore late responses from an older
filter set; no speculative local filtering is applied.

Cards place relative publication age at top-right, keep mode as secondary
metadata, and render interest and one canonical rough-location line at the
bottom. The same localized age formatter is used on detail. Detail groups the
description and deduplicated location into restrained sections, keeps the
existing signed-in request lifecycle and owner shortcuts, and gives signed-out
visitors a Request CTA routed through `/auth` with the exact listing return
path. Concise helper copy explains that chat and Give/Lend exchange terms remain
post-acceptance behaviors owned by the adjacent request/chat/agreement features.

The listing feature does not own private request state. It renders only the
backend-derived active-interest count and delegates Request/Withdraw/View to
`resource_requests/`, whose identity-bound history determines the action. It
still has no reservation, handoff, lending, barter, payment, quantity,
taxonomy, media, Project linkage, saved-search, matching, or notification UX.
Closing only removes a listing from public discovery and records no transfer
outcome.
Published and closed owner listings retain a private schedule entry point;
the owner-only D1 RPC remains the authority for schedule access. No schedule
RPC is called per listing card, and public discovery does not expose borrower
names or reserved periods.
