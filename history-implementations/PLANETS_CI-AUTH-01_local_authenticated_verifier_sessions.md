# PLANETS CI-AUTH-01 — Harden local authenticated verifier sessions

**Repository:** `lillo24/planets.community`  
**Task type:** CI / integration-test reliability repair  
**Base:** latest `origin/main`  
**Known current main when written:** `ec671f7f71f8beecd679e2cbe155d9ba568c1f16`

## Context

PR #34 (`codex/04c2-scambio-dona-mobile`) is functionally complete, but its Database CI has failed twice at the same **pre-existing** integration verifier:

```text
npm run project:chat:notifications:verify:local
→ scripts/verify-local-project-chat-notifications.mjs
→ ensureCompleteProfile(...)
→ PGRST303
```

Observed failure:

```text
Error: Failed to create a chat-alert profile (code PGRST303).
```

Everything before that step passes: migration replay, schema lint/advisors, pgTAP, OTP auth, profile/proposal/recurring/participation integrations, notifications/push, structured Messages, chat lifecycle, and durable chat messages.

The 04C2 branch does **not** modify this verifier, auth, Supabase configuration, database migrations, or generated DB types.

An unrelated PR (#35), based on the same repository state, ran the same Database pipeline successfully, including the Project-chat notification verifier and Scambio-Dona verifier.

Therefore this task is a **test-harness reliability repair**, not a product/domain change and not an 04C2 change.

Do not merge the implementation PR.

Prefer branch:

```text
codex/ci-authenticated-verifier-session-hardening
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_CI-AUTH-01_local_authenticated_verifier_sessions.md
```

## Primary goal

Make local authenticated integration users deterministic so an immediately authenticated PostgREST request cannot intermittently use an invalid/non-user Authorization value.

The fix must eliminate the observed `PGRST303` failure without:

- retrying blindly until it happens to pass;
- sleeping for arbitrary time;
- ignoring authentication errors;
- bypassing RLS with service-role queries for user behavior;
- weakening the Project-chat notification verifier;
- modifying production auth behavior.

## Investigate before patching

Inspect:

- `scripts/verify-local-project-chat-notifications.mjs`;
- its `signInWithLocalOtp(...)` and `ensureCompleteProfile(...)`;
- other local verifier OTP helpers, especially chat messages, participation, messages, notifications, and mobile auth;
- `scripts/lib/local-supabase-status.mjs`;
- the pinned `@supabase/supabase-js` version and its actual authentication/fetch behavior.

Compare the failed verifier to successful integration helpers.

Do not assume the hypothesis below is automatically correct.

## Working hypothesis to verify

The failing verifier creates a client from the local publishable key, completes OTP verification, and immediately uses the same client for an RLS-protected PostgREST insert.

`PGRST303` is a JWT claims validation/parsing failure.

A plausible race is that the first database request can observe the client before the newly returned user access token is deterministically available to its REST fetch path, causing an Authorization fallback to use a publishable/non-user value instead.

Current `supabase-js` supports an explicit `accessToken` callback. A robust test-only pattern may therefore be:

```text
auth client
  → verify OTP
  → receive canonical session access token
  → construct/use authenticated data client whose accessToken callback
    explicitly returns that session token
```

This is a hypothesis, not a mandatory implementation. Inspect the pinned SDK and choose the smallest correct mechanism.

## Required behavior after OTP verification

After `verifyOtp` succeeds, the helper must not return a user object until it has a deterministic authenticated client suitable for immediate RLS-protected REST/RPC calls.

The resulting test user should still expose conceptually:

```text
id
client
```

where `client` reliably authenticates as that user.

Possible valid approaches:

### A. Explicit token-bound data client

Use one client for Supabase Auth, then construct a second non-persistent client using the returned session JWT as its explicit token source.

Prefer this if supported cleanly by the pinned SDK.

### B. Explicit session establishment + verification

If the SDK has a documented deterministic way to bind the returned session to the existing client, establish it and confirm a subsequent session/safe authenticated call resolves the expected user before returning.

Do not manually forge JWTs or modify claims.

## Security/logging requirements

Never print:

- OTPs;
- access/refresh tokens;
- publishable/service-role keys;
- Authorization headers;
- full JWTs;
- DB passwords.

Safe temporary diagnostics may print only user UUID, session-present booleans, non-sensitive claim names/timestamps, and error code/status.

Remove temporary diagnostics before finalizing unless broadly useful and privacy-safe.

## Do not mask the problem with retries

Do not solve this with:

```text
catch PGRST303
sleep
retry
```

or retry-until-pass OTP/profile creation.

The first authenticated query after successful sign-in should be correct.

## Scope of helper changes

Prefer the smallest durable fix.

If the same risky OTP helper is duplicated widely, Codex may extract a shared helper such as:

```text
scripts/lib/local-authenticated-user.mjs
```

only if that is genuinely cleaner and low-risk.

A shared helper may own OTP request, Mailpit retrieval, OTP verification, deterministic authenticated data-client creation, and safe user/session validation.

If extracting it would make the repair much larger, patch the Project-chat notification verifier first and document follow-up cleanup.

Do not refactor every integration script merely for style.

## Preserve verifier semantics

`verify-local-project-chat-notifications.mjs` must continue testing real authenticated behavior:

- creator/member identities;
- actual RLS/RPC authorization;
- send-time fan-out;
- sender exclusion;
- late join;
- leave;
- rejoin;
- independent in-app/push preferences;
- Proposal and Tavolo;
- body-free alert context.

Do not replace user operations with service-role calls.

Service role may remain only where the verifier intentionally acts as trusted projector/worker/admin infrastructure.

## Focused regression coverage

Add a focused real integration assertion proving:

```text
OTP verification succeeds
→ helper returns expected user ID
→ the very next authenticated PostgREST operation succeeds
→ RLS/auth.uid() observes the expected identity
```

Prefer a real local Supabase check, not a mock.

If practical, cover multiple authenticated clients created back-to-back or concurrently, matching the failing verifier.

Do not turn CI into a long stress benchmark.

## Validate the actual failing sequence

Run:

```text
npm run project:chat:messages:verify:local
npm run project:chat:notifications:verify:local
```

against the same clean local Supabase stack/order when feasible.

The notification verifier must pass without auth retries.

## Full regression validation

Run repository-standard checks.

At minimum:

```text
npm run format:check
git diff --check
```

and full GitHub Database Validation:

- clean Supabase startup/reset;
- pgTAP;
- all integration verifiers;
- Project-chat notification verifier;
- Scambio-Dona verifier;
- generated type drift.

Mobile/Web/Site should remain green if the standard workflow runs them.

No schema/generated-type change is expected.

## Independence from 04C2

Do not modify PR #34 in this task.

Base this repair on current `main`, not the 04C2 feature branch.

After this CI repair PR is reviewed and merged, PR #34 can be rebased onto the new main and revalidated.

Do not merge PR #34 from this task.

## No production behavior changes

Do not modify:

- production Supabase Auth settings;
- JWT lifetime/audience;
- RLS policies;
- Project/chat notification schema/projectors;
- resource-listing schema;
- Flutter code;
- Cloudflare config.

If investigation shows a production/runtime defect rather than a test-client/session race, stop and report before broadening scope.

## Acceptance criteria

- [ ] based on current `origin/main`;
- [ ] exact prompt archived;
- [ ] root cause identified with evidence;
- [ ] deterministic authenticated test-client/session handling implemented;
- [ ] no arbitrary sleep/retry workaround;
- [ ] no raw credentials/tokens/OTPs logged;
- [ ] real RLS-authenticated behavior remains tested;
- [ ] focused immediate-post-OTP authenticated operation passes;
- [ ] Project-chat messages verifier passes;
- [ ] Project-chat notification verifier passes;
- [ ] Scambio-Dona verifier passes afterward in full Database CI;
- [ ] all pgTAP passes;
- [ ] generated DB types unchanged/zero drift;
- [ ] normal Mobile/Web/Site jobs remain green;
- [ ] PR remains unmerged.

## Deliverables

1. Exact archived prompt.
2. Root-cause explanation.
3. Minimal auth-test helper/verifier repair.
4. Focused regression coverage.
5. Green Project-chat notification verifier.
6. Green full Database job.
7. Focused PR, preferably `codex/ci-authenticated-verifier-session-hardening`.
8. Structured completion report.

Do not merge the PR.

## Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Root cause**
5. **Why PGRST303 occurred**
6. **Supabase-js behavior inspected**
7. **Chosen deterministic session-binding approach**
8. **Why no retry/sleep workaround was needed**
9. **Security/logging guarantees**
10. **Project-chat notification verifier result**
11. **Back-to-back chat verifier result**
12. **Focused auth regression coverage**
13. **Full Database CI result**
14. **Scambio-Dona verifier result**
15. **Generated-type/schema impact**
16. **Other regression validation**
17. **Warnings/blockers**
18. **Commit/PR reference**
