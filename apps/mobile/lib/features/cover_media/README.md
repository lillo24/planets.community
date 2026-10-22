# Cover media

This feature owns the reusable mobile pipeline for Proposal, Tavolo, and
Scambio-Dona Resource-listing cover images. It does not own any parent
lifecycle or the profile-photo trust gate.

- `domain/cover_media_models.dart` defines normalized images, local edit
  intent, strict RPC results, and safe failure categories.
- `data/cover_media_picker.dart` selects gallery bytes without requesting
  source metadata.
- `data/cover_media_gateway.dart` is the only Flutter boundary for the private
  `cover-images` bucket and typed owner-bound Project/Resource cover RPCs.
- `application/cover_media_processor.dart` performs deterministic 16:9 WebP
  normalization off the UI isolate. It never upscales, targets 280 KiB, and
  enforces the backend's 512 KiB hard limit.
- `application/cover_media_path_generator.dart` creates immutable paths bound
  to an owner and exact Project or Resource listing.
- `application/project_cover_reconciler.dart` uploads before committing the
  canonical row and treats stale-object deletion as best-effort cleanup.
- `application/resource_listing_cover_reconciler.dart` applies the same
  ordering through the Resource-specific canonical RPCs.
- `application/cover_image_loader.dart` caches public bytes by immutable path
  and rejects stale owner loads after an account change.
- `application/owner_cover_cache.dart` retains at most 32 immutable owner paths
  and 8 MiB in an LRU memory cache for the ready actor. It never writes to disk.
  Unmounted owner providers release their state; revisiting reuses cached bytes.
  Actor/readiness replacement, sign-out, provider disposal, memory pressure and
  app backgrounding clear bytes and evict their Flutter decoded-image keys.
  Generation checks reject late downloads. Storage 401/403 closes cache access
  until explicit refresh rebuilds it; failed downloads never return stale bytes.
- `presentation/` owns the fixed 16:9 crop, local editor preview, and shared
  loading/fallback rendering widgets.

`CoverImage.aspectRatio` controls display only and defaults to 16:9. Project
and Tavolo discovery cards opt into 3:2 with `BoxFit.cover`, including loading
and missing-image states. The My activities hub uses 1:1 thumbnails and the
optional `compact` neutral fallback, which omits long visual error copy but keeps
localized failure semantics. Details, older owner management screens, editors,
templates and Resource cards keep their existing ratio. Upload cropping and stored dimensions are
unchanged; the taller discovery frame crops the horizontal edges of 16:9 bytes.

New-Project and new-Resource selection remains local until the parent draft has
been created. Save and Publish reconcile the cover before any publish
transition, so a cover failure leaves the same canonical draft available for
retry. Covers remain optional and independent from profile-photo publication
gates. This feature does not provide galleries, camera capture, Drive hosting,
or chat attachments.

MYHUB01 hub covers always stay actor-scoped: an owner projection does not prove
public readability for moderated records. Public discovery continues to use
`publicCoverBytesProvider`. Neither cache is a fallback for failed authorization.
The hub observes forbidden owner-source reads and closes private cache access;
pull-to-refresh rebuilds the cache and revalidates through Storage. A different
immutable path is a cache miss. There is no bulk history preload or first-download
latency guarantee. Tests measure one download across provider disposal/revisit,
one additional download for a new path, and another download after actor/lifecycle
invalidation; count and byte eviction are tested independently.
