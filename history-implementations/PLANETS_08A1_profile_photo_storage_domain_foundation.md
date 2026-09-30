# PLANETS 08A1 — Profile Photo Storage + Domain Foundation

**Roadmap area:** Plan 08 — Storage and media hardening  
**Sub-area:** 08A — Profile Pictures  
**Task type:** Supabase Storage + PostgreSQL domain/security foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on the current stabilized top of the open stack:

```text
PR #94 — STACK-STABILIZATION-01: clear inherited database gates
branch: codex/stack-stabilization-db-gates
head:   9a1034f457a9a749e1ded5eb28ca744280eed37b
```

PR #94 is open, cleanly mergeable, and intentionally stacked on the open feature chain.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #94 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #94 head;
5. do not merge any PR.

Preferred branch:

```text
codex/08a1-profile-photo-storage-domain
```

Open against:

```text
codex/stack-stabilization-db-gates
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08A1_profile_photo_storage_domain_foundation.md
```

No external document is required.

---

# Product decisions already fixed

08A is intentionally small.

Profile photo design:

```text
one current profile photo per user
private Supabase Storage bucket
512×512 WebP client contract
~100 KB compression target
250 KiB hard upload limit
no original retained
versioned object paths
```

Photo visibility choices:

```text
public
interactions
```

User-facing meaning of:

```text
interactions
```

is:

```text
Only people I interact with
```

The exact relationship authorization is implemented in 08A3.

08A1 must **store** the audience choice but must not yet expose non-owner photo reads.

Default photo audience:

```text
interactions
```

This is the privacy-preserving default.

---

# 1. 08A implementation split

Record/refine the Plan 08 roadmap as:

```text
08A — Profile Pictures

08A1 — Profile Photo Storage + Domain Foundation
  this plan

08A2 — Mobile Photo Upload + Profile Management
  later

08A3 — Photo Read Access + “Only people I interact with”
  later

08A4 — Join/Create Trust Reminder + Review Integration
  later
```

Broader Plan 08 media remains separate.

Do not implement Project images, Resource-listing images, chat attachments, group avatars, galleries, or video.

---

# 2. Storage interface decision

Use:

```text
Supabase Storage
```

for profile photos.

This slice must remain portable between managed and self-hosted Supabase.

Do not:

- persist a `*.supabase.co` URL;
- persist signed URLs;
- persist a provider/CDN hostname;
- hard-code a managed Supabase project ref;
- make Dashboard-only bucket configuration authoritative.

The canonical durable reference is:

```text
object path
```

The current production-hosting/cutover decision is outside 08A1.

---

# 3. Private purpose-specific bucket

Create/configure one bucket:

```text
profile-photos
```

Requirements:

```text
private = true
allowed MIME = image/webp
hard file limit = 250 KiB
```

Use the repository-supported Supabase mechanism that is reproducible across:

```text
local reset
managed Supabase
future self-hosted Supabase
```

Do not rely on someone manually creating the bucket in a Dashboard.

Inspect the pinned Supabase CLI/Storage version and use the supported configuration/migration mechanism.

Supabase Storage bucket restrictions are the authoritative server-side hard limit.

---

# 4. No generic media bucket

Do not create:

```text
uploads
media
images
public-files
```

Profile photos have their own purpose/access boundary.

Later media types should receive separate buckets/policies when their requirements are known.

---

# 5. Object path format

Objects use immutable/versioned paths:

```text
<profile-id>/<photo-version>.webp
```

Example:

```text
a4e0.../46fa....webp
```

`photo-version` should be an opaque UUID or equivalent non-user-provided unique value.

Exactly one directory level plus one file.

Do not use:

```text
<profile-id>/avatar.webp
```

because replacement caching becomes harder.

Do not accept arbitrary nested paths.

---

# 6. No overwrite/upsert model

A replacement photo is:

```text
upload NEW versioned object
→ commit new canonical DB reference
→ later delete old object through Storage API
```

Do not overwrite an existing object path.

Do not require Storage UPDATE permission.

Future mobile upload must use equivalent of:

```text
upsert = false
```

---

# 7. Storage owner policies

On `storage.objects`, add narrowly scoped authenticated policies for:

```text
bucket_id = profile-photos
first path segment = auth.uid()
```

