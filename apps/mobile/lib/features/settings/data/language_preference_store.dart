import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const languagePreferenceStorageKey = 'planets.language.preference';

abstract interface class LanguagePreferenceStore {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesLanguagePreferenceStore
    implements LanguagePreferenceStore {
  SharedPreferencesLanguagePreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() =>
      _preferences.getString(languagePreferenceStorageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(languagePreferenceStorageKey, value);
}

final languagePreferenceStoreProvider = Provider<LanguagePreferenceStore>(
  (ref) => SharedPreferencesLanguagePreferenceStore(),
  dependencies: const [],
);
