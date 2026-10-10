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

## LOCATION01-QA02 follow-up — 2026-10-10

### Scope, source and fresh hosted preflight

The founder authorized one dedicated synthetic staging account and one labelled
Project, then explicitly requested normal login with an owner-controlled inbox
already registered in staging. That account already has a profile and owns the
baseline Project. This follow-up did not create another account, alter that
profile, or edit existing content. The approved Project remains limited to one
new synthetic record; a second account and edits to unrelated content remain
outside this authorization.

Fresh `git fetch origin main` resolved `9a48568e6212ef014d874a237afadda02b3112e6`
(PR #199). The isolated checkout used
`codex/location01-qa02-approved-staging-smoke`. No unfinished PROJECT-IDEA01A
code or migration was included. At 11:27–11:36 UTC (13:27–13:36 Rome), independent
authenticated management metadata, the existing CLI link and ignored staging
configuration agreed on `planets-staging`, `cllpvruvrrvxczjitlqd`, EU West,
`ACTIVE_HEALTHY`, PostgreSQL 17.11. The staging config had demos off; client keys
and signing inputs were not printed.

All **75 canonical migration versions matched exactly**, with no local-only or
remote-only entry; latest was `20261010075613`. The two LOCATION01 definition
MD5s still matched the deployment audit above. Signatures, empty search paths,
security-definer attributes and grants were inspected for the validator,
public List/detail, publication and protected participant-meeting read. No
migration push, reset, seeder, repair or DDL was run.

The fresh baseline contained two Auth actors, one Project (published), zero
published Tavoli, zero city-only published Projects and zero Projects with the
QA02 test title. Counts were obtained without displaying email, profile text,
Project text or protected meeting content. Aggregate fingerprints of the
existing Project, meeting and profile records were retained for readback.
Public product tables readable without RLS: zero.

At 11:42:12 UTC, readback still showed two actors, one published Project and
zero QA02 Projects. All three baseline fingerprints matched exactly. The
existing published Project had actual exact text, so its public withholding is
consistent with restricted presence rather than city-only absence.

### Authentication and independently executable smoke

At 11:30:40 UTC the normal `/auth/v1/otp` endpoint returned HTTP 200 with
`create_user=false`, using only the client-safe staging key and the
owner-designated existing inbox. The connected Gmail account matched that inbox
and confirmed delivery of the newly requested PLANETS message. Its connector
returned **`[one-time authentication code withheld]`** in place of the code.
No alternate representation or bypass was attempted. No verification exchange
completed and no authenticated session became available to the agent.

Consequently **no test actor or Project was created**, and there is no new actor
or Project UUID to report. Request/delivery success is not authenticated OTP,
publication, UI or device acceptance evidence. No password, OTP, access/refresh
token, private email or privileged key was written to the QA files or this PR.

Fresh anonymous HTTPS REST at 11:35:59 UTC returned HTTP 200 for the existing
`list_public_proposals` (one row) and `get_public_proposal` (one matching row).
Schedule/locality were present. Existing restricted content was withheld in the
public projection. `get_project_participant_meeting_details` returned HTTP 401 /
SQLSTATE `42501`. These calls used no user JWT and made no map-provider request.

| Scenario                                                                        | Status  | Fresh evidence or specific blocker                                                                                              |
| ------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Intended hosted target, exact migration parity and LOCATION01 rule installation | PASS    | Three target inputs; 75/75 versions; matching deployed function fingerprints/signatures/grants.                                 |
| Normal OTP request and external delivery                                        | PASS    | HTTP 200 and newly delivered PLANETS email; code withheld by connector.                                                         |
| Authenticated login                                                             | BLOCKED | Owner must complete numeric-code entry directly in the client. No session was minted, harvested or extracted.                   |
| One synthetic actor / labelled city-only Project                                | BLOCKED | No authenticated actor available. Neither account nor Project was created.                                                      |
| City-only canonical publication and immediate owner reopen                      | BLOCKED | Requires the one approved synthetic Project and a genuine owner session.                                                        |
| Existing public List/detail health                                              | PASS    | Fresh anonymous HTTP 200, one matching published record; existing content unchanged.                                            |
| City-only anonymous List/detail, Trento and honest absence/restricted flag      | BLOCKED | No city-only hosted fixture. Existing-content results are not substituted.                                                      |
| One public city field / optional collapsed exact controls                       | BLOCKED | Current-source rendered client acceptance awaits login and editor inspection. Historical widget captures remain local evidence. |
| City-only List-only behavior, no precise marker / Maps destination              | BLOCKED | No city-only hosted fixture; no geocoding/provider call made for this test.                                                     |
| Owner nullable exact read and group/chat eligibility                            | BLOCKED | Genuine owner session and the approved fixture required.                                                                        |
| Participation request/admission and current-member nullable exact/chat read     | BLOCKED | No separately authorized second actor/session. No join request or acceptance performed.                                         |
| Anonymous protected exact read denied                                           | PASS    | Fresh HTTP 401 / `42501` against the existing published Project.                                                                |
| Authenticated unrelated-account denial                                          | BLOCKED | No separately authorized unrelated actor/session.                                                                               |
| Public/restricted exact-text edits and removal                                  | BLOCKED | No approved fixture/session; no existing meeting details edited.                                                                |
| Fully specified Project regression                                              | PASS    | Read-only existing publication/List/detail health only; fresh fully specified creation was not run.                             |
| Current-main signed emulator update                                             | PASS    | Version 4 installed with matching certificate; installed APK hash equals the verified artifact. No uninstall/data clear.        |
| Authenticated emulator city-only journey                                        | BLOCKED | Manual code entry/Explore confirmation pending; no authenticated screen inspected.                                              |
| Physical Android create/publish/reopen and Map/List                             | BLOCKED | Serial `48091FDAS0041A` absent; no installed version/source/certificate established.                                            |

### Android handoff

The physical serial remained absent from `adb devices -l`. Its version, signer,
install source and compatibility are unknown. **No phone installation was
attempted**; there was no uninstall, data clear or signer/package workaround.
The upload certificate below establishes emulator compatibility only and must
not be assumed to match Play App Signing.

The existing task AVD `PLANETS_MAP_LIVE01_API35` was reopened at port 5570 with a
visible Windows window titled
`Android Emulator - PLANETS_MAP_LIVE01_API35:5570`. Android completed boot and
ADB reported `emulator-5570`. The Windows foreground helper twice returned
`failed to activate captured window`; no stale coordinates or authentication
screen capture was used. Window presence and ADB readiness do not establish
that the founder has seen or accepted this client.

Read-only inspection found `community.planets.app` version `0.1.0+3`, target SDK
36, sideloaded with no installer package. Pulling only its installed APK verified
SHA-256 `46a6341ef2688c9c5c970251fb78badd0f7ecf78a884e1d98c73a8012ca80b1f`
and upload certificate
`F9362ED9F6F7BE7C59A6EACFD8AAE99426AF98935FF1197F65E8207CC0FD22C0`.
That binary predates LOCATION01 and is not city-only client evidence.

The authenticated Play **All app bundles** page showed exactly codes 1, 2 and 3
(three entries, no further page) during this run. Code 4 was unused at that
inspection. The current-source emulator APK was built successfully with the
supported `dart run tool/build_map_live_staging.dart apk 4`, preserving the existing
MAP-LIVE01 native QA defines. The script blob matches the previous emulator's
source; no backend/provider flag, limit, JWT setting or billing configuration
was changed.

Artifact:
`C:\Users\leona\.planets\releases\location01-qa02\PLANETS-LOCATION01-QA02-staging-0.1.0+4-main-9a48568.apk`.
SHA-256:
`643d66f4f5876601f325e7b533a303dec5a73dc9c6fb8a4b095185cebb6f7e25`.
It is release/non-debuggable, package `community.planets.app`, version
`0.1.0+4`, target SDK 36 and signed with the same upload certificate above.
Verification covered three app ABIs, 12 native 64-bit 16-KiB alignment checks,
the actual staging origin/client key, no embedded privileged/signing secrets,
no direct Geoapify transport and no GPS permissions. Build warnings included
the plugins' future Kotlin migration warning and missing Cupertino font family;
the release build still completed successfully. No dependency was upgraded.

Before `adb -s emulator-5570 install -r`, a guard rechecked version 3 and the
known installed APK hash. The update returned `Success`; `.MainActivity` opened,
package readback showed version 4, and installed APK SHA-256 matched the artifact
exactly. This is fresh emulator installation evidence, not login, city-only
publication, live map acceptance or physical-phone evidence. No AAB or Play
release was created by this follow-up.

### Advisors, commands and next owner steps

Fresh security advisors retained the same 81 RLS informational findings, 27
anonymous and 230 authenticated security-definer warnings, plus one disabled
leaked-password-protection warning. Their remediation links remain in the
preceding audit. Fresh performance advisors additionally reported 14
[unindexed foreign keys](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
and 171 [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index),
both informational. None was fixed or treated as an advisor-clean result.

The installed CLI help was read before choosing commands. Fresh operations were
`git fetch origin main`, `git rev-parse HEAD origin/main`, read-only linked/config
metadata inspection, management `get_project` / `execute_sql` SELECTs /
`get_advisors`, anonymous `/rest/v1/rpc` POST reads, the ordinary Auth OTP request,
and `adb devices`, `getprop`, `pm path`, package metadata and APK certificate/hash
inspection. No `check:db`, retained local database suite, provider request,
production operation or Play upload/publication was run. Local historical SQL,
REST, widget and native evidence above was not relabelled as fresh hosted QA.

The scoped operation folder is
`C:\Users\leona\.planets\operations\location01-qa02-20261010`.
Its baseline, anonymous-smoke and advisor-summary JSON contain sanitized counts,
booleans, hashes and outcomes only; the installed emulator APK was copied there
solely for certificate comparison. Mail content and authentication credentials
are not retained as evidence.

To finish the authenticated cases:

1. In the visible current-source emulator client, complete normal email-code
   login directly using the owner-controlled inbox. Request a fresh code in the
   app if needed. Keep the code in the client; do not paste it into chat, scripts
   or evidence. The founder must personally review any policy acceptance gate.
   Preserve the existing owner profile and Project. Report only that Explore is
   visible; an authenticated screen must be confirmed before agent UI inspection.
2. Use the ordinary one-time Project editor to create **one**
   `TEST LOCATION01 — Progetto città senza indirizzo`. Use neutral synthetic
   summary/description, city `Trento`, a future start and later end, the existing
   required registration capacity and unchanged profile/photo safeguards. Leave
   the optional exact section empty/collapsed; select no exact place and supply
   no exact coordinates. Do not invite users or manufacture consent.
3. Publish canonically and reopen that same UUID. Check public List/detail,
   absence copy, no hidden-address implication, List-only/no invented pin/Maps
   action, owner group/chat eligibility and nullable authorized meeting data.
   Record only test actor UUID, test Project UUID, time/ref and per-case outcome.
   If publication fails, preserve the single draft for diagnosis/retry instead
   of creating another fixture. Keep the Project until cleanup is authorized.
4. Member/admission and unrelated-account cases still require a separately
   authorized genuine actor. Reconnect the physical serial for read-only signer
   and version comparison before considering any compatible phone update. An
   emulator result cannot satisfy that physical-device gate.

If the emulator window is closed, these commands in a local PowerShell reopen
the existing AVD without wiping it. Run the device checks only after it boots;
the install guard accepts only the known older APK or this exact QA02 artifact.
Every ADB command explicitly selects the emulator, never the physical phone:

```powershell
$qaSdk = "$env:LOCALAPPDATA\Android\Sdk"
Start-Process -FilePath "$qaSdk\emulator\emulator.exe" -WindowStyle Normal -ArgumentList @(
  '-avd', 'PLANETS_MAP_LIVE01_API35', '-port', '5570',
  '-no-snapshot-load', '-no-snapshot-save', '-gpu', 'swiftshader_indirect',
  '-memory', '2048', '-cores', '2'
)

# After Android has booted:
$qaAdb = "$qaSdk\platform-tools\adb.exe"
& $qaAdb devices -l
$qaPackagePath = & $qaAdb -s emulator-5570 shell pm path community.planets.app
if ($LASTEXITCODE -ne 0 -or $qaPackagePath -notmatch '^package:(/data/app/.+/base\.apk)$') {
  throw 'Expected existing PLANETS package on emulator-5570; stop.'
}
$qaRemoteApk = $Matches[1]
$qaHashLine = & $qaAdb -s emulator-5570 shell sha256sum $qaRemoteApk
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify installed emulator APK; stop.' }
$qaHash = ($qaHashLine -split '\s+')[0]
$qaOldHash = '46a6341ef2688c9c5c970251fb78badd0f7ecf78a884e1d98c73a8012ca80b1f'
$qaNewHash = '643d66f4f5876601f325e7b533a303dec5a73dc9c6fb8a4b095185cebb6f7e25'
if ($qaHash -eq $qaOldHash) {
  $qaApk = 'C:\Users\leona\.planets\releases\location01-qa02\PLANETS-LOCATION01-QA02-staging-0.1.0+4-main-9a48568.apk'
  if ((Get-FileHash -LiteralPath $qaApk -Algorithm SHA256).Hash -ne $qaNewHash) {
    throw 'Local QA02 artifact hash changed; stop before install.'
  }
  & $qaAdb -s emulator-5570 install -r $qaApk
  if ($LASTEXITCODE -ne 0) { throw 'Compatible emulator update failed; stop.' }
} elseif ($qaHash -ne $qaNewHash) {
  throw 'Unknown installed emulator build; do not replace it.'
}
& $qaAdb -s emulator-5570 shell am start -n community.planets.app/.MainActivity
```
