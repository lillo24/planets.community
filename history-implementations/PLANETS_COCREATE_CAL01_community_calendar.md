# PLANETS — COCREATE-CAL01: community meeting calendar

**Prepared:** 23 October 2026 (Europe/Rome).  
**Status:** Ready for implementation. This file is an executable Codex handoff.  
**Repository inspected:** `lillo24/planets.community`, `main` at `b9a8603fb9b28e07d07c36bf855d60959454de19`.

## Assignment

Implement a useful calendar for each **Find People community/topic hub**, such as Valorant or Lupus in Fabula. It collects the upcoming dated meetings of that community's numbered groups, shows meeting availability, and opens the existing review/join/attendance flow.

Start from current `main`, inspect current code and applicable `AGENTS.md`, implement the scoped feature, validate it, open a focused PR, and merge according to the repository's current workflow when its gates pass. The inspected SHA is evidence, not a required checkout target. Preserve later fixes and concurrent work.

This is the first implementation in a three-step product direction:

1. **This prompt:** community calendar using existing meeting and admission rules.
2. **Next prompt:** explicit optional places for meetings and, where authority permits, usual places for groups.
3. **Next prompt:** compact rectangular map above results, showing eligible communities/activities and opening a place's associated groups and sessions.

Steps 2 and 3 are roadmap context, not permission to silently add venue ownership, publish private schedules, or implement another map renderer in this PR. The calendar does not depend on those steps or on the external Activities/Sports queue.

## User intent and interpretation

The founder likes a clean discovery layout with a rectangular map at the top and activities below. They also want to tap a football field and discover the groups playing there and whether there are available sessions. A community need not have a permanent physical location.

For this first step, the named Valorant/Lupus examples identify the **co-creation community hubs** already used in COMM01/FILL01 mock fixtures. Treat “calendar for the group” as a calendar for that named community, collecting its numbered groups' meetings. Do not confuse these communities with registered Groups, private discussion rooms, native Proposals/Tavoli, or imported activities.

“Pending proposals” here means upcoming dated meeting invitations the viewer is entitled to see. It does not mean private drafts, pending membership requests, or proposals to activate a new community. Unscheduled invitations must not receive invented calendar dates.

## External context

**No external attachment or Google Doc is required.** The screenshot's relevant design intent is fully described above; it is not a pixel-perfect implementation asset. The uploaded volunteer-law PDFs are unrelated. This prompt and current repository source contain the required behavior.

If execution encounters another genuinely required external input, report precisely what is missing and finish the independent work. Never infer missing credentials, hosted deployment state, or unseen design decisions.

## Verified foundation and areas to inspect

Current source already implements the relevant domain:

- `apps/mobile/lib/features/co_creation/README.md` explicitly separates Find People from native Projects, Tavoli, registered Groups and imported events.
- `docs/development/cocreate-fill01.md` defines communities, numbered chats, meetings, attendance, recruitment, compatibility and mock fixtures.
- `docs/development/cocreate-experimental-contract.md`, `cocreate-hubs.md` and `cocreate-recruitment.md` describe admission, history and visibility.
- `supabase/migrations/20261022224046_cocreate_meetings.sql` contains canonical meeting records, attendance and commands.
- `supabase/migrations/20261023002240_cocreate_versioned_meeting_readers.sql` preserves installed-client contracts while adding scheduled-card readers.
- `apps/mobile/lib/features/co_creation/domain/co_creation_rooms.dart` and `data/co_creation_rooms_gateway.dart` own strict projections and canonical calls.
- `presentation/co_creation_hubs_screen.dart`, `co_creation_numbered_screen.dart`, `co_creation_meeting_screen.dart` and `co_creation_recruitment_screen.dart` own the current mobile entry/review/action flows.
- `application/people_attempt.dart`, `application/people_signals.dart` and `presentation/people_widgets.dart` own immutable retries, actor-scoped refresh and access handling.
- `scripts/verify-local-cocreate-community-meetings.mjs`, `scripts/verify-local-cocreate-upgrade.mjs`, existing SQL/mobile tests and mock fixtures are the closest validation patterns.

These are inspected ownership pointers, not instructions to place every change in an existing large file. Extract a focused calendar module where appropriate.

Some runbook passages record old branch/PR checkpoints. Presence on inspected `main` establishes merged code; it does not establish hosted migration application, server activation, mock seeding or the installed phone version.

## Existing behavior to preserve

- A numbered group is a persistent chat; attendance belongs to a particular meeting.
- Meeting capacity is **2–50, including the creator**. Scheduling uses the existing persistent-chat ceiling of 50. Meeting occupancy and chat occupancy are different.
- Only the creator initially attends each new meeting. Existing chat members confirm attendance explicitly.
- Recruitment Join atomically reserves a meeting place and obtains the authorized numbered-chat episode. Declining a meeting frees attendance without leaving the chat.
- Meeting time is an immutable UTC instant, entered/displayed in device-local time with its offset. Reuse this policy; do not silently switch to a fixed Europe/Rome display zone.
- There is currently **one future non-cancelled meeting per numbered chat**. Preserve it. Several numbered groups can still supply several events to one community calendar.
- Current creator authority, canonical locking, receipts, blocking, moderation, account eligibility and experiment gates remain authoritative.
- A recruitment card expires at meeting start or the existing seven-day lifetime, whichever comes first. Reposting creates another card for the same meeting and retracts the previous card.
- A future meeting can outlive its recruitment card. An eligible existing chat member may still confirm attendance even when newcomer recruitment has expired.
- Full, past or cancelled meetings do not delete the persistent chat.

