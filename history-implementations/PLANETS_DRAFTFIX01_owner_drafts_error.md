# PLANETS DRAFTFIX01 — Diagnose and repair the owner Drafts error

## Outcome

Fix the real failure behind **Bozze / My drafts** (`/drafts`) in the PLANETS Android app. A signed-in owner must be able to open the screen, see their actual drafts (or a truthful empty state), retry a failed source independently, and return from the editor without a generic unhelpful Error. **Do not treat this as a redesign**: a separate follow-up, MYHUB01, will unify all personally managed records after this root-cause fix.

## Current implementation evidence (checked against GitHub `main`, 2026-10-21)

- Default branch HEAD at review: `271e3b6392f7ce77c0ea0e37fc7f45ffc53bcc2d`; fetch the latest `origin/main` and inspect `AGENTS.md` at execution. The repository may have advanced.
- `apps/mobile/lib/features/drafts/presentation/drafts_screen.dart` loads `ownProposalsProvider`, `ownRecurringActivitiesProvider`, and `ownResourceListingsProvider` using `Future.wait`, derives each matching source's `pending` / `failed` state, and shows `ErrorState` + retry per source. Filter chips are multi-select; the current hub intentionally displays only draft lifecycle records.
- `apps/mobile/lib/features/drafts/application/own_drafts.dart` merges the three owner-controller collections and sorts by `updatedAt`. Gateways are in the existing `proposals`, `recurring_activities`, and `resource_listings` features and use their canonical owner RPCs. For Proposals/Tavoli, owner collection reads are followed by bounded structural-capacity lookups and strict model parsing.
- `apps/mobile/test/features/drafts/drafts_test.dart` covers fixture loading, contextual OR filters, partial failures and owner/delegated screens; those tests do **not** establish a successful real-hosted owner run for this report.
- On `planets-staging` (`cllpvruvrrvxczjitlqd`) read-only access logs for **2026-10-21 around 09:55–09:58 UTC**, requests from Dart/Android to `list_own_proposals_v2`, `list_own_recurring_activities`, and `list_own_resource_listings` returned **HTTP 200**. This does **not** establish that response parsing, follow-up capacity calls, actor/session validity, or the resulting Flutter state succeeded. Do not assume missing RPCs or deploy SQL speculatively. Older STAGING01 missing-function issues had been repaired.
- `CoverImage` reports image-load errors separately; distinguish a failing cover from an owner-collection `ErrorState`.

## Required diagnostic and fix workflow

1. **Identify the actual failing source** (Projects, Tavoli, Donate/Exchange) and layer: missing/incompatible RPC, HTTP/RLS, collection pagination, follow-up capacity RPC, JSON parsing, owner/ready-session invalidation, request racing, or render exception. Preserve original failure class and operation name in debug/test diagnostics, but never expose tokens, private user rows, raw addresses or stack traces in production UI.
2. Reproduce using a signed-in **owned** fixture and, when safely accessible, an authenticated staging session via normal app login. Do not borrow credentials, obtain OTPs from tables, impersonate a user, or dump private records. Phone serial for opted-in native QA: `48091FDAS0041A`; absence does not block local synthetic reproduction.
3. Build a focused regression reproducing the confirmed failure **before** fixing it, including a nonempty owner collection and any necessary follow-up capacity read. Treat HTTP 200 and successfully parsed usable data as separate assertions. Check that incomplete/invalid rows fail with an actionable but privacy-safe classification; do not suppress errors by returning `[]` or skipping malformed records.
4. Fix the actual bug in the responsible layer, preserving canonical authorization, typed lifecycle statuses, no stale identity rows, bounded paging, and latest actor/readiness guards. Do not “fix” the UI by hiding failure messages or force-marking collections successful.
5. Validate refresh and retry: one source fails while others show real data; the owner can retry only that source, switch filters, leave/reopen the screen, and return after a draft edit. An empty owner collection should be a valid empty result, not Error. Ensure unrelated errors from unselected sources do not incorrectly mask selected records.
6. Do not conflate unrelated `get_location_preview_v1` 403 entries in prior staging logs with the drafts failure unless actual evidence links them.

## Validation

- Run focused `test/features/drafts/` and affected owner gateway/parser/controller tests plus standard `npm run check:mobile` from repo root. Add native/hosted acceptance where access permits, and document synthetic vs authenticated proof separately.
- Verify Project, Tavolo, Donate and Exchange, including one valid draft and one published row, mixed partial failure, sign-out/account switch during pending reads, absent covers and malformed payloads.
- If no failing case is reproducible despite instrumented evidence, **do not claim the user-reported issue is fixed**. Report precisely which source and device/session evidence is missing and provide safe on-device collection instructions; a speculative empty-on-error workaround is forbidden.

## Scope, external access, and stop conditions

Use current Flutter/controller/gateway conventions; keep this correction minimal. No redesign of Drafts into all owned items (MYHUB01 handles that), new backends, hosted SQL writes, Play upload, phone installation, secrets, billable provider changes, or alterations to existing Project data. The known recent API status logs are supporting evidence only, not complete diagnosis. If staging deployment or changed RLS is demonstrably required, stop for an explicit approval and safe preflight; do not change staging automatically.

## GitHub completion and Codex report

Work on an isolated branch from latest `main`. After correcting the **confirmed** defect and passing relevant tests plus required CI, open a focused PR and **merge it into `main` automatically**, then sync `main` and clean the task branch/worktree. If root cause cannot be proven or a consequential decision is unresolved, leave a draft PR with clear blocker rather than claiming success or merging a guess. Report the observed symptom, responsible source/layer, before/after reproduction, actual tests, PR link/merge state, whether physical authenticated QA was performed, and any remaining blocker for MYHUB01.