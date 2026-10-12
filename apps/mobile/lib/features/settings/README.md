# Settings feature

This feature owns public app-level settings and links to existing account
preference surfaces. It does not own notification or profile data.

- `domain/language_preference.dart` defines the supported system, English, and
  Italian choices and their stable stored values.
- `data/language_preference_store.dart` persists the selected value locally
  under `planets.language.preference` with `SharedPreferencesAsync`.
- `application/language_preference_controller.dart` restores invalid, missing,
  or unreadable values as System default and publishes successful writes through
  Riverpod.
- `presentation/settings_screen.dart` provides `/settings` and the nested
  `/settings/language` selection screen. General contains Language; Account
  always exposes the legal Privacy Policy link. Notifications remains limited
  to ready signed-in profiles. Profile field visibility is edited through
  Profile > Edit profile, with no duplicate Settings editor shortcut.
- `domain/navigation_preference.dart` defines typed Messages/Browse choices
  and the recoverable preference state.
- `data/navigation_preference_store.dart` persists the bottom-right shortcut
  under `planets.navigation.bottomRight` with `SharedPreferencesAsync`.
- `application/navigation_preference_controller.dart` restores the shortcut
  and publishes it only after a successful write. It rejects overlapping saves.
- `presentation/navigation_selection_screen.dart` provides the public nested
  `/settings/navigation` selector and reports save failures for retry.

Bootstrap restores both preferences before `runApp` to avoid displaying a
transient wrong choice. Language read failures fall back to System default.
Navigation defaults to Messages for missing or unknown values. A navigation
read failure uses Messages while exposing a localized recovery message in
Settings; successfully saving either choice clears it. A write failure keeps
the prior in-memory choice and is reported with localized UI copy.

Navigation is an experimental device/app preference, independent of account
identity and retained through sign-out; it has no backend or account sync.
Settings ends with the Auth feature's shared destructive Sign out action for
every authenticated phase, including incomplete profiles. It remains public,
and signed-out users see no Sign out action.

Sandbox contains only the persistent bottom-right tab setting. Its label
explicitly describes its effect on real navigation; storage key, values,
default and `/settings/navigation` remain compatible. The separate Messages
preview and redundant real-Messages shortcut have been removed. Shared tutorial
examples remain tutorial-owned.

Ready signed-in users can open My Reports and Blocked Users from Account using
the existing protected Profile routes. These are pushed so Close/Back returns
to Settings. Their authorization and backend controllers are unchanged.

Debug builds alone expose the startup reset, strictly guarded by `kDebugMode`.
Sign-out and account deletion eligibility are unchanged.

Optional real-font visual captures use `UIFIX02_CAPTURE_DIR` and
`UIFIX02_CAPTURE_FONTS` (Flutter SDK `bin/cache/artifacts/material_fonts`). Run
`flutter test test/features/settings/presentation/settings_screen_test.dart
--plain-name "2x Settings"` from `apps/mobile`. Normal tests write no images.

Profile-ready owners see Public Profile Visibility in Account, separately from
the Privacy Policy. The nested protected screen is owned by `profile`; guest
and incomplete sessions redirect to Settings without loading visibility. This
adds no policy-consent gating to Settings or its legal links.
