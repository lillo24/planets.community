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
import '../../resource_listings/application/resource_listing_controllers.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../../resource_listings/presentation/resource_listing_widgets.dart';
import '../application/resource_saved_search_controller.dart';
import '../domain/resource_saved_search_models.dart';
import 'resource_saved_search_editor.dart';

class ResourceSavedSearchesScreen extends ConsumerStatefulWidget {
  const ResourceSavedSearchesScreen({super.key});

  @override
  ConsumerState<ResourceSavedSearchesScreen> createState() =>
      _ResourceSavedSearchesScreenState();
}

class _ResourceSavedSearchesScreenState
    extends ConsumerState<ResourceSavedSearchesScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load({bool refresh = false}) async {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready) return;
    final profileId = session.identity?.id;
    if (profileId == null) return;
    await ref
        .read(resourceSavedSearchesProvider.notifier)
        .load(profileId, refresh: refresh);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final state = ref.watch(resourceSavedSearchesProvider);
    final belongs = state.expectedProfileId == profileId;
    final items = belongs ? state.items : const <ResourceSavedSearch>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resourceSavedSearchesTitle)),
      body: SafeArea(
        child:
            profileId == null ||
                (!belongs && state.phase == ResourceSavedSearchPhase.idle) ||
                (state.phase == ResourceSavedSearchPhase.loading &&
                    items.isEmpty)
            ? LoadingState(message: l10n.resourceSavedSearchesLoading)
            : state.phase == ResourceSavedSearchPhase.failure && items.isEmpty
            ? ErrorState(
                message: resourceSavedSearchFailureMessage(l10n, state.failure),
                onRetry: _load,
              )
            : RefreshIndicator(
                onRefresh: () => _load(refresh: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    if (items.isEmpty)
                      Column(
                        children: [
                          EmptyState(
                            title: l10n.resourceSavedSearchesEmptyTitle,
                            message: l10n.resourceSavedSearchesEmptyMessage,
                            icon: Icons.bookmarks_outlined,
                          ),
                          FilledButton.icon(
                            key: const Key('saved-search-empty-browse'),
                            onPressed: () => context.go('/resources'),
                            icon: const Icon(Icons.search),
                            label: Text(
                              l10n.resourceSavedSearchBrowseResources,
                            ),
                          ),
                        ],
                      )
                    else
                      for (final savedSearch in items) ...[
                        _ResourceSavedSearchCard(
                          savedSearch: savedSearch,
                          isActing: state.isActing,
                          isDeleting:
                              state.action ==
                                  ResourceSavedSearchAction.deleting &&
                              state.actionTargetId == savedSearch.id,
                          onOpen: () => _open(savedSearch),
                          onEdit: () => _edit(profileId, savedSearch),
                          onDelete: () => _delete(profileId, savedSearch),
                        ),
                        const SizedBox(height: AppSpacing.small),
                      ],
                    if (state.failure != null && items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.small,
                        ),
                        child: Text(
                          resourceSavedSearchFailureMessage(
                            l10n,
                            state.failure,
                          ),
                          key: const Key('saved-search-partial-error'),
                        ),
                      ),
                    if (items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('saved-search-load-more'),
                        onPressed: state.isLoading || state.isActing
                            ? null
                            : () => ref
                                  .read(resourceSavedSearchesProvider.notifier)
                                  .loadMore(profileId),
                        child:
                            state.phase == ResourceSavedSearchPhase.loadingMore
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
    );
  }

  Future<void> _open(ResourceSavedSearch savedSearch) async {
    await ref
        .read(publicResourceListingsProvider.notifier)
        .applyFilters(
          mode: savedSearch.mode,
          locality: savedSearch.locality ?? '',
          query: savedSearch.query ?? '',
        );
    if (mounted) context.go('/resources');
  }

  Future<void> _edit(
    String expectedProfileId,
    ResourceSavedSearch savedSearch,
  ) async {
    final updated = await showResourceSavedSearchEditor(
      context,
      expectedProfileId: expectedProfileId,
      savedSearch: savedSearch,
    );
    if (!mounted || !updated) return;
    _showMessage(AppLocalizations.of(context).resourceSavedSearchUpdated);
  }

  Future<void> _delete(
    String expectedProfileId,
    ResourceSavedSearch savedSearch,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceSavedSearchDeleteTitle),
            content: Text(l10n.resourceSavedSearchDeleteMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.resourceSavedSearchCancel),
              ),
              FilledButton(
                key: const Key('saved-search-confirm-delete'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.resourceSavedSearchDeleteAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(resourceSavedSearchesProvider.notifier)
        .delete(expectedProfileId, savedSearch.id);
    if (!mounted) return;
    _showMessage(
      outcome == ResourceSavedSearchMutationOutcome.success
          ? l10n.resourceSavedSearchDeleted
          : l10n.resourceSavedSearchUnableDelete,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ResourceSavedSearchCard extends StatelessWidget {
  const _ResourceSavedSearchCard({
    required this.savedSearch,
    required this.isActing,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ResourceSavedSearch savedSearch;
  final bool isActing;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = <String>[
      if (savedSearch.mode case final mode?)
        l10n.resourceSavedSearchModeFilter(_modeLabel(l10n, mode)),
      if (savedSearch.query case final query?)
        l10n.resourceSavedSearchQueryFilter(query),
      if (savedSearch.locality case final locality?)
        l10n.resourceSavedSearchLocalityFilter(locality),
    ];
    return Semantics(
      label: l10n.resourceSavedSearchCardSemantics(filters.join(', ')),
      child: Card(
        key: Key('saved-search-card-${savedSearch.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                filters.join(' · '),
                key: Key('saved-search-summary-${savedSearch.id}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.resourceSavedSearchUpdatedDate(
                  formatResourceListingDate(context, savedSearch.updatedAt),
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  FilledButton.icon(
                    key: Key('saved-search-open-${savedSearch.id}'),
                    onPressed: isActing ? null : onOpen,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.resourceSavedSearchOpen),
                  ),
                  OutlinedButton.icon(
                    key: Key('saved-search-edit-${savedSearch.id}'),
                    onPressed: isActing ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.resourceSavedSearchEdit),
                  ),
                  TextButton.icon(
                    key: Key('saved-search-delete-${savedSearch.id}'),
                    onPressed: isActing ? null : onDelete,
                    icon: isDeleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(l10n.resourceSavedSearchDeleteAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeLabel(AppLocalizations l10n, ResourceListingMode mode) =>
      switch (mode) {
        ResourceListingMode.donate => l10n.resourceModeDonate,
        ResourceListingMode.exchange => l10n.resourceModeExchange,
      };
}

String resourceSavedSearchFailureMessage(
  AppLocalizations l10n,
  ResourceSavedSearchFailureKind? failure,
) => switch (failure) {
  ResourceSavedSearchFailureKind.invalidInput =>
    l10n.resourceSavedSearchInvalidInput,
  ResourceSavedSearchFailureKind.forbidden => l10n.resourceSavedSearchForbidden,
  ResourceSavedSearchFailureKind.duplicate =>
    l10n.resourceSavedSearchCreateDuplicate,
  ResourceSavedSearchFailureKind.notFound =>
    l10n.resourceSavedSearchNoLongerAvailable,
  ResourceSavedSearchFailureKind.unavailable ||
  null => l10n.resourceSavedSearchUnavailable,
};
