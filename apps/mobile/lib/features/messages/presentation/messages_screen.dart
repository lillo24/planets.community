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

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref
        .read(messagesInboxProvider.notifier)
        .load(profileId, refresh: true);
  }

  Future<void> _loadMore() async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref.read(messagesInboxProvider.notifier).loadMore(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(messagesInboxProvider);
    final belongsToScreen = state.expectedProfileId == _expectedProfileId;
    final items = belongsToScreen
        ? state.items
        : const <ParticipationRequestMessageItem>[];
    final isInitialLoading =
        !belongsToScreen ||
        (state.phase == MessagesInboxPhase.loading && items.isEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: SafeArea(
        child: isInitialLoading
            ? LoadingState(message: l10n.messagesLoading)
            : state.phase == MessagesInboxPhase.failure && items.isEmpty
            ? ErrorState(
                message: messagesFailureMessage(l10n, state.failure!),
                onRetry: _load,
              )
            : items.isEmpty
            ? RefreshIndicator(
                onRefresh: _load,
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
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  itemCount:
                      items.length +
                      (state.failure != null ? 1 : 0) +
                      (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.failure != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.small,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            messagesFailureMessage(l10n, state.failure!),
                            key: const Key('messages-inline-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      );
                    }
                    final itemIndex = index - (state.failure != null ? 1 : 0);
                    if (itemIndex == items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.medium,
                        ),
                        child: OutlinedButton(
                          key: const Key('messages-load-more'),
                          onPressed: state.isBusy ? null : _loadMore,
                          child: state.phase == MessagesInboxPhase.loadingMore
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
                    final item = items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: _MessageCard(item: item),
                    );
                  },
                ),
              ),
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
                '${_projectKindLabel(l10n, item.projectKind)} · '
                '${item.projectTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.messagesUpdatedAt(_formatDate(context, item.activityAt)),
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
    label: _statusLabel(AppLocalizations.of(context), status),
    child: Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusLabel(AppLocalizations.of(context), status)),
    ),
  );
}

String messageStatusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    _statusLabel(l10n, status);

String messageProjectKindLabel(AppLocalizations l10n, ProjectKind kind) =>
    _projectKindLabel(l10n, kind);

String messageDate(BuildContext context, DateTime date) =>
    _formatDate(context, date);

String _statusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    switch (status) {
      JoinRequestStatus.pending => l10n.participationStatusPending,
      JoinRequestStatus.accepted => l10n.participationStatusAccepted,
      JoinRequestStatus.rejected => l10n.participationStatusRejected,
      JoinRequestStatus.withdrawn => l10n.participationStatusWithdrawn,
    };

String _projectKindLabel(AppLocalizations l10n, ProjectKind kind) =>
    switch (kind) {
      ProjectKind.oneTime => l10n.messagesProposal,
      ProjectKind.recurring => l10n.messagesTavolo,
    };

String _formatDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  return '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(local)} '
      '${DateFormat.Hm(Localizations.localeOf(context).toString()).format(local)}';
}
