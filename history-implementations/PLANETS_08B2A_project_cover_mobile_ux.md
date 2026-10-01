# PLANETS 08B2A — Proposal + Tavolo Cover Image Mobile UX

**Roadmap area:** PLANETS 08 — Storage and media hardening  
**Task type:** Flutter mobile cover-image selection, processing, management, and rendering for Proposal + Tavolo  
**Repository:** `lillo24/planets.community`  
**Required base at prompt creation:** PR #106 head `9ecbe4f63c171d6d264fbe6c8cc21d68540e1d91` (`codex/08b1-cover-media-domain`)  
**Preferred branch:** `codex/08b2a-project-cover-mobile-ux`  
**Do not merge the implementation PR.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08B2A_project_cover_mobile_ux.md
```

---

## 0. Objective

Implement the first user-facing cover-image experience for:

- one-time Proposals;
- recurring activities / Tavoli.

After 08B2A, a creator should be able to:

```text
Create/Edit Proposal or Tavolo
  → choose an image from the device
  → crop it to the cover format
  → preview it
  → Save / Publish
```

and later:

```text
Edit
  → replace cover
  → remove cover
```

Public and owner surfaces should render the canonical cover:

```text
Browse card
Detail
Own Proposal/Tavolo card
```

The cover remains optional.

This task should also establish a **reusable cover-media Flutter pipeline** that 08B2B can later reuse for Scambio-Dona rather than building a second image processor/downloader.

Do not implement Scambio-Dona cover UI in this slice.

---

## 1. Base and stack safety

Use the current 08B1 head as the exact dependency base:

```text
PR #106
branch: codex/08b1-cover-media-domain
head:   9ecbe4f63c171d6d264fbe6c8cc21d68540e1d91
```

PR #106 is open, mergeable, and intentionally stacked on the open 08A media/profile-photo chain.

Before coding:

1. fetch remote;
2. verify PR #106 still exists at the expected head;
3. create a new branch/worktree from that exact commit unless the founder explicitly provides a newer equivalent base;
4. preserve the full 08A + 08B1 stack;
5. do not rebase onto `main` if that would drop the unmerged media foundation;
6. do not merge PR #106 or any dependency;
7. do not clean/reset unrelated founder or Codex worktrees;
8. open a stacked PR targeting `codex/08b1-cover-media-domain`;
9. leave it unmerged.

There are unrelated parallel branches for Italian localization/settings and delegate/co-organizer work. Do not pull those branches into this task merely to acquire copy or permissions.

---

## 2. Verified current repository state

08B1 already provides the canonical backend/storage layer.

### 2.1 Storage

Private bucket:

```text
cover-images
```

Current contract:

```text
MIME: image/webp
hard limit: 524288 bytes (512 KiB)
```

Object paths are immutable and parent-bound.

Project path shape is conceptually:

```text
<owner_profile_id>/projects/<project_id>/<version_uuid>.webp
```

The database stores object paths, not URLs.

### 2.2 Project cover RPCs

08B1 provides owner operations equivalent to:

```text
get_own_project_cover
set_own_project_cover
clear_own_project_cover
```

Inspect generated types/migration for the exact signatures.

The backend verifies:

- expected identity;
- Project ownership;
- parent lifecycle/editability;
- object ownership;
- exact parent-bound path;
- WebP MIME;
- canonical replacement.

Replacement returns the previous path for separate cleanup.

### 2.3 Read contracts already contain cover paths

08B1 extended the canonical Proposal/Tavolo contracts with nullable:

```text
cover_object_path
```

and strict Flutter parsing already retains it.

This includes public summaries/details and owner models.

Do not add per-card metadata RPCs merely to discover the cover path.

### 2.4 Public cover authorization

The bucket remains private, but the current canonical cover of a publicly viewable Project can be downloaded through Storage by anonymous/authenticated viewers.

Draft covers remain owner-only.

Replaced/cleared stale objects are no longer public even if physical cleanup has not happened yet.

### 2.5 Current profile-photo implementation

The existing profile-photo feature already demonstrates:

- `image_picker`;
- `crop_your_image`;
- isolate-based `package:image` processing;
- orientation normalization;
- explicit image metadata stripping;
- WebP quality fallback;
- immutable UUID paths;
- upload → canonical commit → best-effort old-object delete;
- cleanup of newly uploaded object when commit fails;
- identity/revision safety.

Reuse the proven low-level ideas.

Do **not** inherit profile-specific behavior such as:

- 1:1 crop;
- 512×512 output;
- ~100 KiB target;
- profile-photo audience;
- relationship authorization;
- trust-gate semantics.

---

## 3. Important new-parent constraint

A cover Storage path is bound to a real Project ID, and upload authorization verifies that the Project exists.

Therefore:

> Selecting a cover for a brand-new Proposal/Tavolo must NOT create a hidden draft immediately.

The existing editor behavior intentionally keeps a new form local until Save/Publish.

Preserve that.

For a new Proposal/Tavolo:

```text
pick image
→ crop/process locally
→ hold pending cover in editor memory
→ user presses Save/Publish
→ create canonical draft and obtain Project ID
→ upload + commit cover
→ continue requested lifecycle action
```

Do not:

```text
open editor → create draft
```

and do not:

```text
pick image → create draft
```

This also means cancelling/backing out before Save/Publish creates no Storage object and no orphan.

---

## 4. Product decisions

Treat these as settled for 08B2A.

### 4.1 One optional cover

Exactly the 08B1 capability:

```text
0 or 1 canonical cover
```

No gallery.

### 4.2 Gallery selection only

Use the existing device gallery/image picker pattern.

Do not add camera capture in this task.

### 4.3 Fixed landscape crop

The user should be able to choose the visible crop.

Use a fixed:

```text
16:9
```

landscape crop UI.

Do not silently center-crop the original with no user control.

### 4.4 Normalized output

Produce a normalized WebP suitable for cards and detail hero use.

Target direction:

```text
max target dimensions: about 1280 × 720
target encoded size: about 200–300 KiB
hard client limit: <= 512 KiB
MIME: image/webp
```

Do not retain the original file.

Do not preserve EXIF/GPS/text/ICC metadata.

Do not upscale a low-resolution source merely to manufacture 1280×720 pixels if the image library can cleanly preserve a smaller 16:9 result.

Exact quality fallback values are implementation detail, but processing must deterministically stay under the backend hard limit or fail with safe user-facing feedback.

### 4.5 Cover changes are editor state until Save/Publish

Do not commit the canonical cover immediately when the user taps Change/Remove.

Within Proposal/Tavolo editors, cover selection/removal behaves like form editing:

```text
current canonical cover
        ↓
