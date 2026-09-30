# PLANETS 08B1 — Cover Image Storage + Domain Foundation

**Roadmap area:** PLANETS 08 — Storage and media hardening  
**Task type:** Backend/storage/domain foundation for one canonical cover image on Proposals, Tavoli, and Scambio-Dona listings  
**Repository:** `lillo24/planets.community`  
**Required base at prompt creation:** PR #104 head `c10909b66e643491fa0148b2e7b85c8d64ce6461` (`codex/08a4b-scambio-dona-photo-trust`)  
**Preferred branch:** `codex/08b1-cover-media-domain`  
**Do not merge the implementation PR.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08B1_cover_media_domain_foundation.md
```

---

## 0. Objective

Add the canonical storage/domain foundation for **one optional cover image** on each of:

- one-time Proposal;
- recurring activity / Tavolo;
- Scambio-Dona Resource listing.

After 08B1:

- each supported entity can have zero or one canonical current cover image;
- an authenticated owner can securely upload an immutable cover object for an entity they own, attach/replace the canonical cover, read it, and clear it while the parent domain allows that content to be edited;
- public/anonymous readers can download only the canonical cover of content that is already public under that domain's existing visibility/lifecycle rules;
- draft/private/terminal-hidden content does not leak merely because a Storage path exists;
- public and owner read contracts expose the nullable current cover object path so later mobile UI can render covers without one extra RPC per card;
- storage URLs are never persisted as application data;
- no mobile cover picker/editor/card UI is implemented yet.

This is a **foundation task**, not the visual cover-image UX.

The intended next slices are approximately:

```text
08B1  Cover media storage/domain foundation
  ├── 08B2A  Proposal + Tavolo cover mobile UX
  └── 08B2B  Scambio-Dona cover mobile UX
```

Demo-world visual polish is a separate later task after the UI can display these images.

---

## 1. Base and stacked-work safety

At prompt creation, the required media foundation exists in the open 08A stack, not on `main`.

Use as the base:

```text
PR #104
branch: codex/08a4b-scambio-dona-photo-trust
head:   c10909b66e643491fa0148b2e7b85c8d64ce6461
```

PR #104 is itself stacked on the profile-photo work:

```text
08A1 / PR #95  Profile photo storage/domain
08A2 / PR #96  Mobile profile photo processing/upload
08A3 / PR #98  Authorized viewer delivery
08A4A / PR #101 Project trust gates/contextual profile photos
08A4B / PR #104 Scambio-Dona profile-photo integration
```

Before coding:

1. fetch the remote repository;
2. verify PR #104 and its head;
3. create the new branch/worktree from that exact dependency head unless the founder explicitly supplies a newer equivalent base;
4. preserve all inherited 08A behavior;
5. do not rebase this work onto `main` if doing so would drop the unmerged 08A infrastructure;
6. do not modify or clean unrelated founder/Codex worktrees;
7. open a new stacked PR targeting the 08A4B branch;
8. do not merge any PR.

There is a separate open delegate/co-organizer stack around PRs #102–#105. It is **not** part of this base. Do not invent delegate cover-management permissions in 08B1. Future integration can extend the creator/owner mutation boundary after those branches are reconciled.

---

## 2. Current repository evidence

The following was verified immediately before this prompt was written.

### 2.1 Profile-photo media foundation already exists in the 08A stack

08A1 currently defines a private Supabase Storage bucket:

```text
profile-photos
```

with:

- WebP-only content;
- hard size limit;
- immutable UUID object names;
- owner-scoped Storage policies;
- canonical database metadata storing object paths rather than URLs;
- explicit owner RPCs;
- upload first, then commit canonical path;
- replacement returning the previous path for cleanup.

08A2 currently includes mobile patterns for:

- gallery selection via `image_picker`;
- decoding and orientation normalization;
- deterministic crop/resize;
- metadata stripping;
- WebP encoding;
- target-size quality fallback;
- immutable UUID path generation;
- Storage upload with `upsert = false`.

These are useful patterns, but profile-photo-specific semantics must not be copied blindly.

### 2.2 Profile-photo rules that are NOT cover-image rules

Profile photos currently use:

- 512 × 512 square output;
- profile-specific audience values (`public` / `interactions`);
- relationship-dependent viewer authorization;
- profile-specific paths and RPCs;
- trust gates that can require a profile photo before certain actions.

Those rules belong to profile photos.

Cover images must not inherit:

- the square crop;
- the profile-photo audience model;
- relationship-based profile visibility;
- profile-photo trust-gate semantics.

### 2.3 One-time and recurring Projects have a shared identity anchor

The repository already has:

```text
public.projects
```

as a private cross-domain identity anchor for:

```text
one_time
recurring
```

while `proposals` and `recurring_activities` remain authoritative for content and lifecycle.

Prefer this existing anchor where it provides a clean FK/ownership boundary for shared Project-cover metadata. Do not introduce a weak polymorphic table with an unconstrained arbitrary target UUID merely to make the schema look generic.

### 2.4 Scambio-Dona remains a separate domain

`resource_listings` is standalone and currently has no media field.

The original 04C implementation intentionally omitted media. 08B now adds only the one-cover capability; it must not collapse Resource listings into Projects.

### 2.5 Public discovery already works signed out

Canonical public reads already exist for:

```text
list_public_proposals
get_public_proposal

