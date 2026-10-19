import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activities_split_preference_store.dart';
import '../domain/activities_split_preference.dart';

Future<ActivitiesSplitPreferenceState> restoreActivitiesSplitPreference(
  ActivitiesSplitPreferenceStore store,
) async {
  try {
    return ActivitiesSplitPreferenceState(
      mode: ActivitiesSplitMode.fromStorage(await store.read()),
    );
  } catch (_) {
    // Local storage is an application boundary. The experiment fails closed;
    // Settings exposes the failed read and permits recovery by saving again.
    return const ActivitiesSplitPreferenceState(restoreFailed: true);
  }
}

final initialActivitiesSplitPreferenceProvider =
    Provider<ActivitiesSplitPreferenceState>(
      (ref) => const ActivitiesSplitPreferenceState(),
      dependencies: const [],
    );

class ActivitiesSplitPreferenceController
    extends Notifier<ActivitiesSplitPreferenceState> {
  var _isSaving = false;

  @override
  ActivitiesSplitPreferenceState build() =>
      ref.read(initialActivitiesSplitPreferenceProvider);

  Future<bool> select(ActivitiesSplitMode mode) async {
    if (_isSaving) return false;
    _isSaving = true;
    try {
      await ref
          .read(activitiesSplitPreferenceStoreProvider)
          .write(mode.storageValue);
      if (!ref.mounted) return false;
      state = ActivitiesSplitPreferenceState(mode: mode);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
    }
  }
}

final activitiesSplitPreferenceProvider =
    NotifierProvider<
      ActivitiesSplitPreferenceController,
      ActivitiesSplitPreferenceState
    >(
      ActivitiesSplitPreferenceController.new,
      dependencies: [
        initialActivitiesSplitPreferenceProvider,
        activitiesSplitPreferenceStoreProvider,
      ],
    );
