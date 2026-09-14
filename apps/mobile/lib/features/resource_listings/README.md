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
  discovery and read-only public detail.
- `presentation/own_resource_listings_screen.dart` owns the canonical
  draft/published/closed owner history.
- `presentation/resource_listing_editor_screen.dart` owns the local
  create/edit form, draft/publish actions, and terminal close flow.
- `presentation/resource_listing_widgets.dart` owns shared mode/lifecycle,
  location, date, card, and safe-error presentation.

Opening Create keeps the form local and does not create a row. A new Publish
creates one draft and then publishes that exact ID; if publication fails, the
controller retains the ID so a retry cannot create a second draft. Public
discovery uses backend mode/locality/literal-keyword filters and paired
`published_at + listing_id` keyset pagination.

The feature intentionally has no request, claim, reservation, contact,
handoff, lending, barter, payment, quantity, taxonomy, media, Project linkage,
saved-search, matching, or notification behavior. Closing only removes a
listing from public discovery and records no transfer outcome.
