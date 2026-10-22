# RELEASE01 staging and Google Play closed testing

Current execution and remaining gates: [RELEASE01 status](release01-status.md).

The dedicated [workflow](../../.github/workflows/staging-release.yml) owns SQL
deployment to `planets-staging` (`cllpvruvrrvxczjitlqd`) and Android delivery to
the existing `community.planets.app` closed track. Production and iOS distribution
remain outside this workflow. The initial [live assessment](evidence/release01/assessment.md)
records the blockers; merging release plumbing does not resolve them.

## Explicit Android build variants

The workflow selects `release_variant=closed-test-mock` by default, including
future explicitly enabled push builds. Its Android environment must contain
`MOCK_CONFIG_JSON`: only `MOCK_SUPABASE_URL`, `MOCK_SUPABASE_PUBLISHABLE_KEY`,
`MOCK_PERSONA_BROKER_URL`, and `MOCK_FIXTURE_GENERATION`, all strings. The fixed
mock project is `pnolarmzxmmjtguligfc`, broker `/functions/v1/mock-personas`, and
generation `mock-world-2026-10-21-v1`. The existing private client build config
supplies these four fields; no human enrollment or real login is required.

The variant combines those public client values with the unchanged normal
`STAGING_CONFIG_JSON` and explicitly compiles `ENABLE_CLOSED_TEST_MOCK=true`.
Missing, foreign, privileged or incomplete mock configuration blocks the build;
there is no automatic ordinary-build fallback. Choose `release_variant=staging`
to build the ordinary test app with Mock off. Direct script use defaults to
`RELEASE_VARIANT=staging`; opt in with `RELEASE_VARIANT=closed-test-mock`.
Neither path accepts production. `APP_ENV=production` also suppresses the runtime
capability even with a stale true define. Existing map flags and signing remain.

The AAB inspector requires a single effective `PLANETS_COMPILED_MOCK_V1=true`
or `false` AOT constant in **every ABI**, agreeing with the chosen variant and
build provenance. The compile-time application loader checks that marker against
the actual `AppConfig.closedTestMockEnabled` gate and emits it once in the device
log without credentials. Missing/conflicting markers fail verification. Every ZIP
payload is scanned for privileged keys/JWTs. Publication rechecks the variant,
compiled receipts and exact AAB hash. Marker/config evidence proves build capability;
it does not prove hosted availability, Play publication or a complete device journey.

## STAGING-AUTO01 safety policy

Code merge and activation are separate. After one-time setup, eligible main
pushes deploy staging SQL without a second founder prompt. Android build and
Play publication require an explicit manual `build` or `publish` dispatch;
`STAGING_AUTO_PUBLISH=false` stays in place and cannot enable push delivery.
Production, Mock, Edge deployment, map provider settings and billing are outside
this change.

`safety.mjs` recognizes one complete, deliberately small SQL grammar:

```sql
SET lock_timeout='5s';
SET statement_timeout='60s';
ALTER TABLE private.example ADD COLUMN optional_note text NULL;
RESET lock_timeout;
RESET statement_timeout;
```

One or more nullable columns may target an **existing**, non-inherited, regular
`public`/`private` table owned by postgres/supabase_admin, with RLS enabled and
no anon/authenticated/service_role table access (RPC-only). Supported built-in
types are boolean, smallint, integer, bigint, text, uuid, jsonb, date and
timestamptz. Quoted names, defaults, constraints, data writes, privileged code,
new tables and all other syntax require review. A candidate is routine only
when its actual before/after catalog preserves existing columns, grants, RLS,
policies, triggers, functions, constraints, indexes and views, and the populated
rehearsal preserves every original row/column. SQL without DROP is not proof.
This narrow class avoids table rewrites/defaults and caps lock/statement waits.

Destruction, rewrites/backfills, incompatible contracts, permission expansion,
RLS/Storage changes, function/trigger changes, unknown syntax/history and stale
or absent evidence fail closed. A reviewed migration still needs the populated
preservation witness; intentionally destructive upgrades require a separately
planned recovery/execution path. The whole pending set is authorized before any
SQL invocation, so an unreviewed dependency cannot leave an intentionally
applied safe prefix. A later operational failure can still leave a partial
batch; see incident handling below.

