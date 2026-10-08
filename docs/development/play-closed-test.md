# CT-01: release plumbing and deferred Play closed test

This is staging distribution of current `main`, not a production launch.
CT-01 initially started at `67133025b4dc8a90a3d303e70d69df6ee6faf84c` and
previously reconciled through `eb70fe249978585f754fa9175d337d7ef8b99e17`.
The code-merge continuation reconciles `main` at
`5cfcdd14331f003b5cf3b5e92cb1c2bcd62d9878`, preserving merged MAP02 #174,
POLICY01 #178 and TUT03 #177. It does not incorporate unmerged Map activation.
The previously verified staging deployment contained 60 canonical migrations;
that historical result does not establish deployment of the current migration
history. Do not apply hosted migrations during this code-only merge.
Use the permanent Android package `community.planets.app`, Flutter 3.47.2,
and `0.1.0+1`. Check Play's existing bundle history before uploading; increase
the version code only if 1 has already been used for this package.

## Code merge is not release approval

The founder authorizes merging PR #149 once its current-main reconciliation,
mobile tests, Android compile/signing safeguards, secret review and final-head
CI pass. External OTP and physical-device checks are no longer code-merge gates;
they remain publication gates. Merging does not authorize a backend deployment,
new AAB, Play upload, provider activation or a running tester clock.

Do not produce the final Play AAB until the intended Map integration is merged.
That integration must update its own checkout from the new `main` containing
CT-01 before its later merge and run its own independent validation. Preserve
the permanent package ID, upload-key arrangement, deep links and current policy,
location and tutorial behavior during that reconciliation.

The subsequent release task must:

1. Reconcile staging migration history safely with the actual integrated app
   revision, without reset, seed or history rewriting.
2. Build a **new** signed AAB from then-current `main` using the same upload key;
   verify app ID, signer, SDK >=36, version code, staging origin and demos off.
   Earlier CT-01 AABs are historical artifacts, not final upload candidates.
3. Verify external email OTP/session flows and representative physical-device
   journeys. One reported successful personal-email login is useful evidence,
   not a second distinct external inbox result or a completed smoke suite.
4. Review live Privacy/Terms/Rules/deletion links, in-app acceptance and Play data
   declarations against that actual AAB, including its eventual Map behavior.
5. Obtain founder release approval and publish specifically to **Closed testing**.

Do not call the backend/release ready before the external tests pass. The clock
starts only after the closed release is actually published and at least 12
testers are continuously opted in, not after a merge, AAB build or sideload.
The setup/build/publication sections below are a future authorized release
runbook, not actions authorized by this code-merge continuation.

## 1. Create the Free test backend

1. In Supabase, choose an organization on the **Free** plan and create a new
   **standard PostgreSQL** project, for example `planets-closed-test` in an EU
   region. Keep its database password in a password manager. If the Free project
   quota is full, resolve that with the account owner; do not upgrade billing.
2. From this checkout, restore the repository-scoped CLI with `npm ci`.
   Authenticate and link this **new empty test project only**:

   ```powershell
   npx --no-install supabase login
   npx --no-install supabase projects list
   npx --no-install supabase link --project-ref YOUR_TEST_PROJECT_REF
   npx --no-install supabase migration list --linked
   npx --no-install supabase db push --linked --skip-vault --dry-run
   npx --no-install supabase db push --linked --skip-vault
   npx --no-install supabase migration list --linked
   npx --no-install supabase db lint --linked --schema public,private --level warning --fail-on warning
   npx --no-install supabase db advisors --linked --type security --level warn --fail-on error
   ```

   Use the login/link password prompts, not secrets in shell history. Review the
   dry run: it must contain only this checkout's canonical migrations in order.
   Do not use `db reset`, `demo:reset:local`, `--include-seed`, or migration-history
   repair against the hosted project. Empty browsing is acceptable. The starter
   skill catalog and media buckets are already migration-owned.

   If the direct endpoint is unreachable on an IPv4-only network, use the
   project's **Connect > Direct > Session pooler** connection details, as
   documented by [Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres).
   Inspect this installed CLI's `db push --help` before using `--db-url`.
   Percent-encode the password when assembling a URI in process memory; never
   paste a credential-bearing URI into shell history, output or a report.
   A connection error before a successful dry run is a deployment blocker, not
   evidence of an applied migration. Diagnose network bans/restrictions and
   routing instead of rewriting history or repeatedly retrying the same path.

