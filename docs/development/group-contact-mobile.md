# D02 contact client and native verification

Status: **provisional review only**, with no founder approval reference. The
contract and backend are documented in `group-contact-contract.md` and
`group-contact-backend.md`.

## Context and ownership

Public group and attributed Project details expose a labelled Contact group
sheet. Supported purposes are Idea and Collaboration. The sending human chooses
an eligible represented group explicitly. The recipient disclosure explains that
the sender is the current authenticated person, whose minimal self-name projection
is displayed alongside their chosen group, and that
current destination managers can triage the note; only the submitting human and
the accepting representative enter the resulting conversation. Participation
continues through its existing independent group/Project action.

Routes are `/groups/<uuid>/contact?project=<public-project-uuid>&purpose=<purpose>`,
`/messages/requests/group-contact/<uuid>`,
`/messages/chats/group-contact/<uuid>` and its `/info` route. Sign-in, profile and
policy gates retain only a sanitized destination and never execute a contact
command. The optional onboarding group offer recognizes D continuations.

Central Messages uses Requests v2, scoped Chats v6 and unread/acknowledge v2. The
new request kind is `group_contact_request`, and `group_contact_chat` belongs to
Groups with neutral group imagery. Lists preserve independent scope windows,
lookahead, compound cursor and identity refresh epochs. D participants are omitted
from personal photo batching. Resolved target managers have a minimal outcome and
no note, acceptor identity or chat route. Exact detail does not trust list cache.

The feature folder README maps implementation owners. Attempts freeze exact
submitted text and context, including whitespace, until a definitive rejection or
receipt. Network/parse failure is ambiguous. Check delivery status remains
available after role loss and returns metadata only; it never reopens body access.
Completed operations whose original screen was disposed can also recover their
receipt. No private note/action token is persisted or logged. Closing a composer
does not withdraw a submitted request. A withdrawal is a separate command.

## Access invalidation

The D02 additive migration augments authorized public references with current
kind/title and introduces `group.contact_access_changed` on the existing own
account topic. Both D events have only `profile_id` plus the pinned Realtime
transport's delivery ID. Access hints may reach a former admission's still-open
socket solely to clear displayed content. They include no affected request/chat,
human activity, body or name. Delegate/seat, group/accountable Creator, closed-room
and profile/Auth identity changes invalidate displayed data. Regrant retains the
old episode's denial. Own receipt/report/exit permission is independently checked.

The client clears D bodies/list rows/badges before rereading after an access hint.
A failed reread is an explicit failure, not an empty conversation or authorization
verdict. The chat keeps known incoming IDs for the narrow protected Report action.
Valid read-only admissions retain permitted history and info/exit controls.

`has_own_group_contact_admission` returns only whether the verified actor still
has their own non-left seat, irrespective of live representation. Info can offer
safe leave after role loss without reading body or audience. Another manager's
group role cannot produce an own seat; identity mismatch is rejected. It is an
additive metadata endpoint, not a replacement authorization decision for reads.

## Reproduce native QA

Use an owned emulator and an explicitly disposable local Supabase project. Never
reset a shared project or install over the Play app on a physical phone. Fixtures
are genuine OTP sessions for three synthetic `@planets.invalid` accounts, two
public groups, a Co-organizer grant and a separate public Project. The Co-organizer
has no photo; existing Project join retains its own photo requirement.

From the repository root, with its `node_modules/.bin` on PATH and the correct
local container engine/loopback Mailpit configured:

```powershell
$env:PLANETS_DISPOSABLE_QA='1'
node apps/mobile/integration_test/prepare_group_contact_smoke.mjs "$env:TEMP/planets-d02-defines.json"
adb -s emulator-5580 reverse tcp:55321 tcp:55321
adb -s emulator-5580 shell wm size 720x1600
adb -s emulator-5580 shell wm density 360
cd apps/mobile
flutter drive -d emulator-5580 --driver=test_driver/group_contact_screenshots.dart --target=integration_test/group_contact_smoke_test.dart --dart-define-from-file="$env:TEMP/planets-d02-defines.json"
```

The private compile-time file lives outside the checkout and must be removed after
QA. No tokens appear in test logs or committed evidence. Default local ports are
543xx; the task-owned project uses 553xx as described in the backend document.
Adjust only the owned emulator's reverse port. The driver saves native PNGs under
ignored `apps/mobile/build/group-contact-screenshots`; inspect them before claiming
visual QA. This is a bounded journey, not a substitute for physical-device or iOS
release validation. The final integration evidence records actual successful runs
and any limitations.

Native QA also exercises the shared moderation category selector at narrow width.
Long EN/IT category labels wrap within the bounded field and menu at enlarged text.
The chat checks foreground route and laid-out scroll dimensions before following
newest history, including when an info route covers its still-mounted parent.

## Stage validation status

The scoped Mobile regression run passed 451 tests before the final sender/layout
additions; the final focused contact/moderation run passed 23 tests. The additive
access/sender/exit/expiry SQL suite passed 20 assertions, and the inherited real
OTP/PostgREST verifier passed 62 checks with the D02 schema. Web generated types
passed typechecking. D02 required CI subsequently passed on `a1bf9f9`; D03 and
the cumulative runtime/schema checks also passed. See the
[final integration evidence](group-contact-integration-evidence.md) for exact heads
and the remaining whole native journey blocker.

Native debugging exercised submission, exact lost-response recovery, manager
triage, acceptance, human messages, audience, revocation and protected reporting.
It found a covered-parent scroll callback and a report selector overflow; both
were repaired. A clean whole-journey native rerun is still pending at this stage
snapshot; partial screenshots do not qualify the complete journey. The final D
integration evidence must replace this status with actual results and limits.
