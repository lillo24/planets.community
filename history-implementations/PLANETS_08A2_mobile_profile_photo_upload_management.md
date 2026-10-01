# PLANETS 08A2 — Mobile Profile Photo Upload + Management

**Roadmap area:** Plan 08 — Storage and media hardening  
**Sub-area:** 08A — Profile Pictures  
**Task type:** Flutter/mobile integration over 08A1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on:

```text
PR #95 — 08A1 Profile Photo Storage + Domain Foundation
branch: codex/08a1-profile-photo-storage-domain
head:   9c4d92af2558cb4624a1768f581791453aac920d
```

PR #95 is open and stacked on PR #94.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #95 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #95 head;
5. do not merge any PR.

Preferred branch:

```text
codex/08a2-mobile-profile-photo-management
```

Open against:

```text
codex/08a1-profile-photo-storage-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08A2_mobile_profile_photo_upload_management.md
```

No external product document is required.

---

# Product decisions already fixed

08A profile photos use:

```text
private bucket: profile-photos

output:
512×512
WebP
~100 KB compression target
250 KiB hard maximum

one canonical current photo
no retained original
versioned immutable object paths
```

Photo audience:

```text
public
interactions = “Only people I interact with”
```

Default for a new photo:

```text
interactions
```

08A2 is **owner-only mobile management**.

08A3 will implement actual non-owner:

```text
public
interactions
```

delivery.

---

# Objective

Implement the mobile owner flow:

```text
Profile
  ↓
Add / Change photo
  ↓
choose from gallery
  ↓
square crop
  ↓
exact 512×512
  ↓
lossy WebP compression
  ↓
~100 KB target / <=250 KiB required
  ↓
upload immutable version
  ↓
A1 canonical commit
  ↓
render current owner avatar
```

Also support:

```text
change audience
remove photo
```

Do not couple photo actions to the existing profile Save button.

---

# 1. No database migration

08A2 is mobile-only.

Do not change:

```text
profile_photos schema
Storage bucket/policies
A1 RPC signatures
existing profile visibility schema
```

Consume exactly:

```text
get_own_profile_photo(uuid)

set_own_profile_photo(
  uuid,
  text,
  text
)

set_own_profile_photo_audience(
  uuid,
  text
)

clear_own_profile_photo(uuid)
```

and Storage bucket:

```text
profile-photos
```

---

# 2. Keep ordinary profile editing backward-compatible

The existing:

```text
ProfileController
ProfileUpdate
ProfileAudience
ProfileFieldKey
update_own_profile(...)
```

remain unchanged.

Do not add photo state to:

```text
ProfileFieldKey
ProfileAudience
ProfileUpdate
```

Photo media has its own A1 audience model:

```text
public
interactions
```

This avoids changing the strict three-field:

```text
display_name
bio
skills
```

profile form contract.

---

# 3. Separate profile-photo feature/state boundary

Add a focused mobile boundary, either:

```text
features/profile_photo/
```

or a clearly separated submodule inside:

```text
features/profile/
```

Prefer independent components equivalent to:

```text
domain/profile_photo_models.dart
data/profile_photo_gateway.dart
application/profile_photo_controller.dart
application/profile_photo_processor.dart
presentation/profile_photo_section.dart
presentation/profile_photo_crop_view.dart
```

Exact file layout is Codex's choice.

Do not overload the existing text/skills ProfileController with upload/crop/storage state.

---

# 4. Dependencies

Inspect current Flutter/Dart/native support before pinning.

Preferred packages after current-package review:

```text
image_picker
crop_your_image
image >= 4.10.0
uuid
```

Rationale:

```text
image_picker
→ official Flutter gallery picker

crop_your_image
→ embedded/testable Flutter square-crop UI

image >=4.10.0
→ exact resize + lossy WebP encoding in Dart

uuid
→ opaque v4 object version path
```

Current `image` releases support WebP read/write, including lossy encoding.

Do not add:

```text
flutter_image_compress
image_cropper
camera
permission_handler
```

unless repository/package compatibility makes the preferred approach genuinely unsuitable.

If an alternative is required, explain it in the completion report.

---

# 5. Do not silently raise supported OS minimums

The latest `image_picker` currently advertises Android API 24+.

The Android app currently inherits:

```text
flutter.minSdkVersion
```

Before choosing the exact package version:

1. resolve the actual current Flutter Android min SDK;
2. resolve the current iOS deployment target;
3. select the newest compatible stable picker version.

