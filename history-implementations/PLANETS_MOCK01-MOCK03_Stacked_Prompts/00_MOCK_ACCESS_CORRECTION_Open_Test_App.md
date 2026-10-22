# MOCK access correction — open to everyone using the test app

Date: 21 October 2026. Repository: `lillo24/planets.community`.
Authority: the founder explicitly clarified: “I never said to have only some people access the mock mode … for now anyone with the app should be able.”

## Read first: this overrides the access restrictions in MOCK01–MOCK03

The original three prompts introduced an approved-tester roster and mandatory normal-account control identity. Those were assistant-added restrictions, not the requested product policy. **Remove them.** This correction is sufficient product approval for open mock access; do not seek another approval of a tester list or leave that list as a release blocker.

This is a scoped correction to the existing sequential MOCK stack, not a new independent feature stack. Inspect the latest cumulative implementation and preserve its valid isolation, session recovery, fictional scenarios and qualification work. Reuse the current draft PR; do not rebuild unrelated functionality.

The original prompts remain archived as historical context. Where they require enrollment, tester approval, issuer/UUID rosters, normal-login prerequisites or per-tester entitlement/offboarding as a condition of Mock Mode, **this document takes precedence**. Other requirements remain unless explicitly changed below.

## Required user experience

- Anyone using the current test app can choose **Settings → Sandbox → Mock Mode: Yes**, including a signed-out guest. No tester whitelist, approved names/emails, enrollment file, Play account mapping, invitation code or normal PLANETS registration is required.
- Mock Mode defaults to **No**. Turning it on opens the existing fictional-persona selector; choosing a persona establishes its actual mock Auth session and returns to Home. Cancellation leaves the prior mode/session unchanged.
- While Mock Mode is active, **? → Mock Accounts → Log in** switches between the predefined fictional people and returns to Home. No manual email, password or OTP step is part of this experience.
- Preserve an existing normal account privately and independently. On leaving mock, restore that account if still valid. A user who entered as a guest returns to normal guest Home; do not require real sign-in solely to leave mock. A genuinely expired previous real session follows the existing honest restoration/sign-in behavior.
- No additional mock card tags, title prefixes, permanent banners or DEMO watermark. Keep the existing short shared-fictional-community explanation in the selector and normal functional badges.
- Keep the mock feature out of the production release. This is an explicit test-app capability, not permission to enable unrelated developer utilities.

## Backend access model

Treat the mock persona catalog/session-issuance service as a deliberately public demo capability while the dedicated mock environment is enabled. It must not require a normal-staging token, tester Auth UUID or roster lookup. A client build flag or possession of the app is not a secret; do not claim that the endpoint is inaccessible to other callers.

Only an **operator-controlled fixed persona registry** may supply sessions. This registry is a list of fictional accounts, **not a list of approved human testers**; retain it. The caller chooses a persona key, never an arbitrary email, user UUID, role, issuer, project, redirect or privileged account. Validate the existing exact registered mock user and session identity before returning ordinary mock access/refresh tokens. Exclude database administrators, service-role identities and staff/reviewer personas.

Administrative credentials, signing keys and reusable persona passwords stay server-side. Normal Auth, OTP, RLS, Storage policies and normal-project authorization remain unchanged. Do not grant public clients general SQL, Auth administration, user-directory or arbitrary-account impersonation access. Removing tester eligibility does not remove persona restrictions or endpoint validation.

Replace normal-tester ownership in switch/recovery records with an automatically established opaque, unguessable mock-client capability or equivalent narrow mechanism. It must require no human enrollment and confer no normal-account access. Its purpose is to isolate each client's pending issuance, recovery and session-local retirement; it is **not** a verified human identity or proof of test-app installation. Do not derive it from a real email, hardware identifier or a shared secret embedded in the APK.

Bind recovery to the requesting client capability, exact persona, mock generation and request identity. Another caller who knows a request UUID must not retrieve its delivered session or retire it. Independent clients choosing the same shared persona must retain independent sessions. Preserve no-store responses, confidential token storage, stale-operation fencing and local rather than global persona logout.

Retain server-enforced request/concurrency/issuance bounds, global resource ceilings and the mock-only kill switch. Per-installation identifiers alone do not provide strong abuse prevention, so do not make global limits depend on their honesty. Use bounded existing platform protections; do not introduce paid identity/attestation infrastructure, new PII collection or another manual approval process to recreate the removed gate. Mock-only account/credential takeover protections and no-real-mail/push/analytics behavior remain required.

## Isolation and removal for production

The dedicated mock target is `pnolarmzxmmjtguligfc`; normal staging `cllpvruvrrvxczjitlqd` remains protected and unchanged. Do not mix real people into mock or seed fictional people into normal staging. No real product refresh, write, notification registration or analytics event may be caused by mock actions. Maintaining an already-retained normal Auth session remains separate from any mock access decision; guests have no such dependency.

When retiring Mock Mode, remove/disable the production UI/build capability **and** disable hosted mock session issuance. Existing issued mock sessions are not automatically gone when a button disappears: provide mock-only session revocation or a documented expiry/disable procedure for the mock service/data plane. Do not delete the shared mock world or revoke normal-user sessions as an incidental cleanup action. Test that old clients cannot obtain fresh mock sessions after shutdown.

## Changes and verification required in the existing stack

Update the broker, mock-control schema/commands, native coordinator, selector, release preflight, runbook/status and tests so no runtime path or readiness report still depends on a tester roster. Safely retire now-unneeded mock-only enrollment plumbing; preserve canonical migration history and ordinary data. Do not edit normal-product authorization to accomplish this change.

Specific overrides:

- MOCK01 section 3: replace the approved-tester/control-identity prerequisite with the public fixed-persona issuance contract above. Enrollment coverage is no longer a setup input or gate.
- MOCK02 entry/restoration: allow normal signed-out state, avoid redirecting guests to real OTP, and scope switches by realm/client operation rather than compulsory normal identity. Secure persistence and endpoint separation still apply.
- MOCK03 picker/acceptance/readiness: replace denied-tester/missing-roster cases with enabled/disabled broker, allowed/disallowed persona, client-bound recovery and guest-entry cases. Do not request names, sign-in emails, issuer/UUID lists or roster files again.

Prove guest → Yes → persona → Home; guest persona switching; restart; guest → No → guest Home; existing normal account → mock → same normal account; independent clients sharing a persona; interrupted issuance/recovery; account/mode ABA; request-key guessing; unknown/privileged persona denial; disabled broker; production route gating; normal/mock token rejection; and no normal product traffic during mock. Qualify the changed source with affected backend/mobile tests and the required cumulative CI/native gates; prior roster-based passes do not qualify this revision.

Continue the original mock provisioning/seed/merge workflow. Genuine database connection, secret storage or network limitations remain separate technical setup issues; do not remove locks, weaken isolation, claim hosted completion or change normal credentials to hide them. This correction does not authorize password rotation, paid resources, normal hosted migrations or a Play upload.

Report code qualification, hosted public-mock readiness and release artifact readiness separately. This documentation update alone changes no deployed access.
