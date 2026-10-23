# External activity catalogue

This feature reads PLANETS' licensed external catalogue under Activities Split
Mode. It never contacts providers, imports events or invokes native participation.

When Co-Creation's independent presentation/server gates are ON, detail delegates
an explicit Find company action to that feature. It re-fetches the actual public
source and opens an editable unpublished people-seeking draft. This module keeps
its read-only import/participation boundary. No category-to-topic mapping or
attendance/capacity inference is added.

- `domain/external_activity.dart` owns strict public payloads, filter state,
  event/course/place kinds, bounded course schedules, published geometry,
  exact occurrences, complete server facets and observation freshness.
- `data/external_activity_gateway.dart` calls only canonical public list/detail
  V2 RPCs and translates an invalidated continuation into an explicit refresh.
- `application/external_activities_controller.dart` owns retained pages, filter
  resets and stale-request fencing. Construction does no IO; screens activate
  reads only while visible, enabled and foreground. No background polling.
- `presentation/external_activities_screen.dart` owns the main Activities route,
  server-side filters, backend-only refresh, native Tavoli entry and the explicit
  fictional preview action. Discipline options come from full-catalogue metadata.
- `presentation/external_activity_detail_screen.dart` shows public provenance,
  exact schedule values and observation times, then uses the shared validated
  external-link boundary. There are no joins, chats or native creator identities.
- `presentation/external_activity_share_actions.dart` reuses the existing OS
  clipboard/share adapter for the validated official source URL. Successful
  handoffs invoke the typed ACTMET01 tracker with only the canonical item ID;
  account, route, record replacement and Mock guards discard stale completions.
- `presentation/external_activity_widgets.dart` renders text-only cards and
  schedule labels. Dates without times stay dates; all-day ends are exclusive.

`activities_sandbox` retains its own example list, filters and detail. Its
fixtures are never a fallback here. The router and Settings keep the experiment
off by default. See the ACTAPI01 runbook for server contracts and activation.
ACTCAT02 extends those contracts without replacing the released event RPCs;
see [the V2 rollout and eligibility contract](../../../../../docs/development/actcat02-catalogue-contract.md).

ACTMET01 instruments only deliberate real catalogue card opens and successful
official-link copy/share handoffs. Rebuilds, external browser opening, examples
and Mock records emit nothing. Production analytics remains disabled; see the
[metrics guide](../../../../../docs/development/activity-interest-metrics.md).

ACTUI02: `presentation/external_activity_filters.dart` owns the one category/kind,
server discipline and date disclosure, ready for List/Map composition. Category
changes clear sports discipline; Culture clears a sports place lane; choosing a
place clears dates. Dates are an explicit exclusive-end window of at most 90
calendar dates and exclude undated places. Reset keeps the selected category.
Search, filters and scroll are RAM-only within the retained route; no history is
persisted or background fetching introduced. Examples are a secondary footer.

SPORTUI01 cards/details render known course terms and weekly rules without
computing next lessons locally. No supplied next session is explicit. Places
have source type/access text and no event date; unknown price is never free.
Optional typed `link_scope=dataset` changes the action to View source dataset;
missing scope keeps the compatible item action. The canonical source extension
in ACTSRC02 supplies this field; the UI never guesses from a URL or opens a
booking/join flow. D03 remains event-only. Unknown controlled discipline slugs
remain visible while known server facets use EN/IT labels.

ACTSRC02 V2 partial health retains readable healthy-source results and shows a
sanitized warning. It does not turn failure into an empty or fictional catalogue.
The V1 event API remains compatible; public source configuration stays private.

ACTGEO01: the gateway now uses the additive external V3 list with shared `GeoArea`,
explicit mapped-only scope and canonical namespaced/precision-safe distances.
Existing detail remains V2. Old clients retain V1/V2 readers. Controllers fence
account transitions, inactive state and stale continuations. This client requires
the V3 migration before live use; no production provider/source gate changes.

ACTMAP01: `application/external_map_session.dart` owns RAM-only camera/selection.
`presentation/external_activities_map_screen.dart` composes the shared public map,
clustering, loaded-entry chooser and existing scoped basemap caches. Mock Mode
draws demanded public imagery through MAPMOCK and keeps baseline warmup off. The second
result controller listens to the base filter authority; it owns no second filter
store. See `docs/development/activities-map.md` for routes, lifecycle, attribution,
no-provider behavior and reproducible qualification. The kind choice is a compact
native dropdown so 2x text does not duplicate the category chip hierarchy.
