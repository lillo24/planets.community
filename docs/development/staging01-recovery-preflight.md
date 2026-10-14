# STAGING01 staging recovery preflight

Status: Phase 1; hosted writes await explicit owner approval and a verified
recoverable backup. The Android app is **not yet verified fixed**. No hosted
schema/data, Edge Function, provider, Storage policy, Play release or installed
app was changed. The active [STAGING01 plan](../../history-implementations/PLANETS_STAGING01_restore_proposals_messages.md)
requires this stop before Phase 2.

## Verified cause and target — 2026-10-14

Inspected source: `origin/main` / `17b7c76` (96 canonical migration files).
Connected project metadata independently identifies **planets-staging**,
`cllpvruvrrvxczjitlqd`, `https://cllpvruvrrvxczjitlqd.supabase.co`, healthy,
EU West 1, PostgreSQL `17.11.0.003`; its organization is on the Free plan.

Staging has 83 migration versions, ending `20261011141420`. Fresh anonymous
PostgREST reads returned:

| RPC                                                               | HTTP / result                              |
| ----------------------------------------------------------------- | ------------------------------------------ |
| `list_public_proposals_v2`                                        | 200; two public rows; content not recorded |
| `get_public_project_groups` with an empty UUID array              | 404 / `PGRST202`                           |
| `list_own_scoped_conversation_items_v5` with a fictional identity | 404 / `PGRST202`; no private data read     |

Catalog inspection confirms v4 exists and both newer functions are absent.
The current proposal gateway enriches public results with group attribution;
the current Messages gateway invokes v5. Missing deployed contracts therefore
explain both failures without requiring a client fallback or data reset.
Sanitized edge-log aggregation for 09:00–09:10 UTC found three proposal-list
200s, three group-attribution 404s and four Messages-v5 404s.

ADB reports only `emulator-5582`; phone `48091FDAS0041A` is absent. Its installed
version, signer, installer and runtime remain unknown. No app install, uninstall,
data clearing, OTP inspection or staging session impersonation was performed.

## Complete pending set, in application order

All files are under `supabase/migrations/`. Reviewed bytes are pinned in
[the SHA-256 manifest](evidence/staging01/pending-migration-sha256.json).

| Version          | Canonical file suffix                       | Effect / dependency                                                                                                                                             |
| ---------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `20261011132245` | `project_workspace_named_links.sql`         | Restructure existing private links in place; new ID/name/legacy marker; preserve old URL RPCs. Older than the latest applied version: requires `--include-all`. |
| `20261011180000` | `location_text_provenance.sql`              | Private provenance table/triggers and additive location metadata; no inferred manual backfill.                                                                  |
| `20261012091701` | `profile_content_only_update.sql`           | Add authenticated content-only profile edit; preferences are independent.                                                                                       |
| `20261012094725` | `chat_list_group_covers.sql`                | Add v5 on v4, with authorized nullable cover metadata; v4 remains.                                                                                              |
| `20261012104716` | `proposal_skills_management.sql`            | Manager-authorized skill operation and compatible ordinary content-update implementation.                                                                       |
| `20261012110923` | `group_membership_and_authority.sql`        | Add private group relationship/history/receipt tables and canonical identity/authority rules.                                                                   |
| `20261012111424` | `group_relationship_api.sql`                | Relationship/structural RPCs on the preceding rules.                                                                                                            |
| `20261012111833` | `group_membership_blocking_and_grants.sql`  | RLS, explicit grants, block integration and schema-cache notification for the preceding APIs.                                                                   |
| `20261012152803` | `group_exact_self_membership_context.sql`   | Authenticated exact-self relationship projection.                                                                                                               |
| `20261013100000` | `group_project_attribution.sql`             | Add publication provenance, guards and bounded public group projection; depends on group authority.                                                             |
| `20261013100100` | `group_project_atomic_creation.sql`         | Atomic group-bound scratch/template drafts on the attribution domain.                                                                                           |
| `20261013100200` | `group_project_publish_revision.sql`        | Revision-checked publication; legacy publishers share the guards.                                                                                               |
| `20261013175400` | `project_workspace_paging_and_recovery.sql` | Version, paging and durable Add recovery; depends on the older named-links migration.                                                                           |

