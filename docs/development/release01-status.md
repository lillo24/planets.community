# RELEASE01 execution status

## STAGING-AUTO01 update — 22 October 2026

Repository safety implementation is ready for exact-head CI; activation is **disabled**.
Local focused release tests: **41 passed**. Full tooling tests: **178 passed**.
Formatting and actionlint 1.7.12 passed. Local Docker is unavailable; the
disposable populated rehearsal and complete four-area Validation run in CI.
A fresh read-only observation at main `97a215ca60dc35c30b4b9f652441bdb7c35937ba`
found **123 applied / 126 canonical / three pending / zero drift**. See
[metadata evidence](evidence/release01/staging-auto01-predecessor.json). The added
ACTAPI catalogue migration is independently review-required; the bounded
historical reconciliation still contains only the exact original avatar and
notification files and remains disabled. No hosted migrations/data writes, AAB
build/upload or Play publication are authorized or performed by STAGING-AUTO01.

Live settings inspected by name: `STAGING_RELEASE_ENABLED=false`,
`STAGING_AUTO_PUBLISH=false`; staging still requires its owner reviewer.
Main protection was absent (GitHub API 404). Recovery workflow/policy, verified
credentials/native-auto-deploy ownership and protected readiness are one-time
activation requirements; none are claimed configured. The
[existing runbook](release01-staging-play.md) gives exact owner steps and proof
contracts. A code merge alone cannot activate automatic deployment.

The older execution record below is retained as dated evidence; its 125-file
snapshot and task-specific no-backup waiver do not describe today's pending set
or authorize later SQL. The implementation PR checks and their artifacts are the source of truth for
exact-head CI and rehearsal completion; this record does not imply deployment.

## Historical RELEASE01 execution

Recorded at 2026-10-21 22:02 UTC (22 October locally). Release plumbing is merged
and the original approved 26 migrations are deployed. **The first RELEASE01 AAB
is still blocked by two later main migrations awaiting owner approval.** No app
upload, submission, publication, Recovery prompt or minimum-version raise occurred.

