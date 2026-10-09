import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_command_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_status.dart';
import '../domain/message_chat_models.dart';
import 'messages_navigation.dart';
import 'messages_screen.dart';

/// Only /messages is public. Mount private loaders solely for a ready identity;
/// descendants still use router protection and repository read boundaries.
class MessagesLandingScreen extends ConsumerWidget {
  const MessagesLandingScreen({this.controlsOnly = false, super.key});

  /// Tutorial presentation: real navigation with no private list mounts/reads.
  final bool controlsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final l10n = AppLocalizations.of(context);
    if (session.phase == AuthSessionPhase.ready && controlsOnly) {
      final scope = ref.watch(messagesNavigationProvider).scope;
      return MessagesFrame(
        controlsOnly: controlsOnly,
        chats: ListView(
          children: [
            MessageChatScopeToggle(
              scope: scope,
              onChanged: ref
                  .read(messagesNavigationProvider.notifier)
                  .selectScope,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Text(l10n.tutorialMessagesPreview),
            ),
          ],
        ),
        requests: Center(child: Text(l10n.tutorialMessagesPreview)),
      );
    }
    if (session.phase == AuthSessionPhase.ready) {
      return MessagesScreen(key: ValueKey(session.identity!.id));
    }
    if (session.phase == AuthSessionPhase.signedOut ||
        session.phase == AuthSessionPhase.profileSetupRequired) {
      final scope = ref.watch(messagesNavigationProvider).scope;
      return MessagesFrame(
        controlsOnly: controlsOnly,
        key: const Key('messages-context-screen'),
        chats: controlsOnly
            ? ListView(
                children: [
                  MessageChatScopeToggle(
                    scope: scope,
                    onChanged: ref
                        .read(messagesNavigationProvider.notifier)
                        .selectScope,
                  ),
                  const _MessagesAccessState(),
                ],
              )
            : Column(
                children: [
                  MessageChatScopeToggle(
                    scope: scope,
                    onChanged: ref
                        .read(messagesNavigationProvider.notifier)
                        .selectScope,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Expanded(child: _MessagesAccessState(scope: scope)),
                ],
              ),
        requests: const _MessagesAccessState(),
      );
    }
    return MessagesFrame(
      key: const Key('messages-context-screen'),
      controlsOnly: controlsOnly,
      chats: const _ScrollableContext(child: AuthStatus()),
      requests: const _ScrollableContext(child: AuthStatus()),
    );
  }
}

/// Guest/setup states never watch private Messages or photo providers.
class _MessagesAccessState extends ConsumerWidget {
  const _MessagesAccessState({this.scope});

  final MessageChatScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final busy = ref.watch(authCommandProvider.select((state) => state.isBusy));
    final l10n = AppLocalizations.of(context);
    final signedOut = session.phase == AuthSessionPhase.signedOut;
    final message = signedOut
        ? switch (scope) {
            MessageChatScope.private => l10n.messagesGuestPrivateMessage,
            MessageChatScope.groups => l10n.messagesGuestGroupsMessage,
            null => l10n.messagesGuestRequestsMessage,
          }
        : session.hasProfileAnchor
        ? l10n.profileSetupRequired
        : l10n.authProfileSetupFailure;
    return _ScrollableContext(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            key: Key('messages-access-${scope?.name ?? 'requests'}'),
            title: scope == null
                ? l10n.messagesGuestRequestsTitle
                : l10n.messagesGuestChatsTitle,
            message: message,
            icon: switch (scope) {
              MessageChatScope.private => Icons.lock_outline,
              MessageChatScope.groups => Icons.groups_outlined,
              null => Icons.mark_email_unread_outlined,
            },
          ),
          FilledButton(
            key: const Key('messages-context-action'),
            onPressed: busy
                ? null
                : () {
                    if (!signedOut && !session.hasProfileAnchor) {
                      ref
                          .read(authCommandProvider.notifier)
                          .retryProfileSetup();
                      return;
                    }
                    context.push(
                      Uri(
                        path: signedOut ? '/auth' : '/profile/edit',
                        queryParameters: const {'returnTo': '/messages'},
                      ).toString(),
                    );
                  },
            child: Text(
              signedOut
                  ? l10n.welcomeLogin
                  : session.hasProfileAnchor
                  ? l10n.profileSetupAction
                  : l10n.retryAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableContext extends StatelessWidget {
  const _ScrollableContext({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: child,
      ),
    ),
  );
}
