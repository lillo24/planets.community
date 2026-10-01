# PLANETS 07C3 — Shared Project Workspace Link + Chat Organization Tools

**Roadmap area:** PLANETS 07 — Project coordination / delegated management  
**Task type:** Shared Project organization link domain + Flutter group-info/chat UX  
**Repository:** `lillo24/planets.community`  
**Required base at prompt creation:** PR #113 head `c288334bf8b31bce0d40a34711fbea0bc4094c0b` (`codex/07c2e-cocreator-structural-ux`)  
**Preferred branch:** `codex/07c3-project-shared-workspace`  
**Do not merge the implementation PR.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_07C3_project_shared_workspace.md
```

---

## 0. Objective

Give each Proposal/Tavolo Project one optional **shared external workspace link** for organizational material that does not belong in PLANETS chat.

Typical use:

```text
Project group
  → Shared workspace
  → Google Drive shared folder
```

but the stored concept must remain provider-neutral so it can also point to:

```text
Google Docs
OneDrive
Dropbox
Nextcloud
Notion
another HTTPS shared workspace
```

After 07C3:

- each Project can have zero or one shared-workspace URL;
- Creator, Co-creator, and Co-organizer can add/change/remove it;
- current Project participants can view/open it;
- former participants cannot retrieve it after their current entitlement ends;
- managers can configure it before the first participant joins, from Project Manage;
- Group info has a clear Shared workspace section;
- current chat has a compact organization-tools strip with Needs + Workspace;
- the existing Needs control is reused/moved rather than duplicated;
- external links open outside PLANETS through a safe, explicit user action;
- PLANETS still stores no files, images, documents, or attachments for this feature.

This is deliberately the lightweight answer to heavy collaborative files in chat.

---

## 1. Why this task uses PR #113, not the media/demo stack

The recently completed cover/demo work is on a separate open stack:

```text
PR #115 → PR #112 → PR #110 → PR #106 → 08A stack
```

Shared workspace is independent of cover media.

Its material dependency is the current delegated Project authority model:

```text
PR #113 — 07C2E
head c288334bf8b31bce0d40a34711fbea0bc4094c0b
```

That stack already distinguishes:

```text
Creator
Co-creator
Co-organizer
ordinary participant
former participant
```

and provides the canonical Project-management authorization helpers.

Therefore:

1. fetch remote;
2. verify PR #113/head;
3. create this branch from that exact commit unless the founder explicitly supplies a newer equivalent base;
4. target the new stacked PR to `codex/07c2e-cocreator-structural-ux`;
5. do not merge PR #113 or dependencies;
6. do not merge the cover/demo stack into this task;
7. do not clean/reset unrelated founder/Codex worktrees.

Later stack reconciliation can combine these independent feature lines.

---

## 2. Verified authorization model on the base

PR #113 / its delegate stack already defines:

```text
ProjectManagementRole.creator
ProjectManagementRole.coCreator
ProjectManagementRole.coOrganizer
ProjectManagementRole.none
```

with:

```text
isManager
  = Creator | Co-creator | Co-organizer

hasStructuralAuthority
  = Creator | Co-creator
```

Backend helper semantics include:

```text
private.profile_is_project_manager(project_id, profile_id)
```

which means immutable Creator or a current, non-revoked delegated manager.

This task is an **operational coordination tool**, not a structural Project-content edit.

Therefore the settled mutation rule is:

```text
Creator      → can manage workspace
Co-creator   → can manage workspace
Co-organizer → can manage workspace
```

Do not restrict workspace management to structural authority.

Do not grant workspace management to ordinary participants.

---

## 3. Read authorization

The shared workspace may contain private organizational files.

It is **not public Project metadata**.

Readers should be:

```text
current Project managers
OR
current Project participants
```

Readers should NOT include:

```text
anonymous users
signed-in unrelated users
pending applicants
rejected/withdrawn applicants
former participants after leave/removal
```

The existing Project chat authorization already has the useful conceptual distinction:

```text
current entitlement
history entitlement
```

Former members retain authorized historical chat, but they must **not** retain the shared workspace URL merely because they can read old messages.

Use current relationship truth, not historical chat entitlement.

A clean backend helper may be equivalent to:

```text
private.profile_can_read_project_workspace(project_id, profile_id)
  = profile_is_project_manager(...)
    OR profile_has_current_project_membership(...)
