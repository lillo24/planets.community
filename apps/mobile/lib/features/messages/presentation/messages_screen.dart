import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/domain/visible_profile_photo_models.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../resource_listings/presentation/resource_listing_widgets.dart';
import '../../resource_requests/presentation/resource_request_widgets.dart';
import '../application/message_chats_controller.dart';
import '../application/message_unread_controller.dart';
import '../application/messages_controllers.dart';
import '../domain/message_chat_models.dart';
import '../domain/message_models.dart';
import 'message_chats_failure_message.dart';
import 'messages_formatters.dart';
import 'messages_failure_message.dart';
import 'messages_routes.dart';
import 'message_unread_badge.dart';
import 'participation_request_details.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with WidgetsBindingObserver {
  late final String? _expectedProfileId;
  late final MessageChatsController _privateChatListController;
  late final MessageChatsController _groupChatListController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    _privateChatListController = ref.read(messageChatsProvider.notifier);
    _groupChatListController = ref.read(groupMessageChatsProvider.notifier);
    Future<void>.microtask(_loadAll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privateChatListController.stopSignals();
    _groupChatListController.stopSignals();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profileId = _expectedProfileId;
    if (state == AppLifecycleState.resumed && profileId != null) {
      _privateChatListController.handleAppResumed(profileId);
      _groupChatListController.handleAppResumed(profileId);
    }
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
    await Future.wait([
      ref.read(messageUnreadProvider.notifier).refresh(profileId),
      _privateChatListController.load(profileId, refresh: true),
      _groupChatListController.load(profileId, refresh: true),
    ]);
    if (!mounted || !_hasExpectedIdentity) return;
    _privateChatListController.startSignals(profileId);
    _groupChatListController.startSignals(profileId);
  }

  Future<void> _loadMoreChats(MessageChatScope scope) async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await switch (scope) {
      MessageChatScope.private => _privateChatListController.loadMore(
        profileId,
      ),
      MessageChatScope.groups => _groupChatListController.loadMore(profileId),
    };
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

