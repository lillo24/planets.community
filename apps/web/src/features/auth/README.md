# Web authentication feature

This folder owns ordinary-user web authentication and the minimum application-identity readiness check. Supabase Auth remains the session authority, and PostgreSQL RLS remains the data-authorization boundary.

- `auth-models.ts` defines UI-safe auth states, casing-preserving input normalization/masking, validation, and stable error categories.
- `return-destination.ts` accepts only safe internal post-auth destinations and rejects external, protocol-relative, encoded, and auth-loop targets.
- Participant returns add narrow cancellation to the exact preview or token-free public Project, including nested profile continuation; normal Home and authority-invite defaults stay unchanged. All `/auth` and `/profile` responses receive no-store/no-referrer/noindex headers, protecting encoded token returns.
- `auth-gateway.ts` is the browser-only Supabase boundary for requesting/verifying numeric email OTPs, ensuring the own-ID profile anchor, and signing out. Successful verification returns the actual OTP subject, allowing the static invitation host to bind a previously explicit Join to that identity without accepting restored-session hints as consent.
- `auth-flow-view.tsx` owns the in-memory request, verify, resend, duplicate-submit, retry, and navigation state machine for `/auth`. Unmounting invalidates late verification/setup results. `auth-flow.tsx` supplies the normal Next navigation adapter; the isolated static trial supplies its own adapter to the same view.
  Hosts may set `showBackLink={false}` when they provide their own safe back
  control. The static invitation header arrow performs that navigation and
  clears the pending Join; the default Next footer controls remain available.
- `auth-session-actions.tsx` provides profile-anchor retry and sign-out for restored authenticated sessions.
- `auth-status-card.tsx` renders only signed-out, ready, or profile-setup-required status; it receives no email, token, or user ID.
- `current-auth.ts` is the server-only trusted session/profile-readiness reader. It uses verified claims rather than `getSession()`.
- `update-session.ts` is the request Proxy helper that validates/refreshes Supabase cookies and propagates them without making authorization decisions.
- Colocated `*.test.ts(x)` files cover these ownership boundaries with injected or mocked Supabase behavior.

The feature intentionally has no durable pending-email/code storage, magic links, deep links, passwords, social providers, profile editing, or admin authorization. It derives readiness from the profile display name and delegates setup/editing to the Profile feature.
