# Activity interest (ACTMET01)

This feature owns two explicit, internal attention signals for real public
activities. It owns no attendance, registration, popularity or canonical domain
state. **Production transmission is disabled and SDK activation is blocked.**

- `domain/activity_interest_event.dart` owns the closed version-1 vocabulary,
  lowercase canonical UUID validation and immutable property allowlist. Only
  `tavolo` and `imported_activity` factories exist; the latter uses ACTAPI01's
  actual canonical catalogue ID. Fictional examples cannot be passed as IDs.
- `application/activity_interest_tracker.dart` owns independent configuration
  and denied-by-default permission providers, actor/readiness invalidation,
  short gesture deduplication, volume bounds, unconditional Mock exclusion and
  best-effort dispatch.
- `data/activity_interest_sink.dart` owns explicit delivery outcomes and the
  no-op sink.
- `data/posthog_activity_interest_sink.dart` owns the EU/manual-only adapter and
  the app-owned client requirements. There is **no installed production SDK
  client**. Its injected client is a test seam, not an assertion that the SDK
  exposes these options. Unsupported identity persistence fails closed.

The public Tavoli list calls the tracker from its Requested and ordinary card
callbacks. The ordinary `ProjectShareDialog` supplies a typed public Tavolo to
`ShareLinkButtons`; platform success, exact ordinary URL, account, route and
mode checks must pass before recording. Invitation controls leave this nullable
argument unset. No router observer or widget-build capture exists.

ACTAPI01's public external catalogue calls the same typed boundary on card taps.
Its detail-only Copy/Share controls reuse `projectInviteSharingProvider` for OS
handoffs of the validated official source URL. Public link opening is not a
share event. Mock controls are unavailable, and its card gestures emit nothing.

`test/support/fake_activity_interest.dart` provides an inspectable in-memory
sink and mutable test permission. Neither is used by production bootstrap.
See the [metrics and activation guide](../../../../../docs/development/activity-interest-metrics.md)
for boundaries, counts, SDK evidence and imported-catalogue integration.
