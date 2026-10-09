import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/message_chat_models.dart';

/// Presentation choices only: no identity, content, counts or persistence.
/// Kept in memory so Auth cancellation/completion can rebuild the root frame.
final messagesNavigationProvider =
    NotifierProvider<MessagesNavigation, MessagesNavigationSelection>(
      MessagesNavigation.new,
    );

class MessagesNavigationSelection {
  const MessagesNavigationSelection({
    this.tabIndex = 0,
    this.scope = MessageChatScope.private,
  });

  /// 0 is the Chats root; 1 is the secondary Requests inbox.
  final int tabIndex;
  final MessageChatScope scope;
}

class MessagesNavigation extends Notifier<MessagesNavigationSelection> {
  @override
  MessagesNavigationSelection build() => const MessagesNavigationSelection();

  void selectTab(int index) {
    if (state.tabIndex == index) return;
    state = MessagesNavigationSelection(tabIndex: index, scope: state.scope);
  }

  void selectScope(MessageChatScope scope) {
    state = MessagesNavigationSelection(tabIndex: state.tabIndex, scope: scope);
  }
}

/// Data-free frame shared by guest/setup presentation and ready Messages.
class MessagesFrame extends ConsumerWidget {
  const MessagesFrame({
    required this.chats,
    required this.requests,
    this.controlsOnly = false,
    super.key,
  });

  final Widget chats;
  final bool controlsOnly;
  final Widget requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requestsOpen =
        !controlsOnly && ref.watch(messagesNavigationProvider).tabIndex == 1;
    void returnToChats() =>
        ref.read(messagesNavigationProvider.notifier).selectTab(0);
    return PopScope(
      canPop: !requestsOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && requestsOpen) returnToChats();
      },
      child: Scaffold(
        appBar: pageAppBar(
          context,
          automaticallyImplyClose: false,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              requestsOpen ? l10n.messagesRequestsTab : l10n.messagesTitle,
            ),
          ),
          actions: requestsOpen
              ? [
                  TextButton(
                    key: const Key('messages-return-chats'),
                    onPressed: returnToChats,
                    child: Text(l10n.messagesChatsTab),
                  ),
                ]
              : [
                  IconButton(
                    key: const Key('messages-requests-action'),
                    tooltip: l10n.messagesRequestsTab,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    // A tour preview keeps the real control visible without
                    // changing the remembered destination behind the tour.
                    onPressed: controlsOnly
                        ? () {}
                        : () => ref
                              .read(messagesNavigationProvider.notifier)
                              .selectTab(1),
                    icon: const Icon(Icons.inbox_outlined),
                  ),
                ],
        ),
        body: SafeArea(child: requestsOpen ? requests : chats),
      ),
    );
  }
}

class MessageChatScopeToggle extends StatelessWidget {
  const MessageChatScopeToggle({
    required this.scope,
    required this.onChanged,
    this.privateLabel,
    this.groupsLabel,
    super.key,
  });

  final MessageChatScope scope;
  final ValueChanged<MessageChatScope> onChanged;
  final Widget? privateLabel;
  final Widget? groupsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<MessageChatScope>(
          key: const Key('message-chat-scope-toggle'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MessageChatScope.private,
              label: KeyedSubtree(
                key: const Key('message-chat-scope-private'),
                child: privateLabel ?? Text(l10n.messageChatsPrivate),
              ),
            ),
            ButtonSegment(
              value: MessageChatScope.groups,
              label: KeyedSubtree(
                key: const Key('message-chat-scope-groups'),
                child: groupsLabel ?? Text(l10n.messageChatsGroups),
              ),
            ),
          ],
          selected: {scope},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
      ),
    );
  }
}
