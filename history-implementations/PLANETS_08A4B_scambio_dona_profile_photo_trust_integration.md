# PLANETS 08A4B — Scambio-Dona Profile Photo Trust Integration

**Roadmap area:** Plan 08 — Storage and media hardening  
**Sub-area:** 08A — Profile Pictures  
**Task type:** PostgreSQL authorization/business rules + Flutter Scambio-Dona trust integration  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on:

```text
PR #101 — PLANETS 08A4A: add personal project photo trust gates
branch: codex/08a4a-personal-project-trust-gates
verified head while this prompt was prepared:
7cdc2c72d1074cc343a161126f3658cb82cf1e27
```

PR #101 is stacked on PR #98 and remains open/unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #101 still points to the expected head, or reconcile a newer 08A4A head;
3. inspect `AGENTS.md`, `implementation_plan_sections_suggestions.md`, the current 08A1–08A4A implementation/history, and the current Scambio-Dona listing/request/chat/exchange code;
4. preserve unrelated open stacks;
5. branch from the final 08A4A head;
6. do not merge any PR.

Preferred branch:

```text
codex/08a4b-scambio-dona-photo-trust
```

Open the PR against:

```text
codex/08a4a-personal-project-trust-gates
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_08A4B_scambio_dona_profile_photo_trust_integration.md
```

No external product document is required. The product decisions needed for this slice are recorded below.

---

# Objective

Complete the contextual profile-photo trust model for Scambio-Dona.

After this task:

- a person may still create and edit a Scambio-Dona draft without a profile photo;
- publishing a Scambio-Dona listing requires a current canonical profile photo;
- sending a new request for a listing requires a current canonical profile photo;
- viewers of a public published listing can see the listing owner's current photo in that listing context even when the owner's stored audience is `interactions`;
- the listing owner can see the requester's photo while a request is pending;
- after acceptance, while canonical coordination remains open, owner and requester can continue to see each other's photos;
- rejected, withdrawn, listing-closed-before-acceptance, or coordination-closed relationships no longer grant the Scambio-specific `interactions` authorization;
- the Flutter UI explains the photo requirement and reuses the existing 08A2 photo-management surface;
- generic profile-photo privacy remains separate from listing-context visibility.

This is the final currently planned 08A4 trust-integration slice. Do not expand it into phone verification, biometrics, moderation, or unrelated resource UX.

---

# Current repository evidence

Verified while preparing this prompt from the PR #101 stack:

## Profile-photo foundation

08A1–08A4A already provide:

- private `profile-photos` Storage bucket;
- one current canonical photo row per profile;
- `public` and `interactions` audiences;
- owner upload/change/remove/audience management;
- generic exact and bounded-batch viewer metadata;
- exact canonical private-Storage download authorization;
- identity-safe in-memory Flutter viewer caches;
- `VisibleProfilePhotoAvatar`;
- `ProfilePhotoRequirement`;
- reusable `ProfilePhotoTrustGate`;
- backend `PT422` semantics for a missing required canonical photo;
- Project publication/join trust gates;
- Project-context organizer-photo metadata/delivery without broadening the generic exact-profile metadata RPC.

The existing `private.can_view_profile_photo(viewer, subject)` currently handles:

```text
owner
public audience
Project organizer → pending requester/current participant for interactions
```

08A4B must extend the `interactions` relationship set for Scambio-Dona rather than replace the existing Project relationship.

## Current Scambio-Dona implementation

The current stack has separate Flutter features:

```text
resource_listings/
resource_requests/
resource_chat/
resource_exchange/
resource_loans/
resource_saved_searches/
```

Relevant current backend operations include:

```text
publish_resource_listing(expected_owner, listing_id)
request_resource_listing(expected_requester, listing_id, message)
accept_resource_listing_request(...)
reject_resource_listing_request(...)
withdraw_resource_listing_request(...)
get_public_resource_listing(listing_id)
get_own_resource_request_chat(...)
```

Current canonical domain facts:

- listing lifecycle is `draft`, `published`, `closed`;
- public listing detail is available only for `published`;
- public detail already returns the listing owner's profile ID and visibility-sanitized display name;
- a Resource request may be `pending`, `accepted`, `rejected`, `withdrawn`, or `listing_closed`;
- accepted means coordination may proceed; it is not itself proof of handoff/completion;
- accepted requests own the canonical Resource chat/agreement;
- canonical open coordination is represented by accepted request state plus `coordination_closed_at is null`;
- completion/cancellation makes the Resource chat read-only and closes canonical coordination;
- `ResourceChatSummary` already carries owner/requester profile IDs and role information;
- `resource_request_screen.dart` owns exact owner/requester request handling;
- `resource_chat_screen.dart` already has a counterparty header;
- `public_resource_listings_screen.dart` owns public listing detail and the request entry point;
- `resource_listing_editor_screen.dart` owns draft/publish actions.