list_public_recurring_activities
get_public_recurring_activity

list_public_resource_listings
get_public_resource_listing
```

Owner read APIs also already exist.

08B1 should extend these canonical read contracts so later clients receive the nullable current cover path in the same list/detail data, rather than performing one cover RPC per visible card.

Inspect current signatures before changing them. Preserve pagination, ordering, filtering, location privacy, profile-photo context, and all other existing fields.

---

## 3. Decisions already made

Treat these as settled for 08B1.

### 3.1 One cover only

Each supported parent has:

```text
0 or 1 current canonical cover image
```

No gallery, carousel, album, attachments, multiple images, or image ordering.

### 3.2 Cover is optional

A missing cover must **not** prevent:

- saving a draft;
- publishing a Proposal;
- publishing a Tavolo;
- publishing a Resource listing.

Do not create a cover-image trust gate.

Whether Scambio-Dona eventually requires an image for publication is a later product decision.

### 3.3 Native PLANETS cover storage

Cover images use PLANETS-controlled object storage for this MVP foundation.

Do **not** implement:

- Google Drive image hosting;
- external image URLs;
- Dropbox/OneDrive/Nextcloud image URLs;
- URL scraping;
- hotlinking;
- remote-image proxying.

The separate product idea of a Project **shared workspace / Drive link** belongs to a later isolated task and is not cover-media storage.

### 3.4 Keep provider portability

Follow the established 08A rule:

```text
database stores provider-independent object paths
not public URLs
not signed URLs
```

Using Supabase Storage for the current implementation is acceptable and expected because the stack already proves that boundary. Do not spread Supabase-generated URLs through domain tables.

### 3.5 Purpose-specific private bucket

Do not make a public bucket and do not rely on UUID secrecy as authorization.

Use a dedicated cover-media bucket, named consistently with repository conventions, for example:

```text
cover-images
```

or another clear equivalent.

The bucket must remain **private**.

Anonymous/public access to an object must be granted only when the canonical parent entity is itself public under its existing domain contract.

### 3.6 Normalized image format

Canonical cover objects are WebP only.

The later mobile UX will normalize selected images before upload. Define/document a landscape cover target appropriate for cards/details, with the intended direction approximately:

```text
16:9 landscape
around 1280 × 720
target roughly 200–300 KiB
hard limit around 512 KiB
```

Codex may adjust the exact target/hard limit slightly if current libraries/tests justify a materially better boundary, but:

- keep it substantially larger than the 512×512 profile avatar;
- keep one bounded normalized WebP;
- do not store the original;
- document the selected constants clearly.

08B1 itself does not need to implement the Flutter cropper/processor unless a small refactor is genuinely required for compilation. That work belongs primarily to 08B2A.

### 3.7 Immutable object versions

Cover objects are immutable.

Replacement flow remains conceptually:

```text
upload new immutable object
→ commit it as canonical for the owned parent
→ receive previous object path
→ caller may delete previous object
```

No overwrite-in-place / `upsert=true`.

A new canonical version therefore naturally has a new cache key.

### 3.8 Parent lifecycle remains authoritative

Do not invent a second cover lifecycle.

Cover mutation eligibility should align with the parent's existing owner-edit semantics.

Examples conceptually:

- Proposal cover must not remain freely editable after the Proposal content is frozen;
- a terminal Resource listing must not gain a new cover merely through the media API;
- Tavolo cover mutation must follow the existing recurring-activity edit/lifecycle rules.

Inspect the current canonical mutation rules and mirror them rather than approximating them in Flutter/client logic.

---

## 4. Scope

08B1 owns:

1. cover Storage bucket/policies;
2. canonical cover metadata;
3. secure owner attach/replace/clear/read operations;
4. public versus owner Storage-read authorization;
5. extension of canonical Proposal/Tavolo/Resource list/detail read contracts with nullable cover object paths;
6. generated database types;
7. database structural/access tests;
8. a real local Auth + Storage verification flow;
9. architecture/database/roadmap documentation.

It may add small shared helpers where justified.

08B1 does **not** own the user-facing image UI.

---

## 5. Data model guidance

Choose the simplest schema that preserves real referential integrity.

A strong likely shape is:

```text
Project covers
  → keyed by public.projects.id
  → therefore covers both one-time Proposal and recurring Tavolo

