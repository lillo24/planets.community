import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../locations/presentation/location_attribution.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../resource_listings/presentation/resource_listing_widgets.dart';
import '../application/project_resource_matches_controller.dart';
import '../application/project_resource_needs_controllers.dart';
import '../domain/project_resource_match_models.dart';
import '../domain/project_resource_need_models.dart';

class ProjectResourceMatchesScreen extends ConsumerStatefulWidget {
  const ProjectResourceMatchesScreen({
    required this.projectId,
    required this.resourceNeedId,
    super.key,
  });

  final String projectId;
  final String resourceNeedId;

  @override
  ConsumerState<ProjectResourceMatchesScreen> createState() =>
      _ProjectResourceMatchesScreenState();
}

class _ProjectResourceMatchesScreenState
    extends ConsumerState<ProjectResourceMatchesScreen> {
  late final String? _expectedCreatorProfileId;

  ProjectResourceMatchesKey get _key => ProjectResourceMatchesKey(
    projectId: widget.projectId,
    resourceNeedId: widget.resourceNeedId,
  );

  @override
  void initState() {
    super.initState();
    _expectedCreatorProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = _currentProfileId();
    if (profileId == null) return;
    await Future.wait([
      ref
          .read(ownProjectResourceNeedsProvider(widget.projectId).notifier)
          .load(profileId),
      ref.read(projectResourceMatchesProvider(_key).notifier).load(profileId),
    ]);
  }

  Future<void> _refresh() async {
    final profileId = _currentProfileId();
    if (profileId == null) return;
    await Future.wait([
      ref
          .read(ownProjectResourceNeedsProvider(widget.projectId).notifier)
          .load(profileId),
      ref
          .read(projectResourceMatchesProvider(_key).notifier)
          .refresh(profileId),
    ]);
  }

  String? _currentProfileId() {
    final current = ref.read(authSessionProvider).identity?.id;
    return current == _expectedCreatorProfileId ? current : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectResourceMatchesProvider(_key));
    final ownerState = ref.watch(
      ownProjectResourceNeedsProvider(widget.projectId),
    );
    final belongsToScreen =
        state.expectedCreatorProfileId == _expectedCreatorProfileId &&
        state.projectId == widget.projectId &&
        state.resourceNeedId == widget.resourceNeedId;
    final items = belongsToScreen
        ? state.items
        : const <ProjectResourceListingMatch>[];
    final sourceNeed = _sourceNeed(ownerState);
    final initiallyLoading =
        !belongsToScreen ||
        (state.phase == ProjectResourceMatchesPhase.loading && items.isEmpty);

    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.projectResourceMatchesTitle),
      ),
      bottomNavigationBar: const SafeArea(child: LocationAttribution()),
      body: SafeArea(
        child: initiallyLoading
            ? LoadingState(message: l10n.projectResourceMatchesLoading)
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    _SourceNeedHeader(need: sourceNeed),
                    const SizedBox(height: AppSpacing.large),
                    _MatchFilters(
                      state: state,
                      onLocationChanged: _setLocationScope,
                      onModeChanged: _setListingMode,
                    ),
                    const SizedBox(height: AppSpacing.large),
                    if (state.phase == ProjectResourceMatchesPhase.failure &&
                        items.isEmpty)
                      ErrorState(
                        message: _failureMessage(l10n, state.failure),
                        onRetry: _load,
                      )
                    else if (items.isEmpty)
                      EmptyState(
                        title: state.hasFilters
                            ? l10n.projectResourceMatchesFilteredEmptyTitle
                            : l10n.projectResourceMatchesBroadEmptyTitle,
                        message: state.hasFilters
                            ? l10n.projectResourceMatchesFilteredEmptyMessage
                            : l10n.projectResourceMatchesBroadEmptyMessage,
                        icon: Icons.manage_search_outlined,
                      )
                    else
                      for (final match in items) ...[
                        PublicResourceListingCard(
                          listing: match.listingSummary,
                          now: DateTime.now().toUtc(),
                          semanticDetails: [
                            l10n.projectResourceMatchesWhy,
                            _textReason(l10n, match.textMatchKind),
                            _locationReason(l10n, match.locationMatchKind),
                          ],
                          footer: _MatchReasons(match: match),
                          onTap: () =>
                              context.go('/resources/${match.listingId}'),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    if (state.phase == ProjectResourceMatchesPhase.failure &&
                        items.isNotEmpty)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.small,
                          ),
                          child: Text(
                            _failureMessage(l10n, state.failure),
                            key: const Key('project-resource-match-error'),
                          ),
                        ),
                      ),
                    if (items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('project-resource-match-load-more'),
                        onPressed: state.isBusy ? null : _loadMore,
                        child:
                            state.phase ==
                                ProjectResourceMatchesPhase.loadingMore
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.projectResourceMatchesLoadMore),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  ProjectResourceNeed? _sourceNeed(OwnProjectResourceNeedsState ownerState) {
    if (ownerState.expectedCreatorProfileId != _expectedCreatorProfileId ||
        ownerState.projectId != widget.projectId) {
      return null;
    }
    for (final need in ownerState.items) {
      if (need.id == widget.resourceNeedId) return need;
    }
    return null;
  }

  void _setLocationScope(ProjectResourceLocationScope scope) {
    final profileId = _currentProfileId();
    if (profileId == null) return;
    unawaited(
      ref
          .read(projectResourceMatchesProvider(_key).notifier)
          .setLocationScope(
            expectedCreatorProfileId: profileId,
            locationScope: scope,
          ),
    );
  }

  void _setListingMode(ProjectResourceListingModeFilter mode) {
    final profileId = _currentProfileId();
    if (profileId == null) return;
    unawaited(
      ref
          .read(projectResourceMatchesProvider(_key).notifier)
          .setListingMode(
            expectedCreatorProfileId: profileId,
            listingMode: mode,
          ),
    );
  }

  void _loadMore() {
    final profileId = _currentProfileId();
    if (profileId == null) return;
    unawaited(
      ref
          .read(projectResourceMatchesProvider(_key).notifier)
          .loadMore(profileId),
    );
  }
}