Repository code after branch creation is the final source of truth. If a current contract differs, adapt to it rather than forcing stale assumptions.

---

# Product decisions already fixed

## 1. Scambio-Dona trust matrix

```text
Listing owner:
  profile photo required before publishing listing

Requester:
  profile photo required before sending a new request
```

Drafts remain allowed without a photo.

The gate is attached to the trust-sensitive action, not to profile creation.

## 2. Contextual visibility

The intended trust flow is:

```text
public published listing viewer
→ can see listing owner's required photo in that listing context

request sent / pending
→ listing owner can see requester's required photo

accepted + coordination still open
→ owner and requester can continue to see each other's photo

relationship ends
→ Scambio-specific interaction authorization ends
```

Do not implement this by changing either participant's stored audience to `public`.

## 3. Photo presence satisfies the gate

For publish/request eligibility:

```text
current canonical profile_photos row exists
```

Either audience qualifies:

```text
public
interactions
```

The user's chosen audience is not rewritten.

## 4. No global public-profile change

A user publishing a Scambio-Dona listing does **not** make:

```text
get_profile_photo_for_viewer(profile_id)
```

globally succeed for an `interactions` photo.

Listing-context owner-photo discovery must remain a distinct context boundary, analogous to the 08A4A Project-context boundary.

## 5. No biometric or phone verification

Do not add:

- face matching;
- liveness;
- identity-document verification;
- biometric templates;
- phone OTP;
- "identity verified" claims.

---

# Mandatory backend enforcement

The gates must be enforced in the canonical mutations, not only Flutter.

## Listing publication

Extend:

```text
publish_resource_listing
```

so that the actual:

```text
draft → published
```

transition requires the current owner to have a current canonical profile photo.

Preserve existing:

- ownership binding;
- content validation;
- locking;
- audit/outbox behavior;
- idempotent already-published behavior.

Do not require a photo merely to:

- create a draft;
- save/edit a draft;
- reopen the editor;
- edit an already-published listing where the existing domain permits it.

If an already-published listing is passed through the existing idempotent no-op, do not introduce a new continuous photo-retention requirement.

Use the same repository-consistent `PT422` trust-gate failure semantics established in 08A4A.

## New Resource request

Extend:

```text
request_resource_listing
```

so that creating a new request requires the requester to have a current canonical profile photo.

Preserve existing:

- complete-profile requirement;
- published-listing requirement;
- self-request prohibition;
- active-request duplicate/conflict behavior;
- optional bounded message;
- locks;
- audit/outbox behavior.

Use `PT422` for the missing canonical photo so Flutter can distinguish the trust gate from connectivity/server failure.

---

# Existing records and later photo removal

Do not rewrite or destroy historical state.

Examples:

```text
published listing whose owner later removes their photo
→ listing remains published
→ UI shows a safe placeholder

pending/accepted request whose requester later removes their photo
→ request/agreement remains canonical
→ counterpart UI shows a safe placeholder
```

Do not automatically:

- close listings;
- reject requests;
- cancel agreements;
- close chats;
- block photo deletion.

A future retention requirement would be a separate product/privacy decision.

---

# Extend `interactions` for Scambio-Dona

Add a narrow private relationship helper, repository-consistent in naming, conceptually equivalent to:

```text
private.has_resource_photo_interaction(
  viewer_profile_id,
  subject_profile_id
)
```

Then extend the existing generic `private.can_view_profile_photo(...)` so the `interactions` audience succeeds when **either** an existing Project relationship **or** the new canonical Scambio relationship applies.

Do not remove or weaken the current Project authorization.

## Pending request: directional

For a request with:

```text
status = pending
```

authorize:

```text
listing owner (viewer)
→ requester (subject)
```

This is the trust use case for evaluating the request.

Do not make the pending request alone authorize arbitrary reverse generic-profile access.

The requester already sees the owner's photo through the public listing context while the listing is published.

## Accepted/open coordination: symmetric

For:

```text
request.status = accepted
AND request.coordination_closed_at is null
```

authorize both:

```text
listing owner ↔ requester
```

