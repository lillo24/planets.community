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

The bootstrap layer restores the noncritical preference before `runApp` to avoid
a normal-start language flash. Read failures fall back to System default. A write
failure keeps the prior in-memory choice and is reported with localized UI copy.
