import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../resource_requests/application/resource_request_controllers.dart';
import '../../resource_requests/domain/resource_request_models.dart';
import '../../resource_requests/presentation/resource_request_composer.dart';
import '../../resource_requests/presentation/resource_request_widgets.dart';
import '../application/resource_listing_controllers.dart';
import '../domain/resource_listing_models.dart';
import 'resource_listing_widgets.dart';

enum _ResourceModeChoice { all, donate, exchange }

class PublicResourceListingsScreen extends ConsumerStatefulWidget {
  const PublicResourceListingsScreen({super.key});

  @override
  ConsumerState<PublicResourceListingsScreen> createState() =>
      _PublicResourceListingsScreenState();
}

class _PublicResourceListingsScreenState
    extends ConsumerState<PublicResourceListingsScreen> {
  static const _filterDebounce = Duration(milliseconds: 350);

  late final TextEditingController _queryController;
  late final TextEditingController _localityController;
  late _ResourceModeChoice _modeChoice;
  Timer? _filterTimer;

  @override
  void initState() {
    super.initState();
    final current = ref.read(publicResourceListingsProvider);
    _queryController = TextEditingController(text: current.query);
    _localityController = TextEditingController(text: current.locality);
    _modeChoice = switch (current.modeFilter) {
      null => _ResourceModeChoice.all,
      ResourceListingMode.donate => _ResourceModeChoice.donate,
      ResourceListingMode.exchange => _ResourceModeChoice.exchange,
    };
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
    final now = ref.watch(resourceListingClockProvider)();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resourceTitle),
        actions: [
          IconButton(
            key: const Key('resource-my-listings-action'),
            tooltip: l10n.resourceMyListings,
            onPressed: () => context.push('/resources/mine'),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child:
            state.phase == ResourceListingLoadPhase.loading &&
                state.items.isEmpty
            ? LoadingState(message: l10n.resourceLoading)
            : state.phase == ResourceListingLoadPhase.failure &&
                  state.items.isEmpty
            ? ErrorState(
                message: resourceListingFailureMessage(l10n, state.failure),
                onRetry: () =>
                    ref.read(publicResourceListingsProvider.notifier).load(),
              )
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(publicResourceListingsProvider.notifier)
                    .load(force: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    Semantics(
                      label: l10n.resourceModeFilterLabel,
                      child: SegmentedButton<_ResourceModeChoice>(
                        key: const Key('resource-mode-filter'),
                        segments: [
                          ButtonSegment(
                            value: _ResourceModeChoice.all,
                            label: Text(
                              l10n.resourceModeAll,
                              key: const Key('resource-filter-mode-all'),
                            ),
                          ),
                          ButtonSegment(
                            value: _ResourceModeChoice.donate,
                            label: Text(
                              l10n.resourceModeDonate,
                              key: const Key('resource-filter-mode-donate'),
                            ),
                          ),
                          ButtonSegment(
                            value: _ResourceModeChoice.exchange,
                            label: Text(
                              l10n.resourceModeExchange,
                              key: const Key('resource-filter-mode-exchange'),
                            ),
                          ),
                        ],
                        selected: {_modeChoice},
                        onSelectionChanged: (selection) {
                          setState(() => _modeChoice = selection.single);
                          _flushFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    TextField(
                      key: const Key('resource-query-filter'),
                      controller: _queryController,
                      maxLength: 120,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: l10n.resourceSearchLabel,
                      ),
                      onChanged: (_) => _scheduleFilters(),
                      onSubmitted: (_) => _flushFilters(),
                    ),
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
                    if (state.phase == ResourceListingLoadPhase.loading &&
                        state.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: LinearProgressIndicator(
                          key: const Key('resource-filter-progress'),
                          semanticsLabel: l10n.resourceLoading,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    if (state.items.isEmpty)
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
                        PublicResourceListingCard(
                          listing: listing,
                          now: now,
                          onTap: () => context.push('/resources/${listing.id}'),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    if (state.phase == ResourceListingLoadPhase.failure &&
                        state.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.small,
                        ),
                        child: Text(
                          resourceListingFailureMessage(l10n, state.failure),
                          key: const Key('resource-partial-error'),
                        ),
                      ),
                    if (state.items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('resource-load-more'),
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                  .read(publicResourceListingsProvider.notifier)
                                  .load(reset: false),
                        child:
                            state.phase == ResourceListingLoadPhase.loadingMore
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(),
                              )
                            : Text(l10n.resourceLoadMore),
                      ),
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
    _filterTimer?.cancel();
    _filterTimer = Timer(_filterDebounce, _applyFilters);
  }

  void _flushFilters() {
    _filterTimer?.cancel();
    _applyFilters();
  }

  void _applyFilters() {
    final mode = switch (_modeChoice) {
      _ResourceModeChoice.all => null,
      _ResourceModeChoice.donate => ResourceListingMode.donate,
      _ResourceModeChoice.exchange => ResourceListingMode.exchange,
    };
    unawaited(
      ref
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: mode,
            locality: _localityController.text,
            query: _queryController.text,
          ),
    );
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

  Future<void> _load() async {
    await ref
        .read(publicResourceListingDetailProvider.notifier)
        .load(widget.listingId);
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
    final now = ref.watch(resourceListingClockProvider)();
    final isOwner =
        session.phase == AuthSessionPhase.ready &&
        session.identity?.id == detail?.ownerProfileId;
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    return Scaffold(
      appBar: AppBar(
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
        child: detail == null && state.phase == ResourceListingLoadPhase.loading
            ? LoadingState(message: l10n.resourceLoading)
            : detail == null
            ? ErrorState(
                message: state.phase == ResourceListingLoadPhase.ready
                    ? l10n.resourceNotFound
                    : resourceListingFailureMessage(l10n, state.failure),
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
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
                      publicLocationLabel: detail.summary.publicLocationLabel,
                      locality: detail.summary.locality,
                      administrativeArea: detail.summary.administrativeArea,
                      countryCode: detail.summary.countryCode,
                    ),
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
  });

  final String listingId;
  final String expectedProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      return FilledButton.icon(
        key: const Key('resource-request-action'),
        onPressed: () => showResourceRequestComposer(
          context,
          listingId: listingId,
          expectedRequesterProfileId: expectedProfileId,
        ),
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