Resource covers
  → keyed by public.resource_listings.id
```

The exact table names are up to repository conventions.

Each canonical row should contain only what is necessary, conceptually:

```text
parent id
object_path
created_at
updated_at
```

Potentially include an owner/profile field only if it materially strengthens constraints or policy simplicity; do not duplicate ownership without a reason because the parent tables already own that truth.

Requirements:

- exactly one canonical current cover per parent;
- object path unique;
- hard FK to the actual parent/anchor;
- cascade metadata cleanup when safe and consistent with the parent;
- RLS enabled;
- direct table access fail closed;
- public application reads through the canonical RPC/storage boundaries;
- no URL columns;
- no external-provider fields;
- no captions, alt-text authoring, galleries, moderation statuses, focal points, blurhashes, or image analytics in this slice.

If a different schema is chosen, explain why it is stronger than using the existing `projects` anchor plus the Resource-listing FK.

---

## 6. Object path shape

Use an owner- and parent-scoped immutable path that can be validated without ambiguity.

A conceptual shape is:

```text
<owner_profile_id>/projects/<project_id>/<version_uuid>.webp
<owner_profile_id>/resources/<listing_id>/<version_uuid>.webp
```

Exact naming may differ, but preserve the important properties:

- first segment binds to authenticated owner;
- path identifies the owning parent/domain;
- version name is immutable UUID;
- `.webp` only;
- a cover object cannot be attached to an unrelated parent merely because the same user owns both;
- a different user cannot upload/attach into another owner's parent.

Do not accept arbitrary user-supplied Storage paths without structural validation.

---

## 7. Storage authorization

This is security-sensitive.

### 7.1 Upload

Authenticated owners may upload only a valid immutable cover path for a parent they currently own.

Do not allow a user to create cover objects for:

- another user's Project;
- another user's Resource listing;
- a nonexistent target;
- a mismatched path target.

Prefer enforcing meaningful ownership at Storage policy time rather than allowing arbitrary objects under a user folder and relying only on the later commit RPC.

### 7.2 Update

Do not grant Storage object update/overwrite for canonical versions.

### 7.3 Delete

The owner must be able to delete their own valid cover versions, including a replaced non-canonical object returned for cleanup.

Do not make public readers able to delete.

### 7.4 Owner read

An authenticated owner should be able to read the cover objects belonging to their own parent as required for management/preview, including a current draft cover.

### 7.5 Public read

Anonymous and authenticated non-owner readers may download an object only when all of the following are true:

1. the object is the **current canonical cover** for that parent;
2. the parent is currently public according to that domain's existing public-read semantics;
3. the canonical public read contract would expose that parent in the relevant exact-ID/list context.

Do not assume all three domains use identical lifecycle rules.

Mirror the actual existing Proposal, recurring-activity, and Resource visibility behavior.

Important examples to test:

```text
draft cover                        → not public
published visible cover            → public
replaced old object still stored   → not public
cleared cover object still stored  → not public
closed Resource cover              → follows Resource public-detail semantics
cancelled Proposal cover           → follows Proposal public-detail semantics
paused/ended Tavolo cover          → follows current Tavolo public-detail semantics
```

If list visibility and exact-ID detail visibility intentionally differ for a domain, preserve that distinction instead of inventing a new media rule. The cover path returned by an API and the Storage read policy must stay coherent.

No public bucket.

No signed URL persisted in the database.

---

## 8. Canonical owner mutations

Implement narrow, expected-identity-bound backend operations consistent with existing patterns.

Conceptually each domain needs operations equivalent to:

```text
get own current cover
set/replace own current cover
clear own current cover
```

Project covers may share operations through the `projects` anchor if this remains unambiguous and secure.

Resource listing covers remain Resource-specific.

### Set/replace

The canonical commit must verify at minimum:

- authenticated identity matches the expected owner identity;
- parent exists;
- caller owns the parent;
- parent lifecycle currently permits a cover mutation;
- supplied object path has the expected parent/owner/path structure;
- Storage object exists;
- Storage object owner is the caller;
- object belongs to the intended cover bucket;
- object is suitable for canonical cover use under the selected MIME/path rules.

Return enough information for safe client cleanup, including conceptually:

```text
current_object_path
previous_object_path?
updated_at
```

Serialise concurrent replacements on a stable parent/cover anchor so two commits cannot create an ambiguous canonical result.

### Clear

Clearing should:

- remove only the canonical metadata reference;
- return the cleared object path for separate Storage cleanup;
- obey the same parent mutation eligibility;
- be deterministic when no cover exists according to established repository conventions.

Do not delete the Storage object inside a database transaction that cannot atomically include the Storage API.

### Orphans

The system must remain correct if:

```text
upload succeeds
commit fails
```

or:

```text
canonical replacement succeeds
old-object deletion fails
```

The canonical database row is authoritative.

Document dangling object cleanup as an operational concern. Add local detection/verification if appropriate, but do not build a broad scheduled media garbage collector unless the current repository already has an obvious generic mechanism suitable for it.

---

## 9. Extend canonical read contracts

Later UI should not perform one media RPC per card.

Extend the existing canonical domain reads with a nullable cover path, using a clear field such as:

```text
cover_object_path
```

or repository-consistent equivalent.

Cover path should be included where relevant in:

### Proposal

```text
list_public_proposals
get_public_proposal
list_own_proposals
get_own_proposal
```

and any existing request-aware Proposal summary RPC that structurally embeds the public Proposal summary.

### Tavolo / recurring activity

```text
list_public_recurring_activities
get_public_recurring_activity
list_own_recurring_activities
get_own_recurring_activity
```

and any existing request-aware summary boundary that embeds the same public item.

### Resource listing

```text
list_public_resource_listings
get_public_resource_listing
list_own_resource_listings
get_own_resource_listing
```

Also inspect newer request/matching/saved-search contracts from the current Resource stack. If they embed full listing summary shapes used in mobile UI, propagate the nullable cover path through the canonical shared summary boundary rather than creating inconsistent versions of the same listing.

Do **not** add the cover path to unrelated audit/outbox payloads or notifications.

### No cover

The nullable value is simply:

```text
null
```

Do not fabricate a placeholder URL or default Storage object in the backend.

Fallback visuals belong to the presentation layer in 08B2.

---

## 10. Public web compatibility

Proposal and Tavolo public web surfaces already use the canonical public RPCs.

08B1 does not need to visually render covers on the web unless required to preserve build/type compatibility.

However:

- update TypeScript/generated contracts;
- update strict server parsers if they enumerate RPC fields;
- keep existing public pages working;
- do not introduce N+1 media fetches;
- do not accidentally make existing signed-out public discovery require authentication.

Visual web cover integration can be a later UI task.

---

## 11. Flutter compatibility

Do not implement cover selection/rendering screens yet.

However, if current strict Flutter parsers model every public/owner RPC row, update their domain models/gateways to safely parse and retain the nullable cover path so the app remains compatible with the changed backend.

This should be a minimal contract update, not 08B2 UI.

Likely areas include:

```text
features/proposals/
features/recurring_activities/
features/resource_listings/
```

Add fixture/test updates as necessary.

Do not duplicate profile-photo UI under a new name.

When 08B2A introduces cover processing, it should evaluate extracting genuinely reusable low-level picker/WebP helpers from 08A2 while preserving different crop geometry and semantic models. 08B1 should not perform a speculative large Flutter refactor solely for abstraction purity.

---

## 12. Profile-photo compatibility

08B1 must not weaken or rewrite 08A.

Verify that:

- `profile-photos` remains private;
- existing profile-photo RLS/policies remain unchanged unless a narrowly necessary shared helper refactor is proven equivalent;
- `public`/`interactions` audience semantics remain profile-only;
- trust gates introduced in 08A4A/08A4B behave exactly as before;
- Project creator/profile photo and Resource owner/profile photo contextual reads remain independent of cover images;
- a cover image never satisfies a required profile-photo gate.

A user may therefore have:

```text
profile photo: absent
cover image: present
```

and still fail a profile-photo trust gate where the current product requires a profile photo.

---

## 13. Scambio-Dona compatibility

Preserve all current Resource semantics:

- `donate` / `exchange`;
- request lifecycle;
- agreement/handoff behavior already implemented in the current stack;
- saved searches/matching where present;
- profile-photo trust integration from 08A4B;
- existing filters and pagination;
- public rough location rules.

A cover is descriptive media only.

It does not imply:

- item condition;
- ownership proof;
- availability proof;
- reservation;
- successful transfer;
- quantity;
- price;
- loan;
- return obligation.

Do not add any of those fields.

---

## 14. Project/Tavolo compatibility

Preserve:

- the concrete Proposal and recurring-activity lifecycle rules;
- the shared `projects` identity anchor;
- participation behavior;
- exact-location privacy;
- skills/requirements;
- chat;
- profile-photo trust gates.

Cover media is Project presentation content, not participation data.

Do not put cover objects into Project chat messages.

Do not add attachments to chat.

---

## 15. External shared-drive idea is explicitly out of scope

A separate accepted product direction is to allow a Project group to store a link to an external shared workspace, initially useful for a Google Drive/shared folder.

That later feature may expose something like:

```text
Group info
  → Shared workspace