### Review before merge

The existing always-present **Change classification** Validation job enforces
static risk review and, for SQL/release/baseline/workflow/dependency changes,
runs the disposable populated semantic rehearsal. Other PRs avoid that cost;
complete manual Validation always includes it. No path-filtered required check
is left pending. Canonical history edits/deletions are rejected; add migrations.

For review-required SQL, the failed job uploads `review-required.json`, containing
only staging identity, exact PR head SHA, migration hashes and the canonical
predecessor inventory digest. The repository's **numeric owner identity** must
post a PR issue comment with this exact prefix followed by that JSON:

```text
STAGING-AUTO01-REVIEW
{"project_ref":"cllpvruvrrvxczjitlqd","source_sha":"<40 hex PR head>","approvals":[{"version":"<14 digits>","sha256":"<64 hex>","predecessor_inventory_sha256":"<64 hex>"}]}
```

The owner reviews SQL effects, preservation/security evidence and operational
risk before posting. Then rerun the failed Validation job (and inspect the
semantic artifact if that gate requests review). No comments are manufactured
by automation. A new head or predecessor invalidates approval. Creation **and
last edit** must predate merge. Comments by bots/other users, malformed proof,
post-merge edits or wrong source are ignored. Deployment independently finds the
merged PR, re-fetches the owner's proof and the file at that original PR head,
and hashes those bytes. Merging despite failed CI cannot erase the missing proof.
Routine verified migrations need no comment or ongoing safe-manifest ritual.

## One-time owner activation (not performed by this implementation)

Keep `STAGING_AUTOMATION_READY` unset/false until all items below are verified;
leave `STAGING_AUTO_PUBLISH=false`. Code merge does not change live settings.
Recheck current main protection and environment rules rather than treating the
earlier release audit as current evidence.

1. In GitHub **Settings → Rules → Rulesets** (or Branches), protect `main`:
   require PRs, no force pushes/deletion, no bypass for the automation identity,
   and the existing **Change classification**, **Mobile**, **Web**, **Site** and
   **Database** Validation checks. Require up-to-date checks. The four area jobs
   may legitimately skip on unrelated PRs; the classification job always runs
   and includes migration semantics when affected. Keep release policy/workflow
   changes owner-reviewed; standing routine authorization never authorizes
   weakening its own guard. Do not require the separately triggered post-merge
   workflow as a universal PR status. Review exact final-head logs before merge.
2. Select protected staging variable `STAGING_RECOVERY_MODE` explicitly:
   `development-no-backup` accepts potential loss of current development staging
   data, or `verified-backup` requires the genuine recovery route below. Missing
   or unknown values block SQL. Verify credentials and main-only environment
   restrictions before removing any reviewer. The temporary mode needs no R2,
   backup job, restore rehearsal or per-migration waiver approval.
3. In Supabase **Project Settings → Integrations**, confirm native GitHub
   migration deployment is disabled for `planets-staging`. Keep one writer:
   staging environment variable `STAGING_DEPLOYMENT_OWNER=github-actions`.
4. Under GitHub **Settings → Environments**, retain `planets-staging`,
   `planets-android-build`, `planets-play-closed`, selected deployment branch
   `main` only, no tags. Keep the Play owner reviewer and disable bypass where
   supported. Only after the gates/recovery-mode/credentials are verified, open
   **planets-staging → Deployment protection rules → Required reviewers**, remove
   the staging reviewer and save. Retain its selected `main` branch restriction
   and no admin bypass. Keep the **planets-play-closed** reviewer unchanged;
   do not create an unprotected replacement environment.
