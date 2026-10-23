# PLANETS — STAGING-AUTO03 and MAPMOCK01 continuation

**Codex implementation handoff. Continue in the SAME MAPMOCK01 Codex chat.**
Prepared 23 October 2026; repository `lillo24/planets.community`. Start from fresh `main`, existing worktrees and current PR state.

## Goal

Establish **automatic code merging and guarded deployment of validated staging migrations**, without requiring the founder to copy an `STAGING-AUTO01-REVIEW` fingerprint for every nontrivial SQL change. Then **resume and finish existing MAPMOCK01 PR #300** in this chat, validate it under that policy, merge, and complete its eligible hosted map setup. Keep code merge, hosted SQL, Edge deployment, native qualification and Play delivery separately verifiable.

This prompt explicitly authorizes a **standing, bounded, development-staging-only migration policy** and implementation of MAPMOCK's narrowly scoped staging map endpoint after security tests and appropriate access checks. It is not blanket permission for arbitrary SQL, database resets, production deployment, exposing real users or increased paid map usage.

## Why earlier Codex stopped

The previous MAPMOCK01 prompt explicitly prohibited hosted migration/function deployment. Independently, `scripts/release/reviews.mjs` and `writer.mjs` require a human-authored exact JSON `STAGING-AUTO01-REVIEW` comment for almost all SQL beyond nullable-column additions, and `.github/workflows/staging-release.yml` is not activated. #300's additive privileged MAPMOCK SQL therefore failed the required classification gate **before** the remaining database CI, despite passing focused/native checks. It was following those constraints; they do not represent an intrinsic inability to migrate Supabase.

## Verified repository snapshot; REFRESH FIRST

