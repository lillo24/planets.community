import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../messages/presentation/message_read_viewport.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../messages/application/messages_controllers.dart';
import '../../messages/domain/message_models.dart';
import '../data/project_request_chat_gateway.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../messages/presentation/participation_request_details.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/join_acceptance_triage_sheet.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../application/project_request_chat_controller.dart';
import '../domain/project_request_chat_models.dart';
import 'project_request_chat_failure_message.dart';

class ProjectRequestChatScreen extends ConsumerStatefulWidget {
  const ProjectRequestChatScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<ProjectRequestChatScreen> createState() =>
      _ProjectRequestChatScreenState();
}

class _ProjectRequestChatScreenState
    extends ConsumerState<ProjectRequestChatScreen>
    with WidgetsBindingObserver {
  late final String? _expectedProfileId;
  late final ProjectRequestChatController _controller;
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  var _didInitialScroll = false;
  var _isResolving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    _controller = ref.read(projectRequestChatProvider.notifier);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stopSignals();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profileId = _expectedProfileId;
    if (state == AppLifecycleState.resumed && profileId != null) {
      _controller.handleAppResumed(profileId, widget.requestId);
    }
  }

  bool get _hasExpectedIdentity =>
      _expectedProfileId != null &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;

  Future<void> _load() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    final loaded = await _controller.load(
      expectedProfileId: profileId,
      requestId: widget.requestId,
    );
    if (!mounted || !_hasExpectedIdentity) return;
    if (!loaded) {
      final details = ref.read(messagesDetailProvider.notifier);
      final authorized = await details.load(
        expectedProfileId: profileId,
        requestId: widget.requestId,
      );
      if (!mounted || !_hasExpectedIdentity) return;
      final item = ref.read(messagesDetailProvider).item;
      if (authorized &&
          item?.requestId == widget.requestId &&
          item?.viewerRole == MessageViewerRole.delegate) {
        context.go(participationRequestMessageRoute(widget.requestId));
        return;
      }
    }
    _controller.startSignals(profileId, widget.requestId);
  }

  Future<void> _refresh() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _controller.refresh(
      expectedProfileId: profileId,
      requestId: widget.requestId,
    );
  }

  Future<void> _loadOlder() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final loaded = await _controller.loadOlder(
      expectedProfileId: profileId,
      requestId: widget.requestId,
    );
    if (!loaded || !mounted || !_hasExpectedIdentity) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasExpectedIdentity || !_scrollController.hasClients) {
        return;
      }
      final addedExtent =
          _scrollController.position.maxScrollExtent - oldExtent;
      _scrollController.jumpTo(oldOffset + addedExtent);
    });
  }

  Future<void> _send() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    final sent = await _controller.send(
      expectedProfileId: profileId,
      requestId: widget.requestId,
      body: _composer.text,
    );
    if (!sent || !mounted || !_hasExpectedIdentity) return;
    _composer.clear();
    _scrollToBottom();
  }

  Future<void> _showDetails(String requestId) async {
    if (!_hasExpectedIdentity) return;
    await showParticipationRequestDetailsSheet(context, requestId: requestId);
    if (mounted && _hasExpectedIdentity) await _refreshAfterResolution();
  }

  Future<void> _accept(ProjectRequestChatRequestItem summary) async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        !_hasExpectedIdentity ||
        summary.requesterProfileId == profileId ||
        _isResolving) {
      return;
    }
    setState(() => _isResolving = true);
    try {
      await showJoinAcceptanceTriageSheet(
        context,
        expectedManagerProfileId: profileId,
        requestId: summary.requestId,
        projectId: summary.projectId,
        projectKind: summary.projectKind,
        requesterDisplayName: summary.requesterDisplayName,
      );
      if (mounted && _hasExpectedIdentity) await _refreshAfterResolution();
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _reject(ProjectRequestChatRequestItem summary) async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        !_hasExpectedIdentity ||
        summary.requesterProfileId == profileId ||
        _isResolving) {
      return;
    }
    setState(() => _isResolving = true);
    try {
      final details = ref.read(messagesDetailProvider.notifier);
      final loaded = await details.load(
        expectedProfileId: profileId,
        requestId: summary.requestId,
      );
      if (loaded &&
          _hasExpectedIdentity &&
          ref.read(messagesDetailProvider).requestId == summary.requestId) {
        await details.reject();
      }
      if (mounted && _hasExpectedIdentity) await _refreshAfterResolution();
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _refreshAfterResolution() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _controller.refresh(
      expectedProfileId: profileId,
      requestId: widget.requestId,
    );
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    ref.read(projectChatRefreshProvider.notifier).notifyChanged();
    await ref
        .read(messagesInboxProvider.notifier)
        .load(profileId, refresh: true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasExpectedIdentity || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectRequestChatProvider);
    final belongs =
        state.expectedProfileId == _expectedProfileId &&
        state.requestId == widget.requestId;
    final summary = belongs ? state.summary : null;
    final items = belongs ? state.items : const <ProjectRequestChatFeedItem>[];
    final visiblePhotos = ref.watch(visibleProfilePhotoProvider);
    final counterpartyPhoto = summary == null
        ? null
        : visiblePhotos.entryFor(summary.counterpartyProfileId);

    ref.listen(projectRequestChatProvider, (previous, next) {
      final ready =
          next.expectedProfileId == _expectedProfileId &&
          next.requestId == widget.requestId &&
          next.phase == ProjectRequestChatPhase.ready;
      if (ready && !_didInitialScroll) {
        _didInitialScroll = true;
        _scrollToBottom();
      }
    });

    return MessageReadViewport(
      profileId: _expectedProfileId,
      kind: 'project_request_chat',
      chatId: summary?.chatId,
      boundary:
          belongs &&
              state.phase == ProjectRequestChatPhase.ready &&
              state.failure == null
          ? state.readBoundary
          : null,
      scrollController: _scrollController,
      child: Scaffold(
        appBar: pageAppBar(
          context,
          title: summary == null
              ? Text(l10n.projectRequestChatTitle)
              : Row(
                  children: [
                    VisibleProfilePhotoAvatar(
                      key: const Key('project-request-chat-counterparty-photo'),
                      entry: counterpartyPhoto,
                      imageSemanticsLabel: l10n
                          .resourceChatCounterpartyPhotoLabel(
                            summary.counterpartyDisplayName,
                          ),
                      placeholderSemanticsLabel: l10n
                          .resourceChatCounterpartyPhotoLabel(
                            summary.counterpartyDisplayName,
                          ),
                      radius: 18,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        summary.counterpartyDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
        body: SafeArea(
          child:
              !belongs ||
                  (state.phase == ProjectRequestChatPhase.loading &&
                      items.isEmpty)
              ? LoadingState(message: l10n.projectRequestChatLoading)
              : state.phase == ProjectRequestChatPhase.failure && items.isEmpty
              ? ErrorState(
                  message: projectRequestChatFailureMessage(
                    l10n,
                    state.failure!,
                  ),
                  onRetry: _load,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          // Keep transcript/composer space when text or the
                          // keyboard makes the pending banner taller.
                          maxHeight: constraints.maxHeight * .45,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (summary != null)
                                _RequestStatusBanner(
                                  expectedProfileId: _expectedProfileId!,
                                  summary: summary,
                                  isResolving: _isResolving,
                                  onOpenDetails: _showDetails,
                                  onReject: _reject,
                                  onAccept: _accept,
                                ),
                              if (state.hasConnectionIssue)
                                _Notice(
                                  key: const Key(
                                    'project-request-chat-connection-issue',
                                  ),
                                  text: l10n.projectRequestChatConnectionIssue,
                                  isError: true,
                                ),
                              if (state.failure case final failure?)
                                _Notice(
                                  key: const Key(
                                    'project-request-chat-inline-error',
                                  ),
                                  text: projectRequestChatFailureMessage(
                                    l10n,
                                    failure,
                                  ),
                                  isError: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView(
                            key: const Key('project-request-chat-history'),
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.medium),
                            children: [
                              if (state.hasMoreOlder)
                                Center(
                                  child: OutlinedButton(
                                    key: const Key(
                                      'project-request-chat-load-older',
                                    ),
                                    onPressed: state.isLoadingOlder
                                        ? null
                                        : _loadOlder,
                                    child: state.isLoadingOlder
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            l10n.projectRequestChatLoadOlder,
                                          ),
                                  ),
                                ),
                              if (items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xLarge,
                                  ),
                                  child: Text(
                                    l10n.projectRequestChatEmpty,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                for (final item in items)
                                  switch (item) {
                                    ProjectRequestChatRequestItem request =>
                                      _StructuredRequestCard(
                                        key: ValueKey(request.canonicalKey),
                                        item: request,
                                        isMine:
                                            request.requesterProfileId ==
                                            _expectedProfileId,
                                        highlighted:
                                            request.requestId ==
                                            widget.requestId,
                                        onOpenDetails: () =>
                                            _showDetails(request.requestId),
                                        onOpenGroup: (chatId) {
                                          if (_hasExpectedIdentity) {
                                            context.push(
                                              projectChatRoute(chatId),
                                            );
                                          }
                                        },
                                      ),
                                    ProjectRequestChatHumanMessage message =>
                                      _MessageBubble(
                                        key: ValueKey(message.canonicalKey),
                                        message: message,
                                        onOpenDetails: () {
                                          if (message.requestId
                                              case final requestId?) {
                                            _showDetails(requestId);
                                          }
                                        },
                                        isMine:
                                            message.senderProfileId ==
                                            _expectedProfileId,
                                      ),
                                  },
                            ],
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .4,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (summary != null &&
                                  !items.any(
                                    (item) =>
                                        item is ProjectRequestChatRequestItem &&
                                        item.requestId == widget.requestId,
                                  ))
                                TextButton(
                                  onPressed: () =>
                                      _showDetails(widget.requestId),
                                  child: Text(
                                    l10n.pairReferencedRequest(
                                      summary.projectTitle,
                                    ),
                                  ),
                                ),
                              if (summary?.hasSendEntitlement == true)
                                _Composer(
                                  controller: _composer,
                                  isSending: state.isSending,
                                  onSend: _send,
                                )
                              else if (summary != null)
                                _Notice(
                                  key: const Key(
                                    'project-request-chat-read-only',
                                  ),
                                  text: l10n.pairChatReadOnlyReactivation,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RequestStatusBanner extends ConsumerStatefulWidget {
  const _RequestStatusBanner({
    required this.summary,
    required this.expectedProfileId,
    required this.isResolving,
    required this.onOpenDetails,
    required this.onReject,
    required this.onAccept,
  });
  final ProjectRequestChatSummary summary;
  final String expectedProfileId;
  final bool isResolving;
  final void Function(String requestId) onOpenDetails;
  final void Function(ProjectRequestChatRequestItem request) onReject;
  final void Function(ProjectRequestChatRequestItem request) onAccept;
  @override
  ConsumerState<_RequestStatusBanner> createState() =>
      _RequestStatusBannerState();
}

class _RequestStatusBannerState extends ConsumerState<_RequestStatusBanner> {
  List<ProjectRequestChatRequestItem> _older = const [];
  bool _loading = false;
  bool _failed = false;
  int _revision = 0;
  @override
  void didUpdateWidget(covariant _RequestStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary ||
        oldWidget.expectedProfileId != widget.expectedProfileId) {
      _revision++;
      _older = const [];
      _loading = false;
      _failed = false;
    }
  }

  Future<void> _loadMore() async {
    final items = [...widget.summary.pendingRequests, ..._older];
    if (_loading || items.isEmpty) return;
    final revision = ++_revision;
    final identity = widget.expectedProfileId;
    final chatId = widget.summary.chatId;
    final boundary = items.last;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref
          .read(projectRequestChatGatewayProvider)
          .listItems(
            expectedProfileId: identity,
            chatId: chatId,
            limit: 30,
            onlyPending: true,
            cursor: ProjectRequestChatFeedCursor(
              createdAt: boundary.createdAt,
              itemKind: boundary.itemKind,
              itemId: boundary.itemId,
            ),
          );
      if (!mounted ||
          revision != _revision ||
          ref.read(authSessionProvider).identity?.id != identity) {
        return;
      }
      if (page.items.any(
        (item) =>
            item is! ProjectRequestChatRequestItem ||
            item.chatId != chatId ||
            item.requestStatus != JoinRequestStatus.pending,
      )) {
        throw const FormatException('Invalid pending requests page.');
      }
      setState(() {
        _older = [
          ..._older,
          ...page.items.cast<ProjectRequestChatRequestItem>(),
        ];
      });
    } catch (_) {
      if (mounted &&
          revision == _revision &&
          ref.read(authSessionProvider).identity?.id == identity) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [...widget.summary.pendingRequests, ..._older];
    if (widget.summary.pendingCount == 0) return const SizedBox.shrink();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Column(
              key: Key('pending-request-${item.requestId}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.projectTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: AppSpacing.small,
                  children: [
                    TextButton(
                      key: Key('pair-pending-details-${item.requestId}'),
                      onPressed: () => widget.onOpenDetails(item.requestId),
                      child: Text(l10n.projectRequestChatViewDetails),
                    ),
                    if (item.requesterProfileId !=
                        widget.expectedProfileId) ...[
                      OutlinedButton(
                        key: Key('pair-reject-${item.requestId}'),
                        onPressed: widget.isResolving
                            ? null
                            : () => widget.onReject(item),
                        child: Text(l10n.participationReject),
                      ),
                      FilledButton(
                        key: Key('pair-accept-${item.requestId}'),
                        onPressed: widget.isResolving
                            ? null
                            : () => widget.onAccept(item),
                        child: Text(l10n.participationAccept),
                      ),
                    ] else
                      TextButton(
                        key: Key('pair-withdraw-${item.requestId}'),
                        onPressed: () => widget.onOpenDetails(item.requestId),
                        child: Text(l10n.participationWithdraw),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (items.length < widget.summary.pendingCount)
          TextButton(
            onPressed: _loading ? null : _loadMore,
            child: Text(
              _failed ? l10n.retryAction : l10n.projectRequestChatLoadOlder,
            ),
          ),
      ],
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: widget.summary.pendingCount == 1
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pairPendingRequests(widget.summary.pendingCount),
                    key: const Key('project-request-chat-status-banner'),
                  ),
                  content,
                ],
              ),
            )
          : ExpansionTile(
              key: const Key('project-request-chat-status-banner'),
              title: Text(
                l10n.pairPendingRequests(widget.summary.pendingCount),
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(child: content),
                ),
              ],
            ),
    );
  }
}

class _StructuredRequestCard extends StatelessWidget {
  const _StructuredRequestCard({
    required this.item,
    required this.isMine,
    required this.highlighted,
    required this.onOpenDetails,
    required this.onOpenGroup,
    super.key,
  });
  final ProjectRequestChatRequestItem item;
  final bool isMine;
  final bool highlighted;
  final VoidCallback onOpenDetails;
  final ValueChanged<String> onOpenGroup;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * .82).clamp(
              0.0,
              360.0,
            ),
          ),
          child: Container(
            key: Key('pair-request-${item.requestId}'),
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: isMine
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? colors.primary : colors.outline,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: isMine ? colors.onPrimaryContainer : colors.onSurface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.projectRequestChatRequestCardTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${messageProjectKindLabel(l10n, item.projectKind)} · ${item.projectTitle}',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(item.requestMessage ?? l10n.messagesNoRequestMessage),
                  const SizedBox(height: AppSpacing.small),
                  Text(messageStatusLabel(l10n, item.requestStatus)),
                  Text(
                    _formatDate(context, item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    l10n.pairRequestAudience,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    key: Key('pair-details-${item.requestId}'),
                    onPressed: onOpenDetails,
                    child: Text(l10n.projectRequestChatViewDetails),
                  ),
                  if (item.acceptedProjectGroupChatId case final group?)
                    TextButton.icon(
                      key: Key('pair-group-${item.requestId}'),
                      onPressed: () => onOpenGroup(group),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(l10n.projectRequestChatOpenGroup),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onOpenDetails,
    super.key,
  });

  final ProjectRequestChatHumanMessage message;
  final bool isMine;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = isMine
        ? l10n.projectRequestChatYou
        : message.senderDisplayName ?? l10n.projectRequestChatUnknownSender;
    final time = _formatDate(context, message.createdAt);
    return Semantics(
      label: l10n.projectRequestChatMessageSemantics(
        sender,
        message.body,
        time,
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              key: Key('project-request-chat-message-${message.itemId}'),
              margin: EdgeInsets.zero,
              color: isMine
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    if (message.isLegacy) ...[
                      Text(
                        l10n.pairLegacyHistory,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: onOpenDetails,
                        child: Text(l10n.projectRequestChatViewDetails),
                      ),
                    ],
                    Text(message.body),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(time, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.small,
          AppSpacing.small,
          AppSpacing.small,
          // Scaffold already reserves the keyboard inset.
          AppSpacing.small,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('project-request-chat-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: projectRequestChatMessageMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.projectRequestChatMessageHint,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xSmall),
            IconButton.filled(
              key: const Key('project-request-chat-send'),
              tooltip: l10n.projectRequestChatSend,
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = false, super.key});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.small),
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(text),
    ),
  );
}

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
