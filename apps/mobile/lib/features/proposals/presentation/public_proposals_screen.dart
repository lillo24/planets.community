import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../geographic_discovery/domain/map_discovery.dart';
import '../../geographic_discovery/presentation/map_view_button.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../locations/domain/location_preview.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../../core/widgets/async_data_presentation.dart';
import '../../../core/widgets/browse_filter_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../../auth/domain/auth_models.dart';
import '../../drafts/domain/draft_entry.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../participation/application/participation_controllers.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/project_participation_section.dart';
import '../../project_participant_invites/presentation/project_share_action.dart';
import '../../profile_photo/application/project_creator_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../../project_resource_needs/presentation/project_resource_needs_section.dart';
import '../application/proposal_controllers.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';
import 'proposal_widgets.dart';
import 'skill_filter.dart';
import '../../template_workshop/presentation/template_workshop_screens.dart';

class PublicProposalsScreen extends ConsumerStatefulWidget {
  const PublicProposalsScreen({this.tutorialPlaceholder, super.key});

  /// Labelled, read-only illustration used only by the tutorial after its
  /// bounded public read fails. It is never inserted into public state.
  final Widget? tutorialPlaceholder;

  @override
  ConsumerState<PublicProposalsScreen> createState() =>
      _PublicProposalsScreenState();
}

class _PublicProposalsScreenState extends ConsumerState<PublicProposalsScreen> {
  static const _searchDebounce = Duration(milliseconds: 350);

  late final TextEditingController _queryController;
  late final TextEditingController _localityController;
  Timer? _queryDebounce;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(publicProposalsProvider);
    _queryController = TextEditingController(text: current.query);
    _localityController = TextEditingController(text: current.locality);
    if (current.phase == ProposalLoadPhase.idle) {
      Future<void>.microtask(
        () => ref.read(publicProposalsProvider.notifier).load(),
      );
    }
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _queryController.dispose();
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
            key: const Key('template-workshop-action'),
            tooltip: l10n.workshopTitle,
            onPressed: () => context.push(WorkshopRoutes.catalog),
            icon: const Icon(Icons.auto_stories_outlined),
          ),
          IconButton(
            key: const Key('my-proposals-action'),
            tooltip: l10n.draftsTitle,
            onPressed: () =>
                context.push(DraftRoutes.contextual({DraftKind.project})),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(publicProposalsProvider.notifier).load(),
          child: ListView(
            key: const PageStorageKey('public-proposals-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              const BrowseActivitySwitcher(
                selected: BrowseActivityType.proposals,
              ),
              MapViewButton(
                origin: MapDiscoveryOrigin.projects,
                prepare: _flushQuery,
              ),
              const SizedBox(height: 8),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('proposal-query-filter'),
                      controller: _queryController,
                      maxLength: 120,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: l10n.proposalSearchLabel,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.small,
                        ),
                        counterText: '',
                      ),
                      onChanged: (_) => _scheduleQuery(),
                      onSubmitted: (_) => _flushQuery(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  BrowseFilterButton(
                    key: const Key('proposal-toggle-filters'),
                    expanded: _filtersExpanded,
                    hasActiveFilters:
                        state.locality.trim().isNotEmpty ||
                        state.selectedSkillIds.isNotEmpty,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _filtersExpanded = !_filtersExpanded);
                    },
                  ),
                ],
              ),
              if (_filtersExpanded) ...[
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  key: const Key('proposal-locality-filter'),
                  controller: _localityController,
                  decoration: InputDecoration(
                    labelText: l10n.proposalLocalityFilter,
                    suffixIcon: IconButton(
                      key: const Key('proposal-apply-filters'),
                      onPressed: state.isBusy ? null : _applyFilters,
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
                    onApply: (selection) => _applyFilters(skillIds: selection),
                  ),
                ],
              ],
              if (state.phase == ProposalLoadPhase.loading &&
                  !(state.items.isEmpty && state.requestedItems.isEmpty))
                LinearProgressIndicator(semanticsLabel: l10n.proposalLoading),
              const SizedBox(height: AppSpacing.medium),
              if (widget.tutorialPlaceholder != null)
                widget.tutorialPlaceholder!
              else if ((state.phase == ProposalLoadPhase.idle ||
                      state.phase == ProposalLoadPhase.loading) &&
                  state.items.isEmpty &&
                  state.requestedItems.isEmpty)
                LoadingState(message: l10n.proposalLoading)
              else if (state.phase == ProposalLoadPhase.failure &&
                  state.items.isEmpty &&
                  state.requestedItems.isEmpty)
                ErrorState(
                  message: l10n.proposalSafeError,
                  onRetry: () =>
                      ref.read(publicProposalsProvider.notifier).load(),
                )
              else if (state.items.isEmpty && state.requestedItems.isEmpty)
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
                      onTap: () =>
                          context.push('/proposals/${requested.proposal.id}'),
                    ),
                    const SizedBox(height: AppSpacing.medium),
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
                    onTap: () => context.push('/proposals/${proposal.id}'),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
              ],
              if (state.phase == ProposalLoadPhase.failure &&
                  state.items.isNotEmpty)
                ErrorState(
                  key: const Key('proposal-safe-error'),
                  message: l10n.proposalSafeError,
                  onRetry: () =>
                      ref.read(publicProposalsProvider.notifier).load(),
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
              const LocationAttribution(),
              // Let credit links scroll above the floating Create action.
              const SizedBox(height: 80),
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

  void _scheduleQuery() {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(_searchDebounce, _applyFilters);
  }

  void _flushQuery() {
    _queryDebounce?.cancel();
    _applyFilters();
  }

  void _applyFilters({Set<String>? skillIds}) {
    _queryDebounce?.cancel();
    final state = ref.read(publicProposalsProvider);
    unawaited(
      ref
          .read(publicProposalsProvider.notifier)
          .applyFilters(
            query: _queryController.text,
            locality: _localityController.text,
            skillIds: skillIds ?? state.selectedSkillIds,
          ),
    );
  }
}

