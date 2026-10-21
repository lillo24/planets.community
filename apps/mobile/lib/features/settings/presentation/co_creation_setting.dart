import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/co_creation_preference_controller.dart';
import '../domain/co_creation_preference.dart';

class CoCreationSetting extends ConsumerStatefulWidget {
  const CoCreationSetting({super.key});

  @override
  ConsumerState<CoCreationSetting> createState() => _CoCreationSettingState();
}

class _CoCreationSettingState extends ConsumerState<CoCreationSetting> {
  bool _saving = false;
  CoCreationMode? _failedMode;

  Future<void> _save(CoCreationMode mode) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failedMode = null;
    });
    final saved = await ref
        .read(coCreationPreferenceProvider.notifier)
        .select(mode);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failedMode = saved ? null : mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(coCreationPreferenceProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const Key('settings-co-creation'),
            title: Text(l.coCreationSetting),
            subtitle: Text(l.coCreationHelp),
            value: state.enabled,
            onChanged: _saving
                ? null
                : (enabled) =>
                      _save(enabled ? CoCreationMode.on : CoCreationMode.off),
          ),
          if (state.restoreFailed || _failedMode != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _failedMode != null
                        ? l.coCreationSaveError
                        : l.coCreationRestoreError,
                    key: const Key('co-creation-error'),
                    semanticsLabel: _failedMode != null
                        ? l.coCreationSaveError
                        : l.coCreationRestoreError,
                  ),
                  TextButton(
                    key: const Key('co-creation-retry'),
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
