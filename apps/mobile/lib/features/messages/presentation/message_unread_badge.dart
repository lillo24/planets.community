import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/message_unread_controller.dart';
import '../domain/message_chat_models.dart';

class MessageUnreadBadge extends ConsumerWidget {
  const MessageUnreadBadge({
    required this.child,
    this.groups = false,
    this.selected = false,
    super.key,
  });
  final Widget child;
  final bool groups;
  final bool selected;
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
          backgroundColor: selected
              ? colors.inverseSurface
              : failed
              ? colors.errorContainer
              : colors.secondaryContainer,
          textColor: selected
              ? colors.onInverseSurface
              : failed
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
      selected: selected,
      child: child,
    );
  }
}

class MessageCountBadge extends StatelessWidget {
  const MessageCountBadge({
    required this.count,
    required this.label,
    required this.child,
    this.selected = false,
    super.key,
  });
  final int count;
  final String label;
  final Widget child;
  final bool selected;
  @override
  Widget build(BuildContext context) => count == 0
      ? child
      : Semantics(
          label: label,
          child: Badge(
            backgroundColor: selected
                ? Theme.of(context).colorScheme.inverseSurface
                : Theme.of(context).colorScheme.primary,
            textColor: selected
                ? Theme.of(context).colorScheme.onInverseSurface
                : Theme.of(context).colorScheme.onPrimary,
            label: Text(count > 99 ? '99+' : '$count'),
            child: child,
          ),
        );
}

/// Scope totals are complete canonical conversation counts, never page counts.
class MessageScopeLabel extends ConsumerWidget {
  const MessageScopeLabel({
    required this.scope,
    required this.label,
    super.key,
  });
  final MessageChatScope scope;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageUnreadProvider);
    final id = ref.watch(authSessionProvider).identity?.id;
    final belongs = id != null && id == state.profileId;
    final unavailable =
        belongs &&
        (state.failed ||
            state.disconnected ||
            state.stale ||
            state.summary == null);
    final count = !belongs
        ? 0
        : scope == MessageChatScope.private
        ? state.summary?.private ?? 0
        : state.summary?.groups ?? 0;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: unavailable
          ? '$label, ${l10n.messageUnreadUnavailable}'
          : count > 0
          ? '$label, ${l10n.messageUnreadConversations(count)}'
          : label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (unavailable || count > 0) ...[
            const SizedBox(width: 6),
            if (unavailable)
              Tooltip(
                message: l10n.messageUnreadUnavailable,
                child: const Text('?'),
              )
            else
              MessageInlineCount(
                count: count,
                label: l10n.messageUnreadConversations(count),
              ),
          ],
        ],
      ),
    );
  }
}

class MessageInlineCount extends StatelessWidget {
  const MessageInlineCount({
    required this.count,
    required this.label,
    super.key,
  });
  final int count;
  final String label;
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onPrimary),
          ),
        ),
      ),
    );
  }
}
