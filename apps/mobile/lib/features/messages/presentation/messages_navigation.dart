import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class MessagesFrame extends ConsumerStatefulWidget {
  const MessagesFrame({required this.chats, required this.requests, super.key});

  final Widget chats;
  final Widget requests;

  @override
  ConsumerState<MessagesFrame> createState() => _MessagesFrameState();
}

class _MessagesFrameState extends ConsumerState<MessagesFrame>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: ref.read(messagesNavigationProvider).tabIndex,
    )..addListener(_rememberTab);
  }

  void _rememberTab() =>
      ref.read(messagesNavigationProvider.notifier).selectTab(_tabs.index);

  @override
  void dispose() {
    _tabs.removeListener(_rememberTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messagesTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              key: const Key('messages-tab-chat'),
              text: l10n.messagesChatsTab,
              icon: const Icon(Icons.forum),
            ),
            Tab(
              key: const Key('messages-tab-requests'),
              text: l10n.messagesRequestsTab,
              icon: const Icon(Icons.mark_email_unread_outlined),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [widget.chats, widget.requests],
        ),
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
