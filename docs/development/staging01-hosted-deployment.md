# STAGING01 hosted deployment — 2026-10-14

The 13 reviewed canonical migrations are applied to **planets-staging**
(`cllpvruvrrvxczjitlqd`). Canonical history now matches all 96 repository
versions/names. The previously missing public group and Messages-v5 RPCs are
installed. No new app release was made.

After [the preflight](staging01-recovery-preflight.md) and PR #256, the owner
explicitly instructed **“Don't backup, apply migrations.”** This authorized the
staging deployment and waived the preflight's backup requirement for this run.
No backup or recoverable snapshot was taken or claimed. This is a task-specific
override, not a change to future deployment policy.

## Execution and canonical history

Source was fetched `origin/main` / `c99d9fe`; all 13 file SHA-256 values matched
the reviewed [manifest](evidence/staging01/pending-migration-sha256.json).
Before writes, the 83 stored migration records and all 509 routine definitions/
grants matched preflight digests. There was no new missing file or baseline drift.

The local CLI still had no access token. The connected Supabase migration API
executed the complete canonical SQL in reviewed order as one statement batch.
Preconditions inside the batch checked the baseline again; each file's original
version/name/full SQL was recorded only after that file's SQL executed. Final
conditions checked all 13 recorded SHA-256 values and 96 canonical records.
Ephemeral `lock_timeout=10s` and `statement_timeout=120s` bounded this operation;
no persistent database settings were changed. The API acknowledged success.

The API additionally recorded wrapper `20261014182158`, named
`staging01_canonical_recovery_20261014`. After checking every canonical entry
and the wrapper's exact executed-batch MD5/SHA-256, only that redundant wrapper
record was removed with a guarded metadata delete. All 83 previous records
remain unchanged, and all 13 original repository timestamps are present. This
avoids substituting API-generated timestamps for canonical migrations or marking
unexecuted SQL applied. No application routine was hand-patched, old migration
rewritten, or staging data reset/reseeded. The wrapper's identity and hashes
remain in [the deployment evidence](evidence/staging01/hosted-deployment.json).

## Verified hosted outcomes

- `list_public_proposals_v2`: HTTP 200, two public Proposals.
- `get_public_project_groups`: HTTP 200 both for those two public IDs and for
  an empty array. Both return `[]` because existing Projects are personal;
  these are valid domain states, not transport fallbacks.
- Messages v5: installed with the expected six-argument signature, STABLE
  JSONB return, security-definer boundary and empty search path.
- Messages v4: exact preflight definition hash retained. Both versions grant
  execution to `authenticated`, deny `anon`/`service_role`, and return HTTP 401 /
  `42501` for the anonymous smoke. No identity was impersonated.
- Public group projection: bounded UUID-array contract, STABLE JSONB result,
  empty definer path and deliberate anon/authenticated grants.
- All 110 pre-existing domain tables retain their row counts: 225 total rows.
  This is count verification, not a claim of a live row-by-row content audit.
  No private conversation bodies or Auth/session/OTP data were retrieved.
- Six Project anchors remain; exactly two first-publication timestamps were
  backfilled from their existing public source dates. Zero date mismatches or
  historical group assignments were found. Project-chat message count stays four.
- All 11 added private tables have RLS enabled. No private table grants exist
  for PUBLIC, anon, authenticated or service_role. Six older private tables
  without RLS remain the unchanged foundational server-only tables; none was
  introduced or granted client access by this deployment.

The hosted security advisor was checked before and after. New findings are the
11 intentionally RPC-only private tables with RLS/no client policies and 61
intentional security-definer exposure findings (4 anon, 57 authenticated), all
declared by the approved canonical files and covered by preflight security/API
tests. No new finding category appeared. Their identities/bounds/private grants
were reviewed; revoking these intentional RPC grants would break the contracts.
See the official explanations for
[RLS with no policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[anon definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
and [authenticated definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
The existing [leaked-password-protection warning](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
is unchanged; provider/Auth configuration was outside this recovery.

Public reads succeeded immediately, so no additional schema-cache refresh or
function recreation was needed. Production, Storage policies/objects, Edge
Functions, keys, quotas, providers, Play and installed apps were untouched.

## Remaining real-client acceptance

ADB has no connected device, including founder phone `48091FDAS0041A`; no
owner-entered staging tester session was available to the agent. The owner was
asked to reopen the same installed Android app and retry Proposals and Messages.
Authenticated v5 reads, same-app success and Profile/Scambio/Tavoli/Groups/
Project-details/unread regressions remain unverified until that response/smoke.
Backend deployment and public RPC recovery are verified; the app is not yet
claimed fixed end to end. No replacement APK/AAB is needed for the installed
server contracts. A client follow-up would require a confirmed remaining error.
