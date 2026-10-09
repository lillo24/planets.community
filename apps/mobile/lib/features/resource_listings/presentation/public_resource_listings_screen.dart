import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../geographic_discovery/domain/map_discovery.dart';
import '../../geographic_discovery/presentation/map_view_button.dart';
import '../../locations/presentation/location_attribution.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_data_presentation.dart';
import '../../../core/widgets/browse_filter_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../policies/presentation/policy_write_boundary.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../../auth/domain/auth_models.dart';
import '../../drafts/domain/draft_entry.dart';
import '../../blocking/application/blocking_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../messages/application/messages_controllers.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../profile_photo/application/resource_listing_owner_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../resource_requests/application/resource_request_controllers.dart';
import '../../resource_requests/domain/resource_request_models.dart';
import '../../resource_requests/presentation/resource_request_composer.dart';
import '../../resource_requests/presentation/resource_request_widgets.dart';
import '../../resource_saved_searches/application/resource_saved_search_controller.dart';
import '../../resource_saved_searches/domain/resource_saved_search_models.dart';
import '../../resource_saved_searches/presentation/resource_saved_search_routes.dart';
import '../application/resource_listing_controllers.dart';
import '../domain/resource_listing_models.dart';
import 'resource_listing_widgets.dart';

typedef _ResourceFilterTuple = ({
  ResourceListingMode? mode,
  String locality,
  String query,
});

class PublicResourceListingsScreen extends ConsumerStatefulWidget {
  const PublicResourceListingsScreen({this.tutorialPlaceholder, super.key});

  /// Tutorial-only presentation after a bounded read fails; no synthetic
  /// listing is added to providers and real filters/actions are unchanged.
  final Widget? tutorialPlaceholder;

  @override
  ConsumerState<PublicResourceListingsScreen> createState() =>
      _PublicResourceListingsScreenState();
}

