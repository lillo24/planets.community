# PLANETS 08A3 — Profile Photo Read Access + “Only people I interact with”

**Roadmap area:** Plan 08 — Storage and media hardening  
**Sub-area:** 08A — Profile Pictures  
**Task type:** PostgreSQL/Storage authorization + reusable mobile non-owner read boundary  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on:

```text
PR #96 — 08A2 Mobile Profile Photo Upload + Management
branch: codex/08a2-mobile-profile-photo-management
head:   feb3822a3dde08fbce7874d8996cdec3b050a74b
```

PR #96 is stacked on PR #95/#94 and remains open/unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #96 still points to the expected head or reconcile a newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #96 head;
5. do not merge any PR.

Preferred branch:

```text
codex/08a3-profile-photo-viewer-access
```

Open against:

```text
codex/08a2-mobile-profile-photo-management
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08A3_profile_photo_viewer_access.md
```

No external product document is required.

---

# Product decisions already fixed

08A profile photos use:

```text
private bucket: profile-photos
one current canonical photo per profile
512×512 WebP
250 KiB hard maximum
versioned object paths
no retained original
```

Photo audiences:

```text
public
interactions = “Only people I interact with”
```

08A1 stores that audience.
08A2 implements owner upload/change/remove/audience management.

08A3 implements the first actual non-owner authorization boundary.

---

# 1. First meaning of “Only people I interact with”

For this first implementation, `interactions` is deliberately narrow and directional.

A viewer may see another user's `interactions` photo if the viewer is the canonical creator/organizer of a Project/Tavolo and the photo owner is either:

```text
A. currently requesting to join that organizer's Project:
   project_join_requests.status = pending

OR

B. currently participating in that organizer's Project:
   project_memberships.left_at is null
   and project_memberships.removed_at is null
```

This supports the trust use case:

```text
applicant requests to join
→ organizer can see applicant photo before deciding
→ organizer can continue seeing photo while applicant is a current participant
```

Access ends when:

```text
request rejected
request withdrawn
participant leaves
participant is removed
```

Do not grant `interactions` access merely because there was historical interaction.

---

# 2. Relationships NOT included yet

Do not treat these as interaction-photo authorization in 08A3:

```text
other accepted participants / co-participants
former participants
rejected requesters
withdrawn requesters
Resource / Scambio counterparties
Project chat peers
friends/followers
Groups
notification/message actors
people who merely viewed the same listing/project
```

The authorization helper must be structured so future relationship types can be added later without changing `profile_photos` schema or object paths.

---

# 3. Public audience

If:

```text
profile_photos.audience = public
```

the canonical current photo may be read by:

```text
anonymous viewers
authenticated viewers
```

This is exact-ID photo access, not a public profile-photo directory.

Do not add a directory/list-all-photos API.

---

# 4. Owner access

The photo owner always retains access to their own current photo.

Do not regress the existing 08A2 owner read/download flow.

Owner upload/delete Storage policies remain unchanged.

---

# 5. Canonical authorization helper

Add one narrow private helper equivalent to:

```text
private.can_view_profile_photo(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
returns boolean
```

or another repository-consistent shape.

Rules:

```text
subject has no canonical photo
→ false

viewer == subject
→ true

photo audience = public
→ true

photo audience = interactions
AND viewer is authenticated
AND organizer relationship from section 1 exists
→ true

otherwise
→ false
```

For anonymous viewers:

```text
p_viewer_profile_id = null
```

must be supported so public-photo reads can work.

Use fixed/empty `search_path`.

No direct client execute grant.

---

# 6. Organizer relationship helper

Prefer a separate private helper for relationship semantics, for example:

```text
private.has_profile_photo_organizer_interaction(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
```

It should resolve Project creator ownership through the canonical shared Project/concrete Project identity rather than trusting client-supplied Project IDs.

At minimum it may test:

```text
pending project_join_requests
OR
current project_memberships
```

joined to the canonical Project whose creator is `p_viewer_profile_id`.

No historical ended membership qualifies.

---

# 7. Exact viewer metadata RPC

Add:

```text
get_profile_photo_for_viewer(
  p_profile_id uuid
)
```

Callable by:

```text
anon
authenticated
```

Return zero or one row:

```text
profile_id
object_path
updated_at
```

