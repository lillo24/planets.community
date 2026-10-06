import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/navigation_preference_store.dart';
import '../domain/navigation_preference.dart';

Future<NavigationPreferenceState> restoreNavigationPreference(
  NavigationPreferenceStore store,
) async {
  try {
    return NavigationPreferenceState(
      destination: BottomTabDestination.fromStorage(await store.read()),
    );
  } catch (_) {
    // Navigation remains usable; Settings reports the failed read and allows
    // the user to recover by saving a choice.
    return const NavigationPreferenceState(restoreFailed: true);
  }
}

final initialNavigationPreferenceProvider = Provider<NavigationPreferenceState>(
  (ref) => const NavigationPreferenceState(),
  dependencies: const [],
);

class NavigationPreferenceController
    extends Notifier<NavigationPreferenceState> {
  var _isSaving = false;

  @override
  NavigationPreferenceState build() =>
      ref.read(initialNavigationPreferenceProvider);

  Future<bool> select(BottomTabDestination destination) async {
    if (_isSaving) return false;
    _isSaving = true;
    try {
      await ref
          .read(navigationPreferenceStoreProvider)
          .write(destination.storageValue);
      if (!ref.mounted) return false;
      state = NavigationPreferenceState(destination: destination);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
    }
  }
}

final navigationPreferenceProvider =
    NotifierProvider<NavigationPreferenceController, NavigationPreferenceState>(
      NavigationPreferenceController.new,
      dependencies: [
        initialNavigationPreferenceProvider,
        navigationPreferenceStoreProvider,
      ],
    );
