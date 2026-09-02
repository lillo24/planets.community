# Web authentication feature

This folder owns ordinary-user web authentication and the minimum application-identity readiness check. Supabase Auth remains the session authority, and PostgreSQL RLS remains the data-authorization boundary.

- `auth-models.ts` defines UI-safe auth states, casing-preserving input normalization/masking, validation, and stable error categories.
- `return-destination.ts` accepts only safe internal post-auth destinations and rejects external, protocol-relative, encoded, and auth-loop targets.
- `auth-gateway.ts` is the browser-only Supabase boundary for requesting/verifying numeric email OTPs, ensuring the own-ID profile anchor, and signing out.
- `auth-flow.tsx` owns the in-memory request, verify, resend, duplicate-submit, retry, and navigation state machine for `/auth`.
- `auth-session-actions.tsx` provides profile-anchor retry and sign-out for restored authenticated sessions.
- `auth-status-card.tsx` renders only signed-out, ready, or profile-setup-required status; it receives no email, token, or user ID.
- `current-auth.ts` is the server-only trusted session/profile-readiness reader. It uses verified claims rather than `getSession()`.
- `update-session.ts` is the request Proxy helper that validates/refreshes Supabase cookies and propagates them without making authorization decisions.
- Colocated `*.test.ts(x)` files cover these ownership boundaries with injected or mocked Supabase behavior.

The feature intentionally has no durable pending-email/code storage, magic links, deep links, passwords, social providers, profile fields, or admin authorization.
