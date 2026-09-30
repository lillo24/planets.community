# PLANETS 08B2B — Scambio-Dona Cover Image Mobile UX

**Roadmap area:** PLANETS 08 — Storage and media hardening  
**Task type:** Flutter mobile integration of the existing cover-media pipeline with Scambio-Dona Resource listings  
**Repository:** `lillo24/planets.community`  
**Required base at prompt creation:** PR #110 head `10b0cdb6630895ba5baa38c2013887f904322cb3` (`codex/08b2a-project-cover-mobile-ux`)  
**Preferred branch:** `codex/08b2b-resource-cover-mobile-ux`  
**Do not merge the implementation PR.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08B2B_resource_cover_mobile_ux.md
```

---

## 0. Objective

Complete the first cover-image UX across PLANETS by integrating the reusable 08B2A `cover_media` feature with **Scambio-Dona Resource listings**.

After 08B2B, a Resource-listing owner should be able to:

```text
Create/Edit listing
  → choose image from gallery
  → use the existing fixed 16:9 crop
  → preview locally
  → Save / Publish
```

and later:

```text
Edit published/draft listing
  → change cover
  → remove cover
```

Users browsing Scambio-Dona should see the canonical cover, or the existing themed fallback, on:

```text
public listing cards
public listing detail
owner / My listings cards
Project-resource matching results that reuse the public listing card
```

The cover remains optional.

Do not build a second image pipeline. 08B2B should extend and reuse the exact cover-media architecture introduced by 08B2A.

---

## 1. Base and stack safety

Use the current 08B2A head as the exact dependency base:

```text
PR #110
branch: codex/08b2a-project-cover-mobile-ux
head:   10b0cdb6630895ba5baa38c2013887f904322cb3
```

PR #110 is open, mergeable, and intentionally stacked on:

```text
PR #106 — 08B1 cover media domain foundation
PR #104 and earlier — 08A profile-photo stack
```

Before coding:

1. fetch remote;
2. verify PR #110 at the expected head;
3. create the new branch/worktree from that exact commit unless the founder explicitly supplies a newer equivalent base;
4. preserve the full stacked media/resource implementation;
5. do not rebase onto `main` if that drops the unmerged dependencies;
6. do not merge PR #110 or its dependencies;
7. do not clean/reset unrelated founder or Codex worktrees;
8. open a stacked PR targeting `codex/08b2a-project-cover-mobile-ux`;
9. leave it unmerged.

Unrelated delegate, moderation, localization/settings, and other concurrent work must not be pulled into this branch unless strictly required by the exact base.

---

## 2. Verified current repository state

### 2.1 08B1 already supports Resource cover media

The backend on the dependency stack already provides:

- private `cover-images` bucket;
- WebP-only objects;
- 512 KiB hard limit;
- immutable parent-bound paths;
- one optional canonical cover per Resource listing;
- owner get/set/clear cover RPCs;
- public download authorization only for the canonical cover of a public listing;
- owner download for owned draft/published listing covers;
- nullable `cover_object_path` in Resource public/owner models;
- `cover_object_path` in Project-resource matching contracts.

The exact owner operations are:

```text
get_own_resource_listing_cover
set_own_resource_listing_cover
clear_own_resource_listing_cover
```

Inspect the current migration/generated contract for exact parameter names.

Resource paths are conceptually:

```text
<owner_profile_id>/resources/<listing_id>/<version_uuid>.webp
```

Do not add a database migration unless a real backend mismatch is discovered.

### 2.2 08B2A already built reusable mobile media infrastructure

The current `cover_media` feature owns:

```text
gallery picker
fixed 16:9 crop
off-isolate WebP normalization
metadata stripping
1280×720 maximum without upscaling
280 KiB target
512 KiB hard limit
immutable path generation
private Storage byte download
public path-keyed byte loading/cache
owner identity-safe byte loading
themed fallback rendering
editor-local pending image state
upload → canonical commit → stale-object cleanup
```

Current processing policy:

```text
MIME: image/webp
max dimensions: 1280×720 without upscaling
target: 280 KiB
hard limit: 512 KiB
quality sequence: 84, 78, 72, 66, 60, 54, 48, 42
```

Do not create another Resource-specific picker/cropper/processor.

### 2.3 Some names are currently Project-specific

The current reusable feature still contains Project-oriented names such as conceptually:

```text
ProjectCoverChange
OwnProjectCover
ProjectCoverCommit
ProjectCoverReconciler
uploadProjectCover
ProjectCoverImage
```

This was acceptable in 08B2A because Project was the first consumer.

08B2B should now establish the clean shared boundary needed by both parent kinds.

Prefer one of:

1. safely generalize truly media-generic types/functions; or
2. preserve validated Project types and add narrowly parallel Resource metadata/reconciler types where domain semantics actually differ.

Do not perform a broad rename/refactor merely for aesthetics.

The important result is:

- picker/crop/processor/loader/display remain shared;
- path and canonical mutation logic support both Project and Resource;
- Proposal/Tavolo behavior from PR #110 remains unchanged.

### 2.4 Existing Resource UI

Current Scambio-Dona already has:

- public discovery;
- `PublicResourceListingCard`;
- public detail;
- My listings;
- create/edit/publish/close;
- request flows;
- Resource chat;
- saved searches;
- Project-resource matching;
- profile-photo trust gate for Resource publication/request interaction.

`ProjectResourceMatchesScreen` already renders matches through:

```text
PublicResourceListingCard
```

Therefore adding cover rendering correctly to the shared Resource card should automatically improve matching-result cards without a separate matching-media implementation.

---

## 3. Product decisions

Treat these as settled.

### 3.1 One optional cover

A Scambio-Dona listing supports:

```text
0 or 1 current canonical cover
```

No gallery.

### 3.2 Cover remains optional

Do not require a cover to publish in 08B2B.

This was explicitly deferred as a later product decision.

The existing **profile photo** publication trust gate remains required where the current product requires it. Cover images do not satisfy that gate.

### 3.3 Same cover format as Projects

Use the exact 08B2A image-selection and processing policy.

Do not create a square/object-specific crop for Scambio-Dona in this slice.

Use:

```text
16:9
1280×720 maximum without upscaling
metadata-free lossy WebP
280 KiB target
512 KiB hard limit
```

Consistency across cards matters more than inventing another image shape now.

### 3.4 Gallery only

Do not add camera capture.

### 3.5 Save semantics remain editor-local

Selecting, replacing, or removing the cover should not mutate canonical Storage/database state immediately.

Use:

```text
canonical cover
  ↓