5. Only staging credentials are required to activate automatic SQL. Android/Play
   credentials below are needed solely for later manual app delivery.
   Provision secrets through those environment settings or owner-run
   `gh secret set NAME --env ENV` with protected stdin; never paste values into
   chat/history/issues. All three use `SUPABASE_ACCESS_TOKEN` (legitimate scoped
   management access) and `STAGING_CONFIG_JSON`. Staging additionally needs
   `STAGING_DB_URL` (original direct/session-pooler route on port 5432, verified TLS;
   transaction-pooler port 6543 is rejected because the advisory lock is session-scoped).
   Android retains `ANDROID_UPLOAD_KEYSTORE_BASE64`,
   `ANDROID_UPLOAD_STORE_PASSWORD`, `ANDROID_UPLOAD_KEY_PASSWORD`,
   `ANDROID_UPLOAD_KEY_ALIAS`; build/publication retain
   `PLAY_SERVICE_ACCOUNT_JSON`. Use the original upload certificate. Existing
   `STAGING_CONFIG_JSON` string-key schema, client-safe publishable key,
   `ENABLE_DEMO_TOOLS="false"`, empty `SENTRY_DSN` and optional public Google
   client ID remain; no service-role/provider/database keys in that JSON.
6. Review the bounded historical catch-up below in a **new enabling PR**. Do not
   reuse the old `BOOTSTRAP_MANIFEST_SHA256` or task-specific waiver as blanket
   approval. This code PR leaves reconciliation disabled and grants no review.
7. For `verified-backup` only, configure real `STAGING_RECOVERY_POLICY_JSON` and
   fresh restoration evidence. For `development-no-backup`, leave that policy
   unset; do not invent receipt values. Dispatch read-only `inspect` from `main`
   while `STAGING_RELEASE_ENABLED` and protected readiness remain false. This
   manual-only exception retains the protected `planets-staging` environment;
   deploy/build/publish still require the release flag and successful exact-source
   validation/rehearsal. Inspect requires the actual `STAGING_DB_URL`: certificate-validated
   TLS on port 5432, a stable backend session and exact history agreement with the
   Management API; only sanitized booleans are retained in `preflight.json`.
   Connection startup and each SQL statement are bounded to 15 seconds.
   Check identity/history/backend evidence, then set protected staging
   `STAGING_AUTOMATION_READY=true` and repository `STAGING_RELEASE_ENABLED=true`
   after all prerequisites pass and dispatch
   `deploy` from current main. A missing/broken secret blocks inspection and
   writes; its name alone is not connection proof.
   Subsequent eligible main pushes need no environment reviewer prompt.

### Recovery contract

`STAGING_RECOVERY_MODE=development-no-backup` is a standing, staging-only acceptance
of potential data loss for `planets-staging` (`cllpvruvrrvxczjitlqd`). It does not
mean that staging is empty, permit resets/destructive SQL, authorize unreviewed
SQL, or extend the original bootstrap or bounded historical reconciliation.
All exact-source CI, populated upgrade preservation, review, TLS/session-lock,
history, RLS/Storage and deployment-owner checks still apply. The safety artifact
records `mode: "development-no-backup"`, `status: "waived"`, the staging reference
and predecessor digest, and `data_loss_accepted: true`; it contains no backup
hash, restore timestamp or claim of restored data. No recovery workflow is called.
The same protected setting applies across routine eligible merges without a new
waiver file or approval. It cannot activate Mock, production or app-store actions.

The owner must switch to `verified-backup` **before staging holds irreplaceable
user data**. No backup/restore infrastructure is configured by this code change.
For that future mode, choose an existing access-controlled destination and
isolated restore target, then implement/review
`.github/workflows/staging-recovery.yml` on protected main:

- Capture the identified staging DB schema/data (including Auth/private and
  Storage metadata) **and actual Storage objects** with a consistent recovery
  boundary; quiesce writes if needed. Encrypt both before storage, restrict
  access and retain decryption material separately under owner control.
- Restore both into an isolated, non-production target; verify schema/history,
  representative private/Auth data and object checksums/metadata together.
  A dump command succeeding, Storage metadata alone or an encryption claim is
  insufficient. Document retention, restore ownership and the chosen RPO there.