Do not return:

```text
audience
created_at
owner/auth metadata
relationship reason
signed/full URL
```

If unauthorized or no canonical photo:

```text
return zero rows
```

Do not reveal whether:

```text
photo absent
photo interactions-private
relationship missing
```

This keeps unauthorized cases non-enumerating.

---

# 8. Batch viewer metadata RPC

A4 will show multiple applicants in creator request review.

Avoid one metadata RPC per request card.

Add bounded:

```text
list_profile_photos_for_viewer(
  p_profile_ids uuid[]
)
```

Requirements:

```text
1..50 target IDs
reject null UUIDs
deduplicate IDs deterministically
return only authorized canonical photos
```

Return:

```text
profile_id
object_path
updated_at
```

Ordering may follow input position or stable profile ID; document and test it.

Unauthorized/missing profiles simply do not return rows.

Do not expose an authorization status per omitted ID.

---

# 9. Canonical current object only

Non-owner read authorization applies only to:

```text
profile_photos.object_path
```

that is currently canonical for the subject.

Old/replaced profile-photo versions must not remain cross-user readable merely because the old Storage object still exists temporarily.

Storage policy must join the requested object path to the canonical `profile_photos` row.

Owner cleanup semantics from 08A2 remain unchanged.

---

# 10. Storage SELECT authorization

The bucket remains:

```text
private
```

Extend non-owner Storage SELECT authorization so a client can retrieve only a canonical photo for which:

```text
private.can_view_profile_photo(auth.uid(), subject_profile_id)
```

is true.

For anonymous access, public-photo objects may be selected.

Use the canonical `profile_photos.object_path` relation rather than trusting the first path segment alone.

Keep:

```text
no cross-user INSERT
no cross-user DELETE
no UPDATE
```

Non-owner policy is read-only.

---

# 11. Public Storage-read boundary

Because `public` really means public:

```text
anon
```

may read the exact canonical public photo object.

Do not make the entire private bucket public.

Do not generate a public permanent URL.

The object remains in the private bucket and is authorized by policy.

---

# 12. Interaction Storage-read boundary

For `interactions`:

```text
anon → denied
unrelated authenticated → denied
organizer with pending request → allowed
organizer with current membership → allowed
```

Rejected/withdrawn/left/removed relations → denied.

---

# 13. No direct profile_photos table grants

Keep:

```text
profile_photos
```

RPC-only / fail-closed.

Do not grant anonymous/authenticated direct table SELECT just to make photos work.

Storage RLS and the narrow viewer RPCs are the client boundaries.

---

# 14. No weakening get_public_profile

Do not add photo object paths or signed URLs to:

```text
get_public_profile
```

in 08A3.

Keep public scalar-profile visibility and photo-media authorization as separate boundaries.

A future public profile UI can call both exact-ID boundaries.

---

# 15. No service-role credentials in Flutter

All viewer access must work with ordinary:

```text
anon
authenticated
```

Supabase clients under RLS/RPC authorization.

Do not introduce a service key into mobile.

Do not require a Cloud-only backend function.

---

# 16. Mobile viewer model

Add a non-owner/reusable model separate from `OwnProfilePhoto`.

Conceptually:

```text
VisibleProfilePhoto {
  profileId
  objectPath
  updatedAt
}
```

No audience field.

The viewer does not need to know why access was granted.

---

# 17. Extend profile photo gateway

Keep owner methods unchanged.

Add viewer reads equivalent to:

```text
loadVisiblePhoto(profileId)

loadVisiblePhotos(profileIds)

downloadVisiblePhoto(objectPath)
```

`loadVisiblePhoto` uses:

```text
get_profile_photo_for_viewer
```

Batch uses:

```text
list_profile_photos_for_viewer
```

Storage bytes are fetched only for returned authorized paths.

No direct table access.

---

# 18. Delivery format

For the minimal mobile implementation, prefer the existing private Storage download path:

```text
authorized metadata RPC
→ Storage download under RLS
→ in-memory WebP bytes
```

Do not persist:

```text
signed URL
provider URL
file on local disk
```

This is consistent with 08A2's owner avatar flow and avoids introducing a second image-delivery mechanism before a web/public-photo surface needs one.

If the pinned Supabase Storage client requires signed URLs for a specific non-owner case, use only short-lived URLs after the same authorization and do not persist them; report the deviation.