local desired cover state
  ↓
Save / Publish
  ↓
canonical reconciliation
```

Navigating away without saving leaves the canonical cover unchanged.

---

## 4. Reuse/generalize the cover-media feature

Extend the existing `cover_media` module rather than adding image infrastructure under `resource_listings`.

The shared module should remain the owner of:

- gallery selection;
- crop UI;
- processing;
- byte loading;
- common cover preview/rendering;
- Storage upload/delete primitives;
- immutable path generation;
- typed cover persistence failures.

Add the Resource-specific pieces needed for:

```text
resources/<listing_id>
```

and Resource cover RPCs.

### Path generator

Extend current generator with a Resource path method, conceptually:

```text
forResource({
  ownerProfileId,
  listingId,
})
```

producing the exact 08B1 shape.

### Gateway

Support owner Resource cover metadata/RPC operations:

```text
loadOwnResourceListingCover
setOwnResourceListingCover
clearOwnResourceListingCover
```

The raw Storage upload operation is not fundamentally Project-specific. If current naming such as `uploadProjectCover` blocks clean reuse, generalize it narrowly to a media-generic operation while preserving tests and behavior.

### Reconciler

Add Resource reconciliation with the same canonical ordering.

Replacement:

```text
generate immutable Resource path
→ upload WebP
→ set_own_resource_listing_cover
→ receive previous path
→ best-effort delete previous path
```

Removal:

```text
clear_own_resource_listing_cover
→ receive old path
→ best-effort delete old path
```

Commit failure after upload:

```text
best-effort delete newly uploaded object
→ canonical old cover stays unchanged
```

Do not mix Resource and Project RPCs behind an ambiguous runtime string if typed methods are clearer.

---

## 5. New-listing constraint

As with Proposal/Tavolo, the backend path and upload policy require a real parent ID.

Therefore a brand-new Resource listing must behave as:

```text
pick/crop/process locally
→ no draft yet
→ Save/Publish pressed
→ create Resource draft
→ obtain listing ID
→ upload/commit pending cover
→ optionally publish
```

Do not create a draft when:

```text
editor opens
```

or when:

```text
user selects an image
```

If the user backs out before Save/Publish:

- no Resource row is created;
- no cover object is uploaded;
- no cleanup debt is created.

---

## 6. Resource editor UI

Add the existing reusable Cover image section near the top of:

```text
ResourceListingEditorScreen
```

Use the same user-facing behavior as Proposal/Tavolo.

No cover:

```text
Cover image
[ fallback 16:9 preview ]
[ Add image ]
```

Existing/pending cover:

```text
Cover image
[ 16:9 preview ]
[ Change image ] [ Remove ]
```

Requirements:

- use the existing reusable picker/crop/processing flow;
- show existing canonical owner cover;
- show pending replacement immediately;
- show pending removal immediately;
- do not upload until Save/Publish;
- disable cover controls while local preparation is busy;
- preserve text fields when a cover read fails;
- keep cover errors local and safe;
- closed listings remain read-only and must not expose active cover mutation controls;
- use current localization system.

If the existing `CoverEditorSection` can be made parent-agnostic with a small safe refactor, prefer that over creating duplicated Resource cover editor UI.

---

## 7. Resource persistence orchestration

Integrate cover reconciliation into the existing `ResourceListingEditorController` flow without breaking its existing retained-draft retry semantics.

### 7.1 New Save draft

With pending replacement:

```text
validate draft
→ create Resource draft
→ retain returned listing ID
→ reconcile cover
→ canonical Resource reread
```

If cover reconciliation fails after the draft was created:

- keep the same listing ID;
- remain in editor;
- do not create a second draft on retry;
- accurately tell the user the draft exists but the cover did not save;
- refresh My listings as needed;
- canonical cover remains null/previous state;
- allow retry/change/remove.

This should compose with the editor's existing retained-ID behavior rather than introducing a second retry mechanism.

### 7.2 New Publish

The current Resource publish path already includes a **profile-photo trust gate**.

Preserve that.

With a pending cover, use:

```text
validate publish input
→ existing profile-photo trust preflight
→ create/update draft content
→ reconcile pending cover
→ publish Resource listing
→ canonical reread
```

A pending-cover failure must not silently publish the listing without the image the user just chose as part of the save operation.

On cover failure:

- leave the listing as a draft;
- retain the same ID;
- do not call publish;
- explain the partial save safely;
- allow retry.

If cover succeeds but publish fails:

- keep draft + canonical cover;
- do not remove the valid cover;
- preserve existing profile-photo/backend publish failure behavior.

### 7.3 Existing draft

On Save:

```text
update content
→ reconcile cover
→ canonical reread
```

On Publish:

```text
update content
→ reconcile cover
→ publish
→ canonical reread
```

### 7.4 Existing published listing

Published Resources are currently editable.

On Save changes:

```text
update content
→ reconcile cover
→ canonical reread
```

If content succeeds but cover fails:

- do not claim the entire save rolled back;
- canonical existing cover remains unchanged;
- report that listing changes were saved but cover update failed;
- canonical reread should reflect the true server state.

### 7.5 Closed listing

A closed listing is terminal/read-only.

Do not attempt cover upload/set/clear for it.

If state becomes closed concurrently, map the backend rejection safely and reload canonical state.

### 7.6 Unchanged cover

No upload/RPC when the cover was not changed.

---

## 8. Resource public card

Update:

```text
PublicResourceListingCard
```

to render the shared 16:9 cover/fallback above its existing content.

Preserve:

- Dona / Scambia badge;
- title;
- truncated description;
- rough location;
- publication date;
- interest count;
- optional `footer`;
- optional `semanticDetails`;
- entire card tap target.

This component is reused elsewhere.

That means the change must also remain compatible with:

```text
ProjectResourceMatchesScreen
```

where match reasons are passed through `footer`/semantic details.

The cover must not hide or disrupt the “why this matches” footer.

Do not add Resource-specific media network logic directly into the matching screen.

---

## 9. Resource public detail

Add the canonical cover as the lead 16:9 visual near the top of:

```text
/resources/:listingId
```

Preserve:

- mode badge;
- title;
- description;
- rough location;
- published date;
- owner/profile photo;
- interest count;
- request actions;
- owner edit/loan-schedule shortcuts;
- profile-photo visibility rules.

A cover load failure must leave all text/actions usable.

Do not turn the item cover into the owner profile photo or vice versa. They are distinct trust/presentation signals.

---

## 10. My listings / owner cards

Render the current canonical cover or fallback on Resource owner cards.

Requirements:

- draft cover uses owner-authorized Storage read;
- published cover can still use the owner-safe path as appropriate;
- closed listing cover may be displayed from already owner-authorized canonical data, but no mutation controls;
- preserve lifecycle badge and existing actions;
- preserve canonical backend ordering;
- no client ranking or reordering.

Account switching must not flash a previous user's private draft cover.

Reuse the identity-safe owner loader introduced in 08B2A.

---

## 11. Matching surfaces

08B1 already propagated `cover_object_path` through Project-resource matching contracts.

`ProjectResourceMatchesScreen` currently renders:

```text
PublicResourceListingCard(listing: match.listingSummary, ...)
```

Do not create a second cover implementation.

Once the shared Resource card supports covers:

- Project-resource matches should show them automatically;
- existing matching reasons/footer remain intact;
- pagination/filtering/matching logic must remain unchanged.

Add a thin regression/widget test confirming a match card with a cover renders through the shared card.

---

## 12. Saved-search and request compatibility

Do not broaden the task into redesigning saved searches or request UI.

Preserve:

- saved-search definitions;
- matching/notification semantics;
- request lifecycle;
- exchange agreements/handoff;
- loan schedule;
- Resource chat;
- messages.

If a screen already renders `PublicResourceListingCard`, it may naturally inherit cover rendering.

Do not force large cover thumbnails into compact request/message/chat rows that currently use specialized compact presentation.

Do not attach images to chat messages.

---

## 13. Public/owner loading behavior

Reuse the current `cover_image_loader.dart` behavior.

### Public

For public canonical cover paths:

```text
path null
  → themed fallback