- Keep dumps/objects/keys/private records out of this public repository, logs
  and Actions artifacts. Upload **only** `recovery.json` as the single file in
  an artifact named `staging-recovery-receipt`. No sensitive object names/URLs.
  Use `if-no-files-found: error` and emit it only after both restores succeed.
- Pin/review that workflow and all called restore code/actions; a policy hash
  protects the workflow bytes, so mutable dependencies must not undermine it.
  Run on main by schedule or owner dispatch frequently enough for the selected
  freshness bound. No per-migration founder waiver is needed.

For `STAGING_RECOVERY_MODE=verified-backup`, configure protected environment
variable `STAGING_RECOVERY_POLICY_JSON` once:

```json
{
  "project_ref": "cllpvruvrrvxczjitlqd",
  "workflow_id": 123456,
  "workflow_path": ".github/workflows/staging-recovery.yml",
  "workflow_sha256": "<SHA-256 of owner-reviewed workflow bytes>",
  "policy_id": "<owner-generated UUID>",
  "max_age_hours": 1
}
```

`workflow_id` is obtained from `gh api repos/lillo24/planets.community/actions/workflows/staging-recovery.yml`;
compute the workflow hash from its exact Git bytes, for example
`git show HEAD:.github/workflows/staging-recovery.yml` read as bytes by a hashing
script. Choose/document `max_age_hours` explicitly (greater than 0, at most 24;
1 above is an example, not a selected RPO). The receipt contract is:

```json
{
  "project_ref": "cllpvruvrrvxczjitlqd",
  "policy_id": "<same UUID>",
  "predecessor_inventory_sha256": "<canonical version/hash inventory digest>",
  "completed_at": "<UTC ISO restore-completion timestamp>",
  "encrypted": true,
  "access_controlled": true,
  "database_restored": true,
  "storage_objects_restored": true,
  "database_sha256": "<encrypted database backup SHA-256>",
  "storage_objects_sha256": "<encrypted Storage backup SHA-256>"
}
```

Use `inventoryDigest` exported from `scripts/release/safety.mjs` on canonical
`version`/`sha256` rows matching **applied** live history after drift checks; it
is deliberately distinct from the remote raw-statement predecessor digest.
The writer checks the latest successful trusted main recovery workflow, its
pinned source hash, one unexpired bounded metadata ZIP, exact policy/target and
observed predecessor, fresh/non-future timestamp and both restore results.
Missing/changed/stale evidence stops before SQL in verified-backup mode; there is
no fallback to the development waiver. Recovery runs use credentials
scoped separately; this workflow never downloads real backups or decryption keys.
Any recovery code/policy change needs owner review and a new pinned hash.

### Bounded initial catch-up

The original 26-file hashes, boundary `20261021155653`, approval and execution
receipt remain unchanged. Fresh [read-only history observation](evidence/release01/staging-auto01-predecessor.json)
at main `97a215ca60dc35c30b4b9f652441bdb7c35937ba` found **123/126** applied,
zero drift and these three pending files:

| Version                             | Exact SHA-256                                                      | Classification                                                |
| ----------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------- |
| `20261021152141` avatar variants    | `a79fb44d09a12fa9289d68d652c33850232b2bfb74b7974a27fff93b4a95eafc` | Review: Storage policies, functions, triggers; historical gap |
| `20261021193500` notification claim | `9c812abdf8c423d9e395b3c47cc8b958f73186cba62c106792c029cc043a6c14` | Review: privileged worker/claim semantics                     |
| `20261022084023` ACTAPI catalogue   | `3d777c5a3a2863c8f56bb9145be14ea94ebf38fcf2f454b196d325bbb6601bd6` | Separate review: new schema/RPC/security semantics            |

`reconciliation.json` is **disabled** and binds only the original two-file pair
to that exact observed remote predecessor. A new enabling PR changes only its
`enabled` field after re-observation/rehearsal. The owner review request includes
all three independently hash/predecessor-bound approvals; the third gets no
historical rights. Review evidence can be verified from that enabling PR for
all observed pending files. Additional/new files retain independent review or
routine semantic requirements. Changed history means refresh the bounded plan,
not expanding `--include-all` globally. No timestamp/history rewrites.