Do not add automatic recurrence, multiple future meetings per numbered chat, waitlists, bookings, payments, a new participation state machine or automatic group enrollment.

## 1. Canonical calendar read

Add a bounded, versioned calendar projection for one hub and a selected date window. Choose the exact API/type names after inspecting current conventions.

### Audience and privacy

This is an **authorized community view**, not a new public schedule directory.

- A row may be returned only when the caller is currently entitled to the equivalent meeting information through an admitted numbered-room episode or a recruitment card visible under the existing General episode/history rules.
- General membership alone must not reveal every private numbered-group meeting. Do not expose cards outside the caller's authorized history frontier.
- Apply current actor, hub, episode, realm, experiment, policy, blocking, suppression and lifecycle checks on every fresh read. Reuse canonical helpers instead of creating weaker parallel checks.
- Guests and nonmembers must use the existing deliberate community admission path. A calendar button or page load must never join a community, numbered group or meeting automatically.
- Return only the minimal allowed meeting summary, viewer attendance/action state and identifiers needed for existing navigation. No attendee roster, private messages, manager identity or unrelated episode metadata should leak through aggregation.
- Do not fetch chat bodies or advance message-read ACK/unread state while showing a calendar.
- Do not turn former-membership history access into fresh attendance authority.

If current audience rules prevent a row from appearing, omit it consistently without exposing its existence through counts or day markers. Preserve the boundary rather than widening visibility to make the calendar look populated.

### Query and identity

- Read canonical meetings; do not scrape the rendered General feed, maintain duplicate event records, or issue one network request per group.
- Deduplicate by canonical **meeting ID**. Reposts are recruitment changes, not additional calendar events.
- Prefer a current eligible recruitment card when one exists. A retracted card must not suppress a newer eligible card or become a route around its access rules.
- Keep meeting seat availability, the viewer's attendance and the viewer's current ability to join/confirm distinct. Reuse server decisions for action eligibility.
- Bound date windows and page sizes on the server, use deterministic chronological ordering with an ID tie-breaker, and bind cursors to the hub/window/filters and appropriate authority scope.
- Support complete pagination. Date markers and any totals must be accurate for the authorized result set; if based on loaded rows, never present them as complete.
- Convert local calendar boundaries to UTC correctly. Do not obtain the next local day by blindly adding 24 UTC hours across daylight-saving changes.
- Add appropriate indexes only where the actual query needs them. Inspect representative query plans with bounded synthetic data.
- Use additive migrations and new/versioned projections. Do not alter closed installed-client DTO shapes, rewrite applied migrations or relax grants to solve an access error.
- Update generated database types and all affected consumers.

## 2. Mobile experience

Add an obvious **Calendar / Calendario** entry on the named community's page, near its numbered-group activities. Keep the ordinary General and group navigation understandable.

The default experience should be:

1. A compact month view with previous/next navigation and a Today action.
2. Selecting a day shows a readable chronological agenda below it.
3. An upcoming agenda remains useful when the selected day is empty and provides a practical large-text/small-screen presentation.
4. Each meeting row shows its group number/name as currently available, local time, allowed meeting occupancy/availability and the viewer's relevant status.
5. Tapping a row opens the appropriate existing meeting or recruitment review. Explicit confirmation then uses the existing canonical command.

Use the app's existing visual system. Avoid dense calendar cells, multiple nested panels, long explanatory paragraphs and visible implementation terminology.

### Availability presentation

Use the requested green/red distinction together with words and accessible semantics:

| Meaning | Suggested presentation | Action |
| --- | --- | --- |
| Meeting has places and viewer can use the canonical joining flow | Green + “Places available” / “Posti disponibili” | Open review; join/confirm explicitly |
| Meeting is full | Red or accessible subdued red + “Full” / “Completo” | Still selectable for details |
| Viewer already attends | “You're attending” / “Parteciperai” | Existing attendance review/decline |
| Meeting has places but newcomer recruitment is unavailable | Neutral explanatory status | No misleading enabled Join |
| Meeting becomes cancelled, past or unavailable while displayed | Neutral lifecycle state | Refresh/review according to existing authority |

Use **meeting** occupancy, never numbered-chat membership, registered-group size, native Project social headcount, or a color inferred from client-side guesses. Being full must not prevent an existing attendee from reviewing their own attendance.

A day containing both available and full sessions must not be labeled wholly full. Use compact distinguishable markers and let the agenda explain the individual sessions. Unknown/unavailable status is not a full meeting.

