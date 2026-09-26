import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/notifications_controllers.dart';
import '../domain/notification_models.dart';
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

  Future<void> _setEnabled({
    required NotificationCategory category,
    required bool enabled,
  }) async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    final controller = ref.read(notificationPreferencesProvider.notifier);
    final succeeded = switch (category) {
      NotificationCategory.participation =>
        await controller.setParticipationInApp(
          expectedProfileId: profileId,
          enabled: enabled,
        ),
      NotificationCategory.chat => await controller.setChatInApp(
        expectedProfileId: profileId,
        enabled: enabled,
      ),
      NotificationCategory.resources => await controller.setResourcesInApp(
        expectedProfileId: profileId,
        enabled: enabled,
      ),
      NotificationCategory.matching => await controller.setMatchingInApp(
        expectedProfileId: profileId,
        enabled: enabled,
      ),
      NotificationCategory.unknown => false,
    };
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
    final participation = belongsToScreen ? state.participation : null;
    final chat = belongsToScreen ? state.chat : null;
    final resources = belongsToScreen ? state.resources : null;
    final matching = belongsToScreen ? state.matching : null;
    final isInitialLoading =
        !belongsToScreen ||
        (state.phase == NotificationPreferencesPhase.loading &&
            (participation == null ||
                chat == null ||
                resources == null ||
                matching == null));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsSettingsTitle)),
      body: SafeArea(
        child: isInitialLoading
            ? LoadingState(message: l10n.notificationsPreferencesLoading)
            : state.phase == NotificationPreferencesPhase.failure &&
                  (participation == null ||
                      chat == null ||
                      resources == null ||
                      matching == null)
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
                    value: participation!.inAppEnabled,
                    onChanged:
                        state.phase == NotificationPreferencesPhase.saving
                        ? null
                        : (enabled) => _setEnabled(
                            category: NotificationCategory.participation,
                            enabled: enabled,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.notificationsPreferenceExplanation),
                  const SizedBox(height: AppSpacing.large),
                  const Divider(),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    l10n.notificationsChatMessages,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  SwitchListTile(
                    key: const Key('chat-in-app-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.notificationsInApp),
                    value: chat!.inAppEnabled,
                    onChanged:
                        state.phase == NotificationPreferencesPhase.saving
                        ? null
                        : (enabled) => _setEnabled(
                            category: NotificationCategory.chat,
                            enabled: enabled,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.notificationsChatPreferenceExplanation),
                  const SizedBox(height: AppSpacing.large),
                  const Divider(),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.notificationsResourceActivity,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  SwitchListTile(
                    key: const Key('resources-in-app-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.notificationsInApp),
                    value: resources!.inAppEnabled,
                    onChanged:
                        state.phase == NotificationPreferencesPhase.saving
                        ? null
                        : (enabled) => _setEnabled(
                            category: NotificationCategory.resources,
                            enabled: enabled,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.notificationsResourcePreferenceExplanation),
                  const SizedBox(height: AppSpacing.large),
                  const Divider(),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.notificationsMatchingAlerts,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  SwitchListTile(
                    key: const Key('matching-in-app-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.notificationsMatchingInApp),
                    value: matching!.inAppEnabled,
                    onChanged:
                        state.phase == NotificationPreferencesPhase.saving
                        ? null
                        : (enabled) => _setEnabled(
                            category: NotificationCategory.matching,
                            enabled: enabled,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.notificationsMatchingPreferenceExplanation),
                ],
              ),
      ),
    );
  }
}
