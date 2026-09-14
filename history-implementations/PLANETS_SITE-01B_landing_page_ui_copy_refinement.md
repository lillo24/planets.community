# PLANETS SITE-01B — Landing Page UI and Copy Refinement

## Objective

Apply a focused visual/copy refinement pass to the already-implemented PLANETS informational website after founder review of the deployed result.

This is **not** a redesign and must not change the waitlist backend, Cloudflare Worker behavior, D1 schema, Turnstile logic, privacy semantics, deployment configuration, or `apps/web` / Flutter behavior.

The task is limited to the public `apps/site` landing-page UI/content described below.

---

## Inspect first

Before editing, inspect the current branch/worktree and the current merged repository state.

At prompt preparation time, the relevant implementation is in:

- `apps/site/src/App.tsx`
- `apps/site/src/WaitlistForm.tsx`
- `apps/site/src/styles.css`
- `apps/site/public/brand/planets-logo.png`

Do not assume these paths remain unchanged if the active branch has already moved them.

Read `AGENTS.md` and current site tests before editing.

Preserve all currently working SITE-02 / SITE-02W behavior.

---

# Required changes

## 1. Move “In arrivo su iOS e Android” out of the hero eyebrow

Current behavior:

- `In arrivo su iOS e Android` appears as a small eyebrow/label immediately above the large hero title.

Desired behavior:

- remove it from that small eyebrow treatment;
- place **`In arrivo su iOS e Android`** prominently and centered **below the navigation/header and above the main hero content**;
- it should read as a clear standalone announcement, not a tiny metadata label;
- it should visually belong to the page without competing with the main hero title.

Keep it responsive and ensure the sticky header does not overlap it.

Do not duplicate the phrase elsewhere unless needed for an existing footer line.

---

## 2. Split Contatti and Privacy into distinct sections

Current behavior:

- `Contatti` and `Privacy` are two cards inside the same `section--details` section.

Desired behavior:

- `Contatti` should be its own section/divider;
- `Privacy` should begin in a **new, visually distinct section/divider below it**;
- keep both existing anchors:
  - `#contatti`
  - `#privacy`
- navigation/footer links must continue to work;
- preserve the existing privacy content and contact fallback behavior unless another requirement in this prompt explicitly changes it.

This should feel like two independent page sections, not two sibling cards in the same block.

Use the existing visual language: spacing, dividers, restrained backgrounds/borders. Do not introduce a new design system.

---

## 3. Stack the waitlist heading vertically

Current markup visually places:

- `Lista di attesa`
- `Sapere quando parte.`

side-by-side because `.waitlist__heading` is a flex row.

Desired layout:

```text
Lista di attesa
Sapere quando parte.
```

That is:

- `Lista di attesa` remains the smaller kicker;
- `Sapere quando parte.` remains the heading;
- place them vertically, with the title under the kicker;
- keep sensible spacing and responsive behavior.

Do not change the actual waitlist submission behavior.

---

## 4. Configuration message must disappear completely in a configured environment

Current `WaitlistForm` correctly renders:

> `La lista di attesa non è configurata in questo ambiente.`

only when no Turnstile site key exists.

Preserve that useful development/failure-state behavior.

But explicitly ensure:

- when the Turnstile site key is configured, **no “configured environment” status text or replacement message is shown**;
- the configuration warning should simply be absent;
- the user should see the normal Turnstile/waitlist UI.

Add or adjust a focused test if useful to guarantee that configured state does not render the unconfigured warning.

Do not remove the warning from genuinely unconfigured development environments.

---

## 5. Replace the top-left multicolor dot with a miniature PLANETS logo mark

Current header brand uses:

```tsx
<span className="brand__dot" aria-hidden="true" />
<span>PLANETS</span>
```

The founder does not want the generic multicolor dot.

Replace the **header's top-left brand mark** with the same real PLANETS logo already used in the hero:

`/brand/planets-logo.png`

### Visual treatment

The small header logo should:

- be genuinely small/icon-like;
- sit immediately to the left of `PLANETS`;
- remain crisp at header size;
- reuse the visual idea of the hero's `logo-stage`:
  - soft organic/circular border;
  - pale/rainbow “unicorn” gradient background;
  - subtle border/shadow;
- be simplified for the tiny header size:
  - no orbit rings;
  - no large animation;
  - no unnecessary decoration that makes the nav taller.

Prefer a small reusable CSS treatment rather than duplicating a large amount of `.logo-stage` CSS.

