# PI05 — Integration QA and demo data

PI05 extends the existing local demo world and runs its canonical invitation
assertions in the database gate. PI04 is the merged dependency: [PR #138](https://github.com/lillo24/planets.community/pull/138),
merge/base `fcd2236dc620f7b768d4aec01fc5f07ee9b61d76`.
Repository completion and public release verification are separate outcomes.

## Implemented scope

The original three photo-equipped personas, nine realistic activities/listings,
licensed covers, ordinary request states and mural chat remain. Dario is an
admitted photo-free participant; Elena is an unjoined photo-free recipient.
Four focused Proposal/Tavolo activities cover active, full and ended states.
The existing concert/reading group retain ended/paused purposes. The
[demo guide](../development/demo-data.md) owns exact titles, scenarios and safe
link retrieval.

Authenticated actor APIs create/retrieve/replace/revoke capabilities, admit,
leave/remove/re-enter, create offered requests and send chat. Stable action IDs
bind account, Project, generation and deliberate episode. Ignored local journals
retain raw capabilities for explicit rehearsal; verifiers and CI output omit
them. Verification inspects canonical state without repairing domain state.

`demo:check:local` proves interrupted committed admission recovery, unchanged
seed stability, lifecycle/photo gates, stale receipt non-restoration and fresh
explicit restoration. Snapshots compare IDs/relationships across receipts,
generations, memberships, request offers/messages, chats, notifications and
commitments; time refreshes/session state are excluded. The check runs after
clean pgTAP and previous mutation verifiers in local/hosted database gates.

The full demo run exposed a pre-existing projector defect: delegated acceptance,
rejection and removal emitted the real manager actor, while the shared resolver
assumed the Creator. Migration `20261005111132` validates the canonical recorded
resolution/removal actor, including a subsequently revoked delegate. Recipients,
RLS and worker grants retain their existing contracts. Nine pgTAP assertions
exercise both kinds through canonical transitions, in-app/push projection,
idempotency, forged actor rejection and private resolver grants.

The production Next rehearsal reuses the PI04 host harness. A separate debug
Flutter entry point enables driver interaction and a bounded internal route
launcher; normal production bootstrap/repositories remain in use. No session
or admission is injected. This is local route tooling, not OS delivery proof.

## Owned local reproduction

Use a separate checkout with free ports. Temporarily change the selected
`supabase/config.toml` project ID to `planets-community-pi05`, ports 54320–54329
to 58920–58929 and Edge inspector to 8785. Retain the exact original config.
Never apply this setup/reset to another running/shared stack.

```powershell
npm ci
npm run restore:mobile
npm run db:start
$env:MAILPIT_URL = 'http://127.0.0.1:58924'
npm run check:db
npm run web:config:local
npm run build --workspace @planets/web
$env:PI05_LOCAL_REHEARSAL = '1'
$env:PATH = "$((Get-Location).Path)/node_modules/.bin;$env:PATH"
node apps/web/test-support/pi05-browser-fixture.ts
```

Open `http://127.0.0.1:3174` in the actual browser. Its links launch the seeded
special previews without printing tokens. `pi05-browser-proposal@planets.invalid`
is left fresh for real OTP/profile completion; `pi05-browser-tavolo@planets.invalid`
and `pi05-mobile@planets.invalid` have only ready non-photo basic profiles.
The `/__pi05/otp/proposal`, `/tavolo`, `/mobile` helper pages expose only the
corresponding latest local synthetic OTP; consume it privately, never capture,
log or publish it. Keep fixture files/configurations out of artifacts.

Independent safe domain reads and explicitly requested mutations are available
in another terminal with the same local opt-in:

```powershell
node apps/web/test-support/pi05-browser-fixture.ts --status
node apps/web/test-support/pi05-browser-fixture.ts --revoke=proposal
node apps/web/test-support/pi05-browser-fixture.ts --leave=proposal
node apps/web/test-support/pi05-browser-fixture.ts --remove=tavolo
node apps/web/test-support/pi05-browser-fixture.ts --mobile-config
```

These operate only on named PI05 identities/Projects through authenticated APIs.
Revocation/departure intentionally changes the demo baseline. `--reuse` restarts
the fixture with its ignored original links for testing an unavailable preview;
it never silently regenerates. Reset/rebuild only the owned disposable stack
before repeating a fresh onboarding sequence.

The host probe uses the nonsecret Proposal UUID from independent status/fixture
reads with `PI05_PROBE_ORIGIN=http://127.0.0.1:3174` and
`PI05_PROBE_PROPOSAL_ID=<fixture UUID>`. Run
`node apps/web/test-support/pi04-host-probe.ts`.
Stop/restart the fixture with `--reuse --enabled-associations` for synthetic
enabled-association checks. These synthetic identifiers match no release build.
Pass `--enabled-associations` to the probe as well so expected response status
and cache policy match the selected fixture mode.

For Android emulator GUI rehearsal, forward only the owned API port and run
the dedicated debug target:

```powershell
adb reverse tcp:58921 tcp:58921
cd apps/mobile
flutter run -d emulator-5554 --target test_support/pi05_driver.dart --dart-define-from-file=config/local.json
```

Sign in through the real mobile email/code UI with each browser identity after
web Join and link revocation. Open own participation, Project detail and chat;
read/send a synthetic message. Repeat for Proposal and Tavolo. For explicit
mobile Join, sign in as the ready `pi05-mobile` identity before revocation and
invoke `ext.planets.pi05.openInvitation` with only `kind=proposal` or `tavolo`
through the debug VM service. Preview and click the normal explicit Join action;
check independent canonical counts. The extension opens only the ignored
configured internal route and cannot accept or manufacture authentication.
Later use ordinary Repair Café joining to observe the profile-photo requirement.
This route launch cannot be reported as HTTPS OS dispatch.

## Journey evidence, 5 October 2026

Chrome 154 exercised production Next 16.3.4 through the loopback harness.
Flutter 3.47.2/Dart 3.13.2 ran the debug driver on Android 17/API 37,
emulator-5554. Results below identify the observed boundary.

| Case/boundary                                                           | Expected versus observed result                                                                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Canonical demo, both kinds and photo states                             | **Passed** clean `check:db`: direct origins, generations/secret destruction, retained offers/chat, zero commitments, private RLS and photo absence                                                                                                                                                        |
| Partial run / stability / restoration                                   | **Passed** clean interruption after committed admission, non-repairing verify failure/snapshot, recovered seed, unchanged seed comparisons and fresh deliberate restoration; stale receipt never re-admitted                                                                                              |
| Canonical security/concurrency                                          | **Passed** all existing local verifiers and 3,386 pgTAP assertions: both capacity modes, dual roles, blocking against current managers, ordinary acceptance/authority, privacy and leave/removal; no assertions weakened                                                                                  |
| Browser Proposal, fresh incomplete photo-free account                   | **Passed** signed-out preview → OTP → basic name-only profile → explicit Join → token-free confirmation. Independent state showed zero memberships/photos after profile completion and one episode after Join                                                                                             |
| Browser Tavolo, existing ready photo-free account                       | **Passed** signed-out preview → real OTP → ready preview → explicit Join → token-free confirmation. No admission before the explicit action                                                                                                                                                               |
| Browser reload/back/forward                                             | **Passed** preview/profile/confirmation reload, OTP reload returning to email entry, Proposal back/forward with current membership and no new admission. Both revoked previews unavailable; Proposal full reload offered no fictitious Retry                                                              |
| Browser double-click / account isolation                                | **Passed** Proposal Join double-click produced one receipt/episode. Tavolo identity visiting Proposal confirmation had no current entitlement                                                                                                                                                             |
| Browser ambiguous-response recovery / account switch during uncertainty | **Unexecuted** at real transport boundary: available browser APIs supplied no request-loss/interception control. Existing client recovery/account-change tests and canonical retry races passed; manual steps below remain required                                                                       |
| Browser confirmations after revoke/departure                            | **Passed** both confirmations survived authenticated link revocation; after Proposal voluntary leave and Tavolo organizer removal, reload showed no current participation and no automatic rejoin                                                                                                         |
| Ordinary signed-out sharing, both kinds                                 | **Passed** public details with one join intent, normal approval/photo/contribution copy, dismiss action and app CTA; no forced authentication                                                                                                                                                             |
| Actual Open PLANETS / missing downloads                                 | **Passed** actual Proposal confirmation button navigated to the canonical token-free HTTPS UUID detail; Chrome displayed HTTP 404 on 5 October. Honest unavailable-download copy observed. Native delivery **unverified**                                                                                 |
| Configured real downloads                                               | **Unexecuted**: real listing inputs unavailable. Existing configured/unconfigured download tests passed; synthetic settings do not prove store delivery                                                                                                                                                   |
| Mobile GUI continuity, both kinds                                       | **Passed** each web identity signed into the real mobile OTP UI after revocation, found Messages → Groups, read Dario's retained message, sent/read one synthetic message, and opened Group info → normal Project detail. Both accounts had zero photos; no old capability used                           |
| Mobile explicit Join, both kinds                                        | **Passed** ready photo-free `pi05-mobile` UI sign-in, bounded internal preview launch, explicit Join and participating state. Independent reads found one episode per kind and the shared roster/capacity below                                                                                           |
| Later ordinary photo gate                                               | **Passed** actual mobile sample form → Publish photo dialog after admitted chat/detail access, with no publication. Canonical ordinary request and complete private draft publication returned PT422 in the demo check                                                                                    |
| Secondary mobile observations                                           | Unfiltered Proposal browse showed its safe error against accumulated mutation-verifier fixtures; direct Project detail worked. Chat showed a live-update warning while durable read/send succeeded. Live fan-out recovery **unverified**; no application runtime exception identified beyond driver waits |
| Production HTTP/public-origin rehearsal                                 | **Passed** reused PI05 probe in disabled and synthetic enabled association modes: HTML/assets/RSC/prefetch/POST/private headers/404 preserved. This is no public deployment or signed-device association                                                                                                  |
| HTTPS OS dispatch                                                       | **Blocked** predecessor intent command group; never repeated or replaced with lower-level proof                                                                                                                                                                                                           |
| Signed public Android/iOS association                                   | **Unexecuted**: final identities/provisioning/signed builds/devices/host unavailable; Windows cannot run Xcode/iOS                                                                                                                                                                                        |

Nonsecret run IDs: Proposal `9ab34a50-960d-4370-a0a6-65b1e3184b8f`;
Tavolo `1f4435e9-8c69-4477-8d0c-b5095a15cc47`. Before departures each had
five participants, including one browser and one mobile admission. Proposal
used five of twenty spots excluding its Creator; actual mobile detail displayed
five participants plus one organizer / six unique people. Tavolo used six spots
including its Creator. After browser leave/removal, independent `--status` read
four participants per kind, four/five used spots respectively, exactly two
interactive receipts per Project, one ended episode per browser identity and
two current mobile episodes. All three interactive profiles retained zero photos.

For the unexecuted ambiguous-response case, use normal browser offline/request
blocking developer controls around explicit Join on a fresh disposable account
and generation. Independently record whether the server committed; navigate
away/back within the same running application, recover only its original tuple,
then test logout/account change and full reload separately. Restore networking
and assert one receipt/episode or the original ended episode, never an automatic
fresh action. Repeat both kinds. A successful HTTP response does not prove this.

For the secondary browse/live-update observations, reproduce on a separately
clean owned demo-only stack (`demo:reset:local`), retry normal browse/chat refresh
and record actual server/client failure status before changing production code.
The mixed post-gate database includes intentionally incomplete published verifier
fixtures and is not a clean discovery presentation dataset. Durable read/send
does not prove live Realtime fan-out.

## Validation and release inputs

Local `check:db` passed clean reset, migration lint/advisors, 108 pgTAP files /
3,386 assertions, every prior mutation verifier, clean partial-run/demo sequence
and generated-type drift. `check:mobile` passed 1,204 tests (two skips),
localization, formatting and analysis; the expanded driver then passed focused
formatting/analysis and actual Android debug build/startup. `check:web` passed
263 tests (one existing opt-in skip), 30 tooling tests, lint, type checking and
production build. `check:site` passed 34 Site and 19 Worker tests, lint, build
and deployment dry-run. Final formatting/diff and final-head CI are checked
before merge. No external deployment occurred.

Approved ingress/dynamic-origin ownership, DNS/TLS control, final Android identity
and distribution fingerprints, Apple identity/provisioning, signed builds/devices,
real download listings and verified host logging/cache/retention/access controls
remain account-owner prerequisites. Follow the [PI04 release runbook](pi04-native-links-and-public-host-readiness.md#external-release-runbook)
instead of creating a second signing/hosting contract. No external deployment,
DNS/provider/billing change or app-store submission occurred in PI05.

PI04 automatic approval review rejected its Android intent command group and
ignored-fixture deletion with only **“blocked by policy.”** Those operations were
not repeated through another wrapper/tool or cleanup mechanism. Its retained
checkout/ignored fixtures are unrelated to PI05 ownership and remain untouched.
PI05's owned Next/Site/harness and Flutter tool processes were stopped, its
Supabase containers/volumes removed with the explicitly selected PI05 project,
and its original configuration restored before commit. The emulator/debug APK
is left available; it is not a signed release. Managed checkout/branch cleanup
follows the verified merge and is reported in the final handoff. No PI04 cleanup
operation was attempted.
