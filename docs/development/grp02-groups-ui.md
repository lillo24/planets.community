# GRP02 mobile and staff integration

The canonical GRP01 contract remains in [persistent-groups.md](persistent-groups.md).
GRP02 adds mobile Explore directory, public profile, My groups and manager editor,
plus genuine reporting and existing web staff case context/Hide/Restore.

## Navigation and action boundaries

Explore's compact Groups & organizations entry sits below the existing Project/
Tavolo switcher. The same Browse destination is reachable with either right-tab
preference. No bottom branch or preference is added. Pushed directory/detail pages
retain their underlying filters and position; direct entry has a public Close
fallback. Profile also offers My groups. See the mobile feature README for routes.

Public reads are anonymous. Completed personal profiles manage/report without a
photo requirement. Management reads and reporting bypass policy acknowledgement;
each group mutation independently checks account and current bundle. Existing
profile editing keeps its existing acknowledgement boundary. Auth/setup cancel
destinations never repeat the protected continuation. Report routes encode the
group UUID in the path, avoiding loss of a transient navigation extra through OTP.
Sign-in opens the report form; only its explicit Submit creates a report.

Group content is full replacement. Unicode scalar limits match PostgreSQL
character counts; POSIX Unicode whitespace is trimmed without Dart's additional
BOM trimming. Publication requires saved valid content and is separate from Save.
A publication failure leaves the saved draft and stable UUID intact. Published
saves update public content immediately. Suppression is displayed privately and
does not become a manager-controlled state.

The shared departure coordinator guards Close, system Back and route changes.
The feature owns its Save/Discard/Stay dialog and confirmation messages; it does
not reuse Project receipts. Pending ambiguous commands freeze the editor until
exact retry/recovery. PT409 keeps local input, with explicit reload-and-reconcile
or reload-and-discard. Recovery lives only for the editor's lifetime; after process
restart use My groups to locate accepted drafts. Account changes clear private
forms, pending commands and loaded owner rows and reject late responses.

## Staff controls

Group reports load `get_moderation_case_group` only after active staff access is
established on the server. The protected case view shows current content, current
and report-time versions, content-changed status, publication/suppression/public
eligibility, current manager/original actor and latest private suppression action.
Changed content is explicitly described as current, not a historical snapshot.

Hide/Restore call `set_group_directory_suppression` with a reviewed current version,
fresh request UUID and private 10–4,000 Unicode-character reason. The client freezes
intent for ambiguous retries; staff repeat the exact call, never owner recovery.
Every server action revalidates staff access and backend authority. Acceptance and
stale conflicts reload context. Review state remains independent. Restore cannot
publish a draft/archive or repair absent manager authority.

## Repeatable local journey

Use a confirmed disposable Supabase stack with every committed migration and the
repository-scoped CLI on PATH. The fixture helper refuses non-loopback endpoints
and requires `PLANETS_DISPOSABLE_QA=1`. Set `MAILPIT_URL` for nonstandard ports.
Run the helper from that stack's working directory, passing its absolute script
path and an OS-temporary defines path outside the checkout:

```powershell
$env:PLANETS_DISPOSABLE_QA = '1'
node <checkout>/apps/mobile/integration_test/prepare_groups_smoke.mjs $env:TEMP/grp02-smoke-defines.json
adb -s emulator-5554 reverse tcp:<local-api-port> tcp:<local-api-port>
# From apps/mobile:
flutter drive --no-pub -d emulator-5554 --driver=test_driver/groups_screenshots.dart --target=integration_test/groups_smoke_test.dart --dart-define-from-file=$env:TEMP/grp02-smoke-defines.json
```

The helper creates two fictional verified local OTP accounts with completed,
photo-free profiles and real policy acknowledgements. The journey uses real
PostgREST: browse, create, deliberately lose an accepted create reply, recover
without duplication, publish, view the public profile, switch to the second
verified account, and explicitly submit a genuine group report. The harness supplies
token-bound identities without a persistent GoTrue session and reads actual policy
acknowledgements through a fixture-only RPC adapter; it never assumes acceptance.
Production continues to validate the current GoTrue session at the policy boundary.
Driver screenshots
are stored under `apps/mobile/build/groups-screenshots`. Temporary session defines
contain local capabilities: keep them out of Git/logs and remove after QA.

Founder device `48091FDAS0041A` may be used only with an explicitly reviewed local
or shared configuration. For local QA, reverse the selected API port on that device
and replace the emulator ID in the command. Physical Android/TalkBack and iOS
gestures require their actual devices/host; emulator screenshots do not prove them.

## Hosted rollout and later stages

Code merge performs no hosted deployment. Before distributing this client:

1. Inspect the intended shared environment's migration history and apply pending
   reviewed migrations in order through the normal separately authorized workflow,
   including both GRP01 migrations and their predecessors.
2. Verify generated API/type parity, explicit grants and public/private boundaries.
   Missing group RPCs are a setup error, never an empty directory.
3. Smoke public list/detail and unavailable states; owner creation/recovery/edit/
   lifecycle; another account's report; active staff context/Hide/Restore.
4. Distribute only after those checks and the normal release gates.

GRP03 may build on these merged group identities and current authority. Membership,
invitations/delegation/transfer, group-owned Projects/chat, logos/media, verification,
legal registry imports and conversion remain outside GRP02. Hosted migration
activation remains an operational prerequisite for any shared-environment GRP03 QA.
