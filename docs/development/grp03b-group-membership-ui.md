# GRP03B group participation UI

The Groups entry is a localized trailing toolbar action on Proposal/Tavolo Browse
lists. It is absent from switcher/filter bodies and tutorial placeholders. Pushing
the directory retains the originating branch, filters, loaded window and scroll.
Workshop/Drafts and Messages/Browse preference remain under their existing owners.

Mobile group profiles combine public content with the identity-bound exact-self
read. Pending requests are not participation. Optional ordinary-request notes use
500 PostgreSQL-character bounds and remain private. Policy/photo preflight keeps
the form underneath and never submits after profile completion. Withdraw, Leave,
Step down and Decline are exit actions without new policy/photo/readiness gates.

My groups has independent managed/joined/request/offer routes, each with bounded
paired cursors. People uses the canonical ascending rank/UUID union, contextual
names and independent role/participation labels; it grants no bio/photo/contact
access or messaging action. Manager request/membership history and structural
Team/invitation/role history stay separate. Refresh rebuilds only the loaded
window; transport failure retains it, authorization denial clears it and epochs
reject responses for another viewer. Paging requires deliberate scrolling, with
reachable Load more/Retry fallbacks.

Creator content commands retain GRP02 contracts. Co-creators use structural
context/write/recovery, with no Creator draft/publication access. Archive/Restore
uses optimistic versions. Confirmed Restore-to-draft exits without reading the
new draft, including after response loss/recovery. Co-organizers have operational
request/member/link controls. Leave and Step down never substitute for each other.
Targeted seven-day offers bind exact current membership episodes. Co-creator
acceptance explains published editing, lifecycle, participation/link and delegation
powers and excludes Creator identity/drafts, verification and Project powers.

Ordinary `/groups/:id` sharing does not bypass approval. Reusable participant
links use separate current/get/create/replace/revoke/history RPCs. Copy/Share
rechecks current authority. Replacement/revocation confirms the displayed
generation and retains its original key/intent across navigation. Read failure
is not absence. Null rotation retry tokens require an explicit current-link read.
Seven-day, single-use authority invitations reveal plaintext only in the immediate
handoff; metadata recovery offers revoke/reissue, never secret retrieval.

## Invitation and host boundaries

Mobile and canonical Next own `/join/group/<43-token>` and
`/invite/group/<43-token>`. Passive Auth restoration, preview and profile completion
never accept. Existing Next/mobile onboarding returns to explicit Join; authority
requires informed role consent tied to actor, group, role and expiry. Tokens and
ambiguous command keys remain in process/tab memory, never preferences/logs or
analytics. Identity changes clear private state and cancel confirmations.

Unsent request notes survive lazy-list disposal and temporary profile/policy routes
in account-scoped process memory, and clear on submission or identity/authorization
loss. Invitation attempts also freeze the original role/expiry consent; a consumed
or unavailable preview keeps Retry original action available for recovery.

One action freezes actor/key/operation/intent. Exact retry recovers before delivery;
confirmed receipts only retry current status. An ended episode needs fresh deliberate
re-entry. Nullable third-party current status means unavailable to this actor.
Neutral errors never identify blocking direction. Missing RPCs are setup failures.

Native validation extends the existing HTTPS host allowlist, duplicate suppression,
Android path tuples and repository-owned AASA paths. iOS host entitlement is already
shared; no fabricated signing identity was added. Dart's existing URI boundary
normalizes explicit default HTTPS ports before validation; nondefault ports,
credentials, foreign/insecure hosts, fragments, encoded/malformed capabilities and
unexpected capability queries are rejected. Group details accept no native query.

Next applies capability privacy headers and rejects malformed/query-bearing group
capabilities. Confirmed browser navigation uses `/joined/groups/:id`, with current
verified status and optional configured app-store handoff. Public group metadata
alone never establishes participation. Group profile onboarding asks only for a
name, preserving other profile fields and permitting photo-free direct admission.
The static invitation trial and its SPA fallback remain unchanged. Hosting group
paths on the canonical domain and enabling valid native associations are separate
activation work, not implied by this source change.

## Repeatable local QA

Use a separately designated disposable loopback Supabase workdir. `check:db`
resets that selected stack. Run migration replay, lint/advisors, pgTAP, generated
type parity and `group:membership:verify:local`; the latter includes exact-self
PostgREST identity/privacy assertions. Run `npm run check:mobile` and
`npm run check:web` from the task checkout. Site code is unchanged.

From the disposable workdir, with the checkout's pinned Supabase CLI on PATH:

```powershell
$env:PLANETS_DISPOSABLE_QA='1'
$env:MAILPIT_URL='http://127.0.0.1:59824' # use the selected stack's mailbox
$defines=Join-Path $env:TEMP 'grp03b-local-defines.json'
node <checkout>/apps/mobile/integration_test/prepare_group_membership_smoke.mjs $defines
```

The helper creates three fictional verified OTP people, canonical policy records,
a published group and separate participant/authority capabilities. Defines contain
local sessions/secrets: keep them outside Git/logs and delete after QA. On the
selected emulator, reverse the selected API port, then from `apps/mobile`:

```powershell
flutter drive -d <emulator-id> --driver=test_driver/groups_screenshots.dart --target=integration_test/group_membership_smoke_test.dart --dart-define-from-file=$defines
```

The journey uses real PostgREST/Storage and only deliberately loses one accepted
reply. Its fixture-only Auth/policy adapter supplies the genuine OTP subject/token
without persisting GoTrue sessions. Gallery/crop UI is not exercised: after opening
the personal editor, a tiny fictional WebP is uploaded/committed through canonical
Storage/photo RPCs; returning preserves the note and requires another Submit.
Driver screenshots go to `build/groups-screenshots`.

For browser QA, configure/start the Next server against the same reviewed loopback
stack. Use an installed Playwright runtime (the desktop bundle can supply it; no
production dependency is added), then from the checkout:

```powershell
$env:PLANETS_PLAYWRIGHT_PATH='<runtime>/node_modules/playwright'
$env:GRP03B_WEB_URL='http://127.0.0.1:59830'
node apps/web/test-support/group-browser-journey.mjs $defines <outside-checkout-artifacts>
```

This uses real email OTP and profile/cancel/policy UI, drops one accepted HTTP
response, recovers the same action without readmission and accepts an informed
organizer invitation. Screenshots include page content only, without address bars,
capability URLs or private email. Use a fresh fixture for each complete journey;
mobile Restore intentionally returns its fixture group to a private Creator draft.

## Separate rollout and GRP03C handoff

No hosted migration, deployment, DNS, app-store upload or signing activation occurs.
Before distributing dependent clients, separately review/apply pending migrations
in order, including GRP01/GRP03A and `20261012152803` exact-self context. Verify
grants/API/type parity and smoke public, Creator, participant, operational delegate,
structural delegate, invitation/recovery and staff-suppression paths. Confirm real
host headers, association identities and Android/iOS link handling before activation.

Emulator/widget/browser evidence does not prove founder phone `48091FDAS0041A`,
TalkBack/Voice, physical native-link verification or iOS gestures. Those require
their actual reviewed configuration/devices. GRP03C may now add group-attributed
Projects on these identities/roles; this plan adds no Project attribution, chat,
verification, logo pipeline or ownership transfer.
