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
  metadata, creates full (up to 512×512) and small (up to 160×160) lossy WebP off the UI isolate, targets
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
- `application/resource_listing_owner_photo_controller.dart` does the same for
  an exact Scambio-Dona listing. Its listing-keyed cache retains the resolved
  owner identity and is invalidated independently of generic interaction reads.
- `presentation/` contains the circular avatar, fixed-square crop view, and
  owner management section plus the reusable publish/join trust dialog.
  `VisibleProfilePhotoAvatar` accepts already-loaded viewer state and never
  performs per-row RPC calls.

The picker is gallery-only. The app keeps neither the original nor the cropped
intermediate after the flow, and uploaded objects are fresh WebP encodings.
Photo changes save immediately; first upload defaults to `interactions`, while
replacement preserves the canonical audience. The Project `interactions` set
follows current management: the immutable Creator or an active Co-creator/
Co-organizer may see a pending requester or current participant. A pending
requester/current participant may see only the immutable Creator through that
private Project context, not every manager. Revoked delegates, former
participants, rejected/withdrawn requesters, and co-participants do not qualify.

Scambio-Dona extends `interactions` without changing that Project matrix. A
listing owner may see a pending requester's photo, while the requester gains no
reverse generic access. Acceptance makes owner and requester mutually visible
until canonical agreement coordination closes; closing the listing alone does
not end that accepted relationship. Rejection, withdrawal, `listing_closed`,
agreement completion, or agreement cancellation ends the corresponding access
unless another qualifying relationship still exists.

Creator publication and a new join request require only that a canonical photo
exists; both audiences qualify and the app never rewrites the audience. The
database remains authoritative. Missing-photo prompts open the existing profile
editor as a pushed route, preserving the authoring/request form, and never
resubmit after return.

Scambio-Dona publication and creation of a new Resource request use the same
canonical-photo presence rule. Draft create/edit, already-published idempotent
publication, historical rows, and later photo removal remain unchanged. Mobile
preflight failure opens the same profile editor with Scambio-specific copy,
keeps the form or retained draft ID, and never submits automatically on return.

Generic viewer metadata is exact-ID or bounded batch (`1..50`) only. A distinct
Project-context RPC resolves the creator from an authorized Project ID and is
used only on Proposal/Tavolo detail. Public Project context may therefore render
an `interactions` organizer photo without making the generic exact-profile RPC
public. The app keeps
downloaded bytes in memory, clears them on login/logout/account switch, and
persists neither provider URLs nor files. Creator review batch-loads pending
applicant avatars and invalidates target cache entries after rejection,
withdrawal, leave, or removal.

Private Messages reuses the same bounded batch/cache boundary for Project
request and Resource counterparties. Refresh revalidates metadata while
unchanged immutable object versions reuse bytes; pagination requests only new
targets, and denial leaves the placeholder without failing chat data.
During same-viewer single/batch revalidation, loading entries retain previously
authorized in-memory metadata/bytes until a successful replacement is ready.
Canonical absence clears them immediately; metadata/download failures still
produce an explicit failure entry without bytes. Explicit target/all invalidation
and viewer changes clear immediately and reject late responses. This does not
skip authorization revalidation or persist images to disk.

An exact Resource-listing context RPC likewise resolves the owner server-side
for an owner or a currently public listing and never broadens generic profile
visibility. Resource request and chat surfaces use the generic relationship
cache for counterpart avatars, invalidating it when coordination ends or the
signed-in identity changes.

09B2 also invalidates exact-target and contextual Project/Resource owner photo
caches after Block/Unblock. A Block therefore cannot leave interaction-only
bytes rendered from memory; subsequent reloads remain canonical and may still
return a public photo. Unblock never assumes private photo access was restored.

Native/package notes:

- `image_picker` uses the Android system picker with no storage or camera
  permission. Android remains at Flutter's existing minimum SDK 24.
- iOS Profile, Release, and Debug builds declare only
  `NSPhotoLibraryUsageDescription`; camera and microphone purpose strings are
  intentionally absent. The existing iOS 15 deployment target is unchanged.
- `crop_your_image` supplies the fixed 1:1 interactive crop UI, `image`
  performs the deterministic WebP pipeline, and `uuid` creates object versions.


## IMG01 small/full variants

New crops produce two lossy, metadata-free WebP objects in the same isolate:
full up to 512 square (100 KiB target, 256000-byte ceiling), small up to 160
square (20 KiB target, 32768-byte ceiling). Sources smaller than either bound
are never upscaled. Both use independent immutable UUID paths and one atomic
`set_own_profile_photo_v2` metadata commit after both uploads. A partial upload or
failed commit retains the previous canonical photo and attempts cleanup of both
new paths. Replacement returns both old paths for best-effort Storage cleanup;
clear cascades the small metadata and the current client cleans its known old
small path. Concurrent/older-client replacement or deletion may leave a private
orphan, as in the existing deferred physical cleanup/account-deletion contract.

The private `profile_photo_thumbnails` relation binds one small path to the
exact current full path. V2 owner/viewer/batch/Project/Resource RPCs append nullable
`thumbnail_object_path`; all legacy RPC signatures and shapes remain unchanged.
Storage reuses the full object's canonical audience/context/block checks for the
small object, allows authenticated exact GET only, and never adds listing or
upsert access. Unregistered, replaced and cleared small objects are unreadable
to non-owners. The database verifies small owner, path, MIME and byte ceiling;
client processor tests verify actual decoded dimensions and metadata stripping.

List controllers download `smallObjectPath`; legacy photos explicitly fall back
to their existing full object without retrying, mass rewriting or requiring a
re-upload. A declared small-object failure is an explicit failure, never a hidden
full download. The person preview reauthorizes the exact target in its source
context and downloads full bytes into an auto-disposed provider. It never copies
Project-context permission into the generic cache. Block/unblock and owner
replace/remove/audience changes invalidate generic and contextual caches, cancel
in-flight reads, and both avatar variants evict decoded memory on replacement or
disposal. Identity changes clear all viewer bytes. No files or URLs are persisted.

Apply migration `20261021152141_profile_avatar_variants.sql` before activating
these mobile V2 reads. No hosted migration or rollout is performed by this PR.
Old clients continue full-only reads/writes; their next replacement removes any
old small reference. Reverting clients leaves the additive schema safe in place.

Validation: `flutter test test/features/profile test/features/profile_photo`;
`npm run profile:photo:viewer:verify:local` also exercises real small/full Storage
permissions, Project/Tavolo context, Block, legacy replacement/removal and the
32768-byte ceiling through `scripts/lib/profile-avatar-variant-verifier.mjs`.
`supabase test db --local` includes `148_profile_avatar_variants.test.sql`.
The deterministic textured 900x700 input measured 23538 full bytes at 512x512
and 2164 small bytes at 160x160, quality 82. Test input is synthetic; no personal
photo is archived. Physical Android/iOS gallery, pixel-density, VoiceOver and
TalkBack review remain separate native QA.
