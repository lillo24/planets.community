# C01 parallel handoff — PARALLEL-CD-2026-10-15-v1

Status: implementation in progress; cumulative [PR #257](https://github.com/lillo24/planets.community/pull/257). Main `94af1c2` incorporated at `33fa116`; inherited C `e8c5c8c`. D cumulative #254 inspected at `963ad95`, unmerged and not imported. C decisions and Option A are explicitly supplied by the package; the prior missing-C00-approval gate is superseded. Runtime completion/validation remains required. Intermediate draft pushes may skip CI to avoid qualifying a knowingly incomplete head; the final source must receive the complete classified CI gate.

See [approved C contract](group-ideas-revision.md). No new runtime validation is claimed by this handoff. Historical evidence in `group-discussions-integration.md` qualifies only its recorded old heads.

## Shared seams

Preserve C `group_discussion` and D contact/coordination kinds separately. The later merger must compose Messages list/Requests, unread totals, ACK and account invalidation subscriptions before pagination/limits. Room invitations and activity notices are not human unread. Current C uses `get_own_message_unread_summary_with_discussions`; D's installed draft uses unread v2, Requests v3 and Chats v6. Do not pick either adapter wholesale.

Shared files include router/return destinations, Messages adapters/screens, moderation target constraints/evidence wrappers, EN/IT ARBs, generated database types, package scripts and CI classification. UI-polish #264 was open at start; preserve its skill-label/Workshop changes if it lands. Core C work does not authorize personal or representative contact access.

C's four historical unshipped migrations are `20261014074255_group_discussions_domain`, `20261014075208_group_discussion_report_evidence`, `20261014085233_group_discussion_mobile_projection`, and `20261014123208_group_discussion_named_links`. Revisions use forward migrations. D's interleaved report constraints/block hooks require populated-order verification when D lands, including before any later corrective migration can run. Main/applied migration history remains immutable.

## Local ownership

C owns only the prior external workdir `C:/Users/utente/.planets/qa/batch-c`, project `planets-c-qa`, ports 60320–60329, AVD `PLANETS_C_QA` on 5582, and C-specific temporary defines/evidence. D/shared stacks and physical device are excluded. No shared/hosted migrations, provider changes, deployment or real-user invitations are authorized.

Revision QA uses the isolated Podman machine `planets-c-revision` with its explicit
connection/pipe. The prior development-engine C volume is preserved. Never change
global engine defaults or operate on D's `planets-d-qa` machine/ports/emulator.

## Pending interface/evidence updates

The forward revisions are `20261015094229_group_ideas_general_and_history.sql`,
`20261015094324_group_ideas_workspaces_and_project_folders.sql` and
`20261015095020_group_discussion_conversion_final.sql`. The conversion filename
was generated after its new core dependency before shipping; no main/applied
migration was rewritten or renumbered. They follow the four inherited C files.

- Core additions: `create_group_discussion_v2`, `get_group_discussion_v2`,
  `list_group_discussions_v2`, settings get/set, invitation capability
  create/preview/accept/revoke, preferences, notices and versioned history/ACK.
  Current access scope IDs are distinct from explicit admission IDs. Legacy
  readers keep their installed shapes and exclude new summary kinds.
- `list_my_discussion_groups_v2` composes Ideas and independently entitled Project
  folders before pagination. `list_group_project_conversations` uses the exact
  installed v5 Project row and canonical chat entitlement before limit;
  `list_own_group_project_chat_folders` maps only requested readable chats (max25).
- Link `*_v2` RPCs preserve strict collection shapes and accept the current
  `p_expected_admission_id` access scope. General owns the Group-wide collection.
  Former chat history grants no current collection or external-open permission.
- Conversion get/request/review/create-draft APIs bind one actual publisher's
  private draft. Publication freezes the source in the ordinary transaction.
  `list_my_discussion_project_invitations` is bounded per actor and exposes only
  public Project metadata; `opened` is not admission. `get_project_discussion_origin`
  separately checks canonical Project and source history rights.
- `get_own_message_unread_summary_with_discussions_v2` composes C human unread
  with the installed base totals. A later D merger must compose its newer base
  adapter without counting Project folder aliases twice. Ordinary room refresh
  uses `group-discussions:group:<uuid>` with a Group-ID-only invalidation payload;
  account hints remain independently subscribed.

Mobile entries are Messages Group folders (Projects / General & Ideas), Group
participation links, structured Requests/activity, capability links and a separately
authorized planning-history button in canonical Project chat. Continuity currently
uses the permitted linked read-only source fallback; there is no copied transcript
or unified interleaved timeline. Workshop return markers compose with #264's actual
editor-read observer.

Current evidence: full Flutter analysis passed with no issues. Full mobile tests,
Web gate and isolated engine startup are in progress; no revised SQL/Auth/native
runtime pass is claimed. Manifest assertions intentionally change for the added
Idea invitation family. Final command counts, types, native artifacts and source
SHA will be recorded after the required checks.

Core R01/R02, mobile R03/R04 and conversion R05/R06 use separate C worktrees, integrated into #257. Exact revised endpoints, source heads, migration order and executed commands will be added after implementation. The package allows C to merge first; D is not a waiting dependency. Re-fetch main and peer heads before final qualification and immediately before merge.