local desired cover state
        ↓
Save / Publish
        ↓
canonical reconciliation
```

Therefore:

- selecting a replacement and navigating back without saving leaves the canonical cover unchanged;
- selecting Remove and navigating back without saving leaves the canonical cover unchanged;
- selecting several images before save creates no sequence of uploaded orphan versions.

### 4.6 Cover is not required

Do not block publish when no cover exists.

Profile-photo trust gates remain independent and unchanged.

---

## 5. Reusable cover-media Flutter boundary

Create a focused reusable cover-media feature/boundary rather than putting image plumbing separately into Proposal and Tavolo.

A reasonable repository-consistent shape could be:

```text
apps/mobile/lib/features/cover_media/
  domain/
  data/
  application/
  presentation/
```

or another feature-first equivalent supported by inspection.

It should own reusable cover concerns such as:

- bucket constants;
- processed cover model;
- image source picker;
- 16:9 crop view;
- WebP processor;
- immutable Project cover path generation;
- Storage upload/download/delete;
- Project cover get/set/clear RPC mapping;
- public cover byte loading/cache;
- owner cover byte loading;
- reusable cover preview/display widgets;
- safe failure mapping.

Do not move profile photos into this feature simply for symmetry.

A small shared low-level helper extraction from profile photos is acceptable when it eliminates true duplication without changing 08A behavior, but avoid a broad refactor of the already validated profile-photo stack.

The architecture should make 08B2B able to add Resource-listing cover commit methods/UI without duplicating the picker, cropper, processor, public image loader, or display widgets.

---

## 6. Cover path generation

Use the exact 08B1 path contract.

For Projects conceptually:

```text
<creator_profile_id>/projects/<project_id>/<uuid>.webp
```

Use a non-colliding UUID generator consistent with the profile-photo implementation.

Do not:

- reuse one path across replacements;
- use a title in the path;
- use a signed/public URL;
- use `upsert=true`.

Validate generated/received paths through the current 08B1 path parser where appropriate.

---

## 7. Picker + crop flow

The reusable interaction should be approximately:

```text
Add/Change cover
    ↓