Keep undated recruitment separate from dated cells, using an existing appropriate list/link if useful. Community-activation proposals stay in their own existing flow.

### State and navigation

- Opening and returning from details preserves the selected month/day and useful scroll position.
- Refresh canonical state after Join, confirm, decline, cancellation or repost. Handle a last-seat conflict without claiming success or duplicating attendance.
- Reuse immutable command intent and uncertain-delivery recovery; calendar navigation must not create new retry semantics.
- Fence late responses when account, backend realm, hub, episode, month, policy or experiment state changes.
- Clear protected rows immediately when current access is lost. Revalidate on resume/reconnect using existing lifecycle patterns; do not add a separate transcript subscription or persistent private cache.
- Distinguish loading, a genuinely empty date, pagination, unavailable access and backend failure. Do not substitute mock rows or an empty-success state for an error.
- Preserve experiment and Mock isolation. This change does not globally enable Find People or alter the Activities Split mutual-exclusion rules.

## 3. Validation and review evidence

Use current repository commands and the smallest complete meaningful checks for the changed areas. Expected coverage includes:

- Real local database/HTTP checks for the new read contract, grants, cross-hub isolation, exact episode/history rules and the absence of hidden-row count leaks.
- Existing community/meeting/recruitment regression checks, including two actors competing for the last place; no overbooking or duplicate membership.
- Meeting 4/7 while chat membership differs; full meeting; already-attending viewer; decline reopening a place; expired recruitment with a still-future meeting; current eligible repost; duplicate-card deduplication.
- Same day with meetings from two numbered groups; local midnight, month/year boundaries and daylight-saving transitions; complete bounded pagination and invalid/mismatched cursor handling.
- Suppression, blocking, account/realm replacement, stale episodes, experiment OFF and late responses. Calendar reads must not change message ACK/unread state.
- Native Flutter route/widget/state checks and rendered inspection at 320/360dp, 2× text, IT/EN and relevant light/dark states.

Reuse the existing mock persona/realm setup and canonical commands for deterministic Valorant 4/7 and full Lupus examples. Add only the fixtures needed for the missing edge cases. Preserve tester edits and fixture idempotency; no normal production seed pollution.

Capture and inspect a small set of actual rendered screenshots: populated month and agenda, full session, already attending, empty day, large text and error/access state. If the current UI audit conventions apply, reuse their stable issue IDs and avoid duplicate findings. Do not call mock screenshots live-data proof or emulator captures physical-device QA.

Update the feature README and closest runbook with the audience, date-window, pagination and availability rules. Record actual tests, schema compatibility and remaining environment limitations. Do not add an unrelated full repository test campaign or claim checks that were not run.

## Delivery and authority

Follow current `AGENTS.md` and required CI/review gates. Use one focused implementation branch and PR; merge automatically when the applicable gates permit it. Do not leave a green PR open merely because optional phone review has not happened, and do not bypass a required owner/migration review.

Local implementation, disposable validation data, screenshots, normal PR workflow and current authorized staging automation are within scope. Production activation, store submission, manual hosted data changes, billing and destructive shared-data operations remain governed by their existing authorization rules.

The final handoff must report:

- Calendar behavior and where to open it.
- PR and merge status.
- Database/API/mobile changes and actual validation.
- Screenshot evidence and any remaining native-device limits.
- Separately: merged code, hosted migrations, experiment activation, mock data and installed app state.
- Any concrete unresolved issue; never report the feature live solely because its PR merged.

## Next-step design notes: places and the map

Carry these requirements into the next prompt without implementing them incidentally here:

- A community can exist without a physical pin. An online or roaming group retains its list and calendar.
- A place is independent from a community and a meeting. One field may host multiple groups; a group's next session may happen elsewhere.
- “This session meets here” and “this group usually meets here” require explicit associations to a stable place identity. Neither matching locality text nor identical/nearby coordinates establishes that relationship.
- A numbered-group creator already has meeting authority. A whole topic hub has no implied venue owner; do not let an arbitrary member assign one permanent location to everyone. A hub can instead show places used by its eligible groups/meetings.
- Public venue/schedule discovery needs deliberate publication or an audience-scoped projection. Do not backfill it from private chat, existing protected meeting times or protected native exact coordinates.
- Selecting a field should show associated PLANETS groups and upcoming sessions the viewer may see, with actual availability. It must not imply live attendance, exclusive use, a reserved pitch, every real-world group or a booking system.
- Reuse existing map renderer, filters, clustering, explicit Search this area, budgets, basemap cache and attribution. The requested layout is a compact map **above** a coherent result list, with marker/card selection linked.
- Coordinate shared map extraction with `history-implementations/PLANETS_ACTIVITIES_SPORTS_2026-10-23/008_ACTMAP01_activities_map_and_list_sync.md`. That queue covers imported external activities/places; it does not prove group-place relationships or grant native joining for an external event.
- Do not add a paid provider, quota increase, new GPS prompt, public OSM/Nominatim fallback or analytics activation as part of this design.

