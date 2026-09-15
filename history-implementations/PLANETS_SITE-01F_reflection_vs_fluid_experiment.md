# PLANETS SITE-01F — Reflection vs Fluid Announcement Experiment

## Goal

Refine the experimental `In arrivo su iOS e Android` announcement into a direct comparison between **two animated visual variants**:

1. **Riflesso** — preserve the current moving-light/reflection concept, but make its cycle a bit faster and visually cleaner;
2. **Fluido** — create the actual intended effect where the **colors themselves continuously flow and morph** through each other.

Also make the temporary comparison toggle **float over the layout** instead of occupying normal vertical space.

This remains a founder-facing visual experiment. Do not change site content, waitlist behavior, Worker/D1/Turnstile logic, deployment configuration, or other approved UI.

---

# Current context

The current experimental announcement already has:

- a pale/static approved base visual;
- a colored moving layer;
- a separate white sheen/reflection layer;
- a temporary `Attuale / Fluido` toggle.

The current implementation mixes two effects:

- mild color drift;
- a bright reflection sweep.

The founder now wants to compare those ideas explicitly rather than mixing them into one mode.

---

# 1. Replace the current comparison with two animated variants

The temporary toggle should compare:

```text
Riflesso
Fluido
```

Do not use `Attuale / Fluido` for this experiment.

Default to **Riflesso** for now so the founder can compare the familiar current effect against the new interpretation.

The toggle is still temporary and will be removed after a final visual choice.

No persistence, URL state, localStorage, analytics, or backend changes are needed.

---

# 2. Make the toggle float without taking vertical layout space

Current issue:

The toggle currently occupies a normal block/row beneath the announcement, increasing the vertical spacing before the large hero title.

Desired behavior:

- keep it visually around the same area it currently appears;
- make it **floating/overlayed** instead of part of normal document flow;
- it may visually overlap the whitespace / upper edge area above the hero title;
- it must not push the big title downward.

Preferred implementation:

- make the announcement experiment wrapper `position: relative`;
- position the toggle with `position: absolute`;
- anchor it relative to the announcement/wrapper;
- use a high enough `z-index`;
- keep it centered horizontally.

Conceptually:

```text
[ announcement pill ]

        [ Riflesso | Fluido ]   ← floating overlay

Le idee prendono vita, insieme.
```

The toggle may sit slightly below the pill and visually enter the space above the title.

Important:

- no layout jump when switching variants;
- no overlap with the announcement text;
- no horizontal overflow on mobile;
- no obstruction of the hero title at narrow widths;
- preserve keyboard accessibility.

On small screens, adjust the absolute offset responsively if needed.

---

# 3. Variant A — Riflesso

This version intentionally keeps the current moving-light/reflection idea.

The founder likes the reflection effect; it simply should be treated as its **own visual mode**, not confused with fluid color movement.

## Visual behavior

`Riflesso` should have:

- the pale/glassy rainbow base;
- mild or almost-static color movement;
- a visible white/light reflection passing across the pill;
- clean liquid-glass / polished-surface feeling.

The reflection should clearly read as light traveling over a surface.

## Speed

Make the reflection period **a bit faster than the current 6s**.

Target approximately:

```css
4.5s–5s
```

Use judgment within that range.

Do not make it frantic.

The movement should remain elegant and smooth.

## Reflection implementation

The existing `::after` sheen approach is acceptable for this mode.

It may keep:

- transparent → soft white → transparent gradient;
- animated background-position;
- controlled opacity.

Refine only if needed for smoothness.

The key point:

> `Riflesso` is intentionally a moving reflection effect.

Its speed should be controlled independently from the `Fluido` color-motion speed.

---

# 4. Variant B — Fluido

This version must implement the founder's original intent:

> the actual colors continuously move, drift, and morph through each other.

It must **not** rely on a moving white reflection to create the perception of animation.

## Material match

Use the current pale `Attuale` / glassy appearance as the visual material reference:

- translucent;
- lots of white;
- soft rainbow;
- subtle border;
- frosted / liquid-glass feeling.

Do not make Fluido substantially more saturated, darker, or more opaque.

## Color behavior

The colored regions themselves must visibly change position over time:

- pink;
- yellow/gold;
- green;
- cyan.

They should move relative to each other.

Think:

- animated mesh gradient;
- moving radial-gradient blobs;
- slow color currents;
- fluid aurora;
- soft liquid color field.

Do not use:

- a moving white sheen;
- shimmer stripe;
- loading gradient;
- entire gradient sliding rigidly as one piece.

---

# 5. Fluido implementation approach

Prefer a pure-CSS layered gradient field.

Conceptually:

```text
announcement pill
├── pale/static glass base
├── ::before = moving multi-color field
├── ::after  = optional STATIC frosted/highlight veil
└── text
```

For the color field, prefer multiple radial gradients with independently changing positions.

Example concept:

```text
pink blob     → drifts diagonally
gold blob     → moves horizontally
green blob    → moves on another path
cyan blob     → shifts vertically / diagonally
```

Use multiple keyframe stages such as:

```text
0%
25%
50%
75%
100%
```

so the motion feels organic and loops smoothly.

Do not use a simple `alternate` if it produces an obvious back-and-forth pendulum effect.

Do not animate the outer pill geometry.

---

# 6. Fluido speed

The founder wants continuous color movement that is **clearly perceivable**.

Use one obvious primary duration for the color flow, approximately:

```css
5s–7s
```

Pick a value that makes the movement visible without looking nervous.

Important:

Future requests like:

> “make Fluido faster”

must clearly map to the **color-flow duration**, not any reflection layer.

If several color layers use slightly offset timings, keep them conceptually tied to the same fluid-motion system.

---

# 7. No moving sheen in Fluido

This is a hard distinction between the two experimental modes:

## Riflesso
- moving reflection: YES
- strong color-flow requirement: NO

## Fluido
- moving reflection: NO
- continuous color-flow: YES

If Fluido uses `::after`, it may only be a **static** frosted/glass/highlight overlay.

No moving white sweep in Fluido.

---

# 8. Shared visual material

Both `Riflesso` and `Fluido` should still feel like two treatments of the **same PLANETS component**.

Keep approximately consistent:

- pill dimensions;
- text;
- border radius;
- base brightness;
- pale translucent material;
- shadow;
- border;
- text color.

The visual difference should be the **motion language**, not two unrelated color palettes.

---

# 9. Reduced motion

Respect:

```css
@media (prefers-reduced-motion: reduce)
```

When reduced motion is enabled:

- `Riflesso`: show a static representative glass state with no sweep;
- `Fluido`: show a static representative color field with no motion;
- toggle remains usable;
- no layout changes.

---

# 10. Performance

Keep both variants lightweight.

Use CSS only.

Do not add:

- Canvas;
- WebGL;
- Three.js;
- GSAP;
- animation libraries;
- JS animation loops.

Prefer pseudo-elements, background-position, opacity, and modest transforms/blur on the small pill only.

---

# 11. Toggle styling

Keep the temporary toggle visually discreet.

Use labels:

```text
Riflesso
Fluido
```

The active state should remain obvious.

Because it is now floating:

- ensure it has a soft background/border/shadow so it remains readable over the hero background;
- do not let it obscure the announcement text;
- do not let it become the main visual focus.

No `Sfondo:` label is necessary unless it improves clarity; prefer the most compact version.

---

# 12. Tests

Update focused tests so they reflect the new experiment.

At minimum verify:

1. toggle exposes exactly the two experiment states `Riflesso` and `Fluido`;
2. default state is `Riflesso`;
3. switching variants changes the expected class/state;
4. `Riflesso` uses the reflection animation;
5. `Fluido` does not use the reflection animation;
6. `Fluido` uses a dedicated color-flow animation;
7. reduced-motion disables both motion systems;
8. toggle remains one component and no duplicate announcement exists.

Avoid brittle tests that assert every gradient coordinate.

---

# 13. Manual visual QA

Check desktop and mobile.

## Floating toggle

- Does it stop consuming vertical hero space?
- Does the big title remain at the intended position?
- Does the toggle visually float in the whitespace under the announcement?
- Does it avoid covering title/announcement on mobile?

## Riflesso

- Is the reflection clearly visible?
- Is the ~4.5–5s cycle slightly faster but still elegant?
- Does it read as light/reflection rather than color-flow?

## Fluido

- Are the actual colored regions visibly moving?
- Do colors move relative to each other?
- Is there no moving white sheen?
- Does the movement feel continuous and organic?
- Does it remain pale/glassy rather than saturated?

## Shared appearance

- Do the two modes feel like the same component/material?
- Does text remain readable in every animation phase?

---

# Preserve everything else

Do not change:

- announcement wording;
- announcement dimensions unless necessary for the experiment;
- hero text/copy;
- mobile hero ordering;
- waitlist UI;
- Turnstile;
- footer/header logos;
- activity/about/contact/privacy sections;
- Worker/D1/deployment configuration;
- `apps/web`;
- Flutter.

---

# Git / PR behavior

Implement on an isolated branch/worktree from current `main`.

Required:

1. implement;
2. validate;
3. commit;
4. push;
5. open a focused GitHub PR.

Leave the PR open for founder visual review. Do not auto-merge.

---

# Completion report

Return:

1. PR URL and commit;
2. floating-toggle positioning strategy;
3. exact `Riflesso` animation technique and duration;
4. exact `Fluido` color-motion technique and duration;
5. confirmation that Fluido has no moving sheen;
6. shared material/color treatment;
7. reduced-motion behavior;
8. automated tests/checks;
9. desktop/mobile visual QA;
10. specific points the founder should compare before choosing a final mode.
