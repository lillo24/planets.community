# PLANETS 09C2A — Admin Moderation Consequence Controls

## Task type

Focused staff/admin UX implementation on top of the completed 09C1A + 09C1B moderation consequence backend.

This slice extends the existing authenticated Next.js `/admin` moderation case-detail workflow so authorized staff can inspect, apply, and revoke consequences through the real canonical database contracts.

It does **not** implement ordinary-user/mobile consequence history, contextual safety warnings, or consequence notification delivery. Those belong to 09C2B.

---

# 1. Exact Git base

Repository:

`lillo24/planets.community`

Required base:

- PR #125 — `09C1B: account suspension and global private-access enforcement`
- branch:
  `codex/09c1b-account-suspension`
- exact head:
  `c0548a25d39ddc77a92bc02514c83a01f731e9ae`

Suggested branch:

`codex/09c2a-admin-consequence-controls`

Open a **draft stacked PR** against:

`codex/09c1b-account-suspension`

Do not target stale `main`.

Do not merge or deploy.

If PR #125 has moved from the exact head above, inspect new commits first and stop if they materially affect moderation consequence RPCs, staff authorization, `/admin`, suspension, or case detail.

---

# 2. Current validated baseline

PR #125 is draft/unmerged and final-head CI passed.

Current verified baseline includes:

- 109 pgTAP files / 3,465 assertions;
- 24 suspension races;
- existing 36 09C1A consequence races;
- authenticated suspension/Storage/Realtime verification;
- 193-signature authenticated RPC audit;
- Mobile 1,087 tests + debug APK;
- Web 142 application tests + 27 tooling tests;
- Site 53 tests;
- full DB replay/lint/advisors/generated-type drift;
- demo reset/verify/seed/verify;
- hosted final-head Validation run passed.

09C2A should not weaken any backend/domain behavior.

---

# 3. Existing web moderation architecture

The repository already has the canonical staff interface under:

`apps/web/src/features/moderation/`

Current relevant areas include:

- `moderation-server.ts`
- `moderation-operations.ts`
- `moderation-actions.ts`
- `moderation-models.ts`
- `moderation-components.tsx`
- corresponding tests
- `/admin` queue/detail routes

The current server:

- derives authenticated user through the existing SSR/session architecture;
- verifies active staff authorization through canonical database RPCs;
- never uses browser service-role credentials;
- exposes queue/detail/evidence/note/review-state behavior;
- currently has no consequence controls.

Extend this architecture. Do not create a parallel admin app.

---

# 4. Canonical consequence backend already exists

Do not recreate consequence business logic in TypeScript.

09C1A/09C1B already provide the authoritative mutations/history:

## 09C1A

- `apply_moderation_consequence(...)`
- `revoke_moderation_consequence(...)`
- `list_moderation_case_consequence_history(...)`

Types:

- `safety_notice`
- `interaction_restriction`
- `content_hide`

## 09C1B

- `apply_account_suspension(...)`
- `revoke_account_suspension(...)`

Type:

- `account_suspension`

Backend rules already enforce:

- case state;
- canonical target derivation;
- role authorization;
- admin-only suspension;
- admin self-suspension denial;
- reason bounds;
- private note bounds;
- active uniqueness;
- locking/concurrency;
- request withdrawal;
- content hide;
- global suspension enforcement;
- identifier-only audit/outbox.

The UI/server layer must call these operations and present safe results/errors.

Do not duplicate their authorization/state machine in the browser as a security boundary.

---

# 5. Product goal

On a moderation case detail page, staff should be able to understand:

1. what consequence is currently active;
2. what consequence history exists for this case;
3. which consequence actions are valid for this case;
4. what each action will actually do;
5. which explanation will be visible to the affected user;
6. which note is staff-only;
7. how to apply or revoke the action deliberately.

No automated recommendation/ranking/scoring is needed.

Do not suggest that PLANETS has determined guilt.

Use neutral language such as:

- “Apply safety notice”
- “Restrict new interactions”
- “Hide content”
- “Suspend account”
- “Remove safety notice”
- “Remove interaction restriction”
- “Unhide content”
- “Unsuspend account”

