# External activity catalogue

This feature reads PLANETS' licensed external catalogue under Activities Split
Mode. It never contacts providers, imports events or invokes native participation.

- `domain/external_activity.dart` owns strict public payloads, filter state,
  exact occurrences, source health and per-record observation freshness.
- `data/external_activity_gateway.dart` calls only canonical public list/detail
  RPCs and translates an invalidated continuation into an explicit refresh.
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

ACTMET01 instruments only deliberate real catalogue card opens and successful
official-link copy/share handoffs. Rebuilds, external browser opening, examples
and Mock records emit nothing. Production analytics remains disabled; see the
[metrics guide](../../../../../docs/development/activity-interest-metrics.md).