1. **Source and merge.** [PR #286](https://github.com/lillo24/planets.community/pull/286)
   merged as `7134a57b4d1fffe517cb7014dce9959806945401`. PR head
   `719970b2ec5014a8a9d7db673035bbac3d567d4d`, tested PR merge
   `c346145cb1dbeba03fad93551ea17f31009ff44c` and merged main have identical tree
   `5516e08162941eceb35f378228ab64dc2bf64399`. This report is a documentation-only
   follow-up; it does not replace the recorded tested code source.

2. **Staging delta and approval.** Target is `planets-staging`,
   `cllpvruvrrvxczjitlqd`. The owner explicitly approved the [original 26 files](evidence/release01/migration-manifest.json)
   and waived backup for this reconciliation: “No backup is fine”. No backup was
   taken or verified for this run. CAT01 and all 25 historical Group/contact files
   were applied. Staging is **123 applied / 125 canonical / two pending** after
   main subsequently integrated PROF01/IMG01 and the notification-worker fix.
   [Remaining file hashes and effects](evidence/release01/remaining-migrations.json)
   are separate from that original approval; elapsed time does not approve them.

3. **Actual hosted execution.** At 21:20:25 UTC the authorized migration API
   executed the complete 26-file canonical batch with transaction-local lock/time
   bounds, predecessor/routine/grant guards and original-column preservation
   assertions. Each canonical version/name/full SQL was recorded after execution.
   All **97 old history records** are unchanged; all **26 new file SHA-256 values**
   match source. Only redundant API wrapper `20261021212025` was removed after
   verifying its exact name, single statement, MD5 and SHA-256. No canonical
   history was rewritten and no application data reset/reseeded/deleted.
   [Execution receipt](evidence/release01/hosted-26-execution.json).

4. **Hosted verification.** All original column/row hashes across **126 tables /
   355 rows** were preserved. The 40 new private tables remain empty: the current
   preservation baseline is 166 tables / the same 355 rows. Legacy and V2 Resource
   listing reads returned 200; invalid category returned 400/22023; anonymous
   Messages access returned 401/42501. Installed-RPC grants, product-table RLS
   exposure, private WebP Storage limits and existing map gates passed. Normal map
   bundles remain ACTIVE at provider v5, search v5 and preview v4 with their pinned
   hashes. [Current backend checks](evidence/release01/backend-after-26.json)
   identify the seven missing avatar functions; full backend readiness is false.

   Security-advisor categories are unchanged. The approved canonical RPC-only
   tables and definer grants explain the count changes: RLS-without-policy INFO
   106→146, anon-definer WARN 38→40, authenticated-definer WARN 315→449. The
   pre-existing password-protection warning remains one. No client-readable product
   table without RLS was found. Official explanations and counts are linked in the
   execution receipt; these findings are not represented as zero warnings.

5. **Workflow and account configuration.** The [release workflow](../../.github/workflows/staging-release.yml)
   supports inspect → deploy → build → optional publish, with main-only protected
   environments, one writer, exact-source full validation, reviewed bootstrap,
   strict TLS, persisted evidence and a separate publication approval after the AAB
   exists. Main push run [39682777924](https://github.com/lillo24/planets.community/actions/runs/39682777924)
   skipped all jobs. `STAGING_RELEASE_ENABLED=false` and
   `STAGING_AUTO_PUBLISH=false` are verified. Original staging config/database
   input and upload-signing inputs are provisioned; only secret names are recorded
   in the [setup snapshot](evidence/release01/automation-setup.json).

   Future Actions activation needs legitimate `SUPABASE_ACCESS_TOKEN` in the
   environments, confirmation that Supabase native migration deployment is
   disabled, and a verified direct/session-pooler database route with certificate
   validation. The direct hostname returned ENOTFOUND on this computer; its
   credential/TLS/Actions transport was not validated. Future automatic Play
   publication also needs an app-scoped `PLAY_SERVICE_ACCOUNT_JSON`. No OAuth
   connector credential was extracted. Exact setup is in the [runbook](release01-staging-play.md).

6. **Android artifact.** No RELEASE01 AAB was built or offered while backend parity
   is incomplete. Package remains `community.planets.app`; source version is
   `0.1.9+13`, which is not a Play code reservation. The original upload certificate
   is pinned as `f9362ed9f6f7be7c59a6eacfd8aae99426af98935ff1197f65e8207cc0fd22c0`.
   Once approved backend parity is reached, use the clean tested main and existing
   map-enabled builder with all six MAP-LIVE/MAP-COST flags, demos and Mock
   capability off, a freshly checked unused code and the original upload key.
   The artifact inspector checks source, SDK/package/code, signature, every payload,
   compiled staging origin, map flags, Mock capability and 64-bit 16 KiB alignment.

7. **Google Play.** The [existing Closed testing Alpha track](https://play.google.com/console/u/1/developers/8649245788563869268/app/4974645333747478583/tracks/4700334745904524501)
   was last read at 20:16 UTC: Active, code 12 / 0.1.8 available to selected testers,
   one country/region, no unpublished changes. All 11 accepted bundles were read;
   13 was unused then, not reserved. No edit/upload/submission/cohort/country change
   was made. The latest owner instruction explicitly stops before upload/publication.

8. **Validation and limits.** [Complete Validation](https://github.com/lillo24/planets.community/actions/runs/39678880905)
   passed Mobile, Database, Web and Site on the final code head. Mobile:
   **3,958 passed, two skipped**. pgTAP: **159 files / 6,413 tests**, suite passed.
   Local tooling: **144 passed**, including 26 release groups and six Python
   artifact checks. Prettier, diff checks and actionlint 1.7.12 passed; shellcheck
   was unavailable and disabled for actionlint. The latest [populated rehearsal](https://github.com/lillo24/planets.community/actions/runs/39678880959)
   passed **97→125**, preserved all **1,380 original rows in 160 tables**, confirmed
   a no-op retry, real Resource Auth/REST and generated types. Earlier 97→123 and
   97→124 runs are historical evidence, not substitutes for the final source.

   Play API behavior is mocked in tooling tests; no real upload was tested. Hosted
   authenticated listing/create/edit/saved-search, OTP/account switching, map,
   Group/Messages and Play-device journeys remain unrun. Fresh ADB inventory has no
   connected devices. No uninstall, sideload, wipe, real-user impersonation or
   provider-credit request was used. Backend/catalog and CI evidence do not claim
   device or whole-app acceptance.

9. **Smallest next action.** Approve or decline the two-file remaining-set request,
   including whether the task-specific no-backup waiver extends to it. The candidate
   transaction is prepared with preservation guards for all 166 current tables and
   the notification worker's existing OID/grants. Approval permits that staging step
   and then the verified AAB build; it does **not** authorize Google Play upload or
   publication. The task checkout is retained for this pending backend/build work.
