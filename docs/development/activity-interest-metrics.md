# ACTMET01 — internal activity interest metrics

## Implemented and disabled state

ACTMET01 instruments real public native Tavoli, including Requested cards, in
both Activities Split Mode states, plus ACTAPI01's public imported catalogue when
that mode is enabled. Only deliberate list-card navigation attempts and successful
public-link platform handoffs are measured. Existing
public-detail/share authorization and error handling still own the user action.
The tracker does not wait for telemetry before navigation, clipboard or sharing.

Production sends **no analytics**. No PostHog SDK, initializer, native metadata,
HTTP transport, persistent analytics ID or local analytics cache is installed.
Tests inspect injected events only. No PostHog project, dashboard, permission
basis, live traffic, app-store declaration or hosted notice has been configured
or verified by this change.

## Version-1 contract

| Event                   | Trigger                                           | Properties                                                                                                                                                          |
| ----------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `activity_card_opened`  | Explicit public card tap starts detail navigation | `schema_version=1`, `item_kind=tavolo` or `imported_activity`, `item_id=<canonical lowercase UUID>`, `origin_surface=tavoli_list` or `activities_list` respectively |
| `activity_share_action` | Successful public platform handoff                | Same version/kind/ID, `origin_surface=tavolo_detail` or `imported_activity_detail`, `action=link_copied` or `share_sheet_invoked`                                   |

Card opens are navigation **intent**, not confirmed views or unique people. A
share-sheet invocation may end in dismissal. The existing platform adapter
returns after a successful invocation/result; it cannot verify a recipient or
that a message was sent. Merely opening/closing the dialog is not an event.

Factories accept only `tavolo` / `imported_activity` and canonical UUIDs; there is no
arbitrary-property API. No titles, descriptions, locations, URLs, query text,
organizer details, profile/account identifiers, email, tokens, chat, content
metadata or client-supplied IP addresses enter the payload. No per-person or
per-device identifier is created by the tracker.

Excluded: all 12 fictional examples, Mock realm records, Progetti, Scambio-Dona, drafts, failed or
unavailable detail states, route/deep-link opening, widget builds, filters,
restoration and return navigation. Special participant/manager/authority links
have no telemetry hook, including metadata describing their use. An exact
ordinary URL match is required at the shared handoff boundary, but that URL
never enters analytics. Imported handoffs use the already validated official
source link from ACTAPI01's public model, never a fabricated PLANETS URL; opening
that source in a browser is not a share event. The public list/detail model is the eligibility source;
the tracker does not query or broaden private-record access. A later failure to
load a detail does not erase a valid card navigation intent.

## Dispatch and approximation

- The list suppresses duplicate callbacks while that card's detail navigation
  is pending. The tracker also coalesces identical event/item/action callbacks
  within 500 ms using at most 32 transient keys. Later taps can count again.
- At most 8 dispatches can be pending, each with a 2-second deadline, and at most
  60 events can be attempted per process per minute. Excess work is dropped.
- There is no offline persistence, retry, later replay or background flush.
  Failed, expired, disposed and permission-revoked work is dropped. Counts are
  therefore approximate and can undercount.
- The gate is checked before accepting work, before dispatch and by the adapter
  again after asynchronous setup. Actor/readiness changes invalidate pending
  revisions and dispose the old sink without sending identity. A platform
  operation finishing for a stale account/route/mode is not instrumented.
- Telemetry failures become explicit internal delivery outcomes without payload
  logs, Sentry reports or user-facing telemetry errors. An already transmitted
  event cannot be recalled by later revocation.

## Configuration and the SDK blocker

The feature uses the existing Flutter compile-time configuration convention:

| Define                      | Default                | Meaning                                                                                                                   |
| --------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `ACTIVITY_INTEREST_ENABLED` | `false` in every build | Only literal `true` requests an adapter; invalid values report `invalidConfiguration` and remain off                      |
| `POSTHOG_PROJECT_TOKEN`     | empty                  | Future EU project's public `phc_...` project token; missing/malformed values report `invalidConfiguration` when requested |

Keep project configuration in ignored build configuration, not committed values.
No personal API key belongs in a mobile application. The endpoint is fixed to
`https://eu.i.posthog.com`; no arbitrary ingest endpoint is accepted.

Configuration is **not permission**. `activityInterestPermissionProvider`
returns `DeniedActivityInterestPermission` and no user-facing switch overrides
it. Auth, Terms/Rules acceptance and Activities Split Mode do not grant analytics
permission. A future reviewed collection basis/notice or consent mechanism must
own this independent policy, including withdrawal and guest/account transitions.

Mock mode is an unconditional additional denial, including when a test permission
and project configuration are supplied. The widget dispatch boundary and default
tracker enforce `activeMockRealmProvider`; realm replacement disposes prior
pending work. Test persona UUIDs must never be treated as real analytics traffic.

