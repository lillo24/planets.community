# PLANETS POLICY02 — Backend policy acceptance + acceptance-screen cleanup

## Goal

Replace device-local Terms of Use / Community Rules acknowledgement with account-backed, authenticated Supabase persistence, and remove three redundant actions from the acceptance UI.

This is an **implementation plan for Codex**, not a claim that the changes are already implemented.

## Working agreement

- Repository: `lillo24/planets.community`.
- Start from the **latest `main` at execution time**, including any small intervening PRs. Inspect the actual implementation before editing; do not assume this document freezes the repository.
- Deliver **one focused implementation PR** targeting `main`, with related migration, app changes, tests, and documentation. Do not merge or deploy without authorization.
- The app is still pre-release, with effectively one existing tester. **Do not implement legacy acceptance migration, backfill, or compatibility machinery.** An account without a backend record should be asked to explicitly accept once, even if that account previously accepted locally. Do not automatically turn local flags into server-side acceptance.
- Nothing external to the repository is required to design/implement this task. Deployment of a migration to a hosted Supabase instance, if needed, must be reported as a separate operator step.

## Starting points (verified on `main` as of 2026-10-11; recheck)

- `apps/mobile/lib/features/policies/presentation/policy_acceptance_screen.dart` shows Terms, Rules, Privacy, checkbox, Accept, Back, sign-out, plus the three redundant `TextButton` actions: `policyCancel` ("Continue browsing; cancel this action"), Settings, and Help.
- `apps/mobile/lib/features/policies/application/policy_acceptance_controller.dart` implements per-account/version loading, saving, failure states, and generation guards; currently calls `policyAcceptanceStoreProvider`.
- `apps/mobile/lib/features/policies/data/policy_acceptance_store.dart` currently stores the version and acceptance time in `SharedPreferencesAsync`; this is only device-local.
- `apps/mobile/lib/features/policies/application/policy_documents.dart` defines `policyBundleVersion = 'POLICY01-2026-10-08-v1'` and routes for policy acceptance/deletion. Website metadata should remain aligned if bundle content is changed.
- `apps/mobile/lib/app/router/app_router.dart` guards authenticated writing/navigation, while public browsing, Help, reporting, blocking, Settings, deletion, and sign-out intentionally remain accessible.
- `apps/mobile/lib/features/policies/README.md` and `docs/development/policy01-content-review.md` describe existing policy behavior; update any statements made obsolete by the backend change.
- Inspect the latest Supabase migrations, RLS/RPC conventions, auth state, backend clients, and SQL/mobile tests before choosing a persistence implementation. Do not blindly add a duplicate policy table if equivalent support already exists.

## Requirements

### A. Record acceptance for the authenticated account in Supabase

1. Add a minimal backend representation of acceptance of a **specific policy bundle version**, with a **server-generated acceptance timestamp**. Prefer an append-only/idempotent record per authenticated account + version; use another design only if existing repository conventions justify it. Do not store unnecessary user data.
2. Enforce identity and authorization in the database: derive actor identity from the authenticated session, not from a trusted client-supplied account ID; deny unauthenticated and cross-account access; prevent a client from forging `accepted_at` or rewriting past acceptance records.
3. A repeated submission for the same account/version should be idempotent and safe with simultaneous requests. Preserve records for earlier versions as needed for a truthful acceptance history.
4. Backend is authoritative. On a second device or after reinstall, the existing server record for the **current** version is recognized without repeat acceptance. A new material version must require fresh explicit acceptance; merely opening a page or logging in does not constitute acceptance.
5. A read failure, offline state, or indeterminate backend response must **fail closed for protected actions**; a cached or stale local flag must not grant access. Provide a retry path without permanently trapping a user.
6. Save and confirm server-side acceptance **before** marking the UI accepted or resuming a protected return destination. Retain defenses against delayed callbacks after logout, account switch, version change, multiple taps, disposal, or connection recovery.
7. Preserve existing join/deep-link flows, pending invitations, return destinations, profile setup, and explicit exceptions for public browsing, Settings, Help/reporting/blocking, deletion, and sign-out. Do not consume an invitation merely because the user navigates Back.
8. Retire or demote the legacy local acceptance store without treating its data as proof of server consent. **No migration or backfill is needed for the small existing tester base.** A previously locally accepted account may see the gate once again.
9. Review whether sensitive mutation endpoints need server-side acceptance enforcement. Do not introduce a broad write-policy redesign as part of this small feature without evidence. Explicitly document whether enforcement is server-side, client-side, or mixed and what can still bypass it.
10. Do not imply that storing an account/version/timestamp proves the user read the policies or that the policies have undergone legal review.

### B. Remove three buttons from the policy acceptance screen

Remove **only from this screen**:

- `Continue browsing; cancel this action` (localized `policyCancel`);
- `Settings`;
- `Help`.

Keep:

- functional Back/cancel navigation with no acceptance (and without accidentally completing/consuming pending actions);
- Terms of Use, Community Rules, and Privacy links;
- checkbox and disabled-until-checked `Accept and continue` action;
- sign-out/necessary escape route to avoid trapping users.

Do not remove global Settings/Help routes or access elsewhere. Check visual layout, semantics/accessibility, and English/Italian localization. Remove unused strings only if safe.

### C. Tests and release safety

- SQL/security tests: owner reads, other-account denial, anonymous denial, forged actor/timestamp, duplicate and concurrent acceptance, and different versions.
- Mobile tests: no backend record, successful first acceptance, second-device/reinstall simulation, new policy version, read/write error and retry, account switch or sign-out during in-flight work, double tap, protected-route gating, invitation return, Back behavior, and absence of exactly the three targeted buttons.
- Update existing test fixtures that currently simulate the device-local store. Prefer deterministic backend fakes for Flutter unit/widget tests and dedicated integration coverage for SQL.
- Update the policy README and relevant docs accurately. Keep the pinned policy bundle version unchanged unless the **actual legal text** changes; synchronize website metadata when a bundle bump is genuinely needed.
- Run the repo's relevant prescribed checks and report commands/results, including any skipped or unavailable checks. Do not claim real-device testing unless performed.
- Make clear whether hosted database migration must be applied **before** shipping the mobile change. Do not deploy, publish, or merge without permission.

## Codex workflow / deliverable

1. Fetch the latest `main` and inspect current policy/mobile/database conventions, recent related PRs, and existing tests.
2. Choose the smallest sound backend schema or API and implement it alongside Flutter storage/controller updates and the three UI removals.
3. Add targeted tests and update affected documentation.
4. Open a **focused PR**. In its description, distinguish verified results from untested paths, state the migration/deployment sequence, and list any remaining security limitations.
5. Report the PR URL, tests, manual follow-ups, and any assumptions that diverged from this plan.

Do not add an existing-user consent migration or automatic local-to-backend conversion. The developer/tester can explicitly accept the policy again after the backend rollout.
