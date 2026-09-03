import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/proposal_controllers.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';
import 'proposal_widgets.dart';

class PublicProposalsScreen extends ConsumerStatefulWidget {
  const PublicProposalsScreen({super.key});

  @override
  ConsumerState<PublicProposalsScreen> createState() =>
      _PublicProposalsScreenState();
}

class _PublicProposalsScreenState extends ConsumerState<PublicProposalsScreen> {
  late final TextEditingController _localityController;

  @override
  void initState() {
    super.initState();
    _localityController = TextEditingController();
    Future<void>.microtask(
      () => ref.read(publicProposalsProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicProposalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.proposalsTitle),
        actions: [
          IconButton(
            key: const Key('my-proposals-action'),
            tooltip: l10n.proposalMyTitle,
            onPressed: () => context.push('/proposals/mine'),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: state.phase == ProposalLoadPhase.loading && state.items.isEmpty
            ? LoadingState(message: l10n.proposalLoading)
            : state.phase == ProposalLoadPhase.failure && state.items.isEmpty
            ? ErrorState(
                message: l10n.proposalSafeError,
                onRetry: () =>
                    ref.read(publicProposalsProvider.notifier).load(),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(publicProposalsProvider.notifier).load(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    TextField(
                      key: const Key('proposal-locality-filter'),
                      controller: _localityController,
                      decoration: InputDecoration(
                        labelText: l10n.proposalLocalityFilter,
                        suffixIcon: IconButton(
                          key: const Key('proposal-apply-filters'),
                          onPressed: state.isBusy
                              ? null
                              : () => ref
                                    .read(publicProposalsProvider.notifier)
                                    .applyFilters(
                                      locality: _localityController.text,
                                      skillIds: state.selectedSkillIds,
                                    ),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    if (state.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.medium),
                      Text(l10n.proposalSkillsFilter),
                      const SizedBox(height: AppSpacing.small),
                      Wrap(
                        spacing: AppSpacing.small,
                        children: [
                          for (final category in state.categories)
                            for (final skill in category.skills)
                              FilterChip(
                                key: Key('proposal-filter-skill-${skill.slug}'),
                                label: Text(skill.label),
                                selected: state.selectedSkillIds.contains(
                                  skill.id,
                                ),
                                onSelected: state.isBusy
                                    ? null
                                    : (selected) {
                                        final selectedIds = {
                                          ...state.selectedSkillIds,
                                        };
                                        selected
                                            ? selectedIds.add(skill.id)
                                            : selectedIds.remove(skill.id);
                                        ref
                                            .read(
                                              publicProposalsProvider.notifier,
                                            )
                                            .applyFilters(
                                              locality:
                                                  _localityController.text,
                                              skillIds: selectedIds,
                                            );
                                      },
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    if (state.items.isEmpty)
                      EmptyState(
                        title: l10n.proposalEmptyTitle,
                        message: l10n.proposalEmptyMessage,
                        icon: Icons.event_available_outlined,
                      )
                    else
                      for (final proposal in state.items) ...[
                        ProposalCard(
                          proposal: proposal,
                          onTap: () =>
                              context.push('/proposals/${proposal.id}'),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    if (state.phase == ProposalLoadPhase.failure &&
                        state.items.isNotEmpty)
                      Text(
                        l10n.proposalSafeError,
                        key: const Key('proposal-safe-error'),
                      ),
                    if (state.items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('proposal-load-more'),
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                  .read(publicProposalsProvider.notifier)
                                  .load(reset: false),
                        child: state.phase == ProposalLoadPhase.loadingMore
                            ? const CircularProgressIndicator()
                            : Text(l10n.proposalLoadMore),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('proposal-create-action'),
        onPressed: () => context.push('/proposals/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.proposalCreateTitle),
      ),
    );
  }
}

class ProposalDetailScreen extends ConsumerStatefulWidget {
  const ProposalDetailScreen({required this.proposalId, super.key});

  final String proposalId;

  @override
  ConsumerState<ProposalDetailScreen> createState() =>
      _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends ConsumerState<ProposalDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(proposalDetailProvider.notifier).load(widget.proposalId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalDetailProvider);
    final detail = state.proposalId == widget.proposalId ? state.detail : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.proposalDetailTitle)),
      body: SafeArea(
        child: detail == null && state.phase == ProposalLoadPhase.loading
            ? LoadingState(message: l10n.proposalLoading)
            : detail == null
            ? ErrorState(
                message: l10n.proposalSafeError,
                onRetry: () => ref
                    .read(proposalDetailProvider.notifier)
                    .load(widget.proposalId),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detail.summary.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      ProposalStatusBadge(status: detail.summary.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    detail.summary.summary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Text(detail.description),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    l10n.proposalScheduleTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '${l10n.proposalStartLabel}: ${formatProposalDateTime(detail.summary.startsAt, detail.summary.eventTimezone, Localizations.localeOf(context).toLanguageTag())}',
                  ),
                  Text(
                    '${l10n.proposalEndLabel}: ${formatProposalDateTime(detail.summary.endsAt, detail.summary.eventTimezone, Localizations.localeOf(context).toLanguageTag())}',
                  ),
                  Text(detail.summary.eventTimezone),
                  if (detail.summary.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      l10n.proposalSkillsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    ProposalSkillRequirements(skills: detail.summary.skills),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  ProposalLocation(detail: detail),
                  if (detail.creatorDisplayName != null) ...[
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      '${l10n.proposalOrganizedBy} ${detail.creatorDisplayName}',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