---

# 6. Role behavior

## Moderator

An active `moderator` may apply/revoke:

- `safety_notice`
- `interaction_restriction`
- `content_hide`

They must **not** be offered functional suspension controls.

## Admin

An active `admin` may apply/revoke:

- all three above;
- `account_suspension`

Backend remains authoritative.

If role changes between render and submit, the mutation must fail safely and the UI should refresh/reload current case state.

Do not infer authority from a stale client-side role alone.

---

# 7. Case-state behavior

The backend permits apply only when case state is:

- `under_review`
- `completed`

Do not silently transition case state when staff applies a consequence.

If case is `received`:

- consequence controls should be disabled/unavailable for apply;
- explain concisely that review must be started first;
- preserve the existing explicit review-state action.

A completed case may still receive or revoke consequences.

Do not reopen a completed case automatically.

---

# 8. Consequence compatibility by case

Target compatibility is canonical backend policy.

Mirror it in UI for clarity.

## Profile-scoped consequences

These target the case's canonical `subject_profile_id`:

- Safety notice
- Interaction restriction
- Account suspension

They may be offered when the case has a valid subject profile.

Do not require the report's direct target kind to be `profile`.

## Content hide

Offer only when the case's direct target kind is:

- `project`
- `resource_listing`

Do not offer Hide content for:

- profile case;
- Project chat-message case;
- Resource request case;
- Resource chat-message case.

Do not let staff pick another arbitrary Project/listing ID.

---

# 9. Consequence effects copy

Before confirmation, staff must see concise factual effect copy.

## Safety notice

Explain:

- marks a moderator-confirmed safety notice;
- does not itself restrict the account;
- does not create a public badge;
- later contextual warning UX is separate.

## Interaction restriction

Explain:

- prevents this user from starting new Project join and Scambio-Dona Resource requests;
- withdraws their current pending outbound requests;
- existing memberships/chats/accepted Resource coordination remain.

## Content hide

Explain:

- removes the reported Project/listing from public discovery/detail;
- stops new requests and pending acceptance while hidden;
- existing pending requests remain pending;
- existing accepted relationships/history remain;
- owner lifecycle is unchanged.

Adapt the noun to Project vs Resource listing.

## Account suspension

Explain:

- admin-only;
- disables ordinary signed-in/private PLANETS access;
- pending outbound Project/Resource requests are withdrawn;
- existing memberships/roles/content/messages/agreements remain stored;
- public content is **not** automatically hidden;
- the user sees the supplied suspension reason on the suspension screen.

Do not imply data deletion.

---

# 10. Two-text-field model

Every apply/revoke form requires two clearly distinguished text areas.

## User-facing reason

Label clearly, e.g.:

**Reason shown to the user**

Help copy should state:

- the affected user can read this text;
- do not include reporter identity or staff-only evidence;
- plain text;
- backend max 2,000 chars.

## Private staff note

Label clearly, e.g.:

**Private moderation note**

Help copy:

- visible only to moderation staff;
- use for internal reasoning/evidence references;
- never shown to the affected user;
- backend max follows canonical note rule (currently 4,000 chars).

Do not prefill one field from the other.

Do not auto-copy report text into user reason.

---

# 11. Reason privacy

This is a founder-review requirement.

The UI must never accidentally expose:

- private staff note in user-facing reason area;
- report/corroboration/counterstatement bodies as auto-filled user reason;
- reporter identity;
- evidence identities;
- internal case IDs to ordinary user surfaces.

09C2A is staff-only, but the wording must make it obvious which text leaves the staff boundary later.

Tests should assert labels/help text and payload separation.

---

# 12. Current consequence/history section

Add a consequence section to the case detail.

Show:

- consequence type;
- active vs revoked;
- applied timestamp;
- revoked timestamp if any;
- staff actor if already available through canonical staff history;
- user-facing apply reason;
- user-facing revoke reason if any;
- linked private note reference/body only through existing authorized note representation.

Do not show raw database/internal identifiers unless useful for debugging and already normal in the admin design.

