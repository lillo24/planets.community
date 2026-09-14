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
  late final TextEditingController _queryController;
  late final TextEditingController _localityController;
  late _ResourceModeChoice _modeChoice;

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
    _queryController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicResourceListingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resourceTitle),
        actions: [
          IconButton(
            key: const Key('resource-my-listings-action'),
            tooltip: l10n.resourceMyListings,
            onPressed: () => context.go('/resources/mine'),
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
                        onSelectionChanged: state.isBusy
                            ? null
                            : (selection) => setState(
                                () => _modeChoice = selection.single,
                              ),
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
                      onSubmitted: (_) => _applyFilters(),
                    ),
                    TextField(
                      key: const Key('resource-locality-filter'),
                      controller: _localityController,
                      maxLength: 120,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: l10n.resourceLocalityLabel,
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        key: const Key('resource-apply-filters'),
                        onPressed: state.isBusy ? null : _applyFilters,
                        icon: const Icon(Icons.search),
                        label: Text(l10n.resourceSearchAction),
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
                          onTap: () => context.go('/resources/${listing.id}'),
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
        onPressed: () => context.go('/resources/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.resourceCreateListing),
      ),
    );
  }

  void _applyFilters() {
    final mode = switch (_modeChoice) {
      _ResourceModeChoice.all => null,
      _ResourceModeChoice.donate => ResourceListingMode.donate,
      _ResourceModeChoice.exchange => ResourceListingMode.exchange,
    };
    ref
        .read(publicResourceListingsProvider.notifier)
        .applyFilters(
          mode: mode,
          locality: _localityController.text,
          query: _queryController.text,
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
    Future<void>.microtask(
      () => ref
          .read(publicResourceListingDetailProvider.notifier)
          .load(widget.listingId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicResourceListingDetailProvider);
    final detail = state.listingId == widget.listingId ? state.detail : null;
    final session = ref.watch(authSessionProvider);
    final isOwner =
        session.phase == AuthSessionPhase.ready &&
        session.identity?.id == detail?.ownerProfileId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resourceDetailTitle),
        actions: [
          if (isOwner)
            IconButton(
              key: const Key('resource-owner-edit-shortcut'),
              tooltip: l10n.resourceEditListing,
              onPressed: () =>
                  context.go('/resources/${widget.listingId}/edit'),
              icon: const Icon(Icons.edit_outlined),
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
                onRetry: () => ref
                    .read(publicResourceListingDetailProvider.notifier)
                    .load(widget.listingId),
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
                  const SizedBox(height: AppSpacing.large),
                  Text(detail.summary.description),
                  const SizedBox(height: AppSpacing.large),
                  ResourceListingLocation(
                    publicLocationLabel: detail.summary.publicLocationLabel,
                    locality: detail.summary.locality,
                    administrativeArea: detail.summary.administrativeArea,
                    countryCode: detail.summary.countryCode,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    l10n.resourcePublishedDate(
                      formatResourceListingDate(
                        context,
                        detail.summary.publishedAt,
                      ),
                    ),
                  ),
                  if (detail.ownerDisplayName case final owner?) ...[
                    const SizedBox(height: AppSpacing.large),
                    Text(l10n.resourceListedBy(owner)),
                  ],
                ],
              ),
      ),
    );
  }
}