pickFromGallery()
    ↓
16:9 crop screen
    ↓
process locally to WebP
    ↓
return pending processed image to editor
```

The crop screen should:

- use a fixed 16:9 crop rectangle;
- support pan/zoom via current crop package capabilities;
- have Cancel and Use image actions;
- show progress while cropping;
- fail safely;
- be keyboard/screen-reader navigable where supported;
- use localized copy;
- not expose raw internal errors.

Reuse the current profile crop UX patterns where useful, but the cover component should have cover-specific semantics/copy and aspect ratio.

---

## 8. Processing

Processing should happen off the main isolate in line with the current profile-photo pipeline.

Required properties:

1. decode safely;
2. bake orientation;
3. maintain the selected 16:9 crop;
4. resize to the selected cover maximum;
5. strip metadata:
   - EXIF, including GPS;
   - text metadata;
   - ICC/extra metadata where supported;
6. encode single-frame lossy WebP;
7. try a deterministic descending quality sequence;
8. target the selected ~200–300 KiB range where feasible;
9. never upload output above 512 KiB;
10. return a typed processed-cover result;
11. fail with a specific too-large/prepare error rather than crashing.

Do not log image bytes.

Do not write temporary user images to a long-lived local cache unless an existing library requires a transient temporary file and it is safely cleaned.

---

## 9. Public cover downloading and caching

Public list/detail text must not wait for every image download before rendering.

Implement a reusable byte loader keyed by the immutable:

```text
cover_object_path
```

Public behavior:

```text
cover path null
  → render fallback visual

cover path present
  → render layout immediately with loading placeholder
  → asynchronously download from cover-images
  → render Image.memory (or repository-consistent equivalent)

download failure
  → keep safe fallback visual
  → do not fail the entire card/list/detail
```

Because canonical paths are immutable version identifiers, path-keyed caching is appropriate for public covers.

Do not add an RPC per card.

Do not generate public/signed URLs and store them in widget/domain state as a replacement for the existing path contract.

A detail surface may expose a retry affordance if useful, but a failed cover must never make Project text inaccessible.

---

## 10. Owner/draft cover loading

Existing owned drafts may already have a canonical cover.

When editing an existing Proposal/Tavolo:

```text
OwnProposal/OwnRecurringActivity.coverObjectPath
        ↓
owner-authorized Storage download
        ↓
preview current cover
```

Private owner cover bytes must remain identity-safe.

Do not allow account switching to flash the previous user's draft cover.

Use the same revision/identity principles already established in profile-photo and owner-domain controllers:

- scope owner state to expected profile ID;
- reject late async results;
- clear pending bytes on identity change;
- do not preserve a previous identity's private draft preview.

Public immutable image caches do not need to become auth-bound merely because the user signs in.

---

## 11. Editor UI

Add a clear Cover image section near the top of both:

```text
Proposal editor
Tavolo editor
```

Conceptually:

```text
Cover image
┌──────────────────────────────┐
│         16:9 preview         │
└──────────────────────────────┘