Do **not** raise Android/iOS minimum support merely to take the newest package in 08A2.

If a platform-floor increase is truly unavoidable, stop/report rather than silently changing it.

---

# 6. Gallery only

08A2 supports:

```text
choose existing photo from device gallery/library
```

Do not implement:

```text
take photo with camera
```

Therefore do not add camera or microphone permission text.

On iOS add only the photo-library usage description required by the selected picker version.

Use clear privacy copy equivalent to:

```text
PLANETS uses the photo you choose to set your profile picture.
```

On Android do not add broad media/storage permissions unless the selected official picker version explicitly requires them.

Prefer the system picker behavior.

---

# 7. Source-image selection

Use one image only.

Allow ordinary device image formats accepted by the picker.

The source image does not need to be WebP.

The client converts the final result to WebP before Storage upload.

Use reasonable picker-side max dimensions if supported to bound memory use, while retaining enough source resolution for a 512×512 crop.

Suggested:

```text
maxWidth / maxHeight around 2048
```

This is a memory optimization, not part of the durable photo contract.

Do not reject a normal gallery photo merely because its original file is >250 KiB.

The 250 KiB limit applies to the **processed upload**, not the source photo.

---

# 8. Picker cancellation

User canceling the system picker is normal.

Behavior:

```text
return to current profile/edit screen
no error
no upload
no state mutation
```

Do not display failure UI for cancellation.

Process-death recovery of an in-progress picker/crop is not required in this minimum slice; native recovery can be reviewed in Plan 12 if necessary.

---

# 9. Crop UI

After a selection, present a dedicated square crop UI.

Requirements:

```text
aspect ratio fixed 1:1
user can pan/zoom
preview is large enough to position a face
Cancel
Use photo
```

Do not provide:

```text
free aspect ratio
rotation editor
filters
stickers
beautification
```

The crop is rectangular/square; the UI may display a circular avatar overlay for context, but stored pixels remain square.

---

# 10. Crop output

Cropping produces in-memory image bytes only.

Do not save the cropped intermediate into gallery/photos.

Do not persist it as an app document.

No original/intermediate photo should be retained by PLANETS after the flow completes/cancels.

Temporary plugin/runtime files may exist according to platform behavior; do not deliberately copy them into durable app storage.

---

# 11. Image processing service

Create a testable processing abstraction equivalent to:

```text
ProfilePhotoProcessor
```

Input:

```text
cropped image bytes
```

Output:

```text
processed WebP bytes
width
height
byteLength
```

Processing should run off the UI thread where practical, e.g. an isolate/`compute` or the current package's threaded command support.

Do not block animation/UI for large source decoding.

---

# 12. Orientation and metadata

Decode the cropped image safely.

Normalize/bake orientation before final encoding if needed.

The final encoded file must not preserve:

```text
EXIF
GPS
camera metadata
original filename metadata
```

Re-encoding the processed image should produce fresh WebP bytes rather than forwarding source metadata.

---

# 13. Exact output dimensions

Final upload must decode to exactly:

```text
512×512 pixels
```

Resize the square crop to exactly 512×512.

Use a quality interpolation appropriate for an avatar.

Do not rely only on a plugin `maxWidth` argument as proof of dimensions.

Add an automated test that decodes the final bytes and asserts:

```text
width == 512
height == 512
```

---

# 14. WebP encoding

Encode final bytes as:

```text
lossy WebP
```

Content type:

```text
image/webp
```

Do not upload JPEG/PNG while naming it `.webp`.

Tests should decode/identify the resulting WebP bytes rather than checking extension alone.

---

# 15. Compression target

The target is:

```text
~100 KB
```

not an exact file-size requirement.

Use deterministic bounded quality reduction.

Example strategy:

```text
start around quality 82

if >100 KiB:
  retry at progressively lower quality

reasonable floor:
  around quality 40–50
```

Codex may implement a bounded descending sequence or binary-search-like approach.

Goals, in order:

1. preserve reasonable avatar quality;
2. aim for <=100 KiB where practical;
3. always remain <=250 KiB before upload.

Do not repeatedly re-encode an already-compressed WebP as input to the next pass if the library can re-encode from the same resized pixel image.

---

# 16. Hard client limit

Before any upload:

```text
processedBytes.length <= 256000
```

must hold.

If the deterministic compression floor still produces >250 KiB:

```text
do not upload
show safe processing failure
allow retry with another crop/photo
```

Do not rely only on the bucket to reject it.

The bucket remains server-authoritative defense in depth.

