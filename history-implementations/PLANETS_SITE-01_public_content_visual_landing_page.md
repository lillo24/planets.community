# PLANETS SITE-01 — Public Content and Visual Landing Page

## Objective

Turn the SITE-00 static-site foundation into the actual public-facing PLANETS informational website, while keeping it static and lightweight.

The completed SITE-01 should provide:

- a polished responsive PLANETS landing page using the founder-supplied logo;
- a clear "coming soon on iOS and Android" launch message;
- a visible email-notification signup UI ready for SITE-02 backend wiring;
- a short `Chi siamo` section/page;
- a `Contatti` section/page structure;
- a concise privacy page/section that explicitly states the launch-email purpose;
- coherent desktop/mobile navigation, footer, metadata, and accessibility.

SITE-01 is still a **static-content/UI plan**.

Do not add persistence, Cloudflare Functions, D1, Turnstile, Resend, deployment, DNS, or production provider configuration. Those remain SITE-02/SITE-03.

---

# Hard dependency / repository state

Before doing any implementation:

1. inspect the current repository and Git status;
2. confirm **PR #23 / SITE-00 has been merged into the current `main`**;
3. confirm `apps/site` exists on that merged base and the SITE-00 validation still passes.

At prompt-preparation time:

- PR #23 is open at `https://github.com/lillo24/planets.community/pull/23`;
- its head is `df2b187e09b1cd9c144fef05cc14d66ee13194f0`;
- it adds the independent Vite/React/TypeScript `apps/site`;
- `main` has since advanced with other work, including PR #22;
- GitHub currently reports PR #23 as not mergeable against the current base.

Therefore:

> **Do not start SITE-01 on top of an unmerged/conflicted SITE-00 branch.**

If SITE-00 is not yet merged into latest `main`, stop and report that the dependency must first be reconciled/merged. Do not silently stack SITE-01 on PR #23 unless the user explicitly selects that branch as the base.

Once SITE-00 is merged, re-read current:

- `AGENTS.md`;
- `apps/site/README.md`;
- `apps/site/package.json`;
- `apps/site/src/*`;
- root `package.json`;
- `.github/workflows/validation.yml`;
- `docs/architecture/core-stack.md`;
- `docs/architecture/system-design.md`;
- `docs/architecture/decisions/0004-separate-static-informational-site.md`;
- `docs/implementation/roadmap.md`;
- `implementation_plan_sections_suggestions.md`.

Repository code/docs after the merge are the source of truth.

---

# Current intended role of `apps/site`

`apps/site` is the small public informational/launch website.

It is separate from:

- `apps/mobile`: the primary Android/iOS product;
- `apps/web`: the existing dynamic Next.js web/admin/discovery application.

SITE-01 must not import product behavior, Supabase auth, proposal discovery, or admin functionality from `apps/web`.

The informational site should remain buildable to ordinary static assets.

---

# Required external context

## Required logo asset

The founder supplied the current PLANETS logo image:

`selettore_base_shadow2.png`

This exact visual asset is required for SITE-01.

The image contains the multicolor PLANETS mark with the eye, central star/planet, heart/hand, and collaborative hands imagery. Use the supplied file rather than recreating, tracing, simplifying, or generating a replacement.

Copy it into an appropriate site-owned public asset location, for example under:

`apps/site/public/brand/`

Choose a clear final filename consistent with repository conventions.

If the logo file is not available in the Codex task/workspace:

> **Stop and report the missing external asset. Do not invent a substitute logo.**

## Contact email

A public contact email has **not been explicitly supplied in this prompt**.

Do not infer one from private/personal email addresses elsewhere in the project.

Implement the `Contatti` presentation/layout in a way that can accept a real public contact address, but do not publish a guessed address.

If the current repository already contains an explicitly designated public PLANETS contact address, verify its intended public use before reusing it. Otherwise keep the contact-address slot clearly configurable/content-owned and report the missing founder input.

