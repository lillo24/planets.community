import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/notifications_controllers.dart';
import 'notifications_failure_message.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  late final String? _expectedProfileId;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    await ref.read(notificationPreferencesProvider.notifier).load(profileId);
  }

  Future<void> _setEnabled(bool enabled) async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    final succeeded = await ref
        .read(notificationPreferencesProvider.notifier)
        .setParticipationInApp(expectedProfileId: profileId, enabled: enabled);
    if (!succeeded && mounted && _currentExpectedProfileId() != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).notificationsPreferenceUpdateError,
          ),
        ),
      );
    }
  }

  String? _currentExpectedProfileId() {
    final profileId = _expectedProfileId;
    return profileId != null &&
            ref.read(authSessionProvider).identity?.id == profileId
        ? profileId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notificationPreferencesProvider);
    final belongsToScreen = state.expectedProfileId == _expectedProfileId;
    final preference = belongsToScreen ? state.participation : null;
    final isInitialLoading =
        !belongsToScreen ||
        (state.phase == NotificationPreferencesPhase.loading &&
            preference == null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsSettingsTitle)),
      body: SafeArea(
        child: isInitialLoading
            ? LoadingState(message: l10n.notificationsPreferencesLoading)
            : state.phase == NotificationPreferencesPhase.failure &&
                  preference == null
            ? ErrorState(
                message: notificationsFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(
                    l10n.notificationsParticipationAlerts,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          notificationsFailureMessage(l10n, state.failure!),
                          key: const Key('notification-preferences-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  SwitchListTile(
                    key: const Key('participation-in-app-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.notificationsInApp),
                    value: preference!.inAppEnabled,
                    onChanged:
                        state.phase == NotificationPreferencesPhase.saving
                        ? null
                        : _setEnabled,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.notificationsPreferenceExplanation),
                ],
              ),
      ),
    );
  }
}
