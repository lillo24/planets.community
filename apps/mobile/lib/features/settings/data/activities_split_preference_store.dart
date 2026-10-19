import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const activitiesSplitPreferenceStorageKey = 'planets.sandbox.activitiesSplit';

abstract interface class ActivitiesSplitPreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesActivitiesSplitPreferenceStore
    implements ActivitiesSplitPreferenceStore {
  SharedPreferencesActivitiesSplitPreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() =>
      _preferences.getString(activitiesSplitPreferenceStorageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(activitiesSplitPreferenceStorageKey, value);
}

final activitiesSplitPreferenceStoreProvider =
    Provider<ActivitiesSplitPreferenceStore>(
      (ref) => SharedPreferencesActivitiesSplitPreferenceStore(),
      dependencies: const [],
    );
