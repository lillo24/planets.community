# Shared locations

Owns MAP01 search contracts and MAP02's editor-local transaction. Production
still uses `DisabledPlaceSearchGateway`: manual fields remain functional. The
three editors exercise the selector through injected scoped factories. No map
SDK, GPS permission, provider key or live traffic is activated.

- `domain/item_location.dart` parses canonical normalized editor selections,
  omitting coordinates, provider IDs and receipts from the protected projection.
- `data/item_location_gateway.dart` owns authorized reads, receipt-only writes
  and the disabled scoped factory. Activation must construct a separate server
  gateway for each supplied actor/item/revision/slot; both backend switches apply.
- `application/location_editor_session.dart` owns save, authorized revision,
  scoped search/resolve, stable mutation UUID and canonical reread. Response-loss
  retry retains exact input without another content save; superseding edits fail.
- `presentation/location_editor_section.dart` owns EN/IT manual/lookup modes,
  explicit tap/confirmation, type, Change/Clear/manual controls, fixed credit
  links, focus/keyboard/Back and actor/readiness/route/foreground invalidation.
  The editor handle revokes receipts before ordinary Save/Publish. Unchanged
  hydration or cursor movement is not a content edit. A stable key retains the
  first-save session when editor list contents change.

- `domain/place_search.dart`: bounded Italy/Trento requests, locality/address/amenity
  suggestions, mandatory adapter-supplied expiry and independent public locality
  representation. No JSON or `ProposalInput` conversion exists.
- `data/place_search_gateway.dart`: app-owned search/resolve interface and the
  disabled Riverpod registration.
- `data/server_place_search_gateway.dart`: injectable authenticated Edge adapter
  bound to a saved actor/item/revision/slot. Resolves opaque server receipts with
  narrow provenance and unchanged expiry; never accepts a Geoapify key or public
  private-detail cache. Its default is disabled; MAP02 owns lifecycle wiring.
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
their contracts. Canonical nullable storage and versioned receipt/read/write
RPCs are documented in the [MAP01 contract](../../../../../docs/development/map01-geoapify-location.md).
Short-lived receipt objects must not enter draft snapshots. The transient
controller is wired through a **disabled production factory**. Actor/form
generations, readiness, entitlement denials and expiry revoke transient work.
Credits stay visible after clear and in manual mode because derived ordinary
text may survive geometry. MAP03 credits relevant public surfaces; provider activation still requires owner review. A native fake does not prove live provider authorization.

Projects choose an independent public locality and optional exact address/venue;
instructions and Participants/Public remain separate. Resources have one public
slot of any supported precision. See the [MAP02 flow and reproduction](../../../../../docs/development/map02-location-selector.md).

`PublicPlaceArea` rejects a precise result. A future adapter must resolve broad
area independently; rounding, blurring or zooming out an exact pin is insufficient.
Future private maps belong only to canonical identity-bound protected reads,
never shared public caches.

See [provider readiness](../../../../../docs/development/location-provider-readiness.md).

MAP03 is separate from editing. The location_preview domain model defines
read-only precision and Maps URLs; location_preview_gateway owns RPCs, the
disabled static factory and launcher. public_preview_batch owns bounded
public-only read/image caches. location_preview_panel owns laziness, generations,
leases, uncached native decoding and distinct taps. location_attribution is the
fixed linked credit atom shared with editors. The old location_fallbacks map
remains a compatibility widget; real detail now uses the shared panel.
See [MAP03](../../../../../docs/development/map03-location-previews.md).
