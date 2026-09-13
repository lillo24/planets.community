# Public informational site

This package owns the small public informational and launch website. It builds
with Vite to ordinary static assets and is independent from `apps/web`, which
continues to own dynamic public discovery and the future authenticated admin
surface.

## Files

- `index.html` is the static HTML entry point and minimal document metadata.
- `src/main.tsx` mounts the React application.
- `src/App.tsx` owns the temporary SITE-00 placeholder shell.
- `src/styles.css` owns the small global reset and responsive placeholder layout.
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
ordinary static file host. SITE-00 selects no production host and requires no
runtime environment variables, backend, or provider account. Cloudflare
deployment and domain cutover remain deferred to SITE-03.
