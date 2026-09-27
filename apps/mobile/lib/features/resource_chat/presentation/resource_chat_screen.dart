import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../resource_exchange/application/resource_exchange_controller.dart';
import '../../resource_exchange/presentation/resource_exchange_widgets.dart';
import '../application/resource_chat_controller.dart';
import '../domain/resource_chat_models.dart';
import 'resource_chat_failure_message.dart';

class ResourceChatScreen extends ConsumerStatefulWidget {
  const ResourceChatScreen({required this.chatId, super.key});

  final String chatId;

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
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final loaded = await _controller.loadOlder(
      expectedProfileId: profileId,
      chatId: widget.chatId,
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
      final becameReady =
          next.expectedProfileId == _expectedProfileId &&
          next.chatId == widget.chatId &&
          next.phase == ResourceChatDetailPhase.ready;
      if (becameReady && !_didInitialScroll) {
        _didInitialScroll = true;
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
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
            : state.phase == ResourceChatDetailPhase.failure && messages.isEmpty
            ? ErrorState(
                message: resourceChatFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : Column(
                children: [
                  if (summary != null) _CounterpartyHeader(summary: summary),
                  if (summary != null)
                    ResourceExchangeAgreementSection(
                      listingTitle: summary.listingTitle,
                      ownerDisplayName: summary.ownerDisplayName,
                      requesterDisplayName: summary.requesterDisplayName,
                    ),
                  if (state.hasConnectionIssue)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('resource-chat-connection-issue'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.small),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Text(l10n.resourceChatConnectionIssue),
                      ),
                    ),
                  if (state.failure case final failure?)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('resource-chat-inline-error'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.small),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Text(resourceChatFailureMessage(l10n, failure)),
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        key: const Key('resource-chat-history'),
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        children: [
                          if (state.hasMoreOlder)
                            Center(
                              child: OutlinedButton(
                                key: const Key('resource-chat-load-older'),
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
                                    : Text(l10n.resourceChatLoadOlder),
                              ),
                            ),
                          if (messages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xLarge,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    l10n.resourceChatNoMessages,
                                    key: const Key('resource-chat-empty'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (summary?.hasSendEntitlement == true) ...[
                                    const SizedBox(height: AppSpacing.small),
                                    Text(
                                      l10n.resourceChatEmptyGuidance,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            for (final message in messages)
                              _MessageBubble(
                                message: message,
                                isMine:
                                    message.senderProfileId ==
                                    _expectedProfileId,
                              ),
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
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('resource-chat-read-only'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(l10n.resourceChatReadOnlyNotice),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CounterpartyHeader extends ConsumerWidget {
  const _CounterpartyHeader({required this.summary});

  final ResourceChatSummary summary;

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
      child: Row(
        children: [
          VisibleProfilePhotoAvatar(
            key: const Key('resource-chat-counterparty-photo'),
            entry: photo,
            imageSemanticsLabel: l10n.resourceChatCounterpartyPhotoLabel(
              summary.counterpartyDisplayName,
            ),
            placeholderSemanticsLabel: l10n.resourceChatCounterpartyPhotoLabel(
              summary.counterpartyDisplayName,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              l10n.resourceChatCounterparty(
                role,
                summary.counterpartyDisplayName,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ResourceChatMessage message;
  final bool isMine;

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
      child: Align(
        key: Key('resource-chat-message-${message.messageId}'),
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            color: isMine
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sender, style: Theme.of(context).textTheme.labelMedium),
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
