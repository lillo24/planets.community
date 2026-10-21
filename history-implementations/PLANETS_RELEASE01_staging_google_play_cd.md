# PLANETS RELEASE01 — Staging migration deployment + Google Play closed-testing delivery

**Repository:** `lillo24/planets.community`  
**Target source:** current reviewed `main`, not an old branch or local build  
**Target backend:** `planets-staging` — Supabase project ref `cllpvruvrrvxczjitlqd`  
**Target Android app:** `community.planets.app` — existing Google Play **Closed testing** track only  
**Scope:** immediate release readiness and a repeatable, low-friction staging/closed-testing deployment pipeline. No production deployment.

## Goal

Make the already merged PLANETS features testable through an updated **Play-installed app** backed by the corresponding hosted Supabase schema.

Establish a release process that, **after initial configuration and database reconciliation**, can automatically deploy reviewed migrations from `main` to **staging**, verify the backend, build a correctly signed/versioned Android App Bundle, and deliver it to the existing Google Play closed-testing track. Routine releases must not require reconstructing a manual checklist or copying migrations one by one.

Work toward completing the first release in this task, **not just proposing future tooling**. If permissions or safety gates prevent a hosted write or Play upload, finish the safely testable pipeline, produce an actionable blocked-step report, and do not claim deployment occurred.

## Confirmed starting evidence (reinspect immediately)

