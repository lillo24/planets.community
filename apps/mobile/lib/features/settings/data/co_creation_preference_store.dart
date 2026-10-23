import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const coCreationPreferenceStorageKey = 'planets.sandbox.coCreation';

abstract interface class CoCreationPreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesCoCreationPreferenceStore
    implements CoCreationPreferenceStore {
  SharedPreferencesCoCreationPreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() =>
      _preferences.getString(coCreationPreferenceStorageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(coCreationPreferenceStorageKey, value);
}

final coCreationPreferenceStoreProvider = Provider<CoCreationPreferenceStore>(
  (ref) => SharedPreferencesCoCreationPreferenceStore(),
  dependencies: const [],
);
