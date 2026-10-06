import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/message_unread_controller.dart';

class MessageUnreadBadge extends ConsumerWidget {
  const MessageUnreadBadge({
    required this.child,
    this.groups = false,
    super.key,
  });
  final Widget child;
  final bool groups;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageUnreadProvider);
    final id = ref.watch(authSessionProvider).identity?.id;
    if (id == null || id != state.profileId) return child;
    final count = groups ? state.summary?.groups : state.summary?.total;
    final l10n = AppLocalizations.of(context);
    final stale = state.failed || state.disconnected || state.stale;
    if (stale || count == null) {
      final colors = Theme.of(context).colorScheme;
      final failed = state.failed || state.disconnected;
      return Tooltip(
        message: l10n.messageUnreadUnavailable,
        child: Badge(
          backgroundColor: failed
              ? colors.errorContainer
              : colors.secondaryContainer,
          textColor: failed
              ? colors.onErrorContainer
              : colors.onSecondaryContainer,
          label: const Text('?'),
          child: child,
        ),
      );
    }
    return MessageCountBadge(
      count: count,
      label: l10n.messageUnreadConversations(count),
      child: child,
    );
  }
}

class MessageCountBadge extends StatelessWidget {
  const MessageCountBadge({
    required this.count,
    required this.label,
    required this.child,
    super.key,
  });
  final int count;
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => count == 0
      ? child
      : Semantics(
          label: label,
          child: Badge(
            backgroundColor: Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context).colorScheme.onPrimary,
            label: Text(count > 99 ? '99+' : '$count'),
            child: child,
          ),
        );
}