The CLI directory contains already-applied files plus exactly one authorized
pending file per invocation. `--include-all` is used only for an approved
historical file. The whole mixed set must pass all guards first. After parity,
no pending pair means this reconciliation is unnecessary; future routine
migrations use their exact-source populated/catalog proof without new approval.

## Routine operation and release approval

`workflow_dispatch` defaults to read-only `inspect`. `deploy` runs complete
exact-main Validation and a fresh disposable populated rehearsal, then preflight,
whole-set authorization, recovery, lock, dry-run/apply and backend verification.
`build` additionally persists a verified upload-signed AAB; `publish` additionally
waits in `planets-play-closed` for approval of that persisted AAB and submits only
that artifact. Manual routes keep original signing/track/readiness checks.

Ordinary eligible main pushes select **deploy only**. Android/Play jobs explicitly
require manual dispatch even if the legacy auto-publish variable is true. Plan/
document-only commits do not trigger deployment. A single non-cancelling Actions
concurrency group and session advisory lock serialize hosted writers; direct and
management history must agree before writes. Main is freshly checked before
every CLI dry-run/apply. Complete exact-source Mobile/Web/Site/Database Validation
must pass (skips do not count for deployment), with matching per-file populated
witnesses from the same release run. A zero-pending deploy performs current
history/backend/HTTP verification and is a no-op, without requesting new review
or recovery. Drift still blocks readiness.

The disposable rehearsal reconstructs the observed 123-file non-contiguous
predecessor, seeds fictional Auth/Profile/Proposal data, checks original rows and
columns **after each file**, real Resource Auth/REST, no-op retry and generated
types. A rollback-only live pg_catalog fixture tests the routine positive path.
It accepts only a fresh credential-free Linux Actions stack; never use hosted
staging as test data. No real user rows or function bodies are uploaded.

The CLI receives no seed/role/Vault options. A session advisory lock and comparison
with independently identified management history protect application; applied
canonical versions/names/SQL fingerprints are verified afterward. SHA-256 of
original files and stored statement arrays is retained separately, with their
predecessor digest bound into bootstrap approval. Both database clients enforce
verified TLS; trust errors must be resolved using legitimate provider certificates,
never by disabling certificate checks. SQL fingerprints
ignore exterior comments/whitespace and empty terminators; literals, quoted
identifiers, statement boundaries and dollar bodies remain exact. They are not
claims of byte-identical CLI statement serialization.

Backend readiness includes current static mobile RPC names and explicit CAT01/
Messages contracts, RLS exposure, Storage limits/privacy, mutation grants, map
license/budget/TTL settings and pinned deployed Edge bundle/source identities.
New literal mobile Edge dependencies fail until their deployment/policy is reviewed.
The dedicated `mock_environment_config.dart` validator names a broker on its
separate Mock origin; it is excluded from the normal-staging Edge inventory.
RELEASE01 ordinary builds require `ENABLE_CLOSED_TEST_MOCK` absent/false and
all `MOCK_*` endpoint/key/generation fields empty. Build provenance and the AAB
receipt confirm Mock capability is off; its broker is never deployed to staging
as a workaround. The explicit `closed-test-mock` variant adds only the isolated
mock client target and requires compiled-on evidence; hosted mock readiness remains
a separate gate. It never deploys the broker to normal staging.
Anonymous HTTP verifies old/V2 listing reads, `22023` for an invalid category and
denial of authenticated Messages access. These probes do not log returned rows,
impersonate users or create hosted synthetic fixtures. They complement local
real-Auth create/edit/saved-search tests; authenticated hosted/device QA remains
an explicit smoke gate, never inferred from metadata.

Edge Functions are not automatically deployed. If an approved bundle/version or
matching source changes, delivery fails until that deployment is separately
reviewed and the release policy refreshed. Provider credits, licenses and budgets
are never changed by the workflow. MAP-COST01 is selected only while verified.