Owner may:

```text
INSERT own versioned object
SELECT own objects
DELETE own objects
```

No UPDATE policy.

No anonymous access.

No authenticated cross-profile access.

The path policy must reject:

```text
another profile UUID
extra nested folders
non-.webp filename
invalid version filename
```

Use current Supabase Storage helper functions/policy conventions where appropriate.

---

# 8. Owner identity and Storage ownership

Do not trust path prefix alone.

Where supported by the current Storage schema, canonical photo commit must also verify the exact Storage object is owned by the authenticated user using current non-deprecated ownership metadata.

Inspect the actual local Storage schema before implementation.

Do not guess column names from old Supabase versions.

---

# 9. Storage schema is not application state

Do not directly INSERT/UPDATE/DELETE `storage.objects` from PLANETS application functions.

All object creation/deletion happens through Supabase Storage APIs.

Database functions may read Storage metadata for validation if supported.

RLS policies on Storage tables are allowed and expected.

---

# 10. Profile photo metadata table

Add one app-owned table equivalent to:

```text
public.profile_photos
```

Recommended fields:

```text
profile_id uuid primary key
object_path text not null unique
audience text not null default 'interactions'
created_at timestamptz not null
updated_at timestamptz not null
```

Foreign key:

```text
profile_id → profiles(id) ON DELETE CASCADE
```

No full URL.

No signed URL.

No raw bytes.

No original-photo path.

No provider ID.

No filename supplied by the user.

---

# 11. Audience constraint

`audience` accepts exactly:

```text
public
interactions
```

Meaning:

## public

Intended for public profile-photo visibility once 08A3 implements read delivery.

## interactions

User-facing label:

```text
Only people I interact with
```

08A1 **does not yet define every relationship that counts as an interaction**.

08A3 will initially include at least:

```text
Project/Tavolo creator reviewing that user's join request
```

and will create the reusable relationship authorization boundary.

Do not prematurely add accepted participants, chat peers, Resource counterparties, friends, followers, or groups in A1.

---

# 12. Why photo audience is not added to profile_field_visibility yet

Current mobile profile code strictly models:

```text
display_name
bio
skills
```

and currently supports only:

```text
public
private
```

Adding a fourth field / third audience there would force unrelated existing profile editor changes before 08A2 and risks breaking strict parsers.

Therefore 08A1 stores photo audience with `profile_photos`.

Do not modify the existing three-field profile visibility contract in this slice.

This is not a second generic visibility system; it is purpose-specific media authorization metadata.

---

# 13. Updated timestamp

Use the repository's normal trigger/helper pattern so:

```text
created_at
```

is stable and:

```text
updated_at
```

advances when the canonical object path or audience changes.

No immutable history table.

---

# 14. Direct table access

Prefer RPC-only mutation.

Enable RLS on:

```text
public.profile_photos
```

Authenticated owners may read their own row either:

A. through a narrow owner-read RPC; or
B. direct owner SELECT if that is clearly more consistent with the current profile feature.

Prefer the approach that keeps identity handling consistent with the current expected-profile protections.

Do not grant public/anonymous photo metadata reads in A1.

No other user may directly read the row.

---

# 15. Owner read RPC

Preferred operation:

```text
get_own_profile_photo(
  p_expected_profile_id uuid
)
```

Return zero/one row with:

```text
profile_id
object_path
audience
created_at
updated_at
```

Expected identity must match authenticated `auth.uid()`.

No URL generation.

No Storage bytes returned.

---

# 16. Canonical commit RPC

Add an operation equivalent to:

```text
set_own_profile_photo(
  p_expected_profile_id uuid,
  p_object_path text,
  p_audience text
)
```

It is called **after** the Storage upload succeeded.

It must:

1. require authentication;
2. verify expected profile identity;
3. lock the current profile/photo state sufficiently for replacement races;
4. validate `p_audience`;
5. validate exact object-path grammar;
6. verify the referenced Storage object exists in `profile-photos`;
7. verify it belongs to the authenticated user;
8. reject an object outside the user's folder;
9. make that path the one canonical current profile photo;
10. update audience atomically;
11. return enough information for the caller to clean up the previous object.

Suggested return:

```text
current_object_path
previous_object_path nullable
audience
updated_at
```

