# PLANETS — COCREATE-CAL01-FIX01: calendar corrections

**Prepared:** 23 October 2026 (Europe/Rome).  
**Status:** Ready for implementation. This is the corrective Codex handoff after CAL01 review.  
**Repository:** `lillo24/planets.community`.  
**Current main inspected:** `67eee7b402986266116d92d4efe5d8fc690f3a7b`.  
**Predecessor:** PR #309 is merged; merge commit `d9f559951b79be568004b7507b16f4b4b216db48`.

## Assignment

Correct the four verified calendar defects below. Preserve the existing community calendar, canonical meeting records, attendance commands, privacy boundaries and installed-client contracts. Finish the implementation, targeted validation, documentation and normal PR/merge workflow.

Start from current `main` and inspect applicable `AGENTS.md`, the actual current implementation and any concurrent fix before editing. The inspected SHAs establish the review evidence; they are not instructions to reset to an older checkout or repeat work already completed. Use an isolated branch/worktree and preserve concurrent changes.

The original feature prompt is `history-implementations/PLANETS_COCREATE_CAL01_community_calendar.md`. The calendar already exists at **Find people → Communities → community → Calendar**. This task repairs that feature; optional places and the compact map remain subsequent work. No external attachment or product document is required.

Current main also includes PR #298's external Activities/map integration. Preserve that work and the calendar verifier's owned-loopback `MAILPIT_URL` override. The later community/place-map work must build on the shared map implementation; this corrective task changes no map behavior.

The review findings were established by source inspection, not a new runtime reproduction. Reproduce each case with a focused regression test, then make it pass through the implementation change. Report any source evolution that has already resolved a finding.

## Verified findings and ownership

| ID | Observed behavior | Primary source |
| --- | --- | --- |
| CAL01-F01 | The 20-second refresh and return from details replace every loaded page with page one, dropping later meetings and date markers. | `apps/mobile/lib/features/co_creation/presentation/co_creation_calendar_screen.dart` |
| CAL01-F02 | A calendar row can correctly report `can_join=false`, then open a recruitment screen with an enabled Join based only on card availability. | `domain/co_creation_calendar.dart`, `presentation/co_creation_recruitment_screen.dart`, recruitment readers |
| CAL01-F03 | The calendar filters out a blocked/unavailable creator even when the viewer retains canonical current-member meeting review and active attendance. | `supabase/migrations/20261023113719_cocreate_community_calendar_v1.sql` |
| CAL01-F04 | Date cells announce a semantic button but expose no semantic tap action because the actionable child is excluded. | `presentation/co_creation_calendar_month.dart` |

The abbreviated Dart paths above are under `apps/mobile/lib/features/co_creation/`.

Other relevant owners:

- `data/co_creation_calendar_gateway.dart`, `data/co_creation_rooms_gateway.dart` and `domain/co_creation_rooms.dart`: strict readers and canonical commands.
- `presentation/co_creation_meeting_screen.dart`: occurrence-specific attendance review and frozen-operation recovery.
- `application/people_signals.dart`, `application/people_attempt.dart` and `presentation/people_widgets.dart`: refresh hints, command recovery and actor access.
- `supabase/migrations/20261022110000_cocreate_numbered_groups.sql`: numbered-room authority.
- `supabase/migrations/20261022130000_cocreate_recruitment.sql`, `20261022224046_cocreate_meetings.sql` and `20261023002240_cocreate_versioned_meeting_readers.sql`: installed recruitment/meeting behavior and compatibility.
- `docs/development/cocreate-cal01-calendar.md`, the existing calendar widget/domain tests, SQL calendar tests and `scripts/lib/cocreate-calendar-verifier.mjs`: closest documentation and regression owners.

## 1. CAL01-F01 — Preserve useful calendar coverage across refresh

### Reproduction

