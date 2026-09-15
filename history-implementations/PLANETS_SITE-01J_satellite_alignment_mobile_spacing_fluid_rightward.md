# PLANETS SITE-01J — Satellite Alignment, Mobile Waitlist Spacing, Final Rightward Fluid Experiment

## Goal

Make three small visual refinements to the public PLANETS site:

1. correctly center each satellite dot on its orbit stroke and make the orbital motion slightly faster;
2. on phone layouts only, add a little more vertical separation between the orbit/image area and the email waitlist card;
3. make one final `Fluido` experiment with a much simpler motion language: the whole color field should flow continuously **to the right**, with only a small gentle vertical drift, and use much lighter colors much closer to the Base appearance.

Do not redesign anything else.

---

## Inspect first

Read current:

- `AGENTS.md`
- `apps/site/src/App.tsx`
- `apps/site/src/styles.css`
- `apps/site/src/styles.test.ts`
- relevant site tests

Current implementation at prompt preparation time includes:

- three orbit rings: `84%`, `112%`, `140%`;
- orbit timings around `20s`, `28s`, `36s`;
- satellite dots implemented through `.orbit::after`;
- mobile hero order: title/subtitle → visual/orbits → waitlist;
- `Fluido` using multiple independently moving radial-gradient positions.

Preserve all approved SITE work unless explicitly changed below.

---

# 1. Center the satellite dots ON the orbit stroke

## Current visual bug

The satellite dots look offset from the circular trajectory.

It appears that the **edge of the dot**, rather than the **center of the dot**, is following the orbit stroke.

Fix the geometry so the exact center of every satellite dot lies on the circular border.

Do not fake this by changing the orbit radius.

## Preferred implementation

Use a mathematically clear anchor for each pseudo-element.

For example, place the satellite on one canonical point of its ring:

```css
.orbit::after {
  top: 50%;
  right: 0;
  transform: translate(50%, -50%);
}
```

This makes the satellite's center coincide with the ring's rightmost point.

Equivalent precise geometry is acceptable.

The important requirement is:

```text
orbit border passes through the CENTER of the satellite
```

not its inner/outer edge.

Because the orbit element itself rotates, the dot will still travel around the full circle.

## Starting phases

If switching to a canonical satellite anchor changes the initial visual positions, adjust the existing orbit starting rotation angles as needed so the three satellites begin at aesthetically distributed positions.

Do not move or resize the orbit circles themselves:

- inner remains `84%`;
- outer remains `112%`;
- far remains `140%`;
- all remain centered on the same hero-logo center.

Remove old percentage-based satellite positioning rules if they become obsolete.

---

# 2. Make the satellites/orbits slightly faster

Current approximate periods are:

```text
inner: 20s
outer: 28s
far:   36s
```

Speed them up modestly, not dramatically.

Target roughly:

```text
inner: 17–18s
outer: 23–25s
far:   30–32s
```

Choose a harmonious set after visual QA.

Preserve:

- linear continuous rotation;
- different periods;
- current direction choices/opposite-direction character;
- seamless looping.

Do not make them look frantic.

---

# 3. Phone only: give the waitlist more breathing room below the orbits

On phone layouts, the email/signup card currently sits too close to the large orbit system, especially now that the third `140%` orbit intentionally extends beyond the main image.

The waitlist should sit **a little lower**.

## Requirement

For phone/mobile layout only:

- increase the vertical gap between `.hero__visual` and `.waitlist`;
- do not change the gap between title/subtitle and hero visual unless necessary;
- do not change desktop spacing.

Prefer a targeted mobile-only rule rather than increasing the entire hero grid `gap`.

For example, a mobile-only `margin-top` on `.waitlist` or a dedicated row-gap strategy is appropriate.

Start around an extra:

```text
1.25rem–2rem
```

and visually tune it.

The intended result is simply:

```text
orbits
   ↓ comfortable breathing room
email / Avvisami card
```

The third orbit may still overlap/overflow horizontally as intended, but it should no longer feel like it is touching the waitlist card.

Do not shrink the third orbit.

---

# 4. Final Fluido attempt — simplify the motion radically

The founder still does not like the current `Fluido`.

The present effect feels too mixed/random because the different colors move in different directions.

For this final experiment, use a much simpler directional idea:

> **all color movement travels continuously toward the right.**

There may be a small up/down variation, but horizontal rightward flow must dominate.

Think:

```text
→ → → → → → → → →
       slight ↑↓
→ → → → → → → → →
```

Not:

```text
↗  ←  ↓  ↘  ↑  →  ↙
```

---

# 5. Fluido motion behavior

## Horizontal direction

All color regions should share a clear net motion from left to right.

Do not have individual blobs reversing direction or travelling against one another.

The viewer should immediately perceive:

> the colors are flowing to the right.

## Vertical movement

Allow only a small smooth vertical drift to prevent the animation from feeling mechanically flat.

For example:

- colors can rise/fall a few percent while moving right;
- the vertical displacement should be much smaller than horizontal displacement;
- no independent zig-zag paths.

## Constant movement

Use linear/continuous timing.

No:

- ease-in/ease-out pulsing;
- stop/start;
- visible return trip;
- sudden reset;
- pendulum motion.

The motion should feel like a conveyor/current that could continue forever.

---

# 6. Make the rightward loop genuinely seamless

Do not implement:

```text
move finite gradient from left to right
→ snap back to left
```

The reset must not be visible.

Use a looping/tiling strategy.

A preferred conceptual implementation is:

- create an oversized horizontal color field;
- include enough repeated/duplicated color structure that the end visually matches the beginning;
- animate the field by exactly one repeat width;
- loop linearly.

This is analogous to an infinite scrolling background.

Another CSS-only implementation is acceptable if it produces the same result.

The key acceptance criterion:

> watch several cycles and it should be impossible to identify the reset point.

---

# 7. Much lighter Fluido colors — closer to Base

The current Fluido is still visibly too colorful compared with Base.

Make it substantially paler.

Use the existing **Base** announcement as the direct visual reference.

The desired relationship is:

```text
Base    = pale static rainbow glass
Fluido  = almost the same pale glass, but moving to the right
```

not:

```text
Base    = nearly white
Fluido  = colorful gradient
```

## Practical direction

Keep a strong white/frosted veil similar to Base.

Aim for the colors to contribute only roughly the same subtle amount they do in Base.

If helpful:

- reduce radial/gradient color alpha significantly;
- reduce moving-layer opacity;
- increase the static white veil;
- avoid saturation boosts.

The final colors should be noticeably lighter than the current Fluido.

Do not alter the Base appearance itself.

---

# 8. Keep Fluido free of reflection sweep

`Fluido` must remain distinct from `Riflesso`.

Do not add a travelling white sheen/reflection.

The only animated visual change in Fluido should be:

- rightward color flow;
- minor vertical drift.

A static glass highlight/veil remains fine.

---

# 9. Preserve experiment modes

Keep:

```text
Base
Riflesso
Fluido
```

and the hidden footer developer reveal.

Do not change:

- hidden developer access;
- Base mode;
- Riflesso mode;
- toggle position;
- announcement dimensions/text.

Only change Fluido.

---

# 10. Reduced motion

Continue respecting `prefers-reduced-motion`.

When reduced motion is enabled:

- orbit satellites remain static;
- Fluido becomes a static pale representative color field;
- Base/Riflesso retain their current reduced-motion behavior.

---

# 11. Tests

Update focused tests without pinning irrelevant pixel details.

At minimum verify:

### Orbits
- all three orbit sizes remain `84%`, `112%`, `140%`;
- satellite pseudo-elements use center-on-stroke geometry;
- orbit periods are updated to the new slightly faster values;
- reduced-motion still disables orbit rotation.

### Mobile
- there is a mobile-only spacing rule separating waitlist from the hero visual;
- desktop waitlist spacing remains unchanged.

### Fluido
- Fluido still has a dedicated animation;
- its timing is linear/infinite;
- old multi-directional keyframe assumptions are removed;
- no reflection-sweep animation is attached to Fluido;
- Base and Riflesso remain unchanged.

---

# 12. Manual QA

## Satellites

At desktop and mobile:

- zoom in enough to verify the orbit stroke visually passes through the center of each dot;
- watch a complete rotation segment and verify this remains true throughout;
- no wobbling radius;
- no orbit-ring position change.

## Orbit speed

Confirm the increase is noticeable but modest.

## Mobile waitlist

At ~390px:

- third orbit still remains 140% and may go off-screen;
- no horizontal scrollbar;
- waitlist sits clearly below the orbit area with breathing room;
- desktop layout is unaffected.

## Fluido

Watch for several complete cycles.

Confirm:

- all colors have a clear rightward net movement;
- vertical drift is minor;
- nothing moves leftward as a major motion;
- no visible reset;
- no reflection sweep;
- colors are much paler and closer to Base;
- text remains readable.

---

# Scope

Do not change:

- hero copy;
- image/logo-stage dimensions;
- orbit sizes;
- third-orbit intentional mobile overflow;
- waitlist behavior;
- Turnstile/D1/Worker;
- footer/header branding;
- developer reveal behavior;
- site sections;
- deployment;
- `apps/web`;
- Flutter.

---

# Git / PR

Implement as one small focused UI PR from current `main`.

Required:

1. implement;
2. validate;
3. commit;
4. push;
5. open GitHub PR.

Leave open for founder visual review because Fluido remains experimental.

---

# Completion report

Return:

1. PR URL and commit;
2. exact satellite-centering geometry;
3. old → new orbit periods;
4. mobile-only waitlist spacing change;
5. exact new Fluido technique for infinite rightward motion;
6. how the palette/opacity was made closer to Base;
7. reduced-motion behavior;
8. tests/checks;
9. desktop/mobile QA notes.