---

# 19. Viewer controller/cache

Add an identity-bound reusable controller/cache for visible photos.

It should support:

```text
single target
bounded batch targets
loading
authorized photo
no visible photo
safe failure
```

Cache only in memory.

Key cache by at least:

```text
viewer identity (nullable for anon)
target profile ID
object path / updatedAt
```

Do not reuse interaction-authorized photo state across account changes.

---

# 20. Identity changes

On:

```text
login
logout
account switch
```

invalidate non-owner visible-photo cache.

Late metadata/download responses from previous identity must be discarded.

Public-photo data may technically remain valid, but clearing all viewer cache is simpler and safer.

---

# 21. Relationship-state invalidation handoff

08A3 does not yet place photos in creator-review UI.

Expose a simple invalidation API so 08A4 can clear/reload a subject photo after:

```text
accept
reject
withdraw
leave
remove
```

This ensures access changes are reflected promptly in UI once A4 integrates avatars.

Do not add participation mutation coupling inside the generic photo controller yet.

---

# 22. No production avatar placement in A3

Do not render non-owner photos on:

```text
Messages
Participation review
member lists
Project cards
Resource screens
chat
public profile
```

yet.

08A3 builds and validates the reusable authorization/delivery boundary.

08A4 owns actual join/create trust integration and requester-avatar placement.

---

# 23. Security — guessed profile UUID

Knowing:

```text
target profile UUID
```

must not be sufficient to retrieve an `interactions` photo.

Test:

```text
unrelated authenticated user
→ get_profile_photo_for_viewer returns zero
→ Storage download denied even if exact object path is guessed
```

This double gate is intentional.

---

# 24. Security — guessed object path

Even if an unrelated viewer learns a valid canonical:

```text
<profile-id>/<version>.webp
```

path, Storage SELECT must deny access unless public/authorized interaction.

Do not depend on UUID path secrecy.

---

# 25. Security — old object path

After owner replaces photo:

```text
old object may temporarily still exist
```

but non-owner access to old path must fail because it is no longer canonical.

Owner may still delete it through existing cleanup.

---

# 26. Relationship semantics — pending request

Creator A owns Project P.

User B has:

```text
pending join request B → P
photo audience = interactions
```

Expected:

```text
A can view B photo
unrelated C cannot
```

Works for both:

```text
Proposal
Tavolo
```

through shared Project identity.

---

# 27. Relationship semantics — accepted/current participant

B's request is accepted and creates current membership.

Expected:

```text
A continues to view B interactions photo
```

Do not require a pending request after acceptance.

---

# 28. Relationship semantics — rejected/withdrawn

After request becomes:

```text
rejected
withdrawn
```

with no current membership:

```text
A can no longer view B interactions photo
```

No historical access.

---

# 29. Relationship semantics — leave/remove

After current membership ends through:

```text
leave
remove
```

with no other qualifying current/pending relation to the same viewer:

```text
A can no longer view B interactions photo
```

---

# 30. Multiple Projects

If A has any qualifying pending/current relation to B through any Project A creates:

```text
access remains true
```

Ending one relationship must not revoke access if another qualifying relationship still exists.

Test this explicitly.

---

# 31. Co-participant denial

Users B and C are current participants in the same Project created by A.

B's photo audience = interactions.

Expected in 08A3:

```text
A → may view B
C → may NOT view B merely because they share Project membership
```

This is intentional minimum scope.

---

# 32. Reverse-direction denial

B requests to join A's Project.

If A's own photo audience is:

```text
interactions
```

B does not automatically gain access to A's photo merely because B applied.

08A3 interaction authorization is currently:

```text
organizer viewing applicant/current participant
```

not a symmetric friend relation.

Public A photo remains public as usual.

---

# 33. Public photo regression

For `audience=public`:

```text
anon
unrelated authenticated
organizer
owner
```

all may retrieve the canonical photo.

Do not require a participation relationship.

---

# 34. Audience-change behavior

When owner changes:

```text
public → interactions
```

new unauthorized non-owner metadata/storage requests must fail immediately.

When owner changes:

```text
interactions → public
```

public read becomes available without re-uploading bytes.

No object-path change required.

---

# 35. Remove behavior