```

Do not make the read depend on the existence of the Project chat row because managers should be able to configure the workspace **before the first accepted participant activates chat**.

---

## 4. Data model

Add one canonical optional workspace row per shared Project identity.

A strong likely shape is:

```text
public.project_shared_workspaces
```

keyed by:

```text
project_id uuid primary key
  → public.projects(id)
```

with conceptually:

```text
workspace_url text not null
created_at timestamptz
updated_at timestamptz
```

Optionally retain `updated_by_profile_id` if it materially improves canonical provenance/audit behavior, but do not duplicate data without reason.

Requirements:

- one row max per Project;
- cascade with Project deletion where consistent;
- RLS enabled;
- direct grants fail closed;
- no public select;
- no provider-specific schema;
- no OAuth token;
- no Drive file ID;
- no refresh/access token;
- no cached external-file metadata;
- no list of multiple links in this slice.

Do not add the URL directly to both `proposals` and `recurring_activities`; the existing `projects` anchor is the shared identity for this cross-Project capability.

---

## 5. URL contract

Store one **absolute HTTPS URL**.

Recommended constraints:

```text
trimmed
1..2048 chars
starts with https://
contains no whitespace/control characters
```

The Flutter client should additionally parse it strictly with `Uri` and require:

```text
scheme == https
host is non-empty
userinfo is empty
```

Do not whitelist Google domains in the backend.

Provider-neutral links are intentional.

Reject:

```text
http://
javascript:
data:
file:
relative URLs
embedded username:password@
empty/malformed hosts
```

Do not fetch the URL server-side to validate it.

Do not perform link previews or HEAD requests.

That avoids SSRF, connectivity dependence, and accidental leakage of private share URLs.

Store the normalized trimmed URL exactly enough that ordinary provider query parameters/fragments continue to work.

---

## 6. Treat the URL as group-sensitive data

A shared-drive URL can itself contain an opaque share identifier.

Therefore:

- never put the raw URL into audit metadata;
- never put it into outbox events;
- never include it in notifications;
- never log it in analytics/crash breadcrumbs;
- never expose it in public Project list/detail;
- never put it into chat message history;
- never include it in generated invitation links.

If an audit event is useful, record identifiers only, conceptually:

```text
project.workspace_set
project.workspace_cleared

project_id
actor_profile_id
```

The URL itself must stay out of generic audit/outbox payloads.

No notification is required when the link changes in this slice.

---

## 7. Canonical RPC boundary

Add narrow expected-identity-bound functions.

Exact names may follow repository conventions, but conceptually:

### Read

```text
get_own_project_shared_workspace(
  p_expected_profile_id,
  p_project_id
)
```

Returns zero/one row:

```text
project_id
workspace_url
updated_at
```

Authorization:

```text
manager OR current participant
```

Unauthorized/missing access should fail closed without revealing whether a workspace exists.

### Set / replace

```text
set_project_shared_workspace(
  p_expected_manager_profile_id,
  p_project_id,
  p_workspace_url
)
```

Authorization:

```text
current Project manager
```

Meaning Creator, Co-creator, or Co-organizer.

Validate canonical URL shape in the backend.

Use row/Project locking consistent with current mutation patterns so concurrent manager updates are deterministic.

Return canonical state.

### Clear

```text
clear_project_shared_workspace(
  p_expected_manager_profile_id,
  p_project_id
)
```

Manager-only.

Prefer deterministic/idempotent semantics according to repository conventions.

Do not require that Project chat already exists.

---

## 8. Project lifecycle

Do not make workspace availability depend on Proposal/Tavolo authoring editability.

This link can be useful for:

```text
planning before first participant
live coordination
post-event shared photos/material
```

Therefore current manager role is the mutation authority even when the Project's structural editor is no longer editable, unless an existing canonical Project state makes the Project itself unavailable/deleted.

Likewise, current participants may read it while they remain current participants.

The Project's historical lifecycle must not turn former participants into current readers.

This is intentionally different from structural content editing.

---

## 9. No Google account connection

This task stores a link only.

Do **not** implement:

- Google OAuth;
- Google Drive API;
- Drive file listing;
- file uploads into Drive;
- Drive permissions;
- PLANETS-owned Drive folders;
- automatic folder creation;
- OneDrive/Dropbox APIs.

PLANETS should explain that the external service owns its own access permissions.

If the organizer links a folder that is not shared correctly, PLANETS cannot fix those permissions.

The user experience should say this clearly but briefly.

---

## 10. Flutter feature boundary

Create a small dedicated feature such as:

```text
apps/mobile/lib/features/project_workspace/
  domain/
  data/
  application/
  presentation/
