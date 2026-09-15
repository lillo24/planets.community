# PLANETS SITE-01I — Move Hero Caption Copy into “Chi siamo”

## Goal

Make one very small content/layout cleanup on the public PLANETS site.

Current state:

- under the large PLANETS hero image there is a caption container with:

> `PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.`

- in the `Chi siamo` section, the first paragraph currently says:

> `PLANETS nasce per rendere più semplice incontrare persone vicine con cui trasformare un'idea in un'attività concreta.`

Desired result:

1. replace that first `Chi siamo` paragraph with the sentence currently under the hero image;
2. delete the hero caption container entirely.

---

# Exact changes

## 1. “Chi siamo” first paragraph

Replace:

```text
PLANETS nasce per rendere più semplice incontrare persone vicine con cui trasformare un'idea in un'attività concreta.
```

with exactly:

```text
PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.
```

Do not modify the second `Chi siamo` paragraph or the green `about-note`.

---

## 2. Remove the container below the hero image

Delete the entire hero caption element currently rendered under the large PLANETS image:

```tsx
<p className="hero__caption">
  PLANETS mette in contatto persone che vogliono creare qualcosa
  insieme nella propria comunità.
</p>
```

Do not leave an empty caption container.

If `.hero__caption` CSS is no longer used anywhere after this change, remove the dead CSS as well.

---

# Preserve the hero visual

Do **not** change:

- the PLANETS image;
- logo-stage;
- the three orbit borders;
- satellite/orbit animation;
- sizes/positioning of the image/orbits;
- mobile overflow behavior;
- hero title/subtitle;
- waitlist position;
- hidden developer announcement toggle;
- Base/Riflesso/Fluido effects.

Removing the caption should not trigger a redesign of the hero image area.

Only remove the caption and let the remaining layout close naturally.

---

# Tests

Update focused site tests so they verify:

1. the new sentence appears in the `Chi siamo` copy;
2. the old `PLANETS nasce per rendere...` sentence is absent;
3. `.hero__caption` no longer exists;
4. the large PLANETS hero image still exists once;
5. orbit elements remain unchanged.

Run the relevant site checks and `git diff --check`.

---

# Git / PR

Implement as a tiny focused PR from current `main`.

Commit, push, and open a GitHub PR.

This is simple and fully specified; if repository workflow allows auto-merge for trivial UI-copy cleanup after green checks, that is acceptable. Otherwise leave it open.

---

# Completion report

Return:

1. PR URL and commit;
2. confirmation of the new `Chi siamo` sentence;
3. confirmation the hero caption element was removed;
4. confirmation unused caption CSS was removed if applicable;
5. tests/checks run.