Prefer clear chronological presentation.

---

# 13. Active consequence controls

For an active consequence:

- do not offer Apply again;
- offer the matching revoke action when current staff role permits it.

Examples:

- active safety notice → Remove safety notice
- active interaction restriction → Remove restriction
- active content hide → Unhide content
- active suspension → Unsuspend account (admin only)

Revoke also requires:

- user-facing revocation reason;
- private staff note.

Explain that revoke does **not** resurrect prior requests or restore unrelated blocks/consequences.

---

# 14. Historical consequences

Preserve historical episodes.

A revoked historical episode should remain visible.

If no same-type active episode exists, staff may later apply a new episode through the canonical backend.

Do not visually merge separate episodes into one mutable state.

---

# 15. Multiple active consequence types

A profile may legitimately have multiple active consequence types simultaneously, e.g.:

- safety notice;
- interaction restriction;
- account suspension.

A content target may have a content hide while the profile also has a profile consequence from the same or another case.

Do not model the case as having one single “sanction state”.

Render independent consequence episodes/actions.

---

# 16. Consequences from other cases

The case-history RPC returns consequences originating from the current case.

Do not assume this is the subject's full global moderation-consequence history.

The current case page should say what it is showing.

Do not silently present “No consequences” as “This user has never had any consequence” if the backend only proves none for this case.

If a narrow staff-safe subject-level active consequence summary is genuinely required to avoid duplicate-conflict confusion and does not already exist, inspect first.

Prefer handling backend `PT409 active consequence already exists` with a clear refresh/conflict message rather than expanding backend scope unnecessarily.

Do not create a broad profile reputation/history API casually.

---

# 17. Apply UI interaction

Use an explicit deliberate flow:

1. click consequence action;
2. open dedicated modal/panel;
3. show effect summary;
4. enter user-facing reason;
5. enter private staff note;
6. confirm;
7. server action calls canonical RPC;
8. success refreshes/revalidates case detail;
9. display success feedback.

Disable duplicate submits.

Do not optimistic-update consequence state before server success.

---

# 18. Revoke UI interaction

Use a separate explicit revoke modal/panel.

Show:

- consequence being revoked;
- what revocation changes;
- what it does **not** restore.

Require:

- user-facing revocation reason;
- private staff note.

Examples:

## Restriction revoke

Explain:

- future new interactions may become possible;
- previously withdrawn requests are not restored.

## Content unhide

Explain:

- removes moderation visibility barrier;
- cancelled/closed/ended lifecycle is not reversed.

## Unsuspend

Explain:

- signed-in access may resume;
- other restrictions/blocks/content hides remain;
- revoked roles or ended relationships are not recreated.

---

# 19. Server actions

Extend the existing server-action architecture.

Likely areas:

- `moderation-actions.ts`
- `moderation-operations.ts`
- `moderation-server.ts`

Use strict input parsing.

Requirements:

- derive authenticated expected staff profile on server;
- never trust a browser-supplied staff profile ID;
- pass case/consequence IDs only after validation;
- trim inputs consistently but leave canonical bounds enforcement to backend as final authority;
- return bounded safe error kinds;
- never surface raw SQL/backend internals.

No browser-side direct Supabase mutation.

---

# 20. Error mapping

Map relevant backend failures into safe staff-facing messages.

At minimum:

- unauthorized / role changed;
- case must be under review/completed;
- invalid consequence for target;
- active duplicate conflict;
- consequence already revoked;
- self-suspension denied;
- stale/not-found case/consequence;
- generic unavailable.

On conflict/stale state:

- prompt staff to refresh/reload;
- revalidate case data.

Do not expose internal lock details.

---

# 21. Suspension role UX

Only admin should see enabled suspension controls.

For moderators, either omit suspension action entirely, or show a non-interactive “Admin only” indicator if that materially improves clarity.

Prefer not to tease an unusable destructive action.

If a suspension already exists and a moderator views the case:

- they may see the authorized history if the current staff history API allows it;
- they must not receive an actionable Unsuspend control.

