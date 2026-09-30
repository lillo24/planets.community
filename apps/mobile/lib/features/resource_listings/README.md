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
  response rejection, cover reconciliation ordering, and focused refresh
  coordination.
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
  create/edit form, editor-local optional cover intent, draft/publish actions,
  and terminal close flow.
- `presentation/resource_listing_widgets.dart` owns shared mode/lifecycle,
  location, date, cover-aware public card, and safe-error presentation.

Opening Create keeps the form local and does not create a row. A new Publish
creates one draft and then publishes that exact ID; if publication fails, the
controller retains the ID so a retry cannot create a second draft. Public
discovery uses backend mode/locality/literal-keyword filters and paired
`published_at + listing_id` keyset pagination.

When centrally gated demo tools are enabled, only the create form exposes a
synthetic listing preset. It fills fields this model already owns, preserves the
currently selected Donate/Exchange mode, and does not create a row until the
developer explicitly saves or publishes.

Draft creation and editing remain photo-independent. Only the actual
draft-to-published transition requires a canonical owner photo; both photo
audiences qualify. The editor performs a best-effort local preflight and maps
the authoritative `PT422` response to the reusable profile-photo trust dialog.
Returning from Profile never auto-publishes, and a failed first publication
keeps its one retained draft for an explicit retry.

Resource covers reuse `features/cover_media/` for gallery selection, fixed
16:9 cropping, metadata-free WebP normalization, immutable Storage paths,
loading/fallback rendering, and typed persistence failures. A new listing is
created before pending bytes are uploaded; cover reconciliation completes
before Publish. Cover failure retains that exact draft for retry, and an
existing listing reports content-saved/cover-failed partial success against a
canonical reread. Public discovery/detail, My listings, and Project-resource
match cards render the canonical path without per-card metadata RPCs. Owner
draft bytes use the identity-safe loader. The cover stays optional and never
satisfies or changes the independent profile-photo trust gate.

Public detail loads owner-photo metadata through the exact listing-context
boundary, separately from generic interaction caches. Anonymous and unrelated
viewers can therefore see the current owner avatar for a published listing
without receiving generic profile-photo access. Draft and closed listing
contexts remain private except to their canonical owner.

The listing feature does not own private request state. It renders only the
backend-derived active-interest count and delegates Request/Withdraw/View to
`resource_requests/`, whose identity-bound history determines the action. It
still has no reservation, handoff, lending, barter, payment, quantity,
taxonomy, Project linkage, or notification UX. Cover display in matching
results is inherited through the shared public Resource card and does not
change matching semantics. Personal saved
search definitions are independently owned by `resource_saved_searches/`; Open
feeds their tuple back through this feature's normal public controller.
Closing only removes a listing from public discovery and records no transfer
outcome.
Published and closed owner listings retain a private schedule entry point;
the owner-only D1 RPC remains the authority for schedule access. No schedule
RPC is called per listing card, and public discovery does not expose borrower
names or reserved periods.

Multiple photos, camera capture, chat attachments, and Drive/workspace media
remain outside this feature.
