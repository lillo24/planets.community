# PI02 — Mobile Project sharing and participant invitations

Implemented from merged PI01 (`996f019f19f9fc3f661c388c30cb01d966e64d37`, PR #128).
The [PI01 contract](pi01-participant-invitations.md) remains the canonical domain;
PI02 changes no migrations, admission policy, commitments or organizer authority.

## Mobile behavior

Public Proposal/Tavolo details expose Share to signed-out viewers and nonmembers.
Every dialog starts with ordinary sharing. Current Creator, Co-Creator and
Co-Organizer roles may explicitly select reusable special participant sharing.
People, Manage project and entitled manager group info navigate to one
`/proposals|tavoli/<id>/participant-links` destination.

| URL                                                    | Flutter behavior                                            |
| ------------------------------------------------------ | ----------------------------------------------------------- |
| `https://planets.community/proposals/<id>?intent=join` | Public Proposal plus dismissible existing request actions   |
| `https://planets.community/tavoli/<id>?intent=join`    | Public Tavolo plus dismissible existing request actions     |
| `https://planets.community/join/project/<token>`       | Safe public participant preview; explicit Auth/profile/Join |
| `https://planets.community/invite/project/<token>`     | Existing authority invitation, unchanged                    |

The ordinary marker requires exactly one `intent=join`. Closing retains detail
and removes the marker. Continuing uses the existing protected request composer,
photo/contribution gates and approval. Auth cancellation preserves public detail.
No ordinary link creates a request or membership automatically.

Special preview reveals only available Project ID/kind/title. The exact safe
participant return path survives OTP/profile setup and cancellation. Admission
requires an explicit Join and only calls the PI01 acceptance RPC. A complete
non-photo profile is sufficient. Pending requests and their history/offers are
resolved by PI01; Flutter makes no synthetic request or commitment write.

## Recovery and privacy

One UUID is generated at the explicit Join click and retained with account and
token in process-memory controller state. Double clicks, route replacement,
navigation, transport failure and an unavailable refreshed preview reuse that
tuple. Logout/account switch and ProviderScope/process disposal discard it and
reject late results. Process-restart persistence is intentionally absent: after
restart there is no Retry label for the lost attempt.

Receipt recovery never becomes automatic re-entry. Original `left`/`removed`
episodes receive ended-join copy; canonical own participation is refreshed first,
so a newer current episode still gets current Project/chat actions. A new explicit
Join-again click generates a new UUID only with a valid current preview and a
successful canonical read showing no current episode. Creator receipts fabricate
no membership. Chat entitlement is read independently at navigation; chat/read
failures retry reads, without a new admission or photo prompt.

Confirmed results clear meeting access and refresh own participation, cached public
detail/capacity, People/request/history, Messages/request-chat and chat refresh
signals. Managers revalidate account/role before disclosure. Repeated special
sharing gets or retrieves the current generation without rotation. Confirmed
replacement disables the old link; confirmed revoke passes the displayed ID so a
stale screen cannot revoke its replacement. Uncertain mutations retrieve canonical
current/history state before another destructive action. No special error silently
shares an ordinary URL. Pause/closure is shown using safe preview availability;
metadata history and revocation remain useful and there is no fixed expiry.

Secrets stay out of UI history and state/exception serialization. Account/Project
switches remove secret-bearing overlays and ignore pending reads. Optional Sentry
filters drop entire secret-bearing events/breadcrumbs, including encoded `returnTo`
URLs, RPC token keys and standalone 43-character opaque values. Public ordinary
URLs remain observable. Copy/native share is intentional disclosure through the
existing positioned SharePlus/Clipboard adapter. English/Italian catalogs own all
new user copy.

## Reproducible checks and local smoke

Run standard mobile validation from repository root:

```text
npm run check:mobile
cd apps/mobile
flutter build apk --debug --dart-define-from-file=config/local.json
```

Use an isolated worktree and **disposable local Supabase** project/ports before
running fixtures. Start/reset that local stack with repository commands; never
select shared staging/production. The fixture requires loopback CLI status and an
explicit `--disposable-local` argument, creates two deterministic synthetic Auth
accounts plus one future published Proposal and pending request, and writes local
session tokens only into ignored `apps/mobile/config/pi02-smoke.json`. Reset the
disposable stack before repeating it. Root Node dependencies must be installed.

```text
npm run project:participant-invites:verify:local
npm exec --call "node apps/mobile/test/support/local_participant_invitation_fixture.mjs --disposable-local"
cd apps/mobile
flutter test --dart-define=PI02_LOCAL_SMOKE=true test/features/project_participant_invites/participant_local_backend_test.dart
```

The opt-in Dart test exercises the actual Supabase gateway over HTTP: manager
get-or-create/retrieval/history/revoke, anonymous preview, photo-free admission,
pending-request withdrawal without history deletion, current membership/chat and
same-action replay after revocation. Its synthetic clients use explicit test
session access tokens; production Auth/session handling is unchanged. The normal
suite skips this test unless opted in.

For internal-route Android smoke, generate emulator config against the same local
stack and start an emulator:

```text
npm run mobile:config:local -- --host 10.0.2.2
cd apps/mobile
flutter run -d emulator-5554 --dart-define-from-file=config/local.json --route=/join/project/invalid
```

This should show the safe unavailable participant preview with Close/Try again.
Valid-route and Auth/request journeys are exercised by router/widget tests with
synthetic gateways. This internal route does not verify HTTPS OS association.

## Validation record and remaining work

`npm run check:mobile` passed localization generation, formatting, static analysis
and 1,193 Flutter tests, with one opt-in local-backend test skipped. That test
passed separately over actual Supabase HTTP. Local PI01 verification passed all
25 integration/concurrency scenarios. The chat regression suite passed 35 tests.
The final debug APK build passed. Android internal-route launch and hot reload
succeeded with no runtime errors; the task report/PR records hosted CI results. The disposable
backend, volumes and local token fixture were removed after verification.

PI03 still owns browser onboarding/app-download CTAs; PI04 owns public-host
routing, Android/iOS verified association claims and signed-device delivery;
PI05 owns broader demo seeding. No production WhatsApp/browser tap, iOS signed
device, app-store submission or deployment is claimed here. No external provider
credential is required for this implementation.