This missing contact address should not block the rest of SITE-01 unless the implementation cannot avoid publishing a fake value.

---

# Product/content direction

The site should be concise. It is not a full marketing microsite and not a web version of the Flutter app.

The main experience should communicate:

1. PLANETS identity;
2. what PLANETS is;
3. that the Android/iOS app is coming soon;
4. that a visitor will be able to leave an email solely to be notified once when the app launches;
5. `Chi siamo`;
6. `Contatti`;
7. privacy information.

Italian should be the default public language for SITE-01 unless current repository/site decisions say otherwise.

Do not add localization infrastructure in this plan.

---

# Homepage requirements

Design and implement a polished homepage around the supplied logo.

## Hero

The hero should prominently contain:

- PLANETS logo;
- PLANETS name/identity;
- a concise mission statement;
- a clear "In arrivo su iOS e Android" / equivalent natural Italian message;
- the launch-notification email form UI.

The exact wording may be refined for natural Italian, but the meaning must remain simple and factual.

A suitable content direction is:

> **PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.**

Supporting copy can briefly mention local collaborative activities/projects such as creating, gardening, building, organizing, or other community initiatives without turning the page into a feature catalogue.

Do not claim functionality that is not part of the accepted product direction.

## Email notification UI

SITE-01 should implement the **visual and client-side interaction shell only**.

The form should have:

- email input;
- clear accessible label or equivalent;
- CTA such as `Avvisami`;
- basic client-side email-format validation;
- reserved success/error/loading UI structure suitable for SITE-02.

However, in SITE-01:

- do not send the email anywhere;
- do not store it;
- do not call an API;
- do not simulate a successful registration that could mislead a user into believing their address was saved.

Because the site is not intended to be publicly cut over until SITE-02/SITE-03, the pre-backend form may use a clearly non-production preview state/handler. Prefer a design that SITE-02 can wire to the real endpoint without redesigning the component.

## Explicit email-use statement

Directly next to/below the email field, state this meaning clearly:

> **Ti invieremo una sola email quando PLANETS sarà disponibile. Il tuo indirizzo non verrà usato per newsletter, pubblicità, promozioni o altre comunicazioni.**

Minor copy-editing for grammar/layout is allowed, but do **not** weaken the promise.

This is a settled product constraint:

- one launch notification;
- not a newsletter;
- no marketing/promotional reuse;
- no recurring product updates;
- no unrelated communications.

Include an accessible link to the privacy information.

---

# Chi siamo

Implement a concise `Chi siamo` destination.

This may be either:

- a dedicated static route/page using a minimal static routing solution already justified by SITE-00; or
- a semantic anchored section on the same static page,

depending on the simplest robust architecture for the existing Vite foundation.

Do **not** introduce a heavy routing dependency merely to create four simple destinations.

The content should remain short and grounded in the project concept.

A safe content direction is:

> PLANETS nasce per rendere più semplice incontrare persone vicine con cui trasformare un'idea in un'attività concreta. La piattaforma è pensata per progetti e incontri collaborativi locali: creare, costruire, coltivare, organizzare e contribuire insieme alla comunità.

Codex may improve the prose slightly for clarity and consistency, but should not add claims about legal status, partnerships, user numbers, funding, launch dates, or team credentials that are not provided.

Do not fabricate team-member biographies.

---

# Contatti

Implement the visual/content structure for `Contatti`.

It should be intentionally minimal.

Expected eventual content:

- public PLANETS contact email;
- optionally a short line such as "Per informazioni o domande su PLANETS".

Do not create:

- a contact-form backend;
- ticketing;
- CRM integration;
- newsletter signup;
- social links that were not supplied.

If the public contact email is unavailable, keep the source structured so it can be inserted in one obvious place later and report it in the completion report.

Do not expose any private email discovered from unrelated repository/history/context unless explicitly designated public.

---

# Privacy content for SITE-01

SITE-01 does not yet store emails, but the site should include the user-facing privacy explanation needed for the forthcoming waitlist.

