import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../messages/application/messages_controllers.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../messages/presentation/participation_request_details.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/join_acceptance_triage_sheet.dart';
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
    await _controller.load(
      expectedProfileId: profileId,
      requestId: widget.requestId,
    );
    if (!mounted || !_hasExpectedIdentity) return;
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
    if (!loaded || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
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
    if (!sent || !mounted) return;
    _composer.clear();
    _scrollToBottom();
  }

  Future<void> _showDetails() async {
    await showParticipationRequestDetailsSheet(
      context,
      requestId: widget.requestId,
    );
    if (mounted) await _refreshAfterResolution();
  }

  Future<void> _accept(ProjectRequestChatSummary summary) async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        !_hasExpectedIdentity ||
        summary.viewerRole != ProjectRequestChatViewerRole.creator ||
        _isResolving) {
      return;
    }
    setState(() => _isResolving = true);
    try {
      await showJoinAcceptanceTriageSheet(
        context,
        expectedCreatorProfileId: profileId,
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

  Future<void> _reject(ProjectRequestChatSummary summary) async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        !_hasExpectedIdentity ||
        summary.viewerRole != ProjectRequestChatViewerRole.creator ||
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
      if (loaded) await details.reject();
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
      if (!mounted || !_scrollController.hasClients) return;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary?.counterpartyDisplayName ?? l10n.projectRequestChatTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                message: projectRequestChatFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : Column(
                children: [
                  if (summary != null)
                    _RequestStatusBanner(
                      summary: summary,
                      isResolving: _isResolving,
                      onOpenDetails: _showDetails,
                      onReject: () => _reject(summary),
                      onAccept: () => _accept(summary),
                    ),
                  if (state.hasConnectionIssue)
                    _Notice(
                      key: const Key('project-request-chat-connection-issue'),
                      text: l10n.projectRequestChatConnectionIssue,
                      isError: true,
                    ),
                  if (state.failure case final failure?)
                    _Notice(
                      key: const Key('project-request-chat-inline-error'),
                      text: projectRequestChatFailureMessage(l10n, failure),
                      isError: true,
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
                                    : Text(l10n.projectRequestChatLoadOlder),
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
                                    item: request,
                                    onOpenDetails: _showDetails,
                                  ),
                                ProjectRequestChatHumanMessage message =>
                                  _MessageBubble(
                                    message: message,
                                    isMine:
                                        message.senderProfileId ==
                                        _expectedProfileId,
                                  ),
                              },
                        ],
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
                      key: const Key('project-request-chat-read-only'),
                      text: l10n.projectRequestChatReadOnly,
                    ),
                ],
              ),
      ),
    );
  }
}

class _RequestStatusBanner extends StatelessWidget {
  const _RequestStatusBanner({
    required this.summary,
    required this.isResolving,
    required this.onOpenDetails,
    required this.onReject,
    required this.onAccept,
  });

  final ProjectRequestChatSummary summary;
  final bool isResolving;
  final VoidCallback onOpenDetails;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = summary.requestStatus == JoinRequestStatus.pending;
    final creator = summary.viewerRole == ProjectRequestChatViewerRole.creator;
    final (title, body, icon) = switch (summary.requestStatus) {
      JoinRequestStatus.pending => (
        l10n.participationRequestPending,
        creator
            ? l10n.projectRequestChatPendingCreator(
                summary.requesterDisplayName,
                summary.projectTitle,
              )
            : l10n.projectRequestChatPendingRequester(summary.projectTitle),
        Icons.schedule,
      ),
      JoinRequestStatus.accepted => (
        l10n.projectRequestChatAcceptedTitle,
        l10n.projectRequestChatAcceptedBody(summary.projectTitle),
        Icons.check_circle_outline,
      ),
      JoinRequestStatus.rejected => (
        l10n.projectRequestChatRejectedTitle,
        l10n.projectRequestChatResolvedBody,
        Icons.cancel_outlined,
      ),
      JoinRequestStatus.withdrawn => (
        l10n.projectRequestChatWithdrawnTitle,
        l10n.projectRequestChatResolvedBody,
        Icons.undo,
      ),
    };
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('project-request-chat-status-banner'),
              onTap: onOpenDetails,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.small),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon),
                    const SizedBox(width: AppSpacing.small),
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
                          Text(
                            body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n.projectRequestChatViewDetails,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pending && creator)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('project-request-chat-reject'),
                      onPressed: isResolving ? null : onReject,
                      child: Text(l10n.participationReject),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: FilledButton(
                      key: const Key('project-request-chat-accept'),
                      onPressed: isResolving ? null : onAccept,
                      child: isResolving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.participationAccept),
                    ),
                  ),
                ],
              ),
            if (summary.requestStatus == JoinRequestStatus.accepted &&
                summary.acceptedProjectGroupChatId != null)
              FilledButton.icon(
                key: const Key('project-request-chat-open-group'),
                onPressed: () => context.push(
                  projectChatRoute(summary.acceptedProjectGroupChatId!),
                ),
                icon: const Icon(Icons.groups_outlined),
                label: Text(l10n.projectRequestChatOpenGroup),
              ),
          ],
        ),
      ),
    );
  }
}

class _StructuredRequestCard extends StatelessWidget {
  const _StructuredRequestCard({
    required this.item,
    required this.onOpenDetails,
  });

  final ProjectRequestChatRequestItem item;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card.outlined(
      key: const Key('project-request-chat-request-item'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.projectRequestChatRequestCardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              '${messageProjectKindLabel(l10n, item.projectKind)} · '
              '${item.projectTitle}',
            ),
            const SizedBox(height: AppSpacing.small),
            Text(item.requestMessage ?? l10n.messagesNoRequestMessage),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('project-request-chat-request-details'),
                onPressed: onOpenDetails,
                child: Text(l10n.projectRequestChatViewDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ProjectRequestChatHumanMessage message;
  final bool isMine;

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
          AppSpacing.small + MediaQuery.viewInsetsOf(context).bottom,
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
