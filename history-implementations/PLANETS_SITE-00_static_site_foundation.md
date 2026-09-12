# PLANETS SITE-00 — Static Informational Site Foundation

## Objective

Create a new, lightweight public informational-site application under the existing PLANETS monorepo, independent from the existing `apps/web` application.

The end state of this plan should be:

- a new `apps/site` workspace that builds to ordinary static assets;
- a minimal local development experience;
- repository-level scripts and CI validation for the new site;
- a basic placeholder shell ready for the later visual/content plan;
- documentation that clearly separates:
  - `apps/mobile` — primary Flutter Android/iOS product;
  - `apps/web` — existing Next.js web/admin/discovery application;
  - `apps/site` — small public informational/launch website.

This plan is only the foundation. Do not implement the final landing-page design, waitlist backend, Cloudflare production deployment, or domain cutover yet.

---

## Repository evidence to verify first

Before editing, inspect the current `main` branch and confirm the repository still matches the relevant assumptions below.

At prompt preparation time:

- the root npm workspace includes `apps/web`, while `apps/mobile` is managed separately through Flutter;
- the existing `apps/web` is a Next.js application and already contains authentication/profile/discovery behavior, so it must not be repurposed into the simple launch site;
- the accepted backend direction is Supabase/PostgreSQL with intended self-hosted Supabase production later;
- web hosting is explicitly a separate operational decision;
- the main roadmap already defers production infrastructure until after the functional and UI/UX phases;
- `AGENTS.md` requires conservative changes, repository inspection before editing, and reproducible configuration;
- `implementation_plan_sections_suggestions.md` is guidance for handoff structure, not a mandatory template.

Read at least:

- `AGENTS.md`
- `package.json`
- `package-lock.json`
- `apps/web/package.json`
- `.github/workflows/validation.yml`
- `docs/architecture/core-stack.md`
- `docs/architecture/system-design.md`
- `docs/implementation/roadmap.md`
- `docs/development/getting-started.md`
- `implementation_plan_sections_suggestions.md`

Also inspect the actual repository tree and current Git status. Do not assume file paths beyond what the current repository confirms.

---

## Status classification

### Implemented

- Flutter mobile application exists under `apps/mobile`.
- Next.js web/admin/discovery application exists under `apps/web`.
- root npm tooling and CI already validate the existing web and mobile applications.

### Accepted/intended for this mini-track

A separate, intentionally small informational website will be created under `apps/site`.

Its eventual product scope is expected to include:

- public landing page;
- PLANETS branding/logo;
- "coming soon on iOS / Android";
- `Chi siamo`;
- `Contatti`;
- privacy information;
- an email field allowing someone to request **one notification when the app launches**.

The email/waitlist behavior is **not part of SITE-00**.

### Deferred

- final visual design and copy;
- supplied PLANETS logo integration;
- Cloudflare D1;
- Turnstile;
- launch-waitlist persistence;
- any email sending;
- Cloudflare production configuration;
- `planets.community` DNS/domain cutover;
- migration/retirement of the existing WordPress site.

---

## Decisions already made

### Keep this in the existing repository

Do not create a second Git repository.

The intended ownership boundary is:

```text
apps/
  mobile/   # Flutter app
  web/      # existing Next.js web/admin/discovery application
  site/     # new lightweight informational website
```

### `apps/site` must remain lightweight and static

Use a restrained **Vite + React + TypeScript** setup unless current repository evidence reveals a concrete incompatibility.

The output must be ordinary static assets suitable for static hosting.

This task must **not** introduce:

- Next.js for `apps/site`;
- Supabase;
- a database;
- server-side rendering;
- authentication;
- Cloudflare Workers/Functions;
- D1;
- Firebase;
- analytics;
- Sentry;
- a component library;
- a routing library unless the foundation genuinely requires one.

For SITE-00, prefer the smallest working static React/Vite foundation. SITE-01 can introduce the actual page/content structure.

### Do not merge `apps/site` with `apps/web`

The existing Next.js application owns different responsibilities and already contains dynamic/product behavior.

