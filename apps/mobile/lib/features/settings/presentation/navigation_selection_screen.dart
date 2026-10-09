import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/navigation_preference_controller.dart';
import '../domain/navigation_preference.dart';

class NavigationSelectionScreen extends ConsumerStatefulWidget {
  const NavigationSelectionScreen({super.key});

  @override
  ConsumerState<NavigationSelectionScreen> createState() =>
      _NavigationSelectionScreenState();
}

class _NavigationSelectionScreenState
    extends ConsumerState<NavigationSelectionScreen> {
  var _isSaving = false;

  Future<void> _select(BottomTabDestination destination) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final saved = await ref
        .read(navigationPreferenceProvider.notifier)
        .select(destination);
    if (!mounted) return;
    if (saved) {
      context.pop();
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).settingsNavigationSaveError),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(navigationPreferenceProvider);

    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.settingsBottomRightTab)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: RadioGroup<BottomTabDestination>(
              // A failed restore has no confirmed saved choice. Let either
              // option (including the Messages fallback) recover the setting.
              groupValue: preference.restoreFailed
                  ? null
                  : preference.destination,
              onChanged: (value) {
                if (value != null) _select(value);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(l10n.settingsNavigationHelp),
                  if (preference.restoreFailed)
                    Text(
                      l10n.settingsNavigationRestoreError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  RadioListTile<BottomTabDestination>(
                    key: const Key('navigation-messages-option'),
                    value: BottomTabDestination.messages,
                    title: Text(l10n.messagesTitle),
                    enabled: !_isSaving,
                  ),
                  RadioListTile<BottomTabDestination>(
                    key: const Key('navigation-browse-option'),
                    value: BottomTabDestination.browse,
                    title: Text(l10n.navigationBrowse),
                    enabled: !_isSaving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
