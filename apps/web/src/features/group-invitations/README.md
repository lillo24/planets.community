# Canonical group invitations

This Next feature owns `/join/group/:token` and `/invite/group/:token` browser
onboarding. It does not extend the provisional static invitation SPA.

- `group-models.ts` validates feature-owned public/private projections, UUIDs,
  nullable current status and consent versions; errors contain no capabilities.
- `group-gateway.ts` verifies the current Auth subject, reads its own profile and
  calls canonical invitation, recovery, policy and role RPCs. Policy version and
  public policy links match the existing mobile/site bundle.
- `group-controller.ts` owns tab-memory actor/key/intent binding, identity epochs,
  preview/consent revalidation and read-only status recovery.
- `group-browser.ts` creates the browser-only singleton outside React lifetimes.
- `group-invite-flow.tsx` owns deliberate Join/Accept, Auth/profile return,
  actor-bound policy/role consent and token-free confirmation navigation.
- `group-landing.tsx` is a minimal public/confirmation/app handoff. Public content
  and verified own status have separate authority; guests never receive a joined
  claim. App-store links appear only when existing handoff configuration supplies
  them. `/groups/:id` is not a browser directory or management surface.
- Tests cover strict/null projections, lost response and unavailable preview,
  stale role consent, account changes and status-only retries. The opt-in real
  browser journey is `test-support/group-browser-journey.mjs`.

All capability/confirmation routes use existing no-store, no-referrer/noindex
headers and monitoring redaction. Native association configuration remains
fail-closed until separately verified identities/hosting are activated.