Load a month with more than 25 authorized meetings, load the next page and select a date containing a later-page meeting. The timer calls `load()` with `append=false`; it discards the previous rows and fetches the first page only. The later meeting disappears until the person loads more again. Returning from review and actor-signal refresh use the same reset.

### Required behavior

- A routine refresh must revalidate enough fresh data to preserve the already loaded coverage and a usable selected-day agenda. Month/day selection and useful scroll position must continue to survive review navigation.
- Keep the server's bounded date windows, page limits, deterministic ordering and aggregate read. Use a bounded refresh strategy appropriate to the existing controller; document its request/row limit. Do not turn every timer tick into an unbounded full-month crawl.
- Retain the loaded extent or equivalent non-private pagination intent separately from the rows being invalidated. Begin a fresh authorized read sequence when the authority/cursor scope changes. Old signed cursors must not be treated as valid under new membership or window state.
- Reconcile fresh rows by canonical meeting identity. Changed availability, cancellations, removals and new rows before the previous frontier must be handled without duplicates, misleading empty dates or silently truncated completeness.
- If fresh coverage cannot be completed within a bounded pass, expose the honest loading/partial state and a practical continuation. A successful refresh must not silently strand the selected day on page two.
- Coalesce or serialize refresh triggers so the timer, metadata hints and detail return do not repeatedly abort useful work or let a late earlier generation overwrite a later one.
- Preserve immediate clearing and response fencing on actual account, realm, episode, policy, experiment or access loss. Do not retain stale private rows indefinitely to preserve visual continuity.

### Lifecycle regression while touching this controller

The calendar clears for every non-resumed lifecycle state, but its connected-hint listener can initiate another load without a lifecycle check. Add a regression for **inactive/hidden → connected hint → delayed result → resume**. Protected rows must remain cleared while the screen is inactive/hidden; a foreground revalidation may repopulate them. Apply the same active-view guard when initiating and adopting a response, consistent with existing route/lifecycle conventions.

This is a narrow refresh-state correction. Do not claim observed device leakage or assume that the SDK continues delivering normally while fully paused; check the pinned SDK behavior if needed.

### Acceptance tests

Use at least 27 meetings with a later-page selected date. After Load more, separately exercise the 20-second timer, a connected metadata hint and return from review. Assert that valid later meetings/markers return with fresh availability and the selected day remains useful. Include a changed/removed meeting, an authority loss during refresh, and the lifecycle sequence above. Existing genuinely-empty and partial-pagination states must remain distinguishable.

Also delay a Load more response, fire the timer or connected hint while the append is pending, then resolve the requests. Assert that loaded/selected-day coverage survives, stale results cannot overwrite newer state, and request counts remain bounded.

## 2. CAL01-F02 — Use canonical viewer eligibility in recruitment review

### Reproduction

The calendar computes newcomer eligibility separately from meeting seats. A General-only viewer at the maximum numbered-group memberships, or facing a full persistent chat, can see a meeting with spare meeting seats and `can_join=false`. Opening it uses `coRecruitmentRoute`; the existing review screen shows Join when `c.available || pending`. The card's `available` describes the meeting/card, not every viewer-specific admission condition.

### Required behavior

- Recruitment review must obtain fresh server-authoritative eligibility for the current actor and exact recruitment/meeting. An ineligible viewer must not receive an ordinary enabled Join merely because seats remain.
- Reuse canonical admission rules: current hub authority, appropriate block/account/moderation constraints, room exclusions, persistent-chat capacity, maximum numbered memberships, card lifecycle and meeting capacity. The atomic Join command remains the final authority when state races.
- Keep the distinction between meeting availability and the viewer's action. Use understandable existing/localized status wording. Do not label an ineligible viewer's meeting as full when the meeting has seats.
- Apply the corrected review behavior consistently to supported recruitment entry paths, including direct navigation and the calendar. A navigation boolean is a hint, not authorization. Do not replicate the eligibility policy in Dart.
- Choose the smallest compatible reader/helper change. Preserve all installed strict DTOs. If review needs additional fields, expose a deliberately versioned reader or separate minimal authorized projection and update its consumers/types; do not add keys to an existing closed response shape.
- Preserve immutable command intent and uncertain-delivery recovery. A pending frozen Join attempt must retain the ability to recover its exact outcome even if fresh eligibility is now false, the meeting filled, or the card changed. Ordinary new admission and recovery are different UI states.
- Current members continue to use the existing occurrence-specific attendance review. Keep the meeting-ID guard that prevents substituting a newer meeting.

