# Account-bound Terms/Rules acceptance (POLICY01B / POLICY02)

The two supplied implementation prompts describe one feature and are delivered
as one focused change, also covering the repository's POLICY02 plan. The pinned
Terms/Rules bundle remains `POLICY01-2026-10-08-v1`. A1 and Privacy B10 receive
only factual storage corrections, without changing legal terms, legal basis,
effective date or retention promises. Manual founder/device QA is not a merge
gate for this task by the user's explicit instruction; automated checks remain.

## Private database contract

`20261011082932_policy01b_account_acceptance.sql` adds:

- `private.policy_bundle_versions(bundle_version)`: reviewed published versions,
  initially just the pinned bundle. Client roles cannot register arbitrary text.
- `private.policy_acceptances(account_id, bundle_version, accepted_at)`: the Auth
  user UUID, exact registered version and initial server-generated `timestamptz`.
  The composite primary key serializes duplicate/concurrent acceptance. Retries
  insert with `ON CONFLICT DO NOTHING` then return the original row/time; earlier
  versions remain independent records. No email, IP, device ID or marketing data
  is stored. No existing profile or acceptance data is changed/backfilled.
- `get_policy_acceptance(p_expected_account_id, p_bundle_version)` returns zero
  or one exact-account/version row; zero means acceptance is required.
- `accept_policy_bundle(p_expected_account_id, p_bundle_version)` explicitly
  persists and returns one confirmed row with the same shape. It has no timestamp
  parameter and never changes an existing timestamp.

Both RPCs bind identity using `auth.uid()` and reject mismatched/null expected
accounts and absent Auth rows with `42501`. No completed profile or profile anchor
is required. Unregistered/null/non-exact versions fail with `22023`, including on
reads. Responses contain `account_id`, `bundle_version`, `accepted_at` only.
The public functions use security definer, qualified references, an empty search
path and authenticated-only EXECUTE grants. Private tables have RLS with no
client policies or direct privileges, including for `service_role`; the private
validator is not client-callable. No generic audit/outbox/Realtime event is added.

Records cascade on actual Auth account deletion so this feature adds no permanent
deletion blocker or erasure exemption. This does not implement account deletion:
existing domain/audit constraints, lawful retention criteria and the coordinated
verified deletion procedure remain separately unresolved. There is no promised
retention duration or indefinite preservation policy.

## Mobile and enforcement boundary

The production store uses `supabaseClientProvider`, checks the current session
before/after the call, validates the returned account/version/timestamp, and times
out each request after 15 seconds. Changed/expired sessions, including token
refresh during a request, reject the old result. The controller retains its
identity/version generation and disposal guards. Null means a successful read
without a record; transport, permission, schema and response failures are errors.
Backend failure never falls back to local state. A write response lost after
commit remains unconfirmed in the UI; Retry rereads the account/version, or an
explicit repeated acceptance returns the same original timestamp.

Historical SharedPreferences flags are ignored and never promoted or backfilled.
An account without a remote record must explicitly accept once. Another device
or reinstall reads the remote record without a new acceptance. The checkbox
starts unchecked; only its explicit Accept action writes. Header/system Back
exits to public Home without consuming an invitation; sign-out and document links
remain. Only the three redundant trailing cancel/Settings/Help buttons are removed.
Global Settings/Help, reporting, blocking and manual deletion access remain.

Persistence and confirmation are server-side; enforcement of the existing
protected-action boundary remains client-side. Existing Proposal/Tavolo/Resource/
Chat RPCs do not require acceptance and a custom client can bypass the UI gate.
Their canonical domain authorization is unchanged. This is Terms/Rules
acknowledgement, not general Privacy/marketing consent, proof of reading or legal
approval.

## Version and rollout procedure

For a future material Terms/Rules change, review the content, add a new migration
inserting the exact version into `private.policy_bundle_versions`, and synchronize
mobile `policyBundleVersion` and site `POLICY_VERSION`. Keep historical registry
and acceptance rows. Test that the prior version does not satisfy the new bundle.
The initial site's parity test pins the initial migration; future registration
should extend that test to the new migration as part of the version change.

Before external testing/releasing this client:

1. Review/apply the additive migration to its intended backend through the normal
   separately authorized deployment process and verify both RPCs and grants.
2. Publish the updated factual Terms A1 and Privacy B10 pages before the new client
   reaches external users. The legal bundle version is unchanged.
3. Release/test the client against that migrated backend. Existing device-only
   acknowledgements require one explicit acceptance. Missing RPCs fail closed.

PR merge runs validation only; the repository workflow does not deploy these
resources. This task authorizes code merge, not shared database migration,
website deployment, infrastructure changes or Play submission.

## Reproduction

Use an isolated disposable local Supabase project/ports; never reset a shared
stack. Run `npm run db:start`, `npm run db:reset`, `npm run db:lint`,
`npm run db:advisors`, `npm run db:test`, then `npm run policy:verify:local`.
Set `MAILPIT_URL` if its local port differs. The verifier refuses non-loopback
API/database/mailbox targets and creates only synthetic local OTP users. It proves
profile-free acceptance, eight simultaneous submissions preserving one timestamp,
an independent second OTP session, anonymous/cross-account/unregistered-version
denial, forged timestamp denial and private Data API isolation. pgTAP covers
version history, role privileges, exact parameters and Auth erasure dependency.
The verifier runs in Database CI and `check:db`; it never resets by itself.

Run `npm run db:types` after migration and commit only its canonical generated
output. Run `npm run check:mobile`, `npm run check:site`, and `npm run check:web`
for the affected client/site/generated-type/tooling surfaces. Flutter coverage
includes legacy flag rejection, malformed confirmations, missing RPC, permission,
offline/timeout recovery, identity/token/version/disposal races, duplicate taps,
restoration, invitation/OTP/setup continuations and EN/IT 320px/2x navigation.
No physical-device, external handoff, live deployment or legal approval is
established by these automated checks.
