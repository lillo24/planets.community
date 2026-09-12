import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/notifications_controllers.dart';
import '../domain/notification_models.dart';
import 'notification_copy.dart';
import 'notification_destination.dart';
import 'notifications_failure_message.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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
    await Future.wait([
      ref
          .read(notificationsInboxProvider.notifier)
          .load(profileId, refresh: true),
      ref
          .read(notificationsUnreadProvider.notifier)
          .load(profileId, refresh: true),
    ]);
  }

  Future<void> _loadMore() async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    await ref.read(notificationsInboxProvider.notifier).loadMore(profileId);
  }

  Future<void> _markAllRead() async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    final succeeded = await ref
        .read(notificationsInboxProvider.notifier)
        .markAllRead(profileId);
    if (!succeeded && mounted && _currentExpectedProfileId() != null) {
      _showSafeMutationFailure(markAll: true);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    final profileId = _currentExpectedProfileId();
    if (profileId == null) return;
    final router = GoRouter.of(context);
    final route = notificationDestinationRoute(notification);
    final outcome = await ref
        .read(notificationsInboxProvider.notifier)
        .prepareTap(expectedProfileId: profileId, notification: notification);
    if (!mounted || _currentExpectedProfileId() == null) return;
    if (outcome == NotificationTapOutcome.readFailed) {
      _showSafeMutationFailure();
    }
    if (outcome == NotificationTapOutcome.ready ||
        outcome == NotificationTapOutcome.readFailed) {
      if (route != null) router.go(route);
    }
  }

  String? _currentExpectedProfileId() {
    final profileId = _expectedProfileId;
    final session = ref.read(authSessionProvider);
    return profileId != null && session.identity?.id == profileId
        ? profileId
        : null;
  }

  void _showSafeMutationFailure({bool markAll = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          markAll
              ? AppLocalizations.of(context).notificationsMarkAllError
              : AppLocalizations.of(context).notificationsUpdateError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notificationsInboxProvider);
    final unreadState = ref.watch(notificationsUnreadProvider);
    final belongsToScreen = state.expectedProfileId == _expectedProfileId;
    final items = belongsToScreen ? state.items : const <AppNotification>[];
    final isInitialLoading =
        !belongsToScreen ||
        (state.phase == NotificationsInboxPhase.loading && items.isEmpty);
    final representedUnread = items.any((item) => item.isUnread);
    final authoritativeUnread =
        unreadState.expectedProfileId == _expectedProfileId &&
            unreadState.phase == NotificationsUnreadPhase.ready
        ? unreadState.count ?? 0
        : 0;
    final showMarkAll = representedUnread || authoritativeUnread > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (showMarkAll)
            IconButton(
              key: const Key('notifications-mark-all'),
              tooltip: l10n.notificationsMarkAllRead,
              onPressed: state.isMarkingAll ? null : _markAllRead,
              icon: state.isMarkingAll
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
            ),
          IconButton(
            key: const Key('notifications-open-preferences'),
            tooltip: l10n.notificationsSettingsTooltip,
            onPressed: () => context.push('/notifications/preferences'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: isInitialLoading
            ? LoadingState(message: l10n.notificationsLoading)
            : state.phase == NotificationsInboxPhase.failure && items.isEmpty
            ? ErrorState(
                message: notificationsFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : items.isEmpty
            ? RefreshIndicator(
                onRefresh: _load,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        title: l10n.notificationsEmptyTitle,
                        message: l10n.notificationsEmptyMessage,
                        icon: Icons.notifications_none,
                      ),
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  itemCount:
                      items.length +
                      (state.failure != null ? 1 : 0) +
                      (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.failure != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.small,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            notificationsFailureMessage(l10n, state.failure!),
                            key: const Key('notifications-inline-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      );
                    }
                    final itemIndex = index - (state.failure != null ? 1 : 0);
                    if (itemIndex == items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.medium,
                        ),
                        child: OutlinedButton(
                          key: const Key('notifications-load-more'),
                          onPressed: state.isLoading ? null : _loadMore,
                          child:
                              state.phase == NotificationsInboxPhase.loadingMore
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.notificationsLoadMore),
                        ),
                      );
                    }
                    final item = items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: _NotificationCard(
                        notification: item,
                        isPending: state.pendingReadIds.contains(
                          item.notificationId,
                        ),
                        onTap: () => _openNotification(item),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isPending,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = notificationCopy(l10n, notification);
    final route = notificationDestinationRoute(notification);
    final isInteractive =
        !isPending && (notification.isUnread || route != null);
    final readLabel = notification.isUnread
        ? l10n.notificationsUnread
        : l10n.notificationsRead;
    return Semantics(
      label: '$copy. $readLabel',
      button: isInteractive,
      excludeSemantics: true,
      child: Card(
        key: Key('notification-item-${notification.notificationId}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  notification.isUnread
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.small),
                      Row(
                        children: [
                          if (notification.isUnread)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.small,
                              ),
                              child: Text(
                                l10n.notificationsUnread,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              _notificationDate(
                                context,
                                notification.createdAt,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.small),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (route != null)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.small),
                    child: Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _notificationDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  final local = date.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
