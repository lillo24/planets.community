import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../application/resource_listing_controllers.dart';
import '../domain/resource_listing_models.dart';
import 'resource_listing_widgets.dart';

class OwnResourceListingsScreen extends ConsumerStatefulWidget {
  const OwnResourceListingsScreen({super.key});

  @override
  ConsumerState<OwnResourceListingsScreen> createState() =>
      _OwnResourceListingsScreenState();
}

class _OwnResourceListingsScreenState
    extends ConsumerState<OwnResourceListingsScreen> {
  String? _requestedIdentity;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity != null) {
      _requestedIdentity = identity.id;
      await ref.read(ownResourceListingsProvider.notifier).load(identity.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(ownResourceListingsProvider);
    final items = state.expectedOwnerId == identity?.id
        ? state.items
        : const <OwnResourceListing>[];
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resourceMyListings)),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : state.phase == ResourceListingLoadPhase.loading && items.isEmpty
            ? LoadingState(message: l10n.resourceLoading)
            : state.phase == ResourceListingLoadPhase.failure && items.isEmpty
            ? ErrorState(
                message: resourceListingFailureMessage(l10n, state.failure),
                onRetry: _load,
              )
            : items.isEmpty
            ? EmptyState(
                title: l10n.resourceMyEmptyTitle,
                message: l10n.resourceMyEmptyMessage,
                icon: Icons.inventory_2_outlined,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.small),
                  itemBuilder: (context, index) =>
                      _OwnResourceListingCard(listing: items[index]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('resource-create-from-mine'),
        onPressed: () => context.push('/resources/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.resourceCreateListing),
      ),
    );
  }
}

class _OwnResourceListingCard extends StatelessWidget {
  const _OwnResourceListingCard({required this.listing});

  final OwnResourceListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoverImage(
            key: Key('resource-owner-cover-${listing.id}'),
            title: listing.title ?? l10n.resourceUntitled,
            objectPath: listing.coverObjectPath,
            ownerProfileId: listing.ownerProfileId,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        listing.title ?? l10n.resourceUntitled,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    ResourceListingModeBadge(mode: listing.mode),
                  ],
                ),
                const SizedBox(height: AppSpacing.xSmall),
                ResourceListingLifecycleBadge(lifecycle: listing.lifecycle),
                if (listing.publicLocationLabel case final location?) ...[
                  const SizedBox(height: AppSpacing.small),
                  Text(location),
                ],
                const SizedBox(height: AppSpacing.xSmall),
                Text(
                  l10n.resourceUpdatedDate(
                    formatResourceListingDate(context, listing.updatedAt),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                OutlinedButton(
                  key: Key('resource-edit-${listing.id}'),
                  onPressed: () =>
                      context.push('/resources/${listing.id}/edit'),
                  child: Text(
                    listing.lifecycle == ResourceListingLifecycle.closed
                        ? l10n.resourceViewListing
                        : l10n.resourceEditListing,
                  ),
                ),
                if (listing.lifecycle != ResourceListingLifecycle.draft)
                  OutlinedButton.icon(
                    key: Key('resource-loan-schedule-${listing.id}'),
                    onPressed: () =>
                        context.push('/resources/${listing.id}/loan-schedule'),
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text(l10n.resourceLoanScheduleTitle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