This must continue even if the public listing later becomes closed, because the accepted counterparties may still be coordinating the handoff/loan/exchange.

Use the repository's canonical coordination-open semantics. If the current agreement lifecycle adds a stricter invariant, reconcile with it rather than creating a second inconsistent definition.

## Ended/non-qualifying relationships

Do not grant Scambio interaction-photo access solely from:

```text
rejected
withdrawn
listing_closed
accepted with coordination_closed_at set
historical completed/cancelled coordination
old request episode
unrelated viewer
saved search / match
chat participant from another request
```

Historical Resource chat readability must not itself keep `interactions` photo authorization alive after coordination closes.

---

# Public listing-owner photo context

Add a listing-context owner-photo boundary analogous to 08A4A's Project-context organizer boundary.

Conceptually:

```text
get_resource_listing_owner_profile_photo_for_viewer(listing_id)
```

or another repository-consistent name.

Requirements:

1. resolve the canonical listing and owner server-side;
2. authorize against canonical public listing-detail visibility;
3. for ordinary public viewers, only a currently `published` listing qualifies;
4. allow the owner to resolve their own listing context where appropriate for owner UI/testing;
5. return only:

```text
profile_id
object_path
updated_at
```

6. return no audience, relationship reason, Auth fields, phone/contact data, or directory surface;
7. do not trust a client-supplied owner profile ID.

The generic:

```text
get_profile_photo_for_viewer(profile_id)
```

must not become public merely because that profile owns a published listing.

## Storage delivery

Keep the bucket private and preserve:

- exact current canonical object only;
- no replaced/stale object access;
- no bucket listing;
- no direct `profile_photos` SELECT;
- no service-role credential in Flutter.

For the public listing context, use the narrowest repository-consistent Storage rule, analogous to 08A4A.

Because every anonymous/authenticated caller may already view a published listing, exact-object download eligibility while the owner has a qualifying public listing does not broaden the listing's audience. However, metadata discovery must remain contextual/non-enumerating.

For accepted/open counterpart access after the public listing closes, rely on the generic `interactions` authorization expanded above rather than keeping the listing artificially public.

If implementing this would require materially weakening `interactions`, exposing bucket enumeration, or introducing service credentials in the client, stop and report the architectural issue.

---

# Flutter trust-gate UX

Reuse 08A4A infrastructure rather than duplicating photo-presence checks or navigation.

Use:

```text
ProfilePhotoRequirement
ProfilePhotoTrustGate
existing 08A2 photo-management surface
```

or their current evolved equivalents.

All new copy must be localized.

## Listing owner publish gate

When the owner tries to publish without a photo, block the normal action and show localized copy equivalent to:

> **A profile photo is required for Scambio-Dona.**  
> Exchanges, donations and loans can involve meeting another person or handing over an item. Knowing who you are interacting with helps protect both sides and builds trust in the community.

Actions:

```text
Add profile photo
Go back
```

No bypass.

Saving/editing a draft remains available without a photo.

For the editor's combined new-listing Publish flow, preserve the existing "one draft ID then publish that exact ID" safety. A trust-gate failure must not create duplicate drafts on retry.

## Requester gate

When the requester tries to submit a new Scambio-Dona request without a photo, show the same Scambio-Dona trust explanation, with actions:

```text
Add profile photo
Go back
```

No `Continue without photo`.

Do not auto-submit after the user adds a photo.

Return to the original listing/request composition flow with the typed message/form state preserved where the current navigation architecture allows it.

If the backend returns `PT422` because local state was stale, map it back to the same trust-gate UX rather than a generic connection error.

---

# Public listing owner avatar

On Scambio-Dona public listing detail:

```text
published listing
→ show owner avatar through the listing-context photo boundary
```

This must work for anonymous viewers.

If the owner photo is absent because of legacy data or later removal:

```text
show a stable placeholder
do not hide/fail the listing
```

Do not fetch owner photos through direct `profile_photos` reads.

Do not add avatars to every search card unless the existing UI already has an owner identity row and the addition is trivial. Detail is the required surface.

---

# Pending requester photo for listing owner

In the canonical owner-facing Resource request detail/review surface:

```text
pending request
→ owner sees requester avatar when authorized
```

Use the existing generic visible-photo boundary after expanding Scambio `interactions`.

Do not expose:

- requester audience;
- authorization reason;
- any extra private profile/contact field.

Missing/failing photo:

```text
placeholder
request actions remain usable
```

After:

```text
reject
withdraw
listing_closed transition
```

