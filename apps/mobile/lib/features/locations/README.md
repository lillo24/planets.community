# Location foundation

Owns transient place-search contracts and honest disabled presentation. No live
adapter, key flag, map SDK, Project serialization, GPS permission or paid call is
registered. Production always uses `DisabledPlaceSearchGateway`.

- `domain/place_search.dart`: bounded Italy/Trento requests, broad versus address
  suggestions, mandatory adapter-supplied expiry and independent public locality
  representation. No JSON or `ProposalInput` conversion exists.
- `data/place_search_gateway.dart`: app-owned search/resolve interface and the
  disabled Riverpod registration. Synthetic adapters live only in tests.
- `application/place_search_controller.dart`: one transient editor session,
  350 ms debounce, 2–160 character requests, five unique Italian results, opaque
  session tokens and five-second timeouts. Typing never implies selection.
  Editing invalidates selection; cancel/dispose/expiry reject late completions,
  including detail resolution pending across a content deadline. Nothing persists.
  Legal lifetime comes from an approved adapter, never a guessed app TTL.
- `presentation/location_fallbacks.dart`: localized manual-entry notice and
  inert detail-only map fallback. The map accepts no location payload and builds
  no URL, platform view or fabricated directions.

Project manual fields, DRAFT01 snapshots and public/participant gateways retain
their contracts. The transient controller is **not wired into production forms**.
Future activation must bind its lifecycle to actor/form generation and canonical
entitlement changes. A cancellation unit test does not prove live authorization.

`PublicPlaceArea` rejects a precise result. A future adapter must resolve broad
area independently; rounding, blurring or zooming out an exact pin is insufficient.
Future private maps belong only to canonical identity-bound protected reads,
never shared public caches.

See [provider readiness](../../../../../docs/development/location-provider-readiness.md).
