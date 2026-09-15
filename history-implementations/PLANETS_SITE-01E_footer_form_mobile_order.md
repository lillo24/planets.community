# PLANETS SITE-01E — Footer Brand, Simplified Waitlist UI, Mobile Hero Order

## Goal

Apply three focused UI refinements to the public PLANETS informational site:

1. use the same real PLANETS logo mark in the footer that is already used in the top-left header;
2. simplify the waitlist form by removing its visible heading block and visible email label;
3. on mobile only, move the large PLANETS hero image between the hero title/subtitle and the email signup form, while preserving the current desktop layout.

Do not redesign the page or change any backend/deployment behavior.

---

## Inspect first

Read current:

- `AGENTS.md`
- `apps/site/src/App.tsx`
- `apps/site/src/WaitlistForm.tsx`
- `apps/site/src/styles.css`
- current site tests

Work from the latest merged site UI state.

If SITE-01D is being implemented in parallel, preserve its Turnstile-spacing and announcement-experiment work when reconciling. Do not overwrite those changes.

---

# 1. Footer: replace old multicolor dot with the real PLANETS logo mark

The header now correctly uses the real logo:

```tsx
<span className="brand__mark" aria-hidden="true">
  <img src="/brand/planets-logo.png" ... />
</span>
<span>PLANETS</span>
```

The footer still uses the obsolete:

```tsx
<span className="brand__dot" aria-hidden="true" />
```

Replace the footer dot with the **same `brand__mark` treatment and same PLANETS image used in the header**.

Preferred result:

- header and footer brand identity match;
- no old multicolor dot remains in the footer;
- reuse existing CSS/markup rather than creating a second logo style;
- keep the footer mark small and aligned with `PLANETS`.

If `.brand__dot` becomes unused everywhere after this change, remove the dead CSS.

Do not modify the large hero logo.

---

# 2. Simplify the waitlist form header/labels

Remove these visible texts from the waitlist card:

```text
Lista di attesa
Sapere quando parte.
La tua email
```

The card should visually begin directly with the email field / signup controls.

## Remove the heading block

Delete the visible waitlist heading block containing:

- `.waitlist__kicker` / `Lista di attesa`
- `Sapere quando parte.`

Remove now-unused heading/kicker CSS if it is no longer referenced elsewhere.

## Remove the visible “La tua email” label

Do **not** sacrifice accessibility.

The input still needs an accessible name.

Preferred approach:

- keep a semantic `<label>` for the email input but make it visually hidden with an existing/new reusable `.sr-only` / `.visually-hidden` utility; or
- use another semantically correct accessible-label pattern if already established in the repo.

Do not rely on the placeholder alone as the accessible label.

The field should still show:

```text
nome@esempio.it
```

as placeholder.

## Form accessible name

The current form may use:

```tsx
aria-labelledby="waitlist-title"
```

If the visible `waitlist-title` heading is removed, update the form's accessible naming correctly, for example with a concise:

```tsx
aria-label="Avviso lancio PLANETS"
```

or another equivalent semantic solution.

Do not leave dangling ARIA references.

Preserve:

- consent checkbox;
- one-email-only explanatory text;
- Turnstile;
- feedback/error/success states;
- submit button;
- all validation/submission behavior.

---

# 3. Mobile hero order: text → logo → waitlist

## Current structural problem

The hero currently conceptually contains:

```text
hero__body
  hero__content
    big title
    subtitle/lead
    WaitlistForm

  hero__visual
    large PLANETS logo
    caption
```

This naturally puts the waitlist before the large logo on mobile.

The founder wants:

### Mobile

```text
In arrivo su iOS e Android

Le idee prendono vita, insieme.
[hero subtitle]

[LARGE PLANETS IMAGE + its caption]

[email signup card]
```

So specifically:

> **big title + subtitle → large image → email subscription**

### Desktop

Keep the current desktop composition visually the same:

```text
left: title/subtitle + waitlist
right: large PLANETS logo/caption
```

Do not move the desktop waitlist below the image.

