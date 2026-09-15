# PLANETS SITE-01D — Turnstile Spacing + Announcement Scale + Fluid Rainbow Experiment

## Goal

Apply three small visual refinements to the public PLANETS informational site:

1. center the Cloudflare Turnstile widget and remove the excessive empty space at the bottom of the waitlist card;
2. make the `In arrivo su iOS e Android` announcement substantially larger, especially on desktop;
3. add a **temporary visual toggle** that lets the founder compare:
   - the current static rainbow announcement background;
   - a new experimental animated/fluid rainbow background.

This is a UI experiment only.

Do not change waitlist semantics, Worker/D1/Turnstile backend behavior, privacy logic, deployment configuration, `apps/web`, or Flutter.

---

## Dependency / current branch

Implement this after SITE-01C has been applied, or on the active site UI branch that already contains the founder-approved corrected text-container mapping.

Before editing, inspect current:

- `AGENTS.md`
- `apps/site/src/App.tsx`
- `apps/site/src/WaitlistForm.tsx`
- `apps/site/src/TurnstileWidget.tsx`
- `apps/site/src/styles.css`
- relevant `apps/site/src/*.test.tsx`

Preserve all approved SITE-01B/SITE-01C changes.

---

# 1. Center the Cloudflare Turnstile widget

Current Turnstile markup uses:

```tsx
<div className="cf-turnstile waitlist__turnstile" ... />
```

and current CSS only gives `.waitlist__turnstile` a minimum height and top margin, so the rendered Cloudflare widget appears left-aligned.

## Desired result

Center the rendered Turnstile widget horizontally inside the waitlist card.

Prefer a simple CSS solution on the existing wrapper, e.g. an appropriate flex/grid centering treatment.

Do not:

- modify Cloudflare's injected iframe itself unless necessary;
- hard-code iframe dimensions;
- break responsive mobile width;
- alter Turnstile behavior or callbacks.

---

# 2. Reduce the excessive empty space at the bottom of the waitlist card

The founder wants the white-space rhythm of the card to feel approximately balanced:

```text
top card border
   ↓
top content

...

Turnstile / feedback content
   ↓
bottom card border
```

The bottom should not have visibly more empty space than the top.

Current CSS includes:

```css
.waitlist {
  padding: clamp(...);
}

.waitlist__turnstile {
  min-height: 65px;
  margin-top: ...;
}

.waitlist__feedback {
  min-height: 1.4em;
  margin-top: ...;
}
```

The empty feedback area appears to be contributing to the blank bottom region when there is no message.

## Desired behavior

- center Turnstile;
- reduce the idle-state bottom whitespace;
- keep the normal card padding aesthetically balanced;
- preserve enough space for actual success/error/submitting feedback when it exists.

Prefer to make the feedback area collapse or reserve less space **when empty**, rather than globally crushing the card padding.

For example, a selector such as `:empty` or state-aware styling may be appropriate if compatible with the actual DOM.

Do not remove the `aria-live`/status behavior or make error/success messages overlap surrounding content.

Manually inspect both:

- idle state with no feedback;
- visible error/success feedback.

---

# 3. Make the “In arrivo su iOS e Android” announcement larger

The current announcement pill is visually good but too small relative to the hero, especially on desktop.

## Mobile

Increase it **slightly**:

- a little larger font;
- a little more horizontal and vertical padding;
- keep it comfortably inside narrow screens;
- do not let it dominate the mobile hero.

## Desktop

Increase it **substantially**.

The current desktop screenshot makes the announcement look like a small chip floating in a large amount of space. It should instead feel like a deliberate top-level launch announcement.

Use responsive CSS rather than hard-coded separate components.

Preferred direction:

- larger font on wide screens;
- noticeably larger padding;
- larger minimum visual footprint / width if useful;
- preserve the pill shape;
- keep it centered;
- still leave strong visual hierarchy beneath it for the hero title.

Use `clamp()` / media queries as appropriate.

Do not stretch it to full page width.

---

# 4. Add a temporary static-vs-fluid visual toggle

The founder wants to compare two versions before deciding.

Add a small temporary segmented/toggle control associated with the announcement:

```text
Sfondo:
[ Attuale ] [ Fluido ]
```

Exact labels can be slightly refined, but the distinction must be obvious.

