import '../../group_discussions/presentation/discussion_group_conversations.dart';
import '../../group_projects/presentation/group_project_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/event_schedule.dart';
import '../../../core/widgets/user_scroll_pagination.dart';
import '../../geographic_discovery/domain/map_discovery.dart';
import '../../geographic_discovery/presentation/map_view_button.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../locations/presentation/independent_public_city.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../locations/domain/location_preview.dart';
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
import '../application/recurring_activity_controllers.dart';
import '../domain/recurring_activity_models.dart';
import 'recurring_activity_widgets.dart';

class PublicRecurringActivitiesScreen extends ConsumerStatefulWidget {
  const PublicRecurringActivitiesScreen({super.key});

  @override
  ConsumerState<PublicRecurringActivitiesScreen> createState() =>
      _PublicRecurringActivitiesScreenState();
}

class _PublicRecurringActivitiesScreenState
    extends ConsumerState<PublicRecurringActivitiesScreen> {
  late final TextEditingController _localityController;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _localityController = TextEditingController(
      text: ref.read(publicRecurringActivitiesProvider).locality,
    );
    if (ref.read(publicRecurringActivitiesProvider).phase ==
        RecurringActivityLoadPhase.idle) {
      Future<void>.microtask(
        () => ref.read(publicRecurringActivitiesProvider.notifier).load(),
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
    final state = ref.watch(publicRecurringActivitiesProvider);
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.tavoliTitle),
        actions: [
          IconButton(
            key: const Key('browse-groups'),
            tooltip: l10n.groupsTitle,
            onPressed: () => context.push('/groups'),
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            key: const Key('my-tavoli-action'),
            tooltip: l10n.draftsTitle,
            onPressed: () =>
                context.push(DraftRoutes.contextual({DraftKind.table})),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(publicRecurringActivitiesProvider.notifier)
              .load(force: true),
          child: UserScrollPagination(
            enabled:
                state.hasMore &&
                !state.isBusy &&
                !(state.phase == RecurringActivityLoadPhase.failure),
            requestKey: (
              state.items.length,
              state.locality,
              ref.watch(authSessionProvider).phase,
              ref.watch(authSessionProvider).identity?.id,
            ),
            onLoad: () => ref
                .read(publicRecurringActivitiesProvider.notifier)
                .load(reset: false),
            builder: (context, showFallback) => ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              physics: const AlwaysScrollableScrollPhysics(),
              key: const PageStorageKey('public-tavoli-list'),
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                const BrowseActivitySwitcher(
                  selected: BrowseActivityType.tavoli,
                ),
                // Match the Project gap below the complete Browse block.
                const SizedBox(height: AppSpacing.medium),
                MapViewButton(origin: MapDiscoveryOrigin.tavoli),
                const SizedBox(height: AppSpacing.medium),
                Align(
                  alignment: Alignment.centerRight,
                  child: BrowseFilterButton(
                    key: const Key('tavoli-toggle-filters'),
                    expanded: _filtersExpanded,
                    hasActiveFilters: state.locality.trim().isNotEmpty,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _filtersExpanded = !_filtersExpanded);
                    },
                  ),
                ),
                if (_filtersExpanded) ...[
                  const SizedBox(height: AppSpacing.small),
                  TextField(
                    key: const Key('tavoli-locality-filter'),
                    controller: _localityController,
                    decoration: InputDecoration(
                      labelText: l10n.tavoliLocalityFilter,
                      suffixIcon: IconButton(
                        key: const Key('tavoli-apply-filter'),
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    publicRecurringActivitiesProvider.notifier,
                                  )
                                  .applyLocality(_localityController.text),
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
                if (state.phase == RecurringActivityLoadPhase.loading &&
                    !(state.items.isEmpty && state.requestedItems.isEmpty))
                  LinearProgressIndicator(semanticsLabel: l10n.tavoliLoading),
                const SizedBox(height: AppSpacing.medium),
                if ((state.phase == RecurringActivityLoadPhase.idle ||
                        state.phase == RecurringActivityLoadPhase.loading) &&
                    state.items.isEmpty &&
                    state.requestedItems.isEmpty)
                  LoadingState(message: l10n.tavoliLoading)
                else if (state.phase == RecurringActivityLoadPhase.failure &&
                    state.items.isEmpty &&
                    state.requestedItems.isEmpty)
                  ErrorState(
                    message: l10n.tavoliSafeError,
                    onRetry: () => ref
                        .read(publicRecurringActivitiesProvider.notifier)
                        .retry(),
                  )
                else if (state.items.isEmpty && state.requestedItems.isEmpty)
                  EmptyState(
                    title: l10n.tavoliEmptyTitle,
                    message: l10n.tavoliEmptyMessage,
                    icon: Icons.autorenew,
                  )
                else ...[
                  if (state.requestedItems.isNotEmpty) ...[
                    Text(
                      l10n.browseRequestedSection,
                      key: const Key('tavolo-requested-section'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    for (final requested in state.requestedItems) ...[
                      Builder(
                        builder: (context) => RecurringActivityCard(
                          activity: requested.activity,
                          isRequested: true,
                          onTap: () =>
                              context.push('/tavoli/${requested.activity.id}'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                  ],
                  if (state.requestedItems.isNotEmpty &&
                      state.ordinaryItems.isNotEmpty) ...[
                    Text(
                      l10n.browseOtherProjectsSection,
                      key: const Key('tavolo-other-section'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                  ],
                  for (final activity in state.ordinaryItems) ...[
                    Builder(
                      builder: (context) => RecurringActivityCard(
                        activity: activity,
                        onTap: () => context.push('/tavoli/${activity.id}'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                ],
                if (state.phase == RecurringActivityLoadPhase.failure &&
                    state.items.isNotEmpty)
                  ErrorState(
                    key: const Key('tavoli-safe-error'),
                    message: l10n.tavoliSafeError,
                    onRetry: () => ref
                        .read(publicRecurringActivitiesProvider.notifier)
                        .retry(),
                  ),
                if (state.phase == RecurringActivityLoadPhase.loadingMore)
                  const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (showFallback &&
                    state.hasMore &&
                    !state.isBusy &&
                    !(state.phase == RecurringActivityLoadPhase.failure))
                  OutlinedButton(
                    key: const Key('tavoli-load-more'),
                    onPressed: () => ref
                        .read(publicRecurringActivitiesProvider.notifier)
                        .load(reset: false),
                    child: Text(l10n.tavoliLoadMore),
                  ),
                // Independent catalogue names require no Geoapify footer.
                if ([
                  ...state.items,
                  ...state.requestedItems.map((x) => x.activity),
                ].any(
                  (x) =>
                      cataloguedPublicCityName(x.locality, x.countryCode) ==
                      null,
                ))
                  const LocationAttribution(),
                // Let credit links scroll above the floating Create action.
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tavoli-create-action'),
        onPressed: () => context.push('/tavoli/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.tavoliCreateTitle),
      ),
    );
  }
}

class PublicRecurringActivityDetailScreen extends ConsumerStatefulWidget {
  const PublicRecurringActivityDetailScreen({
    required this.activityId,
    this.joinIntent = false,
    super.key,
  });
  final String activityId;
  final bool joinIntent;

  @override
  ConsumerState<PublicRecurringActivityDetailScreen> createState() =>
      _PublicRecurringActivityDetailScreenState();
}

class _PublicRecurringActivityDetailScreenState
    extends ConsumerState<PublicRecurringActivityDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    await Future.wait([
      ref
          .read(publicRecurringActivityDetailProvider.notifier)
          .load(widget.activityId),
      ref
          .read(projectCreatorPhotoProvider.notifier)
          .load(widget.activityId, force: true),
    ]);
  }

  @override
  void didUpdateWidget(
    covariant PublicRecurringActivityDetailScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId == widget.activityId) return;
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicRecurringActivityDetailProvider);
    final detail = state.activityId == widget.activityId ? state.detail : null;
    final organizerPhoto = ref
        .watch(projectCreatorPhotoProvider)
        .entryFor(widget.activityId);
    final presentation = classifyAsyncDataPresentation(
      belongsToTarget: state.activityId == widget.activityId,
      hasData: detail != null,
      isPending:
          state.phase == RecurringActivityLoadPhase.idle ||
          state.phase == RecurringActivityLoadPhase.loading,
      hasFailed: state.phase == RecurringActivityLoadPhase.failure,
    );
    if (presentation == AsyncDataPresentation.loading) {
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l10n.tavoliDetailTitle)),
        body: LoadingState(message: l10n.tavoliLoading),
      );
    }
    if (presentation != AsyncDataPresentation.content) {
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l10n.tavoliDetailTitle)),
        body: ErrorState(message: l10n.tavoliSafeError, onRetry: _load),
      );
    }
    final resolvedDetail = detail!;
    final participation = ProjectParticipationSection(
      projectId: resolvedDetail.id,
      projectKind: ProjectKind.recurring,
      creatorProfileId: resolvedDetail.creatorProfileId,
      acceptsNewRequests:
          resolvedDetail.lifecycle == RecurringActivityLifecycle.published,
      publicLocationLines: [
        resolvedDetail.publicLocationLabel,
        ?resolvedDetail.administrativeArea,
      ],
      previewArea: LegacyPreviewArea(
        resolvedDetail.locality,
        resolvedDetail.countryCode,
      ),
      publicExactMeetingText: resolvedDetail.exactMeetingText,
      exactLocationRestricted: resolvedDetail.exactLocationRestricted,
      capacity: resolvedDetail.capacity,
    );
    final screen = Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.tavoliDetailTitle),
        actions: [
          if (resolvedDetail.lifecycle != RecurringActivityLifecycle.draft)
            ProjectShareAction(
              projectId: resolvedDetail.id,
              kind: ProjectKind.recurring,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            ProjectCoverImage(
              key: Key('tavolo-detail-cover-${detail.id}'),
              title: detail.title,
              objectPath: detail.coverObjectPath,
              borderRadius: AppRadii.medium,
            ),
            const SizedBox(height: AppSpacing.large),
            ProjectGroupBadge(resolvedDetail.groupAttribution),
            if (resolvedDetail.groupAttribution?.groupId != null)
              GroupCommunicationEntry(
                groupId: resolvedDetail.groupAttribution!.groupId!,
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    resolvedDetail.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                RecurringLifecycleBadge(lifecycle: resolvedDetail.lifecycle),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              resolvedDetail.summary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (resolvedDetail.topic case final topic?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(topic, style: Theme.of(context).textTheme.labelLarge),
            ],
            const SizedBox(height: AppSpacing.large),
            Text(resolvedDetail.description),
            const SizedBox(height: AppSpacing.large),
            Text(
              l10n.tavoliScheduleTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            ScheduleSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatRecurringSchedule(resolvedDetail.schedule, context),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    l10n.tavoliDuration(
                      resolvedDetail.schedule.durationMinutes,
                    ),
                  ),
                  Text(
                    l10n.tavoliTimezone(resolvedDetail.schedule.eventTimezone),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              l10n.tavoliUpcomingMeetings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            if (resolvedDetail.nextOccurrences.isEmpty)
              Text(l10n.tavoliNoUpcomingMeetings)
            else
              for (final occurrence in resolvedDetail.nextOccurrences)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  child: EventSchedule(
                    startsAt: occurrence.startsAt,
                    endsAt: occurrence.endsAt,
                    timeZone: occurrence.eventTimezone,
                  ),
                ),
            ProjectResourceNeedsSection(projectId: resolvedDetail.id),
            if (ref.watch(authSessionProvider).identity?.id ==
                resolvedDetail.creatorProfileId) ...[
              const SizedBox(height: AppSpacing.medium),
              OutlinedButton.icon(
                key: Key('project-resources-manage-${resolvedDetail.id}'),
                onPressed: () => context.push(
                  ProjectResourceNeedRoutes.manage(
                    ProjectKind.recurring,
                    resolvedDetail.id,
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.projectResourcesManage),
              ),
            ],
            const SizedBox(height: AppSpacing.large),
            participation,
            const SizedBox(height: AppSpacing.large),
            ListTile(
              key: const Key('tavoli-organizer-identity'),
              contentPadding: EdgeInsets.zero,
              leading: VisibleProfilePhotoAvatar(
                entry: organizerPhoto,
                imageSemanticsLabel: l10n.profilePhotoOrganizerAvatarLabel,
                placeholderSemanticsLabel:
                    l10n.profilePhotoOrganizerAvatarLabel,
              ),
              title: Text(
                l10n.tavoliOrganizedBy(
                  resolvedDetail.creatorDisplayName ??
                      l10n.profilePhotoOrganizerFallback,
                ),
              ),
            ),
            if (ref.watch(authSessionProvider).phase ==
                    AuthSessionPhase.ready &&
                ref.watch(authSessionProvider).identity?.id !=
                    resolvedDetail.creatorProfileId) ...[
              const SizedBox(height: AppSpacing.small),
              BlockingActionButton(
                targetProfileId: resolvedDetail.creatorProfileId,
                targetDisplayName: resolvedDetail.creatorDisplayName,
                buttonKey: const Key('tavoli-blocking-action'),
                onChanged: (_) async {
                  ref
                      .read(projectCreatorPhotoProvider.notifier)
                      .invalidate(resolvedDetail.id);
                  await Future.wait([
                    ref
                        .read(projectCreatorPhotoProvider.notifier)
                        .load(resolvedDetail.id, force: true),
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
                key: const Key('tavoli-report-action'),
                onPressed: () => ModerationRoutes.openReport(
                  context,
                  projectReportTarget(resolvedDetail.id, resolvedDetail.title),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l10n.moderationReportAction),
              ),
            ],
          ],
        ),
      ),
    );
    return widget.joinIntent ? participation.withRequestIntent(screen) : screen;
  }
}
