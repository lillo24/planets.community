# Project resource needs

This feature owns the Flutter read and creator-management boundary for stable
Project resource/material needs shared by one-time Proposals and recurring
Tavoli. It is separate from standalone Scambio-Dona listings, participation
membership, and later accepted-participant commitments. It also owns the
creator-only mobile consumption of the explainable Project-to-listing matcher.

## Source map

- `domain/project_resource_need_models.dart` defines strict public and owner
  need shapes, exact `open` / terminal `closed` state, and canonical input
  bounds.
- `domain/project_resource_match_models.dart` defines the public-safe listing
  projection, strict text/location reasons, explicit filters, and complete
  four-part keyset cursor.
- `data/project_resource_needs_gateway.dart` is the only Supabase boundary. It
  uses the five 04C3A RPCs and never reads `project_resource_needs` directly.
- `data/project_resource_matches_gateway.dart` calls only
  `list_project_resource_need_listing_matches`, validates every returned row,
  and converts the extra fetched row into `hasMore` without exposing it.
- `application/project_resource_needs_controllers.dart` owns independent public
  section loading, identity-bound creator history/mutations, revision checks,
  and narrow public invalidation after a mutation.
- `application/project_resource_matches_controller.dart` owns identity-, need-,
  and filter-bound matching state, refresh/pagination, deduplication, and stale
  response rejection.
- `presentation/project_resource_needs_section.dart` renders public open needs
  without making the enclosing Project detail depend on that read.
- `presentation/project_resource_needs_screen.dart` renders creator open/closed
  history plus add/edit/close controls and the open-need matching entry point.
  Closed means only that the Project is no longer asking; it never means
  supplied or fulfilled.
- `presentation/project_resource_matches_screen.dart` shows explicit location
  and Dona/Scambia filters, localized stable match reasons, public-safe listing
  fields, and routes cards to the existing Resource detail.
- `presentation/project_resource_need_routes.dart` maps protected management
  and matching routes for both Proposals and Tavoli.

Creator state is held only in identity-bound Riverpod memory. Account changes
clear history and reject late reads/mutations. Route visibility is convenience,
not authorization: every operation carries the rendered creator identity and
the canonical backend rechecks ownership and lifecycle. There is no reopen,
delete, fulfillment, quantity, price, taxonomy, contributor, Realtime, or
persisted Scambio-Dona linkage in this feature.

The first matcher remains creator-only and lexical/explainable. It has no
numeric score, synonym/taxonomy layer, private availability inference, saved
search, or direct Project-need-to-Resource-request relation. A match never
closes or covers a Project need and never creates a Resource request.
