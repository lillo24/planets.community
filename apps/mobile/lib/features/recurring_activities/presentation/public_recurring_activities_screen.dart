import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/event_time.dart';
import '../../../core/widgets/async_data_presentation.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/project_participation_section.dart';
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
      appBar: AppBar(
        title: Text(l10n.tavoliTitle),
        actions: [
          IconButton(
            key: const Key('my-tavoli-action'),
            tooltip: l10n.tavoliMyTitle,
            onPressed: () => context.push('/tavoli/mine'),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child:
            state.phase == RecurringActivityLoadPhase.loading &&
                state.items.isEmpty &&
                state.requestedItems.isEmpty
            ? LoadingState(message: l10n.tavoliLoading)
            : state.phase == RecurringActivityLoadPhase.failure &&
                  state.items.isEmpty &&
                  state.requestedItems.isEmpty
            ? ErrorState(
                message: l10n.tavoliSafeError,
                onRetry: () =>
                    ref.read(publicRecurringActivitiesProvider.notifier).load(),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(publicRecurringActivitiesProvider.notifier).load(),
                child: ListView(
                  key: const PageStorageKey('public-tavoli-list'),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    const BrowseActivitySwitcher(
                      selected: BrowseActivityType.tavoli,
                    ),
                    const SizedBox(height: AppSpacing.medium),
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
                                      publicRecurringActivitiesProvider
                                          .notifier,
                                    )
                                    .applyLocality(_localityController.text),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    if (state.items.isEmpty && state.requestedItems.isEmpty)
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
                          RecurringActivityCard(
                            activity: requested.activity,
                            isRequested: true,
                            onTap: () => context.push(
                              '/tavoli/${requested.activity.id}',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
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
                        RecurringActivityCard(
                          activity: activity,
                          onTap: () => context.push('/tavoli/${activity.id}'),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    ],
                    if (state.phase == RecurringActivityLoadPhase.failure &&
                        state.items.isNotEmpty)
                      Text(
                        l10n.tavoliSafeError,
                        key: const Key('tavoli-safe-error'),
                      ),
                    if (state.items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('tavoli-load-more'),
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    publicRecurringActivitiesProvider.notifier,
                                  )
                                  .load(reset: false),
                        child:
                            state.phase ==
                                RecurringActivityLoadPhase.loadingMore
                            ? const CircularProgressIndicator()
                            : Text(l10n.tavoliLoadMore),
                      ),
                  ],
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
    super.key,
  });
  final String activityId;

  @override
  ConsumerState<PublicRecurringActivityDetailScreen> createState() =>
      _PublicRecurringActivityDetailScreenState();
}

class _PublicRecurringActivityDetailScreenState
    extends ConsumerState<PublicRecurringActivityDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(publicRecurringActivityDetailProvider.notifier)
          .load(widget.activityId),
    );
  }

  @override
  void didUpdateWidget(
    covariant PublicRecurringActivityDetailScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId == widget.activityId) return;
    Future<void>.microtask(
      () => ref
          .read(publicRecurringActivityDetailProvider.notifier)
          .load(widget.activityId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicRecurringActivityDetailProvider);
    final detail = state.activityId == widget.activityId ? state.detail : null;
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
        appBar: AppBar(title: Text(l10n.tavoliDetailTitle)),
        body: LoadingState(message: l10n.tavoliLoading),
      );
    }
    if (presentation != AsyncDataPresentation.content) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tavoliDetailTitle)),
        body: ErrorState(
          message: l10n.tavoliSafeError,
          onRetry: () => ref
              .read(publicRecurringActivityDetailProvider.notifier)
              .load(widget.activityId),
        ),
      );
    }
    final resolvedDetail = detail!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tavoliDetailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
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
            Text(formatRecurringSchedule(resolvedDetail.schedule, context)),
            Text(l10n.tavoliTimezone(resolvedDetail.schedule.eventTimezone)),
            Text(l10n.tavoliDuration(resolvedDetail.schedule.durationMinutes)),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    formatEventDateTime(
                      occurrence.startsAt,
                      occurrence.eventTimezone,
                      locale,
                    ),
                  ),
                  subtitle: Text(
                    '${formatEventDateTime(occurrence.endsAt, occurrence.eventTimezone, locale)} · ${occurrence.eventTimezone}',
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
            ProjectParticipationSection(
              projectId: resolvedDetail.id,
              projectKind: ProjectKind.recurring,
              creatorProfileId: resolvedDetail.creatorProfileId,
              acceptsNewRequests:
                  resolvedDetail.lifecycle ==
                  RecurringActivityLifecycle.published,
              publicLocationLines: [
                '${resolvedDetail.publicLocationLabel} · ${resolvedDetail.locality}',
                ?resolvedDetail.administrativeArea,
              ],
              publicExactMeetingText: resolvedDetail.exactMeetingText,
              exactLocationRestricted: resolvedDetail.exactLocationRestricted,
            ),
            if (resolvedDetail.creatorDisplayName case final creator?) ...[
              const SizedBox(height: AppSpacing.large),
              Text(l10n.tavoliOrganizedBy(creator)),
            ],
          ],
        ),
      ),
    );
  }
}
