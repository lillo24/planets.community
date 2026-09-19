import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/participation_controllers.dart';
import '../domain/participation_models.dart';
import 'actual_contribution_sheet.dart';
import 'join_acceptance_triage_sheet.dart';
import 'membership_commitment_sheet.dart';
import 'project_participation_section.dart';

class CreatorParticipationScreen extends ConsumerStatefulWidget {
  const CreatorParticipationScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<CreatorParticipationScreen> createState() =>
      _CreatorParticipationScreenState();
}

class _CreatorParticipationScreenState
    extends ConsumerState<CreatorParticipationScreen> {
  late final String? _expectedCreatorId;

  @override
  void initState() {
    super.initState();
    _expectedCreatorId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null) return;
    await ref
        .read(creatorParticipationProvider.notifier)
        .load(expectedCreatorId, widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(creatorParticipationProvider);
    final belongsToScreen =
        state.expectedCreatorId == _expectedCreatorId &&
        state.projectId == widget.projectId;
    final requests = belongsToScreen
        ? state.requests
        : const <CreatorProjectJoinRequest>[];
    final members = belongsToScreen
        ? state.members
        : const <CreatorProjectMember>[];
    final isInitialLoading =
        !belongsToScreen ||
        (state.phase == CreatorParticipationPhase.loading &&
            requests.isEmpty &&
            members.isEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.participationManage)),
      body: SafeArea(
        child: isInitialLoading
            ? LoadingState(message: l10n.participationLoading)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: [
                    if (state.failure case final failure?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          participationFailureMessage(l10n, failure),
                          key: const Key('creator-participation-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: state.isBusy ? null : _load,
                          child: Text(l10n.retryAction),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    Text(
                      l10n.participationRequests,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (requests.isEmpty)
                      Text(l10n.participationNoRequests)
                    else
                      for (final request in requests) ...[
                        _RequestCard(
                          request: request,
                          enabled: !state.isBusy,
                          isActing:
                              state.actionTargetId == request.id &&
                              state.isBusy,
                          onAccept: () => _accept(request),
                          onReject: () => _reject(request),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      l10n.participationParticipants,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (members.isEmpty)
                      Text(l10n.participationNoParticipants)
                    else
                      for (final member in members) ...[
                        _MemberCard(
                          member: member,
                          enabled: !state.isBusy,
                          isActing:
                              state.actionTargetId == member.id && state.isBusy,
                          onCommitments: () => _openCommitments(member),
                          onActualContributions:
                              widget.projectKind == ProjectKind.oneTime
                              ? () => _openActualContributions(member)
                              : null,
                          onRemove: () => _confirmRemove(member),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _accept(CreatorProjectJoinRequest request) async {
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await showJoinAcceptanceTriageSheet(
      context,
      expectedCreatorProfileId: expectedCreatorId,
      requestId: request.id,
      projectId: widget.projectId,
      projectKind: widget.projectKind,
      requesterDisplayName: request.requesterDisplayName,
    );
    if (!mounted ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await ref
        .read(creatorParticipationProvider.notifier)
        .load(expectedCreatorId, widget.projectId);
  }

  Future<void> _reject(CreatorProjectJoinRequest request) async {
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await ref
        .read(creatorParticipationProvider.notifier)
        .reject(
          expectedCreatorId: expectedCreatorId,
          projectId: widget.projectId,
          requestId: request.id,
        );
  }

  Future<void> _confirmRemove(CreatorProjectMember member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.participationRemoveConfirmTitle(member.participantDisplayName),
        ),
        content: Text(l10n.participationRemoveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.participationKeep),
          ),
          FilledButton(
            key: const Key('participation-confirm-remove'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.participationRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await ref
        .read(creatorParticipationProvider.notifier)
        .remove(
          expectedCreatorId: expectedCreatorId,
          projectId: widget.projectId,
          membershipId: member.id,
        );
  }

  Future<void> _openCommitments(CreatorProjectMember member) async {
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await showMembershipCommitmentSheet(
      context,
      expectedProfileId: expectedCreatorId,
      membershipId: member.id,
      editable: member.isCurrent,
      historical: !member.isCurrent,
    );
  }

  Future<void> _openActualContributions(CreatorProjectMember member) async {
    final expectedCreatorId = _expectedCreatorId;
    if (expectedCreatorId == null ||
        ref.read(authSessionProvider).identity?.id != expectedCreatorId) {
      return;
    }
    await showActualContributionSheet(
      context,
      expectedProfileId: expectedCreatorId,
      membershipId: member.id,
      editable: true,
      participantDisplayName: member.participantDisplayName,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.enabled,
    required this.isActing,
    required this.onAccept,
    required this.onReject,
  });

  final CreatorProjectJoinRequest request;
  final bool enabled;
  final bool isActing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: Key('participation-request-${request.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.requesterDisplayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(_requestStatusLabel(l10n, request.status)),
            Text(
              l10n.participationRequestedAt(
                _formatDate(context, request.createdAt),
              ),
            ),
            if (request.message case final message?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(
                message,
                key: Key('participation-request-message-${request.id}'),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('participation-reject-${request.id}'),
                      onPressed: enabled ? onReject : null,
                      child: Text(l10n.participationReject),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: FilledButton(
                      key: Key('participation-accept-${request.id}'),
                      onPressed: enabled ? onAccept : null,
                      child: isActing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.participationAccept),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.enabled,
    required this.isActing,
    required this.onCommitments,
    required this.onActualContributions,
    required this.onRemove,
  });

  final CreatorProjectMember member;
  final bool enabled;
  final bool isActing;
  final VoidCallback onCommitments;
  final VoidCallback? onActualContributions;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: Key('participation-member-${member.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              member.participantDisplayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(_membershipStatusLabel(l10n, member.status)),
            Text(
              l10n.participationJoinedAt(_formatDate(context, member.joinedAt)),
            ),
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('participation-commitments-${member.id}'),
                    onPressed: enabled ? onCommitments : null,
                    icon: const Icon(Icons.checklist_outlined),
                    label: Text(
                      member.isCurrent
                          ? l10n.participationCommitments
                          : l10n.participationViewCommitments,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (onActualContributions case final action?) ...[
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key(
                        'participation-actual-contributions-${member.id}',
                      ),
                      onPressed: enabled ? action : null,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        l10n.actualContributionsAction,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (member.isCurrent) ...[
              const SizedBox(height: AppSpacing.small),
              OutlinedButton.icon(
                key: Key('participation-remove-${member.id}'),
                onPressed: enabled ? onRemove : null,
                icon: isActing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove_outlined),
                label: Text(l10n.participationRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _requestStatusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    switch (status) {
      JoinRequestStatus.pending => l10n.participationStatusPending,
      JoinRequestStatus.accepted => l10n.participationStatusAccepted,
      JoinRequestStatus.rejected => l10n.participationStatusRejected,
      JoinRequestStatus.withdrawn => l10n.participationStatusWithdrawn,
    };

String _membershipStatusLabel(AppLocalizations l10n, MembershipStatus status) =>
    switch (status) {
      MembershipStatus.current => l10n.participationStatusCurrent,
      MembershipStatus.left => l10n.participationStatusLeft,
      MembershipStatus.removed => l10n.participationStatusRemoved,
    };

String _formatDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .add_jm()
        .format(value.toLocal());