```

or the closest repository-consistent equivalent.

It should own:

```text
workspace model
URL validation
Supabase RPC gateway
identity/project-scoped controller
external URL launcher abstraction
workspace view/edit section
open-link confirmation UI
```

Do not put generic URL-launch logic directly into Project chat widgets.

Do not make Project chat own the database mutation.

---

## 11. State and identity safety

Workspace URL is private relationship-scoped state.

The controller/provider must be scoped to:

```text
expected profile ID
project ID
```

On:

```text
account switch
entitlement loss
delegate revocation
participant leave/removal
```

clear the cached private workspace state and reject late async responses.

A former member must not see the previous URL flash while Group info/chat rerenders as read-only.

Do not persist the raw workspace URL to SharedPreferences or another device-level cache.

In-memory state is sufficient.

---

## 12. Project Manage surface

`ProjectManageScreen` is already accessible to all managers.

Add a clear card:

```text
Shared workspace
```

available to:

```text
Creator
Co-creator
Co-organizer
```

The card should exist even before the first participant/chat exists.

Conceptual states:

### Not configured

```text
Shared workspace
Add a Google Drive or another shared folder for project materials.
[Add]
```

### Configured

```text
Shared workspace
drive.google.com
[Open] [Edit]
```

Tap may route to a dedicated workspace management screen.

Do not hide this card from Co-organizer merely because Co-organizer lacks structural-authoring rights.

Preserve all current Project Manage actions and role checks.

---

## 13. Workspace management screen

Provide a compact manager-only editing surface.

Fields:

```text
Shared workspace link
```

Helper copy conceptually:

```text
Add a Google Drive, OneDrive, Dropbox, Nextcloud, Notion, or another shared HTTPS workspace.
PLANETS stores only the link; access permissions are managed by that service.
```

Actions:

```text
Save
Remove link
```

When configured, show the parsed host/domain.

Validation errors should distinguish:

```text
invalid URL
HTTPS required
link too long
could not save
authorization changed
```

Do not expose raw backend errors.

Remove should use confirmation because participants may depend on the link.

No link title/category/provider picker in this slice.

---

## 14. Group info surface

Current Group info is the main durable place for Project coordination details.

Add a clear section after Project identity/management actions and before or near meeting/commitment details:

```text
Shared workspace
```

### Current participant / manager + configured

Show:

```text
Shared workspace
drive.google.com
[Open workspace]
```

Managers additionally get:

```text
[Edit]
```

### Manager + not configured

Show:

```text
Shared workspace
No workspace added yet.
[Add workspace]
```

### Current participant + not configured

A short neutral empty state is acceptable:

```text
No shared workspace has been added yet.
```

Do not suggest that the participant can add it.

### Former member / no current entitlement

Do not show the URL.

Prefer omitting the Shared workspace section entirely rather than revealing that a private current resource exists.

Do not call the workspace read RPC for a known former member.

---

## 15. Chat organization-tools strip

Add a compact horizontally scrollable organization-tools strip for **current-entitled** Project chat users.

Place it above the message history, below connection/error banners.

Initial tools:

```text
[ Needs ] [ Workspace ]
```

The strip should be visually light and extensible for future group organization actions.

### Needs

The current Needs control lives in the composer.

Move/reuse it in the organization-tools strip.

Preserve all existing behavior:

- uncovered count;
- attention state;
- one-shot pulse/reduced-motion behavior;
- same Needs drawer;
- current-entitlement restriction;
- accessibility semantics.

Do **not** leave a duplicate Needs button in the composer.

The message composer should become text/send focused.

### Workspace — configured

Current managers and participants see:

```text
Workspace
```

Tap:

```text
confirmation
→ open externally
```

### Workspace — not configured

Manager:

```text
Add workspace
```

which opens the manager workspace screen.

Ordinary participant:

- omit the Workspace chip/button when no link exists, rather than showing an unusable control.

### Former member

The organization-tools strip is current-coordination UI.

Do not show Needs or Workspace to former/read-only members.

Keep the existing Group info access for historical/read-only context.

---

## 16. External opening UX

Add `url_launcher` or the repository-appropriate Flutter package if no existing safe launcher exists.

Wrap it behind an injectable abstraction so widget/controller tests do not launch real external apps.

Open URLs using the external browser/provider app rather than an embedded PLANETS webview.

Before leaving PLANETS, show a small confirmation dialog:

```text
Open external workspace?
This link is managed outside PLANETS.

