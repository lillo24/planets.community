import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/project_participation_section.dart';
import '../../profile_photo/application/project_creator_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../../project_resource_needs/presentation/project_resource_needs_section.dart';
import '../application/proposal_controllers.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';
import 'proposal_widgets.dart';
import 'skill_filter.dart';

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
    _localityController = TextEditingController(
      text: ref.read(publicProposalsProvider).locality,
    );
    if (ref.read(publicProposalsProvider).phase == ProposalLoadPhase.idle) {
      Future<void>.microtask(
        () => ref.read(publicProposalsProvider.notifier).load(),
      );
    }
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
            onPressed: () => context.go('/proposals/mine'),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child:
            state.phase == ProposalLoadPhase.loading &&
                state.items.isEmpty &&
                state.requestedItems.isEmpty
            ? LoadingState(message: l10n.proposalLoading)
            : state.phase == ProposalLoadPhase.failure &&
                  state.items.isEmpty &&
                  state.requestedItems.isEmpty
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
                    const BrowseActivitySwitcher(
                      selected: BrowseActivityType.proposals,
                    ),
                    const SizedBox(height: AppSpacing.medium),
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
                      SkillFilter(
                        categories: state.categories,
                        selectedIds: state.selectedSkillIds,
                        enabled: !state.isBusy,
                        onApply: (selection) => ref
                            .read(publicProposalsProvider.notifier)
                            .applyFilters(
                              locality: _localityController.text,
                              skillIds: selection,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    if (state.items.isEmpty && state.requestedItems.isEmpty)
                      EmptyState(
                        title: l10n.proposalEmptyTitle,
                        message: l10n.proposalEmptyMessage,
                        icon: Icons.event_available_outlined,
                      )
                    else ...[
                      if (state.requestedItems.isNotEmpty) ...[
                        Text(
                          l10n.browseRequestedSection,
                          key: const Key('proposal-requested-section'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        for (final requested in state.requestedItems) ...[
                          ProposalCard(
                            proposal: requested.proposal,
                            isRequested: true,
                            onTap: () => context.go(
                              '/proposals/${requested.proposal.id}',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
                        ],
                      ],
                      if (state.requestedItems.isNotEmpty &&
                          state.ordinaryItems.isNotEmpty) ...[
                        Text(
                          l10n.browseOtherProjectsSection,
                          key: const Key('proposal-other-section'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                      for (final proposal in state.ordinaryItems) ...[
                        ProposalCard(
                          proposal: proposal,
                          onTap: () => context.go('/proposals/${proposal.id}'),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
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
        onPressed: () => context.go('/proposals/create'),
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
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    await Future.wait([
      ref.read(proposalDetailProvider.notifier).load(widget.proposalId),
      ref
          .read(projectCreatorPhotoProvider.notifier)
          .load(widget.proposalId, force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalDetailProvider);
    final detail = state.proposalId == widget.proposalId ? state.detail : null;
    final organizerPhoto = ref
        .watch(projectCreatorPhotoProvider)
        .entryFor(widget.proposalId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.proposalDetailTitle)),
      body: SafeArea(
        child: detail == null && state.phase == ProposalLoadPhase.loading
            ? LoadingState(message: l10n.proposalLoading)
            : detail == null
            ? ErrorState(message: l10n.proposalSafeError, onRetry: _load)
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
                  ProjectResourceNeedsSection(projectId: detail.summary.id),
                  if (ref.watch(authSessionProvider).identity?.id ==
                      detail.creatorProfileId) ...[
                    const SizedBox(height: AppSpacing.medium),
                    OutlinedButton.icon(
                      key: Key('project-resources-manage-${detail.summary.id}'),
                      onPressed: () => context.push(
                        ProjectResourceNeedRoutes.manage(
                          ProjectKind.oneTime,
                          detail.summary.id,
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l10n.projectResourcesManage),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  ProjectParticipationSection(
                    projectId: detail.summary.id,
                    projectKind: ProjectKind.oneTime,
                    creatorProfileId: detail.creatorProfileId,
                    acceptsNewRequests:
                        detail.summary.status == ProposalStatus.upcoming ||
                        detail.summary.status == ProposalStatus.happening,
                    publicLocationLines: [detail.summary.publicLocationLabel],
                    publicExactMeetingText: detail.exactMeetingText,
                    exactLocationRestricted: detail.exactLocationRestricted,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  ListTile(
                    key: const Key('proposal-organizer-identity'),
                    contentPadding: EdgeInsets.zero,
                    leading: VisibleProfilePhotoAvatar(
                      entry: organizerPhoto,
                      imageSemanticsLabel:
                          l10n.profilePhotoOrganizerAvatarLabel,
                      placeholderSemanticsLabel:
                          l10n.profilePhotoOrganizerAvatarLabel,
                    ),
                    title: Text(
                      '${l10n.proposalOrganizedBy} '
                      '${detail.creatorDisplayName ?? l10n.profilePhotoOrganizerFallback}',
                    ),
                  ),
                  if (ref.watch(authSessionProvider).phase ==
                          AuthSessionPhase.ready &&
                      ref.watch(authSessionProvider).identity?.id !=
                          detail.creatorProfileId) ...[
                    const SizedBox(height: AppSpacing.small),
                    OutlinedButton.icon(
                      key: const Key('proposal-report-action'),
                      onPressed: () => ModerationRoutes.openReport(
                        context,
                        projectReportTarget(
                          detail.summary.id,
                          detail.summary.title,
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(l10n.moderationReportAction),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