- During preparation, `main` was `9945ad0102218f69acbafd543d8112aa8fa90cec` (COCREATE-DEPLOY01 #297). Canonical main held **142 migration files**; staging `cllpvruvrrvxczjitlqd` had **123 applied**, including historical gaps. These are volatile; **always compare exact live/current inventories and hashes**, not the counts or old three-file manifest.
- [MAPMOCK01 PR #300](https://github.com/lillo24/planets.community/pull/300) remains open at `81234b2bdbde1a2705ffddbd915c129f22c8f109`, behind `main`. It implements private default-off mock tile subcaps sharing the normal Geoapify global ledger, mock-only public image access and Flutter realm routing. Reported tests: 4,036 Mobile, 401 Web, 214 tooling, 221 genuine two-realm checks and 40 native fixture screenshots. **Required full SQL/rehearsal CI and hosted real pixels were not qualified.** Its SQL is `20261023054839_mapmock01_shared_public_basemap.sql`.
- Existing separate **STAGING-AUTO02 work is NOT MERGED**: [PR #293](https://github.com/lillo24/planets.community/pull/293) covers historical catch-up; [#294](https://github.com/lillo24/planets.community/pull/294) introduces `development-no-backup`; [#295](https://github.com/lillo24/planets.community/pull/295) includes TLS/CA session verification. Inspect their current ancestry, CI and changes; prefer reconciling the most complete validated parts of #295, not rewriting or merging incompatible copies blindly. The founder already accepted temporary **staging-only no-backup risk** in `history-implementations/PLANETS_STAGING_AUTO02_temporary_no_backup_staging.md`.
- Main's `scripts/release/{reviews,safety,rehearse,writer,recovery,migrations,staging,config}.mjs` and `.github/workflows/{validation,staging-release}.yml` enforce exact-source/SQL history, one writer, before/after security catalog, population rehearsal, RLS/Storage, no-invented-backup and guarded external delivery. Current five required GitHub checks are **Change classification, Mobile, Web, Site, Database**. Retain the ruleset.
- The signed Closed testing `closed-test-mock` release variant already compiles Mock and approved map flags. Production disables Mock. The new mock map Edge service from #300 has NOT been deployed merely by merging its source.

Read root/nested `AGENTS.md`, `docs/development/codex-tooling.md`, `implementation_plan_sections_suggestions.md`, current architecture/release docs, effective migration definitions, latest relevant PRs and pinned Supabase/Flutter tools before changing anything. Do not assume a historical folder/SQL version is current.

## Phase 1 — Permanent release/approval workflow, separate policy PR FIRST

### 1A. Separate PR checks from hosted deployment authorization

Keep the repository's five required checks and populated semantic migration rehearsal. For each new migration, generate a durable, sanitized, machine-readable receipt: exact PR head/tree, SQL version/hash, predecessor digest, observed catalog/security effect, real-actor RLS/API tests, populated-row preservation, upgrade/retry evidence and a deployment status:

- **auto-eligible-for-staging** — independently verified, bounded/backward-compatible under the predeclared staging policy;
- **review-required-for-hosted** — source can be merged if genuinely valid, but automatic hosted application is withheld for a concrete unproven risk;
- **blocked-unsafe** — broken tests, confirmed data/security violation or unparseable/unrehearsable migration blocks PR itself.

`Change classification` must NOT fail merely because the founder did not paste an owner-SHA comment. Required CI may still fail for *actual* safety or test failures. No automated impersonation of the founder, fake owner comments, bypassed rulesets or synthetic security checks. Publication/deployment independently checks the final merged source and authorization decision. A merged SQL file is **not automatically hosted-compatible** unless the staging writer explicitly qualifies it.

### 1B. Extend machine-verifiable safe SQL beyond nullable columns

The old `classifyMigration` permits only a tiny grammar. Add a bounded **non-destructive additive** class with tests for:

- isolated private tables with RLS, no unintended direct user grants, safe indexes/constraints and no data overwrite;
- narrow service-only functions/RPCs with enforced actor/issuer boundaries and no new public reads;
- carefully reviewed `CREATE OR REPLACE` wrappers that retain signature, OID, ACL, secure search path and **actual established permission/data behavior**, not merely the same function name;
- default-off private budgets/leases like MAPMOCK, with shared provider ledger, concurrency locks, caps and true RLS-denial tests.

Require structured SQL inspection, independent catalog/grant/policy diffs, **populated canonical replay**, generated types, applicable HTTP/Auth/RLS/domain tests, concurrency and backward compatibility. No universal "SQL without DROP is safe" shortcut; new privileged function bodies require independent tests of their effects. Reject or hold for targeted decision when the proof cannot cover an access expansion, destructive/backfill action, role/grant/RLS weakening, existing contract change, secret leak or history rewrite. Keep failure messages specific, not a blanket manual-fingerprint requirement.

To prevent self-approval, policy/validator/CI changes must be reviewed and tested **against a trusted pre-change base** in an isolated policy-only PR before those revised checks can qualify product SQL. Do not modify checks and privileged MAPMOCK SQL in one self-certifying integration PR. A passing test authored by the same unsafe migration must not be the sole approval evidence.

### 1C. One protected staging writer, standing no-backup mode

Reconcile #294/#295: allow protected environment `STAGING_RECOVERY_MODE=development-no-backup` for **only** `planets-staging` `cllpvruvrrvxczjitlqd`, recording the explicit acceptance of possible staging data loss **without inventing recovery evidence**. Preserve `verified-backup` mode and fail closed for unknown/missing modes. The waiver does **not** authorize resets, destructive SQL, deleting records or expanding real-user privileges. If current staging begins to hold irreplaceable personal data, require a reviewed backup policy before continuing.

Reuse existing `STAGING_RELEASE_ENABLED`, `STAGING_AUTOMATION_READY`, `STAGING_DEPLOYMENT_OWNER=github-actions`, protected environment and the **strict TLS session-pooler CA verification** already worked out in #295. Do not extract/move credentials, disable server certificate validation, expose DB URLs in logs or create a competing writer. Verify Supabase's native GitHub migration-deployment integration is disabled so only the repository's writer mutates staging.

Once one-time environment readiness is verified, an eligible `main` merge should run automatically:

1. Exact HEAD Validation + applicable SQL rehearsal against a disposable populated predecessor.
2. Read-only live project identity, current migration hashes, grant/RLS/Storage and existing-data drift checks.
3. Classify **the whole pending dependency set** and reject it before any intentional write if any required predecessor cannot qualify.
4. Serialize through one protected advisory-locked staging writer, use the existing scoped Supabase CLI with dry-run, timeout/transaction bounds, verified TLS and ordered canonical migration files.
5. Re-read authoritative migration history, existing rows, table/function grants, RLS, required API/RPC responses; verify no-op retry and preserve sanitized evidence.
6. Surface exact success/failure, source SHA and remaining gap automatically. A failed/partial deployment must stop until independently reconciled, without marking unexecuted SQL applied.

This workflow is **staging only**. Do not automatically upload AABs, submit Play edits, send real invitations, deploy production, modify the mock provider budget, invoke expensive Geoapify requests or change billing. Keep `STAGING_AUTO_PUBLISH=false` and the separate Play owner's controls.

If Codex lacks permission to set a protected environment variable, finish code/CI and provide the **one-time exact UI setting** and current read-only blocker. Do not request repeated manually authored JSON review comments. Existing secrets should be reused via their protected names, never pasted in chat or the repository.

### 1D. Non-contiguous migration history and staging catch-up

Current source and remote history may be substantially out of sync. A prior STAGING-AUTO02 #293 covers only three historical migrations; it is **not the entire current backlog**. Recompute all canonical file hashes/dependencies and applied versions from live `main` + hosted staging. Rehearse the exact non-contiguous upgrade with representative existing Auth/profile/Storage data and catalog security checks. Do not guess chronological order from the latest version alone, allow `--include-all` without an independently bounded approved set, reset staging or use `migration repair` to mark SQL applied.

Automate delivery of the entire **qualified** dependency chain, including older safe holes, one controlled migration at a time with real after-each-file verification. If any dependency or privilege change is not provably safe, report the version and specific failed security/replay invariant, and do not apply a misleading safe prefix. New source merges during execution invalidate the old plan and require fresh validation. Preserve old records and demonstrate no-op repeat.

### 1E. Policy tests and integration order

Test using disposable, populated Postgres and synthetic actors: additive private tables and service-only APIs; MAPMOCK actor isolation; changed function body but same signature; RLS/grant widening; definer context changes; hidden triggers; malformed SQL; destructive DDL; historical reordering and stale predecessor; failed no-backup setup; missing CA; partial apply; two concurrent writers; change to CI policy within the PR; source SHA drift; changed ledger/quota; protected production/mock endpoints; security evidence missing or fabricated. Keep full five CI checks mandatory. Use existing tooling/tests; do not mute or skip failures to obtain green status.

**Merge policy PR first**, independently of PR #300. Carry forward #295's viable TLS/no-backup code rather than merging both #294 and #295 blindly; reconcile/close superseded drafts only after proving all intended changes landed. Rebase any downstream work on this trusted policy. Do not mix the first change to its own approval rules with #300's new privileged migration.

## Phase 2 — Continue **existing MAPMOCK01 PR #300 in this same Codex chat**

1. Refresh `main` after the policy merge and reconcile open [#300](https://github.com/lillo24/planets.community/pull/300) with current COCREATE/Mock updates, keeping its commits, real two-realm checks, provider-isolation/credit model, native screenshots and PR history. **Do not create a competing MAPMOCK implementation.**
2. Run the new automatic staging safety classifier against the actual `20261023054839_mapmock01_shared_public_basemap.sql` and effective predecessor. Confirm the private mock config/claims, normal map-function OID/ACL invariants, service-only access, one global ledger, separate mock subcaps, source/TTL and denial cases. If proof fails, fix the implementation or narrowly improve the trusted test harness, not waive its results.
3. Run the previously blocked full Database CI/populated migration rehearsals and all affected Mobile/Web/tooling/native tests on **final rebased source**. Prior 4,036/401/214/221 tests and 40 fixture screenshots are useful evidence, but not a substitute for final-head checks. Keep branch protection intact. When actually mergeable and green, merge #300 and verify `main` contains its changes.
4. **Finish hosted SQL deployment**, not merely documentation: apply the qualified MAPMOCK migration and safe pending predecessor files to `planets-staging` through the newly activated protected writer. Prove actual migration history, catalog/grants/RLS, protected normal map RPC compatibility, actor isolation and preserved global credit ceiling. If an unsafe historical migration blocks staging, name it and retain a truthful deployment-blocked status.
5. Reconcile the dedicated `planets-mock` project's canonical schema/fixture generation after COCREATE-DEPLOY01 using its existing guarded mock operator. Preserve all fictional persona identities, shared chat history and mock edits; no blanket reseed/reset. Reverify the public one-tap persona broker without normal-login/roster restrictions.
6. **Activate the new staging-only MAPMOCK tile route** after verified SQL and separate mock-control readiness: deploy exactly the reviewed `mock-basemap` Edge Function, ensure it checks the fixed mock issuer/session within the handler if `verify_jwt=false`, preserve normal `map-provider` JWT verification, configure its default-off mock-specific cap and kill switch within the **unchanged shared Geoapify daily cap**, and record the actual function source/version in the release inventory. This prompt authorizes that *specific staging/mock functional activation* after tests; it does not authorize general Edge rollout, new API providers, additional paid accounts or larger spending limits.
7. Perform a small, bounded **hosted** acceptance: one or a few genuine PNG tiles from a fictional persona, verify nonempty real Geoapify image, shared staging cache/ledger charges, accurate attribution, public mock pins and no real user/private data. Limit the intentional smoke to **at most 12 quarter-credit units (3 credits)** total; stop if behavior/cost is unexpected. Test an ordinary normal-user map independently. If available, capture an Android emulator screen with **hosted real pixels** and fictional pins; don't relabel synthetic PNG fixtures as hosted success.
8. If the checked original upload signing key/config and unused Play version code are available, create and verify a signed **Closed testing** AAB with compiled Mock Mode enabled, six approved MAP-LIVE/BUDGET flags enabled, correct package/cert/source/SHA and no embedded admin key. **Do not upload or publish to Google Play automatically**; current authorization concerns staging migrations and the mock basemap deployment.

On missing external permissions or unsafe conditions, finish independent work and report the **specific one-time blocker**. Do not promise that the app is live just because source merged. Do not change real-account credentials, increase map quotas, expose mock tokens to staging product APIs, enable unreviewed paid static previews or route mock users to the normal database.

## Scope, authorization and stopping rules

- This is a **staging-only, test-environment authorization**: normal `cllpvruvrrvxczjitlqd` and the distinct fictional `pnolarmzxmmjtguligfc`, with correct separation. No production or other project is authorized.
- The founder accepts `development-no-backup` **data-loss risk** on development staging, not arbitrary deletion. Retain existing accounts/records and enforce migration non-destruction/compatibility checks. Preserve future `verified-backup` option.
- No secrets or direct service-role privileges in the app, test screenshots, analytics or GitHub artifacts. Any public tile gateway must remain limited to cartographic bytes, not arbitrary normal-staging resources.
- The mock demo remains open to anyone with the test app. That is why backend quotas, fixed caller/session validation and a reversible kill switch matter. Maintain normal map behavior and licensing/Geoapify attribution.
- If a migration introduces genuinely destructive or unprovable privacy/authorization changes, **block hosted application and request review of that concrete effect**; don't force an unreviewed migration into the “safe” class. The founder's desire for fewer prompts must not be implemented by making the security checks decorative.
- No hosted-reset, `db push --include-seed`, broad historical `--include-all`, rewriting already-applied migrations, self-manufactured owner approvals, ruleset bypass, automatic Play upload, production SQL or provider spending beyond the approved cap. One narrowly authorized hosted map smoke is included above.

## External access and evidence

Needed for **code work**: repository, existing PRs, local/disposable Postgres and CI. No Google Doc or uploaded screenshots are required. Needed for **hosted staging**: actual permitted Supabase/GitHub staging access, protected secrets/TLS route, one-time owner-controlled environment settings and scoped mock operator credentials (reuse existing approved protected configuration). These inputs must remain private; do not ask for passwords or a self-composed UUID/approval file in chat. If Codex cannot access GitHub environment settings, record only the one-off UI action needed and keep other work proceeding.

Run all targeted unit, database/RLS, migration replay, tooling, Flutter and native tests; run complete affected CI on the final tested SHA. Source snapshots, published CI, hosted migration receipts and screenshots have different evidentiary meaning. Avoid repeating expensive full suites after every cosmetic change; run them on each final integration boundary.

## Final report — in this SAME chat

Give a concise result with exact links/commit IDs:

1. **Permanent staging automation** PR, merged main SHA, automatic eligibility classes, updated five-check policy, one-time settings, tested TLS/no-backup mode and whether actual main-push staging deployment is enabled. Clearly separate a configured mechanism from a verified live run.
2. **Staging migration parity**: freshly queried canonical/applied counts, exact applied versions/hashes, populated upgrade+no-op evidence, preserved security/data, and any specific unapplied/unsafe migration.
3. **MAPMOCK #300**: final merged PR/head, source/runtime CI, native screenshot provenance, actual hosted mock endpoint/version and kill/budget configuration.
4. **Actual hosted imagery**: whether a real mock persona received visible real Geoapify map tiles in Android, observed charge within the **same global ledger**, and normal-map isolation. If not, mark this step **unverified**, not completed.
5. **Closed testing artifact**: actual signed AAB only if built and validated, source/version/hash, with Play upload clearly **not performed**.
6. Only genuinely unresolved one-time permission/credential/security decisions, and exact next step. Preserve PR #300 discussion/evidence as the continuous work record.

Do not stop after producing a new plan or after merging the policy code. Finish the requested PR continuation, migrations and verified hosted state wherever the existing authorized tools and safety gates permit.

## Repo references

- [MAPMOCK01 ongoing PR #300](https://github.com/lillo24/planets.community/pull/300) — original implementation, draft runbook and SQL.
- [STAGING-AUTO02 #293](https://github.com/lillo24/planets.community/pull/293), [#294](https://github.com/lillo24/planets.community/pull/294), [#295](https://github.com/lillo24/planets.community/pull/295) — existing outstanding work; integrate, don't rebuild.
- `scripts/release/{reviews,safety,rehearse,writer,recovery,migrations,staging,config}.mjs` and `.github/workflows/{validation,staging-release}.yml`.
- `docs/development/release01-staging-play.md`, `docs/development/mock-environment.md`, `docs/development/map-cost01-trento-baseline.md` and the current PR #300 `docs/development/mapmock01-public-basemap.md`.
- [Supabase migration practices](https://supabase.com/docs/guides/deployment/database-migrations) and [Edge Function authentication](https://supabase.com/docs/guides/functions/auth).