path present
  → layout immediately
  → async Storage download
  → render image on success
  → non-blocking fallback on failure
```

The whole Resource list/detail must not enter an error state because one image failed.

### Owner

For drafts/private owner presentation:

- require expected owner identity;
- reject stale async results after account switch;
- use the existing owner path-keyed loader;
- never flash user A's draft cover to user B.

Because cover paths are immutable versions, path-keyed public caching remains correct.

---

## 14. Cover semantics / fallback

Reuse the exact visual language created in 08B2A.

Do not create a new Scambio-specific fallback system in this task.

No cover is normal.

Accessibility semantics should be restrained, conceptually:

```text
Cover image for <listing title>
```

Do not claim to describe what is depicted.

Do not add an alt-text authoring field.

---

## 15. Localization

Reuse existing cover strings from 08B2A wherever possible.

Only add Resource-specific partial-save wording when existing cover copy cannot accurately express the state.

Examples:

```text
Draft saved, but the cover could not be saved.
Listing changes were saved, but the cover could not be updated.
```

Use concise repository-consistent localized copy.

Do not hard-code production strings.

Do not merge a separate localization branch simply to obtain translations.

---

## 16. Typed failure handling

Reuse existing cover failures:

- source read;
- crop;
- preparation;
- too large;
- upload;
- commit;
- clear;
- owner read;
- public read.

Do not leak Storage/Postgres diagnostics.

Resource lifecycle/identity errors remain canonical Resource failures.

If the cover RPC fails because the listing is now closed/not editable:

- map safely;
- reread canonical Resource state;
- disable cover editing accordingly.

---

## 17. State refresh and invalidation

After successful Resource cover change, refresh only the relevant state:

```text
resource editor canonical record
My listings
public Resource discovery when listing is public
public Resource detail if loaded
Project-resource match results only where the existing controller's refresh/invalidation model requires it
```

Do not invent global app invalidation.

Because public listing summaries now carry the new immutable path, a normal canonical Resource refresh is enough for card caches to key to the new image.

Do not invalidate:

- Project Proposal/Tavolo cover state;
- profile-photo state;
- unrelated chats/notifications.

---

## 18. Preserve profile-photo trust behavior

Resource cover and owner profile photo are independent.

Keep:

```text
profile-photo gate for Scambio-Dona publication/request flows
```

exactly as implemented by 08A4B.

A listing can have:

```text
cover image: present
profile photo: absent
```

and the profile-photo trust gate must still behave exactly as before.

Do not reuse listing cover as an avatar.

Do not relax profile-photo authorization because a public Resource cover exists.

---

## 19. No backend migration expected

08B1 already provides the required:

- Resource cover table;
- Storage policies;
- owner Resource cover RPCs;
- public read policy;
- `cover_object_path` contracts.

08B2B should normally add **no database migration**.

If the actual 08B1 contract cannot support the required mobile flow:

1. stop;
2. report the concrete mismatch;
3. explain why it is a blocker.

Do not silently change RLS/schema/RPC behavior from this UI task.

---

## 20. No new image pipeline

Do not duplicate:

```text
ImagePicker
CoverCropView
CoverMediaProcessor
publicCoverBytesProvider
ownerCoverBytesProvider
fallback renderer
```

under `resource_listings`.

The goal of the 08B split was explicitly to reuse the same media layer.

Resource code should provide Resource ownership/lifecycle orchestration, not another media stack.

---

## 21. Tests — cover-media Resource extension

Add focused unit coverage for:

- Resource path generation;
- exact `resources/<listingId>` binding;
- get own Resource cover RPC mapping;
- set Resource cover RPC mapping;
- clear Resource cover RPC mapping;
- Resource commit response parsing;
- malformed/cross-parent path rejection;
- shared upload uses:
  - `cover-images`;
  - `image/webp`;
  - `upsert = false`;
  - 512 KiB client guard;
- Resource replacement cleanup;
- Resource removal cleanup;
- commit failure cleans newly uploaded object best-effort;
- stale-object deletion failure does not fail a successful canonical mutation.

Do not re-test the entire image encoder matrix already covered by 08B2A unless changed.

---

## 22. Tests — Resource editor orchestration

Required cases:

### New listing

- opening create editor creates no draft;
- selecting/cropping image creates no draft and uploads nothing;
- Save creates draft then cover;
- canonical reread contains cover path;
- cover upload failure retains same draft ID;
- retry does not create second draft;
- commit failure best-effort deletes new upload;
- Publish with pending cover commits cover before publish;
- publish RPC is not called if cover reconciliation fails;
- cover success + publish failure retains draft + canonical cover;
- existing `draftSavedAfterPublishFailure` semantics remain coherent.

### Existing draft/published

- unchanged cover causes no cover mutation;
- replacement commits once;
- Remove clears once;
- local change discarded by navigation/no-save does not mutate canonical cover;
- content-save success + cover failure is surfaced as partial success and old canonical cover remains;
- published listing can change cover while current backend allows edit;
- closed listing cannot persist cover change;
- concurrent close/edit rejection reloads canonical state safely;
- account switch rejects stale pending/private operations.

### Profile-photo gate

- publish still performs existing profile-photo trust preflight;
- cover presence does not bypass the gate;
- gate cancellation causes neither publish nor unintended cover mutation.

---

## 23. Widget tests — Resource UI

Add focused coverage for:

### Public card

- cover success;
- no-cover fallback;
- loading fallback;
- download failure fallback;
- mode badge/title/location/interest/footer remain visible;
- card tap still works.

### Public detail

- cover success/fallback;
- owner profile photo remains separate;
- request actions remain available;
- cover failure does not hide content.

### My listings

- draft owner cover;
- published cover;
- fallback;
- lifecycle/actions preserved.

### Editor

- existing cover preview;
- Add;
- Change;
- Remove;
- pending replacement;
- pending removal;
- cover local failure;
- closed read-only behavior;
- cover selection doesn't create a listing.

### Project-resource match integration

- a match whose embedded Resource summary has a cover renders via `PublicResourceListingCard`;
- matching reason footer remains visible.

Prefer reusing existing shared cover widget tests rather than duplicating crop/encoder tests.

---

## 24. Existing Resource regression coverage

Preserve current behavior/tests for:

- signed-out browse/detail;
- filters;
- search;
- pagination;
- active request count;
- saved searches;
- saved-search matching/notifications;
- create/edit/save/publish;
- close;
- request lifecycle;
- Resource chat;
- exchange agreements/handoff;
- loan schedule;
- Project-resource matching;
- profile-photo trust gate;
- identity switching.

Cover images must not change Resource matching semantics, ranking/order, request counts, or lifecycle.

---

## 25. Performance constraints

Resource discovery may show many cards.

Do not:

- decode/download all images before rendering the list;
- block pagination on cover bytes;
- introduce per-card cover metadata RPCs;
- refetch immutable bytes unnecessarily on every rebuild.

Use the existing path-keyed loader/cache.

Keep memory bounded by normal Riverpod/provider/widget lifecycle conventions; do not build an unbounded custom byte cache unless required.

---

## 26. Native QA checklist

Physical-device QA remains Plan 12.

Add/update Resource-specific checklist items for:

- gallery selection on Android/iOS;
- 16:9 crop gestures;
- large item photos;
- slow/offline upload;
- replacement/remove;
- new listing cover failure and retry;
- public Scambio-Dona scrolling with many covers;
- matching-result cover rendering;
- dark/light theme;
- narrow/tablet layouts;
- account switch with draft editor open;
- cover versus owner-avatar visual distinction;
- TalkBack/VoiceOver semantics.

Do not claim native QA passed.

---

## 27. Documentation

Update relevant current docs, likely:

```text
apps/mobile/lib/features/cover_media/README.md
apps/mobile/lib/features/resource_listings/README.md
docs/architecture/system-design.md
docs/implementation/roadmap.md
```

Update the cover-media README so it no longer describes itself as Proposal/Tavolo-only.

Document:

- Resource integration;
- shared media processing across all three content types;
- Resource path/RPC reconciliation;
- draft-first new listing flow;
- public card/detail behavior;
- matching cards inherit cover from shared Resource card;
- cover remains optional;
- profile-photo gate remains independent;
- no Drive/chat attachments.

---

## 28. Roadmap status

Record the current stack accurately:

```text
08B1  cover domain foundation — PR #106
08B2A Proposal + Tavolo mobile UX — PR #110
08B2B Scambio-Dona mobile UX — current PR
```

While open, keep Plan 08/08B as in progress according to repository conventions.

Do not mark demo polish implemented.

Do not mark shared Drive/workspace integration implemented.

After 08B2B, the planned first cover-image product scope is functionally complete, but native-device QA remains Plan 12 and media cleanup/account-deletion operational work remains separate.

---

## 29. Out of scope

Do not implement:

- cover required for Resource publication;
- multiple item photos;
- galleries/carousels;
- camera capture;
- video;
- chat attachments;
- photo messages;
- Drive/Dropbox/OneDrive integration;
- shared Project workspace link;
- demo-world polish;
- internet stock-photo fetching;
- image moderation;
- OCR;
- object recognition;
- item-condition inference;
- image-derived search/categories;
- profile-photo changes;
- Proposal/Tavolo UX redesign;
- web cover rendering unless compilation strictly requires a compatibility change;
- backend schema/RLS changes absent a reported blocker.

---

## 30. Validation

Run focused cover/Resource Flutter tests plus repository-standard mobile validation.

At minimum:

```text
npm run check:mobile
flutter build apk --debug
git diff --check
```

Run changed-scope formatting checks.

Because no DB/web contracts should change, full DB/Web/Site suites are not automatically required. Run them only if the implementation unexpectedly touches those layers.

If any database migration is introduced, explain why the 08B1 contract was insufficient; under this prompt that should normally have been reported as a blocker before implementation.

Hosted CI may remain blocked by the documented GitHub billing/spending-limit restriction. Make the repository-appropriate final-head attempt if required, document the result, and do not repeatedly rerun an unchanged infrastructure failure.

Do not claim physical-device QA.

---

## 31. Acceptance criteria

08B2B is complete only if all are true:

- [ ] Resource owner can select a cover from gallery.
- [ ] Resource owner uses the existing fixed 16:9 crop.
- [ ] Existing 08B2A processor is reused unchanged unless a proven bug requires a fix.
- [ ] Resource immutable object paths use the exact 08B1 `resources/<listingId>` contract.
- [ ] New listing image selection creates no draft/upload before Save/Publish.
- [ ] New Save creates one draft, then reconciles cover.
- [ ] Retry after cover failure reuses the same draft.
- [ ] New Publish reconciles pending cover before publication.
- [ ] Cover failure prevents the pending Publish action while preserving the draft.
- [ ] Existing draft/published listing can replace cover.
- [ ] Existing draft/published listing can remove cover.
- [ ] Closed listing cannot mutate cover.
- [ ] Navigating away without Save does not commit local cover edits.
- [ ] Failed commit cleans new upload best-effort.
- [ ] Successful replace/clear cleans stale object best-effort.
- [ ] Public Scambio-Dona cards render cover/fallback.
- [ ] Public Resource detail renders cover/fallback.
- [ ] My listings cards render cover/fallback.
- [ ] Project-resource matching cards inherit cover rendering through the shared Resource card.
- [ ] Matching reason footer remains intact.
- [ ] Cover failure never blocks listing text/actions.
- [ ] Owner draft media remains identity-safe.
- [ ] No cover remains publishable.
- [ ] Existing profile-photo trust gate remains unchanged and independent.
- [ ] No separate Resource picker/crop/processor is introduced.
- [ ] `cover_media` documentation now reflects Project + Resource reuse.
- [ ] No DB migration is added unless a blocker was explicitly escalated.
- [ ] No Drive/chat attachment work is introduced.
- [ ] Mobile automated validation passes.
- [ ] Android debug APK builds.
- [ ] Docs/roadmap are updated.
- [ ] Exact prompt is archived.
- [ ] Focused stacked PR is opened and remains unmerged.

---

## 32. Completion report

Return a concise structured report containing:

1. branch;
2. exact base commit;
3. final head commit;
4. PR number/link and target branch;
5. how `cover_media` was generalized/reused for Resources;
6. Resource path/gateway/reconciler additions;
7. new-listing Save/Publish cover ordering;
8. partial-save/retry behavior;
9. public Scambio-Dona surfaces updated;
10. owner surfaces updated;
11. Project-resource matching integration;
12. tests and exact validation results;
13. any inherited warnings/hosted-CI issue;
14. native QA deferred items;
15. confirmation that:
    - cover remains optional,
    - no DB migration was introduced,
    - no Drive/chat attachment work was introduced,
    - profile-photo semantics were unchanged,
    - Proposal/Tavolo cover behavior remains unchanged,
    - the PR remains unmerged.

If a material backend mismatch with 08B1 is discovered, stop and report it instead of silently changing the storage/RLS/RPC contract.
