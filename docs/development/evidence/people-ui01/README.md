# PEOPLE-UI01 widget evidence

Captured on 2026-10-11 from the real shared `CreatorParticipationScreen` and
`ProjectPersonTile`, using deterministic test gateways and the repository theme.
These are Flutter-rendered widget captures, not mockups or native-device evidence.
All images are 320dp wide, rendered at 2 physical pixels per dp.

- `en-light-1.0x-empty.png`: screenshot scenario, creator only, 0/5 participant
  spots used, 1 organizer excluded from capacity; empty requests/offers and no
  history or self menu.
- `it-dark-2.0x-empty.png`: same scenario in Italian with 2x text.
- `en-light-1.0x-populated-roster.png`: independently visible requests/offers,
  current people with organizer/member overlap and wrapping roles, past history.
- `it-dark-2.0x-populated-roster.png`: long name, multiple roles and menus at 2x.
- `it-light-2.0x-populated.png`: full-width applicant name below avatar/Block tools.

The populated fixture has a creator, a Co-creator who also has membership, and
one ordinary participant: 1/5 spots used, 2 organizers, 3 unique people. The role
offer targets the ordinary participant; a separate applicant has the join request.
The complete local capture matrix contains 24 PNGs (top and scrolled roster views)
across EN/IT, light/dark, empty/populated and normal/2x text. Inspected wraps,
clipping, header separation and roster hierarchy. Test elevation shadows may
appear as solid outlines; this does not change the production theme.

To reproduce from `apps/mobile`, run
`flutter test test/features/participation/presentation/project_people_screen_test.dart`
with `--dart-define=PEOPLE_UI_CAPTURE_DIR=<absolute-output-directory>` and
`--dart-define=PEOPLE_UI_FONT_DIR=<flutter-sdk>/bin/cache/artifacts/material_fonts`.
The font directory supplies the SDK's Roboto and Material Icons fonts.

The tests also cover independent keyset paging/retries, role visibility and
navigation for Projects and Tavoli, full/unset capacity, keyboard menu activation,
section/count semantics, refresh and guarded Close. Existing real participation
flow tests cover triage, offer acceptance, membership/delegate/contribution actions
and the display-name disclosure before joining. Native Android/iOS and manual
TalkBack/voice QA remain unrun; no device installs or external deployment occurred.