Chat utility strip
  → Info
  → Needs
  → Shared workspace
```

It exists specifically so heavy files, documents, photo collections, and planning material do not need to become chat attachments.

08B1 must **not** implement this.

In particular do not add:

- Google OAuth;
- Drive API integration;
- Drive file browsing;
- external workspace URL fields;
- chat attachment support.

---

## 16. Demo data is out of scope

Do not polish the local demo world in 08B1.

Do not add internet photos to fixtures yet.

A later demo-polish task will replace obviously synthetic titles/content and attach appropriately licensed images after 08B2 can display covers.

Existing deterministic local demo tooling must continue to work with `cover_object_path = null`.

---

## 17. Security / privacy requirements

Fail closed.

At minimum:

- bucket private;
- WebP only;
- bounded file size;
- immutable paths;
- no update/upsert permission;
- exact parent ownership checks;
- no cross-owner attach;
- no cross-parent same-owner attach;
- no public draft reads;
- no public stale/replaced-object reads;
- no direct metadata-table grants that bypass canonical functions;
- no service-role credentials in mobile/web clients;
- no persisted signed/public URL;
- no cover bytes/content in audit or outbox payloads;
- safe errors without leaking internal Storage paths unnecessarily to unrelated users.

Do not use object-path unpredictability as the authorization mechanism.

Do not broaden existing profile/media policies merely to make tests easier.

---

## 18. Structural database tests

Add focused pgTAP coverage for at least:

### Bucket

- dedicated cover bucket exists;
- bucket is private;
- selected hard size limit;
- allowed MIME type is exactly the intended normalized format;
- no object-update policy enabling overwrite.

### Canonical metadata

- expected Project-cover metadata structure;
- expected Resource-cover metadata structure;
- hard FK/anchor relationships;
- one cover per parent;
- unique object path;
- path-shape constraints where stored;
- timestamps;
- RLS enabled;
- direct grants fail closed.

### Functions/contracts

- owner get/set/clear operations exist with narrow grants;
- public/owner list/detail RPCs expose nullable cover path;
- no URL/signed-URL columns;
- existing public APIs keep their pagination/filter signatures aside from the added result field.

---

## 19. Access/behavior database tests

Cover at least the following matrix.

### Project owner

- owner can attach an uploaded cover to own editable Proposal/Tavolo;
- same user cannot attach a Project cover object belonging structurally to another owned Project;
- user cannot attach another user's object;
- user cannot attach to another user's Project;
- replacement returns previous path;
- clear returns current path;
- concurrent or repeated replacement behaves deterministically;
- terminal/frozen Project state rejects cover mutation according to existing parent rules.

### Resource owner

Equivalent coverage for Resource listings.

### Storage

- owner can upload valid path for owned parent;
- upload to unowned/nonexistent parent path is denied;
- overwrite is denied;
- owner can delete obsolete valid versions;
- foreign delete is denied.

### Public reader

- draft cover cannot be downloaded anonymously;
- current canonical cover of public content can be downloaded anonymously;
- a replaced old object becomes unreadable publicly even before physical cleanup;
- a cleared old object becomes unreadable publicly;
- parent lifecycle transition removes public cover access whenever it removes public parent access;
- authenticated non-owner receives no broader access than the relevant public parent contract.

### Optionality

- Proposal/Tavolo/Resource publication still succeeds with no cover.

---

## 20. Local real Auth + Storage verifier

Add or extend a focused script, for example:

```text
scripts/verify-local-cover-media.mjs
```

Use real local Auth and Supabase Storage, not mocked SQL-only state.

The verifier should exercise a compact but meaningful scenario:

1. create/sign in two local identities;
2. create owned draft parent(s);
3. upload valid WebP cover objects through Storage as owner;
4. commit canonical cover;
5. verify owner read;
6. verify anonymous cannot read draft cover;
7. publish parent;
8. verify anonymous public read/download;
9. replace cover;
10. verify new canonical public access;
11. verify old retained object is no longer public;
12. clear or perform a lifecycle transition;
13. verify public access changes accordingly;
14. verify cross-owner and wrong-parent attempts fail;
15. clean up objects created by the verifier where practical.

Reuse the existing trusted local-stack/status helpers rather than inventing a second environment mechanism.

The verifier must refuse non-loopback/non-local targets in line with existing repository safety conventions.

---

## 21. Migration compatibility

Add a new forward migration.

Do not edit historical migrations.

The migration must replay from an empty local database in repository order.

Be careful when extending Postgres functions with `RETURNS TABLE` shapes: change them through a migration-safe drop/recreate strategy where required, preserving grants/comments/security settings and all existing semantics.

Do not silently remove newer Resource/request/matching fields while recreating an older RPC definition.

Use the actual current branch definitions as the source of truth.

---

## 22. Generated types and strict parsers

Regenerate committed database types using the repository command.

Update:

- TypeScript generated database types;
- Flutter strict row parsing/models where required;
- test fixtures;
- server parsing helpers.

Malformed non-null cover paths should fail safely rather than be converted into plausible media.

A valid parent with no cover must remain normal and parse as `null`.

---

## 23. Documentation

Update the relevant current docs, likely including:

```text
docs/architecture/system-design.md
docs/development/database.md
docs/implementation/roadmap.md
```

Document:

- 08B1 as the one-cover foundation;
- dedicated private cover storage;
- object-path-not-URL rule;
- current public-read authorization;
- one optional canonical cover only;
- normalized WebP direction;
- replacement/cleanup semantics;
- no chat attachments;
- no external Drive image hosting;
- later 08B2A/B UI split;
- scheduled/orphan cleanup and account-deletion cleanup remain later operational/privacy work if not implemented here.

Keep profile-photo documentation accurate and separate.

---

## 24. Roadmap status

Update Plan 08 without rewriting unrelated statuses.

Add an 08B section/slice approximately:

```text
08B   Project + Listing Cover Images
08B1  Cover Image Storage + Domain Foundation
08B2A Proposal + Tavolo Cover Mobile UX
08B2B Scambio-Dona Cover Mobile UX
```

While the PR is open:

```text
08B  In progress
08B1 In progress
08B2A Not started
08B2B Not started
```

Do not mark the UI as implemented.

Do not mark demo polish as implemented.

---

## 25. Non-goals

Do not implement:

- multiple images/gallery;
- video;
- PDFs/documents;
- chat attachments;
- Project shared workspace / Drive link;
- Google Drive integration;
- remote image URLs;
- image search;
- AI-generated images;
- demo-world polish;
- image moderation UI/workflow;
- OCR;
- face detection;
- object recognition;
- image-derived categories;
- image requirement at publication;
- profile-photo behavior changes;
- delegate/co-organizer cover permissions from the separate 07C2 stack;
- CDN/provider migration;
- production R2 migration;
- scheduled generic garbage collection unless an already-existing generic mechanism makes it a very small, clearly owned addition.

---

## 26. Validation

Run the repository-standard checks appropriate to the changed layers.

At minimum report exact results for:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
```

