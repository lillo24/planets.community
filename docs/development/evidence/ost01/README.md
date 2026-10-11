# OST01 rendered widget evidence

These snapshots were inspected on 2026-10-11 after integrating main `c6a204e`.
They show the production Workshop widgets with `AppTheme.light` / `AppTheme.dark`
and the reviewed Repair Café manifest content: two skills, two needs, a bundled
cover, organization attribution and a localized Default badge.

- `catalog-it-360-light.png`: Italian narrow catalog and decoded bundled cover.
- `detail-it-360-light.png`: Italian narrow detail and honest example copy.
- `needs-en-360-dark.png`: English narrow dark detail, resource needs and actions.
- `detail-en-1024-light.png`: English wide detail.

Rendering used the `pumpWorkshop` test harness, its `themeOverride`, fake
authenticated gateways and the release manifest. A temporary local capture test
loaded Segoe UI as the test Roboto font and Flutter's Material Icons, decoded the
asset outside the fake clock, then captured each Scaffold at 1x text, 1000px
height and DPR 1. Eight IT/EN × 360/1024px × light/dark render journeys passed;
these four selected images were visually reviewed. They are evidence snapshots,
not platform golden baselines. The committed widget tests separately exercise
IT/EN at 320dp with 2x text, editable-draft navigation and unavailable states.

This is headless widget evidence. It does not establish physical-device,
TalkBack, installed Closed-testing build, shared staging or Play release QA.
