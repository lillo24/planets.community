# Project resource needs

This feature owns the Flutter read and creator-management boundary for stable
Project resource/material needs shared by one-time Proposals and recurring
Tavoli. It is separate from standalone Scambio-Dona listings, participation
membership, and later accepted-participant commitments.

## Source map

- `domain/project_resource_need_models.dart` defines strict public and owner
  need shapes, exact `open` / terminal `closed` state, and canonical input
  bounds.
- `data/project_resource_needs_gateway.dart` is the only Supabase boundary. It
  uses the five 04C3A RPCs and never reads `project_resource_needs` directly.
- `application/project_resource_needs_controllers.dart` owns independent public
  section loading, identity-bound creator history/mutations, revision checks,
  and narrow public invalidation after a mutation.
- `presentation/project_resource_needs_section.dart` renders public open needs
  without making the enclosing Project detail depend on that read.
- `presentation/project_resource_needs_screen.dart` renders creator open/closed
  history plus add/edit/close controls. Closed means only that the Project is no
  longer asking; it never means supplied or fulfilled.
- `presentation/project_resource_need_routes.dart` maps protected management to
  `/proposals/:id/resources` and `/tavoli/:id/resources`.

Creator state is held only in identity-bound Riverpod memory. Account changes
clear history and reject late reads/mutations. Route visibility is convenience,
not authorization: every operation carries the rendered creator identity and
the canonical backend rechecks ownership and lifecycle. There is no reopen,
delete, fulfillment, quantity, price, taxonomy, contributor, Realtime, or
Scambio-Dona linkage in this feature.