---

# Implementation approach for responsive ordering

Do this structurally and cleanly.

Do **not**:

- render two copies of `WaitlistForm`;
- use JavaScript viewport detection;
- duplicate IDs/forms;
- conditionally mount separate mobile/desktop forms.

Preferred architecture:

Make the hero text, hero visual, and waitlist form separate layout items under the hero body, then use CSS Grid/Flex ordering/areas by breakpoint.

Conceptually:

```tsx
<div className="hero__body">
  <div className="hero__content">
    <h1>...</h1>
    <p className="hero__lead">...</p>
  </div>

  <div className="hero__visual">
    ...
  </div>

  <WaitlistForm />
</div>
```

Then desktop can use a two-column grid such as:

```text
"content visual"
"waitlist visual"
```

while mobile becomes:

```text
"content"
"visual"
"waitlist"
```

Exact CSS implementation is up to Codex after inspecting current layout.

The key requirements are:

- a **single** waitlist form instance;
- mobile order is correct;
- desktop visual composition remains effectively unchanged;
- no weird vertical gap is introduced on desktop;
- large logo/caption remain together.

If a different CSS-only structure achieves this more cleanly, use it.

---

# Mobile spacing

After reordering, tune spacing so the mobile flow feels deliberate:

```text
title/subtitle
    ↓ comfortable gap
logo
caption
    ↓ comfortable gap
waitlist card
```

Do not make the logo feel glued to either adjacent section.

Preserve the current responsive logo size unless the new placement exposes a clear spacing issue.

---

# Preserve all other current site behavior

Do not change:

- hero text/copy mapping from SITE-01C;
- `In arrivo su iOS e Android` wording/behavior;
- SITE-01D static/fluid experiment if present;
- Turnstile behavior;
- D1/Worker code;
- waitlist consent semantics;
- privacy copy;
- Contatti/Privacy section split;
- Cloudflare configuration;
- `apps/web`;
- Flutter.

---

# Tests

Update focused tests to verify structure/accessibility, not exact pixels.

At minimum assert:

1. footer uses the real `/brand/planets-logo.png` brand mark and no footer `brand__dot` remains;
2. visible `Lista di attesa` is absent;
3. visible `Sapere quando parte.` is absent;
4. visible `La tua email` is absent;
5. email input still has a valid accessible name;
6. form no longer references a removed heading ID;
7. only one waitlist form/email input exists;
8. existing waitlist submission/validation tests remain green.

CSS layout ordering should be confirmed through manual responsive QA rather than brittle DOM-order pixel tests.

---

# Manual QA

Inspect at least:

### Mobile (~390px)

Confirm exact visual sequence:

1. announcement;
2. big hero title;
3. hero subtitle;
4. large PLANETS image;
5. logo caption;
6. waitlist/signup card.

Confirm there is no duplicate form and no horizontal overflow.

### Desktop (~1280px)

Confirm the current desktop composition is preserved:

- title/subtitle and waitlist remain on the left;
- large PLANETS image remains on the right;
- no large blank area caused by the new grid structure.

Also verify:

- footer logo matches header logo;
- email field remains keyboard/screen-reader accessible;
- Turnstile and feedback states still fit correctly.

---

# Validation

Run at minimum:

- site tests;
- `npm run check:site`;
- relevant formatting checks;
- `git diff --check`;
- current required CI per repository rules.

Do not alter backend behavior merely to satisfy a UI test.

---

# Git / PR behavior

Implement on an isolated branch/worktree.

Required:

1. commit;
2. push;
3. open a focused GitHub PR.

Leave the PR open for founder visual review because the responsive ordering is a visual change.

Do not finish locally only.

---

# Completion report

Return:

1. PR URL and commit;
2. footer-logo change;
3. waitlist texts removed and accessibility replacement;
4. exact responsive layout strategy used;
5. confirmation there is only one `WaitlistForm`;
6. mobile and desktop QA results;
7. automated checks;
8. anything the founder should visually inspect before merge.