3. Database > SQL Editor: run these **read-only** checks. Compare migration
   versions with `supabase/migrations`; all must be applied with no extras.

   ```sql
   select version from supabase_migrations.schema_migrations order by version;
   select n.nspname, c.relname from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p')
     and not c.relrowsecurity
     and (has_table_privilege('anon', c.oid, 'SELECT')
       or has_table_privilege('authenticated', c.oid, 'SELECT'));
   select id, public, file_size_limit, allowed_mime_types
   from storage.buckets where id in ('profile-photos', 'cover-images');
   select schemaname, tablename, policyname, roles, cmd from pg_policies
   where schemaname in ('storage', 'realtime') order by schemaname, policyname;
   ```

   Investigate any exposed product table without RLS (extension-owned tables
   are separate). Never resolve access errors by making private schemas public
   or disabling RLS. Data API exposed schemas must remain `public` and
   `graphql_public`; `private` is not exposed. Migrations own the explicit
   grants and canonical RPCs, not dashboard-generated unrestricted policies.

4. Storage must be enabled. Check the bucket limits against the migrations:
   private `profile-photos` (256,000 bytes, WebP) and private `cover-images`
   (524,288 bytes, WebP). Both use policy-controlled delivery; public cover
   visibility is enforced through the domain/Storage policies, not a public
   bucket. Do not upload demo objects or replace Storage policies.
5. Realtime must be enabled, with private channel authorization supported.
   Current chat uses migration-owned Broadcast triggers and `realtime.messages`
   SELECT policies, rather than exposing product tables via Postgres Changes.
   Do not add every product table to `supabase_realtime`. Verify a message
   arrives between two current participants in the internet smoke test.
6. Keep anonymous Auth sign-ins disabled, email signups enabled, session refresh
   rotation enabled, and JWT expiry at 3,600 seconds. Set Auth's Site URL to
   `https://planets.community`; this app verifies numeric codes without an email
   redirect. Do not copy local loopback redirect URLs, Mailpit SMTP, or local
   permissive rate limits from `supabase/config.toml` into the hosted project.

Local pgTAP/security verification is not evidence of hosted deployment. Run the
linked lint/advisors and smoke checks after applying migrations. Free-project
availability and quotas must be watched during the test; a paused project must
be restored before testers can use it. Push-provider delivery and notification
workers remain separately deferred; they do not block OTP/content testing.

## 2. Configure Resend Free and numeric OTP

1. Add the owned sending subdomain `auth.planets.community` to Resend. Keep the
   Free plan. Use `login@auth.planets.community` as the proposed sender, subject
   to the owner's approval. Disable open/click tracking for authentication mail.
2. In the domain's DNS provider, copy **exactly the records Resend displays**:
   DKIM TXT plus sending SPF TXT and return-path MX, with its displayed names,
   values, priorities and region. Preserve unrelated website/mail records; do
   not invent DKIM values or replace the root domain's SPF. Wait until Resend
   reports the domain verified. If DNS access is missing, give the DNS owner
   that domain's record table; exact values cannot be known before creation.
3. Create a domain-scoped sending API key. Supabase Auth > Email > SMTP Settings:

   | Setting      | Value                                            |
   | ------------ | ------------------------------------------------ |
   | Sender name  | PLANETS                                          |
   | Sender email | Owner-approved address on the verified domain    |
   | Host         | `smtp.resend.com`                                |
   | Port         | `465` (TLS)                                      |
   | Username     | `resend`                                         |
   | Password     | Resend sending API key, entered only in Supabase |

4. Auth email settings: six-digit OTP, expiry 3,600 seconds. Copy
   `supabase/templates/magic_link.html` into **both Confirm signup and Magic
   link templates** so first-time and returning users receive `{{ .Token }}`.
   Subject: `Your PLANETS sign-in code`. Keep the template code-only; do not
   substitute `{{ .ConfirmationURL }}`. Email confirmations can remain enabled
   on hosted Supabase; `verifyOTP(type: email)` confirms the new user's code.

   The repository-scoped CLI also supports a partial hosted configuration
   update. Use an isolated temporary directory containing
   `supabase/config.toml` with **only** the following declarations, and copy the
   repository template into that directory's `supabase/templates/magic_link.html`:

   ```toml
   project_id = "YOUR_TEST_PROJECT_REF"

   [auth.email]
   otp_length = 6
   otp_expiry = 3600

   [auth.email.template.confirmation]
   subject = "Your PLANETS sign-in code"
   content_path = "./supabase/templates/magic_link.html"

   [auth.email.template.magic_link]
   subject = "Your PLANETS sign-in code"
   content_path = "./supabase/templates/magic_link.html"
   ```

   Run `supabase config diff --project-ref YOUR_TEST_PROJECT_REF --workdir TEMP_AUTH_DIRECTORY`
   through `npx --no-install`, review the declared changes, then run `config push`
   with the same flags. Undeclared remote settings remain unchanged. Do not push
   the full local development configuration to hosted Auth. Re-read the diff and
   both saved template bodies afterward; a subject-only diff does not establish
   that the body matches. Confirm SMTP remains enabled without printing its
   credentials.