Backend remains authoritative.

---

# 22. Self-suspension UX

Backend already denies admin self-suspension.

If the case subject is the signed-in admin:

- do not offer enabled Suspend account action;
- show concise “Another admin is required to suspend this account” if useful.

Do not weaken backend check.

---

# 23. Existing case evidence remains independent

Keep current case detail sections:

- report;
- notes;
- group corroboration;
- Resource counterstatement;
- review state.

Consequence UI must not:

- overwrite evidence;
- collapse evidence into a score;
- automatically pick a consequence;
- derive “recommended action”.

No automated recommendation engine.

---

# 24. No public/user mobile changes in 09C2A

Do not implement:

- mobile consequence history;
- safety-warning banners;
- restricted-action explanatory UI;
- hidden-content owner banners;
- consequence notification delivery;
- push/email consequence copy;
- user-facing general moderation status page.

Exception: the existing 09C1B suspension screen remains as-is.

Those are 09C2B.

---

# 25. No backend consequence-policy changes unless strictly necessary

Do not change:

- consequence semantics;
- locking;
- pending-request behavior;
- content lifecycle independence;
- suspension scope;
- admin-only suspension;
- reason privacy;
- Realtime suspension behavior.

If a backend read shape is insufficient for a safe staff UI, make the narrowest possible additive change and document why.

Do not weaken 09C1A/09C1B tests.

---

# 26. Styling/accessibility

Use the existing admin design system/components.

Requirements:

- responsive layout;
- keyboard-accessible modal/forms;
- proper labels;
- error association;
- clear destructive/warning semantics without sensational language;
- confirmation buttons distinguish Apply vs Revoke;
- loading/disabled state;
- no dependence on color alone.

No major admin redesign.

---

# 27. Testing

Add/update Web tests for:

## Models/parsing
- consequence-history parser;
- consequence type parsing;
- target compatibility;
- safe action-result parsing.

## Server authorization
- signed out denied;
- ordinary user denied;
- moderator behavior;
- admin behavior;
- role change between render/submit fails safely.

## Apply
- safety notice;
- interaction restriction;
- Project content hide;
- Resource content hide;
- admin suspension;
- moderator suspension unavailable/denied;
- self-suspension UI disabled and backend failure mapped;
- received case apply unavailable;
- completed case allowed;
- two text fields remain distinct.

## Revoke
- each consequence type;
- historical revoked episode not actionable;
- revoke reason/note separation;
- stale already-revoked handling.

## Rendering
- active vs historical;
- multiple consequence types;
- content-target-specific effect copy;
- no false claim of global subject history when only current-case history is shown.

---

# 28. Database validation

