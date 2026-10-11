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
- `presentation/messages_preview_screen.dart` provides the public nested
  `/settings/messages-preview` Sandbox page. It reuses the fictional
  `MessageExamplePreview` and `MessageChatScopeToggle` presentation with local
  page state. It mounts no private Messages loaders or gateways, does not change
  the real Messages selection, and sends or saves nothing. Close and system
  Back return to Settings.

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

Sandbox contains Messages preview and the persistent bottom-right tab setting.
The setting's label explicitly describes its effect on real navigation; the
existing storage key, values, default and `/settings/navigation` route remain
compatible. The safe preview is public in debug and normal release builds,
including closed testing; it is deliberately outside the `kDebugMode` gate.

When Browse replaces the Messages shortcut, Sandbox also
contains a distinct Open real Messages row (including the existing ready-user unread badge).
It goes to `/messages` and preserves the shell's three branches. Debug builds
alone expose the narrowly scoped [startup reset](../../app/startup/README.md),
still guarded strictly by `kDebugMode`. Sandbox does not expose seeds or other
privileged development tools. Sign-out and account deletion eligibility are
unchanged.

The narrow, large-text journey also covers the distinct real Messages link.
Its empty Chats/Requests states use a minimum viewport height, allowing long
localized content to grow inside the existing refreshable scroll view.

For optional local visual captures, set `UIFIX02_CAPTURE_DIR` to a task-owned
output directory and `UIFIX02_CAPTURE_FONTS` to the Flutter SDK's
`bin/cache/artifacts/material_fonts` directory, then run
`flutter test test/features/settings/presentation/settings_screen_test.dart
--plain-name "2x Settings and preview"` from `apps/mobile`. Without these
variables the tests use normal deterministic test fonts and write no images.
