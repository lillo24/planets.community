# Project app handoff

This folder owns reusable public Project links and optional downloads for
ordinary detail CTAs and verified participant confirmations.

- `project-links.ts` constructs PI02-compatible HTTPS URLs and token-free
  confirmation paths; only exactly one `intent=join` activates ordinary intent.
- `handoff-config.ts` validates optional Android/iOS download URLs. Missing
  settings are an honest unavailable state; invalid settings throw redacted
  configuration errors. HTTPS without credentials/fragments is required;
  explicit `NEXT_PUBLIC_APP_ENV=local` permits HTTP only on loopback hosts.
- `project-app-handoff.tsx` renders deliberate app/download links, browser
  fallback and the same-account sign-in explanation.
- `ordinary-project-handoff.tsx` adds the dismissible public intent and public
  lifecycle copy; it calls no request/admission gateway.
- `project-handoff.test.tsx` verifies query handling, dismissal, links and config.

The origin is fixed at `https://planets.community`, matching mobile. Confirmed
handoff uses `/proposals/<id>` or `/tavoli/<id>` without intent/token/auth state.
There is no automatic opening/install or browser-based success detection. PI04
owns public-host routing and verified native association; store listings remain
account-owner setup.