Run the new focused real Auth + Storage cover verifier.

Because Proposal/Tavolo public web contracts and Flutter parsers may change, also run:

```text
npm run check:web
npm run check:mobile
```

Run `npm run check:site` if shared generated/contracts/docs/tooling cause it to be in the normal affected validation path.

Run:

```text
git diff --check
```

If the repository's known sequential local-fixture contamination still affects the monolithic database command, distinguish:

- failures inherited unchanged from the dependency stack;
- failures introduced by 08B1.

Do not describe an inherited failure as an 08B1 pass.

At prompt creation, hosted GitHub CI on the 08A stack had an account payment/spending-limit restriction that prevented jobs from starting. If the same infrastructure restriction remains, make one appropriate final-head attempt if repository conventions require it, document the exact GitHub status, and do not wastefully rerun unchanged blocked jobs.

Do not claim physical-device QA. Cover UI is not part of this task.

---

## 27. Acceptance criteria

08B1 is complete only if all are true:

- [ ] Proposal supports zero/one canonical cover at the backend/domain layer.
- [ ] Tavolo supports zero/one canonical cover at the backend/domain layer.
- [ ] Scambio-Dona supports zero/one canonical cover at the backend/domain layer.
- [ ] Cover storage is purpose-specific and private.
- [ ] Only normalized WebP objects within the selected limit are accepted by bucket policy/config.
- [ ] Object versions are immutable.
- [ ] Database persists object paths, never provider URLs.
- [ ] Owner upload/attach/replace/clear authorization is parent-bound and fail-closed.
- [ ] Cover mutation cannot bypass the parent's existing edit/lifecycle restrictions.
- [ ] Anonymous/public download is possible only for the current canonical cover of public parent content.
- [ ] Draft and stale/replaced cover objects are not publicly readable.
- [ ] Existing public list/detail contracts include nullable cover path without N+1 media RPCs.
- [ ] Existing owner read contracts expose current nullable cover path.
- [ ] No-cover records continue to publish and behave exactly as before.
- [ ] Profile-photo trust/visibility behavior remains unchanged.
- [ ] No chat attachment or Drive integration appears.
- [ ] Database structural/access tests cover the new boundary.
- [ ] A real local Auth + Storage verifier passes.
- [ ] Generated types and strict client/server parsers are updated.
- [ ] Web/mobile validation passes or any genuine unrelated inherited failure is precisely documented.
- [ ] Architecture/database/roadmap docs are updated.
- [ ] Exact prompt is archived.
- [ ] A focused stacked PR is opened and left unmerged.

---

## 28. Completion report

Return a concise structured report containing:

1. branch name;
2. exact base commit used;
3. final head commit;
4. PR number/link and target branch;
5. storage bucket name and selected MIME/file-size boundary;
6. chosen database representation for Project vs Resource covers and why;
7. public/owner authorization summary;
8. which canonical RPC/read shapes were extended;
9. whether any Flutter/web contract parsing changed;
10. tests/verifiers/build commands and exact results;
11. known inherited warnings/failures;
12. any orphan-cleanup limitation left for later;
13. confirmation that:
    - no UI cover picker/rendering was implemented,
    - no Drive/external image integration was implemented,
    - no profile-photo semantics were broadened,
    - the PR remains unmerged.

If a material blocker requires changing the settled product/security boundaries above, stop and report it instead of silently broadening scope.