Keep it concise and avoid pretending to be final legal counsel.

At minimum, the public wording must explain:

- the email will be requested only to notify the person once when PLANETS becomes available;
- it is not a newsletter subscription;
- it will not be used for advertising, promotions, recurring updates, or unrelated communication;
- the visitor will later be able to request removal before the notification is sent;
- SITE-02 will implement the actual persistence/consent mechanics.

Do not invent:

- legal-entity/controller details that the founder has not supplied;
- arbitrary retention periods;
- third-party processors not yet actually selected/configured;
- cookies/tracking that SITE-01 does not use.

Where legal-controller/contact details are still missing, structure the content so they can be filled before SITE-03 production cutover and clearly report them as outstanding.

---

# Visual direction

Use the supplied logo as the visual anchor.

The logo already contains a broad gradient spectrum (pink/coral/orange/yellow/cyan/green) around a predominantly white center. The site can derive a restrained visual system from it.

Preferred direction:

- light/white or softly tinted background;
- dark readable typography;
- generous whitespace;
- subtle use of the logo's spectrum as accents, gradients, borders, glows, or section highlights;
- rounded/organic shapes are acceptable if they support the identity;
- the logo should remain crisp and visually dominant rather than competing with many decorative elements;
- modern, community-oriented, optimistic rather than corporate/SaaS-heavy.

Avoid:

- generic dark "tech startup" look;
- excessive neon/glow;
- stock photography;
- fake phone mockups/screenshots;
- generated people imagery;
- glassmorphism everywhere;
- multiple unrelated gradients;
- visual clutter around the already-complex logo.

The design should feel intentional on both phone and desktop.

Do not redraw or crop away meaningful parts of the logo unless a purely decorative duplicate is used in addition to the full accessible logo.

---

# Navigation and information architecture

Provide a compact public navigation suitable for the small site.

Likely destinations:

- Home / PLANETS;
- Chi siamo;
- Contatti;
- Privacy.

Choose between anchors and static routes based on the simplest implementation supported by the existing Vite foundation.

Requirements:

- usable with keyboard;
- sensible mobile behavior;
- no unnecessary hamburger-menu framework if ordinary responsive links are sufficient;
- semantic landmarks;
- clear active/focus/hover states.

Keep navigation architecture easy to extend but do not create a CMS/navigation abstraction.

---

# Footer

Provide a minimal footer containing the relevant public destinations.

Do not include:

- invented company registration/legal details;
- social networks not supplied;
- newsletter language;
- app-store badges linking to nonexistent listings.

A simple "iOS e Android — prossimamente" indicator is acceptable if it does not imply store listings already exist.

---

# Metadata / static-document polish

Update the static site's document metadata appropriately:

- meaningful page title;
- short description grounded in PLANETS;
- viewport/standard Vite document requirements;
- reasonable theme color if useful;
- logo-derived favicon only if it can be generated/cropped cleanly from the supplied asset without degrading it.

Do not invent Open Graph/social URLs tied to a live production domain if the domain/deployment is not yet configured.

Do not introduce analytics, cookies, tracking pixels, or consent banners.

---

# Accessibility

At minimum:

- semantic headings/landmarks;
- full keyboard access;
- visible focus states;
- proper form labels;
- sufficient contrast;
- meaningful alt text for the PLANETS logo;
- responsive text sizing;
- respect reduced-motion preferences for any nonessential animation;
- no essential information conveyed only by color.

Decorative effects must not impair readability.

---

# Implementation guidance

Preserve SITE-00's lightweight architecture.

Prefer:

- ordinary React components;
- plain CSS already established by SITE-00;
- CSS custom properties for the small visual token set if useful;
- static assets;
- minimal client state only for the waitlist-form shell/navigation behavior where necessary.

Do not add a UI library, Tailwind, CSS-in-JS, state-management framework, animation framework, form framework, or router unless repository evidence demonstrates a concrete need.

If multiple static pages can be implemented cleanly without a new dependency, prefer that.