class _SourceNeedHeader extends StatelessWidget {
  const _SourceNeedHeader({required this.need});

  final ProjectResourceNeed? need;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: [
        l10n.projectResourceMatchesNeedLabel,
        need?.title ?? l10n.projectResourceMatchesNeedUnavailable,
        ?need?.details,
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.projectResourceMatchesNeedLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Text(
            need?.title ?? l10n.projectResourceMatchesNeedUnavailable,
            key: const Key('project-resource-match-need-title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (need?.details case final details?) ...[
            const SizedBox(height: AppSpacing.xSmall),
            Text(details),
          ],
        ],
      ),
    );
  }
}

class _MatchFilters extends StatelessWidget {
  const _MatchFilters({
    required this.state,
    required this.onLocationChanged,
    required this.onModeChanged,
  });

  final ProjectResourceMatchesState state;
  final ValueChanged<ProjectResourceLocationScope> onLocationChanged;
  final ValueChanged<ProjectResourceListingModeFilter> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        DropdownButtonFormField<ProjectResourceLocationScope>(
          key: ValueKey(
            'project-resource-match-location-${state.locationScope.wireValue}',
          ),
          initialValue: state.locationScope,
          decoration: InputDecoration(
            labelText: l10n.projectResourceMatchesLocationFilter,
          ),
          items: [
            for (final scope in ProjectResourceLocationScope.values)
              DropdownMenuItem(
                value: scope,
                child: Text(_locationScopeLabel(l10n, scope)),
              ),
          ],
          onChanged: state.isBusy
              ? null
              : (value) {
                  if (value != null) onLocationChanged(value);
                },
        ),
        const SizedBox(height: AppSpacing.medium),
        DropdownButtonFormField<ProjectResourceListingModeFilter>(
          key: ValueKey(
            'project-resource-match-mode-${state.listingMode.name}',
          ),
          initialValue: state.listingMode,
          decoration: InputDecoration(
            labelText: l10n.projectResourceMatchesModeFilter,
          ),
          items: [
            for (final mode in ProjectResourceListingModeFilter.values)
              DropdownMenuItem(
                value: mode,
                child: Text(_listingModeLabel(l10n, mode)),
              ),
          ],
          onChanged: state.isBusy
              ? null
              : (value) {
                  if (value != null) onModeChanged(value);
                },
        ),
      ],
    );
  }
}