After:

```text
clear_own_profile_photo
```

viewer RPCs return no row and non-owner Storage reads fail.

No stale canonical metadata.

---

# 36. pgTAP structural coverage

Add focused structural tests covering:

- private viewer authorization helper;
- organizer-interaction helper;
- exact viewer RPC;
- batch viewer RPC;
- anon/authenticated grants;
- private helper grants denied;
- Storage SELECT policies;
- no new cross-user write/delete policy;
- no direct `profile_photos` table grants;
- fixed search paths;
- existing A1 owner RPC signatures unchanged.

---

# 37. pgTAP public access coverage

Test:

```text
public photo + anon → visible
public photo + unrelated authenticated → visible
```

and canonical object path only.

No photo → zero rows.

---

# 38. pgTAP interactions coverage

Test:

```text
pending request organizer → visible
accepted/current membership organizer → visible

unrelated authenticated → hidden
co-participant → hidden
reverse applicant→organizer relation → hidden
```

Proposal + Tavolo parity.

---

# 39. pgTAP revocation coverage

Test:

```text
pending → rejected → access lost
pending → withdrawn → access lost
current membership → leave → access lost
current membership → removed → access lost
```

Multiple qualifying Projects preserve access until the last qualifying relation ends.

---

# 40. Storage policy integration coverage

Use actual Storage metadata/policies where repository test conventions permit.

Verify:

```text
authorized canonical object → SELECT/download possible
guessed unauthorized canonical path → denied
old noncanonical object → denied cross-user
```

Do not test only the metadata RPC.

---

# 41. Real local Storage verifier

Extend:

```text
profile:photo:verify:local
```

or add a focused viewer verifier.

Use real authenticated users:

```text
organizer A
applicant B
unrelated C
co-participant D
```

And anonymous client.

Exercise:

1. B uploads an `interactions` photo.
2. anon cannot read it.
3. C cannot read it.
4. A cannot read before relationship.
5. B requests A's Proposal → A can read.
6. reject → A loses access.
7. B requests again / accepted → A can read as current member.
8. D sharing membership cannot read B.
9. B leaves/removal → A loses access.
10. B switches to `public` → anon/C/A can read.
11. B replaces photo → old path denied cross-user, new path allowed by audience.
12. B removes photo → no viewer access.

Repeat essential interaction check for Tavolo.

Never log tokens or object bytes.

---

# 42. Mobile gateway tests

Cover exact RPCs:

```text
get_profile_photo_for_viewer
list_profile_photos_for_viewer
```

and Storage download.

Verify:

- zero row → no visible photo;
- >1 exact row → fail;
- malformed UUID/path/timestamp → fail;
- batch omits unauthorized rows safely;
- duplicate requested target IDs are handled according to backend contract;
- object download occurs only after authorized metadata row.

---

# 43. Mobile viewer-controller tests

Cover:

- anonymous public photo load;
- authenticated public photo load;
- interaction-authorized photo load;
- hidden photo → absent state, not scary error;
- Storage failure → safe placeholder/failure state;
- account switch clears cached private bytes;
- stale response ignored;
- batch load;
- target invalidation API;
- updated object path replaces cached bytes.

---

# 44. Reusable avatar presentation primitive

If useful for A4, add a small reusable non-owner avatar widget that accepts already-authorized viewer state/bytes.

Requirements:

```text
photo bytes → circular avatar
no photo → neutral placeholder
failure → neutral placeholder
```

Do not let the widget itself perform ad-hoc RPC calls per list row.

A4 should be able to batch-load requester photos and feed this widget.

---

# 45. No N+1 metadata reads

The creator request-review list in A4 may contain many requests.

A3 must provide the batch metadata path so A4 does not need:

```text
one DB RPC per requester card
```

Individual Storage image fetches are acceptable after one batch authorization result.

Do not prefetch photos for unrelated/nonvisible users.

---

# 46. Generated types

Regenerate/update public DB types for:

```text
get_profile_photo_for_viewer
list_profile_photos_for_viewer
```

`db:types:check` must pass.

Do not expose private helper types to mobile.

---

# 47. Documentation / roadmap

Update:

```text
08A1 — PR #95
08A2 — PR #96

08A3 — Photo Read Access + “Only people I interact with”
  this PR

08A4 — Join/Create Trust Reminder + Review Integration
  next
```