Even if no backend migration is needed, run the inherited DB gate because the web operations use security-sensitive RPCs:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run check:db
```

If no DB change occurs, generated types should remain unchanged.

If a narrow backend read addition is required:

```text
npm run db:types
npm run db:types:check
```

Report final counts.

---

# 29. Web validation

Run:

```text
npm run check:web
npm run test:tooling
```

or the repository's current equivalent if tooling is included automatically.

Ensure production build succeeds.

---

# 30. Mobile / Site regression

Keep cumulative confidence:

```text
npm run check:mobile
npm run check:site
```

APK rebuild is not required if no mobile/shared production code changes, unless repository gate or dependency change requires it.

No Site behavior should change.

---

# 31. Demo

If no database/public behavior changes, full demo reseed is optional unless current repository validation normally includes it.

If any backend RPC/migration changes are added, rerun:

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

Never claim it ran if it did not.

---

# 32. Hosted CI

Make the normal final-head hosted attempt.

PR #125 final-head CI is green, so investigate repository-owned failures.

Do not waive failures.

---

# 33. Documentation

Update:

- `apps/web/src/features/moderation/README.md`
- `apps/web/README.md` if necessary
- `docs/architecture/system-design.md`
- `docs/implementation/roadmap.md`
- any relevant admin/moderation docs.

Document that:

- consequences are manually controlled in `/admin`;
- moderator vs admin role differences;
- two-reason-field privacy model;
- backend remains authoritative;
- 09C2B owns ordinary-user/contextual UX and notifications.

Archive this exact prompt as:

`history-implementations/PLANETS_09C2A_admin_moderation_consequence_controls.md`

---

# 34. Roadmap

After implementation, mark:

- 09C1A — implemented/in review;
- 09C1B — implemented/in review;
- 09C2A — admin consequence controls implemented/in review;
- 09C2B — affected-user/contextual UX + notifications not started;
- 09C3 — appeals deferred;
- 09D — minimum age not started.

Plan 09 remains in progress.

---

# 35. Explicit non-goals

Do not implement:

- user-facing general consequence history;
- contextual safety notice display;
- restricted-action mobile banners;
- content-hide owner mobile banners;
- consequence notification projection;
- push/email consequence messages;
- appeals;
- minimum-age policy;
- retention/deletion policy;
- automatic recommendation/scoring;
- batch moderation;
- new consequence types.

---

# 36. Stop conditions

Stop and report before:

- making suspension available to moderators;
- allowing self-suspension;
- merging user-facing reason and internal note;
- exposing internal note/report evidence to ordinary-user surfaces;
- auto-applying a consequence from evidence;
- changing case state implicitly;
- changing consequence backend semantics to simplify UI;
- creating a broad subject reputation/history API without clear necessity;
- implementing 09C2B scope inside this PR;
- weakening current suspension/private-access enforcement.

Ordinary component/server-action/refactor choices should be resolved autonomously.

---

# 37. Acceptance criteria

- [ ] Exact base is PR #125 head `c0548a25d39ddc77a92bc02514c83a01f731e9ae`.
- [ ] Draft stacked PR targets `codex/09c1b-account-suspension`.
- [ ] Existing `/admin` case detail is extended; no parallel admin surface.
- [ ] Active consequence history is visible to authorized staff.
- [ ] Historical revoked episodes remain visible.
- [ ] Moderator can manage safety notice, interaction restriction, content hide.
- [ ] Moderator cannot suspend/unsuspend.
- [ ] Admin can manage all four consequence types.
- [ ] Admin self-suspension is not offered and remains backend-denied.
- [ ] Received cases cannot apply consequences.
- [ ] Under-review/completed cases can apply compatible consequences.
- [ ] Content hide offered only for Project/Resource-listing cases.
- [ ] Apply requires separate user-facing reason + private staff note.
- [ ] Revoke requires separate user-facing reason + private staff note.
- [ ] UI explicitly explains which reason reaches the affected user.
- [ ] No report/evidence body is auto-copied into user reason.
- [ ] Effect copy matches approved backend semantics.
- [ ] Existing accepted relationships/lifecycle independence are described accurately.
- [ ] No optimistic consequence mutation before server success.
- [ ] Role/stale/conflict errors fail safely and refresh/reload state.
- [ ] Web tests cover role, apply, revoke, privacy, compatibility, history.
- [ ] Full Web validation passes.
- [ ] DB security/regression gate passes.
- [ ] Mobile/Site regression gates pass.
- [ ] Hosted final-head CI is attempted and accurately reported.
- [ ] PR remains draft/unmerged.
- [ ] No deployment.
- [ ] No 09C2B behavior is introduced.

---

# 38. Completion report

Return:

1. Summary
2. Git — branch, final SHA, PR link/number, exact base
3. Existing admin architecture extended
4. Consequence history presentation
5. Moderator vs admin controls
6. Apply flow
7. Revoke flow
8. User-facing reason/private-note privacy
9. Safety notice UX
10. Interaction restriction UX
11. Project/Resource content-hide UX
12. Suspension UX
13. Case-state compatibility
14. Target compatibility
15. Error/stale/conflict handling
16. Accessibility/responsive behavior
17. Backend changes, if any
18. Web test/validation results
19. Database regression results
20. Mobile/Site regression results
21. Hosted CI result
22. Documentation/roadmap updates
23. Deferred 09C2B / 09C3 / 09D / Plan 10
24. Stop-worthy findings

Do not merge or deploy.