### Acceptance tests

Cover both a full persistent chat with a non-full meeting and a viewer at the membership limit. Through the nonmember calendar route, verify that review presents no ordinary enabled Join and does not dispatch an admission command. Verify an eligible viewer can explicitly join using the canonical command. Retain last-seat conflict handling, and test pending-command recovery after eligibility changes without creating a new intent or duplicate RSVP.

Exercise eligibility loss between calendar and review (`can_join=true` in the calendar, then false on the fresh review), eligibility recovery on a subsequent fresh review, and a direct recruitment deep link with no calendar state. These cases must demonstrate a fresh authority read rather than reliance on a navigation flag.

Add SQL/real-HTTP coverage for any new eligibility projection, including forged actor/episode identifiers, visible-card history boundaries and direct command denial. A read must create neither membership nor attendance and must not acknowledge messages.

## 3. CAL01-F03 — Keep current-member review consistent with meeting authority

### Reproduction

A person joins a meeting, then either party blocks the other. The new calendar's blanket manager-account/block predicates omit the meeting. Attendance remains active, while `get_cocreate_current_meeting` still permits the current numbered member to review it through `require_cocreate_room_episode`.

### Required behavior

- Mirror the two existing authorization paths. A **current numbered-room member** entitled to canonical current-meeting review retains that calendar row. A **recruitment-card-only viewer** still requires the existing available-creator and symmetric-block conditions.
- Use current authorized membership as the distinction, not only `attending=true`. A member who declines must retain the same authorized review and attendance behavior as the canonical meeting panel.
- Keep common actor, hub, room, suppression, archival/lifecycle, exact-episode and date-window checks. An ended membership must not preserve the exception. A prior RSVP alone grants no new access.
- Preserve newcomer blocking and direct-command denial. The fix must not reveal blocked card-only meetings through rows, markers, counts or continuations.
- Evaluate temporary creator unavailability using the same canonical current-member boundary. Actual room/hub suppression or archival retains its existing precedence.
- Do not cancel attendance, remove chat membership, alter `block_user`, or change the canonical Join/attend/decline policy as a side effect of this read repair.

The smallest inspected repair is to move manager availability/block checks into the recruitment-card-only branch of row eligibility. Reconfirm current helpers before applying that approach; retain all unrelated query conditions.

### Acceptance tests

1. Join normally, then block the creator; verify the same meeting, exact current episode, attendance and occupancy remain reviewable in the calendar and current-meeting reader.
2. Exercise the reverse block direction.
3. Explicitly decline while blocked; occupancy decreases once, chat membership remains, exact retry is harmless, and authorized calendar review remains with `attending=false`.
4. Cover a current chat member who is not attending, including parity of `can_confirm` with the canonical attendance policy.
5. Preserve the existing blocked-newcomer test: no card-only calendar row; direct recruitment Join fails without membership or RSVP.
6. End/remove the current membership while blocked and prove the old episode no longer qualifies.
7. Cover temporary creator unavailability where canonical review remains allowed, plus actual suppression/access-loss denial.

Use real authenticated HTTP for the join/block/review/decline journey and focused SQL for the projection boundary. Administrative synthetic setup belongs only in the owned disposable database. Retain no-transcript/no-ACK checks.

## 4. CAL01-F04 — Make date buttons operable through accessibility semantics

