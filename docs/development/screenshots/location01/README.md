# LOCATION01 visual fixtures

These PNGs show actual Flutter widgets with deterministic fake gateways, AppTheme,
Roboto and MaterialIcons from the local Flutter SDK. They do not show a physical
device or prove hosted/live-backend behavior. A separate local JWT/REST test and
SQL suite validate backend publication, participation/chat and privacy.

Capture parameters: 320 logical pixels wide, device ratio 1, PNG render ratio 2;
820 logical pixels high at normal text, 1000 at 2x. Lookup is disabled, canonical
location is empty and precise instructions are absent. Detail is a sanitized
public fixture with Trento and `exact_location_restricted=false`. Synthetic
English skill/description data is intentionally independent of the UI locale.

| State                      | Italian                            | English                            |
| -------------------------- | ---------------------------------- | ---------------------------------- |
| Collapsed, normal text     | [IT](it-1x-collapsed.png)          | [EN](en-1x-collapsed.png)          |
| Expanded, normal text      | [IT](it-1x-expanded.png)           | [EN](en-1x-expanded.png)           |
| Collapsed, 2x text         | [IT](it-2x-collapsed.png)          | [EN](en-2x-collapsed.png)          |
| Expanded, 2x text          | [IT](it-2x-expanded.png)           | [EN](en-2x-expanded.png)           |
| Published city-only detail | [IT](it-published-city-detail.png) | [EN](en-published-city-detail.png) |

A temporary widget capture test reused the proposal editor test harness and
public detail screen, wrapped the app in RepaintBoundary and exported PNGs with
`toImage(pixelRatio: 2)` outside the fake async clock. Six capture cases passed;
the temporary generator was removed. Permanent behavior/layout regression tests
remain in the editor, location fallback, participation and chat test suites.
Physical Android serial 48091FDAS0041A and iOS were not exercised or modified.