invalidate/reload the relevant visible-photo cache so a revoked requester photo is not retained in UI as though still authorized.

Do not invalidate accepted/open access merely because the public listing closes.

---

# Accepted/open coordination counterpart avatars

The accepted Resource chat is the canonical coordination surface.

Extend the existing Resource chat counterparty header so:

```text
owner viewing chat
→ requester avatar

requester viewing chat
→ owner avatar
```

Use the generic visible-photo authorization, which should now succeed symmetrically during accepted/open coordination.

The chat summary already carries:

```text
owner_profile_id
requester_profile_id
viewer_role
coordination_closed_at
```

Prefer deriving the target counterpart ID from canonical chat state rather than adding a redundant client relationship model.

When coordination becomes closed/completed/cancelled:

- history remains readable according to the existing Resource-chat rules;
- Scambio `interactions` photo authorization ends;
- invalidate/reload the counterpart photo entry;
- render placeholder if the now-unauthorized photo cannot be fetched.

Do not keep photo authorization alive merely because historical chat remains visible.

---

# Cache and identity safety

Reuse the 08A3/08A4A identity-safe visible-photo controller.

Required invalidation points include Scambio relationship transitions that remove authorization, at least:

```text
request rejected
request withdrawn
request closed because listing closes
coordination completed/cancelled/otherwise canonically closed
account login/logout/switch
```

Do not retain cross-account photo bytes.

A stale photo may remain momentarily during the canonical mutation only if unavoidable, but after the mutation succeeds the local state must invalidate/reconcile.

---

# Data/security guidance

Use a forward migration. Do not edit released migration history.

Likely DB work:

- reuse `private.has_current_profile_photo(...)` from 08A4A;
- replace/extend `publish_resource_listing`;
- replace/extend `request_resource_listing`;
- add private Scambio photo-interaction helper;
- extend `private.can_view_profile_photo`;
- add exact listing-context owner-photo metadata authorization;
- add minimal exact-object Storage authorization for public listing context if needed;
- update generated DB types.

Keep private helpers:

```text
fixed/empty search_path
no direct API execute grants
fail closed
```

Preserve all current Resource request/chat/agreement locks and state-machine behavior.

Do not merge Project participation and Resource request tables or controllers.

---

# Fixture/test impact

This task will affect many existing Scambio tests/verifiers because listing publication and request creation become photo-gated.

Use the reusable profile-photo fixture helper introduced in 08A4A:

```text
scripts/lib/local-profile-photo.mjs
```

or its current repository equivalent.

Prefer central fixture provisioning over scattered ad-hoc `profile_photos` inserts.

Existing tests that intentionally exercise ordinary published listings/requests should provision canonical photos.

Dedicated negative tests must verify the no-photo cases.

Do not weaken the new gate to avoid fixture updates.

## Known inherited validation notes from PR #101

PR #101 documented two pre-existing/non-08A4A issues:

1. sequential `npm run check:db` fixture-isolation assumptions can fail even though clean-reset focused verifiers pass;
2. repository-wide formatting encounters two unchanged Site formatting issues.

Treat these as known inherited diagnostics, not permission to ignore new failures.

Do not broaden 08A4B into a repository-wide fixture-isolation cleanup unless 08A4B itself causes a new regression that cannot be tested safely otherwise.

Report:

- clean focused validation;
- full command results;
- the first inherited failure if still present;
- whether the failure changed relative to PR #101.

---

# Required database tests

Cover at least:

## Publication/request gates

- Scambio-Dona draft creation without photo succeeds;
- draft editing without photo succeeds;
- draft → published without photo fails with `PT422`;
- publication succeeds with a canonical `public` photo;
- publication succeeds with a canonical `interactions` photo;
- idempotent already-published call remains a no-op even if the photo was later removed;
- new request without photo fails with `PT422`;
- new request succeeds with either photo audience;
- all prior listing/request auth, lifecycle, self-request, duplicate, and message validation remains intact.

## Public listing owner context

- anonymous viewer of a published listing receives the owner's current contextual photo metadata;
- authenticated unrelated viewer receives the same because the listing is public;
- draft/closed listing does not expose owner photo through the public listing-context RPC;
- generic exact-profile metadata remains denied for an unrelated viewer when owner audience is `interactions`;
- current canonical exact object downloads;
- replaced object remains denied;
- bucket listing remains denied.

## Pending request interaction

For an `interactions` requester photo:

```text
pending:
  owner → requester allowed
  unrelated viewer → requester denied
  requester → owner generic interaction not granted merely by pending request
```