Do not delete, simplify, redirect, or repurpose `apps/web` in this plan.

---

## Required work

### 1. Add the `apps/site` workspace

Create a new npm workspace/package for the informational site.

Use repository conventions for:

- package naming;
- TypeScript;
- ESLint;
- formatting;
- dependency version policy;
- Node/npm engines inherited from the root where appropriate.

Prefer a minimal dependency set.

Expected capabilities:

- local development command;
- type checking;
- linting;
- production build;
- deterministic output directory.

Do not add libraries merely because they may be useful later.

### 2. Add a minimal placeholder site

Create only enough UI to prove the independent site works.

A simple placeholder is sufficient, for example:

- PLANETS text/placeholder identity;
- a short note that this is the public informational site foundation;
- semantic HTML structure;
- basic responsive layout;
- a small global stylesheet/reset.

Do not attempt the final public design.

Do not fabricate `Chi siamo`, legal/privacy, or marketing copy in this plan.

Do not embed the uploaded logo yet; that is external context for SITE-01.

### 3. Root scripts and workspace integration

Update the root workspace configuration so `apps/site` is installed and validated through the existing npm workflow.

Add clear root commands, following current naming patterns, such as equivalents of:

- `dev:site`
- `check:site`

Integrate site formatting/lint/typecheck/build into the appropriate existing root checks without weakening current `apps/web` or mobile validation.

Avoid renaming unrelated scripts.

### 4. CI

Inspect `.github/workflows/validation.yml`.

Add the smallest CI change needed so a pull request cannot merge with a broken `apps/site` build/typecheck/lint state.

Reuse existing installation/cache patterns.

Do not introduce deployment from CI in SITE-00.

### 5. Formatting

Ensure the repository's format/format-check commands cover the new site source/configuration files.

Do not broaden formatting in a way that causes unrelated repository churn.

### 6. Documentation / architecture role split

Update the smallest authoritative documentation necessary to prevent future agents from confusing the new informational site with the existing Next.js web application.

Document clearly:

- `apps/site` is the minimal public informational/launch site;
- it is deliberately static-first and independently deployable;
- `apps/web` remains the existing dynamic web/admin/discovery application;
- creating `apps/site` does not select the final production host;
- Cloudflare is a later SITE-03 deployment decision, not implemented here.

Because the current architecture describes the public website using Next.js, inspect the existing ADR/document conventions and determine whether this new split requires:

- a small architecture-document update only; or
- a new ADR.

Use an ADR only if consistent with repository convention and needed to record the lasting responsibility split. Do not create ceremonial documentation.

Add a concise **Public informational site mini-track** to the implementation roadmap if that is the cleanest way to make SITE-00 → SITE-04 visible without interfering with the main 00–14 dependency chain.

If added, record approximately:

- SITE-00 — static site foundation;
- SITE-01 — public content and visual landing page;
- SITE-02 — one-time launch waitlist;
- SITE-03 — Cloudflare production deployment/domain cutover;
- SITE-04 — launch notification and waitlist retirement, deferred until app release.

Do not expand later SITE plans into implementation detail inside this task.

### 7. Development documentation

Update the nearest development documentation with the exact commands needed to:

- install dependencies;
- run the informational site locally;
- validate/build it.

Keep this concise.

---

## External context

No external resource is required to complete SITE-00.

The PLANETS logo supplied by the founder is intentionally deferred to SITE-01.

Do not block this plan waiting for:

- design files;
- logo assets;
- contact email;
- Cloudflare account access;
- domain access;
- WordPress/Serverplan access;
- privacy/legal copy.

If implementation unexpectedly requires any of those, stop and explain why rather than guessing.

---

## Non-goals

Do not implement any of the following:

- final PLANETS visual identity;
- final homepage;
- `Chi siamo` content;
- `Contatti` content;
- privacy/legal text;
- email signup form behavior;
- waitlist API;
- D1 schema/database;
- Turnstile;
- Resend;
- newsletter behavior;
- Supabase integration;
- Cloudflare Worker/Pages Function;
- Cloudflare account/project creation;
- production deployment;
- DNS changes;
- `planets.community` cutover;
- WordPress migration;
- old-site content extraction;
- SEO polish beyond minimal technically sensible defaults;
- analytics/tracking;
- cookie banners;
- changes to Flutter/mobile behavior;
- changes to the existing `apps/web` product behavior.

