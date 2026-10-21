# RELEASE01 staging and Google Play closed testing

The dedicated [workflow](../../.github/workflows/staging-release.yml) owns SQL
deployment to `planets-staging` (`cllpvruvrrvxczjitlqd`) and Android delivery to
the existing `community.planets.app` closed track. Production and iOS distribution
remain outside this workflow. The initial [live assessment](evidence/release01/assessment.md)
records the blockers; merging release plumbing does not resolve them.

## First-time owner setup

1. Review the [26-file manifest](evidence/release01/migration-manifest.json).
   CAT01 is authorized conditionally by RELEASE01; the other 25 files need
   explicit hosted deployment approval. Member-contact policy 3 was approved on
   20 October; that does not authorize its hosted deployment. The stale pending
   footer of the older member review is not a new policy decision.
2. Establish a recovery route before consequential writes: an owner-held encrypted
   logical backup, including appropriate Auth/Storage metadata and object recovery
   requirements, with a restore rehearsal; or obtain an explicit task-specific
   owner waiver. Free-plan availability is not proof of a usable backup. Record
   the precise approved recovery reference in `policy.json`; do not put backup
   contents, credentials or personal records in Git/Actions artifacts. A waiver
   must say it is a waiver, never claim a backup exists. Previous STAGING01's
   waiver applied only to that task.
3. Review the populated rehearsal artifact and complete Validation for the intended
   source. Put that run URL in `rehearsal_reference`, each approved canonical
   version→SHA-256 in `bootstrap_approvals`, and the live preflight's exact
   `approval_digest` in environment variable `BOOTSTRAP_MANIFEST_SHA256`.
   A changed predecessor, SQL file or pending set requires renewed review.
4. Create GitHub Environments `planets-staging`, `planets-android-build` and
   `planets-play-closed`. Restrict all to `main` (no tags), require the owner as
   reviewer on staging and publication for initial deployment/publication and
   disable administrator bypass where available. Build preparation can run without
   repeated approval; its verified artifact exists before the publication job asks
   for owner approval.
   GitHub supports required reviewers for this public repository. Do not create
   an unprotected substitute if account features prevent enforcement.
5. Confirm Supabase native GitHub migration deployment is **disabled** for this
   project, then set staging environment variable
   `STAGING_DEPLOYMENT_OWNER=github-actions`. RELEASE01 selects one owner: this
   workflow. It does not enable or configure Supabase native integration.
6. Provision these environment secrets through GitHub Settings or an owner-run
   `gh secret set --env ...` reading a protected local file/stdin; never paste
   credentials into chat, command history, committed JSON or an issue:

   | Environment                        | Secrets                                                                                                                                   |
   | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
   | All three                          | `SUPABASE_ACCESS_TOKEN` (legitimate project-scoped management access), `STAGING_CONFIG_JSON`                                              |
   | `planets-staging` only             | `STAGING_DB_URL` (original staging database credential; exact direct host or session pooler identity, TLS certificate validation enabled) |
   | `planets-android-build` only       | `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_STORE_PASSWORD`, `ANDROID_UPLOAD_KEY_PASSWORD`, `ANDROID_UPLOAD_KEY_ALIAS`              |
   | Android build and Play publication | `PLAY_SERVICE_ACCOUNT_JSON` (build uses a temporary edit for inventory, then discards it; only the publication job uploads/commits)       |

   Use the original upload key, not Play's distribution key. The verified upload
   SHA-256 is pinned in `policy.json`; no replacement key is generated. Base64
   must be one line. Staging JSON uses the existing strict documented string
   keys, exact staging HTTPS origin, client-safe `sb_publishable_` key,
   `ENABLE_DEMO_TOOLS="false"`, `SENTRY_DSN=""` and optional public Google client
   ID. Never include a service role, provider key or database credential.

7. Configure a narrowly scoped Google Play service account for this app's testing
   releases, without production-release or tester-management permissions. Follow
   [Google's account/API setup](https://developers.google.com/android-publisher/getting_started):
   enable Android Publisher in an owned Cloud project and invite the service
   account in Play Console with appropriate app-level permissions. Account/Cloud
   setup and secure credential provisioning remain owner actions. No Cloud
   project linking is required by Google's current instructions.
8. Set repository `STAGING_RELEASE_ENABLED=true` only after the above is ready.
   Leave `STAGING_AUTO_PUBLISH` unset/false for bootstrap. Neither variable is
   created by this PR. Dispatch `inspect`, review its sanitized artifact, then
   dispatch `deploy`. Approve only the exact reviewed scope in the environment.

After successful reconciliation, confirm complete parity and post-deployment
checks, then commit `bootstrap_complete=true` and `reconciled_through` equal to
the reconciled canonical boundary through a PR. Remove bootstrap approvals/digest
after preserving their evidence. Future reviewed main migrations above that
boundary deploy automatically; older timestamp gaps or changed applied SQL fail.

## Routine operation and release approval

`workflow_dispatch` defaults to read-only `inspect`. `deploy` runs complete
exact-source Validation and the bootstrap rehearsal, then SQL preflight → apply
→ verification. `build` additionally persists a verified upload-signed AAB;
`publish` additionally waits for first-publication owner approval of that persisted
AAB, then uploads/validates/commits the Play edit and re-reads the track in a separate
job. This job has no signing key. Every mutation requires current `main`; an advancing main aborts delivery.

The guarded main-push trigger covers mobile code, migrations/functions, release
tooling, dependency manifests and this workflow. Documentation/plan archival alone
does not deploy. `STAGING_RELEASE_ENABLED` defaults disabled through absence.
Pushes deploy SQL after bootstrap; Android publishing on push additionally requires
`STAGING_AUTO_PUBLISH=true`. First publication requires protected-environment owner
approval. After a successful first release, the owner may remove repeated reviewer
approval and enable automatic closed-test publishing, keeping main-only restrictions
and credentials scoped to environments. This change is explicit infrastructure
configuration, not performed by RELEASE01's code merge.

One concurrency group serializes all hosted writers without cancellation; PR
rehearsals use separate groups, cancel stale PR runs and have no environment secrets. Complete release
Validation is reused by exact SHA or explicitly dispatched; every Mobile, Web,
Site and Database check must succeed, including generated types and existing
upgrade/RLS/Auth tests. Existing change-scoped PR CI is unchanged. The extra
populated predecessor job runs only for changes to release plumbing/baseline and
bootstrap release runs, because the observed 97-file predecessor is not a simple
timestamp prefix. It becomes a short no-op after bootstrap is reconciled.

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
forward through a reviewed migration, and re-run preflight. A partial bootstrap
requires a fresh remaining-set digest and renewed approval; a fully applied retry
is a no-op. Never claim success from a previous artifact after a failed run.

If an upload/commit times out, inspect Console and all used codes before retrying;
Google may have accepted the bundle. Do not automatically repeat a write or create
a production release. Preserve the previous usable closed release until Google
accepts the replacement; use Console's existing track controls only with explicit
owner intent. No tester cohort or publication policy is changed as error recovery.
