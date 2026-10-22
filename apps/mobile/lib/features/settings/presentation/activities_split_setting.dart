import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/activities_split_preference_controller.dart';
import '../domain/activities_split_preference.dart';
import '../application/co_creation_preference_controller.dart';
import '../application/presentation_mode_selection.dart';

class ActivitiesSplitSetting extends ConsumerStatefulWidget {
  const ActivitiesSplitSetting({super.key});

  @override
  ConsumerState<ActivitiesSplitSetting> createState() =>
      _ActivitiesSplitSettingState();
}

class _ActivitiesSplitSettingState
    extends ConsumerState<ActivitiesSplitSetting> {
  bool _saving = false;
  ActivitiesSplitMode? _failedMode;

  Future<void> _save(ActivitiesSplitMode mode) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failedMode = null;
    });
    final saved = await ref
        .read(presentationModeSelectionProvider.notifier)
        .select(people: false, enabled: mode == ActivitiesSplitMode.on);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failedMode = saved ? null : mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(activitiesSplitPreferenceProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const Key('settings-activities-split'),
            title: Text(l.activitiesSplitSetting),
            subtitle: Text(l.activitiesSplitHelp),
            value:
                state.enabled &&
                !ref.watch(coCreationPreferenceProvider).enabled,
            onChanged: _saving || ref.watch(presentationModeSelectionProvider)
                ? null
                : (enabled) => _save(
                    enabled ? ActivitiesSplitMode.on : ActivitiesSplitMode.off,
                  ),
          ),
          if (state.restoreFailed || _failedMode != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _failedMode != null
                        ? l.activitiesSplitSaveError
                        : l.activitiesSplitRestoreError,
                    key: const Key('activities-split-error'),
                    semanticsLabel: _failedMode != null
                        ? l.activitiesSplitSaveError
                        : l.activitiesSplitRestoreError,
                  ),
                  TextButton(
                    key: const Key('activities-split-retry'),
                    onPressed: _saving
                        ? null
                        : () => _save(_failedMode ?? state.mode),
                    child: Text(l.retryAction),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
