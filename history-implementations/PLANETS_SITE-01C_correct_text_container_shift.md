# PLANETS SITE-01C — Correct Landing-Page Text Container Shift

## Goal

Correct one specific mistake from SITE-01B: the founder intended the existing text blocks to **shift through the existing visual containers**, not merely to substitute strings while keeping the same number of hero paragraphs.

Do not redesign the page. Preserve all other approved SITE-01B changes.

Current `main` has the wrong structure:

- hero lead: `Persone, idee e luoghi che si incontrano.`
- hero support: `PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.`
- hero logo caption: `Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.`
- the previous about-note container has been removed.

That is not the intended result.

## Inspect first

Read current:

- `AGENTS.md`
- `apps/site/src/App.tsx`
- `apps/site/src/App.test.tsx`
- `apps/site/src/styles.css`

The current merged repository is the source of truth for everything except the correction explicitly specified below.

Do not touch the waitlist Worker/D1/Turnstile implementation, Cloudflare deployment configuration, Contatti/Privacy split, header logo, announcement placement, or other approved SITE-01B UI changes.

# Correct container mapping

Think in terms of **containers/slots**, not just phrases.

Before SITE-01B there were four relevant text containers:

1. hero lead;
2. hero support;
3. caption below the large PLANETS logo;
4. the separate `about-note` / “principle of PLANETS” block inside `Chi siamo`.

The founder intended each previous text to move **one container upward**, and the text from the final container to disappear.

## 1. Hero lead container

The **single subsection directly under the large title** must contain:

> `Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.`

This should remain styled as the primary hero lead/subsection.

## 2. Hero support container

Delete the **entire second hero paragraph element**.

There must no longer be a `hero__support` paragraph under the hero lead.

The visual structure should therefore be:

```text
Le idee prendono vita, insieme.

Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.

[waitlist]
```

There must be **only one textual subsection between the big title and the waitlist**.

If `.hero__support` CSS becomes unused after this, remove it rather than leaving dead styling.

## 3. Caption below the large PLANETS logo

The caption container below the large logo must contain:

> `PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.`

Preserve the existing caption visual treatment unless minor width/wrapping adjustments are needed for the longer sentence.

## 4. About-note container in “Chi siamo”

Restore the separate visual `about-note` / principle container inside the `Chi siamo` content.

Its text must be:

> `Persone, idee e luoghi che si incontrano.`

The previous SITE-01B task incorrectly removed this container. Restore it as a distinct visual note under/within the existing about copy.

If the old `.about-note` styling was removed, recover the prior design from repository history if practical, or restore an equivalent treatment consistent with the existing page.

## 5. Delete the final text entirely

This sentence must no longer appear anywhere on the page:

> `Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.`

It was the final item in the shift chain, so it falls off entirely.

# Exact resulting chain

```text
OLD hero support
    ↓
NEW hero lead

OLD hero lead
    ↓
NEW logo caption

OLD logo caption
    ↓
NEW about-note

OLD about-note
    ↓
DELETED
```

In actual strings:

```text
Hero lead:
Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.

Hero support:
[ENTIRE ELEMENT REMOVED]

Logo caption:
PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.

About-note:
Persone, idee e luoghi che si incontrano.

Deleted completely:
Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.
```

Do not reinterpret this mapping.

# Preserve all other SITE-01B results

Do not undo:

- centered `In arrivo su iOS e Android` announcement below the nav;
- real miniature PLANETS logo in the top-left header;
- vertically stacked `Lista di attesa` / `Sapere quando parte.`;
- separate Contatti and Privacy sections;
- configured/unconfigured waitlist behavior;
- current responsive/mobile work;
- current Cloudflare/Worker behavior.

# Tests

Update the existing SITE-01B regression test so it verifies the **container mapping**, not only whether strings exist somewhere on the page.

At minimum assert:

1. `.hero__lead` contains exactly the `Un luogo per incontrarsi...` sentence.
2. `.hero__support` does not exist.
3. `.hero__caption` contains the `PLANETS mette in contatto...` sentence.
4. `.about-note` exists and contains `Persone, idee e luoghi che si incontrano.`
5. `Ogni persona porta qualcosa...` does not appear anywhere in the rendered page.

Run:

- relevant site tests;
- `npm run check:site`;
- formatting checks;
- `git diff --check`;
- any relevant full repository validation required by current `AGENTS.md`.

Perform quick manual QA at mobile and desktop widths, especially checking the long hero lead and logo caption wrapping.

# Git / PR behavior

This must be visible on GitHub.

- branch/worktree from current `main`;
- implement;
- commit;
- push;
- open a focused PR.

Leave the PR open for founder visual review because this is a visual/content correction. Do not auto-merge it.

# Completion report

Return:

1. branch/commit and PR URL;
2. exact final mapping of all four containers;
3. confirmation that `.hero__support` was removed entirely;
4. confirmation that the about-note container was restored;
5. tests/checks run;
6. mobile/desktop visual QA result;
7. any visual detail the founder should inspect before merge.