---

## Privacy / future waitlist guardrail

Although SITE-00 does not collect email addresses, future SITE-02 behavior has a settled product constraint that should be recorded where useful:

> The waitlist email address is collected solely to send one notification when the PLANETS app becomes available. It is not a newsletter signup and must not be reused for marketing, promotions, recurring product updates, or unrelated communications.

Do not implement storage or legal copy yet. This note exists so the foundation does not accidentally imply a general newsletter system.

---

## Implementation guidance

Keep the new app boring.

Prefer:

- conventional Vite configuration;
- TypeScript strictness consistent with the repository;
- simple CSS or the lightest existing-compatible styling approach;
- static asset imports;
- accessible semantic markup;
- no runtime environment configuration unless SITE-00 genuinely needs it.

Do not prematurely create abstractions for:

- CMS/content models;
- API clients;
- forms;
- persistence;
- navigation state;
- deployment providers.

If Vite/React introduces a material conflict with current repository tooling, stop and report the concrete conflict rather than silently choosing another framework.

---

## Testing and validation

Run the smallest complete set that proves every changed area works.

At minimum, expected evidence should include:

- clean dependency installation using repository conventions;
- `apps/site` lint;
- `apps/site` typecheck;
- `apps/site` production build;
- root site validation command;
- existing web validation remains green;
- existing formatting checks remain green;
- `git diff --check`.

If the root `check` command is modified to include SITE-00, run it if the environment permits. Do not claim mobile/database checks passed if they were not run.

Inspect the generated static build output enough to confirm it does not require a Node server.

If practical, add a small automated smoke/component test only if the foundation contains behavior worth testing. Do not add a test framework merely to test static placeholder text if that creates more infrastructure than value.

---

## Acceptance criteria

SITE-00 is complete when:

- [ ] `apps/site` exists as a separate npm workspace/package.
- [ ] It runs locally with one documented command.
- [ ] It builds successfully to static assets.
- [ ] It has its own lint/typecheck/build validation.
- [ ] Root scripts and CI include appropriate site validation.
- [ ] Existing `apps/web` behavior and architecture are untouched.
- [ ] No Supabase/backend/waitlist/deployment dependency has been introduced.
- [ ] Documentation clearly distinguishes `apps/site` from `apps/web`.
- [ ] The later SITE-01–SITE-04 sequence is recorded where appropriate.
- [ ] No production deployment or external account configuration has been performed.
- [ ] Changed areas pass their relevant validation.

---

## Autonomy and stop conditions

Codex may decide ordinary implementation details such as exact Vite file organization, CSS-file placement, and script names when consistent with repository conventions.

Stop and report instead of guessing if:

- adding `apps/site` conflicts materially with current workspace/tooling architecture;
- the current repository has already introduced another informational-site implementation that would duplicate this work;
- a framework choice would create a new recurring infrastructure cost;
- a required change would alter `apps/web` product behavior;
- the task unexpectedly requires provider credentials or domain changes.

---

## Deliverables

Produce:

1. the new static site foundation;
2. root workspace/tooling integration;
3. CI validation;
4. minimal documentation/architecture updates;
5. any roadmap/ADR update justified by repository convention;
6. a focused pull request;
7. a completion report.

Archive this prompt under the repository's established `history-implementations/` convention if that workflow is still active.

Do not merge the PR unless the active Codex/user workflow explicitly authorizes merging.

---

## Completion report

Return:

1. summary;
2. files/areas changed;
3. final `apps/site` technology and why it matched the repository;
4. root scripts and CI changes;
5. architecture/documentation changes;
6. commands/checks run and exact results;
7. external/manual setup remaining;
8. deferred SITE-01/SITE-02/SITE-03/SITE-04 work;
9. warnings or decisions that should block SITE-01;
10. PR link or commit reference.