---

# 17. Typical-size test

Add a representative synthetic/photo-like test fixture and prove the selected processing configuration normally achieves approximately:

```text
<=100 KiB
```

Do not make `100 KiB` a correctness assertion for every possible image.

Correctness is:

```text
valid WebP
512×512
<=250 KiB
```

---

# 18. Photo domain model

Add a dedicated audience enum:

```text
ProfilePhotoAudience
  public
  interactions
```

Do not reuse the existing:

```text
ProfileAudience
```

because that enum means:

```text
public / private
```

for different profile fields.

Model canonical owner metadata equivalent to:

```text
OwnProfilePhoto {
  profileId
  objectPath
  audience
  createdAt
  updatedAt
}
```

Strictly parse A1 RPC output.

---

# 19. Owner photo state

State should distinguish:

```text
loading
ready without photo
ready with photo
picking/cropping
processing
uploading
updating audience
removing
safe failure
```

Exact enum/state structure is Codex's choice.

State with a current photo should contain:

```text
canonical metadata
owner-renderable image bytes
```

or an equivalent ephemeral owner rendering reference.

Never persist signed URLs.

---

# 20. Owner rendering

For 08A2 the only viewer is the owner.

Prefer authenticated Storage:

```text
download(objectPath)
```

to obtain the current photo bytes because:

```text
max object size = 250 KiB
```

is already tightly bounded.

Render with:

```text
Image.memory / MemoryImage
```

or equivalent.

Do not create a non-owner signed-URL backend path in A2.

Do not persist downloaded bytes to durable app storage.

In-memory caching for the current session is fine.

---

# 21. Profile-photo gateway

Implement mobile operations equivalent to:

```text
loadOwnPhoto(expectedProfileId)
downloadOwnPhoto(objectPath)

uploadNewPhoto(
  objectPath,
  webpBytes
)

commitOwnPhoto(
  expectedProfileId,
  objectPath,
  audience
)

setAudience(
  expectedProfileId,
  audience
)

clearOwnPhoto(expectedProfileId)

deleteOwnObject(objectPath)
```

RPC calls must use exact A1 names/params.

Storage calls use:

```text
profile-photos
```

and:

```text
contentType = image/webp
upsert = false
```

No direct reads/writes of:

```text
profile_photos
storage.objects
```

from Flutter.

---

# 22. Object path generation

For every upload generate a fresh version UUID:

```text
<authenticated-profile-id>/<uuid-v4>.webp
```

Example:

```text
f47a.../cd17....webp
```

Never derive version from:

```text
timestamp only
source filename
display name
email
```

Never reuse the current canonical path for replacement.

---

# 23. Upload/commit sequence

New or replacement flow:

```text
1. process image
2. generate fresh object path
3. Storage upload with upsert=false
4. call set_own_profile_photo(...)
5. receive:
   current_object_path
   previous_object_path
   audience
   updated_at
6. update owner UI/state to new canonical photo
7. best-effort delete previous_object_path if present
```

The audience passed to commit is:

```text
existing canonical audience
```

for replacement, or:

```text
interactions
```

for first photo.

Changing a photo must not silently reset `public` back to `interactions`.

---

# 24. Commit failure cleanup

If:

```text
Storage upload succeeds
DB canonical commit fails
```

then:

```text
attempt best-effort Storage delete of the newly uploaded path
leave previous canonical photo/state unchanged
show safe retryable failure
```

Never display the uncommitted photo as canonical success.

Do not leak raw RPC/Storage diagnostics.

---

# 25. Old-object cleanup failure

If:

```text
canonical commit succeeds
old Storage object delete fails
```

then:

```text
new photo remains successful/canonical
UI shows the new photo
do not roll back
```

The old object is owner-private orphan cleanup debt documented by A1.

If current safe telemetry/error-reporting conventions allow, capture a scrubbed operational failure.

Do not expose old object path/token in UI/logging.

---

# 26. Same-path defense

A1 can return:

```text
previous_object_path = null
```

when the same path is committed.

A2 should nevertheless always generate a fresh path for actual replacements.

Do not deliberately recommit/reupload to the same object path.

---

# 27. Audience management

When a photo exists, expose exactly:

```text
Public

Only people I interact with
```

Wire values:

```text
public
interactions
```

Changing audience:

```text
calls set_own_profile_photo_audience
updates canonical photo state
does not re-upload bytes
```

No non-owner access changes are visible until 08A3 implements delivery.

