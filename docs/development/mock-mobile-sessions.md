# Closed-test mobile realm boundary

`ENABLE_CLOSED_TEST_MOCK=true` enables the native staging/loopback Sandbox
control. It defaults false and is suppressed in production and web.
`ENABLE_DEMO_TOOLS=false` remains required. APK possession grants no entitlement;
the broker's private issuer/UUID tester roster remains authoritative.

The exact string keys accepted by the staging validator are
`MOCK_SUPABASE_URL=https://pnolarmzxmmjtguligfc.supabase.co`, its client-safe
`MOCK_SUPABASE_PUBLISHABLE_KEY`,
`MOCK_PERSONA_BROKER_URL=https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas`
and `MOCK_FIXTURE_GENERATION=mock-world-2026-10-21-v1`. Normal remains
`https://cllpvruvrrvxczjitlqd.supabase.co`. Local QA requires two distinct
loopback origins/ports and keys. Equal origins, foreign brokers and privileged
keys fail validation. Incomplete setup is visibly unavailable. The map builder
passes the same validated JSON through without enabling mock or new providers.

## Audited owners

| Owner                                                       | Boundary                                                                                      |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `core/backend/supabase_backend.dart`                        | Stable normal client, sole normal Auth refresh owner                                          |
| `core/backend/secure_session_storage.dart`                  | Confidential normal, PKCE and per-root/request mock credentials                               |
| `core/backend/realm_transport.dart`                         | Exact origin/no redirects; product fence, original in-flight request tracking                 |
| `mock_mode/application/mock_mode_coordinator.dart`          | Serialized transitions, monotone generation, recovery and stale completion rejection          |
| `mock_mode/data/mock_session_access.dart`                   | Fixed broker, ordinary Auth session and canonical profile/registry validation                 |
| `mock_mode/presentation/mock_realm_host.dart`               | Entire root product ProviderScope/router/image cache replaced per realm/revision              |
| `app/router/app_router.dart`                                | Guarded picker, normal-link boundary and denied persona provider Auth/support/deletion routes |
| `project_workspace_pending_add_store.dart`                  | Realm/root/actor/project journal and acknowledged known-normal legacy migration               |
| `group_discussions/data/discussion_hint_store.dart`         | Realm/root/actor hint; no private Group content                                               |
| Sharing provider, `ShareLinkButtons`, delegate result sheet | Clear unavailable external sharing; no normal-origin mock capability disclosure               |
| `help/application/support_mail.dart`                        | Denied persona mailto handoff; public policies remain readable                                |
| `core/monitoring/app_monitoring.dart`                       | Sentry never initializes for a closed-capability build                                        |

All product gateways depend on the active root client: Profile/visibility and
avatar/cover Storage, Groups/People/history, Ideas, Projects/Tavoli/workspaces/
participation, templates, resources/Scambio, Messages/Requests/unread/read ACKs,
C/D/M, reports, Block, notifications and owner-management. Map domain/preview
gateways use that client. Generic public basemap caching retains its existing
generic-byte contract. No cost-bearing mock provider function/secrets are
configured. Direct Supabase singleton access is confined to backend initialization
and its default provider. No mobile push registration or separate analytics
client currently exists. Mock delivery workers are not deployed.

Normal product requests and Realtime are fenced/disconnected during mock; only
GET Auth user, refresh-token grant and logout remain permitted. Normal tokens
are sent outside normal Auth only to the exact trusted broker. In-flight work
keeps its original destination; completed responses cannot populate a new scope.
Draft departure uses Save/Discard/Stay. Unknown writes require Stay or explicit
retention in the original realm; the receipt contains operation names only, no
payload, query or capability, and cannot replay. Frozen workspace Adds preserve
their original exact request in their feature journal. Normal-origin links in
mock require explicit return to normal and reopening; they never look up the
same UUID in mock.

## Persistence, restart and logout

The maintained `flutter_secure_storage` dependency is pinned to 11.2.0. Android
uses RSA-OAEP/AES-GCM with reset-on-error disabled. iOS uses Keychain after first
unlock on this device only. Normal legacy SDK preferences migrate after secure
write/readback; conflicting sessions fail closed. Legacy loopback keys omit
ports and cannot be safely attributed, so a nonempty such key requires explicit
recovery. Late callbacks cannot overwrite rotated or cleared credentials.
Android backup/extraction rules exclude SharedPreferences XML and its DataStore
directory from cloud backup and
device transfer, including secure ciphertext, legacy Auth, pending capabilities
and installation settings. Device-bound encryption keys must not be restored
onto another device. This does not clear existing installation data.
Mode SharedPreferences contain public root/persona/user/request/revision/origin/
generation metadata only. Installation language, navigation, Activities Split
and tutorial preferences remain independent.

Preparing mock clients have automatic refresh off. Only the active mock client
starts refresh after commit, stops on pause/departure and revalidates entitlement
on resume. Restored pending issuance enters recovery and retries its original
request/persona. Restored Yes validates its confidential session and registry;
it does not silently issue a new session or send OTP.
Recovery keeps conflicting actions disabled until the originating operation has
settled and completed scoped cleanup, even after control-account A/B/A changes.
Retirement coalesces concurrent callers; failed secure deletion remains retryable.
Normal product transport resumes only after No is persisted and its revision is
still current. A superseded activation cannot install a retired candidate.
Changed configuration,
control account replacement, denial, mock Auth loss and downtime show isolated
recovery instead of normal content. No/persona change retires only the current
mock session; explicit PLANETS logout clears retained normal and local mock
access and metadata. Failure remains recovery rather than a success message.
Returning to normal revalidates its retained Auth authority before product reads
resume. A lost/expired normal session opens ordinary sign-in with Mock Mode off;
explicit PLANETS logout still owns the Welcome transition. A delayed validation
cannot sign out a newer normal token/account. Authoritative mock Auth loss
disposes protected presentation rather than retaining its hidden product scope.

The shared selector consumes `catalog()` and
`select(persona, prepareDeparture: ...)` on the same coordinator. Help exposes it
only while mock is active; initial entry requires the explicit Sandbox action.
Scenarios are localized exploration suggestions and do not assert current roles.
The release Android network policy permits HTTP only for IPv4 loopback/localhost
QA; external destinations remain HTTPS. Debug keeps its existing overlay.
The map-build manifest records only the public mock origin, fixed broker,
generation and capability; it excludes client keys and states that hosted
readiness has not been established by a build.
No production fake gateway fallback exists. Hosted setup and the normal
staging migration gap remain separately recorded in `mock-hosted-status.json`.
