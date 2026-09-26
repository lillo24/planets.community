# Profile photo feature

This folder owns the signed-in owner's mobile profile-photo workflow over the
private Supabase Storage and RPC boundary established by Plan 08A1.

- `domain/profile_photo_models.dart` defines strict canonical metadata,
  public/interactions audience values, processing results, and safe UI state.
- `data/profile_photo_gateway.dart` is the only Flutter boundary for the A1
  owner RPCs and authenticated `profile-photos` Storage operations.
- `data/profile_photo_picker.dart` selects one gallery image without requesting
  camera access or durable app storage.
- `application/profile_photo_processor.dart` normalizes orientation, strips
  metadata, creates an exact 512×512 lossy WebP off the UI isolate, targets
  about 100 KiB, and enforces the 256000-byte client ceiling.
- `application/profile_photo_path_generator.dart` creates immutable
  `<profile-id>/<uuid-v4>.webp` object paths.
- `application/profile_photo_controller.dart` owns identity-safe loading,
  upload/commit/cleanup, audience, and removal state independently of the
  ordinary profile form.
- `presentation/` contains the circular avatar, fixed-square crop view, and
  owner management section.

The picker is gallery-only. The app keeps neither the original nor the cropped
intermediate after the flow, and uploaded objects are fresh WebP encodings.
Photo changes save immediately; first upload defaults to `interactions`, while
replacement preserves the canonical audience. Non-owner delivery remains
deferred to 08A3.

Native/package notes:

- `image_picker` uses the Android system picker with no storage or camera
  permission. Android remains at Flutter's existing minimum SDK 24.
- iOS Profile, Release, and Debug builds declare only
  `NSPhotoLibraryUsageDescription`; camera and microphone purpose strings are
  intentionally absent. The existing iOS 15 deployment target is unchanged.
- `crop_your_image` supplies the fixed 1:1 interactive crop UI, `image`
  performs the deterministic WebP pipeline, and `uuid` creates object versions.
