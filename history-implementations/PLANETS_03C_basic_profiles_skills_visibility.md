# PLANETS 03C — Basic Profiles, Skills, and Visibility

**Roadmap parent:** PLANETS 03 — Authentication and profiles  
**Task type:** Third and final portion of roadmap plan 03  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`

## Objective

Complete the first PLANETS profile model without over-designing identity, location, media, or taxonomy.

After this task:

- every authenticated user can complete and edit a basic profile;
- the first required user-facing profile field is a display name;
- users can optionally add a short bio;
- users can select useful skills from a small categorized catalog;
- skills include concrete starter examples such as musician and mural painting;
- users can decide whether each supported profile section is visible publicly;
- public reads expose only explicitly public profile information;
- private owner reads always expose the user's own full editable profile;
- mobile gets functional profile setup/settings/edit/display UI;
- web gets a minimal authenticated profile/settings surface sufficient to exercise the same backend model;
- profile photo remains optional and conceptually supported, but actual photo upload/storage is deferred to the dedicated media plan;
- no proposal, participation, organizer-only visibility, exact location, badges, or notification preferences are implemented.

When this PR is merged, plans 03A, 03B, and 03C are all implemented and parent plan 03 may be marked `Implemented`.

## Read before changing anything

Inspect current `main` and Git status first.

At minimum read:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/development/database.md`;
6. `docs/development/getting-started.md`;
7. `docs/implementation/roadmap.md`;
8. all existing profile migrations and pgTAP tests;
9. current generated database types;
10. 03A mobile Auth/profile-anchor implementation;
11. 03B web Auth/profile-readiness implementation;
12. Flutter routing/theme/common-state conventions;
13. Next.js version-matched `apps/web/AGENTS.md` and relevant bundled Next.js docs;
14. current Supabase skill guidance where useful.

GitHub implementation is authoritative for existing behavior.

## Product decisions resolved for 03C

This plan intentionally adopts a small first version.

### Basic profile fields

Implement:

- **display name** — required to consider a profile complete;
- **bio** — optional, short free text;
- **created_at** — existing system-managed value;
- **updated_at** — system-managed profile timestamp.

Do not add first name + last name separately.

Do not expose the authentication email as a profile field.

Do not add age, birthday, gender, profession, phone, website, social links, exact address, or other identity fields.

### Photo

A profile photo is **not required**.

The product may later require a photo for specific participation flows, and future visibility may include audiences such as proposal organizers.

However, actual media upload/storage policy belongs to plan 08.

Therefore 03C should:

- not create an ad-hoc Storage bucket;
- not upload images;
- not store arbitrary remote image URLs;
- document photo as a future optional media-backed profile field;
- make the visibility model extensible so a future `photo` field/audience can be added cleanly.

Do not add a fake photo picker that cannot persist securely.

### Skills

Skills are selectable capabilities relevant to community projects.

Use a small controlled starter catalog rather than free-form user-generated skill text.

Examples include:

- "I am a musician";
- "I know how to paint murals";
- practical/DIY abilities.

Skills are grouped into broad categories.

Use stable technical IDs/slugs and concise user-facing labels.

Suggested initial categories:

1. **Art & Creativity**
2. **Music**
3. **DIY & Practical**
4. **Gardening & Nature**
5. **Cooking & Food**
6. **Technology**
7. **Organization & Community**

Seed a small useful starter set, not an exhaustive ontology.

Examples:

**Art & Creativity**
- mural painting;
- drawing/illustration;
- photography;
- graphic design.

**Music**
- musician;
- singing;
- audio/sound setup.

**DIY & Practical**
- general handyman / practical making;
- woodworking;
- basic repairs;
- painting/decorating.

**Gardening & Nature**
- gardening;
- plant care;
- urban gardening.

**Cooking & Food**
- cooking;
- baking;
- food-event support.

**Technology**
- programming;
- electronics;
- web/design tools.

**Organization & Community**
- event organization;
- facilitation;
- communication/social media;
- fundraising/community outreach.

Exact wording can be polished minimally during implementation, but do not expand into hundreds of skills.

Do not add proficiency levels yet.

Do not allow custom free-text skill creation yet.

### Public visibility

The user can decide what ordinary public viewers can see.

For the first version support public/private visibility for:

- display name;
- bio;
- skills.

Default new profiles to:

- display name: **public**;
- bio: **public**;
- skills: **public**.

Users can change each independently.

The owner always sees their own full profile regardless of public visibility.

Future audiences such as proposal organizers, accepted participants, or authenticated users only are explicitly deferred.

Do not encode today's visibility as three unrelated booleans if doing so would make future audience expansion awkward. Prefer a small field-level visibility representation that can later accept more audience values.

For 03C, the only valid audience values are:

```text
public
private
```

Choose a database representation that can be extended safely later without forcing profile-column redesign.

## Architecture decisions

### 1. Extend the existing `public.profiles` anchor

The current table is the canonical one-to-one application identity.

Extend it rather than creating a second profile-details table merely for these few scalar fields.

Likely profile columns:

```text
display_name
bio
updated_at
```

Use sensible constraints.

Suggested boundaries:

- display name: trimmed, 2–60 characters;
- bio: nullable, trimmed, maximum about 500 characters.

Do not silently mutate casing.

Empty optional bio should canonicalize to `NULL` or another single consistent representation.

### 2. Profile completion is derived

A profile is considered complete when required profile data is valid, currently just a non-empty valid display name.

Do not add a writable `is_complete` boolean that can drift.

03A/03B currently treat existence of the skeletal profile anchor as ready. Update their readiness semantics carefully so:

- authenticated + anchor exists + required fields complete → profile ready;
- authenticated + anchor exists but required fields incomplete → profile setup required;
- authenticated + missing anchor → profile setup required/retry as today.

Do not break existing Auth sessions.

Existing users with only the skeletal anchor must naturally enter profile setup after this migration.

### 3. Normalize skills

Use relational tables rather than arrays or JSON in `profiles`.

Suggested structure:

```text
skill_categories
skills
profile_skills
```

Requirements:

- stable IDs;
- stable unique slug/key;
- category ordering;
- skill ordering;
- unique `(profile_id, skill_id)`;
- foreign keys;
- no client-controlled catalog insertion;
- authenticated users can manage only their own `profile_skills`;
- ordinary clients cannot modify categories/skills.

Catalog rows are system-managed migration data.

### 4. Visibility is field-level and future-extensible

Prefer a normalized representation such as:

```text
profile_field_visibility
  profile_id
  field_key
  audience
```

with currently supported field keys:

```text
display_name
bio
skills
```

and audiences:

```text
public
private
```

A different equally clean representation is acceptable if it preserves future extensibility.

Requirements:

- exactly one visibility setting per supported field/profile;
- defaults exist for new/completed profiles;
- users can edit only their own settings;
- clients cannot invent arbitrary field keys/audiences;
- later migrations can add `photo` or an `organizers` audience without redesigning `profiles`.

Do not build a generic policy engine.

### 5. Public reads use a sanitized API surface

Do **not** grant anonymous direct SELECT access to `public.profiles`.

Create a narrow public API surface—view or stable read function—through which anon/authenticated clients can read only publicly visible profile data.

The public representation should contain only:

- profile ID;
- display name if public, otherwise null;
- bio if public, otherwise null;
- public skills if skills are public.

It must never expose email, auth metadata, hidden values, or visibility internals.

Use the repository's fail-closed grant/RLS model.

If a SQL view is used, verify current PostgreSQL/Supabase view security behavior explicitly; do not accidentally bypass RLS because of view ownership.

If a security-definer function is safer/clearer, lock its `search_path`, validate grants, and keep its output narrow.

### 6. Owner writes are canonical named operations where helpful

Profile editing involves several related values plus skills/visibility.

Avoid fragile client sequences that can leave partial state if a named PostgreSQL function can update the profile atomically and simply.

A canonical operation may accept:

- display name;
- bio;
- selected skill IDs;
- visibility settings.

If using a database function:

- authenticate with `auth.uid()`;
- act only on current user's profile;
- validate all inputs;
- update profile + skill selections + visibility atomically;
- grant execute only as required;
- revoke default/public execute per repo conventions.

Do not make a giant future-proof JSON command.

### 7. Do not duplicate domain behavior between mobile and web

Both clients should call the same canonical database model/operation.

Flutter and Next.js own form state/presentation only.

