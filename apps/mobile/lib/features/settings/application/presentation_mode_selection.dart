import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activities_split_preference.dart';
import '../domain/co_creation_preference.dart';
import 'activities_split_preference_controller.dart';
import 'co_creation_preference_controller.dart';

/// One serialized selection across the two existing preferences. Disable the
/// other presentation first: failed persistence can never enable both modes.
/// Mock realm selection is independent and is not changed by this controller.
class PresentationModeSelection extends Notifier<bool> {
  @override
  bool build() => false;
  Future<bool> select({required bool people, required bool enabled}) async {
    if (state) return false;
    state = true;
    try {
      if (enabled) {
        final disabled = people
            ? await ref
                  .read(activitiesSplitPreferenceProvider.notifier)
                  .select(ActivitiesSplitMode.off)
            : await ref
                  .read(coCreationPreferenceProvider.notifier)
                  .select(CoCreationMode.off);
        if (!disabled || !ref.mounted) return false;
      }
      return people
          ? await ref
                .read(coCreationPreferenceProvider.notifier)
                .select(enabled ? CoCreationMode.on : CoCreationMode.off)
          : await ref
                .read(activitiesSplitPreferenceProvider.notifier)
                .select(
                  enabled ? ActivitiesSplitMode.on : ActivitiesSplitMode.off,
                );
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final presentationModeSelectionProvider =
    NotifierProvider<PresentationModeSelection, bool>(
      PresentationModeSelection.new,
      dependencies: [
        activitiesSplitPreferenceProvider,
        coCreationPreferenceProvider,
      ],
    );
