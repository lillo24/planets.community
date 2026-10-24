# CP01 — Community-first navigation

Scope derived from the 2026-10-24 Community / Project consolidation plan on
`d1e4581b`. The router owns `/people`; it now renders the existing categorized
Community directory, retaining the first-entry illustration and replay. The
directory exposes existing hub, General, numbered group, support and category-bound
Community proposal flows. Home's Community proposal card opens that directory so
the user selects an eligible category before composing.

No primary directory link opens People-post discovery, compose, mine or demo.
Exact legacy post, compose, mine, contact and exit routes remain unchanged pending
CP04's inventory. Database gates, eligibility, activation thresholds and native
Project routes retain their existing contracts. UIAUDIT02 and A1 have separate
unmerged working copies; their files were not used as dependency bases.

Acceptance: IT/EN Home actions, 320dp and 2x text, actual root router/intro with
server gate OFF, categorized proposal/support/activation and nested General/group
journeys, legacy exact exit routes, and Mock realm routing. Run `flutter gen-l10n`,
`dart format --output=none --set-exit-if-changed lib test test_support`,
`flutter analyze` and the affected Flutter suites before merge.

Rollback: revert the CP01 commit. No schema, data or hosted configuration changes
are required. Repository integration does not activate a hosted gate or release.
