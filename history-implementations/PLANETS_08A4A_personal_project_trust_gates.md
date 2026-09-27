# PLANETS 08A4A — Personal Project Trust Gates + Contextual Profile Photos

**Roadmap area:** Plan 08 — Storage and media hardening  
**Sub-area:** 08A — Profile Pictures  
**Task type:** PostgreSQL authorization/business rules + Flutter trust-gate integration  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on the current 08A profile-photo stack:

```text
PR #98 — PLANETS 08A3: authorize profile photo viewers
branch: codex/08a3-profile-photo-viewer-access
verified head while this prompt was prepared:
66e2719a23d57f719a2687d677a30838a10856df
```

PR #98 is stacked on PR #96 → #95 → #94 and remains open/unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #98 still points to the expected head, or reconcile a newer 08A3 head;
3. inspect `AGENTS.md`, the current 08A1–08A3 implementation/history, relevant Project/Tavolo participation and authoring code, and current tests;
4. preserve unrelated open stacks such as the 07C participation-chat work;
5. branch from the final 08A3 head;
6. do not merge any PR.

Preferred branch:

```text
codex/08a4a-personal-project-trust-gates
```

Open the PR against:

```text
codex/08a3-profile-photo-viewer-access
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08A4A_personal_project_trust_gates.md
```

No external document is required to implement this task. The product decisions needed for 08A4A are recorded below.

---

# Objective

Make a profile photo a **contextual mandatory trust requirement** for person-to-person Project/Tavolo exposure, without making the user's profile photo globally public.

After this task:

- a person may still create and edit Proposal/Tavolo drafts without a profile photo;
- a person cannot transition their personal Proposal/Tavolo from draft to published without a current canonical profile photo;
- a person cannot send a new Project/Tavolo join request without a current canonical profile photo;
- the Flutter UI explains this before blocking the action and routes to the existing profile-photo management surface;
- Project creators can see pending applicants' photos in creator-review UI using the 08A3 viewer boundary;
- a personal Project/Tavolo organizer's photo can be shown in that Project context to people allowed to view the Project even when the photo audience is `interactions`;
- the general profile-photo audience setting remains unchanged and must not be weakened.

This is **08A4A only**. Scambio-Dona receives its separate trust integration in 08A4B.

---

# Current repository evidence

Verified while preparing this prompt:

- `main` is the repository default branch.
- PR #95 / 08A1 provides the private `profile-photos` bucket, canonical `profile_photos` metadata and owner RPC boundary.
- PR #96 / 08A2 provides mobile owner upload/change/remove/audience management.
- PR #98 / 08A3 adds:
  - `private.has_profile_photo_organizer_interaction(viewer, subject)`;
  - `private.can_view_profile_photo(viewer, subject)`;
  - `get_profile_photo_for_viewer(profile_id)`;
  - `list_profile_photos_for_viewer(profile_ids[])`;
  - exact canonical private-Storage download authorization;
  - the Flutter `VisibleProfilePhoto` model/gateway/controller/cache;
  - `VisibleProfilePhotoAvatar`;
  - no production avatar placement and no 08A4 trust UI.
- 08A3 `interactions` is deliberately directional: Project creator → pending requester/current participant. It excludes the reverse organizer-as-subject Project-viewer case.
- Project participation is shared across Proposal and Tavolo and uses canonical `request_to_join_project`.
- Proposal publication uses canonical `publish_proposal`.
- Tavolo publication uses canonical `publish_recurring_activity`.
- `apps/mobile/lib/features/participation/presentation/join_request_screen.dart` contains the existing send-request action.
- `apps/mobile/lib/features/participation/` owns Project/Tavolo requester and creator-review flows.
- `apps/mobile/lib/features/proposals/` and `apps/mobile/lib/features/recurring_activities/` own Proposal/Tavolo authoring and publication.
- Profile-photo delivery is currently private Storage download through authorized metadata, with in-memory bytes and identity-safe cache invalidation.

Repository code after branch creation is the final source of truth. If paths or contracts changed, adapt to the current implementation rather than forcing this prompt's examples.

---

# Product decisions already fixed

## 1. Trust matrix for this slice

```text
Person-created Project/Tavolo:
  organizer/creator:
    photo required before publishing

  applicant:
    photo required before sending join request
```

