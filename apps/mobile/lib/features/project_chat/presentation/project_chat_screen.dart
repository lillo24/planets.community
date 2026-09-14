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
import '../domain/project_chat_models.dart';
import 'project_chat_failure_message.dart';

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
    final messages = belongs ? state.messages : const <ProjectChatMessage>[];

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
                    messages.isEmpty)
            ? LoadingState(message: l10n.projectChatLoading)
            : state.phase == ProjectChatDetailPhase.failure && messages.isEmpty
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
                      child: messages.isEmpty
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
                                  messages.length +
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
                                final messageIndex =
                                    index - (state.hasMoreOlder ? 1 : 0);
                                return _MessageBubble(
                                  message: messages[messageIndex],
                                  isMine:
                                      messages[messageIndex].senderProfileId ==
                                      _expectedProfileId,
                                );
                              },
                            ),
                    ),
                  ),
                  if (summary?.hasCurrentEntitlement == true)
                    _Composer(
                      controller: _composer,
                      isSending: state.isSending,
                      onSend: _send,
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

  final ProjectChatMessage message;
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
      child: Align(
        key: Key('project-chat-message-${message.messageId}'),
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
          AppSpacing.medium,
          AppSpacing.small,
          AppSpacing.small,
          AppSpacing.small + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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

String _formatChatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