This is still useful because the user's selected future audience is stored now.

---

# 28. No-photo audience UI

When no canonical photo exists:

- do not show a meaningless enabled audience selector;
- explain/set the default implicitly as:
  ```text
  Only people I interact with
  ```
  for first upload.

The crop/upload confirmation does not need another privacy screen.

After upload, show the audience control.

---

# 29. Remove-photo flow

When a photo exists:

```text
Remove photo
```

requires a simple confirmation.

Canonical sequence:

```text
1. call clear_own_profile_photo
2. receive prior object path
3. clear canonical photo from UI/state
4. best-effort Storage delete returned path
```

If clear RPC fails:

```text
keep existing UI/photo
show safe failure
```

If Storage delete fails after clear:

```text
photo remains removed from UI/canonical state
do not roll back
```

---

# 30. Independent save semantics

This is important.

Photo actions:

```text
upload
replace
audience change
remove
```

save immediately and independently.

They must not call:

```text
update_own_profile
```

and must not require the profile form Save button.

Likewise ordinary profile Save must not rewrite photo metadata.

---

# 31. Preserve unsaved profile edits

The current edit screen keeps unsaved:

```text
display name
bio
skills
field visibility
```

in local widget state.

Opening picker/crop, uploading a photo, changing photo audience, or removing a photo must **not reset those unsaved edits**.

Do not reload/re-key/reconstruct the entire profile edit form after a photo mutation in a way that discards local form state.

Use the independent photo provider/section.

Add a widget test proving this explicitly.

---

# 32. Profile screen presentation

Add the owner's avatar near the current profile identity.

If photo exists and bytes are available:

```text
circular avatar rendering
```

If no photo:

```text
neutral person/avatar placeholder
```

A generic person icon is sufficient.

Profile image is not mandatory for profile completeness.

---

# 33. Profile edit presentation

At/near the top of the profile edit screen add a photo section.

When absent:

```text
avatar placeholder

[ Add photo ]
```

When present:

```text
current avatar

[ Change photo ]
[ Remove photo ]

Photo visibility
○ Public
● Only people I interact with
```

Exact Material components may follow current design tokens.

Do not force the user into this section during first profile setup.

---

# 34. Crop interaction

After Add/Change:

```text
system gallery picker
→ square crop screen/sheet
```

Crop UI should contain:

```text
Cancel
Use photo
```

After `Use photo`:

```text
processing/upload progress
```

Prevent accidental duplicate submissions.

Do not require the user to press the ordinary profile Save action afterward.

---

# 35. Loading/progress

While processing/uploading:

- disable duplicate photo actions;
- keep ordinary profile content visible where practical;
- show bounded progress indicator/activity;
- do not pretend byte-level progress unless the current Storage SDK genuinely provides it.

Simple copy such as:

```text
Preparing photo…
Uploading photo…
```

is sufficient.

---

# 36. Safe errors

Differentiate user-understandable categories where useful:

```text
Unable to read this photo.
Unable to prepare this photo.
The processed photo is too large.
Unable to upload the photo.
Unable to save the profile photo.
Unable to remove the profile photo.
```

Do not show:

```text
SQLSTATE
bucket name
object path
Supabase exception
storage policy details
```

Cancellation is not an error.

---

# 37. Identity safety

Mirror existing controller protections.

Every photo action is bound to the expected current profile ID.

On:

```text
logout
account switch
re-login
```

invalidate:

```text
pending load
processing result
upload completion
commit completion
audience completion
remove completion
```

A late result from user A must never update user B's photo UI.

If an uploaded-but-uncommitted object was created before identity invalidation, attempt safe best-effort cleanup when possible.

Do not issue a commit under a different identity.

---

# 38. Photo load behavior

On authenticated ready profile display/edit:

```text
load owner photo metadata
```

If absent:

```text
ready/no photo
```

If present:

```text
download owner bytes
render avatar
```

Do not make ordinary profile text/skills unusable solely because photo loading fails.

Photo load failure should degrade to placeholder + photo retry/action, not turn the whole Profile screen into a fatal error.

---

# 39. Refresh after mutation

Do not blindly reload the whole profile.

Photo controller should update/reload only its own canonical state.

After commit/audience/clear, it may use validated RPC return values and/or reload `get_own_profile_photo` if needed.

Avoid redundant Storage downloads.

---

# 40. No non-owner rendering

Do not add photos to:

```text
public profile
Project cards
Tavolo cards
Messages join requests
participants
chat
Resource listings
Resource requests
```