Do not modify `apps/web` merely to share styling/components.

Shared branding can be extracted later only if a demonstrated need appears.

---

# Testing

Add tests where they provide value, especially for user-facing behavior such as:

- email validation;
- non-submission/no-network behavior in SITE-01;
- navigation/accessibility-critical rendering if the existing foundation has a suitable test setup.

Do not add a large end-to-end framework solely for SITE-01 unless already justified by repository tooling.

At minimum validate:

- site lint;
- site typecheck;
- static production build;
- relevant root checks;
- formatting;
- `git diff --check`.

Run the site locally and manually verify at representative narrow/mobile and wide/desktop widths.

The completion report must state exactly what was automated versus manually inspected.

---

# Documentation and roadmap

Update only documentation affected by the implemented public-site behavior.

Expected:

- `apps/site/README.md` should describe the new page/content structure and clearly say waitlist persistence arrives in SITE-02;
- roadmap should mark SITE-00 implemented once PR #23 is actually merged;
- SITE-01 should be marked implemented only when this plan is merged;
- preserve SITE-02/SITE-03/SITE-04 scope boundaries.

Do not change the main 00–14 roadmap ordering.

Archive this implementation prompt under the established `history-implementations/` convention if still active.

---

# Non-goals

Do not implement:

- D1;
- Cloudflare Workers/Pages Functions;
- Turnstile;
- Resend;
- Supabase;
- email persistence;
- launch-email sending;
- real waitlist submission;
- production deployment;
- Cloudflare project/account provisioning;
- DNS;
- `planets.community` cutover;
- Serverplan/WordPress migration;
- analytics;
- cookies/tracking;
- a CMS;
- app-store integration;
- full product feature pages;
- `apps/web` redesign;
- Flutter UI changes.

---

# Acceptance criteria

SITE-01 is complete when:

- [ ] SITE-00 is merged and SITE-01 is based on current `main`.
- [ ] The supplied PLANETS logo is used as the site's primary brand asset.
- [ ] The placeholder shell has been replaced by a polished responsive public landing page.
- [ ] The page clearly communicates that PLANETS is coming to iOS and Android.
- [ ] The email signup UI exists and performs local validation but does not persist/transmit data yet.
- [ ] The page explicitly says the address is for one launch notification only and is not a newsletter/marketing channel.
- [ ] `Chi siamo`, `Contatti`, and Privacy destinations are present.
- [ ] No private/personal contact address has been guessed or exposed.
- [ ] The site remains an ordinary static build with no backend/runtime dependency.
- [ ] No analytics/tracking/cookies are introduced.
- [ ] Accessibility/responsive basics are implemented.
- [ ] Relevant site/root validation passes.
- [ ] SITE-02 can wire persistence into the existing email-form UI without a redesign.

---

# Autonomy and stop conditions

Codex may make ordinary low-risk design choices within the visual direction above.

Stop and report rather than guessing if:

- SITE-00 is not merged into latest `main`;
- the supplied logo is inaccessible;
- implementing the requested page structure would require changing `apps/web`;
- a new backend/runtime dependency appears necessary;
- legal copy requires an unresolved legal-entity fact;
- a public contact email is essential to completion but none has been explicitly approved.

A missing public contact email should normally be isolated and reported rather than blocking the rest of the landing-page implementation.

---

# Completion report

Return:

1. summary;
2. branch/commit and PR;
3. confirmation that SITE-00 was merged before starting;
4. visual/content structure implemented;
5. logo asset location and handling;
6. waitlist form behavior and explicit confirmation that SITE-01 stores/sends nothing;
7. `Chi siamo`, `Contatti`, and Privacy content status;
8. any founder inputs still missing, especially public contact/legal-controller details;
9. dependencies added, if any, with justification;
10. checks/tests run and exact results;
11. manual responsive/accessibility checks;
12. deferred SITE-02/SITE-03/SITE-04 work;
13. warnings that should block SITE-02.
