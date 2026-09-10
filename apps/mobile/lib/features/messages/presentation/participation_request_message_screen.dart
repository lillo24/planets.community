import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/participation_routes.dart';
import '../application/messages_controllers.dart';
import '../domain/message_models.dart';
import 'messages_failure_message.dart';
import 'messages_screen.dart';

class ParticipationRequestMessageScreen extends ConsumerStatefulWidget {
  const ParticipationRequestMessageScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<ParticipationRequestMessageScreen> createState() =>
      _ParticipationRequestMessageScreenState();
}

class _ParticipationRequestMessageScreenState
    extends ConsumerState<ParticipationRequestMessageScreen> {
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
        .read(messagesDetailProvider.notifier)
        .load(expectedProfileId: profileId, requestId: widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(messagesDetailProvider);
    final belongsToScreen =
        state.expectedProfileId == _expectedProfileId &&
        state.requestId == widget.requestId;
    final item = belongsToScreen ? state.item : null;
    final initialLoading =
        !belongsToScreen ||
        (state.phase == MessagesDetailPhase.loading && item == null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesRequestDetailTitle)),
      body: SafeArea(
        child: initialLoading
            ? LoadingState(message: l10n.messagesLoadingRequest)
            : item == null
            ? ErrorState(
                message: messagesFailureMessage(
                  l10n,
                  state.failure ?? MessagesFailureKind.unavailable,
                ),
                onRetry: _load,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: [
                    if (state.failure case final failure?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          messagesFailureMessage(l10n, failure),
                          key: const Key('message-detail-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    Text(
                      item.viewerRole == MessageViewerRole.creator
                          ? l10n.messagesIncomingTitle(
                              item.requesterDisplayName,
                            )
                          : l10n.messagesOutgoingDetailTitle(
                              item.creatorDisplayName,
                            ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Wrap(
                      spacing: AppSpacing.small,
                      runSpacing: AppSpacing.small,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(messageStatusLabel(l10n, item.status)),
                        ),
                        Chip(
                          avatar: Icon(
                            item.projectKind == ProjectKind.oneTime
                                ? Icons.event_outlined
                                : Icons.repeat_outlined,
                            size: 18,
                          ),
                          label: Text(
                            messageProjectKindLabel(l10n, item.projectKind),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    _DetailSection(
                      title: l10n.messagesProjectLabel,
                      child: Text(item.projectTitle),
                    ),
                    _DetailSection(
                      title: l10n.messagesPeopleLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.messagesRequesterLabel(
                              item.requesterDisplayName,
                            ),
                          ),
                          Text(
                            l10n.messagesOrganizerLabel(
                              item.creatorDisplayName,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DetailSection(
                      title: l10n.messagesRequestMessageLabel,
                      child: SelectableText(
                        item.requestMessage ?? l10n.messagesNoRequestMessage,
                        key: const Key('message-detail-request-message'),
                      ),
                    ),
                    _DetailSection(
                      title: l10n.messagesTimelineLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.messagesRequestedAt(
                              messageDate(context, item.createdAt),
                            ),
                          ),
                          if (item.resolvedAt case final resolvedAt?)
                            Text(
                              l10n.messagesResolvedAt(
                                messageDate(context, resolvedAt),
                              ),
                            ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('message-view-project'),
                      onPressed: () => context.go(
                        ParticipationRoutes.detail(
                          item.projectKind,
                          item.projectId,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.messagesViewProject),
                    ),
                    if (item.isPending) ...[
                      const SizedBox(height: AppSpacing.medium),
                      _MessageActions(item: item, state: state),
                    ] else ...[
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        l10n.messagesResolvedHistoryNote,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.large),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xSmall),
        child,
      ],
    ),
  );
}

class _MessageActions extends ConsumerWidget {
  const _MessageActions({required this.item, required this.state});

  final ParticipationRequestMessageItem item;
  final MessagesDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(messagesDetailProvider.notifier);
    if (item.viewerRole == MessageViewerRole.requester) {
      return OutlinedButton.icon(
        key: const Key('message-withdraw'),
        onPressed: state.isActing ? null : controller.withdraw,
        icon: state.action == MessageAction.withdrawing
            ? const _ActionProgress()
            : const Icon(Icons.undo),
        label: Text(l10n.participationWithdraw),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('message-reject'),
            onPressed: state.isActing ? null : controller.reject,
            child: state.action == MessageAction.rejecting
                ? const _ActionProgress()
                : Text(l10n.participationReject),
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: FilledButton(
            key: const Key('message-accept'),
            onPressed: state.isActing ? null : controller.accept,
            child: state.action == MessageAction.accepting
                ? const _ActionProgress()
                : Text(l10n.participationAccept),
          ),
        ),
      ],
    );
  }
}

class _ActionProgress extends StatelessWidget {
  const _ActionProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
