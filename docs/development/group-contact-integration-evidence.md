# Batch D cumulative integration evidence

The sections below preserve the historical D00–D03 evidence. Current main,
revised D/M interfaces, policy decisions and final qualification are tracked in
[the parallel revision handoff](group-contact-parallel-handoff.md). Historical
green checks and partial native frames do not qualify the revised source.

**Historical stage evidence.** Policies 1/2 were approved on 19 October and the
scoped member policy 3 on 20 October 2026. Full combined CI and both complete
Android journeys passed; cumulative PR #254 merged as `db21460b`. The
[final qualification](group-contact-parallel-handoff.md#final-qualification-and-merge-20-october-2026)
supersedes the pending gates below without changing the original stage results.
No hosted migration, production deployment or app-store action occurred.

## Source and traceability

Main was pulled to `31521db` on 14 October 2026. Batch A integration PR
[#243](https://github.com/lillo24/planets.community/pull/243) is actually merged
(`7ab8700`, 06:52 UTC). The later main commits only archive prompts/add UXFIX
prompts; they introduce no competing runtime/schema definitions. The cumulative
branch merges fresh main and the complete D ancestry, without unfinished C work.

| Stage | Draft review artifact                                         | Source responsibility                                                                                      |
| ----- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| D00   | [#244](https://github.com/lillo24/planets.community/pull/244) | Provisional access/history/consent/finite-limit contract                                                   |
| D01   | [#247](https://github.com/lillo24/planets.community/pull/247) | Canonical contacts, role-bound human chat, projections, safety and upgrade/concurrency checks              |
| D02   | [#249](https://github.com/lillo24/planets.community/pull/249) | Contextual mobile contact, explicit source, retry/recovery, privacy invalidation and EN/IT safety layout   |
| D03   | [#253](https://github.com/lillo24/planets.community/pull/253) | Versioned independent seats/all-party consent, fresh history, Requests v3 and protected invitation reports |

Each plan uses its own branch/worktree. Draft stages are retained for review and
must not be merged independently. The cumulative PR is the eventual source gate.
The [coordination protocol](group-coordination-protocol.md) and
[distribution/record delta](group-contact-rollout-delta.md) specify concrete behavior
and remaining decisions.

## Verified checks and current limits

- D01 and D02 required CI passed on their recorded final stage heads. D02's Auth
  structural test now permits only the reviewed row-level AFTER DELETE cache
  invalidation trigger; it continues to reject application profile-creation hooks.
- D03 focused models/widgets: 10 passed, including EN/IT 320dp at 2x text,
  account A→B→A late replies and clearing an open consent dialog on access loss.
- D03 canonical SQL: 39 assertions passed, including original/new-party consent,
  independent membership and authority, fresh history, role loss, protected reports,
  source exit independence, and same-group replacement invalidating old consent.
- Real OTP/PostgREST D03 verifier: 218 checks passed, including simultaneous same
  final intent, grant revoke/regrant and lifecycle loss during observed lock waits,
  new-manager body/preview/unread denial, explicit version invalidation, Block,
  more than one request page, and equal-time message/admission/report boundaries.
- Populated D02→D03 additive upgrade preserved 130 existing table/column/row
  snapshots and the warmed Block function OID; repeated migration-up was harmless.
  This used an explicitly recorded fresh D02 cold start followed by local
  `--from-current-d02`, after Windows/Podman CLI recreation timed out. No timeout
  was reported as a passing reset. Normal CI uses the standard reset path.
- Generated Web types were produced from the combined running schema (102 D03
  lines); typecheck and strict public/private schema lint passed.
- Web checks passed: 382 tests and two existing skips, tooling checks, lint,
  typecheck, production build and static invitation build.
- Changed files pass formatting. The repository-wide Prettier command identifies
  seven existing untouched warnings (proposal-skills verifier and six older guides);
  they were not rewritten as part of D.

One whole Mobile run overlapped a consent-dialog source/test repair and used the
old compiled screen with the new assertion: 3342 passed, two existing skips and
that one failure. The repaired focused suite passed; D03 Mobile CI subsequently
passed on `e8a3c85`. A whole SQL run against already-populated QA data triggered
existing empty-baseline count assertions; it was not counted as qualification.
Both the D03 run `38587678652` and cumulative run `38591101897` subsequently
passed all required Mobile/Web/Site/Database statuses. Clean CI replay passed all
5,242 SQL assertions, both populated upgrade paths and the 218-check real-Auth
coordination verifier. The cumulative source gate was green at `8446bc7`.

The native Android build and genuine local users exercised contact context,
explicit source/purpose, exact lost-response recovery, manager triage, acceptance,
human send, audience and nonaccepting-manager denial. The first D03 native run also
reached fresh composition and additional seat claim. A harness retained a lazy
scrollable across account/route replacement; the corrected bounded helper re-finds
it, waits for auth readiness/canonical detail and records a diagnostic on missing
actions. The final gate also reconciles a committed proposal through its explicit
receipt-recovery UI if an access hint races the submit response.
Later attempts reached proposal submission but did not return a complete result;
the last driver lost its VM debug service (`ext.flutter.driver: Service has
disappeared`) without a whole-journey report. No native pass is inferred from it.
Complete native consent/fresh-history/report/block/decline/withdraw and Italian
evidence remains a release/source-merge qualification blocker. Eight native PNGs
were saved; inspected metadata denial was minimal, while the audience PNG showed
loading and did not qualify its final layout. Partial frames are not a pass.

Hot restart was executed successfully against the task-owned app through DTD.
The final harness itself passed scoped static analysis. No native device or
back-end limitation was hidden behind mocked successful results.

The task-owned target is `PLANETS_D_QA` / `emulator-5580`; the real phone
`48091FDAS0041A` and unrelated C services/worktrees were not used or cleaned up.
No physical Android, iOS or screen-reader qualification is claimed.

## A + D seams and final gate

A is present in the tested source. Existing A setup/late-save/offer, Idea/Requested
cards, Workspace paging/recovery/Checklist and group-attributed publishing tests
remain in Mobile CI. D adds contextual detail actions and a separate Groups chat
kind; it does not borrow Project/Resource membership, editing or Workspace access.
The native fixture's separately published group Project requires its own explicit
participation request. Installed Requests v1/v2 and own-reports v1/v2 exclude new
kinds before keyset limits; current Requests/own-reports v3 include coordination,
while Chats v6 and unread/read v2 preserve human-message semantics.

Before source merge: record exact founder approval/departures, finish native
qualification, confirm all required CI on the final cumulative head,
fetch main again and review the complete effective migration/schema diff. Approval
of the code does not authorize production rollout or resolve lawful retention.
