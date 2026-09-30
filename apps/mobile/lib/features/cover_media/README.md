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
- `presentation/` owns the fixed 16:9 crop, local editor preview, and shared
  loading/fallback rendering widgets.

New-Project and new-Resource selection remains local until the parent draft has
been created. Save and Publish reconcile the cover before any publish
transition, so a cover failure leaves the same canonical draft available for
retry. Covers remain optional and independent from profile-photo publication
gates. This feature does not provide galleries, camera capture, Drive hosting,
or chat attachments.