## Behavior

Default to **Attuale** so the current approved appearance remains the initial state.

Switching to **Fluido** should activate the experimental animated rainbow background on the announcement pill.

Switching back must restore the current static look exactly.

This is a local UI state only:

- no persistence needed;
- no URL parameter;
- no backend;
- no analytics;
- no localStorage unless there is a strong reason.

Keep the toggle visually discreet. It exists for founder/design review and should not compete with the announcement itself.

Place it immediately below or adjacent to the announcement in a way that works on phone and desktop.

This toggle is expected to be removed after the founder chooses a final version.

---

# 5. Experimental “fluid rainbow” background

Interpret the founder's description:

> keep the current rainbow/glittery character, but make the colors feel fluid, alive, and slowly moving through each other.

Start with a **pure CSS** experiment.

Do not introduce:

- canvas;
- WebGL;
- Three.js;
- GSAP;
- animation libraries;
- extra runtime dependencies.

## Visual direction

Aim for something between:

- animated mesh gradient;
- aurora / flowing gradient;
- liquid gradient;
- drifting blurred color blobs;
- soft iridescent / holographic sheen.

The movement should feel:

- slow;
- smooth;
- organic;
- premium/subtle;
- not like a loading spinner;
- not like a rapidly rotating rainbow.

The text must stay crisp and readable.

## Suggested implementation approach

Codex may use its design judgment, but a likely approach is:

- keep the announcement pill as the clipping container;
- add one or two pseudo-elements behind the text;
- layer radial/conic/linear gradients using the existing PLANETS palette;
- animate `transform`, `background-position`, and/or `background-size`;
- use controlled blur/opacity to make colors melt into each other;
- optionally add a very subtle highlight/shimmer layer for the “glittery” impression.

Avoid expensive filters over large page areas.

The effect is only on the announcement pill.

## Performance

Keep it lightweight enough for mobile.

Avoid continuous layout changes.

Prefer compositor-friendly transforms where possible.

---

# 6. Reduced motion

Respect:

```css
@media (prefers-reduced-motion: reduce)
```

When reduced motion is requested:

- the experimental mode should show a static representative rainbow state;
- no continuous fluid animation should run;
- the static/current mode remains unchanged.

The toggle itself may still work; only animation should stop.

---

# 7. Preserve everything else

Do not change:

- announcement wording;
- hero title;
- SITE-01C corrected text-container mapping;
- hero logo;
- header logo;
- activity cards;
- Chi siamo content;
- Contatti/Privacy layout;
- waitlist consent wording;
- Cloudflare Turnstile semantics;
- D1/Worker behavior;
- deployment/env configuration.

This should be a small UI-only PR.

---

# Tests

Add/adjust only focused tests where useful.

At minimum verify:

- announcement still renders exactly once;
- toggle defaults to current/static mode;
- activating the experimental option changes the appropriate class/state;
- switching back restores static state;
- waitlist/Turnstile structure remains present;
- existing waitlist tests remain green.

Do not write brittle tests asserting exact pixel values.

---

# Manual visual QA

Inspect at least:

- ~390px mobile width;
- ~1280px desktop width.

Check:

1. Turnstile is centered.
2. Idle waitlist card no longer has excessive bottom whitespace.
3. Error/success feedback still has enough room.
4. Announcement is slightly larger on mobile.
5. Announcement is substantially larger on desktop.
6. Static mode looks the same apart from requested sizing.
7. Fluid mode is clearly animated but not distracting.
8. Text contrast remains good throughout the animation.
9. No horizontal overflow.
10. `prefers-reduced-motion` stops the animation.

---

# Git / PR behavior

This task must be visible on GitHub.

- branch/worktree from the current site UI base;
- implement;
- commit;
- push;
- open a focused PR.

Leave the PR open for founder visual review. Do not auto-merge: the fluid effect is explicitly experimental.

---

# Completion report

Return:

1. PR URL and commit;
2. exact Turnstile centering/spacing changes;
3. announcement mobile vs desktop sizing approach;
4. implementation of the static/fluid toggle;
5. description of the experimental fluid animation technique;
6. reduced-motion behavior;
7. tests/checks run;
8. mobile/desktop visual QA notes;
9. anything the founder should compare specifically before choosing a final version.
