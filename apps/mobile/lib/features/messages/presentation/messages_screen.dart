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
import '../../participation/domain/participation_models.dart';
import '../../project_chat/application/project_chat_controllers.dart';
import '../../project_chat/domain/project_chat_models.dart';
import '../../project_chat/presentation/project_chat_failure_message.dart';
import '../application/messages_controllers.dart';
import '../domain/message_models.dart';
import 'messages_failure_message.dart';
import 'messages_routes.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late final String? _expectedProfileId;
  late final ProjectChatListController _chatListController;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    _chatListController = ref.read(projectChatListProvider.notifier);
    Future<void>.microtask(_loadAll);
  }

  @override
  void dispose() {
    _chatListController.stopSignals();
    super.dispose();
  }

  bool get _hasExpectedIdentity =>
      _expectedProfileId != null &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;

  Future<void> _loadAll() async {
    await Future.wait([_loadChats(), _loadRequests()]);
  }

  Future<void> _loadChats() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _chatListController.load(profileId, refresh: true);
    if (!mounted || !_hasExpectedIdentity) return;
    _chatListController.startSignals(profileId);
  }

  Future<void> _loadMoreChats() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _chatListController.loadMore(profileId);
  }

  Future<void> _loadRequests() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await ref
        .read(messagesInboxProvider.notifier)
        .load(profileId, refresh: true);
  }

  Future<void> _loadMoreRequests() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await ref.read(messagesInboxProvider.notifier).loadMore(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.messagesTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.messagesChatsTab, icon: const Icon(Icons.forum)),
              Tab(
                text: l10n.messagesRequestsTab,
                icon: const Icon(Icons.mark_email_unread_outlined),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _ChatsTab(
                expectedProfileId: _expectedProfileId,
                onRefresh: _loadChats,
                onLoadMore: _loadMoreChats,
              ),
              _RequestsTab(
                expectedProfileId: _expectedProfileId,
                onRefresh: _loadRequests,
                onLoadMore: _loadMoreRequests,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab({
    required this.expectedProfileId,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final String? expectedProfileId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectChatListProvider);
    final belongs = state.expectedProfileId == expectedProfileId;
    final items = belongs ? state.items : const <ProjectChatSummary>[];
    final initialLoading =
        !belongs ||
        (state.phase == ProjectChatListPhase.loading && items.isEmpty);

    if (initialLoading) return LoadingState(message: l10n.projectChatsLoading);
    if (state.phase == ProjectChatListPhase.failure && items.isEmpty) {
      return ErrorState(
        message: projectChatFailureMessage(l10n, state.failure!),
        onRetry: onRefresh,
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                title: l10n.projectChatsEmptyTitle,
                message: l10n.projectChatsEmptyMessage,
                icon: Icons.forum_outlined,
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        key: const Key('project-chat-list'),
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount:
            items.length +
            (state.failure != null ? 1 : 0) +
            (state.hasMore ? 1 : 0) +
            (state.hasConnectionIssue ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.hasConnectionIssue && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.projectChatConnectionIssue,
                  key: const Key('project-chat-list-connection-issue'),
                ),
              ),
            );
          }
          var itemIndex = index - (state.hasConnectionIssue ? 1 : 0);
          if (state.failure != null && itemIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  projectChatFailureMessage(l10n, state.failure!),
                  key: const Key('project-chat-list-inline-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          itemIndex -= state.failure != null ? 1 : 0;
          if (itemIndex == items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
              child: OutlinedButton(
                key: const Key('project-chats-load-more'),
                onPressed: state.isBusy ? null : onLoadMore,
                child: state.phase == ProjectChatListPhase.loadingMore
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.messagesLoadMore),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: _ProjectChatCard(summary: items[itemIndex]),
          );
        },
      ),
    );
  }
}

class _ProjectChatCard extends StatelessWidget {
  const _ProjectChatCard({required this.summary});