Do not delete the previous Storage object with direct SQL.

---

# 17. Bucket restrictions remain authoritative

The bucket enforces:

```text
image/webp
<= 250 KiB
```

The commit operation should validate relevant Storage metadata where safely available, but must not reimplement a brittle fake file-size authority from client parameters.

Do not accept:

```text
p_byte_size
p_mime_type
```

as trusted client truth.

---

# 18. 512×512 / ~100 KB boundary

The agreed image-production contract is:

```text
512×512
WebP
target around 100 KB
hard max 250 KiB
```

A1 can hard-enforce:

```text
MIME
max bytes
path
ownership
```

through Storage/domain constraints.

A1 does **not** need to decode WebP server-side to prove dimensions.

08A2 owns deterministic mobile crop/resize/compression to 512×512.

Do not create an image-transformation server pipeline solely to validate dimensions in A1.

---

# 19. Audience update RPC

Add:

```text
set_own_profile_photo_audience(
  p_expected_profile_id uuid,
  p_audience text
)
```

Require an existing current photo.

Allowed values only:

```text
public
interactions
```

Use expected-profile identity binding.

No object mutation.

---

# 20. Clear-photo RPC

Add:

```text
clear_own_profile_photo(
  p_expected_profile_id uuid
)
```

Behavior:

```text
remove canonical profile_photos row
return prior object_path
```

Do not directly delete Storage bytes from SQL.

The caller can delete the returned path through Storage API.

If Storage deletion later fails, the user's profile must still have:

```text
no canonical photo
```

An inaccessible/unreferenced object is cleanup debt, not a reason to keep displaying a removed photo.

---

# 21. Replacement transaction boundary

Canonical sequence for 08A2 will be:

```text
upload new versioned object
        ↓
set_own_profile_photo(...)
        ↓
DB now points to new object
        ↓
delete returned previous object through Storage API
```

If commit fails:

```text
new upload is unreferenced
→ caller should attempt cleanup
```

If old-object deletion fails:

```text
new canonical photo remains valid
→ old object is orphaned
```

Do not attempt distributed atomicity between PostgreSQL and object storage.

---

# 22. Orphan strategy for 08A1

Do not implement a full cleanup worker yet.

Document the two orphan cases:

```text
upload succeeds / DB commit fails
DB switch succeeds / old Storage delete fails
```

Ensure unreferenced objects are not visible to other users.

Later Plan 08 cleanup can detect:

```text
profile-photos Storage objects
LEFT JOIN canonical profile_photos.object_path
```

and delete stale unreferenced objects after an appropriate safety window.

Do not introduce cron/scheduler infrastructure solely for 08A1.

---

# 23. No public photo delivery yet

Even when:

```text
audience = public
```

08A1 must not add:

```text
anon Storage SELECT
public signed-URL RPC
public photo URL
```

08A3 owns non-owner delivery.

This ensures private access design is reviewed before photos become externally readable.

---

# 24. No “interactions” read implementation yet

Do not implement:

```text
join-request reviewer photo access
participant access
Resource-counterparty access
chat-peer access
```

in 08A1.

Only the owner can access their object in this slice.

08A3 owns relationship-based reads.

---

# 25. Existing profile APIs must remain compatible

Do not change the signature/behavior of:

```text
update_own_profile(...)
get_public_profile(...)
```

in 08A1.

Existing mobile/web profile screens must continue to work unchanged.

No new photo field is required in `OwnProfile` or the existing profile form yet.

08A2 owns mobile model/UI integration.

---

# 26. Account/profile deletion

`profile_photos.profile_id` should cascade when the profile row is deleted.

That does not automatically delete Storage bytes.

Document the Storage-object cleanup obligation for Plan 10/account deletion and later Plan 08 cleanup infrastructure.

Do not fake cascading physical object deletion with SQL against `storage.objects`.

---

# 27. Security-definer rules

If photo RPCs require `SECURITY DEFINER` to safely inspect Storage metadata:

- fixed empty/search-limited `search_path`;
- fully qualify relations/functions;
- explicitly revoke default execute;
- grant only intended roles;
- bind every owner operation to `auth.uid()`;
- do not expose arbitrary object lookup.

If `SECURITY INVOKER` can satisfy the contract safely, prefer it.

Follow the repository's established least-privilege conventions.