Inspected on 2026-10-21: the official
[`posthog_flutter` 5.56.0 archive](https://pub.dev/api/archives/posthog_flutter-5.56.0.tar.gz),
especially `lib/src/posthog_config.dart`, native Android setup, and the
[official Flutter guide](https://posthog.com/docs/libraries/flutter).
The public Flutter configuration does not expose a native Android/iOS
identity-persistence-off option. Its bootstrap documentation explicitly retains
stored identity; `personProfiles=never` suppresses profiles but does not remove
anonymous identity persistence. Disabling application lifecycle events, screen
views and replay alone cannot satisfy this plan. The guide also documents native
offline queuing. No attempt is made to initialize then reset the SDK, since that
would already create prohibited persisted state.

Accordingly the concrete production client is absent and the configured adapter
reports `unsupportedSdkPrivacy`, even if an injected permission policy allows
collection. `ManualActivityInterestPostHogOptions` describes **app-owned
requirements**, not real SDK field names. Injected clients in tests verify the
adapter's EU host, strict properties, no autocapture/lifecycle/screen/replay,
no identity/profile enrichment or persistence, bounded memory and zero retries.
Those tests do not prove native SDK behavior. No new dependency is justified
until a concrete SDK can satisfy the requirements.

Before live activation, a separately reviewed follow-up must:

1. Select/pin an SDK and its native dependencies that can demonstrably avoid
   stable cross-session identity and persistent event storage; implement the
   narrow `ManualActivityInterestPostHogClient` against its real API. Verify
   manual-only capture, bounded/cancellable work, disabled IP/geolocation and
   automatic metadata collection, and no startup/offline network on Android/iOS.
   If none qualifies, keep activation blocked and review a separate alternative.
2. Obtain the owner's authorized PostHog EU project and reviewed lawful
   collection basis, user notice and any required consent/withdrawal control.
   No provisional policy wording is approved here.
3. Wire the independent policy and configured client explicitly, then verify
   safe real events in the intended environment before any authorized rollout.
   Native/device and iOS validation are still required for that client.

## Internal inspection after approved activation

In the authorized EU project, inspect the event stream first: verify version,
kind/ID, origin and action, and check that no other properties or automatic
events appear. Create a Trends insight using **total event count**, filter
`schema_version=1`, `item_kind=tavolo`, and break down by `item_id`.

Compare the last 7 days with the preceding 7 days, then the last 30 days with
the preceding 30 days. Inspect `activity_card_opened` separately from
`activity_share_action`; split the latter into its two action values. Use an
exact `item_id` filter to inspect one activity. Do not interpret any SDK
distinct-ID or unique-person calculation as measured people.

`share actions / card opens` can be a descriptive proxy for the same item/time
window and item kind. Use `item_kind=imported_activity` for a separate catalogue
comparison, with `activities_list` versus `imported_activity_detail` origins.
It is not a verified conversion rate: a direct-link visitor can share
without a card open, one person can act repeatedly, and drops/deduplication alter
counts. Zero denominator is undefined. Neither signal measures attendance,
crowding, capacity, demand, occupancy or a reason to change public ranking.
No insight/dashboard has been installed by this implementation.

## Stop and rollback

The current denied policy and absent production client already stop collection.
For any future rollout, deny the independent policy immediately, invalidate the
tracker/sink, and rebuild with `ACTIVITY_INTEREST_ENABLED=false` (or remove the
define). Remove the token from subsequent build configuration. A rebuild only
affects upgraded installations; design any required remote stop mechanism in the
activation follow-up. Follow the provider's approved retention/deletion process
for previously ingested data; disabling capture does not delete it. The UI hooks
can remain without telemetry and do not require a backend rollback.

## ACTAPI01 integration

The resumed implementation integrates merged ACTAPI01 (`8d9c3ac0`) on the
2026-10-23 main baseline. `ExternalActivitiesScreen` instruments only its explicit
real-card callback. `ExternalActivityDetailScreen` supplies the loaded public
record to `ExternalActivityShareActions`, which shares its typed `officialLink`
through the existing clipboard/native adapter. `PublicExternalLink.parse` already
validates that externally published URL. Metrics receive only the canonical
database UUID and fixed `imported_activity` kind, never its source URL/provider
token, and never a fabricated PLANETS link. Opening official/license links is not
an analytics event. The import pipeline and backend writer are untouched.

The licensed connector and actual source activation remain ACTAPI01 owner gates;
its empty/unconfigured catalogue produces no fabricated events. Injected public
fixtures exercise navigation, handoffs, failures, actor changes and Mock exclusion
without live imports, provider configuration or PostHog traffic.

## Local validation

From `apps/mobile`, run `flutter analyze`, the affected suites and an Android
debug build. The deterministic fixtures require no analytics credentials or
network. Full mobile CI also runs localization generation, formatting, analysis
and the complete Flutter test suite. Tests cover the default/denied gate,
explicit blocked adapter, allowlist/IDs, revocation/disposal, actor changes,
deduplication/bounds, native and imported hooks, platform failures,
private-link/Progetti/example/Mock exclusion, and navigation with pending/failing
telemetry.