Do not create, redraw, recolor, or generate a new logo.

### Scope

The request is specifically for the **top-left header brand**.

Do not change the footer mark unless there is a strong consistency reason and the visual result is clearly better; avoid broadening this patch unnecessarily.

Maintain the existing accessible header link label.

---

# 6. Apply the founder's exact text-shift chain

There are currently four relevant phrases in the page:

### A — current hero lead
> `PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.`

### B — current hero support
> `Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.`

### C — current hero visual caption
> `Persone, idee e luoghi che si incontrano.`

### D — current “principle of PLANETS” about-note
> `Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.`

The founder wants these shifted **one position upward/backward through the current visual slots**, with the final old slot removed.

Implement exactly:

### Hero lead becomes C

```text
Persone, idee e luoghi che si incontrano.
```

### Hero support becomes A

```text
PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.
```

### Hero visual caption becomes D

```text
Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.
```

### Remove B entirely

Delete this sentence from the page:

```text
Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.
```

### Remove the old D/about-note slot entirely

Because D has moved to the hero visual caption, remove the existing separate `about-note` block that currently contains D.

Do **not** leave an empty decorative card/aside behind.

The rest of the `Chi siamo` copy should remain intact unless tiny layout adjustments are necessary after removing the aside.

---

# Design constraints

Keep the existing overall visual direction:

- light background;
- dark typography;
- PLANETS rainbow accents;
- generous whitespace;
- existing hero composition;
- existing logo stage;
- existing typography family;
- existing responsive behavior.

Do not:

- redesign the whole hero;
- change the large hero title `Le idee prendono vita, insieme.`;
- replace the logo;
- add a UI framework;
- add animation libraries;
- add new dependencies unless unavoidable;
- modify waitlist API behavior;
- modify D1/Turnstile/Worker configuration;
- modify privacy/data semantics;
- touch `apps/web` or `apps/mobile`.

---

# Responsive / accessibility checks

Verify at minimum:

- desktop/wide layout;
- narrow mobile layout;
- header brand mark remains legible and does not increase header height excessively;
- centered “In arrivo…” announcement does not collide with the sticky nav;
- new Contatti and Privacy sections have correct anchor scroll positions;
- waitlist heading remains visually clear on mobile;
- moved hero caption wraps cleanly despite being longer than the previous caption;
- no horizontal overflow;
- keyboard navigation/focus remains intact;
- logo image has appropriate accessible semantics without duplicate noisy announcements.

Respect existing reduced-motion handling.

---

# Tests / validation

Update existing site tests only where the intentional copy/layout structure changes require it.

At minimum verify:

- old removed copy B is no longer rendered;
- hero lead contains `Persone, idee e luoghi che si incontrano.`;
- hero support contains the PLANETS community sentence;
- hero caption contains the `Ogni persona porta qualcosa...` sentence;
- the old about-note instance is gone;
- Contatti and Privacy anchors still exist separately;
- configured waitlist state does not display the unconfigured-environment warning;
- header uses the actual PLANETS logo rather than the old decorative `brand__dot`.

Run the repository's relevant site checks and formatting checks, including at least:

- site tests;
- lint;
- TypeScript;
- static build;
- relevant root validation;
- `git diff --check`.

Perform manual visual QA at representative mobile and desktop widths.

---

# Documentation

This is a UI/copy refinement patch, not a new architecture decision.

Do not create an ADR or a new roadmap phase for it.

Only update documentation if current docs explicitly reproduce UI/copy that becomes inaccurate.

Archive this prompt under the repository's existing `history-implementations/` convention if that remains standard.

---

# Git / PR behavior

This task must be visible on GitHub.

Required:

1. implement on an isolated branch/worktree;
2. commit;
3. push;
4. open a focused GitHub PR against current `main`;
5. wait for required CI.

**Leave this PR open for founder visual review. Do not auto-merge it**, even if CI is green, because this task consists primarily of subjective UI changes that the founder explicitly wants to inspect in the deployed/local result.

Do not finish with local-only work.

---

# Completion report

Return:

1. summary;
2. branch/commit and GitHub PR URL;
3. files changed;
4. exact text substitutions/removals performed;
5. header logo implementation;
6. new “In arrivo…” positioning;
7. Contatti/Privacy section split;
8. waitlist heading/configuration-state behavior;
9. automated checks and results;
10. manual desktop/mobile visual QA;
11. any visual point the founder should specifically inspect before merging.
