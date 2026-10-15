# C01 parallel handoff — PARALLEL-CD-2026-10-15-v1

Status: implementation in progress; cumulative [PR #257](https://github.com/lillo24/planets.community/pull/257). Main `6b5f419` incorporated at `aec2ce1`; inherited C `e8c5c8c`. D cumulative #254 inspected at `db17cd2`, unmerged and not imported. C decisions and Option A are now explicitly supplied by the package; the prior missing-C00-approval gate is superseded. Runtime completion/validation remains required.

See [approved C contract](group-ideas-revision.md). No new runtime validation is claimed by this handoff. Historical evidence in `group-discussions-integration.md` qualifies only its recorded old heads.

## Shared seams

Preserve C `group_discussion` and D contact/coordination kinds separately. The later merger must compose Messages list/Requests, unread totals, ACK and account invalidation subscriptions before pagination/limits. Room invitations and activity notices are not human unread. Current C uses `get_own_message_unread_summary_with_discussions`; D's installed draft uses unread v2, Requests v3 and Chats v6. Do not pick either adapter wholesale.

Shared files include router/return destinations, Messages adapters/screens, moderation target constraints/evidence wrappers, EN/IT ARBs, generated database types, package scripts and CI classification. UI-polish #264 was open at start; preserve its skill-label/Workshop changes if it lands. Core C work does not authorize personal or representative contact access.

C's four historical unshipped migrations are `20261014074255_group_discussions_domain`, `20261014075208_group_discussion_report_evidence`, `20261014085233_group_discussion_mobile_projection`, and `20261014123208_group_discussion_named_links`. Revisions use forward migrations. D's interleaved report constraints/block hooks require populated-order verification when D lands, including before any later corrective migration can run. Main/applied migration history remains immutable.

## Local ownership

C owns only the prior external workdir `C:/Users/utente/.planets/qa/batch-c`, project `planets-c-qa`, ports 60320–60329, AVD `PLANETS_C_QA` on 5582, and C-specific temporary defines/evidence. D/shared stacks and physical device are excluded. No shared/hosted migrations, provider changes, deployment or real-user invitations are authorized.

## Pending interface/evidence updates

Core R01/R02, mobile R03/R04 and conversion R05/R06 use separate C worktrees, integrated into #257. Exact revised endpoints, source heads, migration order and executed commands will be added after implementation. The package allows C to merge first; D is not a waiting dependency. Re-fetch main and peer heads before final qualification and immediately before merge.