Drafts remain allowed without a photo.

The gate is tied to the action that exposes the user to another person, not to profile creation.

Do **not** add a global "photo required to use PLANETS" rule.

## 2. Photo existence, not audience, satisfies the gate

For publication/join eligibility, the requirement is:

```text
a current canonical profile_photos row exists for that profile
```

Both current audiences qualify:

```text
public
interactions
```

Do not silently change the user's audience to `public`.

## 3. Group/organization projects

Future group/organization-created Projects may use group/org identity instead of a personal creator photo.

That identity model is not part of this slice unless it already exists in the repository.

Do not invent a Group/Organization schema to solve 08A4A.

Apply this slice to the current **person-created** Proposal/Tavolo model.

## 4. No biometric verification

Do not add:

- face matching;
- liveness;
- identity-document verification;
- biometric templates;
- "verified identity" wording.

A required ordinary profile photo is the current trust layer.

## 5. Phone verification is later

Do not add OTP phone verification in this task.

If future phone verification is referenced in docs, keep it explicitly separate from identity verification.

---

# Mandatory backend enforcement

The photo gate must not be Flutter-only.

A direct RPC call must not be able to bypass it.

## Publication

Enforce the requirement in the canonical transitions:

```text
publish_proposal
publish_recurring_activity
```

When a personal creator is attempting the actual draft → published transition:

```text
no current canonical profile photo
→ publication fails atomically
```

Preserve existing auth/profile/lifecycle/content validation, locks, audit/outbox behavior and idempotency semantics.

Do not require a photo merely to:

- create a draft;
- save/edit a draft;
- reopen authoring;
- edit ordinary content where the existing lifecycle already permits it.

If an existing publish RPC is idempotent for an already-published entity, do not invent a new continuous photo-retention rule as part of the no-op path. The settled rule for this slice is **required before publishing**, not "a published Project can never exist while its creator later has no photo."

## Join request

Enforce the requirement in:

```text
request_to_join_project
```

A requester with no current canonical profile photo must not create a new pending request.

Keep existing:

- expected-profile binding;
- creator exclusion;
- lifecycle eligibility;
- one-pending-request rule;
- current-membership rule;
- request message semantics;
- audit/outbox behavior.

Use a distinct repository-consistent backend failure that the mobile client can map to a typed "profile photo required" state rather than a generic connectivity/server error.

Do not leak unrelated profile-photo metadata in the error.

---

# Existing records and post-action removal

Do not retroactively break historical state.

Examples:

```text
legacy published Project with creator currently lacking a photo
→ keep published
→ UI may show a safe placeholder

legacy pending join request whose requester currently lacks a photo
→ keep the request
→ creator-review UI may show a safe placeholder
```

Do not automatically reject, cancel, unpublish, or delete historical records.

Also do not add a new rule preventing users from removing a photo after publication/request submission. That would be a broader retention/privacy decision and is intentionally not decided in 08A4A.

---

# Flutter blocking UX

The user should normally encounter a clear local trust gate before the backend failure.

Reuse the existing owner profile-photo management surface from 08A2.

Do not create a second upload implementation.

## Personal Project/Tavolo creator

When the user attempts to publish without a photo, block the action and show localized copy equivalent to:

> **A profile photo is required to publish a personal activity.**  
> PLANETS is built on trust between people who may meet in person. Showing who is organizing helps protect both sides and makes the community more trustworthy. Your photo will be visible to people who can view this activity.

Actions:

```text
Add profile photo
Go back
```

No:

```text
Continue without photo
```

## Applicant

When the user attempts to send a join request without a photo, block the action and show localized copy equivalent to:

> **Add a profile photo before requesting to join.**  
> PLANETS connects people who may meet in person. A recognizable photo helps the organizer know who is asking to participate and helps protect both sides.

Actions:

```text
Add profile photo
Go back
```

Do not auto-submit the publish/join mutation after photo upload. Return to the original flow with the user's draft/form state preserved; the user explicitly presses Publish / Send request again.

Preserve the repository's existing auth/profile-completion/`returnTo` conventions.

If the backend returns the photo-required failure because client state was stale, present the same trust-gate UX rather than a generic connection failure.

---

# Applicant avatars in creator review

Integrate 08A3's reusable viewer API into the creator participation-review surfaces.

