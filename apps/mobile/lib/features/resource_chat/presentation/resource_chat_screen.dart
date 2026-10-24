import '../../profile/presentation/person_preview_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../messages/presentation/message_read_viewport.dart';
import '../../messages/presentation/conversation_history_list.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../resource_exchange/application/resource_exchange_controller.dart';
import '../../resource_exchange/presentation/resource_exchange_widgets.dart';
import '../application/resource_chat_controller.dart';
import '../domain/resource_chat_models.dart';
import 'resource_chat_failure_message.dart';

class ResourceChatScreen extends ConsumerStatefulWidget {
  const ResourceChatScreen({
    required this.chatId,
    this.managementOnly = false,
    super.key,
  });

  final String chatId;

  /// A1 keeps agreement/request actions in their original owner, without a
  /// second personal transcript, composer or read acknowledgement.
  final bool managementOnly;

  @override
  ConsumerState<ResourceChatScreen> createState() => _ResourceChatScreenState();
}

class _ResourceChatScreenState extends ConsumerState<ResourceChatScreen>
    with WidgetsBindingObserver {
  late final String? _expectedProfileId;
  late final ResourceChatDetailController _controller;
  late final ResourceExchangeController _exchangeController;
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final _summaryScrollController = ScrollController();
  var _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    _controller = ref.read(resourceChatDetailProvider.notifier);
    _exchangeController = ref.read(resourceExchangeProvider.notifier);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stopSignals();
    _composer.dispose();
    _scrollController.dispose();
    _summaryScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profileId = _expectedProfileId;
    if (state == AppLifecycleState.resumed && profileId != null) {
      _controller.handleAppResumed(profileId, widget.chatId);
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
      chatId: widget.chatId,
    );
    if (!mounted || !_hasExpectedIdentity) return;
    _controller.startSignals(profileId, widget.chatId);
    if (!loaded) return;
    final summary = ref.read(resourceChatDetailProvider).summary;
    if (summary == null) return;
    await _exchangeController.load(
      expectedProfileId: profileId,
      chatId: widget.chatId,
      requestId: summary.requestId,
      agreementId: summary.agreementId,
      listingId: summary.listingId,
      ownerProfileId: summary.ownerProfileId,
      requesterProfileId: summary.requesterProfileId,
    );
  }

  Future<void> _refresh() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await Future.wait([
      _controller.refresh(expectedProfileId: profileId, chatId: widget.chatId),
      _exchangeController.refresh(),
    ]);
  }

  Future<void> _loadOlder() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _controller.loadOlder(
      expectedProfileId: profileId,
      chatId: widget.chatId,
    );
  }

  Future<void> _send() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    final sent = await _controller.send(
      expectedProfileId: profileId,
      chatId: widget.chatId,
      body: _composer.text,
    );
    if (!sent || !mounted) return;
    _composer.clear();
    _scrollToBottom();
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

  void _showSummaryWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _summaryScrollController.hasClients) {
        _summaryScrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceChatDetailProvider);
    final belongs =
        state.expectedProfileId == _expectedProfileId &&
        state.chatId == widget.chatId;
    final summary = belongs ? state.summary : null;
    final messages = belongs ? state.messages : const <ResourceChatMessage>[];

    ref.listen(resourceChatDetailProvider, (previous, next) {
      if ((next.failure != null && previous?.failure != next.failure) ||
          (next.hasConnectionIssue && previous?.hasConnectionIssue != true)) {
        _showSummaryWarning();
      }
      final becameReady =
          next.expectedProfileId == _expectedProfileId &&
          next.chatId == widget.chatId &&
          next.phase == ResourceChatDetailPhase.ready;
      if (becameReady && !_didInitialScroll) {
        _didInitialScroll = true;
        _scrollToBottom();
      }
    });
    ref.listen(resourceExchangeProvider, (previous, next) {
      if ((next.failure != null && previous?.failure != next.failure) ||
          (next.eventLoadFailure && previous?.eventLoadFailure != true) ||
          (next.hasRefreshWarning && previous?.hasRefreshWarning != true)) {
        _showSummaryWarning();
      }
    });

    return MessageReadViewport(
      profileId: _expectedProfileId,
      kind: 'resource_chat',
      chatId: summary?.chatId,
      boundary:
          !widget.managementOnly &&
              belongs &&
              state.phase == ResourceChatDetailPhase.ready &&
              state.failure == null &&
              !state.isLoadingOlder
          ? state.readBoundary
          : null,
      scrollController: _scrollController,
      child: Scaffold(
        appBar: pageAppBar(
          context,
          title: Text(
            summary?.listingTitle ?? l10n.resourceChatTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child:
              !belongs ||
                  (state.phase == ResourceChatDetailPhase.loading &&
                      messages.isEmpty)
              ? LoadingState(message: l10n.resourceChatLoading)
              : state.phase == ResourceChatDetailPhase.failure &&
                    messages.isEmpty
              ? ErrorState(
                  message: resourceChatFailureMessage(l10n, state.failure!),
                  onRetry: _load,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      // Bound only the summary's share of available height. Its
                      // full content scrolls independently of message read/paging.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              constraints.maxHeight *
                              (widget.managementOnly ? 1 : .45),
                        ),
                        child: Scrollbar(
                          controller: _summaryScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            key: const Key('resource-chat-summary-scroll'),
                            controller: _summaryScrollController,
                            child: Column(
                              children: [
                                const ResourceExchangeFeedback(),
                                if (state.hasConnectionIssue)
                                  Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      key: const Key(
                                        'resource-chat-connection-issue',
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.small,
                                      ),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .errorContainer,
                                      child: Text(
                                        l10n.resourceChatConnectionIssue,
                                      ),
                                    ),
                                  ),
                                if (state.failure case final failure?)
                                  Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      key: const Key(
                                        'resource-chat-inline-error',
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.small,
                                      ),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .errorContainer,
                                      child: Text(
                                        resourceChatFailureMessage(
                                          l10n,
                                          failure,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (summary != null)
                                  _CounterpartyHeader(
                                    summary: summary,
                                    onBlockingChanged: _refresh,
                                  ),
                                if (summary != null)
                                  ResourceExchangeAgreementSection(
                                    listingTitle: summary.listingTitle,
                                    ownerDisplayName: summary.ownerDisplayName,
                                    requesterDisplayName:
                                        summary.requesterDisplayName,
                                  ),
                                if (widget.managementOnly && summary != null)
                                  TextButton(
                                    key: const Key(
                                      'resource-coordination-request-detail',
                                    ),
                                    onPressed: () => context.push(
                                      resourceRequestMessageRoute(
                                        summary.requestId,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.resourceRequestDetailTitle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.managementOnly)
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            child: ConversationHistoryList<ResourceChatMessage>(
                              key: const Key('resource-chat-history'),
                              controller: _scrollController,
                              items: messages,
                              itemKey: (item) => item.messageId,
                              itemBuilder: (context, message) => _MessageBubble(
                                message: message,
                                isMine:
                                    message.senderProfileId ==
                                    _expectedProfileId,
                                onReport:
                                    message.senderProfileId ==
                                        _expectedProfileId
                                    ? null
                                    : () => ModerationRoutes.openReport(
                                        context,
                                        resourceMessageReportTarget(
                                          message.messageId,
                                          l10n.moderationResourceMessageTarget,
                                        ),
                                      ),
                              ),
                              enabled:
                                  belongs &&
                                  summary != null &&
                                  _hasExpectedIdentity,
                              hasMore: state.hasMoreOlder,
                              loading: state.isLoadingOlder,
                              failed: state.failure != null,
                              onLoadOlder: _loadOlder,
                              fallbackLabel: l10n.resourceChatLoadOlder,
                              buttonKey: const Key('resource-chat-load-older'),
                              empty: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.medium,
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 24,
                                    ),
                                    const SizedBox(height: AppSpacing.small),
                                    Text(
                                      l10n.resourceChatNoMessages,
                                      key: const Key('resource-chat-empty'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (summary?.hasSendEntitlement ==
                                        true) ...[
                                      const SizedBox(height: AppSpacing.small),
                                      Text(
                                        l10n.resourceChatEmptyGuidance,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!widget.managementOnly &&
                          summary?.hasSendEntitlement == true)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .45,
                          ),
                          child: SingleChildScrollView(
                            key: const Key('resource-chat-composer-scroll'),
                            primary: false,
                            reverse: true,
                            child: _Composer(
                              controller: _composer,
                              isSending: state.isSending,
                              onSend: _send,
                            ),
                          ),
                        )
                      else if (!widget.managementOnly && summary != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .45,
                          ),
                          child: SingleChildScrollView(
                            primary: false,
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                key: const Key('resource-chat-read-only'),
                                width: double.infinity,
                                padding: const EdgeInsets.all(
                                  AppSpacing.medium,
                                ),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Text(l10n.resourceChatReadOnlyNotice),
                              ),
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

class _CounterpartyHeader extends ConsumerWidget {
  const _CounterpartyHeader({
    required this.summary,
    required this.onBlockingChanged,
  });

  final ResourceChatSummary summary;
  final Future<void> Function() onBlockingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photo = ref
        .watch(visibleProfilePhotoProvider)
        .entryFor(summary.counterpartyProfileId);
    final role = summary.viewerRole == ResourceChatViewerRole.owner
        ? l10n.resourceChatRequester
        : l10n.resourceChatOwner;
    return Container(
      key: const Key('resource-chat-counterparty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => showPersonPreviewSheet(
          context,
          profileId: summary.counterpartyProfileId,
          contextDisplayName: summary.counterpartyDisplayName,
          consequence: BlockingContextConsequence.acceptedResourceCoordination,
          onChanged: (_) => onBlockingChanged(),
        ),
        child: Row(
          children: [
            VisibleProfilePhotoAvatar(
              key: const Key('resource-chat-counterparty-photo'),
              entry: photo,
              imageSemanticsLabel: l10n.resourceChatCounterpartyPhotoLabel(
                summary.counterpartyDisplayName,
              ),
              placeholderSemanticsLabel: l10n
                  .resourceChatCounterpartyPhotoLabel(
                    summary.counterpartyDisplayName,
                  ),
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: summary.counterpartyDisplayName,
                    child: Text(
                      summary.counterpartyDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(role, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            BlockingActionButton(
              targetProfileId: summary.counterpartyProfileId,
              targetDisplayName: summary.counterpartyDisplayName,
              consequence:
                  BlockingContextConsequence.acceptedResourceCoordination,
              compact: true,
              buttonKey: const Key('resource-chat-blocking-action'),
              onChanged: (_) => onBlockingChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onReport,
  });

  final ResourceChatMessage message;
  final bool isMine;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = isMine
        ? l10n.resourceChatYou
        : message.senderDisplayName ?? l10n.resourceChatUnknownSender;
    final time = _formatDate(context, message.createdAt);
    return Semantics(
      label: l10n.resourceChatMessageSemantics(sender, message.body, time),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              key: Key('resource-chat-message-${message.messageId}'),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xSmall,
                      children: [
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (onReport != null)
                          IconButton(
                            key: Key(
                              'resource-chat-report-${message.messageId}',
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.moderationReportAction,
                            onPressed: onReport,
                            icon: const Icon(Icons.flag_outlined, size: 18),
                          ),
                      ],
                    ),
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
        // Scaffold resizes the body and removes its bottom view inset.
        // Composer padding stays independent of keyboard metrics.
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('resource-chat-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: resourceChatMessageMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.resourceChatMessageHint,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xSmall),
            IconButton.filled(
              key: const Key('resource-chat-send'),
              tooltip: l10n.resourceChatSend,
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

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