The month widget places `InkWell(onTap: ...)` inside `ExcludeSemantics`, while its outer `Semantics(button: true, ...)` has no `onTap`.

- Expose the same date-selection action on the accessible date node, or use the framework's appropriate semantics composition without duplicate announcements.
- Preserve the full localized date, selection state and mixed availability markers in the accessible description.
- Add a widget test that enables semantics, finds a non-selected date, verifies the semantic tap action and invokes it. Assert selection and the agenda change. A normal pointer tap or label assertion alone is insufficient.
- Retain ordinary tapping, EN/IT localization, small-screen and large-text behavior. Use APIs supported by the repository's pinned Flutter version.

## 5. Compatibility, validation and documentation

### Forward migration discipline

CAL01 is merged. Add a new forward migration using the repository's current Supabase CLI workflow; do not edit the merged calendar migration. For a calendar-reader body correction, preserve its installed OID, signature/defaults, stability, fixed search path, ACL, envelope/row shape, cursor format and per-page authorization. A new version is needed only where a new response contract requires it.

Extend the existing populated upgrade rehearsal from an actual **CAL01-installed predecessor**. Warm the installed readers, apply the actual new migration source, and prove preservation of existing membership/attendance rows and unchanged installed-client contracts. A clean replay alone does not establish this. Regenerate and compare database types if the public API changes.

### Focused validation

Run the smallest complete set covering every changed area under current repository commands:

- Calendar domain/widget/route tests, including nonmember review, semantic activation and refreshed multi-page coverage.
- Changed SQL tests, real calendar/meeting HTTP checks and the populated compatibility rehearsal.
- Existing admission/attendance regressions, including last-seat concurrency and frozen retry recovery.
- Required formatting, analysis, generated types and affected tooling checks.

Reuse current verifier fixtures and commands rather than creating a second test framework. Update expectations only for the intended behavior changes. Keep required CI coverage intact; do not introduce an unrelated full-repository campaign or recurring jobs.

Update the feature README and `docs/development/cocreate-cal01-calendar.md` with refreshed-pagination behavior, viewer-specific recruitment review and the current-member blocking distinction. In particular, replace the blanket statement that blocked/unavailable creators are always omitted.

Inspect a small representative rendered set if visible layout/status changes: later-page selected date after refresh, ineligible recruitment review and the ordinary available/full/attending states. Label fictional widget renders accurately. Automated semantic-action evidence and actual TalkBack/VoiceOver device QA must be reported separately.

## 6. PR, merge and delivery

Open a focused implementation PR and merge automatically once the current required checks pass and the repository permits it. Refresh from latest `main` before merge. If a concrete consequential decision remains, describe that decision and complete independent work; do not request routine reconfirmation.

Use the **current** `AGENTS.md`, `.github/workflows/README.md` and `docs/development/staging-auto03-verified-policy.md`. The current policy separates validated source merge from hosted migration eligibility and replaces the old per-migration owner fingerprint comments. Do not repeat PR #309's obsolete approval template.

Keep release-policy/trusted-contract changes out of this product-fix PR. If current validation reports `review-required-for-hosted`, preserve and report that hosted hold; it does not by itself invalidate a permitted source merge. Actual failing source checks must be fixed. Hosted deployment follows the existing independently verified workflow and its authorization; this prompt adds no manual hosted migration, seeding, experiment activation, app installation or store release step.

The final handoff must include:

- The PR, final commit and merge status.
- What changed for each CAL01-F01 through CAL01-F04, with links to the regression evidence.
- Checks actually run and any remaining device/environment limitation.
- Installed-client compatibility and populated-upgrade evidence.
- Separate status for merged code, hosted migration eligibility/application, experiment activation, mock data and installed app.

After these corrections, the next product prompt remains optional places for meetings and usual group places. The later map should use those explicit associations to show a field's eligible groups/sessions above a coherent result list. This task does not implement either later phase.