  final ProjectChatSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = summary.lastVisibleSenderDisplayName;
    final preview = summary.lastVisibleMessageBody;
    return Card(
      key: Key('project-chat-item-${summary.chatId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(projectChatRoute(summary.chatId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.projectTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    key: summary.isReadOnly
                        ? const Key('project-chat-former-chip')
                        : Key('project-chat-role-${summary.chatId}'),
                    visualDensity: VisualDensity.compact,
                    avatar: summary.isReadOnly
                        ? const Icon(Icons.lock_outline, size: 18)
                        : null,
                    label: Text(
                      summary.isReadOnly
                          ? l10n.projectChatReadOnlyLabel
                          : summary.isCreator
                          ? l10n.projectChatRoleCreator
                          : l10n.projectChatRoleCurrent,
                    ),
                  ),
                ],
              ),
              Text(messageProjectKindLabel(l10n, summary.projectKind)),
              const SizedBox(height: AppSpacing.small),
              Text(
                preview == null
                    ? l10n.projectChatNoMessages
                    : sender == null
                    ? preview
                    : l10n.projectChatPreview(sender, preview),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.messagesUpdatedAt(
                  messageDate(context, summary.activityAt),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({
    required this.expectedProfileId,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final String? expectedProfileId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(messagesInboxProvider);
    final belongs = state.expectedProfileId == expectedProfileId;
    final items = belongs
        ? state.items
        : const <ParticipationRequestMessageItem>[];
    final initialLoading =
        !belongs ||
        (state.phase == MessagesInboxPhase.loading && items.isEmpty);

    if (initialLoading) return LoadingState(message: l10n.messagesLoading);
    if (state.phase == MessagesInboxPhase.failure && items.isEmpty) {
      return ErrorState(
        message: messagesFailureMessage(l10n, state.failure!),
        onRetry: onRefresh,
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                title: l10n.messagesEmptyTitle,
                message: l10n.messagesEmptyMessage,
                icon: Icons.mail_outline,
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount:
            items.length +
            (state.failure != null ? 1 : 0) +
            (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.failure != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  messagesFailureMessage(l10n, state.failure!),
                  key: const Key('messages-inline-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          final itemIndex = index - (state.failure != null ? 1 : 0);
          if (itemIndex == items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
              child: OutlinedButton(
                key: const Key('messages-load-more'),
                onPressed: state.isBusy ? null : onLoadMore,
                child: state.phase == MessagesInboxPhase.loadingMore
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.messagesLoadMore),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: _MessageCard(item: items[itemIndex]),
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.item});

  final ParticipationRequestMessageItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = item.viewerRole == MessageViewerRole.creator
        ? l10n.messagesIncomingTitle(item.requesterDisplayName)
        : l10n.messagesOutgoingTitle(item.projectTitle);
    final preview = item.requestMessage ?? l10n.messagesNoRequestMessage;
    return Card(
      key: Key('message-item-${item.requestId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(participationRequestMessageRoute(item.requestId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  _StatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                '${messageProjectKindLabel(l10n, item.projectKind)} · '
                '${item.projectTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.messagesUpdatedAt(messageDate(context, item.activityAt)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final JoinRequestStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
    label: messageStatusLabel(AppLocalizations.of(context), status),
    child: Chip(
      visualDensity: VisualDensity.compact,
      label: Text(messageStatusLabel(AppLocalizations.of(context), status)),
    ),
  );
}

String messageStatusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    switch (status) {
      JoinRequestStatus.pending => l10n.participationStatusPending,
      JoinRequestStatus.accepted => l10n.participationStatusAccepted,
      JoinRequestStatus.rejected => l10n.participationStatusRejected,
      JoinRequestStatus.withdrawn => l10n.participationStatusWithdrawn,
    };

String messageProjectKindLabel(AppLocalizations l10n, ProjectKind kind) =>
    switch (kind) {
      ProjectKind.oneTime => l10n.messagesProposal,
      ProjectKind.recurring => l10n.messagesTavolo,
    };

String messageDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
