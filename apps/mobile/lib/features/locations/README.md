# Shared locations

Owns MAP01 search contracts and MAP02's editor-local transaction. Production
and ordinary builds retain manual entry. MAP-LIVE01 adds an explicit staging-only
`LOCATION_EDITOR_SEARCH_ENABLED=true` opt-in: the factory constructs a distinct
authenticated server gateway for each saved actor/item/revision/slot. Readiness
loss fails closed, including late responses. Backend runtime and database kill
switches and quotas still apply. No provider key enters the client.
See the [staging activation runbook](../../../../../docs/development/map-live01-android-activation.md).

- `domain/item_location.dart` parses canonical normalized editor selections,
  omitting coordinates, provider IDs and receipts from the protected projection.
- `data/item_location_gateway.dart` owns authorized reads, receipt-only writes
  and the default-disabled, staging-only scoped factory. Activation constructs a separate server
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
leases, uncached native decoding and one freshly reauthorized Maps action.
MAP-UX01 removes preview panels from feed cards. Detail panels show authorized
text immediately, no image space when disabled, a 144dp actual PNG when enabled,
and one fallback on rendering failure. A decoded map is itself the action; only
unavailable imagery uses a compact text action with a valid canonical destination.
Centered small detail credits follow the image with independent 48dp links.
Denial still revokes protected state.
location_attribution is the compact labelSmall linked credit atom shared with
editors, detail, Map and List footers, retaining 48dp keyboard/tap targets.
The old location_fallbacks map
remains a compatibility widget; real detail now uses the shared panel.
See [MAP03](../../../../../docs/development/map03-location-previews.md).

MAP04 public radius/bounds queries live in the separate geographic_discovery
feature. It never uses editor receipts or protected preview reads. MAP05 must
define a distinct public search-center lookup before enabling autocomplete.

MAP-CACHE01 lets the existing canonical detail panel explicitly select the shared
read-only tile compositor, with default-off LOCATION_DETAIL_TILES_ENABLED.
Selecting tiles excludes static generation, including on errors/guests. Lease
revocation destroys protected tile pixels/buffers before reauthorization. Public
lease renewal retains an unchanged decoded view; route/scroll/TickerMode return
and transient OS `inactive` revalidate without restarting public tile transport.
Real background, account changes and learned shutdown still clear scopes.
An authorized locality becomes public only after an independently matching public
canonical read; the RPC audience alone never relaxes private ownership.
See [cache contract and fake measurements](../../../../../docs/development/map-cache01-shared-tiles.md).

## One-time inline place editor (LOCATION02)

`presentation/proposal_location_editor.dart` owns the Project-only primary query,
inline city/address/venue results, deliberate manual-city confirmation, explicit
exact-place-public switch and separate private arrival-directions disclosure.
Raw queries do not enter public form/matching fields. `LocationEditorHandle`
connects unsaved-query validation, draft departure, receipt revocation and save
acknowledgement. Exact selections default private; existing visibility rehydrates.
`LocationEditorSession.setProposalVisibility` and the gateway use the new
revision-bound `apply_proposal_place_v1`; the other editor slots stay unchanged.
Clearing directions preserves a verified point, and removing the point preserves
directions. City-only Projects still have no invented map point/destination.
The former `proposalCityOnly` adapter remains compatible for older consumers,
but the one-time editor now uses this component. See the
[LOCATION02 contract and staging handoff](../../../../../docs/development/location02-inline-project-place.md).