5. Review Auth email rate limits and Resend Free daily/monthly limits in the
   dashboards. Custom SMTP starts with a low Supabase email allowance; set an
   appropriate test allowance within the Free quotas and stagger onboarding.
   Keep server resend/abuse protection enabled. Do not claim unlimited delivery.
6. Before publishing, request codes from the release app to **two consenting
   external, non-project-team inboxes**, including a new signup and a returning
   login. Verify receipt and successful code entry. Record time, provider,
   success/failure and delivery latency without emails, OTPs or credentials.

The built-in Supabase sender and Resend's default test sender are insufficient
for an arbitrary tester list. SMTP/DNS verification alone is not a delivery test.

## 3. Upload key and staging configuration

Google Play App Signing owns the distributed app-signing key. PLANETS retains
the separate upload key. Reuse an existing registered upload key if this package
already exists in Play; otherwise create it once on Windows:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE/.planets/android"
keytool -genkeypair -v -keystore "$env:USERPROFILE/.planets/android/planets-upload.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Copy-Item apps/mobile/android/key.properties.example apps/mobile/android/key.properties
```

Answer keytool's password/identity prompts locally. Edit the ignored properties
file with the actual passwords and path; `storeFile` uses forward slashes on
Windows and resolves relative paths from `apps/mobile/android`. Back up the
keystore/passwords securely outside Git. Existing Android ignore rules exclude
`key.properties`, `*.jks` and `*.keystore`; never put passwords in the example.
Debug builds need no signing secrets. Every release build fails if signing
fields or the keystore are missing; known debug-key names are rejected.

Before removing a release-task checkout, preserve ignored `android/key.properties`
and `config/staging.json` outside Git in an owner-restricted directory and verify
the copies match. Confirm the referenced permanent upload keystore also survives
cleanup. Restore the inputs into the eventual current-main build checkout only
after confirming those destinations are ignored; never overwrite other local
signing/configuration or print credentials. Keep the backup/passwords local.

Copy `apps/mobile/config/staging.example.json` to ignored `staging.json`. Supply
the **actual new project's** HTTPS URL and its `sb_publishable_` key from Project
Settings > API Keys. Keep `APP_ENV` as `"staging"`, `ENABLE_DEMO_TOOLS` as the
**string** `"false"`, and `SENTRY_DSN` empty unless a real staging DSN exists.
Only those five string keys are accepted by the distribution command. Never add
a service-role/secret key, database password, management token or SMTP secret.

From `apps/mobile`, the obvious closed-test command is:

```powershell
dart run tool/build_staging_bundle.dart
```

It validates distribution config, then invokes
`flutter build appbundle --release --dart-define-from-file=config/staging.json`.
Successful output: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`.
The validator rejects placeholders/local endpoints but cannot prove a project
exists or OTP works; that requires the hosted checks. It does not change runtime
support for local/self-hosted backends. Do not upload an old bundle after a failed
build; use the artifact from the successful command and record its SHA-256.

## 4. Verify the produced artifact

Use Google's [bundletool](https://github.com/google/bundletool/releases) outside
the repository. From the root, with its JAR at the indicated local path:

```powershell
$ctBundle = 'apps/mobile/build/app/outputs/bundle/release/app-release.aab'
java -jar C:/Tools/bundletool-all.jar validate --bundle=$ctBundle
java -jar C:/Tools/bundletool-all.jar dump manifest --bundle=$ctBundle --module=base
jarsigner -verify -verbose -certs $ctBundle
keytool -printcert -jarfile $ctBundle
Get-FileHash $ctBundle -Algorithm SHA256
```

Require package `community.planets.app`, version name/code `0.1.0`/`1`, target
SDK **at least 36**, and `android:debuggable` absent/false. Compare the signer
fingerprint with the upload key, not the debug key; self-signed upload certificates
are expected. Verify the emitted `build/app/intermediates/flutter/release/`
config inputs and the AAB's `base/lib/*/libapp.so` contain the actual staging
endpoint and no local backend, privileged tokens or SMTP/management secrets.
Preflight allows only the client-safe key and disables demos; also confirm no
DEMO marker/presets in the release smoke test. Record the artifact checks rather
than inferring SDK/signing from source configuration. Flutter 3.47.2 defaults to
compile/target 36; no Gradle/Flutter version change is needed for CT-01.

## 5. Publish the closed test (founder)