drive.google.com

[Cancel] [Open]
```

Display only the hostname in explanatory UI where possible; do not unnecessarily expose long opaque share tokens on screen.

If launch fails:

- keep PLANETS usable;
- show localized safe feedback;
- do not modify canonical workspace state.

Do not use `canLaunchUrl` as a substitute for actual launch success if plugin guidance discourages it.

---

## 17. Provider labeling

The stored data remains one generic URL.

Client presentation may infer familiar labels from the hostname, for example:

```text
drive.google.com / docs.google.com → Google Drive
onedrive.live.com / sharepoint.com → OneDrive
dropbox.com                       → Dropbox
```

but this is optional presentation sugar.

Do not persist `provider = google_drive`.

For unknown providers, display the normalized hostname.

Never reject a valid HTTPS workspace merely because the host is unfamiliar.

---

## 18. Refresh behavior

No Realtime event/notification is required in this first slice.

Canonical refresh points:

- workspace management save/remove updates its local canonical state;
- returning from management to Group info/chat should show the updated link;
- Group info opening reloads;
- chat initial load loads workspace for current-entitled users;
- pull-to-refresh reloads it;
- app resume may refresh it if this fits the existing chat resume flow without adding complexity.

Another manager changing the link on another device does not need instant Realtime propagation in 07C3.

Do not add another Realtime channel.

---

## 19. Existing chat behavior to preserve

Do not change:

- human message schema;
- message max length;
- mixed message/system history;
- historical frontier;
- Realtime message hints;
- requirement resurfacing system events;
- read-only former-member history;
- Project chat notification projection.

Workspace URLs must never become chat messages.

No attachments.

No link previews.

No auto-post such as “Giulia changed the Drive link” in message history.

---

## 20. Existing delegated authority to preserve

Do not modify role semantics.

In particular:

```text
Co-organizer
  can manage workspace
  can manage participation
  cannot structurally edit Project content

Co-creator
  can manage workspace
  can manage participation
  retains current structural powers

Creator
  can manage workspace