class ProposalDetailScreen extends ConsumerStatefulWidget {
  const ProposalDetailScreen({
    required this.proposalId,
    this.joinIntent = false,
    this.tutorialPreview = false,
    super.key,
  });

  final String proposalId;
  final bool joinIntent;

  /// Reuse prefetched public detail and measure every real section before
  /// the guided scroll. Ordinary detail keeps its lazy list and fresh read.
  final bool tutorialPreview;

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
      widget.tutorialPreview
          ? ref
                .read(proposalDetailProvider.notifier)
                .ensureLoaded(widget.proposalId)
          : ref.read(proposalDetailProvider.notifier).load(widget.proposalId),
      ref
          .read(projectCreatorPhotoProvider.notifier)
          .load(widget.proposalId, force: true),
    ]);
  }

  @override
  void didUpdateWidget(covariant ProposalDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposalId == widget.proposalId) return;
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalDetailProvider);
    final detail = state.proposalId == widget.proposalId ? state.detail : null;
    final organizerPhoto = ref
        .watch(projectCreatorPhotoProvider)
        .entryFor(widget.proposalId);
    final presentation = classifyAsyncDataPresentation(
      belongsToTarget: state.proposalId == widget.proposalId,
      hasData: detail != null,
      isPending:
          state.phase == ProposalLoadPhase.idle ||
          state.phase == ProposalLoadPhase.loading,
      hasFailed: state.phase == ProposalLoadPhase.failure,
    );
    final emptyDetail = switch (presentation) {
      AsyncDataPresentation.loading => LoadingState(
        message: l10n.proposalLoading,
      ),
      AsyncDataPresentation.absent ||
      AsyncDataPresentation.failure => ErrorState(
        message: l10n.proposalSafeError,
        onRetry: () =>
            ref.read(proposalDetailProvider.notifier).load(widget.proposalId),
      ),
      AsyncDataPresentation.content => const SizedBox.shrink(),
    };
    final participation = detail == null
        ? null
        : ProjectParticipationSection(
            projectId: detail.summary.id,
            projectKind: ProjectKind.oneTime,
            creatorProfileId: detail.creatorProfileId,
            acceptsNewRequests:
                detail.summary.status == ProposalStatus.upcoming ||
                detail.summary.status == ProposalStatus.happening,
            publicLocationLines: [detail.summary.publicLocationLabel],
            previewArea: LegacyPreviewArea(
              detail.summary.locality,
              detail.summary.countryCode,
            ),
            publicExactMeetingText: detail.exactMeetingText,
            exactLocationRestricted: detail.exactLocationRestricted,
            capacity: detail.summary.capacity,
          );
    final screen = Scaffold(
      appBar: AppBar(
        title: Text(l10n.proposalDetailTitle),
        actions: [
          if (detail != null)
            ProjectShareAction(
              projectId: detail.summary.id,
              kind: ProjectKind.oneTime,
            ),
        ],
      ),
      body: SafeArea(
        child: detail == null
            ? widget.tutorialPreview
                  ? SingleChildScrollView(child: emptyDetail)
                  : emptyDetail
            : _detailBody(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  ProjectCoverImage(
                    key: Key('proposal-detail-cover-${detail.summary.id}'),
                    title: detail.summary.title,
                    objectPath: detail.summary.coverObjectPath,
                    borderRadius: AppRadii.medium,
                  ),
                  const SizedBox(height: AppSpacing.large),
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
                  Text(
                    detail.description,
                    key: const Key('tutorial-project-purpose'),
                  ),
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
                  ProjectResourceNeedsSection(
                    key: const Key('tutorial-project-needs'),
                    projectId: detail.summary.id,
                  ),
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
                  participation!,
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
                    BlockingActionButton(
                      targetProfileId: detail.creatorProfileId,
                      targetDisplayName: detail.creatorDisplayName,
                      buttonKey: const Key('proposal-blocking-action'),
                      onChanged: (_) async {
                        ref
                            .read(projectCreatorPhotoProvider.notifier)
                            .invalidate(detail.summary.id);
                        await Future.wait([
                          ref
                              .read(projectCreatorPhotoProvider.notifier)
                              .load(detail.summary.id, force: true),
                          if (ref.read(authSessionProvider).identity?.id
                              case final profileId?)
                            ref
                                .read(ownParticipationProvider.notifier)
                                .load(profileId),
                        ]);
                      },
                    ),
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
    return widget.joinIntent && participation != null
        ? participation.withRequestIntent(screen)
        : screen;
  }

  Widget _detailBody({
    required EdgeInsets padding,
    required List<Widget> children,
  }) => widget.tutorialPreview
      ? SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        )
      : ListView(padding: padding, children: children);
}
