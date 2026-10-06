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
  `/settings/language` selection screen. Account rows link to their existing
  feature routes and appear only for a ready signed-in profile.
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

The PLANETS notices account row links to moderation's protected
`/settings/notices` child, preserving Settings as the Back destination. Settings
does not fetch/cache reasons, infer restrictions or bypass Auth's suspension gate.