class _ChatsTab extends ConsumerStatefulWidget {
  const _ChatsTab({
    required this.expectedProfileId,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final String? expectedProfileId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(MessageChatScope scope) onLoadMore;

  @override
  ConsumerState<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<_ChatsTab> {
  var _scope = MessageChatScope.private;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = switch (_scope) {
      MessageChatScope.private => ref.watch(messageChatsProvider),
      MessageChatScope.groups => ref.watch(groupMessageChatsProvider),
    };
    final visiblePhotos = ref.watch(visibleProfilePhotoProvider);
    final belongs = state.expectedProfileId == widget.expectedProfileId;
    final items = belongs ? state.items : const <MessageChatItem>[];
    final initialLoading =
        !belongs || (state.phase == MessageChatsPhase.loading && items.isEmpty);

    return Column(
      children: [
        Padding(
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
                  label: MessageScopeLabel(
                    scope: MessageChatScope.private,
                    label: l10n.messageChatsPrivate,
                  ),
                ),
                ButtonSegment(
                  value: MessageChatScope.groups,
                  label: MessageScopeLabel(
                    scope: MessageChatScope.groups,
                    label: l10n.messageChatsGroups,
                  ),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (selection) {
                setState(() => _scope = selection.single);
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Expanded(
          child: initialLoading
              ? LoadingState(message: l10n.messageChatsLoading)
              : state.phase == MessageChatsPhase.failure && items.isEmpty
              ? ErrorState(
                  message: messageChatsFailureMessage(l10n, state.failure!),
                  onRetry: widget.onRefresh,
                )
              : items.isEmpty
              ? RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: EmptyState(
                          title: _scope == MessageChatScope.private
                              ? l10n.messageChatsPrivateEmptyTitle
                              : l10n.projectChatsEmptyTitle,
                          message: _scope == MessageChatScope.private
                              ? l10n.messageChatsPrivateEmptyMessage
                              : l10n.projectChatsEmptyMessage,
                          icon: _scope == MessageChatScope.private
                              ? Icons.lock_outline
                              : Icons.groups_outlined,
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    key: const Key('message-chat-list'),
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    itemCount:
                        items.length +
                        (state.failure != null ? 1 : 0) +
                        (state.hasMore ? 1 : 0) +
                        (state.hasConnectionIssue ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.hasConnectionIssue && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.small,
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              l10n.resourceChatConnectionIssue,
                              key: const Key(
                                'message-chat-list-connection-issue',
                              ),
                            ),
                          ),
                        );
                      }
                      var itemIndex =
                          index - (state.hasConnectionIssue ? 1 : 0);
                      if (state.failure != null && itemIndex == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.small,
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              messageChatsFailureMessage(l10n, state.failure!),
                              key: const Key('message-chat-list-inline-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      }
                      itemIndex -= state.failure != null ? 1 : 0;
                      if (itemIndex == items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.medium,
                          ),
                          child: OutlinedButton(
                            key: const Key('message-chats-load-more'),
                            onPressed: state.isBusy
                                ? null
                                : () => widget.onLoadMore(_scope),
                            child: state.phase == MessageChatsPhase.loadingMore
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.messagesLoadMore),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.small,
                        ),
                        child: _ChatCard(
                          item: items[itemIndex],
                          photoEntry: switch (items[itemIndex]) {
                            ProjectRequestMessageChatItem item =>
                              visiblePhotos.entryFor(
                                item.counterpartyProfileId,
                              ),
                            ResourceMessageChatItem item =>
                              visiblePhotos.entryFor(
                                item.counterpartyProfileId,
                              ),
                            ProjectMessageChatItem() => null,
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChatCard extends ConsumerWidget {
  const _ChatCard({required this.item, required this.photoEntry});
  final MessageChatItem item;
  final VisibleProfilePhotoEntry? photoEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewerId = ref.watch(authSessionProvider).identity?.id;
    final colors = Theme.of(context).colorScheme;
    final title = switch (item) {
      ProjectMessageChatItem i => i.displayTitle,
      ResourceMessageChatItem i => i.counterpartyDisplayName,
      ProjectRequestMessageChatItem i => i.counterpartyDisplayName,
    };
    final counterpartyId = switch (item) {
      ProjectMessageChatItem() => null,
      ResourceMessageChatItem i => i.counterpartyProfileId,
      ProjectRequestMessageChatItem i => i.counterpartyProfileId,
    };
    final preview = switch (item) {
      ProjectRequestMessageChatItem i
          when i.latestRequestActivityStatus != null =>
        messageRequestActivityLabel(l10n, i.latestRequestActivityStatus!),
      ProjectMessageChatItem i when i.latestSystemEventLabel != null =>
        l10n.projectNeedsSystemEvent(i.latestSystemEventLabel!),
      _ =>
        item.lastVisibleMessageBody == null
            ? item is ResourceMessageChatItem
                  ? l10n.resourceChatNoMessages
                  : l10n.projectChatNoMessages
            : item.lastVisibleSenderProfileId == viewerId
            ? l10n.messageOwnPreview(item.lastVisibleMessageBody!)
            : item.lastVisibleSenderProfileId != counterpartyId &&
                  item.lastVisibleSenderDisplayName != null
            ? l10n.projectChatPreview(
                item.lastVisibleSenderDisplayName!,
                item.lastVisibleMessageBody!,
              )
            : item.lastVisibleMessageBody!,
    };
    final (key, linkKey, route) = switch (item) {
      ProjectMessageChatItem i => (
        'project-chat-item-${i.chatId}',
        'project-chat-link-${i.chatId}',
        projectChatRoute(i.chatId),
      ),
      ResourceMessageChatItem i => (
        'resource-chat-item-${i.chatId}',
        'resource-chat-link-${i.chatId}',
        resourceChatRoute(i.chatId),
      ),
      ProjectRequestMessageChatItem i => (
        'project-request-chat-item-${i.chatId}',
        'project-request-chat-link-${i.requestId}',
        projectRequestChatRoute(i.requestId),
      ),
    };
    return Semantics(
      button: true,
      label: item is ProjectMessageChatItem
          ? l10n.messageProjectChatCardSemantics(title)
          : l10n.messagePrivateChatSemantics(title),
      child: Card(
        key: Key(key),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: item.unreadCount > 0
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          key: Key(linkKey),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item is! ProjectMessageChatItem) ...[
                    VisibleProfilePhotoAvatar(
                      key: Key(
                        '${item.kind == MessageChatItemKind.resourceChat ? 'resource' : 'project-request'}-chat-photo-${item.chatId}',
                      ),
                      entry: photoEntry,
                      imageSemanticsLabel: l10n
                          .resourceChatCounterpartyPhotoLabel(title),
                      placeholderSemanticsLabel: l10n
                          .resourceChatCounterpartyPhotoLabel(title),
                      radius: 20,
                    ),
                    const SizedBox(width: AppSpacing.small),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xSmall),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .29,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          messageActivityDate(context, item.activityAt),
                          key: Key('chat-time-${item.compositeId}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (item.unreadCount > 0) ...[
                          const SizedBox(height: AppSpacing.xSmall),
                          MessageInlineCount(
                            count: item.unreadCount,
                            label: l10n.messageUnreadMessages(item.unreadCount),
                          ),
                        ],
                      ],
                    ),
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
        : const <StructuredRequestMessageItem>[];
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
            child: _StructuredRequestCard(item: items[itemIndex]),
          );
        },
      ),
    );
  }
}

class _StructuredRequestCard extends StatelessWidget {
  const _StructuredRequestCard({required this.item});

  final StructuredRequestMessageItem item;

  @override
  Widget build(BuildContext context) => switch (item) {
    ParticipationRequestMessageItem item => _ParticipationRequestCard(
      item: item,
    ),
    ResourceRequestMessageItem item => _ResourceRequestCard(item: item),
  };
}

class _ParticipationRequestCard extends StatelessWidget {
  const _ParticipationRequestCard({required this.item});

  final ParticipationRequestMessageItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = item.viewerRole != MessageViewerRole.requester
        ? l10n.messagesIncomingTitle(item.requesterDisplayName)
        : l10n.messagesOutgoingTitle(item.projectTitle);
    final preview = item.requestMessage ?? l10n.messagesNoRequestMessage;
    return Card(
      key: Key('message-item-${item.requestId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showParticipationRequestDetailsSheet(
          context,
          requestId: item.requestId,
        ),
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

class _ResourceRequestCard extends StatelessWidget {
  const _ResourceRequestCard({required this.item});

  final ResourceRequestMessageItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = item.viewerRole == MessageViewerRole.owner
        ? l10n.resourceRequestInboxIncomingTitle(item.requesterDisplayName)
        : l10n.resourceRequestInboxOutgoingTitle(item.listingTitle);
    final preview = item.requestMessage ?? l10n.messagesNoRequestMessage;
    return Card(
      key: Key('resource-request-message-item-${item.requestId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('resource-request-message-link-${item.requestId}'),
        onTap: () => context.push(resourceRequestMessageRoute(item.requestId)),
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
                  ResourceRequestStatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                '${l10n.resourceRequestTypeLabel} · '
                '${resourceListingModeLabel(l10n, item.listingMode)} · '
                '${item.listingTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.viewerRole == MessageViewerRole.owner
                    ? l10n.resourceRequestRequesterLabel(
                        item.requesterDisplayName,
                      )
                    : l10n.resourceRequestOwnerLabel(item.ownerDisplayName),
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
