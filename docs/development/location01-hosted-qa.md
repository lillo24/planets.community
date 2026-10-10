# LOCATION01 hosted migration and Android handoff

## Verified target and source

Observed on 2026-10-10, approximately 09:24–09:31 UTC (11:24–11:31 Rome).
The clean source checkout and freshly fetched `origin/main` were both
`77747b747f742d17892b4c7e7c20829c850ab384`, the merge of [PR #198](https://github.com/lillo24/planets.community/pull/198).
The operational checkout used branch `codex/location01-hosted-qa`.

Three independent inputs agreed on the staging target:

- The existing linked project and newly linked task checkout: `cllpvruvrrvxczjitlqd`.
- The authenticated Supabase project listing: `planets-staging`, EU West,
  `ACTIVE_HEALTHY`, PostgreSQL 17.11.
- The ignored mobile staging configuration: origin
  `https://cllpvruvrrvxczjitlqd.supabase.co`, `APP_ENV=staging`,
  `ENABLE_DEMO_TOOLS="false"`. Configuration values containing credentials were
  not printed.

Only this confirmed staging project was changed. No production target,
Auth/provider configuration, seed, retained local database, or app installation
was changed.

## Controlled migration and readback

The repository-pinned Supabase CLI was `2.118.0-beta.39`; its installed help was
checked without upgrading it. Before deployment, both CLI and management SQL
showed 74 matching migrations, no remote-only history, and exactly one pending
file: `20261010075613_defined_proposal_city_only.sql`.

The reviewed `db push --linked --skip-vault --dry-run` listed only that file and
no roles/seeds. The normal linked push then applied it successfully with
`--skip-vault`. Hosted ledger readback showed **75/75 matching migrations**, and
a second dry run returned `upToDate=true` with an empty migration list.

The applied canonical file's SHA-256 was
`BECF52942218246BF0C4B23147CEB1C3AD17592AFBC0C92EE0F2E748940879F0`.
Readback of both function sources matched the merged migration exactly after
normalizing line endings:

| Function                                            | Before definition MD5              | After definition MD5               |
| --------------------------------------------------- | ---------------------------------- | ---------------------------------- |
| `private.assert_proposal_publishable(uuid,boolean)` | `c2c94ae0233b695a7fb44655c9005534` | `cc787f2e745c35258405f1981417c72c` |
| `public.get_public_proposal(uuid)`                  | `4e8ee62d2c3cbe2fc5aa71b1be46d77d` | `80285b4eb1e32310dd2c8746b59002ee` |

The validator no longer requires precise instructions; its content, meeting-row,
schedule, locality and timezone checks remain. The public restricted flag now
requires actual protected text or geometry. Both functions retained their
signatures, return types, grants, stable/security-definer attributes and empty
search paths. Definition hashes and grants for 18 surrounding publication,
update, participant-read and capacity functions were unchanged, including
`publish_proposal` with its expected-actor, complete-profile, ownership,
lifecycle and current-photo safeguards. Public product tables exposed without
RLS: zero, before and after.

Recovery preflight returned `backups=[]`, `pitr_enabled=false` and
`walg_enabled=true`. No usable hosted restore point was established. Only the
two previous function definitions were saved locally as reference for a
reviewed **forward** correction, not as a data backup or an automatic rollback.
No restore, broad data export, migration repair or history rewrite was performed.

## Hosted health, security and smoke evidence

`db lint --linked --schema public,private --level warning --fail-on warning`
passed with no schema errors. Management security advisors ran before and after;
their findings were unchanged:

- 81 informational [RLS enabled without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) findings.
- 27 [anonymous security-definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) warnings.
- 230 [authenticated security-definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) warnings.
- One [leaked-password protection disabled](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) warning.

These existing findings are recorded, not represented as an advisor-clean result
or resolved by this deployment. Canonical RPC grants were preserved.

The staging dataset contained one published one-time Project, zero published
Tavoli and **zero published city-only Projects**. Existing content was not edited.
Anonymous HTTPS REST checks at 09:28:29 UTC before and 09:29:14 UTC after deployment
returned HTTP 200 for `list_public_proposals` (one row) and a fresh
`get_public_proposal` (one matching row). An anonymous
`get_project_participant_meeting_details` probe returned HTTP 401 / SQLSTATE
`42501` both times. Read-only DB comparison found zero restricted-flag
mismatches on existing published content. This is existing-content health and
anonymous denial evidence, not a city-only publication or authenticated
unrelated-account test.

| Scenario                                                                 | Status  | Evidence and remaining dependency                                                                                                                 |
| ------------------------------------------------------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Canonical city-only publication rule installed                           | PASS    | Hosted DB function-source comparison and 75/75 ledger readback.                                                                                   |
| Publish a new synthetic Trento Project and reload it                     | BLOCKED | Approved dedicated staging actor and approval to create test content were requested but unavailable during this run. No stateful RPC was invoked. |
| Existing public List/detail and anonymous protected-read denial          | PASS    | Real anonymous HTTPS REST before/after; no user content or private fields logged.                                                                 |
| City-only mobile/web absence copy, List-only behavior and no Maps action | BLOCKED | No existing city-only staging fixture or approved new one; no rendered hosted mobile/web proof.                                                   |
| Join/admit, authenticated null meeting details and group chat            | BLOCKED | Dedicated owner/member accounts and fixture required. No sessions were minted or harvested.                                                       |
| Optional Public/Participants details, unrelated-account denial and clear | BLOCKED | Dedicated authorized content and legitimate account sessions required.                                                                            |
| Fully specified publication and draft save/reopen                        | NOT RUN | Stateful checks require the approved test actor; no existing draft/Project was modified.                                                          |
| Tavoli/Scambio publication guards unchanged                              | PASS    | Hosted function definition/grant comparison only; no new Tavolo/Scambio was published.                                                            |
| Intended staging network reached                                         | PASS    | Workstation HTTPS REST to the verified staging origin; no device-network claim.                                                                   |
| Physical Android scenarios                                               | BLOCKED | Requested serial absent from ADB; installed version/signer and safe installation could not be established.                                        |
| Emulator scenarios                                                       | NOT RUN | Existing emulator was not used as substitute physical evidence.                                                                                   |

Provider/search/tiles/centering were already enabled by separate work and stayed
unchanged. The existing provider ceiling was 8,000 quarter-credit units/day
(global and actor), tile TTL 60 seconds, and search limits 1,000 global/day,
80 actor/day, 10 actor/minute. Static preview remained disabled. This task made
no map/search/preview provider request and changed no flags, budgets or billing.

The prior PR's widget, SQL and authenticated local REST results remain historical
local evidence. They were not rerun or relabelled as hosted/physical results.
In particular, `npm run check:db` was not run against the retained local stack.

## Android guard and next owner action

Two read-only `adb -s 48091FDAS0041A devices -l` checks found only the existing
`emulator-5554`; the requested physical device was disconnected. No install,
uninstall, downgrade, data clear, account/session change, phone screenshot or
logcat capture occurred. The installed package's model, version, install source,
certificate and build identity remain unknown.

No new APK/AAB was built: compatibility cannot be established without the
installed signer/version. The selected source is PR #198's merged main above;
there is no task-built artifact, hash, compiled runtime-flags proof or verified
phone commit to report. The repository uses the permanent
`community.planets.app` identity and has no configured side-by-side application
ID. The upload signer must not be assumed to match a Play-installed app.

The founder's next steps are:

1. Connect/unlock serial `48091FDAS0041A` and authorize USB debugging. Read its
   installed package/version/source and pull only the APK needed to inspect its
   signing certificate; preserve app data. Compare with the existing upload/debug
   signer before choosing a compatible normal staging build. An incompatible
   Play signer is a blocker requiring a separately authorized distribution path,
   never uninstall/clear-data or an invented package/signing scheme.
2. Approve a dedicated staging test identity and creation of a clearly labelled
   synthetic LOCATION01 Project. Authenticate normally in the app; provide a
   legitimate second test account for membership/privacy cases. Do not share
   passwords, JWTs or OTPs in evidence.
3. On that compatible current-source client, use manual `Trento`, future schedule,
   ordinary content/capacity and the existing profile/photo requirements; leave
   precise details empty. Publish/reload, then perform the blocked cases above.
   Record the resulting fixture ID and its owner; cancellation/deletion needs
   explicit permission. No fixture was created by this run.

The scoped local operation folder is
`C:\Users\leona\.planets\operations\location01-hosted-qa-20261010`.
It retains sanitized REST summaries, function/grant/config fingerprints, the
read-only public smoke helper and the two-function recovery reference, without
credentials or private data. It is useful follow-up QA evidence and is not a
retained build checkout. See the [feature contract](location01-defined-project-city-only.md)
and [signing procedure](play-closed-test.md).