class _PublicResourceListingsScreenState
    extends ConsumerState<PublicResourceListingsScreen> {
  static const _filterDebounce = Duration(milliseconds: 350);

  late final TextEditingController _queryController;
  late final TextEditingController _localityController;
  ResourceListingMode? _modeFilter;
  bool _filtersExpanded = false;
  Timer? _filterTimer;

  @override
  void initState() {
    super.initState();
    final current = ref.read(publicResourceListingsProvider);
    _queryController = TextEditingController(text: current.query);
    _localityController = TextEditingController(text: current.locality);
    _modeFilter = current.modeFilter;
    if (current.phase == ResourceListingLoadPhase.idle) {
      Future<void>.microtask(
        () => ref.read(publicResourceListingsProvider.notifier).load(),
      );
    }
  }

  @override
  void dispose() {
    _filterTimer?.cancel();
    _queryController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicResourceListingsProvider);
    final session = ref.watch(authSessionProvider);
    final expectedProfileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final savedSearches = ref.watch(resourceSavedSearchesProvider);
    ref.listen<_ResourceFilterTuple>(
      publicResourceListingsProvider.select(
        (value) => (
          mode: value.modeFilter,
          locality: value.locality,
          query: value.query,
        ),
      ),
      (previous, next) {
        if (previous != next) _syncFilterControls(next);
      },
    );
    final pendingInput = _currentInput();
    final now = ref.watch(resourceListingClockProvider)();
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.resourceTitle),
        actions: [
          if (expectedProfileId != null)
            IconButton(
              key: const Key('resource-saved-searches-action'),
              tooltip: l10n.resourceSavedSearchesTitle,
              onPressed: () => context.go(ResourceSavedSearchRoutes.path),
              icon: const Icon(Icons.bookmarks_outlined),
            ),
          IconButton(
            key: const Key('resource-my-listings-action'),
            tooltip: l10n.draftsTitle,
            onPressed: () => context.push(
              DraftRoutes.contextual({DraftKind.donate, DraftKind.exchange}),
            ),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(publicResourceListingsProvider.notifier)
              .load(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              MapViewButton(
                origin: MapDiscoveryOrigin.resources,
                prepare: _flushFilters,
              ),
              const SizedBox(height: 8),
              Semantics(
                label: l10n.resourceModeFilterLabel,
                child: SegmentedButton<ResourceListingMode>(
                  key: const Key('resource-mode-filter'),
                  multiSelectionEnabled: true,
                  emptySelectionAllowed: true,
                  selectedIcon: const Icon(Icons.check),
                  segments: [
                    ButtonSegment(
                      value: ResourceListingMode.donate,
                      label: Text(
                        l10n.resourceModeDonate,
                        key: const Key('resource-filter-mode-donate'),
                      ),
                    ),
                    ButtonSegment(
                      value: ResourceListingMode.exchange,
                      label: Text(
                        l10n.resourceModeExchange,
                        key: const Key('resource-filter-mode-exchange'),
                      ),
                    ),
                  ],
                  selected: _modeFilter == null
                      ? ResourceListingMode.values.toSet()
                      : {_modeFilter!},
                  onSelectionChanged: (selection) {
                    setState(() {
                      // Deselecting the last mode switches to the other
                      // one, so an empty visual/filter state never exists.
                      _modeFilter = selection.isEmpty
                          ? (_modeFilter == ResourceListingMode.donate
                                ? ResourceListingMode.exchange
                                : ResourceListingMode.donate)
                          : selection.length == 2
                          ? null
                          : selection.single;
                    });
                    _flushFilters();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('resource-query-filter'),
                      controller: _queryController,
                      maxLength: 120,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: l10n.resourceSearchLabel,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.small,
                        ),
                        counterText: '',
                      ),
                      onChanged: (_) => _scheduleFilters(),
                      onSubmitted: (_) => _flushFilters(),
                    ),
                  ),
                  BrowseFilterButton(
                    key: const Key('resource-toggle-filters'),
                    expanded: _filtersExpanded,
                    hasActiveFilters: state.locality.trim().isNotEmpty,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _filtersExpanded = !_filtersExpanded);
                    },
                  ),
                ],
              ),
              if (_filtersExpanded) ...[
                const SizedBox(height: AppSpacing.small),
                TextField(
                  key: const Key('resource-locality-filter'),
                  controller: _localityController,
                  maxLength: 120,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.resourceLocalityLabel,
                  ),
                  onChanged: (_) => _scheduleFilters(),
                  onSubmitted: (_) => _flushFilters(),
                ),
              ],
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  if (expectedProfileId != null)
                    OutlinedButton.icon(
                      key: const Key('resource-save-search'),
                      onPressed:
                          state.isBusy ||
                              savedSearches.isActing ||
                              !pendingInput.isValid
                          ? null
                          : () => _saveCurrentSearch(expectedProfileId),
                      icon:
                          savedSearches.action ==
                              ResourceSavedSearchAction.creating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bookmark_add_outlined),
                      label: Text(l10n.resourceSavedSearchSaveAction),
                    ),
                ],
              ),
              if (state.phase == ResourceListingLoadPhase.loading &&
                  state.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: LinearProgressIndicator(
                    key: const Key('resource-filter-progress'),
                    semanticsLabel: l10n.resourceLoading,
                  ),
                ),
              if (!state.resultsMatchFilters && state.items.isNotEmpty)
                Text(
                  l10n.browsePreviousResults,
                  key: const Key('resource-previous-results'),
                ),
              const SizedBox(height: AppSpacing.medium),
              if (widget.tutorialPlaceholder != null)
                widget.tutorialPlaceholder!
              else if ((state.phase == ResourceListingLoadPhase.idle ||
                      state.phase == ResourceListingLoadPhase.loading) &&
                  state.items.isEmpty)
                LoadingState(message: l10n.resourceLoading)
              else if (state.phase == ResourceListingLoadPhase.failure &&
                  state.items.isEmpty)
                ErrorState(
                  message: resourceListingFailureMessage(l10n, state.failure),
                  onRetry: () =>
                      ref.read(publicResourceListingsProvider.notifier).load(),
                )
              else if (state.items.isEmpty)
                EmptyState(
                  title: state.hasFilters
                      ? l10n.resourceFilteredEmptyTitle
                      : l10n.resourceEmptyTitle,
                  message: state.hasFilters
                      ? l10n.resourceFilteredEmptyMessage
                      : l10n.resourceEmptyMessage,
                  icon: Icons.inventory_2_outlined,
                )
              else
                for (final listing in state.items) ...[
                  AbsorbPointer(
                    absorbing: !state.resultsMatchFilters,
                    child: PublicResourceListingCard(
                      listing: listing,
                      now: now,
                      onTap: () => context.push('/resources/${listing.id}'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
              if (state.phase == ResourceListingLoadPhase.failure &&
                  state.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  child: Column(
                    children: [
                      Text(
                        resourceListingFailureMessage(l10n, state.failure),
                        key: const Key('resource-partial-error'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(publicResourceListingsProvider.notifier)
                            .load(force: true),
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ),
                ),
              if (state.items.isNotEmpty && state.hasMore)
                OutlinedButton(
                  key: const Key('resource-load-more'),
                  onPressed: state.isBusy || !state.resultsMatchFilters
                      ? null
                      : () => ref
                            .read(publicResourceListingsProvider.notifier)
                            .load(reset: false),
                  child: state.phase == ResourceListingLoadPhase.loadingMore
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(),
                        )
                      : Text(l10n.resourceLoadMore),
                ),
              const LocationAttribution(),
              // Let credit links scroll above the floating Create action.
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('resource-create-action'),
        onPressed: () => context.push('/resources/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.resourceCreateListing),
      ),
    );
  }

  void _scheduleFilters() {
    setState(() {});
    _filterTimer?.cancel();
    _filterTimer = Timer(_filterDebounce, _applyFilters);
  }

  Future<void> _flushFilters() {
    _filterTimer?.cancel();
    return _applyFilters();
  }

  Future<void> _applyFilters() async {
    final input = _currentInput();
    final current = ref.read(publicResourceListingsProvider);
    // Submit/Save may follow a debounce that already applied the same tuple.
    // A failed request remains retryable; successful/in-flight tuples dedupe.
    if (current.phase != ResourceListingLoadPhase.failure &&
        current.modeFilter == input.mode &&
        current.locality == (input.locality ?? '') &&
        current.query == (input.query ?? '')) {
      return;
    }
    await ref
        .read(publicResourceListingsProvider.notifier)
        .applyFilters(
          mode: input.mode,
          locality: input.locality ?? '',
          query: input.query ?? '',
        );
  }

  ResourceSavedSearchInput _currentInput() =>
      ResourceSavedSearchInput.normalized(
        query: _queryController.text,
        mode: _modeFilter,
        locality: _localityController.text,
      );

  void _syncFilterControls(_ResourceFilterTuple filters) {
    _filterTimer?.cancel();
    _queryController.text = filters.query;
    _localityController.text = filters.locality;
    setState(() {
      _modeFilter = filters.mode;
    });
  }

  Future<void> _saveCurrentSearch(String expectedProfileId) async {
    if (!requirePolicyAcknowledgement(context, ref, '/resources')) return;
    final l10n = AppLocalizations.of(context);
    final input = _currentInput();
    if (!input.isValid) return;
    await _flushFilters();
    final outcome = await ref
        .read(resourceSavedSearchesProvider.notifier)
        .create(expectedProfileId, input);
    if (!mounted) return;
    final message = switch (outcome) {
      ResourceSavedSearchMutationOutcome.success =>
        l10n.resourceSavedSearchCreated,
      ResourceSavedSearchMutationOutcome.duplicate =>
        l10n.resourceSavedSearchCreateDuplicate,
      ResourceSavedSearchMutationOutcome.invalidInput =>
        l10n.resourceSavedSearchInvalidInput,
      ResourceSavedSearchMutationOutcome.forbidden ||
      ResourceSavedSearchMutationOutcome.notFound =>
        l10n.resourceSavedSearchForbidden,
      ResourceSavedSearchMutationOutcome.unavailable ||
      ResourceSavedSearchMutationOutcome.staleIdentity ||
      ResourceSavedSearchMutationOutcome.busy =>
        l10n.resourceSavedSearchUnableCreate,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class PublicResourceListingDetailScreen extends ConsumerStatefulWidget {
  const PublicResourceListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<PublicResourceListingDetailScreen> createState() =>
      _PublicResourceListingDetailScreenState();
}

class _PublicResourceListingDetailScreenState
    extends ConsumerState<PublicResourceListingDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant PublicResourceListingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId == widget.listingId) return;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    await Future.wait([
      ref
          .read(publicResourceListingDetailProvider.notifier)
          .load(widget.listingId),
      ref
          .read(resourceListingOwnerPhotoProvider.notifier)
          .load(widget.listingId, force: true),
    ]);
    if (!mounted) return;
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId != null) {
      await ref.read(resourceRequestHistoryProvider.notifier).load(profileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicResourceListingDetailProvider);
    final detail = state.listingId == widget.listingId ? state.detail : null;
    final session = ref.watch(authSessionProvider);
    final ownerPhoto = ref
        .watch(resourceListingOwnerPhotoProvider)
        .entryFor(widget.listingId);
    final now = ref.watch(resourceListingClockProvider)();
    final isOwner =
        session.phase == AuthSessionPhase.ready &&
        session.identity?.id == detail?.ownerProfileId;
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final presentation = classifyAsyncDataPresentation(
      belongsToTarget: state.listingId == widget.listingId,
      hasData: detail != null,
      isPending:
          state.phase == ResourceListingLoadPhase.idle ||
          state.phase == ResourceListingLoadPhase.loading,
      hasFailed: state.phase == ResourceListingLoadPhase.failure,
    );
    final emptyDetail = switch (presentation) {
      AsyncDataPresentation.loading => LoadingState(
        message: l10n.resourceLoading,
      ),
      AsyncDataPresentation.absent => ErrorState(
        message: l10n.resourceNotFound,
        onRetry: _load,
      ),
      AsyncDataPresentation.failure => ErrorState(
        message: resourceListingFailureMessage(l10n, state.failure),
        onRetry: _load,
      ),
      AsyncDataPresentation.content => const SizedBox.shrink(),
    };
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.resourceDetailTitle),
        actions: [
          if (isOwner)
            IconButton(
              key: const Key('resource-owner-edit-shortcut'),
              tooltip: l10n.resourceEditListing,
              onPressed: () =>
                  context.push('/resources/${widget.listingId}/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (isOwner)
            IconButton(
              key: const Key('resource-owner-loan-schedule-shortcut'),
              tooltip: l10n.resourceLoanScheduleView,
              onPressed: () =>
                  context.push('/resources/${widget.listingId}/loan-schedule'),
              icon: const Icon(Icons.event_note_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: detail == null
            ? emptyDetail
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  CoverImage(
                    key: const Key('resource-detail-cover'),
                    title: detail.summary.title,
                    objectPath: detail.summary.coverObjectPath,
                    borderRadius: AppRadii.medium,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ResourceListingModeBadge(mode: detail.summary.mode),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    detail.summary.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Builder(
                    builder: (context) {
                      final age = formatResourceListingRelativeAge(
                        context,
                        detail.summary.publishedAt,
                        now: now,
                      );
                      final owner = detail.ownerDisplayName;
                      final metadata = owner == null
                          ? l10n.resourcePublishedRelative(age)
                          : l10n.resourceDetailMetadata(age, owner);
                      return Semantics(
                        label: metadata,
                        child: Text(
                          metadata,
                          key: const Key('resource-detail-published-age'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _ResourceDetailSection(
                    title: l10n.resourceDescriptionTitle,
                    child: Text(detail.summary.description),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _ResourceDetailSection(
                    child: ResourceListingLocation(
                      listingId: detail.summary.id,
                      publicLocationLabel: detail.summary.publicLocationLabel,
                      locality: detail.summary.locality,
                      administrativeArea: detail.summary.administrativeArea,
                      countryCode: detail.summary.countryCode,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Row(
                    key: const Key('resource-listing-owner'),
                    children: [
                      VisibleProfilePhotoAvatar(
                        entry: ownerPhoto,
                        imageSemanticsLabel:
                            l10n.resourceListingOwnerPhotoLabel,
                        placeholderSemanticsLabel:
                            l10n.resourceListingOwnerPhotoLabel,
                      ),
                      if (detail.ownerDisplayName case final owner?) ...[
                        const SizedBox(width: AppSpacing.small),
                        Expanded(child: Text(l10n.resourceListedBy(owner))),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    label: l10n.resourceInterestCount(
                      detail.summary.activeRequestCount,
                    ),
                    child: Row(
                      key: const Key('resource-detail-interest-count'),
                      children: [
                        const Icon(Icons.people_outline, size: 20),
                        const SizedBox(width: AppSpacing.small),
                        Expanded(
                          child: Text(
                            l10n.resourceInterestCount(
                              detail.summary.activeRequestCount,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (profileId != null && !isOwner) ...[
                    const SizedBox(height: AppSpacing.large),
                    _ResourceRequestListingActions(
                      listingId: widget.listingId,
                      expectedProfileId: profileId,
                      ownerProfileId: detail.ownerProfileId,
                      ownerDisplayName: detail.ownerDisplayName,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    BlockingActionButton(
                      targetProfileId: detail.ownerProfileId,
                      targetDisplayName: detail.ownerDisplayName,
                      buttonKey: const Key('resource-listing-blocking-action'),
                      onChanged: (_) async {
                        ref
                            .read(resourceListingOwnerPhotoProvider.notifier)
                            .invalidate(widget.listingId);
                        await Future.wait([
                          ref
                              .read(resourceListingOwnerPhotoProvider.notifier)
                              .load(widget.listingId, force: true),
                          ref
                              .read(resourceRequestHistoryProvider.notifier)
                              .load(profileId, force: true),
                          ref
                              .read(messagesInboxProvider.notifier)
                              .load(profileId, refresh: true),
                        ]);
                      },
                    ),
                    const SizedBox(height: AppSpacing.small),
                    OutlinedButton.icon(
                      key: const Key('resource-listing-report-action'),
                      onPressed: () => ModerationRoutes.openReport(
                        context,
                        resourceListingReportTarget(
                          widget.listingId,
                          detail.summary.title,
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(l10n.moderationReportAction),
                    ),
                  ],
                  if (session.phase == AuthSessionPhase.signedOut) ...[
                    const SizedBox(height: AppSpacing.large),
                    FilledButton.icon(
                      key: const Key('resource-signed-out-request-action'),
                      onPressed: () => context.go(
                        Uri(
                          path: '/auth',
                          queryParameters: {
                            'returnTo': '/resources/${widget.listingId}',
                          },
                        ).toString(),
                      ),
                      icon: const Icon(Icons.front_hand_outlined),
                      label: Text(l10n.resourceSignedOutRequestAction),
                    ),
                  ],
                  if (!isOwner &&
                      (profileId != null ||
                          session.phase == AuthSessionPhase.signedOut)) ...[
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      l10n.resourceRequestFlowHelper,
                      key: const Key('resource-request-flow-helper'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ResourceDetailSection extends StatelessWidget {
  const _ResourceDetailSection({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title case final value?) ...[
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.small),
          ],
          child,
        ],
      ),
    ),
  );
}

class _ResourceRequestListingActions extends ConsumerWidget {
  const _ResourceRequestListingActions({
    required this.listingId,
    required this.expectedProfileId,
    required this.ownerProfileId,
    required this.ownerDisplayName,
  });

  final String listingId;
  final String expectedProfileId;
  final String ownerProfileId;
  final String? ownerDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocking = ref.watch(blockingProvider);
    if (!blocking.hasExactStatus(ownerProfileId) &&
        !blocking.isLoadingStatus(ownerProfileId) &&
        !blocking.hasStatusFailure(ownerProfileId)) {
      Future<void>.microtask(
        () => ref
            .read(blockingProvider.notifier)
            .loadStatus(expectedProfileId, ownerProfileId),
      );
    }
    final history = ref.watch(resourceRequestHistoryProvider);
    final belongs = history.expectedRequesterProfileId == expectedProfileId;
    if (!belongs || history.phase == ResourceRequestHistoryPhase.loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (history.phase == ResourceRequestHistoryPhase.failure) {
      return Semantics(
        liveRegion: true,
        child: Column(
          children: [
            Text(
              l10n.resourceRequestUnableLoad,
              key: const Key('resource-request-history-error'),
            ),
            TextButton(
              onPressed: () => ref
                  .read(resourceRequestHistoryProvider.notifier)
                  .load(expectedProfileId, force: true),
              child: Text(l10n.retryAction),
            ),
          ],
        ),
      );
    }
    final active = ref
        .read(resourceRequestHistoryProvider.notifier)
        .activeRequestForListing(listingId);
    if (active == null) {
      if (blocking.exactStatus(ownerProfileId) != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.blockingOwnBlockInteractionExplanation,
              key: const Key('resource-request-blocked-explanation'),
            ),
            const SizedBox(height: AppSpacing.small),
            BlockingActionButton(
              targetProfileId: ownerProfileId,
              targetDisplayName: ownerDisplayName,
              buttonKey: const Key('resource-request-unblock-owner'),
              onChanged: (_) async {
                await Future.wait([
                  ref
                      .read(resourceRequestHistoryProvider.notifier)
                      .load(expectedProfileId, force: true),
                  ref
                      .read(messagesInboxProvider.notifier)
                      .load(expectedProfileId, refresh: true),
                ]);
              },
            ),
          ],
        );
      }
      return FilledButton.icon(
        key: const Key('resource-request-action'),
        onPressed: () {
          if (!requirePolicyAcknowledgement(
            context,
            ref,
            '/resources/$listingId',
          )) {
            return;
          }
          showResourceRequestComposer(
            context,
            listingId: listingId,
            expectedRequesterProfileId: expectedProfileId,
          );
        },
        icon: const Icon(Icons.front_hand_outlined),
        label: Text(l10n.resourceRequestAction),
      );
    }
    final mutation = ref.watch(resourceRequestDetailProvider(active.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ResourceRequestStatusChip(status: active.status),
        ),
        const SizedBox(height: AppSpacing.small),
        if (active.status == ResourceRequestStatus.pending)
          OutlinedButton.icon(
            key: const Key('resource-request-inline-withdraw'),
            onPressed: mutation.isActing
                ? null
                : () => ref
                      .read(resourceRequestDetailProvider(active.id).notifier)
                      .withdrawFromHistory(
                        expectedProfileId: expectedProfileId,
                        request: active,
                      ),
            icon: mutation.action == ResourceRequestMutation.withdrawing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.undo),
            label: Text(l10n.resourceRequestWithdraw),
          ),
        OutlinedButton.icon(
          key: const Key('resource-request-view'),
          onPressed: () => context.push(resourceRequestMessageRoute(active.id)),
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.resourceRequestView),
        ),
      ],
    );
  }
}