Requirements:

- pending applicant rows/cards show the applicant's profile photo when authorized;
- use the 08A3 **batch** metadata path for bounded lists rather than one metadata RPC per applicant;
- use `VisibleProfilePhotoAvatar` or the repository's evolved equivalent;
- loading/failure/missing-photo cases use a stable placeholder and must not block request review;
- do not expose the applicant's photo audience or authorization reason;
- do not fetch from `profile_photos` directly.

Historical no-photo requests remain reviewable.

After local relationship-changing actions:

```text
reject
withdraw
leave
remove
```

invalidate/reload relevant visible-photo cache state so a previously interaction-authorized photo is not kept in UI after authorization should end.

Acceptance keeps organizer → participant access because 08A3 intentionally authorizes current membership.

Do not build a new global participant directory.

---

# Contextual organizer photo on Project/Tavolo

A personal organizer who publishes a Project/Tavolo is intentionally exposing their photo in that **Project context**, even if their general photo audience is:

```text
interactions
```

The audience setting itself must remain `interactions`.

## Required authorization behavior

Add a context-aware read boundary for organizer photos.

Conceptually, prefer an operation such as:

```text
get_project_creator_profile_photo_for_viewer(project_id)
```

or another repository-consistent contract that:

1. resolves the canonical Project and creator server-side;
2. verifies the caller is allowed to view that Project using the same lifecycle/visibility rules as the canonical Project detail;
3. returns only the current canonical organizer photo metadata needed for rendering;
4. does not let the caller supply/trust an arbitrary creator profile ID;
5. returns no audience, relationship reason, Auth metadata, or directory/listing surface.

For a currently public published Project/Tavolo, anonymous viewers may qualify because they are already allowed to view that Project.

For owner-only draft/private state, do not grant anonymous contextual photo access.

## Do not weaken the generic profile-photo boundary

Do **not** make:

```text
get_profile_photo_for_viewer(profile_id)
```

succeed merely because that profile owns a public Project.

That generic exact-profile API must retain the ordinary owner/public/08A3-interaction rules.

The Project-context authorization must be a distinct reason/boundary.

This prevents the app from turning "I organize a public Project" into "my `interactions` photo is now generally visible on my profile everywhere."

## Storage/download security

08A3 currently authorizes Storage downloads through the generic exact viewer boundary.

Extend delivery only as narrowly as necessary for the new Project-context read.

Important security constraint:

```text
do not solve this by changing the photo audience to public
do not expose bucket listing
do not expose old/replaced object versions
do not add direct profile_photos table SELECT
do not make every interactions photo anonymously readable
```

A context RPC may expose the canonical opaque object path only after Project-view authorization.

If the existing private-Storage RLS model cannot preserve this contextual authorization without materially broadening object-read access beyond the intended Project context, **stop and report the exact architectural limitation before introducing a new service-role/Edge-Function/signed-capability design**.

Do not silently weaken privacy to make the UI work.

If the repository's existing architecture supports a narrow fail-closed solution, implement it and document the exact authorization semantics.

---

# Organizer photo placement

Use the context-aware Project-photo boundary on Proposal and Tavolo **detail/organizer identity presentation**.

At minimum:

```text
published Proposal detail
published Tavolo detail
```

should be able to show the organizer avatar for viewers who may view that Project.

Do not mass-add avatars to unrelated profile, search, chat, notification, or resource screens.

If current browse cards already have an explicit organizer identity row and reuse is trivial, adding the avatar there is acceptable; otherwise keep this slice focused on detail.

Missing/legacy organizer photo:

```text
show stable placeholder
do not hide the Project
do not fail Project detail
```

---

# Data/security implementation guidance

Prefer a forward migration; do not edit released migration history.

Likely DB work includes:

- a narrow private helper for "profile has current canonical photo";
- publication/join gate changes in canonical RPCs;
- context-aware organizer-photo viewer authorization;
- any minimal Storage policy extension required by the chosen safe design;
- generated DB type updates if public RPC signatures are added/changed;
- pgTAP/security coverage.

Keep helpers:

```text
security definer only where needed
fixed/empty search_path
no client execute grant for private helpers
```

Preserve:

- private bucket;
- immutable UUID object paths;
- canonical-current-object checks;
- no stale object read;
- no directory listing;
- no service key in Flutter;
- no logs containing image bytes, private paths, or unrelated profile metadata.

