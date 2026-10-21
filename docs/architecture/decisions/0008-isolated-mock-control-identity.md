# ADR 0008: Independent mock data realm and normal control identity

Status: Accepted for the MOCK01–MOCK03 closed-test implementation, 2026-10-21.

Closed-test Mock Mode uses a dedicated Supabase project, `planets-mock`
(`pnolarmzxmmjtguligfc`). Normal `planets-staging`
(`cllpvruvrrvxczjitlqd`) remains a protected independent realm. Each owns its
Auth, signing keys, product database, Storage and Realtime. Product migrations
and domain/RLS rules remain canonical and shared as source, never as data.

The ordinary verified normal user is the control identity. An operator-managed
issuer/UUID roster authorizes a narrow broker catalog and persona-session
issuance. A shared persona's ordinary session authorizes only mock product
operations. It cannot enroll testers, browse Auth or issue another session.
No normal administrator secret is required for token verification. Backend flags,
the APK capability, fictional email suffixes and user metadata grant no access.

Mock controls, fixture registration and seeding live outside product migrations.
Every hosted operator operation requires an independent project marker and
reviewed migration digest. Seed receipts preserve deliberate tester changes;
there is no automatic reseed or hosted reset. The environment and broker start
disabled. Missing enrollment/configuration must remain visibly unavailable.

The broker uses server-only one-time login generation and ordinary verification,
with no mail. Request-bound AES-GCM deliveries are recoverable for two minutes;
changing a request's persona conflicts. One OTP exchange runs per persona at a
time. Shared accounts permit independent tester sessions. Offboarding removes
only the departing tester's recorded refresh sessions; already issued access
tokens retain their configured lifetime (at most one hour), which is not instant
revocation. No paid session-control feature is assumed.

MOCK02 implements confidential device persistence, transactional switching and
complete provider/router/cache disposal by realm and transition generation.
The normal SDK retains sole control-session refresh ownership; mock candidates
use independent clients and device keys. Root scope replacement includes the
router, unread frontiers and protected image presentation. Normal product
transport remains fenced during mock; only narrow normal Auth maintenance and
fixed-broker authorization use its control token. Unknown writes retain their
original scoped recovery intent and are never replayed across realms.
See the [mobile boundary inventory](../../development/mock-mobile-sessions.md).
MOCK03 owns
the shared selector, signed/native qualification and cumulative merge. Actual
hosted and release readiness are separate from local code qualification. See the
[operator runbook](../../development/mock-environment.md).
