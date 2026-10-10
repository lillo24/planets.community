# MAP02 location selector

LOCATION02 replaces only the one-time Project editor with a single inline place
query, an explicit exact-place visibility switch and separate private directions.
Tavolo/Resource flows below are unchanged. See the
[current one-time contract](location02-inline-project-place.md).

Dependency: MAP01 PR #172, main `6650d995c4a393ef43e13f16d51933645be72db9`
(predecessor implementation `6761ac63f5fbe22afff58f18f370555c8ca7d039`).
This slice adds editor selection without activating Geoapify, maps or discovery.

## UI and exposure

All three editors use `features/locations/presentation/location_editor_section.dart`.
The default disabled factory preserves legacy manual inputs, international
country/timezone values and ordinary draft/publish validation. No new UI flag,
provider key, GPS permission or dependency is added. Injected deterministic
factories exercise the primary selector; production registration is off.

| Item              | Public choice                                  | Optional precise choice                                        | Other content                               |
| ----------------- | ---------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------- |
| Proposal / Tavolo | Independently selected locality                | Address/amenity under existing Public/Participants entitlement | Instructions and visibility remain separate |
| Scambio/Dona      | Locality/address/amenity, all precision public | None                                                           | Existing publish/close and manual rules     |

No precise point produces a broad area. Selected public components update the
ordinary form controllers after canonical reread so later saves preserve the
selection. Clearing removes geometry and retains ordinary text. Coordinates
are unnecessary for MAP02 and are omitted from its editor projection.
Creator/Co-creator structural authority and Co-organizer/member protected read
rights remain governed by MAP01 and existing domain RPCs/RLS.

Project area suggestions filter to localities, exact suggestions to
address/amenity; Resources permit all supported types. Typing remains unverified
until explicit tap, resolution and save confirmation. Loading, genuine no
matches, connection/timeout, quota, unsupported source, expired/stale, disabled
and authorization failures have safe EN/IT copy. Errors never become successful
empty locations or raw upstream messages.

Geoapify and OpenStreetMap contributor links use fixed HTTPS targets. Credits
remain in manual mode and after clear because provider-derived text can persist.
MAP03 owns credits on other public detail/card/template surfaces before activation.

## Save and recovery contract

Opening create makes no record. Choosing lookup deliberately saves a draft,
as explained by the section. Ordinary validation, cover reconciliation and
partial-save behavior remain authoritative:

1. Save pending content/cover without publishing or navigating.
2. Obtain the canonical saved ID and read the authorized location revision.
3. Construct a new actor/kind/item/revision/slot gateway and transient controller.
4. Explicitly tap a result to resolve its receipt, then confirm.
5. Apply actions, receipt UUID, expected revision and stable mutation UUID only.
6. Reread through the authorized RPC and require the committed revision before
   displaying durable selection. Apply success alone is insufficient.

Each slot completes before the next begins. The editor handle revokes an earlier
receipt before ordinary Save/Publish. Content changes, readiness loss, ABA
accounts, route/form replacement, departure, background, TTL and disposal reject
late work. Foreground and route return reread protected state. Unchanged
hydration and cursor movement do not count as edits. Dialogs cancel on expiry,
stale or authorization denial; choosing again reauthorizes and searches afresh.
No denial automatically searches, publishes or retries.

After ambiguous apply/read timeout, explicit Retry retains the exact write input
without another content save. Another save or expired session discards that
volatile retry. A canonical conflict requires a fresh choice. No raw query,
receipt, session, suggestion or protected transient point enters DRAFT01,
templates, logs, analytics or shared caches.

Proposal uses the existing DRAFT01 idempotent bootstrap. The other two create
RPCs were non-idempotent; additive migration
`20261008144158_map02_idempotent_editor_drafts.sql` adds typed
`create_editor_recurring_activity_draft` / `create_editor_resource_listing_draft`
and their actor-bound `recover_editor_*_draft` RPCs. Legacy create APIs remain.
Each editor retains one UUID and frozen creation intent across retries, recovers
the same ID before applying newer content through ordinary update, and retains
received IDs across cover/refresh failures. Provider families isolate concurrent
Tavolo/Resource editors. Account/form replacement cannot reuse another scope.

Private append-only creation receipts hold actor/request/item/hash/time, with
restrictive references, no raw API grants and no search/location payload.
Transaction advisory locks serialize duplicate creation/recovery. Wrappers use
existing complete-profile/content rules, hardened search paths and authenticated
execution only. Location storage, receipt format and grants are unchanged.
Generated public types come from the canonical CLI generator.

## Reproduction and boundaries

Run focused `apps/mobile/test/features/locations/` tests, existing domain
editor/cover/draft suites and `npm run check:mobile`. Fixtures inject
`editorPlaceGatewayFactoryProvider` and `itemLocationGatewayProvider`; fakes
cannot fall through to live Geoapify. Default registration remains disabled.

Replay, lint/advisors, pgTAP and `npm run location:verify:local` require an
explicit disposable loopback stack (`PLANETS_DISPOSABLE_QA=1`, explicit
`MAILPIT_URL`). The verifier exercises real authenticated bootstrap, concurrent
duplicate creation, recovery, receipt resolution, per-slot apply/retry/reread,
privacy and clear for all three kinds using synthetic provider data. It restores
local configuration in `finally`. Never reset the retained `planets-community`
phone/demo stack or ports 54321/54322.

`test_support/map02_rehearsal.dart` and `map02_native_smoke.dart` provide an
explicit debug-only (`MAP02_REHEARSAL=true`) Android journey using the real
three editors and deterministic domain/location gateways. The driver requires
a verified task-owned VM URI and capture directory, covers EN/IT, emulated text entry,
explicit selection, independent Project slots and draft saves, and checks fake
write totals. Native presentation is separate from real local RPC evidence;
neither proves live Geoapify or iOS behavior.

## MAP03 and owner activation

MAP03 may build on implemented MAP02 before merge, with ordered reconciliation.
Use its final PR head/merge SHA and preserve newer main changes. Maps, card
previews, geographic discovery and public credits remain later work. Before
activation the owner must confirm commercial Free scope/terms, supply a
server-only key, approve quota/cost budgets, complete public attribution and
native provider QA, and deliberately review scoped mobile factory registration
plus both runtime and database kill switches. No deployment, accounts, billing,
signing or publishing occurs in MAP02.

[MAP03](map03-location-previews.md) now owns read-only previews, public batching,
static transport, public attribution and the shared rendering/autocomplete
credit ceiling. Provider defaults remain disabled.
