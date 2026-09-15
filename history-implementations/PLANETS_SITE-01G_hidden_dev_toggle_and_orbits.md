# PLANETS SITE-01G — Hidden Developer Toggle + Animated Orbit Satellites

## Goal

Make two small founder/developer-facing refinements to the public PLANETS site:

1. hide the announcement experiment controls from normal visitors and reveal them only through a secret footer interaction;
2. animate the small orbit “satellite” dots around the PLANETS hero image and add a third, larger orbit.

Preserve all current approved site behavior and visual structure unless explicitly changed below.

---

# 1. Hidden developer access for announcement variants

## Default public behavior

On normal page load:

- the announcement uses the existing **Base/basic/static** appearance;
- the experiment toggle is completely hidden;
- no visitor-facing hint suggests experimental controls exist.

The experiment control must not reserve layout space while hidden.

## Secret reveal interaction

At the bottom of the page, use the **footer PLANETS logo mark** as the hidden developer trigger.

Two clicks/taps on that footer logo within approximately **500 ms** should reveal the existing floating experiment toggle.

Requirements:

- works on desktop mouse;
- works on mobile touch;
- do not rely exclusively on native `dblclick` if that makes mobile unreliable;
- revealing the control does not automatically change the active visual mode;
- once revealed, it remains visible until page reload;
- no localStorage/session persistence;
- no URL/query parameter;
- no visible “developer mode” hint.

## Footer-link behavior

The footer PLANETS brand may currently link to `#inizio`.

Do not let the **first tap on the hidden trigger** immediately navigate to the top and prevent the second tap.

Restructure the footer brand cleanly if needed so:

- the logo mark itself can receive the secret double-tap/click interaction;
- normal footer navigation to the top remains available through the PLANETS text or another sensible accessible element.

Do not make the hidden logo trigger confusing to keyboard/screen-reader users.

---

# 2. Developer toggle modes

Once revealed, expose the current three experiment modes:

```text
Base
Riflesso
Fluido
```

Requirements:

- default mode is `Base`;
- `Base` exactly matches the normal public static appearance;
- revealing the developer toggle keeps `Base` selected;
- `Riflesso` and `Fluido` use the already implemented experimental variants;
- the toggle remains floating/absolute and must not consume hero vertical layout space.

Do not change the actual Base/Riflesso/Fluido designs in this task.

---

# 3. Preserve current PLANETS hero image/orbit composition

The current hero visual already has:

```tsx
<span className="orbit orbit--outer" aria-hidden="true" />
<span className="orbit orbit--inner" aria-hidden="true" />
<div className="logo-stage">...</div>
```

with current geometry approximately:

```css
.orbit--inner { width: 84%; }
.orbit--outer { width: 112%; }
```

and each orbit has a satellite dot through `::after`.

**Keep the current image, logo-stage, two orbit borders, sizes, angles, and overall visual composition as they are.**

Do not redesign or resize the existing image/orbits merely to make the new animation easier.

---

# 4. Make the existing satellite dots actually orbit

Currently each `::after` dot sits at a fixed point on its orbit.

Animate the satellite dots so they continuously travel around the center of the PLANETS image along their existing circular orbit paths.

The simplest correct model is acceptable:

- rotate the orbit element around its center;
- because the orbit border is circular, its visual geometry remains unchanged;
- the attached `::after` satellite naturally travels around the circumference.

The goal is:

```text
circle border visually stays the same
satellite dot moves around that circle
```

Do not animate the whole hero/logo.

Do not translate the orbit center.

## Existing starting orientations

Preserve the current apparent initial orientation as closely as practical:

- outer currently starts around `rotate(-16deg)`;
- inner currently starts around `rotate(24deg)`.

Animate from those base angles rather than causing an obvious initial jump when the page loads.

---

# 5. Orbit motion

Use slow, elegant continuous rotation.

Suggested direction:

- inner and outer should use different periods;
- optionally rotate in opposite directions;
- avoid synchronized motion that makes them look mechanically locked together.

Example conceptual timings:

```text
inner: ~18–24s
outer: ~24–32s
```

Exact values are up to Codex after visual QA.

Use linear continuous motion for actual orbital travel unless another easing clearly looks more natural.

There should be no pause at loop boundaries.

---

# 6. Add a third orbit

Add one new orbit span, e.g.:

```tsx
<span className="orbit orbit--far" aria-hidden="true" />
```

or another naming convention consistent with the codebase.

## Geometry

The existing radial spacing is:

```text
inner = 84%
outer = 112%

difference = 28 percentage points
```

Therefore the new third orbit should be:

```text
far = 140%
```

This preserves the same distance from:

```text
inner → outer
outer → far
```

Do not approximate this by visually squeezing it to fit the viewport.

The third orbit should be centered on exactly the same point as the existing two.

## Third satellite

Give the third orbit its own satellite dot.

Use a PLANETS-palette color distinct from the existing cyan/gold dots, e.g. pink/green/coral, while keeping the same small visual treatment:

- same general satellite size;
- same light border;
- same subtle outline/shadow.

Do not add a large planet graphic.

---

# 7. Mobile overflow is intentional

This is important.

The third orbit at `140%` will be larger than the available mobile hero width.

**That is intentional.**

On phone:

- do NOT shrink the third orbit to fit;
- do NOT reduce `140%`;
- do NOT change the existing first/second orbit geometry to compensate;
- allow parts of the third border and its moving satellite to travel outside the viewport/page edge.

It is acceptable for the third satellite to temporarily leave the visible screen.

However:

- do not introduce horizontal scrolling;
- preserve the existing page overflow/clipping behavior as needed;
- the main logo/image and existing two orbits should remain positioned as before.

The intended visual effect is that the third orbital system is larger than the phone viewport and sometimes disappears beyond the edge.

---

# 8. Desktop

On desktop:

- keep the current hero image scale and positioning;
- third orbit should naturally appear outside the existing outer orbit;
- it must not push or resize layout columns;
- it should be purely absolutely positioned decoration.

The third orbit must not alter the hero grid dimensions.

---

# 9. Reduced motion

Respect:

```css
@media (prefers-reduced-motion: reduce)
```

When reduced motion is enabled:

- stop all satellite/orbit rotation;
- keep all three orbit borders and dots visible in static positions;
- announcement developer modes should retain their existing reduced-motion behavior.

---

# 10. Accessibility

All orbit elements remain decorative:

```text
aria-hidden="true"
```

Do not expose the satellite animation to screen readers.

The hidden developer trigger should not compromise the ordinary accessible footer navigation.

---

# 11. Tests

Add focused tests for developer access:

- default announcement mode is Base;
- experiment toggle hidden initially;
- two footer-logo activations within the threshold reveal it;
- a single activation does not;
- revealing it does not change Base;
- Base/Riflesso/Fluido switching still works;
- only one experiment toggle exists.

For the orbit structure, assert at least:

- three decorative orbit elements exist;
- inner and outer remain present;
- third orbit exists with its dedicated class;
- no duplicate hero logo was introduced.

For CSS, avoid brittle pixel tests, but it is reasonable to assert:

- third orbit keeps the intended `140%` geometry;
- an orbit rotation animation exists;
- reduced-motion disables orbit animations.

---

# 12. Manual QA

Check at least desktop and ~390px mobile.

## Developer access

- no toggle visible at normal load;
- Base appearance shown;
- single footer-logo tap/click does nothing visible;
- double tap/click reveals toggle;
- first tap does not unexpectedly jump to the top;
- toggle remains floating and does not move hero layout.

## Orbits

- existing two circle borders still look as before;
- existing image/logo-stage remains unchanged;
- dots visibly orbit their own circle paths;
- motion is continuous and smooth;
- third orbit spacing looks equal to the inner→outer spacing;
- third orbit is 140% and centered with the others.

## Mobile

- third orbit visibly exceeds the viewport;
- its satellite may move off-screen;
- no horizontal scrollbar appears;
- logo and first two orbits are not shrunk/repositioned to accommodate it.

---

# Preserve everything else

Do not change:

- hero copy/order;
- announcement dimensions/content;
- Base/Riflesso/Fluido visual implementations;
- waitlist UI/behavior;
- Turnstile/D1/Worker;
- Cloudflare configuration;
- header/footer branding apart from the hidden footer-logo interaction;
- activity/about/contact/privacy sections;
- `apps/web`;
- Flutter.

---

# Git / PR

Implement on an isolated branch/worktree from current `main`.

Required:

1. implement;
2. run relevant site validation;
3. commit;
4. push;
5. open a focused GitHub PR.

Leave the PR open for founder visual review.

---

# Completion report

Return:

1. PR URL and commit;
2. hidden developer-trigger implementation;
3. double-click/tap threshold and touch handling;
4. confirmation Base is the invisible/default public state;
5. orbit animation strategy and periods/directions;
6. confirmation existing inner/outer geometry remained unchanged;
7. confirmation third orbit is exactly `140%`;
8. third satellite color/treatment;
9. reduced-motion behavior;
10. desktop/mobile QA, especially intentional third-orbit overflow.