1. `RESOURCE-UX01` merged as [PR #279](https://github.com/lillo24/planets.community/pull/279), merge `c6f66f3148ff8d238bfd33825f82f88302d0f517`. It puts Save search beside the keyword field and collapses the Donate/Exchange selector.
2. `RESOURCE-CAT01` merged as [PR #282](https://github.com/lillo24/planets.community/pull/282), merge `f37b818d7424942daa50ec644483d4e5d0b533ad`. It provides nine categories across listings, filters, category-only saved searches, notifications and maps.
3. `docs/development/resource-cat01-categories.md` requires additive migration `supabase/migrations/20261021155653_resource_cat01_categories.sql` **before** the new mobile client is distributed. Category-aware Resource endpoints use new `*_v2` RPCs; old-client calls remain compatible. Existing listings retain NULL categories.
4. `.github/workflows/validation.yml` runs on PRs or manual dispatch, and `docs/development/ci.md` explicitly says it does **not** run after pushes to `main`. It is CI, not a hosted deployment pipeline. Do not weaken/change its existing change-scoped validation.
5. Read-only inspection on 21 Oct 2026: connected hosted `planets-staging` was healthy and had **97** applied canonical migrations, latest `20261020150706`; CAT01 was absent. The category-aware public Resource RPCs were also absent. Recheck current remote state rather than trusting these snapshots.
6. **Critical:** `docs/development/map-staging-rollout.md` recorded **25 other unapplied Group/contact migrations** after its 20 Oct deployment. Newer main's Messages code expects functions missing from staging, including `list_own_scoped_conversation_items_v7` and `get_own_message_unread_summary_with_contacts_and_discussions`. There may now be more than 25 pending. **Do not blindly push the entire current migration folder to staging or claim the whole app works after deploying CAT01 alone.**
7. `docs/development/play-closed-test.md` describes owner-held upload signing and staging config. `apps/mobile/tool/build_staging_bundle.dart` builds the ordinary AAB; `apps/mobile/tool/build_map_live_staging.dart` builds a **map-enabled** AAB with explicit version code and optional `--budget-basemap`. `docs/development/map-staging-rollout.md` records a deployed/enabled MAP-COST01 staging backend, but verify its present gates before selecting the v2 client flags.
8. App identity remains `community.planets.app`, pinned Flutter **3.47.2**, existing upload key/Play App Signing identity, demo tools disabled. The last documented Play code `2` was observed on 9 Oct 2026 and is **not** a reservation or proof of the latest code.

Read the latest repository, relevant deployment/rollback runbooks, current migrations, CI and actual Play/backend state before writing workflows or changing live services. Do not treat earlier design notes as proof that a live backend is current.

## External context and access — explicit blockers

The task may require access that Codex does not have through GitHub alone:

- Read/write access to the correct Supabase **staging** project, migration history, current SQL/RPC inventory and a legitimate CI deployment credential.
- GitHub repository Actions/Environments settings and secure secret provisioning.
- Google Play Console for the **existing PLANETS app**, its existing Closed-testing track and current highest accepted version code; Google Cloud Android Publisher API access, preferably a narrowly scoped Play service account.
- The original Android upload keystore and credentials, currently expected to be in ignored local files or protected owner-held storage. **Never generate a replacement upload key to get past a missing original.**
- Ignored staging config or secure Actions equivalents (`APP_ENV=staging`, actual backend URL, client-safe publishable key, demos off).
- Optional real-device access to Android serial `48091FDAS0041A`, only when connected/authorized; testers obtain the release from Play.

**Before any downloadable link or release artifact, clearly identify which of these are needed but inaccessible to Codex.** If essential information is absent, stop only the step needing it: never invent credentials, signing identities, track names, migration approvals, Play version codes or API results. Never reveal secret values or private user records in logs, artifacts or PRs.

## Phase 1 — Exact migration inventory and one-time staged reconciliation

1. Pull latest `main`. Fetch the **live** staging project identity and its applied migration versions. Compute the complete migration delta versus `supabase/migrations/`, including earlier-timestamp unapplied files, duplicate/missing versions, historical differences and changed dependency order.
2. Produce a concise machine-readable **pending migration manifest** showing every pending file, SHA-256, prerequisite, affected domain, expected data/security effects, whether current app code requires it, and whether rollout approval exists. Distinguish CAT01 from unrelated Group/contact features and any provisional/unapproved privacy-policy changes. Review the corresponding docs, especially `member-contact-backend-review.md` and the staging rollout report.
3. Assess the real database's pre-existing data and migration-history compatibility using non-destructive reads; compare canonical hashes where available. Do not rewrite history, mark SQL applied without running it, or sidestep migration tracking.
4. Rehearse the actual approved pending set in the disposable CI/local Supabase stack with populated predecessor data, auth/RLS/grants, generated types, and idempotent second invocation. Do not run destructive fixtures against staging.
5. **Apply to staging only the set that is explicitly in scope and proven safe** using the repository-supported Supabase CLI or authorized migration API with correct canonical timestamps, recorded after successful execution. The user's request authorizes preparing/releasing CAT01, **not automatically approving dozens of unrelated or legally unresolved migrations**. If the newer mobile client needs those migrations, report the exact gap and obtain the required approval instead of deploying a broken client.
6. Run post-deployment remote checks: applied version/hash parity; category-aware listing/create/edit/saved-search RPCs; legacy-call compatibility; strict category validation; privacy/grants/RLS; affected Messages/Group calls; metadata/Storage preservation; read-only or narrowly controlled synthetic auth tests. Avoid inspecting or exposing real user content. Record sanitized evidence.
7. A failed/partial migration **blocks Play publication**. Do not reset, reseed, delete data, drop users, disable RLS, use `--include-all` without reviewed scope, or add dangerous grants. Review practical backup/recovery options for this Free-plan staging project; if recovery is not established for consequential writes, clearly surface that risk before executing them.

## Phase 2 — Make staging migrations automatic for subsequent merges

Implement a minimal, auditable deployment pipeline, preferably a **GitHub Actions workflow dedicated to staged releases** with `workflow_dispatch` for immediate first deployment and a guarded `push` on `main` after bootstrap. The owner should not repeatedly execute migration commands by hand.

Requirements:

- Restrict the remote target to `cllpvruvrrvxczjitlqd` by verified identity; protect staging credentials using GitHub Environment secrets, branch restrictions, least privilege and concurrency. No credentials in client builds.
- Migration **preflight → apply → verify** must be deterministic and idempotent. Never silently apply an unexpected historical backlog. Initial 25+ migration catch-up is a distinct reviewed/approved step. Once staging is reconciled, genuinely new reviewed `main` migrations can deploy automatically, with fail-closed drift/security checks.
- Build in adequate pre-release verification. Preserve existing PR CI coverage and do not rely on skipped checks as evidence that affected code passed. Avoid duplicate deployments if Supabase's native GitHub integration is also configured: pick **one** migration deployment owner and document the choice. Native GitHub integration is an alternative, but it must not be enabled blindly against the current historical backlog.
- Add clear status, safe failure notification, hashes, migration versions, tested commit SHA, and a straightforward retry/resume route that does not falsely record success.
- Hosted deployment and production deployment must remain distinct. Do **not** deploy to a future production backend, migrate live production data, enable paid providers or loosen policies.

## Phase 3 — Signed AAB → the existing Google Play Closed-testing track

Build distribution from the exact tested `main` commit, **only after required hosted APIs are verified**:

1. Find the existing Play app and correct closed-testing track **by reading Play Console/API**, not by guessing. Determine the highest already-used version code, then choose a fresh higher one with concurrency protection. Never overwrite or try to reuse an uploaded version code.
2. Preserve the permanent package `community.planets.app`, existing **upload** signing certificate, min/target SDK contract (target >= 36), release variant, current publishing policies, app links and testing audience. Store keystore/passwords as protected files/secrets, with restrictive permissions and cleanup. Do not commit either signing material or staging config.
3. Use the existing vetted map-enabled staging build path (`dart run tool/build_map_live_staging.dart appbundle <VERIFIED_UNUSED_VERSION_CODE> [--budget-basemap]`) rather than accidentally shipping the ordinary map-disabled defaults. Choose `--budget-basemap` only when the deployed MAP-COST01 schema/provider, license and bounded credits are verified; preserve existing budgets. Record actual nonsecret map defines. Do not introduce direct client Geoapify/service keys.
4. Build an upload-signed `.aab` from a clean pinned source and config; inspect the resulting artifact (package, version, SHA-256, upload certificate, target SDK, debug status, real staging HTTPS backend, disabled demos). Fail if config points to local/mock or is missing.
5. Provide both (a) a downloadable/persisted build artifact for manual owner upload if automatic Play access is absent, and (b) a secure supported Play Developer API upload workflow when access is configured. Use the existing **Closed-testing** track only, keep the existing cohort, and never submit to production. Start by requiring explicit first-release approval through a protected environment or equivalent; afterward allow routine closed-test publishing directly from reviewed `main` when all gates succeed, as requested.
6. Check the actual Play API/Console release/edit status after uploading. Pending review, draft, processing, published, and installable are different states. Do not say “published” or “testable from Play” until verified. If Google-side account configuration, release permissions, upload key or track is missing, provide only the minimal concrete owner setup steps and finish the rest of the implementation.

Google Play Developer API access may require a Cloud project, API enablement, Play Console invitation/permissions for a service account and secure CI credentials. Verify current official instructions; do not invent or request secrets in chat.

## Phase 4 — Smoke tests and evidence

Verify, where credentials/devices permit, a Play-distributed build against **hosted staging**, not a local container:

- Signed-out Scambio-Dona Browse; keyword, locality, Donate/Exchange, categories, combination/clear/reset; category-only saved-search Save/Edit/Open; account switching.
- Create/publish/edit a category-bearing listing and browse it; confirm old NULL-category listings remain visible under All and do not falsely match a specific category.
- List ↔ Map filter handoff and Resources/All map results with map flags/budget/guest fallback.
- Ordinary OTP, Projects, Tavoli, Messages/unread and relevant Group flows, especially ones affected by pending migration gaps.
- Existing app/photo permissions, storage, exact-vs-public location constraints, and non-privileged API access.
- On device `48091FDAS0041A`, if connected, inspect the Play-installed version via **read-only** ADB. Do not uninstall, wipe data, replace the user's Play install with a sideload, or capture credentials. The actual QA install must use the Play track.

Use safe owned test identities; avoid spamming notifications or consuming significant paid provider credits. Record source SHA, database migration versions, sanitized smoke results, bundle fingerprint/hash/code, track/release status and remaining blockers. No fabricated green checks.

## Scope, tests, and handoff

- Keep this as one **release-plumbing task with sequential backend and Play gates**. Do not redesign Scambio-Dona UX, alter CAT01 taxonomy, change app package identity or refactor unrelated features.
- Add focused automated tests for migration-diff detection/allowlist approval, stage target mismatch, unreconciled history, no-op retry, absent credentials, signing/version errors, map flags, blocking Play upload after backend failure, and correct track selection. Use mock APIs for Play-side tests; never publish from CI tests.
- Update `docs/development/ci.md`, `docs/development/play-closed-test.md`, `apps/mobile/tool/README.md` and a concise release runbook/incident procedure. Include a short first-time account-owner secret/permission setup checklist.
- Implement on a focused branch from latest `main` and open a PR. After green CI and any required explicit infrastructure approval, merge through the normal repository workflow; never directly commit application/workflow changes to `main` outside the PR. Do not let this plan file itself trigger deployment.
- **Do the first staged rollout and closed-test delivery only when the current migration scope, credentials, tested artifact and safety checks permit it.** If blocked, leave the validated repeatable release workflow and the exact next actions; do not halt all useful work.

### Completion report

Return: (1) PR/merge/current `main` SHA; (2) current staging migration delta including the unrelated backlog, reviewed/approved status and remote hashes; (3) actual hosted migrations applied or explicit blockers; (4) exact staging verification results; (5) GitHub deployment workflow triggers, secrets and one-time owner setup; (6) signed AAB artifact path/hash/package/version/code/cert, if created; (7) verified Google Play Closed-testing track and release state/link, if available; (8) tested user flows including Play-device QA versus simulated QA; (9) any safety warnings and the single smallest next action needed to complete deployment.

**Do not claim any hosted migration, Android build or Play upload happened unless it did.**
