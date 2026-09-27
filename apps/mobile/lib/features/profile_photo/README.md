# Profile photo feature

This folder owns owner management plus reusable owner/public/authorized
non-owner delivery over the private Supabase Storage and RPC boundary.

- `domain/profile_photo_models.dart` defines strict canonical metadata,
  public/interactions audience values, processing results, and safe UI state.
- `domain/visible_profile_photo_models.dart` defines the audience-free viewer
  metadata and identity-bound in-memory delivery state used by future surfaces.
- `data/profile_photo_gateway.dart` is the only Flutter boundary for the A1
  owner RPCs, A3 exact/batch viewer RPCs, and authorized `profile-photos`
  Storage operations.
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
- `application/visible_profile_photo_controller.dart` batches viewer metadata,
  downloads only authorized paths, caches bytes in memory by viewer/target/
  object version, drops stale responses on account changes, and exposes target
  invalidation for participation transitions.
- `application/profile_photo_requirement.dart` performs the optional local
  owner-metadata preflight used before trust-sensitive mutations. Only a
  successful empty read is treated as missing; transport failure defers to the
  authoritative database gate.
- `application/project_creator_photo_controller.dart` keeps Project-context
  organizer metadata and bytes in a separate project-keyed, identity-bound
  cache so contextual authorization never populates the generic profile cache.
- `presentation/` contains the circular avatar, fixed-square crop view, and
  owner management section plus the reusable publish/join trust dialog.
  `VisibleProfilePhotoAvatar` accepts already-loaded viewer state and never
  performs per-row RPC calls.

The picker is gallery-only. The app keeps neither the original nor the cropped
intermediate after the flow, and uploaded objects are fresh WebP encodings.
Photo changes save immediately; first upload defaults to `interactions`, while
replacement preserves the canonical audience. The first `interactions` set is
directional: a Project/Tavolo organizer may see a subject with a pending join
request or current membership in any Project they create. Former participants,
rejected/withdrawn requesters, co-participants, and reverse applicant-to-
organizer reads do not qualify. This is the first relationship set rather than
the permanent exhaustive meaning of interaction.

Creator publication and a new join request require only that a canonical photo
exists; both audiences qualify and the app never rewrites the audience. The
database remains authoritative. Missing-photo prompts open the existing profile
editor as a pushed route, preserving the authoring/request form, and never
resubmit after return.

Generic viewer metadata is exact-ID or bounded batch (`1..50`) only. A distinct
Project-context RPC resolves the creator from an authorized Project ID and is
used only on Proposal/Tavolo detail. Public Project context may therefore render
an `interactions` organizer photo without making the generic exact-profile RPC
public. The app keeps
downloaded bytes in memory, clears them on login/logout/account switch, and
persists neither provider URLs nor files. Creator review batch-loads pending
applicant avatars and invalidates target cache entries after rejection,
withdrawal, leave, or removal.

Native/package notes:

- `image_picker` uses the Android system picker with no storage or camera
  permission. Android remains at Flutter's existing minimum SDK 24.
- iOS Profile, Release, and Debug builds declare only
  `NSPhotoLibraryUsageDescription`; camera and microphone purpose strings are
  intentionally absent. The existing iOS 15 deployment target is unchanged.
- `crop_your_image` supplies the fixed 1:1 interactive crop UI, `image`
  performs the deterministic WebP pipeline, and `uuid` creates object versions.
