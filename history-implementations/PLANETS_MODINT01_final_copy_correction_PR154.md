# PLANETS MODINT01 — final restriction-copy correction on PR #154

Continue the existing draft PR #154 in `lillo24/planets.community`. This is a small correction to the private interaction-restriction explanation, followed by an updated founder-review packet. It does not reopen the completed integration or behavioral QA.

## Verified baseline and scope

- Branch: `codex/modint01-moderation-auth-integration`.
- Published head: `70c0454bde671f3ea4a9841b92b9c80990f8102d`.
- Tested source: `cf5469ab32912299b4e382e8ef582e99cbf99b51`.
- Included main, still current when this prompt was prepared: `e7971d6611a1bd750c0c51b797234f5cf19c9dec`.
- PR #154 is draft, unmerged and conflict-free. Hosted run `37771267505` passed classification, Mobile, Web, Site and Database on the tested source. Published changes contain only documentation and images.
- Complete real Android and normal-browser campaigns passed, with precise source boundaries in `docs/development/modint01-moderation-auth-integration-review.md`. The 28 current captures and their provenance are indexed in `docs/development/screenshots/modint01-continuation/README.md`.

Read the current `AGENTS.md`, relevant folder maps and review/copy packet. Fetch and inspect the current task head and main before editing. Keep this corrective work on the existing branch/PR; this instruction overrides the default new-worktree/new-PR workflow. If main has moved, assess conflicts and affected contracts before deciding whether reconciliation is necessary. Do not automatically repeat the entire integration campaign.

All required design and technical context is in the repository. Private Windows backups are optional resources for reuse, not required external inputs for this copy correction.

## Demonstrated wording gap

The source ARB key `noticesRestrictionEffect` currently describes new outbound Project join requests and Scambio/Dona requests, but omits admission through participant invitation links.

Implemented behavior already covers that admission path. In `scripts/verify-local-modint01.mjs`, an active interaction restriction denies a new `accept_project_participant_invitation` action with PT409 and verifies no new membership/receipt/event side effects. Recovery of an existing receipt remains strictly read-only. These are existing rules, not a new policy proposal.

Correct the private notice so a person does not infer that an invitation link bypasses their restriction. Keep the explanation concise and preserve pending-request withdrawal and relationship-preservation semantics.

## Required change

Update only the English and Italian values of `noticesRestrictionEffect` in the canonical ARBs under `apps/mobile/lib/l10n/`, with the normal localization generation workflow. Use this draft wording:

**English**

> While active, this blocks new Project join requests, new admissions through participant links, and new Scambio/Dona requests. Pending outbound requests were withdrawn when it was applied. Existing memberships, agreements and organizer roles are preserved; their usual rules and other active restrictions still apply.

**Italian**

> Finché la limitazione è attiva, non puoi inviare nuove richieste di partecipazione ai Progetti o nuove richieste in Scambio/Dona, né aderire ai Progetti tramite link di invito. Le richieste in attesa sono state ritirate quando è stata applicata. Partecipazioni, accordi e ruoli esistenti sono conservati e restano soggetti alle regole abituali e ad altre eventuali limitazioni.

Treat both versions as proposed founder-review copy, not founder approval. Small grammatical refinements are permitted if they preserve this exact meaning; report any refinement. Do not imply that existing membership/receipt confirmation is blocked, that every chat action is restricted, or that revocation automatically resubmits requests.

Leave all other copy and product behavior unchanged. Do not change backend rules, migrations, invitation APIs, error mappings, navigation, suspension screens, or disclosure/notification/appeal policy.

Regenerate the verbatim copy extract in `docs/development/modint01-moderation-copy.md` and update the review packet with the precise correction and tested/published source records. Existing completed QA stays valid for unchanged behavior; do not relabel old evidence as a new run.

## Proportionate verification

- Run localization generation and the required Mobile formatting/static-analysis checks.
- Run the existing focused own-consequence presentation tests, including scroll/reduced-height coverage where already present. Update expectations only if the displayed sentence changed; do not add tests that merely repeat the ARB value.
- Inspect the updated notice in EN and IT using the existing widget harness or an available native device. An explicitly labelled widget preview is sufficient to review this text-only correction. Preserve historical actual-capture provenance; do not claim a preview is real-backend QA.
- Do not restart/reset a backend, rebuild all applications, or rerun the full OTP/request/browser/Database campaigns solely for this text change. If a real layout regression is demonstrated, fix only that defect and validate its affected area.
- Commit/push the narrow correction and allow normally classified CI once. Do not modify workflow classification or manually trigger duplicate unrelated suites. Report the actual executed/skipped jobs and exact tested source.
- Preserve the founder's request to leave emulator/build processes running; do not stop them incidentally. New copy-generation or preview work does not authorize shared-service changes.

Open dependency findings, Realtime limitations, physical-device/iOS/accessibility gaps and hosting/policy decisions retain their current dispositions. Do not claim this correction resolves them or establishes release readiness.

## Completion and founder handoff

Update the same PR #154 and archive this prompt under `history-implementations/`. Keep the PR draft/unmerged, without deployment or predecessor closure.

Return the PR URL, exact correction, affected files, actual checks, tested/published SHAs and a direct link to the updated EN/IT review packet. State clearly:

1. The required MODINT01 Android/browser behavioral QA is complete.
2. The invitation wording gap is corrected without changing moderation behavior.
3. Founder wording/presentation approval remains the next review decision.

Do not create another implementation task or demand another full QA loop merely because that founder decision is pending.
