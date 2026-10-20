# Contact Android manual review

This procedure is for the founder and the local QA operator reviewing synthetic
representative contact (D), three-Group coordination, and member contact (M).
Representative audience/history and coordination policies 1 and 2 were approved
by the founder on 19 October 2026. Member policy 3 (origin lifetime and retained
history) remains **provisional** pending that separate decision in the
[current ledger](group-contact-parallel-handoff.md#decision-ledger). Completing
this review does not approve an unresolved product policy or authorize hosted
database changes or Play Store deployment.

The manual app uses `lib/main.dart` and real email OTP sign-in. An APK built from
`integration_test/group_contact_smoke_test.dart` or
`integration_test/member_contact_smoke_test.dart` runs an automated test with
injected initial identity; it is not a normal app for this manual procedure.
Those tests additionally prove exact canonical postconditions and deterministic
lost-response recovery. Keep their results separate from manual observations.

## Operator handoff before the founder starts

The operator supplies a short, local handoff sheet containing:

- The full tested Git commit, build time, normal-app APK path, local API/Mailpit
  addresses, owned device serial, and whether any required migrations are pending.
- The synthetic account **email addresses and display names**, each actor's role,
  exact Group names/IDs, the independent Project, and any already-created request
  or chat IDs needed to identify the right run. Never include passwords, OTPs,
  access/refresh tokens, service-role keys or complete fixture JSON.
- A fresh, unused scenario set. Do not reuse the accepted requests or ended
  conversations from an earlier test. Record the fixture run label; duplicate
  Group display names from old runs must not be mistaken for this run.
- Which companion automated checks have actually passed, failed, or remain
  blocked. A build, screenshot, or manual observation is not an automated pass.

At drafting, the current integrated source is
`eed96e5d` (including latest-main Activities Split Mode); native checkout merge
`5f34ab2dfeab8004ea0cec7a186f7d870aa99478` has identical tracked Mobile content.
This is a source checkpoint, not a qualification result. Reconcile any later main
or contact changes (including the corrected EN/IT read-only notice) and record
the new full SHA before building. Older `0912` APKs
were built from `1bcf6087`, and their fixture tokens expired on 19 October 2026 at
10:11 UTC. They cannot qualify the current source.

### Owned local environment

Only start work after C has explicitly returned both the runtime and shared SDK
slot. The D operator verifies ownership before every start/stop:

| Resource             | D allocation                                                           |
| -------------------- | ---------------------------------------------------------------------- |
| Checkout             | `C:/Users/utente/Documents/GitHub/planets.community-d-native-revision` |
| Podman connection    | `planets-d-qa-root`                                                    |
| Pipe                 | `npipe:////./pipe/podman-planets-d-qa`                                 |
| Supabase project     | `planets-community-d-qa`                                               |
| API / DB / Mailpit   | `55321` / `55322` / `55324`                                            |
| Android AVD / serial | `PLANETS_D_QA` / `emulator-5580`                                       |

The seven D containers are `supabase_{db,auth,inbucket,realtime,rest,storage,kong}`
with suffix `_planets-community-d-qa`. Each must have matching Supabase project
and native-checkout workdir labels. Keep the local `supabase/config.toml`
uncommitted. Start/stop only these verified containers and retain their volumes;
this procedure does not require a database reset. Do not change the default
Podman connection or global WSL settings. Do not operate C's ports/device, another
task's stack, hosted services, the Play Store app, or a physical phone.

If an agent launch is rejected by approval review, retain the exact rejection and
stop that attempt. The 19 October rejection happened before PowerShell execution
and returned only `blocked by policy`; it did not establish an Android failure.
The coordinating task may submit the same owned launch for review under the
human's explicit authorization. If automation remains unavailable, the human
can perform the reviewed operation locally; do not change executor, disguise the
command, or substitute another device to evade the agent restriction.

If review still blocks agent execution, the founder may launch this same owned
AVD in a local PowerShell terminal for manual interaction. The visible window is
needed for the human-operated procedure; the agent does not execute this as an
alternate route around a rejected launch:

```powershell
$manualEmulator='C:/Users/utente/AppData/Local/Android/Sdk/emulator/emulator.exe'
if (-not (Test-Path -LiteralPath $manualEmulator -PathType Leaf)) {
  throw 'Expected Android SDK emulator executable is missing.'
}
Start-Process -FilePath $manualEmulator -WindowStyle Normal -ArgumentList @(
  '-avd','PLANETS_D_QA','-port','5580',
  '-no-snapshot-load','-no-snapshot-save','-no-audio',
  '-gpu','swiftshader','-cores','2','-memory','2048'
)
```

Run this only after the operator verifies C's resource handoff, the exact D AVD,
unused D ports and no existing 5580 process. It does not change the AVD, global
engine, security settings or another task's device. A successful human launch is
not an automated test pass; record who launched it and each subsequent outcome.

The 20 October retry used process-local 2 GiB RAM after a 1.5 GiB cold boot left a
System UI ANR holding focus. Boot completion alone was insufficient: verify a
responsive launcher with visible icons and no ANR before starting the app. This
is a bounded test configuration, not a proven general fix for emulator crashes;
do not edit global WSL/engine settings or another task's AVD.

### Fresh fixtures and normal app

The operator runs preparation from the D checkout root, after verifying the
labels, ports and healthy local Auth. Set the explicit D connection and Mailpit
variables described in [D native QA](group-contact-mobile.md#reproduce-native-qa).
Use `PLANETS_DISPOSABLE_QA=1` and unique OS-temporary output filenames with the
existing `prepare_group_contact_smoke.mjs` and
`prepare_member_contact_smoke.mjs`. These create real local OTP accounts and
canonical Group relationships. They do not provide a founder login screen or
automatically produce the non-secret handoff roster above. The operator must
verify that roster against this run's local accounts and fixture IDs. Never copy
the private defines into a report, chat or this repository.

For the normal app, from the verified D checkout root:

```powershell
$env:CONTAINER_CONNECTION='planets-d-qa-root'
$env:DOCKER_HOST='npipe:////./pipe/podman-planets-d-qa'
npm run mobile:config:local
```

This writes ignored `apps/mobile/config/local.json` with the local public client
configuration. The operator verifies its API is D's loopback port 55321 without
printing its contents. Do not replace it with a D/M integration defines file.
With the emulator stopped, from `apps/mobile`:

```powershell
$env:GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false "-Dorg.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m"'
$env:JAVA_TOOL_OPTIONS='-XX:ActiveProcessorCount=2'
flutter gen-l10n
flutter build apk --debug --no-pub --target=lib/main.dart --dart-define-from-file=config/local.json --dart-define=ENABLE_DEMO_TOOLS=false
```

Preserve this APK under a distinct ignored name such as
`build/native-review/contact-manual.apk` before any integration build replaces
`app-debug.apk`. Record build exit status. Once the owned AVD launch is authorized
and complete, install this APK only on `emulator-5580`, set ADB reverse
`tcp:55321 tcp:55321`, and open PLANETS normally. Keep Gradle builds and emulator
execution serial on this host. Check boot completion, launcher responsiveness and
absence of System UI ANR before reviewing the app.

## Sign in and switch people through the real app

1. Open Profile or another sign-in entry. Choose email + OTP, enter the exact
   synthetic address from the handoff, and request a new code.
2. Open local Mailpit at `http://127.0.0.1:55324` on the host. Select the newest
   message addressed to that exact account. Type its six-digit code into PLANETS.
   Do not reuse the preparer's already-used code. Keep Mailpit/OTP out of evidence.
3. Verify the displayed fictional identity. Complete any genuine profile/policy
   gate presented by the current app; record unexpected gates instead of bypassing
   them or pasting a JWT. The fixture already creates profiles and accepts the
   current test policy bundle.
4. To change actor, use **Sign out** at the bottom of Profile or authenticated
   Settings. Sign in again with the next actor's email and a fresh Mailpit code.
   Confirm the identity before every consequential action. This manual flow uses
   normal session restoration; no provider override or service-role session.

Open the real Projects/Proposals list, then **Groups & organizations**. Search
for the exact fixture Group and check its handoff ID/context. Activities Split
Mode may change Home navigation; its fictional example listings are not contact
fixtures. Settings → Language selects English or Italiano.

## Narrow display, language and keyboard evidence

The operator first reads existing device settings and changes only this owned
AVD if necessary: `wm size` should override to `720x1600`, `wm density` to `360`
(320 logical dp wide), and `show_ime_with_hard_keyboard` to `1`. Record original
settings for cleanup. For manual large-text review, set the Android Font size
setting to 2.0 (the operator can set/read `settings system font_scale` on 5580).
Record this as **Android font setting 2.0**. Android may use nonlinear scaling;
it is not proof of the automated harness's exact linear Flutter 2x assertion.
Keep the automated actual-width/text-scaler result as separate required evidence.

Review each important screen in EN and IT, with actual loaded content. Scroll the
whole consent dialog and long notice; a clipped screenshot alone cannot prove
that the rest is reachable. Focus a multiline composer, type several fictional
lines, and keep the real keyboard visible while checking Send, recovery controls
and history. Capture full-device PNGs for visible keyboard pixels. Integration
Flutter PNGs capture the app surface only; their positive view-inset assertion
must not be described as a screenshot of the system keyboard.

## D: representative request and three-Group consent

Fixture roles: D Alice owns Garden; D Bob owns Workshop; D Carol is Workshop's
Co-organizer with no profile photo; D Dave owns Library. These are different
accounts from M Alice/Bob. The handoff supplies their exact emails and run IDs.

1. As Alice, open Workshop → **Contact group**. Choose Idea or Collaboration and
   explicitly choose Garden as the represented Group. Check the displayed human
   name and readership explanation. Type a fictional title/note. Opening/editing
   must not send. Capture EN/IT and the open keyboard, then send once.
2. Track the sent item in Messages → Requests. As Bob, check that the current
   destination manager can triage it. As Carol, open the same incoming request;
   opening the Accept dialog must not itself accept. Read the named counterpart
   and representation disclosure, cancel once, then explicitly accept.
3. As Alice and Carol, open the resulting Groups conversation and each send a
   clearly fictional human message. Check named human authors and the two-person
   audience. As Bob, the resolved request may show outcome metadata; the accepted
   note/body/chat must not become readable merely because he manages Workshop.
4. From conversation info, propose Group coordination with Library, using a new
   title and fresh summary. The old conversation history must not be copied into
   the invitation. As Dave, claim Library's representative seat, then decline
   this first proposal. Verify it remains declined and creates no chat.
5. Create a second proposal for Library. Dave claims; Alice confirms the named
   audience. Alice then uses **Change additional groups**, selects Library again
   and confirms replacement. The old selected seat and earlier consents must be
   cleared. Dave claims the new seat; Alice and Carol each confirm again.
6. As Dave, inspect the final consent dialog: exactly Alice/Garden,
   Carol/Workshop and Dave/Library. Before the final explicit confirmation there
   must be no coordination chat. Confirm, then open the fresh room: it starts
   with the fresh summary and no earlier messages. Dave cannot open the original
   Alice/Carol conversation. Send a new message and inspect EN/IT audience/history.
7. As Bob, use Workshop's People/role management to revoke Carol's delegated
   role. On Carol's next access, protected body/composer disappear; no fresh
   private content appears on retry. Use the retained known incoming-message
   Report action where offered. Submit a fictional report and record the receipt.
   Regrant only via a new normal invitation accepted by Carol; old admissions
   must not revive. Safe conversation Leave must not change Group membership.
8. On a still-authorized conversation, inspect Block and Close confirmations,
   cancel once, then execute the intended action on its designated test episode.
   Check the promised permitted history/read-only state. On the separate public
   Project, check that contact and **Ask to participate** remain independent;
   a pending participation request is not membership or contact acceptance.

The operator records canonical corroboration for exact audience/consents, no chat
before final consent, protected source denial, no revival, and exact report
target/receipt using the existing authenticated verifiers. UI absence alone is
not proof of a backend denial. Keep these checks attached to the same fixture run.

### Delivery recovery: do not manufacture a manual pass

If the normal app genuinely shows **Delivery is not confirmed**, keep that
attempt open, restore connectivity and use its delivery-status/recovery action.
Do not compose and submit a second request. Confirm one canonical request or
final confirmation, with the original frozen text/action, through the operator's
authenticated receipt check.

Switching airplane mode at an arbitrary instant does not establish that a command
committed before its response was lost. Normal UI has no deterministic
"drop successful reply" control. If this state does not occur, mark manual
recovery **not exercised**. The existing D automated driver must separately pass
the committed-request and final-consent lost-response cases, including its
same-action confirm/recover counters; do not describe a normal successful submit
as recovery evidence. Do not change clocks, tokens or cooldowns to induce it.

## M: three provisional origin-lifetime journeys

The M owner manages three separate Groups. M Alice and M Bob are ordinary
participants in each, without authority or photos. Review their actual names and
the origin Group on every sheet. These candidate lifetime rules are review
questions, not founder-approved policy.

1. **Garden / Close.** As Alice, open Garden → People → Bob → **Request
   conversation**. Inspect the shared-Group origin, two-person privacy and optional
   introduction. Editing sends nothing; submit once. As Bob, use Requests to
   explicitly accept after reading/canceling/reopening the consent dialog. Both
   people send a message. The conversation belongs to Private, not Groups; the
   owner must not gain access. Mute from Info: it must not mark unread messages
   read. As recipient, open the foreground conversation and scroll through the
   complete newest incoming card, including its timestamp/report action; unread
   should clear. Inspect Block confirmation, then block: retained permitted
   history is read-only and sending is unavailable. Explicitly unblock, then
   Close this episode. Its history remains read-only; record the canonical ended
   reason and rejected stale-send check separately.
2. **Tool Library / Leave.** Repeat a fresh request and explicit acceptance for
   the same pair through Tool Library, and exchange a message. Create/accept the
   third-origin conversation below before ending this one. Use conversation
   **Leave**, not **Leave group**. Verify this episode is read-only while the
   third-origin episode remains active. Group membership is unchanged.
3. **Laboratorio / context loss and rejoin.** After its independent request,
   acceptance and messages, Bob leaves this Group through its actual Group Leave
   action. With no surviving role in that Group, the episode ends. As owner,
   create a fresh ordinary participant invitation; Bob explicitly accepts through
   its normal invitation UI. People becomes available again, but the old chat
   stays read-only with no composer. Other shared Groups do not revive it. As
   Alice, report a known incoming historical Bob message; record the receipt and
   the operator's exact persisted message-target check.

Capture the pending/recovery state if actually encountered, acceptance, human
chat, mute, Block/Close/Leave dialogs, read-only history, rejoin without revival,
and historical-message report in EN and IT. M's deterministic lost-response and
canonical unread-zero/stale-send assertions still require its companion driver.

## Record the actual result and clean up

Use one row per scenario: source SHA; fixture label; actor/role; language;
device/width/font setting; expected result; actual result; PASS/FAIL/NOT RUN;
PNG/log path; canonical corroboration if required. Include an ANR, blank/loading
state, inaccessible action, overflow or driver disconnect as its actual failure.
Do not count intermediate frames, compilation, or partial journeys as completed
native qualification. A blocked launch is a preflight blocker, not a failed
product journey and not a pass.

The companion commands and complete acceptance details remain in
[D native QA](group-contact-mobile.md#reproduce-native-qa) and
[M native QA](member-contact-mobile-native.md). Run their distinct prebuilt APKs
serially against fresh fixtures only after normal-app manual work is finished or
use separate fresh fixture sets. Never hot-restart an active integration driver.

Archive sanitized screenshots/logs outside the checkout with source, outcome and
scope recorded; exclude Mailpit screens, OTPs, private defines and instrumented
APKs. Stop only the verified D containers and `emulator-5580`, retain volumes,
verify no D listeners/device remain, and explicitly return the shared slot.
Remove only the exact owned private defines/instrumented APKs after QA; never
delete a shared cache or another task's artifacts. This Android local review does
not establish iOS, physical-device, hosted-provider or production readiness.
