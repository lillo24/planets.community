# PLANETS STAGING-AUTO02 — Temporary no-backup staging, safe migration continuity

**Codex implementation prompt.** Make a focused follow-up to STAGING-AUTO01 (#289). The founder wants to continue development **without configuring R2, routine encrypted backup jobs, or restore rehearsals right now**. This is a deliberate **staging-only acceptance of potential data loss**, **not** a statement that the database is empty, permission to erase existing records, or approval of arbitrary SQL.

## Goal

Once enabled, PLANETS staging should receive migrations that have passed the repository's existing classification, CI, permissions and migration-history checks **without a backup/restore requirement or repeated waiver prompt**. Review-required SQL stays review-required. Keep the ability to switch to verified backups later. The separate Android/Play release flow must not be activated.

Implement the change, verify it, merge via the protected PR workflow when eligible, and leave a precise one-time route to catch up the three already-merged pending migrations. Do as much read-only environment verification as tools allow. Do not perform a hosted SQL write unless the canonical migration review/approval guards are satisfied.

## Repository evidence checked 22 Oct 2026

- Repository: `lillo24/planets.community`. Main was `a3ae3bfb467bab2f5f5f1ac1d85d9c055f028da8` at planning time, including STAGING-AUTO01 #289 and subsequent Closed testing Mock correction #290. Recheck HEAD and active integration PRs before editing.
- Active GitHub `Protect main` ruleset #25636573 requires PRs and five Validation checks (Change classification, Mobile, Web, Site, Database); no owner review for ordinary code. Treat it as an immutable protection boundary, not an obstacle to bypass.
- `AGENTS.md` **already** says: “Validated backward-compatible migrations merged to `main` may auto-deploy to staging; destructive or unverified changes require explicit approval.” **Do not add an essay or duplicate rule to AGENTS.md**. Edit it only if a real contradiction demands a one-line change.
- `scripts/release/writer.mjs` currently unconditionally calls `verifiedRecovery` from `scripts/release/recovery.mjs` before applying any pending migrations. That function requires a source-hash-pinned `.github/workflows/staging-recovery.yml` with fresh proof of encrypted **DB and Storage-object** backups and successful restores. That workflow does not exist. Remove this **unconditional** dependency for the deliberately opted-in development-staging mode; do not falsify a recovery receipt.
- `scripts/release/{migrations,safety,reviews,reconciliation,writer,staging}.mjs` already enforce canonical SQL fingerprint/history, whole-set authorization, pre-merge owner review for nonroutine SQL, verified populated rehearsal, exact tested `main`, staging identity, session-lock/TLS, RLS/Storage/grants, and bounded `--include-all` for a historical gap. Preserve these boundaries.
- `.github/workflows/staging-release.yml` has a single staging writer and explicitly manual-only Android/Play build/publish. `STAGING_RELEASE_ENABLED`, `STAGING_AUTOMATION_READY` and `STAGING_AUTO_PUBLISH` were OFF/unset at last verified release snapshot. The user has since configured the scoped staging `SUPABASE_ACCESS_TOKEN`, `STAGING_DB_URL` and `STAGING_DEPLOYMENT_OWNER=github-actions`; **presence is not evidence that the DB URL works with TLS**. The user turned off Supabase's own `Deploy to production` GitHub integration for the project; verify if available.
- Live read-only migration inventory was confirmed again: `planets-staging` (`cllpvruvrrvxczjitlqd`) has **123 of 126 canonical versions** applied. Remaining:
  - `20261021152141_profile_avatar_variants.sql` — SHA-256 `a79fb44d09a12fa9289d68d652c33850232b2bfb74b7974a27fff93b4a95eafc`; historical gap; adds private thumbnail metadata and secured V2 photo RPCs.
  - `20261021193500_notification_projection_atomic_claim.sql` — SHA-256 `9c812abdf8c423d9e395b3c47cc8b958f73186cba62c106792c029cc043a6c14`; changes notification-worker claim semantics with definition checks.
  - `20261022084023_external_activity_catalogue.sql` (ACTAPI) — SHA-256 `3d777c5a3a2863c8f56bb9145be14ea94ebf38fcf2f454b196d325bbb6601bd6`; new secured catalogue tables and API.
- `scripts/release/reconciliation.json` is currently **disabled** and binds only the first two exact migrations to a known predecessor. ACTAPI has its own security review; do not secretly add it to historical `--include-all`.
- The older staging audit counted **355 rows across 126 tables** (including metadata and potentially account/test records). The founder considers the current staging data expendable and explicitly chooses to accept the no-backup risk **for this early-stage environment**. Never claim the DB is literally empty or use this decision to justify `db reset`, seeding, dropping or rewriting existing data.

## A. Replace mandatory backup recovery with explicit staging-only mode

Introduce a **single simple, owner-controlled protected environment setting** (e.g. `STAGING_RECOVERY_MODE=development-no-backup`) with these semantics:

- **Absent/unknown:** fail closed before any migration write. No implicit waiver and no fallback based on detected row counts.
- **`development-no-backup`:** for only `planets-staging`, allow a properly reviewed/validated staging SQL deployment **without calling the backup/restore verifier**. This setting means “current staging data may be lost if a defect occurs”; it does **not** authorize destructive/unreviewed SQL. Require the existing deployment owner, validated main SHA, protected environment readiness, project-identity and all existing SQL safety checks. Log a concise sanitized waiver status in the safety artifact; **never** emit invented backup hashes, restore timestamps, or `database_restored=true`.
- **`verified-backup`:** continue to support the current real backup/restore verifier for later use with valuable data. Do not delete `recovery.mjs` or undermine the existing receipt validation, although its current workflow is deferred. Switching back must work without rewriting historical migrations.
- Keep the choice **stable across routine merges**: no recurring founder prompt, no per-migration waiver file/hash and no new paid backup provider. Clearly document that the owner must switch to a verified recovery mode before the staging database starts holding irreplaceable user data.
- Preserve distinct default-deny treatment for any other project, Mock, production or app-store operations. Treat `STAGING_AUTOMATION_READY` as a separate deployment-readiness gate, not a substitute for the explicit recovery mode.

Choose the smallest consistent implementation: adapt `writer.mjs` and its existing recovery interface/helpers and configuration plumbing. Do not build a second deployment system.

## B. Keep staging protection, simplify activation

Preserve all STAGING-AUTO01 review and rehearsal behavior. An eligible `main` push may only run the staging migration deployment; it must **never** trigger an AAB build, upload, or Play release. Leave `STAGING_AUTO_PUBLISH=false` and the `planets-play-closed` reviewer restrictions unchanged, including the independent normal-staging versus Mock build variants from #290.

Update `docs/development/release01-staging-play.md`, `scripts/release/README.md` and other directly contradictory release notes to replace “backup workflow required for *every* staging migration” with this **temporary explicit waiver alternative**. Retain verified-backup instructions as an optional future path. Document one-time owner configuration of the mode, plus which credentials/connection checks and environment protections are still required. Do not fill `STAGING_RECOVERY_POLICY_JSON` with dummy values. Avoid expanding `AGENTS.md`.

The current GitHub `planets-staging` environment still had a required reviewer in the last audit. Once required safeguards and configuration have been verified, give exact steps to remove the **staging-only** reviewer; keep main-only restriction and no admin bypass. Do not silently modify unavailable account settings. Existing scoped `SUPABASE_ACCESS_TOKEN` is limited to staging; keep deployment through an independently verified session database URL on port 5432 with certificate validation; don't accept transaction-pooler 6543, disable TLS or extract credentials. Check that Supabase's native auto-deploy remains OFF so there is one writer.

## C. Finish the *bounded* outstanding staging catch-up without weakening review

After code and safety CI are green, re-inventory **live** staging/main (the three-file snapshot may have changed). If the same three remain, use the existing exact-SHA `reconciliation.json` mechanism for the avatar historical gap; do not edit migration timestamps, rewrite applied history, widen `--include-all` or mark an existing migration applied without executing it.

The founder's **no-backup acceptance does not bypass SQL review**. Keep the precise owner proof required by `reviews.mjs` for the already-merged, nonroutine migrations, including ACTAPI's separate review. Where the historical pre-merge check cannot be retroactively satisfied, use the established one-time reviewed reconciliation PR route, with the exact predecessor/files/hashes and security/data consequences stated. Reuse the populated 123→126 rehearsal only when it still matches the current source/predecessor; otherwise regenerate.

If relevant approvals and access are available, complete an exact current-source, guarded **staging-only** reconciliation after the implementation PR is merged, verifying history, existing rows, grants/RLS/Storage, required RPCs, backend readiness and idempotent retry. The user accepts **no backup for this staging operation** under the temporary mode, but has **not** waived the migration security review. If credentials, review evidence, environment settings or TLS cannot be verified, **stop before the database write and return only the specific one-time action(s) required**; do not ask for another backup authorization or pretend staging is synchronized.

## Test and acceptance

Add focused tests to `scripts/lib/staging-auto01.test.mjs` / `scripts/lib/release01.test.mjs` (or a small new sibling) proving:

- Missing/invalid recovery mode blocks SQL; staging-only `development-no-backup` with otherwise valid guards proceeds **without** fetching or fabricating a backup receipt; recovery evidence correctly records “waived” and no restore claim.
- `verified-backup` still requires genuine, fresh matching DB+Storage restoration; wrong project, Mock, production, stale main, wrong DB URL, incorrect owner or missing readiness all fail closed.
- Review-required SQL, historical gaps, mixed pending batches, changed hashes, unreviewed ACTAPI, old predecessor, unsafe grants/RLS, failing CI/rehearsal and unexpected live data/history changes **remain blocked even with the waiver**.
- Clean zero-pending runs remain no-op. Subsequent routine eligible migrations require no new backup approval; manual-only Play/Android and mock/production isolation are unchanged.
- Source/log/artifact scanning finds no secrets, raw user records, invented recovery proof, or backup data.

Run the focused Node tests, `npm run test:tooling`, formatting/actionlint, relevant SQL/safety integration, the disposable populated upgrade rehearsal, and complete four-area CI for this shared release change. State exactly which were run and passed. Do not use real staging as a disposable test database.

## External context and authorization boundaries

All product decisions needed **for the code change** are in this prompt. No external Google Doc, R2 account, backup repository, credentials or screenshot is required by Codex to implement and test the change.

External GitHub/Supabase environment configuration may still be required. Source settings and real database connection are user-controlled; Codex may inspect them if authorized, but must never invent credentials or claim verified connections from secret *names*. The staging-only backup waiver is explicitly authorized here, not production/Mock deletion. Existing dangerous-migration review is still mandatory. **Do not run a database reset, production SQL, application upload/publication, signed release rollout, Edge deployment or provider-billing change under this task.** If any active stage requires extra permission, report precisely what is missing.

## Deliverable

Use a separate branch/worktree and PR to latest `main` under the active ruleset. After CI, follow repository merge and cleanup conventions. Return: PR/merge link; exact no-backup mode name and owner-setting instructions; unchanged safety barriers; focused/full CI results; current staging count and whether the three-file reconciliation succeeded or is blocked; no-backup risk clearly acknowledged; unconfigured settings; confirmation that no AAB or Play publication occurred. Prefer finishing the one-time migration catch-up under existing review permissions rather than writing another generic plan.