in A2.

08A3/A4 own those integrations.

---

# 41. No trust reminder yet

Do not add the:

```text
Adding a photo can help others trust your request
```

join/create prompt yet.

That is 08A4.

A2 only gives the user a working place to add/manage the photo.

---

# 42. No web photo management

Do not add upload/crop/photo controls to:

```text
apps/web
```

in A2.

The web app must continue to compile against the unchanged existing profile editor contract.

---

# 43. Picker permission boundary

iOS:

- add only the photo-library purpose string required by the selected picker;
- no camera purpose string;
- no microphone purpose string.

Android:

- avoid broad legacy storage/media permission if the current official system picker path does not require it;
- do not add camera permission.

Document any platform manifest change.

---

# 44. Package compatibility tests/builds

Because new mobile plugins/dependencies are introduced:

Run at least:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

If macOS/iOS tooling is available, run the repository-supported iOS compile/static validation.

If not available, record iOS native build verification for Plan 12 rather than claiming it ran.

Do not modify deployment targets casually.

---

# 45. Processor unit tests

Use generated in-memory images, not personal photos.

Cover:

- landscape input;
- portrait input;
- square input;
- orientation handling where practical;
- exact 512×512 final dimensions;
- WebP encoding is decodable;
- final bytes <=250 KiB;
- representative photo-like fixture aims <=100 KiB;
- metadata is not deliberately carried through;
- corrupt/unsupported input fails safely;
- compression algorithm has a finite number of attempts.

---

# 46. Crop UI tests

Do not depend on the real platform picker in widget tests.

Abstract picker/crop inputs.

Cover:

```text
cancel crop
successful square crop
Use photo disabled while processing
safe crop failure
high text scale
small screen
```

Exact pixel-crop math can be delegated to the package; test PLANETS flow/state.

---

# 47. Gateway tests

Verify exact:

```text
get_own_profile_photo
set_own_profile_photo
set_own_profile_photo_audience
clear_own_profile_photo
```

RPC names/parameters.

Verify Storage:

```text
bucket profile-photos
fresh UUID path
contentType image/webp
upsert=false
owner download
owner delete
```

Strictly parse canonical RPC returns.

No direct table reads.

---

# 48. Controller tests

Cover:

- initial absent photo;
- initial existing photo + owner download;
- owner-download failure degrades safely;
- first upload defaults to interactions;
- replacement preserves existing public audience;
- upload failure;
- commit failure cleans new object best effort;
- successful replacement cleans prior object best effort;
- prior-object delete failure does not roll back canonical success;
- audience public → interactions;
- audience interactions → public;
- remove success;
- clear failure leaves photo;
- delete-after-clear failure leaves photo removed;
- duplicate action protection;
- account switch/stale response rejection.

---

# 49. Profile screen tests

Cover:

```text
no-photo placeholder
existing owner avatar
photo-load failure placeholder
ordinary profile data still visible
```

Long names/text scaling must not break avatar layout.

---

# 50. Profile edit tests

Cover:

```text
Add photo
Change photo
Remove photo
photo visibility choices
default interactions
processing/upload state
safe failures
```

Most importantly:

```text
edit bio/name/skills without saving
→ change/upload photo
→ original unsaved field edits remain intact
```

and:

```text
change photo audience
→ unsaved normal profile edits remain intact
```

---

# 51. Accessibility/localization

Localize equivalent copy:

```text
Profile photo
Add photo
Change photo
Remove photo
Remove profile photo?
Choose from photos
Adjust photo
Cancel
Use photo
Preparing photo…
Uploading photo…

Photo visibility
Public
Only people I interact with

Unable to read this photo.
Unable to prepare this photo.
This photo could not be made small enough.
Unable to upload the photo.
Unable to save the profile photo.
Unable to remove the profile photo.
```

Use semantic labels for:

```text
avatar
Add/Change
Remove
visibility choices
crop controls
progress
```

Do not rely on icons alone.

---

# 52. Documentation

Update mobile Profile docs:

```text
owner can add/change/remove profile photo
gallery-only in 08A2
square crop
512×512 WebP
~100 KB target / 250 KiB hard max
no original retained
photo actions save independently
audience public/interactions
non-owner visibility still deferred to 08A3
```

Document package/native permission additions.

---

# 53. Roadmap

Update:

```text
08A1 — PR #95
08A2 — Mobile Photo Upload + Profile Management
  this PR
08A3 — Photo Read Access + “Only people I interact with”
  next
08A4 — Join/Create Trust Reminder + Review Integration
```