---

# Test-fixture impact

Backend enforcement will affect existing tests/verifiers that publish Projects or submit join requests.

Update trusted fixtures/helpers so existing scenarios intentionally provision a profile photo for actors that need one.

Do not weaken the new gate merely to avoid test churn.

Add explicit negative tests for no-photo actors.

When possible, centralize fixture provisioning rather than scattering ad-hoc profile-photo inserts across many tests.

Do not claim validation passed if Docker/Actions infrastructure is unavailable; report exactly what ran.

---

# Required tests

## Database / pgTAP

Cover at least:

- Proposal draft creation/edit without photo succeeds;
- Tavolo draft creation/edit without photo succeeds;
- Proposal draft → published without photo fails;
- Tavolo draft → published without photo fails;
- both publish transitions succeed with canonical photo, for either audience;
- join request without photo fails;
- join request succeeds with canonical photo, for either audience;
- existing auth/lifecycle/duplicate/current-membership semantics remain intact;
- no direct `profile_photos` client read is introduced;
- Project-context organizer-photo metadata is returned only for a viewer allowed to view that Project;
- public published Project context works for anon where canonical detail is public;
- draft/non-viewable Project context does not leak organizer photo;
- generic `get_profile_photo_for_viewer(profile_id)` is **not** broadened by Project ownership;
- only the canonical current object is readable;
- old/replaced photo paths remain denied;
- no bucket listing.

## Real local verifier

Extend/create the appropriate local verifier to exercise real Auth + Storage where necessary:

1. creator with `interactions` photo publishes a personal Proposal/Tavolo;
2. anonymous/public viewer opens allowed Project context and can retrieve only that contextual canonical organizer photo;
3. same viewer cannot use the generic profile-photo metadata boundary to obtain the organizer's `interactions` photo;
4. unrelated private/draft Project context does not expose it;
5. requester without photo cannot request;
6. requester with `interactions` photo can request;
7. creator can then retrieve requester photo through the 08A3 organizer-interaction path;
8. rejection revokes that interaction path;
9. replaced/stale object paths fail.

Adapt this scenario if the final safe Storage design uses a different context-delivery mechanism.

## Flutter

Cover at least:

- Proposal publish without photo opens creator trust gate;
- Tavolo publish without photo opens creator trust gate;
- join submit without photo opens applicant trust gate;
- Add profile photo routes to existing photo management while preserving unsaved authoring/join state;
- returning does not auto-submit;
- stale backend photo-required failure maps to trust-gate UI;
- normal users with a photo continue through existing publish/join flow;
- creator-review list batch-loads applicant avatars;
- missing/legacy applicant photo renders placeholder;
- reject/other relevant relationship-ending action invalidates visible-photo state;
- Proposal/Tavolo detail loads contextual organizer avatar;
- contextual avatar failure never breaks Project detail;
- account switch/logout still clears viewer-photo state;
- localization and accessibility labels exist for new copy/actions/avatar semantics.

Run the full existing mobile suite afterward.

---

# Localization

All new user-facing strings must use the repository's localization system.

Do not hardcode the English explanatory text directly in widgets.

Use the current canonical ARB structure and regenerate localized output as required by the repository.

If Italian localization infrastructure is being added on another concurrent branch, do not entangle that unrelated branch here. Keep this PR consistent with the base branch's current localization setup and make strings ready for translation.

---

# Non-goals

Do not implement in 08A4A:

- Scambio-Dona photo gates or counterpart visibility — 08A4B;
- phone verification;
- face/liveness/identity verification;
- group/organization identity architecture;
- mandatory photo during profile creation;
- "make photo public" automation;
- general public profile redesign;
- unsolicited private messaging;
- moderation/reporting/blocking features unrelated to required cache invalidation;
- new photo upload/cropping pipeline;
- web photo management;
- participant/co-participant photo directory;
- photo-retention lock after publish/request;
- production deploy or automatic merge.

---

# Acceptance criteria

