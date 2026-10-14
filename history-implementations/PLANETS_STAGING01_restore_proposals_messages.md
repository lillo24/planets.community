# PLANETS STAGING01 — Restore Proposals and Messages by reconciling hosted schema

## Objective

Restore **Proposals** and **Messages** in the Android app against the existing **planets-staging** Supabase backend. Diagnose and resolve proven application/backend contract mismatches without losing or changing user content, weakening authorization, inventing fallback data, or touching Google Play until staging works.

This is an **operational staging recovery**, not a new feature or an invitation to refactor the app. Prefer the canonical repository migrations and existing verification procedures rather than ad hoc RPC patching.

## Verified evidence (2026-10-14, independent inspection)

- Repository: `https://github.com/lillo24/planets.community`. Refresh and inspect latest `origin/main` when executing; the inspected head was `cc07d467a338955d424872151e2855abcd631687`, but later changes may exist.
- Supabase project: **planets-staging**, project ref `cllpvruvrrvxczjitlqd`. Do not target any other project.
- Staging migration history contained **83 applied migrations**, last listed `20261011141420_persistent_group_reporting`.
- From the real staging API access logs on 2026-10-14 (UTC):
  - `09:05:09` — `POST /rest/v1/rpc/list_public_proposals_v2` returned **200**, followed by `POST /rest/v1/rpc/get_public_project_groups` returning **404**.
  - `09:05:56` and `09:06:14` — `POST /rest/v1/rpc/list_own_scoped_conversation_items_v5` returned **404**.
  - Other requests (skill catalog, public capacity, pending requested proposals) returned 200. This points to missing RPCs, not a general network outage.
