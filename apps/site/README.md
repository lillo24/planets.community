# Public informational site

This package owns the small public informational and launch website. It builds
with Vite to ordinary static assets and is independent from `apps/web`, which
continues to own dynamic public discovery and the future authenticated admin
surface.

## Content structure

The single static document uses semantic anchored destinations rather than a
router:

- `#inizio` contains the PLANETS identity, launch message, and waitlist preview;
- `#chi-siamo` introduces the local collaboration concept;
- `#contatti` reserves the public contact destination without guessing an
  address;
- `#privacy` explains the one-launch-email purpose and current preview status.

The waitlist form validates email shape only. SITE-01 never sends, stores, or
persists the entered value and explicitly reports that state after valid input.
SITE-02 will replace that preview behavior with the consent-aware persistence
boundary; it must preserve the promise of one launch notification and no
newsletter, advertising, promotions, recurring updates, or unrelated use.

## Files

- `index.html` is the static HTML entry point and owns document metadata plus
  the primary-logo preload.
- `public/brand/planets-logo.png` is the unchanged founder-supplied transparent
  PLANETS logo.
- `src/main.tsx` mounts the React application.
- `src/App.tsx` owns page landmarks, anchored content, navigation, and footer.
- `src/WaitlistForm.tsx` owns the local-only waitlist interaction shell.
- `src/email-validation.ts` owns the small testable email-format check.
- `src/site-content.ts` is the single content-owned slot for an explicitly
  approved public contact address; it intentionally remains `null` in SITE-01.
- `src/App.test.tsx` covers navigation, contact safety, validation, and the
  no-network preview behavior.
- `src/styles.css` owns the responsive visual system and accessibility states.
- `src/vite-env.d.ts` provides Vite's static-asset and client environment types.
- `vite.config.ts`, `tsconfig.json`, and `eslint.config.js` define build and
  validation behavior.

## Commands

Run commands from the repository root:

```text
npm run dev:site
npm run check:site
npm run format:check:site
```

The production build is written to `apps/site/dist/` and can be served by an
ordinary static file host. The site has no runtime environment variables,
backend, analytics, cookies, or provider account. Cloudflare deployment and
domain cutover remain deferred to SITE-03.
