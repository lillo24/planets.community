# Policy documents, account acknowledgement and manual requests

- `application/policy_documents.dart` owns the pinned Terms/Rules bundle and
  four site paths. `PUBLIC_SITE_URL` optionally replaces the verified Workers
  HTTPS origin; it must be an origin without credentials, path, query or fragment.
  This is public configuration, not a key. Invalid configuration fails explicitly.
- `data/policy_acceptance_store.dart` uses the shared Supabase client and the
  account-only `get_policy_acceptance` / `accept_policy_bundle` RPCs. Only a
  confirmed exact account/version and server timestamp establishes acceptance.
  Reads with no record require explicit acceptance. Errors, malformed responses,
  missing RPCs and 15-second request timeouts deny protected actions. Session
  replacement/token refresh during a request rejects its response; retry reads
  under the current session. No local cache or device clock is used.
- `application/policy_acceptance_controller.dart` owns loading/retry/save states
  and generation checks for identity/version replacement and disposal. The app
  router gates editors, management, message details and invitation continuations.
  Standalone router constructors deny writing when no acceptance reader is given.
  Router refresh waits until after an active build frame. Native duplicate
  suppression preserves a pending acceptance form, but lets an acknowledged
  cold-start delivery resume its continuation.
  Public inline Resource request/search creation rechecks before opening/writing.
- `presentation/policy_acceptance_screen.dart` owns the unchecked control,
  provisional status, separate Terms/Rules links and disabled-until-checked action.
  It cancels the pending action to public Home on header/system Back; it does not decline
  or consume an invitation. A fresh action can resume its public preview.
  Sign-out remains available. Retry after a failed write can read a committed
  acceptance whose response was lost; another explicit acceptance is idempotent.
- `presentation/policy_link_action.dart` uses Help's supported external launcher
  for HTTPS, preserving Settings state. Failure exposes retry, visible URL and an
  explicit copy action. Clipboard failures are reported.
- `presentation/policy_write_boundary.dart` checks public inline writing controls
  against the same exact account/version state.
- `presentation/account_deletion_screen.dart` reviews a minimal Italian request
  for Leonardo using Help's mail launcher. The optional account email is manually
  entered because the current identity abstraction exposes only an ID. Identity
  replacement clears the draft and ignores old callbacks. Address/draft copying
  is explicit. No backend deletion/email endpoint is called.

Settings/privacy, public browsing, Help/reporting, blocking, the public deletion
route and sign-out bypass acknowledgement. The final authenticated Settings action
is deletion, including incomplete profiles. These paths perform no automated
deletion and cannot observe Send versus Cancel in another app.

Acceptance is **persisted and confirmed by the backend** for the account/version,
so another device or reinstall recognizes it. Historical SharedPreferences
acknowledgements are ignored: without a server record the account must explicitly
accept once. There is no local-to-server import, backfill or fallback.
The protected-action gate remains **client-side**. Existing domain RPCs do not
enforce acceptance and a custom client can bypass this gate; their existing
authorization is unchanged. Recording acceptance is not proof of reading or
legal approval, and it is not Privacy/marketing consent.
Material policy changes must bump `policyBundleVersion` together with
`apps/site/src/policies/metadata.ts` and register the version in a new migration
in `private.policy_bundle_versions`; the site test checks initial registry parity.
No live policy feed or Google Doc scraping controls acceptance.

Deploy the compatible additive migration and publish the factual site update
before releasing this client to external users. An unmigrated backend fails
closed. Merge does not perform either deployment. The private records cascade
only when an Auth account is actually deleted; they introduce no independent
retention exemption or deletion blocker. The full verified deletion procedure
and retention criteria remain separate work.

Review and remaining operator work: `docs/development/policy01-content-review.md`.
Backend contract and rollout: `docs/development/policy01b-server-acceptance.md`.
Run `npm run check:mobile`. The backend-free production-screen smoke is
`flutter drive --driver=integration_test/policy01_driver.dart
--target=integration_test/policy01_smoke_test.dart -d <owned QA Android device>`.
It uses synthetic identities and an injected mail launcher, not a real email send.
The driver saves actual screen captures under the system temporary directory's
`planets-policy01-runtime` folder. It does not prove an OS email/browser handoff.

Existing feature test harnesses use `preacceptedPolicyFixture` to keep their
accounts after acknowledgement; dedicated policy tests inject unaccepted stores.
