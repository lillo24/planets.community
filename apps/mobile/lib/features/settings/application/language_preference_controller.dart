import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/language_preference_store.dart';
import '../domain/language_preference.dart';

Future<LanguagePreference> restoreLanguagePreference(
  LanguagePreferenceStore store,
) async {
  try {
    return LanguagePreference.fromStorage(await store.read());
  } catch (_) {
    return LanguagePreference.system;
  }
}

final initialLanguagePreferenceProvider = Provider<LanguagePreference>(
  (ref) => LanguagePreference.system,
  dependencies: const [],
);

class LanguagePreferenceController extends Notifier<LanguagePreference> {
  var _revision = 0;

  @override
  LanguagePreference build() {
    ref.onDispose(() => _revision++);
    return ref.read(initialLanguagePreferenceProvider);
  }

  Future<bool> select(LanguagePreference preference) async {
    final revision = ++_revision;
    try {
      await ref
          .read(languagePreferenceStoreProvider)
          .write(preference.storageValue);
    } catch (_) {
      return false;
    }
    if (!ref.mounted || revision != _revision) {
      return false;
    }
    state = preference;
    return true;
  }
}

final languagePreferenceProvider =
    NotifierProvider<LanguagePreferenceController, LanguagePreference>(
      LanguagePreferenceController.new,
      dependencies: [
        initialLanguagePreferenceProvider,
        languagePreferenceStoreProvider,
      ],
    );