- [ ] Proposal drafts remain creatable/editable without a photo.
- [ ] Tavolo drafts remain creatable/editable without a photo.
- [ ] `publish_proposal` rejects the actual publish transition when the creator has no canonical photo.
- [ ] `publish_recurring_activity` rejects the actual publish transition when the creator has no canonical photo.
- [ ] `request_to_join_project` rejects a new request when the requester has no canonical photo.
- [ ] Flutter shows the specified blocking explanation before normal publish/join attempts when photo is missing.
- [ ] The block has **Add profile photo** and **Go back**, with no bypass.
- [ ] Existing 08A2 photo management is reused.
- [ ] Returning from photo management preserves the original flow but does not auto-submit.
- [ ] Creator-review surfaces show pending applicant avatars through 08A3 viewer APIs, using batch metadata for lists.
- [ ] Relationship-ending actions do not leave revoked interaction photos retained in visible UI cache.
- [ ] Proposal/Tavolo detail can show the personal organizer's photo through a Project-context authorization boundary.
- [ ] `interactions` remains the user's stored audience; it is not rewritten to `public`.
- [ ] Generic exact-profile viewer authorization is not broadened solely by Project ownership.
- [ ] Storage remains private/non-enumerable and stale object paths stay denied.
- [ ] Historical no-photo published Projects/requests are not destroyed or rewritten.
- [ ] Scambio-Dona, phone verification and biometrics remain untouched.
- [ ] Relevant DB, verifier, Flutter and repository-wide validation passes, or unavailable checks are explicitly reported.
- [ ] Architecture/feature docs and roadmap are updated to record the implemented semantics.
- [ ] This prompt is archived unchanged in `history-implementations/`.

---

# Validation

Use the repository's current commands after inspection. At minimum, where applicable:

```bash
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run profile:verify:local
npm run profile:photo:verify:local
npm run profile:photo:viewer:verify:local
npm run participation:verify:local
npm run check:web
npm run check:site
npm run check:mobile
flutter build apk --debug
git diff --check
```

Add/run any new focused verifier required for the Project-context photo path.

Do not rerun hosted CI repeatedly if the known GitHub billing/spending-limit infrastructure problem still prevents runner allocation. One final-head attempt is enough if repository policy calls for it; report infrastructure failure separately from test failure.

---

# Documentation

Update only documentation affected by this slice, likely including:

- profile-photo feature boundary/readme;
- participation or Project/Tavolo feature docs where the trust gate changes behavior;
- architecture/system-design privacy/authorization description;
- implementation roadmap;
- database/security docs if public RPC/storage semantics change.

Do not rewrite broad product documentation unrelated to 08A4A.

Record clearly:

```text
photo gate = presence of canonical photo
audience remains user-controlled
Project organizer visibility = contextual Project authorization
generic profile visibility remains separate
```

---

# Autonomy and stop conditions

Codex may choose repository-consistent:

- helper/function names;
- typed mobile failure/model names;
- widget composition;
- cache invalidation mechanics;
- exact test-helper organization.

Stop and report instead of guessing if implementation would require deciding any of these:

1. weakening the generic `interactions` privacy setting;
2. making a private bucket or interactions photos generally public;
3. adding service-role credentials to Flutter;
4. adding an Edge Function or new signed-capability service because exact Project-context Storage authorization cannot be expressed safely in the existing architecture;
5. inventing group/organization identity rules;
6. preventing photo deletion while a Project/request is active;
7. changing the product rule from "photo required before trust-sensitive action" to global profile-photo enforcement.

Do not stop for minor naming/layout choices that can be resolved from repository conventions.

---

# Deliverables

1. focused 08A4A branch and PR stacked on 08A3;
2. forward DB migration(s) if required;
3. DB/generated type updates;
4. Flutter trust-gate and avatar integration;
5. focused + regression tests/verifiers;
6. updated affected docs/roadmap;
7. archived exact prompt;
8. completion report.

---

# Completion report

Return:

1. base/head/PR and dependency status;
2. summary of implemented behavior;
3. changed areas/files;
4. exact backend photo-gate semantics;
5. exact Project-context organizer-photo authorization semantics;
6. whether Storage authorization stayed within the existing architecture or required a stop/escalation;
7. applicant-avatar placement and cache invalidation behavior;
8. treatment of legacy no-photo records;
9. commands/tests run with exact results;
10. hosted validation result or infrastructure limitation;
11. warnings/deferred work for 08A4B or later;
12. commit/PR link.

Do not merge the PR.
