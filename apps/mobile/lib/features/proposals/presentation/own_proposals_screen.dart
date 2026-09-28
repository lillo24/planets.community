import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../application/proposal_controllers.dart';
import '../domain/proposal_models.dart';

class OwnProposalsScreen extends ConsumerStatefulWidget {
  const OwnProposalsScreen({super.key});

  @override
  ConsumerState<OwnProposalsScreen> createState() => _OwnProposalsScreenState();
}

class _OwnProposalsScreenState extends ConsumerState<OwnProposalsScreen> {
  String? _requestedIdentity;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load({bool force = false}) async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity != null && (force || _requestedIdentity != identity.id)) {
      _requestedIdentity = identity.id;
      await Future.wait([
        ref.read(ownProposalsProvider.notifier).load(identity.id),
        ref.read(delegatedProjectsProvider.notifier).load(identity.id),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(ownProposalsProvider);
    final items = state.expectedCreatorId == identity?.id
        ? state.items
        : const <OwnProposal>[];
    final delegatedState = ref.watch(delegatedProjectsProvider);
    final delegated = delegatedState.expectedProfileId == identity?.id
        ? delegatedState.items
              .where((item) => item.kind == ProjectKind.oneTime)
              .toList(growable: false)
        : const <DelegatedProject>[];
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.proposalMyTitle)),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : items.isEmpty &&
                  delegated.isEmpty &&
                  (state.phase == ProposalLoadPhase.loading ||
                      delegatedState.phase == ProjectDelegateLoadPhase.loading)
            ? LoadingState(message: l10n.proposalLoading)
            : items.isEmpty &&
                  delegated.isEmpty &&
                  (state.phase == ProposalLoadPhase.failure ||
                      delegatedState.phase == ProjectDelegateLoadPhase.failure)
            ? ErrorState(
                message: l10n.proposalSafeError,
                onRetry: () => _load(force: true),
              )
            : items.isEmpty && delegated.isEmpty
            ? EmptyState(
                title: l10n.proposalMyEmpty,
                message: l10n.proposalMyEmptyMessage,
              )
            : RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    Text(
                      l10n.projectCreatedByYouTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (items.isEmpty &&
                        state.phase == ProposalLoadPhase.failure) ...[
                      Text(l10n.proposalSafeError),
                      TextButton(
                        onPressed: () => _load(force: true),
                        child: Text(l10n.retryAction),
                      ),
                    ] else if (items.isEmpty)
                      Text(l10n.projectCreatedByYouEmpty)
                    else
                      for (final proposal in items) ...[
                        _OwnProposalCard(
                          proposal: proposal,
                          identityId: identity.id,
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      l10n.projectCoorganizingTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (delegated.isEmpty &&
                        delegatedState.phase ==
                            ProjectDelegateLoadPhase.failure) ...[
                      Text(l10n.projectDelegateSafeError),
                      TextButton(
                        onPressed: () => _load(force: true),
                        child: Text(l10n.retryAction),
                      ),
                    ] else if (delegated.isEmpty)
                      Text(l10n.projectCoorganizingEmpty)
                    else
                      for (final project in delegated) ...[
                        _DelegatedProposalCard(project: project),
                        const SizedBox(height: AppSpacing.small),
                      ],
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/proposals/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.proposalCreateTitle),
      ),
    );
  }
}

class _DelegatedProposalCard extends StatelessWidget {
  const _DelegatedProposalCard({required this.project});

  final DelegatedProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lifecycle = switch (project.status) {
      'completed' => l10n.proposalStatusCompleted,
      'cancelled' => l10n.proposalLifecycleCancelled,
      _ => l10n.proposalLifecyclePublished,
    };
    return Card(
      key: Key('delegated-proposal-${project.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xSmall),
            Text('${_roleLabel(l10n, project.authorityRole)} · $lifecycle'),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                OutlinedButton(
                  onPressed: () => context.push('/proposals/${project.id}'),
                  child: Text(l10n.tavoliView),
                ),
                FilledButton.tonal(
                  key: Key('delegated-proposal-manage-${project.id}'),
                  onPressed: () => context.push(
                    ProjectDelegateRoutes.manage(project.kind, project.id),
                  ),
                  child: Text(l10n.projectManageTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, ProjectDelegatedAuthorityRole role) =>
    switch (role) {
      ProjectDelegatedAuthorityRole.coCreator => l10n.projectCocreatorBadge,
      ProjectDelegatedAuthorityRole.coOrganizer => l10n.projectCoorganizerBadge,
    };

class _OwnProposalCard extends ConsumerWidget {
  const _OwnProposalCard({required this.proposal, required this.identityId});

  final OwnProposal proposal;
  final String identityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(proposalClockProvider)();
    final lifecycle = switch (proposal.lifecycle) {
      ProposalLifecycle.draft => l10n.proposalLifecycleDraft,
      ProposalLifecycle.published =>
        proposal.status == ProposalStatus.completed
            ? l10n.proposalStatusCompleted
            : l10n.proposalLifecyclePublished,
      ProposalLifecycle.cancelled => l10n.proposalLifecycleCancelled,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal.title ?? l10n.proposalUntitled,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(lifecycle, key: Key('own-proposal-state-${proposal.id}')),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                OutlinedButton.icon(
                  key: Key('proposal-resources-${proposal.id}'),
                  onPressed: () => context.push(
                    ProjectResourceNeedRoutes.manage(
                      ProjectKind.oneTime,
                      proposal.id,
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.projectResourcesManage),
                ),
                if (proposal.isEditableAt(now))
                  OutlinedButton(
                    key: Key('proposal-edit-${proposal.id}'),
                    onPressed: () =>
                        context.push('/proposals/${proposal.id}/edit'),
                    child: Text(l10n.proposalEditAction),
                  ),
                if (proposal.lifecycle == ProposalLifecycle.draft)
                  FilledButton(
                    key: Key('proposal-publish-${proposal.id}'),
                    onPressed: () async {
                      final published = await ref
                          .read(ownProposalsProvider.notifier)
                          .publish(identityId, proposal.id);
                      if (!published && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.proposalSafeError)),
                        );
                      }
                    },
                    child: Text(l10n.proposalPublishAction),
                  ),
                if (proposal.canCancelAt(now))
                  TextButton(
                    key: Key('proposal-cancel-${proposal.id}'),
                    onPressed: () => _confirmCancel(context, ref),
                    child: Text(l10n.proposalCancelAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.proposalCancelConfirmTitle),
        content: Text(l10n.proposalCancelConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.proposalKeepAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.proposalCancelAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(ownProposalsProvider.notifier)
          .cancel(identityId, proposal.id);
    }
  }
}