Document current `interactions` meaning precisely:

```text
organizer of a Project/Tavolo with:
- pending request from subject, or
- current membership for subject
```

Also document that this is the first relationship set, not the permanent exhaustive meaning of “interaction”.

---

# 48. 08A4 handoff

08A4 should consume the A3 viewer/batch boundary to:

```text
creator request review
→ batch requester profile IDs
→ load authorized photo metadata once
→ fetch/render permitted avatars
```

And implement the previously decided non-blocking reminder:

```text
before Join Project/Tavolo
before Create Project/Tavolo
if own photo absent
→ encourage Add photo
→ Continue without photo remains available
```

08A4 must invalidate/reload viewer photos after participation transitions where access changes.

---

# 49. Validation

Run at minimum:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

npm run profile:verify:local
npm run profile:photo:verify:local
<new/focused viewer-photo verifier if separate>

npm run check:web
npm run check:site
npm run check:mobile
flutter build apk --debug
git diff --check
```

Run focused mobile viewer-photo tests.

Attempt hosted Validation once.

If GitHub again allocates no runner because of billing/spending-limit restrictions:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- join/create reminder UI;
- requester avatar placement in production request-review UI;
- co-participant photo visibility;
- Scambio counterparty visibility;
- chat-peer visibility;
- friends/followers;
- Groups;
- public profile screen redesign;
- Project/Resource images;
- chat attachments;
- camera capture;
- generic media framework;
- permanent provider URLs;
- service-role credentials in mobile.

---

# Acceptance criteria

- [ ] based on exact PR #96 head;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] owner A1/A2 behavior preserved;
- [ ] `public` photos readable anonymously/authenticated;
- [ ] `interactions` photos not anonymous;
- [ ] pending-request organizer may read applicant photo;
- [ ] current-membership organizer may read participant photo;
- [ ] rejected/withdrawn request revokes access;
- [ ] leave/remove revokes access;
- [ ] another qualifying Project preserves access;
- [ ] co-participant does not gain access;
- [ ] reverse applicant→organizer relation does not grant access;
- [ ] exact viewer RPC is non-enumerating;
- [ ] batch viewer RPC supports up to 50 IDs;
- [ ] only canonical current object is cross-user readable;
- [ ] guessed object path is insufficient;
- [ ] old replaced path loses non-owner access;
- [ ] `get_public_profile` remains unchanged;
- [ ] no direct profile_photos grants;
- [ ] no service key in Flutter;
- [ ] reusable mobile viewer gateway/controller exists;
- [ ] batch metadata path prevents future request-list N+1 DB reads;
- [ ] account switching clears private viewer state;
- [ ] no production requester-avatar placement yet;
- [ ] pgTAP + real Storage verifier pass;
- [ ] generated types/drift pass;
- [ ] Web/Site/Mobile regressions pass;
- [ ] debug APK passes;
- [ ] no 08A4 scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 08A3 branch/base/PR
3. Changed files
4. Viewer authorization helper
5. Organizer interaction helper
6. Exact viewer RPC
7. Batch viewer RPC
8. Public audience semantics
9. Interactions audience semantics
10. Pending-request authorization
11. Current-membership authorization
12. Rejected/withdrawn revocation
13. Leave/remove revocation
14. Multiple-Project behavior
15. Co-participant denial
16. Reverse-direction denial
17. Storage SELECT policy
18. Canonical-object-only behavior
19. Guessed-path behavior
20. Old-object behavior
21. Audience-change behavior
22. Remove behavior
23. No-get_public_profile weakening
24. Mobile visible-photo model
25. Viewer gateway
26. Delivery/download choice
27. Viewer controller/cache
28. Account-switch safety
29. Batch/N+1 boundary
30. Reusable avatar primitive
31. Structural pgTAP
32. Public access pgTAP
33. Interaction/revocation pgTAP
34. Storage-policy integration tests
35. Real Storage/OTP verifier
36. Mobile gateway/controller/widget tests
37. Generated types/drift
38. Local database validation
39. Web/Site/Mobile validation
40. Debug APK
41. Hosted Validation executed/not-executed
42. 08A4 handoff
43. Warnings/blockers
44. Commit/PR reference

Do not merge any PR.
