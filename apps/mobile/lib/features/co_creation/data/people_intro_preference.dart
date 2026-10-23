import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Installation-local illustration state, independent of startup and identity.
const peopleIntroSeenStorageKey = 'planets.coCreation.interestsIntroSeen.v1';

abstract interface class PeopleIntroPreferenceStore {
  Future<bool> readSeen();
  Future<void> markSeen();
}

class SharedPreferencesPeopleIntroStore implements PeopleIntroPreferenceStore {
  SharedPreferencesPeopleIntroStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> readSeen() async =>
      await _preferences.getBool(peopleIntroSeenStorageKey) ?? false;

  @override
  Future<void> markSeen() =>
      _preferences.setBool(peopleIntroSeenStorageKey, true);
}

final peopleIntroPreferenceStoreProvider = Provider<PeopleIntroPreferenceStore>(
  (ref) => SharedPreferencesPeopleIntroStore(),
  dependencies: const [],
);

/// Presentation only: a failed disk write must not repeatedly interrupt browsing
/// within this process. The failure is still surfaced by the entry screen.
class PeopleIntroSession extends Notifier<bool> {
  @override
  bool build() => false;

  bool claim() {
    if (state) return false;
    state = true;
    return true;
  }
}

final peopleIntroSessionProvider = NotifierProvider<PeopleIntroSession, bool>(
  PeopleIntroSession.new,
  dependencies: const [],
);