```

Revocation/demotion behavior:

- demoting Co-creator → Co-organizer does NOT remove workspace-management ability;
- revoking delegated authority removes manager-based workspace mutation immediately;
- if that profile is separately a current participant, it may still read the link as a participant;
- participation Leave does not remove delegated manager ability;
- role revocation does not remove ordinary current membership.

Keep delegated authority independent from participation exactly as PR #113 defines.

---

## 21. Data/security tests

Add pgTAP structural coverage for:

- canonical workspace table;
- project PK/FK;
- one row per Project;
- URL bounds/shape;
- RLS enabled;
- direct grants fail closed;
- expected RPC signatures/grants;
- no anonymous/public workspace read API;
- no provider/token columns.

Add access/behavior coverage for at least:

### Manager mutations

- Creator set/read/update/clear;
- Co-creator set/read/update/clear;
- Co-organizer set/read/update/clear;
- unrelated user denied;
- ordinary participant mutation denied;
- revoked delegate mutation denied;
- demoted Co-creator → Co-organizer still allowed;
- concurrent manager updates produce one canonical value;
- malformed/non-HTTPS URL rejected.

### Reads

- current participant can read;
- current manager can read before chat activation;
- pending requester denied;
- rejected requester denied;
- withdrawn requester denied;
- former participant denied after membership ends unless they separately remain a manager;
- unrelated authenticated user denied;
- anonymous denied;
- no-link returns the chosen deterministic empty shape.

### Independent role cases

- manager who is not a participant can read/manage;
- participant who is not manager can read but not manage;
- profile losing manager role but retaining current membership changes from read/write → read-only.

---

## 22. Real local verifier

Add a focused real-OTP verifier such as:

```text
scripts/verify-local-project-workspace.mjs
```

Use repository local-stack helpers.

Suggested scenario:

1. Creator creates Project.
2. Creator sets workspace before first accepted participant.
3. Co-organizer is granted authority and can change it.
4. Co-creator can change it.
5. Participant is accepted and can read.
6. Unrelated/pending profile cannot read.
7. Participant leaves and immediately loses workspace read.
8. A delegated manager who leaves ordinary participation still retains manager read/write.
9. Delegate revocation removes manager mutation.
10. If still a current participant after revocation, read remains.
11. Clear removes canonical link for all current readers.
12. No raw URL appears in generic audit/outbox payloads if audit events were implemented.

Verifier must refuse non-local/non-loopback targets.

---

## 23. Flutter data/controller tests

Cover:

- strict row parsing;
- URL validation;
- expected-profile binding;
- read call mapping;
- set/clear mapping;
- malformed response rejection;
- identity switch clears state;
- late read/save response ignored;
- entitlement loss clears link;
- manager/participant read state;
- safe failure mapping.

External launcher abstraction tests:

- valid URL passed unchanged to launcher after confirmation;
- Cancel performs no launch;
- launch failure is safe;
- no launch for invalid URL.

---

## 24. Flutter widget tests

### Project Manage

- Creator sees Shared workspace;
- Co-creator sees it;
- Co-organizer sees it;
- `none` role still fails closed as existing Manage behavior;
- add/edit navigation.

### Workspace manager

- empty form;
- invalid HTTP URL;
- malformed URL;
- valid Google Drive URL;
- generic HTTPS provider;
- Save;
- Remove confirmation;
- authorization loss;
- safe save failure.

### Group info

- configured current participant sees Open;
- manager sees Open + Edit;
- manager no-link sees Add;
- current participant no-link sees neutral empty state;
- former member does not see workspace section or URL;
- no stale URL after account switch.

### Chat tools strip

- current user sees Needs;
- Needs count/attention/pulse semantics remain;
- configured workspace button appears;
- manager without link sees Add workspace;
- participant without link has no unusable Workspace button;
- former member has no tools strip;
- Needs is no longer duplicated in composer;
- narrow widths use horizontal scrolling/wrapping safely;
- long localized labels do not break composer/history layout.

---

## 25. Localization

All new copy through the existing localization system on this branch.

At minimum:

```text
Shared workspace
Add workspace
Edit workspace
Open workspace
Workspace link
Remove workspace
Remove workspace?
No shared workspace has been added yet.
Add a Google Drive or another shared folder for project materials.
PLANETS stores only the link. Access permissions are managed by the external service.
HTTPS link required.
Invalid workspace link.
Could not save workspace.
Could not open workspace.
Open external workspace?
This link is managed outside PLANETS.
Organization tools
```

Do not hard-code production strings.

The Italian-localization work exists on a separate branch. Do not merge that branch into this task solely for translations; keep this branch consistent with its own localization setup and note later reconciliation if needed.

---

## 26. Accessibility/responsive behavior

At minimum:

- workspace actions have semantic labels;
- external confirmation announces destination hostname;
- error/save feedback uses appropriate live-region semantics;
- organization-tools strip is keyboard/focus accessible;
- horizontal tool scrolling is discoverable and does not trap focus;
- Needs attention is not communicated by color alone;
- text scaling does not clip the tool strip or editor actions;
- screen-reader users can distinguish Needs from Workspace;
- external URL token is not read aloud unnecessarily when hostname is sufficient.

---

## 27. No web UI required

This feature is for Project organization inside the mobile group experience.

No public web workspace rendering.

Generated database types may require web contract regeneration/build validation, but do not add the link to public Proposal/Tavolo web pages.

No anonymous link route.

No external workspace link in public SEO/server output.

---

## 28. Documentation

Update relevant docs, likely:

```text
apps/mobile/lib/features/project_chat/README.md
apps/mobile/lib/features/project_delegates/README.md
apps/mobile/lib/features/project_workspace/README.md
docs/architecture/system-design.md
docs/development/database.md
docs/implementation/roadmap.md
```

Document:

- one provider-neutral HTTPS workspace URL per Project;
- manager mutation matrix;
- current-member read matrix;
- former-member denial;
- pre-chat management from Project Manage;
- Group info presentation;
- chat organization-tools strip;
- Needs moved from composer into the strip;
- external service owns file permissions/content;
- no Drive API/OAuth;
- no PLANETS file attachment storage.

---

## 29. Roadmap

Add/record this as a separate follow-up after the delegated-authority stack, approximately:

```text
07C3 — Shared Project Workspace + Group Organization Tools
```

Depend on:

```text
07C2E
```

Do not falsely mark unrelated 07C/08/09 stacks merged.

While the PR is open, use the repository's existing “in progress/open PR” convention.

---

## 30. Explicit non-goals

Do not implement:

- Google OAuth;
- Drive API;
- Drive folder creation;
- uploads into external providers;
- chat file attachments;
- photo messages;
- PLANETS document storage;
- multiple Project links;
- link categories;
- rich previews;
- server-side URL fetching;
- provider webhooks;
- Realtime workspace-change signals;
- notifications for workspace changes;
- workspace analytics;
- public workspace exposure;
- Scambio-Dona shared workspace;
- Project templates;
- cover-image changes;
- demo-world changes.

---

## 31. Validation

Run repository-standard validation for database + mobile changes.

At minimum:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run project:workspace:verify:local
npm run check:mobile
flutter build apk --debug
npm run check:web
git diff --check
```