- Read-only `pg_proc` inspection confirms staging has `list_own_scoped_conversation_items_v4` but **not v5**, and lacks `get_public_project_groups`.
- Current Flutter `apps/mobile/lib/features/messages/data/message_chats_gateway.dart` calls v5. Migration `supabase/migrations/20261012094725_chat_list_group_covers.sql` introduces it.
- Current Flutter `apps/mobile/lib/features/proposals/data/proposal_gateway.dart` calls `attachPublicProjectGroups` after listing proposals. `apps/mobile/lib/features/group_projects/data/group_project_gateway.dart` invokes `get_public_project_groups`. The function comes from `supabase/migrations/20261013100000_group_project_attribution.sql` (GRP03C / PR #241). The staging list query has at least two published results, so the enrichment call executes.
- `docs/development/mapfix02-project-detail-map.md` already warned that seven repository migrations were absent from staging at the 2026-10-12 MAPFIX02 baseline. A comparison from code-10 candidate commit `c6f7e6305036005bfb5438621fe1a21912fe1ed0` to the inspected `main` found **six additional migration files** (some have timestamps earlier than the latest applied migration). Do not assume that exactly thirteen remain now; recompute authoritative version/file parity. One such out-of-order file is `20261011132245_project_workspace_named_links.sql`.
- The code-10 candidate was assembled before PR #241. The *current live 404 requests* nevertheless prove that at least one running Android client is requesting the newer group RPC. The installed APK/version itself was not identified. Do not infer client version from filenames.

### Primary interpretation

The app can connect to staging. The shipped/running client expects newer database functions that the deployed staging schema does not have. The current generic UI error should disappear when the right server RPCs and their dependencies are installed, assuming no additional defects. The logs are stronger evidence than speculation about the map implementation or group chat data.

## Phase 1 — Read-only inventory, no writes

1. Fetch latest `origin/main`, inspect `AGENTS.md`, repository migration/runbook guidance, and relevant feature docs, including `docs/development/mapfix02-project-detail-map.md`, `docs/development/group-attributed-projects.md`, and `docs/development/grp03b-group-membership-ui.md`.
2. Establish exactly which application build/version is actually used if possible, but **do not make this a prerequisite** for fixing the confirmed missing server RPCs. Use ADB **read-only** for device `48091FDAS0041A` if connected; do not uninstall/overwrite Play-installed apps or clear data.
3. Independently confirm the Supabase URL/ref and database migration history, including code/file parity and migration hashes where tools support them. Identify **all** migrations absent from staging, not just two names. Include out-of-order versions and any drift in existing migrations. Do not mark a migration applied in history merely to silence a tool.
4. Determine migration dependencies, expected existing-data effects, grants, RLS, security-definer boundaries, publication behavior, generated API contracts, and potential incompatibilities with the currently distributed app. Treat the existing staging data as persistent tester data.
5. Reconfirm the two missing RPCs and identify their exact signatures and the safe anonymous/authenticated smoke checks. Do not query private user conversations, OTPs or credentials as diagnosis artifacts. Aggregate/sanitize logs.
6. Build/test all pending migrations against a **separate disposable local database** with a representative *non-sensitive* fixture, including populated upgrade, replay, PostgREST/RPC checks and focused Mobile validation. Reuse existing CI/test scripts. Do not reset the hosted database.
7. Produce a compact preflight report: missing versions in effective order; whether any baseline/remote drift exists; expected data changes; backup/restore strategy; test results; exact SQL/API checks; risks/stop conditions.

**Approval gate:** STOP after the preflight, **before any hosted schema migration, backend function deployment, SQL write, storage-policy change or destructive action**. Request explicit owner authorization to proceed on `planets-staging` with the enumerated migrations. If a suitable recoverable backup/snapshot cannot be established, or nontrivial migration safety is uncertain, stop and explain the blocker. Do not silently use production or another project.

## Phase 2 — Staging-only repair (only after explicit approval)

1. Take or verify the approved backup/snapshot and establish a recovery path appropriate to the staging plan. Never print/commit credentials or dump private contents into logs.
2. Apply approved **canonical repository migrations**, in the correct safe dependency order, using the existing supported deployment procedure. Pay attention to out-of-order migration versions; if the CLI cannot handle them safely, stop for a reviewed approach rather than falsifying migration history. Never hand-create only the two missing functions if that would omit prerequisites, security rules or migrations.
3. Do not reseed/delete/reset staging, weaken RLS, loosen grants, rotate keys, activate unrelated providers, raise quotas, or alter real Projects/groups/messages. Do not change production.
4. Verify the applied migration history and function signatures/grants. Force only a supported PostgREST schema-cache refresh **if actually necessary**; do not interpret a cached 404 as a reason to recreate routines.
5. Smoke the existing public list RPC and `get_public_project_groups` with an allowlisted, nonprivate sample; verify the function returns a valid response (including empty/no-attribution cases) and not HTTP 404. Verify the v5 Messages RPC with a **legitimate signed-in staging tester** entered by the owner. Do not impersonate users or bypass RLS. Ensure legacy v4 clients remain supported if repository contract requires it.
6. With the owner, reopen the **same installed app** (no uninstall or data clear), retry Proposals and Messages, and observe HTTP statuses/user-visible outcomes. If it still fails, capture sanitized request, HTTP/error code and which layer fails. Fix only confirmed remaining defects in a focused follow-up; do not hide errors or fabricate success.
7. Check that Profile, Scambio, Tavoli, Groups, project details, unread counts and normal permissions still work. Validate policy/privacy boundaries, old client compatibility, and zero unintended content edits.

## Non-goals and safety

- No release/APK/AAB rebuild merely to compensate for known missing server RPCs.
- No Play Console upload/publish, no production deployment or Cloudflare/provider configuration changes.
- No broad UI redesign, unrelated code cleanup, new group features or migration rewriting.
- No direct SQL patches bypassing existing migrations; no `supabase db reset` or equivalent on shared staging.
- No direct access to user OTPs, private chat content, session tokens or service-role secrets in verification output.
- Keep generic-user-facing error copies unchanged unless a separate product decision authorizes diagnostic UX.

## Deliverables and report

Provide (1) root-cause classification with read-only evidence, (2) exact pending migration checklist and preflight/tests, (3) explicit approval request before hosted writes, (4) after approval, deployment log/version parity and verification outcomes, (5) outstanding risks and whether a new app release is still needed, and (6) a clear statement of any steps blocked by missing phone/auth/session access. Do not say the app is fixed until Proposals and Messages both load successfully against staging in an authenticated real-client smoke test.