class _MatchReasons extends StatelessWidget {
  const _MatchReasons({required this.match});

  final ProjectResourceListingMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textReason = _textReason(l10n, match.textMatchKind);
    final locationReason = _locationReason(l10n, match.locationMatchKind);
    return Semantics(
      label: '${l10n.projectResourceMatchesWhy}: $textReason. $locationReason.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.projectResourceMatchesWhy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Text(textReason),
          Text(locationReason),
        ],
      ),
    );
  }
}

String _locationScopeLabel(
  AppLocalizations l10n,
  ProjectResourceLocationScope scope,
) => switch (scope) {
  ProjectResourceLocationScope.anywhere => l10n.projectResourceMatchesAnywhere,
  ProjectResourceLocationScope.sameCountry =>
    l10n.projectResourceMatchesSameCountry,
  ProjectResourceLocationScope.sameAdministrativeArea =>
    l10n.projectResourceMatchesSameArea,
  ProjectResourceLocationScope.sameLocality =>
    l10n.projectResourceMatchesSameLocality,
};

String _listingModeLabel(
  AppLocalizations l10n,
  ProjectResourceListingModeFilter mode,
) => switch (mode) {
  ProjectResourceListingModeFilter.all => l10n.resourceModeAll,
  ProjectResourceListingModeFilter.donate => l10n.resourceModeDonate,
  ProjectResourceListingModeFilter.exchange => l10n.resourceModeExchange,
};

String _textReason(AppLocalizations l10n, ProjectResourceTextMatchKind kind) =>
    switch (kind) {
      ProjectResourceTextMatchKind.titlePhrase =>
        l10n.projectResourceMatchesTitlePhrase,
      ProjectResourceTextMatchKind.needTitleInListingTitle =>
        l10n.projectResourceMatchesNeedTitleInListingTitle,
      ProjectResourceTextMatchKind.needTitleInListingDescription =>
        l10n.projectResourceMatchesNeedTitleInListingDescription,
      ProjectResourceTextMatchKind.needDetailsInListingTitle =>
        l10n.projectResourceMatchesNeedDetailsInListingTitle,
      ProjectResourceTextMatchKind.needDetailsInListingDescription =>
        l10n.projectResourceMatchesNeedDetailsInListingDescription,
    };

String _locationReason(
  AppLocalizations l10n,
  ProjectResourceLocationMatchKind kind,
) => switch (kind) {
  ProjectResourceLocationMatchKind.sameLocality =>
    l10n.projectResourceMatchesSameLocality,
  ProjectResourceLocationMatchKind.sameAdministrativeArea =>
    l10n.projectResourceMatchesSameArea,
  ProjectResourceLocationMatchKind.sameCountry =>
    l10n.projectResourceMatchesSameCountry,
  ProjectResourceLocationMatchKind.otherOrUnknown =>
    l10n.projectResourceMatchesOtherLocation,
};

String _failureMessage(
  AppLocalizations l10n,
  ProjectResourceMatchesFailureKind? failure,
) => switch (failure) {
  ProjectResourceMatchesFailureKind.invalidInput =>
    l10n.projectResourceMatchesInvalidInput,
  ProjectResourceMatchesFailureKind.forbidden =>
    l10n.projectResourceMatchesForbidden,
  ProjectResourceMatchesFailureKind.projectStateUnavailable =>
    l10n.projectResourceMatchesProjectStateUnavailable,
  ProjectResourceMatchesFailureKind.notFound =>
    l10n.projectResourceMatchesNotFound,
  ProjectResourceMatchesFailureKind.unavailable ||
  null => l10n.projectResourceMatchesUnavailable,
};
