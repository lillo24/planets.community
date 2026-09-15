# PLANETS SITE-01K — Responsive Hero Spacing + Larger Mobile Announcement

## Goal

Make a small responsive spacing refinement to the PLANETS landing hero.

There are two requested changes:

1. reduce excessive vertical whitespace around the hero/announcement on normal laptop-sized screens;
2. make the `In arrivo su iOS e Android` announcement pill about 20% larger on phones.

Do not redesign the page or change unrelated behavior.

---

## Inspect first

Read current:

- `AGENTS.md`
- `apps/site/src/styles.css`
- relevant site tests

Work from current `main`.

---

# 1. Reduce excessive hero vertical whitespace on normal laptop/desktop screens

On a normal laptop-sized screen, roughly:

```text
1366×768
1440×900
13–15" laptop
```

there is currently too much vertical space around the top announcement / Fluid element and the hero content.

Current hero CSS includes approximately:

```css
.hero {
  min-height: calc(100vh - 5rem);
  justify-content: center;
  padding-block: clamp(3.5rem, 8vw, 7rem);
}
```

The `8vw` growth makes the vertical padding too large on ordinary desktop/laptop widths.

## Desired result

For ordinary laptop/desktop widths, reduce the effective hero top/bottom padding to about:

```css
3rem
```

Do **not** simply make every large desktop layout cramped.

Use responsive CSS so:

- phone behavior remains separate;
- normal laptop screens get roughly `3rem` vertical padding;
- genuinely large/wide screens may retain somewhat more breathing room if appropriate.

Also inspect the announcement's bottom spacing:

```css
.hero__announcement-experiment {
  margin-bottom: ...;
}
```

The visual spacing from:

```text
top of hero
↓
In arrivo su iOS e Android
↓
main hero content
```

should feel balanced and noticeably tighter than now on a 14" laptop.

Do not remove the full-page/hero feeling.

If `min-height` + `justify-content: center` is contributing more to the apparent whitespace than the padding itself, make the smallest responsive adjustment necessary instead of changing unrelated layout.

---

# 2. Mobile: make the announcement pill about 20% larger

On phone widths only, make the main:

```text
In arrivo su iOS e Android
```

pill approximately **20% larger**.

Increase proportionally:

- font size;
- vertical padding;
- horizontal padding.

Current mobile appearance is good; it should just have slightly more visual presence.

Rough target:

```text
font:       ~+20%
vertical:   ~+20%
horizontal: ~+20%
```

Do not enlarge the hidden `Base / Riflesso / Fluido` developer toggle.

This applies only to the main announcement pill.

Keep it fully inside narrow phone screens with no horizontal overflow.

---

# Preserve

Do not change:

- Base / Riflesso / Fluido effects;
- hidden developer access;
- orbit geometry/animation;
- hero copy;
- mobile hero ordering;
- waitlist;
- desktop columns;
- other sections;
- Turnstile/D1/Worker behavior;
- deployment configuration.

---

# Tests / validation

Update focused CSS tests only if necessary.

Run:

- relevant site tests;
- `npm run check:site`;
- formatting checks;
- `git diff --check`.

Avoid brittle exact-pixel tests unless the repository already uses that pattern.

---

# Manual QA

Check at least:

- ~390px phone;
- 1366×768 laptop;
- 1440×900 laptop/desktop;
- one larger desktop viewport.

Verify:

- laptop hero no longer has excessive top/bottom whitespace;
- spacing still looks intentional;
- mobile announcement is visibly ~20% larger;
- hidden developer toggle size is unchanged;
- no overflow or layout shift;
- larger desktops still retain appropriate breathing room.

---

# Git / PR

Implement as a tiny focused PR from current `main`.

Required:

1. implement;
2. validate;
3. commit;
4. push;
5. open GitHub PR.

Leave it open for founder visual review.

---

# Completion report

Return:

1. PR URL and commit;
2. exact old/new hero spacing values;
3. exact announcement mobile font/padding changes;
4. viewport QA results;
5. automated checks run.
