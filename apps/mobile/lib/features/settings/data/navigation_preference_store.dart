import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navigationPreferenceStorageKey = 'planets.navigation.bottomRight';

abstract interface class NavigationPreferenceStore {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesNavigationPreferenceStore
    implements NavigationPreferenceStore {
  SharedPreferencesNavigationPreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() =>
      _preferences.getString(navigationPreferenceStorageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(navigationPreferenceStorageKey, value);
}

final navigationPreferenceStoreProvider = Provider<NavigationPreferenceStore>(
  (ref) => SharedPreferencesNavigationPreferenceStore(),
  dependencies: const [],
);