## AAB and versioning

The existing `build_map_live_staging.dart appbundle CODE --budget-basemap` path
owns map defines and Gradle's original upload-signing checks. Flutter is pinned
to 3.47.2; the runner uses JDK 25. Source version name advances to `0.1.9` because
Console already serves `0.1.8`. The pubspec build suffix is not a reservation.

Automated codes are `historical_version_code_floor + GITHUB_RUN_NUMBER` under the
single writer lock, and must exceed all codes returned by every Play track,
bundle and APK. The Console-observed historical floor starts at 12; current edit
APIs alone cannot prove that every historical upload is listed. If manual uploads
advance/burn codes, refresh the historical floor through a reviewed policy change.
A used/stale code fails; a new dispatch gets a fresh run number. Never rerun an
accepted upload under the same code or reduce a floor to bypass a rejection.

If Publisher access is absent, `build` supports manual upload: set protected
environment variables `PLAY_VERIFIED_UNUSED_CODE` and `PLAY_CONSOLE_CHECKED_AT`
(UTC ISO timestamp no older than 24 hours) after inspecting the full Console
history. This is an explicit owner verification, not a guessed code. `publish`
always requires the service account and exact existing API track. The observed
Console track is Alpha/`alpha`; its API identity must still be returned by Play.
Production/internal/open testing and creating a new track are rejected.

The artifact inspector validates package, code, target SDK ≥36, release/debug
status, original upload certificate, signatures/digests on every payload, the
exact clean tested source, staging origin in compiled app libraries, explicit map
flags, disabled demos and 64-bit native 16 KiB alignment. Bundletool 1.18.3 is
checksum pinned. Secret config/signing files are private temporary inputs and
removed in `finally`; terminated jobs lose their ephemeral runner. Raw build/CLI
output is withheld because it may contain configuration or connection strings.
Only named nonsecret JSON/AAB files enter Actions artifacts (30-day retention).
Persist the artifact elsewhere before retention expires if it is needed longer.

Play updates only the verified existing closed track, preserving country targeting
and leaving testers and other tracks untouched. The API's `completed` status is
recorded as **submitted**, with review/processing/installability still unverified.
Check Publishing overview/Console and install from Play before claiming delivery.
It does not send Recovery update prompts or raise APPVER01 minimum versions.

## Smoke and incident procedure

After Console shows the intended release available to selected testers, update
the existing app through Play. On authorized connected serial `48091FDAS0041A`,
read-only ADB can inspect installed package/code/install source. Never sideload,
uninstall or wipe the owner's Play installation.

Use owned test identities for OTP/account switching; signed-out Resource Browse,
keyword/locality/mode/category combinations and clear/reset; category-only saved
search Save/Edit/Open; create/publish/edit category content; NULL legacy content;
List↔Map family/filter handoff and guest fallback; Projects/Tavoli, Messages/unread
and relevant Group flows; photo/privacy and exact-location boundaries. Record
actual evidence separately from local mocks/CI; do not capture OTPs/private content
or consume provider credits to manufacture exhaustion tests.

On failure, the job/Actions notification and sanitized stage artifacts identify
the failing gate. Set `STAGING_RELEASE_ENABLED=false` to stop new releases; let an
active migration finish rather than cancelling it. Do not reset/repair/reseed or
drop schema to roll back. Inspect exact history and preservation evidence, correct
forward through a reviewed migration, and re-run preflight. A partial apply requires fresh history, recovery and predecessor-specific
preservation/review evidence for the remaining set; do not reuse a stale proof.
Restore only through the owner-approved recovery route, with separate explicit
authorization for a destructive restore. A fully applied retry is a verified no-op. Never claim success from a previous artifact after a failed run.

If an upload/commit times out, inspect Console and all used codes before retrying;
Google may have accepted the bundle. Do not automatically repeat a write or create
a production release. Preserve the previous usable closed release until Google
accepts the replacement; use Console's existing track controls only with explicit
owner intent. No tester cohort or publication policy is changed as error recovery.
