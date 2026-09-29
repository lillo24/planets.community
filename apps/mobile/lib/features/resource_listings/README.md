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
  discovery, public detail with its exact-context owner avatar, canonical
  filter controls, the authenticated Save search entry point into adjacent
  `resource_saved_searches/`, the sanitized active-interest count, and the
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
`published_at + listing_id` keyset pagination.

Draft creation and editing remain photo-independent. Only the actual
draft-to-published transition requires a canonical owner photo; both photo
audiences qualify. The editor performs a best-effort local preflight and maps
the authoritative `PT422` response to the reusable profile-photo trust dialog.
Returning from Profile never auto-publishes, and a failed first publication
keeps its one retained draft for an explicit retry.

Public detail loads owner-photo metadata through the exact listing-context
boundary, separately from generic interaction caches. Anonymous and unrelated
viewers can therefore see the current owner avatar for a published listing
without receiving generic profile-photo access. Draft and closed listing
contexts remain private except to their canonical owner.

The listing feature does not own private request state. It renders only the
backend-derived active-interest count and delegates Request/Withdraw/View to
`resource_requests/`, whose identity-bound history determines the action. It
still has no reservation, handoff, lending, barter, payment, quantity,
taxonomy, media, Project linkage, matching, or notification UX. Personal saved
search definitions are independently owned by `resource_saved_searches/`; Open
feeds their tuple back through this feature's normal public controller.
Closing only removes a listing from public discovery and records no transfer
outcome.
Published and closed owner listings retain a private schedule entry point;
the owner-only D1 RPC remains the authority for schedule access. No schedule
RPC is called per listing card, and public discovery does not expose borrower
names or reserved periods.

09B2 composes Block/Unblock for a visible non-owner listing. A caller-owned
owner block explains why a new request is unavailable and offers Unblock;
public listing visibility and accepted Resource coordination remain unchanged.