1. Create/open **PLANETS** in Play Console. Choose app/language and free/paid
   status deliberately; upload establishes `community.planets.app` permanently.
2. Enable Play App Signing using Google's app-signing key. Upload the verified
   signed AAB to Testing > Closed testing > create track/release.
3. Complete the dashboard's minimum app setup, store listing/contact details
   and App content declarations required for closed testing. Address the
   concrete founder decisions below before submission.
4. Create a testers email list or Google Group. Recruit **15–20** to retain at
   least 12. Select eligible countries/regions and add the list/group to the
   closed track; save and submit the release for review/publication.
5. Check Publishing overview and any managed-publishing hold. Wait until the
   closed release is actually available; an upload or pending review is not
   publication. Copy the track's opt-in link and send it to consenting testers.
6. Each tester must open that link with the **Google account used for Play on
   their Android phone**, join any required Google Group, opt in and install
   from Play. Being on the email list or installing a sideload is insufficient.
7. Verify at least 12 opted-in testers and record the date/time. Keep them opted
   in continuously for 14 days, ask them to use the app and collect feedback.
   Only then request production access if the personal-account requirement
   applies; the closed test does not itself grant production access.

### Minimum declarations: evidence and decisions

| Play question                                               | Repository evidence / immediate owner action                                                                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App access: all or some functionality restricted?           | Public browse exists; profile, creation and chat require email OTP. Declare restricted portions and provide reliable review access/instructions. Owner must supply a reviewer mailbox/access method that can receive codes; do not add an OTP bypass or static universal code.                                                                                                                                                                    |
| Contains ads?                                               | Current manifests/Flutter dependencies contain no ad SDK or ad feature. Confirm commercial intent before selecting the declaration.                                                                                                                                                                                                                                                                                                               |
| Data collected/shared, purposes, optionality and retention? | Email/auth identifiers, profile/display name/skills, selected public/private profile fields, rough/exact meeting location text, user content, private messages, optional profile/cover photos and session/device-local preferences exist. Sentry is off with empty DSN; no maps/GPS permission or configured push provider. Owner must classify Supabase/Resend processing, optional data, deletion/retention and the actual Data safety answers. |
| Target age groups and children-directed status?             | No accepted minimum-age/child policy in this release task. Owner must choose the offered Play age bands (under 13, 13–15, 16–17, 18+) and whether children are targeted; do not infer adult-only from test recruitment.                                                                                                                                                                                                                           |
| Content rating / user-generated content questionnaire?      | Profiles, shared activity/listing content, photos and chat are user-generated. Owner must answer the questionnaire about interaction, moderation and applicable content; repository code cannot establish legal guarantees.                                                                                                                                                                                                                       |
| Privacy policy URL / account deletion URL and process?      | POLICY01 adds provisional public policies, in-app version acceptance and a manual deletion-request path; it does not implement automated deletion or settle retention policy. Verify the live pages/process and founder-approved Play answers against the actual release. Report any unmet requirement as a publication blocker.                                                                                                                  |

These declarations are not finalized by CT-01. A required legal/policy question
must be answered by the owner; it cannot be replaced by an invented policy.

Android App Links do not block this test. After Play exposes the **app-signing**
SHA-256 fingerprint, update the host's `assetlinks.json` association for
`community.planets.app` per [project invite links](project-invite-links.md).
The upload/debug fingerprint is not the Play-installed signing fingerprint.
Existing browser fallback is acceptable while host verification is pending.

## 6. Internet smoke and handoff record

On the Play-installed release over ordinary internet (no adb reverse): launch,
request/receive/enter OTP, complete profile, browse (empty state is valid), create
one representative proposal or resource item, upload a profile/cover image,
sign out and back in. Check a private chat between two eligible participants if
available. Confirm demos are absent and failed requests surface errors.

Record: base/head SHAs and PR, AAB path/hash, package/version/target SDK,
non-debuggable/signature checks, project ref, migration/lint/advisor result,
two external OTP results, image/chat smoke results, remaining DNS/declarations,
Play release/opt-in link and opted-in count/start timestamp. Preserve failed or
unrun checks explicitly. Before real credentials arrive, no upload-ready AAB,
hosted readiness or running closed-test clock can be claimed.

Sources checked 2026-10-06: [Google target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878),
[12-testers/14-days requirement](https://support.google.com/googleplay/android-developer/answer/14151465),
[Flutter signing](https://docs.flutter.dev/deployment/android),
[Supabase environment deployment](https://supabase.com/docs/guides/deployment/managing-environments),
[Supabase custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), and
[Resend SMTP setup](https://resend.com/docs/send-with-supabase-smtp).
