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
import '../../messages/presentation/messages_routes.dart';
import '../application/project_chat_controllers.dart';
import '../application/project_needs_controller.dart';
import '../domain/project_chat_models.dart';
import 'project_chat_failure_message.dart';
import 'project_needs_sheet.dart';

class ProjectChatScreen extends ConsumerStatefulWidget {
  const ProjectChatScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends ConsumerState<ProjectChatScreen>
    with WidgetsBindingObserver {
  late final String? _expectedProfileId;
  late final ProjectChatDetailController _detailController;
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  var _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    _detailController = ref.read(projectChatDetailProvider.notifier);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailController.stopSignals();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profileId = _expectedProfileId;
    if (state == AppLifecycleState.resumed && profileId != null) {
      _detailController.handleAppResumed(profileId, widget.chatId);
    }
  }

  bool get _hasExpectedIdentity =>
      _expectedProfileId != null &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;

  Future<void> _load() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _detailController.load(
      expectedProfileId: profileId,
      chatId: widget.chatId,
    );
    if (!mounted || !_hasExpectedIdentity) return;
    _detailController.startSignals(profileId, widget.chatId);
  }

  Future<void> _refresh() async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await _detailController.refresh(
      expectedProfileId: profileId,
      chatId: widget.chatId,
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
    final loaded = await _detailController.loadOlder(
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
    final sent = await _detailController.send(
      expectedProfileId: profileId,
      chatId: widget.chatId,
      body: _composer.text,
    );
    if (!sent || !mounted) return;
    _composer.clear();
    _scrollToBottom();
  }

  Future<void> _openNeeds() async {
    if (!_hasExpectedIdentity) return;
    await showProjectNeedsSheet(context);
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
    final state = ref.watch(projectChatDetailProvider);
    final belongs =
        state.expectedProfileId == _expectedProfileId &&
        state.chatId == widget.chatId;
    final summary = belongs ? state.summary : null;
    final feedItems = belongs ? state.feedItems : const <ProjectChatFeedItem>[];
    final needsState = ref.watch(projectNeedsProvider);
    final needsBelong =
        needsState.expectedProfileId == _expectedProfileId &&
        needsState.projectId == summary?.projectId &&
        needsState.chatId == widget.chatId;

    ref.listen(projectChatDetailProvider, (previous, next) {
      final becameReady =
          next.expectedProfileId == _expectedProfileId &&
          next.chatId == widget.chatId &&
          next.phase == ProjectChatDetailPhase.ready;
      if (becameReady && !_didInitialScroll) {
        _didInitialScroll = true;
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(summary?.projectTitle ?? l10n.projectChatTitle),
        actions: [
          IconButton(
            key: const Key('project-chat-info'),
            tooltip: l10n.projectChatGroupInfo,
            onPressed: summary == null
                ? null
                : () => context.push(projectChatInfoRoute(widget.chatId)),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child:
            !belongs ||
                (state.phase == ProjectChatDetailPhase.loading &&
                    feedItems.isEmpty)
            ? LoadingState(message: l10n.projectChatLoading)
            : state.phase == ProjectChatDetailPhase.failure && feedItems.isEmpty
            ? ErrorState(
                message: projectChatFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : Column(
                children: [
                  if (state.hasConnectionIssue)
                    MaterialBanner(
                      content: Text(l10n.projectChatConnectionIssue),
                      actions: [
                        TextButton(
                          onPressed: _refresh,
                          child: Text(l10n.retryAction),
                        ),
                      ],
                    ),
                  if (state.failure != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.small),
                        child: Text(
                          projectChatFailureMessage(l10n, state.failure!),
                          key: const Key('project-chat-inline-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: feedItems.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: SizedBox(
                                      height: constraints.maxHeight,
                                      child: EmptyState(
                                        title: l10n.projectChatEmptyTitle,
                                        message: l10n.projectChatEmptyMessage,
                                        icon: Icons.forum_outlined,
                                      ),
                                    ),
                                  ),
                            )
                          : ListView.builder(
                              key: const Key('project-chat-history'),
                              controller: _scrollController,
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              itemCount:
                                  feedItems.length +
                                  (state.hasMoreOlder ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (state.hasMoreOlder && index == 0) {
                                  return Center(
                                    child: TextButton(
                                      key: const Key('project-chat-load-older'),
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
                                          : Text(l10n.projectChatLoadOlder),
                                    ),
                                  );
                                }
                                final itemIndex =
                                    index - (state.hasMoreOlder ? 1 : 0);
                                final item = feedItems[itemIndex];
                                return switch (item) {
                                  ProjectChatHumanMessage message =>
                                    _MessageBubble(
                                      message: message,
                                      isMine:
                                          message.senderProfileId ==
                                          _expectedProfileId,
                                    ),
                                  ProjectChatRequirementNeededAgain event =>
                                    _RequirementNeededAgainCard(event: event),
                                };
                              },
                            ),
                    ),
                  ),
                  if (summary?.hasCurrentEntitlement == true)
                    _Composer(
                      controller: _composer,
                      isSending: state.isSending,
                      onSend: _send,
                      needsControl: _NeedsControl(
                        uncoveredCount: needsBelong
                            ? needsState.uncoveredCount
                            : 0,
                        hasAttention:
                            needsBelong && needsState.hasUnseenAttention,
                        pulseRevision: needsBelong
                            ? needsState.attentionPulseRevision
                            : 0,
                        onPressed: _openNeeds,
                      ),
                    )
                  else if (summary != null)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('project-chat-read-only'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(l10n.projectChatReadOnlyNotice),
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

  final ProjectChatHumanMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = isMine
        ? l10n.projectChatYou
        : message.senderDisplayName ?? l10n.projectChatUnknownSender;
    final time = _formatChatDate(context, message.createdAt);
    return Semantics(
      label: l10n.projectChatMessageSemantics(sender, message.body, time),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              key: Key('project-chat-message-${message.itemId}'),
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

class _RequirementNeededAgainCard extends StatelessWidget {
  const _RequirementNeededAgainCard({required this.event});

  final ProjectChatRequirementNeededAgain event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = _formatChatDate(context, event.createdAt);
    final message = l10n.projectNeedsSystemEvent(event.requirementLabel);
    return Semantics(
      label: l10n.projectNeedsSystemEventSemantics(
        event.requirementLabel,
        time,
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card.outlined(
              key: Key('project-chat-system-${event.itemId}'),
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message),
                          const SizedBox(height: AppSpacing.xSmall),
                          Text(
                            time,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
    required this.needsControl,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final Widget needsControl;

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
            needsControl,
            const SizedBox(width: AppSpacing.xSmall),
            Expanded(
              child: TextField(
                key: const Key('project-chat-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: projectChatMessageMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.projectChatMessageHint,
                  counterText: '',
                ),
              ),
            ),
            IconButton.filled(
              key: const Key('project-chat-send'),
              tooltip: l10n.projectChatSend,
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

class _NeedsControl extends ConsumerStatefulWidget {
  const _NeedsControl({
    required this.uncoveredCount,
    required this.hasAttention,
    required this.pulseRevision,
    required this.onPressed,
  });

  final int uncoveredCount;
  final bool hasAttention;
  final int pulseRevision;
  final VoidCallback onPressed;

  @override
  ConsumerState<_NeedsControl> createState() => _NeedsControlState();
}

class _NeedsControlState extends ConsumerState<_NeedsControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late int _lastPulseRevision;

  @override
  void initState() {
    super.initState();
    _lastPulseRevision = widget.pulseRevision;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 45),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 55),
      ],
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _NeedsControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseRevision != _lastPulseRevision) {
      _lastPulseRevision = widget.pulseRevision;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _pulseController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boundedCount = widget.uncoveredCount > 99
        ? '99+'
        : '${widget.uncoveredCount}';
    final countLabel = l10n.projectNeedsCountSemantics(widget.uncoveredCount);
    final semanticsLabel = widget.hasAttention
        ? l10n.projectNeedsButtonAttentionSemantics(countLabel)
        : l10n.projectNeedsButtonSemantics(countLabel);
    final control = Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.projectNeedsTitle,
        child: Badge(
          isLabelVisible: widget.uncoveredCount > 0,
          label: Text(boundedCount),
          child: IconButton.outlined(
            key: const Key('project-needs-button'),
            onPressed: widget.onPressed,
            icon: const Icon(Icons.checklist),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.hasAttention)
          Semantics(
            liveRegion: true,
            label: l10n.projectNeedsNewAttention,
            child: Container(
              key: const Key('project-needs-attention-callout'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xSmall,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.projectNeedsNeededAgain,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ScaleTransition(scale: _pulse, child: control),
      ],
    );
  }
}

String _formatChatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