[ Add image ]
```

or when one exists:

```text
[ Change image ]   [ Remove ]
```

Requirements:

- display existing canonical cover;
- pending replacement immediately replaces the preview locally;
- pending removal shows the no-cover state locally;
- show busy state while picking/cropping/processing;
- do not upload until Save/Publish;
- disable conflicting image actions during processing;
- image errors remain local to the Cover section;
- ordinary text fields remain usable after a recoverable cover-read failure;
- all copy uses the app localization system.

The no-cover preview should use a simple theme-driven PLANETS fallback/placeholder rather than a blank grey rectangle or remote stock image.

Do not add final branding/category artwork in this task.

---

## 12. Persistence orchestration

This is the most important behavior of the task.

The content parent remains authoritative and the cover is a separate canonical object/reference.

### 12.1 New Save draft

When the new form has a pending cover:

```text
validate draft
→ create Proposal/Tavolo draft
→ obtain parent ID
→ generate parent-bound cover path
→ upload processed WebP
→ set canonical Project cover
→ canonical reread
```

If cover upload/commit fails after draft creation:

- do not create another draft on retry;
- retain the same draft identity in editor state;
- remain in the editor;
- explain safely that the draft exists but the cover was not saved;
- allow retry/change/remove;
- do not navigate to My Projects as if everything succeeded.

If upload succeeded but canonical commit failed:

- best-effort delete the newly uploaded object;
- canonical cover remains unchanged/null.

### 12.2 New Publish

With a pending cover, order the flow so a cover failure does **not** silently publish an image-less Project contrary to the user's current Save/Publish intent.

Preferred canonical sequence:

```text
validate publish input
→ profile-photo trust preflight as already implemented
→ create/update draft content
→ reconcile pending cover while parent is still editable
→ publish
→ canonical reread
```

If cover reconciliation fails:

- leave the Project as a saved draft;
- retain/reload the canonical draft identity;
- do not publish;
- explain that the draft was saved but the cover could not be saved.

If cover reconciliation succeeds but publish then fails:

- keep the draft and successfully committed cover;
- do not delete the valid canonical cover merely because publication failed;
- present the existing safe publication failure/trust handling.

### 12.3 Existing draft

On Save/Publish:

```text
update content
→ reconcile cover desired state
→ publish if requested
→ canonical reread
```

### 12.4 Existing published editable Project

On Save changes:

```text
update content
→ reconcile cover desired state
→ canonical reread
```

If content succeeds but cover reconciliation fails:

- do not pretend the whole operation rolled back;
- canonical existing cover remains unchanged;
- tell the user that content changes were saved but the cover could not be updated;
- keep them in an accurate editor state after canonical reread.

### 12.5 Replacement

Canonical replacement:

```text
upload new immutable object
→ set_own_project_cover
→ receive previous path
→ canonical state now points to new path
→ best-effort delete old path
```

Old-object deletion failure must not roll back the new canonical cover.

### 12.6 Removal

When the desired editor state is no cover and a canonical cover currently exists:

```text
clear_own_project_cover
→ receive old path
→ canonical state has no cover
→ best-effort delete old object
```

Deletion failure after successful clear is cleanup debt, not a failed canonical remove.

### 12.7 Unchanged cover

Do not re-upload/re-commit when the user did not change the cover.

---

## 13. Proposal rendering

### Public Proposal card

Update the current `ProposalCard`.

Show a consistent 16:9 cover region at the top of the card.

If `proposal.coverObjectPath` exists:

- asynchronously show the current cover.

If null/loading/failure:

- show the reusable PLANETS cover fallback appropriate to that state;
- do not leave the card blank;
- do not fail the card.

Keep all existing:

- requested styling/badge;
- title;
- status;
- summary;
- time;
- public location;
- skill requirements;
- tap behavior.

The cover must not interfere with the requested-card border/tap target.

### Public Proposal detail

Render the cover as a 16:9 hero/lead visual near the top before the main detail content.

Preserve:

- creator/profile-photo context;
- participation;
- resource needs;
- exact-location privacy;
- lifecycle/status behavior.

### Own Proposals

Show the canonical cover/fallback on owner cards as well.

Draft covers use owner-authorized download, not public assumptions.

Preserve all existing management actions.

---

## 14. Tavolo rendering

Apply the same cover language to:

### Public Tavolo card

Use the same reusable cover widget/ratio/fallback rather than creating an unrelated Tavolo image component.

Preserve:

- requested styling;
- recurrence/schedule information;
- lifecycle indicators;
- tap behavior.

### Public Tavolo detail

Show the cover as the lead 16:9 visual.

Preserve all existing schedule, occurrences, needs, participation, organizer/profile-photo, and meeting-location behavior.

### Own Tavoli

Show canonical owner cover/fallback on existing cards.

Preserve publish/pause/resume/end/edit/resource controls.

---

## 15. Fallback visual

No cover is a normal state.

Build a light, theme-driven reusable fallback that:

- fits 16:9;
- works in light/dark themes;
- clearly reads as an intentional visual placeholder;
- does not imply that an upload failed;
- does not use a network image;
- does not embed demo stock photography;
- does not need separate category art in this slice.

Loading and download-error state may reuse the same base visual with an appropriate progress/error affordance.

Avoid making image failure visually dominate the card.

---

## 16. Accessibility

At minimum:

- Add/Change/Remove cover controls have semantic labels;
- crop controls are labeled;
- progress/error messages use appropriate live-region semantics where relevant;
- the cover does not duplicate the entire card into an unusable screen-reader label;
- if no authored alt text exists, use restrained semantics such as localized “Cover image for {title}” rather than inventing a description of the actual photo;
- fallback state is understandable without color alone;
- 16:9 layout handles text scaling around it without clipping controls.

Do not add an alt-text authoring field in this task.

---

## 17. Localization

All new user-facing copy goes through the current localization system.

Cover at minimum:

```text
Cover image
Add image
Change image
Remove image
Adjust cover
Use image
Cancel
Preparing image…
Cover could not be prepared
Cover is too large
Cover could not be uploaded
Cover could not be saved
Cover could not be loaded
Draft saved, but the cover could not be saved
Changes saved, but the cover could not be updated
Retry
```

Use better concise copy if consistent with existing app style.

Do not hard-code production strings.

Do not merge unrelated localization/settings branches solely for this task. Update the localization catalogs that exist on the required base and document any later branch reconciliation need.

---

## 18. Error mapping

Introduce cover-specific typed failures.

Distinguish at least:

- source/gallery read;
- crop;
- prepare/encode;
- too large;
- upload;
- canonical commit;
- canonical clear;
- owner/private read;
- public download.

Do not leak raw Supabase/Postgres/Storage messages to users.

Parent-domain failures remain Proposal/Tavolo failures.

Where a backend cover mutation returns a parent lifecycle/authorization rejection, map it into a safe cover operation failure and canonical refresh rather than claiming the parent is still editable.

---

## 19. State and invalidation

After a successful cover canonical change, refresh/invalidate only the relevant state:

```text
own Proposal/Tavolo collection
public Proposal/Tavolo discovery
public detail for the changed Project
editor canonical owner record
```

Requested-item sections use the same canonical Proposal/Tavolo summaries, so they must reflect the new path after the relevant refresh.

Do not invalidate unrelated Resource, chat, notifications, or profile-photo state.

Because paths are immutable, replacing a cover naturally changes the image-cache key.

Old cached public bytes may remain in memory until eviction; they must not be reachable through current canonical parent state.

---

## 20. Scambio-Dona remains out of scope

08B1 already contains the Resource-listing cover backend.

Do not add Resource-listing image UI yet.

08B2B will reuse this task's:

- picker;
- cropper;
- WebP processor;
- public cover loader/cache;
- fallback/display widgets;
- Storage upload/delete primitives.

Do not duplicate the same pipeline pre-emptively inside `resource_listings`.

---

## 21. Shared Drive / chat attachments remain out of scope

Do not implement:

- Project shared Drive/workspace URL;
- Google OAuth;
- Drive API;
- chat attachments;
- photo messages;
- PDFs/files in chat.

That is a separate product slice.

---

## 22. Demo polish remains out of scope

Do not replace the demo-world titles/people/images yet.

A later DEMO task will add realistic content and licensed cover photography after both 08B2A and 08B2B can render canonical covers.

Do not hotlink internet images into production/demo models in this task.

---

## 23. No database migration expected

08B1 already owns the backend contract.

08B2A should normally require **no new database migration**.

If the implemented 08B1 contract is genuinely insufficient for this mobile UX:

1. stop;
2. report the exact blocker;
3. explain why a client implementation cannot safely satisfy it.

Do not casually broaden the storage/RPC schema from the mobile task.

Small generated-type/parser changes should not be necessary unless the dependency changed.

---

## 24. Tests — cover processing

Add deterministic unit coverage for:

- valid landscape crop processing;
- portrait source after crop;
- orientation handling;
- expected 16:9 output;
- maximum dimensions;
- metadata stripping;
- WebP encoding;
- target-size quality fallback;
- hard 512 KiB rejection;
- invalid/corrupt bytes;
- single-frame output where inspectable.

Do not rely only on golden screenshots.

---

## 25. Tests — picker/crop

Cover:

- gallery cancel;
- gallery source failure;
- crop cancel;
- crop success;
- crop failure;
- fixed 16:9 configuration;
- actions disabled appropriately while cropping;
- successful crop returns bytes to editor without uploading.

Use test injection patterns similar to the current profile crop view rather than requiring native gallery UI in widget tests.

---

## 26. Tests — data/gateway

Cover:

- correct `cover-images` bucket;
- `image/webp`;
- `upsert = false`;
- Project path generation;
- download by exact path;
- `get_own_project_cover`;
- `set_own_project_cover`;
- `clear_own_project_cover`;
- commit response validation;
- previous-path parsing;
- safe object delete;
- malformed/mismatched path rejection.

Do not make direct table calls.

---

## 27. Tests — editor orchestration

This is required.

### New Proposal/Tavolo

Test:

- opening editor creates no draft;
- selecting/cropping image creates no draft and uploads nothing;
- Save draft creates parent first, then uploads/commits cover;
- final canonical owner record contains returned cover path;
- publish with pending cover performs cover commit before publish;
- cover upload failure after parent creation leaves the same saved draft;
- retry does not create a second draft;
- cover commit failure cleans new object best-effort and leaves no canonical cover;
- publish is not called when pending-cover reconciliation failed;
- publish failure after successful cover commit leaves draft + cover intact.

### Existing

Test:

- unchanged cover performs no media mutation;
- replacement uploads new object and commits once;
- old-path delete is best effort;
- removal clears canonical cover and then deletes old object best effort;
- selecting replacement then navigating/cancelling without Save leaves canonical cover unchanged;
- selecting Remove then cancelling leaves canonical cover unchanged;
- content-save success + cover failure reports partial success accurately and canonical cover remains prior version;
- non-editable/frozen Proposal rejects cover persistence safely;
- ended Tavolo rejects cover persistence safely;
- identity switch clears pending private image state and rejects late results.

---

## 28. Widget tests — rendering

Add focused coverage for:

### Proposal

- public card with successful cover;
- card no-cover fallback;
- card loading fallback;
- card image-download failure fallback;
- requested Proposal card still renders requested treatment;
- public detail cover;
- owner card cover;
- editor existing cover;
- editor Add/Change/Remove;
- pending replacement preview;
- pending removal preview;
- safe cover errors;
- cover does not block text content.

### Tavolo

Equivalent functional coverage for:

- public card;
- requested card;
- detail;
- owner card;
- editor.

Prefer testing shared cover widgets once plus thin Proposal/Tavolo integration tests rather than duplicating every low-level state in both domains.

---

## 29. Existing behavior regression coverage

Preserve current tests/behavior for:

- signed-out Proposal/Tavolo browse;
- pagination;
- requested-item separation;
- create/edit/save/publish;
- Proposal freeze rules;
- Tavolo pause/resume/end;
- skill/resource requirements;
- participation;
- exact meeting privacy;
- organizer profile photo;
- profile-photo trust gate;
- account switching.

A cover is presentation content and must not alter these semantics.

---

## 30. Native QA checklist

Comprehensive native QA remains Plan 12; do not claim it passed.

Add/update the Plan-12 checklist for:

- Android/iOS gallery permission/selection;
- portrait and landscape source photos;
- zoom/pan/crop interaction;
- very large source images;
- processing responsiveness;
- upload on slow/offline connections;
- app background/resume during image operations;
- new draft + cover failure recovery;
- replace/remove cover;
- light/dark theme;
- narrow devices/tablets;
- card scrolling performance with multiple covers;
- anonymous public cover reads;
- signed-in owner draft cover reads;
- account switch with owner editor open;
- TalkBack/VoiceOver crop/actions.

---

## 31. Documentation

Update relevant docs, likely:

```text
apps/mobile/... cover-media README or source map
apps/mobile/lib/features/proposals/README.md
apps/mobile/lib/features/recurring_activities/README.md
docs/architecture/system-design.md
docs/implementation/roadmap.md
```

Document:

- 08B2A mobile scope;
- 16:9 crop;
- normalized WebP processing boundary;
- local-pending-before-parent-ID behavior;
- Save/Publish cover orchestration;
- public path-keyed image loading;
- owner identity safety;
- 08B2B reuse boundary;
- no Scambio UI yet;
- no Drive/chat attachments.

Do not rewrite 08B1 storage rules.

---

## 32. Roadmap status

Record PR #106 accurately as the 08B1 foundation dependency.

While the new PR is open:

```text
08B   In progress
08B1  In progress/open dependency PR #106
08B2A In progress
08B2B Not started
```

Do not mark 08B complete.

Do not mark demo polish complete.

If repository conventions use “Implemented” for completed-but-unmerged stacked slices, follow the existing wording precisely and include the PR number/head rather than inventing a new status convention.

---

## 33. Validation

Run the focused Flutter tests plus repository-standard mobile validation.

At minimum:

```text
npm run check:mobile
flutter build apk --debug
git diff --check
```

Run changed-scope formatting checks.

Because this task should not change DB/web contracts, full database/web/site checks are not automatically required. If shared code/docs/generated files make them relevant, run the affected checks and report them.

If a database migration is unexpectedly required, this task has hit a material blocker and should have stopped before implementation unless the founder explicitly approved the broadened scope.

Hosted CI may still be unable to start because the current GitHub account has an Actions payment/spending-limit restriction. Do not repeatedly rerun an unchanged infrastructure failure. Record the exact result of the appropriate final-head attempt if one is made.

Do not claim physical-device QA.

---

## 34. Acceptance criteria

08B2A is complete only if all are true:

- [ ] Proposal creator can select a cover from gallery.
- [ ] Tavolo creator can select a cover from gallery.
- [ ] User gets an interactive fixed 16:9 crop step.
- [ ] Output is normalized metadata-free WebP within the 512 KiB backend limit.
- [ ] Cover pipeline is reusable by later Scambio-Dona UI.
- [ ] New-form image selection creates no draft and uploads nothing before Save/Publish.
- [ ] New Save creates the parent before uploading the parent-bound cover.
- [ ] New Publish reconciles a pending cover before publication.
- [ ] Pending-cover failure prevents new publication and retains the same draft for retry.
- [ ] Existing creator can replace cover.
- [ ] Existing creator can remove cover.
- [ ] Cover edits are not committed merely by selecting/removing before Save.
- [ ] Failed canonical commit best-effort deletes the new orphan upload.
- [ ] Successful replacement/clear best-effort cleans the previous object.
- [ ] Proposal public cards render cover/fallback.
- [ ] Proposal detail renders cover/fallback.
- [ ] Proposal owner cards render cover/fallback.
- [ ] Tavolo public cards render cover/fallback.
- [ ] Tavolo detail renders cover/fallback.
- [ ] Tavolo owner cards render cover/fallback.
- [ ] Requested Proposal/Tavolo cards preserve their requested visual treatment.
- [ ] Image download failure never breaks the parent card/detail.
- [ ] Anonymous public cover rendering works through the private bucket's canonical public policy.
- [ ] Draft cover preview uses owner authorization and remains identity-safe.
- [ ] Account switching cannot flash another user's private cover/pending image.
- [ ] No cover remains a valid publishable state.
- [ ] Profile-photo trust gates are unchanged.
- [ ] No Resource/Scambio cover UI is introduced.
- [ ] No Drive integration or chat attachments are introduced.
- [ ] No new DB migration is introduced unless a blocker was explicitly escalated.
- [ ] Automated Flutter validation and Android debug build pass.
- [ ] Docs/roadmap are updated.
- [ ] Exact prompt is archived.
- [ ] A focused stacked PR is opened and remains unmerged.

---

## 35. Completion report

Return a concise structured report containing:

1. branch;
2. exact base commit;
3. final head commit;
4. PR number/link and target branch;
5. cover-media Flutter architecture introduced;
6. selected output dimensions/size target/quality policy;
7. how profile-photo code was reused or intentionally kept separate;
8. new-parent pending-cover Save/Publish ordering;
9. replacement/remove cleanup behavior;
10. Proposal surfaces updated;
11. Tavolo surfaces updated;
12. tests and exact validation results;
13. any known inherited warnings/CI infrastructure issue;
14. any UX concern deferred to Plan 12;
15. confirmation that:
    - no Scambio cover UI was implemented,
    - no Drive/chat attachment work was implemented,
    - no cover requirement was added,
    - no profile-photo semantics changed,
    - the PR remains unmerged.

If implementation uncovers a material mismatch in 08B1 that requires schema/RLS/RPC changes, stop and report the blocker rather than silently changing the backend boundary.
