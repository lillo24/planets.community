# C01 parallel handoff — PARALLEL-CD-2026-10-15-v1

Status: local qualification complete; final classified CI/merge/cleanup are recorded by cumulative [PR #257](https://github.com/lillo24/planets.community/pull/257). Main `5c3d50b4` incorporated at `a7092c99`, main `224bcab6` at `0bcf6e23`, and ACTSPLIT01 main `32f37791` at `d298f059`; inherited C `e8c5c8c`. D cumulative #254 is published at `f355736a`, unmerged and not imported; actual interfaces and newer peer handoffs were inspected. C decisions and Option A are explicitly supplied by the package; the prior missing-C00-approval gate is superseded. Intermediate draft pushes skipped CI to avoid qualifying an incomplete head; the final published source must pass the complete classified CI gate.

See [approved C contract](group-ideas-revision.md) and the [revised qualification report](group-ideas-final-qualification.md). Historical evidence in `group-discussions-integration.md` qualifies only its recorded old heads.

## Shared seams

Preserve C `group_discussion` and D contact/coordination kinds separately. The later merger must compose Messages list/Requests, unread totals, ACK and account invalidation subscriptions before pagination/limits. Room invitations and activity notices are not human unread. Current C uses `get_own_message_unread_summary_with_discussions`; D's installed draft uses unread/ACK v3, Requests v4, Chats v7 and own-report v4. Do not pick either adapter wholesale.

Shared files include router/return destinations, Messages adapters/screens, moderation target constraints/evidence wrappers, EN/IT ARBs, generated database types, package scripts and CI classification. UI-polish #264 is incorporated; its skill-label/Workshop changes and editor-read observer are preserved. Core C work does not authorize personal or representative contact access.

C's four historical unshipped migrations are `20261014074255_group_discussions_domain`, `20261014075208_group_discussion_report_evidence`, `20261014085233_group_discussion_mobile_projection`, and `20261014123208_group_discussion_named_links`. Revisions use forward migrations. D's interleaved report constraints/block hooks require populated-order verification when D lands, including before any later corrective migration can run. Main/applied migration history remains immutable.

## Local ownership

C owns only the prior external workdir `C:/Users/utente/.planets/qa/batch-c`, project `planets-c-qa`, ports 60320–60329, AVD `PLANETS_C_QA` on 5582, and C-specific temporary defines/evidence. D/shared stacks and physical device are excluded. No shared/hosted migrations, provider changes, deployment or real-user invitations are authorized.

Revision QA uses the isolated Podman machine `planets-c-revision` with its explicit
connection/pipe. The prior development-engine C volume is preserved. Never change
global engine defaults or operate on D's `planets-d-qa` machine/ports/emulator.

## Implemented interfaces and qualification

The forward revisions are `20261015094229_group_ideas_general_and_history.sql`,
`20261015094324_group_ideas_workspaces_and_project_folders.sql` and
`20261015095020_group_discussion_conversion_final.sql`, plus
`20261020123403_group_idea_invitation_context.sql`. The final additive reader is
`list_group_discussion_invitations_v2`, with the legacy parameters/order and
exact old fields plus `purpose` and `visibility`. It delegates the unchanged
canonical legacy eligibility and exposes no messages, roster or links before
consent. Existing installed clients retain the old strict projection.
The conversion filename
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
- `get_own_message_unread_summary_with_discussions` composes C human unread
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

Current local evidence: `check:mobile` passed localization, formatting, analysis
and 3,489 tests (two existing skips); the additional account-switch mapping
regression also passed. Web's 98 tooling tests passed; 380 application tests
passed (two existing skips) with a local 30-second timeout allowance under host
contention, followed by the standard lint/typecheck/build/invitation checks.
Site's 19 tests, lint/typecheck/build and deploy dry-run passed. CI571 on
`7183efe0` passed all Database/Mobile/Web/Site jobs with default timeouts;
Mobile passed 3,559 tests with two existing skips. Fresh revised migration
replay and canonical database type generation succeeded on the isolated C stack.
The corrected forward SQL passed a clean replay, schema lint/security advisors and all 145 pgTAP files / 5,845 assertions. Populated old C upgrade passed 56 assertions across six original tables, including repeated application. Genuine Auth passed revised Ideas195, links/folders180 and conversion49 (including an observed publication-before-queued-send lock race). These focused counts are not summed as unique cases. Full CI Database passed on `7183efe0`; at that historical head native qualification remained pending. The completed final-runtime journey is recorded below. Manifest assertions
intentionally change for the added Idea invitation family. Final native artifacts
and the subsequent source CI will be recorded after the required checks.

The lanes explicitly serialized local SDK/backend/native work. On 20 October D
used the agreed window after C's failed native14, then explicitly returned the
complete slot at 13:31 UTC: its services, listeners, owned SDK processes and AVD
were stopped. C owns the following final native slot using only its named
machine, ports and AVD; fixture preparation stops the backend before APK building,
and runtime starts after the build. The final native evidence records the actual
source, run and stop verification.

D CI574 passed all classified jobs on `eed96e5d`, including its populated-history
checks and 3,611 Mobile tests/two existing skips. The peer's subsequent notice
copy/approved-policy/manual-procedure head `f355736a` passed all CI575 jobs,
including 3,613 Mobile tests/two existing skips. D remains
draft and unmerged: its corrected native launch previously received an automatic
approval-policy rejection. On 20 October the peer's same owned launch was allowed
under new explicit human authorization in a bounded preflight; D verified its
emulator stopped before returning the resource slot. That preflight is not
complete native qualification. In the later authorized window, D's retry reached
nine checkpoints before a decline-UI failure. M's app assertions completed, but
the host driver failed allocating screenshot memory and exited nonzero. Neither
is a complete qualified driver pass. Current native qualification and the
Group-member conversation lifetime choice remain unresolved. Representative policies 1 and 2
were explicitly approved in the D task, not inferred by C. C does not
retry D through another launcher or import its unfinished source. The package
allows C to qualify and merge independently; D must then reconcile actual C main.

Core R01/R02, mobile R03/R04 and conversion R05/R06 used separate C worktrees,
integrated into #257. The qualification report records source heads, migrations,
commands and actual results. Main advanced again to `32f37791` (ACTSPLIT01 #269)
during native QA and is incorporated at `d298f059`, preserving C routes and all
locale values. The lanes serialize the following focused SDK/native checks.
The package allows C to merge first; D is not a waiting dependency. Main and
peer heads are rechecked immediately before merge.

The final runtime source `56e657ed` passed all 41 revised Android checkpoints
with driver exit 0 and 41 fresh 960×1920 screenshots; seven contact sheets and
critical originals were inspected. The [R07 evidence map](evidence/group-discussions/r07/README.md)
records exact source/build/run/hashes and setup limits. The reconciled gate
passed 607 selected Mobile tests; final consent passed 142 affected tests,
214 real-Auth and 260 SQL assertions; the final Project layout passed 520 affected
tests, clean full analysis and formatting of 771 files. Counts overlap.
The conversion verifier then passed 57 assertions, including independent source
revocation and Project removal. Final native runtime and backend inventories were
empty after stopping C's AVD and its eight services; SDK serialization remains
explicit. The last two origin-reauthorization tests and targeted analysis passed,
then the full SDK/runtime slot was explicitly returned to D with zero proven
C processes/listeners. Final published-head CI runs remotely.
