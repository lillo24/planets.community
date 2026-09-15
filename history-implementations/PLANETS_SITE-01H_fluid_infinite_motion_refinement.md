# PLANETS SITE-01H — Fluid Infinite-Motion Refinement

## Goal

Refine only the existing PLANETS `Fluido` announcement animation so the color movement feels continuous and infinite.

The current animation is visually close, but its timing/path makes it feel like:

- it moves calmly for most of the cycle;
- then speeds up near the end;
- then visibly resets to the start.

The founder wants an **endless current** feeling instead.

Do not redesign the effect.

---

## Inspect first

Read current:

- `AGENTS.md`
- `apps/site/src/styles.css`
- `apps/site/src/styles.test.ts`
- the current announcement experiment component/tests

At prompt preparation time, the fluid animation is approximately:

```css
animation: announcement-fluid-color-flow 6s ease-in-out infinite;
```

with keyframes at roughly:

```text
0%
25%
50%
75%
100%
```

and `100%` returns to the same visual position as `0%`.

---

# 1. Use linear timing

Change the primary Fluido color-motion animation from `ease-in-out` to `linear`.

Target:

```css
animation: announcement-fluid-color-flow 6s linear infinite;
```

Keep the current duration around 6s initially.

The objective is approximately constant perceived speed.

Do not change the Base or Riflesso animation timing in this task.

---

# 2. Fix the loop seam, not just the easing

Changing to `linear` is necessary but may not be sufficient.

Inspect the current color-blob trajectories around:

```text
75% → 100%/0% → 25%
```

The current path may effectively rush the blobs back toward their initial positions near the end.

Adjust the keyframes so every color follows a smooth closed trajectory.

The key requirement is:

> `100%` must visually match `0%`, but the **direction and apparent velocity** entering and leaving that point must also match.

Think of each color as continuously travelling around a loop, not as travelling through a sequence and then returning home.

---

# 3. Add intermediate keyframes if needed

If necessary, introduce additional points such as:

```text
0%
12.5%
25%
50%
75%
87.5%
100%
```

or another clean distribution.

The exact percentages are not important.

What matters is that:

- motion into 100% is smooth;
- motion out of 0% is the natural continuation;
- no single final segment covers noticeably more visual distance than the others;
- there is no visible reset.

Do not add complexity unless it improves the loop.

---

# 4. Preserve the current visual design exactly

Do not change:

- color palette;
- color opacity;
- saturation;
- blur;
- frosted/static overlay;
- Base mode;
- Riflesso mode;
- hidden developer toggle;
- announcement sizing;
- announcement position;
- text;
- hero layout;
- orbit animation.

This task is only about the **Fluido motion trajectory/timing**.

---

# 5. Preserve relative color movement

The fluid effect should continue to show the individual color regions moving relative to one another.

Do not simplify it into:

- one entire gradient sliding left/right;
- one rotating rainbow layer;
- a reflection sweep.

The colored regions should continue to behave like a moving mesh/liquid field.

---

# 6. Speed

First try:

```text
6s linear infinite
```

If manual QA shows linear 6s now feels clearly too fast, increase the duration slightly.

Do not reduce it unless there is a strong visual reason.

The main problem to solve is continuity, not raw speed.

---

# 7. Reduced motion

Preserve current:

```css
@media (prefers-reduced-motion: reduce)
```

Fluido must remain static when reduced motion is requested.

---

# 8. Tests

Update focused CSS regression tests.

At minimum verify:

1. `announcement-fluid-color-flow` still exists;
2. the animation now uses `linear`;
3. it remains `infinite`;
4. the old `ease-in-out` expectation for Fluido is removed;
5. reduced-motion still disables the animation;
6. Base/Riflesso behavior remains untouched.

Do not write brittle assertions for every background-position coordinate.

---

# 9. Manual QA

Watch Fluido continuously for **at least 3 full cycles**.

Explicitly check:

- no visible cycle beginning/end;
- no slowdown around keyframes;
- no rushed final movement;
- no perceptible reset;
- motion feels calm and approximately constant;
- colors still move relative to one another;
- text remains stable and readable.

If you can tell exactly when the animation restarts, the task is not complete.

---

# Scope

Do not touch:

- waitlist;
- Turnstile/D1/Worker;
- footer/header;
- orbit work;
- deployment;
- `apps/web`;
- Flutter.

---

# Git / PR

Implement as a small focused PR from current `main`.

Required:

1. implement;
2. validate;
3. commit;
4. push;
5. open PR.

Leave it open for founder visual review.

---

# Completion report

Return:

1. PR URL and commit;
2. previous timing/easing;
3. new timing/easing;
4. whether intermediate keyframes were added;
5. how the loop seam was made continuous;
6. test results;
7. result of watching at least 3 full cycles.