Plan 08 remains in progress.

---

# 54. Validation

No DB migration is expected, but the entire open stack must remain healthy.

Run:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

npm run profile:verify:local
npm run profile:photo:verify:local

npm run check:web
npm run check:site
npm run check:mobile

flutter build apk --debug
git diff --check
```

Run all new focused mobile photo tests.

Attempt hosted Validation once.

If GitHub cannot allocate a runner because of the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database changes;
- public photo access;
- “interactions” authorization;
- signed URLs for other users;
- join-request creator photo display;
- trust reminders;
- camera capture;
- camera/microphone permission;
- web photo upload;
- Project/Tavolo images;
- Resource-listing images;
- chat attachments;
- group avatars;
- retained originals;
- multiple avatar sizes;
- server-side image transforms;
- face detection;
- image moderation;
- per-image history;
- generic media framework;
- orphan cleanup worker;
- account-deletion media worker;
- R2;
- production self-hosting.

---

# Acceptance criteria

- [ ] based on exact PR #95 head;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] compatible picker/crop/image dependencies added;
- [ ] supported OS floors are not silently increased;
- [ ] gallery-only picker;
- [ ] no camera permission;
- [ ] fixed 1:1 crop UX;
- [ ] processing off UI thread where practical;
- [ ] orientation normalized;
- [ ] metadata/EXIF not retained;
- [ ] exact 512×512 final image;
- [ ] genuine lossy WebP output;
- [ ] compression targets ~100 KiB;
- [ ] upload rejected client-side above 256000 bytes;
- [ ] finite compression strategy;
- [ ] dedicated ProfilePhotoAudience model;
- [ ] A1 RPCs strictly integrated;
- [ ] private bucket Storage API strictly integrated;
- [ ] fresh UUID object path per upload;
- [ ] `upsert=false`;
- [ ] first photo defaults to interactions;
- [ ] replacement preserves existing audience;
- [ ] upload → commit → old cleanup sequence;
- [ ] commit-failure new-object cleanup;
- [ ] old-delete failure does not roll back success;
- [ ] audience changes without reupload;
- [ ] clear → canonical removal → object cleanup;
- [ ] owner avatar renders from private authenticated bytes;
- [ ] no signed URL persisted;
- [ ] normal profile form/save contract unchanged;
- [ ] photo mutations preserve unsaved text/skills/visibility edits;
- [ ] account-switch/stale-response safety;
- [ ] no non-owner photo rendering;
- [ ] no trust reminder yet;
- [ ] no web photo management;
- [ ] localization/accessibility complete;
- [ ] processor tests green;
- [ ] gateway/controller/widget tests green;
- [ ] clean DB gates remain green;
- [ ] existing profile verifiers green;
- [ ] Web/Site/Mobile regressions green;
- [ ] debug APK green;
- [ ] hosted CI attempted once/reported accurately;
- [ ] no 08A3/08A4 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 08A2 branch/base/PR
3. Changed files
4. Added package versions
5. Android/iOS compatibility decision
6. Platform permission changes
7. Gallery picker behavior
8. Crop UX
9. Image processing architecture
10. Orientation/metadata handling
11. Exact dimensions verification
12. WebP encoding
13. Compression algorithm
14. Typical ~100 KiB result
15. 250 KiB hard client guard
16. Profile-photo models
17. Owner photo state/controller
18. A1 RPC gateway integration
19. Storage upload/download/delete integration
20. UUID object-path generation
21. First-upload audience default
22. Replacement audience preservation
23. Upload/commit sequence
24. Commit-failure cleanup
25. Old-object cleanup failure behavior
26. Audience update behavior
27. Remove-photo behavior
28. Independent-save boundary
29. Unsaved normal-profile-edit preservation
30. Profile owner avatar rendering
31. Profile edit photo UI
32. Account-switch/stale-response safety
33. No-non-owner-read boundary
34. No-trust-reminder boundary
35. Localization/accessibility
36. Processor tests
37. Crop/presentation tests
38. Gateway tests
39. Controller tests
40. Existing profile regression
41. `db:reset`
42. `db:lint`
43. `db:advisors`
44. full `db:test`
45. `db:types:check`
46. profile verifiers
47. Web validation
48. Site validation
49. Mobile validation
50. Debug APK
51. Hosted Validation executed/not-executed
52. 08A3 handoff
53. Warnings/blockers
54. Commit/PR reference

Do not merge any PR.
