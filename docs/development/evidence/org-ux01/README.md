# ORG-UX01 rendered evidence

Captured 2026-10-11 using the actual Manage Project, Project Team, Participant
Links and Group Info Flutter widgets, repository themes, SDK Roboto/Material
fonts and synthetic test gateways. No shared backend reads or writes are used.

The 72 PNGs cover the four screens at 320×800 logical/physical pixels in EN/IT,
light/dark, 1×/2× text, and empty/populated fixtures (64 initial viewports), plus
eight scrolled Team invitation views. Filenames encode each case. “Empty” means
no delegates/invitations/current participant link/workspace and no organizer
membership; “populated” adds two delegates, one bearer invitation, a current
reusable participant link and a workspace. Group Info's organizer is deliberately
not a participant, so it shows no invented commitments. Full existing flow tests
cover current/past commitments and actual contributions separately.

Inspect the initial and scrolled views together: 2× text legitimately requires
vertical scrolling, while labels and actions remain reachable without horizontal
overflow. Test elevation shadows may appear as outlines. These are Flutter engine
renders, not mockups, native-device screenshots or manual accessibility evidence.

From `apps/mobile`, reproduce with:

```powershell
flutter test --dart-define=ORG_UX01_CAPTURE_DIR=../../docs/development/evidence/org-ux01 test/features/project_delegates/presentation/project_organization_layout_test.dart
```

The optional directory enables PNG output and font loading from the SDK's engine
artifact directory. Normal CI writes no screenshots. The test matrix checks all
64 layouts, scrolling, routes for all manager roles and both Project kinds,
history paging, create/share/replace, local retry, current/former entitlement,
lazy meeting access, workspace loading/error and the landscape invitation handoff.

Required validation: `npm run check:mobile` plus the affected hosted Mobile job
and aggregate validation on the final PR head. Physical Android/iOS,
TalkBack/VoiceOver and real OS clipboard/share-sheet QA remain unrun. A temporary
fake-gateway Chrome harness was used for a live hot reload; it is not a backend or
native-device qualification and is not shipped.