The requester's normal access to owner photo comes from the published listing context.

After rejection/withdrawal/listing-closed:

```text
owner → requester Scambio interaction denied
```

## Accepted/open coordination

For `interactions` photos:

```text
accepted + coordination open:
  owner → requester allowed
  requester → owner allowed
```

This must remain true after the listing itself closes if coordination remains open.

After canonical coordination closes/completes/cancels:

```text
owner ↔ requester Scambio interaction denied
```

unless another independent Project/Resource relationship separately authorizes them.

Test relationship composition: removing one Scambio relationship must not accidentally revoke a photo still authorized by a different qualifying relationship.

---

# Real Auth + Storage verifier

Extend the existing profile-photo viewer verifier or add a focused Scambio trust verifier.

Exercise at least:

1. listing owner with `interactions` photo creates draft;
2. publish fails for a no-photo owner in a separate case;
3. owner with photo publishes;
4. anonymous viewer obtains owner photo through exact listing context;
5. same viewer cannot obtain that `interactions` photo through generic profile metadata;
6. requester without photo cannot create request;
7. requester with `interactions` photo creates pending request;
8. listing owner can retrieve requester's photo through generic `interactions`;
9. requester does not gain reverse generic access merely from pending request;
10. owner accepts;
11. both counterpart directions now work while coordination is open;
12. close the public listing while keeping accepted coordination open and verify both counterpart directions still work;
13. close/complete/cancel coordination canonically and verify Scambio-specific generic access ends;
14. old/replaced object paths remain denied;
15. object listing remains denied.

Use the current canonical agreement/coordination transitions rather than directly mutating state for steps that already have public testable RPCs.

---

# Required Flutter tests

Cover at least:

## Listing editor

- Save/create draft without photo is still usable;
- Publish without photo opens Scambio trust gate;
- Add profile photo uses the existing owner photo-management route;
- returning does not auto-publish;
- typed/unsaved editor state is preserved according to existing navigation conventions;
- backend `PT422` maps to the same trust-gate UI;
- user with photo follows the existing publish flow without extra interruption;
- retry cannot duplicate a newly created draft.

## Public listing detail

- contextual owner avatar loads;
- anonymous detail can show it;
- missing/failing legacy owner photo renders placeholder;
- avatar failure never breaks listing detail.

## Resource request

- requester submit without photo opens trust gate;
- returning from photo management does not auto-submit;
- request message state is preserved where possible;
- backend `PT422` maps to the trust-gate UI;
- pending owner-facing request detail shows requester avatar;
- missing/failed requester photo does not disable Accept/Reject;
- reject/withdraw/listing-close reconciliation invalidates relevant photo state.

## Resource chat

- owner sees requester avatar in counterparty header during open accepted coordination;
- requester sees owner avatar;
- account switch cannot reuse prior counterpart bytes;
- coordination closure invalidates/reloads counterpart photo and safely falls back to placeholder;
- chat history still renders after coordination closure according to current domain behavior.

Run the complete mobile suite afterward.

---

# Localization/accessibility

All new user-facing strings must use the current localization system.

Do not hardcode trust-gate or avatar semantics text in widgets.

Use clear semantics labels for:

- listing owner avatar;
- requester avatar;
- Resource chat counterpart avatar;
- trust-gate actions.

If another concurrent localization PR exists, do not rebase unrelated localization work into this slice unless the current base already contains it.

---

# Non-goals

Do not implement:

- mandatory photo at profile creation;
- global `photo = public`;
- phone verification;
- face/liveness/ID verification;
- reporting/blocking/moderation;
- contact-detail exchange;
- exact private meeting/address release changes;
- new Resource chat lifecycle;
- agreement redesign;
- payment/escrow;
- dispute/damage/liability handling;
- new listing modes;
- generic DM;
- web photo management;
- broad visual redesign;
- production deployment;
- automatic merge.

---

# Acceptance criteria

