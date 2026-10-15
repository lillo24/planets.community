# C-R07 — Final C qualification, latest-main reconciliation and automatic source merge

## Objective

Complete and merge the revised C lane. There is no third integration chat and no requirement that D finish first. Follow the shared contract's Git, policy, isolation and no-deployment rules.

## Final review

Re-fetch actual main and current C/D PRs. Ensure the revision includes the existing C cumulative source and C-R00–R06 changes, preserves Batch A/GRP03C and intervening main work, and replaces the obsolete C00 policy rather than only adding new UI over old authorization. Reconcile D **if it is on main**; otherwise inspect/document its expected shared seams without importing or merging unfinished D. Use #257 or a clearly linked successor.

Check all invariants in the approved C matrix. Inspect real SQL effective definitions and client callers; tests formerly asserting no General/pre-admission/no-former access must be changed to prove the new intended contract. Do not weaken unrelated safety assertions.

## Required evidence

- Clean migration replay; populated main → C upgrade; populated old C → revised C upgrade where applicable; repeated application/no duplicate General or invitations; types/grants/advisors. When D is present also test combined fresh replay and populated peer preservation in actual sorted order, including report constraints, Block hooks, legacy RPCs, Messages/read-ACK kinds and both invalidation subscriptions.
- Full affected Mobile/Web/Database checks and Site where classified/affected; focused real-Auth tests for General, settings, visibility, full history, exact former cutoff, invitation and capability consent, creator vs manager, links, muted/hidden room delivery, publication races and opt-in Project membership. Record actual commands/counts/skips.
- One completed final-source Android emulator journey: ordinary setup/Group; General; all-member setting; ordinary member Idea; manager oversight of restricted Idea; invitations; pre-Join/full and former history; Hide/Show hidden/mute; Group/Idea links; propose/review/publish; one planner accepts and another declines; public newcomer has Project-only history; continuous view and return state. Capture and inspect EN/IT narrow/large-text and light/dark. A stopped driver or screenshots of loading screens are not a pass.
- Preserve existing Project/Tavolo/Resource conversations, profile/photo and link compatibility. If D is merged, add at least one legitimate member contact and representative conversation to the regression corpus; confirm no manager access to personal chat, no source leak and correct combined totals. Do not fabricate D runtime fixtures while D is absent.
- Review source record inventory and truthful user disclosure of manager/full-history access, retained pre-exit history, conversion audiences and external links. No new retention period or store-compliance certification is invented. Keep actual distribution work separate.

## Merge and cleanup

Do not ask again for approved C decisions or ordinary conflict resolution. Once this revised source matches the supplied contract, required validation/CI passes and no consequential blocker remains, merge the completed C cumulative PR. Re-fetch main immediately before merging and reassess any intervening change; the later merger owns combined correctness.

Verify the resulting main SHA, ancestry/equivalence of incorporated C stages and final behavior. Clean only proven incorporated C branches/worktrees/services. Do not delete D work or bypass a policy-denied resource cleanup. No real-user invitations, shared migrations, provider configuration, deployments or Play uploads.

If a genuine blocker remains, leave the affected cumulative work unmerged and identify it precisely; do not claim a partial/fallback implementation is the whole approved package.

## Return

Final PR/merge commit; included main and peer SHA; stage heads; delivered feature checklist; source/Project permission matrix; migration/API changes; all actual tests and native evidence; limitations and any safe continuity fallback; source-to-staging prerequisites; physical/iOS/accessibility/provider work not run; cleanup and residuals. Report whether D was actually included on main, not merely known as a draft.