Expected existing-data effects are limited to new workspace columns/defaults
and personal Project first-publication provenance. Read-only staging aggregates
show six Project anchors, two previously published Proposals, zero published
Tavoli, zero groups, zero workspace rows and four Project-chat messages. The
publication migration fills the two known publication dates; it never assigns a
historical Project to a group. New relationship/receipt/provenance tables start
empty. Existing user content, messages, memberships, policy acceptances,
location geometry, cover metadata and notification state must be preserved.
No new relationship, group publication or outbox event is created merely by
applying these migrations. DDL may briefly lock affected tables.

## Baseline and migration drift

81 applied migration statement arrays match a clean canonical replay exactly.
`20261010112941` and `20261010173000` were stored remotely as one complete file
instead of the CLI's split statements: their complete-file MD5 matches after
line-ending/outer-whitespace normalization. Internal whitespace is preserved;
this is a storage-format difference, not evidence of a changed SQL file. No
history repair or applied-file rewrite is proposed.

One extra hosted object is outside canonical history:
`public.rls_auto_enable()` / event trigger `ensure_rls`. Its inspected body
enables RLS only on newly created `public` tables, matching the documented
[Supabase event-trigger pattern](https://supabase.com/docs/guides/database/postgres/event-triggers).
The rehearsal reproduces its exact definition/grants locally, then compares all
509 hosted non-extension `public`/`private` routines with the baseline. Canonical
PLANETS tables retain explicit RLS; this recovery neither removes this hosted
setting nor adopts it as a repository dependency. These comparisons cover
stored migration SQL and routine definitions/grants, not a full physical
database or every platform setting.

## Rehearsal and checks

A separate disposable `planets-staging01-qa` stack uses loopback API/database/
mailbox ports `60421`/`60422`/`60424`. The retained development and Batch C/D
databases were not reset. The checkout's pinned CLI is `2.118.0-beta.39`.
Windows uses the existing Podman Docker-compatible endpoint
`tcp://127.0.0.1:55600`; that host-specific endpoint is not a repository default.

- Clean replay of all 96 migrations and empty deterministic seed: passed.
- Standard local lint and security advisors: passed.
- Complete pgTAP: 139 files / 5,118 assertions, passed.
- Focused Mobile gateway/controller/group-attribution tests: 34 passed.
- `flutter analyze lib/features/messages lib/features/proposals lib/features/group_projects`: no issues.
- Exact 83-version populated upgrade: passed; all 13 files applied, no-op retry
  passed, 2,958 original rows across 110 tables preserved, and expected personal
  publication provenance verified. The extra hosted RLS helper was reproduced.
- Public proposal/group reads, populated Messages v4/v5 compatibility (two
  items), anonymous and wrong-identity denial: passed. See
  [the result](evidence/staging01/upgrade-result.json).
- Post-upgrade group membership (106 assertions), group Project attribution
  (90 assertions), Project/Tavolo workspace/authority and location
  (210 API/concurrency checks) verifiers: passed, fake providers only.
- Generated public TypeScript contract parity: passed with no file diff.
- Verifier syntax/format, reviewed migration-byte parity, direct pinned CLI
  dry run and missing-disposable-flag rejection: passed.

The [local verifier](../../scripts/verify-local-staging01-upgrade.mjs) resets only
the explicitly selected, non-default, task-owned loopback stack to the exact 83
recorded files, including the omission of the older workspace migration. It
uses existing genuine-local-OTP verifiers for representative histories, hashes
every predecessor table's original columns, then applies all pending canonical
files with `migration up --local --include-all` twice to test the no-op retry.
Evidence records hashes/counts, not conversations, identities or tokens.

To reproduce, copy the current `supabase/` tree to a separate local workdir,
change `project_id` to `planets-staging01-qa` and all ports away from other
stacks, and expose the pinned `supabase` executable on PATH. On Windows the
task's outside-repository wrapper forwards arguments to that executable.
Set `SUPABASE_WORKDIR` to the disposable workdir,
`PLANETS_DISPOSABLE_QA=1`, and `MAILPIT_URL` to its loopback mailbox; start the
stack and run `node scripts/verify-local-staging01-upgrade.mjs` from the checkout.
`--continue-after-replay` skips only the reset when resuming an already replayed
83-version local baseline; exact version/file/routine comparisons still run.
The usual run requires a reset. Run pgTAP on clean data before fixture verifiers.

## Backup, approval and recovery requirements

No recoverable staging snapshot/export has been verified. This machine has no
Supabase CLI access token, linked project or ignored staging client config.
The connected management tools permit read-only inventory but do not provide
a backup-export capability. Never infer a backup from project health or the
Free plan. Supabase recommends off-site CLI exports for Free projects, and
database backups exclude actual Storage object bytes; see
[Database Backups](https://supabase.com/docs/guides/platform/backups).

Before writes, the owner must provide or authorize an accessible protected
backup path and legitimate database/CLI access without putting credentials in
chat, Git or logs. Take a consistent recoverable PostgreSQL export/snapshot
covering Auth, public/private domain data, migration history, grants and Storage
metadata; retain the corresponding platform/extension versions and account
configuration needed for restoration. Keep the backup encrypted or in an
owner-restricted location outside Git, record its timestamp/hash, and verify a
restore into an isolated restricted target. Storage objects remain untouched
by this repair; an owner-approved recovery must retain their bytes and mapping.
A nominal schema-only dump or the CLI's default managed-schema exclusions are
insufficient to establish full tester-data recovery. No paid backup/PITR or
new hosted resource is authorized by this preflight.

**Stop if backup/restore cannot be verified, migration hashes/history changed,
new pending migrations appear, dependencies fail rehearsal, or grants/privacy
checks regress.** Do not mark a file applied without executing it. If one
transaction fails after earlier files commit, retain truthful history, halt,
inventory the actual state and review recovery; do not reset staging or apply
ad hoc replacement functions. A restore discards later writes and requires a
separately approved recovery/maintenance decision.

After explicit approval, from the reviewed commit and a separate linked
deployment workdir, verify the linked ref is exactly `cllpvruvrrvxczjitlqd` and
that the dry run enumerates exactly the 13 reviewed files:

```text
supabase migration list --linked
supabase db push --linked --skip-vault --include-all --dry-run
supabase db push --linked --skip-vault --include-all
supabase migration list --linked
supabase db lint --linked --schema public,private --level warning --fail-on warning
supabase db advisors --linked --type security --level warn --fail-on error
```

The write command is Phase 2 only, after the backup gate. Do not include seeds,
role dumps or Vault changes in deployment. Prefer CLI-controlled canonical
history; the management migration tool generates its own version and is not a
substitute for preserving these exact canonical timestamps.

## Exact post-deployment acceptance

Verify these installed signatures/security boundaries in `pg_proc`:
`get_public_project_groups(uuid[])` (anon/authenticated), and
`list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid)`
(authenticated only). Both are STABLE JSONB security-definer RPCs with empty
`search_path`; retain v4 and its existing grants. Verify private relationship,
receipt and provenance tables have RLS and no client table grants.

Anonymous smoke: call `list_public_proposals_v2` with a bounded page, then group
attribution for those public IDs and an empty array. Existing personal Projects
legitimately return `[]`; a request failure must remain an error. Require HTTP
200, not 404. Messages smoke needs a legitimate owner-entered staging tester
session: bind `p_expected_profile_id` to that tester, `p_scope='all'`,
`p_limit=20`, null cursors, and require a valid v5 response. Compare v4 metadata,
ordering and unread counts; only v5's nullable cover field is additive. Do not
record message bodies/session tokens or bypass account authorization. Anonymous
and wrong-identity attempts must be denied.

Use the same installed Android app and account to reopen/retry **both Proposals
and Messages**, then check Profile, Scambio, Tavoli, Groups, Project details and
unread counts. Record sanitized RPC/status/outcome, permissions and unchanged
content, without uninstall/data clear or a release. If the RPC inventory is
correct but PostgREST remains stale, use a supported schema-cache refresh only
when necessary; never recreate a function because of a cached 404.

No new app release is required to install the confirmed missing server RPCs.
Whether any additional client defect remains can only be decided after the
authenticated staging/real-client smoke. Phone access, owner-entered Auth,
backup verification and hosted migration approval remain outstanding.
