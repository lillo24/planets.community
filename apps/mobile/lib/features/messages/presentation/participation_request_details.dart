import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/join_acceptance_triage_sheet.dart';
import '../../participation/presentation/participation_routes.dart';
import '../application/messages_controllers.dart';
import '../domain/message_models.dart';
import 'messages_failure_message.dart';
import 'messages_formatters.dart';

Future<void> showParticipationRequestDetailsSheet(
  BuildContext context, {
  required String requestId,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.small,
            AppSpacing.small,
            AppSpacing.small,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).messagesRequestDetailTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ParticipationRequestDetailsContent(requestId: requestId),
        ),
      ],
    ),
  ),
);

class ParticipationRequestDetailsContent extends ConsumerStatefulWidget {
  const ParticipationRequestDetailsContent({
    required this.requestId,
    super.key,
  });

  final String requestId;

  @override
  ConsumerState<ParticipationRequestDetailsContent> createState() =>
      _ParticipationRequestDetailsContentState();
}

class _ParticipationRequestDetailsContentState
    extends ConsumerState<ParticipationRequestDetailsContent> {
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

  Future<void> _accept(ParticipationRequestMessageItem item) async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        item.viewerRole == MessageViewerRole.requester ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await showJoinAcceptanceTriageSheet(
      context,
      expectedManagerProfileId: profileId,
      requestId: item.requestId,
      projectId: item.projectId,
      projectKind: item.projectKind,
      requesterDisplayName: item.requesterDisplayName,
    );
    if (!mounted || ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref
        .read(messagesDetailProvider.notifier)
        .reloadAfterJoinAcceptanceTriage();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(messagesDetailProvider);
    final belongs =
        state.expectedProfileId == _expectedProfileId &&
        state.requestId == widget.requestId;
    final item = belongs ? state.item : null;
    final loading =
        !belongs ||
        (state.phase == MessagesDetailPhase.loading && item == null);
    if (loading) return LoadingState(message: l10n.messagesLoadingRequest);
    if (item == null) {
      return ErrorState(
        message: messagesFailureMessage(
          l10n,
          state.failure ?? MessagesFailureKind.unavailable,
        ),
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('participation-request-details'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.large),
        children: [
          if (state.failure case final failure?) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                messagesFailureMessage(l10n, failure),
                key: const Key('message-detail-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
          ],
          Text(
            item.viewerRole != MessageViewerRole.requester
                ? l10n.messagesIncomingTitle(item.requesterDisplayName)
                : l10n.messagesOutgoingDetailTitle(item.creatorDisplayName),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.medium),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              Chip(label: Text(messageStatusLabel(l10n, item.status))),
              Chip(
                avatar: Icon(
                  item.projectKind == ProjectKind.oneTime
                      ? Icons.event_outlined
                      : Icons.repeat_outlined,
                  size: 18,
                ),
                label: Text(messageProjectKindLabel(l10n, item.projectKind)),
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
                Text(l10n.messagesRequesterLabel(item.requesterDisplayName)),
                Text(l10n.messagesOrganizerLabel(item.creatorDisplayName)),
              ],
            ),
          ),
          _ContributionSelectionsSection(state: state),
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
                    l10n.messagesResolvedAt(messageDate(context, resolvedAt)),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const Key('message-view-project'),
            onPressed: () => context.go(
              ParticipationRoutes.detail(item.projectKind, item.projectId),
            ),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.messagesViewProject),
          ),
          const SizedBox(height: AppSpacing.medium),
          if (item.isPending)
            _MessageActions(
              item: item,
              state: state,
              onAccept: () => _accept(item),
            )
          else
            Text(
              l10n.messagesResolvedHistoryNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _ContributionSelectionsSection extends ConsumerWidget {
  const _ContributionSelectionsSection({required this.state});

  final MessagesDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skills = state.selections
        .where((item) => item.kind == RequestContributionSelectionKind.skill)
        .toList(growable: false);
    final resources = state.selections
        .where((item) => item.kind == RequestContributionSelectionKind.resource)
        .toList(growable: false);
    return _DetailSection(
      title: l10n.messagesCanContribute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.selectionPhase == MessagesSelectionPhase.loading &&
              state.selections.isEmpty)
            Row(
              key: const Key('message-contributions-loading'),
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.small),
                Text(l10n.messagesContributionsLoading),
              ],
            )
          else if (state.selectionPhase == MessagesSelectionPhase.ready &&
              state.selections.isEmpty)
            Text(l10n.messagesNoContributionsSelected)
          else ...[
            if (skills.isNotEmpty)
              _SelectionGroup(
                title: l10n.participationCompetencesGroup,
                selections: skills,
              ),
            if (resources.isNotEmpty) ...[
              if (skills.isNotEmpty) const SizedBox(height: AppSpacing.small),
              _SelectionGroup(
                title: l10n.participationResourcesGroup,
                selections: resources,
              ),
            ],
          ],
          if (state.selectionPhase == MessagesSelectionPhase.loading &&
              state.selections.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.small),
            const LinearProgressIndicator(),
          ],
          if (state.selectionPhase == MessagesSelectionPhase.failure) ...[
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.messagesContributionsLoadError,
                    key: const Key('message-contributions-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('message-contributions-retry'),
                  onPressed: ref
                      .read(messagesDetailProvider.notifier)
                      .retryContributionSelections,
                  child: Text(l10n.retryAction),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionGroup extends StatelessWidget {
  const _SelectionGroup({required this.title, required this.selections});

  final String title;
  final List<RequestContributionSelection> selections;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xSmall),
      Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.small,
        children: [
          for (final selection in selections)
            Chip(
              key: Key(
                'message-contribution-${selection.kind.wireValue}-${selection.id}',
              ),
              label: Text(selection.label),
            ),
        ],
      ),
    ],
  );
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
  const _MessageActions({
    required this.item,
    required this.state,
    required this.onAccept,
  });

  final ParticipationRequestMessageItem item;
  final MessagesDetailState state;
  final VoidCallback onAccept;

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
            onPressed: state.isActing ? null : onAccept,
            child: Text(l10n.participationAccept),
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