If the exact verifier command uses another repository-consistent name, add it to `package.json` and report it.

Run focused delegate/chat/workspace tests.

Hosted CI may still be blocked by the known GitHub billing/spending-limit restriction. Inspect the final-head attempt once if appropriate, document the exact status, and do not rerun unchanged infrastructure failures.

Do not claim physical-device QA.

---

## 32. Plan 12 native QA additions

Add checklist items for:

- paste/edit Google Drive and generic HTTPS links;
- malformed links and very long share URLs;
- external Google Drive app/browser launch on Android/iOS;
- Cancel/Open confirmation behavior;
- missing external app/browser fallback;
- current participant → leave while chat/info is open;
- Co-organizer revocation while workspace editor is open;
- Co-creator demotion while workspace editor is open;
- manager who is not participant;
- account switch while private workspace URL is visible;
- organization-tools strip on narrow phone/tablet;
- Needs attention indicator after relocation;
- VoiceOver/TalkBack external-link confirmation and tool navigation;
- offline state when opening external workspace.

---

## 33. Acceptance criteria

07C3 is complete only if all are true:

- [ ] One optional canonical shared-workspace URL exists per Project.
- [ ] URL is provider-neutral and HTTPS-only.
- [ ] No provider access token/OAuth data is stored.
- [ ] Creator can set/change/remove.
- [ ] Co-creator can set/change/remove.
- [ ] Co-organizer can set/change/remove.
- [ ] Ordinary participant cannot mutate.
- [ ] Current participant can read/open.
- [ ] Manager can configure before chat activation.
- [ ] Former participant cannot retrieve the link after losing current membership, unless they independently remain a manager.
- [ ] Pending/rejected/withdrawn applicants cannot read.
- [ ] Anonymous/unrelated users cannot read.
- [ ] Raw workspace URL is absent from public Project contracts.
- [ ] Raw workspace URL is absent from audit/outbox/notification payloads.
- [ ] Project Manage exposes Shared workspace to every manager role.
- [ ] Group info clearly exposes it to current entitled users.
- [ ] Group info gives managers Add/Edit controls.
- [ ] Former/read-only group info does not expose it.
- [ ] Current chat has a compact organization-tools strip.
- [ ] Existing Needs control is moved/reused there, not duplicated.
- [ ] Workspace quick-open appears only when meaningful.
- [ ] External opening shows destination host and requires explicit confirmation.
- [ ] External link opens outside PLANETS.
- [ ] Account/entitlement changes clear private workspace state.
- [ ] No Google Drive API integration exists.
- [ ] No chat attachments exist.
- [ ] Database tests cover role/read matrix.
- [ ] Real local Auth verifier passes.
- [ ] Mobile tests and Android debug build pass.
- [ ] Web generated-type/build compatibility passes.
- [ ] Docs/roadmap are updated.
- [ ] Exact prompt is archived.
- [ ] Focused stacked PR is open and unmerged.

---

## 34. Completion report

Return a concise structured report containing:

1. branch;
2. exact base commit;
3. final head commit;
4. PR number/link and target branch;
5. canonical workspace table/RPC names;
6. final URL validation contract;
7. read authorization matrix;
8. write authorization matrix;
9. Project Manage UX;
10. Group info UX;
11. chat organization-tools strip behavior;
12. how the existing Needs control was relocated without regression;
13. external URL-launch package/abstraction;
14. database/verifier/mobile/web validation results;
15. any inherited CI/environment warnings;
16. native QA items deferred to Plan 12;
17. confirmation that:
    - no Google OAuth/Drive API was added,
    - no chat attachments were added,
    - no raw workspace URL is public/logged,
    - no media/demo stack was merged,
    - the PR remains unmerged.

If a material authorization conflict with PR #113 is discovered, stop and report it instead of weakening the Creator/Co-creator/Co-organizer role model.
