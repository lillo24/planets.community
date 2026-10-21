import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/co_creation_preference_store.dart';
import '../domain/co_creation_preference.dart';

Future<CoCreationPreferenceState> restoreCoCreationPreference(
  CoCreationPreferenceStore store,
) async {
  try {
    return CoCreationPreferenceState(
      mode: CoCreationMode.fromStorage(await store.read()),
    );
  } catch (_) {
    // Local storage is an application boundary. The experiment fails closed;
    // Settings exposes the failed read and permits recovery by saving again.
    return const CoCreationPreferenceState(restoreFailed: true);
  }
}

final initialCoCreationPreferenceProvider = Provider<CoCreationPreferenceState>(
  (ref) => const CoCreationPreferenceState(),
  dependencies: const [],
);

class CoCreationPreferenceController
    extends Notifier<CoCreationPreferenceState> {
  var _isSaving = false;

  @override
  CoCreationPreferenceState build() =>
      ref.read(initialCoCreationPreferenceProvider);

  Future<bool> select(CoCreationMode mode) async {
    if (_isSaving) return false;
    _isSaving = true;
    try {
      await ref
          .read(coCreationPreferenceStoreProvider)
          .write(mode.storageValue);
      if (!ref.mounted) return false;
      state = CoCreationPreferenceState(mode: mode);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
    }
  }
}

final coCreationPreferenceProvider =
    NotifierProvider<CoCreationPreferenceController, CoCreationPreferenceState>(
      CoCreationPreferenceController.new,
      dependencies: [
        initialCoCreationPreferenceProvider,
        coCreationPreferenceStoreProvider,
      ],
    );