Do not create web-only profile semantics.

## Required work

### A. Database migration

Add a new timestamped migration implementing:

- profile scalar fields;
- updated timestamp behavior;
- skill categories;
- skills;
- profile-skill relationships;
- visibility settings;
- default visibility initialization;
- canonical profile update operation if selected;
- safe public read surface;
- required indexes;
- explicit grants/revokes;
- RLS on every exposed table.

Preserve all existing fail-closed defaults.

Do not edit prior migrations.

### B. Starter skill catalog

The starter taxonomy is canonical product data and should be deterministic across environments.

Prefer migration-managed catalog rows with stable slugs rather than dev-only `seed.sql`.

Do not let normal users edit catalog labels/categories.

Document that the catalog is deliberately small and can expand later.

### C. Database tests

Add pgTAP coverage for:

- profile constraints;
- profile-completion semantics;
- owner read/write;
- other users cannot read private profile rows;
- anon cannot read `profiles` directly;
- catalog readability/mutation restrictions;
- own skill add/remove only;
- visibility constraints and ownership;
- sanitized public reads show public values and hide private ones;
- no email/auth metadata leakage;
- atomic profile update operation;
- narrow function execute grants;
- existing default-privilege/security invariants.

Regenerate public database types and enforce drift.

### D. Mobile profile feature

Create a restrained `features/profile/` implementation.

Provide:

1. **profile setup/edit**
   - display name;
   - optional bio;
   - categorized multi-select skills;
   - save;
2. **visibility settings**
   - display name public/private;
   - bio public/private;
   - skills public/private;
3. **own profile display**
   - functional, minimal representation.

After Auth:

- incomplete profiles should be recognized as setup-required;
- `/` remains public and usable;
- provide a clear setup-required affordance;
- do not globally trap a signed-in incomplete user in setup while public-first browsing is still a product rule.

Use Riverpod 3.

All visible Flutter copy goes through localization.

### E. Web profile/settings

Add a minimal authenticated route such as:

```text
/profile
```

The signed-in owner can:

- view the basic profile;
- edit display name/bio;
- select skills;
- edit visibility.

Use Server Components for initial reads where appropriate and a narrow Client Component for editing.

Signed-out access redirects safely to `/auth?returnTo=/profile`.

Do not build a public profile directory.

### F. Skill presentation

Display skills grouped by category.

Do not add proficiency, endorsements, years of experience, badges, or arbitrary tags.

### G. Visibility UX

Keep it simple:

```text
Public profile visibility

Display name   [Public / Private]
Bio            [Public / Private]
Skills         [Public / Private]
```

Avoid complicated privacy matrices.

Do not claim organizer-only sharing exists yet.

### H. Photo boundary

Prefer omitting photo controls entirely in this version.

Do not request file permissions, upload, create Storage buckets, accept arbitrary URLs, or store base64 images.

Plan 08 will implement media properly.

### I. Mobile tests

Cover:

- existing skeletal profile becomes setup-required;
- valid save completes profile;
- display-name validation;
- bio optional/limit;
- categorized skills render/select/deselect;
- saved skill state restores;
- visibility settings update;
- `/` remains public;
- signed-out profile edit requires Auth with safe return;
- errors are safe/retryable.

### J. Web tests

Cover:

- signed-out `/profile` redirects through Auth safely;
- owner profile renders;
- incomplete profile setup renders;
- edit validation;
- categorized skill selection;
- save calls canonical backend boundary;
- visibility controls;
- safe errors;
- no email/raw backend errors;
- public sanitized representation hides private fields.

### K. Integration evidence

Through database/API integration prove:

1. authenticate/create two users;
2. complete user A with bio + skills;
3. set mixed visibility;
4. anon/public read returns only public values;
5. user B cannot directly read A's private profile row;
6. user A can read/edit own full profile;
7. hidden skills/profile values do not leak.

Reuse existing local Auth tooling where useful.

### L. CI

All existing Mobile/Web/Database checks stay green.

Add new profile tests and generated-type drift validation.

Do not require hosted providers.

### M. Documentation and roadmap

Update docs with:

- scalar profile model;
- completion rule;
- skill catalog;
- visibility model;
- sanitized public API;
- photo deferral;
- future organizer-only audience deferral.

While the PR is open:

- 03A → `Implemented`;
- 03B → `Implemented`;
- 03C → `In progress`;
- parent 03 → `In progress`;
- 04 → `Not started`.

After merge, mark 03C and parent 03 `Implemented`.

## Explicitly deferred

Do not implement:

- profile photo upload/storage;
- organizer-only or participant-only visibility;
- exact location/address/postal matching;
- age/birth date;
- phone/social links;
- skill proficiency/endorsement;
- free-form custom skills;
- user-created categories;
- badges;
- participation stats;
- notification preferences;
- public profile directory/search;
- proposal-specific profile requirements;
- proposal/discovery;
- account deletion;
- moderation/admin.

## Future compatibility

### Photo

A future media-backed photo field should reuse the profile visibility/audience concept.

Do not model photo now through unsafe URL storage.

### Organizer-only visibility

Future participation may add an audience such as:

```text
organizers
```

for photo or other fields.

Do not implement it until proposal ownership/membership semantics exist.

### Skills and proposal requirements

Plan 04 will likely reference the **same skill catalog** for required/useful proposal skills.

Do not create a profile-local taxonomy that forces a second unrelated skill model later.

## Acceptance criteria

03C is ready for merge when:

- [ ] existing `profiles` anchor is extended;
- [ ] display name is the only required new user-facing field;
- [ ] bio is optional and constrained;
- [ ] completion is derived;
- [ ] starter categorized skill catalog exists;
- [ ] catalog includes musician, mural painting, and practical/DIY examples;
- [ ] profile skills are relational and unique;
- [ ] normal clients cannot mutate catalog definitions;
- [ ] public/private visibility exists for display name, bio, and skills;
- [ ] visibility can later add new fields/audiences;
- [ ] owner always sees full own profile;
- [ ] anon cannot directly SELECT private profile rows;
- [ ] sanitized public API exposes only public fields;
- [ ] no Auth email or metadata leaks;
- [ ] mobile profile setup/edit/visibility works;
- [ ] web profile/settings works;
- [ ] incomplete profiles are recognized after Auth;
- [ ] `/` remains public-first;
- [ ] photo Storage is not pulled into 03C;
- [ ] organizer-only semantics are not invented;
- [ ] database/mobile/web tests pass;
- [ ] local integration proves visibility isolation;
- [ ] generated DB types are updated;
- [ ] existing Auth integration stays green;
- [ ] parent plan 03 remains in progress until merge.

## Autonomy and stop conditions

You may decide:

- exact SQL names;
- exact stable skill slugs;
- exact small starter-skill wording;
- exact relational visibility representation;
- exact atomic database operation shape;
- exact `/profile` component decomposition;
- exact Flutter profile route names;
- exact small test seams.

Stop and report before:

- adding actual photo Storage;
- introducing organizer/participant access semantics;
- adding precise location/address;
- making multiple identity fields mandatory;
- adding free-form user-generated skills;
- changing Auth behavior;
- adding public profile search/directory;
- introducing a second skill taxonomy for proposals;
- weakening RLS/grants;
- absorbing plan 04.

## Deliverables

Produce:

1. profile/skill/visibility migration;
2. starter categorized skill catalog;
3. RLS/grants/sanitized public read surface;
4. database tests;
5. regenerated DB types;
6. mobile profile setup/edit/visibility;
7. web profile/settings;
8. profile-completion integration with Auth state;
9. profile-focused tests;
10. visibility-isolation integration evidence;
11. documentation/roadmap updates;
12. focused PR, preferably `codex/03c-basic-profiles-skills-visibility`;
13. completion report.

Do not merge the PR yourself unless explicitly instructed.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Database profile model**
4. **Profile completion rule**
5. **Skill categories/catalog**
6. **Profile-skill model**
7. **Visibility model**
8. **Public sanitized API**
9. **RLS/grants**
10. **Mobile profile flow**
11. **Web profile/settings flow**
12. **Photo/media deferral**
13. **Future organizer-only compatibility**
14. **Tests**
15. **Integration evidence**
16. **Validation/CI**
17. **Manual/external setup**
18. **Deferred work**
19. **Warnings/blockers for plan 04**
20. **Pull request/commit reference**

Do not report parent plan 03 as implemented until this PR is merged.
