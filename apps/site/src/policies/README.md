# Public policy HTML

`content.json` owns the reviewed public A1–A9, B1–B10, C1–C7 and manual deletion
copy. `metadata.ts` pins the bundle version/status and clean route links.
`render.ts` produces escaped, accessible standalone Italian HTML; no JavaScript,
login, external document permissions or waitlist form is needed to read it.

The Vite plugin in `vite.config.ts` serves these documents in development and
emits `privacy.html`, `terms.html`, `community-rules.html`, `delete-account.html`
into `dist`. Existing Workers Static Assets HTML handling resolves their clean
paths on direct loads and refresh; unrelated 404/API behavior is unchanged.
The React landing footer imports only metadata, keeping policy text out of its
client bundle. The waitlist privacy section remains a separate notice.

`policies.test.ts` checks public hierarchy/links, provisional treatment, the mailto
and website/mobile version parity. Run `npm run check:site` and
`npm run format:check:site`. Review source changes and outstanding policy/operator
work in `docs/development/policy01-content-review.md`.

Publish through the existing site path after scoped checks:
`npm run build --workspace @planets/site`, then
`npm run deploy --workspace @planets/site`. Keep collection disabled by not
introducing `VITE_TURNSTILE_SITE_KEY`; retain the existing Worker runtime secret
and bindings. Verify all four clean URLs on the current Workers origin. No DNS,
invitation hosting or database migration belongs to these pages.