---

# 28. SQLSTATE conventions

Use current repository conventions:

```text
42501 → auth/ownership violation
22023 → invalid audience/path/input
55000 → inconsistent/missing canonical backend state where appropriate
PT409 → explicit application conflict only if a genuine conflict condition requires it
```

Do not manufacture `40001`.

---

# 29. Replacement concurrency

Two concurrent `set_own_profile_photo` calls for the same profile must not corrupt metadata.

Serialize on the profile/current-photo row or equivalent stable lock.

Allowed outcome:

```text
one canonical final object path
```

The losing/replaced uploaded path may require cleanup, but there must never be:

```text
two canonical profile_photos rows for one profile
```

Return values must permit callers to identify replaced paths correctly.

Add focused concurrency coverage where feasible.

---

# 30. Storage RLS structural coverage

Add pgTAP/schema tests for:

- bucket is private;
- bucket is `profile-photos`;
- allowed MIME includes only `image/webp`;
- max size is 250 KiB;
- no anonymous object policy;
- owner INSERT policy;
- owner SELECT policy;
- owner DELETE policy;
- no UPDATE policy;
- path prefix is owner-bound;
- policies are restricted to this bucket.

Do not weaken unrelated Storage behavior.

---

# 31. Metadata structural pgTAP

Cover:

- `profile_photos` table;
- one row per profile;
- FK cascade;
- unique `object_path`;
- exact audience constraint;
- default `interactions`;
- timestamps;
- RLS;
- direct grants;
- RPC signatures;
- fixed search paths;
- authenticated-only execute;
- no anon/public photo-read RPC.

---

# 32. Metadata behavioral pgTAP

Cover:

```text
owner can read own metadata
cross-user read denied
anonymous denied
invalid audience rejected
invalid path rejected
wrong profile prefix rejected
missing Storage object rejected
cross-user-owned Storage object rejected
```

Where direct Storage object creation is inappropriate inside pgTAP, keep Storage API behavior in the real integration verifier rather than mutating production Storage metadata incorrectly.

---

# 33. Real local Storage verifier

Add a focused script using real local authenticated users and the Supabase Storage API.

Cover:

1. sign in user A and user B;
2. ensure complete profiles;
3. upload valid small WebP-like fixture using `image/webp`;
4. owner path succeeds;
5. other-user path is denied;
6. unsupported MIME is denied;
7. >250 KiB upload is denied;
8. owner can SELECT/download own private object;
9. user B cannot read user A object;
10. anonymous cannot read;
11. commit owner photo metadata;
12. default/intended `interactions` metadata works;
13. switch audience to public;
14. public still does **not** make object anonymously readable in A1;
15. upload a second version and replace canonical metadata;
16. old path is returned;
17. canonical row points only to second path;
18. clear returns current path;
19. metadata is absent after clear;
20. delete uploaded objects through Storage API;
21. concurrent canonical commits cannot create multiple current rows.

Use bounded deterministic fixtures.

Never log access tokens or raw auth secrets.

---

# 34. Test fixture image

Use a tiny repository-owned generated/test WebP fixture or generate one in the verifier.

Do not commit a large photo asset.

No user/person image is needed.

The fixture exists only to exercise Storage MIME/size/upload behavior.

---

# 35. Generated types

Regenerate database types after adding:

```text
profile_photos
get_own_profile_photo
set_own_profile_photo
set_own_profile_photo_audience
clear_own_profile_photo
```

Use canonical generation.

Do not hand-edit generated types.

The stack-stabilization PR established a green:

```text
db:types:check
```

Keep it green.

---

# 36. Documentation

Update profile/media docs to state:

```text
profile photos now have backend/storage foundation
no mobile photo picker yet
no public/interactions delivery yet
bucket is private
canonical DB reference is object path only
audiences are public / interactions
interactions label = “Only people I interact with”
default = interactions
```

Document:

```text
512×512 WebP
~100 KB client target
250 KiB server hard limit
no original retained
```

---

# 37. Architecture portability

Document the migration-safe rules:

```text
DB stores path, not URL
bucket name is stable
object paths are provider-independent identifiers within Supabase Storage
no managed project ref in domain rows
no signed URL persisted
```

Do not redesign ADR 0003 or provision production infrastructure in this PR.