- [ ] Scambio-Dona drafts remain creatable/editable without a photo.
- [ ] `publish_resource_listing` gates only the actual draft → published transition on canonical photo presence.
- [ ] `request_resource_listing` requires canonical requester photo.
- [ ] Both `public` and `interactions` photos satisfy trust gates.
- [ ] Flutter shows the required Scambio trust explanation with **Add profile photo** / **Go back** and no bypass.
- [ ] Existing photo-management UI is reused.
- [ ] Public published listing detail shows the owner's contextual photo.
- [ ] An `interactions` owner photo does not become generically public through `get_profile_photo_for_viewer`.
- [ ] Pending request authorizes listing owner → requester photo visibility.
- [ ] Pending request alone does not create reverse generic interaction authorization.
- [ ] Accepted/open coordination authorizes owner ↔ requester.
- [ ] Scambio authorization ends when the canonical request/coordination relationship ends.
- [ ] Closing the listing does not prematurely revoke accepted/open counterpart access.
- [ ] Historical chat visibility does not itself perpetuate photo authorization.
- [ ] Public listing exact-object delivery remains canonical/non-enumerable.
- [ ] Replaced photo objects and bucket listing remain denied.
- [ ] Existing Project photo authorization from 08A3/08A4A is preserved.
- [ ] Legacy records without photos are not rewritten/deleted.
- [ ] Relevant photo caches invalidate on relationship/account changes.
- [ ] DB, verifier, Flutter, web/site regression validation passes, or inherited unavailable/failing checks are reported precisely.
- [ ] Affected docs/roadmap are updated.
- [ ] This prompt is archived unchanged.
- [ ] PR remains unmerged.

---

# Validation

Use current repository commands after inspection. At minimum, where applicable:

```bash
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

npm run profile:verify:local
npm run profile:photo:verify:local
npm run profile:photo:viewer:verify:local

# current Scambio-Dona listing/request/chat/exchange/loan verifiers
# inspect package.json and run all affected canonical commands

npm run check:web
npm run check:site
npm run check:mobile
flutter build apk --debug
git diff --check
```

Run `npm run check:db` as a diagnostic if repository policy expects it. If it still fails only through the PR #101 inherited sequential fixture-isolation issues, record the exact first failure and demonstrate that the affected 08A4B tests/verifiers pass from clean state.

For hosted CI, follow the same one-attempt discipline as PR #101 if GitHub still refuses runner allocation because of billing/spending limits. Do not repeatedly rerun infrastructure failures.

---

# Documentation

Update only affected documentation, likely:

- `apps/mobile/lib/features/profile_photo/README.md`;
- `apps/mobile/lib/features/resource_listings/README.md`;
- `apps/mobile/lib/features/resource_requests/README.md`;
- `apps/mobile/lib/features/resource_chat/README.md`;
- `docs/architecture/system-design.md`;
- `docs/development/database.md`;
- `docs/implementation/roadmap.md`.

Record the final semantics clearly:

```text
trust gate = canonical photo presence
audience remains user-controlled

public Project/listing contextual owner photo
≠ generic public profile photo

interactions now includes:
  Project organizer → pending/current participant
  Scambio owner → pending requester
  Scambio owner ↔ requester during accepted/open coordination
```

If 08A4B completes the currently planned 08A profile-picture slices, update roadmap status consistently while leaving native-device UX review deferred to Plan 12.

---

# Autonomy and stop conditions

Codex may choose repository-consistent:

- helper/RPC names;
- typed failure names;
- widget composition;
- exact avatar sizes/placement;
- cache invalidation mechanics;
- fixture organization.

Stop and report rather than guessing if implementation would require:

1. changing the meaning of accepted/open Resource coordination;
2. keeping photo access after coordination closes for historical-chat convenience;
3. making all `interactions` photos publicly addressable/enumerable;
4. adding service-role credentials to Flutter;
5. blocking photo removal during an active listing/request/agreement;
6. changing listing/request/agreement lifecycle rules;
7. introducing new moderation/legal/identity-verification policy.

Do not stop for ordinary implementation details that can be resolved from repository conventions.

---

# Deliverables

1. focused 08A4B branch and stacked PR;
2. forward migration(s);
3. generated type updates;
4. Flutter Scambio trust gates and contextual avatars;
5. focused DB/mobile/verifier coverage;
6. affected documentation/roadmap updates;
7. archived exact prompt;
8. completion report.

---

# Completion report

Return:

1. base/head/PR and dependency status;
2. summary of implemented behavior;
3. changed areas/files;
4. exact listing publication and request gate semantics;
5. exact pending and accepted/open Scambio `interactions` rules;
6. exact public listing-owner contextual authorization/storage semantics;
7. Flutter placement of listing owner/requester/counterparty avatars;
8. cache invalidation behavior;
9. treatment of legacy records and post-action photo deletion;
10. commands/tests run with exact results;
11. status of the inherited PR #101 sequential `check:db` and formatting diagnostics;
12. hosted validation result or infrastructure limitation;
13. warnings/deferred work;
14. commit/PR link.

Do not merge the PR.