---

# 38. Roadmap

Update Plan 08:

```text
08A — Profile Pictures
08A1 — Storage + Domain Foundation
  this PR
08A2 — Mobile Upload + Profile Management
  next
08A3 — Photo Read Access + Interactions
08A4 — Join/Create Trust Reminder + Review Integration
```

Plan 08 overall remains in progress.

---

# 39. Validation

Run from a clean current stack:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
```

Run the new local Storage/profile-photo verifier.

Then:

```text
npm run check:web
npm run check:site
npm run check:mobile
flutter build apk --debug
git diff --check
```

Existing profile mobile/web tests must remain green.

Attempt hosted Validation once.

If GitHub still allocates no runner because of the known billing/spending-limit problem, report:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- Flutter image picker;
- camera permission;
- crop UI;
- client WebP conversion;
- mobile upload screen;
- profile avatar rendering;
- public photo reads;
- join-request reviewer photo reads;
- signed URLs for other users;
- Project/Tavolo trust reminder;
- Project images;
- Resource-listing images;
- group avatars;
- chat attachments;
- original-image storage;
- thumbnail variants;
- server-side image transformations;
- EXIF retention;
- moderation/AI image analysis;
- generic media service;
- R2 integration;
- production self-hosting;
- scheduled orphan cleanup;
- account-deletion media worker.

---

# Acceptance criteria

- [ ] based on exact PR #94 head;
- [ ] exact prompt archived;
- [ ] private `profile-photos` bucket is repository-defined;
- [ ] bucket accepts only WebP;
- [ ] hard max is 250 KiB;
- [ ] no originals;
- [ ] versioned immutable path format;
- [ ] owner-only INSERT/SELECT/DELETE Storage policies;
- [ ] no object UPDATE/upsert path;
- [ ] cross-profile/anonymous Storage access denied;
- [ ] one canonical profile-photo metadata row per profile;
- [ ] DB stores object path, never URL;
- [ ] audience exactly `public | interactions`;
- [ ] default audience is `interactions`;
- [ ] user-facing meaning documented as “Only people I interact with”;
- [ ] existing `profile_field_visibility` contract remains unchanged;
- [ ] existing profile APIs remain backward-compatible;
- [ ] owner read RPC exists;
- [ ] canonical set/replace RPC exists;
- [ ] audience-change RPC exists;
- [ ] clear RPC exists;
- [ ] canonical commit verifies auth/profile/path/object ownership;
- [ ] replacement concurrency is deterministic;
- [ ] SQL never deletes Storage objects directly;
- [ ] no public/interactions read access implemented yet;
- [ ] orphan cases documented;
- [ ] generated types green;
- [ ] structural/behavioral pgTAP green;
- [ ] real local Storage verifier green;
- [ ] clean DB reset/lint/advisors/full tests green;
- [ ] Web/Site/Mobile regression green;
- [ ] debug APK green;
- [ ] hosted CI attempted once/reported accurately;
- [ ] no 08A2/08A3/08A4 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 08A1 branch/base/PR
3. Changed files
4. Bucket creation/configuration
5. Private bucket status
6. MIME restriction
7. File-size restriction
8. Object-path grammar
9. Storage owner policies
10. Storage ownership verification
11. No-overwrite/upsert boundary
12. `profile_photos` schema
13. Audience model/default
14. Existing profile-visibility compatibility
15. Owner-read RPC
16. Set/replace RPC
17. Audience-update RPC
18. Clear RPC
19. Storage-object validation
20. Replacement transaction boundary
21. Concurrency behavior
22. Orphan behavior
23. No-public-read boundary
24. No-interactions-read boundary
25. Profile/account deletion behavior
26. Security/grants/search paths
27. Structural pgTAP
28. Behavioral pgTAP
29. Real Storage verifier
30. Cross-user/anonymous privacy verification
31. MIME/oversize verifier
32. Replacement/clear verifier
33. Generated types
34. `db:reset`
35. `db:lint`
36. `db:advisors`
37. full `db:test`
38. `db:types:check`
39. Web regression
40. Site regression
41. Mobile regression
42. Debug APK
43. Hosted Validation executed/not-executed
44. 08A2 handoff
45. Warnings/blockers
46. Commit/PR reference

Do not merge any PR.
